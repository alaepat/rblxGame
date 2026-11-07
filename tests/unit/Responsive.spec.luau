-- Phone / tablet UI scale rule (Client/UI/Responsive.scaleFor).

local roblox = require("@lune/roblox")
local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Responsive = Loader.module("Client/UI/Responsive")
local V2 = roblox.Vector2.new

local function near(a: number, b: number)
	T.near(a, b, 1e-3)
end

return {
	["desktop screens stay at scale 1"] = function()
		T.eq(Responsive.scaleFor(V2(1920, 1080), Responsive.WINDOW), 1)
		T.eq(Responsive.scaleFor(V2(1366, 768), Responsive.HUD), 1)
	end,
	["phone landscape shrinks to the tighter axis"] = function()
		-- 844 x 390: height is the limit (390 / 470)
		near(Responsive.scaleFor(V2(844, 390), Responsive.WINDOW), 390 / 470)
		-- HUD design is smaller, so it shrinks less
		near(Responsive.scaleFor(V2(844, 354), Responsive.HUD), 354 / 440)
	end,
	["never below the minimum scale"] = function()
		T.eq(Responsive.scaleFor(V2(320, 200), Responsive.WINDOW), Responsive.MIN_SCALE)
	end,
	["zero-size screen (not laid out yet) is scale 1"] = function()
		T.eq(Responsive.scaleFor(V2(0, 0), Responsive.WINDOW), 1)
	end,
}
