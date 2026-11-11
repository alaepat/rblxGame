--!strict
-- Delta encoding for the per-player State snapshot (ProgressService -> client
-- Controllers/State). The full snapshot is ~3.8 KB and was sent ~2x a second
-- during a shift although most of it (stock, capacity, upgrades, recipes)
-- rarely changes. Now only top-level keys that changed are sent.
--
-- Server: local delta, nextSent = StateDelta.diff(lastSent, snap)
--   lastSent holds DEEP COPIES of what was sent: the snapshot contains live
--   profile tables, so comparing against the same references would always
--   look unchanged.
-- Client: StateDelta.apply(data, delta)
-- A delta is { set = { [key] = value }?, removed = { key }?, full = true? }.
-- Pure (no Roblox APIs), tested in tests/unit/StateDelta.spec.luau.

local StateDelta = {}

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

StateDelta.deepCopy = deepCopy
StateDelta.deepEqual = deepEqual

-- Returns (delta or nil when nothing changed, the new lastSent).
-- lastSent = nil means the client has nothing yet: send everything.
function StateDelta.diff(lastSent: { [string]: any }?, snap: { [string]: any }): (any?, { [string]: any })
	local nextSent = {}
	if not lastSent then
		for k, v in snap do
			nextSent[k] = deepCopy(v)
		end
		return { full = true, set = snap }, nextSent
	end
	local set, removed = {}, {}
	local any = false
	for k, v in snap do
		local old = lastSent[k]
		if deepEqual(old, v) then
			nextSent[k] = old
		else
			set[k] = v
			nextSent[k] = deepCopy(v)
			any = true
		end
	end
	for k in lastSent do
		if snap[k] == nil then
			table.insert(removed, k)
			any = true
		end
	end
	if not any then
		return nil, nextSent
	end
	return { set = if next(set) then set else nil, removed = if #removed > 0 then removed else nil }, nextSent
end

-- Applies a delta to the client's data table (in place) and returns it.
function StateDelta.apply(data: { [string]: any }, delta: any): { [string]: any }
	if type(delta) ~= "table" then
		return data
	end
	if delta.full then
		table.clear(data)
	end
	for k, v in delta.set or {} do
		data[k] = v
	end
	for _, k in delta.removed or {} do
		data[k] = nil
	end
	return data
end

return StateDelta
