--!strict
-- Purchasing upgrades and making them visible in the restaurant.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local FoodLogic = require(Shared.Food.FoodLogic)
local Net = require(Shared.Net)

local UpgradeService = {}
local S: any

function UpgradeService.init(services)
	S = services
end

function UpgradeService.has(player: Player, id: string): boolean
	local profile = S.DataService.get(player)
	return profile ~= nil and profile.upgrades[id] == true
end

-- Sum of an effect over every owned upgrade.
function UpgradeService.effect(player: Player, effect: string): number
	local profile = S.DataService.get(player)
	if not profile then
		return 0
	end
	local total = 0
	for id in profile.upgrades do
		local u = Upgrades.get(id)
		if u and u.effects and u.effects[effect] then
			total += u.effects[effect]
		end
	end
	return total
end

-- Show / hide upgrade models in a plot to match ownership.
function UpgradeService.applyPlot(plot)
	local player = plot.owner
	local model = plot.model
	local hidden = plot.hidden
	if not player or not model or not hidden then
		return
	end
	local profile = S.DataService.get(player)
	local owned = profile and profile.upgrades or {}
	-- Pull everything back first so the check is order-independent.
	local candidates = {}
	for _, d in model:GetDescendants() do
		if d:GetAttribute("UpgradeId") or d:GetAttribute("HideWhen") then
			table.insert(candidates, d)
		end
	end
	for _, d in hidden:GetChildren() do
		table.insert(candidates, d)
	end
	-- rules nested inside a hidden model (e.g. the east neon sign inside the
	-- neon decor, hidden again by the annex) must be checked too
	for _, d in hidden:GetDescendants() do
		if d.Parent ~= hidden and (d:GetAttribute("UpgradeId") or d:GetAttribute("HideWhen")) then
			table.insert(candidates, d)
		end
	end
	for _, d in candidates do
		local need = d:GetAttribute("UpgradeId")
		local hideWhen = d:GetAttribute("HideWhen")
		local visible = true
		if need and not owned[need] then
			visible = false
		end
		if hideWhen and owned[hideWhen] then
			visible = false
		end
		if visible then
			if d.Parent == hidden then
				local parentPath = d:GetAttribute("HomeParent")
				-- its home may itself be hidden: then it goes back inside it and stays hidden with it
				local home = parentPath and (model:FindFirstChild(parentPath, true) or hidden:FindFirstChild(parentPath, true)) or model
				d.Parent = home
			end
		else
			if d.Parent ~= hidden then
				d:SetAttribute("HomeParent", (d.Parent :: Instance).Name)
				d.Parent = hidden
			end
		end
	end
end

function UpgradeService.buy(player: Player, id: any): (boolean, string)
	if type(id) ~= "string" then
		return false, "Invalid upgrade"
	end
	local u = Upgrades.get(id)
	local profile = S.DataService.get(player)
	local plot = S.PlotService.get(player)
	if not u or not profile or not plot then
		return false, "Invalid upgrade"
	end
	if profile.upgrades[id] then
		return false, "Already owned"
	end
	if profile.level < u.level then
		return false, "Reach level " .. u.level .. " first"
	end
	if u.requires and not profile.upgrades[u.requires] then
		local req = Upgrades.get(u.requires)
		return false, "Requires " .. (req and req.name or u.requires)
	end
	if not S.ProgressService.spend(player, u.cost) then
		return false, ("You need $%d"):format(u.cost)
	end
	profile.upgrades[id] = true
	profile.unlockedRecipes = FoodLogic.unlockedRecipes(profile.level, profile.upgrades)
	UpgradeService.applyPlot(plot)
	S.StationService.refreshPlot(plot)
	S.PlotService.onLevelChanged(player)
	S.ProgressService.addXP(player, 10)
	S.ProgressService.sound(player, "Upgrade")
	S.ProgressService.push(player)
	return true, u.name .. " installed!"
end

function UpgradeService.start()
	Net.func("BuyUpgrade").OnServerInvoke = function(player, id)
		return UpgradeService.buy(player, id)
	end
end

return UpgradeService
