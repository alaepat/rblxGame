--!strict
-- NPC customers and their orders.
-- Flow: spawn on the sidewalk -> walk in -> queue -> order at the register
-- (player uses the POS) -> wait at the pickup area -> collect food, pay, leave.
-- Patience runs down the whole time; at zero the customer storms out.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Recipes = require(Shared.Config.Recipes)
local GameConfig = require(Shared.Config.GameConfig)
local DayCycleConfig = require(Shared.Config.DayCycle)
local FoodLogic = require(Shared.Food.FoodLogic)
local Net = require(Shared.Net)

local CustomerService = {}
local S: any

type Customer = {
	id: number,
	plot: any,
	model: Model,
	humanoid: Humanoid,
	name: string,
	personality: any,
	want: { string },
	says: string,
	state: string, -- arriving | queue | waiting | collecting | leaving
	patience: number,
	patienceMax: number,
	path: { Vector3 },
	order: any?,
	waitSlot: number?,
	gui: BillboardGui?,
	alive: boolean,
}

local NAMES = {
	"Amir", "Bella", "Callum", "Dani", "Eli", "Fatima", "George", "Hana", "Isaac", "Jade", "Kofi", "Lena",
	"Marco", "Nia", "Oscar", "Priya", "Quinn", "Rosa", "Sami", "Tilly", "Umar", "Vera", "Will", "Yara", "Zane",
}
local PERSONALITIES = {
	{ id = "relaxed", label = "Relaxed", patience = 1.35, tip = 0.9 },
	{ id = "regular", label = "Regular", patience = 1.0, tip = 1.0 },
	{ id = "hurried", label = "In a hurry", patience = 0.7, tip = 1.35 },
	{ id = "generous", label = "Generous", patience = 1.0, tip = 1.6 },
	{ id = "hungry", label = "Very hungry", patience = 0.9, tip = 1.1, extra = true },
}
local SKIN = {
	Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(150, 100, 70), Color3.fromRGB(105, 70, 50), Color3.fromRGB(255, 204, 160),
}
local SHIRTS = {
	Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 220), Color3.fromRGB(60, 170, 90), Color3.fromRGB(250, 190, 40),
	Color3.fromRGB(150, 80, 200), Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 48), Color3.fromRGB(255, 130, 60),
	Color3.fromRGB(80, 200, 200), Color3.fromRGB(230, 110, 170),
}
local PANTS = {
	Color3.fromRGB(40, 50, 80), Color3.fromRGB(30, 30, 35), Color3.fromRGB(110, 80, 60), Color3.fromRGB(90, 100, 110),
	Color3.fromRGB(70, 90, 140), Color3.fromRGB(150, 130, 100),
}
local WALK_ANIM = "rbxassetid://507777826"
local IDLE_ANIM = "rbxassetid://507766388"

local rng = Random.new()
local nextId = 0
local posEvent = Net.event("OpenPOS")

function CustomerService.init(services)
	S = services
end

------------------------------------------------------------------ helpers

local function node(plot, name: string): Vector3?
	local n = S.PlotService.node(plot, name)
	return n and n.Position
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function maxQueue(plot): number
	local owner = plot.owner
	local extra = owner and S.UpgradeService.effect(owner, "queue") or 0
	local n = GameConfig.BaseQueueSize + extra
	-- never exceed the number of queue nodes in the building
	local count = 0
	while S.PlotService.node(plot, "Queue" .. (count + 1)) do
		count += 1
	end
	return math.min(n, count)
end

local function waitSlots(plot): number
	local count = 0
	while S.PlotService.node(plot, "Wait" .. (count + 1)) do
		count += 1
	end
	return count
end

local function buildWant(plot): { string }
	local profile = S.DataService.get(plot.owner)
	local unlocked = FoodLogic.unlockedRecipes(profile.level, profile.upgrades)
	local mains, drinks = {}, {}
	for _, id in unlocked do
		local r = Recipes.get(id) :: any
		if r.kind == "drink" then
			table.insert(drinks, id)
		else
			-- newer recipes appear a little more often so they get practised
			local weight = 1 + math.max(0, r.level - profile.level + 3) // 2
			for _ = 1, weight do
				table.insert(mains, id)
			end
		end
	end
	local want = {}
	table.insert(want, pick(mains))
	if rng:NextNumber() < 0.25 and #want < GameConfig.MaxItemsPerOrder then
		table.insert(want, pick(mains))
	end
	if #drinks > 0 and rng:NextNumber() < 0.55 and #want < GameConfig.MaxItemsPerOrder then
		table.insert(want, pick(drinks))
	end
	return want
end

local function sayOrder(want: { string }): string
	local names = {}
	for _, id in want do
		local r = Recipes.get(id)
		table.insert(names, (r and r.name or id))
	end
	local list: string
	if #names == 1 then
		list = "a " .. names[1]
	else
		list = "a " .. table.concat(names, ", a ", 1, #names - 1) .. " and a " .. names[#names]
	end
	local openers = { "Hi! Can I get ", "Hello! I'd like ", "Hey there, ", "Evening! I'll have ", "Could I please have " }
	local closers = { ", please.", " to take away, please.", ". Thanks!", ", cheers!" }
	return pick(openers) .. list .. pick(closers)
end

------------------------------------------------------------------ NPC model

local function makeDescription(): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin, shirt, pants = pick(SKIN), pick(SHIRTS), pick(PANTS)
	d.HeadColor = skin
	d.TorsoColor = shirt
	d.LeftArmColor = if rng:NextNumber() < 0.5 then shirt else skin
	d.RightArmColor = d.LeftArmColor
	d.LeftLegColor = pants
	d.RightLegColor = pants
	return d
end

local function fallbackModel(): Model
	-- Simple blocky rig used only if avatar creation fails.
	local m = Instance.new("Model")
	local function p(name, size, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = m
		return part
	end
	local hrp = p("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(1, 1, 1))
	hrp.Transparency = 1
	local torso = p("Torso", Vector3.new(2, 2, 1), pick(SHIRTS))
	local head = p("Head", Vector3.new(1.2, 1.2, 1.2), pick(SKIN))
	head.Shape = Enum.PartType.Ball
	local legs = p("Legs", Vector3.new(2, 2, 1), pick(PANTS))
	torso.CFrame = hrp.CFrame
	head.CFrame = hrp.CFrame * CFrame.new(0, 1.6, 0)
	legs.CFrame = hrp.CFrame * CFrame.new(0, -2, 0)
	for _, part in { torso, head, legs } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = part
		w.Parent = part
		part.CanCollide = false
	end
	local h = Instance.new("Humanoid")
	h.HipHeight = 3
	h.Parent = m
	m.PrimaryPart = hrp
	return m
end

local function createNPC(): Model
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(makeDescription(), Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		return model
	end
	warn("[CustomerService] avatar creation failed, using fallback:", model)
	return fallbackModel()
end

local function setupAnimations(c: Customer)
	local animator = c.humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = c.humanoid
	local okW, walk = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = WALK_ANIM
		return animator:LoadAnimation(a)
	end)
	local okI, idle = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = IDLE_ANIM
		return animator:LoadAnimation(a)
	end)
	if okI then
		idle.Looped = true
		idle:Play()
	end
	if okW then
		walk.Looped = true
		c.humanoid.Running:Connect(function(speed)
			if speed > 0.5 then
				if not walk.IsPlaying then
					walk:Play(0.15)
				end
				walk:AdjustSpeed(speed / 12)
			elseif walk.IsPlaying then
				walk:Stop(0.2)
			end
		end)
	end
end

local function makeGui(c: Customer)
	local head = c.model:FindFirstChild("Head") :: BasePart?
	local g = Instance.new("BillboardGui")
	g.Name = "CustomerGui"
	g.Size = UDim2.fromOffset(170, 58)
	g.StudsOffset = Vector3.new(0, 2.4, 0)
	g.MaxDistance = 60
	g.AlwaysOnTop = false
	g.LightInfluence = 0
	g.Adornee = head
	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.new(1, 0, 0, 36)
	bubble.BackgroundColor3 = Color3.fromRGB(28, 24, 30)
	bubble.BackgroundTransparency = 0.1
	bubble.Parent = g
	Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 12)
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -12, 1, -6)
	text.Position = UDim2.fromOffset(6, 3)
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Text = c.name
	text.Parent = bubble
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Position = UDim2.new(0.15, 0, 0, 42)
	barBg.Size = UDim2.new(0.7, 0, 0, 10)
	barBg.BackgroundColor3 = Color3.fromRGB(28, 24, 30)
	barBg.BackgroundTransparency = 0.2
	barBg.Parent = g
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(80, 210, 100)
	bar.Parent = barBg
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	g.Parent = c.model
	c.gui = g
end

local function updateGui(c: Customer)
	local g = c.gui
	if not g then
		return
	end
	local frac = math.clamp(c.patience / c.patienceMax, 0, 1)
	local bar = (g:FindFirstChild("BarBg") :: Frame):FindFirstChild("Bar") :: Frame
	bar.Size = UDim2.fromScale(frac, 1)
	bar.BackgroundColor3 = Color3.fromRGB(230, 60, 50):Lerp(Color3.fromRGB(80, 210, 100), frac)
	local text = (g:FindFirstChild("Bubble") :: Frame):FindFirstChild("Text") :: TextLabel
	if c.state == "queue" then
		local front = CustomerService.frontCustomer(c.plot)
		text.Text = if front == c then "💬 Ready to order!" else (frac < 0.35 and "😠 " or "🙂 ") .. c.name
	elseif c.state == "waiting" and c.order then
		text.Text = "🧾 #" .. c.order.number .. (frac < 0.35 and "  😠" or "  ⏳")
	elseif c.state == "collecting" or c.state == "leaving" then
		text.Text = c.order and c.order.done and "😋 Thanks!" or "😡 Too slow!"
		local barBg = g:FindFirstChild("BarBg") :: Frame
		barBg.Visible = false
	else
		text.Text = c.name
	end
end

------------------------------------------------------------------ movement

local function goTo(c: Customer, points: { Vector3 })
	c.path = points
end

local function runMovement(c: Customer)
	task.spawn(function()
		while c.alive and c.model.Parent do
			local target = c.path[1]
			if target then
				c.humanoid:MoveTo(target)
				local hrp = c.model.PrimaryPart :: BasePart
				local flat = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
				if flat.Magnitude < 1.6 then
					table.remove(c.path, 1)
					if #c.path == 0 and c.state == "leaving" then
						c.alive = false
						c.model:Destroy()
						return
					end
				end
			end
			task.wait(0.15)
		end
	end)
end

local function faceTowards(c: Customer, pos: Vector3?)
	if not pos then
		return
	end
	local hrp = c.model.PrimaryPart :: BasePart
	local look = Vector3.new(pos.X, hrp.Position.Y, pos.Z)
	if (look - hrp.Position).Magnitude > 0.1 then
		hrp.CFrame = CFrame.lookAt(hrp.Position, look)
	end
end

------------------------------------------------------------------ queue logic

local function reflowQueue(plot)
	for i, c in plot.queue do
		local q = node(plot, "Queue" .. i)
		if q and (c.state ~= "arriving" or (c :: any).atDoor) then
			local path = {}
			if c.state == "arriving" then
				for _, n in { "DoorInside", "Lobby" } do
					local p = node(plot, n)
					if p then
						table.insert(path, p)
					end
				end
				c.state = "queue"
			end
			table.insert(path, q)
			goTo(c, path)
		end
	end
end

local function freeWaitSlot(plot): number?
	local used = {}
	for _, c in plot.customers do
		if c.waitSlot then
			used[c.waitSlot] = true
		end
	end
	for i = 1, waitSlots(plot) do
		if not used[i] then
			return i
		end
	end
	return nil
end

local function leave(c: Customer)
	local plot = c.plot
	local qi = table.find(plot.queue, c)
	if qi then
		table.remove(plot.queue, qi)
		reflowQueue(plot)
	end
	if c.order then
		local oi = table.find(plot.orders, c.order)
		if oi and not c.order.done then
			table.remove(plot.orders, oi)
		end
	end
	c.waitSlot = nil
	c.state = "leaving"
	updateGui(c)
	local path = {}
	for _, n in { "Lobby", "DoorInside", "DoorOutside", "CustomerSpawn" } do
		local p = node(plot, n)
		if p then
			table.insert(path, p)
		end
	end
	goTo(c, path)
	local ci = table.find(plot.customers, c)
	if ci then
		table.remove(plot.customers, ci)
	end
	task.delay(40, function()
		if c.model.Parent then
			c.alive = false
			c.model:Destroy()
		end
	end)
end

local function updateScreens(plot)
	local model = plot.model
	if not model then
		return
	end
	for _, screen in model:GetDescendants() do
		if screen:IsA("SurfaceGui") and screen.Name == "OrderScreenGui" then
			local list = screen:FindFirstChild("List") :: Frame?
			if list then
				for _, ch in list:GetChildren() do
					if ch:IsA("Frame") then
						ch:Destroy()
					end
				end
				local empty = list:FindFirstChild("Empty") :: TextLabel?
				if empty then
					empty.Visible = #plot.orders == 0
				end
				for i, order in plot.orders do
					if i > 6 then
						break
					end
					local card = Instance.new("Frame")
					card.Name = "Order" .. order.number
					card.LayoutOrder = i
					card.Size = UDim2.new(0, 230, 1, -10)
					card.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
					card.Parent = list
					Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
					local head = Instance.new("TextLabel")
					head.Size = UDim2.new(1, -16, 0, 36)
					head.Position = UDim2.fromOffset(8, 6)
					head.BackgroundTransparency = 1
					head.Font = Enum.Font.GothamBlack
					head.TextXAlignment = Enum.TextXAlignment.Left
					head.TextColor3 = Color3.new(1, 1, 1)
					head.TextScaled = true
					head.Text = "#" .. order.number .. "  " .. order.customerName
					head.Parent = card
					for j, entry in order.items do
						local r = Recipes.get(entry.recipe)
						local row = Instance.new("TextLabel")
						row.Size = UDim2.new(1, -16, 0, 28)
						row.Position = UDim2.fromOffset(8, 46 + (j - 1) * 30)
						row.BackgroundTransparency = 1
						row.Font = Enum.Font.GothamBold
						row.TextXAlignment = Enum.TextXAlignment.Left
						row.TextScaled = true
						row.TextColor3 = if entry.done then Color3.fromRGB(90, 220, 120) else Color3.fromRGB(230, 230, 240)
						row.Text = (entry.done and "✓ " or "• ") .. (r and r.name or entry.recipe)
						row.Parent = card
					end
				end
			end
		end
	end
end
CustomerService.updateScreens = updateScreens

-- End of day: everyone still queueing or waiting leaves without a review.
function CustomerService.sendHomeAll(plot)
	local any = false
	for _, c in table.clone(plot.customers or {}) do
		if c.alive and (c.state == "arriving" or c.state == "queue" or c.state == "waiting") then
			any = true
			leave(c)
			local g = c.gui
			local bubble = g and g:FindFirstChild("Bubble")
			local text = bubble and bubble:FindFirstChild("Text") :: TextLabel?
			if text then
				text.Text = "👋 See you tomorrow!"
			end
		end
	end
	if any then
		plot.posCustomer = nil
		updateScreens(plot)
		if plot.owner then
			S.StationService.refreshPlot(plot)
			S.ProgressService.push(plot.owner)
		end
	end
end

------------------------------------------------------------------ spawning

local function spawnCustomer(plot)
	local spawnPos = node(plot, "CustomerSpawn")
	local outside = node(plot, "DoorOutside")
	if not spawnPos or not outside then
		return
	end
	nextId += 1
	local model = createNPC()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local personality = pick(PERSONALITIES)
	local want = buildWant(plot)
	if personality.extra and #want < GameConfig.MaxItemsPerOrder then
		table.insert(want, 1, buildWant(plot)[1])
	end
	local patience = rng:NextNumber(GameConfig.OrderPatience.min, GameConfig.OrderPatience.max) * personality.patience
	local c: Customer = {
		id = nextId,
		plot = plot,
		model = model,
		humanoid = humanoid,
		name = pick(NAMES),
		personality = personality,
		want = want,
		says = sayOrder(want),
		state = "arriving",
		patience = patience,
		patienceMax = patience,
		path = {},
		order = nil,
		waitSlot = nil,
		gui = nil,
		alive = true,
	}
	model.Name = "Customer_" .. c.name
	humanoid.WalkSpeed = GameConfig.WalkSpeed * rng:NextNumber(0.9, 1.15)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	model:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3, 0)))
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Customers"
		end
	end
	model.Parent = plot.npcFolder
	if model.PrimaryPart then
		pcall(function()
			(model.PrimaryPart :: BasePart):SetNetworkOwner(nil)
		end)
	end
	makeGui(c)
	setupAnimations(c)
	table.insert(plot.customers, c)
	table.insert(plot.queue, c)
	goTo(c, { outside })
	runMovement(c)
	-- once at the door, join the queue properly
	task.spawn(function()
		while c.alive and c.state == "arriving" do
			local hrp = c.model.PrimaryPart
			if hrp and (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(outside.X, 0, outside.Z)).Magnitude < 2.5 then
				(c :: any).atDoor = true
				reflowQueue(plot)
				break
			end
			task.wait(0.2)
		end
	end)
	updateGui(c)
	S.ProgressService.push(plot.owner)
	S.StationService.refreshPlot(plot)
end

local function spawnInterval(plot): number
	local owner = plot.owner
	local profile = S.DataService.get(owner)
	local traffic = 1 + S.UpgradeService.effect(owner, "traffic")
	local ratingFactor = ((profile.rating or 3) / 3) ^ 0.7
	local levelFactor = 1 + math.min(profile.level, 20) * 0.03
	local base = math.max(GameConfig.MinSpawnInterval, GameConfig.BaseSpawnInterval / (traffic * ratingFactor * levelFactor))
	-- lunch / dinner rush (ShiftService) can go below MinSpawnInterval, down to RushMinSpawnInterval
	local rush = S.ShiftService.traffic(plot)
	return if rush == 1 then base else math.max(DayCycleConfig.RushMinSpawnInterval, base / rush)
end

------------------------------------------------------------------ public

function CustomerService.frontCustomer(plot): Customer?
	local c = plot.queue and plot.queue[1]
	if not c or c.state ~= "queue" then
		return nil
	end
	local q1 = node(plot, "Queue1")
	local hrp = c.model.PrimaryPart
	if q1 and hrp and (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(q1.X, 0, q1.Z)).Magnitude < 3 then
		return c
	end
	return nil
end

function CustomerService.openPOS(player: Player, plot)
	local c = CustomerService.frontCustomer(plot)
	if not c then
		return S.ProgressService.notify(player, "Nobody is waiting to order", "info")
	end
	local profile = S.DataService.get(player)
	plot.posCustomer = c
	posEvent:FireClient(player, {
		customerName = c.name,
		personality = c.personality.label,
		says = c.says,
		menu = FoodLogic.unlockedRecipes(profile.level, profile.upgrades),
	})
end

function CustomerService.submitOrder(player: Player, recipeIds: any): (boolean, string)
	local plot = S.PlotService.get(player)
	if not plot or type(recipeIds) ~= "table" or #recipeIds == 0 or #recipeIds > 6 then
		return false, "Invalid order"
	end
	local c = CustomerService.frontCustomer(plot)
	if not c or plot.posCustomer ~= c then
		return false, "That customer is gone"
	end
	local clean = {}
	for _, id in recipeIds do
		if type(id) ~= "string" or not Recipes.get(id) then
			return false, "Invalid item"
		end
		table.insert(clean, id)
	end
	if not FoodLogic.setEquals(clean, c.want) then
		c.patience -= c.patienceMax * GameConfig.WrongOrderPatiencePenalty
		updateGui(c)
		S.ProgressService.sound(player, "Error")
		return false, "That's not what " .. c.name .. " asked for! Listen carefully."
	end
	local profile = S.DataService.get(player)
	profile.orderCounter += 1
	local number = ((profile.orderCounter - 1) % 99) + 1
	local price = 0
	local items = {}
	for _, id in clean do
		local r = Recipes.get(id) :: any
		price += r.price
		table.insert(items, { recipe = id, done = false })
	end
	local order = {
		number = number,
		customer = c,
		customerName = c.name,
		items = items,
		price = price,
		created = os.clock(),
		done = false,
	}
	plot.orders = plot.orders or {}
	table.insert(plot.orders, order)
	c.order = order
	plot.posCustomer = nil
	-- move to the waiting area
	local qi = table.find(plot.queue, c)
	if qi then
		table.remove(plot.queue, qi)
	end
	c.state = "waiting"
	local food = rng:NextNumber(GameConfig.FoodPatience.min, GameConfig.FoodPatience.max) * c.personality.patience
	c.patience = food
	c.patienceMax = food
	local slot = freeWaitSlot(plot)
	c.waitSlot = slot
	local dest = slot and node(plot, "Wait" .. slot) or node(plot, "Wait1")
	if dest then
		goTo(c, { dest })
	end
	reflowQueue(plot)
	updateGui(c)
	updateScreens(plot)
	S.ProgressService.addXP(player, 2)
	S.ProgressService.sound(player, "Register")
	S.ProgressService.push(player)
	S.StationService.refreshPlot(plot)
	return true, "Order #" .. number .. " sent to the kitchen"
end

local function completeOrder(player: Player, plot, order)
	order.done = true
	local c: Customer = order.customer
	local oi = table.find(plot.orders, order)
	if oi then
		table.remove(plot.orders, oi)
	end
	local profile = S.DataService.get(player)
	local frac = math.clamp(c.patience / c.patienceMax, 0, 1)
	local cleanliness = S.CleaningService.cleanliness(plot) / 100
	local tipFrac = GameConfig.MaxTipFraction * frac * c.personality.tip * (0.4 + 0.6 * cleanliness)
		+ S.UpgradeService.effect(player, "tip")
	local tip = math.floor(order.price * tipFrac * 100 + 0.5) / 100
	S.ProgressService.addMoney(player, order.price + tip, "order")
	S.ProgressService.addXP(player, 6)
	local stars = 1.5 + 3.5 * (0.35 + 0.65 * frac) * (0.5 + 0.5 * cleanliness)
	S.ProgressService.addReview(player, math.floor(stars + 0.5))
	profile.stats.served = (profile.stats.served or 0) + 1
	S.GoalService.record(player, "order", 1)
	S.GoalService.record(player, "earn", order.price + tip)
	if tip > 0 then
		S.GoalService.record(player, "tip", tip)
	end
	if frac >= GameConfig.HappyPatience then
		S.GoalService.record(player, "happy", 1)
	end
	S.ProgressService.notify(player, ("Order #%d complete! +$%.2f%s"):format(order.number, order.price + tip, tip > 0 and (" (tip $%.2f)"):format(tip) or ""), "good")
	S.ProgressService.sound(player, "Cash")
	-- walk to the counter, grab the bag, then leave
	c.state = "collecting"
	updateGui(c)
	local pickup = node(plot, "PickupSpot")
	if pickup then
		goTo(c, { pickup })
	end
	task.delay(2.5, function()
		if c.alive then
			leave(c)
			if rng:NextNumber() < GameConfig.TrashChance then
				S.CleaningService.spawnTrash(plot)
			end
		end
	end)
	updateScreens(plot)
end

function CustomerService.serve(player: Player, plot)
	local held = S.HeldService.get(player)
	if not held then
		return
	end
	local recipeId = FoodLogic.identify(held)
	if not recipeId then
		S.ProgressService.sound(player, "Error")
		return S.ProgressService.notify(player, "That doesn't match anything on the menu. Check the recipe book!", "bad")
	end
	for _, order in plot.orders or {} do
		for _, entry in order.items do
			if entry.recipe == recipeId and not entry.done then
				entry.done = true
				S.HeldService.take(player)
				local r = Recipes.get(recipeId) :: any
				S.ProgressService.addXP(player, r.xp)
				local profile = S.DataService.get(player)
				if r.kind == "pizza" then
					profile.stats.pizzas = (profile.stats.pizzas or 0) + 1
				elseif r.kind == "kebab" then
					profile.stats.kebabs = (profile.stats.kebabs or 0) + 1
				end
				S.ProgressService.sound(player, "Serve")
				S.GoalService.record(player, "serve_kind", 1, r.kind)
				S.GoalService.record(player, "serve_recipe", 1, recipeId)
				local all = true
				for _, e in order.items do
					if not e.done then
						all = false
					end
				end
				if all then
					completeOrder(player, plot, order)
				else
					updateScreens(plot)
				end
				S.ProgressService.push(player)
				return
			end
		end
	end
	local r = Recipes.get(recipeId)
	S.ProgressService.sound(player, "Error")
	S.ProgressService.notify(player, "No open order needs a " .. (r and r.name or recipeId), "bad")
end

function CustomerService.setOpen(plot, open: boolean)
	plot.open = open
	local sign = plot.model and plot.model:FindFirstChild("OpenSignLight", true)
	if sign and sign:IsA("BasePart") then
		sign.Color = if open then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(255, 70, 60)
		for _, d in sign:GetDescendants() do
			if d:IsA("TextLabel") then
				d.Text = if open then "OPEN" else "CLOSED"
			end
		end
	end
	if plot.owner then
		S.ProgressService.notify(plot.owner, open and "You're open! Customers are on their way." or "Closed. No new customers will come in.", open and "good" or "info")
		S.ProgressService.sound(plot.owner, "Bell")
		S.ProgressService.push(plot.owner)
	end
	S.ShiftService.onOpenChanged(plot, open) -- starts / closes the day
	S.StationService.refreshPlot(plot)
end

function CustomerService.setupPlot(plot)
	plot.customers = {}
	plot.queue = {}
	plot.orders = {}
	local folder = Instance.new("Folder")
	folder.Name = "Customers"
	folder.Parent = plot.model
	plot.npcFolder = folder
	local token = {}
	plot.customerToken = token
	-- spawn loop
	task.spawn(function()
		local timer = 4
		while plot.customerToken == token do
			task.wait(1)
			if plot.open and plot.owner then
				timer -= 1
				local waiting = 0
				for _, c in plot.customers do
					if c.state == "waiting" then
						waiting += 1
					end
				end
				if timer <= 0 and #plot.queue < maxQueue(plot) and waiting < waitSlots(plot) then
					timer = spawnInterval(plot) * rng:NextNumber(0.8, 1.2)
					task.spawn(spawnCustomer, plot)
				end
			end
		end
	end)
	-- patience loop
	task.spawn(function()
		while plot.customerToken == token do
			task.wait(0.5)
			local changed = false
			for _, c in table.clone(plot.customers) do
				if c.alive and (c.state == "queue" or c.state == "waiting") then
					local rate = if c.state == "queue" and CustomerService.frontCustomer(plot) ~= c then 0.6 else 1
					c.patience -= 0.5 * rate
					if c.state == "queue" and CustomerService.frontCustomer(plot) == c then
						faceTowards(c, node(plot, "RegisterLook"))
					elseif c.state == "waiting" and #c.path == 0 then
						faceTowards(c, node(plot, "PickupSpot"))
					end
					if c.patience <= 0 then
						local owner = plot.owner
						if owner then
							local profile = S.DataService.get(owner)
							profile.stats.angry = (profile.stats.angry or 0) + 1
							S.ProgressService.addReview(owner, GameConfig.AngryRatingStars)
							S.GoalService.record(owner, "angry", 1)
							S.ProgressService.notify(owner, c.name .. " got fed up and left! ⭐ rating dropped.", "bad")
							S.ProgressService.sound(owner, "Angry")
						end
						leave(c)
						changed = true
					end
					updateGui(c)
				end
			end
			if changed then
				updateScreens(plot)
				if plot.owner then
					S.StationService.refreshPlot(plot)
				end
			end
			if plot.owner then
				S.ProgressService.push(plot.owner)
			end
		end
	end)
	updateScreens(plot)
end

function CustomerService.cleanupPlot(plot)
	plot.customerToken = nil
	for _, c in plot.customers or {} do
		c.alive = false
		if c.model then
			c.model:Destroy()
		end
	end
	plot.customers = {}
	plot.queue = {}
	plot.orders = {}
end

function CustomerService.start()
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Customers")
		PhysicsService:CollisionGroupSetCollidable("Customers", "Customers", false)
	end)
	Net.func("SubmitOrder").OnServerInvoke = function(player, ids)
		local ok, msg = CustomerService.submitOrder(player, ids)
		return ok, msg
	end
	Net.func("CancelPOS").OnServerInvoke = function(player)
		local plot = S.PlotService.get(player)
		if plot then
			plot.posCustomer = nil
		end
		return true
	end
	Net.func("ToggleOpen").OnServerInvoke = function(player)
		local plot = S.PlotService.get(player)
		if not plot then
			return false, "No restaurant"
		end
		CustomerService.setOpen(plot, not plot.open)
		return true, plot.open and "Open" or "Closed"
	end
	S.ProgressService.addStateProvider(function(player)
		local plot = S.PlotService.get(player)
		if not plot then
			return {}
		end
		local orders = {}
		for _, o in plot.orders or {} do
			local c = o.customer
			table.insert(orders, {
				number = o.number,
				customerName = o.customerName,
				items = o.items,
				price = o.price,
				patience = c and math.clamp(c.patience / c.patienceMax, 0, 1) or 0,
			})
		end
		return {
			orders = orders,
			queue = #(plot.queue or {}),
			open = plot.open,
			cleanliness = S.CleaningService.cleanliness(plot),
		}
	end)
end

return CustomerService
