--!strict
-- Rubbish left by customers + messy prep counters.
-- Cleanliness (0-100) feeds tips and review stars in CustomerService.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local FoodVisuals = require(Shared.Food.FoodVisuals)

local CleaningService = {}
local S: any
local rng = Random.new()

function CleaningService.init(services)
	S = services
end

local function cleanPrompt(parent: BasePart, text: string, onClean: (Player) -> ())
	local p = Instance.new("ProximityPrompt")
	p.ObjectText = "Mess"
	p.ActionText = text
	p.HoldDuration = 0 -- hold prompts don't complete with the custom interaction UI
	p.MaxActivationDistance = GameConfig.PromptDistance
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	p.Parent = parent
	p.Triggered:Connect(onClean)
	return p
end

function CleaningService.cleanliness(plot): number
	local trash = #(plot.trash or {})
	local dirty = 0
	for _, st in plot.stations or {} do
		if st.dirty then
			dirty += 1
		end
	end
	return math.clamp(100 - trash * GameConfig.CleanlinessPerTrash - dirty * GameConfig.CleanlinessPerDirtyCounter, 0, 100)
end

local function rewardClean(player: Player)
	local profile = S.DataService.get(player)
	profile.stats.cleaned = (profile.stats.cleaned or 0) + 1
	S.ProgressService.addXP(player, GameConfig.CleanXP)
	S.ProgressService.sound(player, "Clean")
	S.ProgressService.push(player)
end

function CleaningService.spawnTrash(plot)
	plot.trash = plot.trash or {}
	if #plot.trash >= GameConfig.MaxTrash or not plot.model then
		return
	end
	local spots = plot.model:FindFirstChild("TrashSpots")
	if not spots then
		return
	end
	local list = spots:GetChildren()
	if #list == 0 then
		return
	end
	local spot = list[rng:NextInteger(1, #list)] :: BasePart
	local m = Instance.new("Model")
	m.Name = "Trash"
	local kind = rng:NextInteger(1, 3)
	local base: BasePart
	if kind == 1 then
		-- crumpled napkin + cup
		base = FoodVisuals.newPart(m, "Napkin", Vector3.new(0.7, 0.35, 0.6), CFrame.new(), Color3.fromRGB(245, 245, 240), nil, Enum.PartType.Ball)
		FoodVisuals.newPart(m, "Cup", Vector3.new(0.9, 0.5, 0.5), CFrame.new(0.7, 0.05, 0.3) * CFrame.Angles(0, 0.6, 0), Color3.fromRGB(250, 250, 250), nil, Enum.PartType.Cylinder)
	elseif kind == 2 then
		-- dropped pizza crust
		base = FoodVisuals.newPart(m, "Crust", Vector3.new(0.9, 0.12, 0.35), CFrame.new() * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(226, 168, 92))
		FoodVisuals.newPart(m, "Sauce", Vector3.new(0.6, 0.13, 0.25), CFrame.new(0.1, 0.01, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(196, 40, 28))
	else
		-- spill
		base = FoodVisuals.newPart(m, "Spill", Vector3.new(0.04, 2.2, 1.6), CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 40, 25), Enum.Material.Glass, Enum.PartType.Cylinder)
		base.Transparency = 0.25
	end
	base.CanQuery = true
	m.PrimaryPart = base
	m:PivotTo(spot.CFrame * CFrame.new(rng:NextNumber(-1, 1), 0.15, rng:NextNumber(-1, 1)))
	m.Parent = plot.model
	table.insert(plot.trash, m)
	cleanPrompt(base, kind == 3 and "Mop up" or "Pick up rubbish", function(player)
		if player ~= plot.owner then
			return
		end
		local i = table.find(plot.trash, m)
		if i then
			table.remove(plot.trash, i)
			m:Destroy()
			rewardClean(player)
		end
	end)
	if plot.owner then
		S.ProgressService.push(plot.owner)
	end
end

function CleaningService.makeDirty(st)
	st.dirty = true
	local part: BasePart = st.part
	local mess = Instance.new("Model")
	mess.Name = "Mess"
	local splat = FoodVisuals.newPart(mess, "Splat", Vector3.new(0.03, 1.2, 1.2), CFrame.new(), Color3.fromRGB(196, 60, 35), nil, Enum.PartType.Cylinder)
	FoodVisuals.newPart(mess, "Flour", Vector3.new(0.03, 0.9, 0.9), CFrame.new(0.005, 0.4, 0.5), Color3.fromRGB(250, 246, 236), nil, Enum.PartType.Cylinder)
	splat.CanQuery = true
	mess.PrimaryPart = splat
	mess:PivotTo(part.CFrame * CFrame.new(part.Size.X * 0.32, part.Size.Y / 2 + 0.02, part.Size.Z * 0.25) * CFrame.Angles(0, 0, math.rad(90)))
	mess.Parent = part
	local plot = st.plot
	cleanPrompt(splat, "Wipe counter", function(player)
		if player ~= plot.owner then
			return
		end
		st.dirty = false
		st.uses = 0
		mess:Destroy()
		rewardClean(player)
	end)
	if plot.owner then
		S.ProgressService.notify(plot.owner, "A prep counter is getting messy. Wipe it down!", "info")
		S.ProgressService.push(plot.owner)
	end
end

function CleaningService.setupPlot(plot)
	plot.trash = {}
end

function CleaningService.cleanupPlot(plot)
	plot.trash = {}
end

function CleaningService.start() end

return CleaningService
