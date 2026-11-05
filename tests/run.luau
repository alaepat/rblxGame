-- Offline test runner (Lune). From the repo root:
--   lune run tests/run.luau
-- Runs every tests/unit/*.spec.luau. Each spec returns { [name] = function }.

local fs = require("@lune/fs")
local process = require("@lune/process")

local specs = {}
for _, f in fs.readDir("tests/unit") do
	if f:sub(-10) == ".spec.luau" then
		table.insert(specs, f)
	end
end
table.sort(specs)

local passed, failed = 0, 0
for _, f in specs do
	local suite = require("./unit/" .. f:sub(1, -6))
	local names = {}
	for name in suite do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local ok, err = pcall(suite[name])
		if ok then
			passed += 1
		else
			failed += 1
			print(("FAIL  %s > %s\n      %s"):format(f, name, tostring(err)))
		end
	end
end

print(("%d passed, %d failed"):format(passed, failed))
process.exit(if failed > 0 then 1 else 0)
