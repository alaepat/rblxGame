--!strict
-- Every interactive kitchen station. The RestaurantBuilder tags parts with a
-- `Station` attribute (plus extra attributes); this service turns them into
-- ProximityPrompts and runs their rules on the server.
--
-- Station types: Bin, PizzaBoard, KebabBoard, Topping, Oven, Fryer, BoxStation,
-- HeatShelf, Trash, Fountain, Register, Pickup, Storage, OfficePC, OpenSign

local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ingredients = require(Shared.Config.Ingredients)
local Recipes = require(Shared.Config.Recipes)
local GameConfig = require(Shared.Config.GameConfig)
local FoodLogic = require(Shared.Food.FoodLogic)
local FoodVisuals = require(Shared.Food.FoodVisuals)
local Net = require(Shared.Net)

type Item = { [string]: any }
type Station = {
	kind: string,
	part: BasePart,
	plot: any,
	item: Item?,
	visual: Model?,
	prompts: { [string]: ProximityPrompt },
	uses: number,
	dirty: boolean,
	gui: BillboardGui?,
	lastState: string?,
	busy: boolean?,
}

local StationService = {}
local S: any
local byPart: { [BasePart]: Station } = {}

function StationService.init(services)
	S = services
end

------------------------------------------------------------------ helpers

local function ingName(id: string): string
	local ing = Ingredients.get(id)
	return ing and ing.name or id
end

local function profileOf(st: Station)
	local owner = st.plot.owner
	return owner, owner and S.DataService.get(owner)
end

local function hasStock(player: Player, id: string, n: number?): boolean
	local profile = S.DataService.get(player)
	return profile ~= nil and (profile.stock[id] or 0) >= (n or 1)
end

local function useStock(player: Player, id: string, n: number?): boolean
	local profile = S.DataService.get(player)
	n = n or 1
	if not profile or (profile.stock[id] or 0) < (n :: number) then
		return false
	end
	profile.stock[id] -= n :: number
	S.ProgressService.push(player)
	return true
end
StationService.useStock = useStock

local function itemAt(st: Station): CFrame
	local at = st.part:FindFirstChild("ItemAt")
	if at and at:IsA("Attachment") then
		return at.WorldCFrame
	end
	return st.part.CFrame * CFrame.new(0, st.part.Size.Y / 2, 0)
end

local function setItem(st: Station, item: Item?)
	st.item = item
	if st.visual then
		st.visual:Destroy()
		st.visual = nil
	end
	if item then
		local m = FoodVisuals.build(item)
		m.Name = "StationItem"
		m:PivotTo(itemAt(st))
		m.Parent = st.part
		st.visual = m
	end
end
StationService.setItem = setItem

local function newPrompt(st: Station, key: string, keyCode: Enum.KeyCode?, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "Prompt_" .. key
	p.ObjectText = st.part:GetAttribute("Label") or st.kind
	p.ActionText = key
	p.KeyboardKeyCode = keyCode or Enum.KeyCode.E
	p.GamepadKeyCode = if keyCode == Enum.KeyCode.F then Enum.KeyCode.ButtonY else Enum.KeyCode.ButtonX
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = GameConfig.PromptDistance
	p.RequiresLineOfSight = false
	-- Custom style: the client InteractionController draws the UI for the
	-- prompt under the cursor/crosshair (lets players aim at one topping pan).
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	local at = st.part:FindFirstChild("PromptAt")
	p.Parent = if at then at else st.part
	st.prompts[key] = p
	return p
end

local function show(p: ProximityPrompt?, enabled: boolean, text: string?)
	if not p then
		return
	end
	p.Enabled = enabled
	if text then
		p.ActionText = text
	end
end

local function cookSpeed(player: Player?): number
	if not player then
		return 1
	end
	return 1 + S.UpgradeService.effect(player, "cookSpeed")
end

local function boardFor(st: Station): Station?
	local boardId = st.part:GetAttribute("Board")
	if not boardId then
		return nil
	end
	for _, other in st.plot.stations do
		if (other.kind == "PizzaBoard" or other.kind == "KebabBoard") and other.part:GetAttribute("BoardId") == boardId then
			return other
		end
	end
	return nil
end

local function ensureGui(st: Station): BillboardGui
	if st.gui then
		return st.gui
	end
	local g = Instance.new("BillboardGui")
	g.Name = "CookGui"
	g.Size = UDim2.fromOffset(150, 38)
	g.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	g.AlwaysOnTop = true
	g.MaxDistance = 40
	g.LightInfluence = 0
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(25, 22, 28)
	bg.BackgroundTransparency = 0.15
	bg.Parent = g
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Position = UDim2.fromOffset(4, 4)
	fill.Size = UDim2.new(0, 0, 1, -8)
	fill.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Parent = bg
	local pad = Instance.new("UIPadding", label)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	g.Parent = st.part
	st.gui = g
	return g
end

local function updateCookGui(st: Station)
	local item = st.item
	if not item then
		if st.gui then
			st.gui.Enabled = false
		end
		return
	end
	local g = ensureGui(st)
	g.Enabled = true
	local cook = item.cook or 0
	local state = FoodLogic.cookState(cook)
	local bg = g:FindFirstChildOfClass("Frame") :: Frame
	local fill = bg:FindFirstChild("Fill") :: Frame
	local label = bg:FindFirstChild("Label") :: TextLabel
	local pct = math.floor(cook * 100)
	local frac = math.clamp(cook / GameConfig.BurnAt, 0, 1)
	fill.Size = UDim2.new(frac, -8 * frac, 1, -8)
	if state == "cooked" then
		fill.BackgroundColor3 = Color3.fromRGB(70, 200, 90)
		label.Text = "READY " .. pct .. "%"
	elseif state == "burnt" then
		fill.BackgroundColor3 = Color3.fromRGB(60, 40, 30)
		label.Text = "BURNT!"
	else
		fill.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
		label.Text = pct .. "%"
	end
end

------------------------------------------------------------------ refresh

local function refresh(st: Station)
	local owner, profile = profileOf(st)
	if not owner or not profile then
		for _, p in st.prompts do
			p.Enabled = false
		end
		return
	end
	local held: Item? = S.HeldService.get(owner)
	local empty = held == nil
	local k = st.kind
	local P = st.prompts

	if k == "Bin" then
		local id = st.part:GetAttribute("Ingredient") :: string
		local ing = Ingredients.get(id)
		if ing and profile.level < ing.level then
			show(P.main, true, "Unlocks at level " .. ing.level)
		elseif not hasStock(owner, id) then
			show(P.main, true, "Out of stock")
		else
			show(P.main, empty, "Take " .. ingName(id) .. " (" .. (profile.stock[id] or 0) .. ")")
		end
	elseif k == "PizzaBoard" then
		local level = profile.level
		show(P.fold, FoodLogic.canFold(st.item) and level >= GameConfig.CalzoneLevel, "Fold into a calzone")
		if st.item then
			show(P.main, empty, "Pick up " .. (st.item.folded and "calzone" or "pizza"))
		elseif held and held.kind == "dough" then
			show(P.main, true, "Place dough")
		elseif held and held.kind == "pizza" and not held.boxed and (held.cook or 0) == 0 then
			show(P.main, true, "Put pizza down")
		else
			show(P.main, false)
		end
	elseif k == "KebabBoard" then
		local item = st.item
		if item then
			show(P.main, empty, "Pick up " .. (item.base == "food_box" and "box" or "kebab"))
			local canWrap = not item.wrapped and #item.fillings > 0
			show(P.wrap, canWrap and empty, item.base == "food_box" and "Close the box" or "Wrap it up")
			local chipsReady = held and held.kind == "chips" and FoodLogic.cookState(held.cook or 0) == "cooked"
			show(P.chips, chipsReady and item.base == "food_box" and not item.wrapped and not table.find(item.fillings, "chips"), "Add chips")
		else
			show(P.main, held ~= nil and held.kind == "bread", "Place " .. (held and held.base and ingName(held.base) or "bread"))
			show(P.wrap, false)
			show(P.chips, false)
		end
	elseif k == "Topping" then
		local id = st.part:GetAttribute("Ingredient") :: string
		local ing = Ingredients.get(id)
		if ing and profile.level < ing.level then
			show(P.main, true, "Unlocks at level " .. ing.level)
		elseif not hasStock(owner, id) then
			show(P.main, true, ingName(id) .. ": out of stock")
		else
			show(P.main, true, "Add " .. ingName(id))
		end
	elseif k == "Oven" or k == "Fryer" then
		local accepts = if k == "Oven" then "pizza" else "chips"
		if st.item then
			local state = FoodLogic.cookState(st.item.cook or 0)
			show(P.main, empty, "Take out (" .. state .. ")")
		else
			local ok = held ~= nil and held.kind == accepts and not held.boxed and (held.cook or 0) < GameConfig.BurnAt
			show(P.main, ok, if k == "Oven" then "Put pizza in oven" else "Drop basket in fryer")
		end
	elseif k == "BoxStation" then
		local ok = held ~= nil and held.kind == "pizza" and not held.boxed
		show(P.main, ok, "Put pizza in a box (" .. (profile.stock.pizza_box or 0) .. ")")
	elseif k == "HeatShelf" then
		if st.item then
			show(P.main, empty, "Take " .. FoodLogic.describe(st.item))
		else
			show(P.main, held ~= nil and held.kind ~= "supply", "Set down here")
		end
	elseif k == "Trash" then
		show(P.main, held ~= nil, "Throw away")
	elseif k == "Fountain" and st.busy then
		show(P.main, false, "Pouring...")
	elseif k == "Fountain" then
		local syrup = st.part:GetAttribute("Ingredient") :: string
		local recipe: any = nil
		for _, r in Recipes.List do
			if r.kind == "drink" and r.syrup == syrup then
				recipe = r
			end
		end
		if recipe and profile.level < recipe.level then
			show(P.main, true, "Unlocks at level " .. recipe.level)
		else
			local ok = held ~= nil and held.kind == "cup" and held.syrup == nil
			show(P.main, ok, "Pour " .. (recipe and recipe.name or "drink"))
		end
	elseif k == "SoftServe" and st.busy then
		show(P.main, false, "Filling...")
	elseif k == "SoftServe" then
		local mix = st.part:GetAttribute("Ingredient") :: string
		local ing = Ingredients.get(mix)
		if not hasStock(owner, mix) then
			show(P.main, true, ingName(mix) .. ": out of stock")
		else
			local ok = held ~= nil and held.kind == "dessert" and held.flavour == nil
			show(P.main, ok, "Fill with " .. (ing and ing.name:gsub(" Mix$", "") or "ice cream"))
		end
	elseif k == "DessertTopping" then
		local id = st.part:GetAttribute("Ingredient") :: string
		local ing = Ingredients.get(id)
		if ing and profile.level < ing.level then
			show(P.main, true, "Unlocks at level " .. ing.level)
		elseif not hasStock(owner, id) then
			show(P.main, true, ingName(id) .. ": out of stock")
		else
			show(P.main, held ~= nil and held.kind == "dessert" and held.flavour ~= nil, "Add " .. ingName(id))
		end
	elseif k == "Register" then
		local ready = S.CustomerService.frontCustomer(st.plot) ~= nil
		show(P.main, ready, "Take order")
	elseif k == "Pickup" then
		show(P.main, held ~= nil and FoodLogic.isPackaged(held), "Serve " .. (held and FoodLogic.describe(held) or ""))
	elseif k == "Storage" then
		local cat = st.part:GetAttribute("Category")
		local ok = held ~= nil and held.kind == "supply"
		local ing = ok and Ingredients.get((held :: Item).ingredient)
		if ok and ing and ing.category ~= cat then
			show(P.main, true, "This belongs in " .. ing.category .. " storage")
		else
			show(P.main, ok, "Put away")
		end
	elseif k == "OfficePC" then
		show(P.main, true, "Use computer")
	elseif k == "OpenSign" then
		show(P.main, true, st.plot.open and "Close restaurant" or "Open restaurant")
	end
end

-- Redraws one station after something other than a prompt changed it
-- (staff taking a pizza out of the oven, putting one on the heat shelf).
function StationService.refreshStation(st: Station)
	if st.kind == "Oven" or st.kind == "Fryer" then
		st.lastState = FoodLogic.cookState(st.item and st.item.cook or 0)
		updateCookGui(st)
	end
	refresh(st)
end

function StationService.refreshPlot(plot)
	if not plot.stations then
		return
	end
	for _, st in plot.stations do
		refresh(st)
	end
end

function StationService.refreshFor(player: Player)
	local plot = S.PlotService.get(player)
	if plot then
		StationService.refreshPlot(plot)
	end
end

------------------------------------------------------------------ actions

local function deny(player: Player, text: string)
	S.ProgressService.notify(player, text, "bad")
	S.ProgressService.sound(player, "Error")
end

local function markUse(st: Station)
	st.uses += 1
	if st.uses >= GameConfig.PrepUsesBeforeDirty and not st.dirty then
		S.CleaningService.makeDirty(st)
	end
end

local actions: { [string]: (Station, Player, string) -> () } = {}

actions.Bin = function(st, player)
	local id = st.part:GetAttribute("Ingredient") :: string
	local ing = Ingredients.get(id)
	local profile = S.DataService.get(player)
	if ing and profile.level < ing.level then
		return deny(player, ing.name .. " unlocks at level " .. ing.level)
	end
	if not S.HeldService.isEmpty(player) then
		return deny(player, "Your hands are full")
	end
	if not useStock(player, id) then
		return deny(player, "Out of " .. ingName(id) .. ". Order more on the office computer.")
	end
	local item: Item
	if id == "dough" then
		item = { kind = "dough" }
	elseif id == "cup" then
		item = { kind = "cup" }
	elseif id == "dessert_cup" then
		item = { kind = "dessert", toppings = {} }
	elseif id == "chips" then
		item = { kind = "chips", cook = 0 }
	else
		item = { kind = "bread", base = id }
	end
	S.HeldService.set(player, item)
	S.ProgressService.sound(player, "Pickup")
end

actions.PizzaBoard = function(st, player, which)
	local held = S.HeldService.get(player)
	if which == "fold" then
		local profile = S.DataService.get(player)
		if not FoodLogic.canFold(st.item) or profile.level < GameConfig.CalzoneLevel then
			return
		end
		st.item.folded = true
		setItem(st, st.item)
		markUse(st)
		S.ProgressService.sound(player, "Wrap")
		S.StationService.refreshFor(player)
		return
	end
	if st.item then
		if held then
			return deny(player, "Your hands are full")
		end
		local item = st.item
		setItem(st, nil)
		S.HeldService.set(player, item)
		S.ProgressService.sound(player, "Pickup")
		return
	end
	if held and held.kind == "dough" then
		S.HeldService.take(player)
		setItem(st, { kind = "pizza", toppings = {}, cook = 0, boxed = false })
		markUse(st)
		S.ProgressService.sound(player, "Place")
	elseif held and held.kind == "pizza" and not held.boxed and (held.cook or 0) == 0 then
		setItem(st, S.HeldService.take(player))
		S.ProgressService.sound(player, "Place")
	end
	refresh(st)
end

actions.KebabBoard = function(st, player, which)
	local held = S.HeldService.get(player)
	local item = st.item
	if which == "wrap" then
		if not item or item.wrapped or #item.fillings == 0 then
			return
		end
		if item.base ~= "food_box" and not useStock(player, "kebab_wrapper") then
			return deny(player, "Out of kebab wrappers")
		end
		item.wrapped = true
		setItem(st, item)
		markUse(st)
		S.ProgressService.sound(player, "Wrap")
		S.StationService.refreshFor(player)
		return
	elseif which == "chips" then
		if not item or item.base ~= "food_box" or not held or held.kind ~= "chips" then
			return
		end
		if FoodLogic.cookState(held.cook or 0) ~= "cooked" then
			return deny(player, "The chips need frying first")
		end
		local ok, err = FoodLogic.canAddToKebab(item, "chips")
		if not ok then
			return deny(player, err or "Can't add that")
		end
		table.insert(item.fillings, "chips")
		S.HeldService.take(player)
		setItem(st, item)
		S.ProgressService.sound(player, "Topping")
		return
	end
	if item then
		if held then
			return deny(player, "Your hands are full")
		end
		setItem(st, nil)
		S.HeldService.set(player, item)
		S.ProgressService.sound(player, "Pickup")
		return
	end
	if held and held.kind == "bread" then
		S.HeldService.take(player)
		setItem(st, { kind = "kebab", base = held.base, fillings = {}, wrapped = false })
		S.ProgressService.sound(player, "Place")
		refresh(st)
	end
end

actions.Topping = function(st, player)
	local id = st.part:GetAttribute("Ingredient") :: string
	local ing = Ingredients.get(id)
	local profile = S.DataService.get(player)
	if ing and profile.level < ing.level then
		return deny(player, ing.name .. " unlocks at level " .. ing.level)
	end
	local board = boardFor(st)
	if not board or not board.item then
		return deny(player, if board and board.kind == "KebabBoard" then "Put a pitta, wrap or box on the board first" else "Put dough on the board first")
	end
	local item = board.item :: Item
	local ok, err
	if board.kind == "PizzaBoard" then
		ok, err = FoodLogic.canAddToPizza(item, id)
	else
		ok, err = FoodLogic.canAddToKebab(item, id)
	end
	if not ok then
		return deny(player, err or "Can't add that")
	end
	if not useStock(player, id) then
		return deny(player, "Out of " .. ingName(id) .. ". Order more on the office computer.")
	end
	if board.kind == "PizzaBoard" then
		if FoodLogic.PizzaSauces[id] then
			item.sauce = id
		else
			table.insert(item.toppings, id)
		end
	else
		table.insert(item.fillings, id)
	end
	setItem(board, item)
	S.ProgressService.sound(player, if FoodLogic.PizzaSauces[id] or FoodLogic.KebabSauces[id] then "Sauce" else "Topping")
	S.StationService.refreshFor(player)
end

local function cookAction(accepts: string)
	return function(st: Station, player: Player)
		local held = S.HeldService.get(player)
		if st.item then
			if held then
				return deny(player, "Your hands are full")
			end
			local item = st.item
			setItem(st, nil)
			updateCookGui(st)
			S.HeldService.set(player, item)
			S.ProgressService.sound(player, "OvenOpen")
			if accepts == "pizza" and FoodLogic.cookState(item.cook or 0) == "cooked" then
				S.GoalService.record(player, "bake_perfect", 1)
			end
			return
		end
		if held and held.kind == accepts and not held.boxed then
			if accepts == "pizza" and not held.sauce then
				return deny(player, "Add sauce and toppings before baking")
			end
			setItem(st, S.HeldService.take(player))
			st.lastState = FoodLogic.cookState(st.item and st.item.cook or 0)
			updateCookGui(st)
			S.ProgressService.sound(player, "OvenOpen")
			refresh(st)
		end
	end
end
actions.Oven = cookAction("pizza")
actions.Fryer = cookAction("chips")

actions.BoxStation = function(st, player)
	local held = S.HeldService.get(player)
	if not held or held.kind ~= "pizza" or held.boxed then
		return
	end
	local state = FoodLogic.cookState(held.cook or 0)
	if state == "raw" or state == "cooking" then
		return deny(player, "Bake the pizza in the oven first")
	elseif state == "burnt" then
		return deny(player, "That's burnt! Throw it in the bin")
	end
	if not useStock(player, "pizza_box") then
		return deny(player, "Out of pizza boxes")
	end
	held.boxed = true
	S.HeldService.changed(player)
	S.ProgressService.sound(player, "Box")
	if not FoodLogic.identify(held) then
		S.ProgressService.notify(player, "Heads up: that pizza doesn't match anything on the menu", "bad")
	end
end

actions.HeatShelf = function(st, player)
	local held = S.HeldService.get(player)
	if st.item then
		if held then
			return deny(player, "Your hands are full")
		end
		local item = st.item
		setItem(st, nil)
		S.HeldService.set(player, item)
	elseif held and held.kind ~= "supply" then
		setItem(st, S.HeldService.take(player))
	end
	S.ProgressService.sound(player, "Place")
	refresh(st)
end

actions.Trash = function(st, player)
	local held = S.HeldService.take(player)
	if held then
		S.ProgressService.sound(player, "Trash")
	end
end

actions.Fountain = function(st, player)
	local held = S.HeldService.get(player)
	local syrup = st.part:GetAttribute("Ingredient") :: string
	if not held or held.kind ~= "cup" or held.syrup then
		return deny(player, "Grab an empty cup first")
	end
	local profile = S.DataService.get(player)
	for _, r in Recipes.List do
		if r.kind == "drink" and r.syrup == syrup and profile.level < r.level then
			return deny(player, r.name .. " unlocks at level " .. r.level)
		end
	end
	if st.busy then
		return
	end
	if not useStock(player, syrup) then
		return deny(player, "Out of " .. ingName(syrup))
	end
	-- Pour takes a moment (single press; hold-prompts don't work with the custom UI).
	st.busy = true
	S.ProgressService.sound(player, "Pour")
	show(st.prompts.main, false, "Pouring...")
	-- the wait runs on its own thread so the prompt handler returns at once
	task.delay(GameConfig.PourTime, function()
		st.busy = false
		if player.Parent and S.HeldService.get(player) == held and held.syrup == nil then
			held.syrup = syrup
			S.HeldService.changed(player) -- also refreshes every station
		else
			-- cup was dropped or swapped mid-pour: give the syrup back
			local p = S.DataService.get(player)
			if p then
				p.stock[syrup] = (p.stock[syrup] or 0) + 1
				S.ProgressService.push(player)
			end
			refresh(st)
		end
	end)
end

-- Soft-serve: fill the held dessert cup (takes a moment, like the fountain)
actions.SoftServe = function(st, player)
	local held = S.HeldService.get(player)
	local mix = st.part:GetAttribute("Ingredient") :: string
	if not held or held.kind ~= "dessert" or held.flavour then
		return deny(player, "Grab an empty dessert cup first")
	end
	if st.busy then
		return
	end
	if not useStock(player, mix) then
		return deny(player, "Out of " .. ingName(mix))
	end
	st.busy = true
	S.ProgressService.sound(player, "Pour")
	show(st.prompts.main, false, "Filling...")
	task.delay(GameConfig.PourTime, function()
		st.busy = false
		if player.Parent and S.HeldService.get(player) == held and held.flavour == nil then
			held.flavour = mix
			S.HeldService.changed(player)
		else
			local p = S.DataService.get(player)
			if p then
				p.stock[mix] = (p.stock[mix] or 0) + 1
				S.ProgressService.push(player)
			end
			refresh(st)
		end
	end)
end

actions.DessertTopping = function(st, player)
	local id = st.part:GetAttribute("Ingredient") :: string
	local ing = Ingredients.get(id)
	local profile = S.DataService.get(player)
	if ing and profile.level < ing.level then
		return deny(player, ing.name .. " unlocks at level " .. ing.level)
	end
	local held = S.HeldService.get(player)
	local ok, err = FoodLogic.canAddToDessert(held or {}, id)
	if not ok then
		return deny(player, err or "Can't add that")
	end
	if not useStock(player, id) then
		return deny(player, "Out of " .. ingName(id) .. ". Order more on the office computer.")
	end
	table.insert((held :: Item).toppings, id)
	S.HeldService.changed(player)
	S.ProgressService.sound(player, if id == "sprinkles" or id == "cookie_crumble" then "Topping" else "Sauce")
end

actions.Register = function(st, player)
	S.CustomerService.openPOS(player, st.plot)
end

actions.Pickup = function(st, player)
	S.CustomerService.serve(player, st.plot)
end

actions.Storage = function(st, player)
	S.SupplyService.putAway(player, st)
end

actions.OfficePC = function(st, player)
	Net.event("OpenManager"):FireClient(player, "Supplies")
	S.ProgressService.sound(player, "Click")
end

actions.OfficeTablet = function(st, player)
	Net.event("OpenManager"):FireClient(player, "Restock")
	S.ProgressService.sound(player, "Click")
end

actions.OpenSign = function(st, player)
	S.CustomerService.setOpen(st.plot, not st.plot.open)
end

------------------------------------------------------------------ setup

local function setupStation(plot, part: BasePart)
	local kind = part:GetAttribute("Station") :: string
	local st: Station = {
		kind = kind,
		part = part,
		plot = plot,
		item = nil,
		visual = nil,
		prompts = {},
		uses = 0,
		dirty = false,
		gui = nil,
	}
	newPrompt(st, "main", Enum.KeyCode.E, 0)
	if kind == "PizzaBoard" then
		newPrompt(st, "fold", Enum.KeyCode.F)
	end
	if kind == "KebabBoard" then
		newPrompt(st, "wrap", Enum.KeyCode.F)
		newPrompt(st, "chips", Enum.KeyCode.R)
	end
	for key, prompt in st.prompts do
		prompt.Triggered:Connect(function(player)
			if player ~= plot.owner then
				return S.ProgressService.notify(player, "This isn't your restaurant", "bad")
			end
			local fn = actions[kind]
			if fn then
				local ok, err = pcall(fn, st, player, key)
				if not ok then
					warn("[StationService] " .. kind .. " error: " .. tostring(err))
				end
			end
			refresh(st)
		end)
	end
	byPart[part] = st
	table.insert(plot.stations, st)
	return st
end

function StationService.setupPlot(plot)
	plot.stations = {}
	for _, d in plot.model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Station") then
			setupStation(plot, d)
		end
	end
	StationService.refreshPlot(plot)
end

function StationService.cleanupPlot(plot)
	if plot.stations then
		for _, st in plot.stations do
			byPart[st.part] = nil
		end
	end
	plot.stations = nil
end

function StationService.get(part: BasePart): Station?
	return byPart[part]
end

function StationService.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		local step = acc
		acc = 0
		for _, plot in S.PlotService.Plots do
			if plot.stations and plot.owner then
				local speed = cookSpeed(plot.owner)
				for _, st in plot.stations do
					if (st.kind == "Oven" or st.kind == "Fryer") and st.item and st.part:IsDescendantOf(workspace) then
						local item = st.item :: Item
						local total = if st.kind == "Oven" then FoodLogic.pizzaCookTime(item) else GameConfig.ChipsCookTime
						item.cook = (item.cook or 0) + step * speed / total
						local state = FoodLogic.cookState(item.cook)
						if state ~= st.lastState then
							st.lastState = state
							setItem(st, item)
							refresh(st)
							if state == "cooked" then
								S.ProgressService.sound(plot.owner, "Ding")
							elseif state == "burnt" then
								S.ProgressService.notify(plot.owner, "Something is burning!", "bad")
							end
						end
						updateCookGui(st)
					end
				end
			end
		end
	end)
end

return StationService
