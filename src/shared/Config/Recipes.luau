--!strict
-- Menu items. Customers only order recipes the player has unlocked
-- (level >= recipe.level AND, if set, the required upgrade is owned).
--
-- kind "pizza": base dough -> sauce -> toppings (set). Must be cooked + boxed.
-- kind "kebab": base (pitta / wrap_bread / food_box) -> fillings (set). Must be wrapped/closed.
-- kind "drink": a cup filled from the fountain with `syrup`.

export type Recipe = {
	id: string,
	name: string,
	kind: string,
	level: number,
	price: number,
	xp: number,
	icon: string,
	requires: string?, -- upgrade id required
	sauce: string?, -- pizza
	toppings: { string }?, -- pizza (includes cheese)
	base: string?, -- kebab
	fillings: { string }?, -- kebab
	syrup: string?, -- drink
	description: string,
}

local list: { Recipe } = {
	-- ===== PIZZAS =====
	{ id = "cheese_pizza", name = "Cheese Pizza", kind = "pizza", level = 1, price = 8, xp = 10, icon = "🍕",
		sauce = "tomato_sauce", toppings = { "mozzarella" }, description = "Tomato sauce and a blanket of mozzarella." },
	{ id = "tomato_pizza", name = "Tomato Pizza", kind = "pizza", level = 1, price = 9, xp = 11, icon = "🍅",
		sauce = "tomato_sauce", toppings = { "mozzarella", "tomato" }, description = "Cheese pizza topped with fresh tomato slices." },
	{ id = "pepperoni_pizza", name = "Pepperoni Pizza", kind = "pizza", level = 2, price = 10, xp = 13, icon = "🍕",
		sauce = "tomato_sauce", toppings = { "mozzarella", "pepperoni" }, description = "The classic. Mozzarella and pepperoni." },
	{ id = "mushroom_pizza", name = "Mushroom Pizza", kind = "pizza", level = 2, price = 10, xp = 13, icon = "🍄",
		sauce = "tomato_sauce", toppings = { "mozzarella", "mushroom" }, description = "Mozzarella and sliced mushrooms." },
	{ id = "ham_pizza", name = "Ham Pizza", kind = "pizza", level = 3, price = 11, xp = 15, icon = "🥓",
		sauce = "tomato_sauce", toppings = { "mozzarella", "ham" }, description = "Mozzarella and smoked ham." },
	{ id = "chicken_pizza", name = "Chicken Pizza", kind = "pizza", level = 4, price = 12, xp = 16, icon = "🍗",
		sauce = "tomato_sauce", toppings = { "mozzarella", "chicken" }, description = "Mozzarella and roast chicken pieces." },
	{ id = "vegetable_pizza", name = "Vegetable Pizza", kind = "pizza", level = 4, price = 13, xp = 18, icon = "🥦",
		sauce = "tomato_sauce", toppings = { "mozzarella", "mushroom", "onion", "green_pepper", "olive" }, description = "Mushroom, red onion, green pepper and olives." },
	{ id = "extra_cheese_pizza", name = "Extra Cheese Pizza", kind = "pizza", level = 4, price = 11, xp = 15, icon = "🧀",
		sauce = "tomato_sauce", toppings = { "mozzarella", "cheddar" }, description = "Mozzarella AND cheddar." },
	{ id = "bbq_chicken_pizza", name = "BBQ Chicken Pizza", kind = "pizza", level = 9, price = 15, xp = 22, icon = "🍖",
		sauce = "bbq_sauce", toppings = { "mozzarella", "chicken", "onion" }, description = "BBQ sauce base, chicken and red onion." },
	{ id = "meat_feast_pizza", name = "Meat Feast Pizza", kind = "pizza", level = 9, price = 17, xp = 25, icon = "🥩",
		sauce = "tomato_sauce", toppings = { "mozzarella", "pepperoni", "ham", "beef", "chicken" }, description = "Pepperoni, ham, beef and chicken." },
	{ id = "spicy_pepperoni_pizza", name = "Spicy Pepperoni Pizza", kind = "pizza", level = 9, price = 15, xp = 22, icon = "🌶️",
		sauce = "tomato_sauce", toppings = { "mozzarella", "pepperoni", "jalapeno" }, description = "Pepperoni with a jalapeño kick." },
	{ id = "supreme_pizza", name = "Supreme Pizza", kind = "pizza", level = 10, price = 18, xp = 28, icon = "⭐",
		sauce = "tomato_sauce", toppings = { "mozzarella", "pepperoni", "beef", "mushroom", "onion", "green_pepper", "olive" }, description = "Everything a supreme should have." },
	{ id = "deluxe_house_pizza", name = "Deluxe House Pizza", kind = "pizza", level = 11, price = 21, xp = 32, icon = "🪐",
		sauce = "tomato_sauce", toppings = { "mozzarella", "cheddar", "ham", "pepperoni", "mushroom", "olive", "jalapeno" }, description = "The Pizza Planet signature." },

	-- ===== KEBABS =====
	{ id = "chicken_doner", name = "Chicken Doner Kebab", kind = "kebab", level = 6, price = 9, xp = 14, icon = "🥙", requires = "kebab_station",
		base = "pitta", fillings = { "chicken_doner", "lettuce", "tomato", "garlic_sauce" }, description = "Chicken doner in pitta with salad and garlic sauce." },
	{ id = "lamb_doner", name = "Lamb Doner Kebab", kind = "kebab", level = 7, price = 10, xp = 15, icon = "🥙", requires = "kebab_station",
		base = "pitta", fillings = { "lamb_doner", "lettuce", "red_cabbage", "onion", "chilli_sauce" }, description = "Lamb doner, cabbage, onion and chilli sauce." },
	{ id = "mixed_doner", name = "Mixed Doner Kebab", kind = "kebab", level = 7, price = 12, xp = 18, icon = "🥙", requires = "kebab_station",
		base = "pitta", fillings = { "chicken_doner", "lamb_doner", "lettuce", "tomato", "garlic_sauce", "chilli_sauce" }, description = "Both meats, salad, both sauces." },
	{ id = "chicken_wrap", name = "Chicken Wrap", kind = "kebab", level = 8, price = 9, xp = 14, icon = "🌯", requires = "kebab_station",
		base = "wrap_bread", fillings = { "chicken_doner", "lettuce", "cucumber", "mayo" }, description = "Chicken doner wrap with cucumber and mayo." },
	{ id = "lamb_wrap", name = "Lamb Wrap", kind = "kebab", level = 8, price = 10, xp = 15, icon = "🌯", requires = "kebab_station",
		base = "wrap_bread", fillings = { "lamb_doner", "lettuce", "onion", "chilli_sauce" }, description = "Lamb doner wrap with onion and chilli." },
	{ id = "mixed_wrap", name = "Mixed Wrap", kind = "kebab", level = 8, price = 12, xp = 18, icon = "🌯", requires = "kebab_station",
		base = "wrap_bread", fillings = { "chicken_doner", "lamb_doner", "lettuce", "tomato", "garlic_sauce" }, description = "Both meats wrapped with salad." },
	{ id = "doner_box", name = "Doner Meat Box", kind = "kebab", level = 8, price = 11, xp = 17, icon = "🥡", requires = "fryer",
		base = "food_box", fillings = { "chips", "lamb_doner", "garlic_sauce", "chilli_sauce" }, description = "Chips loaded with lamb doner and both sauces." },
	{ id = "loaded_fries", name = "Loaded Fries", kind = "kebab", level = 8, price = 8, xp = 12, icon = "🍟", requires = "fryer",
		base = "food_box", fillings = { "chips", "cheddar", "chicken_doner", "garlic_sauce" }, description = "Chips, cheddar, chicken doner, garlic sauce." },
	{ id = "planet_special", name = "Planet Special Box", kind = "kebab", level = 12, price = 19, xp = 30, icon = "🪐", requires = "fryer",
		base = "food_box", fillings = { "chips", "chicken_doner", "lamb_doner", "cheddar", "lettuce", "red_cabbage", "garlic_sauce", "chilli_sauce" }, description = "The ultimate box. Everything on it." },

	-- ===== DRINKS =====
	{ id = "cola", name = "Planet Cola", kind = "drink", level = 1, price = 2, xp = 3, icon = "🥤", syrup = "cola_syrup", description = "Ice-cold cola." },
	{ id = "orange_soda", name = "Orbit Orange", kind = "drink", level = 3, price = 2, xp = 3, icon = "🍊", syrup = "orange_syrup", description = "Fizzy orange." },
	{ id = "lime_soda", name = "Lunar Lime", kind = "drink", level = 6, price = 2, xp = 3, icon = "🍋", syrup = "lime_syrup", description = "Sharp lime soda." },
}

local byId: { [string]: Recipe } = {}
for _, r in list do
	byId[r.id] = r
end

return {
	List = list,
	ById = byId,
	get = function(id: string): Recipe?
		return byId[id]
	end,
}
