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
local AssetService = game:GetService("AssetService")
-- optional: absent until generated (see buildFromManifest)
local Manifest: any = nil
do
	local m = Shared.Config:FindFirstChild("MeshManifest")
	if m then
		local ok, res = pcall(require, m)
		Manifest = if ok then res else nil
	end
end
local usedManifest = 0

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

-- Fallback when the Model asset can't be loaded: InsertService only loads
-- models owned by the place's creator, so in a teammate's own Studio place
-- every LoadAsset fails ("User is not authorized"). Config.MeshManifest
-- lists each normalised template part (mesh id, size, CFrame, colour),
-- recorded from a working load, and the parts are rebuilt from the raw mesh
-- ids with AssetService:CreateMeshPartAsync.
local function buildFromManifest(prop: string, folder: Folder): boolean
	local list = Manifest and Manifest[prop]
	if not list then
		return false
	end
	local m = Instance.new("Model")
	m.Name = prop
	for _, e in list do
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync("rbxassetid://" .. e[2])
		end)
		if not ok or not part then
			warn("[MeshService] " .. prop .. ": mesh " .. tostring(e[2]) .. " failed: " .. tostring(part))
			m:Destroy()
			return false
		end
		part.Name = e[1]
		part.Size = Vector3.new(e[3], e[4], e[5])
		-- every normalised part is turned half a turn about Y (see normalise step 4)
		part.CFrame = CFrame.new(e[6], e[7], e[8]) * CFrame.Angles(0, math.pi, 0)
		part.Anchored = true
		part.Parent = m
	end
	m.WorldPivot = CFrame.new()
	m.Parent = folder
	return true
end

local function loadOne(prop: string, info: MeshIds.MeshInfo, folder: Folder)
	-- Studio test of the teammate path: set workspace attribute
	-- PP_MeshManifestOnly = true (in edit mode) before pressing Play.
	if workspace:GetAttribute("PP_MeshManifestOnly") == true then
		if buildFromManifest(prop, folder) then
			usedManifest += 1
		end
		return
	end
	local ok, res
	for attempt = 1, 2 do -- one retry: parallel loads can hit transient throttling
		ok, res = pcall(function()
			return InsertService:LoadAsset(info.assetId)
		end)
		if ok and res then
			break
		end
		if string.find(tostring(res), "not authorized", 1, true) then
			break -- a permission error won't change on retry
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
	elseif buildFromManifest(prop, folder) then
		usedManifest += 1
	else
		warn("[MeshService] could not load " .. prop .. " (" .. info.assetId .. "): " .. tostring(res))
	end
end

-- Source text for Config/MeshManifest, built from the loaded templates. Run it
-- in a Studio playtest that loaded every mesh (the asset owner's), e.g. with
-- the command bar on the server, and paste the result into MeshManifest.luau.
function MeshService.manifestSource(): string
	local folder = ReplicatedStorage:FindFirstChild("PP_Meshes")
	if not folder then
		return "-- PP_Meshes not loaded"
	end
	local function n(v: number): string
		local s = string.gsub(string.gsub(string.format("%.4f", v), "0+$", ""), "%.$", "")
		return if s == "-0" then "0" else s
	end
	local names = {}
	for _, m in folder:GetChildren() do
		table.insert(names, m.Name)
	end
	table.sort(names)
	local lines = { "return {" }
	for _, prop in names do
		local parts = folder[prop]:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name < b.Name
		end)
		local entries = {}
		for _, p in parts do
			if p:IsA("MeshPart") then
				local s, c = p.Size, p.CFrame.Position
				table.insert(entries, ('{"%s",%s,%s,%s,%s,%s,%s,%s}'):format(p.Name, string.match(p.MeshId, "%d+") or "0", n(s.X), n(s.Y), n(s.Z), n(c.X), n(c.Y), n(c.Z)))
			end
		end
		table.insert(lines, "\t" .. prop .. " = { " .. table.concat(entries, ", ") .. " },")
	end
	table.insert(lines, "}")
	return table.concat(lines, "\n")
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
	print(string.format("[MeshService] %d meshes ready in %.1fs%s", #folder:GetChildren(), os.clock() - t0,
		if usedManifest > 0 then (" (%d rebuilt from MeshManifest)"):format(usedManifest) else ""))
end

return MeshService
