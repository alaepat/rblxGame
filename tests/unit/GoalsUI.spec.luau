-- Client goals panel built with real (Lune) Instances, so bad property names or
-- runtime errors in the UI code fail here instead of in Studio. Button clicks
-- are simulated because Lune Instances have no events.

local roblox = require("@lune/roblox")
local Loader = require("../lib/Loader")
local T = require("../lib/T")

local DailyGoals = Loader.module("Shared/Goals/DailyGoals")

local DAY0 = 20397

local function setup()
	local clicks: { [any]: () -> () } = {}
	local Theme = Loader.module("Client/UI/Theme")
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

	local state = { goals = nil :: any }
	local changed: { () -> () } = {}
	local fakeState = {
		get = function(k)
			return state[k]
		end,
		Changed = { Connect = function(_, fn)
			table.insert(changed, fn)
		end },
	}
	local invoked = {}
	local fakeNet = {
		func = function(name)
			return { InvokeServer = function(_, arg)
				table.insert(invoked, { name = name, arg = arg })
				return true, "ok"
			end }
		end,
	}
	local toasts = {}
	local playerGui = roblox.Instance.new("Folder")
	local Goals = Loader.module("Client/Controllers/Goals", {
		["Client/UI/Theme"] = Theme,
		["Client/Controllers/State"] = fakeState,
		["Client/Controllers/Notifications"] = { toast = function(text, kind)
			table.insert(toasts, { text = text, kind = kind })
		end },
		["Client/Controllers/Sounds"] = { play = function() end },
		["Shared/Net"] = fakeNet,
	}, {
		services = {
			Players = { LocalPlayer = { WaitForChild = function()
				return playerGui
			end } },
			TweenService = { Create = function()
				return { Play = function() end }
			end },
		},
		env = {
			task = { spawn = function() end, wait = function() end, delay = function() end },
			-- Lune has no TweenInfo; the fake TweenService ignores it anyway
			TweenInfo = { new = function(...)
				return { ... }
			end },
		},
	})
	local ctx = {}
	function ctx.setView(view)
		state.goals = view
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
	function ctx.buttons(): { any }
		local out = {}
		for _, d in playerGui:GetDescendants() do
			if d:IsA("TextButton") then
				table.insert(out, d)
			end
		end
		return out
	end
	function ctx.click(b)
		assert(clicks[b], "not a clickable button: " .. b.Text)
		clicks[b]()
	end
	function ctx.buttonWithText(pattern: string)
		for _, b in ctx.buttons() do
			if b.Visible ~= false and string.find(b.Text, pattern, 1, true) then
				return b
			end
		end
		return nil
	end
	ctx.Goals = Goals
	ctx.invoked = invoked
	ctx.toasts = toasts
	return ctx
end

local function sampleView(opts: { doneFirst: boolean?, allClaimed: boolean? }?)
	local d = DailyGoals.new()
	DailyGoals.rollover(d, DAY0, 42, 6, { kebab_station = true })
	if opts and opts.doneFirst then
		d.goals[1].progress = d.goals[1].target
	end
	if opts and opts.allClaimed then
		for _, g in d.goals do
			g.progress = g.target
			g.claimed = true
		end
	end
	return DailyGoals.view(d, 6, DAY0 * 86400 + 60)
end

return {
	["button stays hidden until goals arrive"] = function()
		local ctx = setup()
		ctx.Goals.start()
		local button = ctx.find("GoalsButton")
		T.ok(button, "no goals button")
		T.eq(button.Visible, false)
		ctx.setView(sampleView())
		T.eq(button.Visible, true)
		T.eq(ctx.find("GoalsPanel").Visible, false)
	end,

	["badge counts claimable goals and the panel draws every card"] = function()
		local ctx = setup()
		ctx.Goals.start()
		ctx.setView(sampleView({ doneFirst = true }))
		local button = ctx.find("GoalsButton")
		local badgeText
		for _, d in button:GetDescendants() do
			if d:IsA("TextLabel") then
				badgeText = d
			end
		end
		T.eq(badgeText.Text, "1")
		ctx.click(button)
		T.eq(ctx.find("GoalsPanel").Visible, true)
		local claimBtn = ctx.buttonWithText("Claim")
		T.ok(claimBtn, "no Claim button for the finished goal")
		ctx.click(claimBtn)
		T.eq(#ctx.invoked, 1)
		T.eq(ctx.invoked[1].name, "ClaimGoal")
		T.eq(ctx.invoked[1].arg, 1)
		T.eq(ctx.toasts[1].kind, "good")
	end,

	["bonus button appears once every goal is claimed"] = function()
		local ctx = setup()
		ctx.Goals.start()
		ctx.setView(sampleView({ allClaimed = true }))
		ctx.click(ctx.find("GoalsButton"))
		local bonus = ctx.buttonWithText("Claim bonus")
		T.ok(bonus, "no bonus button")
		ctx.click(bonus)
		T.eq(ctx.invoked[1].arg, "bonus")
		-- closing works
		ctx.click(ctx.buttonWithText("X"))
		T.eq(ctx.find("GoalsPanel").Visible, false)
	end,
}
