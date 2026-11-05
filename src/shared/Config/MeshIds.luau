--!strict
-- Blender meshes (blender/scripts/pp_props.py -> blender/export/*.fbx ->
-- uploaded as Roblox Model assets). Set assetId to the uploaded Model id.
-- assetId = 0 means "not uploaded yet": the game uses the procedural parts.
--
-- size = the prop's real size in studs (X, Y up, Z) as built in Blender.
-- The loader rescales the imported model to exactly this size, so FBX unit
-- quirks don't matter. Parts are named <Prop>_<Role>; roles are coloured in
-- code (see FoodVisuals / RestaurantBuilder).

export type MeshInfo = { assetId: number, size: Vector3 }

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
} :: { [string]: MeshInfo }
