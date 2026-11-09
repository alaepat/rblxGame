-- StaffService against fake services: NPCs follow hires, the cashier takes
-- orders through CustomerService.submitOrder, the cleaner cleans the nearest
-- mess through CleaningService, and wages reach the day summary.

local roblox = require("@lune/roblox")
local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local function fakeModel()
	local m = { Parent = true, destroyed = false }
	function m:Destroy()
		self.destroyed = true
		self.Parent = nil
	end
	m.pivots = {}
	function m:PivotTo(cf)
		self.cf = cf
		table.insert(self.pivots, cf.Position)
	end
	return m
end

local function setup()
	local spawned = {}
	-- run spawned threads right away so cleaner jobs finish inside the test
	local fakeTask = {
		spawn = function(fn, ...)
			fn(...)
		end,
		wait = function() end,
	}
	local Staff = Loader.module("Server/Services/StaffService", nil, { env = { task = fakeTask }, services = { Players = {} } })
	local player = { UserId = 3, Name = "Tester" }
	local profile = { upgrades = {}, money = 0 }
	local plot = {
		owner = player,
		model = { Name = "Restaurant" },
		origin = CFrame.new(100, 0, 0),
		trash = {},
		stations = {},
		posCustomer = nil,
	}
	local log = { orders = {}, notes = {}, removed = {}, wiped = {}, front = nil :: any }
	local S = {
		DataService = { get = function(p)
			return if p == player then profile else nil
		end },
		PlotService = { Plots = { plot } },
		ProgressService = {
			notify = function(_, text)
				table.insert(log.notes, text)
			end,
			push = function() end,
		},
		CustomerService = {
			frontCustomer = function()
				return log.front
			end,
			-- like the real one: only works for the customer the POS is open for
			submitOrder = function(p, ids)
				if plot.posCustomer ~= log.front then
					return false, "That customer is gone"
				end
				table.insert(log.orders, { player = p, ids = ids })
				plot.posCustomer = nil
				log.front = nil
				return true, "Order #1 sent to the kitchen"
			end,
		},
		CleaningService = {
			removeTrash = function(_, m, who)
				local i = table.find(plot.trash, m)
				if i then
					table.remove(plot.trash, i)
				end
				table.insert(log.removed, { m = m, who = who })
				return i ~= nil
			end,
			wipeCounter = function(st, who)
				st.dirty = false
				table.insert(log.wiped, { st = st, who = who })
				return true
			end,
		},
	}
	Staff.init(S)
	Staff.makeNPC = function(role, parent, cf)
		local npc = { role = role, model = fakeModel(), root = { Position = cf.Position, CFrame = cf } }
		npc.model.Parent = parent
		table.insert(spawned, npc)
		return npc
	end
	-- no pathfinding offline: pretend every walk arrives
	Staff.walkPath = function(_, _, npc, goal)
		npc.root.Position = goal
		return true
	end
	local t = 0
	Staff.clock = function()
		return t
	end
	local ctx = { Staff = Staff, player = player, profile = profile, plot = plot, log = log, spawned = spawned, S = S }
	function ctx.advance(s)
		t += s
	end
	function ctx.trashAt(x: number, z: number)
		local m = fakeModel()
		m.GetPivot = function()
			return CFrame.new(x, 0, z)
		end
		table.insert(plot.trash, m)
		return m
	end
	return ctx
end

return {
	["no hires, no staff"] = function()
		local ctx = setup()
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.spawned, 0)
	end,

	["hiring spawns staff at their spots, firing removes them"] = function()
		local ctx = setup()
		ctx.profile.upgrades.hire_cashier = true
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.spawned, 1)
		local cashier = ctx.plot.staff.npcs.cashier
		T.ok(cashier, "cashier spawned")
		T.ok(cashier.model.Parent == ctx.plot.model, "inside the restaurant model")
		-- placed relative to the plot origin (register at local x = -2)
		T.near(cashier.root.Position.X, 100 - 2, 1e-6)
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.spawned, 1, "not spawned twice")
		ctx.profile.upgrades.hire_cashier = nil
		ctx.Staff.tick(ctx.plot)
		T.ok(cashier.model.destroyed, "fired")
		T.eq(ctx.plot.staff.npcs.cashier, nil)
	end,

	["cashier takes the order after the delay"] = function()
		local ctx = setup()
		local delay = 4 -- Config/Staff cashier.orderDelay
		ctx.profile.upgrades.hire_cashier = true
		local customer = { want = { "cheese_pizza", "cola" } }
		ctx.log.front = customer
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.log.orders, 0, "just arrived")
		ctx.advance(delay - 0.5)
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.log.orders, 0, "still waiting")
		ctx.advance(1)
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.log.orders, 1, "order taken")
		local o = ctx.log.orders[1]
		T.ok(o.player == ctx.player, "placed for the owner")
		T.eq(o.ids[1], "cheese_pizza")
		T.eq(o.ids[2], "cola")
		T.ok(o.ids ~= customer.want, "a copy, not the customer's own table")
		T.ok(string.find(ctx.log.notes[1], "Cashier: Order #1", 1, true), ctx.log.notes[1] or "no toast")
	end,

	["cashier leaves customers alone while the player has the POS open"] = function()
		local ctx = setup()
		ctx.profile.upgrades.hire_cashier = true
		local customer = { want = { "cola" } }
		ctx.log.front = customer
		ctx.plot.posCustomer = customer
		for _ = 1, 20 do
			ctx.advance(1)
			ctx.Staff.tick(ctx.plot)
		end
		T.eq(#ctx.log.orders, 0)
	end,

	["no cashier hired: nobody takes orders"] = function()
		local ctx = setup()
		ctx.log.front = { want = { "cola" } }
		for _ = 1, 20 do
			ctx.advance(1)
			ctx.Staff.tick(ctx.plot)
		end
		T.eq(#ctx.log.orders, 0)
	end,

	["cleaner cleans the nearest rubbish first, without giving the owner credit"] = function()
		local ctx = setup()
		ctx.profile.upgrades.hire_cleaner = true
		ctx.Staff.tick(ctx.plot) -- spawns the cleaner (and starts on any job)
		local cleaner = ctx.plot.staff.npcs.cleaner
		T.ok(cleaner, "cleaner spawned")
		local home = cleaner.root.Position
		local far = ctx.trashAt(home.X + 30, home.Z)
		local near = ctx.trashAt(home.X + 3, home.Z)
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.log.removed, 1)
		T.ok(ctx.log.removed[1].m == near, "nearest first")
		T.eq(ctx.log.removed[1].who, nil, "staff clean: no player credit")
		ctx.Staff.tick(ctx.plot)
		T.ok(ctx.log.removed[2] and ctx.log.removed[2].m == far, "then the next one")
		T.eq(#ctx.plot.trash, 0)
		T.eq(ctx.plot.staff.busy, false, "free again")
	end,

	["cleaner wipes messy counters"] = function()
		local ctx = setup()
		ctx.profile.upgrades.hire_cleaner = true
		local part = { Position = Vector3.new(90, 4, 0), CFrame = CFrame.new(90, 4, 0), Size = Vector3.new(6, 1, 3) }
		local st = { dirty = true, part = part }
		ctx.plot.stations = { st }
		ctx.Staff.tick(ctx.plot)
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.log.wiped, 1)
		T.ok(ctx.log.wiped[1].st == st)
		T.eq(ctx.log.wiped[1].who, nil)
		T.eq(st.dirty, false)
	end,

	["cleaner skips a mess the player already cleaned"] = function()
		local ctx = setup()
		ctx.profile.upgrades.hire_cleaner = true
		ctx.Staff.tick(ctx.plot)
		local m = ctx.trashAt(0, 0)
		-- the player picks it up while the cleaner is walking over
		ctx.Staff.walkPath = function(_, _, npc, goal)
			table.remove(ctx.plot.trash, table.find(ctx.plot.trash, m))
			npc.root.Position = goal
			return true
		end
		ctx.Staff.tick(ctx.plot)
		T.eq(#ctx.log.removed, 0, "nothing to remove")
		T.eq(ctx.plot.staff.busy, false)
	end,

	["if no path works the cleaner steps straight to the mess"] = function()
		local ctx = setup()
		ctx.profile.upgrades.hire_cleaner = true
		ctx.Staff.tick(ctx.plot)
		ctx.Staff.walkPath = function()
			return false
		end
		ctx.trashAt(120, 5)
		ctx.Staff.tick(ctx.plot)
		local cleaner = ctx.plot.staff.npcs.cleaner
		local wentToMess = false
		for _, p in cleaner.model.pivots do
			if math.abs(p.X - 120) < 1e-6 and math.abs(p.Z - 5) < 1e-6 then
				wentToMess = true
			end
		end
		T.ok(wentToMess, "stepped straight to the mess")
		T.eq(#ctx.log.removed, 1, "and cleaned it")
		T.near(cleaner.model.cf.Position.X, 100 + 13.5, 1e-6, "then back to the spot by the counter")
	end,

	["wages: ShiftService pays for hired staff"] = function()
		local Shift = Loader.module("Server/Services/ShiftService", { ["Shared/Net"] = { event = function()
			return { FireClient = function() end }
		end } })
		local profile = { upgrades = { hire_cleaner = true, hire_cashier = true } }
		Shift.init({ DataService = { get = function()
			return profile
		end } })
		local staff = Shift.staffOf({})
		T.eq(staff.cleaner, 1)
		T.eq(staff.cashier, 1)
		profile.upgrades = {}
		T.eq(next(Shift.staffOf({})), nil)
	end,
}
