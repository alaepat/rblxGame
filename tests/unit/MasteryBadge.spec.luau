-- The mastery row on recipe cards, built with real (Lune) Instances so bad
-- property names or runtime errors fail here instead of in Studio.

local roblox = require("@lune/roblox")
local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Mastery = Loader.module("Shared/Mastery/Mastery")
local Recipes = Loader.module("Shared/Config/Recipes")
local Badge = Loader.module("Client/UI/MasteryBadge")

local pizza = Recipes.get("cheese_pizza")

local function build(count: number?)
	local card = roblox.Instance.new("Frame")
	local row = Badge.attach(card, pizza, count)
	return card, row
end

return {
	["attaches a named row with stars, bar and caption"] = function()
		local card, row = build(nil)
		T.ok(card:FindFirstChild("Mastery") == row)
		local stars = row:FindFirstChild("Stars")
		T.ok(stars and stars.RichText, "stars use RichText")
		T.eq(stars.Text, Mastery.stars(0))
		T.ok(row:FindFirstChild("Caption"), "caption")
	end,

	["caption counts toward the next tier"] = function()
		local th = Mastery.thresholds(pizza)
		T.eq(Badge.caption(pizza, nil), ("0 / %d to 🥉 Bronze"):format(th[1]))
		T.eq(Badge.caption(pizza, th[1] + 2), ("%d / %d to 🥈 Silver"):format(th[1] + 2, th[2]))
		T.ok(string.find(Badge.caption(pizza, th[3]), "Mastered!", 1, true))
		T.ok(string.find(Badge.caption(pizza, th[3]), "+30% XP", 1, true))
	end,

	["bar fill matches progress"] = function()
		local th = Mastery.thresholds(pizza)
		local _, row = build(th[1] + (th[2] - th[1]) / 2)
		local fill
		for _, d in row:GetDescendants() do
			if d.Name == "Fill" then
				fill = d
			end
		end
		T.ok(fill, "fill frame")
		T.near(fill.Size.X.Scale, 0.5, 1e-6)
		local _, full = build(th[3])
		for _, d in full:GetDescendants() do
			if d.Name == "Fill" then
				T.eq(d.Size.X.Scale, 1)
			end
		end
	end,
}
