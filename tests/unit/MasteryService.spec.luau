-- MasteryService against fake services: serve_recipe events count, tiers pay
-- once, bonus XP applies, other events and bad ids are ignored, state totals.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Mastery = Loader.module("Shared/Mastery/Mastery")
local Recipes = Loader.module("Shared/Config/Recipes")

local function setup(savedMastery: any?)
	local M = Loader.module("Server/Services/MasteryService")
	local player = { UserId = 9, Name = "Tester" }
	local profile = { money = 0, xp = 0, level = 1, mastery = savedMastery }
	local log = { money = 0, xp = 0, notes = {}, sounds = {}, listener = nil :: any, provider = nil :: any }
	local S = {
		DataService = {
			get = function(p)
				return if p == player then profile else nil
			end,
		},
		ProgressService = {
			addMoney = function(_, n)
				log.money += n
			end,
			addXP = function(_, n)
				log.xp += n
			end,
			notify = function(_, text)
				table.insert(log.notes, text)
			end,
			sound = function(_, name)
				table.insert(log.sounds, name)
			end,
			push = function() end,
			addStateProvider = function(fn)
				log.provider = fn
			end,
		},
		GoalService = {
			onEvent = function(fn)
				log.listener = fn
			end,
		},
	}
	M.init(S)
	return M, player, profile, log
end

local pizza = Recipes.get("cheese_pizza")

return {
	["start listens to the event feed and adds state"] = function()
		local M, _, _, log = setup()
		M.start()
		T.ok(log.listener == M.record)
		T.ok(log.provider == M.stateFor)
	end,

	["serves count and reaching bronze pays once"] = function()
		local M, player, profile, log = setup()
		local need = Mastery.thresholds(pizza)[1]
		for _ = 1, need - 1 do
			M.record(player, "serve_recipe", 1, "cheese_pizza")
		end
		T.eq(profile.mastery.cheese_pizza, need - 1)
		T.eq(log.money, 0)
		T.eq(#log.notes, 0)
		M.record(player, "serve_recipe", 1, "cheese_pizza")
		local reward = Mastery.reward(pizza, 1)
		T.eq(log.money, reward.cash)
		T.eq(log.xp, reward.xp)
		T.eq(#log.notes, 1)
		T.ok(string.find(log.notes[1], "Bronze mastery: Cheese Pizza", 1, true), log.notes[1])
		T.eq(log.sounds[1], "LevelUp")
		-- the next serve earns the bronze bonus XP and no second reward
		M.record(player, "serve_recipe", 1, "cheese_pizza")
		T.eq(log.money, reward.cash)
		T.eq(log.xp, reward.xp + Mastery.serveBonusXP(pizza, 1))
		T.eq(#log.notes, 1)
	end,

	["a big jump pays every tier crossed"] = function()
		local M, player, _, log = setup()
		M.addServes(player, "cheese_pizza", Mastery.thresholds(pizza)[3])
		local expected = 0
		for tier = 1, 3 do
			expected += Mastery.reward(pizza, tier).cash
		end
		T.near(log.money, expected, 0.001)
		T.eq(#log.notes, 3)
	end,

	["other events and unknown recipes are ignored"] = function()
		local M, player, profile, log = setup()
		M.record(player, "order", 1)
		M.record(player, "serve_kind", 1, "pizza")
		M.record(player, "serve_recipe", 1, "ghost_pizza")
		M.record(player, "serve_recipe", 1, nil)
		T.eq(next(profile.mastery or {}), nil)
		T.eq(log.money + log.xp, 0)
		M.record({ UserId = 1 }, "serve_recipe", 1, "cheese_pizza") -- no profile
	end,

	["saved counts are cleaned once and kept"] = function()
		local M, player, profile = setup({ cheese_pizza = 3, ghost = 50, cola = "x" })
		M.record(player, "serve_recipe", 1, "cheese_pizza")
		T.eq(profile.mastery.cheese_pizza, 4)
		T.eq(profile.mastery.ghost, nil)
		T.eq(profile.mastery.cola, nil)
	end,

	["stateFor sends counts and star totals"] = function()
		local M, player = setup({ cheese_pizza = Mastery.thresholds(pizza)[2] })
		local st = M.stateFor(player)
		T.eq(st.mastery.cheese_pizza, Mastery.thresholds(pizza)[2])
		T.eq(st.masteryStars, 2)
		T.eq(st.masteryMax, #Recipes.List * Mastery.MaxTier)
		T.eq(next(M.stateFor({ UserId = 1 })), nil)
	end,
}
