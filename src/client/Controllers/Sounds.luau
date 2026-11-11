--!strict
-- UI / gameplay sound effects. Fill Shared.Config.SoundIds with licensed audio.
-- Missing ids are simply silent, so the game never errors on audio.

local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SoundIds = require(Shared.Config.SoundIds)

local Sounds = {}
local cache: { [string]: Sound } = {}

-- Loudness per sound (default 0.5): UI ticks quiet, rewards a bit louder.
local VOLUME: { [string]: number } = {
	Click = 0.35,
	Place = 0.35,
	Pickup = 0.4,
	Topping = 0.6,
	Sauce = 0.4,
	Pour = 0.45,
	Register = 0.35,
	Trash = 0.4,
	Clean = 0.45,
	Bell = 0.35,
	Truck = 0.3,
	Angry = 0.5,
	Error = 0.4,
	Cash = 0.45,
	Ding = 0.5,
	Serve = 0.5,
	GoalDone = 0.55,
	Upgrade = 0.55,
	LevelUp = 0.6,
}

function Sounds.play(name: string)
	local id = SoundIds[name]
	if not id or id == "" then
		return
	end
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "SFX_" .. name
		s.SoundId = id
		s.Volume = VOLUME[name] or 0.5
		s.Parent = SoundService
		cache[name] = s
	end
	SoundService:PlayLocalSound(s)
end

return Sounds
