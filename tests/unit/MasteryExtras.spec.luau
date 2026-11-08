-- Mastery extras (TASKS #21): gold price bonus, the "different recipes" daily
-- goal (serve_variety) and its once-per-recipe-per-day event.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Mastery = Loader.module("Shared/Mastery/Mastery")
local Recipes = Loader.module("Shared/Config/Recipes")
local Challenges = Loader.module("Shared/Config/Challenges")
local DailyGoals = Loader.module("Shared/Goals/DailyGoals")

local function setupService()
	local M = Loader.module("Server/Services/MasteryService")
	local player = { UserId = 9, Name = "Tester" }
	local profile = { money = 0, xp = 0, level = 1 }
	local events = {}
	M.init({
		DataService = {
			get = function(p)
				return if p == player then profile else nil
			end,
		},
		ProgressService = {
			addMoney = function() end,
			addXP = function() end,
			notify = function() end,
			sound = function() end,
			push = function() end,
			addStateProvider = function() end,
		},
		GoalService = {
			onEvent = function() end,
			record = function(_, event, amount, param)
				table.insert(events, { event = event, amount = amount, param = param })
			end,
		},
	})
	return M, player, profile, events
end

return {
	["only gold adds to the price, rounded to cents"] = function()
		local r = Recipes.get("cheese_pizza")
		local th = Mastery.thresholds(r)
		T.eq(Mastery.priceFor(r, 0), r.price)
		T.eq(Mastery.priceFor(r, th[1]), r.price, "bronze changed the price")
		T.eq(Mastery.priceFor(r, th[2]), r.price, "silver changed the price")
		local gold = Mastery.priceFor(r, th[Mastery.MaxTier])
		T.eq(gold, math.floor(r.price * (1 + Mastery.priceBonus(Mastery.MaxTier)) * 100 + 0.5) / 100)
		T.ok(gold > r.price, "gold gave no bonus")
		T.eq(Mastery.priceBonus(0), 0)
		T.eq(Mastery.priceBonus(99), 0)
	end,

	["variety goal only rolls when the menu has more recipes than the target"] = function()
		local t = Challenges.ById.variety
		T.ok(t, "no variety template")
		T.eq(t.event, "serve_variety")
		-- level 1 has too few recipes: never rolled across many days
		for day = 1, 40 do
			for _, g in DailyGoals.generate(day, 77, 1, {}) do
				T.ok(g.id ~= "variety", "variety goal at level 1")
			end
		end
		-- at a higher level it can roll
		local seen = false
		for day = 1, 200 do
			for _, g in DailyGoals.generate(day, 77, 10, {}) do
				seen = seen or g.id == "variety"
			end
		end
		T.ok(seen, "variety goal never rolled at level 10")
	end,

	["first serve of each recipe per day sends serve_variety once"] = function()
		local M, player, profile, events = setupService()
		M.record(player, "serve_recipe", 1, "cheese_pizza")
		M.record(player, "serve_recipe", 1, "cheese_pizza")
		M.record(player, "serve_recipe", 1, "cola")
		M.record(player, "serve_recipe", 1, "not_a_recipe")
		M.record(player, "order", 1)
		T.eq(#events, 2)
		T.eq(events[1].event, "serve_variety")
		T.eq(events[1].param, "cheese_pizza")
		T.eq(events[2].param, "cola")
		-- a new day starts over
		profile.masteryDay.day -= 1
		M.record(player, "serve_recipe", 1, "cheese_pizza")
		T.eq(#events, 3)
	end,
}
