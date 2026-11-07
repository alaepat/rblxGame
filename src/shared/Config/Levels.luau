--!strict
-- Level curve and per-level rewards. Unlock lists are derived from the
-- `level` field of Recipes / Ingredients / Upgrades so content only needs
-- to be configured in one place.

local Recipes = require(script.Parent.Recipes)
local Ingredients = require(script.Parent.Ingredients)
local Upgrades = require(script.Parent.Upgrades)

local MAX_LEVEL = 30

local Levels = {}
Levels.MaxLevel = MAX_LEVEL

-- XP needed to go from `level` to `level + 1`.
function Levels.xpToNext(level: number): number
	if level >= MAX_LEVEL then
		return math.huge
	end
	return math.floor(80 + 55 * (level - 1) ^ 1.45)
end

-- Cash bonus awarded on reaching `level`.
function Levels.reward(level: number): number
	return 50 + level * 25
end

-- Extra flavour text for milestone levels.
local milestones: { [number]: string } = {
	[5] = "Kebab Station available in Upgrades",
	[8] = "Chip Fryer available in Upgrades",
	[10] = "Dining Room Extension available",
	[12] = "Planet Special Box unlocked + Dessert Station available in Upgrades",
	[13] = "Late-game menu: new pizzas and sides keep coming every level",
	[15] = "Hotter Oven III available",
	[19] = "Galaxy Pizza: every topping on one pizza",
	[20] = "Planet Mega Box: the biggest order in the galaxy",
}

export type Unlocks = { recipes: { string }, ingredients: { string }, upgrades: { string }, note: string? }

function Levels.unlocksAt(level: number): Unlocks
	local result: Unlocks = { recipes = {}, ingredients = {}, upgrades = {}, note = milestones[level] }
	for _, r in Recipes.List do
		if r.level == level then
			table.insert(result.recipes, r.id)
		end
	end
	for _, i in Ingredients.List do
		if i.level == level then
			table.insert(result.ingredients, i.id)
		end
	end
	for _, u in Upgrades.List do
		if u.level == level then
			table.insert(result.upgrades, u.id)
		end
	end
	return result
end

return Levels
