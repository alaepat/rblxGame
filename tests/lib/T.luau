-- Minimal test helpers. Each spec returns a table of name -> function.

local T = {}

function T.eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", tostring(expected), tostring(actual)), 2)
	end
end

function T.ok(value: any, msg: string?)
	if not value then
		error(msg or "expected a truthy value", 2)
	end
end

function T.near(actual: number, expected: number, tol: number, msg: string?)
	if math.abs(actual - expected) > tol then
		error(("%sexpected %s ± %s, got %s"):format(msg and (msg .. ": ") or "", tostring(expected), tostring(tol), tostring(actual)), 2)
	end
end

return T
