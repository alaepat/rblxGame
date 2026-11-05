--[[
	Loader: runs the game's ModuleScripts under Lune, outside Roblox Studio.

	It mirrors default.project.json as a tree of fake instances, so modules can
	use `script.Parent.X`, `:WaitForChild` and `require(...)` exactly as they do
	in Roblox. Roblox data types (Color3, Vector3, UDim2, Enum, …) come from
	Lune's roblox library. Only modules that don't touch live services can be
	loaded this way; tests pass fakes for everything else (see `overrides`).

	  local Loader = require("../lib/Loader")
	  local DailyGoals = Loader.module("Shared/Goals/DailyGoals")
	  local GoalService = Loader.module("Server/Services/GoalService", {
	      ["Shared/Net"] = fakeNet,
	  })
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Loader = {}

-- Must match default.project.json
local ROOTS = {
	Shared = "src/shared", -- ReplicatedStorage.Shared
	Server = "src/server", -- ServerScriptService.Server
	Client = "src/client", -- StarterPlayerScripts.Client
}

-- Lune's fs calls can yield, which isn't allowed inside metamethods, so the
-- source tree is read into memory once.
local dirs: { [string]: boolean } = {}
local files: { [string]: string } = {}

local function scan(dir: string)
	dirs[dir] = true
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			scan(path)
		elseif entry:sub(-5) == ".luau" then
			files[path] = fs.readFile(path)
		end
	end
end
for _, dir in ROOTS do
	scan(dir)
end

Loader.files = files

---------------------------------------------------------------- fake tree

local Node = {}
Node.__index = function(self, key)
	local method = rawget(Node, key)
	if method then
		return method
	end
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	local child = Node.FindFirstChild(self, key)
	if child then
		return child
	end
	error(("%s is not a valid member of %s"):format(tostring(key), rawget(self, "Name")), 2)
end
Node.__tostring = function(self)
	return rawget(self, "Name")
end

local cache: { [string]: any } = {}

local function node(name: string, logical: string, dir: string?, file: string?, parent: any)
	if cache[logical] then
		return cache[logical]
	end
	local n = setmetatable({ Name = name, _logical = logical, _dir = dir, _file = file, _parent = parent }, Node)
	cache[logical] = n
	return n
end

function Node.FindFirstChild(self, childName: string)
	local dir = rawget(self, "_dir")
	if not dir then
		return nil
	end
	local logical = rawget(self, "_logical") .. "/" .. childName
	for _, suffix in { ".luau", ".server.luau", ".client.luau" } do
		local f = dir .. "/" .. childName .. suffix
		if files[f] then
			return node(childName, logical, nil, f, self)
		end
	end
	local sub = dir .. "/" .. childName
	if dirs[sub] then
		return node(childName, logical, sub, files[sub .. "/init.luau"] and (sub .. "/init.luau") or nil, self)
	end
	return nil
end

function Node.WaitForChild(self, childName: string)
	local child = Node.FindFirstChild(self, childName)
	if not child then
		error("WaitForChild: " .. childName .. " not found in " .. rawget(self, "Name"), 2)
	end
	return child
end

local roots = {}
for name, dir in ROOTS do
	roots[name] = node(name, name, dir, nil, nil)
end

local extraServices: { [string]: any } = {}

local fakeGame = {
	GetService = function(_, serviceName: string)
		if extraServices[serviceName] then
			return extraServices[serviceName]
		end
		if serviceName == "ReplicatedStorage" then
			return { WaitForChild = function(_, n)
				return roots[n]
			end, FindFirstChild = function(_, n)
				return roots[n]
			end }
		end
		error("fake game has no service " .. serviceName .. " (pass an override)")
	end,
}

---------------------------------------------------------------- require

local function makeRequire(overrides: { [string]: any }, loaded: { [string]: any }, envExtra: { [string]: any })
	local req
	local function load(n)
		local logical = rawget(n, "_logical")
		if overrides[logical] ~= nil then
			return overrides[logical]
		end
		if loaded[logical] ~= nil then
			return loaded[logical]
		end
		local file = rawget(n, "_file")
		assert(file, "not a module: " .. logical)
		local env = {
			script = n,
			game = fakeGame,
			require = req,
			Color3 = roblox.Color3,
			Vector3 = roblox.Vector3,
			Vector2 = roblox.Vector2,
			CFrame = roblox.CFrame,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
			Instance = roblox.Instance,
			task = task,
			warn = function(...)
				print("[warn]", ...)
			end,
		}
		for k, v in envExtra do
			env[k] = v
		end
		local fn = luau.load(files[file], { debugName = file, environment = env })
		local result = fn()
		loaded[logical] = result
		return result
	end
	req = function(target)
		if type(target) == "string" then
			error("string require not supported: " .. target)
		end
		return load(target)
	end
	return req, load
end

-- Load a module by logical path, e.g. "Shared/Goals/DailyGoals".
-- Each call gets a fresh module cache so tests don't share state.
--   overrides: logical path -> value returned instead of loading that module
--   opts.services: extra fakes for game:GetService (e.g. Players, TweenService)
--   opts.env: extra globals (e.g. a fake `task` or `workspace`)
function Loader.module(logical: string, overrides: { [string]: any }?, opts: { services: any?, env: any? }?): any
	local parts = string.split(logical, "/")
	local n = roots[parts[1]]
	assert(n, "unknown root " .. parts[1])
	for i = 2, #parts do
		n = n:WaitForChild(parts[i])
	end
	table.clear(extraServices)
	for k, v in (opts and opts.services) or {} do
		extraServices[k] = v
	end
	local _, load = makeRequire(overrides or {}, {}, (opts and opts.env) or {})
	return load(n)
end

return Loader
