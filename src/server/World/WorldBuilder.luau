--!strict
-- Builds the shared town: one long street with a restaurant plot for every
-- player slot, houses across the road, street lamps and lighting.
-- Returns the CFrame origin of every plot.

local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local B = require(script.Parent.Build)
local C = B.C
local M = Enum.Material

local WorldBuilder = {}

local function lighting()
	-- Lighting.Technology can't be set by scripts; set it to Future in Studio (Lighting properties).
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 1.7
	Lighting.ExposureCompensation = -0.25
	Lighting.Ambient = Color3.fromRGB(70, 62, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 132, 128)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	local function ensure(class: string, name: string): Instance
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class :: any)
			e.Name = name
			e.Parent = Lighting
		end
		return e :: Instance
	end
	local atmo = ensure("Atmosphere", "PP_Atmosphere") :: Atmosphere
	atmo.Density = 0.28
	atmo.Haze = 1.2
	atmo.Color = Color3.fromRGB(200, 215, 230)
	atmo.Decay = Color3.fromRGB(110, 120, 140)
	local cc = ensure("ColorCorrectionEffect", "PP_Color") :: ColorCorrectionEffect
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(255, 250, 244)
	local bloom = ensure("BloomEffect", "PP_Bloom") :: BloomEffect
	bloom.Intensity = 0.18
	bloom.Size = 18
	bloom.Threshold = 2.4
end

local function house(c: B.Ctx, x: number, z: number, seed: number)
	local rng = Random.new(seed)
	local palette = {
		Color3.fromRGB(120, 150, 190), Color3.fromRGB(230, 214, 170), Color3.fromRGB(170, 190, 160),
		Color3.fromRGB(210, 170, 150), Color3.fromRGB(150, 150, 160), Color3.fromRGB(240, 236, 228),
	}
	local wall = palette[rng:NextInteger(1, #palette)]
	local w, d, h = rng:NextNumber(20, 28), rng:NextNumber(18, 24), rng:NextNumber(13, 16)
	local s = B.sub(c, x, z, 180)
	local m = B.model(s, "House")
	B.box(m, "Base", -w / 2, -1.2, -d / 2, w / 2, 0.6, d / 2, C.STONE, M.Concrete)
	B.box(m, "Walls", -w / 2, 0.6, -d / 2, w / 2, h, d / 2, wall, M.WoodPlanks)
	-- gable roof from two wedges
	local roofCol = Color3.fromRGB(70, 66, 72)
	B.wedge(m, "RoofL", Vector3.new(w + 2, 6, d / 2 + 1), CFrame.new(0, h + 3, d / 4 + 0.5), roofCol, M.RoofShingles)
	B.wedge(m, "RoofR", Vector3.new(w + 2, 6, d / 2 + 1), CFrame.new(0, h + 3, -d / 4 - 0.5) * CFrame.Angles(0, math.rad(180), 0), roofCol, M.RoofShingles)
	-- door + windows (front = +Z after rotation faces the road)
	B.box(m, "Door", -1.6, 0.6, d / 2, 1.6, 8, d / 2 + 0.2, Color3.fromRGB(150, 40, 40), M.Wood)
	B.box(m, "Porch", -4, 0, d / 2, 4, 0.8, d / 2 + 4, C.WOOD, M.WoodPlanks)
	for _, wx in { -w / 2 + 4, w / 2 - 4 } do
		B.box(m, "Window", wx - 2, 4, d / 2, wx + 2, 9, d / 2 + 0.15, Color3.fromRGB(255, 236, 180), M.Glass, { Transparency = 0.2 })
		B.box(m, "Frame", wx - 2.2, 3.8, d / 2 + 0.1, wx + 2.2, 4.1, d / 2 + 0.5, C.WHITE)
	end
	B.box(m, "Lawn", -w / 2 - 4, -1.2, d / 2, w / 2 + 4, -0.05, d / 2 + 10, C.GRASS, M.Grass)
	-- fence
	for fx = -w / 2 - 3, w / 2 + 3, 2 do
		B.box(m, "Picket", fx - 0.2, 0, d / 2 + 9.6, fx + 0.2, 3, d / 2 + 9.8, C.WHITE, M.Wood)
	end
	B.box(m, "Rail", -w / 2 - 3, 2.2, d / 2 + 9.55, w / 2 + 3, 2.5, d / 2 + 9.85, C.WHITE, M.Wood)
end

function WorldBuilder.build(): { CFrame }
	lighting()
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	if not workspace:FindFirstChild("Restaurants") then
		local r = Instance.new("Folder")
		r.Name = "Restaurants"
		r.Parent = workspace
	end
	-- remove the default baseplate/spawn if present
	local bp = workspace:FindFirstChild("Baseplate")
	if bp then
		bp:Destroy()
	end
	for _, s in workspace:GetChildren() do
		if s:IsA("SpawnLocation") then
			s:Destroy()
		end
	end

	local n = GameConfig.PlotCount
	local spacing = GameConfig.PlotSpacing
	local half = (n * spacing) / 2 + 60
	local c = B.ctx(world, CFrame.new())

	-- ground, road, sidewalks
	B.box(c, "Ground", -half - 200, -3, -260, half + 200, -1.4, 300, C.GRASS, M.Grass)
	B.box(c, "Road", -half, -1.6, 34.2, half, -0.15, 60, C.ASPHALT, M.Asphalt)
	for x = -half + 4, half - 8, 14 do
		B.box(c, "LaneMark", x, -0.15, 46.8, x + 7, -0.12, 47.4, C.WHITE)
	end
	B.box(c, "SidewalkFar", -half, -1.6, 60, half, 0.05, 68, C.CONCRETE, M.Concrete)
	B.box(c, "CurbFar", -half, -1.6, 59.8, half, 0.25, 60.4, C.WHITE, M.Concrete)

	-- street lamps along both curbs
	for x = -half + 20, half - 20, 40 do
		for _, z in { 35.5, 62 } do
			B.cyl(c, "LampPost", 0.5, 14, x, 0, z, C.BLACK, M.Metal)
			local head = B.box(c, "LampHead", x - 1.2, 13.6, z - 0.6, x + 1.2, 14.2, z + 0.6, Color3.fromRGB(255, 244, 210), M.Neon)
			B.pointLight(head, Color3.fromRGB(255, 226, 180), 24, 0.8)
		end
	end

	-- houses across the road
	local seed = 1
	for x = -half + 18, half - 18, 34 do
		house(c, x, 82, seed)
		seed += 1
	end

	-- hub spawn in the middle of the far sidewalk (players are moved to their plot)
	local hub = Instance.new("SpawnLocation")
	hub.Name = "HubSpawn"
	hub.Anchored = true
	hub.Size = Vector3.new(8, 0.3, 8)
	hub.CFrame = CFrame.new(0, 0.2, 64)
	hub.Color = C.YELLOW
	hub.Material = M.SmoothPlastic
	hub.Neutral = true
	hub.Duration = 0
	hub.Parent = world

	local origins = {}
	for i = 1, n do
		local x = (i - (n + 1) / 2) * spacing
		table.insert(origins, CFrame.new(x, 0, 0))
		-- empty-lot sign for unclaimed plots
		local sign = B.box(c, "PlotSign" .. i, x - 4, 0, 30, x + 4, 5, 30.6, C.WHITE)
		sign.CanCollide = false
		B.label(sign, Enum.NormalId.Back, "Plot " .. i, { color = C.RED_DARK, font = Enum.Font.FredokaOne, pad = 10 })
	end
	return origins
end

return WorldBuilder
