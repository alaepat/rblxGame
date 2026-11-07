--!strict
-- Day-cycle extras (TASKS #19), next to Account 2's DayClock:
--  * "Before you open" checklist card under the HUD's left column while the
--    restaurant is closed (server builds it: ShiftService.checklist).
--  * Day / night lighting that follows the shift clock (Shared.Shift.Sky).
--    Lighting changes made on the client are local, so each player sees their
--    own restaurant's time of day.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DayCycle = require(Shared.Shift.DayCycle)
local Sky = require(Shared.Shift.Sky)

local Theme = require(script.Parent.Parent.UI.Theme)
local Responsive = require(script.Parent.Parent.UI.Responsive)
local State = require(script.Parent.State)
local DayClock = require(script.Parent.DayClock)
local T = Theme.make
local Col = Theme.Colors

local DayExtras = {}

local card: Frame
local rows: Frame
local lastSig = ""

-- night look (blended in by Sky's night factor)
local NIGHT_OUTDOOR = Color3.fromRGB(58, 62, 92)
local NIGHT_BRIGHTNESS = 0.9
local base = {
	brightness = Lighting.Brightness,
	outdoor = Lighting.OutdoorAmbient,
	exposure = Lighting.ExposureCompensation,
}

local function buildCard(gui: ScreenGui)
	card = T("Frame", {
		Parent = gui,
		Name = "OpenChecklist",
		-- under the HUD's left column (status pill at y = 60, save warning under it)
		Position = UDim2.fromOffset(12, 150),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Col.Pill,
		BackgroundTransparency = 0.08,
		Visible = false,
	}, { Theme.corner(14), Theme.pad(10, 12), Theme.list(Enum.FillDirection.Vertical, 6) })
	Theme.text({
		Parent = card,
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Text = "📋 BEFORE YOU OPEN",
		Font = Theme.FontBlack,
		TextSize = 14,
		TextColor3 = Col.Yellow,
	})
	rows = T("Frame", {
		Parent = card,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, { Theme.list(Enum.FillDirection.Vertical, 4) })
end

local function renderChecklist(view: any?)
	local list = view and view.state == "idle" and view.checklist or nil
	card.Visible = list ~= nil and not DayClock.covered
	if not list then
		lastSig = ""
		return
	end
	local parts = {}
	for _, it in list.items do
		table.insert(parts, tostring(it.ok) .. it.text)
	end
	local sig = table.concat(parts, "|")
	if sig == lastSig then
		return
	end
	lastSig = sig
	for _, ch in rows:GetChildren() do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	for i, it in list.items do
		Theme.text({
			Parent = rows,
			Name = "Check_" .. it.id,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = (if it.ok then "✅ " else "⬜ ") .. it.text,
			TextWrapped = true,
			TextSize = 13,
			TextColor3 = if it.ok then Col.Muted else Col.PillText,
		})
	end
	Theme.text({
		Parent = rows,
		Name = "Footer",
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 16),
		Text = if list.ready then "All set: flip the OPEN sign by the door!" else "You can open anyway, but customers will notice.",
		TextSize = 11,
		TextColor3 = if list.ready then Col.Green else Col.Muted,
	})
end

local function applyLighting(view: any?, t: number)
	local minute: number? = nil
	if view and (view.state == "open" or view.state == "closing") and view.startedAt then
		minute = DayCycle.minuteFromElapsed(t - view.startedAt)
	end
	local clock, night = Sky.at(minute)
	Lighting.ClockTime = clock
	Lighting.Brightness = base.brightness + (NIGHT_BRIGHTNESS - base.brightness) * night
	Lighting.OutdoorAmbient = base.outdoor:Lerp(NIGHT_OUTDOOR, night)
	Lighting.ExposureCompensation = base.exposure + 0.25 * night
end

function DayExtras.start()
	local gui = T("ScreenGui", {
		Name = "DayExtras",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 3,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Responsive.apply(gui, Responsive.HUD)
	buildCard(gui)
	State.Changed:Connect(function()
		renderChecklist(State.get("shift"))
	end)
	task.spawn(function()
		while true do
			local view = State.get("shift")
			renderChecklist(view)
			applyLighting(view, workspace:GetServerTimeNow())
			task.wait(0.25)
		end
	end)
end

return DayExtras
