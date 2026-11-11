--!strict
-- Client-only cosmetic effects (nothing here touches gameplay):
--  * spins anything with a `Spin` attribute (doner meat cones)
--  * oven / fryer particles from the station part's `CookState` attribute
--    (StationService): heat haze while cooking, steam when ready, dark smoke
--    when burnt
--  * customer `Mood` attribute (CustomerService, set when they pay or walk
--    out): floating ❤️ / ✨ / 💢 above the head + particles
--  * bursts at your own character for the gameplay sound events (Cash,
--    Clean, Trash, Upgrade, GoalDone, LevelUp ...)
-- Textures: Config/VfxIds (our own smoke puff, group asset; Roblox's built-in
-- sparkle). The built-in smoke_main.dds renders almost invisible.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Effects = {}

type Spinner = { model: Model, speed: number }
local spinners: { [Model]: Spinner } = {}

local VfxIds = require(Shared.Config.VfxIds)
local SMOKE = VfxIds.Smoke
local SPARKLE = VfxIds.Sparkle

local function track(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("Spin") and not spinners[inst] then
		spinners[inst] = { model = inst, speed = inst:GetAttribute("Spin") :: number }
	end
end

------------------------------------------------------------------ particles

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

-- One-shot burst at a world position; cleans itself up.
local function burst(pos: Vector3, props: { [string]: any }, count: number)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	for k, v in props do
		(pe :: any)[k] = v
	end
	pe.Parent = att
	pe:Emit(count)
	task.delay(pe.Lifetime.Max + 0.2, function()
		att:Destroy()
	end)
end

local function sparkles(pos: Vector3, color: Color3, count: number, speed: number?)
	burst(pos, {
		Texture = SPARKLE,
		Color = ColorSequence.new(color),
		LightEmission = 0.8,
		Size = seq(0.5, 0),
		Transparency = seq(0, 1),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new((speed or 6) * 0.5, speed or 6),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -6, 0),
		Rotation = NumberRange.new(0, 360),
	}, count)
end

local function puff(pos: Vector3, color: Color3, count: number)
	burst(pos, {
		Texture = SMOKE,
		Color = ColorSequence.new(color),
		Size = seq(0.6, 2),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(70, 70),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	}, count)
end

-- Emoji that floats up and fades (hearts over a happy customer etc.)
local function floatText(adornee: BasePart, text: string, offset: number)
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(60, 60)
	g.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	g.LightInfluence = 0
	g.MaxDistance = 60
	g.Adornee = adornee
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.Parent = g
	g.Parent = adornee
	local info = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(g, info, { StudsOffsetWorldSpace = Vector3.new(0, offset + 2.2, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(1.5, function()
		g:Destroy()
	end)
end

------------------------------------------------------------------ ovens / fryers

local COOK_FX: { [string]: { [string]: any } } = {
	cooking = { -- faint warm haze
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(255, 236, 210)),
		Size = seq(0.5, 1.6),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 1.8),
		Rate = 4,
		Speed = NumberRange.new(0.8, 1.4),
		SpreadAngle = Vector2.new(12, 12),
		Rotation = NumberRange.new(0, 360),
	},
	cooked = { -- clear white steam: "take me out"
		Texture = SMOKE,
		-- light grey-blue, not pure white: white vanishes against the cream kitchen tiles
		Color = ColorSequence.new(Color3.fromRGB(196, 204, 218)),
		Size = seq(0.8, 2.4),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.4, 2.2),
		Rate = 9,
		Speed = NumberRange.new(1.5, 2.5),
		SpreadAngle = Vector2.new(15, 15),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
	},
	burnt = { -- thick dark smoke
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(70, 64, 60)),
		Size = seq(1, 3.5),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.05), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = NumberRange.new(0, 360),
		Lifetime = NumberRange.new(2, 3),
		Rate = 14,
		Speed = NumberRange.new(2, 3.5),
		SpreadAngle = Vector2.new(18, 18),
		RotSpeed = NumberRange.new(-40, 40),
	},
}

local cookFx: { [BasePart]: ParticleEmitter } = {}

local function updateCook(part: BasePart)
	local state = part:GetAttribute("CookState")
	local props = type(state) == "string" and COOK_FX[state] or nil
	local pe = cookFx[part]
	if not props then
		if pe then
			pe.Enabled = false -- let the last puffs fade out
			cookFx[part] = nil
			task.delay(3.5, function()
				if pe.Parent and not pe.Enabled then
					(pe.Parent :: Instance):Destroy()
				end
			end)
		end
		return
	end
	if not pe or not pe.Parent then
		local att = Instance.new("Attachment")
		att.Name = "CookFx"
		-- ovens: out of the mouth (the dome and hood hide anything rising from
		-- inside); fryers: straight up out of the basket
		att.Position = if part:GetAttribute("Station") == "Oven"
			then Vector3.new(0, 1.2, 1.6) -- object space: +Z is the kitchen side (-LookVector)
			else Vector3.new(0, part.Size.Y / 2, 0)
		att.Parent = part
		pe = Instance.new("ParticleEmitter")
		pe.Parent = att
		cookFx[part] = pe
	end
	local emitter = pe :: ParticleEmitter
	for k, v in props do
		(emitter :: any)[k] = v
	end
	emitter.Enabled = true
end

local function watchCook(part: Instance)
	if part:IsA("BasePart") and not part:GetAttribute("CookFxWatched") then
		part:SetAttribute("CookFxWatched", true) -- client-side attribute, local only
		part:GetAttributeChangedSignal("CookState"):Connect(function()
			updateCook(part)
		end)
		updateCook(part)
	end
end

------------------------------------------------------------------ customers

local function onMood(model: Model)
	local mood = model:GetAttribute("Mood")
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	if mood == "happy" then
		floatText(head, "❤️", 1.6)
		sparkles(head.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 120, 170), 14, 5)
	elseif mood == "ok" then
		floatText(head, "👍", 1.6)
	elseif mood == "angry" then
		floatText(head, "💢", 1.6)
		puff(head.Position + Vector3.new(0, 0.8, 0), Color3.fromRGB(230, 70, 60), 8)
	end
end

local function watchCustomer(model: Instance)
	if model:IsA("Model") and string.sub(model.Name, 1, 9) == "Customer_" then
		model:GetAttributeChangedSignal("Mood"):Connect(function()
			onMood(model)
		end)
	end
end

------------------------------------------------------------------ your own actions

local function inFront(): (Vector3?, BasePart?)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end
	return root.Position + root.CFrame.LookVector * 2, root
end

local GOLD = Color3.fromRGB(255, 205, 60)

local ON_SOUND: { [string]: () -> () } = {
	Cash = function()
		local pos = inFront()
		if pos then
			sparkles(pos + Vector3.new(0, 1, 0), GOLD, 16, 7)
		end
	end,
	Clean = function()
		local pos = inFront()
		if pos then
			sparkles(pos - Vector3.new(0, 2, 0), Color3.fromRGB(150, 220, 255), 18, 5)
		end
	end,
	Trash = function()
		local pos = inFront()
		if pos then
			puff(pos, Color3.fromRGB(170, 160, 150), 6)
		end
	end,
	Upgrade = function()
		local pos = inFront()
		if pos then
			sparkles(pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(110, 190, 255), 24, 8)
		end
	end,
	GoalDone = function()
		local _, root = inFront()
		if root then
			sparkles(root.Position + Vector3.new(0, 2.5, 0), GOLD, 20, 6)
		end
	end,
	LevelUp = function()
		local _, root = inFront()
		if root then
			-- confetti ring
			for i, c in { Color3.fromRGB(255, 90, 90), GOLD, Color3.fromRGB(90, 200, 120), Color3.fromRGB(110, 160, 255), Color3.fromRGB(200, 120, 255) } do
				task.delay(i * 0.06, function()
					sparkles(root.Position + Vector3.new(0, 2, 0), c, 14, 12)
				end)
			end
			floatText(root, "⭐", 3.2)
		end
	end,
}

function Effects.start()
	-- ovens and fryers are station parts (attribute Station, RestaurantBuilder)
	local function watchStation(d: Instance)
		local kind = d:GetAttribute("Station")
		if kind == "Oven" or kind == "Fryer" then
			watchCook(d)
		end
	end
	for _, d in workspace:GetDescendants() do
		track(d)
		watchStation(d)
		watchCustomer(d)
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(track, d)
			watchCustomer(d)
		elseif d:IsA("BasePart") then
			task.defer(watchStation, d) -- attributes replicate with the part
		end
	end)
	Net.event("Sound").OnClientEvent:Connect(function(name)
		local fx = ON_SOUND[name]
		if fx then
			fx()
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
