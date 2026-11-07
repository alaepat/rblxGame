--!strict
-- Dining-room themes (TASKS #13). Bought once in the office PC (🎨 Decor tab),
-- then switched freely. Each role restyles a group of parts in the dining room
-- and the extension (see ThemeService): Floor, Wainscot (lower wall panels),
-- Wall (upper walls), TableTop, Chair, Seat (booths + window-bar stools).

export type Look = { color: Color3, material: Enum.Material? }
export type Theme = {
	id: string,
	name: string,
	icon: string,
	description: string,
	level: number,
	cost: number,
	roles: { [string]: Look },
}

local M = Enum.Material

local list: { Theme } = {
	{
		id = "classic", name = "Classic Pizzeria", icon = "🍕", level = 1, cost = 0,
		description = "Warm wood floors, red panelling and cream walls. The original look.",
		roles = {
			Floor = { color = Color3.fromRGB(178, 126, 82), material = M.WoodPlanks },
			Wainscot = { color = Color3.fromRGB(150, 30, 32), material = M.Wood },
			Wall = { color = Color3.fromRGB(246, 232, 204), material = M.Plaster },
			TableTop = { color = Color3.fromRGB(196, 142, 92), material = M.Wood },
			Chair = { color = Color3.fromRGB(246, 244, 240) },
			Seat = { color = Color3.fromRGB(206, 40, 40), material = M.Leather },
		},
	},
	{
		id = "diner", name = "Retro Diner", icon = "🥤", level = 4, cost = 600,
		description = "Mint walls, chrome-white tables and cherry-red seats.",
		roles = {
			Floor = { color = Color3.fromRGB(236, 236, 232), material = M.CeramicTiles },
			Wainscot = { color = Color3.fromRGB(64, 170, 160), material = M.SmoothPlastic },
			Wall = { color = Color3.fromRGB(196, 236, 224), material = M.Plaster },
			TableTop = { color = Color3.fromRGB(240, 240, 244), material = M.Marble },
			Chair = { color = Color3.fromRGB(214, 40, 52) },
			Seat = { color = Color3.fromRGB(214, 40, 52), material = M.Leather },
		},
	},
	{
		id = "trattoria", name = "Tuscan Trattoria", icon = "🍇", level = 7, cost = 1000,
		description = "Terracotta tiles, olive panels, sunny walls and dark oak.",
		roles = {
			Floor = { color = Color3.fromRGB(176, 92, 58), material = M.Slate },
			Wainscot = { color = Color3.fromRGB(96, 112, 58), material = M.Wood },
			Wall = { color = Color3.fromRGB(240, 210, 140), material = M.Plaster },
			TableTop = { color = Color3.fromRGB(92, 60, 40), material = M.Wood },
			Chair = { color = Color3.fromRGB(110, 84, 58) },
			Seat = { color = Color3.fromRGB(120, 140, 70), material = M.Fabric },
		},
	},
	{
		id = "space", name = "Space Station", icon = "🚀", level = 10, cost = 1600,
		description = "Steel deck plates, navy walls with violet panels. Very on-brand.",
		roles = {
			Floor = { color = Color3.fromRGB(120, 126, 138), material = M.DiamondPlate },
			Wainscot = { color = Color3.fromRGB(120, 70, 220), material = M.SmoothPlastic },
			Wall = { color = Color3.fromRGB(40, 48, 84), material = M.SmoothPlastic },
			TableTop = { color = Color3.fromRGB(30, 30, 38), material = M.Glass },
			Chair = { color = Color3.fromRGB(236, 240, 248) },
			Seat = { color = Color3.fromRGB(70, 200, 230), material = M.Leather },
		},
	},
	{
		id = "luxury", name = "Gold & Marble", icon = "💎", level = 14, cost = 3000,
		description = "Polished marble, black panelling and gold-trimmed tables.",
		roles = {
			Floor = { color = Color3.fromRGB(236, 232, 226), material = M.Marble },
			Wainscot = { color = Color3.fromRGB(30, 28, 32), material = M.Wood },
			Wall = { color = Color3.fromRGB(250, 246, 236), material = M.Plaster },
			TableTop = { color = Color3.fromRGB(214, 172, 80), material = M.Metal },
			Chair = { color = Color3.fromRGB(34, 32, 36) },
			Seat = { color = Color3.fromRGB(34, 32, 36), material = M.Leather },
		},
	},
}

local byId: { [string]: Theme } = {}
for _, t in list do
	byId[t.id] = t
end

return {
	List = list,
	Default = "classic",
	get = function(id: string): Theme?
		return byId[id]
	end,
}
