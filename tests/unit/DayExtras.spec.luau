-- Day-cycle extras (TASKS #19): the "Before you open" checklist and the
-- clock-driven sky (Shared/Shift/Checklist, Shared/Shift/Sky).

local Loader = require("../lib/Loader")
local T = require("../lib/T")

local Checklist = Loader.module("Shared/Shift/Checklist")
local Sky = Loader.module("Shared/Shift/Sky")
local Challenges = Loader.module("Shared/Config/Challenges")

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

local function fullStock(level: number, upgrades)
	local stock = {}
	for _, id in Checklist.neededIngredients(level, upgrades) do
		stock[id] = 10
	end
	return stock
end

return {
	["level 1 menu needs dough, sauce, cheese, boxes, cups and syrup"] = function()
		local need = Checklist.neededIngredients(1, {})
		for _, id in { "dough", "tomato_sauce", "mozzarella", "pizza_box", "cup", "cola_syrup" } do
			T.ok(has(need, id), "missing " .. id)
		end
	end,

	["kebab stock only counts once the kebab station is owned"] = function()
		T.ok(not has(Checklist.neededIngredients(8, {}), "kebab_wrapper"), "kebab packaging needed without a station")
		T.ok(has(Checklist.neededIngredients(8, { kebab_station = true }), "kebab_wrapper"))
	end,

	["all three checks pass on a stocked, clean, empty kitchen"] = function()
		local r = Checklist.build({ stock = fullStock(3, {}), level = 3, upgrades = {}, cleanliness = 100, cookersBusy = 0 })
		T.eq(#r.items, 3)
		T.eq(r.ready, true)
		for _, it in r.items do
			T.eq(it.ok, true, it.id)
		end
	end,

	["each problem is reported on its own line"] = function()
		local stock = fullStock(3, {})
		stock.mozzarella = 0
		stock.cup = nil
		local r = Checklist.build({ stock = stock, level = 3, upgrades = {}, cleanliness = 82.4, cookersBusy = 2 })
		T.eq(r.ready, false)
		local byId = {}
		for _, it in r.items do
			byId[it.id] = it
		end
		T.eq(byId.stock.ok, false)
		T.ok(string.find(byId.stock.text, "Mozzarella", 1, true) ~= nil, byId.stock.text)
		T.ok(string.find(byId.stock.text, "Drink Cups", 1, true) ~= nil, byId.stock.text)
		T.eq(byId.clean.ok, false)
		T.ok(string.find(byId.clean.text, "82%", 1, true) ~= nil, byId.clean.text)
		T.eq(byId.ovens.ok, false)
		T.ok(string.find(byId.ovens.text, "2 leftover items", 1, true) ~= nil, byId.ovens.text)
	end,

	["a long out-of-stock list is shortened"] = function()
		local r = Checklist.build({ stock = {}, level = 10, upgrades = {}, cleanliness = 100, cookersBusy = 0 })
		T.ok(string.find(r.items[1].text, "more", 1, true) ~= nil, r.items[1].text)
	end,

	["sky follows the shift clock and darkens after dusk"] = function()
		local clock, night = Sky.at(nil)
		T.eq(clock, Sky.IDLE_CLOCK)
		T.eq(night, 0)
		clock, night = Sky.at(10 * 60)
		T.eq(clock, 10)
		T.eq(night, 0)
		local _, dusk = Sky.at(19.25 * 60)
		T.ok(dusk > 0 and dusk < 1, "no dusk blend")
		clock, night = Sky.at(21.5 * 60)
		T.eq(clock, 21.5)
		T.eq(night, 1)
	end,

	["rush goal template exists and is in the weekly pool"] = function()
		local t = Challenges.ById.rush
		T.ok(t, "no rush template")
		T.eq(t.event, "rush_order")
		T.ok(table.find(Challenges.Weekly.Ids, "rush") ~= nil)
	end,
}
