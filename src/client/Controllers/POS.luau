--!strict
-- Register screen: read what the customer says, tap the matching menu items,
-- send the order. The server checks it against what they actually want.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Recipes = require(Shared.Config.Recipes)
local Mastery = require(Shared.Mastery.Mastery)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Parent.UI.Theme)
local Responsive = require(script.Parent.Parent.UI.Responsive)
local Interaction = require(script.Parent.Interaction)
local DayClock = require(script.Parent.DayClock)
local State = require(script.Parent.State)
local Notify = require(script.Parent.Notifications)
local T = Theme.make
local Col = Theme.Colors

local POS = {}
local gui: ScreenGui
local window: Frame
local saysLabel: TextLabel
local nameLabel: TextLabel
local menuGrid: Frame
local cartList: Frame
local totalLabel: TextLabel
local sendBtn: TextButton
local tabs: Frame
local cart: { string } = {}
local menu: { string } = {}
local filter = "all"

local KIND_TABS = { { "all", "All" }, { "pizza", "🍕 Pizzas" }, { "kebab", "🥙 Kebabs" }, { "drink", "🥤 Drinks" } }

local function close(cancel: boolean)
	window.Visible = false
	Interaction.blocked = false
	DayClock.covered = false
	if cancel then
		task.spawn(function()
			Net.func("CancelPOS"):InvokeServer()
		end)
	end
end

-- Price after menu mastery (gold recipes sell for more; the server prices the order).
local function priceOf(r: any): number
	return Mastery.priceFor(r, (State.get("mastery") or {})[r.id])
end

local function refreshCart()
	for _, ch in cartList:GetChildren() do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	local counts: { [string]: number } = {}
	local order: { string } = {}
	local total = 0
	for _, id in cart do
		if not counts[id] then
			table.insert(order, id)
		end
		counts[id] = (counts[id] or 0) + 1
		local r = Recipes.get(id)
		total += r and priceOf(r) or 0
	end
	for i, id in order do
		local r = Recipes.get(id) :: any
		local row = T("Frame", { Parent = cartList, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Col.Paper }, { Theme.corner(10) })
		Theme.text({ Parent = row, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -110, 1, 0), Text = r.icon .. " " .. r.name, TextColor3 = Col.Ink, TextSize = 15 })
		Theme.text({ Parent = row, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -74, 0, 0), Size = UDim2.fromOffset(30, 40), Text = "×" .. counts[id], TextColor3 = Col.Ink, Font = Theme.FontBlack, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center })
		Theme.button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -38, 0.5, 0), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(240, 220, 210), TextColor3 = Col.Red, Text = "−", TextSize = 20 }, function()
			local idx = table.find(cart, id)
			if idx then
				table.remove(cart, idx)
				refreshCart()
			end
		end)
		Theme.button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Col.Ink, Text = "+", TextSize = 18 }, function()
			table.insert(cart, id)
			refreshCart()
		end)
	end
	totalLabel.Text = Theme.money(total) .. "  ·  " .. #cart .. " items"
	sendBtn.BackgroundTransparency = #cart > 0 and 0 or 0.5
end

local function refreshMenu()
	for _, ch in menuGrid:GetChildren() do
		if ch:IsA("GuiButton") then
			ch:Destroy()
		end
	end
	for i, id in menu do
		local r = Recipes.get(id) :: any
		if filter == "all" or r.kind == filter then
			local accent = if r.kind == "pizza" then Col.Red elseif r.kind == "kebab" then Color3.fromRGB(230, 120, 30) else Col.Blue
			local b = Theme.button({ Parent = menuGrid, LayoutOrder = i, BackgroundColor3 = Col.Paper, Text = "" }, function()
				table.insert(cart, id)
				refreshCart()
			end)
			Theme.text({ Parent = b, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 34), Text = r.icon, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center })
			Theme.text({ Parent = b, Position = UDim2.fromOffset(4, 44), Size = UDim2.new(1, -8, 0, 32), Text = r.name, TextWrapped = true, TextColor3 = Col.Ink, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center })
			Theme.text({ Parent = b, Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 18), Text = Theme.money(priceOf(r)) .. (if priceOf(r) > r.price then " 🥇" else ""), TextColor3 = Col.Green, Font = Theme.FontBlack, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center })
			T("Frame", { Parent = b, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0.7, 0, 0, 4), BackgroundColor3 = accent }, { Theme.corner(2) })
		end
	end
	for _, tab in tabs:GetChildren() do
		if tab:IsA("TextButton") then
			tab.BackgroundColor3 = tab.Name == filter and Col.Ink or Color3.fromRGB(240, 230, 214)
			tab.TextColor3 = tab.Name == filter and Color3.new(1, 1, 1) or Col.Ink
		end
	end
end

local function build()
	gui = T("ScreenGui", { Name = "POS", ResetOnSpawn = false, DisplayOrder = 20, IgnoreGuiInset = true, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	local root = Responsive.apply(gui, Responsive.WINDOW)
	window = T("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.86, 0.8),
		BackgroundColor3 = Col.Cream,
		Visible = false,
	}, { Theme.corner(18), T("UISizeConstraint", { MaxSize = Vector2.new(1100, 700) }) })
	-- Modal button frees the mouse in first person while the window is open
	T("TextButton", { Parent = window, Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromOffset(0, 0) })
	Responsive.fit(root, window, UDim2.fromScale(0.86, 0.8), UDim2.fromScale(0.98, 0.94))
	-- header
	local header = T("Frame", { Parent = window, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.fromRGB(36, 16, 14) }, { Theme.corner(18) })
	T("Frame", { Parent = header, Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = Color3.fromRGB(36, 16, 14), BorderSizePixel = 0 })
	T("Frame", { Parent = header, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Col.Red, BorderSizePixel = 0 })
	Theme.text({ Parent = header, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.5, 0, 1, 0), Text = "🪐 PIZZA PLANET · FRONT COUNTER", Font = Theme.FontFun, TextSize = 20 })
	Theme.button({ Parent = header, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(90, 36), BackgroundColor3 = Color3.fromRGB(70, 40, 36), Text = "Leave", TextSize = 15 }, function()
		close(true)
	end)
	-- left: tabs + menu grid
	local left = T("Frame", { Parent = window, Position = UDim2.fromOffset(16, 72), Size = UDim2.new(0.62, -24, 1, -88), BackgroundTransparency = 1 })
	tabs = T("Frame", { Parent = left, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, { Theme.list(Enum.FillDirection.Horizontal, 8) })
	for i, tab in KIND_TABS do
		Theme.button({ Parent = tabs, Name = tab[1], LayoutOrder = i, Size = UDim2.fromOffset(110, 34), Text = tab[2], TextSize = 14, BackgroundColor3 = Col.Ink, Radius = 17 }, function()
			filter = tab[1]
			refreshMenu()
		end)
	end
	local scroll = T("ScrollingFrame", { Parent = left, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 })
	menuGrid = scroll
	T("UIGridLayout", { Parent = scroll, CellSize = UDim2.fromOffset(124, 110), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	-- right: speech bubble + cart + send
	local right = T("Frame", { Parent = window, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 72), Size = UDim2.new(0.38, -8, 1, -88), BackgroundColor3 = Color3.fromRGB(245, 236, 220) }, { Theme.corner(14), Theme.pad(12) })
	local bubble = T("Frame", { Parent = right, Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = Color3.fromRGB(252, 232, 180) }, { Theme.corner(12), Theme.pad(10) })
	nameLabel = Theme.text({ Parent = bubble, Size = UDim2.new(1, 0, 0, 16), Text = "CUSTOMER SAYS", TextColor3 = Color3.fromRGB(190, 110, 20), Font = Theme.FontBlack, TextSize = 12 })
	saysLabel = Theme.text({ Parent = bubble, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), Text = "", TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Col.Ink, Font = Theme.Font, TextSize = 16 })
	cartList = T("ScrollingFrame", { Parent = right, Position = UDim2.fromOffset(0, 122), Size = UDim2.new(1, 0, 1, -240), BackgroundTransparency = 1, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, { Theme.list(Enum.FillDirection.Vertical, 6) })
	Theme.text({ Parent = right, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 16), Text = "TOTAL · Tap items to build the order", TextColor3 = Col.InkSoft, TextSize = 12 })
	totalLabel = Theme.text({ Parent = right, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 24), Text = "$0.00", TextColor3 = Col.Ink, Font = Theme.FontBlack, TextSize = 22 })
	Theme.button({ Parent = right, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.34, -6, 0, 36), BackgroundColor3 = Color3.fromRGB(230, 218, 200), TextColor3 = Col.Ink, Text = "Clear", TextSize = 15 }, function()
		cart = {}
		refreshCart()
	end)
	sendBtn = Theme.button({ Parent = right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0.66, 0, 0, 36), BackgroundColor3 = Col.Green, Text = "Send order ✓", TextSize = 16 }, function()
		if #cart == 0 then
			return
		end
		local ok, msg = Net.func("SubmitOrder"):InvokeServer(cart)
		if ok then
			Notify.toast(msg, "good")
			close(false)
		else
			Notify.toast(msg, "bad")
		end
	end)
end

function POS.open(payload: any)
	cart = {}
	menu = payload.menu or {}
	filter = "all"
	saysLabel.Text = "“" .. payload.says .. "”"
	nameLabel.Text = string.upper(payload.customerName) .. " SAYS  ·  " .. (payload.personality or "")
	refreshMenu()
	refreshCart()
	window.Visible = true
	Interaction.blocked = true
	DayClock.covered = true -- the day-clock pill would sit over the window's corner
end

function POS.start()
	build()
	Net.event("OpenPOS").OnClientEvent:Connect(POS.open)
end

return POS
