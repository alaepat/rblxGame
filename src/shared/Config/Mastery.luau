--!strict
-- Menu mastery tuning (TASKS #16). Rules: Shared/Mastery/Mastery.
--
-- Every recipe you serve counts toward its mastery. Reaching a tier pays a
-- one-off reward and gives a permanent bonus on that recipe's serve XP.

return {
	-- Serves needed for each tier (index = tier). Drinks are quick and
	-- frequent, so their thresholds are multiplied by KindMultiplier.drink.
	Tiers = {
		{ id = "bronze", name = "Bronze", icon = "🥉", serves = 10, rewardPrice = 3, rewardXP = 2, serveXPBonus = 0.1 },
		{ id = "silver", name = "Silver", icon = "🥈", serves = 30, rewardPrice = 6, rewardXP = 4, serveXPBonus = 0.2 },
		{ id = "gold", name = "Gold", icon = "🥇", serves = 75, rewardPrice = 12, rewardXP = 8, serveXPBonus = 0.3 },
	},
	-- Tier reward: cash = recipe.price * rewardPrice, XP = recipe.xp * rewardXP.
	-- Serve bonus: every serve of a mastered recipe adds floor(recipe.xp * serveXPBonus) XP.
	KindMultiplier = {
		drink = 2,
	},
}
