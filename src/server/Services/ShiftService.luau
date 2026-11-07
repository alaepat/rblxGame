--!strict
-- Day / shift cycle (TASKS #7), server authoritative.
--  * Opening the restaurant (CustomerService.setOpen) starts "Day N" at 10:00
--    on the game clock; closing it (by hand, or automatically at closing time)
--    moves the shift to "closing". When the last customers have left, or
--    DayCycle.ClosingGrace runs out, the day ends: the owner gets a summary
--    (DaySummary remote), a shift bonus, and wages are paid.
--  * Rush phases multiply customer traffic: CustomerService divides its spawn
--    interval by ShiftService.traffic(plot).
--  * Stats come from GoalService.record (the game's event feed) via
--    GoalService.onEvent, so no extra hooks are needed in gameplay code.
--  * Per-plot state lives in plot.shift (PlotService.release clears it).
--    Lifetime records (days played, best day) are saved in profile.shift.
--  * Rules live in Shared.Shift.DayCycle, numbers in Config/DayCycle.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DayCycle = require(Shared.Shift.DayCycle)
local Net = require(Shared.Net)

local Config = DayCycle.Config

local ShiftService = {}
ShiftService.Config = Config
local S: any

local TICK = 1 -- seconds between shift checks

function ShiftService.init(services)
	S = services
end

-- Replaceable clock (tests move it). Same timeline the client reads with
-- workspace:GetServerTimeNow(), so the HUD clock matches the server.
ShiftService.clock = function(): number
	return workspace:GetServerTimeNow()
end

local function now(): number
	return ShiftService.clock()
end

local function recordsOf(player: Player): DayCycle.Records?
	local profile = S.DataService.get(player)
	if not profile then
		return nil
	end
	profile.shift = DayCycle.reconcileRecords(profile.shift)
	return profile.shift
end

-- Staff on the payroll: { [role] = count }. No staff exist yet (TASKS #11);
-- when they do, return them here and DayCycle.wages charges Config.Wages.
function ShiftService.staffOf(_player: Player): { [string]: number }
	return {}
end

local function pushOwner(plot)
	if plot.owner then
		S.ProgressService.push(plot.owner)
	end
end

local function startShift(plot)
	local owner = plot.owner
	local profile = owner and S.DataService.get(owner)
	local records = owner and recordsOf(owner)
	if not profile or not records then
		return
	end
	local shift = DayCycle.newShift(records.days + 1, now(), profile.rating or 4)
	shift.phase = (DayCycle.phaseAt(DayCycle.minuteAt(shift, now())) or {}).id
	plot.shift = shift
	S.ProgressService.notify(owner, ("☀️ Day %d begins! Lunch rush at noon, dinner rush at 5:30."):format(shift.day), "info")
end

-- Ends the day: summary, bonus, wages, records. Called when closing is done.
function ShiftService.finish(plot)
	local shift = plot.shift
	plot.shift = nil
	local owner = plot.owner
	if not shift or not owner then
		return
	end
	-- anyone still inside when the day ends goes home politely (no review),
	-- so leftover queues can't cost rating after the summary
	if S.CustomerService.sendHomeAll then
		S.CustomerService.sendHomeAll(plot)
	end
	if not DayCycle.counts(shift) then
		S.ProgressService.notify(owner, "Closed before serving anyone, so this day doesn't count.", "info")
		pushOwner(plot)
		return
	end
	local profile = S.DataService.get(owner)
	local records = recordsOf(owner)
	if not profile or not records then
		return
	end
	local summary = DayCycle.finish(shift, records, profile.rating or 4, ShiftService.staffOf(owner))
	if summary.bonusCash > 0 then
		S.ProgressService.addMoney(owner, summary.bonusCash, "shift")
	end
	if summary.wages > 0 then
		-- wages come out of your money; never below zero
		local pay = math.min(summary.wages, math.max(0, profile.money))
		if pay > 0 then
			S.ProgressService.spend(owner, pay)
		end
	end
	if summary.bonusXP > 0 then
		S.ProgressService.addXP(owner, summary.bonusXP)
	end
	Net.event("DaySummary"):FireClient(owner, summary)
	S.ProgressService.sound(owner, "Cash")
	pushOwner(plot)
end

-- Called by CustomerService.setOpen whenever the sign flips.
function ShiftService.onOpenChanged(plot, open: boolean)
	if not plot.owner then
		return
	end
	local shift = plot.shift
	if open then
		if shift and shift.state == "closing" then
			if DayCycle.isClosingTime(DayCycle.minuteAt(shift, now())) then
				-- reopening after closing time: wrap up the old day, start a new one
				ShiftService.finish(plot)
				startShift(plot)
			else
				shift.state = "open"
				shift.closingSince = nil
				S.ProgressService.notify(plot.owner, ("Back open! Day %d continues."):format(shift.day), "good")
			end
		elseif not shift then
			startShift(plot)
		end
	elseif shift and shift.state == "open" then
		shift.state = "closing"
		shift.closingSince = now()
		if DayCycle.counts(shift) and not shift.reachedClose then
			S.ProgressService.notify(plot.owner, "Serve the customers still inside. Your day summary comes when they've left.", "info")
		end
	end
	pushOwner(plot)
end

-- Customers that still need serving (leaving customers are already removed).
local function customersInside(plot): number
	local n = 0
	for _, c in plot.customers or {} do
		if c.alive and c.state ~= "leaving" then
			n += 1
		end
	end
	return n
end

-- One step of a plot's shift. Exposed for tests.
function ShiftService.tick(plot)
	local shift = plot.shift
	if not plot.owner then
		return
	end
	if not shift then
		-- open with no day running (e.g. opened before this service saw it): start one
		if plot.open then
			startShift(plot)
			pushOwner(plot)
		end
		return
	end
	local t = now()
	local minute = DayCycle.minuteAt(shift, t)
	if shift.state == "open" then
		if DayCycle.isClosingTime(minute) then
			shift.reachedClose = true
			S.ProgressService.notify(plot.owner, "🌙 Closing time! Serve the last customers, then your day summary comes.", "info")
			S.CustomerService.setOpen(plot, false) -- calls onOpenChanged -> "closing"
			return
		end
		local phase = DayCycle.phaseAt(minute)
		if phase and phase.id ~= shift.phase then
			shift.phase = phase.id
			if phase.rush then
				S.ProgressService.notify(plot.owner, ("%s %s! Customers are pouring in."):format(phase.icon or "🔥", phase.label), "good")
				S.ProgressService.sound(plot.owner, "Bell")
			end
			pushOwner(plot)
		end
	elseif shift.state == "closing" then
		local since = shift.closingSince or t
		if customersInside(plot) == 0 or t - since >= Config.ClosingGrace then
			ShiftService.finish(plot)
		end
	end
end

-- Spawn-rate multiplier for CustomerService (1 when no shift is running).
function ShiftService.traffic(plot): number
	local shift = plot.shift
	if not shift or shift.state ~= "open" then
		return 1
	end
	local profile = plot.owner and S.DataService.get(plot.owner)
	return DayCycle.traffic(DayCycle.minuteAt(shift, now()), profile and profile.level)
end

-- Fed by GoalService.onEvent with every recorded game event.
function ShiftService.record(player: Player, event: string, amount: number?, param: string?)
	local plot = S.PlotService.get(player)
	local shift = plot and plot.shift
	if not shift then
		return
	end
	DayCycle.record(shift, event, amount, param, DayCycle.minuteAt(shift, now()))
end

-- Snapshot field for the client day clock (Controllers/DayClock).
function ShiftService.stateFor(player: Player): { [string]: any }
	local plot = S.PlotService.get(player)
	local records = recordsOf(player)
	if not plot or not records then
		return {}
	end
	local shift = plot.shift
	local view: { [string]: any } = {
		openHour = Config.OpenHour,
		closeHour = Config.CloseHour,
		secondsPerHour = Config.SecondsPerHour,
		daysPlayed = records.days,
	}
	if shift then
		view.state = shift.state
		view.day = shift.day
		view.startedAt = shift.startedAt
		view.orders = shift.stats.orders
		view.earned = shift.stats.sales + shift.stats.tips
		view.closingSince = shift.closingSince
		view.closingGrace = Config.ClosingGrace
	else
		view.state = "idle"
		view.day = records.days + 1
	end
	return { shift = view }
end

-- Studio test hook: jump the clock of a running shift to `hour`.
function ShiftService.devJump(plot, hour: number): string
	local shift = plot.shift
	if not shift then
		return "no shift running (open the restaurant first)"
	end
	shift.startedAt = DayCycle.startForHour(hour, now())
	ShiftService.tick(plot)
	pushOwner(plot)
	return ("clock %s"):format(DayCycle.formatClock(DayCycle.minuteAt(shift, now())))
end

function ShiftService.start()
	S.GoalService.onEvent(ShiftService.record)
	S.ProgressService.addStateProvider(ShiftService.stateFor)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, plot in S.PlotService.Plots do
				local ok, err = pcall(ShiftService.tick, plot)
				if not ok then
					warn("[ShiftService] tick failed: " .. tostring(err))
				end
			end
		end
	end)
end

return ShiftService
