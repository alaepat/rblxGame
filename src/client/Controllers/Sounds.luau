--!strict
-- UI / gameplay sound effects. Fill Shared.Config.SoundIds with licensed audio.
-- Missing ids are simply silent, so the game never errors on audio.

local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SoundIds = require(Shared.Config.SoundIds)

local Sounds = {}
local cache: { [string]: Sound } = {}

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
		s.Volume = 0.5
		s.Parent = SoundService
		cache[name] = s
	end
	SoundService:PlayLocalSound(s)
end

return Sounds
