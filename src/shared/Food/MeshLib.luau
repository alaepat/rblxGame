--!strict
-- Access to the normalised Blender mesh templates in ReplicatedStorage.PP_Meshes
-- (filled by the server MeshService). Every template's pivot is at its
-- bottom centre = CFrame.new(), parts are named <Prop>_<Role>.
--
--   if MeshLib.has("Tray") then MeshLib.place(model, "Tray", cf, { Body = red }) end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshLib = {}

local function folder(): Folder?
	return ReplicatedStorage:FindFirstChild("PP_Meshes") :: Folder?
end

function MeshLib.has(prop: string): boolean
	local f = folder()
	return f ~= nil and f:FindFirstChild(prop) ~= nil
end

function MeshLib.role(part: Instance): string
	local n = part.Name
	local i = string.find(n, "_", 1, true)
	return if i then string.sub(n, i + 1) else n
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
	local scale: number = o.scale or 1
	for _, src in template:GetChildren() do
		if src:IsA("BasePart") then
			local role = MeshLib.role(src)
			if not (o.hide and o.hide[role]) then
				local p = src:Clone()
				if scale ~= 1 then
					p.Size *= scale
					local rel = src.CFrame
					p.CFrame = cf * (rel - rel.Position + rel.Position * scale)
				else
					p.CFrame = cf * src.CFrame
				end
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
