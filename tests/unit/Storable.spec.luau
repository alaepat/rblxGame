-- DataStore-safety check for saved profiles (TASKS #14).

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Storable = Loader.module("Shared/Data/Storable")

local function has(list: { string }, needle: string): boolean
	for _, s in list do
		if string.find(s, needle, 1, true) then
			return true
		end
	end
	return false
end

return {
	["a normal profile shape is fine"] = function()
		local p = {
			money = 120.5,
			stock = { dough = 10 },
			unlockedRecipes = { "cheese_pizza", "cola" },
			mastery = { cheese_pizza = 3 },
			daily = { day = 20400, goals = { { id = "serve", progress = 0, claimed = false } }, weekly = { goal = { id = "x" } } },
			masteryDay = { day = 20400, seen = { cola = true } },
			upgrades = {},
		}
		T.eq(#Storable.problems(p), 0)
		T.ok(Storable.ok(p))
	end,

	["NaN and infinity are caught"] = function()
		local out = Storable.problems({ money = 0 / 0, xp = math.huge })
		T.ok(has(out, "profile.money: NaN"))
		T.ok(has(out, "profile.xp: infinite"))
	end,

	["number keys in a dictionary and sparse arrays are caught"] = function()
		T.ok(has(Storable.problems({ a = { [1] = 1, x = 2 } }), "not a string"))
		T.ok(has(Storable.problems({ a = { [1] = 1, [3] = 3 } }), "sparse"))
	end,

	["functions and cycles are caught; shared tables are fine"] = function()
		T.ok(has(Storable.problems({ f = function() end }), "profile.f: can't save a function"))
		local loop = {}
		loop.self = loop
		T.ok(has(Storable.problems(loop), "cycle"))
		local shared = { 1 }
		T.ok(Storable.ok({ a = shared, b = shared }))
	end,
}
