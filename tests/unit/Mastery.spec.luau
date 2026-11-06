-- Pure menu-mastery rules: thresholds, tiers, rewards, serve bonus, views,
-- star totals and cleaning saved data.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Mastery = Loader.module("Shared/Mastery/Mastery")
local Recipes = Loader.module("Shared/Config/Recipes")
local C = Mastery.Config

local pizza = Recipes.get("cheese_pizza")
local drink = Recipes.get("cola")

return {
	["config tiers rise in serves and rewards"] = function()
		T.ok(#C.Tiers >= 3, "bronze, silver, gold")
		for i = 2, #C.Tiers do
			local a, b = C.Tiers[i - 1], C.Tiers[i]
			T.ok(b.serves > a.serves, b.id .. " needs more serves")
			T.ok(b.rewardPrice >= a.rewardPrice and b.rewardXP >= a.rewardXP, b.id .. " pays at least as much")
			T.ok(b.serveXPBonus > a.serveXPBonus, b.id .. " bonus grows")
		end
	end,

	["thresholds are per kind (drinks need more)"] = function()
		local p = Mastery.thresholds(pizza)
		local d = Mastery.thresholds(drink)
		T.eq(p[1], C.Tiers[1].serves)
		T.eq(d[1], C.Tiers[1].serves * C.KindMultiplier.drink)
		T.eq(#p, Mastery.MaxTier)
	end,

	["tierFor counts whole tiers only"] = function()
		local th = Mastery.thresholds(pizza)
		T.eq(Mastery.tierFor(pizza, 0), 0)
		T.eq(Mastery.tierFor(pizza, th[1] - 1), 0)
		T.eq(Mastery.tierFor(pizza, th[1]), 1)
		T.eq(Mastery.tierFor(pizza, th[3] - 1), 2)
		T.eq(Mastery.tierFor(pizza, th[3] + 500), 3)
	end,

	["record counts serves and reports tier changes and bonus XP"] = function()
		local counts = {}
		local th = Mastery.thresholds(pizza)
		local old, new, bonus = Mastery.record(counts, "cheese_pizza", th[1] - 1)
		T.eq(old, 0)
		T.eq(new, 0)
		T.eq(bonus, 0, "no bonus before bronze")
		old, new, bonus = Mastery.record(counts, "cheese_pizza", 1)
		T.eq(old, 0)
		T.eq(new, 1, "reached bronze")
		T.eq(bonus, 0, "the serve that reaches bronze was made at tier 0")
		old, new, bonus = Mastery.record(counts, "cheese_pizza", 1)
		T.eq(bonus, Mastery.serveBonusXP(pizza, 1), "later serves earn the bronze bonus")
		-- one big jump can cross several tiers
		old, new = Mastery.record(counts, "cheese_pizza", 1000)
		T.eq(old, 1)
		T.eq(new, 3)
		T.eq(counts.cheese_pizza, th[1] + 1 + 1000)
	end,

	["record ignores unknown recipes and bad amounts"] = function()
		local counts = {}
		Mastery.record(counts, "not_a_recipe", 5)
		Mastery.record(counts, 42, 5)
		Mastery.record(counts, "cheese_pizza", -3)
		Mastery.record(counts, "cheese_pizza", 0 / 0)
		T.eq(next(counts), nil)
		Mastery.record(counts, "cheese_pizza", 2.7)
		T.eq(counts.cheese_pizza, 2, "whole serves only")
	end,

	["rewards scale with the recipe and the tier"] = function()
		local r1 = Mastery.reward(pizza, 1)
		T.eq(r1.cash, pizza.price * C.Tiers[1].rewardPrice)
		T.eq(r1.xp, math.floor(pizza.xp * C.Tiers[1].rewardXP))
		local r3 = Mastery.reward(pizza, 3)
		T.ok(r3.cash > r1.cash and r3.xp > r1.xp)
		local none = Mastery.reward(pizza, 0)
		T.eq(none.cash, 0)
		T.eq(none.xp, 0)
		T.eq(Mastery.serveBonusXP(pizza, 0), 0)
		T.eq(Mastery.serveBonusXP(pizza, 3), math.floor(pizza.xp * C.Tiers[3].serveXPBonus))
	end,

	["view gives progress toward the next tier"] = function()
		local th = Mastery.thresholds(pizza)
		local v = Mastery.view(pizza, nil)
		T.eq(v.tier, 0)
		T.eq(v.nextAt, th[1])
		T.eq(v.progress, 0)
		v = Mastery.view(pizza, th[1] + (th[2] - th[1]) / 2)
		T.eq(v.tier, 1)
		T.eq(v.prevAt, th[1])
		T.eq(v.nextAt, th[2])
		T.near(v.progress, 0.5, 1e-9)
		v = Mastery.view(pizza, th[3])
		T.eq(v.tier, 3)
		T.eq(v.nextAt, nil)
		T.eq(v.progress, 1)
	end,

	["stars use only the filled glyph, coloured by RichText"] = function()
		T.ok(not string.find(Mastery.stars(1), "☆", 1, true), "no hollow star glyph")
		local _, filled = string.gsub(Mastery.stars(2), "★", "")
		T.eq(filled, Mastery.MaxTier)
		T.ok(string.find(Mastery.stars(0), "F5B400", 1, true) == nil, "no gold at tier 0")
		T.ok(string.find(Mastery.stars(3), "D2C8BC", 1, true) == nil, "no grey at max")
	end,

	["totalStars sums tiers across the menu"] = function()
		local th = Mastery.thresholds(pizza)
		local total, max = Mastery.totalStars({ cheese_pizza = th[2], cola = 1 })
		T.eq(total, 2)
		T.eq(max, #Recipes.List * Mastery.MaxTier)
	end,

	["reconcile keeps only known recipes with positive whole counts"] = function()
		local r = Mastery.reconcile({ cheese_pizza = 4.9, cola = -1, ghost = 9, tomato_pizza = "x", [5] = 3, ham_pizza = 0 / 0 })
		T.eq(r.cheese_pizza, 4)
		T.eq(r.cola, nil)
		T.eq(r.ghost, nil)
		T.eq(r.tomato_pizza, nil)
		T.eq(r.ham_pizza, nil)
		T.eq(next(Mastery.reconcile(nil)), nil)
	end,
}
