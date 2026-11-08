--!strict
-- Pure daily-goal rules (no Roblox services), shared by GoalService (server,
-- authoritative) and tests. The saved state lives in profile.daily:
--
--   daily = {
--     day = 20397,            -- UTC day number the goals belong to (0 = never rolled)
--     goals = { Goal },       -- see below
--     streak = 2,             -- consecutive days with every goal finished
--     bestStreak = 5,
--     lastFullDay = 20396,    -- last day the all-goals bonus was earned
--     bonusClaimed = false,
--     rerollsUsed = 0,        -- free goal swaps used today (Challenges.FreeRerollsPerDay)
--     weekly = { week = 2913, goal = Goal? },  -- weekly challenge (weeks start Monday)
--   }
--   Goal = { id, param?, target, progress, cash, xp, claimed }
--
-- Content and numbers come from Config/Challenges.

local Config = script.Parent.Parent.Config
local Challenges = require(Config.Challenges)
local Levels = require(Config.Levels)
local Recipes = require(Config.Recipes)
local FoodLogic = require(script.Parent.Parent.Food.FoodLogic)

export type Goal = {
	id: string,
	param: string?,
	target: number,
	progress: number,
	cash: number,
	xp: number,
	claimed: boolean,
}

export type Daily = {
	day: number,
	goals: { Goal },
	streak: number,
	bestStreak: number,
	lastFullDay: number,
	bonusClaimed: boolean,
	rerollsUsed: number,
	weekly: { week: number, goal: Goal? },
}

export type Reward = { cash: number, xp: number }

local DAY = 86400

local DailyGoals = {}

------------------------------------------------------------------ time

function DailyGoals.dayNumber(t: number): number
	return (t - Challenges.ResetHourUTC * 3600) // DAY
end

-- Unix time of the next reset after `t`.
function DailyGoals.nextReset(t: number): number
	return (DailyGoals.dayNumber(t) + 1) * DAY + Challenges.ResetHourUTC * 3600
end

-- Weeks start on Monday at the daily reset hour. Day 4 (1970-01-05) was a Monday.
function DailyGoals.weekOfDay(day: number): number
	return (day - 4) // 7
end

-- Unix time when the weekly challenge for the week containing `t` ends.
function DailyGoals.nextWeeklyReset(t: number): number
	local week = DailyGoals.weekOfDay(DailyGoals.dayNumber(t))
	return ((week + 1) * 7 + 4) * DAY + Challenges.ResetHourUTC * 3600
end

------------------------------------------------------------------ random
-- Park-Miller "minimal standard" generator. Deterministic and identical in
-- Roblox and Lune, so a player's goals for a day can be reproduced exactly.

local MOD = 2147483647

local function makeRng(seed: number): () -> number
	local s = math.floor(seed) % MOD
	if s <= 0 then
		s += MOD - 1
	end
	return function(): number
		s = (s * 48271) % MOD
		return s / MOD
	end
end

------------------------------------------------------------------ rewards

local function xpBase(level: number): number
	local n = Levels.xpToNext(level)
	if n == math.huge then
		n = Levels.xpToNext(Levels.MaxLevel - 1)
	end
	return n
end

function DailyGoals.goalReward(level: number, difficulty: number): Reward
	return {
		cash = math.floor((Challenges.CashBase + Challenges.CashPerLevel * level) * difficulty + 0.5),
		xp = math.max(5, math.floor(xpBase(level) * Challenges.XpFraction * difficulty + 0.5)),
	}
end

function DailyGoals.streakMultiplier(streak: number): number
	return 1 + Challenges.StreakStep * math.clamp(streak - 1, 0, Challenges.StreakMaxSteps)
end

function DailyGoals.bonusReward(level: number, streak: number): Reward
	local m = DailyGoals.streakMultiplier(streak)
	return {
		cash = math.floor((Challenges.BonusCashBase + Challenges.BonusCashPerLevel * level) * m + 0.5),
		xp = math.max(10, math.floor(xpBase(level) * Challenges.BonusXpFraction * m + 0.5)),
	}
end

function DailyGoals.target(t: Challenges.Template, level: number): number
	local raw = t.base + t.perLevel * (level - 1)
	return math.max(t.step, math.floor(raw / t.step + 0.5) * t.step)
end

------------------------------------------------------------------ generation

local function mainRecipes(level: number, upgrades: { [string]: boolean }): { string }
	local out = {}
	for _, id in FoodLogic.unlockedRecipes(level, upgrades) do
		local r = Recipes.get(id)
		if r and r.kind ~= "drink" then
			table.insert(out, id)
		end
	end
	return out
end

local function eligible(t: Challenges.Template, level: number, upgrades: { [string]: boolean }, mains: { string }): boolean
	if level < t.minLevel then
		return false
	end
	if t.requires and not upgrades[t.requires] then
		return false
	end
	if t.event == "serve_recipe" and #mains < 2 then
		return false
	end
	-- "different recipes" goals need more recipes on the menu than the target
	if t.event == "serve_variety" and #FoodLogic.unlockedRecipes(level, upgrades) <= DailyGoals.target(t, level) then
		return false
	end
	return true
end

local function makeGoal(t: Challenges.Template, rand: () -> number, mains: { string }, level: number): Goal
	local param = t.param
	if t.event == "serve_recipe" then
		param = mains[math.clamp(math.floor(rand() * #mains) + 1, 1, #mains)]
	end
	local reward = DailyGoals.goalReward(level, t.difficulty)
	return {
		id = t.id,
		param = param,
		target = DailyGoals.target(t, level),
		progress = 0,
		cash = reward.cash,
		xp = reward.xp,
		claimed = false,
	}
end

local function pickWeighted(pool: { Challenges.Template }, rand: () -> number): number
	local total = 0
	for _, t in pool do
		total += t.weight
	end
	local roll = rand() * total
	for i, t in pool do
		roll -= t.weight
		if roll <= 0 then
			return i
		end
	end
	return #pool
end

-- The goals a player gets on `day`. Same inputs always give the same goals.
function DailyGoals.generate(day: number, userId: number, level: number, upgrades: { [string]: boolean }): { Goal }
	local rand = makeRng(day * 1000003 + userId % 1000000007 + 17)
	for _ = 1, 4 do
		rand()
	end
	local mains = mainRecipes(level, upgrades)
	local pool = {}
	for _, t in Challenges.Templates do
		if eligible(t, level, upgrades, mains) then
			table.insert(pool, t)
		end
	end
	local goals: { Goal } = {}
	while #goals < Challenges.GoalsPerDay and #pool > 0 do
		local index = pickWeighted(pool, rand)
		local t = table.remove(pool, index) :: Challenges.Template
		table.insert(goals, makeGoal(t, rand, mains, level))
	end
	return goals
end

------------------------------------------------------------------ state

function DailyGoals.new(): Daily
	return {
		day = 0,
		goals = {},
		streak = 0,
		bestStreak = 0,
		lastFullDay = -1,
		bonusClaimed = false,
		rerollsUsed = 0,
		weekly = { week = -1 },
	}
end

-- Fill in fields missing from an older or partial save.
function DailyGoals.reconcile(daily: any): Daily
	if type(daily) ~= "table" then
		return DailyGoals.new()
	end
	local fresh = DailyGoals.new() :: any
	for k, v in fresh do
		if daily[k] == nil or type(daily[k]) ~= type(v) then
			daily[k] = v
		end
	end
	return daily
end

function DailyGoals.isDone(goal: Goal): boolean
	return goal.progress >= goal.target
end

function DailyGoals.allDone(daily: Daily): boolean
	if #daily.goals == 0 then
		return false
	end
	for _, g in daily.goals do
		if not DailyGoals.isDone(g) then
			return false
		end
	end
	return true
end

function DailyGoals.allClaimed(daily: Daily): boolean
	if #daily.goals == 0 then
		return false
	end
	for _, g in daily.goals do
		if not g.claimed then
			return false
		end
	end
	return true
end

-- Streak shown to the player today (0 if a day was missed).
function DailyGoals.currentStreak(daily: Daily, today: number): number
	if daily.lastFullDay == today or daily.lastFullDay == today - 1 then
		return daily.streak
	end
	return 0
end

-- The streak the player will have once today's bonus is earned.
local function streakAfterBonus(daily: Daily, today: number): number
	if daily.lastFullDay == today then
		return daily.streak
	elseif daily.lastFullDay == today - 1 then
		return daily.streak + 1
	end
	return 1
end

local function earnBonus(daily: Daily, level: number, today: number): Reward
	daily.streak = streakAfterBonus(daily, today)
	daily.bestStreak = math.max(daily.bestStreak, daily.streak)
	daily.lastFullDay = today
	daily.bonusClaimed = true
	return DailyGoals.bonusReward(level, daily.streak)
end

-- Moves the state to `today`. Rewards that were finished but never claimed are
-- paid out automatically (nobody loses a reward by logging off). Returns the
-- payout and whether anything changed.
function DailyGoals.rollover(daily: Daily, today: number, userId: number, level: number, upgrades: { [string]: boolean }): (boolean, Reward)
	local payout: Reward = { cash = 0, xp = 0 }
	if daily.day == today or today < daily.day then
		return false, payout
	end
	if daily.day > 0 then
		for _, g in daily.goals do
			if DailyGoals.isDone(g) and not g.claimed then
				g.claimed = true
				payout.cash += g.cash
				payout.xp += g.xp
			end
		end
		if DailyGoals.allDone(daily) and not daily.bonusClaimed then
			local b = earnBonus(daily, level, daily.day)
			payout.cash += b.cash
			payout.xp += b.xp
		end
	end
	if daily.lastFullDay < today - 1 then
		daily.streak = 0
	end
	daily.day = today
	daily.goals = DailyGoals.generate(today, userId, level, upgrades)
	daily.bonusClaimed = false
	daily.rerollsUsed = 0
	return true, payout
end

------------------------------------------------------------------ free reroll

function DailyGoals.rerollsLeft(daily: Daily): number
	return math.max(0, Challenges.FreeRerollsPerDay - (daily.rerollsUsed or 0))
end

-- Swap goal `index` for a different goal (not one already on today's list).
-- Only unfinished, unclaimed goals can be swapped; progress starts over.
function DailyGoals.reroll(daily: Daily, index: any, today: number, userId: number, level: number, upgrades: { [string]: boolean }): (boolean, string)
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 then
		return false, "Invalid goal"
	end
	local g = daily.goals[index]
	if not g then
		return false, "Invalid goal"
	end
	if daily.day ~= today then
		return false, "Your goals are out of date"
	end
	if DailyGoals.rerollsLeft(daily) <= 0 then
		return false, "No free swaps left today"
	end
	if g.claimed or DailyGoals.isDone(g) then
		return false, "That goal is already finished"
	end
	local used: { [string]: boolean } = {}
	for _, other in daily.goals do
		used[other.id] = true
	end
	local mains = mainRecipes(level, upgrades)
	local pool = {}
	for _, t in Challenges.Templates do
		if not used[t.id] and eligible(t, level, upgrades, mains) then
			table.insert(pool, t)
		end
	end
	if #pool == 0 then
		return false, "No other goals available yet"
	end
	daily.rerollsUsed = (daily.rerollsUsed or 0) + 1
	local rand = makeRng(today * 1000003 + userId % 1000000007 + 7919 * daily.rerollsUsed + index * 31)
	for _ = 1, 4 do
		rand()
	end
	daily.goals[index] = makeGoal(pool[pickWeighted(pool, rand)], rand, mains, level)
	return true, "🎲 New goal: " .. DailyGoals.describe(daily.goals[index])
end

------------------------------------------------------------------ weekly challenge

-- The weekly challenge for `week`. Same inputs always give the same goal.
function DailyGoals.generateWeekly(week: number, userId: number, level: number, upgrades: { [string]: boolean }): Goal?
	local rand = makeRng(week * 7919 + userId % 1000000007 + 99991)
	for _ = 1, 4 do
		rand()
	end
	local mains = mainRecipes(level, upgrades)
	local pool = {}
	for _, id in Challenges.Weekly.Ids do
		local t = Challenges.ById[id]
		if t and eligible(t, level, upgrades, mains) then
			table.insert(pool, t)
		end
	end
	if #pool == 0 then
		return nil
	end
	local t = pool[pickWeighted(pool, rand)]
	local g = makeGoal(t, rand, mains, level)
	g.target = math.max(t.step, math.floor(g.target * Challenges.Weekly.TargetMultiplier / t.step + 0.5) * t.step)
	g.cash *= Challenges.Weekly.RewardMultiplier
	g.xp *= Challenges.Weekly.RewardMultiplier
	return g
end

-- Moves the weekly challenge to the week containing `today`. A finished but
-- unclaimed weekly reward is paid out. Returns (changed, payout, isNewWeek).
function DailyGoals.weeklyRollover(daily: Daily, today: number, userId: number, level: number, upgrades: { [string]: boolean }): (boolean, Reward)
	local payout: Reward = { cash = 0, xp = 0 }
	if type(daily.weekly) ~= "table" then
		daily.weekly = { week = -1 }
	end
	local w = daily.weekly
	local week = DailyGoals.weekOfDay(today)
	if w.week == week or week < (w.week or -1) then
		return false, payout
	end
	local old = w.goal
	if old and DailyGoals.isDone(old) and not old.claimed then
		payout.cash += old.cash
		payout.xp += old.xp
	end
	daily.weekly = { week = week, goal = DailyGoals.generateWeekly(week, userId, level, upgrades) }
	return true, payout
end

-- Counts an event toward the weekly challenge. Returns true when it just finished.
function DailyGoals.recordWeekly(daily: Daily, event: string, amount: number?, param: string?): boolean
	local g = type(daily.weekly) == "table" and daily.weekly.goal or nil
	local n = amount or 1
	if not g or n ~= n or n <= 0 or DailyGoals.isDone(g) then
		return false
	end
	local t = Challenges.ById[g.id]
	if not t or t.event ~= event or (g.param ~= nil and g.param ~= param) then
		return false
	end
	g.progress = math.min(g.target, math.floor((g.progress + n) * 100 + 0.5) / 100)
	return DailyGoals.isDone(g)
end

function DailyGoals.claimWeekly(daily: Daily, today: number): (boolean, string, Reward?)
	local w = daily.weekly
	local g = type(w) == "table" and w.goal or nil
	if not g or w.week ~= DailyGoals.weekOfDay(today) then
		return false, "No weekly challenge right now", nil
	end
	if g.claimed then
		return false, "Already claimed", nil
	end
	if not DailyGoals.isDone(g) then
		return false, "Not finished yet", nil
	end
	g.claimed = true
	return true, "🏆 Weekly challenge complete!", { cash = g.cash, xp = g.xp }
end

-- Counts an event toward matching goals. Returns the indices of goals that
-- were finished by this event.
function DailyGoals.record(daily: Daily, event: string, amount: number?, param: string?): { number }
	local finished = {}
	local n = amount or 1
	if n ~= n or n <= 0 then
		return finished
	end
	for i, g in daily.goals do
		local t = Challenges.ById[g.id]
		if t and t.event == event and not DailyGoals.isDone(g) and (g.param == nil or g.param == param) then
			g.progress = math.min(g.target, math.floor((g.progress + n) * 100 + 0.5) / 100)
			if DailyGoals.isDone(g) then
				table.insert(finished, i)
			end
		end
	end
	return finished
end

function DailyGoals.claim(daily: Daily, index: any): (boolean, string, Reward?)
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 then
		return false, "Invalid goal", nil
	end
	local g = daily.goals[index]
	if not g then
		return false, "Invalid goal", nil
	end
	if g.claimed then
		return false, "Already claimed", nil
	end
	if not DailyGoals.isDone(g) then
		return false, "Not finished yet", nil
	end
	g.claimed = true
	return true, "Goal complete!", { cash = g.cash, xp = g.xp }
end

function DailyGoals.claimBonus(daily: Daily, level: number, today: number): (boolean, string, Reward?)
	if daily.day ~= today then
		return false, "Your goals are out of date", nil
	end
	if daily.bonusClaimed then
		return false, "Already claimed", nil
	end
	if not DailyGoals.allClaimed(daily) then
		return false, "Claim every goal first", nil
	end
	local reward = earnBonus(daily, level, today)
	return true, ("All goals done! %d-day streak"):format(daily.streak), reward
end

------------------------------------------------------------------ text

function DailyGoals.amountText(t: Challenges.Template?, n: number): string
	if t and t.money then
		if n % 1 == 0 then
			return "$" .. tostring(n)
		end
		return ("$%.2f"):format(n)
	end
	return tostring(math.floor(n))
end

function DailyGoals.describe(goal: Goal): string
	local t = Challenges.ById[goal.id]
	if not t then
		return goal.id
	end
	local target = DailyGoals.amountText(t, goal.target)
	if t.event == "serve_recipe" then
		local r = goal.param and Recipes.get(goal.param)
		return (string.format(t.text, target, r and r.name or tostring(goal.param)))
	end
	return (string.format(t.text, target))
end

local function weeklyView(daily: Daily, now: number): { [string]: any }?
	local w = daily.weekly
	local g = type(w) == "table" and w.goal or nil
	if not g or w.week ~= DailyGoals.weekOfDay(DailyGoals.dayNumber(now)) then
		return nil
	end
	local t = Challenges.ById[g.id]
	return {
		text = DailyGoals.describe(g),
		icon = t and t.icon or "🏆",
		progress = g.progress,
		target = g.target,
		progressText = DailyGoals.amountText(t, g.progress) .. " / " .. DailyGoals.amountText(t, g.target),
		cash = g.cash,
		xp = g.xp,
		done = DailyGoals.isDone(g),
		claimed = g.claimed,
		resetsAt = DailyGoals.nextWeeklyReset(now),
	}
end

-- What the client needs to draw the goals panel.
function DailyGoals.view(daily: Daily, level: number, now: number): { [string]: any }
	local today = DailyGoals.dayNumber(now)
	local list = {}
	for i, g in daily.goals do
		local t = Challenges.ById[g.id]
		local icon = t and t.icon or "🎯"
		if t and t.event == "serve_recipe" and g.param then
			local r = Recipes.get(g.param)
			icon = r and r.icon or icon
		end
		table.insert(list, {
			index = i,
			text = DailyGoals.describe(g),
			icon = icon,
			progress = g.progress,
			target = g.target,
			progressText = DailyGoals.amountText(t, g.progress) .. " / " .. DailyGoals.amountText(t, g.target),
			cash = g.cash,
			xp = g.xp,
			done = DailyGoals.isDone(g),
			claimed = g.claimed,
		})
	end
	local nextStreak = streakAfterBonus(daily, today)
	local bonus = DailyGoals.bonusReward(level, nextStreak)
	return {
		goals = list,
		streak = DailyGoals.currentStreak(daily, today),
		bestStreak = daily.bestStreak,
		bonus = {
			cash = bonus.cash,
			xp = bonus.xp,
			multiplier = DailyGoals.streakMultiplier(nextStreak),
			streakAfter = nextStreak,
			ready = DailyGoals.allClaimed(daily) and not daily.bonusClaimed,
			claimed = daily.bonusClaimed,
		},
		resetsAt = DailyGoals.nextReset(now),
		rerollsLeft = DailyGoals.rerollsLeft(daily),
		weekly = weeklyView(daily, now),
	}
end

return DailyGoals
