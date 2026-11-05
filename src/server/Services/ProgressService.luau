--!strict
-- Money, XP, levels, rating, and the client state snapshot.
-- ALL money/XP changes go through here (server authoritative).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Levels = require(Shared.Config.Levels)
local Upgrades = require(Shared.Config.Upgrades)
local Ingredients = require(Shared.Config.Ingredients)
local GameConfig = require(Shared.Config.GameConfig)
local FoodLogic = require(Shared.Food.FoodLogic)
local Net = require(Shared.Net)

local ProgressService = {}
local S: any -- services registry

local stateEvent = Net.event("State")
local notifyEvent = Net.event("Notify")
local levelUpEvent = Net.event("LevelUp")
local soundEvent = Net.event("Sound")

local providers: { (Player) -> { [string]: any } } = {}
local dirty: { [Player]: boolean } = {}

function ProgressService.init(services)
	S = services
end

function ProgressService.addStateProvider(fn: (Player) -> { [string]: any })
	table.insert(providers, fn)
end

function ProgressService.notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

function ProgressService.sound(player: Player, name: string)
	soundEvent:FireClient(player, name)
end

-- Marks the snapshot dirty; flushed at most ~8x per second.
function ProgressService.push(player: Player)
	dirty[player] = true
end

function ProgressService.capacity(player: Player, ingredientId: string): number
	local profile = S.DataService.get(player)
	local ing = Ingredients.get(ingredientId)
	if not profile or not ing then
		return 0
	end
	local mult = 1 + S.UpgradeService.effect(player, "capacity")
	return math.floor(ing.boxSize * GameConfig.BaseCapacityBoxes * mult)
end

local function snapshot(player: Player): { [string]: any }
	local profile = S.DataService.get(player)
	if not profile then
		return {}
	end
	local caps = {}
	for _, ing in Ingredients.List do
		caps[ing.id] = ProgressService.capacity(player, ing.id)
	end
	local snap: { [string]: any } = {
		money = profile.money,
		xp = profile.xp,
		level = profile.level,
		xpNext = Levels.xpToNext(profile.level),
		rating = profile.rating,
		reviews = profile.reviews,
		stock = profile.stock,
		capacity = caps,
		upgrades = profile.upgrades,
		unlockedRecipes = FoodLogic.unlockedRecipes(profile.level, profile.upgrades),
		stats = profile.stats,
		temporary = S.DataService.Temporary[player] == true,
	}
	for _, fn in providers do
		local ok, extra = pcall(fn, player)
		if ok and extra then
			for k, v in extra do
				snap[k] = v
			end
		end
	end
	return snap
end

function ProgressService.addMoney(player: Player, amount: number, reason: string?)
	local profile = S.DataService.get(player)
	if not profile or amount ~= amount then
		return
	end
	amount = math.floor(amount * 100 + 0.5) / 100
	profile.money = math.floor((profile.money + amount) * 100 + 0.5) / 100
	if amount > 0 then
		profile.stats.earned = (profile.stats.earned or 0) + amount
	end
	ProgressService.push(player)
end

-- Returns true and deducts if the player can afford `amount`.
function ProgressService.spend(player: Player, amount: number): boolean
	local profile = S.DataService.get(player)
	if not profile or amount < 0 or profile.money + 1e-6 < amount then
		return false
	end
	profile.money = math.floor((profile.money - amount) * 100 + 0.5) / 100
	ProgressService.push(player)
	return true
end

function ProgressService.addXP(player: Player, amount: number)
	local profile = S.DataService.get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.xp += math.floor(amount)
	while profile.level < Levels.MaxLevel and profile.xp >= Levels.xpToNext(profile.level) do
		profile.xp -= Levels.xpToNext(profile.level)
		profile.level += 1
		local reward = Levels.reward(profile.level)
		profile.money += reward
		local unlocks = Levels.unlocksAt(profile.level)
		profile.unlockedRecipes = FoodLogic.unlockedRecipes(profile.level, profile.upgrades)
		levelUpEvent:FireClient(player, {
			level = profile.level,
			reward = reward,
			unlocks = unlocks,
			xpNext = Levels.xpToNext(profile.level),
		})
		if S.PlotService then
			S.PlotService.onLevelChanged(player)
		end
	end
	player:SetAttribute("Level", profile.level)
	ProgressService.push(player)
end

-- stars: 1..5 review from one customer
function ProgressService.addReview(player: Player, stars: number)
	local profile = S.DataService.get(player)
	if not profile then
		return
	end
	stars = math.clamp(stars, 1, 5)
	-- rolling average weighted toward the last ~40 reviews
	local n = math.min(profile.reviews, 40)
	profile.rating = math.floor(((profile.rating * n + stars) / (n + 1)) * 100 + 0.5) / 100
	profile.reviews += 1
	ProgressService.push(player)
end

function ProgressService.start()
	task.spawn(function()
		while true do
			task.wait(0.12)
			for player in dirty do
				dirty[player] = nil
				if player.Parent then
					stateEvent:FireClient(player, snapshot(player))
				end
			end
		end
	end)
end

ProgressService.Upgrades = Upgrades

return ProgressService
