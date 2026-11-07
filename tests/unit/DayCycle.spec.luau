-- Pure day / shift rules: clock, phases, traffic, event counting, grades,
-- end-of-day bonus, wages and records.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local DayCycle = Loader.module("Shared/Shift/DayCycle")
local C = DayCycle.Config

local function minute(h: number, m: number?): number
	return h * 60 + (m or 0)
end

local function shiftWith(stats: { [string]: number }, reachedClose: boolean?)
	local s = DayCycle.newShift(1, 0, 4)
	for k, v in stats do
		s.stats[k] = v
	end
	s.reachedClose = reachedClose == true
	return s
end

return {
	["config phases cover the whole day with no gaps"] = function()
		T.eq(C.Phases[1].from, C.OpenHour, "first phase starts at opening")
		T.eq(C.Phases[#C.Phases].to, C.CloseHour, "last phase ends at closing")
		for i = 2, #C.Phases do
			T.eq(C.Phases[i].from, C.Phases[i - 1].to, "phase " .. C.Phases[i].id .. " follows the previous one")
		end
		local rushes = 0
		for _, p in C.Phases do
			T.ok(p.traffic > 0, p.id .. " traffic > 0")
			if p.rush then
				rushes += 1
				T.ok(p.traffic > 1, p.id .. " rush brings more customers")
			end
		end
		T.ok(rushes >= 2, "lunch and dinner rush at least")
	end,

	["clock starts at opening and runs SecondsPerHour per game hour"] = function()
		T.eq(DayCycle.minuteFromElapsed(0), minute(C.OpenHour))
		T.eq(DayCycle.minuteFromElapsed(C.SecondsPerHour), minute(C.OpenHour + 1))
		T.eq(DayCycle.minuteFromElapsed(-5), minute(C.OpenHour), "never before opening")
		T.eq(DayCycle.dayLength(), (C.CloseHour - C.OpenHour) * C.SecondsPerHour)
		local s = DayCycle.newShift(1, 1000, 4)
		T.near(DayCycle.minuteAt(s, 1000 + C.SecondsPerHour * 2.5), minute(C.OpenHour + 2, 30), 1e-6)
		s.startedAt = DayCycle.startForHour(13, 5000)
		T.near(DayCycle.minuteAt(s, 5000), minute(13), 1e-6, "startForHour puts the clock at that hour")
	end,

	["formatClock prints 12-hour time in 5-minute steps"] = function()
		T.eq(DayCycle.formatClock(minute(10)), "10:00 AM")
		T.eq(DayCycle.formatClock(minute(12)), "12:00 PM")
		T.eq(DayCycle.formatClock(minute(13, 37)), "1:35 PM")
		T.eq(DayCycle.formatClock(minute(22)), "10:00 PM")
		T.eq(DayCycle.formatClock(0), "12:00 AM")
		T.eq(DayCycle.formatClock(minute(11, 59.9)), "11:55 AM")
	end,

	["phases and traffic: rushes are busier, closing time has none"] = function()
		T.eq(DayCycle.phaseAt(minute(10, 30)).id, "morning")
		T.eq(DayCycle.phaseAt(minute(12)).id, "lunch", "phase starts exactly on its hour")
		T.eq(DayCycle.phaseAt(minute(17, 45)).id, "dinner")
		T.eq(DayCycle.phaseAt(minute(21, 30)).id, "latenight")
		T.eq(DayCycle.phaseAt(minute(22)), nil)
		T.eq(DayCycle.traffic(minute(12, 30)), 1.8)
		T.eq(DayCycle.traffic(minute(18)), 2.0)
		T.eq(DayCycle.traffic(minute(23)), 1, "no multiplier after closing")
		T.ok(DayCycle.isClosingTime(minute(22)))
		T.ok(not DayCycle.isClosingTime(minute(21, 59)))
	end,

	["rushes are softened at low levels, quiet phases are not"] = function()
		local rs = C.RushScale
		T.eq(DayCycle.rushScale(nil), 1, "no level: full strength")
		T.eq(DayCycle.rushScale(rs.FromLevel), rs.MinScale)
		T.eq(DayCycle.rushScale(rs.FullAtLevel), 1)
		T.eq(DayCycle.rushScale(50), 1)
		T.ok(DayCycle.rushScale(4) > DayCycle.rushScale(2), "grows with level")
		T.eq(DayCycle.rushScale(0), rs.MinScale, "never below MinScale")
		local dinner = minute(18)
		T.eq(DayCycle.traffic(dinner), 2.0)
		T.near(DayCycle.traffic(dinner, 1), 1 + 1.0 * rs.MinScale, 1e-9)
		T.eq(DayCycle.traffic(dinner, rs.FullAtLevel), 2.0)
		T.eq(DayCycle.traffic(minute(15), 1), 0.8, "afternoon lull unchanged")
		T.eq(DayCycle.traffic(minute(23), 1), 1)
		T.ok(DayCycle.traffic(dinner, 1) > 1, "a rush is still busier than normal at level 1")
	end,

	["timeline fractions match the phases"] = function()
		local tl = DayCycle.timeline()
		T.eq(#tl, #C.Phases)
		T.eq(tl[1].from, 0)
		T.eq(tl[#tl].to, 1)
		T.near(tl[2].from, (12 - C.OpenHour) / (C.CloseHour - C.OpenHour), 1e-9)
		T.ok(tl[2].rush and not tl[1].rush)
	end,

	["record splits sales from tips and counts rush orders"] = function()
		local s = DayCycle.newShift(1, 0, 4)
		-- completeOrder sends earn (price + tip) and then tip
		DayCycle.record(s, "earn", 20, nil, minute(12, 30))
		DayCycle.record(s, "tip", 3, nil, minute(12, 30))
		DayCycle.record(s, "order", 1, nil, minute(12, 30))
		DayCycle.record(s, "order", 1, nil, minute(10, 30))
		DayCycle.record(s, "happy", 1, nil, 0)
		DayCycle.record(s, "angry", 1, nil, 0)
		DayCycle.record(s, "clean", 1, nil, 0)
		DayCycle.record(s, "serve_kind", 1, "pizza", 0)
		DayCycle.record(s, "serve_kind", 1, "kebab", 0)
		DayCycle.record(s, "serve_kind", 2, "drink", 0)
		DayCycle.record(s, "serve_recipe", 1, "cheese_pizza", 0) -- not a day stat
		DayCycle.record(s, "order", -1, nil, 0) -- ignored
		DayCycle.record(s, "order", 0 / 0, nil, 0) -- NaN ignored
		local st = s.stats
		T.eq(st.sales, 17)
		T.eq(st.tips, 3)
		T.eq(st.orders, 2)
		T.eq(st.rushOrders, 1)
		T.eq(st.happy, 1)
		T.eq(st.angry, 1)
		T.eq(st.cleaned, 1)
		T.eq(st.pizzas, 1)
		T.eq(st.kebabs, 1)
		T.eq(st.drinks, 2)
	end,

	["grade comes from the share of happy customers"] = function()
		T.eq(DayCycle.grade(shiftWith({ orders = 10, happy = 10 }).stats), "S")
		T.eq(DayCycle.grade(shiftWith({ orders = 9, happy = 8, angry = 1 }).stats), "A") -- 0.8
		T.eq(DayCycle.grade(shiftWith({ orders = 10, happy = 6 }).stats), "B")
		T.eq(DayCycle.grade(shiftWith({ orders = 10, happy = 4 }).stats), "C")
		T.eq(DayCycle.grade(shiftWith({ orders = 2, happy = 0, angry = 5 }).stats), "D")
		T.eq(DayCycle.happyShare(DayCycle.newStats()), 0)
	end,

	["finish: bonus, full-day multiplier and rating factor"] = function()
		local b = C.Bonus
		local stats = { orders = 10, happy = 6, rushOrders = 4, sales = 150, tips = 20 }
		local early = DayCycle.finish(shiftWith(stats, false), DayCycle.reconcileRecords(nil), b.RatingPivot, nil)
		local expected = 10 * b.CashPerOrder + 6 * b.CashPerHappy + 4 * b.CashPerRushOrder
		T.near(early.bonusCash, expected, 0.001)
		T.eq(early.bonusXP, 10 * b.XPPerOrder)
		T.ok(not early.fullDay)
		local full = DayCycle.finish(shiftWith(stats, true), DayCycle.reconcileRecords(nil), b.RatingPivot, nil)
		T.near(full.bonusCash, expected * b.FullDayMultiplier, 0.01)
		T.eq(full.bonusXP, math.floor(10 * b.XPPerOrder * b.FullDayMultiplier))
		T.ok(full.fullDay)
		-- rating factor is clamped
		T.eq(DayCycle.ratingFactor(0), b.RatingFactorMin)
		T.eq(DayCycle.ratingFactor(100), b.RatingFactorMax)
		local low = DayCycle.finish(shiftWith(stats, false), DayCycle.reconcileRecords(nil), 1, nil)
		T.near(low.bonusCash, expected * b.RatingFactorMin, 0.01)
		-- summary keeps a copy of the stats, not the live table
		T.eq(full.stats.orders, 10)
	end,

	["wages are charged per staff role and come off the bonus"] = function()
		T.eq(DayCycle.wages(nil), 0)
		T.eq(DayCycle.wages({}), 0)
		T.eq(DayCycle.wages({ cashier = 1, cleaner = 2, wizard = 5 }), C.Wages.cashier + 2 * C.Wages.cleaner)
		T.eq(DayCycle.wages({ cashier = -1 }), 0)
		local s = DayCycle.finish(shiftWith({ orders = 1 }, false), DayCycle.reconcileRecords(nil), C.Bonus.RatingPivot, { cashier = 1 })
		T.eq(s.wages, C.Wages.cashier)
		T.near(s.net, s.bonusCash - C.Wages.cashier, 0.001)
	end,

	["records count days and flag new bests after the first day"] = function()
		local r = DayCycle.reconcileRecords({ days = "x" })
		T.eq(r.days, 0)
		local d1 = DayCycle.finish(shiftWith({ orders = 5, sales = 60 }), r, 4, nil)
		T.eq(r.days, 1)
		T.ok(not d1.bestSales and not d1.bestOrders, "day 1 is not a 'new best'")
		local d2 = DayCycle.finish(shiftWith({ orders = 4, sales = 80 }), r, 4, nil)
		T.ok(d2.bestSales, "more sales than before")
		T.ok(not d2.bestOrders, "fewer orders than before")
		T.eq(r.bestSales, 80)
		T.eq(r.bestOrders, 5)
		T.eq(r.days, 2)
	end,

	["a day only counts once someone was served"] = function()
		T.ok(not DayCycle.counts(DayCycle.newShift(1, 0, 4)))
		T.ok(DayCycle.counts(shiftWith({ orders = 1 })))
	end,
}
