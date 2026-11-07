--!strict
-- Loads / saves player profiles with DataStoreService.
--  * Retries with backoff on every DataStore call.
--  * Soft session lock (lock = {job, time}) so two servers never write the same
--    profile at once; a stale lock (> LOCK_EXPIRY) is taken over.
--  * Autosave loop + save on leave + BindToClose.
--  * If DataStores are unavailable (e.g. Studio without API access) the
--    player still plays on a temporary profile and is told it won't save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local LOCK_EXPIRY = 30 * 60
local JOB_ID = if game.JobId ~= "" then game.JobId else ("studio-" .. HttpService:GenerateGUID(false))

export type Profile = {
	money: number,
	xp: number,
	level: number,
	stock: { [string]: number },
	upgrades: { [string]: boolean },
	unlockedRecipes: { string },
	rating: number,
	reviews: number,
	orderCounter: number,
	stats: { [string]: number },
	lastEmergency: number,
	theme: string,
	themes: { [string]: boolean },
	version: number,
}

local DataService = {}
DataService.Profiles = {} :: { [Player]: Profile }
DataService.Temporary = {} :: { [Player]: boolean }

local loadedCallbacks: { (Player, Profile) -> () } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable:", result)
	end
end

local function template(): Profile
	local stock = {}
	for k, v in GameConfig.StartingStock do
		stock[k] = v
	end
	return {
		money = GameConfig.StartingMoney,
		xp = 0,
		level = 1,
		stock = stock,
		upgrades = {},
		unlockedRecipes = {},
		rating = 4,
		reviews = 0,
		orderCounter = 0,
		stats = { served = 0, earned = 0, angry = 0, pizzas = 0, kebabs = 0, cleaned = 0 },
		lastEmergency = 0,
		theme = "classic",
		themes = { classic = true },
		version = GameConfig.DataVersion,
	}
end

-- Fill in any fields added since the profile was first saved.
local function reconcile(data: { [string]: any }): Profile
	local t = template() :: any
	for k, v in t do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and k == "stats" then
			for sk, sv in v do
				if data[k][sk] == nil then
					data[k][sk] = sv
				end
			end
		end
	end
	data.lock = nil
	return data :: any
end

local function retry<T>(label: string, fn: () -> T): (boolean, T | string)
	local lastErr: any
	for attempt = 1, 5 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(("[DataService] %s failed (attempt %d): %s"):format(label, attempt, tostring(result)))
		local msg = tostring(result)
		if string.find(msg, "403", 1, true) or string.find(msg, "StudioAccessToApisNotAllowed", 1, true) then
			-- Studio without "Enable Studio Access to API Services": retrying won't help.
			break
		end
		task.wait(math.min(2 ^ attempt, 10))
	end
	return false, tostring(lastErr)
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

function DataService.onLoaded(cb: (Player, Profile) -> ())
	table.insert(loadedCallbacks, cb)
end

function DataService.get(player: Player): Profile?
	return DataService.Profiles[player]
end

function DataService.load(player: Player)
	local profile: Profile? = nil
	local temporary = false
	if store and (not RunService:IsStudio() or game.GameId ~= 0) then
		local ok, result = retry("load " .. player.UserId, function()
			local loaded: any = nil
			(store :: DataStore):UpdateAsync(key(player), function(old: any)
				if old and old.lock and old.lock.job ~= JOB_ID and os.time() - (old.lock.time or 0) < LOCK_EXPIRY then
					-- Another server still holds the session. Don't modify; we retry.
					loaded = "locked"
					return nil
				end
				local data = old or template()
				data.lock = { job = JOB_ID, time = os.time() }
				loaded = data
				return data
			end)
			if loaded == "locked" then
				error("profile is locked by another server")
			end
			return loaded
		end)
		if ok then
			profile = reconcile(result :: any)
		else
			temporary = true
		end
	else
		temporary = true
	end
	if not profile then
		profile = template()
	end
	if not player.Parent then
		return
	end
	DataService.Profiles[player] = profile :: Profile
	DataService.Temporary[player] = temporary
	if temporary then
		player:SetAttribute("DataTemporary", true)
	end
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, profile :: Profile)
	end
end

function DataService.save(player: Player, release: boolean?)
	local profile = DataService.Profiles[player]
	if not profile or DataService.Temporary[player] or not store then
		return
	end
	retry("save " .. player.UserId, function()
		(store :: DataStore):UpdateAsync(key(player), function(old: any)
			if old and old.lock and old.lock.job ~= JOB_ID and os.time() - (old.lock.time or 0) < LOCK_EXPIRY then
				return nil -- someone else owns it now; never clobber
			end
			local copy = table.clone(profile) :: any
			copy.lock = if release then nil else { job = JOB_ID, time = os.time() }
			return copy
		end)
		return true
	end)
end

function DataService.start()
	Players.PlayerAdded:Connect(function(p)
		DataService.load(p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(DataService.load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		DataService.save(p, true)
		DataService.Profiles[p] = nil
		DataService.Temporary[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for p in DataService.Profiles do
				task.spawn(DataService.save, p, false)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for p in DataService.Profiles do
			pending += 1
			task.spawn(function()
				DataService.save(p, true)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
