-- Every source file must at least compile (catches syntax errors before Studio).

local luau = require("@lune/luau")
local Loader = require("../lib/Loader")

return {
	["every src file compiles"] = function()
		local bad = {}
		local count = 0
		for path, source in Loader.files do
			count += 1
			local ok, err = pcall(luau.compile, source)
			if not ok then
				table.insert(bad, path .. ": " .. tostring(err))
			end
		end
		assert(count > 30, "expected the whole src tree, found " .. count .. " files")
		assert(#bad == 0, table.concat(bad, "\n"))
	end,
}
