--!strict
-- Restaurant upgrades. Purchased from the office computer.
-- Visible upgrades: the restaurant template contains models with attribute
-- UpgradeId = <id>; they stay hidden until the upgrade is owned. Models with
-- attribute HideWhen = <id> are removed once that upgrade is owned.
--
-- effects are read by server systems through UpgradeService.

export type Upgrade = {
	id: string,
	name: string,
	description: string,
	category: string,
	level: number,
	cost: number,
	requires: string?,
	icon: string,
	effects: { [string]: number }?,
}

local list: { Upgrade } = {
	-- Kitchen
	{ id = "prep_2", name = "Second Prep Counter", category = "Kitchen", level = 3, cost = 250, icon = "🍕",
		description = "A second pizza prep board with its own topping rail." },
	{ id = "oven_heat_1", name = "Hotter Oven I", category = "Kitchen", level = 3, cost = 300, icon = "🔥",
		description = "Pizzas cook 25% faster.", effects = { cookSpeed = 0.25 } },
	{ id = "oven_2", name = "Second Pizza Oven", category = "Kitchen", level = 4, cost = 450, icon = "🧱",
		description = "Adds a second stone deck oven." },
	{ id = "kebab_station", name = "Kebab Station", category = "Kitchen", level = 5, cost = 500, icon = "🥙",
		description = "Doner spits, kebab prep board and salad rail. Unlocks kebabs." },
	{ id = "fryer", name = "Chip Fryer", category = "Kitchen", level = 8, cost = 400, icon = "🍟", requires = "kebab_station",
		description = "Fry chips for loaded fries and doner boxes." },
	{ id = "oven_heat_2", name = "Hotter Oven II", category = "Kitchen", level = 9, cost = 900, icon = "🔥", requires = "oven_heat_1",
		description = "Pizzas cook another 25% faster.", effects = { cookSpeed = 0.25 } },
	{ id = "heat_shelf_2", name = "Bigger Heat Shelf", category = "Kitchen", level = 6, cost = 200, icon = "♨️",
		description = "Two more heated holding slots on the pass." },
	-- Storage
	{ id = "storage_1", name = "Bigger Storage I", category = "Storage", level = 4, cost = 300, icon = "📦",
		description = "+50% stock capacity for every ingredient.", effects = { capacity = 0.5 } },
	{ id = "storage_2", name = "Bigger Storage II", category = "Storage", level = 10, cost = 800, icon = "📦", requires = "storage_1",
		description = "+50% more stock capacity.", effects = { capacity = 0.5 } },
	-- Dining
	{ id = "seating_1", name = "More Seating I", category = "Dining", level = 2, cost = 150, icon = "🪑",
		description = "Two more tables. Customers arrive 15% more often.", effects = { traffic = 0.15 } },
	{ id = "seating_2", name = "More Seating II", category = "Dining", level = 6, cost = 400, icon = "🪑", requires = "seating_1",
		description = "Booth seating. Customers arrive 15% more often.", effects = { traffic = 0.15 } },
	{ id = "expansion_1", name = "Dining Room Extension", category = "Dining", level = 10, cost = 2000, icon = "🏗️",
		description = "Knock through into the extension. Bigger queue, +25% customers.", effects = { traffic = 0.25, queue = 2 } },
	-- Decor
	{ id = "decor_plants", name = "Plants & Planters", category = "Decor", level = 2, cost = 80, icon = "🌿",
		description = "Leafy planters. Customers tip a little more.", effects = { tip = 0.03 } },
	{ id = "decor_neon", name = "Neon Wall Signs", category = "Decor", level = 5, cost = 200, icon = "💡",
		description = "Glowing pizza and kebab neon signs.", effects = { tip = 0.04 } },
	{ id = "decor_lights", name = "Pendant Lights", category = "Decor", level = 7, cost = 250, icon = "🏮",
		description = "Warm pendant lights over the tables.", effects = { tip = 0.04 } },
}

local byId: { [string]: Upgrade } = {}
for _, u in list do
	byId[u.id] = u
end

return {
	List = list,
	ById = byId,
	Categories = { "Kitchen", "Storage", "Dining", "Decor" },
	get = function(id: string): Upgrade?
		return byId[id]
	end,
}
