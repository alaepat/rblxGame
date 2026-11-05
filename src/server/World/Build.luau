--!strict
-- Small geometry toolkit used by the world/restaurant builders.
-- A "ctx" is { parent = Instance, origin = CFrame }. All coordinates passed
-- to helpers are LOCAL to ctx.origin (studs). y = 0 is the floor surface.

local Build = {}

export type Ctx = { parent: Instance, origin: CFrame }

Build.C = {
	STEEL = Color3.fromRGB(200, 204, 210),
	STEEL_DARK = Color3.fromRGB(128, 132, 140),
	BLACK = Color3.fromRGB(34, 32, 36),
	DARK = Color3.fromRGB(52, 48, 54),
	WHITE = Color3.fromRGB(246, 244, 240),
	CREAM = Color3.fromRGB(246, 234, 208),
	TILE_WALL = Color3.fromRGB(238, 234, 226),
	TILE_FLOOR = Color3.fromRGB(198, 96, 60),
	WOOD_FLOOR = Color3.fromRGB(178, 126, 82),
	WOOD = Color3.fromRGB(196, 142, 92),
	WOOD_DARK = Color3.fromRGB(110, 72, 48),
	RED = Color3.fromRGB(206, 40, 40),
	RED_DARK = Color3.fromRGB(150, 30, 32),
	YELLOW = Color3.fromRGB(255, 196, 40),
	ORANGE = Color3.fromRGB(255, 130, 40),
	GREEN = Color3.fromRGB(70, 160, 80),
	BRICK = Color3.fromRGB(168, 76, 54),
	STONE = Color3.fromRGB(150, 140, 130),
	GLASS = Color3.fromRGB(170, 210, 230),
	CONCRETE = Color3.fromRGB(178, 176, 172),
	ASPHALT = Color3.fromRGB(58, 58, 62),
	GRASS = Color3.fromRGB(96, 160, 72),
}

function Build.ctx(parent: Instance, origin: CFrame): Ctx
	return { parent = parent, origin = origin }
end

-- Sub-context translated + rotated (yaw in degrees). Front of a sub-builder is +Z.
function Build.sub(c: Ctx, x: number, z: number, yaw: number?, parent: Instance?, y: number?): Ctx
	return { parent = parent or c.parent, origin = c.origin * CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0) }
end

function Build.folder(c: Ctx, name: string, class: string?): Ctx
	local f = Instance.new((class or "Folder") :: any)
	f.Name = name
	f.Parent = c.parent
	return { parent = f, origin = c.origin }
end

function Build.model(c: Ctx, name: string): Ctx
	return Build.folder(c, name, "Model")
end

function Build.part(c: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = c.origin * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if props then
		for k, v in props do
			if k == "Shape" and v == Enum.PartType.Ball and (size.X ~= size.Y or size.Y ~= size.Z) then
				-- Ball parts are forced round; ellipsoids use a sphere mesh instead.
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			else
				(p :: any)[k] = v
			end
		end
		p.Size = size
	end
	p.Parent = c.parent
	return p
end

-- Axis-aligned box from two corners (local).
function Build.box(c: Ctx, name: string, x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1))
	local center = Vector3.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
	return Build.part(c, name, size, CFrame.new(center), color, material, props)
end

-- Vertical cylinder (axis = Y) with bottom at y.
function Build.cyl(c: Ctx, name: string, d: number, h: number, x: number, y: number, z: number, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	return Build.part(c, name, Vector3.new(h, d, d), CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, material, (function()
		local t = props or {}
		t.Shape = Enum.PartType.Cylinder
		return t
	end)())
end

function Build.ball(c: Ctx, name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local t = props or {}
	t.Shape = Enum.PartType.Ball
	return Build.part(c, name, size, CFrame.new(x, y, z), color, material, t)
end

function Build.wedge(c: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = c.origin * cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = c.parent
	return w
end

-- Invisible navigation / reference node.
function Build.node(c: Ctx, name: string, x: number, y: number, z: number): Part
	return Build.part(c, name, Vector3.new(1, 1, 1), CFrame.new(x, y, z), Color3.new(1, 0, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

-- Marks a part as an interactive station.
function Build.station(p: BasePart, kind: string, label: string, attrs: { [string]: any }?): BasePart
	p:SetAttribute("Station", kind)
	p:SetAttribute("Label", label)
	if attrs then
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
	end
	p.CanQuery = true
	return p
end

-- Invisible hit-box station (for things made of many small visuals).
function Build.hitbox(c: Ctx, name: string, size: Vector3, cf: CFrame): Part
	return Build.part(c, name, size, cf, Color3.new(1, 1, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
	})
end

function Build.itemAt(p: BasePart, offset: CFrame)
	local a = Instance.new("Attachment")
	a.Name = "ItemAt"
	a.CFrame = offset
	a.Parent = p
	return a
end

-- Text on a part face.
function Build.label(p: BasePart, face: Enum.NormalId, text: string, opts: { [string]: any }?): TextLabel
	local o = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = o.guiName or "Label"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.ppu or 40
	gui.LightInfluence = o.light or 0.2
	gui.Brightness = o.brightness or 1
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = if o.bg then 0 else 1
	t.BackgroundColor3 = o.bg or Color3.new(0, 0, 0)
	t.Font = o.font or Enum.Font.FredokaOne
	t.TextColor3 = o.color or Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Text = text
	t.Parent = gui
	if o.pad then
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, o.pad)
		pad.PaddingRight = UDim.new(0, o.pad)
		pad.PaddingTop = UDim.new(0, o.pad)
		pad.PaddingBottom = UDim.new(0, o.pad)
		pad.Parent = t
	end
	return t
end

function Build.pointLight(p: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = p
	return l
end

function Build.surfaceLight(p: BasePart, face: Enum.NormalId, color: Color3, range: number, brightness: number, angle: number?)
	local l = Instance.new("SurfaceLight")
	l.Face = face
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Angle = angle or 120
	l.Shadows = false
	l.Parent = p
	return l
end

-- A wall running along X at depth z (centre line), from x1..x2, y1..y2,
-- with rectangular openings { {a, b, top} } (top = opening height).
function Build.wallX(c: Ctx, name: string, z: number, x1: number, x2: number, y1: number, y2: number, t: number, color: Color3, material: Enum.Material?, openings: { { number } }?)
	local cuts = openings or {}
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local x = x1
	for _, o in cuts do
		if o[1] > x then
			Build.box(c, name, x, y1, z - t / 2, o[1], y2, z + t / 2, color, material)
		end
		if o[3] < y2 then
			Build.box(c, name .. "Lintel", o[1], o[3], z - t / 2, o[2], y2, z + t / 2, color, material)
		end
		if o[4] and o[4] > y1 then
			Build.box(c, name .. "Sill", o[1], y1, z - t / 2, o[2], o[4], z + t / 2, color, material)
		end
		x = o[2]
	end
	if x < x2 then
		Build.box(c, name, x, y1, z - t / 2, x2, y2, z + t / 2, color, material)
	end
end

function Build.wallZ(c: Ctx, name: string, x: number, z1: number, z2: number, y1: number, y2: number, t: number, color: Color3, material: Enum.Material?, openings: { { number } }?)
	local cuts = openings or {}
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local z = z1
	for _, o in cuts do
		if o[1] > z then
			Build.box(c, name, x - t / 2, y1, z, x + t / 2, y2, o[1], color, material)
		end
		if o[3] < y2 then
			Build.box(c, name .. "Lintel", x - t / 2, o[3], o[1], x + t / 2, y2, o[2], color, material)
		end
		if o[4] and o[4] > y1 then
			Build.box(c, name .. "Sill", x - t / 2, y1, o[1], x + t / 2, o[4], o[2], color, material)
		end
		z = o[2]
	end
	if z < z2 then
		Build.box(c, name, x - t / 2, y1, z, x + t / 2, y2, z2, color, material)
	end
end

return Build
