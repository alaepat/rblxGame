--!strict
-- Client bootstrap.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Controllers = script.Parent:WaitForChild("Controllers")
local Sounds = require(Controllers:WaitForChild("Sounds"))
local Notifications = require(Controllers:WaitForChild("Notifications"))
local Interaction = require(Controllers:WaitForChild("Interaction"))
local HUD = require(Controllers:WaitForChild("HUD"))
local POS = require(Controllers:WaitForChild("POS"))
local Manager = require(Controllers:WaitForChild("Manager"))
local Effects = require(Controllers:WaitForChild("Effects"))
local Goals = require(Controllers:WaitForChild("Goals"))

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local player = Players.LocalPlayer
player.CameraMaxZoomDistance = 18

Notifications.start()
Interaction.start()
HUD.start()
POS.start()
Manager.start()
Effects.start()
Goals.start()

HUD.openRecipes = function()
	Manager.open("Recipes", false)
end

Net.event("Sound").OnClientEvent:Connect(function(name)
	Sounds.play(name)
end)

print("[Pizza Planet] client started")
