--!strict
-- Daily goals ("challenges"). Every player gets GoalsPerDay goals each UTC day,
-- picked from Templates by level and owned upgrades. Finishing a goal pays
-- cash + XP when claimed; finishing ALL of them pays a bonus that grows with
-- the daily streak.
--
-- Template fields
--   id         unique id (saved in the profile)
--   event      what GoalService.record() counts (see the list below)
--   param      "kind" goals: the recipe kind to count ("pizza" | "kebab" | "drink")
--              "recipe" goals pick a random unlocked main recipe each day
--   text       description; %s is replaced by the target (and recipe name)
--   minLevel   lowest player level that can roll this goal
--   requires   upgrade id that must be owned (optional)
--   base, perLevel, step   target = round_to_step(base + perLevel * (level - 1))
--   money      true if the target is a money amount (shown as $)
--   weight     relative chance of being picked
--   difficulty scales the reward
--
-- Events (sent by the server systems)
--   order          a whole order completed                     amount 1
--   earn           money received for an order (incl. tip)     amount $
--   tip            tip received                                amount $
--   happy          order completed with patience >= GameConfig.HappyPatience
--   serve_kind     one item served, param = recipe kind
--   serve_recipe   one item served, param = recipe id
--   clean          rubbish picked up / counter wiped
--   bake_perfect   pizza taken out of the oven while "cooked" (not raw, not burnt)

export type Template = {
	id: string,
	event: string,
	param: string?,
	text: string,
	icon: string,
	minLevel: number,
	requires: string?,
	base: number,
	perLevel: number,
	step: number,
	money: boolean?,
	weight: number,
	difficulty: number,
}

local templates: { Template } = {
	{ id = "orders", event = "order", text = "Complete %s orders", icon = "🧾",
		minLevel = 1, base = 4, perLevel = 0.5, step = 1, weight = 3, difficulty = 1 },
	{ id = "earn", event = "earn", text = "Earn %s from orders", icon = "💰", money = true,
		minLevel = 1, base = 50, perLevel = 12, step = 5, weight = 3, difficulty = 1 },
	{ id = "pizzas", event = "serve_kind", param = "pizza", text = "Serve %s pizzas", icon = "🍕",
		minLevel = 1, base = 4, perLevel = 0.4, step = 1, weight = 3, difficulty = 1 },
	{ id = "drinks", event = "serve_kind", param = "drink", text = "Serve %s drinks", icon = "🥤",
		minLevel = 1, base = 3, perLevel = 0.25, step = 1, weight = 2, difficulty = 0.8 },
	{ id = "happy", event = "happy", text = "Serve %s happy customers (no long waits)", icon = "😊",
		minLevel = 1, base = 3, perLevel = 0.35, step = 1, weight = 2, difficulty = 1.2 },
	{ id = "bake", event = "bake_perfect", text = "Bake %s pizzas to perfection", icon = "🔥",
		minLevel = 1, base = 4, perLevel = 0.35, step = 1, weight = 2, difficulty = 1 },
	{ id = "clean", event = "clean", text = "Clean up %s messes", icon = "🧽",
		minLevel = 2, base = 3, perLevel = 0.15, step = 1, weight = 2, difficulty = 0.8 },
	{ id = "tips", event = "tip", text = "Collect %s in tips", icon = "💵", money = true,
		minLevel = 2, base = 5, perLevel = 1.5, step = 1, weight = 2, difficulty = 1.1 },
	{ id = "recipe", event = "serve_recipe", text = "Serve %s × %s", icon = "⭐",
		minLevel = 2, base = 2, perLevel = 0.2, step = 1, weight = 3, difficulty = 1.1 },
	{ id = "kebabs", event = "serve_kind", param = "kebab", text = "Serve %s kebabs, wraps or boxes", icon = "🥙",
		minLevel = 6, requires = "kebab_station", base = 3, perLevel = 0.3, step = 1, weight = 3, difficulty = 1.1 },
}

local byId: { [string]: Template } = {}
for _, t in templates do
	byId[t.id] = t
end

return {
	GoalsPerDay = 3,
	-- Free swaps per day: replace an unfinished, unclaimed goal with a different one.
	FreeRerollsPerDay = 1,
	-- Goals reset at this hour (UTC). 0 = midnight UTC.
	ResetHourUTC = 0,
	-- The "happy customer" threshold is GameConfig.HappyPatience.

	-- Reward per goal: cash = (CashBase + CashPerLevel * level) * difficulty,
	-- xp = xpToNext(level) * XpFraction * difficulty
	CashBase = 25,
	CashPerLevel = 6,
	XpFraction = 0.12,

	-- Bonus for finishing every goal of the day, multiplied by the streak:
	-- 1 + StreakStep * min(streak - 1, StreakMaxSteps)
	BonusCashBase = 40,
	BonusCashPerLevel = 10,
	BonusXpFraction = 0.2,
	StreakStep = 0.25,
	StreakMaxSteps = 6,

	-- Weekly challenge: one big goal per week (weeks start Monday at ResetHourUTC).
	-- Picked from these template ids; target = daily target x TargetMultiplier,
	-- reward = daily goal reward x RewardMultiplier. Unclaimed finished weekly
	-- rewards are paid automatically when the week rolls over.
	Weekly = {
		Ids = { "orders", "earn", "pizzas", "happy", "bake", "clean", "tips" },
		TargetMultiplier = 7,
		RewardMultiplier = 5,
	},

	Templates = templates,
	ById = byId,
}
