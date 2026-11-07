--!strict
-- "Before you open" checklist (TASKS #19). Pure: ShiftService feeds it the
-- player's stock, level, upgrades, cleanliness and how many ovens / fryers
-- still have food inside; the day clock shows the result while the
-- restaurant is closed. It's a reminder only: you can always open anyway.

local Shared = script.Parent.Parent
local Ingredients = require(Shared.Config.Ingredients)
local Recipes = require(Shared.Config.Recipes)
local FoodLogic = require(Shared.Food.FoodLogic)

local Checklist = {}

-- Packaging / bases every recipe of a kind uses (not named in the recipe itself).
local PACKAGING: { [string]: { string } } = {
	pizza = { "dough", "pizza_box" },
	kebab = { "kebab_wrapper" },
	drink = { "cup" },
	dessert = { "dessert_cup" },
}

export type Input = {
	stock: { [string]: number },
	level: number,
	upgrades: { [string]: boolean },
	cleanliness: number, -- 0..100
	cookersBusy: number, -- ovens / fryers with food still inside
}

export type Item = { id: string, ok: boolean, text: string }

local function addId(set: { [string]: boolean }, list: { string }, id: any)
	if type(id) == "string" and not set[id] and Ingredients.get(id) then
		set[id] = true
		table.insert(list, id)
	end
end

-- Every ingredient the unlocked menu needs, in menu order.
function Checklist.neededIngredients(level: number, upgrades: { [string]: boolean }): { string }
	local set, list = {}, {}
	for _, rid in FoodLogic.unlockedRecipes(level, upgrades) do
		local r = Recipes.get(rid) :: any
		if r then
			for _, id in PACKAGING[r.kind] or {} do
				addId(set, list, id)
			end
			for k, v in r do
				if k ~= "id" and k ~= "requires" then
					if type(v) == "table" then
						for _, id in v do
							addId(set, list, id)
						end
					else
						addId(set, list, v)
					end
				end
			end
		end
	end
	return list
end

function Checklist.missingStock(input: Input): { string }
	local out = {}
	for _, id in Checklist.neededIngredients(input.level, input.upgrades) do
		if (input.stock[id] or 0) <= 0 then
			table.insert(out, id)
		end
	end
	return out
end

local function nameList(ids: { string }, max: number): string
	local names = {}
	for i = 1, math.min(#ids, max) do
		local ing = Ingredients.get(ids[i])
		table.insert(names, ing and ing.name or ids[i])
	end
	local s = table.concat(names, ", ")
	if #ids > max then
		s ..= (" +%d more"):format(#ids - max)
	end
	return s
end

function Checklist.build(input: Input): { items: { Item }, ready: boolean }
	local missing = Checklist.missingStock(input)
	local clean = math.floor(input.cleanliness + 0.5)
	local items: { Item } = {
		{
			id = "stock",
			ok = #missing == 0,
			text = if #missing == 0 then "📦 Stock: everything on the menu is in stock" else "📦 Out of: " .. nameList(missing, 3),
		},
		{
			id = "clean",
			ok = clean >= 100,
			text = if clean >= 100 then "🧽 Clean: spotless" else ("🧽 Clean up first: %d%% clean"):format(clean),
		},
		{
			id = "ovens",
			ok = input.cookersBusy <= 0,
			text = if input.cookersBusy <= 0
				then "🔥 Ovens and fryers: empty and ready"
				else ("🔥 Ovens and fryers: take out %d leftover item%s"):format(input.cookersBusy, if input.cookersBusy == 1 then "" else "s"),
		},
	}
	local ready = true
	for _, it in items do
		ready = ready and it.ok
	end
	return { items = items, ready = ready }
end

return Checklist
