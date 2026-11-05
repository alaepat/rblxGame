--!strict
-- Daily goals + streaks (server authoritative).
--  * Other services call GoalService.record(player, event, amount, param) when
--    something countable happens (see the event list in Config/Challenges).
--  * Goals roll over at the UTC reset; finished-but-unclaimed rewards are paid
--    automatically at rollover.
--  * The client claims through the ClaimGoal remote: ClaimGoal(index) for one
--    goal, ClaimGoal("bonus") for the all-goals streak bonus.
--  * Rules live in Shared.Goals.DailyGoals, numbers/content in Config/Challenges.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DailyGoals = require(Shared.Goals.DailyGoals)
local Net = require(Shared.Net)

local GoalService = {}
local S: any

local CHECK_INTERVAL = 20 -- seconds between rollover checks for online players

function GoalService.init(services)
	S = services
end

-- Replaceable clock (tests move it forward to simulate new days).
GoalService.clock = os.time

local function now(): number
	return GoalService.clock()
end

local function dailyOf(player: Player): DailyGoals.Daily?
	local profile = S.DataService.get(player)
	if not profile then
		return nil
	end
	profile.daily = DailyGoals.reconcile(profile.daily)
	return profile.daily
end

local function pay(player: Player, reward: DailyGoals.Reward)
	if reward.cash > 0 then
		S.ProgressService.addMoney(player, reward.cash, "goal")
	end
	if reward.xp > 0 then
		S.ProgressService.addXP(player, reward.xp)
	end
end

-- Moves the player's goals to today if the day changed. Safe to call often.
function GoalService.ensure(player: Player)
	local profile = S.DataService.get(player)
	local daily = dailyOf(player)
	if not profile or not daily then
		return
	end
	local today = DailyGoals.dayNumber(now())
	local hadGoals = daily.day > 0
	local changed, payout = DailyGoals.rollover(daily, today, player.UserId, profile.level, profile.upgrades)
	if not changed then
		return
	end
	if payout.cash > 0 or payout.xp > 0 then
		pay(player, payout)
		S.ProgressService.notify(player, ("Yesterday's unclaimed goals paid out: +$%d, +%d XP"):format(payout.cash, payout.xp), "good")
	end
	if hadGoals then
		S.ProgressService.notify(player, "🎯 New daily goals are ready!", "info")
	end
	S.ProgressService.push(player)
end

-- Other systems that want every recorded event (ShiftService day stats).
local listeners: { (Player, string, number?, string?) -> () } = {}
function GoalService.onEvent(fn: (Player, string, number?, string?) -> ())
	table.insert(listeners, fn)
end

-- Count an event toward the player's goals. This is the game's event feed:
-- listeners registered with onEvent get every event too, even ones no goal uses.
function GoalService.record(player: Player?, event: string, amount: number?, param: string?)
	if not player then
		return
	end
	for _, fn in listeners do
		local ok, err = pcall(fn, player, event, amount, param)
		if not ok then
			warn("[GoalService] event listener failed: " .. tostring(err))
		end
	end
	GoalService.ensure(player)
	local daily = dailyOf(player)
	if not daily then
		return
	end
	local finished = DailyGoals.record(daily, event, amount, param)
	for _, i in finished do
		local g = daily.goals[i]
		S.ProgressService.notify(player, "🎯 Goal done: " .. DailyGoals.describe(g) .. "  (claim it in Goals)", "good")
		S.ProgressService.sound(player, "Ding")
	end
	S.ProgressService.push(player)
end

function GoalService.claim(player: Player, which: any): (boolean, string)
	local profile = S.DataService.get(player)
	GoalService.ensure(player)
	local daily = dailyOf(player)
	if not profile or not daily then
		return false, "Profile not loaded"
	end
	local ok, msg, reward
	if which == "bonus" then
		ok, msg, reward = DailyGoals.claimBonus(daily, profile.level, DailyGoals.dayNumber(now()))
	else
		ok, msg, reward = DailyGoals.claim(daily, which)
	end
	if not ok or not reward then
		return false, msg
	end
	pay(player, reward)
	S.ProgressService.sound(player, "Cash")
	S.ProgressService.push(player)
	return true, ("%s +$%d, +%d XP"):format(msg, reward.cash, reward.xp)
end

-- Snapshot fields for the client (see Controllers/Goals).
function GoalService.stateFor(player: Player): { [string]: any }
	local profile = S.DataService.get(player)
	local daily = dailyOf(player)
	if not profile or not daily or daily.day == 0 then
		return {}
	end
	return { goals = DailyGoals.view(daily, profile.level, now()) }
end

function GoalService.start()
	Net.func("ClaimGoal").OnServerInvoke = function(player, which)
		local ok, res, msg = pcall(GoalService.claim, player, which)
		if not ok then
			warn("[GoalService] claim failed: " .. tostring(res))
			return false, "Something went wrong"
		end
		return res, msg
	end
	S.ProgressService.addStateProvider(GoalService.stateFor)
	S.DataService.onLoaded(function(player)
		GoalService.ensure(player)
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for player in S.DataService.Profiles do
				local ok, err = pcall(GoalService.ensure, player)
				if not ok then
					warn("[GoalService] rollover failed: " .. tostring(err))
				end
			end
		end
	end)
end

return GoalService
