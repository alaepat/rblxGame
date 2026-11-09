--!strict
-- Staff tuning (TASKS #11). Rules: Shared/Staff/StaffRules. Server: StaffService.
--
-- Staff are hired as upgrades (Config/Upgrades entries with `staff = <role>`),
-- and their daily wages are in Config/DayCycle.Wages (paid at the end of each day).

return {
	Roles = {
		cashier = {
			name = "Cashier",
			icon = "🧾",
			-- seconds a customer waits at the register before the cashier takes
			-- the order (so a player at the register still gets there first)
			orderDelay = 4,
			shirt = Color3.fromRGB(214, 40, 40),
		},
		cleaner = {
			name = "Cleaner",
			icon = "🧹",
			cleanTime = 2.5, -- seconds spent cleaning one mess
			walkSpeed = 12,
			-- give up walking to a spot after this long and step straight there
			-- (in case pathfinding can't find a way round the furniture)
			walkTimeout = 10,
			shirt = Color3.fromRGB(40, 130, 230),
		},
	},
}
