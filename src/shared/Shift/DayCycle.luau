--!strict
-- Pure rules for the day / shift cycle (no services, so it runs in Lune tests).
-- Numbers live in Config/DayCycle. The server side is ShiftService.
--
-- Time: a shift stores the real time it started (`startedAt`, in
-- workspace:GetServerTimeNow() seconds). The game clock is "minutes since
-- midnight": OpenHour * 60 at the start, CloseHour * 60 at closing time.

local Config = require(script.Parent.Parent.Config.DayCycle)

local DayCycle = {}
DayCycle.Config = Config

export type Stats = {
	orders: number,
	sales: number, -- order prices (without tips)
	tips: number,
	happy: number,
	angry: number, -- walk-outs
	rushOrders: number, -- orders completed during a rush phase
	pizzas: number,
	kebabs: number,
	drinks: number,
	cleaned: number,
}

export type Shift = {
	day: number,
	startedAt: number,
	state: string, -- "open" | "closing"
	closingSince: number?,
	reachedClose: boolean, -- stayed open until closing time
	startRating: number,
	phase: string?, -- last phase id announced (ShiftService uses it for rush toasts)
	stats: Stats,
}

export type Records = {
	days: number,
	bestSales: number,
	bestOrders: number,
}

export type Summary = {
	day: number,
	grade: string,
	happyShare: number,
	fullDay: boolean,
	stats: Stats,
	startRating: number,
	endRating: number,
	bonusCash: number,
	bonusXP: number,
	wages: number,
	net: number, -- bonusCash - wages (can be negative)
	bestSales: boolean,
	bestOrders: boolean,
}

local function cents(n: number): number
	return math.floor(n * 100 + 0.5) / 100
end

------------------------------------------------------------------ clock

function DayCycle.dayLength(): number
	return (Config.CloseHour - Config.OpenHour) * Config.SecondsPerHour
end

function DayCycle.minuteFromElapsed(elapsed: number): number
	return Config.OpenHour * 60 + math.max(0, elapsed) * 60 / Config.SecondsPerHour
end

function DayCycle.minuteAt(shift: Shift, now: number): number
	return DayCycle.minuteFromElapsed(now - shift.startedAt)
end

-- Real start time that puts the clock at `hour` right now (dev jumps, tests).
function DayCycle.startForHour(hour: number, now: number): number
	return now - (hour - Config.OpenHour) * Config.SecondsPerHour
end

function DayCycle.isClosingTime(minute: number): boolean
	return minute >= Config.CloseHour * 60
end

-- The phase at a clock minute, or nil once it's closing time.
function DayCycle.phaseAt(minute: number): any?
	if DayCycle.isClosingTime(minute) then
		return nil
	end
	local hour = minute / 60
	for _, p in Config.Phases do
		if hour >= p.from and hour < p.to then
			return p
		end
	end
	return Config.Phases[1]
end

-- How much of a rush's extra traffic applies at this level (Config.RushScale).
function DayCycle.rushScale(level: number?): number
	local rs = Config.RushScale
	if not rs or not level then
		return 1
	end
	if level >= rs.FullAtLevel then
		return 1
	end
	local t = math.clamp((level - rs.FromLevel) / math.max(1, rs.FullAtLevel - rs.FromLevel), 0, 1)
	return rs.MinScale + (1 - rs.MinScale) * t
end

-- Customer arrival multiplier at a clock minute (1 outside the day).
-- With a level, rushes are softened for low levels (see rushScale).
function DayCycle.traffic(minute: number, level: number?): number
	local p = DayCycle.phaseAt(minute)
	local traffic = if p then p.traffic or 1 else 1
	if traffic > 1 then
		traffic = 1 + (traffic - 1) * DayCycle.rushScale(level)
	end
	return traffic
end

-- "12:40 PM" (rounded down to 5 minutes so the clock ticks calmly).
function DayCycle.formatClock(minute: number): string
	local m = math.floor(minute / 5) * 5
	local h24 = (m // 60) % 24
	local mm = m % 60
	local suffix = if h24 >= 12 then "PM" else "AM"
	local h12 = h24 % 12
	if h12 == 0 then
		h12 = 12
	end
	return ("%d:%02d %s"):format(h12, mm, suffix)
end

-- Phases as fractions of the day, for the HUD timeline bar.
function DayCycle.timeline(): { { from: number, to: number, rush: boolean, label: string, icon: string } }
	local span = Config.CloseHour - Config.OpenHour
	local out = {}
	for _, p in Config.Phases do
		table.insert(out, {
			from = (p.from - Config.OpenHour) / span,
			to = (p.to - Config.OpenHour) / span,
			rush = p.rush == true,
			label = p.label,
			icon = p.icon or "",
		})
	end
	return out
end

------------------------------------------------------------------ shift

function DayCycle.newStats(): Stats
	return { orders = 0, sales = 0, tips = 0, happy = 0, angry = 0, rushOrders = 0, pizzas = 0, kebabs = 0, drinks = 0, cleaned = 0 }
end

function DayCycle.newShift(day: number, now: number, rating: number): Shift
	return {
		day = day,
		startedAt = now,
		state = "open",
		closingSince = nil,
		reachedClose = false,
		startRating = rating,
		phase = nil,
		stats = DayCycle.newStats(),
	}
end

-- Count a game event (the same events GoalService.record receives).
function DayCycle.record(shift: Shift, event: string, amount: number?, param: string?, minute: number)
	local n = amount or 1
	if n ~= n or n <= 0 then
		return
	end
	local s = shift.stats
	if event == "order" then
		s.orders += n
		local p = DayCycle.phaseAt(minute)
		if p and p.rush then
			s.rushOrders += n
		end
	elseif event == "earn" then
		-- price + tip; the tip is also sent on its own as "tip"
		s.sales = cents(s.sales + n)
	elseif event == "tip" then
		s.tips = cents(s.tips + n)
		s.sales = cents(s.sales - n)
	elseif event == "happy" then
		s.happy += n
	elseif event == "angry" then
		s.angry += n
	elseif event == "clean" then
		s.cleaned += n
	elseif event == "serve_kind" then
		if param == "pizza" then
			s.pizzas += n
		elseif param == "kebab" then
			s.kebabs += n
		elseif param == "drink" then
			s.drinks += n
		end
	end
end

function DayCycle.happyShare(stats: Stats): number
	local total = stats.orders + stats.angry
	if total <= 0 then
		return 0
	end
	return math.clamp(stats.happy / total, 0, 1)
end

function DayCycle.grade(stats: Stats): string
	local share = DayCycle.happyShare(stats)
	for _, g in Config.Grades do
		if share >= g.min then
			return g.grade
		end
	end
	return Config.Grades[#Config.Grades].grade
end

function DayCycle.ratingFactor(rating: number): number
	local b = Config.Bonus
	return math.clamp(rating / b.RatingPivot, b.RatingFactorMin, b.RatingFactorMax)
end

-- staff: { [role] = count }. Unknown roles cost nothing.
function DayCycle.wages(staff: { [string]: number }?): number
	local total = 0
	for role, count in staff or {} do
		local w = (Config.Wages :: any)[role]
		if w and type(count) == "number" and count > 0 then
			total += w * count
		end
	end
	return cents(total)
end

function DayCycle.reconcileRecords(r: any): Records
	if type(r) ~= "table" then
		r = {}
	end
	r.days = tonumber(r.days) or 0
	r.bestSales = tonumber(r.bestSales) or 0
	r.bestOrders = tonumber(r.bestOrders) or 0
	return r :: Records
end

-- Builds the end-of-day summary and updates `records` (days played, bests).
function DayCycle.finish(shift: Shift, records: Records, endRating: number, staff: { [string]: number }?): Summary
	local s = shift.stats
	local b = Config.Bonus
	local full = shift.reachedClose
	local mult = if full then b.FullDayMultiplier else 1
	local cash = (s.orders * b.CashPerOrder + s.happy * b.CashPerHappy + s.rushOrders * b.CashPerRushOrder)
		* mult
		* DayCycle.ratingFactor(endRating)
	local bonusCash = cents(cash)
	local bonusXP = math.floor(s.orders * b.XPPerOrder * mult)
	local wages = DayCycle.wages(staff)
	local bestSales = s.sales > records.bestSales and records.days > 0
	local bestOrders = s.orders > records.bestOrders and records.days > 0
	records.days += 1
	records.bestSales = math.max(records.bestSales, s.sales)
	records.bestOrders = math.max(records.bestOrders, s.orders)
	return {
		day = shift.day,
		grade = DayCycle.grade(s),
		happyShare = DayCycle.happyShare(s),
		fullDay = full,
		stats = table.clone(s),
		startRating = shift.startRating,
		endRating = endRating,
		bonusCash = bonusCash,
		bonusXP = bonusXP,
		wages = wages,
		net = cents(bonusCash - wages),
		bestSales = bestSales,
		bestOrders = bestOrders,
	}
end

-- A day only counts (summary, bonus, day number) once someone was served.
function DayCycle.counts(shift: Shift): boolean
	return shift.stats.orders > 0
end

return DayCycle
