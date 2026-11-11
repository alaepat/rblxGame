-- Delta encoding of the State snapshot (optimisation pass).

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local StateDelta = Loader.module("Shared/StateDelta")

return {
	["first send is full and the client gets everything"] = function()
		local snap = { money = 5, stock = { dough = 3 } }
		local delta, sent = StateDelta.diff(nil, snap)
		T.ok(delta and delta.full, "full on first send")
		local data = StateDelta.apply({ stale = true }, delta)
		T.eq(data.money, 5)
		T.eq(data.stock.dough, 3)
		T.eq(data.stale, nil, "full clears old keys")
		T.ok(sent.stock ~= snap.stock, "lastSent keeps a copy, not the live table")
	end,

	["unchanged snapshot sends nothing"] = function()
		local snap = { money = 5, stock = { dough = 3 } }
		local _, sent = StateDelta.diff(nil, snap)
		local delta = StateDelta.diff(sent, { money = 5, stock = { dough = 3 } })
		T.eq(delta, nil)
	end,

	["live table mutated in place is still detected"] = function()
		local stock = { dough = 3 }
		local snap = { money = 5, stock = stock }
		local _, sent = StateDelta.diff(nil, snap)
		stock.dough = 2 -- the profile table changes under us
		local delta = StateDelta.diff(sent, { money = 5, stock = stock })
		T.ok(delta and delta.set and delta.set.stock, "stock sent again")
		T.eq(delta.set.money, nil, "money unchanged, not sent")
	end,

	["removed keys are sent and applied"] = function()
		local _, sent = StateDelta.diff(nil, { money = 5, shift = { day = 1 } })
		local delta = StateDelta.diff(sent, { money = 5 })
		T.ok(delta and delta.removed and delta.removed[1] == "shift")
		local data = StateDelta.apply({ money = 5, shift = { day = 1 } }, delta)
		T.eq(data.shift, nil)
		T.eq(data.money, 5)
	end,

	["apply merges a partial delta"] = function()
		local data = StateDelta.apply({ money = 1, level = 3 }, { set = { money = 9 } })
		T.eq(data.money, 9)
		T.eq(data.level, 3)
	end,
}
