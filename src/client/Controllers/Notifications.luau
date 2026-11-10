--!strict
-- Toast messages and the level-up celebration popup.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Recipes = require(Shared.Config.Recipes)
local Ingredients = require(Shared.Config.Ingredients)
local Upgrades = require(Shared.Config.Upgrades)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Parent.UI.Theme)
local Responsive = require(script.Parent.Parent.UI.Responsive)
local Sounds = require(script.Parent.Sounds)
local T = Theme.make
local Col = Theme.Colors

local Notifications = {}
local gui: ScreenGui
local stack: Frame
local levelWindow: Frame
local levelQueue: { any } = {}
local showingLevel = false

local KIND_COLORS = {
	good = Color3.fromRGB(46, 170, 90),
	bad = Color3.fromRGB(210, 60, 50),
	info = Color3.fromRGB(60, 60, 80),
}

function Notifications.toast(text: string, kind: string?)
	if not stack then
		return
	end
	local color = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	local f = T("Frame", {
		Parent = stack,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Col.Pill,
		BackgroundTransparency = 0.08,
		LayoutOrder = math.floor(os.clock() * 100),
	}, { Theme.corner(20), Theme.pad(0, 16) })
	T("Frame", { Parent = f, Position = UDim2.new(0, -10, 0.5, -5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = color }, { Theme.corner(5) })
	Theme.text({ Parent = f, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 15 })
	if #stack:GetChildren() > 6 then
		for _, ch in stack:GetChildren() do
			if ch:IsA("Frame") then
				ch:Destroy()
				break
			end
		end
	end
	task.delay(4, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			for _, d in f:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				elseif d:IsA("Frame") then
					TweenService:Create(d, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				end
			end
			task.wait(0.35)
			f:Destroy()
		end
	end)
end

local function unlockRow(parent: Instance, order: number, icon: string, text: string, tag: string, tagColor: Color3)
	local row = T("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Col.Paper }, { Theme.corner(10) })
	Theme.text({ Parent = row, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -110, 1, 0), Text = icon .. "  " .. text, TextColor3 = Col.Ink, TextSize = 15 })
	local t = T("Frame", { Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(90, 22), BackgroundColor3 = tagColor }, { Theme.corner(11) })
	Theme.text({ Parent = t, Size = UDim2.fromScale(1, 1), Text = tag, Font = Theme.FontBlack, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center })
end

-- The end-of-day summary card (DayClock) and the level-up window must never
-- stack: the summary goes first, level-ups wait until it is closed.
local currentLevel: any = nil
local waitingOnSummary = false

local function openSummary(): Instance?
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local dc = pg and pg:FindFirstChild("DayClock")
	-- recursive: Responsive moves the card into the gui's scaled Root frame
	return dc and dc:FindFirstChild("DaySummary", true)
end

local showNextLevel: () -> ()

local function waitForSummary(card: Instance)
	if waitingOnSummary then
		return
	end
	waitingOnSummary = true
	card.Destroying:Once(function()
		waitingOnSummary = false
		task.defer(showNextLevel) -- re-checks: a new summary may have replaced this one
	end)
end

-- Several level-ups in a row (a big serve, mastery rewards, a shift bonus)
-- become ONE popup: highest level, rewards added up, all unlocks listed.
local LEVEL_AUTO_CLOSE = 12 -- seconds; the popup never sits on screen forever
local levelToken = 0

local function concat(a: { any }?, b: { any }?): { any }
	local out = table.clone(a or {})
	for _, v in b or {} do
		table.insert(out, v)
	end
	return out
end

local function mergeLevels(a: any, b: any): any
	local ua, ub = a.unlocks or {}, b.unlocks or {}
	return {
		level = math.max(a.level or 0, b.level or 0),
		fromLevel = math.min(a.fromLevel or a.level or 0, b.fromLevel or b.level or 0),
		reward = (a.reward or 0) + (b.reward or 0),
		xpNext = if (b.level or 0) >= (a.level or 0) then b.xpNext else a.xpNext,
		unlocks = {
			recipes = concat(ua.recipes, ub.recipes),
			ingredients = concat(ua.ingredients, ub.ingredients),
			upgrades = concat(ua.upgrades, ub.upgrades),
			note = ub.note or ua.note,
		},
	}
end

local function closeLevel()
	levelToken += 1
	levelWindow.Visible = false
	showingLevel = false
	currentLevel = nil
	showNextLevel()
end

function showNextLevel()
	if showingLevel or #levelQueue == 0 then
		return
	end
	local card = openSummary()
	if card then
		return waitForSummary(card)
	end
	showingLevel = true
	local p = table.remove(levelQueue, 1)
	currentLevel = p
	levelToken += 1
	local token = levelToken
	for _, ch in levelWindow:GetChildren() do
		if not ch:IsA("UICorner") and not ch:IsA("UISizeConstraint") then
			ch:Destroy()
		end
	end
	T("TextButton", { Parent = levelWindow, Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromOffset(0, 0) })
	local banner = T("Frame", { Parent = levelWindow, Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Color3.new(1, 1, 1) }, { Theme.corner(18) })
	T("UIGradient", { Parent = banner, Color = ColorSequence.new(Color3.fromRGB(150, 90, 240), Color3.fromRGB(240, 80, 120)), Rotation = 20 })
	Theme.text({ Parent = banner, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 24), Text = "LEVEL UP!", Font = Theme.FontBlack, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center })
	Theme.text({ Parent = banner, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 60), Text = tostring(p.level), Font = Theme.FontFun, TextSize = 60, TextXAlignment = Enum.TextXAlignment.Center })
	local sub = "Next level in " .. tostring(p.xpNext) .. " XP"
	if p.fromLevel and p.fromLevel < p.level then
		sub = ("Levels %d → %d  ·  "):format(p.fromLevel, p.level) .. sub
	end
	Theme.text({ Parent = banner, Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 18), Text = sub, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(240, 230, 255) })
	local body = T("ScrollingFrame", { Parent = levelWindow, Position = UDim2.fromOffset(16, 132), Size = UDim2.new(1, -32, 1, -200), BackgroundTransparency = 1, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, { Theme.list(Enum.FillDirection.Vertical, 6) })
	local n = 0
	n += 1
	unlockRow(body, n, "💰", "Level reward", "+" .. Theme.money(p.reward), Col.Green)
	for _, id in p.unlocks.recipes or {} do
		local r = Recipes.get(id)
		if r then
			n += 1
			unlockRow(body, n, r.icon, r.name .. (r.requires and " (needs " .. (Upgrades.get(r.requires) or {} :: any).name .. ")" or ""), "NEW RECIPE", Col.Red)
		end
	end
	for _, id in p.unlocks.ingredients or {} do
		local ing = Ingredients.get(id)
		if ing then
			n += 1
			unlockRow(body, n, ing.icon, ing.name, "INGREDIENT", Color3.fromRGB(230, 130, 30))
		end
	end
	for _, id in p.unlocks.upgrades or {} do
		local u = Upgrades.get(id)
		if u then
			n += 1
			unlockRow(body, n, u.icon, u.name .. "  " .. Theme.money(u.cost), "UPGRADE", Col.Blue)
		end
	end
	if p.unlocks.note then
		n += 1
		unlockRow(body, n, "⭐", p.unlocks.note, "MILESTONE", Col.Purple)
	end
	Theme.button({ Parent = levelWindow, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(1, -32, 0, 44), BackgroundColor3 = Col.Green, Text = "Awesome!", TextSize = 18 }, function()
		closeLevel()
	end)
	if not levelWindow.Visible then
		levelWindow.Size = UDim2.fromOffset(380, 300)
		TweenService:Create(levelWindow, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(420, 460) }):Play()
	end
	levelWindow.Visible = true
	Sounds.play("LevelUp")
	task.delay(LEVEL_AUTO_CLOSE, function()
		if levelToken == token and showingLevel then
			closeLevel()
		end
	end)
end

function Notifications.levelUp(payload: any)
	if showingLevel and currentLevel then
		-- already celebrating: fold the new level into the open popup
		local merged = mergeLevels(currentLevel, payload)
		showingLevel = false
		table.insert(levelQueue, 1, merged)
	elseif #levelQueue > 0 then
		levelQueue[#levelQueue] = mergeLevels(levelQueue[#levelQueue], payload)
	else
		table.insert(levelQueue, payload)
	end
	showNextLevel()
end

function Notifications.start()
	gui = T("ScreenGui", { Name = "Notifications", ResetOnSpawn = false, DisplayOrder = 30, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	Responsive.apply(gui, Responsive.POPUP)
	stack = T("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(600, 300),
		BackgroundTransparency = 1,
	}, { Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })
	levelWindow = T("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 460),
		BackgroundColor3 = Col.Cream,
		Visible = false,
	}, { Theme.corner(18), T("UISizeConstraint", { MaxSize = Vector2.new(440, 520) }) })
	Net.event("Notify").OnClientEvent:Connect(function(text, kind)
		Notifications.toast(text, kind)
	end)
	Net.event("LevelUp").OnClientEvent:Connect(Notifications.levelUp)
	-- A summary card opening over a level-up: put the level-up back at the
	-- front of the queue and show it again once the summary is closed.
	gui.Parent.DescendantAdded:Connect(function(d)
		if d.Name ~= "DaySummary" or not d:IsA("GuiObject") then
			return
		end
		if showingLevel and currentLevel then
			table.insert(levelQueue, 1, currentLevel)
			currentLevel = nil
			showingLevel = false
			levelWindow.Visible = false
		end
		if #levelQueue > 0 then
			waitForSummary(d)
		end
	end)
end

return Notifications
