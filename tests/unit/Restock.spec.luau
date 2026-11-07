-- Office tablet "Quick restock" suggestion rules.

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Restock = Loader.module("Shared/Food/Restock")

local ING = {
	{ id = "dough", level = 1, boxSize = 12 },
	{ id = "cheese", level = 1, boxSize = 30 },
	{ id = "ham", level = 3, boxSize = 30 },
}
local CAP = { dough = 36, cheese = 90, ham = 90 }

local function count(cart): number
	local n = 0
	for _, q in cart do
		n += q
	end
	return n
end

return {
	["well stocked: nothing suggested"] = function()
		local cart = Restock.suggest(ING, { dough = 30, cheese = 80, ham = 80 }, CAP, 5, 12)
		T.eq(count(cart), 0)
	end,

	["low ingredients are topped up to capacity in whole boxes"] = function()
		local cart = Restock.suggest(ING, { dough = 2, cheese = 10, ham = 90 }, CAP, 5, 12)
		T.eq(cart.dough, 2, "36 - 2 = 34 -> 2 boxes of 12")
		T.eq(cart.cheese, 2, "90 - 10 = 80 -> 2 boxes of 30")
		T.eq(cart.ham, nil, "ham is full")
	end,

	["locked ingredients are skipped"] = function()
		local cart = Restock.suggest(ING, { dough = 30, cheese = 80, ham = 0 }, CAP, 2, 12)
		T.eq(cart.ham, nil)
	end,

	["the cart never exceeds the delivery limit and every low item gets a box"] = function()
		local cart = Restock.suggest(ING, { dough = 0, cheese = 0, ham = 0 }, CAP, 5, 4)
		T.eq(count(cart), 4)
		T.ok((cart.dough or 0) >= 1 and (cart.cheese or 0) >= 1 and (cart.ham or 0) >= 1, "one each first")
	end,

	["never suggests more than fits"] = function()
		local cart = Restock.suggest(ING, { dough = 5, cheese = 0, ham = 0 }, CAP, 5, 99)
		T.eq(cart.dough, 2, "31 free -> 2 whole boxes")
		T.eq(cart.cheese, 3)
		T.eq(cart.ham, 3)
	end,
}
