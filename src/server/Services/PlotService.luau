--!strict
-- Gives every player their own restaurant plot. The restaurant is generated
-- by RestaurantBuilder at the plot's origin, then systems hook into it.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local World = script.Parent.Parent.World
local WorldBuilder = require(World.WorldBuilder)
local RestaurantBuilder = require(World.RestaurantBuilder)

export type Plot = {
	index: number,
	origin: CFrame,
	owner: Player?,
	model: Model?,
	hidden: Folder?,
	open: boolean,
	[string]: any,
}

local PlotService = {}
local S: any
PlotService.Plots = {} :: { Plot }
local byPlayer: { [Player]: Plot } = {}

function PlotService.init(services)
	S = services
end

function PlotService.get(player: Player): Plot?
	return byPlayer[player]
end

function PlotService.ownerOf(inst: Instance): (Player?, Plot?)
	for _, plot in PlotService.Plots do
		if plot.model and inst:IsDescendantOf(plot.model) then
			return plot.owner, plot
		end
	end
	return nil, nil
end

-- Local position helper (plot space -> world).
function PlotService.toWorld(plot: Plot, v: Vector3): Vector3
	return plot.origin:PointToWorldSpace(v)
end

function PlotService.node(plot: Plot, name: string): BasePart?
	local nodes = plot.model and plot.model:FindFirstChild("Nodes")
	return nodes and nodes:FindFirstChild(name) :: BasePart?
end

local function teleportHome(player: Player, plot: Plot)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local spawnNode = PlotService.node(plot, "PlayerSpawn")
	if hrp and spawnNode then
		char:PivotTo(spawnNode.CFrame + Vector3.new(0, 3, 0))
	end
end

local function claim(player: Player)
	if byPlayer[player] then
		return
	end
	local plot: Plot? = nil
	for _, p in PlotService.Plots do
		if not p.owner then
			plot = p
			break
		end
	end
	if not plot then
		S.ProgressService.notify(player, "Server is full of restaurants! Try another server.", "bad")
		return
	end
	local thePlot = plot :: Plot
	thePlot.owner = player
	byPlayer[player] = thePlot
	local hidden = Instance.new("Folder")
	hidden.Name = "HiddenUpgrades_" .. thePlot.index
	hidden.Parent = ServerStorage
	thePlot.hidden = hidden
	local model = RestaurantBuilder.build(thePlot.origin, player.DisplayName)
	model.Name = "Restaurant_" .. thePlot.index
	model:SetAttribute("OwnerUserId", player.UserId)
	thePlot.model = model
	thePlot.open = false
	-- Systems that set up per-plot state BEFORE parenting (keeps prompts consistent).
	S.StationService.setupPlot(thePlot)
	S.UpgradeService.applyPlot(thePlot)
	model.Parent = workspace:WaitForChild("Restaurants")
	S.CustomerService.setupPlot(thePlot)
	S.SupplyService.setupPlot(thePlot)
	S.CleaningService.setupPlot(thePlot)

	local spawnNode = PlotService.node(thePlot, "PlayerSpawn")
	if spawnNode then
		local sp = Instance.new("SpawnLocation")
		sp.Name = "OwnerSpawn"
		sp.Anchored = true
		sp.Size = Vector3.new(4, 0.2, 4)
		sp.Transparency = 1
		sp.CanCollide = false
		sp.Neutral = true
		sp.Enabled = true
		sp.Duration = 0
		sp.CFrame = spawnNode.CFrame
		sp.Parent = model
		player.RespawnLocation = sp
	end
	PlotService.onLevelChanged(player)
	teleportHome(player, thePlot)
	-- kept on the plot and disconnected in release() so a re-claim can't stack handlers
	thePlot.charConn = player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if byPlayer[player] == thePlot then
			teleportHome(player, thePlot)
		end
	end)
	S.ProgressService.notify(player, "Welcome to your Pizza Planet! Flip the OPEN sign by the door when you're ready.", "good")
	S.ProgressService.push(player)
end

local function release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	if plot.charConn then
		plot.charConn:Disconnect()
		plot.charConn = nil
	end
	S.CustomerService.cleanupPlot(plot)
	S.StationService.cleanupPlot(plot)
	S.SupplyService.cleanupPlot(plot)
	S.CleaningService.cleanupPlot(plot)
	if plot.model then
		plot.model:Destroy()
	end
	if plot.hidden then
		plot.hidden:Destroy()
	end
	plot.model = nil
	plot.hidden = nil
	plot.owner = nil
	plot.open = false
	for k in plot do
		if k ~= "index" and k ~= "origin" and k ~= "open" then
			plot[k] = nil
		end
	end
end

function PlotService.onLevelChanged(player: Player)
	local plot = byPlayer[player]
	local profile = S.DataService.get(player)
	if plot and plot.model and profile then
		S.StationService.refreshPlot(plot)
		RestaurantBuilder.updateMenuBoard(plot.model, profile.level, profile.upgrades)
	end
end

function PlotService.start()
	local origins = WorldBuilder.build()
	for i, cf in origins do
		table.insert(PlotService.Plots, { index = i, origin = cf, owner = nil, open = false })
	end
	S.DataService.onLoaded(function(player)
		claim(player)
	end)
	Players.PlayerRemoving:Connect(release)
end

return PlotService
