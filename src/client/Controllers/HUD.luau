--!strict
-- Always-on HUD: money / level / XP / rating (top right), restaurant status and
-- order tickets (top left), held item (bottom centre), recipe book button.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Recipes = require(Shared.Config.Recipes)

local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local T = Theme.make
local Col = Theme.Colors

local HUD = {}
HUD.openRecipes = nil :: (() -> ())?

local gui: ScreenGui
local moneyLabel: TextLabel
local levelLabel: TextLabel
local xpFill: Frame
local xpText: TextLabel
local ratingLabel: TextLabel
local cleanLabel: TextLabel
local statusLabel: TextLabel
local statusDot: Frame
local ordersFrame: Frame
local heldPill: Frame
local heldLabel: TextLabel
local warnLabel: TextLabel
local lastMoney = 0

local function pill(parent: Instance, name: string, size: UDim2): Frame
	return T("Frame", {
		Name = name,
		Parent = parent,
		Size = size,
		BackgroundColor3 = Col.Pill,
		BackgroundTransparency = 0.12,
	}, { Theme.corner(14) })
end

local function build()
	local player = Players.LocalPlayer
	gui = T("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- TOP RIGHT --------------------------------------------------------
	local right = T("Frame", {
		Name = "Right",
		Parent = gui,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(420, 52),
		BackgroundTransparency = 1,
	}, { Theme.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) })

	local lvl = pill(right, "Level", UDim2.fromOffset(150, 52))
	lvl.LayoutOrder = 1
	local badge = T("Frame", {
		Parent = lvl,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Col.Purple,
	}, { Theme.corner(20) })
	levelLabel = Theme.text({ Parent = badge, Size = UDim2.fromScale(1, 1), Text = "1", Font = Theme.FontBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center })
	Theme.text({ Parent = lvl, Position = UDim2.fromOffset(54, 6), Size = UDim2.fromOffset(90, 16), Text = "LEVEL", TextSize = 12, TextColor3 = Col.Muted })
	local xpBg = T("Frame", { Parent = lvl, Position = UDim2.fromOffset(54, 24), Size = UDim2.fromOffset(88, 10), BackgroundColor3 = Color3.fromRGB(60, 55, 70) }, { Theme.corner(5) })
	xpFill = T("Frame", { Parent = xpBg, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Col.Purple }, { Theme.corner(5) })
	xpText = Theme.text({ Parent = lvl, Position = UDim2.fromOffset(54, 35), Size = UDim2.fromOffset(90, 14), Text = "0 / 80 XP", TextSize = 11, TextColor3 = Col.Muted })

	local money = pill(right, "Money", UDim2.fromOffset(150, 52))
	money.LayoutOrder = 2
	moneyLabel = Theme.text({ Parent = money, Size = UDim2.fromScale(1, 1), Text = "$0.00", Font = Theme.FontBlack, TextSize = 24, TextColor3 = Color3.fromRGB(120, 240, 140), TextXAlignment = Enum.TextXAlignment.Center })

	local rating = pill(right, "Rating", UDim2.fromOffset(96, 52))
	rating.LayoutOrder = 3
	ratingLabel = Theme.text({ Parent = rating, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 26), Text = "★ 4.0", Font = Theme.FontBlack, TextSize = 20, TextColor3 = Col.Yellow, TextXAlignment = Enum.TextXAlignment.Center })
	cleanLabel = Theme.text({ Parent = rating, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 16), Text = "🧽 100%", TextSize = 12, TextColor3 = Col.Muted, TextXAlignment = Enum.TextXAlignment.Center })

	-- TOP LEFT ---------------------------------------------------------
	local left = T("Frame", {
		Name = "Left",
		Parent = gui,
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(0, 250, 1, -200),
		BackgroundTransparency = 1,
	}, { Theme.list(Enum.FillDirection.Vertical, 8) })
	local status = pill(left, "Status", UDim2.fromOffset(250, 40))
	status.LayoutOrder = 1
	statusDot = T("Frame", { Parent = status, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Col.Red }, { Theme.corner(6) })
	statusLabel = Theme.text({ Parent = status, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), Text = "CLOSED · flip the sign to open", TextSize = 14 })
	warnLabel = Theme.text({ Parent = left, LayoutOrder = 2, Size = UDim2.fromOffset(250, 34), Text = "⚠ Progress is not being saved (Studio / DataStore unavailable)", TextWrapped = true, TextSize = 12, TextColor3 = Col.Yellow, Visible = false })
	ordersFrame = T("Frame", {
		Name = "Orders",
		Parent = left,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 1, -90),
		BackgroundTransparency = 1,
	}, { Theme.list(Enum.FillDirection.Vertical, 6) })

	-- BOTTOM CENTRE: held item ----------------------------------------
	heldPill = pill(gui, "Held", UDim2.fromOffset(360, 40))
	heldPill.AnchorPoint = Vector2.new(0.5, 1)
	heldPill.Position = UDim2.new(0.5, 0, 1, -18)
	heldPill.Visible = false
	heldLabel = Theme.text({ Parent = heldPill, Size = UDim2.fromScale(1, 1), Text = "", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })

	-- Recipe book button (right edge)
	local bookBtn = Theme.button({
		Parent = gui,
		Name = "RecipeButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 70),
		Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = Col.Red,
		Text = "📖 Recipes",
		TextSize = 16,
	}, function()
		if HUD.openRecipes then
			HUD.openRecipes()
		end
	end)
	bookBtn.ZIndex = 2
end

local function orderCard(order: any, index: number)
	local card = T("Frame", {
		Name = "Order" .. order.number,
		Parent = ordersFrame,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 34 + #order.items * 20 + 12),
		BackgroundColor3 = Col.Paper,
	}, { Theme.corner(12) })
	local head = T("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Col.Red }, { Theme.corner(12) })
	T("Frame", { Parent = head, Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Col.Red, BorderSizePixel = 0 })
	Theme.text({ Parent = head, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -80, 1, 0), Text = "#" .. order.number .. "  " .. order.customerName, Font = Theme.FontBlack, TextSize = 15 })
	Theme.text({ Parent = head, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(70, 30), Text = Theme.money(order.price), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right })
	for i, entry in order.items do
		local r = Recipes.get(entry.recipe)
		Theme.text({
			Parent = card,
			Position = UDim2.fromOffset(12, 32 + (i - 1) * 20),
			Size = UDim2.new(1, -24, 0, 20),
			Text = (entry.done and "✓ " or "○ ") .. (r and (r.icon .. " " .. r.name) or entry.recipe),
			TextSize = 14,
			TextColor3 = entry.done and Col.Green or Col.Ink,
		})
	end
	local barBg = T("Frame", { Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.new(1, -20, 0, 5), BackgroundColor3 = Col.Line }, { Theme.corner(3) })
	local frac = order.patience or 0
	T("Frame", { Parent = barBg, Size = UDim2.fromScale(frac, 1), BackgroundColor3 = Color3.fromRGB(230, 60, 50):Lerp(Col.Green, frac) }, { Theme.corner(3) })
end

local function update(snap: { [string]: any })
	if not gui then
		return
	end
	local money = snap.money or 0
	moneyLabel.Text = Theme.money(money)
	if money > lastMoney + 0.001 and lastMoney > 0 then
		moneyLabel.TextColor3 = Color3.fromRGB(255, 255, 140)
		TweenService:Create(moneyLabel, TweenInfo.new(0.6), { TextColor3 = Color3.fromRGB(120, 240, 140) }):Play()
	end
	lastMoney = money
	levelLabel.Text = tostring(snap.level or 1)
	local xpNext = snap.xpNext or 1
	local frac = math.clamp((snap.xp or 0) / xpNext, 0, 1)
	TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(frac, 1) }):Play()
	xpText.Text = ("%d / %d XP"):format(snap.xp or 0, xpNext)
	ratingLabel.Text = ("★ %.1f"):format(snap.rating or 0)
	cleanLabel.Text = ("🧽 %d%%"):format(snap.cleanliness or 100)
	if snap.open then
		statusDot.BackgroundColor3 = Col.Green
		local n = #(snap.orders or {})
		statusLabel.Text = ("OPEN · %d in queue · %d order%s"):format(snap.queue or 0, n, if n == 1 then "" else "s")
	else
		statusDot.BackgroundColor3 = Col.Red
		statusLabel.Text = "CLOSED · flip the sign by the door"
	end
	warnLabel.Visible = snap.temporary == true
	for _, ch in ordersFrame:GetChildren() do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	for i, order in snap.orders or {} do
		if i <= 5 then
			orderCard(order, i)
		end
	end
	if snap.heldText then
		heldPill.Visible = true
		local ok = snap.heldRecipe ~= nil
		heldLabel.Text = "✋ " .. snap.heldText .. (ok and "  ✓" or "")
		heldLabel.TextColor3 = ok and Color3.fromRGB(140, 255, 160) or Col.PillText
	else
		heldPill.Visible = false
	end
end

function HUD.start()
	build()
	State.Changed:Connect(update)
	if next(State.data) then
		update(State.data)
	end
end

return HUD
