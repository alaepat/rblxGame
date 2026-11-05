--!strict
-- Aim-to-interact. Every gameplay ProximityPrompt uses Style = Custom; this
-- controller raycasts from the cursor (or screen centre in first person / on
-- mobile) to find the object you are looking at, outlines it, shows its
-- actions next to the cursor and triggers them with E / F / R, left click or tap.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Parent.UI.Theme)
local T = Theme.make
local Col = Theme.Colors

local Interaction = {}
Interaction.blocked = false -- set true while a modal UI is open

local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local title: TextLabel
local rows: Frame
local crosshair: Frame
local highlight: Highlight
local current: { ProximityPrompt } = {}
local currentTarget: Instance? = nil
local holding: ProximityPrompt? = nil

local ORDER = { Prompt_main = 1, Prompt_wrap = 2, Prompt_chips = 3 }

local function keyName(k: Enum.KeyCode): string
	return string.upper(string.sub(tostring(k), 14))
end

local function build()
	gui = T("ScreenGui", { Name = "Interaction", ResetOnSpawn = false, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
	crosshair = T("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		Visible = false,
	}, { Theme.corner(4), Theme.stroke(Color3.new(0, 0, 0), 1, 0.5) })
	panel = T("Frame", {
		Parent = gui,
		Size = UDim2.fromOffset(240, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
	}, { Theme.list(Enum.FillDirection.Vertical, 4) })
	local head = T("Frame", {
		Parent = panel,
		LayoutOrder = 0,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Col.Pill,
		BackgroundTransparency = 0.1,
	}, { Theme.corner(15), Theme.pad(4, 12) })
	title = Theme.text({ Parent = head, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = "", Font = Theme.FontBlack, TextSize = 16 })
	rows = T("Frame", { Parent = panel, LayoutOrder = 1, Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, { Theme.list(Enum.FillDirection.Vertical, 4) })
	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(235, 225, 255)
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = gui
end

local function promptsOn(inst: Instance): { ProximityPrompt }
	local out = {}
	for _, ch in inst:GetChildren() do
		if ch:IsA("ProximityPrompt") then
			table.insert(out, ch)
		elseif ch:IsA("Attachment") then
			for _, p in ch:GetChildren() do
				if p:IsA("ProximityPrompt") then
					table.insert(out, p)
				end
			end
		end
	end
	return out
end

local function findPrompts(hit: BasePart): (Instance?, { ProximityPrompt })
	local node: Instance? = hit
	for _ = 1, 3 do
		if not node or node == workspace then
			break
		end
		local list = promptsOn(node)
		if #list > 0 then
			return node, list
		end
		node = node.Parent
	end
	return nil, {}
end

-- Prompts inside another player's restaurant are skipped. The server would
-- reject them anyway, but drawing them is confusing. Restaurant models carry
-- an OwnerUserId attribute (PlotService.claim).
local function ownedByOther(inst: Instance): boolean
	local node: Instance? = inst
	while node and node ~= workspace do
		local owner = node:GetAttribute("OwnerUserId")
		if owner ~= nil then
			return owner ~= player.UserId
		end
		node = node.Parent
	end
	return false
end
Interaction.ownedByOther = ownedByOther

local function usable(p: ProximityPrompt, root: BasePart): boolean
	if not p.Enabled or ownedByOther(p) then
		return false
	end
	local parent = p.Parent
	local pos: Vector3? = nil
	if parent and parent:IsA("BasePart") then
		pos = parent.Position
	elseif parent and parent:IsA("Attachment") then
		pos = parent.WorldPosition
	end
	return pos ~= nil and (pos - root.Position).Magnitude <= p.MaxActivationDistance + 1.5
end

local function aimPoint(): Vector2
	local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	local cam = workspace.CurrentCamera
	if locked or UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return cam.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation() -- viewport coordinates
end

local function raycastAt(screenPos: Vector2): RaycastResult?
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(ray.Origin, ray.Direction * 40, params)
end

local lastSig = ""
local lastTargetRef: Instance? = nil
local function render(target: Instance?, list: { ProximityPrompt }, screenPos: Vector2)
	local sig = ""
	if target then
		sig = tostring(target)
		for _, p in list do
			sig ..= "|" .. p.Name .. p.ActionText
		end
	end
	if sig == lastSig and target == lastTargetRef then
		if panel.Visible then
			panel.Position = UDim2.fromOffset(screenPos.X + 22, screenPos.Y - 16)
		end
		return
	end
	lastSig = sig
	lastTargetRef = target
	for _, ch in rows:GetChildren() do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	if not target or #list == 0 then
		panel.Visible = false
		highlight.Enabled = false
		return
	end
	table.sort(list, function(a, b)
		return (ORDER[a.Name] or 9) < (ORDER[b.Name] or 9)
	end)
	panel.Visible = true
	panel.Position = UDim2.fromOffset(screenPos.X + 22, screenPos.Y - 16)
	title.Text = list[1].ObjectText
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	for i, p in list do
		local row = T("TextButton", {
			Parent = rows,
			LayoutOrder = i,
			AutoButtonColor = touch,
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Col.Pill,
			BackgroundTransparency = 0.18,
			Text = "",
		}, { Theme.corner(14), Theme.pad(3, 6), Theme.list(Enum.FillDirection.Horizontal, 8) })
		local keyTag = T("Frame", { Parent = row, LayoutOrder = 1, Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Col.Yellow }, { Theme.corner(6) })
		Theme.text({ Parent = keyTag, Size = UDim2.fromScale(1, 1), Text = touch and "👆" or keyName(p.KeyboardKeyCode), Font = Theme.FontBlack, TextSize = 13, TextColor3 = Col.Ink, TextXAlignment = Enum.TextXAlignment.Center })
		Theme.text({ Parent = row, LayoutOrder = 2, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = p.ActionText .. (p.HoldDuration > 0 and "  (hold)" or ""), TextSize = 14 })
		row.Activated:Connect(function()
			if touch then
				p:InputHoldBegin()
				task.delay(p.HoldDuration + 0.05, function()
					p:InputHoldEnd()
				end)
			end
		end)
	end
	-- outline: prefer the visible model around an invisible hitbox
	local adornee: Instance = target
	if target:IsA("BasePart") and target.Transparency >= 0.95 and target.Parent and target.Parent:IsA("Model") then
		adornee = target.Parent
	end
	highlight.Adornee = adornee
	highlight.Enabled = true
end

local function step()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	crosshair.Visible = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	if Interaction.blocked or not root then
		current = {}
		currentTarget = nil
		render(nil, {}, Vector2.zero)
		return
	end
	local pos = aimPoint()
	local result = raycastAt(pos)
	local target: Instance? = nil
	local list: { ProximityPrompt } = {}
	if result and result.Instance then
		local t, all = findPrompts(result.Instance)
		for _, p in all do
			if usable(p, root) then
				table.insert(list, p)
			end
		end
		if #list > 0 then
			target = t
		end
	end
	current = list
	currentTarget = target
	local inset = GuiService:GetGuiInset()
	render(target, list, pos - Vector2.new(0, inset.Y))
end

local function promptForKey(key: Enum.KeyCode): ProximityPrompt?
	for _, p in current do
		if p.KeyboardKeyCode == key then
			return p
		end
	end
	return nil
end

function Interaction.start()
	build()
	RunService.RenderStepped:Connect(step)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or Interaction.blocked then
			return
		end
		local p: ProximityPrompt? = nil
		if input.UserInputType == Enum.UserInputType.Keyboard then
			p = promptForKey(input.KeyCode)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			p = current[1]
		elseif input.KeyCode == Enum.KeyCode.ButtonX then
			p = current[1]
		end
		if p then
			holding = p
			p:InputHoldBegin()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if holding and (input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonX) then
			holding:InputHoldEnd()
			holding = nil
		end
	end)
end

return Interaction
