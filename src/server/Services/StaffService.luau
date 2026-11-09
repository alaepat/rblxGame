--!strict
-- Staff NPCs (TASKS #11), server authoritative.
--  * Staff are hired through upgrades with a `staff` field (Config/Upgrades:
--    hire_cleaner, hire_cashier). Each tick this service makes the staff NPCs
--    in a restaurant match what the owner has hired.
--  * Cashier: stands behind the register. When a customer has waited
--    Config.Staff.Roles.cashier.orderDelay seconds at the register and no
--    player has the POS open for them, the cashier takes exactly what they
--    asked for through CustomerService.submitOrder (same path as the POS).
--  * Cleaner: walks to the nearest rubbish or messy prep counter (Roblox
--    pathfinding, stepping straight there if no path is found in time),
--    cleans it through CleaningService.removeTrash / wipeCounter (no XP for
--    the owner: staff did it), then goes back to their spot.
--  * Wages: ShiftService.staffOf reads the same hires, and the end-of-day
--    summary charges Config/DayCycle.Wages.
--  * Per-plot state lives in plot.staff (PlotService.release clears it; the
--    NPCs are inside plot.model, so they go when the restaurant does).

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StaffRules = require(Shared.Staff.StaffRules)

local Config = StaffRules.Config

local StaffService = {}
local S: any

local TICK = 0.5
local WALK_ANIM = "rbxassetid://507777826"
local IDLE_ANIM = "rbxassetid://507766388"
-- Where staff stand, in the restaurant's local studs (see RestaurantBuilder
-- buildNodes / the register at x = -2, z ~6). The cleaner rests by the gap
-- in the front counter, next to the player spawn.
local CASHIER_SPOT = Vector3.new(-2, 3, 4.2)
local CASHIER_FACE = Vector3.new(-2, 3, 12)
local CLEANER_SPOT = Vector3.new(13.5, 3, 10.5)

function StaffService.init(services)
	S = services
end

-- Replaceable clock (tests move it).
StaffService.clock = os.clock

export type NPC = { role: string, model: Model, humanoid: Humanoid?, root: BasePart?, bubble: TextLabel? }

------------------------------------------------------------------ NPC model

local function makeDescription(role: string): HumanoidDescription
	local r = Config.Roles[role]
	local skins = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100), Color3.fromRGB(150, 100, 70), Color3.fromRGB(105, 70, 50) }
	local skin = skins[math.random(1, #skins)]
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = skin
	d.TorsoColor = r.shirt
	d.LeftArmColor = skin
	d.RightArmColor = skin
	d.LeftLegColor = Color3.fromRGB(30, 30, 35)
	d.RightLegColor = Color3.fromRGB(30, 30, 35)
	return d
end

local function fallbackModel(role: string): Model
	local m = Instance.new("Model")
	local function p(name: string, size: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.Parent = m
		return part
	end
	local hrp = p("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(1, 1, 1))
	hrp.Transparency = 1
	local torso = p("Torso", Vector3.new(2, 2, 1), Config.Roles[role].shirt)
	local head = p("Head", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(234, 184, 146))
	head.Shape = Enum.PartType.Ball
	local legs = p("Legs", Vector3.new(2, 2, 1), Color3.fromRGB(30, 30, 35))
	head.CFrame = hrp.CFrame * CFrame.new(0, 1.6, 0)
	legs.CFrame = hrp.CFrame * CFrame.new(0, -2, 0)
	for _, part in { torso, head, legs } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = part
		w.Parent = part
	end
	local h = Instance.new("Humanoid")
	h.HipHeight = 3
	h.Parent = m
	m.PrimaryPart = hrp
	return m
end

local function nameTag(model: Model, role: string): TextLabel?
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local r = Config.Roles[role]
	local gui = Instance.new("BillboardGui")
	gui.Name = "StaffTag"
	gui.Size = UDim2.fromOffset(140, 44)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = false
	gui.Parent = head
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(1, 0, 0, 22)
	tag.BackgroundColor3 = Color3.fromRGB(26, 22, 30)
	tag.BackgroundTransparency = 0.15
	tag.TextColor3 = Color3.new(1, 1, 1)
	tag.Font = Enum.Font.GothamBold
	tag.TextSize = 14
	tag.Text = r.icon .. " " .. r.name
	tag.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 11)
	corner.Parent = tag
	local bubble = Instance.new("TextLabel")
	bubble.Name = "Bubble"
	bubble.Position = UDim2.fromOffset(0, 24)
	bubble.Size = UDim2.new(1, 0, 0, 18)
	bubble.BackgroundTransparency = 1
	bubble.TextColor3 = Color3.fromRGB(255, 230, 150)
	bubble.TextStrokeTransparency = 0.4
	bubble.Font = Enum.Font.GothamBold
	bubble.TextSize = 13
	bubble.Text = ""
	bubble.Parent = gui
	return bubble
end

local function animate(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local okI, idle = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = IDLE_ANIM
		return animator:LoadAnimation(a)
	end)
	if okI then
		idle.Looped = true
		idle:Play()
	end
	local okW, walk = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = WALK_ANIM
		return animator:LoadAnimation(a)
	end)
	if okW then
		walk.Looped = true
		humanoid.Running:Connect(function(speed)
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

-- Builds a staff NPC standing at `cf` inside `parent`. Replaceable in tests.
function StaffService.makeNPC(role: string, parent: Instance, cf: CFrame): NPC
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(makeDescription(role), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[StaffService] avatar creation failed, using fallback:", model)
		model = fallbackModel(role)
	end
	local animateScript = model:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end
	model.Name = "Staff_" .. role
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
		humanoid.WalkSpeed = Config.Roles[role].walkSpeed or 10
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Customers" -- NPCs don't bump into each other
		end
	end
	model:PivotTo(cf)
	local root = model.PrimaryPart
	if role == "cashier" and root then
		root.Anchored = true -- the cashier stays put behind the register
	end
	model.Parent = parent
	if root and not root.Anchored then
		pcall(function()
			(root :: BasePart):SetNetworkOwner(nil)
		end)
	end
	if humanoid then
		animate(humanoid)
	end
	return { role = role, model = model, humanoid = humanoid, root = root, bubble = nameTag(model, role) }
end

------------------------------------------------------------------ helpers

local function world(plot, localPos: Vector3): Vector3
	return (plot.origin :: CFrame):PointToWorldSpace(localPos)
end

local function homeCFrame(plot, role: string): CFrame
	if role == "cashier" then
		return CFrame.lookAt(world(plot, CASHIER_SPOT), world(plot, CASHIER_FACE))
	end
	return CFrame.new(world(plot, CLEANER_SPOT))
end

local function say(npc: NPC, text: string)
	if npc.bubble then
		npc.bubble.Text = text
	end
end

local function stateOf(plot)
	if not plot.staff then
		plot.staff = { npcs = {}, memo = { customer = nil, since = 0 }, busy = false }
	end
	return plot.staff
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Is this NPC still the one working in this plot?
local function current(plot, staff, npc: NPC): boolean
	return plot.staff == staff and staff.npcs[npc.role] == npc and npc.model.Parent ~= nil
end

------------------------------------------------------------------ hiring

-- Spawns / removes NPCs so the plot matches the owner's hires.
function StaffService.sync(plot)
	local owner = plot.owner
	local profile = owner and S.DataService.get(owner)
	if not profile or not plot.model then
		return
	end
	local staff = stateOf(plot)
	local hired = StaffRules.hired(profile.upgrades)
	for role in Config.Roles do
		local npc = staff.npcs[role]
		if (hired[role] or 0) > 0 and not npc then
			staff.npcs[role] = StaffService.makeNPC(role, plot.model, homeCFrame(plot, role))
		elseif (hired[role] or 0) == 0 and npc then
			npc.model:Destroy()
			staff.npcs[role] = nil
		end
	end
end

------------------------------------------------------------------ cashier

function StaffService.cashierStep(plot)
	local staff = plot.staff
	local npc = staff and staff.npcs.cashier
	local owner = plot.owner
	if not npc or not owner then
		return
	end
	local front = S.CustomerService.frontCustomer(plot)
	local delay = Config.Roles.cashier.orderDelay
	if not StaffRules.cashierStep(staff.memo, front, plot.posCustomer, StaffService.clock(), delay) then
		say(npc, if front and plot.posCustomer ~= front then "Hi! What can I get you?" else "")
		return
	end
	staff.memo.customer = nil
	plot.posCustomer = front
	local ok, msg = S.CustomerService.submitOrder(owner, table.clone(front.want))
	if ok then
		S.ProgressService.notify(owner, "🧾 Cashier: " .. tostring(msg), "info")
		say(npc, "Order in!")
	elseif plot.posCustomer == front then
		plot.posCustomer = nil
	end
end

------------------------------------------------------------------ cleaner

-- Messes the cleaner can deal with, each with a `position`.
function StaffService.jobs(plot): { any }
	local jobs = {}
	for _, m in plot.trash or {} do
		if m.Parent then
			table.insert(jobs, { kind = "trash", ref = m, position = m:GetPivot().Position })
		end
	end
	for _, st in plot.stations or {} do
		if st.dirty and st.part then
			table.insert(jobs, { kind = "counter", ref = st, position = st.part.Position })
		end
	end
	return jobs
end

-- Floor-level points to walk to for a job (several for counters: one per side).
local function standPoints(plot, job): { Vector3 }
	local floorY = world(plot, Vector3.new(0, 3, 0)).Y
	if job.kind == "trash" then
		local p = job.position
		return { Vector3.new(p.X, floorY, p.Z) }
	end
	local part: BasePart = job.ref.part
	local cf = part.CFrame
	local out = {}
	for _, dir in { cf.LookVector, -cf.LookVector, cf.RightVector, -cf.RightVector } do
		local reach = math.abs(dir:Dot(cf.LookVector)) * part.Size.Z / 2 + math.abs(dir:Dot(cf.RightVector)) * part.Size.X / 2 + 2
		local p = part.Position + dir * reach
		table.insert(out, Vector3.new(p.X, floorY, p.Z))
	end
	return out
end

-- Walks along a computed path. Returns false if there's no path or it times out.
function StaffService.walkPath(plot, staff, npc: NPC, goal: Vector3, timeout: number): boolean
	local humanoid, root = npc.humanoid, npc.root
	if not humanoid or not root then
		return false
	end
	local PathfindingService = game:GetService("PathfindingService")
	local ok, path = pcall(function()
		local p = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = false })
		p:ComputeAsync(root.Position, goal)
		return p
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return false
	end
	local started = StaffService.clock()
	for _, wp in path:GetWaypoints() do
		humanoid:MoveTo(wp.Position)
		while current(plot, staff, npc) and flat(root.Position, wp.Position) > 2 do
			if StaffService.clock() - started > timeout then
				return false
			end
			task.wait(0.1)
		end
		if not current(plot, staff, npc) then
			return false
		end
	end
	return flat(root.Position, goal) <= 3
end

-- Gets the NPC to one of `points`, stepping straight to the first if no path works.
local function goTo(plot, staff, npc: NPC, points: { Vector3 })
	local timeout = Config.Roles.cleaner.walkTimeout
	for _, p in points do
		if StaffService.walkPath(plot, staff, npc, p, timeout) then
			return
		end
		if not current(plot, staff, npc) then
			return
		end
	end
	if points[1] and npc.root then
		npc.model:PivotTo(CFrame.new(points[1]) * (npc.root.CFrame - npc.root.Position))
	end
end

local function stillThere(plot, job): boolean
	if job.kind == "trash" then
		return table.find(plot.trash or {}, job.ref) ~= nil
	end
	return job.ref.dirty == true
end

-- Cleans one job (walk, clean, done). Runs in its own thread.
function StaffService.doJob(plot, staff, npc: NPC, job)
	say(npc, "On my way!")
	goTo(plot, staff, npc, standPoints(plot, job))
	if current(plot, staff, npc) and stillThere(plot, job) then
		say(npc, "🧹 Cleaning...")
		task.wait(Config.Roles.cleaner.cleanTime)
		if current(plot, staff, npc) then
			if job.kind == "trash" then
				S.CleaningService.removeTrash(plot, job.ref, nil)
			else
				S.CleaningService.wipeCounter(job.ref, nil)
			end
		end
	end
	if not current(plot, staff, npc) then
		return
	end
	say(npc, "")
	-- nothing else to do: head back to the spot by the counter
	if #StaffService.jobs(plot) == 0 then
		goTo(plot, staff, npc, { homeCFrame(plot, "cleaner").Position })
	end
	staff.busy = false
end

function StaffService.cleanerStep(plot)
	local staff = plot.staff
	local npc = staff and staff.npcs.cleaner
	if not npc or staff.busy or not npc.root then
		return
	end
	local job = StaffRules.nearest(StaffService.jobs(plot), npc.root.Position)
	if not job then
		return
	end
	staff.busy = true
	task.spawn(function()
		local ok, err = pcall(StaffService.doJob, plot, staff, npc, job)
		if not ok then
			warn("[StaffService] cleaner job failed: " .. tostring(err))
		end
		if plot.staff == staff then
			staff.busy = false
		end
	end)
end

------------------------------------------------------------------ loop

function StaffService.tick(plot)
	if not plot.owner or not plot.model then
		return
	end
	StaffService.sync(plot)
	StaffService.cashierStep(plot)
	StaffService.cleanerStep(plot)
end

function StaffService.start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, plot in S.PlotService.Plots do
				local ok, err = pcall(StaffService.tick, plot)
				if not ok then
					warn("[StaffService] tick failed: " .. tostring(err))
				end
			end
		end
	end)
end

return StaffService
