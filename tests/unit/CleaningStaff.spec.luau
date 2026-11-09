-- CleaningService.removeTrash / wipeCounter: the shared clean-up path used by
-- the player's prompts and by the hired cleaner. A player gets XP + credit;
-- staff (player = nil) don't.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local function setup()
	local Cleaning = Loader.module("Server/Services/CleaningService", { ["Shared/Food/FoodVisuals"] = {} }, {
		-- Lune has no Random; these tests never spawn rubbish, so a stub is enough
		env = { Random = { new = function()
			return {}
		end } },
	})
	local player = { UserId = 5 }
	local profile = { stats = { cleaned = 0 } }
	local log = { xp = 0, events = {}, pushes = 0 }
	Cleaning.init({
		DataService = { get = function()
			return profile
		end },
		ProgressService = {
			addXP = function(_, n)
				log.xp += n
			end,
			sound = function() end,
			push = function()
				log.pushes += 1
			end,
		},
		GoalService = { record = function(_, event)
			table.insert(log.events, event)
		end },
	})
	local function thing()
		local t = { destroyed = false }
		function t:Destroy()
			self.destroyed = true
		end
		return t
	end
	return Cleaning, player, profile, log, thing
end

return {
	["a player removing rubbish gets credit"] = function()
		local Cleaning, player, profile, log, thing = setup()
		local m = thing()
		local plot = { owner = player, trash = { m } }
		T.ok(Cleaning.removeTrash(plot, m, player))
		T.ok(m.destroyed)
		T.eq(#plot.trash, 0)
		T.eq(profile.stats.cleaned, 1)
		T.ok(log.xp > 0)
		T.eq(log.events[1], "clean")
		T.eq(Cleaning.removeTrash(plot, m, player), false, "already gone")
		T.eq(profile.stats.cleaned, 1, "no double credit")
	end,

	["staff removing rubbish gives no credit but updates the HUD"] = function()
		local Cleaning, player, profile, log, thing = setup()
		local m = thing()
		local plot = { owner = player, trash = { m } }
		T.ok(Cleaning.removeTrash(plot, m, nil))
		T.ok(m.destroyed)
		T.eq(profile.stats.cleaned, 0)
		T.eq(log.xp, 0)
		T.eq(#log.events, 0)
		T.ok(log.pushes > 0, "cleanliness refreshes")
	end,

	["wipeCounter clears the mess once"] = function()
		local Cleaning, player, profile, log, thing = setup()
		local mess = thing()
		local st = { dirty = true, uses = 8, mess = mess, plot = { owner = player } }
		T.ok(Cleaning.wipeCounter(st, nil))
		T.eq(st.dirty, false)
		T.eq(st.uses, 0)
		T.ok(mess.destroyed)
		T.eq(st.mess, nil)
		T.eq(log.xp, 0, "staff: no XP")
		T.eq(Cleaning.wipeCounter(st, player), false, "already clean")
		st.dirty = true
		T.ok(Cleaning.wipeCounter(st, player))
		T.eq(profile.stats.cleaned, 1, "player wipe counts")
	end,
}
