--!strict
-- Studio-only test hooks. Creates ServerStorage.DevCommand (BindableFunction)
-- so tests run from the Studio command bar / MCP can set up state quickly:
--   ServerStorage.DevCommand:Invoke("level", 8)
--   ServerStorage.DevCommand:Invoke("money", 5000)
--   ServerStorage.DevCommand:Invoke("stock")            -- fill all stock
--   ServerStorage.DevCommand:Invoke("upgrade", "kebab_station")
--   ServerStorage.DevCommand:Invoke("trash")            -- spawn rubbish
--   ServerStorage.DevCommand:Invoke("info")
--   ServerStorage.DevCommand:Invoke("goals")            -- finish every daily goal
--   ServerStorage.DevCommand:Invoke("goals", "reset")   -- roll a fresh set of goals
--   ServerStorage.DevCommand:Invoke("goals", "weekly")  -- finish the weekly challenge
--   ServerStorage.DevCommand:Invoke("goals", "rush")    -- goal 1 becomes a goal of that template (any Challenges id)
--   ServerStorage.DevCommand:Invoke("day", 12)          -- jump the shift clock to 12:00 (lunch rush)
--   ServerStorage.DevCommand:Invoke("day", "close")     -- jump to closing time
--   ServerStorage.DevCommand:Invoke("day", "end")       -- end the day now (summary)
--   ServerStorage.DevCommand:Invoke("queue")            -- front customer's wish + open orders (for test bots)
--   ServerStorage.DevCommand:Invoke("traffic")          -- current customer-traffic multiplier (rush x level)
--   ServerStorage.DevCommand:Invoke("theme", "space")   -- buy (cost applies) + switch dining theme
--   ServerStorage.DevCommand:Invoke("event", "order")   -- record one game event (as if an order finished)
--   ServerStorage.DevCommand:Invoke("mastery", "cheese_pizza") -- jump a recipe to its next mastery tier
--   ServerStorage.DevCommand:Invoke("mastery")          -- list mastery serve counts
--   ServerStorage.DevCommand:Invoke("staff")            -- hire the cleaner, cashier and cook for free ("staff", "fire" removes them)
--   ServerStorage.DevCommand:Invoke("oven", 2)          -- almost-baked pizza in 2 ovens; ("shelf", "fill"/"clear"); ("boxes", 0) sets pizza-box stock
-- Never active in live servers.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ingredients = require(Shared.Config.Ingredients)
local Levels = require(Shared.Config.Levels)
local FoodLogic = require(Shared.Food.FoodLogic)

local DevService = {}
local S: any

function DevService.init(services)
	S = services
end

local function run(cmd: string, arg: any): any
	local player = Players:GetPlayers()[1]
	if not player then
		return "no player"
	end
	local profile = S.DataService.get(player)
	local plot = S.PlotService.get(player)
	if not profile or not plot then
		return "no profile/plot yet"
	end
	if cmd == "level" then
		local target = math.clamp(tonumber(arg) or 1, 1, Levels.MaxLevel)
		local need = 0
		for l = profile.level, target - 1 do
			need += Levels.xpToNext(l)
		end
		S.ProgressService.addXP(player, need - profile.xp + 1)
		return "level " .. profile.level
	elseif cmd == "money" then
		S.ProgressService.addMoney(player, tonumber(arg) or 1000)
		return "money " .. profile.money
	elseif cmd == "oven" then
		-- put an almost-baked cheese pizza in the first N live ovens (cook staff tests)
		local n, placed = tonumber(arg) or 1, 0
		for _, st in plot.stations or {} do
			if placed < n and st.kind == "Oven" and not st.item and st.part:IsDescendantOf(workspace) then
				S.StationService.setItem(st, { kind = "pizza", sauce = "tomato_sauce", toppings = { "mozzarella" }, cook = 0.85 })
				S.StationService.refreshStation(st)
				placed += 1
			end
		end
		return "pizzas in ovens: " .. placed
	elseif cmd == "shelf" then
		-- "fill": a boxed pizza on every free heat shelf slot; "clear": empty them
		local changed = 0
		for _, st in plot.stations or {} do
			if st.kind == "HeatShelf" and st.part:IsDescendantOf(workspace) then
				if arg == "clear" and st.item then
					S.StationService.setItem(st, nil)
					changed += 1
				elseif arg ~= "clear" and not st.item then
					S.StationService.setItem(st, { kind = "pizza", sauce = "tomato_sauce", toppings = { "mozzarella" }, cook = 1, boxed = true })
					changed += 1
				end
				S.StationService.refreshStation(st)
			end
		end
		return "heat shelf slots changed: " .. changed
	elseif cmd == "boxes" then
		profile.stock.pizza_box = tonumber(arg) or 0
		S.ProgressService.push(player)
		return "pizza boxes: " .. profile.stock.pizza_box
	elseif cmd == "stock" then
		for _, ing in Ingredients.List do
			profile.stock[ing.id] = S.ProgressService.capacity(player, ing.id)
		end
		S.ProgressService.push(player)
		S.StationService.refreshPlot(plot)
		return "stock filled"
	elseif cmd == "upgrade" then
		local ok, msg = S.UpgradeService.buy(player, arg)
		return tostring(ok) .. " " .. msg
	elseif cmd == "trash" then
		S.CleaningService.spawnTrash(plot)
		return "trash " .. #plot.trash
	elseif cmd == "open" then
		S.CustomerService.setOpen(plot, true)
		return "open"
	elseif cmd == "impatient" then
		-- every waiting customer runs out of patience on the next tick
		for _, c in plot.customers or {} do
			c.patience = 0.1
		end
		return "customers " .. #(plot.customers or {})
	elseif cmd == "dirty" then
		for _, st in plot.stations do
			if st.kind == "PizzaBoard" and not st.dirty then
				S.CleaningService.makeDirty(st)
				return "dirtied " .. st.part:GetFullName()
			end
		end
		return "nothing to dirty"
	elseif cmd == "broke" then
		S.ProgressService.addMoney(player, -profile.money + 5)
		return "money " .. profile.money
	elseif cmd == "goals" then
		local Challenges = require(Shared.Config.Challenges)
		if type(arg) == "string" and Challenges.ById[arg] then
			-- put a goal of this template in slot 1 (test a specific goal type)
			local DailyGoals = require(Shared.Goals.DailyGoals)
			S.GoalService.ensure(player)
			local t = Challenges.ById[arg]
			local reward = DailyGoals.goalReward(profile.level, t.difficulty)
			profile.daily.goals[1] = { id = t.id, param = t.param, target = DailyGoals.target(t, profile.level), progress = 0, cash = reward.cash, xp = reward.xp, claimed = false }
			S.ProgressService.push(player)
			return "goal 1 is now " .. DailyGoals.describe(profile.daily.goals[1])
		end
		if arg == "weekly" then
			S.GoalService.ensure(player)
			local w = profile.daily.weekly and profile.daily.weekly.goal
			if not w then
				return "no weekly"
			end
			w.progress = w.target
			S.ProgressService.push(player)
			return "weekly finished: " .. w.id
		end
		if arg == "reset" then
			profile.daily = nil
			S.GoalService.ensure(player)
			return "goals rerolled"
		elseif arg == "info" then
			local d = profile.daily
			if not d then
				return "no daily"
			end
			local t = {}
			for _, g in d.goals do
				table.insert(t, g.id .. " " .. g.progress .. "/" .. g.target .. (g.claimed and " claimed" or ""))
			end
			return ("day %d streak %d bonus %s | %s"):format(d.day, d.streak, tostring(d.bonusClaimed), table.concat(t, ", "))
		end
		S.GoalService.ensure(player)
		for _, g in profile.daily.goals do
			g.progress = g.target
		end
		S.ProgressService.push(player)
		return "goals finished: " .. #profile.daily.goals
	elseif cmd == "staff" then
		-- every staff upgrade, including second hires
		for _, u in require(Shared.Config.Upgrades).List do
			if u.staff then
				profile.upgrades[u.id] = if arg == "fire" then nil else true
			end
		end
		S.UpgradeService.applyPlot(plot)
		S.ProgressService.push(player)
		return if arg == "fire" then "staff fired" else "staff hired (cleaner, cashier, cook)"
	elseif cmd == "mastery" then
		local Mastery = require(Shared.Mastery.Mastery)
		local counts = S.MasteryService.stateFor(player).mastery or {}
		local recipe = type(arg) == "string" and require(Shared.Config.Recipes).get(arg)
		if not recipe then
			local t = {}
			for id, n in counts do
				table.insert(t, id .. " " .. n)
			end
			return "mastery: " .. (if #t > 0 then table.concat(t, ", ") else "none (pass a recipe id to level one up)")
		end
		local v = Mastery.view(recipe, counts[arg])
		if not v.nextAt then
			return arg .. " is already gold"
		end
		S.MasteryService.addServes(player, arg, v.nextAt - v.count)
		return ("%s now %d serves (tier %d)"):format(arg, v.nextAt, v.tier + 1)
	elseif cmd == "day" then
		if arg == "end" then
			if not plot.shift then
				return "no shift running"
			end
			if plot.open then
				S.CustomerService.setOpen(plot, false)
			end
			S.ShiftService.finish(plot)
			return "day ended"
		end
		local hour = if arg == "close" then S.ShiftService.Config.CloseHour else tonumber(arg)
		if not hour then
			return "usage: day <hour> | close | end"
		end
		return S.ShiftService.devJump(plot, hour)
	elseif cmd == "event" then
		-- feed a game event through GoalService (goals, day stats, rush goals)
		-- "name" or "name:param", e.g. "serve_recipe:cheese_pizza"
		local name, param = string.match(tostring(arg), "^([^:]+):?(.*)$")
		S.GoalService.record(player, name, 1, if param ~= "" then param else nil)
		return "recorded " .. tostring(arg)
	elseif cmd == "theme" then
		local ok, msg = S.ThemeService.choose(player, arg)
		return (ok and "ok: " or "fail: ") .. msg
	elseif cmd == "traffic" then
		return ("traffic x%.2f at level %d"):format(S.ShiftService.traffic(plot), profile.level)
	elseif cmd == "queue" then
		-- what the customer at the register wants, and every open order
		local front = S.CustomerService.frontCustomer(plot)
		local orders = {}
		for _, o in plot.orders or {} do
			local items = {}
			for _, e in o.items do
				table.insert(items, e.recipe .. (if e.done then "*" else ""))
			end
			table.insert(orders, "#" .. o.number .. " " .. table.concat(items, "+"))
		end
		return {
			want = front and front.want or nil,
			queue = plot.queue and #plot.queue or 0,
			customers = #(plot.customers or {}),
			orders = orders,
			money = profile.money,
		}
	elseif cmd == "info" then
		local up = {}
		for id in profile.upgrades do
			table.insert(up, id)
		end
		return ("level %d xp %d money %.2f upgrades [%s] recipes %d orders %d customers %d"):format(
			profile.level, profile.xp, profile.money, table.concat(up, ","),
			#FoodLogic.unlockedRecipes(profile.level, profile.upgrades), #(plot.orders or {}), #(plot.customers or {}))
	end
	return "unknown command"
end

function DevService.start()
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "DevCommand"
	f.OnInvoke = function(cmd, arg)
		local ok, res = pcall(run, cmd, arg)
		return if ok then res else ("error: " .. tostring(res))
	end
	f.Parent = ServerStorage
end

return DevService
