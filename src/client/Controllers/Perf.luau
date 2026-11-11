--!strict
-- Client render budget (optimisation pass). CastShadow is a render-only
-- property, so trimming it here changes nothing on the server or for physics.
--  * Flat ground pieces (roads, pavements, road markings, floor tiles, rugs:
--    under 0.35 studs tall, lying flat, wider than 2 studs) cast no visible
--    shadow but still cost a shadow-map draw each: shadows off.
--  * Tiny props (smaller than ~1 stud across): shadows off.
--  * Characters (anything inside a model with a Humanoid) are left alone.
-- Covers parts added later (upgrades, deliveries, new restaurants) too.
-- Street lamps only light up at night: Controllers/DayExtras.

local Perf = {}

local FLAT_HEIGHT = 0.35
local FLAT_MIN_WIDTH = 2
local TINY = 1.2

Perf.trimmed = 0

local function inCharacter(p: Instance): boolean
	local m = p:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then
			return true
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- Pure rule, exposed for the spec.
function Perf.shadowless(size: Vector3, upY: number): boolean
	local flat = size.Y <= FLAT_HEIGHT and math.abs(upY) > 0.95 and math.max(size.X, size.Z) > FLAT_MIN_WIDTH
	return flat or size.Magnitude < TINY
end

local function trim(d: Instance)
	if d:IsA("BasePart") and d.CastShadow and Perf.shadowless(d.Size, d.CFrame.UpVector.Y) and not inCharacter(d) then
		d.CastShadow = false
		Perf.trimmed += 1
	end
end

function Perf.start()
	task.spawn(function()
		local n = 0
		for _, d in workspace:GetDescendants() do
			trim(d)
			n += 1
			if n % 2000 == 0 then
				task.wait() -- don't hitch the first frames
			end
		end
	end)
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			task.defer(trim, d) -- after the builder has set its size / CFrame
		end
	end)
end

return Perf
