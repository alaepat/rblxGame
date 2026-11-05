--!strict
-- Day / shift cycle tuning (TASKS #7). Rules: Shared/Shift/DayCycle.
--
-- Each restaurant runs its own day: flipping the sign to OPEN starts a shift at
-- OpenHour, the in-game clock runs SecondsPerHour real seconds per game hour,
-- and at CloseHour the restaurant closes itself. When the last customers have
-- left (or ClosingGrace runs out) the day ends with a summary and a bonus.

return {
	OpenHour = 10, -- the clock reads 10:00 AM when you open
	CloseHour = 22, -- closing time, 10:00 PM
	SecondsPerHour = 40, -- real seconds per game hour: 12 hours = an 8-minute day

	-- Phases cover OpenHour..CloseHour with no gaps (hours may be fractional).
	-- traffic divides the time between customer arrivals (2 = twice as many).
	Phases = {
		{ id = "morning", from = 10, to = 12, label = "Morning", icon = "☀️", traffic = 0.9 },
		{ id = "lunch", from = 12, to = 14, label = "Lunch rush", icon = "🔥", traffic = 1.8, rush = true },
		{ id = "afternoon", from = 14, to = 17.5, label = "Afternoon", icon = "☕", traffic = 0.8 },
		{ id = "dinner", from = 17.5, to = 20, label = "Dinner rush", icon = "🔥", traffic = 2.0, rush = true },
		{ id = "evening", from = 20, to = 21, label = "Evening", icon = "🌆", traffic = 1.0 },
		{ id = "latenight", from = 21, to = 22, label = "Late-night rush", icon = "🌙", traffic = 1.4, rush = true },
	},
	-- During a rush, arrivals can be closer together than GameConfig.MinSpawnInterval.
	RushMinSpawnInterval = 4.5,

	-- Real seconds after closing time to serve the last customers before the
	-- day ends anyway (customers still inside keep their orders).
	ClosingGrace = 90,

	-- End-of-day shift bonus. Cash and XP are multiplied by FullDayMultiplier
	-- when the restaurant stayed open until closing time, and cash by the
	-- rating factor (rating / RatingPivot, clamped to RatingFactorMin..Max).
	Bonus = {
		CashPerOrder = 2,
		CashPerHappy = 1,
		CashPerRushOrder = 1.5,
		XPPerOrder = 3,
		FullDayMultiplier = 1.5,
		RatingPivot = 4,
		RatingFactorMin = 0.5,
		RatingFactorMax = 1.25,
	},

	-- Daily wage per staff role, paid out of the shift bonus at the end of the
	-- day (and out of your money if the bonus doesn't cover it). There are no
	-- staff yet (TASKS #11): ShiftService passes an empty staff list.
	Wages = {
		cashier = 25,
		cleaner = 20,
		cook = 35,
	},

	-- Day grade from the share of customers who left happy (happy / (orders + walk-outs)).
	Grades = {
		{ grade = "S", min = 0.95 },
		{ grade = "A", min = 0.8 },
		{ grade = "B", min = 0.6 },
		{ grade = "C", min = 0.4 },
		{ grade = "D", min = 0 },
	},
}
