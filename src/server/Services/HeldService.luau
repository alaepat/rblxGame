--!strict
-- What each player is carrying (one item at a time, like a real kitchen).
-- The item table is authoritative on the server; a visual model is welded in
-- front of the character so everyone can see it.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FoodVisuals = require(Shared.Food.FoodVisuals)
local FoodLogic = require(Shared.Food.FoodLogic)

type Item = { [string]: any }

local HeldService = {}
local S: any
local held: { [Player]: Item } = {}
local visuals: { [Player]: Model } = {}

local HOLD_OFFSET = CFrame.new(0, 0.2, -1.7)

function HeldService.init(services)
	S = services
end

local function clearVisual(player: Player)
	local v = visuals[player]
	if v then
		v:Destroy()
		visuals[player] = nil
	end
end

local function attachVisual(player: Player)
	clearVisual(player)
	local item = held[player]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not item or not hrp then
		return
	end
	local model = FoodVisuals.build(item)
	model.Name = "HeldItem"
	local root = model.PrimaryPart :: BasePart
	model:PivotTo(hrp.CFrame * HOLD_OFFSET)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			if p ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = root
	weld.Parent = root
	model.Parent = char
	visuals[player] = model
end

function HeldService.get(player: Player): Item?
	return held[player]
end

function HeldService.isEmpty(player: Player): boolean
	return held[player] == nil
end

function HeldService.set(player: Player, item: Item?)
	held[player] = item
	attachVisual(player)
	player:SetAttribute("Holding", item and FoodLogic.describe(item) or "")
	S.ProgressService.push(player)
	S.StationService.refreshFor(player)
end

-- Re-render after mutating the held table in place.
function HeldService.changed(player: Player)
	HeldService.set(player, held[player])
end

function HeldService.take(player: Player): Item?
	local item = held[player]
	if item then
		HeldService.set(player, nil)
	end
	return item
end

function HeldService.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			attachVisual(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		clearVisual(p)
		held[p] = nil
	end)
	S.ProgressService.addStateProvider(function(player)
		local item = held[player]
		return { held = item, heldText = item and FoodLogic.describe(item) or nil, heldRecipe = FoodLogic.identify(item) }
	end)
end

return HeldService
