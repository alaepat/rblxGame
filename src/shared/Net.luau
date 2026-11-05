--!strict
-- Single place that defines every remote. The server creates them; clients wait.
--
-- Server -> Client (RemoteEvent):
--   State(snapshot)            full player snapshot (money, level, stock, orders, held...)
--   Notify(text, kind)         toast message  kind: "info" | "good" | "bad"
--   LevelUp(payload)           { level, unlocks, reward }
--   OpenPOS(payload)           { customerName, says, menu = {recipeId} }
--   OpenManager(tab)           open the office computer UI on a tab
--   Sound(name)                play a UI sound locally
-- Client -> Server (RemoteFunction):
--   SubmitOrder(recipeIds)     -> ok, message
--   CancelPOS()                -> nil
--   BuyUpgrade(id)             -> ok, message
--   OrderSupplies({id=qty})    -> ok, message
--   EmergencyDelivery()        -> ok, message
--   ToggleOpen()               -> ok, message
--   ClaimGoal(index | "bonus") -> ok, message   (daily goals)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = { "State", "Notify", "LevelUp", "OpenPOS", "OpenManager", "Sound" }
local FUNCTIONS = { "SubmitOrder", "CancelPOS", "BuyUpgrade", "OrderSupplies", "EmergencyDelivery", "ToggleOpen", "ClaimGoal" }

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, n in EVENTS do
		local e = Instance.new("RemoteEvent")
		e.Name = n
		e.Parent = folder
	end
	for _, n in FUNCTIONS do
		local f = Instance.new("RemoteFunction")
		f.Name = n
		f.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
