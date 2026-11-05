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
--   ServerStorage.DevCommand:Invoke("day", 12)          -- jump the shift clock to 12:00 (lunch rush)
--   ServerStorage.DevCommand:Invoke("day", "close")     -- jump to closing time
--   ServerStorage.DevCommand:Invoke("day", "end")       -- end the day now (summary)
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
		if arg == "reset" then
			profile.daily = nil
			S.GoalService.ensure(player)
			return "goals rerolled"
		end
		S.GoalService.ensure(player)
		for _, g in profile.daily.goals do
			g.progress = g.target
		end
		S.ProgressService.push(player)
		return "goals finished: " .. #profile.daily.goals
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
