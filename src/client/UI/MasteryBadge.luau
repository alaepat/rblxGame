--!strict
-- Menu-mastery row for a recipe card in the Recipes tab (Controllers/Manager):
-- stars, a progress bar toward the next tier and "12 / 30 to 🥈 Silver".
-- The card must leave ~22 px free at the bottom (MasteryBadge.Height).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Mastery = require(Shared.Mastery.Mastery)

local Theme = require(script.Parent.Theme)
local T = Theme.make
local Col = Theme.Colors

local MasteryBadge = {}
MasteryBadge.Height = 22

local GOLD = Color3.fromRGB(245, 180, 0)

-- The text next to the bar, e.g. "12 / 30 to 🥈 Silver".
function MasteryBadge.caption(recipe: any, count: number?): string
	local v = Mastery.view(recipe, count)
	if not v.nextAt then
		local top = Mastery.Config.Tiers[Mastery.MaxTier]
		return ("%s Mastered! +%d%% XP per serve"):format(top.icon, math.floor(top.serveXPBonus * 100 + 0.5))
	end
	local nextTier = Mastery.Config.Tiers[v.tier + 1]
	return ("%d / %d to %s %s"):format(v.count, v.nextAt, nextTier.icon, nextTier.name)
end

function MasteryBadge.attach(card: Frame, recipe: any, count: number?): Frame
	local v = Mastery.view(recipe, count)
	local row = T("Frame", {
		Parent = card,
		Name = "Mastery",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 60, 1, -6),
		Size = UDim2.new(1, -72, 0, 16),
		BackgroundTransparency = 1,
	})
	Theme.text({
		Parent = row,
		Name = "Stars",
		Size = UDim2.fromOffset(54, 16),
		RichText = true,
		Text = Mastery.stars(v.tier),
		Font = Theme.FontBlack,
		TextSize = 15,
		TextColor3 = Col.InkSoft,
	})
	local barBg = T("Frame", {
		Parent = row,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 58, 0.5, 0),
		Size = UDim2.new(1, -250, 0, 6),
		BackgroundColor3 = Col.Line,
	}, { Theme.corner(3) })
	T("Frame", {
		Parent = barBg,
		Name = "Fill",
		Size = UDim2.fromScale(v.progress, 1),
		BackgroundColor3 = if v.nextAt then Col.Purple else GOLD,
	}, { Theme.corner(3) })
	Theme.text({
		Parent = row,
		Name = "Caption",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(184, 16),
		Text = MasteryBadge.caption(recipe, count),
		TextColor3 = if v.nextAt then Col.InkSoft else Color3.fromRGB(190, 130, 0),
		Font = Theme.FontBlack,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	return row
end

return MasteryBadge
