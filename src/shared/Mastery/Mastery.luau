--!strict
-- Pure menu-mastery rules (no services, so it runs in Lune tests).
-- Numbers live in Config/Mastery; recipes in Config/Recipes. Server: MasteryService.
--
-- Saved data is just serve counts per recipe id: profile.mastery = { [id] = n }.
-- Tiers are worked out from the counts, so there's nothing else to keep in sync.

local Config = require(script.Parent.Parent.Config.Mastery)
local Recipes = require(script.Parent.Parent.Config.Recipes)

local Mastery = {}
Mastery.Config = Config
Mastery.MaxTier = #Config.Tiers

export type Counts = { [string]: number }
export type Reward = { cash: number, xp: number }
export type View = {
	tier: number, -- 0..MaxTier
	count: number,
	prevAt: number, -- serves where the current tier started
	nextAt: number?, -- serves for the next tier (nil at max)
	progress: number, -- 0..1 toward the next tier (1 at max)
}

-- Serves needed for each tier of this recipe.
function Mastery.thresholds(recipe: any): { number }
	local mult = (Config.KindMultiplier :: any)[recipe.kind] or 1
	local out = {}
	for i, t in Config.Tiers do
		out[i] = t.serves * mult
	end
	return out
end

function Mastery.tierFor(recipe: any, count: number): number
	local tier = 0
	for i, need in Mastery.thresholds(recipe) do
		if count >= need then
			tier = i
		end
	end
	return tier
end

function Mastery.reward(recipe: any, tier: number): Reward
	local t = Config.Tiers[tier]
	if not t then
		return { cash = 0, xp = 0 }
	end
	return {
		cash = math.floor(recipe.price * t.rewardPrice * 100 + 0.5) / 100,
		xp = math.floor(recipe.xp * t.rewardXP),
	}
end

-- Extra XP for one serve of a recipe at this tier.
function Mastery.serveBonusXP(recipe: any, tier: number): number
	local t = Config.Tiers[tier]
	if not t then
		return 0
	end
	return math.floor(recipe.xp * t.serveXPBonus)
end

-- Keeps only sane entries (known recipe ids, whole non-negative numbers).
function Mastery.reconcile(counts: any): Counts
	local out: Counts = {}
	if type(counts) ~= "table" then
		return out
	end
	for id, n in counts do
		if type(id) == "string" and Recipes.get(id) and type(n) == "number" and n == n and n > 0 then
			out[id] = math.floor(n)
		end
	end
	return out
end

-- Counts `amount` serves of `recipeId`. Returns the tier before, the tier
-- after, and the bonus XP earned by these serves (at the tier they were made at).
-- Unknown recipes or bad amounts change nothing.
function Mastery.record(counts: Counts, recipeId: any, amount: number?): (number, number, number)
	local recipe = type(recipeId) == "string" and Recipes.get(recipeId)
	local n = amount or 1
	if not recipe or n ~= n or n <= 0 then
		return 0, 0, 0
	end
	n = math.floor(n)
	local before = counts[recipeId] or 0
	local oldTier = Mastery.tierFor(recipe, before)
	counts[recipeId] = before + n
	local newTier = Mastery.tierFor(recipe, before + n)
	return oldTier, newTier, Mastery.serveBonusXP(recipe, oldTier) * n
end

function Mastery.view(recipe: any, count: number?): View
	local c = count or 0
	local th = Mastery.thresholds(recipe)
	local tier = Mastery.tierFor(recipe, c)
	local prevAt = if tier > 0 then th[tier] else 0
	local nextAt = th[tier + 1]
	local progress = 1
	if nextAt then
		progress = math.clamp((c - prevAt) / (nextAt - prevAt), 0, 1)
	end
	return { tier = tier, count = c, prevAt = prevAt, nextAt = nextAt, progress = progress }
end

-- Stars for a tier as RichText: earned ones gold, the rest grey. (Only "★" is
-- used: the Gotham fonts have no "☆", like the missing "✕" on the goals panel.)
function Mastery.stars(tier: number): string
	local t = math.clamp(tier, 0, Mastery.MaxTier)
	local s = ""
	if t > 0 then
		s ..= '<font color="#F5B400">' .. string.rep("★", t) .. "</font>"
	end
	if t < Mastery.MaxTier then
		s ..= '<font color="#D2C8BC">' .. string.rep("★", Mastery.MaxTier - t) .. "</font>"
	end
	return s
end

-- Total tiers earned across the menu, and the most possible.
function Mastery.totalStars(counts: Counts): (number, number)
	local total = 0
	for _, r in Recipes.List do
		total += Mastery.tierFor(r, counts[r.id] or 0)
	end
	return total, #Recipes.List * Mastery.MaxTier
end

return Mastery
