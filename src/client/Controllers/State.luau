--!strict
-- Latest server snapshot for this player + change signal.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local State = {}
State.data = {} :: { [string]: any }
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

Net.event("State").OnClientEvent:Connect(function(snap)
	State.data = snap
	changed:Fire(snap)
end)

function State.get(key: string): any
	return State.data[key]
end

return State
