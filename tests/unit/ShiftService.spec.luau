-- ShiftService against fake services: opening starts a day, rushes raise
-- traffic, closing time closes the restaurant, and the day ends with a summary,
-- a bonus and saved records once the last customers have left.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local DayCycle = Loader.module("Shared/Shift/DayCycle")
local C = DayCycle.Config

local function setup()
	local fired = {}
	local fakeNet = {
		event = function(name)
			return { FireClient = function(_, _player, payload)
				fired[name] = fired[name] or {}
				table.insert(fired[name], payload)
			end }
		end,
		func = function()
			return {}
		end,
	}
	local Shift = Loader.module("Server/Services/ShiftService", { ["Shared/Net"] = fakeNet })
	local player = { UserId = 7, Name = "Tester" }
	local profile = { money = 100, xp = 0, level = 3, rating = 4, upgrades = {}, stats = {} }
	local plot = { owner = player, open = false, customers = {} }
	local log = { money = 0, spent = 0, xp = 0, notes = {}, listener = nil :: any, provider = nil :: any }
	local S
	S = {
		DataService = {
			get = function(p)
				return if p == player then profile else nil
			end,
		},
		PlotService = {
			Plots = { plot },
			get = function(p)
				return if p == player then plot else nil
			end,
		},
		ProgressService = {
			addMoney = function(_, n)
				log.money += n
				profile.money += n
			end,
			spend = function(_, n)
				if profile.money < n then
					return false
				end
				log.spent += n
				profile.money -= n
				return true
			end,
			addXP = function(_, n)
				log.xp += n
			end,
			notify = function(_, text)
				table.insert(log.notes, text)
			end,
			sound = function() end,
			push = function() end,
			addStateProvider = function(fn)
				log.provider = fn
			end,
		},
		-- mimics the real setOpen: flips the flag, then tells ShiftService
		CustomerService = {
			setOpen = function(p, open)
				p.open = open
				Shift.onOpenChanged(p, open)
			end,
		},
		GoalService = {
			onEvent = function(fn)
				log.listener = fn
			end,
		},
	}
	Shift.init(S)
	local t = 100000
	Shift.clock = function()
		return t
	end
	local ctx = { Shift = Shift, player = player, profile = profile, plot = plot, log = log, fired = fired, S = S }
	function ctx.advance(seconds: number)
		t += seconds
	end
	function ctx.toHour(hour: number)
		-- move real time forward until the shift clock reads `hour`
		local s = plot.shift
		assert(s, "open the restaurant first")
		t = s.startedAt + (hour - C.OpenHour) * C.SecondsPerHour
	end
	function ctx.open()
		S.CustomerService.setOpen(plot, true)
	end
	function ctx.close()
		S.CustomerService.setOpen(plot, false)
	end
	function ctx.serveOrder(price: number, tip: number, happy: boolean)
		-- the events CustomerService.completeOrder sends through GoalService.record
		Shift.record(player, "order", 1)
		Shift.record(player, "earn", price + tip)
		if tip > 0 then
			Shift.record(player, "tip", tip)
		end
		if happy then
			Shift.record(player, "happy", 1)
		end
	end
	function ctx.notesMatching(pattern: string): number
		local n = 0
		for _, note in log.notes do
			if string.find(note, pattern, 1, true) then
				n += 1
			end
		end
		return n
	end
	return ctx
end

return {
	["start registers the event listener and state provider"] = function()
		local ctx = setup()
		local spawned = 0
		local fakeTask = { spawn = function()
			spawned += 1
		end }
		-- start() spawns the tick loop; run it with a fake task library
		local Shift = Loader.module("Server/Services/ShiftService", { ["Shared/Net"] = { event = function() end } }, { env = { task = fakeTask } })
		Shift.init(ctx.S)
		Shift.start()
		T.ok(ctx.log.listener == Shift.record, "GoalService.onEvent(ShiftService.record)")
		T.ok(ctx.log.provider == Shift.stateFor)
		T.eq(spawned, 1, "one tick loop")
	end,

	["opening starts day 1 at opening time"] = function()
		local ctx = setup()
		local view = ctx.Shift.stateFor(ctx.player).shift
		T.eq(view.state, "idle")
		T.eq(view.day, 1)
		ctx.open()
		local s = ctx.plot.shift
		T.ok(s, "shift started")
		T.eq(s.day, 1)
		T.eq(s.state, "open")
		T.near(DayCycle.minuteAt(s, ctx.Shift.clock()), C.OpenHour * 60, 1e-6)
		T.eq(ctx.Shift.traffic(ctx.plot), DayCycle.traffic(C.OpenHour * 60))
		view = ctx.Shift.stateFor(ctx.player).shift
		T.eq(view.state, "open")
		T.eq(view.startedAt, s.startedAt)
	end,

	["lunch rush raises traffic and is announced once"] = function()
		local ctx = setup()
		ctx.open()
		ctx.toHour(12.5)
		ctx.profile.level = C.RushScale.FullAtLevel
		T.eq(ctx.Shift.traffic(ctx.plot), 1.8, "full rush once levelled up")
		ctx.profile.level = 1
		T.near(ctx.Shift.traffic(ctx.plot), 1 + 0.8 * C.RushScale.MinScale, 1e-9, "gentle rush at level 1")
		ctx.Shift.tick(ctx.plot)
		ctx.advance(1)
		ctx.Shift.tick(ctx.plot)
		T.eq(ctx.notesMatching("Lunch rush!"), 1)
		ctx.toHour(15)
		ctx.Shift.tick(ctx.plot)
		T.eq(ctx.Shift.traffic(ctx.plot), 0.8)
	end,

	["traffic is normal when no shift is running or it's closing"] = function()
		local ctx = setup()
		T.eq(ctx.Shift.traffic(ctx.plot), 1)
		ctx.open()
		ctx.toHour(12.5)
		ctx.plot.customers = { { alive = true, state = "waiting" } }
		ctx.close()
		T.eq(ctx.plot.shift.state, "closing")
		T.eq(ctx.Shift.traffic(ctx.plot), 1)
	end,

	["events count toward the day while a shift runs"] = function()
		local ctx = setup()
		ctx.Shift.record(ctx.player, "order", 1) -- no shift yet: ignored
		ctx.open()
		ctx.serveOrder(15, 2.5, true)
		local view = ctx.Shift.stateFor(ctx.player).shift
		T.eq(view.orders, 1)
		T.near(view.earned, 17.5, 0.001)
		T.eq(ctx.plot.shift.stats.happy, 1)
	end,

	["closing time closes the restaurant, then the day ends when customers leave"] = function()
		local ctx = setup()
		ctx.open()
		ctx.serveOrder(20, 0, true)
		ctx.plot.customers = { { alive = true, state = "waiting" } }
		ctx.toHour(C.CloseHour)
		ctx.Shift.tick(ctx.plot)
		T.eq(ctx.plot.open, false, "sign flipped to closed")
		T.eq(ctx.plot.shift.state, "closing")
		T.ok(ctx.plot.shift.reachedClose)
		ctx.advance(5)
		ctx.Shift.tick(ctx.plot)
		T.ok(ctx.plot.shift, "still waiting for the last customer")
		ctx.plot.customers = { { alive = true, state = "leaving" } } -- leaving ones don't count
		ctx.Shift.tick(ctx.plot)
		T.eq(ctx.plot.shift, nil, "day over")
		local summary = ctx.fired.DaySummary and ctx.fired.DaySummary[1]
		T.ok(summary, "summary sent to the owner")
		T.eq(summary.day, 1)
		T.ok(summary.fullDay)
		T.eq(summary.stats.orders, 1)
		T.near(ctx.log.money, summary.bonusCash, 0.001)
		T.eq(ctx.log.xp, summary.bonusXP)
		T.ok(summary.bonusCash > 0)
		T.eq(ctx.profile.shift.days, 1, "saved in profile.shift")
		local view = ctx.Shift.stateFor(ctx.player).shift
		T.eq(view.state, "idle")
		T.eq(view.day, 2)
	end,

	["closing grace ends the day even if customers are still inside"] = function()
		local ctx = setup()
		ctx.open()
		ctx.serveOrder(10, 0, false)
		ctx.plot.customers = { { alive = true, state = "waiting" } }
		ctx.close()
		ctx.advance(C.ClosingGrace - 1)
		ctx.Shift.tick(ctx.plot)
		T.ok(ctx.plot.shift, "not yet")
		ctx.advance(1)
		ctx.Shift.tick(ctx.plot)
		T.eq(ctx.plot.shift, nil)
		T.ok(not ctx.fired.DaySummary[1].fullDay, "closed early")
	end,

	["closing before serving anyone doesn't count as a day"] = function()
		local ctx = setup()
		ctx.open()
		ctx.close()
		ctx.Shift.tick(ctx.plot)
		T.eq(ctx.plot.shift, nil)
		T.eq(ctx.fired.DaySummary, nil, "no summary")
		T.eq(ctx.profile.shift.days, 0)
		T.eq(ctx.log.money, 0)
		ctx.open()
		T.eq(ctx.plot.shift.day, 1, "still day 1")
	end,

	["reopening before closing time continues the same day"] = function()
		local ctx = setup()
		ctx.open()
		ctx.serveOrder(10, 0, true)
		ctx.toHour(13)
		ctx.plot.customers = { { alive = true, state = "waiting" } }
		ctx.close()
		local s = ctx.plot.shift
		ctx.open()
		T.ok(ctx.plot.shift == s, "same shift")
		T.eq(s.state, "open")
		T.eq(s.closingSince, nil)
		T.eq(s.stats.orders, 1)
	end,

	["reopening after closing time wraps up the old day and starts the next"] = function()
		local ctx = setup()
		ctx.open()
		ctx.serveOrder(10, 0, true)
		ctx.plot.customers = { { alive = true, state = "waiting" } }
		ctx.toHour(C.CloseHour)
		ctx.Shift.tick(ctx.plot) -- closing time
		ctx.open()
		T.eq(#ctx.fired.DaySummary, 1, "day 1 summary")
		T.eq(ctx.plot.shift.day, 2)
		T.eq(ctx.plot.shift.state, "open")
		T.eq(ctx.plot.shift.stats.orders, 0)
	end,

	["wages are paid from the bonus and never take money below zero"] = function()
		local ctx = setup()
		ctx.Shift.staffOf = function()
			return { cook = 10 } -- far more than one order's bonus covers
		end
		ctx.profile.money = 50
		ctx.open()
		ctx.serveOrder(10, 0, true)
		ctx.close()
		ctx.Shift.tick(ctx.plot)
		local s = ctx.fired.DaySummary[1]
		T.eq(s.wages, 10 * C.Wages.cook)
		T.ok(s.net < 0)
		T.eq(ctx.profile.money, 0, "paid what they could, not below zero")
	end,

	["an open restaurant with no day running starts one on the next tick"] = function()
		local ctx = setup()
		ctx.plot.open = true -- opened without going through setOpen
		ctx.Shift.tick(ctx.plot)
		T.ok(ctx.plot.shift, "day started")
		T.eq(ctx.plot.shift.day, 1)
		ctx.plot.open = false
		ctx.plot.shift = nil
		ctx.Shift.tick(ctx.plot)
		T.eq(ctx.plot.shift, nil, "closed restaurants stay idle")
	end,

	["a player leaving mid-shift doesn't break the tick"] = function()
		local ctx = setup()
		ctx.open()
		ctx.plot.owner = nil
		ctx.Shift.tick(ctx.plot)
		ctx.Shift.onOpenChanged(ctx.plot, false)
		T.ok(true)
	end,
}
