--!strict
-- Menu mastery (TASKS #16), server authoritative.
--  * Counts every served recipe (the "serve_recipe" event from GoalService.record,
--    received through GoalService.onEvent) in profile.mastery = { [recipeId] = n }.
--  * Reaching a tier (bronze / silver / gold) pays a one-off cash + XP reward.
--  * Each tier also adds bonus XP to every later serve of that recipe.
--  * Adds `mastery` (the counts) and the star totals to the State snapshot.
--  * Rules live in Shared.Mastery.Mastery, numbers in Config/Mastery.
--  * The first serve of each recipe in a goals day sends "serve_variety" to
--    GoalService (daily goal "Serve N different recipes"). The recipes seen
--    today are kept in profile.masteryDay = { day, seen = { [id] = true } }.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Mastery = require(Shared.Mastery.Mastery)
local Recipes = require(Shared.Config.Recipes)
local DailyGoals = require(Shared.Goals.DailyGoals)

local MasteryService = {}
local S: any

function MasteryService.init(services)
	S = services
end

-- Profiles whose saved counts were already cleaned this session (not saved).
local reconciled: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function countsOf(player: Player): Mastery.Counts?
	local profile = S.DataService.get(player)
	if not profile then
		return nil
	end
	if type(profile.mastery) ~= "table" or not reconciled[profile] then
		profile.mastery = Mastery.reconcile(profile.mastery)
		reconciled[profile] = true
	end
	return profile.mastery
end

-- Counts serves of a recipe and pays bonus XP and tier rewards.
function MasteryService.addServes(player: Player, recipeId: string, amount: number?)
	local counts = countsOf(player)
	local recipe = Recipes.get(recipeId)
	if not counts or not recipe then
		return
	end
	local oldTier, newTier, bonusXP = Mastery.record(counts, recipeId, amount)
	if bonusXP > 0 then
		S.ProgressService.addXP(player, bonusXP)
	end
	for tier = oldTier + 1, newTier do
		local t = Mastery.Config.Tiers[tier]
		local reward = Mastery.reward(recipe, tier)
		if reward.cash > 0 then
			S.ProgressService.addMoney(player, reward.cash, "mastery")
		end
		if reward.xp > 0 then
			S.ProgressService.addXP(player, reward.xp)
		end
		S.ProgressService.notify(
			player,
			("%s %s mastery: %s! +$%d, +%d XP"):format(t.icon, t.name, recipe.name, math.floor(reward.cash), reward.xp),
			"good"
		)
		S.ProgressService.sound(player, "LevelUp")
	end
	S.ProgressService.push(player)
end

-- First serve of a recipe today -> "serve_variety" goal event.
local function noteVariety(player: Player, recipeId: string)
	local profile = S.DataService.get(player)
	if not profile or not Recipes.get(recipeId) or not (S.GoalService and S.GoalService.record) then
		return
	end
	local today = DailyGoals.dayNumber(os.time())
	local md = profile.masteryDay
	if type(md) ~= "table" or md.day ~= today or type(md.seen) ~= "table" then
		md = { day = today, seen = {} }
		profile.masteryDay = md
	end
	if not md.seen[recipeId] then
		md.seen[recipeId] = true
		S.GoalService.record(player, "serve_variety", 1, recipeId)
	end
end

-- Fed by GoalService.onEvent with every recorded game event.
function MasteryService.record(player: Player, event: string, amount: number?, param: string?)
	if event == "serve_recipe" and type(param) == "string" then
		MasteryService.addServes(player, param, amount)
		noteVariety(player, param)
	end
end

-- Snapshot fields for the Recipes and Business tabs (Controllers/Manager).
function MasteryService.stateFor(player: Player): { [string]: any }
	local counts = countsOf(player)
	if not counts then
		return {}
	end
	local stars, maxStars = Mastery.totalStars(counts)
	return { mastery = counts, masteryStars = stars, masteryMax = maxStars }
end

function MasteryService.start()
	S.GoalService.onEvent(MasteryService.record)
	S.ProgressService.addStateProvider(MasteryService.stateFor)
end

return MasteryService
