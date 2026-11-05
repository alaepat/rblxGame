-- Pure daily-goal rules: generation, progress, claiming, streaks, rollover.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local DailyGoals = Loader.module("Shared/Goals/DailyGoals")
local Challenges = Loader.module("Shared/Config/Challenges")
local FoodLogic = Loader.module("Shared/Food/FoodLogic")

local DAY0 = 20397 -- an arbitrary UTC day number
local UID = 123456789

local function freshDaily(day: number?, level: number?, upgrades: any?)
	local d = DailyGoals.new()
	DailyGoals.rollover(d, day or DAY0, UID, level or 5, upgrades or {})
	return d
end

local function finishAll(d)
	for _, g in d.goals do
		g.progress = g.target
	end
end

local function claimAll(d)
	for i in d.goals do
		assert(DailyGoals.claim(d, i))
	end
end

return {
	["generation is deterministic per day and player"] = function()
		local a = DailyGoals.generate(DAY0, UID, 7, { kebab_station = true })
		local b = DailyGoals.generate(DAY0, UID, 7, { kebab_station = true })
		T.eq(#a, Challenges.GoalsPerDay)
		for i = 1, #a do
			T.eq(a[i].id, b[i].id)
			T.eq(a[i].param, b[i].param)
			T.eq(a[i].target, b[i].target)
		end
	end,

	["each day has distinct goals and days vary"] = function()
		local seen = {}
		local daysDiffer = false
		local prev = ""
		for day = DAY0, DAY0 + 40 do
			local goals = DailyGoals.generate(day, UID, 10, { kebab_station = true })
			local ids = {}
			for _, g in goals do
				T.ok(not ids[g.id], "duplicate goal " .. g.id .. " on day " .. day)
				ids[g.id] = true
				seen[g.id] = true
			end
			local sig = goals[1].id .. goals[2].id .. goals[3].id
			if prev ~= "" and sig ~= prev then
				daysDiffer = true
			end
			prev = sig
		end
		local n = 0
		for _ in seen do
			n += 1
		end
		T.ok(daysDiffer, "every day rolled the same goals")
		T.ok(n >= 8, "only " .. n .. " different goal types in 40 days")
	end,

	["different players get different goals"] = function()
		local same = 0
		for day = DAY0, DAY0 + 20 do
			local a = DailyGoals.generate(day, 1, 8, {})
			local b = DailyGoals.generate(day, 99887766, 8, {})
			if a[1].id == b[1].id and a[2].id == b[2].id and a[3].id == b[3].id then
				same += 1
			end
		end
		T.ok(same < 10, "players share goals too often: " .. same .. "/21")
	end,

	["level and upgrade gates are respected"] = function()
		for day = DAY0, DAY0 + 60 do
			for _, g in DailyGoals.generate(day, UID, 1, {}) do
				local t = Challenges.ById[g.id]
				T.ok(t.minLevel <= 1, g.id .. " rolled at level 1")
			end
			for _, g in DailyGoals.generate(day, UID, 9, {}) do
				T.ok(g.id ~= "kebabs", "kebab goal without the kebab station")
			end
		end
		local found = false
		for day = DAY0, DAY0 + 60 do
			for _, g in DailyGoals.generate(day, UID, 9, { kebab_station = true }) do
				if g.id == "kebabs" then
					found = true
				end
			end
		end
		T.ok(found, "kebab goal never rolls with the kebab station")
	end,

	["recipe goals pick an unlocked main"] = function()
		local upgrades = { kebab_station = true, fryer = true }
		local unlocked = {}
		for _, id in FoodLogic.unlockedRecipes(8, upgrades) do
			unlocked[id] = true
		end
		local count = 0
		for day = DAY0, DAY0 + 80 do
			for _, g in DailyGoals.generate(day, UID, 8, upgrades) do
				if g.id == "recipe" then
					count += 1
					T.ok(unlocked[g.param], "locked recipe " .. tostring(g.param))
					T.ok(g.param ~= "cola" and g.param ~= "orange_soda" and g.param ~= "lime_soda", "recipe goal picked a drink")
					T.ok(string.find(DailyGoals.describe(g), "×", 1, true) ~= nil)
				end
			end
		end
		T.ok(count > 0, "recipe goal never rolled")
	end,

	["targets grow with level and round to their step"] = function()
		local earn = Challenges.ById.earn
		T.eq(DailyGoals.target(earn, 1), 50)
		T.eq(DailyGoals.target(earn, 10) % earn.step, 0)
		T.ok(DailyGoals.target(earn, 20) > DailyGoals.target(earn, 5))
		T.ok(DailyGoals.goalReward(20, 1).xp > DailyGoals.goalReward(2, 1).xp)
		T.ok(DailyGoals.goalReward(30, 1).xp < math.huge, "max-level XP reward must be finite")
	end,

	["record counts matching events only and caps at target"] = function()
		local d = DailyGoals.new()
		d.day = DAY0
		d.goals = {
			{ id = "pizzas", param = "pizza", target = 2, progress = 0, cash = 10, xp = 5, claimed = false },
			{ id = "earn", target = 20, progress = 0, cash = 10, xp = 5, claimed = false },
			{ id = "recipe", param = "ham_pizza", target = 1, progress = 0, cash = 10, xp = 5, claimed = false },
		}
		T.eq(#DailyGoals.record(d, "serve_kind", 1, "kebab"), 0)
		T.eq(d.goals[1].progress, 0, "kebab counted as pizza")
		T.eq(#DailyGoals.record(d, "serve_kind", 1, "pizza"), 0)
		local fin = DailyGoals.record(d, "serve_kind", 1, "pizza")
		T.eq(#fin, 1)
		T.eq(fin[1], 1)
		T.eq(#DailyGoals.record(d, "serve_kind", 1, "pizza"), 0, "finished twice")
		T.eq(d.goals[1].progress, 2)
		DailyGoals.record(d, "earn", 12.37)
		T.near(d.goals[2].progress, 12.37, 1e-9)
		DailyGoals.record(d, "earn", 100)
		T.eq(d.goals[2].progress, 20)
		T.eq(#DailyGoals.record(d, "serve_recipe", 1, "cheese_pizza"), 0)
		T.eq(#DailyGoals.record(d, "serve_recipe", 1, "ham_pizza"), 1)
		-- junk amounts are ignored
		local d2 = freshDaily()
		local before = d2.goals[1].progress
		DailyGoals.record(d2, Challenges.ById[d2.goals[1].id].event, 0 / 0, d2.goals[1].param)
		DailyGoals.record(d2, Challenges.ById[d2.goals[1].id].event, -5, d2.goals[1].param)
		T.eq(d2.goals[1].progress, before)
	end,

	["claim validates and pays once"] = function()
		local d = freshDaily()
		local ok = DailyGoals.claim(d, 1)
		T.eq(ok, false, "claimed an unfinished goal")
		d.goals[1].progress = d.goals[1].target
		local ok2, _, reward = DailyGoals.claim(d, 1)
		T.eq(ok2, true)
		T.eq(reward.cash, d.goals[1].cash)
		T.eq(reward.xp, d.goals[1].xp)
		T.eq((DailyGoals.claim(d, 1)), false, "claimed twice")
		for _, bad in { 0, 4, 1.5, -1, "1", 0 / 0, math.huge } do
			T.eq((DailyGoals.claim(d, bad)), false, "accepted index " .. tostring(bad))
		end
	end,

	["bonus needs every goal claimed and builds a streak"] = function()
		local d = freshDaily(DAY0)
		T.eq((DailyGoals.claimBonus(d, 5, DAY0)), false, "bonus before goals")
		finishAll(d)
		T.eq((DailyGoals.claimBonus(d, 5, DAY0)), false, "bonus before claiming")
		claimAll(d)
		local ok, _, r1 = DailyGoals.claimBonus(d, 5, DAY0)
		T.eq(ok, true)
		T.eq(d.streak, 1)
		T.eq((DailyGoals.claimBonus(d, 5, DAY0)), false, "bonus twice")

		-- next day: streak 2 and a bigger bonus
		DailyGoals.rollover(d, DAY0 + 1, UID, 5, {})
		T.eq(DailyGoals.currentStreak(d, DAY0 + 1), 1, "streak still alive the next day")
		finishAll(d)
		claimAll(d)
		local _, _, r2 = DailyGoals.claimBonus(d, 5, DAY0 + 1)
		T.eq(d.streak, 2)
		T.ok(r2.cash > r1.cash, "streak bonus did not grow")

		-- skip a day: streak resets
		DailyGoals.rollover(d, DAY0 + 3, UID, 5, {})
		T.eq(d.streak, 0)
		T.eq(DailyGoals.currentStreak(d, DAY0 + 3), 0)
		T.eq(d.bestStreak, 2)
		finishAll(d)
		claimAll(d)
		DailyGoals.claimBonus(d, 5, DAY0 + 3)
		T.eq(d.streak, 1)
	end,

	["streak multiplier is capped"] = function()
		T.eq(DailyGoals.streakMultiplier(1), 1)
		T.eq(DailyGoals.streakMultiplier(2), 1 + Challenges.StreakStep)
		T.eq(DailyGoals.streakMultiplier(100), 1 + Challenges.StreakStep * Challenges.StreakMaxSteps)
	end,

	["rollover pays unclaimed rewards and ignores the past"] = function()
		local d = freshDaily(DAY0)
		local first = d.goals[1].id
		T.eq((DailyGoals.rollover(d, DAY0, UID, 5, {})), false, "same day rolled")
		T.eq(d.goals[1].id, first)
		T.eq((DailyGoals.rollover(d, DAY0 - 1, UID, 5, {})), false, "clock going back rolled")

		finishAll(d)
		DailyGoals.claim(d, 1) -- one claimed by hand, two left
		local expected = d.goals[2].cash + d.goals[3].cash
		local changed, payout = DailyGoals.rollover(d, DAY0 + 1, UID, 5, {})
		T.eq(changed, true)
		local bonus = DailyGoals.bonusReward(5, 1)
		T.eq(payout.cash, expected + bonus.cash)
		T.eq(d.streak, 1, "auto-paid bonus should count for the streak")
		T.eq(d.lastFullDay, DAY0)
		T.eq(d.day, DAY0 + 1)
		T.eq(d.bonusClaimed, false)
		for _, g in d.goals do
			T.eq(g.progress, 0)
			T.eq(g.claimed, false)
		end
		-- nothing finished: nothing paid
		local _, payout2 = DailyGoals.rollover(d, DAY0 + 2, UID, 5, {})
		T.eq(payout2.cash, 0)
		T.eq(payout2.xp, 0)
	end,

	["time helpers line up with the UTC reset"] = function()
		local t = DAY0 * 86400 + 3600 * 13 + 125
		T.eq(DailyGoals.dayNumber(t), DAY0)
		T.eq(DailyGoals.nextReset(t), (DAY0 + 1) * 86400)
		T.eq(DailyGoals.dayNumber(DailyGoals.nextReset(t)), DAY0 + 1)
		T.eq(DailyGoals.dayNumber(DailyGoals.nextReset(t) - 1), DAY0)
	end,

	["text and view"] = function()
		T.eq(DailyGoals.describe({ id = "earn", target = 75, progress = 0, cash = 0, xp = 0, claimed = false }), "Earn $75 from orders")
		T.eq(DailyGoals.amountText(Challenges.ById.tips, 3.5), "$3.50")
		T.eq(DailyGoals.amountText(Challenges.ById.orders, 3), "3")
		local d = freshDaily(DAY0, 5)
		d.goals[1].progress = d.goals[1].target
		local now = DAY0 * 86400 + 500
		local v = DailyGoals.view(d, 5, now)
		T.eq(#v.goals, 3)
		T.eq(v.goals[1].done, true)
		T.eq(v.goals[2].done, false)
		T.ok(v.resetsAt > now and v.resetsAt - now <= 86400)
		T.eq(v.bonus.ready, false)
		T.eq(v.streak, 0)
		T.ok(string.find(v.goals[1].progressText, "/", 1, true) ~= nil)
	end,

	["reconcile repairs bad saves"] = function()
		local d = DailyGoals.reconcile(nil)
		T.eq(d.day, 0)
		local partial = DailyGoals.reconcile({ day = 5, goals = {}, streak = "x" })
		T.eq(partial.day, 5)
		T.eq(partial.streak, 0)
		T.eq(partial.bonusClaimed, false)
	end,
}
