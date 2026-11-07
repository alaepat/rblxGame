--!strict
-- Phone / tablet scaling (TASKS #12).
--
-- The UI is laid out in desktop pixels. `Responsive.apply(gui, design)` moves
-- the ScreenGui's children (and any added later) into a "Root" frame with a
-- UIScale, sized so it still covers the whole screen. When the screen is
-- smaller than `design`, everything shrinks evenly to fit; on desktop the scale
-- stays 1, so nothing changes there.
--
-- Studio preview without the device emulator:
--   workspace:SetAttribute("PP_EmulateScreen", Vector2.new(844, 390))  -- phone, landscape
--   workspace:SetAttribute("PP_EmulateScreen", nil)                    -- back to normal
-- The UI is then laid out for that screen size, centred in the real window.

local Responsive = {}

Responsive.MIN_SCALE = 0.55

-- Design sizes (the smallest screen each layout fits at scale 1).
Responsive.WINDOW = Vector2.new(1000, 470) -- office PC, POS (fill the screen when compact, see fit)
Responsive.HUD = Vector2.new(900, 440) -- pills, buttons, day clock, goals
Responsive.POPUP = Vector2.new(900, 560) -- toasts, level-up window

-- Pure: the scale for a screen, never above 1 or below MIN_SCALE.
function Responsive.scaleFor(screen: Vector2, design: Vector2): number
	if screen.X <= 0 or screen.Y <= 0 then
		return 1
	end
	local s = math.min(screen.X / design.X, screen.Y / design.Y, 1)
	return math.max(s, Responsive.MIN_SCALE)
end

function Responsive.apply(gui: ScreenGui, design: Vector2): Frame?
	-- offline tests (Lune) have no workspace or Instance signals: leave the gui as built
	if typeof(workspace) ~= "Instance" then
		return nil
	end
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	local function update()
		local emu = workspace:GetAttribute("PP_EmulateScreen")
		local screen: Vector2 = if typeof(emu) == "Vector2" then emu else gui.AbsoluteSize
		if screen.X <= 0 then
			return
		end
		local s = Responsive.scaleFor(screen, design)
		uiScale.Scale = s
		-- in Root's own (unscaled) units the visible area is screen / s
		root.Size = UDim2.fromOffset(screen.X / s, screen.Y / s)
		root:SetAttribute("Scale", s)
	end

	for _, ch in gui:GetChildren() do
		if ch:IsA("GuiObject") then
			ch.Parent = root
		end
	end
	root.Parent = gui
	gui.ChildAdded:Connect(function(ch)
		if ch ~= root and ch:IsA("GuiObject") then
			task.defer(function()
				if ch.Parent == gui then
					ch.Parent = root
				end
			end)
		end
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	workspace:GetAttributeChangedSignal("PP_EmulateScreen"):Connect(update)
	update()
	return root
end

-- Windows: `normal` size on big screens, `compact` (usually near full-screen)
-- whenever the UI is scaled down, so phones get every pixel.
function Responsive.fit(root: Frame?, obj: GuiObject, normal: UDim2, compact: UDim2)
	if not root then
		obj.Size = normal
		return
	end
	local function update()
		local s = root:GetAttribute("Scale")
		obj.Size = if type(s) == "number" and s < 1 then compact else normal
	end
	root:GetAttributeChangedSignal("Scale"):Connect(update)
	update()
end

-- True on phones / tablets (touch, no mouse).
function Responsive.isTouch(): boolean
	local UIS = game:GetService("UserInputService")
	return UIS.TouchEnabled and not UIS.MouseEnabled
end

return Responsive
