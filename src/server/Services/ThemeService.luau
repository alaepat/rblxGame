--!strict
-- Dining-room themes (Config/Themes): buy once, switch freely, applied to the
-- plot's dining room + extension by part name. Saved as profile.theme and
-- profile.themes = { [id] = true }.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Themes = require(Shared.Config.Themes)
local Net = require(Shared.Net)

local ThemeService = {}
local S: any

function ThemeService.init(services)
	S = services
end

-- which role a part plays, or nil (dining room + east annex; X < 60 covers the annex)
local function roleOf(p: BasePart, localPos: Vector3): string?
	local n = p.Name
	local inDining = localPos.Z > 5.5 and localPos.Z < 40 and localPos.X > -42 and localPos.X < 60 and localPos.Y < 14
	if not inDining then
		return nil
	end
	if n == "DiningFloor" or n == "ExFloor" then
		return "Floor"
	elseif string.sub(n, 1, 8) == "Wainscot" then
		return "Wainscot"
	elseif string.sub(n, 1, 12) == "InWestDining" or string.sub(n, 1, 12) == "InEastDining" or string.sub(n, 1, 7) == "InFront" or n == "ExPlaster" then
		return "Wall"
	elseif n == "Table_Top" or n == "BoothTable_Top" then
		return "TableTop"
	elseif n == "Chair_Shell" then
		return "Chair"
	elseif n == "BoothBench_Seat" or n == "BoothBench_Back" or n == "BarStool_Seat" then
		return "Seat"
	end
	return nil
end

function ThemeService.apply(plot)
	local model = plot.model
	local profile = plot.owner and S.DataService.get(plot.owner)
	if not model or not profile then
		return
	end
	local theme = Themes.get(profile.theme or Themes.Default) or Themes.get(Themes.Default) :: any
	local origin = model:GetPivot()
	-- hidden upgrade content (seating, annex) lives in plot.hidden; restyle it too
	for _, root in { model, plot.hidden } do
		if root then
			for _, d in root:GetDescendants() do
				if d:IsA("BasePart") then
					local role = roleOf(d, origin:PointToObjectSpace(d.Position))
					local look = role and theme.roles[role]
					if look then
						d.Color = look.color
						if look.material then
							d.Material = look.material
						end
					end
				end
			end
		end
	end
end

-- Buy (if needed) and switch to a theme.
function ThemeService.choose(player: Player, id: any): (boolean, string)
	local profile = S.DataService.get(player)
	local plot = S.PlotService.get(player)
	local t = type(id) == "string" and Themes.get(id)
	if not profile or not plot or not t then
		return false, "Unknown theme"
	end
	profile.themes = profile.themes or { [Themes.Default] = true }
	if not profile.themes[t.id] then
		if profile.level < t.level then
			return false, "Reach level " .. t.level .. " first"
		end
		if not S.ProgressService.spend(player, t.cost) then
			return false, ("You need $%d"):format(t.cost)
		end
		profile.themes[t.id] = true
		S.ProgressService.sound(player, "Upgrade")
	end
	profile.theme = t.id
	ThemeService.apply(plot)
	S.ProgressService.push(player)
	return true, t.icon .. " " .. t.name .. " theme applied!"
end

function ThemeService.start()
	Net.func("SetTheme").OnServerInvoke = function(player, id)
		return ThemeService.choose(player, id)
	end
	S.ProgressService.addStateProvider(function(player)
		local profile = S.DataService.get(player)
		return profile and { theme = profile.theme or Themes.Default, themes = profile.themes or { [Themes.Default] = true } } or nil
	end)
end

return ThemeService
