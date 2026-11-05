--!strict
-- Client-only cosmetic animation: spins anything with a `Spin` attribute
-- (doner meat cones). Runs locally so the server does no CFrame work.

local RunService = game:GetService("RunService")

local Effects = {}

type Spinner = { model: Model, speed: number }
local spinners: { [Model]: Spinner } = {}

local function track(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("Spin") and not spinners[inst] then
		spinners[inst] = { model = inst, speed = inst:GetAttribute("Spin") :: number }
	end
end

function Effects.start()
	for _, d in workspace:GetDescendants() do
		track(d)
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(track, d)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		for m, s in spinners do
			if not m.Parent then
				spinners[m] = nil
			else
				local skewer = m:FindFirstChild("Skewer") :: BasePart?
				if skewer then
					local center = CFrame.new(skewer.Position)
					local rot = CFrame.Angles(0, dt * s.speed, 0)
					for _, p in m:GetChildren() do
						if p:IsA("BasePart") and p.Name == "Meat" then
							p.CFrame = center * rot * (center:Inverse() * p.CFrame)
						end
					end
				end
			end
		end
	end)
end

return Effects
