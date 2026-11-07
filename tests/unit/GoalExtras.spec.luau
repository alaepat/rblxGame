-- Daily-goal extras (TASKS #17): the free daily swap (reroll) and the weekly
-- challenge, in Shared/Goals/DailyGoals.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local DailyGoals = Loader.module("Shared/Goals/DailyGoals")
local Challenges = Loader.module("Shared/Config/Challenges")

local DAY0 = 20397 -- a Wednesday
local UID = 4242

local function fresh(day: number, level: number?)
	local d = DailyGoals.new()
	DailyGoals.rollover(d, day, UID, level or 5, {})
	return d
end

local function ids(d): { [string]: boolean }
	local out = {}
	for _, g in d.goals do
		out[g.id] = true
	end
	return out
end

return {
	["weeks start on Monday"] = function()
		T.eq(DailyGoals.weekOfDay(4), 0, "1970-01-05 was a Monday")
		T.eq(DailyGoals.weekOfDay(10), 0)
		T.eq(DailyGoals.weekOfDay(11), 1)
		T.eq(DailyGoals.weekOfDay(3), -1)
		local t = DAY0 * 86400 + 3600
		local reset = DailyGoals.nextWeeklyReset(t)
		T.ok(reset > t and reset - t <= 7 * 86400)
		T.eq(DailyGoals.weekOfDay(DailyGoals.dayNumber(reset)), DailyGoals.weekOfDay(DAY0) + 1)
		T.eq(DailyGoals.weekOfDay(DailyGoals.dayNumber(reset - 1)), DailyGoals.weekOfDay(DAY0))
	end,

	["free swap replaces an unfinished goal with a new one, once a day"] = function()
		local d = fresh(DAY0)
		T.eq(DailyGoals.rerollsLeft(d), Challenges.FreeRerollsPerDay)
		local before = ids(d)
		local oldId = d.goals[2].id
		local ok, msg = DailyGoals.reroll(d, 2, DAY0, UID, 5, {})
		T.eq(ok, true, msg)
		T.ok(d.goals[2].id ~= oldId, "goal did not change")
		T.ok(not before[d.goals[2].id], "swapped to a goal already on the list")
		T.eq(d.goals[2].progress, 0)
		T.eq(#d.goals, Challenges.GoalsPerDay)
		T.eq(DailyGoals.rerollsLeft(d), 0)
		T.eq((DailyGoals.reroll(d, 1, DAY0, UID, 5, {})), false, "second free swap allowed")
		-- a new day gives the swap back
		DailyGoals.rollover(d, DAY0 + 1, UID, 5, {})
		T.eq(DailyGoals.rerollsLeft(d), Challenges.FreeRerollsPerDay)
	end,

	["finished goals, stale days and junk indices can't be swapped"] = function()
		local d = fresh(DAY0)
		d.goals[1].progress = d.goals[1].target
		T.eq((DailyGoals.reroll(d, 1, DAY0, UID, 5, {})), false, "finished goal swapped")
		T.eq((DailyGoals.reroll(d, 2, DAY0 + 1, UID, 5, {})), false, "swapped on a stale day")
		for _, bad in { nil, 0, 99, -1, 1.5, "1", {}, 0 / 0 } do
			T.eq((DailyGoals.reroll(d, bad, DAY0, UID, 5, {})), false, "accepted " .. tostring(bad))
		end
		T.eq(DailyGoals.rerollsLeft(d), Challenges.FreeRerollsPerDay, "a failed swap used the free swap")
	end,

	["weekly challenge: one per week, bigger target and reward, deterministic"] = function()
		local d = fresh(DAY0)
		local changed = DailyGoals.weeklyRollover(d, DAY0, UID, 5, {})
		T.eq(changed, true)
		local w = d.weekly.goal
		T.ok(w, "no weekly goal")
		T.eq(d.weekly.week, DailyGoals.weekOfDay(DAY0))
		local t = Challenges.ById[w.id]
		T.ok(table.find(Challenges.Weekly.Ids, w.id) ~= nil, "weekly picked a non-weekly template")
		T.ok(w.target >= DailyGoals.target(t, 5) * Challenges.Weekly.TargetMultiplier - t.step)
		T.eq(w.cash, DailyGoals.goalReward(5, t.difficulty).cash * Challenges.Weekly.RewardMultiplier)
		-- same week again: nothing changes
		T.eq((DailyGoals.weeklyRollover(d, DAY0 + 1, UID, 5, {})), false)
		T.eq(d.weekly.goal, w)
		-- same inputs, same challenge
		local again = DailyGoals.generateWeekly(d.weekly.week, UID, 5, {})
		T.eq(again.id, w.id)
		T.eq(again.target, w.target)
	end,

	["weekly progress, claim, and auto-pay at the next week"] = function()
		local d = fresh(DAY0)
		DailyGoals.weeklyRollover(d, DAY0, UID, 5, {})
		local w = d.weekly.goal
		local t = Challenges.ById[w.id]
		T.eq(DailyGoals.recordWeekly(d, "no_such_event", 5), false)
		T.eq(w.progress, 0)
		T.eq((DailyGoals.claimWeekly(d, DAY0)), false, "claimed before finishing")
		T.eq(DailyGoals.recordWeekly(d, t.event, w.target - 1, w.param), false)
		T.eq(DailyGoals.recordWeekly(d, t.event, 5, w.param), true)
		T.eq(w.progress, w.target, "progress not capped")
		local ok, msg, reward = DailyGoals.claimWeekly(d, DAY0)
		T.eq(ok, true, msg)
		T.eq(reward.cash, w.cash)
		T.eq((DailyGoals.claimWeekly(d, DAY0)), false, "paid twice")
		-- finish next week's challenge but don't claim it: the rollover pays it
		local nextWeekDay = DAY0 + 7
		DailyGoals.weeklyRollover(d, nextWeekDay, UID, 5, {})
		local w2 = d.weekly.goal
		w2.progress = w2.target
		local changed, payout = DailyGoals.weeklyRollover(d, nextWeekDay + 7, UID, 5, {})
		T.eq(changed, true)
		T.eq(payout.cash, w2.cash)
		T.eq(payout.xp, w2.xp)
		T.eq(d.weekly.goal.progress, 0)
	end,

	["view carries the weekly card and swaps left; old saves get the new fields"] = function()
		local d = fresh(DAY0)
		DailyGoals.weeklyRollover(d, DAY0, UID, 5, {})
		local now = DAY0 * 86400 + 600
		local v = DailyGoals.view(d, 5, now)
		T.eq(v.rerollsLeft, Challenges.FreeRerollsPerDay)
		T.ok(v.weekly, "no weekly in view")
		T.ok(v.weekly.resetsAt > now)
		T.ok(string.find(v.weekly.progressText, "/", 1, true) ~= nil)
		-- a week later without a rollover the stale challenge is hidden
		T.eq(DailyGoals.view(d, 5, now + 8 * 86400).weekly, nil)
		local old = DailyGoals.reconcile({ day = DAY0, goals = {}, streak = 1, bestStreak = 1, lastFullDay = DAY0 - 1, bonusClaimed = false })
		T.eq(old.rerollsUsed, 0)
		T.eq(old.weekly.week, -1)
	end,
}
