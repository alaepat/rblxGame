--!strict
-- Pure food rules shared by server (authoritative) and client (UI hints).
-- An "item" is a plain table so it can be sent over remotes and saved.
--
--   { kind = "dough" }
--   { kind = "pizza", sauce = id?, toppings = {id}, cook = 0..n, boxed = bool }
--   { kind = "bread", base = "pitta" | "wrap_bread" | "food_box" }
--   { kind = "kebab", base = id, fillings = {id}, wrapped = bool }
--   { kind = "chips", cook = 0..n }
--   { kind = "cup", syrup = id? }
--   { kind = "dessert", flavour = id?, toppings = {id} }
--   { kind = "supply", ingredient = id, amount = n }

local Config = script.Parent.Parent.Config
local Recipes = require(Config.Recipes)
local Ingredients = require(Config.Ingredients)
local GameConfig = require(Config.GameConfig)

-- Board capacity = the biggest recipe of each kind, so new recipes always fit.
local MAX_TOPPINGS, MAX_FILLINGS = 0, 0
for _, r in Recipes.List do
	if r.kind == "pizza" then
		MAX_TOPPINGS = math.max(MAX_TOPPINGS, #(r.toppings :: { string }))
	elseif r.kind == "kebab" then
		MAX_FILLINGS = math.max(MAX_FILLINGS, #(r.fillings :: { string }))
	end
end

export type Item = { [string]: any }

local FoodLogic = {}

local SAUCES = { tomato_sauce = true, bbq_sauce = true }
local KEBAB_SAUCES = { garlic_sauce = true, chilli_sauce = true, mayo = true }
FoodLogic.PizzaSauces = SAUCES
FoodLogic.KebabSauces = KEBAB_SAUCES

local function setEquals(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	local count: { [string]: number } = {}
	for _, v in a do
		count[v] = (count[v] or 0) + 1
	end
	for _, v in b do
		local c = count[v]
		if not c or c == 0 then
			return false
		end
		count[v] = c - 1
	end
	return true
end

local function contains(list: { string }, v: string): boolean
	return table.find(list, v) ~= nil
end

function FoodLogic.cookState(cook: number): string
	if cook <= 0 then
		return "raw"
	elseif cook < 1 then
		return "cooking"
	elseif cook < GameConfig.BurnAt then
		return "cooked"
	end
	return "burnt"
end

function FoodLogic.pizzaCookTime(item: Item): number
	return GameConfig.PizzaBaseCookTime + GameConfig.PizzaCookPerTopping * #(item.toppings or {})
end

-- Can `ingredientId` be added to the pizza sitting on a prep board?
function FoodLogic.canAddToPizza(item: Item, ingredientId: string): (boolean, string?)
	if item.kind ~= "pizza" then
		return false, "Place dough on the board first"
	end
	if (item.cook or 0) > 0 then
		return false, "This pizza has already been cooked"
	end
	if SAUCES[ingredientId] then
		if item.sauce then
			return false, "It already has sauce"
		end
		return true, nil
	end
	if not item.sauce then
		return false, "Add sauce first"
	end
	if contains(item.toppings, ingredientId) then
		return false, "Already added"
	end
	if #item.toppings >= MAX_TOPPINGS then
		return false, "Too many toppings"
	end
	return true, nil
end

function FoodLogic.canAddToKebab(item: Item, ingredientId: string): (boolean, string?)
	if item.kind ~= "kebab" then
		return false, "Place a pitta, wrap or box on the board first"
	end
	if item.wrapped then
		return false, "It's already wrapped"
	end
	if contains(item.fillings, ingredientId) then
		return false, "Already added"
	end
	if ingredientId == "chips" and item.base ~= "food_box" then
		return false, "Chips go in a food box"
	end
	if #item.fillings >= MAX_FILLINGS then
		return false, "It's full"
	end
	return true, nil
end

-- Can a dessert topping go on the held dessert cup?
function FoodLogic.canAddToDessert(item: Item, ingredientId: string): (boolean, string?)
	if item.kind ~= "dessert" then
		return false, "Grab a dessert cup first"
	end
	if not item.flavour then
		return false, "Fill it at the soft-serve machine first"
	end
	if contains(item.toppings, ingredientId) then
		return false, "Already added"
	end
	if #item.toppings >= 4 then
		return false, "It's full"
	end
	return true, nil
end

-- Returns the recipe id this finished item satisfies, or nil.
function FoodLogic.identify(item: Item?): string?
	if not item then
		return nil
	end
	if item.kind == "pizza" then
		if not item.boxed or FoodLogic.cookState(item.cook or 0) ~= "cooked" then
			return nil
		end
		for _, r in Recipes.List do
			if r.kind == "pizza" and r.sauce == item.sauce and setEquals(r.toppings :: { string }, item.toppings) then
				return r.id
			end
		end
	elseif item.kind == "kebab" then
		if not item.wrapped then
			return nil
		end
		for _, r in Recipes.List do
			if r.kind == "kebab" and r.base == item.base and setEquals(r.fillings :: { string }, item.fillings) then
				return r.id
			end
		end
	elseif item.kind == "cup" then
		if not item.syrup then
			return nil
		end
		for _, r in Recipes.List do
			if r.kind == "drink" and r.syrup == item.syrup then
				return r.id
			end
		end
	elseif item.kind == "dessert" then
		if not item.flavour then
			return nil
		end
		for _, r in Recipes.List do
			if r.kind == "dessert" and r.flavour == item.flavour and setEquals(r.toppings :: { string }, item.toppings) then
				return r.id
			end
		end
	end
	return nil
end

-- Is the item finished packaging (even if it matches no recipe)?
function FoodLogic.isPackaged(item: Item?): boolean
	if not item then
		return false
	end
	return (item.kind == "pizza" and item.boxed == true)
		or (item.kind == "kebab" and item.wrapped == true)
		or (item.kind == "cup" and item.syrup ~= nil)
		or (item.kind == "dessert" and item.flavour ~= nil)
end

local function ingName(id: string?): string
	local ing = id and Ingredients.get(id)
	return ing and ing.name or tostring(id)
end

function FoodLogic.describe(item: Item?): string
	if not item then
		return ""
	end
	local k = item.kind
	if k == "dough" then
		return "Pizza dough"
	elseif k == "pizza" then
		local id = FoodLogic.identify(item)
		local state = FoodLogic.cookState(item.cook or 0)
		if item.boxed then
			local r = id and Recipes.get(id)
			return "Boxed " .. (r and r.name or "pizza (doesn't match the menu)")
		end
		local prefix = ({ raw = "Raw", cooking = "Undercooked", cooked = "Cooked", burnt = "Burnt" })[state] or ""
		return prefix .. " pizza (" .. (#item.toppings) .. " toppings)"
	elseif k == "bread" then
		return ingName(item.base)
	elseif k == "kebab" then
		if item.wrapped then
			local id = FoodLogic.identify(item)
			local r = id and Recipes.get(id)
			local verb = if item.base == "food_box" then "Boxed " else "Wrapped "
			return verb .. (r and r.name or "kebab (doesn't match the menu)")
		end
		return ingName(item.base) .. " (" .. #item.fillings .. " fillings)"
	elseif k == "chips" then
		local state = FoodLogic.cookState(item.cook or 0)
		return ({ raw = "Frozen chips", cooking = "Undercooked chips", cooked = "Hot chips", burnt = "Burnt chips" })[state] or "Chips"
	elseif k == "cup" then
		if item.syrup then
			local id = FoodLogic.identify(item)
			local r = id and Recipes.get(id)
			return r and r.name or "Drink"
		end
		return "Empty cup"
	elseif k == "dessert" then
		if not item.flavour then
			return "Empty dessert cup"
		end
		local id = FoodLogic.identify(item)
		local r = id and Recipes.get(id)
		return r and r.name or (ingName(item.flavour):gsub(" Mix$", "") .. " (" .. #item.toppings .. " toppings)")
	elseif k == "supply" then
		return "Supply box: " .. ingName(item.ingredient) .. " ×" .. tostring(item.amount)
	end
	return k
end

-- Recipes a player at `level` with `upgrades` set can serve.
function FoodLogic.isRecipeUnlocked(recipeId: string, level: number, upgrades: { [string]: boolean }): boolean
	local r = Recipes.get(recipeId)
	if not r then
		return false
	end
	if level < r.level then
		return false
	end
	if r.requires and not upgrades[r.requires] then
		return false
	end
	return true
end

function FoodLogic.unlockedRecipes(level: number, upgrades: { [string]: boolean }): { string }
	local out = {}
	for _, r in Recipes.List do
		if FoodLogic.isRecipeUnlocked(r.id, level, upgrades) then
			table.insert(out, r.id)
		end
	end
	return out
end

FoodLogic.setEquals = setEquals

return FoodLogic
