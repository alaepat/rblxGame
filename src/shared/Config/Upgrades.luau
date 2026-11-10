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
	staff: string?, -- hires a member of staff with this role (Config/Staff, StaffService)
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
	{ id = "oven_heat_3", name = "Hotter Oven III", category = "Kitchen", level = 15, cost = 1800, icon = "🔥", requires = "oven_heat_2",
		description = "Pizzas cook another 20% faster.", effects = { cookSpeed = 0.2 } },
	{ id = "dessert_station", name = "Dessert Station", category = "Kitchen", level = 12, cost = 1200, icon = "🍨",
		description = "A soft-serve machine and topping jars. Unlocks sundaes; customers add desserts to orders." },
	{ id = "heat_shelf_2", name = "Bigger Heat Shelf", category = "Kitchen", level = 6, cost = 200, icon = "♨️",
		description = "Two more heated holding slots on the pass." },
	-- Storage
	{ id = "storage_1", name = "Bigger Storage I", category = "Storage", level = 4, cost = 300, icon = "📦",
		description = "+50% stock capacity for every ingredient.", effects = { capacity = 0.5 } },
	{ id = "storage_2", name = "Bigger Storage II", category = "Storage", level = 10, cost = 800, icon = "📦", requires = "storage_1",
		description = "+50% more stock capacity.", effects = { capacity = 0.5 } },
	{ id = "storage_3", name = "Bigger Storage III", category = "Storage", level = 16, cost = 1500, icon = "📦", requires = "storage_2",
		description = "+50% more stock capacity again.", effects = { capacity = 0.5 } },
	{ id = "freezer_racks", name = "Freezer Racks", category = "Storage", level = 6, cost = 350, icon = "❄️", requires = "kebab_station",
		description = "Extra racks in the walk-in freezer: double capacity for frozen stock (doner meat, chips).", effects = { capacity_frozen = 1.0 } },
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
	{ id = "premium_packaging", name = "Premium Packaging", category = "Decor", level = 13, cost = 600, icon = "🎁",
		description = "Branded boxes and napkins. Customers tip more.", effects = { tip = 0.05 } },
	-- Staff (wages per day are in Config/DayCycle.Wages)
	{ id = "hire_cleaner", name = "Hire a Cleaner", category = "Staff", level = 9, cost = 900, icon = "🧹", staff = "cleaner",
		description = "Picks up rubbish and wipes messy counters for you. Wage $20 a day." },
	{ id = "hire_cashier", name = "Hire a Cashier", category = "Staff", level = 11, cost = 1500, icon = "🧾", staff = "cashier",
		description = "Takes orders at the register while you cook. Wage $25 a day." },
	{ id = "hire_cook", name = "Hire a Pizza Cook", category = "Staff", level = 13, cost = 2200, icon = "👨‍🍳", staff = "cook",
		description = "Watches the ovens: takes pizzas out the moment they're ready, boxes them and puts them on the heat shelf. Wage $35 a day." },
	-- second hires of a role (StaffService runs several NPCs per role; one cashier per register)
	{ id = "hire_cleaner_2", name = "Second Cleaner", category = "Staff", level = 15, cost = 1800, icon = "🧹", staff = "cleaner", requires = "hire_cleaner",
		description = "Another cleaner for the dinner rush. Two never go for the same mess. Wage $20 a day." },
	{ id = "hire_cook_2", name = "Second Pizza Cook", category = "Staff", level = 17, cost = 3500, icon = "👨‍🍳", staff = "cook", requires = "hire_cook",
		description = "A second cook watches a different oven, so two pizzas can come out at once. Wage $35 a day." },
}

local byId: { [string]: Upgrade } = {}
for _, u in list do
	byId[u.id] = u
end

return {
	List = list,
	ById = byId,
	Categories = { "Kitchen", "Storage", "Dining", "Decor", "Staff" },
	get = function(id: string): Upgrade?
		return byId[id]
	end,
}
