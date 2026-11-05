--!strict
-- Ingredient ordering and deliveries.
-- Office computer -> OrderSupplies({id = boxes}) -> money taken -> after
-- DeliveryTime the boxes appear on the back-door pallet -> player carries each
-- box to matching storage (dry shelf / fridge / freezer) -> stock goes up.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ingredients = require(Shared.Config.Ingredients)
local GameConfig = require(Shared.Config.GameConfig)
local FoodVisuals = require(Shared.Food.FoodVisuals)
local Net = require(Shared.Net)

local SupplyService = {}
local S: any

function SupplyService.init(services)
	S = services
end

local function pendingUnits(plot, id: string): number
	local n = 0
	for _, box in plot.deliveries or {} do
		if box.item.ingredient == id then
			n += box.item.amount
		end
	end
	return n
end

local function spawnBox(plot, item)
	local pad = S.PlotService.node(plot, "DeliveryPad")
	if not pad or not plot.model then
		return
	end
	plot.deliveries = plot.deliveries or {}
	local index = #plot.deliveries
	local model = FoodVisuals.build(item)
	model.Name = "Delivery"
	local col = index % 3
	local row = (index // 3) % 3
	local layer = index // 9
	model:PivotTo(pad.CFrame * CFrame.new(-2.2 + col * 2.2, 0.1 + layer * 1.35, -1.7 + row * 1.7))
	local box = model:FindFirstChild("Box") :: BasePart
	box.CanQuery = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.ObjectText = "Supply box"
	prompt.ActionText = "Pick up"
	prompt.MaxActivationDistance = GameConfig.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	local entry = { item = item, model = model }
	table.insert(plot.deliveries, entry)
	prompt.Triggered:Connect(function(player)
		if player ~= plot.owner then
			return
		end
		if not S.HeldService.isEmpty(player) then
			return S.ProgressService.notify(player, "Your hands are full", "bad")
		end
		local i = table.find(plot.deliveries, entry)
		if not i then
			return
		end
		table.remove(plot.deliveries, i)
		model:Destroy()
		S.HeldService.set(player, item)
		S.ProgressService.sound(player, "Pickup")
	end)
	model.Parent = plot.model
end

function SupplyService.order(player: Player, cart: any): (boolean, string)
	local plot = S.PlotService.get(player)
	local profile = S.DataService.get(player)
	if not plot or not profile or type(cart) ~= "table" then
		return false, "Invalid order"
	end
	local total, boxes = 0, 0
	local lines = {}
	for id, qty in cart do
		if type(id) ~= "string" or type(qty) ~= "number" or qty ~= qty or qty < 0 or qty % 1 ~= 0 then
			return false, "Invalid quantity"
		end
		if qty > 0 then
			local ing = Ingredients.get(id)
			if not ing then
				return false, "Unknown item"
			end
			if profile.level < ing.level then
				return false, ing.name .. " unlocks at level " .. ing.level
			end
			local cap = S.ProgressService.capacity(player, id)
			local after = (profile.stock[id] or 0) + pendingUnits(plot, id) + qty * ing.boxSize
			if after > cap + ing.boxSize - 1 then
				return false, "Not enough storage space for " .. ing.name .. " (max " .. cap .. ")"
			end
			total += ing.boxCost * qty
			boxes += qty
			table.insert(lines, { ing = ing, qty = qty })
		end
	end
	if boxes == 0 then
		return false, "Your cart is empty"
	end
	if boxes > GameConfig.MaxBoxesPerDelivery then
		return false, "Max " .. GameConfig.MaxBoxesPerDelivery .. " boxes per delivery"
	end
	if #(plot.deliveries or {}) + boxes > 27 then
		return false, "The delivery pallet is full. Put some boxes away first."
	end
	if not S.ProgressService.spend(player, total) then
		return false, ("You need $%.2f"):format(total)
	end
	task.delay(GameConfig.DeliveryTime, function()
		if S.PlotService.get(player) ~= plot then
			return
		end
		for _, line in lines do
			for _ = 1, line.qty do
				spawnBox(plot, { kind = "supply", ingredient = line.ing.id, amount = line.ing.boxSize })
			end
		end
		S.ProgressService.notify(player, "🚚 Delivery arrived at the back door!", "good")
		S.ProgressService.sound(player, "Truck")
	end)
	return true, ("Ordered %d box%s for $%.2f. Arriving in %ds."):format(boxes, boxes == 1 and "" or "es", total, GameConfig.DeliveryTime)
end

function SupplyService.putAway(player: Player, st)
	local held = S.HeldService.get(player)
	if not held or held.kind ~= "supply" then
		return
	end
	local ing = Ingredients.get(held.ingredient)
	if not ing then
		return
	end
	if ing.category ~= st.part:GetAttribute("Category") then
		return S.ProgressService.notify(player, ing.name .. " goes in " .. ing.category .. " storage", "bad")
	end
	local profile = S.DataService.get(player)
	local cap = S.ProgressService.capacity(player, ing.id)
	local current = profile.stock[ing.id] or 0
	if current >= cap then
		return S.ProgressService.notify(player, ing.name .. " storage is full", "bad")
	end
	local added = math.min(held.amount, cap - current)
	profile.stock[ing.id] = current + added
	if added < held.amount then
		held.amount -= added
		S.HeldService.changed(player)
		S.ProgressService.notify(player, ("Stored %d %s. Storage is now full."):format(added, ing.name), "info")
	else
		S.HeldService.take(player)
		S.ProgressService.notify(player, ("+%d %s"):format(added, ing.name), "good")
	end
	S.ProgressService.addXP(player, 1)
	S.ProgressService.sound(player, "Place")
	S.ProgressService.push(player)
	S.StationService.refreshFor(player)
end

-- Free basics if the player is broke and out of dough (prevents soft-locks).
function SupplyService.emergency(player: Player): (boolean, string)
	local profile = S.DataService.get(player)
	local plot = S.PlotService.get(player)
	if not profile or not plot then
		return false, "No restaurant"
	end
	if os.time() - (profile.lastEmergency or 0) < GameConfig.EmergencyCooldown then
		return false, "Emergency delivery is on cooldown"
	end
	local dough = Ingredients.get("dough") :: any
	if profile.money >= dough.boxCost * 2 then
		return false, "Emergency delivery is only for when you can't afford supplies"
	end
	profile.lastEmergency = os.time()
	for _, id in { "dough", "tomato_sauce", "mozzarella", "pizza_box" } do
		local ing = Ingredients.get(id) :: any
		spawnBox(plot, { kind = "supply", ingredient = id, amount = math.ceil(ing.boxSize / 2) })
	end
	return true, "Head office sent the basics to your back door, free!"
end

function SupplyService.setupPlot(plot)
	plot.deliveries = {}
end

function SupplyService.cleanupPlot(plot)
	for _, d in plot.deliveries or {} do
		d.model:Destroy()
	end
	plot.deliveries = {}
end

function SupplyService.start()
	Net.func("OrderSupplies").OnServerInvoke = function(player, cart)
		return SupplyService.order(player, cart)
	end
	Net.func("EmergencyDelivery").OnServerInvoke = function(player)
		return SupplyService.emergency(player)
	end
end

return SupplyService
