--!strict
-- Blender meshes (blender/scripts/pp_props.py -> blender/export/*.fbx ->
-- uploaded as Roblox Model assets). Set assetId to the uploaded Model id.
-- assetId = 0 means "not uploaded yet": the game uses the procedural parts.
--
-- size = the prop's real size in studs (X, Y up, Z) as built in Blender.
-- The loader rescales the imported model to exactly this size, so FBX unit
-- quirks don't matter. Parts are named <Prop>_<Role>; roles are coloured in
-- code (see FoodVisuals / RestaurantBuilder).

-- center = bbox centre relative to the prop's Blender origin (x, 0, z),
-- printed by pp_props.py as a "[pp-lua]" line. Omit for symmetric props.
export type MeshInfo = { assetId: number, size: Vector3, center: Vector3? }

return {
	Tray = { assetId = 74801280720242, size = Vector3.new(2.6, 0.22, 1.9) },
	PizzaBox = { assetId = 77497405824044, size = Vector3.new(2.72, 0.44, 2.74) },
	Cup = { assetId = 92636755840275, size = Vector3.new(0.674, 1.806, 0.674) },
	Pizza = { assetId = 75772657593749, size = Vector3.new(2.4, 0.232, 2.4) },
	Pan = { assetId = 75355237638471, size = Vector3.new(1.03, 0.343, 0.94) },
	Chair = { assetId = 83745013241204, size = Vector3.new(2.029, 3.59, 1.6) },
	Table = { assetId = 92174867220620, size = Vector3.new(3.24, 3.05, 3.24) },
	FoodBox = { assetId = 99181578547885, size = Vector3.new(1.74, 0.72, 1.29) },
	Bottle = { assetId = 126043155864298, size = Vector3.new(0.5, 1.31, 0.5) },
	-- batch 2
	CounterModule = { assetId = 136575518841113, size = Vector3.new(2.18, 3.05, 2.675), center = Vector3.new(0, 0, 0.087) },
	CounterTop = { assetId = 108085486428461, size = Vector3.new(2.2, 0.15, 2.73), center = Vector3.new(0, 0, 0.065) },
	Oven = { assetId = 102619920759537, size = Vector3.new(6.1, 9.48, 6.297), center = Vector3.new(0, 0, 0.277) },
	Fridge = { assetId = 109833127403653, size = Vector3.new(4.0, 8.0, 2.88), center = Vector3.new(0, 0, 0.14) },
	MeatCone = { assetId = 127751619282514, size = Vector3.new(1.8, 3.62, 1.8) },
	ChipsBasket = { assetId = 96443753849525, size = Vector3.new(2.805, 0.635, 0.96), center = Vector3.new(0.722, 0, 0) },
	Pitta = { assetId = 133882486226033, size = Vector3.new(1.7, 0.34, 1.069), center = Vector3.new(0.013, 0, -0.01) },
	WrapRoll = { assetId = 114164787975862, size = Vector3.new(1.76, 0.69, 0.69), center = Vector3.new(-0.03, 0, 0) },
	KebabPaper = { assetId = 88859290777596, size = Vector3.new(1.83, 0.61, 1.13) },
	-- batch 3 (uploaded, NOT yet wired into the builders - see TASKS #5)
	Awning = { assetId = 110910852509985, size = Vector3.new(2.0, 2.81, 4.14), center = Vector3.new(0, 0, 1.96) },
	DoorLeaf = { assetId = 117465565905076, size = Vector3.new(3.3, 8.2, 0.37), center = Vector3.new(0, 0, 0.095) },
	Hood = { assetId = 78189935457667, size = Vector3.new(12.8, 5.5, 6.5) },
	WallLamp = { assetId = 98581202296636, size = Vector3.new(0.72, 1.24, 1.092), center = Vector3.new(0, 0, 0.466) },
	StreetLamp = { assetId = 84333486745577, size = Vector3.new(1.5, 13.7, 4.0), center = Vector3.new(0, 0, 1.55) },
	Planter = { assetId = 120604147995887, size = Vector3.new(5.2, 2.885, 2.2) },
	Parasol = { assetId = 103836274296009, size = Vector3.new(7.015, 8.225, 7.015) },
	Bench = { assetId = 119556240349489, size = Vector3.new(6.0, 3.2, 1.61) },
} :: { [string]: MeshInfo }
