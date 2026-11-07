--!strict
-- Generates one complete Pizza Planet restaurant at a plot origin.
-- Layout (local studs, +Z faces the street, y=0 is the floor):
--
--   Z  34 ┌──────────── front windows ── door ──┐   ZF = 22 + FrontExtra
--         │  West dining   queue lane   East dining│
--   Z   6 ├── front counter (registers, pickup) ──┤
--         │ ovens │ pizza prep line  │ drinks │ kebab station │
--   Z  -8 ├───────┬──────────────┬────────────┬───┤
--         │ Storage + walk-in freezer │ Owner office │ Staff room │
--   Z -32 └─ back door ───────────────────────────┘   ZB = -22 - BackExtra
--        X -40                                  X 40   XW/XE = ±(30 + SideExtra)
--
-- Interactive parts carry a `Station` attribute (see StationService).
-- Upgrade content carries `UpgradeId`; placeholders carry `HideWhen`.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Recipes = require(Shared.Config.Recipes)
local Ingredients = require(Shared.Config.Ingredients)
local FoodVisuals = require(Shared.Food.FoodVisuals)
local FoodLogic = require(Shared.Food.FoodLogic)
local MeshLib = require(Shared.Food.MeshLib)
local GameConfig = require(Shared.Config.GameConfig)
local B = require(script.Parent.Build)
local C = B.C

type Ctx = B.Ctx

local M = Enum.Material
local RestaurantBuilder = {}

local COUNTER_H = 3.2
-- Building depth: the storefront is pushed out by DF, the back wall by DB.
local DF: number = GameConfig.FrontExtra
local DB: number = GameConfig.BackExtra
local ZF = 22 + DF -- front wall line
local ZB = -22 - DB -- back wall line
-- Width: each side wall moves out by DW. West-wall kitchen kit (ovens, hood,
-- dough fridge) and east-wall kit (kebab station, spits, fryer) move with it.
local DW: number = GameConfig.SideExtra
local XW = -30 - DW -- west wall line
local XE = 30 + DW -- east wall line
local IW, IE = XW + 0.5, XE - 0.5 -- inner faces

------------------------------------------------------------------ props

local function counter(c: Ctx, name: string, w: number, d: number, opts: { [string]: any }?): Ctx
	-- Stainless cabinet centred at local origin, front face at +Z.
	local o = opts or {}
	local m = B.model(c, name)
	local h = o.height or COUNTER_H
	local body = o.body or C.STEEL
	if MeshLib.has("CounterModule") and MeshLib.has("CounterTop") then
		-- Blender cabinet bays tiled across the width + one stretched worktop
		local doors = math.max(1, math.floor(w / 2.2))
		local dw = (w - 0.2) / doors
		local mats = { Body = o.bodyMat or M.Metal, Door = o.bodyMat or M.Metal, Handle = M.Metal, Kick = M.SmoothPlastic, Top = o.topMat or M.Metal, Edge = M.Metal }
		for i = 0, doors - 1 do
			local cx = -w / 2 + 0.1 + i * dw + dw / 2
			MeshLib.place(m.parent, "CounterModule", m.origin * CFrame.new(cx, 0, 0), {
				Body = body, Door = o.door or body:Lerp(C.WHITE, 0.12), Handle = C.STEEL_DARK, Kick = C.BLACK,
			}, { scale = Vector3.new(dw / 2.2, (h - 0.15) / 3.05, d / 2.6), collide = true, materials = mats })
		end
		MeshLib.place(m.parent, "CounterTop", m.origin * CFrame.new(0, h - 0.15, 0), {
			Top = o.top or C.STEEL, Edge = C.STEEL_DARK,
		}, { scale = Vector3.new(w / 2.2, 1, d / 2.6), collide = true, materials = mats })
		return m
	end
	B.box(m, "Kick", -w / 2 + 0.15, 0, -d / 2 + 0.15, w / 2 - 0.15, 0.35, d / 2 - 0.15, C.BLACK)
	B.box(m, "Body", -w / 2 + 0.05, 0.35, -d / 2 + 0.05, w / 2 - 0.05, h - 0.15, d / 2 - 0.05, body, o.bodyMat or M.Metal)
	B.box(m, "Top", -w / 2, h - 0.15, -d / 2, w / 2, h, d / 2 + 0.1, o.top or C.STEEL, o.topMat or M.Metal)
	B.box(m, "TopEdge", -w / 2, h - 0.25, d / 2 + 0.02, w / 2, h - 0.1, d / 2 + 0.12, C.STEEL_DARK, M.Metal)
	-- doors with seams + handles
	local doors = math.max(1, math.floor(w / 2.2))
	local dw = (w - 0.2) / doors
	for i = 0, doors - 1 do
		local x0 = -w / 2 + 0.1 + i * dw
		B.box(m, "Door", x0 + 0.06, 0.5, d / 2 - 0.08, x0 + dw - 0.06, h - 0.35, d / 2 + 0.01, o.door or body:Lerp(C.WHITE, 0.12), o.bodyMat or M.Metal)
		B.box(m, "Handle", x0 + dw / 2 - 0.4, h - 0.7, d / 2 + 0.01, x0 + dw / 2 + 0.4, h - 0.58, d / 2 + 0.12, C.STEEL_DARK, M.Metal)
	end
	return m
end

local function pan(c: Ctx, ingredientId: string, x: number, y: number, z: number, boardId: string, w: number?)
	local size = Vector3.new(w or 0.88, 0.34, 0.86)
	local m = FoodVisuals.ingredientPan(ingredientId, size)
	m:PivotTo(c.origin * CFrame.new(x, y, z))
	m.Parent = c.parent
	local ing = Ingredients.get(ingredientId)
	local hit = B.hitbox(c, "Topping_" .. ingredientId, Vector3.new(size.X, 0.6, size.Z), CFrame.new(x, y + 0.3, z))
	hit.Parent = m -- so the hover outline wraps just this pan
	B.station(hit, "Topping", (ing and (ing.icon .. " " .. ing.name) or ingredientId), { Ingredient = ingredientId, Board = boardId })
	return hit
end

local function bottle(c: Ctx, ingredientId: string, x: number, y: number, z: number, boardId: string)
	local ing = Ingredients.get(ingredientId)
	local color = ing and ing.color or C.RED
	local m = B.model(c, "Bottle_" .. ingredientId)
	B.cyl(m, "Body", 0.5, 1.0, x, y, z, color, M.SmoothPlastic, { CanQuery = false })
	B.cyl(m, "Cap", 0.36, 0.18, x, y + 1.0, z, color:Lerp(C.WHITE, 0.3), M.SmoothPlastic, { CanQuery = false })
	B.cyl(m, "Nozzle", 0.12, 0.35, x, y + 1.18, z, color:Lerp(C.WHITE, 0.3), M.SmoothPlastic, { CanQuery = false })
	B.box(m, "Tag", x - 0.18, y + 0.35, z + 0.24, x + 0.18, y + 0.7, z + 0.26, C.WHITE, nil, { CanQuery = false })
	if MeshLib.has("Bottle") then
		for _, p in m.parent:GetChildren() do
			if p:IsA("BasePart") then
				p:Destroy()
			end
		end
		MeshLib.place(m.parent, "Bottle", c.origin * CFrame.new(x, y, z), { Body = color, Cap = color:Lerp(C.WHITE, 0.6), Nozzle = color:Lerp(C.WHITE, 0.6) })
	end
	local hit = B.hitbox(m, "Topping_" .. ingredientId, Vector3.new(0.7, 1.5, 0.7), CFrame.new(x, y + 0.75, z))
	B.station(hit, "Topping", (ing and (ing.icon .. " " .. ing.name) or ingredientId), { Ingredient = ingredientId, Board = boardId })
end

local function chair(c: Ctx, x: number, z: number, yaw: number, color: Color3?)
	local s = B.sub(c, x, z, yaw)
	local m = B.model(s, "Chair")
	local col = color or C.WHITE
	if MeshLib.has("Chair") then
		-- Blender chair back is at Blender -Y = Roblox +Z; procedural back is -Z
		local parts = MeshLib.place(m.parent, "Chair", s.origin * CFrame.Angles(0, math.pi, 0), { Shell = col, Legs = C.BLACK }, { collide = true })
		_ = parts
		return
	end
	for _, lx in { -0.7, 0.7 } do
		for _, lz in { -0.7, 0.7 } do
			B.cyl(m, "Leg", 0.14, 1.75, lx, 0, lz, C.BLACK, M.Metal)
		end
	end
	B.box(m, "Seat", -0.85, 1.75, -0.85, 0.85, 1.95, 0.85, col)
	B.box(m, "Back", -0.85, 1.95, -0.95, 0.85, 3.7, -0.78, col)
	B.box(m, "BackTop", -0.85, 3.55, -0.97, 0.85, 3.75, -0.76, col:Lerp(C.BLACK, 0.1))
end

local function table4(c: Ctx, name: string, x: number, z: number, top: Color3?)
	local s = B.sub(c, x, z, 0)
	local m = B.model(s, name)
	if MeshLib.has("Table") then
		MeshLib.place(m.parent, "Table", s.origin, { Top = top or C.WOOD, Edge = C.WOOD_DARK, Base = C.BLACK }, {
			collide = true,
			materials = { Top = M.Wood, Edge = M.Wood, Base = M.Metal },
		})
	else
		B.cyl(m, "Base", 1.6, 0.15, 0, 0, 0, C.BLACK, M.Metal)
		B.cyl(m, "Pole", 0.3, 2.7, 0, 0.15, 0, C.BLACK, M.Metal)
		B.box(m, "Top", -1.6, 2.85, -1.6, 1.6, 3.05, 1.6, top or C.WOOD, M.Wood)
		B.box(m, "Edge", -1.62, 2.8, -1.62, 1.62, 2.88, 1.62, C.WOOD_DARK, M.Wood)
	end
	-- napkin holder + salt & pepper (mesh), or the simple parts
	if MeshLib.has("TableCaddy") then
		MeshLib.place(m.parent, "TableCaddy", m.origin * CFrame.new(-0.2, 3.05, 0) * CFrame.Angles(0, math.rad(20), 0), {
			Chrome = C.STEEL, Napkin = C.WHITE, Glass = Color3.fromRGB(225, 235, 240), Cap = C.STEEL,
		}, { materials = { Chrome = M.Metal, Napkin = M.SmoothPlastic, Glass = M.Glass, Cap = M.Metal }, shadow = false })
	else
		B.box(m, "Napkins", -0.3, 3.05, -0.15, 0.3, 3.5, 0.15, C.STEEL, M.Metal)
		B.cyl(m, "Chilli", 0.25, 0.5, 0.55, 3.05, 0.1, C.RED)
	end
	chair(s, 0, 2.3, 180)
	chair(s, 0, -2.3, 0)
	chair(s, 2.3, 0, -90)
	chair(s, -2.3, 0, 90)
	return m
end

local function booth(c: Ctx, name: string, x: number, z: number, yaw: number)
	local s = B.sub(c, x, z, yaw)
	local m = B.model(s, name)
	if MeshLib.has("BoothBench") and MeshLib.has("BoothTable") then
		-- two channel-tufted benches facing each other across a pedestal table
		for _, side in { -1, 1 } do
			local cf = m.origin * CFrame.new(0, 0, side * 2.6) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0)
			MeshLib.place(m.parent, "BoothBench", cf, {
				Wood = C.WOOD_DARK, Kick = C.BLACK, Seat = C.RED, Back = C.RED, Cap = C.WOOD_DARK, Piping = C.CREAM,
			}, { collide = true, materials = { Wood = M.Wood, Kick = M.Metal, Seat = M.Leather, Back = M.Leather, Cap = M.Wood, Piping = M.SmoothPlastic } })
		end
		MeshLib.place(m.parent, "BoothTable", m.origin, { Top = C.WOOD, Edge = C.STEEL, Base = C.BLACK },
			{ collide = true, materials = { Top = M.Wood, Edge = M.Metal, Base = M.Metal } })
		if MeshLib.has("TableCaddy") then
			MeshLib.place(m.parent, "TableCaddy", m.origin * CFrame.new(-0.2, 3.1, 0) * CFrame.Angles(0, math.rad(20), 0), {
			Chrome = C.STEEL, Napkin = C.WHITE, Glass = Color3.fromRGB(225, 235, 240), Cap = C.STEEL,
		}, { materials = { Chrome = M.Metal, Napkin = M.SmoothPlastic, Glass = M.Glass, Cap = M.Metal }, shadow = false })
		end
		return
	end
	local leather = C.RED
	for _, side in { -1, 1 } do
		local zz = side * 2.6
		B.box(m, "Base", -2.6, 0, zz - 0.9, 2.6, 1.6, zz + 0.9, C.WOOD_DARK, M.Wood)
		B.box(m, "Seat", -2.5, 1.6, zz - 0.85, 2.5, 2.0, zz + 0.85, leather, M.Leather)
		B.box(m, "Back", -2.5, 2.0, zz + side * 0.55, 2.5, 4.6, zz + side * 0.95, leather, M.Leather)
		B.box(m, "BackCap", -2.6, 4.6, zz + side * 0.5, 2.6, 4.8, zz + side * 1.0, C.WOOD_DARK, M.Wood)
	end
	B.box(m, "TableTop", -2.4, 2.9, -1.4, 2.4, 3.1, 1.4, C.WOOD, M.Wood)
	B.cyl(m, "Pole", 0.35, 2.9, 0, 0, 0, C.BLACK, M.Metal)
end

-- Framed poster on a wall. yaw turns the poster's face: 0 = +Z, pi/2 = +X, -pi/2 = -X.
local function hangArt(c: Ctx, x: number, z: number, yaw: number, text: string, color: Color3)
	local rel = CFrame.new(x, 6.5, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 0.13)
	if MeshLib.has("ArtFrame") then
		-- moulded frame on the wall facing into the room, with a printed poster inside
		MeshLib.place(c.parent, "ArtFrame", c.origin * rel, { Frame = C.BLACK, Lip = C.YELLOW, Mat = C.CREAM },
			{ materials = { Frame = M.Wood, Lip = M.Metal, Mat = M.SmoothPlastic } })
	else
		local frame = B.part(c, "ArtFrame", Vector3.new(4.4, 3.6, 0.2), rel * CFrame.new(0, 1.8, -0.06), C.BLACK)
		frame.CanQuery = false
	end
	local poster = B.part(c, "Poster", Vector3.new(3.4, 2.6, 0.04), rel * CFrame.new(0, 1.8, 0), color, M.SmoothPlastic, { CanCollide = false, CanQuery = false })
	B.label(poster, Enum.NormalId.Back, text, { color = C.WHITE, bg = color, font = Enum.Font.FredokaOne, pad = 14, ppu = 50 })
end

-- A cardboard carton filling the box x1..x2 / y1..y2 / z1..z2 (shelf stock).
-- Falls back to a plain box when the mesh is missing.
local CARTON_SIZE = Vector3.new(2.054, 1.31, 1.557)
local function carton(c: Ctx, name: string, x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, color: Color3, yaw: number?)
	if not MeshLib.has("Carton") then
		return B.box(c, name, x1, y1, z1, x2, y2, z2, color, M.Cardboard, { CanQuery = false })
	end
	local size = Vector3.new(x2 - x1, y2 - y1, z2 - z1)
	local cf = c.origin * CFrame.new((x1 + x2) / 2, y1, (z1 + z2) / 2) * CFrame.Angles(0, yaw or 0, 0)
	MeshLib.place(c.parent, "Carton", cf, {
		Box = color, Rib = color:Lerp(Color3.new(0, 0, 0), 0.12), Tape = color:Lerp(Color3.fromRGB(214, 176, 120), 0.6), Label = Color3.fromRGB(250, 248, 240),
	}, { scale = Vector3.new(size.X / CARTON_SIZE.X, size.Y / CARTON_SIZE.Y, size.Z / CARTON_SIZE.Z), materials = { Box = M.Cardboard, Rib = M.Cardboard, Tape = M.SmoothPlastic, Label = M.SmoothPlastic } })
	return nil
end

local function plant(c: Ctx, x: number, z: number, scale: number?)
	local s = scale or 1
	local m = B.model(c, "Plant")
	B.cyl(m, "Pot", 1.6 * s, 1.6 * s, x, 0, z, C.WHITE, M.SmoothPlastic)
	B.cyl(m, "PotRim", 1.75 * s, 0.2 * s, x, 1.5 * s, z, C.WHITE:Lerp(C.BLACK, 0.08), M.SmoothPlastic)
	B.cyl(m, "Soil", 1.45 * s, 0.1, x, 1.55 * s, z, C.WOOD_DARK, M.Ground)
	local rng = Random.new(math.floor(x * 7 + z * 13))
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local h = rng:NextNumber(1.6, 2.6) * s
		B.part(m, "Leaf", Vector3.new(0.5 * s, h, 0.12 * s), CFrame.new(x + math.cos(a) * 0.35 * s, 1.6 * s + h / 2, z + math.sin(a) * 0.35 * s) * CFrame.Angles(math.cos(a) * 0.45, 0, -math.sin(a) * 0.45), C.GREEN:Lerp(Color3.fromRGB(40, 120, 60), rng:NextNumber()), M.SmoothPlastic)
	end
	return m
end

local function ceilingLight(c: Ctx, x: number, z: number, w: number?, d: number?)
	local p = B.box(c, "CeilingLight", x - (w or 4) / 2, 12.85, z - (d or 1.6) / 2, x + (w or 4) / 2, 13.0, z + (d or 1.6) / 2, Color3.fromRGB(236, 230, 214), M.Neon)
	B.surfaceLight(p, Enum.NormalId.Bottom, Color3.fromRGB(255, 244, 225), 16, 0.5, 120)
	return p
end

-- A Blender bar prop (FrameBar / SignEdge: constant profile, 1 stud long)
-- stretched between two points. `yaw` turns the bar's face (+Z) to point
-- away from the wall: 0 = +Z, pi = -Z, -pi/2 = -X, pi/2 = +X.
local function meshBar(c: Ctx, prop: string, h: number, a: Vector3, b: Vector3, yaw: number, color: Color3, mat: Enum.Material)
	local d = b - a
	local len = d.Magnitude
	if len < 0.05 then
		return
	end
	local vertical = math.abs(d.Y) > math.abs(d.X) + math.abs(d.Z)
	local rot = CFrame.Angles(0, yaw, 0) * (if vertical then CFrame.Angles(0, 0, math.pi / 2) else CFrame.new())
	local cf = c.origin * CFrame.new((a + b) / 2) * rot * CFrame.new(0, -h / 2, 0)
	MeshLib.place(c.parent, prop, cf, { [if prop == "SignEdge" then "Edge" else "Frame"] = color }, { scale = Vector3.new(len, 1, 1), materials = { Edge = mat, Frame = mat }, shadow = false })
end

-- Rounded cabinet edge around a rectangle x1..x2 / y1..y2 in the plane z
-- (signs, menu boards, screens). Returns false when the mesh is missing.
local EDGE_H = 0.4
local function edgeFrame(c: Ctx, x1: number, y1: number, x2: number, y2: number, z: number, color: Color3, mat: Enum.Material?): boolean
	if not MeshLib.has("SignEdge") then
		return false
	end
	local m = mat or M.SmoothPlastic
	local h = EDGE_H / 2
	meshBar(c, "SignEdge", EDGE_H, Vector3.new(x1 - EDGE_H, y2 + h, z), Vector3.new(x2 + EDGE_H, y2 + h, z), 0, color, m)
	meshBar(c, "SignEdge", EDGE_H, Vector3.new(x1 - EDGE_H, y1 - h, z), Vector3.new(x2 + EDGE_H, y1 - h, z), 0, color, m)
	meshBar(c, "SignEdge", EDGE_H, Vector3.new(x1 - h, y1, z), Vector3.new(x1 - h, y2, z), 0, color, m)
	meshBar(c, "SignEdge", EDGE_H, Vector3.new(x2 + h, y1, z), Vector3.new(x2 + h, y2, z), 0, color, m)
	return true
end

local function screen(c: Ctx, name: string, x1: number, y1: number, x2: number, y2: number, z: number, faceZ: number): Part
	-- A hanging flat screen. faceZ = 1 faces +Z, -1 faces -Z.
	local frame = B.box(c, name .. "Frame", x1 - 0.15, y1 - 0.15, z - 0.2, x2 + 0.15, y2 + 0.15, z + 0.2, C.BLACK)
	edgeFrame(c, x1 - 0.15, y1 - 0.15, x2 + 0.15, y2 + 0.15, z, Color3.fromRGB(34, 34, 38), M.Metal)
	local scr = B.box(c, name, x1, y1, z - 0.22 * (faceZ > 0 and -1 or 1) - 0.02, x2, y2, z - 0.22 * (faceZ > 0 and -1 or 1) + 0.02, Color3.fromRGB(10, 10, 14))
	scr.CanQuery = false
	frame.CanQuery = false
	-- hanging rods
	B.box(c, "Rod", x1 + 0.3, y2 + 0.15, z - 0.06, x1 + 0.42, 13, z + 0.06, C.BLACK, M.Metal)
	B.box(c, "Rod", x2 - 0.42, y2 + 0.15, z - 0.06, x2 - 0.3, 13, z + 0.06, C.BLACK, M.Metal)
	return scr
end

------------------------------------------------------------------ shell

-- One moulded frame bar between two points in a wall plane. `yaw` turns the
-- bar's face (+Z) to the wall's outside: 0 = +Z, pi = -Z, -pi/2 = -X, pi/2 = +X.
local FRAME_H = 0.3
local function frameBar(c: Ctx, a: Vector3, b: Vector3, yaw: number, color: Color3)
	meshBar(c, "FrameBar", FRAME_H, a, b, yaw, color, M.Metal)
end

-- Perimeter frame for a window opening. Front/back walls: x1..x2 at plane z.
-- Side walls: z1..z2 at plane x (`side` = true).
local function frameOpening(c: Ctx, u1: number, u2: number, y1: number, y2: number, plane: number, side: boolean, yaw: number, color: Color3)
	local h = FRAME_H / 2
	local function P(u: number, y: number): Vector3
		return if side then Vector3.new(plane, y, u) else Vector3.new(u, y, plane)
	end
	frameBar(c, P(u1, y1 + h), P(u2, y1 + h), yaw, color)
	frameBar(c, P(u1, y2 - h), P(u2, y2 - h), yaw, color)
	frameBar(c, P(u1 + h, y1 + FRAME_H), P(u1 + h, y2 - FRAME_H), yaw, color)
	frameBar(c, P(u2 - h, y1 + FRAME_H), P(u2 - h, y2 - FRAME_H), yaw, color)
end

local function windowFrames(s: Ctx, sf: Ctx, sb: Ctx, winW: { { number } }, winBackW: { number }, winBackE: { number })
	if not MeshLib.has("FrameBar") then
		return
	end
	-- storefront: black aluminium, matching the door frames
	for _, g in { { XW + 2, -29.2 }, { -28, -17.2 }, { -16.4, -5.6 }, { -4.8, 12 }, { 22.5, 28.5 }, { 29.7, XE - 2 } } do
		local yb = if g[1] >= 22.5 then 2.6 else 1.4
		frameOpening(sf, g[1], g[2], yb, 10, 22, false, 0, C.BLACK)
	end
	-- side + back windows: white frames with a centre mullion
	for _, w in winW do
		frameOpening(s, w[1], w[2], w[4], w[3], XW, true, -math.pi / 2, C.WHITE)
		frameBar(s, Vector3.new(XW, w[4] + FRAME_H, (w[1] + w[2]) / 2), Vector3.new(XW, w[3] - FRAME_H, (w[1] + w[2]) / 2), -math.pi / 2, C.WHITE)
	end
	frameOpening(s, winBackW[1], winBackW[2], winBackW[4], winBackW[3], XW, true, -math.pi / 2, C.WHITE)
	frameOpening(s, winBackE[1], winBackE[2], winBackE[4], winBackE[3], XE, true, math.pi / 2, C.WHITE)
	for _, w in { { 1.5, 8.5 }, { 17, 25 } } do
		frameOpening(sb, w[1], w[2], 4, 9, -22, false, math.pi, C.WHITE)
	end
end

local function buildShell(c: Ctx)
	local s = B.folder(c, "Shell")
	-- The storefront (written for z = 22) and the back facade (written for
	-- z = -22) are built on offset contexts so the dining room and the back
	-- rooms are deeper than the kitchen; spanning pieces use ZF / ZB.
	local sf = B.sub(s, 0, DF, 0)
	local sb = B.sub(s, 0, -DB, 0)
	local winW = { { 10, 18, 10, 2 }, { 24, 32, 10, 2 } } -- dining side windows (z1, z2, top, bottom)
	local winBackW = { -30, -25, 9, 4 } -- storage room side window (clear of shelving)
	local winBackE = { -22, -14, 9, 4 } -- staff room side window
	local swk = B.sub(s, -DW, 0, 0) -- west-wall kitchen kit (hood, chimney)
	-- Foundation + floors
	B.box(s, "Foundation", XW - 1, -1.2, ZB - 1, XE + 1, -0.2, ZF + 1, C.STONE, M.Concrete)
	B.box(s, "KitchenFloor", IW, -0.2, -8, IE, 0, 6, C.TILE_FLOOR, M.CeramicTiles)
	B.box(s, "DiningFloor", IW, -0.2, 6, IE, 0, ZF - 0.5, C.WOOD_FLOOR, M.WoodPlanks)
	B.box(s, "StorageFloor", IW, -0.2, ZB + 0.5, -2, 0, -8, C.CONCRETE, M.Concrete)
	B.box(s, "OfficeFloor", -2, -0.2, ZB + 0.5, 12, 0, -8, Color3.fromRGB(96, 108, 130), M.Carpet)
	B.box(s, "StaffFloor", 12, -0.2, ZB + 0.5, IE, 0, -8, C.WOOD_FLOOR:Lerp(C.WHITE, 0.15), M.WoodPlanks)
	-- Floor drains (kitchen detail)
	for _, x in { -14, 10 } do
		B.box(s, "Drain", x - 0.6, 0, 1.4, x + 0.6, 0.02, 2.6, C.STEEL_DARK, M.DiamondPlate)
	end

	-- Exterior walls (brick lower, cream band upper)
	local function exterior(name: string, fn: (y1: number, y2: number, color: Color3, mat: Enum.Material) -> ())
		fn(0, 11, C.BRICK, M.Brick)
		fn(11, 14, C.CREAM, M.Plaster)
	end
	-- Front (street) wall
	local frontOpenings = function()
		return {
			{ XW + 2, -29.2, 10, 1.4 },
			{ -28, -17.2, 10, 1.4 },
			{ -16.4, -5.6, 10, 1.4 },
			{ -4.8, 12, 10, 1.4 },
			{ 13.5, 20.5, 8.6 },
			{ 22.5, 28.5, 10, 2.6 },
			{ 29.7, XE - 2, 10, 2.6 },
		}
	end
	exterior("Front", function(y1, y2, col, mat)
		B.wallX(sf, "FrontWall", 22, XW - 0.5, XE + 0.5, y1, y2, 1, col, mat, if y1 == 0 then frontOpenings() else nil)
	end)
	-- Back wall (back door + windows)
	exterior("Back", function(y1, y2, col, mat)
		B.wallX(sb, "BackWall", -22, XW - 0.5, XE + 0.5, y1, y2, 1, col, mat, if y1 == 0 then { { -27, -22, 8.4 }, { 1.5, 8.5, 9, 4 }, { 17, 25, 9, 4 } } else nil)
	end)
	-- West wall x = -30
	exterior("West", function(y1, y2, col, mat)
		B.wallZ(s, "WestWall", XW, ZB + 0.5, ZF - 0.5, y1, y2, 1, col, mat, if y1 == 0 then { winW[1], winW[2], winBackW } else nil)
	end)
	-- East wall x = 30 (dining part is a separate model for the extension upgrade)
	exterior("East", function(y1, y2, col, mat)
		B.wallZ(s, "EastWall", XE, ZB + 0.5, 7, y1, y2, 1, col, mat, if y1 == 0 then { winBackE } else nil)
	end)
	local eastDining = B.model(s, "EastDiningWall")
	eastDining.parent:SetAttribute("HideWhen", "expansion_1")
	exterior("EastD", function(y1, y2, col, mat)
		B.wallZ(eastDining, "EastWall", XE, 7, ZF - 0.5, y1, y2, 1, col, mat, if y1 == 0 then { winW[1], winW[2] } else nil)
	end)
	for _, w in winW do
		B.box(eastDining, "Glass", XE - 0.1, w[4], w[1], XE + 0.1, w[3], w[2], C.GLASS, M.Glass, { Transparency = 0.65, CastShadow = false })
		B.box(eastDining, "Mullion", XE - 0.2, w[4], (w[1] + w[2]) / 2 - 0.1, XE + 0.2, w[3], (w[1] + w[2]) / 2 + 0.1, C.BLACK, M.Metal)
	end
	B.wallZ(eastDining, "InEastDining", IE - 0.08, 6, ZF - 0.6, 3.6, 13, 0.1, Color3.fromRGB(246, 232, 204), M.Plaster, { winW[1], winW[2] })

	-- Corner piers, base plinth and cornice
	for _, x in { XW - 0.5, XE + 0.5 } do
		for _, z in { ZB - 0.5, ZF + 0.5 } do
			B.box(s, "Pier", x - 0.7, 0, z - 0.7, x + 0.7, 14.6, z + 0.7, C.CREAM, M.Plaster)
		end
	end
	B.box(sf, "PlinthF", XW - 1, 0, 22.4, XE + 1, 1.4, 22.8, C.STONE, M.Slate)
	B.box(sb, "PlinthB", XW - 1, 0, -22.8, XE + 1, 1.4, -22.4, C.STONE, M.Slate)
	B.box(sf, "CorniceF", XW - 1.2, 14, 22.3, XE + 1.2, 14.7, 23.1, C.WHITE, M.Plaster)
	B.box(sb, "CorniceB", XW - 1.2, 14, -23.1, XE + 1.2, 14.7, -22.3, C.WHITE, M.Plaster)
	B.box(s, "CorniceW", XW - 1.1, 14, ZB - 1.1, XW - 0.3, 14.7, ZF + 1.1, C.WHITE, M.Plaster)
	B.box(s, "CorniceE", XE + 0.3, 14, ZB - 1.1, XE + 1.1, 14.7, ZF + 1.1, C.WHITE, M.Plaster)
	B.box(sf, "StripeF", XW - 1, 10.8, 22.45, XE + 1, 11.2, 22.65, C.RED, M.SmoothPlastic)

	-- Storefront glass + mullions
	local glass = { { XW + 2, -29.2 }, { -28, -17.2 }, { -16.4, -5.6 }, { -4.8, 12 }, { 22.5, 28.5 }, { 29.7, XE - 2 } }
	for _, g in glass do
		local yb = if g[1] >= 22.5 then 2.6 else 1.4
		B.box(sf, "Glass", g[1], yb, 21.9, g[2], 10, 22.1, C.GLASS, M.Glass, { Transparency = 0.65, CastShadow = false })
		B.box(sf, "SillOut", g[1] - 0.2, yb - 0.2, 21.6, g[2] + 0.2, yb, 22.9, C.WHITE, M.Plaster)
		local n = math.max(1, math.floor((g[2] - g[1]) / 4))
		for i = 1, n - 1 do
			local x = g[1] + (g[2] - g[1]) * i / n
			B.box(sf, "Mullion", x - 0.12, yb, 21.85, x + 0.12, 10, 22.2, C.BLACK, M.Metal)
		end
		B.box(sf, "Transom", g[1], 7.4, 21.85, g[2], 7.6, 22.2, C.BLACK, M.Metal)
	end
	-- Side windows (west dining + both back rooms)
	for _, w in { { XW, winW[1] }, { XW, winW[2] }, { XW, winBackW }, { XE, winBackE } } do
		local o = w[2]
		B.box(s, "Glass", w[1] - 0.1, o[4], o[1], w[1] + 0.1, o[3], o[2], C.GLASS, M.Glass, { Transparency = 0.65, CastShadow = false })
	end
	for _, w in { { 1.5, 8.5 }, { 17, 25 } } do
		B.box(sb, "Glass", w[1], 4, -22.1, w[2], 9, -21.9, C.GLASS, M.Glass, { Transparency = 0.65, CastShadow = false })
	end
	windowFrames(s, sf, sb, winW, winBackW, winBackE)

	-- Entrance: frame + glass doors (non-colliding, stand slightly open)
	B.box(sf, "DoorFrameL", 13.3, 0, 21.6, 13.7, 8.8, 22.6, C.BLACK, M.Metal)
	B.box(sf, "DoorFrameR", 20.3, 0, 21.6, 20.7, 8.8, 22.6, C.BLACK, M.Metal)
	B.box(sf, "DoorFrameT", 13.3, 8.4, 21.6, 20.7, 8.8, 22.6, C.BLACK, M.Metal)
	local doors = {}
	if MeshLib.has("DoorLeaf") then
		-- Blender door leaves: aluminium frame, glass, push bar, kick plate
		for _, d in { { 13.7, -70, 1.65 }, { 20.3, 70, -1.65 } } do
			local cf = sf.origin * CFrame.new(d[1], 0, 22) * CFrame.Angles(0, math.rad(d[2]), 0) * CFrame.new(d[3], 0, 0)
			local parts = MeshLib.place(s.parent, "DoorLeaf", cf, { Frame = C.BLACK, Glass = C.GLASS, Bar = C.STEEL, Kick = C.STEEL },
				{ materials = { Frame = M.Metal, Glass = M.Glass, Bar = M.Metal, Kick = M.Metal } })
			if parts.Glass then
				parts.Glass.Transparency = 0.55
				parts.Glass.CastShadow = false
			end
		end
	else
		doors = {
			B.part(sf, "DoorL", Vector3.new(3.3, 8.2, 0.15), CFrame.new(13.7, 4.1, 22) * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(1.65, 0, 0), C.GLASS, M.Glass, { Transparency = 0.55, CanCollide = false }),
			B.part(sf, "DoorR", Vector3.new(3.3, 8.2, 0.15), CFrame.new(20.3, 4.1, 22) * CFrame.Angles(0, math.rad(70), 0) * CFrame.new(-1.65, 0, 0), C.GLASS, M.Glass, { Transparency = 0.55, CanCollide = false }),
		}
	end
	for _, d in doors do
		local bar = Instance.new("Part")
		bar.Anchored = true
		bar.CanCollide = false
		bar.Size = Vector3.new(2.6, 0.18, 0.3)
		bar.CFrame = d.CFrame * CFrame.new(0, -0.3, 0)
		bar.Color = C.STEEL
		bar.Material = M.Metal
		bar.Parent = d.Parent
	end
	B.box(sf, "DoorMat", 14, 0, 18.5, 20, 0.05, 21.4, C.DARK, M.Fabric)
	B.box(sf, "Step", 13, -0.2, 22.5, 21, 0.05, 25, C.CONCRETE, M.Concrete)

	-- Back door (steel, kept open)
	B.box(sb, "BackDoorFrame", -27.2, 8.4, -22.6, -21.8, 8.8, -21.4, C.STEEL_DARK, M.Metal)
	B.part(sb, "BackDoor", Vector3.new(4.8, 8.2, 0.2), CFrame.new(-27, 4.1, -22) * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(2.4, 0, 0), C.STEEL, M.Metal, { CanCollide = false })
	local exit = B.box(sb, "ExitSign", -25.6, 9, -21.4, -23.4, 9.7, -21.3, Color3.fromRGB(40, 200, 90), M.Neon)
	B.label(exit, Enum.NormalId.Back, "EXIT", { color = C.WHITE, font = Enum.Font.GothamBlack })

	-- Ceiling + roof
	B.box(s, "Ceiling", IW, 13, ZB + 0.5, IE, 13.4, ZF - 0.5, Color3.fromRGB(236, 234, 230), M.SmoothPlastic)
	B.box(s, "Roof", XW - 0.5, 13.4, ZB - 0.5, XE + 0.5, 14.2, ZF + 0.5, C.DARK, M.Asphalt)
	B.box(sf, "Parapet", XW - 1, 14.2, 22.1, XE + 1, 16.2, 22.9, C.CREAM, M.Plaster)
	B.box(sf, "ParapetCap", XW - 1.2, 16.2, 21.9, XE + 1.2, 16.5, 23.1, C.WHITE, M.Plaster)
	B.box(s, "HVAC", -12, 14.2, -16, -4, 17, -10, C.STEEL, M.Metal)
	B.box(s, "HVACGrill", -11.6, 15, -16.1, -4.4, 16.6, -15.95, C.STEEL_DARK, M.DiamondPlate)
	B.cyl(swk, "OvenChimney", 1.6, 5, -27, 14.2, -4.5, C.STEEL_DARK, M.Metal)

	-- Awning over the storefront (red/white stripes)
	local aw = B.model(sf, "Awning")
	local stripes = 2 * math.floor((12.5 - (XW + 1)) / 3.8 + 0.5)
	local x1, x2 = XW + 1, 12.5
	local sw = (x2 - x1) / stripes
	if MeshLib.has("Awning") then
		-- curved fabric bays (one red + one white stripe each) with a scalloped valance
		local bays = stripes // 2
		local bw = (x2 - x1) / bays
		for i = 0, bays - 1 do
			MeshLib.place(aw.parent, "Awning", sf.origin * CFrame.new(x1 + bw * (i + 0.5), 11.55 - 2.81, 22.6), {
				Red = C.RED, White = C.WHITE, Rod = C.BLACK,
			}, { scale = Vector3.new(bw / 2, 1, 1), materials = { Red = M.Fabric, White = M.Fabric, Rod = M.Metal } })
		end
		stripes = 0
	end
	for i = 0, stripes - 1 do
		local col = if i % 2 == 0 then C.RED else C.WHITE
		local x = x1 + sw * (i + 0.5)
		B.part(aw, "Stripe", Vector3.new(sw, 0.2, 4.6), CFrame.new(x, 10.4, 24.4) * CFrame.Angles(math.rad(-28), 0, 0), col, M.Fabric)
		B.part(aw, "Valance", Vector3.new(sw, 0.9, 0.1), CFrame.new(x, 9.0, 26.45), col, M.Fabric)
	end
	B.box(aw, "AwningBar", x1, 11.3, 22.4, x2, 11.6, 22.8, C.BLACK, M.Metal)

	-- Rooftop sign: PIZZA PLANET with a planet logo
	local signM = B.model(sf, "RoofSign")
	local board = B.box(signM, "Board", -16, 16.5, 21.6, 14, 21.5, 22.4, C.RED, M.SmoothPlastic)
	if not edgeFrame(signM, -16, 16.5, 14, 21.5, 22, C.YELLOW) then
		B.box(signM, "BoardTrim", -16.3, 16.3, 21.5, 14.3, 21.7, 22.3, C.YELLOW, M.SmoothPlastic)
	end
	B.label(board, Enum.NormalId.Back, "PIZZA PLANET", { guiName = "SignText", color = C.WHITE, font = Enum.Font.FredokaOne, ppu = 30, pad = 18, brightness = 2.5, light = 0 })
	if MeshLib.has("PlanetSign") then
		-- sculpted cratered planet + banded ring (planet centre 4.7 above the mesh base)
		local parts = MeshLib.place(signM.parent, "PlanetSign", signM.origin * CFrame.new(19, 19.5 - 4.7, 22), {
			Planet = C.RED, Crater = C.RED_DARK, Ring = C.YELLOW, Band = Color3.fromRGB(255, 150, 40), Mount = C.BLACK,
		}, { materials = { Planet = M.SmoothPlastic, Crater = M.SmoothPlastic, Ring = M.SmoothPlastic, Band = M.Neon, Mount = M.Metal } })
		if parts.Planet then
			B.pointLight(parts.Planet, Color3.fromRGB(255, 120, 90), 18, 1.2)
		end
	else
		local planet = B.ball(signM, "Planet", Vector3.new(7, 7, 7), 19, 19.5, 22, C.RED, M.SmoothPlastic)
		B.part(signM, "Ring", Vector3.new(0.3, 10.5, 10.5), CFrame.new(19, 19.5, 22) * CFrame.Angles(math.rad(-12), 0, math.rad(72)), C.YELLOW, M.Neon, { Shape = Enum.PartType.Cylinder })
		B.ball(signM, "Crater", Vector3.new(1.4, 1.4, 0.6), 17.6, 20.8, 25.3, C.RED_DARK, M.SmoothPlastic)
		B.ball(signM, "Crater", Vector3.new(1, 1, 0.5), 20.5, 18.4, 25.4, C.RED_DARK, M.SmoothPlastic)
		B.pointLight(planet, Color3.fromRGB(255, 120, 90), 18, 1.2)
	end
	for _, x in { -12, 0, 10 } do
		B.box(signM, "Post", x - 0.2, 14.2, 21.9, x + 0.2, 16.6, 22.1, C.BLACK, M.Metal)
	end
	-- Facade name panel above door
	local namePanel = B.box(sf, "DoorSign", 13.4, 9.0, 22.55, 20.6, 10.6, 22.75, C.YELLOW)
	B.label(namePanel, Enum.NormalId.Back, "ENTRANCE", { color = C.RED_DARK, font = Enum.Font.GothamBlack, pad = 6 })
	edgeFrame(sf, 13.4, 9.0, 20.6, 10.6, 22.65, C.RED)
	if MeshLib.has("BladeSign") then
		-- wrought-iron bracket sign over the right-hand window, readable along the street
		local parts = MeshLib.place(sf.parent, "BladeSign", sf.origin * CFrame.new(25.5, 10.3, 22.5), { Iron = C.BLACK, Rim = C.YELLOW },
			{ materials = { Iron = M.Metal, Rim = M.Metal } })
		if parts.Rim then
			local disc = Instance.new("Part")
			disc.Name = "BladeDisc"
			disc.Shape = Enum.PartType.Cylinder
			disc.Size = Vector3.new(0.12, 2.55, 2.55)
			disc.CFrame = CFrame.new(parts.Rim.Position) * (sf.origin - sf.origin.Position)
			disc.Color = C.RED
			disc.Material = M.SmoothPlastic
			disc.Anchored = true
			disc.CanCollide = false
			disc.CanQuery = false
			disc.Parent = sf.parent
			for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
				B.label(disc, face, "🍕\nPIZZA", { color = C.WHITE, font = Enum.Font.FredokaOne, pad = 14, brightness = 1.5 })
			end
		end
	end
	-- Wall lanterns
	for _, x in { XW + 0.5, 12.8, 21.2, 29.2, XE - 0.5 } do
		if MeshLib.has("WallLamp") then
			local parts = MeshLib.place(s.parent, "WallLamp", sf.origin * CFrame.new(x, 8.7, 22.6), {
				Metal = C.BLACK, Cap = C.BLACK, Cage = C.BLACK, Glow = Color3.fromRGB(255, 214, 140),
			}, { materials = { Metal = M.Metal, Cap = M.Metal, Cage = M.Metal, Glow = M.Neon } })
			if parts.Glow then
				B.pointLight(parts.Glow, Color3.fromRGB(255, 210, 150), 14, 1)
			end
		else
			local lamp = B.box(sf, "WallLamp", x - 0.35, 8.8, 22.5, x + 0.35, 9.8, 23.2, C.YELLOW, M.Neon)
			B.box(sf, "LampCap", x - 0.5, 9.8, 22.5, x + 0.5, 10.05, 23.35, C.BLACK, M.Metal)
			B.pointLight(lamp, Color3.fromRGB(255, 210, 150), 14, 1)
		end
	end

	-- Interior partitions
	local inner = Color3.fromRGB(236, 232, 224)
	B.wallX(s, "Partition", -8, IW, IE, 0, 13, 0.6, inner, M.Plaster, { { -5.6, -2.4, 8.4 }, { 1.5, 6.5, 8.4 }, { 13, 17, 8.4 } })
	B.wallZ(s, "Partition", -2, ZB + 0.5, -8.3, 0, 13, 0.6, inner, M.Plaster)
	B.wallZ(s, "Partition", 12, ZB + 0.5, -8.3, 0, 13, 0.6, inner, M.Plaster)
	-- Kitchen wall tiles (white, waist-high red stripe)
	B.box(s, "KTileBack", IW, 0, -7.7, IE, 8.5, -7.65, C.TILE_WALL, M.CeramicTiles)
	B.box(s, "KTileStripe", IW, 5.6, -7.66, IE, 5.9, -7.62, C.RED)
	B.box(s, "KTileWest", IW, 0, -7.7, IW + 0.05, 8.5, 6, C.TILE_WALL, M.CeramicTiles)
	B.box(s, "KTileEast", IE - 0.05, 0, -7.7, IE, 8.5, 6, C.TILE_WALL, M.CeramicTiles)
	-- Dining walls: dark red wainscot + cream plaster
	local wcut = { { 10, 18, 3.6, 2 }, { 24, 32, 3.6, 2 } }
	B.wallZ(s, "Wainscot", IW + 0.05, 6, ZF - 0.5, 0, 3.6, 0.1, C.RED_DARK, M.Wood, wcut)
	-- east panelling lives in the wall section the annex upgrade removes
	B.wallZ(eastDining, "Wainscot", IE - 0.05, 6, ZF - 0.5, 0, 3.6, 0.1, C.RED_DARK, M.Wood, wcut)
	for _, r in { { 6, 10 }, { 18, 24 }, { 32, ZF - 0.5 } } do
		B.box(s, "Rail", IW, 3.6, r[1], IW + 0.2, 3.8, r[2], C.WOOD_DARK, M.Wood)
	end

	-- Interior cladding so no exterior brick shows inside
	local paint = Color3.fromRGB(240, 236, 228)
	local warm = Color3.fromRGB(246, 232, 204)
	-- back rooms: back wall, west + east walls
	B.wallX(sb, "InBack", -21.45, IW, IE, 0, 13, 0.1, paint, M.Plaster, { { -27, -22, 8.4 }, { 1.5, 8.5, 9, 4 }, { 17, 25, 9, 4 } })
	B.wallZ(s, "InWestBack", IW + 0.05, ZB + 0.6, -8.3, 0, 13, 0.1, paint, M.Plaster, { { -30, -25, 9, 4 } })
	B.wallZ(s, "InEastBack", IE - 0.05, ZB + 0.6, -8.3, 0, 13, 0.1, paint, M.Plaster, { { -22, -14, 9, 4 } })
	-- kitchen: above the tiles
	B.box(s, "InWestKitchen", IW + 0.05, 8.5, -7.7, IW + 0.1, 13, 6, paint, M.Plaster)
	B.box(s, "InEastKitchen", IE - 0.1, 8.5, -7.7, IE - 0.05, 13, 6, paint, M.Plaster)
	-- dining: above the wainscot (west), front wall inner face
	B.wallZ(s, "InWestDining", IW + 0.08, 6, ZF - 0.6, 3.6, 13, 0.1, warm, M.Plaster, { { 10, 18, 10, 2 }, { 24, 32, 10, 2 } })
	B.wallX(sf, "InFront", 21.45, IW + 0.1, IE - 0.1, 0, 13, 0.1, warm, M.Plaster, {
		{ XW + 2, -29.2, 10, 1.4 },
		{ 29.7, XE - 2, 10, 2.6 },
		{ -28, -17.2, 10, 1.4 },
		{ -16.4, -5.6, 10, 1.4 },
		{ -4.8, 12, 10, 1.4 },
		{ 13.5, 20.5, 8.6 },
		{ 22.5, 28.5, 10, 2.6 },
	})

	-- Ceiling lights
	for _, z in { -3, 2 } do
		for _, x in { -33, -22, -11, 0, 11, 22, 33 } do
			ceilingLight(s, x, z)
		end
	end
	for _, z in { 10, 16.5, 23, 29.5 } do
		for _, x in { -33, -22, -11, 0, 11, 22, 33 } do
			ceilingLight(s, x, z, 3, 3)
		end
	end
	for _, p in { { -16, -14 }, { -22, -24 }, { -32, -14 }, { -32, -25 }, { 4, -14 }, { 4, -25 }, { 21, -14 }, { 21, -25 }, { 32, -14 }, { 32, -25 }, { -8, -26 } } do
		ceilingLight(s, p[1], p[2], 4, 2)
	end
	-- Kitchen extractor hood over the ovens
	if MeshLib.has("Hood") then
		-- canopy hood with baffle filters + strip light; front faces the kitchen (+X).
		-- Squashed a little in Y so the duct ends inside the ceiling.
		MeshLib.place(s.parent, "Hood", swk.origin * CFrame.new(-26.25, 9.5, -1.6) * CFrame.Angles(0, math.pi / 2, 0), {
			Body = C.STEEL, Duct = C.STEEL:Lerp(C.BLACK, 0.08), Filter = C.STEEL_DARK, Light = Color3.fromRGB(255, 244, 220),
		}, { scale = Vector3.new(1, 0.75, 1), materials = { Body = M.Metal, Duct = M.Metal, Filter = M.DiamondPlate, Light = M.Neon } })
	else
		B.box(swk, "Hood", -29.5, 9.5, -8, -23, 10.5, 4.8, C.STEEL, M.Metal)
		B.wedge(swk, "HoodSlope", Vector3.new(13, 1.6, 6.5), CFrame.new(-26.25, 11.3, -1.6) * CFrame.Angles(0, math.rad(-90), 0), C.STEEL, M.Metal)
		B.box(swk, "HoodDuct", -28.5, 10.5, -5.5, -26, 13, -3.5, C.STEEL, M.Metal)
	end
end

------------------------------------------------------------------ kitchen

local function buildOven(c: Ctx, name: string, z: number, slotLabel: string): Ctx
	-- Stone dome pizza oven against the west wall, mouth facing +X.
	local s = B.sub(c, -26.8, z, 90)
	local m = B.model(s, name)
	local meshOven = MeshLib.has("Oven")
	if meshOven then
		MeshLib.place(m.parent, "Oven", m.origin, {
			Plinth = C.BRICK, Slab = C.STONE, Dome = Color3.fromRGB(208, 120, 82), Band = C.RED_DARK,
			Arch = C.BRICK, Key = C.STONE, Soot = Color3.fromRGB(28, 14, 10), Chimney = C.STEEL_DARK, Shelf = C.STONE,
		}, {
			collide = true,
			materials = { Plinth = M.Brick, Slab = M.Slate, Dome = M.Plaster, Arch = M.Brick, Key = M.Slate, Chimney = M.Metal, Shelf = M.Slate },
		})
	else
		-- plinth (brick)
		B.box(m, "Plinth", -2.9, 0, -2.6, 2.9, 3.2, 2.6, C.BRICK, M.Brick)
		B.box(m, "PlinthTop", -3.05, 3.2, -2.75, 3.05, 3.5, 2.75, C.STONE, M.Slate)
	end
	-- wood store
	B.box(m, "WoodStore", -2, 0.4, 2.55, 2, 2.6, 2.65 + (meshOven and 0.03 or 0), C.BLACK)
	for i = 0, 3 do
		B.cyl(m, "Log", 0.55, 0.01, -1.4 + i * 0.9, 0.7, 2.67 + (meshOven and 0.03 or 0), C.WOOD_DARK, M.Wood)
	end
	if not meshOven then
		-- dome
		B.ball(m, "Dome", Vector3.new(5.6, 4.6, 5.2), 0, 3.6, -0.2, Color3.fromRGB(208, 120, 82), M.Plaster)
		B.ball(m, "DomeBand", Vector3.new(5.7, 1.0, 5.3), 0, 3.9, -0.2, C.RED_DARK, M.SmoothPlastic)
		-- mouth arch
		B.box(m, "MouthFace", -2.2, 3.5, 1.9, 2.2, 5.6, 2.6, C.BRICK, M.Brick)
		B.box(m, "MouthKey", -0.4, 5.4, 2.55, 0.4, 5.9, 2.75, C.STONE, M.Slate)
		local mouth = B.box(m, "Mouth", -1.5, 3.5, 1.85, 1.5, 4.9, 2.65, Color3.fromRGB(28, 14, 10))
		mouth.CanQuery = false
	end
	-- glowing embers at the back
	local embers = B.box(m, "Embers", -1.2, 3.5, -1.6, 1.2, 3.8, -0.8, Color3.fromRGB(255, 110, 30), M.Neon)
	B.pointLight(embers, Color3.fromRGB(255, 140, 60), 10, 2.5)
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 3
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = embers
	if not meshOven then
		B.box(m, "Chimney", -0.6, 5.6, -1.2, 0.6, 9.5, 0, C.STEEL_DARK, M.Metal)
		-- peel shelf
		B.box(m, "Shelf", -2.4, 3.35, 2.6, 2.4, 3.5, 3.4, C.STONE, M.Slate)
	end
	-- station hit area (in the mouth)
	local slot = B.hitbox(m, "OvenSlot", Vector3.new(3.4, 1.6, 2.4), CFrame.new(0, 4.2, 1.6))
	B.station(slot, "Oven", slotLabel)
	B.itemAt(slot, CFrame.new(0, -0.7, -0.4))
	-- temperature dial plate
	local bz = if meshOven then 0.03 else 0
	local plate = B.box(m, "Badge", -0.9, 2.2, 2.6 + bz, 0.9, 2.9, 2.7 + bz, C.YELLOW)
	B.label(plate, Enum.NormalId.Back, "400°C", { color = C.RED_DARK, font = Enum.Font.GothamBlack, pad = 4 })
	return m
end

local function buildPrepCounter(c: Ctx, name: string, x: number, boardId: string, label: string): Ctx
	-- Pizza prep counter against the back partition, facing +Z.
	local s = B.sub(c, x, -6.4, 0)
	local m = counter(s, name, 7.4, 2.6)
	-- wooden board
	local board = B.box(m, "Board", -1.7, COUNTER_H, -0.1, 1.7, COUNTER_H + 0.18, 1.25, C.WOOD, M.Wood)
	B.station(board, "PizzaBoard", label, { BoardId = boardId })
	B.itemAt(board, CFrame.new(0, 0.09, 0))
	-- topping rail (two tiers)
	local railMesh = MeshLib.has("PrepRail")
	if railMesh then
		-- rail housing, backsplash, bracketed upper shelf, LED strip and sneeze guard
		local rail = MeshLib.place(m.parent, "PrepRail", m.origin * CFrame.new(0, COUNTER_H, 0), {
			Steel = C.STEEL, Light = Color3.fromRGB(255, 240, 210), Glass = Color3.fromRGB(215, 235, 245),
		}, { materials = { Steel = M.Metal, Light = M.Neon, Glass = M.Glass } })
		if rail.Glass then
			rail.Glass.Transparency = 0.7
			rail.Glass.CastShadow = false
		end
	else
		B.box(m, "Rail1", -3.6, COUNTER_H, -1.25, 3.6, COUNTER_H + 0.35, -0.35, C.STEEL, M.Metal)
		B.box(m, "Rail2", -3.6, COUNTER_H, -1.3, 3.6, COUNTER_H + 0.9, -1.25, C.STEEL, M.Metal)
		B.box(m, "Backsplash", -3.7, COUNTER_H, -1.32, 3.7, COUNTER_H + 1.8, -1.28, C.STEEL, M.Metal)
	end
	local row1 = { "tomato_sauce", "mozzarella", "tomato", "pepperoni", "mushroom", "ham", "onion" }
	local row2 = { "bbq_sauce", "cheddar", "green_pepper", "chicken", "olive", "beef", "jalapeno" }
	for i, id in row1 do
		pan(m, id, -3.6 + 0.5 + (i - 1) * 1.03, COUNTER_H + 0.35, -0.8, boardId, 0.95)
	end
	-- upper tier sits on a raised shelf behind
	if not railMesh then
		B.box(m, "Shelf", -3.7, COUNTER_H + 1.8, -1.32, 3.7, COUNTER_H + 1.95, -0.55, C.STEEL, M.Metal)
	end
	for i, id in row2 do
		pan(m, id, -3.6 + 0.5 + (i - 1) * 1.03, COUNTER_H + 1.95, -0.95, boardId, 0.95)
	end
	-- heat-lamp style strip under shelf
	local strip = B.box(m, "LightStrip", -3.5, COUNTER_H + 1.7, -1.0, 3.5, COUNTER_H + 1.78, -0.7, Color3.fromRGB(255, 240, 210), M.Neon)
	if railMesh then
		strip.Transparency = 1 -- the mesh has its own LED strip; keep this part for its light
	end
	B.surfaceLight(strip, Enum.NormalId.Bottom, Color3.fromRGB(255, 236, 200), 6, 0.8)
	return m
end

local function buildKitchen(c: Ctx)
	local k = B.folder(c, "Kitchen")
	local kw = B.sub(k, -DW, 0, 0) -- along the (moved) west wall
	local ke = B.sub(k, DW, 0, 0) -- along the (moved) east wall

	-- Ovens (oven 2 is an upgrade)
	buildOven(kw, "Oven1", -4.6, "🔥 Pizza Oven")
	local o2 = buildOven(B.folder(kw, "Oven2Upgrade", "Model"), "Oven2", 1.6, "🔥 Pizza Oven 2")
	o2.parent.Parent:SetAttribute("UpgradeId", "oven_2")
	local o2Space = B.model(kw, "Oven2Placeholder")
	o2Space.parent:SetAttribute("HideWhen", "oven_2")
	counter(B.sub(o2Space, -27.8, 1.6, 90), "Bench", 5, 2.6)
	-- hotter oven trims
	local heat1 = B.model(kw, "OvenHeat1")
	heat1.parent:SetAttribute("UpgradeId", "oven_heat_1")
	for _, z in { -4.6, 1.6 } do
		B.box(heat1, "BrassTrim", -24.2, 3.4, z - 1.75, -23.95, 5.0, z + 1.75, Color3.fromRGB(230, 170, 60), M.Metal)
	end
	local heat2 = B.model(kw, "OvenHeat2")
	heat2.parent:SetAttribute("UpgradeId", "oven_heat_2")
	for _, z in { -4.6, 1.6 } do
		B.box(heat2, "GoldTrim", -23.95, 5.0, z - 1.75, -23.75, 5.3, z + 1.75, Color3.fromRGB(255, 210, 60), M.Neon)
	end

	-- Dough fridge (drawer unit) with a tray of dough on top
	-- extra worktop run between the dough fridge and the prep line
	local run = counter(B.sub(k, -26.3, -6.4, 0), "SideCounter", 7.4, 2.6)
	B.box(run, "MixerBase", -2.6, COUNTER_H, -0.8, -1.2, COUNTER_H + 0.5, 0.6, C.WHITE)
	B.box(run, "MixerArm", -2.4, COUNTER_H + 0.5, -0.8, -1.4, COUNTER_H + 2.2, -0.3, C.WHITE)
	B.box(run, "MixerHead", -2.5, COUNTER_H + 1.8, -0.8, -0.6, COUNTER_H + 2.4, 0.2, C.WHITE)
	B.cyl(run, "MixerBowl", 1.1, 0.8, -1.1, COUNTER_H, -0.1, C.STEEL, M.Metal)
	for i = 0, 2 do
		B.box(run, "FlourSack", 0.6 + i * 0.95, COUNTER_H, -1.0, 1.4 + i * 0.95, COUNTER_H + 1.0, -0.3, Color3.fromRGB(240, 232, 214), M.Fabric, { CanQuery = false })
	end
	local doughCtx = B.sub(kw, -21.9, -6.4, 0)
	local doughUnit = counter(doughCtx, "DoughFridge", 2.6, 2.6, { body = Color3.fromRGB(220, 224, 230) })
	B.box(doughUnit, "Tray", -1.2, COUNTER_H, -1.0, 1.2, COUNTER_H + 0.12, 1.0, C.STEEL_DARK, M.Metal)
	for i = 0, 5 do
		local dx = -0.75 + (i % 3) * 0.75
		local dz = -0.4 + (i // 3) * 0.8
		B.ball(doughUnit, "DoughBall", Vector3.new(0.7, 0.4, 0.7), dx, COUNTER_H + 0.3, dz, Color3.fromRGB(242, 224, 190), M.SmoothPlastic, { CanQuery = false })
	end
	local doughHit = B.hitbox(doughUnit, "DoughBin", Vector3.new(2.6, 0.9, 2.2), CFrame.new(0, COUNTER_H + 0.45, 0))
	B.station(doughHit, "Bin", "🍞 Dough Tray", { Ingredient = "dough" })
	local tempTag = B.box(doughUnit, "Temp", -0.6, 2.4, 1.36, 0.6, 2.8, 1.4, C.BLACK)
	B.label(tempTag, Enum.NormalId.Back, "3°C", { color = Color3.fromRGB(80, 220, 255), font = Enum.Font.Code })

	-- Prep counters
	buildPrepCounter(k, "PrepCounter1", -16.85, "pizza1", "🍕 Prep Board")
	local p2 = buildPrepCounter(B.folder(k, "Prep2Upgrade", "Model"), "PrepCounter2", -9.6, "pizza2", "🍕 Prep Board 2")
	p2.parent.Parent:SetAttribute("UpgradeId", "prep_2")
	local p2Space = B.model(k, "Prep2Placeholder")
	p2Space.parent:SetAttribute("HideWhen", "prep_2")
	local plain = counter(B.sub(p2Space, -9.6, -6.4, 0), "PlainCounter", 7.4, 2.6)
	for i = 0, 3 do
		B.box(plain, "BoxStack", -3 + i * 0.1, COUNTER_H, -0.9, -1.2 + i * 0.1, COUNTER_H + 0.15 * (i + 1), 0.9, C.WHITE)
	end
	-- Trash bin by the prep line
	local bin = B.model(k, "KitchenBin")
	if MeshLib.has("TrashBin") then
		MeshLib.place(bin.parent, "TrashBin", bin.origin * CFrame.new(-6.6, 0, -2.6), {
			Body = C.STEEL, Base = C.BLACK, Lid = C.STEEL:Lerp(C.WHITE, 0.15), Bag = C.BLACK, Pedal = C.BLACK,
		}, { collide = true, materials = { Body = M.Metal, Base = M.SmoothPlastic, Lid = M.Metal, Bag = M.SmoothPlastic, Pedal = M.SmoothPlastic } })
	else
		B.cyl(bin, "Bin", 1.7, 3, -6.6, 0, -2.6, C.STEEL_DARK, M.Metal)
		B.cyl(bin, "Lid", 1.8, 0.2, -6.6, 3, -2.6, C.BLACK)
	end
	local binHit = B.hitbox(bin, "TrashHit", Vector3.new(1.9, 3.4, 1.9), CFrame.new(-6.6, 1.7, -2.6))
	B.station(binHit, "Trash", "🗑️ Bin")

	-- Middle island: boxing + heat shelf (the pass)
	local island = B.sub(k, -13.5, 0.6, 180)
	local isl = counter(island, "Island", 9, 2.8)
	-- flat-pack pizza box stack
	for i = 0, 7 do
		B.box(isl, "FlatBox", 1.6, COUNTER_H + i * 0.12, -1.0, 4.2, COUNTER_H + i * 0.12 + 0.1, 1.1, if i % 2 == 0 then C.WHITE else Color3.fromRGB(240, 232, 216))
	end
	local boxTop = B.box(isl, "BoxLogo", 2.4, COUNTER_H + 0.96, -0.3, 3.4, COUNTER_H + 0.98, 0.5, C.RED)
	boxTop.CanQuery = false
	local boxHit = B.hitbox(isl, "BoxStation", Vector3.new(3, 1.4, 2.3), CFrame.new(2.9, COUNTER_H + 0.7, 0))
	B.station(boxHit, "BoxStation", "📦 Pizza Boxes")
	-- heat shelf gantry with 4 slots
	local gantryMesh = MeshLib.has("HeatGantry")
	if gantryMesh then
		-- steel deck, chrome posts, hood with four glowing heat-lamp shades
		MeshLib.place(isl.parent, "HeatGantry", isl.origin * CFrame.new(-1.8, COUNTER_H, 0), {
			Base = C.STEEL_DARK, Post = C.STEEL, Hood = C.STEEL, Glow = Color3.fromRGB(255, 130, 60),
		}, { materials = { Base = M.Metal, Post = M.Metal, Hood = M.Metal, Glow = M.Neon } })
	else
		B.box(isl, "ShelfBase", -4.4, COUNTER_H, -1.2, 0.8, COUNTER_H + 0.1, 1.2, C.STEEL_DARK, M.Metal)
		for _, x in { -4.3, 0.7 } do
			B.box(isl, "Post", x - 0.1, COUNTER_H, -0.1, x + 0.1, COUNTER_H + 3, 0.1, C.STEEL, M.Metal)
		end
		local lamp = B.box(isl, "HeatLamp", -4.4, COUNTER_H + 3, -0.6, 0.8, COUNTER_H + 3.3, 0.6, C.STEEL, M.Metal)
		lamp.CanQuery = false
	end
	local glow = B.box(isl, "LampGlow", -4.2, COUNTER_H + 2.95, -0.45, 0.6, COUNTER_H + 3.0, 0.45, Color3.fromRGB(255, 120, 50), M.Neon)
	glow.CanQuery = false
	if gantryMesh then
		glow.Transparency = 1 -- light source only; the mesh bulbs do the glowing
	end
	B.surfaceLight(glow, Enum.NormalId.Bottom, Color3.fromRGB(255, 150, 80), 6, 1.2)
	for i = 1, 4 do
		local sx = -3.75 + (i - 1) * 1.25
		local target = isl
		if i > 2 then
			local up = B.model(k, "HeatShelfSlot" .. i)
			up.parent:SetAttribute("UpgradeId", "heat_shelf_2")
			target = { parent = up.parent, origin = isl.origin }
		end
		local slot = B.box(target, "Slot" .. i, sx - 0.6, COUNTER_H + 0.1, -1.1, sx + 0.6, COUNTER_H + 0.15, 1.1, C.STEEL, M.Metal)
		B.station(slot, "HeatShelf", "♨️ Heat Shelf " .. i, { Slot = i })
		B.itemAt(slot, CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- Drinks island: cup stack + soda fountain
	local drinks = B.sub(k, 4, 0.6, 180)
	local dr = counter(drinks, "DrinksCounter", 7, 2.8)
	-- cup dispenser tube
	if MeshLib.has("CupDispenser") then
		local parts = MeshLib.place(dr.parent, "CupDispenser", dr.origin * CFrame.new(-2.6, COUNTER_H, 0.2), {
			Base = C.STEEL_DARK, Tube = Color3.fromRGB(215, 235, 245), Chrome = C.STEEL,
		}, { materials = { Base = M.Metal, Tube = M.Glass, Chrome = M.Metal } })
		if parts.Tube then
			parts.Tube.Transparency = 0.55
		end
	else
		B.cyl(dr, "CupTube", 0.9, 2.2, -2.6, COUNTER_H, 0.2, C.STEEL, M.Metal, { Transparency = 0.2 })
	end
	for i = 0, 5 do
		B.cyl(dr, "Cup", 0.75, 0.3, -2.6, COUNTER_H + 0.2 + i * 0.32, 0.2, if i % 2 == 0 then C.WHITE else C.RED, nil, { CanQuery = false })
	end
	local cupHit = B.hitbox(dr, "CupBin", Vector3.new(1.4, 2.6, 1.4), CFrame.new(-2.6, COUNTER_H + 1.2, 0.2))
	B.station(cupHit, "Bin", "🥤 Drink Cups", { Ingredient = "cup" })
	-- fountain body
	local fountainMesh = MeshLib.has("SodaFountain")
	if fountainMesh then
		-- three-valve tower with a slotted drip tray; flavour panels sit on its front face
		MeshLib.place(dr.parent, "SodaFountain", dr.origin * CFrame.new(0.8, COUNTER_H, -0.55), {
			Body = C.BLACK, Header = C.RED, Tray = C.STEEL_DARK, Chrome = C.STEEL, Lever = C.WHITE,
		}, { materials = { Body = M.SmoothPlastic, Header = M.SmoothPlastic, Tray = M.Metal, Chrome = M.Metal, Lever = M.SmoothPlastic } })
	else
		B.box(dr, "Fountain", -1.6, COUNTER_H, -1.3, 3.2, COUNTER_H + 3.4, 0.2, C.BLACK)
		B.box(dr, "DripTray", -1.5, COUNTER_H, 0.2, 3.1, COUNTER_H + 0.15, 1.2, C.STEEL_DARK, M.DiamondPlate)
	end
	local flavours = {
		{ "cola_syrup", "PLANET\nCOLA", Color3.fromRGB(200, 30, 30) },
		{ "orange_syrup", "ORBIT\nORANGE", Color3.fromRGB(255, 140, 20) },
		{ "lime_syrup", "LUNAR\nLIME", Color3.fromRGB(120, 210, 40) },
	}
	for i, f in flavours do
		local fx = -0.8 + (i - 1) * 1.55
		local panel = B.box(dr, "Panel_" .. f[1], fx - 0.65, COUNTER_H + 1.7, 0.2, fx + 0.65, COUNTER_H + 3.1, 0.3, f[3])
		B.label(panel, Enum.NormalId.Back, f[2], { color = C.WHITE, font = Enum.Font.FredokaOne, pad = 4, brightness = 1.5 })
		if not fountainMesh then
			B.box(dr, "Nozzle", fx - 0.15, COUNTER_H + 1.3, 0.25, fx + 0.15, COUNTER_H + 1.7, 0.55, C.STEEL, M.Metal)
		end
		local hit = B.hitbox(dr, "Fountain_" .. f[1], Vector3.new(1.3, 2.6, 1.2), CFrame.new(fx, COUNTER_H + 1.5, 0.6))
		B.station(hit, "Fountain", "🥤 " .. string.gsub(f[2], "\n", " "), { Ingredient = f[1] })
	end

	-- Kebab station (upgrade) along the east wall, facing -X
	local kebabFolder = B.model(ke, "KebabStation")
	kebabFolder.parent:SetAttribute("UpgradeId", "kebab_station")
	local ks = B.sub(kebabFolder, 28.2, -1.2, -90)
	local kc = counter(ks, "KebabCounter", 7.4, 2.6)
	local kboard = B.box(kc, "KebabBoard", -1.6, COUNTER_H, -0.1, 1.6, COUNTER_H + 0.18, 1.25, Color3.fromRGB(235, 235, 230), M.SmoothPlastic)
	B.station(kboard, "KebabBoard", "🥙 Kebab Board", { BoardId = "kebab1" })
	B.itemAt(kboard, CFrame.new(0, 0.09, 0))
	if MeshLib.has("PrepRail") then
		local rail = MeshLib.place(kc.parent, "PrepRail", kc.origin * CFrame.new(0, COUNTER_H, 0), {
			Steel = C.STEEL, Light = Color3.fromRGB(255, 240, 210), Glass = Color3.fromRGB(215, 235, 245),
		}, { materials = { Steel = M.Metal, Light = M.Neon, Glass = M.Glass } })
		if rail.Glass then
			rail.Glass.Transparency = 0.7
			rail.Glass.CastShadow = false
		end
	else
		B.box(kc, "Rail1", -3.6, COUNTER_H, -1.25, 3.6, COUNTER_H + 0.35, -0.35, C.STEEL, M.Metal)
		B.box(kc, "Backsplash", -3.7, COUNTER_H, -1.32, 3.7, COUNTER_H + 1.8, -1.28, C.STEEL, M.Metal)
		B.box(kc, "Shelf", -3.7, COUNTER_H + 1.8, -1.32, 3.7, COUNTER_H + 1.95, -0.55, C.STEEL, M.Metal)
	end
	local salad = { "lettuce", "tomato", "cucumber", "red_cabbage", "onion", "cheddar" }
	for i, id in salad do
		pan(kc, id, -3.6 + 0.6 + (i - 1) * 1.2, COUNTER_H + 0.35, -0.8, "kebab1", 1.1)
	end
	for i, id in { "garlic_sauce", "chilli_sauce", "mayo" } do
		bottle(kc, id, -2.4 + (i - 1) * 2.4, COUNTER_H + 1.95, -0.95, "kebab1")
	end
	-- bread bins on a side counter (towards the front)
	local bs = B.sub(kebabFolder, 28.2, 3.75, -90)
	local bc = counter(bs, "BreadCounter", 2.5, 2.6)
	local breads = { { "pitta", "🥙 Pitta Bread" }, { "wrap_bread", "🌯 Wrap Bread" } }
	for i, b in breads do
		local bx = -0.62 + (i - 1) * 1.24
		B.box(bc, "Basket", bx - 0.58, COUNTER_H, -0.8, bx + 0.58, COUNTER_H + 0.35, 0.8, C.WOOD_DARK, M.Wood)
		for j = 0, 2 do
			B.ball(bc, "Bread", Vector3.new(1.0, 0.25, 0.65), bx, COUNTER_H + 0.35 + j * 0.15, -0.3 + j * 0.3, Ingredients.ById[b[1]].color, nil, { CanQuery = false })
		end
		local hit = B.hitbox(bc, "Bin_" .. b[1], Vector3.new(1.35, 1, 1.7), CFrame.new(bx, COUNTER_H + 0.5, 0))
		B.station(hit, "Bin", b[2], { Ingredient = b[1] })
	end
	-- food boxes stack on the shelf above the bread
	B.box(bc, "UpperShelf", -1.5, COUNTER_H + 2.2, -1.3, 1.5, COUNTER_H + 2.35, 0.4, C.STEEL, M.Metal)
	for j = 0, 3 do
		B.box(bc, "FoodBox", -0.8, COUNTER_H + 2.35 + j * 0.3, -0.9, 0.8, COUNTER_H + 2.6 + j * 0.3, 0.2, C.WHITE, nil, { CanQuery = false })
	end
	local fbHit = B.hitbox(bc, "Bin_food_box", Vector3.new(2, 1.4, 1.6), CFrame.new(0, COUNTER_H + 2.9, -0.35))
	B.station(fbHit, "Bin", "🥡 Food Boxes", { Ingredient = "food_box" })

	-- Doner spits (vertical rotisseries) next to the board
	local function spit(x: number, z: number, meat: string, label: string)
		local sp = B.sub(kebabFolder, x, z, -90)
		local m = B.model(sp, "Spit_" .. meat)
		counter(m, "Base", 2.4, 2)
		B.box(m, "Back", -1.2, COUNTER_H, -1.05, 1.2, COUNTER_H + 4.2, -0.75, C.STEEL, M.Metal)
		local heater = B.box(m, "Heater", -0.8, COUNTER_H + 0.5, -0.76, 0.8, COUNTER_H + 3.8, -0.7, Color3.fromRGB(255, 80, 30), M.Neon)
		B.pointLight(heater, Color3.fromRGB(255, 120, 60), 8, 1.2)
		B.box(m, "DripTray", -0.9, COUNTER_H, -0.6, 0.9, COUNTER_H + 0.2, 0.9, C.STEEL_DARK, M.Metal)
		local ing = Ingredients.ById[meat]
		local cone = B.model(m, "MeatCone")
		cone.parent:SetAttribute("Spin", 0.6)
		B.cyl(cone, "Skewer", 0.12, 4.2, 0, COUNTER_H + 0.2, 0.15, C.STEEL, M.Metal)
		if MeshLib.has("MeatCone") then
			local parts = MeshLib.place(cone.parent, "MeatCone", cone.origin * CFrame.new(0, COUNTER_H + 0.25, 0.15), {
				Meat = ing.color, Plate = C.STEEL, Cap = C.STEEL,
			}, { materials = { Plate = M.Metal, Cap = M.Metal } })
			-- client Effects spins parts named "Meat" around the skewer
			for _, p in parts do
				p.Name = "Meat"
			end
		else
			for i = 0, 6 do
				local d = 1.6 - i * 0.12
				B.cyl(cone, "Meat", d, 0.5, 0, COUNTER_H + 0.4 + i * 0.5, 0.15, ing.color:Lerp(C.BLACK, (i % 2) * 0.08), M.SmoothPlastic, { CanQuery = false })
			end
		end
		local hit = B.hitbox(m, "Spit_" .. meat, Vector3.new(2, 4, 2), CFrame.new(0, COUNTER_H + 2, 0.2))
		B.station(hit, "Topping", label, { Ingredient = meat, Board = "kebab1" })
	end
	spit(28.4, -6.3, "chicken_doner", "🍗 Chicken Doner Spit")
	spit(25.2, -6.6, "lamb_doner", "🥩 Lamb Doner Spit")
	local kWrapSign = B.box(kebabFolder, "WrapHint", 29.4, 7, -4.5, 29.45, 8.2, 2.1, C.RED)
	B.label(kWrapSign, Enum.NormalId.Left, "KEBAB STATION", { color = C.WHITE, font = Enum.Font.FredokaOne, pad = 6 })

	-- Placeholder before the kebab station is bought
	local soon = B.model(ke, "KebabComingSoon")
	soon.parent:SetAttribute("HideWhen", "kebab_station")
	for _, z in { -6.5, 5 } do
		B.cyl(soon, "Post", 0.4, 3.4, 24, 0, z, C.YELLOW, M.SmoothPlastic)
	end
	B.box(soon, "Tape", 23.9, 2.6, -6.5, 24.1, 2.9, 5, C.YELLOW, M.SmoothPlastic)
	B.box(soon, "Tape2", 23.9, 1.6, -6.5, 24.1, 1.9, 5, C.BLACK, M.SmoothPlastic)
	local sign = B.box(soon, "Sign", 23.8, 3.4, -2.5, 24.2, 6.6, 2.5, C.WHITE)
	B.label(sign, Enum.NormalId.Left, "🥙 KEBAB STATION\nUnlocks at Level 5", { color = C.RED_DARK, font = Enum.Font.FredokaOne, pad = 10, bg = C.WHITE })

	-- Fryer (upgrade) between the drinks and the kebab station
	local fry = B.model(ke, "FryerUpgrade")
	fry.parent:SetAttribute("UpgradeId", "fryer")
	local fs = B.sub(fry, 21.5, -6.4, 0)
	local fc
	if MeshLib.has("Fryer") then
		-- twin-well stainless fryer: oil wells, basket hangers, splashback, dials
		fc = B.model(fs, "Fryer")
		local parts = MeshLib.place(fc.parent, "Fryer", fc.origin, {
			Body = C.STEEL, Well = C.STEEL_DARK, Oil = Color3.fromRGB(230, 170, 45), Panel = C.STEEL:Lerp(C.BLACK, 0.15),
			Knob = C.BLACK, Splash = C.STEEL, Hanger = C.STEEL_DARK,
		}, { collide = true, materials = { Body = M.Metal, Well = M.Metal, Oil = M.Glass, Panel = M.Metal, Knob = M.SmoothPlastic, Splash = M.Metal, Hanger = M.Metal } })
		if parts.Oil then
			parts.Oil.Transparency = 0.15
			parts.Oil.Reflectance = 0.1
		end
	else
		fc = counter(fs, "Fryer", 3.2, 2.6)
		local oil = B.box(fc, "Oil", -1.3, COUNTER_H - 0.3, -1, 1.3, COUNTER_H + 0.02, 1, Color3.fromRGB(230, 180, 50), M.Glass)
		oil.Transparency = 0.2
		oil.CanQuery = false
	end
	local disp = if MeshLib.has("Fryer")
		then B.box(fc, "Display", -0.32, 2.48, 1.38, 0.32, 2.82, 1.42, C.BLACK)
		else B.box(fc, "Display", -1, 1.9, 1.36, 1, 2.5, 1.4, C.BLACK)
	B.label(disp, Enum.NormalId.Back, "FRYER", { color = Color3.fromRGB(255, 70, 50), font = Enum.Font.Code })
	local fryHit = B.hitbox(fc, "FryerSlot", Vector3.new(2.8, 1.4, 2.2), CFrame.new(0, COUNTER_H + 0.5, 0))
	B.station(fryHit, "Fryer", "🍟 Fryer")
	B.itemAt(fryHit, CFrame.new(0, -0.6, 0))
	local chipsCtx = B.sub(fry, 18.4, -6.4, 0)
	local cc = counter(chipsCtx, "ChipsFreezer", 2.6, 2.6, { body = Color3.fromRGB(220, 230, 240) })
	for i = 0, 10 do
		B.box(cc, "FrozenChip", -0.9 + (i % 6) * 0.35, COUNTER_H, -0.6 + (i // 6) * 0.7, -0.8 + (i % 6) * 0.35, COUNTER_H + 0.1, -0.1 + (i // 6) * 0.7, Color3.fromRGB(250, 236, 190), nil, { CanQuery = false })
	end
	local chipsHit = B.hitbox(cc, "Bin_chips", Vector3.new(2.4, 0.9, 2.2), CFrame.new(0, COUNTER_H + 0.45, 0))
	B.station(chipsHit, "Bin", "🍟 Frozen Chips", { Ingredient = "chips" })

	-- Kitchen order screens
	local scr1 = screen(k, "OrderScreen1", -26, 8.8, -9, 12.2, -7.2, 1)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OrderScreenGui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = scr1
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 44)
	header.BackgroundColor3 = C.RED
	header.TextColor3 = C.WHITE
	header.Font = Enum.Font.FredokaOne
	header.TextScaled = true
	header.Text = "  🍕 KITCHEN ORDERS"
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = gui
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(10, 54)
	list.Size = UDim2.new(1, -20, 1, -64)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.Size = UDim2.new(1, 0, 1, 0)
	empty.BackgroundTransparency = 1
	empty.TextColor3 = Color3.fromRGB(90, 100, 120)
	empty.Font = Enum.Font.GothamBold
	empty.TextScaled = true
	empty.Text = "No orders yet ✓"
	empty.Parent = list
	-- mirror the screen above the pass (facing the kitchen) and the kebab station
	local scr2 = screen(k, "OrderScreen2", -2, 8.8, 14, 12.2, 5.6, -1)
	local g2 = gui:Clone()
	g2.Face = Enum.NormalId.Front
	g2.Parent = scr2
end

------------------------------------------------------------------ front of house

local function buildFront(c: Ctx)
	local f = B.folder(c, "FrontOfHouse")
	-- Front counter: wood top, red front with yellow stripe, faces +Z (customers)
	local function frontCounter(x1: number, x2: number)
		B.box(f, "CounterBody", x1, 0, 5.2, x2, 3.3, 7.4, C.RED, M.SmoothPlastic)
		B.box(f, "CounterKick", x1 + 0.1, 0, 7.3, x2 - 0.1, 0.4, 7.45, C.BLACK)
		B.box(f, "CounterStripe", x1, 2.4, 7.4, x2, 2.75, 7.5, C.YELLOW, M.SmoothPlastic)
		B.box(f, "CounterTop", x1 - 0.1, 3.3, 5.0, x2 + 0.1, 3.55, 7.7, Color3.fromRGB(232, 226, 220), M.Marble)
		-- red cubbies on the kitchen side
		for x = x1 + 0.2, x2 - 1.6, 2.2 do
			B.box(f, "Cubby", x, 0.4, 5.15, x + 2.0, 3.2, 5.2, C.RED_DARK)
		end
	end
	frontCounter(IW, 10)
	frontCounter(13, IE)
	-- logo plates on the counter front
	for _, x in { -32, -22, 2, 21, 32 } do
		local plate = B.box(f, "LogoPlate", x - 1.2, 0.8, 7.45, x + 1.2, 2.2, 7.55, C.WHITE)
		B.label(plate, Enum.NormalId.Back, "🪐", { pad = 2 })
	end
	-- Register (POS) at x = -2
	local reg = B.model(f, "Register")
	local posCF = CFrame.new(-2, 5.1, 6.2) * CFrame.Angles(math.rad(-15), 0, 0)
	local posMesh = MeshLib.has("PosStand") and MeshLib.has("PosBezel") and MeshLib.has("ReceiptPrinter")
	if posMesh then
		-- terminal on a weighted stand with a bezel around the screen, receipt printer beside it
		MeshLib.place(reg.parent, "PosStand", reg.origin * CFrame.new(-2, 3.55, 6.3), { Base = C.BLACK, Neck = Color3.fromRGB(40, 40, 44) },
			{ scale = Vector3.new(1, 0.6, 1), materials = { Base = M.Metal, Neck = M.Metal } }) -- neck ends at the screen's bottom edge
		MeshLib.place(reg.parent, "PosBezel", reg.origin * posCF * CFrame.new(0, -0.89, 0), { Bezel = Color3.fromRGB(28, 28, 32) },
			{ materials = { Bezel = M.SmoothPlastic } })
		MeshLib.place(reg.parent, "ReceiptPrinter", reg.origin * CFrame.new(-0.3, 3.55, 6.05) * CFrame.Angles(0, math.pi, 0), {
			Body = Color3.fromRGB(40, 40, 44), Paper = C.WHITE, Button = C.GREEN,
		}, { materials = { Body = M.SmoothPlastic, Paper = M.SmoothPlastic, Button = M.Neon } })
	else
		B.box(reg, "Base", -3, 3.55, 5.6, -1, 3.85, 6.9, C.BLACK)
		B.box(reg, "Stand", -2.15, 3.85, 6.0, -1.85, 4.6, 6.3, C.BLACK, M.Metal)
	end
	local posScreen = B.part(reg, "Screen", Vector3.new(2.2, 1.5, 0.12), posCF, C.BLACK)
	B.label(posScreen, Enum.NormalId.Front, "🪐 Pizza Planet\nTap to take order", { color = C.WHITE, font = Enum.Font.GothamBold, pad = 6, bg = Color3.fromRGB(30, 30, 40) })
	B.label(posScreen, Enum.NormalId.Back, "✓ Ready", { color = C.GREEN, font = Enum.Font.GothamBold, pad = 6, bg = Color3.fromRGB(245, 240, 230) })
	if not posMesh then
		B.box(reg, "Printer", -0.8, 3.55, 5.6, 0.2, 4.2, 6.5, C.BLACK)
	end
	local regHit = B.hitbox(reg, "RegisterHit", Vector3.new(3, 2.4, 2), CFrame.new(-2, 4.8, 6.2))
	B.station(regHit, "Register", "🧾 Register")
	-- Pickup counter section with heat lamps and sign
	local pick = B.model(f, "Pickup")
	for _, x in { -14.5, -7.5 } do
		B.box(pick, "Post", x - 0.12, 3.55, 6.2, x + 0.12, 7.6, 6.45, C.BLACK, M.Metal)
	end
	B.box(pick, "LampBar", -14.6, 7.4, 5.7, -7.4, 7.8, 6.9, C.BLACK, M.Metal)
	local pglow = B.box(pick, "LampGlow", -14.2, 7.35, 5.9, -7.8, 7.4, 6.7, Color3.fromRGB(255, 150, 70), M.Neon)
	B.surfaceLight(pglow, Enum.NormalId.Bottom, Color3.fromRGB(255, 170, 100), 7, 1)
	local psign = B.box(pick, "PickupSign", -13.5, 7.9, 6.2, -8.5, 9.2, 6.4, C.YELLOW)
	B.label(psign, Enum.NormalId.Back, "ORDER PICK-UP", { color = C.RED_DARK, font = Enum.Font.GothamBlack, pad = 6 })
	B.label(psign, Enum.NormalId.Front, "SERVE HERE", { color = C.RED_DARK, font = Enum.Font.GothamBlack, pad = 6 })
	-- tray stack + bag stack decor
	if MeshLib.has("Tray") then
		for i = 0, 4 do
			MeshLib.place(pick.parent, "Tray", pick.origin * CFrame.new(-13, 3.55 + i * 0.12, 6.1) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, 0, 0), {
				Body = C.RED, Liner = Color3.fromRGB(250, 244, 230), Print = C.RED,
			}, { scale = 0.72 })
		end
	else
		for i = 0, 4 do
			B.box(pick, "Tray", -14, 3.55 + i * 0.12, 5.4, -12, 3.65 + i * 0.12, 6.8, C.RED)
		end
	end
	for i = 0, 5 do
		B.box(pick, "Bag", -9.6, 3.55 + i * 0.08, 5.5, -8.2, 3.62 + i * 0.08, 6.6, Color3.fromRGB(190, 145, 95), M.Cardboard)
	end
	local pickHit = B.hitbox(pick, "PickupHit", Vector3.new(7, 2.6, 2.8), CFrame.new(-11, 4.8, 6.3))
	B.station(pickHit, "Pickup", "🛎️ Order Pick-Up")

	-- Menu boards above the counter (customer facing)
	local function menuBoard(name: string, x1: number, x2: number, guiName: string, title: string, color: Color3)
		local scr = screen(f, name, x1, 9, x2, 12.3, 7.2, 1)
		local gui = Instance.new("SurfaceGui")
		gui.Name = guiName
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 45
		gui.LightInfluence = 0
		gui.Parent = scr
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(250, 244, 232)
		bg.Parent = gui
		local head = Instance.new("TextLabel")
		head.Name = "Title"
		head.Size = UDim2.new(1, 0, 0, 34)
		head.BackgroundColor3 = color
		head.TextColor3 = C.WHITE
		head.Font = Enum.Font.FredokaOne
		head.TextScaled = true
		head.Text = title
		head.Parent = bg
		local items = Instance.new("Frame")
		items.Name = "Items"
		items.Position = UDim2.fromOffset(8, 40)
		items.Size = UDim2.new(1, -16, 1, -46)
		items.BackgroundTransparency = 1
		items.Parent = bg
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.5, -6, 0, 26)
		grid.CellPadding = UDim2.fromOffset(6, 4)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = items
	end
	menuBoard("MenuPizza", -27, -12.5, "MenuGui_pizza", "🍕 PIZZAS", C.RED)
	menuBoard("MenuKebab", -11.5, 1, "MenuGui_kebab", "🥙 KEBABS & BOXES", Color3.fromRGB(220, 110, 30))
	menuBoard("MenuDrink", 2, 9.5, "MenuGui_drink", "🥤 DRINKS", Color3.fromRGB(40, 120, 220))
	-- Promo board facing the door
	local promo = screen(f, "PromoBoard", 14, 9, 28, 12.3, 7.2, 1)
	B.label(promo, Enum.NormalId.Back, "🪐 PIZZA PLANET\nFresh from the stone oven", { color = C.WHITE, bg = Color3.fromRGB(20, 120, 120), font = Enum.Font.FredokaOne, pad = 14 })

	-- Queue stanchions (decorative, non-colliding so NPC paths stay simple)
	local nc = { CanCollide = false }
	for _, z in { 11.8, 15.4, 18.8 } do
		for _, x in { -4.2, 0.2 } do
			B.cyl(f, "StanchionBase", 0.8, 0.12, x, 0, z, C.BLACK, M.Metal, { CanCollide = false })
			B.cyl(f, "Stanchion", 0.18, 3, x, 0.12, z, C.STEEL, M.Metal, { CanCollide = false })
			B.cyl(f, "StanchionTop", 0.3, 0.2, x, 3.1, z, C.YELLOW, M.Metal, { CanCollide = false })
		end
	end
	for _, x in { -4.2, 0.2 } do
		B.box(f, "Rope", x - 0.08, 2.75, 11.8, x + 0.08, 2.9, 18.8, C.RED, M.Fabric, nc)
	end

	-- Dining tables (west side + east side)
	local dining = B.folder(c, "Dining")
	-- (keep the door -> lobby -> queue walk, x 6..17 / z 17..ZF, clear of tables)
	local TABLES = { { -19.5, 11 }, { -19.5, 17.5 }, { 18.5, 11 }, { 25.5, 11 }, { -19.5, 24 }, { -10, 24.5 }, { 25.5, 24 },
		{ -28.5, 11 }, { -28.5, 24 }, { 33, 11 }, { 33, 24 } }
	for _, t in TABLES do
		table4(dining, "Table", t[1], t[2], nil)
	end
	-- seating upgrades
	local s1 = B.model(dining, "Seating1")
	s1.parent:SetAttribute("UpgradeId", "seating_1")
	for _, t in { { 25.5, 17.5 }, { 11.5, 13.2 }, { 25.5, 30.5 }, { -19.5, 30.5 }, { -28.5, 17.5 }, { 33, 17.5 }, { 33, 30.5 } } do
		table4(s1, "Table", t[1], t[2], nil)
	end
	local s2 = B.model(dining, "Seating2")
	s2.parent:SetAttribute("UpgradeId", "seating_2")
	booth(s2, "Booth", IW + 3.1, 13.5, 0)
	booth(s2, "Booth", IW + 3.1, 21, 0)
	booth(s2, "Booth", IW + 3.1, 28.5, 0)
	-- window bar with stools along the storefront
	B.box(dining, "WindowBar", -15.5, 3.4, ZF - 1.8, -2, 3.65, ZF - 0.6, C.WOOD, M.Wood)
	B.box(dining, "WindowBarLeg", -15.3, 0, ZF - 1.0, -2.2, 3.4, ZF - 0.7, C.WOOD_DARK, M.Wood)
	for x = -14.5, -3, 2.4 do
		if MeshLib.has("BarStool") then
			MeshLib.place(dining.parent, "BarStool", dining.origin * CFrame.new(x, 0, ZF - 2.8), {
				Seat = C.RED, Welt = C.RED_DARK, Chrome = C.STEEL, Base = C.BLACK,
			}, { collide = true, materials = { Seat = M.Leather, Welt = M.Leather, Chrome = M.Metal, Base = M.Metal } })
		else
			B.cyl(dining, "StoolPole", 0.25, 2.6, x, 0, ZF - 2.8, C.BLACK, M.Metal)
			B.cyl(dining, "StoolSeat", 1.2, 0.3, x, 2.6, ZF - 2.8, C.RED, M.Leather)
		end
	end
	-- Wall art (framed pizza posters)
	local art = {
		{ IE, 21, -math.pi / 2, "🍕\nSLICE OF\nTHE GALAXY", C.RED },
		{ IW, 21, math.pi / 2, "🥙\nKEBAB\nORBIT", Color3.fromRGB(230, 120, 30) },
	}
	for _, a in art do
		local ctx = dining
		if a[1] > 0 then
			-- the east wall opens into the annex when it's bought
			local m = B.model(dining, "EastArt")
			m.parent:SetAttribute("HideWhen", "expansion_1")
			ctx = m
		end
		hangArt(ctx, a[1], a[2], a[3], a[4], a[5])
	end
	-- Decor upgrades
	local plants = B.model(c, "DecorPlants")
	plants.parent:SetAttribute("UpgradeId", "decor_plants")
	plant(plants, IW + 1, ZF - 1.5)
	plant(plants, IE - 1, ZF - 1.5)
	plant(plants, 14.2, 8.6, 0.8)
	plant(plants, 11.5, ZF + 2.5, 1.1)
	plant(plants, 22, ZF + 2.5, 1.1)
	-- base plants (always) by the entrance outside
	plant(B.folder(c, "EntrancePlants"), XW + 0.2, ZF + 2.6, 1)

	local neon = B.model(c, "DecorNeon")
	neon.parent:SetAttribute("UpgradeId", "decor_neon")
	local n1 = B.box(neon, "NeonPizza", IW + 0.1, 6, 6.5, IW + 0.2, 9.5, 9, Color3.fromRGB(255, 200, 40), M.Neon)
	B.label(n1, Enum.NormalId.Right, "🍕", { pad = 2, brightness = 3 })
	B.pointLight(n1, Color3.fromRGB(255, 190, 60), 10, 1.2)
	local eastNeon = B.model(neon, "EastNeon")
	eastNeon.parent:SetAttribute("HideWhen", "expansion_1") -- the annex has its own
	local n2 = B.box(eastNeon, "NeonKebab", IE - 0.2, 6, 6.5, IE - 0.1, 9.5, 9, Color3.fromRGB(255, 90, 160), M.Neon)
	B.label(n2, Enum.NormalId.Left, "🥙", { pad = 2, brightness = 3 })
	B.pointLight(n2, Color3.fromRGB(255, 90, 160), 10, 1.2)

	local pend = B.model(c, "DecorLights")
	pend.parent:SetAttribute("UpgradeId", "decor_lights")
	for _, p in TABLES do
		B.box(pend, "Cord", p[1] - 0.04, 9, p[2] - 0.04, p[1] + 0.04, 13, p[2] + 0.04, C.BLACK)
		B.ball(pend, "Shade", Vector3.new(1.8, 1.2, 1.8), p[1], 8.8, p[2], C.YELLOW, M.SmoothPlastic)
		local bulb = B.ball(pend, "Bulb", Vector3.new(0.7, 0.7, 0.7), p[1], 8.3, p[2], Color3.fromRGB(255, 236, 190), M.Neon)
		B.pointLight(bulb, Color3.fromRGB(255, 210, 150), 14, 1.4, true)
	end

	-- OPEN / CLOSED sign in the window next to the door
	local fs = B.sub(f, 0, DF, 0)
	local signPart = B.box(fs, "OpenSignLight", 9.5, 6.5, 21.2, 12, 7.8, 21.4, Color3.fromRGB(255, 70, 60), M.Neon)
	B.label(signPart, Enum.NormalId.Front, "CLOSED", { color = C.WHITE, font = Enum.Font.GothamBlack, brightness = 2 })
	B.label(signPart, Enum.NormalId.Back, "CLOSED", { color = C.WHITE, font = Enum.Font.GothamBlack, brightness = 2 })
	local signStand = B.box(fs, "SignStand", 10.3, 0, 19.6, 11.2, 3.4, 20.6, C.BLACK, M.Metal)
	signStand.CanQuery = false
	local signHit = B.hitbox(fs, "OpenSign", Vector3.new(3, 8, 2.4), CFrame.new(10.75, 4, 20.3))
	B.station(signHit, "OpenSign", "🚪 Open Sign")
end

------------------------------------------------------------------ back of house

local function shelving(c: Ctx, name: string, w: number, d: number, h: number): Ctx
	local m = B.model(c, name)
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			B.box(m, "Upright", x - 0.08, 0, z - 0.08, x + 0.08, h, z + 0.08, C.STEEL, M.Metal)
		end
	end
	for i = 0, 3 do
		local y = 0.4 + i * (h - 0.6) / 3
		B.box(m, "Shelf", -w / 2, y, -d / 2, w / 2, y + 0.08, d / 2, C.STEEL, M.DiamondPlate)
	end
	return m
end

local function buildBack(c: Ctx)
	-- Back rooms run from the kitchen partition (z = -8) to the back wall
	-- (inner face ZB + 0.5). Storage x IW..-2 (with a walk-in freezer room),
	-- owner's office x -2..12, staff room x 12..IE.
	local b = B.folder(c, "BackOfHouse")
	local zIn = ZB + 0.5
	-- STORAGE ROOM: dry shelving against the back wall, next to the back door
	local dry = shelving(B.sub(b, -18, zIn + 1.3, 0), "DryShelves", 7.6, 2.4, 7)
	local rng = Random.new(5)
	for i = 0, 2 do
		for j = 0, 2 do
			local y = 0.48 + i * 2.13
			local x = -2.6 + j * 2.6
			if rng:NextNumber() < 0.85 then
				carton(dry, "Stock", x - 0.9, y, -0.9, x + 0.9, y + rng:NextNumber(0.8, 1.4), 0.9, Color3.fromRGB(196, 150, 100):Lerp(C.WHITE, rng:NextNumber(0, 0.25)), rng:NextNumber(-0.06, 0.06))
			end
		end
	end
	local dryHit = B.hitbox(dry, "DryStorage", Vector3.new(7.6, 7, 3), CFrame.new(0, 3.5, 0.3))
	B.station(dryHit, "Storage", "📦 Dry Storage", { Category = "dry" })
	-- yaw 90 = front faces +X (into the room), 0 = faces +Z
	local function tallUnit(ctx: Ctx, x: number, z: number, yaw: number, name: string, label: string, cat: string, temp: string, tint: Color3)
		local s = B.sub(ctx, x, z, yaw)
		local m = B.model(s, name)
		if MeshLib.has("Fridge") then
			local parts = MeshLib.place(m.parent, "Fridge", m.origin, {
				Body = C.STEEL, Door = C.STEEL:Lerp(C.WHITE, 0.15), Glass = tint, Inside = tint:Lerp(C.WHITE, 0.6),
				Shelf = C.WHITE, Handle = C.STEEL_DARK,
			}, {
				collide = true,
				materials = { Body = M.Metal, Door = M.Metal, Glass = M.Glass, Inside = M.Neon, Shelf = M.SmoothPlastic, Handle = M.Metal },
			})
			if parts.Glass then
				parts.Glass.Transparency = 0.55
			end
			if parts.Inside then
				parts.Inside.Transparency = 0.35
			end
		else
			B.box(m, "Body", -2, 0, -1.3, 2, 8, 1.3, C.STEEL, M.Metal)
			B.box(m, "DoorL", -1.9, 0.6, 1.3, -0.05, 7.6, 1.4, tint, M.Glass, { Transparency = 0.3 })
			B.box(m, "DoorR", 0.05, 0.6, 1.3, 1.9, 7.6, 1.4, tint, M.Glass, { Transparency = 0.3 })
			for _, hx in { -0.3, 0.3 } do
				B.box(m, "Handle", hx - 0.06, 3, 1.4, hx + 0.06, 5.5, 1.55, C.STEEL_DARK, M.Metal)
			end
			local inside = B.box(m, "Inside", -1.85, 0.7, 1.0, 1.85, 7.5, 1.25, tint:Lerp(C.WHITE, 0.5), M.Neon)
			inside.Transparency = 0.6
		end
		local disp = B.box(m, "TempDisplay", -0.7, 7.65, 1.38, 0.7, 7.95, 1.42, C.BLACK)
		B.label(disp, Enum.NormalId.Back, temp, { color = Color3.fromRGB(90, 220, 255), font = Enum.Font.Code })
		local hit = B.hitbox(m, name .. "Hit", Vector3.new(4, 8, 3), CFrame.new(0, 4, 0.4))
		B.station(hit, "Storage", label, { Category = cat })
	end
	-- cold fridge against the west wall, facing into the room
	tallUnit(b, IW + 1.55, -12, 90, "Fridge", "🧊 Fridge (cold)", "cold", "3°C", Color3.fromRGB(180, 220, 255))

	-- WALK-IN FREEZER ROOM (x -14..-2.3, back wall .. z -21): insulated white
	-- panels, a strip curtain doorway, frosty light; the freezer unit + racks inside
	local fz = B.folder(b, "WalkInFreezer")
	local fz1, fz2, fzFront = -14, -2.3, -21
	local panel = Color3.fromRGB(238, 242, 246)
	B.wallX(fz, "FreezerFront", fzFront, fz1, fz2, 0, 13, 0.5, panel, M.SmoothPlastic, { { -9.6, -6, 8.2 } })
	B.wallZ(fz, "FreezerSide", fz1, zIn, fzFront, 0, 13, 0.5, panel, M.SmoothPlastic)
	B.box(fz, "FreezerFloor", fz1, 0, zIn, fz2, 0.05, fzFront, Color3.fromRGB(200, 210, 220), M.DiamondPlate)
	for i = 0, 7 do -- PVC strip curtain
		local x = -9.5 + i * 0.44
		local strip = B.box(fz, "Strip", x, 1.2, fzFront - 0.05, x + 0.4, 8.1, fzFront + 0.02, Color3.fromRGB(200, 225, 235), M.Glass, { CanCollide = false, Transparency = 0.6, CastShadow = false })
		strip.CanQuery = false
	end
	local fsign = B.box(fz, "FreezerSign", -10.6, 8.6, fzFront + 0.26, -5, 9.8, fzFront + 0.3, Color3.fromRGB(40, 120, 200))
	B.label(fsign, Enum.NormalId.Back, "❄️ WALK-IN FREEZER  -18°C", { color = C.WHITE, font = Enum.Font.GothamBlack, pad = 6 })
	local frost = B.box(fz, "FrostLight", -11, 12.8, zIn + 3, -5, 13, zIn + 5, Color3.fromRGB(200, 235, 255), M.Neon)
	B.pointLight(frost, Color3.fromRGB(170, 215, 255), 16, 1.1)
	tallUnit(fz, -6.5, zIn + 1.45, 0, "Freezer", "❄️ Freezer (frozen)", "frozen", "-18°C", Color3.fromRGB(200, 240, 255))
	local rack = shelving(B.sub(fz, -12.5, (zIn + fzFront) / 2, 90), "FreezerRack", 7, 2.2, 7)
	for i = 0, 2 do
		for j = 0, 2 do
			local y = 0.48 + i * 2.13
			carton(rack, "Frozen", -2.6 + j * 2.4 - 0.85, y, -0.8, -2.6 + j * 2.4 + 0.85, y + 0.9, 0.8, Color3.fromRGB(225, 236, 245):Lerp(C.WHITE, (i + j) % 2 * 0.4), (i * 3 + j) % 3 * 0.04 - 0.04)
		end
	end

	-- Freezer Racks upgrade: a second stocked rack along the walk-in's east wall
	local fr = B.model(fz, "FreezerRacks")
	fr.parent:SetAttribute("UpgradeId", "freezer_racks")
	local rack2 = shelving(B.sub(fr, -3.6, -24.6, 90), "FreezerRack2", 6, 2.2, 7)
	for i = 0, 2 do
		for j = 0, 1 do
			local y = 0.48 + i * 2.13
			carton(rack2, "Frozen", -2.2 + j * 2.6 - 0.95, y, -0.8, -2.2 + j * 2.6 + 0.95, y + 1.0, 0.8, Color3.fromRGB(250, 236, 190):Lerp(Color3.fromRGB(215, 160, 90), (i + j) % 2 * 0.6), (i + j) % 2 * 0.05 - 0.025)
		end
	end

	-- storage upgrades: extra shelves
	local st1 = B.model(b, "Storage1")
	st1.parent:SetAttribute("UpgradeId", "storage_1")
	shelving(B.sub(st1, IW + 1.3, -19, 90), "ExtraShelves", 7, 2.4, 7)
	local st2 = B.model(b, "Storage2")
	st2.parent:SetAttribute("UpgradeId", "storage_2")
	shelving(B.sub(st2, -19, -13, 90), "ExtraShelves2", 6, 2.4, 7)
	-- bulk shelving in the west end of the storage room (decor)
	local bulk = shelving(B.sub(b, -33, zIn + 1.3, 0), "BulkShelves", 7.6, 2.4, 7)
	for i = 0, 2 do
		for j = 0, 2 do
			B.box(bulk, "Sack", -2.6 + j * 2.6 - 1, 0.48 + i * 2.13, -0.9, -2.6 + j * 2.6 + 1, 0.48 + i * 2.13 + 1.1, 0.9, Color3.fromRGB(236, 226, 205), M.Fabric, { CanQuery = false })
		end
	end
	-- pallet just inside the back door
	B.box(b, "Pallet", -29, 0, zIn + 0.8, -26.6, 0.4, zIn + 3, C.WOOD, M.WoodPlanks)

	-- OWNER'S OFFICE (x -2..12): desk + PC against the back wall, ordering tablet,
	-- filing, safe, bookcase, corkboard and a small meeting corner
	local o = B.folder(c, "Office")
	local dz = zIn + 0.7 -- desk back edge
	if MeshLib.has("OfficeDesk") then
		-- desk with a drawer pedestal facing the chair
		MeshLib.place(o.parent, "OfficeDesk", o.origin * CFrame.new(4.75, 0, dz + 1.6), {
			Top = C.WOOD_DARK, Body = C.WOOD, Drawer = C.WOOD:Lerp(C.WOOD_DARK, 0.25), Handle = C.STEEL,
		}, { collide = true, materials = { Top = M.Wood, Body = M.Wood, Drawer = M.Wood, Handle = M.Metal } })
	else
		B.box(o, "Desk", 1, 0, dz, 8.5, 2.9, dz + 3.2, C.WOOD, M.Wood)
		B.box(o, "DeskTop", 0.8, 2.9, dz - 0.2, 8.7, 3.1, dz + 3.4, C.WOOD_DARK, M.Wood)
	end
	B.box(o, "MonitorStand", 4.4, 3.1, dz + 1, 4.8, 3.9, dz + 1.4, C.BLACK)
	local mon = B.box(o, "Monitor", 2.6, 3.9, dz + 0.9, 6.6, 6.3, dz + 1.1, C.BLACK)
	B.label(mon, Enum.NormalId.Back, "🪐 Pizza Planet OS", { color = C.WHITE, bg = Color3.fromRGB(70, 90, 210), font = Enum.Font.FredokaOne, pad = 12, brightness = 1.5 })
	B.box(o, "Keyboard", 3.4, 3.1, dz + 2, 5.8, 3.2, dz + 2.7, C.DARK)
	B.box(o, "Mouse", 6.2, 3.1, dz + 2.1, 6.5, 3.22, dz + 2.5, C.DARK)
	-- supplier tablet on a stand: same Pizza Planet OS (order stock, upgrades)
	B.box(o, "TabletStand", 7.25, 3.1, dz + 1.6, 7.55, 3.5, dz + 1.9, C.STEEL_DARK, M.Metal)
	local tab = B.part(o, "Tablet", Vector3.new(1.5, 1.05, 0.08), CFrame.new(7.4, 3.85, dz + 1.85) * CFrame.Angles(math.rad(-20), 0, 0), C.BLACK)
	B.label(tab, Enum.NormalId.Back, "📦 Order stock", { color = C.WHITE, bg = Color3.fromRGB(230, 90, 40), font = Enum.Font.GothamBlack, pad = 4, brightness = 1.5 })
	local pcHit = B.hitbox(o, "PCHit", Vector3.new(4.6, 3.6, 2.6), CFrame.new(4.6, 5, dz + 1.6))
	B.station(pcHit, "OfficePC", "💻 Owner PC (orders & upgrades)")
	-- the tablet is a shortcut: supplies with a suggested restock already in the cart
	local tabHit = B.hitbox(o, "TabletHit", Vector3.new(1.8, 1.8, 1.4), CFrame.new(7.4, 3.9, dz + 1.8))
	B.station(tabHit, "OfficeTablet", "📱 Quick restock")
	if MeshLib.has("OfficeChair") then
		-- swivel chair turned to face the desk
		MeshLib.place(o.parent, "OfficeChair", o.origin * CFrame.new(4.6, 0, dz + 4.6) * CFrame.Angles(0, math.pi + 0.25, 0), {
			Frame = C.BLACK, Wheel = C.BLACK, Seat = Color3.fromRGB(45, 45, 52),
		}, { collide = true, materials = { Frame = M.Metal, Wheel = M.SmoothPlastic, Seat = M.Fabric } })
	else
		chair(B.sub(o, 4.6, dz + 4.4, 0), 0, 0, 0, C.DARK)
	end
	B.box(o, "Filing", 9.5, 0, zIn + 0.2, 11.4, 4.2, zIn + 2.2, C.STEEL_DARK, M.Metal)
	B.box(o, "Bookcase", -1.6, 0, -24, -0.6, 7, -18, C.WOOD_DARK, M.Wood)
	for i = 0, 3 do
		B.box(o, "Binders", -1.55, 0.9 + i * 1.6, -23.6, -0.8, 2.0 + i * 1.6, -18.6, if i % 2 == 0 then C.RED else Color3.fromRGB(60, 120, 200), M.SmoothPlastic, { CanQuery = false })
	end
	local board = B.box(o, "Corkboard", -1.6, 4, -16, -1.65, 8, -10, Color3.fromRGB(180, 130, 80), M.Wood)
	board.Size = Vector3.new(0.12, 4, 6)
	B.label(board, Enum.NormalId.Right, "📋 GOALS\n• Serve fast\n• Keep it clean\n• Stock up!", { color = C.BLACK, font = Enum.Font.GothamBold, pad = 8 })
	plant(o, 10.6, -10, 0.9)
	B.box(o, "Safe", 9.6, 0, -13.8, 11.4, 2.2, -11.8, C.DARK, M.Metal)
	B.box(o, "Rug", 0.5, 0, -22, 9, 0.04, -15, Color3.fromRGB(150, 40, 40), M.Fabric)
	table4(o, "MeetingTable", 4.6, -17.5, C.WOOD_DARK)

	-- STAFF ROOM (x 12..IE): lockers, sofa, vending machines, break tables
	local sr = B.folder(c, "StaffRoom")
	for i = 0, 4 do
		local x = 13 + i * 1.6
		B.box(sr, "Locker", x, 0, zIn + 0.2, x + 1.5, 7, zIn + 1.7, if i % 2 == 0 then Color3.fromRGB(60, 120, 200) else Color3.fromRGB(70, 135, 215), M.Metal)
		B.box(sr, "Vent", x + 0.3, 5.6, zIn + 1.71, x + 1.2, 6.4, zIn + 1.75, C.STEEL_DARK)
	end
	B.box(sr, "LockerBench", 13, 0, zIn + 2.6, 20.8, 1.5, zIn + 3.8, C.WOOD, M.Wood)
	B.box(sr, "SofaBase", 25, 0, -12, 33.5, 1.6, -9.5, C.RED_DARK, M.Fabric)
	B.box(sr, "SofaBack", 25, 1.6, -9.9, 33.5, 3.6, -9, C.RED_DARK, M.Fabric)
	B.box(sr, "CoffeeTable", 27, 0, -15.5, 31.5, 1.4, -13.5, C.WOOD, M.Wood)
	local vend = B.box(sr, "Vending", IE - 2.8, 0, zIn + 0.1, IE - 0.2, 7.2, zIn + 2.3, C.RED, M.SmoothPlastic)
	local vend2 = B.box(sr, "Snacks", IE - 5.8, 0, zIn + 0.1, IE - 3.2, 7.2, zIn + 2.3, Color3.fromRGB(40, 110, 200), M.SmoothPlastic)
	B.label(vend2, Enum.NormalId.Back, "🍫 SNACKS", { color = C.WHITE, font = Enum.Font.FredokaOne, pad = 10 })
	B.label(vend, Enum.NormalId.Back, "🥤 PLANET\nCOLA", { color = C.WHITE, font = Enum.Font.FredokaOne, pad = 10 })
	table4(sr, "BreakTable", 21, -24.5, nil)
	table4(sr, "BreakTable2", 29, -24.5, nil)
end

------------------------------------------------------------------ outside

local function buildOutside(c: Ctx)
	local o = B.folder(c, "Outside")
	local of = B.sub(o, 0, DF, 0) -- in front of the storefront
	local ob = B.sub(o, 0, -DB, 0) -- behind the back wall
	-- Plot ground: parking lot west, grass strips, delivery yard behind
	B.box(o, "Lot", -70 - DW, -1.4, -45 - DB, 70 + DW, -0.2, 32 + DF, C.ASPHALT, M.Asphalt)
	B.box(of, "SidewalkFront", -70 - DW, -1.4, 26, 70 + DW, 0.05, 34, C.CONCRETE, M.Concrete)
	B.box(of, "Curb", -70 - DW, -1.4, 33.6, 70 + DW, 0.25, 34.2, C.WHITE, M.Concrete)
	B.box(of, "Apron", XW - 1, -1.4, 22.5, XE + 1, 0.05, 26, C.CONCRETE, M.Pavement)
	-- parking bays (lines)
	for i = 0, 6 do
		local x = -66 - DW + i * 5
		B.box(o, "Line", x - 0.15, -0.2, 2, x + 0.15, -0.17, 18 + DF, C.WHITE)
	end
	B.box(o, "Wheelstops", -66 - DW, -0.2, 2.5, -36 - DW, 0.2, 3.1, C.YELLOW)
	-- grass and trees east
	B.box(o, "Lawn", 34 + DW, -1.4, -40 - DB, 68 + DW, -0.05, 24 + DF, C.GRASS, M.Grass)
	local rng = Random.new(11)
	for i = 1, 5 do
		local x, z = rng:NextNumber(38 + DW, 64 + DW), rng:NextNumber(-34 - DB, 18 + DF)
		B.cyl(o, "Trunk", 1, 5, x, 0, z, C.WOOD_DARK, M.Wood)
		B.ball(o, "Canopy", Vector3.new(7, 6, 7), x, 7, z, Color3.fromRGB(70, 150, 70):Lerp(Color3.fromRGB(40, 110, 50), rng:NextNumber()), M.LeafyGrass)
		B.ball(o, "Canopy2", Vector3.new(5, 4.5, 5), x + 1.5, 9, z - 1, Color3.fromRGB(90, 170, 80), M.LeafyGrass)
	end
	-- delivery yard behind the back door
	B.box(ob, "Yard", -31, -1.4, -36, -10, 0.05, -22.5, C.CONCRETE, M.Concrete)
	B.box(ob, "YardLine", -31, 0.05, -30.5, -10, 0.08, -30.2, C.YELLOW)
	local pad = B.box(ob, "DeliveryPallet", -27.5, 0.05, -29.5, -21, 0.45, -24.5, C.WOOD, M.WoodPlanks)
	pad.CanQuery = false
	-- dumpster
	B.box(ob, "Dumpster", -16, 0, -30, -11, 4, -26, Color3.fromRGB(40, 110, 60), M.Metal)
	B.box(ob, "DumpsterLid", -16.2, 4, -30.2, -10.8, 4.3, -25.8, Color3.fromRGB(30, 90, 50), M.Metal)
	-- bollards
	for _, x in { -28, -20 } do
		B.cyl(ob, "Bollard", 0.8, 3, x, 0, -31.5, C.YELLOW, M.SmoothPlastic)
	end
	-- lamp over back door
	local bl = B.box(ob, "BackLamp", -25, 9.2, -23.2, -24, 9.6, -22.5, C.WHITE, M.Neon)
	B.pointLight(bl, Color3.fromRGB(255, 230, 200), 16, 1)
	-- outdoor seating
	for _, x in { -24, -12 } do
		local s = B.sub(of, x, 29, 0)
		if MeshLib.has("Parasol") then
			MeshLib.place(s.parent, "Parasol", s.origin, { Pole = C.STEEL, Canopy = C.RED, Valance = C.WHITE, Finial = C.STEEL },
				{ materials = { Pole = M.Metal, Canopy = M.Fabric, Valance = M.Fabric, Finial = M.Metal } })
		else
			B.cyl(s, "PatioPole", 0.3, 7.5, 0, 0, 0, C.STEEL, M.Metal)
			B.part(s, "Umbrella", Vector3.new(0.6, 7, 7), CFrame.new(0, 7.3, 0) * CFrame.Angles(0, 0, math.rad(90)), C.RED, M.Fabric, { Shape = Enum.PartType.Cylinder })
		end
		B.box(s, "PatioTable", -1.4, 2.8, -1.4, 1.4, 3, 1.4, C.WHITE, M.Metal)
		chair(s, 0, 2.1, 180, C.RED)
		chair(s, 0, -2.1, 0, C.RED)
	end
	-- bench by the curb
	if MeshLib.has("Bench") then
		-- park bench facing the street (+Z)
		MeshLib.place(o.parent, "Bench", of.origin * CFrame.new(26 + DW, 0, 32.3), { Wood = C.WOOD, Iron = C.BLACK },
			{ collide = true, materials = { Wood = M.Wood, Iron = M.Metal } })
	else
		B.box(of, "Bench", 23, 1.6, 31.6, 29, 1.9, 33, C.WOOD, M.Wood)
		B.box(of, "BenchLegL", 23.4, 0, 31.7, 23.8, 1.6, 32.9, C.BLACK, M.Metal)
		B.box(of, "BenchLegR", 28.2, 0, 31.7, 28.6, 1.6, 32.9, C.BLACK, M.Metal)
	end
	-- planter boxes along the front
	for _, x in { -6, 4 } do
		if MeshLib.has("Planter") then
			MeshLib.place(o.parent, "Planter", of.origin * CFrame.new(x, 0, 24.2), {
				Box = C.BRICK, Rim = C.CONCRETE, Soil = Color3.fromRGB(78, 52, 34), Shrub = Color3.fromRGB(70, 150, 70),
			}, { collide = true, materials = { Box = M.Brick, Rim = M.Concrete, Soil = M.Ground, Shrub = M.LeafyGrass } })
		else
			B.box(of, "Planter", x - 2.5, 0, 23.2, x + 2.5, 1.6, 25.2, C.BRICK, M.Brick)
			for i = 0, 3 do
				B.ball(of, "Shrub", Vector3.new(1.6, 1.4, 1.6), x - 1.8 + i * 1.2, 2, 24.2, Color3.fromRGB(70, 150, 70), M.LeafyGrass)
			end
		end
	end
	-- pylon sign by the road
	if MeshLib.has("PylonPost") then
		MeshLib.place(o.parent, "PylonPost", of.origin * CFrame.new(-39.4 - DW, 0, 30.1), { Post = C.STEEL_DARK, Base = C.STEEL },
			{ collide = true, materials = { Post = M.Metal, Base = M.Metal } })
	else
		local pylon = B.box(of, "Pylon", -40 - DW, 0, 29.5, -38.8 - DW, 16, 30.7, C.STEEL_DARK, M.Metal)
		pylon.CanQuery = false
	end
	local panel = B.box(of, "PylonSign", -43.5 - DW, 13, 29.3, -35.3 - DW, 18, 30.9, C.RED)
	for _, z in { 29.45, 30.75 } do
		edgeFrame(of, -43.5 - DW, 13, -35.3 - DW, 18, z, C.YELLOW)
	end
	B.label(panel, Enum.NormalId.Front, "🪐 PIZZA\nPLANET", { color = C.WHITE, font = Enum.Font.FredokaOne, pad = 10, brightness = 2 })
	B.label(panel, Enum.NormalId.Back, "🪐 PIZZA\nPLANET", { color = C.WHITE, font = Enum.Font.FredokaOne, pad = 10, brightness = 2 })
	B.pointLight(panel, Color3.fromRGB(255, 120, 100), 16, 1)

	-- Expansion annex (upgrade): extra dining room east of the building
	local ex = B.model(B.sub(c, DW, 0, 0), "Expansion") -- annex against the east wall
	ex.parent:SetAttribute("UpgradeId", "expansion_1")
	B.box(ex, "ExFloor", 29.5, -0.2, 6, 47, 0, ZF - 0.5, C.WOOD_FLOOR, M.WoodPlanks)
	B.box(ex, "ExFoundation", 30, -1.2, 5.5, 47.5, -0.2, ZF + 0.5, C.STONE, M.Concrete)
	B.wallX(ex, "ExFront", ZF, 29.5, 47.5, 0, 14, 1, C.BRICK, M.Brick, { { 32, 45, 10, 1.4 } })
	B.box(ex, "ExGlass", 32, 1.4, ZF - 0.1, 45, 10, ZF + 0.1, C.GLASS, M.Glass, { Transparency = 0.65 })
	B.wallX(ex, "ExBack", 6, 29.5, 47.5, 0, 14, 1, C.BRICK, M.Brick)
	B.wallZ(ex, "ExSide", 47, 6, ZF, 0, 14, 1, C.BRICK, M.Brick, { { 9, 19, 10, 2 }, { 22, 31, 10, 2 } })
	B.box(ex, "ExSideGlass", 46.9, 2, 9, 47.1, 10, 19, C.GLASS, M.Glass, { Transparency = 0.65 })
	B.box(ex, "ExSideGlass", 46.9, 2, 22, 47.1, 10, 31, C.GLASS, M.Glass, { Transparency = 0.65 })
	B.box(ex, "ExCeiling", 29.5, 13, 6, 47, 13.4, ZF, Color3.fromRGB(236, 234, 230))
	B.box(ex, "ExRoof", 29.5, 13.4, 5.5, 47.5, 14.2, ZF + 0.5, C.DARK, M.Asphalt)
	B.box(ex, "ExCornice", 29.5, 14, ZF + 0.3, 47.7, 14.7, ZF + 1.1, C.WHITE, M.Plaster)
	for _, t in { { 35, 10.5 }, { 42, 10.5 }, { 35, 17.5 }, { 42, 17.5 }, { 35, 25 }, { 42, 25 } } do
		table4(ex, "Table", t[1], t[2], nil)
		ceilingLight(ex, t[1], t[2], 3, 3)
	end
	-- interior to match the main dining room: red panelling, cream plaster, art
	B.wallX(ex, "Wainscot", 6.55, 29.5, 46.5, 0, 3.6, 0.1, C.RED_DARK, M.Wood)
	B.wallZ(ex, "Wainscot", 46.45, 6.6, ZF - 0.5, 0, 3.6, 0.1, C.RED_DARK, M.Wood, { { 9, 19, 3.6, 2 }, { 22, 31, 3.6, 2 } })
	B.wallX(ex, "ExPlaster", 6.6, 29.5, 46.5, 3.6, 13, 0.1, Color3.fromRGB(246, 232, 204), M.Plaster)
	hangArt(ex, 38.5, 6.65, 0, "🪐\nPLANET\nPIZZERIA", Color3.fromRGB(40, 120, 200))
	local exNeon = B.model(ex, "ExNeon")
	exNeon.parent:SetAttribute("UpgradeId", "decor_neon")
	local n3 = B.box(exNeon, "NeonKebab", 31.5, 6, 6.6, 34, 9.5, 6.7, Color3.fromRGB(255, 90, 160), M.Neon)
	B.label(n3, Enum.NormalId.Back, "🥙", { pad = 2, brightness = 3 })
	B.pointLight(n3, Color3.fromRGB(255, 90, 160), 10, 1.2)
end

------------------------------------------------------------------ nodes

local function buildNodes(c: Ctx)
	local n = B.folder(c, "Nodes")
	B.node(n, "PlayerSpawn", 11.5, 0.5, 9.5)
	B.node(n, "CustomerSpawn", 52 + DW, 3, 30 + DF)
	B.node(n, "DoorOutside", 17, 3, 27 + DF)
	B.node(n, "DoorInside", 17, 3, 18.5 + DF)
	B.node(n, "Lobby", 6, 3, 17.5)
	B.node(n, "RegisterLook", -2, 3, 5)
	for i = 1, 4 do
		B.node(n, "Queue" .. i, -2, 3, 9.4 + (i - 1) * 2.7)
	end
	-- extension adds two more queue spots (only used with expansion_1)
	B.node(n, "Queue5", 1.5, 3, 20)
	B.node(n, "Queue6", 4.5, 3, 20)
	B.node(n, "PickupSpot", -11, 3, 9)
	local waits = { { -14.5, 11.2 }, { -11, 11.6 }, { -7.5, 11.2 }, { -13, 14.2 }, { -9, 14.4 }, { -6, 14 } }
	for i, w in ipairs(waits) do
		B.node(n, "Wait" .. i, w[1], 3, w[2])
	end
	B.node(n, "DeliveryPad", -24.3, 0.45, -27 - DB)
	local t = B.folder(c, "TrashSpots")
	for _, p in { { -20, 13 }, { -10, 16.5 }, { 6, 12 }, { 12, 15 }, { -24, 14.2 }, { 22, 14.5 }, { -2, 20.5 }, { 16, 9.5 }, { -14, 27.5 }, { 8, 26 }, { 22, 27.5 } } do
		B.node(t, "Spot", p[1], 0.05, p[2])
	end
end

------------------------------------------------------------------ public

function RestaurantBuilder.build(origin: CFrame, ownerName: string?): Model
	local model = Instance.new("Model")
	model.Name = "Restaurant"
	local c = B.ctx(model, origin)
	buildShell(c)
	buildKitchen(c)
	buildFront(c)
	buildBack(c)
	buildOutside(c)
	buildNodes(c)
	-- Owner name plate on the facade
	if ownerName then
		local plate = B.box(c, "OwnerPlate", -16, 11.3, 22.55, 12, 12.6, 22.75, C.CREAM)
		plate.Parent = model:FindFirstChild("Shell")
		B.label(plate, Enum.NormalId.Back, ownerName .. "'s Pizza Planet", { color = C.RED_DARK, font = Enum.Font.FredokaOne, pad = 4 })
	end
	model.WorldPivot = origin
	return model
end

-- Fill the customer-facing menu boards with unlocked / locked items.
function RestaurantBuilder.updateMenuBoard(model: Model?, level: number, upgrades: { [string]: boolean })
	if not model then
		return
	end
	for _, gui in model:GetDescendants() do
		if gui:IsA("SurfaceGui") and string.sub(gui.Name, 1, 8) == "MenuGui_" then
			local kind = string.sub(gui.Name, 9)
			local items = gui:FindFirstChild("Items", true) :: Frame?
			if items then
				for _, ch in items:GetChildren() do
					if ch:IsA("TextLabel") then
						ch:Destroy()
					end
				end
				local order = 0
				local teasers = 0
				local shown = {}
				for _, r in Recipes.List do
					if r.kind == kind then
						local unlocked = FoodLogic.isRecipeUnlocked(r.id, level, upgrades)
						if unlocked or teasers < 2 then
							if not unlocked then
								teasers += 1
							end
							table.insert(shown, r)
						end
					end
				end
				-- Like a real digital menu board: up to MENU_PAGE items per page
				-- (2 columns), cycling through pages so the text stays readable.
				local MENU_PAGE = 10
				local pages = math.max(1, math.ceil(#shown / MENU_PAGE))
				local grid = items:FindFirstChildOfClass("UIGridLayout")
				if grid then
					local rows = math.clamp(math.ceil(math.min(#shown, MENU_PAGE) / 2), 4, MENU_PAGE // 2)
					grid.CellSize = UDim2.new(0.5, -6, 1 / rows, -4)
				end
				gui:SetAttribute("MenuPages", pages)
				gui:SetAttribute("MenuPage", 1)
				if pages > 1 and not gui:GetAttribute("MenuCycling") then
					gui:SetAttribute("MenuCycling", true)
					task.spawn(function()
						while gui.Parent do
							task.wait(6)
							local n = gui:GetAttribute("MenuPages") or 1
							local page = ((gui:GetAttribute("MenuPage") or 1) % n) + 1
							gui:SetAttribute("MenuPage", page)
							for _, t in items:GetChildren() do
								if t:IsA("TextLabel") then
									t.Visible = t:GetAttribute("Page") == page
								end
							end
						end
					end)
				end
				for _, r in shown do
					do
						order += 1
						local unlocked = FoodLogic.isRecipeUnlocked(r.id, level, upgrades)
						local t = Instance.new("TextLabel")
						t.LayoutOrder = order
						t:SetAttribute("Page", (order - 1) // MENU_PAGE + 1)
						t.Visible = (order - 1) // MENU_PAGE + 1 == 1
						t.BackgroundTransparency = 1
						t.Font = Enum.Font.GothamBold
						t.TextScaled = true
						t.TextXAlignment = Enum.TextXAlignment.Left
						t.TextColor3 = if unlocked then Color3.fromRGB(60, 30, 20) else Color3.fromRGB(190, 180, 170)
						t.Text = if unlocked then ("%s %s  $%d"):format(r.icon, r.name, r.price) else ("🔒 %s  Lv %d"):format(r.name, r.level)
						t.Parent = items
					end
				end
			end
		end
	end
end

return RestaurantBuilder
