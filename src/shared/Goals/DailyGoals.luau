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
	return true
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
		local total = 0
		for _, t in pool do
			total += t.weight
		end
		local roll = rand() * total
		local index = #pool
		for i, t in pool do
			roll -= t.weight
			if roll <= 0 then
				index = i
				break
			end
		end
		local t = table.remove(pool, index) :: Challenges.Template
		local param = t.param
		if t.event == "serve_recipe" then
			param = mains[math.clamp(math.floor(rand() * #mains) + 1, 1, #mains)]
		end
		local reward = DailyGoals.goalReward(level, t.difficulty)
		table.insert(goals, {
			id = t.id,
			param = param,
			target = DailyGoals.target(t, level),
			progress = 0,
			cash = reward.cash,
			xp = reward.xp,
			claimed = false,
		})
	end
	return goals
end

------------------------------------------------------------------ state

function DailyGoals.new(): Daily
	return { day = 0, goals = {}, streak = 0, bestStreak = 0, lastFullDay = -1, bonusClaimed = false }
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
	return true, payout
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
	}
end

return DailyGoals
