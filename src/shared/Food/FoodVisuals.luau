--!strict
-- Builds stylised 3D models for food items from their item tables.
-- Style rules (match the whole game): SmoothPlastic for food, clean rounded
-- primitives, warm saturated colours, slight overlaps so nothing floats.
-- Every model is built around a "Root" part at the bottom centre (origin),
-- all parts anchored + non-colliding. Callers PivotTo / weld as needed.

local Config = script.Parent.Parent.Config
local Ingredients = require(Config.Ingredients)
local FoodLogic = require(script.Parent.FoodLogic)

type Item = { [string]: any }

local FoodVisuals = {}

local DOUGH_RAW = Color3.fromRGB(242, 224, 190)
local DOUGH_COOKED = Color3.fromRGB(226, 168, 92)
local DOUGH_BURNT = Color3.fromRGB(72, 48, 34)
local CHEESE_COOKED = Color3.fromRGB(252, 206, 110)
local PAPER = Color3.fromRGB(250, 246, 236)
local BRAND_RED = Color3.fromRGB(214, 40, 40)
local BRAND_YELLOW = Color3.fromRGB(255, 196, 40)

local function newPart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == Enum.PartType.Ball and (size.X ~= size.Y or size.Y ~= size.Z) then
		-- Ball parts are always round; use a sphere mesh for ellipsoids.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

-- Flat disc lying on the XZ plane, bottom at y.
local DISC_ROT = CFrame.Angles(0, 0, math.rad(90))
local function disc(model: Model, name: string, d: number, h: number, y: number, color: Color3, x: number?, z: number?, mat: Enum.Material?): Part
	return newPart(model, name, Vector3.new(h, d, d), CFrame.new(x or 0, y + h / 2, z or 0) * DISC_ROT, color, mat, Enum.PartType.Cylinder)
end

local function newModel(name: string): (Model, Part)
	local m = Instance.new("Model")
	m.Name = name
	local root = newPart(m, "Root", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.1, 0), Color3.new(1, 1, 1))
	root.Transparency = 1
	m.PrimaryPart = root
	return m, root
end

local function seedFor(id: string): number
	local s = 0
	for i = 1, #id do
		s = (s * 31 + string.byte(id, i)) % 2147483647
	end
	return s
end

-- Scatter topping pieces over a circle (pizza) or ellipse (kebab).
local function scatter(model: Model, ingredientId: string, y: number, radiusX: number, radiusZ: number, count: number, cooked: boolean)
	local ing = Ingredients.get(ingredientId)
	if not ing then
		return
	end
	local rng = Random.new(seedFor(ingredientId))
	local color = ing.color
	if cooked then
		color = color:Lerp(Color3.fromRGB(120, 60, 20), 0.12)
	end
	for i = 1, count do
		local ang = (i / count) * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local rad = math.sqrt(rng:NextNumber(0.08, 1))
		local x = math.cos(ang) * rad * radiusX
		local z = math.sin(ang) * rad * radiusZ
		local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local shape = ing.shape
		local name = ingredientId
		if shape == "disc" then
			disc(model, name, 0.42, 0.045, y, color, x, z)
		elseif shape == "slice" then
			disc(model, name, 0.44, 0.05, y, color, x, z)
			disc(model, name .. "_seed", 0.26, 0.055, y, color:Lerp(Color3.fromRGB(255, 120, 90), 0.4), x, z)
		elseif shape == "ring" then
			disc(model, name, 0.24, 0.05, y, color, x, z)
			disc(model, name .. "_in", 0.12, 0.055, y, color:Lerp(Color3.new(1, 1, 1), ingredientId == "olive" and 0.05 or 0.55), x, z)
		elseif shape == "square" then
			newPart(model, name, Vector3.new(0.36, 0.04, 0.32), CFrame.new(x, y + 0.02, z) * yaw, color)
		elseif shape == "strip" then
			newPart(model, name, Vector3.new(0.48, 0.05, 0.1), CFrame.new(x, y + 0.025, z) * yaw, color)
		elseif shape == "chunk" then
			newPart(model, name, Vector3.new(0.24, 0.13, 0.2), CFrame.new(x, y + 0.06, z) * yaw, color)
		elseif shape == "mushroom" then
			newPart(model, name, Vector3.new(0.34, 0.1, 0.3), CFrame.new(x, y + 0.04, z) * yaw, color, nil, Enum.PartType.Ball)
			newPart(model, name .. "_gill", Vector3.new(0.1, 0.05, 0.16), CFrame.new(x, y + 0.06, z) * yaw, color:Lerp(Color3.fromRGB(120, 90, 60), 0.4))
		elseif shape == "crumble" then
			newPart(model, name, Vector3.new(0.17, 0.12, 0.17), CFrame.new(x, y + 0.05, z), color, nil, Enum.PartType.Ball)
		elseif shape == "shred" then
			newPart(model, name, Vector3.new(0.34, 0.035, 0.06), CFrame.new(x, y + 0.02, z) * yaw, color)
		elseif shape == "leaf" then
			newPart(model, name, Vector3.new(0.38, 0.05, 0.26), CFrame.new(x, y + 0.03, z) * yaw * CFrame.Angles(math.rad(12), 0, 0), color)
		elseif shape == "meat" then
			newPart(model, name, Vector3.new(0.46, 0.07, 0.16), CFrame.new(x, y + 0.04, z) * yaw * CFrame.Angles(0, 0, math.rad(8)), color)
		elseif shape == "chips" then
			newPart(model, name, Vector3.new(0.1, 0.1, 0.5), CFrame.new(x, y + 0.08, z) * yaw * CFrame.Angles(math.rad(10), 0, 0), color)
		elseif shape == "drizzle" then
			newPart(model, name, Vector3.new(0.5, 0.03, 0.05), CFrame.new(x, y + 0.03, z) * yaw, color)
		elseif shape == "cheese" then
			newPart(model, name, Vector3.new(0.3, 0.04, 0.3), CFrame.new(x, y + 0.02, z) * yaw, color)
		else
			disc(model, name, 0.3, 0.05, y, color, x, z)
		end
	end
end

local function labelGui(part: BasePart, face: Enum.NormalId, text: string, sub: string?, bg: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = bg and 0 or 1
	t.BackgroundColor3 = bg or Color3.new(1, 1, 1)
	t.Size = UDim2.fromScale(1, sub and 0.62 or 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(60, 35, 20)
	t.Text = text
	t.Parent = gui
	if sub then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Position = UDim2.fromScale(0, 0.6)
		s.Size = UDim2.fromScale(1, 0.38)
		s.Font = Enum.Font.GothamBold
		s.TextScaled = true
		s.TextColor3 = Color3.fromRGB(90, 60, 40)
		s.Text = sub
		s.Parent = gui
	end
end

-- Planet logo: red disc with a yellow orbit ring.
function FoodVisuals.logo(model: Model, cf: CFrame, size: number)
	newPart(model, "LogoPlanet", Vector3.new(0.03, size, size), cf * DISC_ROT, BRAND_RED, nil, Enum.PartType.Cylinder)
	newPart(model, "LogoRing", Vector3.new(size * 1.5, 0.035, size * 0.16), cf * CFrame.new(0, 0.005, 0) * CFrame.Angles(0, math.rad(-20), 0), BRAND_YELLOW)
end

------------------------------------------------------------------ builders

local function buildDough(): Model
	local m = newModel("Dough")
	newPart(m, "Ball", Vector3.new(1.15, 0.55, 1.15), CFrame.new(0, 0.27, 0), DOUGH_RAW, nil, Enum.PartType.Ball)
	newPart(m, "Flour", Vector3.new(0.7, 0.2, 0.6), CFrame.new(0.1, 0.48, 0.05), Color3.fromRGB(252, 248, 238), nil, Enum.PartType.Ball)
	return m
end

local function buildPizzaBox(m: Model, closed: boolean)
	local W, H = 2.7, 0.42
	if closed then
		newPart(m, "Box", Vector3.new(W, H, W), CFrame.new(0, H / 2, 0), PAPER)
		newPart(m, "StripeF", Vector3.new(W + 0.02, 0.08, 0.02), CFrame.new(0, H * 0.55, W / 2), BRAND_RED)
		newPart(m, "StripeB", Vector3.new(W + 0.02, 0.08, 0.02), CFrame.new(0, H * 0.55, -W / 2), BRAND_RED)
		newPart(m, "StripeL", Vector3.new(0.02, 0.08, W + 0.02), CFrame.new(-W / 2, H * 0.55, 0), BRAND_RED)
		newPart(m, "StripeR", Vector3.new(0.02, 0.08, W + 0.02), CFrame.new(W / 2, H * 0.55, 0), BRAND_RED)
		FoodVisuals.logo(m, CFrame.new(0, H + 0.01, 0), 1.1)
	end
end

local function buildPizza(item: Item): Model
	local m = newModel(item.boxed and "BoxedPizza" or "Pizza")
	if item.boxed then
		buildPizzaBox(m, true)
		return m
	end
	local state = FoodLogic.cookState(item.cook or 0)
	local cooked = state == "cooked" or state == "burnt"
	local base = DOUGH_RAW
	if state == "cooking" then
		base = DOUGH_RAW:Lerp(DOUGH_COOKED, math.clamp(item.cook or 0, 0, 1))
	elseif state == "cooked" then
		base = DOUGH_COOKED
	elseif state == "burnt" then
		base = DOUGH_BURNT
	end
	disc(m, "Crust", 2.4, 0.24, 0, base)
	disc(m, "CrustTop", 2.25, 0.02, 0.24, base:Lerp(Color3.new(1, 1, 1), 0.08))
	local y = 0.25
	if item.sauce then
		local sauce = Ingredients.get(item.sauce)
		disc(m, "Sauce", 2.02, 0.04, y, sauce and sauce.color or BRAND_RED)
		y += 0.04
	end
	local toppings: { string } = item.toppings or {}
	if table.find(toppings, "mozzarella") then
		local c = Color3.fromRGB(255, 240, 190)
		if cooked then
			c = CHEESE_COOKED
		end
		if state == "burnt" then
			c = Color3.fromRGB(90, 60, 30)
		end
		disc(m, "Mozzarella", 1.88, 0.05, y, c)
		if cooked and state ~= "burnt" then
			-- golden browned spots
			local rng = Random.new(7)
			for i = 1, 6 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(0.2, 0.75)
				disc(m, "Brown", rng:NextNumber(0.18, 0.3), 0.055, y, Color3.fromRGB(230, 160, 70), math.cos(a) * r, math.sin(a) * r)
			end
		end
		y += 0.05
	end
	for _, t in toppings do
		if t ~= "mozzarella" then
			local ing = Ingredients.get(t)
			local n = 7
			if ing and (ing.shape == "shred" or ing.shape == "crumble") then
				n = 14
			end
			scatter(m, t, y, 0.78, 0.78, n, cooked)
		end
	end
	if state == "burnt" then
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "Root" then
				p.Color = p.Color:Lerp(Color3.fromRGB(40, 28, 20), 0.6)
			end
		end
	end
	return m
end

local function buildFoodBox(m: Model, closed: boolean)
	local W, H, D = 1.7, 0.65, 1.25
	local T = 0.06
	newPart(m, "Bottom", Vector3.new(W, T, D), CFrame.new(0, T / 2, 0), PAPER)
	newPart(m, "Front", Vector3.new(W, H, T), CFrame.new(0, H / 2, D / 2), PAPER)
	newPart(m, "Back", Vector3.new(W, H, T), CFrame.new(0, H / 2, -D / 2), PAPER)
	newPart(m, "Left", Vector3.new(T, H, D), CFrame.new(-W / 2, H / 2, 0), PAPER)
	newPart(m, "Right", Vector3.new(T, H, D), CFrame.new(W / 2, H / 2, 0), PAPER)
	newPart(m, "Band", Vector3.new(W + 0.02, 0.12, D + 0.02), CFrame.new(0, H * 0.35, 0), BRAND_RED)
	if closed then
		newPart(m, "Lid", Vector3.new(W + 0.04, T, D + 0.04), CFrame.new(0, H + T / 2, 0), PAPER)
		FoodVisuals.logo(m, CFrame.new(0, H + T + 0.005, 0), 0.6)
	end
end

local function buildBread(base: string): Model
	local m = newModel("Bread")
	local ing = Ingredients.get(base)
	if base == "pitta" then
		newPart(m, "Pitta", Vector3.new(1.7, 0.32, 1.05), CFrame.new(0, 0.16, 0), ing and ing.color or DOUGH_COOKED, nil, Enum.PartType.Ball)
		newPart(m, "Toast", Vector3.new(1.2, 0.34, 0.7), CFrame.new(0, 0.17, 0), (ing and ing.color or DOUGH_COOKED):Lerp(Color3.fromRGB(190, 130, 70), 0.3), nil, Enum.PartType.Ball)
	elseif base == "wrap_bread" then
		disc(m, "Wrap", 1.9, 0.06, 0, ing and ing.color or DOUGH_RAW)
		for i = 1, 5 do
			local a = i * 1.3
			disc(m, "Spot", 0.18, 0.065, 0, Color3.fromRGB(205, 160, 100), math.cos(a) * 0.55, math.sin(a) * 0.55)
		end
	else
		buildFoodBox(m, false)
	end
	return m
end

local function buildKebab(item: Item): Model
	local m = newModel("Kebab")
	local base = item.base
	local fillings: { string } = item.fillings or {}
	if base == "food_box" then
		buildFoodBox(m, item.wrapped == true)
		if not item.wrapped then
			for _, f in fillings do
				scatter(m, f, 0.32, 0.6, 0.42, f == "chips" and 14 or 7, false)
			end
		end
		return m
	end
	if item.wrapped then
		if base == "wrap_bread" then
			newPart(m, "Roll", Vector3.new(1.7, 0.6, 0.6), CFrame.new(0, 0.3, 0), Color3.fromRGB(236, 206, 152), nil, Enum.PartType.Cylinder)
			newPart(m, "Foil", Vector3.new(1.0, 0.64, 0.64), CFrame.new(-0.36, 0.3, 0), Color3.fromRGB(215, 218, 226), Enum.Material.Foil, Enum.PartType.Cylinder)
			newPart(m, "Stripe", Vector3.new(0.12, 0.66, 0.66), CFrame.new(-0.2, 0.3, 0), BRAND_RED, nil, Enum.PartType.Cylinder)
		else
			newPart(m, "Paper", Vector3.new(1.8, 0.62, 1.1), CFrame.new(0, 0.31, 0), PAPER, nil, Enum.PartType.Ball)
			newPart(m, "Stripe", Vector3.new(1.82, 0.12, 1.12), CFrame.new(0, 0.31, 0), BRAND_RED, nil, Enum.PartType.Ball)
			-- fillings poking out the top
			for i, f in fillings do
				local ing = Ingredients.get(f)
				if ing then
					newPart(m, f, Vector3.new(0.3, 0.14, 0.22), CFrame.new(-0.6 + (i - 1) * (1.2 / math.max(#fillings - 1, 1)), 0.6, 0) * CFrame.Angles(0, i, 0), ing.color)
				end
			end
		end
		return m
	end
	-- open on the board
	local bread = buildBread(base)
	for _, p in bread:GetChildren() do
		if p.Name ~= "Root" then
			p.Parent = m
		end
	end
	bread:Destroy()
	local y = base == "pitta" and 0.3 or 0.06
	local rx, rz = 0.62, 0.32
	if base == "wrap_bread" then
		rx, rz = 0.7, 0.28
	end
	for _, f in fillings do
		scatter(m, f, y, rx, rz, 7, false)
		y += 0.015
	end
	return m
end

local function buildChips(item: Item): Model
	local m = newModel("Chips")
	local state = FoodLogic.cookState(item.cook or 0)
	local color = Color3.fromRGB(250, 236, 190)
	if state == "cooking" then
		color = color:Lerp(Color3.fromRGB(250, 200, 80), math.clamp(item.cook or 0, 0, 1))
	elseif state == "cooked" then
		color = Color3.fromRGB(250, 198, 70)
	elseif state == "burnt" then
		color = Color3.fromRGB(110, 70, 30)
	end
	-- wire basket
	local steel = Color3.fromRGB(200, 204, 210)
	newPart(m, "BasketBottom", Vector3.new(1.3, 0.05, 0.9), CFrame.new(0, 0.025, 0), steel, Enum.Material.Metal)
	newPart(m, "BasketF", Vector3.new(1.3, 0.55, 0.04), CFrame.new(0, 0.3, 0.45), steel, Enum.Material.Metal).Transparency = 0.35
	newPart(m, "BasketB", Vector3.new(1.3, 0.55, 0.04), CFrame.new(0, 0.3, -0.45), steel, Enum.Material.Metal).Transparency = 0.35
	newPart(m, "BasketL", Vector3.new(0.04, 0.55, 0.9), CFrame.new(-0.65, 0.3, 0), steel, Enum.Material.Metal).Transparency = 0.35
	newPart(m, "BasketR", Vector3.new(0.04, 0.55, 0.9), CFrame.new(0.65, 0.3, 0), steel, Enum.Material.Metal).Transparency = 0.35
	newPart(m, "Handle", Vector3.new(0.9, 0.08, 0.08), CFrame.new(1.1, 0.55, 0), steel, Enum.Material.Metal)
	newPart(m, "Grip", Vector3.new(0.55, 0.14, 0.14), CFrame.new(1.6, 0.55, 0), BRAND_RED, nil, Enum.PartType.Cylinder)
	local rng = Random.new(3)
	for i = 1, 22 do
		newPart(m, "Chip", Vector3.new(0.09, 0.09, 0.55), CFrame.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0.1, 0.42), rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), 0), color)
	end
	return m
end

local function buildCup(item: Item): Model
	local m = newModel("Cup")
	local filled = item.syrup ~= nil
	local up = CFrame.Angles(0, 0, math.rad(90))
	newPart(m, "Cup", Vector3.new(1.1, 0.62, 0.62), CFrame.new(0, 0.55, 0) * up, PAPER, nil, Enum.PartType.Cylinder)
	newPart(m, "Band", Vector3.new(0.26, 0.64, 0.64), CFrame.new(0, 0.42, 0) * up, BRAND_RED, nil, Enum.PartType.Cylinder)
	newPart(m, "Logo", Vector3.new(0.1, 0.25, 0.04), CFrame.new(0, 0.75, 0.31), BRAND_YELLOW)
	if filled then
		local ing = Ingredients.get(item.syrup)
		newPart(m, "Lid", Vector3.new(0.08, 0.68, 0.68), CFrame.new(0, 1.14, 0) * up, Color3.fromRGB(245, 245, 245), nil, Enum.PartType.Cylinder)
		newPart(m, "Straw", Vector3.new(0.07, 0.6, 0.07), CFrame.new(0.08, 1.4, 0) * CFrame.Angles(0, 0, math.rad(-8)), BRAND_RED)
		newPart(m, "Flavor", Vector3.new(0.02, 0.2, 0.2), CFrame.new(0, 1.185, 0) * up, ing and ing.color or BRAND_RED, nil, Enum.PartType.Cylinder)
	end
	return m
end

local CATEGORY_COLORS = {
	dry = Color3.fromRGB(230, 170, 60),
	cold = Color3.fromRGB(70, 150, 230),
	frozen = Color3.fromRGB(120, 220, 240),
}

local function buildSupply(item: Item): Model
	local m = newModel("SupplyBox")
	local ing = Ingredients.get(item.ingredient)
	local box = newPart(m, "Box", Vector3.new(2, 1.3, 1.5), CFrame.new(0, 0.65, 0), Color3.fromRGB(196, 150, 100), Enum.Material.Cardboard)
	newPart(m, "Tape", Vector3.new(0.3, 1.32, 1.52), CFrame.new(0, 0.65, 0), Color3.fromRGB(220, 190, 140))
	newPart(m, "Stripe", Vector3.new(2.02, 0.2, 1.52), CFrame.new(0, 0.2, 0), ing and CATEGORY_COLORS[ing.category] or Color3.new(1, 1, 1))
	labelGui(box, Enum.NormalId.Front, (ing and ing.icon or "📦") .. " " .. (ing and ing.name or "?"), "×" .. tostring(item.amount) .. "  " .. string.upper(ing and ing.category or ""))
	labelGui(box, Enum.NormalId.Top, (ing and ing.icon or "📦"))
	return m
end

function FoodVisuals.build(item: Item): Model
	local k = item.kind
	local m: Model
	if k == "dough" then
		m = buildDough()
	elseif k == "pizza" then
		m = buildPizza(item)
	elseif k == "bread" then
		m = buildBread(item.base)
	elseif k == "kebab" then
		m = buildKebab(item)
	elseif k == "chips" then
		m = buildChips(item)
	elseif k == "cup" then
		m = buildCup(item)
	elseif k == "supply" then
		m = buildSupply(item)
	else
		m = newModel("Unknown")
	end
	m:SetAttribute("ItemKind", k)
	return m
end

-- Convenience for stations: container of an ingredient (steel pan with pieces).
function FoodVisuals.ingredientPan(ingredientId: string, size: Vector3): Model
	local m = newModel("Pan_" .. ingredientId)
	local steel = Color3.fromRGB(196, 200, 206)
	local W, H, D = size.X, size.Y, size.Z
	local T = 0.06
	newPart(m, "Bottom", Vector3.new(W, T, D), CFrame.new(0, T / 2, 0), steel, Enum.Material.Metal)
	newPart(m, "F", Vector3.new(W, H, T), CFrame.new(0, H / 2, D / 2), steel, Enum.Material.Metal)
	newPart(m, "B", Vector3.new(W, H, T), CFrame.new(0, H / 2, -D / 2), steel, Enum.Material.Metal)
	newPart(m, "L", Vector3.new(T, H, D), CFrame.new(-W / 2, H / 2, 0), steel, Enum.Material.Metal)
	newPart(m, "R", Vector3.new(T, H, D), CFrame.new(W / 2, H / 2, 0), steel, Enum.Material.Metal)
	newPart(m, "Lip", Vector3.new(W + 0.1, 0.05, D + 0.1), CFrame.new(0, H, 0), steel:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Metal)
	local ing = Ingredients.get(ingredientId)
	if ing then
		if ing.shape == "sauce" or ing.shape == "drizzle" then
			newPart(m, "Fill", Vector3.new(W - 0.1, H * 0.6, D - 0.1), CFrame.new(0, H * 0.35, 0), ing.color)
		else
			newPart(m, "Fill", Vector3.new(W - 0.1, H * 0.45, D - 0.1), CFrame.new(0, H * 0.25, 0), ing.color:Lerp(Color3.new(0, 0, 0), 0.08))
			scatter(m, ingredientId, H * 0.47, W * 0.36, D * 0.34, 9, false)
		end
	end
	return m
end

FoodVisuals.disc = disc
FoodVisuals.newPart = newPart
FoodVisuals.labelGui = labelGui

return FoodVisuals
