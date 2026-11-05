--!strict
-- Server bootstrap. Every service is a ModuleScript with optional
-- init(services) and start(). init runs for all services before any start.

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"DataService",
	"MeshService", -- loads Blender meshes before anything builds models
	"ProgressService",
	"UpgradeService",
	"GoalService", -- daily goals + streaks
	"ShiftService", -- day / shift cycle, rushes, end-of-day summary
	"HeldService",
	"StationService",
	"CleaningService",
	"SupplyService",
	"CustomerService",
	"PlotService", -- last: claiming plots uses all the others
	"DevService", -- Studio-only test hooks
}

local registry: { [string]: any } = {}
for _, name in ORDER do
	registry[name] = require(Services:WaitForChild(name)) :: any
end
for _, name in ORDER do
	local s = registry[name]
	if s.init then
		s.init(registry)
	end
end
-- DataService starts LAST so every onLoaded listener is registered before
-- the first profile finishes loading.
local START_ORDER = table.clone(ORDER)
table.remove(START_ORDER, table.find(START_ORDER, "DataService"))
table.insert(START_ORDER, "DataService")
for _, name in START_ORDER do
	local s = registry[name]
	if s.start then
		local ok, err = pcall(s.start)
		if not ok then
			warn("[Main] " .. name .. ".start failed: " .. tostring(err))
		end
	end
end

print("[Pizza Planet] server started")
