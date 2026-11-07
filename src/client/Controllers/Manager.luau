--!strict
-- "Pizza Planet OS": the office computer. Tabs: Supplies, Upgrades, Recipes,
-- Stats. The recipe book button on the HUD opens it on Recipes only.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Recipes = require(Shared.Config.Recipes)
local Ingredients = require(Shared.Config.Ingredients)
local Upgrades = require(Shared.Config.Upgrades)
local Themes = require(Shared.Config.Themes)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local Theme = require(script.Parent.Parent.UI.Theme)
local Responsive = require(script.Parent.Parent.UI.Responsive)
local MasteryBadge = require(script.Parent.Parent.UI.MasteryBadge)
local State = require(script.Parent.State)
local Interaction = require(script.Parent.Interaction)
local Notify = require(script.Parent.Notifications)
local DayClock = require(script.Parent.DayClock)
local Restock = require(Shared.Food.Restock)
local FoodVisuals = require(Shared.Food.FoodVisuals)
local MeshLib = require(Shared.Food.MeshLib)
local T = Theme.make
local Col = Theme.Colors

local Manager = {}
local gui: ScreenGui
local window: Frame
local content: ScrollingFrame
local footer: Frame
local footerText: TextLabel
local sideButtons: { [string]: TextButton } = {}
local tab = "Supplies"
local fromPC = false
local cart: { [string]: number } = {}

local TABS = {
	{ "Supplies", "🛒 Supplies" },
	{ "Upgrades", "⚡ Upgrades" },
	{ "Recipes", "📖 Recipes" },
	{ "Decor", "🎨 Decor" },
	{ "Stats", "📈 Business" },
}

local function clear()
	for _, ch in content:GetChildren() do
		ch:Destroy()
	end
end

local function card(parent: Instance, order: number, locked: boolean): Frame
	return T("Frame", { Parent = parent, LayoutOrder = order, BackgroundColor3 = locked and Color3.fromRGB(236, 230, 222) or Col.Paper }, { Theme.corner(14), Theme.stroke(Col.Line, 1) })
end

local function ingName(id: string): string
	local i = Ingredients.get(id)
	return i and (i.icon .. " " .. i.name) or id
end

local function cartTotals(): (number, number)
	local total, boxes = 0, 0
	for id, q in cart do
		local ing = Ingredients.get(id)
		if ing then
			total += ing.boxCost * q
			boxes += q
		end
	end
	return total, boxes
end

local render: () -> ()

local function renderSupplies()
	local snap = State.data
	local level = snap.level or 1
	T("UIGridLayout", { Parent = content, CellSize = UDim2.fromOffset(176, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, ing in Ingredients.List do
		local locked = level < ing.level
		local c = card(content, i + (locked and 1000 or 0), locked)
		local catColor = ({ dry = Color3.fromRGB(230, 170, 60), cold = Color3.fromRGB(70, 150, 230), frozen = Color3.fromRGB(90, 200, 230) })[ing.category]
		local tag = T("Frame", { Parent = c, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(56, 18), BackgroundColor3 = catColor }, { Theme.corner(9) })
		Theme.text({ Parent = tag, Size = UDim2.fromScale(1, 1), Text = string.upper(ing.category), TextSize = 10, Font = Theme.FontBlack, TextXAlignment = Enum.TextXAlignment.Center })
		Theme.text({ Parent = c, Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(40, 30), Text = ing.icon, TextSize = 24 })
		Theme.text({ Parent = c, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 18), Text = ing.name, TextColor3 = Col.Ink, Font = Theme.FontBlack, TextSize = 14 })
		local stock = (snap.stock or {})[ing.id] or 0
		local cap = (snap.capacity or {})[ing.id] or 0
		Theme.text({ Parent = c, Position = UDim2.fromOffset(10, 58), Size = UDim2.new(1, -20, 0, 16), Text = ("×%d per box · %s"):format(ing.boxSize, Theme.money(ing.boxCost)), TextColor3 = Col.InkSoft, TextSize = 12 })
		Theme.text({ Parent = c, Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 16), Text = ("In stock: %d / %d"):format(stock, cap), TextColor3 = stock == 0 and Col.Red or Col.InkSoft, TextSize = 12 })
		if locked then
			Theme.text({ Parent = c, Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 30), Text = "🔒 Level " .. ing.level, TextColor3 = Col.InkSoft, Font = Theme.FontBlack, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center })
		else
			local q = cart[ing.id] or 0
			Theme.button({ Parent = c, Position = UDim2.fromOffset(10, 104), Size = UDim2.fromOffset(40, 34), BackgroundColor3 = Color3.fromRGB(240, 226, 216), TextColor3 = Col.Ink, Text = "−", TextSize = 20 }, function()
				if (cart[ing.id] or 0) > 0 then
					cart[ing.id] -= 1
					render()
				end
			end)
			Theme.text({ Parent = c, Position = UDim2.fromOffset(50, 104), Size = UDim2.new(1, -100, 0, 34), Text = tostring(q), TextColor3 = Col.Ink, Font = Theme.FontBlack, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center })
			Theme.button({ Parent = c, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 104), Size = UDim2.fromOffset(40, 34), BackgroundColor3 = Col.Green, Text = "+", TextSize = 20 }, function()
				local _, boxes = cartTotals()
				if boxes >= GameConfig.MaxBoxesPerDelivery then
					return Notify.toast("Max " .. GameConfig.MaxBoxesPerDelivery .. " boxes per delivery", "bad")
				end
				cart[ing.id] = (cart[ing.id] or 0) + 1
				render()
			end)
		end
	end
	local total, boxes = cartTotals()
	footerText.Text = ("%d / %d boxes · Total %s · Delivered to the back door in ~%ds"):format(boxes, GameConfig.MaxBoxesPerDelivery, Theme.money(total), GameConfig.DeliveryTime)
end

local function renderUpgrades()
	local snap = State.data
	local level = snap.level or 1
	local owned = snap.upgrades or {}
	T("UIGridLayout", { Parent = content, CellSize = UDim2.fromOffset(268, 132), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, u in Upgrades.List do
		local isOwned = owned[u.id] == true
		local reqOk = not u.requires or owned[u.requires] == true
		local locked = level < u.level or not reqOk
		local c = card(content, (isOwned and 2000 or (locked and 1000 or 0)) + i, locked and not isOwned)
		Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(34, 34), Text = u.icon, TextSize = 26 })
		Theme.text({ Parent = c, Position = UDim2.fromOffset(52, 10), Size = UDim2.new(1, -64, 0, 18), Text = u.name, TextColor3 = Col.Ink, Font = Theme.FontBlack, TextSize = 15 })
		Theme.text({ Parent = c, Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -64, 0, 14), Text = string.upper(u.category), TextColor3 = Col.InkSoft, TextSize = 11 })
		Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 36), Text = u.description, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Col.InkSoft, Font = Theme.Font, TextSize = 13 })
		if isOwned then
			Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 0, 30), Text = "✓ INSTALLED", TextColor3 = Col.Green, Font = Theme.FontBlack, TextSize = 15 })
		elseif locked then
			local req = u.requires and Upgrades.get(u.requires)
			local why = if level < u.level then "🔒 Level " .. u.level else "🔒 Needs " .. (req and req.name or "?")
			Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 0, 30), Text = why, TextColor3 = Col.InkSoft, Font = Theme.FontBlack, TextSize = 14 })
		else
			Theme.button({ Parent = c, Position = UDim2.new(0, 12, 0, 90), Size = UDim2.new(1, -24, 0, 32), BackgroundColor3 = (snap.money or 0) >= u.cost and Col.Green or Color3.fromRGB(180, 180, 180), Text = "Buy  " .. Theme.money(u.cost), TextSize = 15 }, function()
				if not fromPC then
					return Notify.toast("Use the office computer to buy upgrades", "bad")
				end
				local ok, msg = Net.func("BuyUpgrade"):InvokeServer(u.id)
				Notify.toast(msg, ok and "good" or "bad")
				task.wait(0.2)
				render()
			end)
		end
	end
	footerText.Text = "Upgrades change your restaurant instantly. New ones unlock as you level up."
end

-- Dining-room themes: buy once, switch any time (server: ThemeService).
local SWATCH_ROLES = { "Floor", "Wainscot", "Wall", "TableTop", "Chair", "Seat" }

local function renderDecor()
	local snap = State.data
	local level = snap.level or 1
	local owned = snap.themes or { classic = true }
	local active = snap.theme or Themes.Default
	T("UIGridLayout", { Parent = content, CellSize = UDim2.fromOffset(268, 176), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, t in Themes.List do
		local isOwned = owned[t.id] == true
		local locked = not isOwned and level < t.level
		local c = card(content, i, locked)
		Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(34, 34), Text = t.icon, TextSize = 26 })
		Theme.text({ Parent = c, Position = UDim2.fromOffset(52, 12), Size = UDim2.new(1, -64, 0, 18), Text = t.name, TextColor3 = Col.Ink, Font = Theme.FontBlack, TextSize = 15 })
		-- colour swatches: floor, panels, walls, tables, chairs, seats
		for j, role in SWATCH_ROLES do
			local look = t.roles[role]
			if look then
				T("Frame", { Parent = c, Position = UDim2.fromOffset(12 + (j - 1) * 40, 46), Size = UDim2.fromOffset(34, 22), BackgroundColor3 = look.color }, { Theme.corner(6), Theme.stroke(Col.Line, 1) })
			end
		end
		Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -24, 0, 50), Text = t.description, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Col.InkSoft, Font = Theme.Font, TextSize = 13 })
		if active == t.id then
			Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 134), Size = UDim2.new(1, -24, 0, 30), Text = "✓ IN USE", TextColor3 = Col.Green, Font = Theme.FontBlack, TextSize = 15 })
		elseif locked then
			Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 134), Size = UDim2.new(1, -24, 0, 30), Text = "🔒 Level " .. t.level, TextColor3 = Col.InkSoft, Font = Theme.FontBlack, TextSize = 14 })
		else
			local label = if isOwned then "Use this theme" else "Buy  " .. Theme.money(t.cost)
			local affordable = isOwned or (snap.money or 0) >= t.cost
			Theme.button({ Parent = c, Name = "Theme_" .. t.id, Position = UDim2.new(0, 12, 0, 132), Size = UDim2.new(1, -24, 0, 32), BackgroundColor3 = affordable and Col.Green or Color3.fromRGB(180, 180, 180), Text = label, TextSize = 15 }, function()
				local ok, msg = Net.func("SetTheme"):InvokeServer(t.id)
				Notify.toast(msg, ok and "good" or "bad")
				task.wait(0.2)
				render()
			end)
		end
	end
	footerText.Text = "Themes restyle the dining room: floor, wall panels, walls, tables, chairs and seats. Buy once, switch any time."
end

-- 3D recipe previews: the real food model in a small ViewportFrame.
-- Models are built once per recipe (after the Blender meshes have arrived)
-- and cloned into each card, so re-rendering the tab stays cheap.
local previewCache: { [string]: Model } = {}

local function previewItem(r: any): { [string]: any }
	if r.kind == "pizza" then
		return { kind = "pizza", sauce = r.sauce, toppings = r.toppings, cook = 1, folded = r.folded }
	elseif r.kind == "kebab" then
		return { kind = "kebab", base = r.base, fillings = r.fillings, wrapped = false }
	elseif r.kind == "dessert" then
		return { kind = "dessert", flavour = r.flavour, toppings = r.toppings }
	end
	return { kind = "cup", syrup = r.syrup }
end

local function previewModel(r: any): Model?
	local cached = previewCache[r.id]
	if cached then
		return cached
	end
	local ok, m = pcall(FoodVisuals.build, previewItem(r))
	if not ok or not m then
		return nil
	end
	if MeshLib.has("Pizza") then -- don't keep a procedural stand-in once meshes exist
		previewCache[r.id] = m
	end
	return m
end

local function attachPreview(card: Frame, r: any, locked: boolean)
	local src = previewModel(r)
	if not src then
		return false
	end
	local vp = T("ViewportFrame", {
		Parent = card,
		Name = "Preview",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(50, 50),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 160, 150),
		LightColor = Color3.fromRGB(255, 244, 228),
		LightDirection = Vector3.new(-0.4, -1, -0.5),
		ImageColor3 = if locked then Color3.fromRGB(150, 150, 150) else Color3.new(1, 1, 1),
		ImageTransparency = if locked then 0.35 else 0,
	})
	local m = src:Clone()
	m.Parent = vp
	local cf, size = m:GetBoundingBox()
	local reach = math.max(size.X, size.Z, size.Y * 1.6)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, reach * 1.25, reach * 1.35), cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return true
end

-- Roblox only draws so much 3D across all ViewportFrames, so previews exist
-- only for cards on screen: they are added/removed as the list scrolls.
local previewCards: { { card: Frame, recipe: any, locked: boolean, icon: TextLabel } } = {}

local function refreshPreviews()
	if #previewCards == 0 then
		return
	end
	local top = content.AbsolutePosition.Y - 40
	local bottom = content.AbsolutePosition.Y + content.AbsoluteSize.Y + 40
	for _, e in previewCards do
		local y = e.card.AbsolutePosition.Y
		local onScreen = y + e.card.AbsoluteSize.Y > top and y < bottom
		local vp = e.card:FindFirstChild("Preview")
		if onScreen and not vp then
			e.icon.Visible = not attachPreview(e.card, e.recipe, e.locked)
		elseif not onScreen and vp then
			vp:Destroy()
			e.icon.Visible = true
		end
	end
end

local function renderRecipes()
	previewCards = {}
	local snap = State.data
	local unlocked: { [string]: boolean } = {}
	for _, id in snap.unlockedRecipes or {} do
		unlocked[id] = true
	end
	T("UIListLayout", { Parent = content, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, r in Recipes.List do
		local ok = unlocked[r.id] == true
		local c = card(content, i, not ok)
		c.Size = UDim2.new(1, -12, 0, 86 + (ok and MasteryBadge.Height or 0))
		if ok then
			MasteryBadge.attach(c, r, (snap.mastery or {})[r.id]) -- menu mastery stars + progress
		end
		-- emoji shows until (or if) the 3D preview is attached by refreshPreviews
		local icon = Theme.text({ Parent = c, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(40, 40), Text = r.icon, TextSize = 30 })
		table.insert(previewCards, { card = c, recipe = r, locked = not ok, icon = icon })
		Theme.text({ Parent = c, Position = UDim2.fromOffset(60, 8), Size = UDim2.new(1, -200, 0, 20), Text = r.name, TextColor3 = Col.Ink, Font = Theme.FontBlack, TextSize = 16 })
		local req = r.requires and Upgrades.get(r.requires)
		Theme.text({ Parent = c, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(200, 20), Text = ok and (Theme.money(r.price) .. " · " .. r.xp .. " XP") or ("🔒 Level " .. r.level .. (req and (" + " .. req.name) or "")), TextColor3 = ok and Col.Green or Col.InkSoft, Font = Theme.FontBlack, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right })
		local steps: string
		if r.kind == "pizza" then
			local tops = {}
			for _, t in r.toppings :: { string } do
				table.insert(tops, ingName(t))
			end
			if r.folded then
				steps = "1. 🍞 Dough  →  2. " .. ingName(r.sauce :: string) .. "  →  3. " .. table.concat(tops, ", ") .. "  →  4. 🥟 Fold it (F)  →  5. 🔥 Bake  →  6. 📦 Box it"
			elseif #tops == 0 then
				steps = "1. 🍞 Dough on the board  →  2. " .. ingName(r.sauce :: string) .. "  →  3. 🔥 Bake until READY  →  4. 📦 Box it"
			else
				steps = "1. 🍞 Dough on the board  →  2. " .. ingName(r.sauce :: string) .. "  →  3. " .. table.concat(tops, ", ") .. "  →  4. 🔥 Bake until READY  →  5. 📦 Box it"
			end
		elseif r.kind == "kebab" then
			local fills = {}
			for _, t in r.fillings :: { string } do
				table.insert(fills, ingName(t) .. (t == "chips" and " (fried)" or ""))
			end
			steps = "1. " .. ingName(r.base :: string) .. " on the kebab board  →  2. " .. table.concat(fills, ", ") .. "  →  3. " .. (r.base == "food_box" and "Close the box" or "Wrap it up")
		elseif r.kind == "dessert" then
			local tops = {}
			for _, t in r.toppings :: { string } do
				table.insert(tops, ingName(t))
			end
			steps = "1. 🍨 Take a dessert cup  →  2. Fill with " .. ingName(r.flavour :: string) .. "  →  3. " .. table.concat(tops, ", ")
		else
			steps = "1. 🥤 Take a cup  →  2. Hold the " .. ingName(r.syrup :: string) .. " fountain"
		end
		Theme.text({ Parent = c, Position = UDim2.fromOffset(60, 30), Size = UDim2.new(1, -72, 0, 50), Text = r.description .. "\n" .. steps, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Col.InkSoft, Font = Theme.Font, TextSize = 12 })
	end
	footerText.Text = "Serve exactly what's on the ticket. Wrong food doesn't count! Serve a recipe often to earn 🥉🥈🥇 mastery."
end

local function stat(parent: Instance, order: number, label: string, value: string, color: Color3?)
	local c = card(parent, order, false)
	Theme.text({ Parent = c, Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 16), Text = label, TextColor3 = Col.InkSoft, TextSize = 13 })
	Theme.text({ Parent = c, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 36), Text = value, TextColor3 = color or Col.Ink, Font = Theme.FontBlack, TextSize = 28 })
end

local function renderStats()
	local snap = State.data
	local st = snap.stats or {}
	T("UIGridLayout", { Parent = content, CellSize = UDim2.fromOffset(200, 86), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	stat(content, 1, "Money", Theme.money(snap.money or 0), Col.Green)
	stat(content, 2, "Review score", ("★ %.2f (%d)"):format(snap.rating or 0, snap.reviews or 0), Color3.fromRGB(220, 150, 20))
	stat(content, 3, "Customers served", tostring(st.served or 0))
	stat(content, 4, "Total earned", Theme.money(st.earned or 0))
	stat(content, 5, "Pizzas served", tostring(st.pizzas or 0))
	stat(content, 6, "Kebabs served", tostring(st.kebabs or 0))
	stat(content, 7, "Angry walk-outs", tostring(st.angry or 0), Col.Red)
	stat(content, 8, "Messes cleaned", tostring(st.cleaned or 0))
	stat(content, 9, "Cleanliness", tostring(snap.cleanliness or 100) .. "%")
	stat(content, 10, "Menu mastery", ("★ %d / %d"):format(snap.masteryStars or 0, snap.masteryMax or 0), Color3.fromRGB(220, 150, 20))
	local toggle = card(content, 11, false)
	Theme.button({ Parent = toggle, Position = UDim2.fromOffset(12, 20), Size = UDim2.new(1, -24, 0, 46), BackgroundColor3 = snap.open and Col.Red or Col.Green, Text = snap.open and "Close restaurant" or "Open restaurant", TextSize = 16 }, function()
		Net.func("ToggleOpen"):InvokeServer()
		task.wait(0.2)
		render()
	end)
	footerText.Text = "Tip: a clean restaurant and fast service mean better reviews, more customers and bigger tips."
end

render = function()
	if not window.Visible then
		return
	end
	clear()
	for name, b in sideButtons do
		local active = name == tab
		b.BackgroundColor3 = active and Color3.fromRGB(255, 228, 220) or Col.Cream
		b.TextColor3 = active and Col.Red or Col.Ink
		b.Visible = fromPC or name == "Recipes"
	end
	for _, n in { "Order", "Clear", "Emergency" } do
		local btn = footer:FindFirstChild(n) :: GuiObject?
		if btn then
			btn.Visible = tab == "Supplies"
		end
	end
	-- the order buttons only show on Supplies; elsewhere the tip gets the whole bar
	footerText.Size = UDim2.new(1, if tab == "Supplies" then -460 else -32, 1, 0)
	previewCards = {}
	if tab == "Supplies" then
		renderSupplies()
	elseif tab == "Upgrades" then
		renderUpgrades()
	elseif tab == "Decor" then
		renderDecor()
	elseif tab == "Recipes" then
		renderRecipes()
		task.defer(refreshPreviews) -- after the list layout has positioned the cards
	else
		renderStats()
	end
end

local function close()
	window.Visible = false
	Interaction.blocked = false
	DayClock.covered = false
end

local function build()
	gui = T("ScreenGui", { Name = "Manager", ResetOnSpawn = false, DisplayOrder = 20, IgnoreGuiInset = true, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	local root = Responsive.apply(gui, Responsive.WINDOW)
	window = T("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.84),
		BackgroundColor3 = Color3.fromRGB(242, 238, 236),
		Visible = false,
	}, { Theme.corner(18), T("UISizeConstraint", { MaxSize = Vector2.new(1180, 760) }) })
	T("TextButton", { Parent = window, Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromOffset(0, 0) })
	Responsive.fit(root, window, UDim2.fromScale(0.9, 0.84), UDim2.fromScale(0.98, 0.94))
	-- sidebar
	local side = T("Frame", { Parent = window, Size = UDim2.new(0, 210, 1, 0), BackgroundColor3 = Col.Cream }, { Theme.corner(18), Theme.pad(14) })
	local logo = T("Frame", { Parent = side, Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1 })
	T("Frame", { Parent = logo, Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Col.Red }, { Theme.corner(20), Theme.stroke(Col.Yellow, 3) })
	Theme.text({ Parent = logo, Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -50, 0, 22), Text = "Pizza Planet OS", TextColor3 = Col.Ink, Font = Theme.FontBlack, TextSize = 16 })
	Theme.text({ Parent = logo, Position = UDim2.fromOffset(50, 22), Size = UDim2.new(1, -50, 0, 16), Text = "Restaurant manager", TextColor3 = Col.InkSoft, TextSize = 12 })
	local nav = T("Frame", { Parent = side, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -130), BackgroundTransparency = 1 }, { Theme.list(Enum.FillDirection.Vertical, 6) })
	for i, t in TABS do
		local b = Theme.button({ Parent = nav, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Col.Cream, TextColor3 = Col.Ink, Text = "  " .. t[2], TextSize = 15, Font = Theme.Font }, function()
			tab = t[1]
			render()
		end)
		b.TextXAlignment = Enum.TextXAlignment.Left
		sideButtons[t[1]] = b
	end
	Theme.button({ Parent = side, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(252, 226, 226), TextColor3 = Col.Red, Text = "Log off", TextSize = 15 }, close)
	-- content
	content = T("ScrollingFrame", {
		Parent = window,
		Position = UDim2.fromOffset(226, 16),
		Size = UDim2.new(1, -242, 1, -96),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
	})
	content:GetPropertyChangedSignal("CanvasPosition"):Connect(refreshPreviews)
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshPreviews)
	-- footer bar
	footer = T("Frame", { Parent = window, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 226, 1, -14), Size = UDim2.new(1, -242, 0, 60), BackgroundColor3 = Color3.fromRGB(36, 16, 14) }, { Theme.corner(14) })
	footerText = Theme.text({ Parent = footer, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -460, 1, 0), Text = "", TextWrapped = true, TextSize = 13 })
	local orderBtn = Theme.button({ Parent = footer, Name = "Order", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 40), BackgroundColor3 = Col.Green, Text = "🚚 Place order", TextSize = 15 }, function()
		local _, boxes = cartTotals()
		if boxes == 0 then
			return Notify.toast("Add some boxes first", "bad")
		end
		local ok, msg = Net.func("OrderSupplies"):InvokeServer(cart)
		Notify.toast(msg, ok and "good" or "bad")
		if ok then
			cart = {}
		end
		task.wait(0.2)
		render()
	end)
	_ = orderBtn
	Theme.button({ Parent = footer, Name = "Clear", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -180, 0.5, 0), Size = UDim2.fromOffset(90, 40), BackgroundColor3 = Color3.fromRGB(240, 236, 230), TextColor3 = Col.Ink, Text = "Clear", TextSize = 15 }, function()
		cart = {}
		render()
	end)
	Theme.button({ Parent = footer, Name = "Emergency", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -280, 0.5, 0), Size = UDim2.fromOffset(150, 40), BackgroundColor3 = Color3.fromRGB(252, 226, 226), TextColor3 = Col.Red, Text = "🚨 Emergency (free)", TextSize = 13 }, function()
		local ok, msg = Net.func("EmergencyDelivery"):InvokeServer()
		Notify.toast(msg, ok and "good" or "bad")
	end)
end

function Manager.open(which: string?, pc: boolean)
	fromPC = pc
	tab = which or "Supplies"
	if not pc then
		tab = "Recipes"
	end
	window.Visible = true
	Interaction.blocked = true
	DayClock.covered = true -- the day-clock pill would sit over the window's corner
	render()
end

function Manager.start()
	build()
	Net.event("OpenManager").OnClientEvent:Connect(function(which)
		if which == "Restock" then
			-- office tablet: Supplies with a suggested top-up in the cart
			local snap = State.data
			cart = Restock.suggest(Ingredients.List, snap.stock or {}, snap.capacity or {}, snap.level or 1, GameConfig.MaxBoxesPerDelivery)
			local _, boxes = cartTotals()
			Manager.open("Supplies", true)
			Notify.toast(if boxes > 0 then ("📱 Suggested restock: %d box%s. Check it and place the order."):format(boxes, boxes == 1 and "" or "es") else "📱 Everything is well stocked", "info")
			return
		end
		Manager.open(which, true)
	end)
	-- light refresh for live numbers (money, stock) without rebuilding every tick
	local last = 0
	local lastMastery = ""
	local function masteryKey(): string
		local parts = {}
		for id, n in State.get("mastery") or {} do
			table.insert(parts, id .. "=" .. tostring(n))
		end
		table.sort(parts)
		return table.concat(parts, ",")
	end
	State.Changed:Connect(function()
		if not window.Visible then
			return
		end
		if (tab == "Upgrades" or tab == "Stats") and os.clock() - last > 1 then
			last = os.clock()
			render()
		elseif tab == "Recipes" then
			-- redraw the mastery rows when a count changes (a serve, a new tier),
			-- keeping the scroll position
			local key = masteryKey()
			if key ~= lastMastery then
				lastMastery = key
				local scroll = content.CanvasPosition
				render()
				content.CanvasPosition = scroll
			end
		end
	end)
end

return Manager
