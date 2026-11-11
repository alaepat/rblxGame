--!strict
-- What DataStore can save (TASKS #14). DataStoreService turns a profile into
-- JSON, so it rejects (or silently mangles) a few kinds of value:
--  * functions, userdata (Vector3, CFrame, Instance, Color3 ...), threads
--  * NaN and ±inf numbers
--  * tables mixing array slots with other keys, sparse arrays, non-string
--    dictionary keys (a number key in a dictionary comes back as a string)
--  * a table that contains itself (cycles)
-- Storable.problems(value) lists every such spot as "path: reason", so the
-- server can warn before a save is lost. Pure: used by DataService + tests.

local Storable = {}

local MAX_DEPTH = 32

local function isArray(t: { [any]: any }): (boolean, number)
	local n = 0
	for k in t do
		if type(k) ~= "number" then
			return false, 0
		end
		n += 1
	end
	return true, n
end

local function walk(value: any, path: string, depth: number, seen: { [any]: boolean }, out: { string })
	local kind = type(value)
	if kind == "string" or kind == "boolean" then
		return
	elseif kind == "number" then
		if value ~= value then
			table.insert(out, path .. ": NaN")
		elseif value == math.huge or value == -math.huge then
			table.insert(out, path .. ": infinite number")
		end
		return
	elseif kind ~= "table" then
		table.insert(out, path .. ": can't save a " .. typeof(value))
		return
	end
	if seen[value] then
		table.insert(out, path .. ": table contains itself (cycle)")
		return
	end
	if depth > MAX_DEPTH then
		table.insert(out, path .. ": nested too deep")
		return
	end
	seen[value] = true
	local array, n = isArray(value)
	if array and n > 0 then
		for i = 1, n do
			if value[i] == nil then
				table.insert(out, path .. ": sparse array (missing index " .. i .. ")")
				break
			end
		end
		for i = 1, n do
			if value[i] ~= nil then
				walk(value[i], path .. "[" .. i .. "]", depth + 1, seen, out)
			end
		end
	else
		for k, v in value do
			local kp = if type(k) == "string" then path .. "." .. k else path .. "[" .. tostring(k) .. "]"
			if type(k) ~= "string" then
				table.insert(out, kp .. ": dictionary key is a " .. typeof(k) .. ", not a string")
			end
			walk(v, kp, depth + 1, seen, out)
		end
	end
	seen[value] = nil
end

-- Every spot DataStore would refuse or change ({} if the value is fine).
function Storable.problems(value: any, root: string?): { string }
	local out = {}
	walk(value, root or "profile", 0, {}, out)
	return out
end

function Storable.ok(value: any): boolean
	return #Storable.problems(value) == 0
end

return Storable
