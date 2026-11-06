--!strict
-- Access to the normalised Blender mesh templates in ReplicatedStorage.PP_Meshes
-- (filled by the server MeshService). Every template's pivot is at its
-- bottom centre = CFrame.new(), parts are named <Prop>_<Role>.
--
--   if MeshLib.has("Tray") then MeshLib.place(model, "Tray", cf, { Body = red }) end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MeshIds = require(script.Parent.Parent.Config.MeshIds)

local MeshLib = {}

local function folder(): Folder?
	return ReplicatedStorage:FindFirstChild("PP_Meshes") :: Folder?
end

function MeshLib.has(prop: string): boolean
	local f = folder()
	return f ~= nil and f:FindFirstChild(prop) ~= nil
end

function MeshLib.role(part: Instance): string
	-- role = text after the LAST underscore ("Top_Pepperoni_Fat" -> "Fat")
	local n = part.Name
	return string.match(n, "_([^_]+)$") or n
end

-- Clone the prop's parts into `parent` with the prop's bottom centre at `cf`.
-- colors: role -> Color3; materials: role -> Material; hide: role -> true.
-- Returns role -> part.
function MeshLib.place(parent: Instance, prop: string, cf: CFrame, colors: { [string]: Color3 }?, opts: { [string]: any }?): { [string]: BasePart }
	local f = folder()
	local template = f and f:FindFirstChild(prop)
	local out: { [string]: BasePart } = {}
	if not template then
		return out
	end
	local o = opts or {}
	-- scale: number (uniform) or Vector3 (per axis, for stretching counters).
	-- Per-axis scaling assumes the template parts are axis-aligned (they are).
	local scale: Vector3 = if typeof(o.scale) == "Vector3" then o.scale else Vector3.one * (o.scale or 1)
	-- template origin is the bbox bottom-centre; shift so the prop's own
	-- Blender origin lands on `cf` (matters for asymmetric props)
	local info = MeshIds[prop]
	local center: Vector3 = (info and info.center) or Vector3.zero
	local base = cf * CFrame.new(center * scale)
	for _, src in template:GetChildren() do
		if src:IsA("BasePart") then
			local role = MeshLib.role(src)
			if not (o.hide and o.hide[role]) then
				local p = src:Clone()
				local rel = src.CFrame
				p.Size *= scale
				p.CFrame = base * (rel - rel.Position + rel.Position * scale)
				p.Anchored = true
				p.CanCollide = o.collide == true
				p.CanQuery = o.query == true
				p.CanTouch = false
				p.CastShadow = o.shadow ~= false
				p.Massless = true
				local col = colors and colors[role]
				if col then
					p.Color = col
				end
				local mat = o.materials and o.materials[role]
				if mat then
					p.Material = mat
				end
				p.Parent = parent
				out[role] = p
			end
		end
	end
	return out
end

return MeshLib
