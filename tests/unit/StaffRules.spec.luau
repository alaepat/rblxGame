-- Pure staff rules plus the hire upgrades in config: who is hired, the
-- cashier's wait-then-take rule, nearest job, and wages wired to DayCycle.

local roblox = require("@lune/roblox")
local Loader = require("../lib/Loader")
local T = require("../lib/T")

local StaffRules = Loader.module("Shared/Staff/StaffRules")
local Upgrades = Loader.module("Shared/Config/Upgrades")
local DayCycle = Loader.module("Shared/Shift/DayCycle")
local Vector3 = roblox.Vector3

return {
	["every role has a hire upgrade in the Staff category with its wage in the text"] = function()
		for role in StaffRules.Config.Roles do
			local u = StaffRules.upgradeFor(role)
			T.ok(u, "upgrade for " .. role)
			T.eq(u.category, "Staff")
			T.ok(table.find(Upgrades.Categories, "Staff"), "Staff category listed")
			local wage = DayCycle.Config.Wages[role]
			T.ok(wage and wage > 0, role .. " has a wage")
			T.ok(string.find(u.description, ("$%d a day"):format(wage), 1, true), u.id .. " description shows the wage")
		end
		T.eq(StaffRules.upgradeFor("wizard"), nil)
	end,

	["hired counts only owned staff upgrades"] = function()
		T.eq(next(StaffRules.hired(nil)), nil)
		T.eq(next(StaffRules.hired({ oven_2 = true, seating_1 = true })), nil, "normal upgrades aren't staff")
		local h = StaffRules.hired({ hire_cleaner = true, hire_cashier = true, oven_2 = true })
		T.eq(h.cleaner, 1)
		T.eq(h.cashier, 1)
		T.eq(StaffRules.hired({ hire_cleaner = false }).cleaner, nil, "false isn't owned")
	end,

	["wages for hired staff come from DayCycle"] = function()
		local h = StaffRules.hired({ hire_cleaner = true, hire_cashier = true })
		T.eq(DayCycle.wages(h), DayCycle.Config.Wages.cleaner + DayCycle.Config.Wages.cashier)
	end,

	["cashier waits orderDelay for the same customer, then takes the order"] = function()
		local memo = { customer = nil, since = 0 }
		local a, b = { name = "A" }, { name = "B" }
		T.eq(StaffRules.cashierStep(memo, a, nil, 10, 4), false, "just arrived")
		T.eq(StaffRules.cashierStep(memo, a, nil, 13.9, 4), false, "not long enough")
		T.eq(StaffRules.cashierStep(memo, a, nil, 14, 4), true, "waited 4 s")
		-- a different customer restarts the wait
		T.eq(StaffRules.cashierStep(memo, b, nil, 15, 4), false)
		T.eq(memo.customer, b)
		T.eq(memo.since, 15)
	end,

	["cashier never takes a customer a player is serving, or nobody"] = function()
		local memo = { customer = nil, since = 0 }
		local a = { name = "A" }
		StaffRules.cashierStep(memo, a, nil, 0, 4)
		T.eq(StaffRules.cashierStep(memo, a, a, 100, 4), false, "player has the POS open for them")
		T.eq(memo.customer, nil, "wait resets")
		T.eq(StaffRules.cashierStep(memo, a, nil, 101, 4), false, "starts waiting again")
		T.eq(StaffRules.cashierStep(memo, nil, nil, 200, 4), false, "nobody at the register")
		T.eq(memo.customer, nil)
	end,

	["nearest picks the closest job"] = function()
		local jobs = {
			{ id = 1, position = Vector3.new(10, 0, 0) },
			{ id = 2, position = Vector3.new(2, 0, 1) },
			{ id = 3, position = Vector3.new(-5, 0, 0) },
		}
		T.eq(StaffRules.nearest(jobs, Vector3.new(0, 0, 0)).id, 2)
		T.eq(StaffRules.nearest(jobs, Vector3.new(-6, 0, 0)).id, 3)
		T.eq(StaffRules.nearest({}, Vector3.new(0, 0, 0)), nil)
	end,
}
