--!strict
-- Client-only procedural poses, layered on top of the normal animations by
-- adding an eased offset to each joint's animated .Transform every frame:
--  * Players carrying something (Player attribute "Holding" ~= "") hold both
--    arms forward under the item.
--  * Customers standing in the queue / waiting area (model attribute "State")
--    do small idles every few seconds: look around, check a phone, shift weight.
--  * Staff NPCs (Staff_<role>) carry pizzas with the carry pose, wipe / type /
--    fold boxes from their "Activity" attribute, and idle (look, shift weight,
--    fold arms) while waiting for work.
-- Every client poses every character, so everyone sees the same thing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Poses = {}

local EASE = 8 -- how fast poses blend in/out (per second)

-- Works for classic Motor6D joints and the newer AnimationConstraint joints:
-- both expose .Transform, which the Animator rewrites every frame. We apply
-- our offset after the animation step (PreSimulation). If a joint has no
-- animation on it, its Transform isn't rewritten, so we remember what we
-- wrote and start again from the animation's own value to avoid stacking.
type Joint = { inst: any, lastWritten: CFrame?, lastBase: CFrame }

local function jointFor(part: Instance, name: string): Joint?
	local j = part:FindFirstChild(name)
	if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
		return { inst = j, lastWritten = nil, lastBase = CFrame.new() }
	end
	return nil
end
type Rig = { joints: { [string]: Joint }, current: { [string]: CFrame } }

local rigs: { [Model]: Rig } = {}

local JOINTS = {
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	Neck = "Head",
	Waist = "UpperTorso",
}

local function rigOf(model: Model): Rig?
	local r = rigs[model]
	if r then
		return r
	end
	local joints = {}
	for name, partName in JOINTS do
		local part = model:FindFirstChild(partName)
		local j = part and jointFor(part, name)
		if j then
			joints[name] = j
		end
	end
	if not joints.RightShoulder or not joints.LeftShoulder then
		return nil -- not an R15 rig: leave it alone
	end
	r = { joints = joints, current = {} }
	rigs[model] = r
	return r
end

local function ease(rig: Rig, target: { [string]: CFrame }, dt: number)
	local a = math.clamp(dt * EASE, 0, 1)
	for name, j in rig.joints do
		local want = target[name] or CFrame.new()
		local cur = (rig.current[name] or CFrame.new()):Lerp(want, a)
		rig.current[name] = cur
		local inst = j.inst
		if inst.Parent then
			local t: CFrame = inst.Transform
			if j.lastWritten and t == j.lastWritten then
				t = j.lastBase -- nothing animated this joint since our last write
			end
			j.lastBase = t
			local out = cur * t
			inst.Transform = out
			j.lastWritten = out
		end
	end
end

------------------------------------------------------------------ carrying

local CARRY = {
	RightShoulder = CFrame.Angles(math.rad(78), math.rad(-14), 0),
	LeftShoulder = CFrame.Angles(math.rad(78), math.rad(14), 0),
	RightElbow = CFrame.Angles(math.rad(14), 0, 0),
	LeftElbow = CFrame.Angles(math.rad(14), 0, 0),
}

------------------------------------------------------------------ customer idles

type Idle = { name: string, untilT: number, nextT: number, seed: number }
local idles: { [Model]: Idle } = {}

local function idlePose(name: string, t: number, seed: number): { [string]: CFrame }
	if name == "look" then
		-- slow look left then right
		local yaw = math.sin(t * 1.4 + seed) * math.rad(42)
		return { Neck = CFrame.Angles(math.rad(-4), yaw, 0), Waist = CFrame.Angles(0, yaw * 0.25, 0) }
	elseif name == "phone" then
		-- right hand up in front of the face, head tipped down to the screen
		return {
			RightShoulder = CFrame.Angles(math.rad(70), math.rad(-30), 0),
			RightElbow = CFrame.Angles(math.rad(95), 0, 0),
			Neck = CFrame.Angles(math.rad(-22), math.rad(-8), 0),
		}
	elseif name == "shift" then
		-- weight on one leg: hips and shoulders sway a little
		local s = math.sin(t * 2 + seed)
		return { Waist = CFrame.Angles(0, 0, math.rad(5) * s), Neck = CFrame.Angles(0, 0, math.rad(-3) * s) }
	end
	return {}
end

local IDLE_NAMES = { "look", "phone", "shift", "none", "look" }

local function customerTarget(model: Model, now: number): { [string]: CFrame }
	local state = model:GetAttribute("State")
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local standing = (state == "queue" or state == "waiting") and hrp ~= nil and hrp.AssemblyLinearVelocity.Magnitude < 0.5
	local idle = idles[model]
	if not standing then
		idles[model] = nil
		return {}
	end
	if not idle then
		idle = { name = "none", untilT = 0, nextT = now + math.random() * 3, seed = math.random() * 10 }
		idles[model] = idle
	end
	if now >= idle.nextT then
		idle.name = IDLE_NAMES[math.random(#IDLE_NAMES)]
		idle.untilT = now + 2.5 + math.random() * 3
		idle.nextT = idle.untilT + 2 + math.random() * 4
	end
	if now < idle.untilT then
		return idlePose(idle.name, now, idle.seed)
	end
	return {}
end

------------------------------------------------------------------ staff (Staff_<role> NPCs, StaffService)

local CROSS = { -- arms folded across the chest
	RightShoulder = CFrame.Angles(math.rad(48), math.rad(-38), 0),
	LeftShoulder = CFrame.Angles(math.rad(48), math.rad(38), 0),
	RightElbow = CFrame.Angles(math.rad(105), 0, 0),
	LeftElbow = CFrame.Angles(math.rad(105), 0, 0),
}

-- Work poses from the model's "Activity" attribute (set by StaffService.say).
local function workPose(activity: string, t: number): { [string]: CFrame }?
	if activity == "clean" then
		-- right arm wipes in small circles, head down at the spot
		local a, b = math.sin(t * 7), math.cos(t * 7)
		return {
			RightShoulder = CFrame.Angles(math.rad(62 + 10 * a), math.rad(-10 + 12 * b), 0),
			RightElbow = CFrame.Angles(math.rad(25), 0, 0),
			Neck = CFrame.Angles(math.rad(-25), 0, 0),
			Waist = CFrame.Angles(math.rad(-10), 0, 0),
		}
	elseif activity == "type" then
		-- both hands on the register screen, small tapping bob
		local tap = math.sin(t * 14) * math.rad(4)
		return {
			RightShoulder = CFrame.Angles(math.rad(48) + tap, math.rad(-12), 0),
			LeftShoulder = CFrame.Angles(math.rad(48) - tap, math.rad(12), 0),
			RightElbow = CFrame.Angles(math.rad(40), 0, 0),
			LeftElbow = CFrame.Angles(math.rad(40), 0, 0),
			Neck = CFrame.Angles(math.rad(-15), 0, 0),
		}
	elseif activity == "box" then
		-- folding the box shut: arms low and forward, alternating
		local s = math.sin(t * 6) * math.rad(10)
		return {
			RightShoulder = CFrame.Angles(math.rad(55) + s, math.rad(-18), 0),
			LeftShoulder = CFrame.Angles(math.rad(55) - s, math.rad(18), 0),
			RightElbow = CFrame.Angles(math.rad(30), 0, 0),
			LeftElbow = CFrame.Angles(math.rad(30), 0, 0),
			Neck = CFrame.Angles(math.rad(-22), 0, 0),
		}
	end
	return nil
end

local STAFF_IDLES = { "look", "shift", "cross", "none", "cross" }

local function staffTarget(model: Model, now: number): { [string]: CFrame }
	-- carrying a pizza (the cook welds a "Carried" model in front of him)
	if model:FindFirstChild("Carried", true) then
		idles[model] = nil
		return CARRY
	end
	local activity = model:GetAttribute("Activity")
	if type(activity) == "string" then
		local pose = workPose(activity, now)
		if pose then
			idles[model] = nil
			return pose
		end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or hrp.AssemblyLinearVelocity.Magnitude >= 0.5 then
		idles[model] = nil
		return {}
	end
	-- waiting for work: the same idle timing as customers, plus folded arms
	local idle = idles[model]
	if not idle then
		idle = { name = "none", untilT = 0, nextT = now + math.random() * 3, seed = math.random() * 10 }
		idles[model] = idle
	end
	if now >= idle.nextT then
		idle.name = STAFF_IDLES[math.random(#STAFF_IDLES)]
		idle.untilT = now + 3 + math.random() * 4
		idle.nextT = idle.untilT + 1.5 + math.random() * 3
	end
	if now < idle.untilT then
		return if idle.name == "cross" then CROSS else idlePose(idle.name, now, idle.seed)
	end
	return {}
end

------------------------------------------------------------------ loop

function Poses.start()
	-- NPC models to pose: "customer" (queue idles) or "staff" (work + idles)
	local customers: { [Model]: string } = {}
	local function track(d: Instance)
		if d:IsA("Model") and string.sub(d.Name, 1, 9) == "Customer_" then
			customers[d] = "customer"
		elseif d:IsA("Model") and string.sub(d.Name, 1, 6) == "Staff_" then
			customers[d] = "staff"
		end
	end
	for _, d in workspace:GetDescendants() do
		track(d)
	end
	workspace.DescendantAdded:Connect(track)

	-- after the Animator has written this frame's Transforms
	RunService.PreSimulation:Connect(function(dt)
		local now = os.clock()
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char then
				local rig = rigOf(char)
				if rig then
					local holding = p:GetAttribute("Holding")
					ease(rig, if type(holding) == "string" and holding ~= "" then CARRY else {}, dt)
				end
			end
		end
		for m, kind in customers do
			if not m.Parent then
				customers[m] = nil
				rigs[m] = nil
				idles[m] = nil
			else
				local rig = rigOf(m)
				if rig then
					ease(rig, if kind == "staff" then staffTarget(m, now) else customerTarget(m, now), dt)
				end
			end
		end
		-- forget characters that were removed (respawn makes a new model)
		for m in rigs do
			if not m.Parent then
				rigs[m] = nil
			end
		end
	end)
end

return Poses
