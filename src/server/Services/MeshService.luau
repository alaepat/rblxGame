--!strict
-- Loads the uploaded Blender meshes (Config.MeshIds) with InsertService,
-- normalises each one (exact size from config, upright, pivot at bottom
-- centre, origin at CFrame.new()) and stores it in ReplicatedStorage.PP_Meshes
-- for MeshLib. Runs before the world is built; any failure just means the
-- procedural fallback is used.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeshIds = require(Shared.Config.MeshIds)

local MeshService = {}

local function sortedDims(v: Vector3): { number }
	local t = { v.X, v.Y, v.Z }
	table.sort(t)
	return t
end

local function normalise(prop: string, info: MeshIds.MeshInfo, container: Instance): Model?
	local parts: { BasePart } = {}
	for _, d in container:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = prop
	for _, p in parts do
		p.Anchored = true
		p.Parent = m
		-- strip the prop prefix variants the importer may add ("Tray_Body.001")
		p.Name = string.gsub(p.Name, "%.%d+$", "")
	end
	-- 1) uniform scale so the largest dimension matches the config
	local _, size = m:GetBoundingBox()
	local want = sortedDims(info.size)
	local have = sortedDims(size)
	local scale = want[3] / math.max(have[3], 1e-4)
	m:ScaleTo(m:GetScale() * scale)
	-- 2) fix orientation if the importer left it Z-up (Y and Z swapped)
	local cf, s2 = m:GetBoundingBox()
	if math.abs(s2.Y - info.size.Y) > math.abs(s2.Z - info.size.Y) + 0.01 then
		m:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(math.rad(-90), 0, 0) * cf.Rotation:Inverse() * m:GetPivot())
		cf, s2 = m:GetBoundingBox()
	end
	-- 3) pivot at bottom centre, then move the pivot to the origin
	m.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, s2.Y / 2, 0))
	m:PivotTo(CFrame.new())
	-- 4) the FBX import lands Blender -Y (prop front) on Roblox -Z and mirrors
	--    X; a half turn makes it Roblox +Z / +X, the builders' convention
	--    (Blender (x, y, z) -> Roblox (x, z, -y)).
	m:PivotTo(CFrame.Angles(0, math.pi, 0))
	m.WorldPivot = CFrame.new()
	return m
end

-- Give up waiting after this long; anything still loading falls back to the
-- procedural parts (and lands in PP_Meshes later for new builds).
local LOAD_TIMEOUT = 45

local function loadOne(prop: string, info: MeshIds.MeshInfo, folder: Folder)
	local ok, res
	for attempt = 1, 2 do -- one retry: parallel loads can hit transient throttling
		ok, res = pcall(function()
			return InsertService:LoadAsset(info.assetId)
		end)
		if ok and res then
			break
		end
		task.wait(1 + attempt)
	end
	if ok and res then
		local m = normalise(prop, info, res)
		if m then
			m.Parent = folder
		else
			warn("[MeshService] " .. prop .. ": asset has no MeshParts")
		end
		res:Destroy()
	else
		warn("[MeshService] could not load " .. prop .. " (" .. info.assetId .. "): " .. tostring(res))
	end
end

function MeshService.start()
	local folder = ReplicatedStorage:FindFirstChild("PP_Meshes") or Instance.new("Folder")
	folder.Name = "PP_Meshes"
	folder.Parent = ReplicatedStorage
	-- Every LoadAsset yields on a network fetch, so start them all at once and
	-- wait for the last one instead of fetching ~60 assets one after another.
	local t0 = os.clock()
	local pending = 0
	for prop, info in MeshIds do
		if info.assetId and info.assetId > 0 and not folder:FindFirstChild(prop) then
			pending += 1
			task.spawn(function()
				loadOne(prop, info, folder)
				pending -= 1
			end)
		end
	end
	while pending > 0 and os.clock() - t0 < LOAD_TIMEOUT do
		task.wait(0.05)
	end
	if pending > 0 then
		warn(string.format("[MeshService] %d meshes still loading after %ds; using procedural fallbacks for those", pending, LOAD_TIMEOUT))
	end
	print(string.format("[MeshService] %d meshes ready in %.1fs", #folder:GetChildren(), os.clock() - t0))
end

return MeshService
