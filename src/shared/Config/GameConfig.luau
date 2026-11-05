--!strict
-- Global tuning values. Change numbers here, not in systems.

return {
	GameName = "Pizza Planet",
	DataStoreName = "PizzaPlanet_Player_v1",
	DataVersion = 1,
	AutosaveInterval = 90,

	StartingMoney = 200,
	-- Units of each ingredient a brand-new restaurant starts with.
	StartingStock = {
		dough = 12,
		tomato_sauce = 30,
		mozzarella = 30,
		tomato = 20,
		pizza_box = 20,
		cup = 20,
		cola_syrup = 30,
	},
	-- Max units per ingredient = boxSize * BaseCapacityBoxes * (1 + capacity upgrades)
	BaseCapacityBoxes = 3,

	-- Plots (one restaurant per player)
	PlotCount = 6,
	PlotSpacing = 160,

	-- Cooking
	PizzaBaseCookTime = 14, -- seconds at 1x speed
	PizzaCookPerTopping = 1.2,
	BurnAt = 1.6, -- progress fraction (1 = perfectly cooked)
	ChipsCookTime = 10,
	PourTime = 1.5,

	-- Customers
	BaseSpawnInterval = 26, -- seconds between arrivals at rating 3, no upgrades
	MinSpawnInterval = 7,
	BaseQueueSize = 4,
	OrderPatience = { min = 70, max = 120 }, -- waiting at the register
	FoodPatience = { min = 120, max = 200 }, -- waiting for food after ordering
	MaxItemsPerOrder = 3,
	WalkSpeed = 10,

	-- Economy
	MaxTipFraction = 0.3,
	WrongOrderPatiencePenalty = 0.15,
	AngryRatingStars = 1,
	DeliveryTime = 12, -- seconds for supplies to arrive at the back door
	MaxBoxesPerDelivery = 12,
	EmergencyCooldown = 300,

	-- Cleaning
	TrashChance = 0.35, -- chance a served customer leaves rubbish
	MaxTrash = 8,
	PrepUsesBeforeDirty = 8,
	CleanXP = 4,
	CleanlinessPerTrash = 8,
	CleanlinessPerDirtyCounter = 10,

	-- Interaction
	PromptDistance = 7,
}
