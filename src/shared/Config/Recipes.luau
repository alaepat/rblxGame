--!strict
-- Menu items. Customers only order recipes the player has unlocked
-- (level >= recipe.level AND, if set, the required upgrade is owned).
--
-- kind "pizza": base dough -> sauce -> toppings (set). Must be cooked + boxed.
--   folded = true: a calzone (press Fold on the board before baking).
--   Garlic bread is a pizza with garlic_butter as its "sauce".
-- kind "kebab": base (pitta / wrap_bread / food_box) -> fillings (set). Must be wrapped/closed.
-- kind "drink": a cup filled from the fountain with `syrup`.
-- kind "dessert": a dessert cup filled at the soft-serve machine with
--   `flavour`, then toppings (set) from the jars. Served as soon as it's filled.

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
	flavour: string?, -- dessert (ice cream mix)
	folded: boolean?, -- pizza: calzone
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
	-- levels 13-20: late-game pizzas from the same rail, bigger and pricier
	{ id = "chicken_mushroom_pizza", name = "Chicken & Mushroom Pizza", kind = "pizza", level = 13, price = 16, xp = 26, icon = "🍗",
		sauce = "tomato_sauce", toppings = { "mozzarella", "chicken", "mushroom", "green_pepper" }, description = "Roast chicken, mushrooms and green pepper." },
	{ id = "bbq_meat_feast_pizza", name = "BBQ Meat Feast", kind = "pizza", level = 14, price = 22, xp = 34, icon = "🔥",
		sauce = "bbq_sauce", toppings = { "mozzarella", "chicken", "beef", "ham", "pepperoni", "onion" }, description = "BBQ base, four meats and red onion." },
	{ id = "four_cheese_heat_pizza", name = "Cheesy Inferno", kind = "pizza", level = 15, price = 18, xp = 29, icon = "🌋",
		sauce = "tomato_sauce", toppings = { "mozzarella", "cheddar", "jalapeno", "green_pepper", "onion" }, description = "Double cheese, jalapeños and peppers." },
	{ id = "garden_supreme_pizza", name = "Garden Supreme", kind = "pizza", level = 16, price = 19, xp = 30, icon = "🌿",
		sauce = "tomato_sauce", toppings = { "mozzarella", "tomato", "mushroom", "onion", "green_pepper", "olive", "jalapeno" }, description = "Every vegetable on the rail." },
	{ id = "bbq_ranch_pizza", name = "Smokehouse Pizza", kind = "pizza", level = 17, price = 21, xp = 33, icon = "🤠",
		sauce = "bbq_sauce", toppings = { "mozzarella", "cheddar", "beef", "chicken", "jalapeno", "onion" }, description = "BBQ beef and chicken with jalapeño heat." },
	{ id = "galaxy_pizza", name = "Galaxy Pizza", kind = "pizza", level = 19, price = 30, xp = 45, icon = "🌌",
		sauce = "tomato_sauce", toppings = { "mozzarella", "cheddar", "tomato", "pepperoni", "mushroom", "ham", "onion", "green_pepper", "chicken", "olive", "beef", "jalapeno" },
		description = "Every topping in the kitchen. Only for legends." },

	-- garlic bread + calzones (levels 17-20)
	{ id = "garlic_bread", name = "Garlic Bread", kind = "pizza", level = 17, price = 6, xp = 10, icon = "🧄",
		sauce = "garlic_butter", toppings = {}, description = "Dough brushed with garlic butter and baked." },
	{ id = "cheesy_garlic_bread", name = "Cheesy Garlic Bread", kind = "pizza", level = 17, price = 8, xp = 13, icon = "🧀",
		sauce = "garlic_butter", toppings = { "mozzarella" }, description = "Garlic bread with melted mozzarella." },
	{ id = "classic_calzone", name = "Classic Calzone", kind = "pizza", level = 18, price = 16, xp = 26, icon = "🥟", folded = true,
		sauce = "tomato_sauce", toppings = { "mozzarella", "ham", "mushroom" }, description = "Ham and mushroom folded in a pizza and baked." },
	{ id = "meat_calzone", name = "Meat Lover's Calzone", kind = "pizza", level = 20, price = 21, xp = 34, icon = "🥩", folded = true,
		sauce = "bbq_sauce", toppings = { "mozzarella", "pepperoni", "beef", "chicken" }, description = "BBQ sauce and three meats, folded and baked." },

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
	-- levels 13-20
	{ id = "cheesy_chips", name = "Cheesy Chips", kind = "kebab", level = 13, price = 7, xp = 12, icon = "🧀", requires = "fryer",
		base = "food_box", fillings = { "chips", "cheddar", "garlic_sauce" }, description = "Hot chips, melted cheddar, garlic sauce." },
	{ id = "chilli_chicken_wrap", name = "Chilli Chicken Wrap", kind = "kebab", level = 14, price = 11, xp = 18, icon = "🌶️", requires = "kebab_station",
		base = "wrap_bread", fillings = { "chicken_doner", "lettuce", "red_cabbage", "onion", "chilli_sauce" }, description = "Chicken doner with cabbage, onion and chilli." },
	{ id = "lamb_salad_box", name = "Lamb Salad Box", kind = "kebab", level = 15, price = 12, xp = 19, icon = "🥗", requires = "kebab_station",
		base = "food_box", fillings = { "lamb_doner", "lettuce", "tomato", "cucumber", "red_cabbage", "mayo" }, description = "Lamb doner on salad, no bread." },
	{ id = "mixed_grill_pitta", name = "Mixed Grill Pitta", kind = "kebab", level = 18, price = 18, xp = 29, icon = "🥙", requires = "kebab_station",
		base = "pitta", fillings = { "chicken_doner", "lamb_doner", "cheddar", "lettuce", "tomato", "onion", "cucumber", "garlic_sauce", "chilli_sauce", "mayo" },
		description = "Both meats, cheese, full salad and all three sauces." },
	{ id = "planet_mega_box", name = "Planet Mega Box", kind = "kebab", level = 20, price = 26, xp = 40, icon = "🚀", requires = "fryer",
		base = "food_box", fillings = { "chips", "chicken_doner", "lamb_doner", "cheddar", "lettuce", "tomato", "cucumber", "red_cabbage", "onion", "garlic_sauce", "chilli_sauce", "mayo" },
		description = "Everything from the kebab station. Bring a friend." },

	-- ===== DESSERTS (Dessert Station upgrade) =====
	{ id = "vanilla_sundae", name = "Vanilla Sundae", kind = "dessert", level = 12, price = 5, xp = 8, icon = "🍨", requires = "dessert_station",
		flavour = "vanilla_mix", toppings = { "choc_sauce" }, description = "Vanilla soft serve with chocolate sauce." },
	{ id = "chocolate_sundae", name = "Chocolate Sundae", kind = "dessert", level = 12, price = 5, xp = 8, icon = "🍫", requires = "dessert_station",
		flavour = "chocolate_mix", toppings = { "sprinkles" }, description = "Chocolate soft serve with rainbow sprinkles." },
	{ id = "strawberry_sundae", name = "Strawberry Sundae", kind = "dessert", level = 13, price = 6, xp = 9, icon = "🍓", requires = "dessert_station",
		flavour = "vanilla_mix", toppings = { "strawberry_sauce", "sprinkles" }, description = "Vanilla, strawberry sauce and sprinkles." },
	{ id = "cookie_crunch_sundae", name = "Cookie Crunch", kind = "dessert", level = 14, price = 7, xp = 11, icon = "🍪", requires = "dessert_station",
		flavour = "chocolate_mix", toppings = { "cookie_crumble", "choc_sauce" }, description = "Chocolate soft serve, cookie crumble, chocolate sauce." },
	{ id = "galaxy_sundae", name = "Galaxy Sundae", kind = "dessert", level = 16, price = 9, xp = 15, icon = "🌌", requires = "dessert_station",
		flavour = "chocolate_mix", toppings = { "choc_sauce", "strawberry_sauce", "sprinkles", "cookie_crumble" }, description = "Every topping on chocolate soft serve." },

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
