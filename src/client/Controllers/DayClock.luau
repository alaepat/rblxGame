--!strict
-- Day clock (top-left, above the order list) and the end-of-day summary.
--  * The clock reads the `shift` snapshot field (ShiftService.stateFor) and
--    works the time out locally from `startedAt` with GetServerTimeNow, so it
--    ticks smoothly between snapshots.
--  * A timeline bar under it shows the day with the rush phases in orange and
--    a marker for "now".
--  * The DaySummary remote opens a cream card with the day's numbers, grade,
--    shift bonus and wages.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local DayCycle = require(Shared.Shift.DayCycle)

local Theme = require(script.Parent.Parent.UI.Theme)
local Responsive = require(script.Parent.Parent.UI.Responsive)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local T = Theme.make
local Col = Theme.Colors

local DayClock = {}

local RUSH = Color3.fromRGB(255, 140, 40)
local CALM = Color3.fromRGB(70, 64, 82)
local GRADE_COLORS = {
	S = Color3.fromRGB(255, 196, 40),
	A = Color3.fromRGB(46, 190, 90),
	B = Color3.fromRGB(40, 130, 230),
	C = Color3.fromRGB(140, 80, 220),
	D = Color3.fromRGB(214, 40, 40),
}

local gui: ScreenGui
local pill: Frame
local dayLabel: TextLabel
local clockLabel: TextLabel
local phaseLabel: TextLabel
local statsLabel: TextLabel
local bar: Frame
local marker: Frame
local summaryWindow: Frame

-- Set by the Pizza Planet OS window while it is open (the pill would cover
-- its top-left corner); render() hides the pill while this is true.
DayClock.covered = false

-- Replaceable for tests.
DayClock.now = function(): number
	return workspace:GetServerTimeNow()
end

local function fmtDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- Updates the pill from a `shift` view at real time `t`.
function DayClock.render(view: any?, t: number)
	if not pill then
		return
	end
	-- hidden while a full-screen window (Pizza Planet OS) is open over it
	pill.Visible = view ~= nil and view.state ~= nil and not DayClock.covered
	if not view or not view.state then
		return
	end
	dayLabel.Text = "DAY " .. tostring(view.day or 1)
	if view.state == "idle" then
		clockLabel.Text = "CLOSED"
		clockLabel.TextColor3 = Col.Muted
		phaseLabel.Text = "Flip the OPEN sign to start the day"
		phaseLabel.TextColor3 = Col.Muted
		statsLabel.Text = ""
		marker.Visible = false
		return
	end
	local elapsed = t - (view.startedAt or t)
	local minute = DayCycle.minuteFromElapsed(elapsed)
	local frac = math.clamp(elapsed / DayCycle.dayLength(), 0, 1)
	marker.Visible = true
	marker.Position = UDim2.new(frac, 0, 0.5, 0)
	local n = view.orders or 0
	statsLabel.Text = ("%d %s · %s"):format(n, if n == 1 then "order" else "orders", Theme.money(view.earned or 0))
	if view.state == "closing" then
		clockLabel.Text = "CLOSING"
		clockLabel.TextColor3 = Col.Yellow
		local left = (view.closingGrace or 0) - (t - (view.closingSince or t))
		phaseLabel.Text = "🌙 Last customers · " .. fmtDuration(left)
		phaseLabel.TextColor3 = Col.Muted
		return
	end
	clockLabel.Text = DayCycle.formatClock(minute)
	clockLabel.TextColor3 = Col.PillText
	local phase = DayCycle.phaseAt(minute)
	if phase then
		phaseLabel.Text = (phase.icon or "") .. " " .. phase.label
		phaseLabel.TextColor3 = if phase.rush then RUSH else Col.Muted
	else
		phaseLabel.Text = "🌙 Closing time"
		phaseLabel.TextColor3 = Col.Yellow
	end
end

local function buildPill()
	pill = T("Frame", {
		Parent = gui,
		Name = "DayClock",
		-- Above the HUD's left column (which starts at y = 60).
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.fromOffset(250, 52),
		BackgroundColor3 = Col.Pill,
		BackgroundTransparency = 0.08,
		Visible = false,
	}, { Theme.corner(14) })
	dayLabel = Theme.text({ Parent = pill, Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(110, 20), Text = "DAY 1", Font = Theme.FontBlack, TextSize = 15 })
	clockLabel = Theme.text({
		Parent = pill,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 4),
		Size = UDim2.fromOffset(120, 20),
		Text = "",
		Font = Theme.FontBlack,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	phaseLabel = Theme.text({ Parent = pill, Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -110, 0, 14), Text = "", TextSize = 12, TextColor3 = Col.Muted })
	statsLabel = Theme.text({
		Parent = pill,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 24),
		Size = UDim2.fromOffset(110, 14),
		Text = "",
		TextSize = 11,
		TextColor3 = Col.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	bar = T("Frame", {
		Parent = pill,
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 5),
		BackgroundColor3 = CALM,
		ClipsDescendants = false,
	}, { Theme.corner(3) })
	for _, seg in DayCycle.timeline() do
		if seg.rush then
			T("Frame", {
				Parent = bar,
				Position = UDim2.fromScale(seg.from, 0),
				Size = UDim2.fromScale(seg.to - seg.from, 1),
				BackgroundColor3 = RUSH,
				BorderSizePixel = 0,
			}, { Theme.corner(2) })
		end
	end
	marker = T("Frame", {
		Parent = bar,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(4, 11),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Visible = false,
	}, { Theme.corner(2) })
end

------------------------------------------------------------------ summary

local function row(parent: Instance, order: number, label: string, value: string, color: Color3?)
	local r = T("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
	Theme.text({ Parent = r, Size = UDim2.new(0.62, 0, 1, 0), Text = label, TextColor3 = Col.InkSoft, TextSize = 14 })
	Theme.text({
		Parent = r,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.38, 0, 1, 0),
		Text = value,
		TextColor3 = color or Col.Ink,
		Font = Theme.FontBlack,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
end

function DayClock.showSummary(s: any)
	if summaryWindow then
		summaryWindow:Destroy()
	end
	local st = s.stats or {}
	summaryWindow = T("Frame", {
		Parent = gui,
		Name = "DaySummary",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Col.Cream,
	}, {
		Theme.corner(18),
		Theme.stroke(Col.Line, 1),
		Theme.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center),
		T("UIPadding", { PaddingBottom = UDim.new(0, 16) }),
	})
	local head = T("Frame", { Parent = summaryWindow, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = RUSH }, { Theme.corner(18) })
	T("Frame", { Parent = head, Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = RUSH, BorderSizePixel = 0 })
	Theme.text({ Parent = head, Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -110, 0, 30), Text = ("DAY %d DONE!"):format(s.day or 0), Font = Theme.FontBlack, TextSize = 24 })
	Theme.text({
		Parent = head,
		Position = UDim2.fromOffset(18, 48),
		Size = UDim2.new(1, -110, 0, 30),
		Text = if s.fullDay then "Open until closing time: full-day bonus ×" .. tostring(DayCycle.Config.Bonus.FullDayMultiplier) else "Closed early",
		TextWrapped = true,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 240, 220),
	})
	local badge = T("Frame", {
		Parent = head,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = GRADE_COLORS[s.grade] or Col.Purple,
	}, { Theme.corner(32), Theme.stroke(Color3.new(1, 1, 1), 3) })
	Theme.text({ Parent = badge, Size = UDim2.fromScale(1, 1), Text = tostring(s.grade or "?"), Font = Theme.FontFun, TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center })

	local body = T("Frame", {
		Parent = summaryWindow,
		LayoutOrder = 2,
		Size = UDim2.new(1, -36, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, { Theme.list(Enum.FillDirection.Vertical, 2) })
	row(body, 1, "📋 Orders served", tostring(st.orders or 0))
	if (st.desserts or 0) > 0 then
		row(body, 2, "🍕 Pizzas · 🌯 Kebabs · 🥤 Drinks · 🍨 Desserts", ("%d · %d · %d · %d"):format(st.pizzas or 0, st.kebabs or 0, st.drinks or 0, st.desserts))
	else
		row(body, 2, "🍕 Pizzas · 🌯 Kebabs · 🥤 Drinks", ("%d · %d · %d"):format(st.pizzas or 0, st.kebabs or 0, st.drinks or 0))
	end
	row(body, 3, "💵 Sales", Theme.money(st.sales or 0))
	row(body, 4, "💰 Tips", Theme.money(st.tips or 0))
	row(body, 5, "😊 Happy customers", ("%d (%d%%)"):format(st.happy or 0, math.floor((s.happyShare or 0) * 100 + 0.5)))
	row(body, 6, "😠 Walk-outs", tostring(st.angry or 0), if (st.angry or 0) > 0 then Col.Red else nil)
	row(body, 7, "🔥 Rush orders", tostring(st.rushOrders or 0))
	row(body, 8, "🧽 Messes cleaned", tostring(st.cleaned or 0))
	local dr = (s.endRating or 0) - (s.startRating or 0)
	row(body, 9, "⭐ Rating", ("%.2f → %.2f"):format(s.startRating or 0, s.endRating or 0), if dr > 0.005 then Col.GreenDark elseif dr < -0.005 then Col.Red else nil)

	local pay = T("Frame", {
		Parent = summaryWindow,
		LayoutOrder = 3,
		Size = UDim2.new(1, -36, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Col.Paper,
	}, { Theme.corner(12), Theme.stroke(Col.Line, 1), Theme.pad(8, 12), Theme.list(Enum.FillDirection.Vertical, 2) })
	row(pay, 1, "🎁 Shift bonus", ("+%s  +%d XP"):format(Theme.money(s.bonusCash or 0), s.bonusXP or 0), Col.GreenDark)
	if (s.wages or 0) > 0 then
		row(pay, 2, "👥 Staff wages", "-" .. Theme.money(s.wages), Col.Red)
	end
	if s.bestSales or s.bestOrders then
		Theme.text({
			Parent = summaryWindow,
			LayoutOrder = 4,
			Size = UDim2.new(1, -36, 0, 20),
			Text = if s.bestSales then "🏆 New best day for sales!" else "🏆 New record for orders in a day!",
			TextColor3 = Col.Ink,
			Font = Theme.FontBlack,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	Theme.button({
		Parent = summaryWindow,
		Name = "Continue",
		LayoutOrder = 5,
		Size = UDim2.new(1, -36, 0, 44),
		BackgroundColor3 = Col.Green,
		Text = "Nice! Get ready for tomorrow",
		TextSize = 16,
	}, function()
		Sounds.play("Click")
		if summaryWindow then
			summaryWindow:Destroy()
			summaryWindow = nil :: any
		end
	end)
end

function DayClock.start()
	gui = T("ScreenGui", {
		Name = "DayClock",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25, -- under the toasts (30)
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Responsive.apply(gui, Responsive.HUD)
	buildPill()
	Net.event("DaySummary").OnClientEvent:Connect(DayClock.showSummary)
	State.Changed:Connect(function()
		DayClock.render(State.get("shift"), DayClock.now())
	end)
	task.spawn(function()
		while true do
			DayClock.render(State.get("shift"), DayClock.now())
			task.wait(0.25)
		end
	end)
end

-- Tests build the UI into their own parent without remotes or loops.
function DayClock._buildInto(parent: Instance)
	gui = parent :: any
	buildPill()
end

return DayClock
