-- Client day clock + end-of-day summary built with real (Lune) Instances, so
-- bad property names or runtime errors in the UI code fail here, not in Studio.

local roblox = require("@lune/roblox")
local Loader = require("../lib/Loader")
local T = require("../lib/T")

local DayCycle = Loader.module("Shared/Shift/DayCycle")
local C = DayCycle.Config

local function setup()
	local clicks: { [any]: () -> () } = {}
	local Theme = Loader.module("Client/UI/Theme")
	-- Lune Instances have no events: build buttons without Activated and keep the handler
	Theme.button = function(props, onClick)
		local b = Theme.make("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = props.BackgroundColor3 or Theme.Colors.Green,
			Font = props.Font or Theme.FontBlack,
			TextColor3 = props.TextColor3 or roblox.Color3.new(1, 1, 1),
			TextSize = props.TextSize or 16,
			Text = props.Text or "",
		})
		for k, v in props do
			if k ~= "Radius" then
				b[k] = v
			end
		end
		Theme.corner(props.Radius or 10).Parent = b
		clicks[b] = onClick
		return b
	end
	local state = { shift = nil :: any }
	local changed: { () -> () } = {}
	local summaryHandler: any
	local playerGui = roblox.Instance.new("Folder")
	local DayClock = Loader.module("Client/Controllers/DayClock", {
		["Client/UI/Theme"] = Theme,
		["Client/Controllers/State"] = {
			get = function(k)
				return state[k]
			end,
			Changed = { Connect = function(_, fn)
				table.insert(changed, fn)
			end },
		},
		["Client/Controllers/Sounds"] = { play = function() end },
		["Shared/Net"] = {
			event = function(name)
				return { OnClientEvent = { Connect = function(_, fn)
					if name == "DaySummary" then
						summaryHandler = fn
					end
				end } }
			end,
		},
	}, {
		services = {
			Players = { LocalPlayer = { WaitForChild = function()
				return playerGui
			end } },
		},
		env = { task = { spawn = function() end, wait = function() end } },
	})
	local now = 50000
	DayClock.now = function()
		return now
	end
	DayClock.start()
	local ctx = { DayClock = DayClock }
	function ctx.setShift(view, t: number?)
		now = t or now
		state.shift = view
		for _, fn in changed do
			fn()
		end
	end
	function ctx.find(name: string): any
		for _, d in playerGui:GetDescendants() do
			if d.Name == name then
				return d
			end
		end
		return nil
	end
	function ctx.texts(root: any): { string }
		local out = {}
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				table.insert(out, d.Text)
			end
		end
		return out
	end
	function ctx.hasText(root: any, pattern: string): boolean
		for _, s in ctx.texts(root) do
			if string.find(s, pattern, 1, true) then
				return true
			end
		end
		return false
	end
	function ctx.summary(payload)
		assert(summaryHandler, "DaySummary handler connected")
		summaryHandler(payload)
	end
	function ctx.clickContinue()
		for b, fn in clicks do
			if b.Name == "Continue" then
				return fn()
			end
		end
		error("no Continue button")
	end
	ctx.now = function()
		return now
	end
	return ctx
end

local function summaryPayload(overrides: { [string]: any }?)
	local p = {
		day = 3,
		grade = "A",
		happyShare = 0.8,
		fullDay = true,
		stats = { orders = 10, sales = 150, tips = 20, happy = 8, angry = 2, rushOrders = 4, pizzas = 6, kebabs = 3, drinks = 5, cleaned = 2 },
		startRating = 4,
		endRating = 4.2,
		bonusCash = 33,
		bonusXP = 45,
		wages = 0,
		net = 33,
		bestSales = true,
		bestOrders = false,
	}
	for k, v in overrides or {} do
		p[k] = v
	end
	return p
end

return {
	["clock is hidden until the server sends a shift view"] = function()
		local ctx = setup()
		local pill = ctx.find("DayClock")
		T.ok(pill and pill:IsA("ScreenGui"), "ScreenGui exists")
		local frame = pill:FindFirstChild("DayClock")
		T.ok(frame, "pill frame")
		T.eq(frame.Visible, false)
	end,

	["idle shows the next day and how to start"] = function()
		local ctx = setup()
		ctx.setShift({ state = "idle", day = 4 })
		local frame = ctx.find("DayClock"):FindFirstChild("DayClock")
		T.eq(frame.Visible, true)
		T.ok(ctx.hasText(frame, "DAY 4"))
		T.ok(ctx.hasText(frame, "CLOSED"))
		T.ok(ctx.hasText(frame, "OPEN sign"))
	end,

	["open shift shows the clock, the rush and today's numbers"] = function()
		local ctx = setup()
		local t = ctx.now()
		local startedAt = DayCycle.startForHour(12.5, t)
		ctx.setShift({ state = "open", day = 2, startedAt = startedAt, orders = 3, earned = 41.5 }, t)
		local frame = ctx.find("DayClock"):FindFirstChild("DayClock")
		T.ok(ctx.hasText(frame, "12:30 PM"), "clock")
		T.ok(ctx.hasText(frame, "Lunch rush"), "phase")
		T.ok(ctx.hasText(frame, "3 orders · $41.50"), "stats")
		-- render() can be driven directly too (the 0.25 s loop does this)
		ctx.DayClock.render({ state = "open", day = 2, startedAt = startedAt }, t + C.SecondsPerHour * 3)
		T.ok(ctx.hasText(frame, "3:30 PM"))
		T.ok(ctx.hasText(frame, "Afternoon"))
	end,

	["pill hides while the Pizza Planet OS window covers it"] = function()
		local ctx = setup()
		ctx.setShift({ state = "idle", day = 4 })
		local frame = ctx.find("DayClock"):FindFirstChild("DayClock")
		T.eq(frame.Visible, true)
		ctx.DayClock.covered = true
		ctx.DayClock.render({ state = "idle", day = 4 }, ctx.now())
		T.eq(frame.Visible, false, "hidden while covered")
		ctx.DayClock.covered = false
		ctx.DayClock.render({ state = "idle", day = 4 }, ctx.now())
		T.eq(frame.Visible, true, "back after the window closes")
	end,

	["closing shows the last-customers countdown"] = function()
		local ctx = setup()
		local t = ctx.now()
		ctx.setShift({ state = "closing", day = 2, startedAt = t - 100, closingSince = t - 30, closingGrace = 90, orders = 1, earned = 10 }, t)
		local frame = ctx.find("DayClock"):FindFirstChild("DayClock")
		T.ok(ctx.hasText(frame, "CLOSING"))
		T.ok(ctx.hasText(frame, "1:00"), "60 s left")
	end,

	["summary card shows the day, grade, bonus and records"] = function()
		local ctx = setup()
		ctx.summary(summaryPayload())
		local win = ctx.find("DaySummary")
		T.ok(win, "summary window")
		T.ok(ctx.hasText(win, "DAY 3 DONE!"))
		T.ok(ctx.hasText(win, "A"), "grade")
		T.ok(ctx.hasText(win, "$150.00"), "sales")
		T.ok(ctx.hasText(win, "8 (80%)"), "happy share")
		T.ok(ctx.hasText(win, "+$33.00  +45 XP"), "bonus")
		T.ok(ctx.hasText(win, "full-day bonus"))
		T.ok(ctx.hasText(win, "New best day for sales"))
		T.ok(not ctx.hasText(win, "Staff wages"), "no wages row without staff")
	end,

	["wages row appears when staff were paid, and Continue closes the card"] = function()
		local ctx = setup()
		ctx.summary(summaryPayload({ wages = 25, net = 8, fullDay = false, bestSales = false }))
		local win = ctx.find("DaySummary")
		T.ok(ctx.hasText(win, "Staff wages"))
		T.ok(ctx.hasText(win, "-$25.00"))
		T.ok(ctx.hasText(win, "Closed early"))
		T.ok(not ctx.hasText(win, "New best"))
		ctx.clickContinue()
		T.eq(ctx.find("DaySummary"), nil, "closed")
	end,

	["a second summary replaces the first"] = function()
		local ctx = setup()
		ctx.summary(summaryPayload({ day = 1 }))
		ctx.summary(summaryPayload({ day = 2 }))
		local count = 0
		for _, d in ctx.find("DayClock"):GetChildren() do
			if d.Name == "DaySummary" then
				count += 1
			end
		end
		T.eq(count, 1)
	end,
}
