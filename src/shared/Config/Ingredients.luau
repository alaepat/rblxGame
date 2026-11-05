--!strict
-- Every ingredient / consumable the restaurant stocks.
-- category: "dry" | "cold" | "frozen"  (decides which storage accepts the supply box)
-- boxSize: units per supply box, boxCost: price of one box
-- shape: how FoodVisuals draws it as a topping/filling
-- level: player level required before it can be ordered from suppliers

export type Ingredient = {
	id: string,
	name: string,
	category: string,
	boxSize: number,
	boxCost: number,
	level: number,
	color: Color3,
	shape: string,
	icon: string,
}

local list: { Ingredient } = {
	-- Pizza base & sauces
	{ id = "dough", name = "Pizza Dough", category = "cold", boxSize = 12, boxCost = 10, level = 1, color = Color3.fromRGB(240, 222, 186), shape = "dough", icon = "🫓" },
	{ id = "tomato_sauce", name = "Tomato Sauce", category = "dry", boxSize = 30, boxCost = 6, level = 1, color = Color3.fromRGB(196, 40, 28), shape = "sauce", icon = "🥫" },
	{ id = "bbq_sauce", name = "BBQ Sauce", category = "dry", boxSize = 30, boxCost = 8, level = 9, color = Color3.fromRGB(105, 40, 20), shape = "sauce", icon = "🍖" },
	-- Cheese
	{ id = "mozzarella", name = "Mozzarella", category = "cold", boxSize = 30, boxCost = 9, level = 1, color = Color3.fromRGB(255, 236, 170), shape = "cheese", icon = "🧀" },
	{ id = "cheddar", name = "Cheddar", category = "cold", boxSize = 30, boxCost = 9, level = 4, color = Color3.fromRGB(255, 170, 40), shape = "shred", icon = "🧀" },
	-- Pizza toppings
	{ id = "tomato", name = "Sliced Tomatoes", category = "cold", boxSize = 30, boxCost = 6, level = 1, color = Color3.fromRGB(225, 50, 45), shape = "slice", icon = "🍅" },
	{ id = "pepperoni", name = "Pepperoni", category = "cold", boxSize = 30, boxCost = 10, level = 2, color = Color3.fromRGB(170, 35, 30), shape = "disc", icon = "🍕" },
	{ id = "mushroom", name = "Mushrooms", category = "cold", boxSize = 30, boxCost = 7, level = 2, color = Color3.fromRGB(214, 196, 168), shape = "mushroom", icon = "🍄" },
	{ id = "ham", name = "Ham", category = "cold", boxSize = 30, boxCost = 10, level = 3, color = Color3.fromRGB(240, 150, 150), shape = "square", icon = "🥓" },
	{ id = "onion", name = "Red Onions", category = "cold", boxSize = 30, boxCost = 5, level = 3, color = Color3.fromRGB(175, 95, 160), shape = "ring", icon = "🧅" },
	{ id = "green_pepper", name = "Green Peppers", category = "cold", boxSize = 30, boxCost = 6, level = 3, color = Color3.fromRGB(70, 160, 50), shape = "strip", icon = "🫑" },
	{ id = "chicken", name = "Chicken Pieces", category = "cold", boxSize = 30, boxCost = 12, level = 4, color = Color3.fromRGB(230, 200, 150), shape = "chunk", icon = "🍗" },
	{ id = "olive", name = "Black Olives", category = "cold", boxSize = 30, boxCost = 7, level = 4, color = Color3.fromRGB(35, 30, 35), shape = "ring", icon = "🫒" },
	{ id = "beef", name = "Ground Beef", category = "cold", boxSize = 30, boxCost = 12, level = 9, color = Color3.fromRGB(110, 60, 40), shape = "crumble", icon = "🥩" },
	{ id = "jalapeno", name = "Jalapeños", category = "cold", boxSize = 30, boxCost = 7, level = 9, color = Color3.fromRGB(60, 140, 40), shape = "disc", icon = "🌶️" },
	-- Kebab
	{ id = "pitta", name = "Pitta Bread", category = "dry", boxSize = 20, boxCost = 8, level = 5, color = Color3.fromRGB(232, 196, 140), shape = "bread", icon = "🥙" },
	{ id = "wrap_bread", name = "Wrap Bread", category = "dry", boxSize = 20, boxCost = 8, level = 8, color = Color3.fromRGB(240, 214, 165), shape = "bread", icon = "🌯" },
	{ id = "food_box", name = "Food Boxes", category = "dry", boxSize = 30, boxCost = 5, level = 8, color = Color3.fromRGB(250, 250, 245), shape = "box", icon = "🥡" },
	{ id = "chicken_doner", name = "Chicken Doner", category = "frozen", boxSize = 24, boxCost = 18, level = 5, color = Color3.fromRGB(215, 160, 90), shape = "meat", icon = "🍗" },
	{ id = "lamb_doner", name = "Lamb Doner", category = "frozen", boxSize = 24, boxCost = 20, level = 7, color = Color3.fromRGB(140, 80, 50), shape = "meat", icon = "🥩" },
	{ id = "lettuce", name = "Lettuce", category = "cold", boxSize = 30, boxCost = 5, level = 5, color = Color3.fromRGB(120, 200, 70), shape = "leaf", icon = "🥬" },
	{ id = "cucumber", name = "Cucumber", category = "cold", boxSize = 30, boxCost = 5, level = 5, color = Color3.fromRGB(150, 210, 110), shape = "disc", icon = "🥒" },
	{ id = "red_cabbage", name = "Red Cabbage", category = "cold", boxSize = 30, boxCost = 5, level = 5, color = Color3.fromRGB(130, 40, 110), shape = "shred", icon = "🥬" },
	{ id = "garlic_sauce", name = "Garlic Sauce", category = "dry", boxSize = 40, boxCost = 6, level = 5, color = Color3.fromRGB(248, 246, 232), shape = "drizzle", icon = "🧄" },
	{ id = "chilli_sauce", name = "Chilli Sauce", category = "dry", boxSize = 40, boxCost = 6, level = 5, color = Color3.fromRGB(215, 30, 20), shape = "drizzle", icon = "🌶️" },
	{ id = "mayo", name = "Mayonnaise", category = "dry", boxSize = 40, boxCost = 6, level = 8, color = Color3.fromRGB(255, 248, 210), shape = "drizzle", icon = "🥚" },
	{ id = "chips", name = "Frozen Chips", category = "frozen", boxSize = 16, boxCost = 12, level = 8, color = Color3.fromRGB(250, 205, 90), shape = "chips", icon = "🍟" },
	-- Packaging & drinks
	{ id = "pizza_box", name = "Pizza Boxes", category = "dry", boxSize = 30, boxCost = 6, level = 1, color = Color3.fromRGB(250, 246, 236), shape = "box", icon = "📦" },
	{ id = "kebab_wrapper", name = "Kebab Wrappers", category = "dry", boxSize = 40, boxCost = 4, level = 5, color = Color3.fromRGB(235, 235, 240), shape = "box", icon = "🧻" },
	{ id = "cup", name = "Drink Cups", category = "dry", boxSize = 40, boxCost = 5, level = 1, color = Color3.fromRGB(250, 250, 250), shape = "box", icon = "🥤" },
	{ id = "cola_syrup", name = "Cola Syrup", category = "dry", boxSize = 40, boxCost = 10, level = 1, color = Color3.fromRGB(60, 25, 15), shape = "sauce", icon = "🥤" },
	{ id = "orange_syrup", name = "Orange Syrup", category = "dry", boxSize = 40, boxCost = 10, level = 3, color = Color3.fromRGB(255, 140, 20), shape = "sauce", icon = "🍊" },
	{ id = "lime_syrup", name = "Lime Syrup", category = "dry", boxSize = 40, boxCost = 10, level = 6, color = Color3.fromRGB(150, 220, 40), shape = "sauce", icon = "🍋" },
}

local byId: { [string]: Ingredient } = {}
for i, ing in list do
	byId[ing.id] = ing
end

return {
	List = list,
	ById = byId,
	get = function(id: string): Ingredient?
		return byId[id]
	end,
}
