--!strict
-- Daily goals panel: a "Goals" button under the recipe book (with a badge
-- counting claimable rewards) that opens a card list of today's goals, the
-- streak, the all-goals bonus and the time until new goals.
-- Data comes from the server snapshot (`goals`, built by DailyGoals.view);
-- claiming goes through the ClaimGoal remote, which validates everything.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local Notifications = require(script.Parent.Notifications)
local Sounds = require(script.Parent.Sounds)
local T = Theme.make
local Col = Theme.Colors

local Goals = {}

local gui: ScreenGui
local button: TextButton
local badge: Frame
local badgeText: TextLabel
local panel: Frame
local list: Frame
local resetLabel: TextLabel
local lastSig = ""
local claiming = false

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	if h > 0 then
		return ("%dh %02dm"):format(h, m)
	end
	return ("%dm %02ds"):format(m, seconds % 60)
end

local function claim(which: number | string)
	if claiming then
		return
	end
	claiming = true
	local ok, res, msg = pcall(function()
		return Net.func("ClaimGoal"):InvokeServer(which)
	end)
	claiming = false
	if not ok then
		Notifications.toast("Couldn't reach the server. Try again.", "bad")
	elseif res then
		Notifications.toast(tostring(msg), "good")
	else
		Sounds.play("Error")
		Notifications.toast(tostring(msg), "bad")
	end
end

local function claimable(view: any): number
	local n = 0
	for _, g in view.goals or {} do
		if g.done and not g.claimed then
			n += 1
		end
	end
	if view.bonus and view.bonus.ready then
		n += 1
	end
	return n
end

local function rewardText(cash: number, xp: number): string
	return ("💰 %s   ✨ %d XP"):format(Theme.money(cash), xp)
end

local function goalCard(g: any, order: number)
	local card = T("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundColor3 = g.claimed and Color3.fromRGB(236, 246, 236) or Col.Paper,
	}, { Theme.corner(12), Theme.stroke(g.done and Col.Green or Col.Line, g.done and 2 or 1) })
	Theme.text({
		Parent = card,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(34, 34),
		Text = g.icon,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Theme.text({
		Parent = card,
		Position = UDim2.fromOffset(50, 6),
		Size = UDim2.new(1, -150, 0, 38),
		Text = g.text,
		TextColor3 = Col.Ink,
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local barBg = T("Frame", {
		Parent = card,
		Position = UDim2.fromOffset(50, 48),
		Size = UDim2.new(1, -150, 0, 10),
		BackgroundColor3 = Col.Line,
	}, { Theme.corner(5) })
	local frac = if g.target > 0 then math.clamp(g.progress / g.target, 0, 1) else 0
	T("Frame", {
		Parent = barBg,
		Size = UDim2.fromScale(frac, 1),
		BackgroundColor3 = g.done and Col.Green or Col.Yellow,
	}, { Theme.corner(5) })
	Theme.text({
		Parent = card,
		Position = UDim2.fromOffset(50, 62),
		Size = UDim2.new(1, -150, 0, 18),
		Text = g.progressText .. "    " .. rewardText(g.cash, g.xp),
		TextColor3 = Col.InkSoft,
		TextSize = 12,
	})
	local btnProps = {
		Parent = card,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(84, 36),
		TextSize = 14,
	}
	if g.claimed then
		btnProps.BackgroundColor3 = Color3.fromRGB(210, 230, 210)
		btnProps.TextColor3 = Col.GreenDark
		btnProps.Text = "✓ Done"
		btnProps.AutoButtonColor = false
		Theme.button(btnProps, function() end)
	elseif g.done then
		btnProps.BackgroundColor3 = Col.Green
		btnProps.Text = "Claim"
		local b = Theme.button(btnProps, function()
			claim(g.index)
		end)
		-- gentle pulse so finished goals stand out
		TweenService:Create(b, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			BackgroundColor3 = Col.GreenDark,
		}):Play()
	else
		btnProps.BackgroundColor3 = Color3.fromRGB(240, 236, 230)
		btnProps.TextColor3 = Col.InkSoft
		btnProps.Text = ("%d%%"):format(math.floor(frac * 100))
		btnProps.AutoButtonColor = false
		Theme.button(btnProps, function() end)
	end
end

local function bonusCard(view: any, order: number)
	local b = view.bonus
	local card = T("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = Color3.fromRGB(255, 244, 220),
	}, { Theme.corner(12), Theme.stroke(b.ready and Col.Yellow or Col.Line, b.ready and 2 or 1) })
	local streakText = if view.streak > 0
		then ("🔥 %d-day streak"):format(view.streak)
		else "🔥 No streak yet"
	if (view.bestStreak or 0) > 1 then
		streakText ..= ("   (best %d)"):format(view.bestStreak)
	end
	Theme.text({
		Parent = card,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 24),
		Text = streakText,
		Font = Theme.FontBlack,
		TextColor3 = Color3.fromRGB(210, 90, 20),
		TextSize = 16,
	})
	local line: string
	if b.claimed then
		line = "Bonus collected. Come back tomorrow to keep the streak!"
	else
		line = ("Finish every goal: %s"):format(rewardText(b.cash, b.xp))
		if b.multiplier > 1 then
			line ..= ("  (×%.2f streak)"):format(b.multiplier)
		end
	end
	Theme.text({
		Parent = card,
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 18),
		Text = line,
		TextColor3 = Col.Ink,
		TextSize = 12,
		TextWrapped = true,
	})
	if b.ready then
		local btn = Theme.button({
			Parent = card,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -24, 0, 30),
			BackgroundColor3 = Col.Yellow,
			TextColor3 = Col.Ink,
			Text = ("🎁 Claim bonus (day %d)"):format(b.streakAfter),
			TextSize = 14,
		}, function()
			claim("bonus")
		end)
		TweenService:Create(btn, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			BackgroundColor3 = Color3.fromRGB(255, 160, 30),
		}):Play()
	else
		Theme.text({
			Parent = card,
			Position = UDim2.fromOffset(12, 56),
			Size = UDim2.new(1, -24, 0, 28),
			Text = if b.claimed
				then "✓ All done for today"
				else "Claim all goals above to unlock the bonus.",
			TextColor3 = Col.InkSoft,
			TextSize = 12,
			TextWrapped = true,
		})
	end
end

local function signature(view: any): string
	local parts = { tostring(view.streak), tostring(view.bonus and view.bonus.ready), tostring(view.bonus and view.bonus.claimed), tostring(view.resetsAt) }
	for _, g in view.goals or {} do
		table.insert(parts, g.text .. ":" .. tostring(g.progress) .. ":" .. tostring(g.claimed))
	end
	return table.concat(parts, "|")
end

local function render(force: boolean?)
	local view = State.get("goals")
	if not view then
		button.Visible = false
		panel.Visible = false
		return
	end
	button.Visible = true
	local n = claimable(view)
	badge.Visible = n > 0
	badgeText.Text = tostring(n)
	if not panel.Visible then
		lastSig = ""
		return
	end
	local sig = signature(view)
	if sig == lastSig and not force then
		return
	end
	lastSig = sig
	for _, ch in list:GetChildren() do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	for i, g in view.goals do
		goalCard(g, i)
	end
	bonusCard(view, 100)
end

local function setOpen(open: boolean)
	panel.Visible = open
	Sounds.play("Click")
	render(true)
end

local function build()
	gui = T("ScreenGui", {
		Name = "Goals",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 2,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- Under the HUD's recipe book button (which sits at y = 70, 40 tall).
	button = Theme.button({
		Parent = gui,
		Name = "GoalsButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 118),
		Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = Col.Purple,
		Text = "🎯 Goals",
		TextSize = 16,
		Visible = false,
	}, function()
		setOpen(not panel.Visible)
	end)
	badge = T("Frame", {
		Parent = button,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Col.Red,
		Visible = false,
		ZIndex = 3,
	}, { Theme.corner(12), Theme.stroke(Color3.new(1, 1, 1), 2) })
	badgeText = Theme.text({
		Parent = badge,
		Size = UDim2.fromScale(1, 1),
		Text = "0",
		Font = Theme.FontBlack,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	panel = T("Frame", {
		Parent = gui,
		Name = "GoalsPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -172, 0, 70),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Col.Cream,
		Visible = false,
	}, {
		Theme.corner(16),
		Theme.stroke(Col.Line, 1),
		Theme.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center),
		T("UIPadding", { PaddingBottom = UDim.new(0, 10) }),
	})
	local head = T("Frame", {
		Parent = panel,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Col.Purple,
	}, { Theme.corner(16) })
	-- square off the header's bottom corners
	T("Frame", { Parent = head, Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Col.Purple, BorderSizePixel = 0 })
	Theme.text({ Parent = head, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -60, 1, 0), Text = "🎯 DAILY GOALS", Font = Theme.FontBlack, TextSize = 18 })
	Theme.button({
		Parent = head,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.fromRGB(110, 60, 180),
		Text = "X", -- GothamBlack has no ✕ glyph (rendered as a blank box)
		TextSize = 16,
	}, function()
		setOpen(false)
	end)
	resetLabel = Theme.text({
		Parent = panel,
		LayoutOrder = 2,
		Size = UDim2.new(1, -28, 0, 18),
		Text = "",
		TextColor3 = Col.InkSoft,
		TextSize = 12,
	})
	list = T("Frame", {
		Parent = panel,
		LayoutOrder = 3,
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, { Theme.list(Enum.FillDirection.Vertical, 8) })
end

function Goals.start()
	build()
	State.Changed:Connect(function()
		render(false)
	end)
	render(true)
	task.spawn(function()
		while true do
			local view = State.get("goals")
			if view and panel.Visible then
				resetLabel.Text = "New goals in " .. formatDuration(view.resetsAt - workspace:GetServerTimeNow())
			end
			task.wait(1)
		end
	end)
end

return Goals
