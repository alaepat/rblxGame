--!strict
-- Latest server snapshot for this player + change signal.
-- The server sends deltas (Shared.StateDelta): only changed top-level keys,
-- merged into State.data here. Changed still fires with the whole snapshot.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local StateDelta = require(Shared.StateDelta)

local State = {}
State.data = {} :: { [string]: any }
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

Net.event("State").OnClientEvent:Connect(function(delta)
	-- a fresh table each update, so readers holding the old one aren't mutated
	State.data = StateDelta.apply(table.clone(State.data), delta)
	changed:Fire(State.data)
end)

function State.get(key: string): any
	return State.data[key]
end

return State
