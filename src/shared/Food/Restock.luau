--!strict
-- Pure rule for the office tablet's "Quick restock": suggest a supply cart
-- that tops up every unlocked ingredient running low.
--
-- An ingredient is "low" below LowShare of its capacity. Each low ingredient
-- gets as many whole boxes as fit under its capacity (never more, so the
-- server's storage check always accepts it). The emptiest go first, and the
-- cart never exceeds maxBoxes in total.

local Restock = {}

Restock.LowShare = 1 / 3

export type Ing = { id: string, level: number, boxSize: number }

function Restock.suggest(
	ingredients: { Ing },
	stock: { [string]: number },
	capacity: { [string]: number },
	level: number,
	maxBoxes: number
): { [string]: number }
	local low = {}
	for _, ing in ingredients do
		local cap = capacity[ing.id] or 0
		local have = stock[ing.id] or 0
		if ing.level <= level and cap > 0 and have < cap * Restock.LowShare then
			local boxes = math.floor((cap - have) / ing.boxSize)
			if boxes > 0 then
				table.insert(low, { id = ing.id, boxes = boxes, fill = have / cap })
			end
		end
	end
	table.sort(low, function(a, b)
		if a.fill ~= b.fill then
			return a.fill < b.fill
		end
		return a.id < b.id
	end)
	local cart: { [string]: number } = {}
	local left = maxBoxes
	-- one box each first, emptiest first, so a big top-up can't crowd out the rest
	for _, l in low do
		if left <= 0 then
			break
		end
		cart[l.id] = 1
		left -= 1
	end
	for _, l in low do
		if left <= 0 then
			break
		end
		local more = math.min(l.boxes - (cart[l.id] or 0), left)
		if more > 0 then
			cart[l.id] = (cart[l.id] or 0) + more
			left -= more
		end
	end
	return cart
end

return Restock
