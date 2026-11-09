--!strict
-- Pure staff rules (no services, so they run in Lune tests).
-- Server: StaffService. Numbers: Config/Staff. Hiring: Config/Upgrades (`staff` field).

local Upgrades = require(script.Parent.Parent.Config.Upgrades)
local Config = require(script.Parent.Parent.Config.Staff)

local StaffRules = {}
StaffRules.Config = Config

-- Staff hired through owned upgrades: { [role] = count }.
function StaffRules.hired(owned: { [string]: any }?): { [string]: number }
	local out: { [string]: number } = {}
	for id, has in owned or {} do
		local u = has and Upgrades.get(id)
		if u and u.staff and Config.Roles[u.staff] then
			out[u.staff] = (out[u.staff] or 0) + 1
		end
	end
	return out
end

-- The upgrade that hires a role (nil if none).
function StaffRules.upgradeFor(role: string): any?
	for _, u in Upgrades.List do
		if u.staff == role then
			return u
		end
	end
	return nil
end

export type CashierMemo = { customer: any?, since: number }

-- One cashier check. `front` is the customer at the register (or nil),
-- `posCustomer` the one a player has the POS open for. Returns true when the
-- cashier should take `front`'s order now. A customer must wait `delay`
-- seconds first, and the cashier never takes one a player is serving.
function StaffRules.cashierStep(memo: CashierMemo, front: any?, posCustomer: any?, now: number, delay: number): boolean
	if not front or posCustomer == front then
		memo.customer = nil
		return false
	end
	if memo.customer ~= front then
		memo.customer = front
		memo.since = now
		return false
	end
	return now - memo.since >= delay
end

-- The closest job to `from` (jobs have a `position: Vector3`), or nil.
function StaffRules.nearest(jobs: { any }, from: Vector3): any?
	local best, bestDist = nil, math.huge
	for _, job in jobs do
		local d = (job.position - from).Magnitude
		if d < bestDist then
			best, bestDist = job, d
		end
	end
	return best
end

return StaffRules
