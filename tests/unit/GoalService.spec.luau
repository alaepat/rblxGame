-- GoalService against fake services: events, claims (server validation),
-- payouts through ProgressService, and day rollover.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local DailyGoals = Loader.module("Shared/Goals/DailyGoals")
local Challenges = Loader.module("Shared/Config/Challenges")

local DAY0 = 20397

local function setup()
	local remotes = {}
	local fakeNet = {
		func = function(name)
			remotes[name] = remotes[name] or {}
			return remotes[name]
		end,
		event = function(name)
			return { FireClient = function() end }
		end,
	}
	local GoalService = Loader.module("Server/Services/GoalService", { ["Shared/Net"] = fakeNet })
	local player = { UserId = 4242, Name = "Tester" }
	local profile = { money = 100, xp = 0, level = 5, upgrades = {}, stats = {} }
	local log = { money = 0, xp = 0, notes = {}, pushes = 0 }
	local S = {
		DataService = {
			get = function(p)
				return if p == player then profile else nil
			end,
			Profiles = { [player] = profile },
			onLoaded = function() end,
		},
		ProgressService = {
			addMoney = function(_, amount)
				log.money += amount
				profile.money += amount
			end,
			addXP = function(_, amount)
				log.xp += amount
			end,
			notify = function(_, text)
				table.insert(log.notes, text)
			end,
			sound = function() end,
			push = function()
				log.pushes += 1
			end,
			addStateProvider = function(fn)
				log.provider = fn
			end,
		},
	}
	GoalService.init(S)
	local t = DAY0 * 86400 + 3600
	GoalService.clock = function()
		return t
	end
	local function advanceDays(n)
		t += n * 86400
	end
	return GoalService, player, profile, log, advanceDays
end

local function eventOf(goal)
	return Challenges.ById[goal.id].event
end

return {
	["first load creates today's goals"] = function()
		local G, player, profile = setup()
		G.ensure(player)
		T.eq(profile.daily.day, DAY0)
		T.eq(#profile.daily.goals, Challenges.GoalsPerDay)
	end,

	["events progress goals and claims pay through ProgressService"] = function()
		local G, player, profile, log = setup()
		G.ensure(player)
		local g = profile.daily.goals[1]
		local ok = G.claim(player, 1)
		T.eq(ok, false, "claimed before finishing")
		T.eq(log.money, 0)
		G.record(player, eventOf(g), g.target, g.param)
		T.eq(g.progress, g.target)
		T.ok(#log.notes > 0, "no 'goal done' toast")
		local ok2, msg = G.claim(player, 1)
		T.eq(ok2, true, msg)
		T.eq(log.money, g.cash)
		T.eq(log.xp, g.xp)
		T.eq((G.claim(player, 1)), false, "paid twice")
		T.eq(log.money, g.cash)
	end,

	["junk claim arguments are rejected"] = function()
		local G, player, _, log = setup()
		G.ensure(player)
		for _, bad in { nil, {}, "x", "1", 99, -1, 0.5, 0 / 0, true } do
			T.eq((G.claim(player, bad)), false, "accepted " .. tostring(bad))
		end
		T.eq(log.money, 0)
	end,

	["bonus flow and unknown players"] = function()
		local G, player, profile, log = setup()
		G.ensure(player)
		T.eq((G.claim(player, "bonus")), false)
		for i, g in profile.daily.goals do
			G.record(player, eventOf(g), g.target, g.param)
			assert(G.claim(player, i))
		end
		local before = log.money
		local ok, msg = G.claim(player, "bonus")
		T.eq(ok, true, msg)
		T.ok(log.money > before)
		T.eq(profile.daily.streak, 1)
		-- a player without a profile can't claim or record
		local stranger = { UserId = 1 }
		T.eq((G.claim(stranger, 1)), false)
		G.record(stranger, "order", 1)
		G.record(nil, "order", 1)
	end,

	["a new day rolls goals and auto-pays leftovers"] = function()
		local G, player, profile, log, advanceDays = setup()
		G.ensure(player)
		local g = profile.daily.goals[2]
		G.record(player, eventOf(g), g.target, g.param)
		advanceDays(1)
		G.ensure(player)
		T.eq(profile.daily.day, DAY0 + 1)
		T.eq(log.money, g.cash, "unclaimed reward not paid at rollover")
		for _, ng in profile.daily.goals do
			T.eq(ng.progress, 0)
		end
	end,

	["stateFor sends the view only once goals exist"] = function()
		local G, player = setup()
		T.eq(next(G.stateFor(player)), nil, "state before goals were rolled")
		G.ensure(player)
		local st = G.stateFor(player)
		T.eq(#st.goals.goals, Challenges.GoalsPerDay)
		T.ok(st.goals.resetsAt > G.clock())
		T.eq(next(G.stateFor({ UserId = 7 })), nil)
	end,
}
