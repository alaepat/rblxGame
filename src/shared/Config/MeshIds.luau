--!strict
-- Blender meshes (blender/scripts/pp_props.py -> blender/export/*.fbx ->
-- uploaded as Roblox Model assets OWNED BY THE GROUP 33618867, so every
-- member can load them in the group's place "Pizza p" (73027696649968)).
-- Upload new meshes with creator groupId 33618867 while the group place is
-- open in Studio. Set assetId to the uploaded Model id.
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
	Tray = { assetId = 100952339544570, size = Vector3.new(2.6, 0.22, 1.9) },
	PizzaBox = { assetId = 133115608071482, size = Vector3.new(2.72, 0.439, 2.74), center = Vector3.new(0, 0, 0.01) },
	Cup = { assetId = 83502075004064, size = Vector3.new(0.674, 1.806, 0.674) },
	Pizza = { assetId = 90536093426442, size = Vector3.new(2.41, 0.263, 2.412) },
	Pan = { assetId = 140532841063969, size = Vector3.new(1.03, 0.343, 0.94) },
	Chair = { assetId = 96409732756145, size = Vector3.new(2.088, 3.659, 1.6) },
	Table = { assetId = 117588014145096, size = Vector3.new(3.24, 3.05, 3.24) },
	FoodBox = { assetId = 116756060587897, size = Vector3.new(1.74, 0.72, 1.29) },
	Bottle = { assetId = 92156035906603, size = Vector3.new(0.5, 1.31, 0.5) },
	-- batch 2
	CounterModule = { assetId = 106148284272967, size = Vector3.new(2.18, 3.05, 2.675), center = Vector3.new(0, 0, 0.087) },
	CounterTop = { assetId = 100997671247264, size = Vector3.new(2.2, 0.15, 2.73), center = Vector3.new(0, 0, 0.065) },
	Oven = { assetId = 135873767760139, size = Vector3.new(6.1, 9.48, 6.297), center = Vector3.new(0, 0, 0.277) },
	Fridge = { assetId = 88924751658484, size = Vector3.new(4.0, 8.0, 2.88), center = Vector3.new(0, 0, 0.14) },
	MeatCone = { assetId = 111996560476292, size = Vector3.new(1.8, 3.62, 1.8) },
	ChipsBasket = { assetId = 138559971146832, size = Vector3.new(2.805, 0.635, 0.96), center = Vector3.new(0.722, 0, 0) },
	Pitta = { assetId = 127338585348133, size = Vector3.new(1.7, 0.34, 1.069), center = Vector3.new(0.013, 0, -0.01) },
	WrapRoll = { assetId = 75076777802049, size = Vector3.new(1.76, 0.69, 0.69), center = Vector3.new(-0.03, 0, 0) },
	KebabPaper = { assetId = 105668673258663, size = Vector3.new(1.83, 0.61, 1.13) },
	-- batch 3 (uploaded, NOT yet wired into the builders - see TASKS #5)
	Awning = { assetId = 133591962222025, size = Vector3.new(2.0, 2.81, 4.14), center = Vector3.new(0, 0, 1.96) },
	DoorLeaf = { assetId = 130709181428802, size = Vector3.new(3.3, 8.2, 0.37), center = Vector3.new(0, 0, 0.095) },
	Hood = { assetId = 73381779750199, size = Vector3.new(12.8, 5.5, 6.5) },
	WallLamp = { assetId = 82395390868199, size = Vector3.new(0.72, 1.24, 1.092), center = Vector3.new(0, 0, 0.466) },
	StreetLamp = { assetId = 89255146888401, size = Vector3.new(1.5, 13.7, 4.0), center = Vector3.new(0, 0, 1.55) },
	Planter = { assetId = 105611147092299, size = Vector3.new(5.2, 2.885, 2.2) },
	Parasol = { assetId = 98336263174436, size = Vector3.new(7.015, 8.225, 7.015) },
	Bench = { assetId = 79792198690539, size = Vector3.new(6.0, 3.2, 1.61) },
	-- batch 4: realistic food. Toppings are scattered by FoodVisuals.scatter;
	-- each ingredient maps to one of these via Ingredients[id].mesh.
	Top_Pepperoni = { assetId = 132708905496351, size = Vector3.new(0.421, 0.059, 0.424) },
	Top_Cucumber = { assetId = 99056568786859, size = Vector3.new(0.434, 0.047, 0.434) },
	Top_Jalapeno = { assetId = 100745280708148, size = Vector3.new(0.36, 0.038, 0.36) },
	Top_Tomato = { assetId = 108500536920851, size = Vector3.new(0.441, 0.063, 0.44) },
	Top_Onion = { assetId = 110791742696541, size = Vector3.new(0.323, 0.035, 0.277) },
	Top_Olive = { assetId = 106953719837716, size = Vector3.new(0.26, 0.067, 0.234) },
	Top_Ham = { assetId = 95260165547842, size = Vector3.new(0.359, 0.037, 0.329), center = Vector3.new(0, 0, 0.006) },
	Top_Pepper = { assetId = 125142275716123, size = Vector3.new(0.471, 0.041, 0.143), center = Vector3.new(0, 0, -0.042) },
	Top_Chicken = { assetId = 135666641349528, size = Vector3.new(0.247, 0.139, 0.211) },
	Top_Mushroom = { assetId = 79037811914890, size = Vector3.new(0.337, 0.04, 0.27), center = Vector3.new(0, 0, -0.045) },
	Top_Beef = { assetId = 133888893136732, size = Vector3.new(0.174, 0.13, 0.158) },
	Top_Shred = { assetId = 86308502065344, size = Vector3.new(0.352, 0.039, 0.155) },
	Top_Leaf = { assetId = 115470518778846, size = Vector3.new(0.429, 0.044, 0.302) },
	Top_Doner = { assetId = 108627235631616, size = Vector3.new(0.494, 0.103, 0.191) },
	Top_Chip = { assetId = 114589607399740, size = Vector3.new(0.102, 0.154, 0.501) },
	Top_Drizzle = { assetId = 113062061655057, size = Vector3.new(0.533, 0.043, 0.137) },
	Top_Cheese = { assetId = 137817530042986, size = Vector3.new(0.359, 0.038, 0.338) },
	Dough = { assetId = 95372258162967, size = Vector3.new(1.163, 0.581, 1.167) },
	-- batch 5: window frame bar (stretched along X only), bar stool, fryer
	FrameBar = { assetId = 115857397559140, size = Vector3.new(1.0, 0.3, 0.4) },
	BarStool = { assetId = 74141681472715, size = Vector3.new(1.328, 2.96, 1.328) },
	Fryer = { assetId = 130922144744795, size = Vector3.new(3.2, 4.45, 2.75), center = Vector3.new(0, 0, 0.075) },
	-- batch 6: signs (SignEdge is stretched along X only, like FrameBar)
	SignEdge = { assetId = 83193486869641, size = Vector3.new(1.0, 0.4, 0.5) },
	PlanetSign = { assetId = 139691759114222, size = Vector3.new(10.196, 8.198, 9.359) },
	PylonPost = { assetId = 90802276290684, size = Vector3.new(2.6, 13.2, 2.6) },
	BladeSign = { assetId = 123176828026409, size = Vector3.new(0.5, 3.12, 2.99), center = Vector3.new(0, 0, 1.375) },
	-- batch 7: booths + wall art
	BoothBench = { assetId = 96242616828243, size = Vector3.new(5.3, 4.69, 1.915), center = Vector3.new(0, 0, -0.118) },
	BoothTable = { assetId = 113308669714267, size = Vector3.new(4.86, 3.1, 2.86) },
	ArtFrame = { assetId = 94565831609919, size = Vector3.new(4.4, 3.6, 0.24) },
	-- batch 8: counter + kitchen small kit
	SodaFountain = { assetId = 119417281640965, size = Vector3.new(4.9, 3.475, 2.275), center = Vector3.new(0, 0, 0.337) },
	CupDispenser = { assetId = 130604270262197, size = Vector3.new(1.15, 2.32, 1.15) },
	TrashBin = { assetId = 71794392566975, size = Vector3.new(1.8, 3.05, 1.955), center = Vector3.new(0, 0, 0.077) },
	TableCaddy = { assetId = 79044713988627, size = Vector3.new(1.0, 0.46, 0.42), center = Vector3.new(0.2, 0, 0) },
	PosStand = { assetId = 124388931664964, size = Vector3.new(1.5, 1.4, 1.1) },
	PosBezel = { assetId = 88121116312328, size = Vector3.new(2.48, 1.78, 0.2) },
	ReceiptPrinter = { assetId = 116392517674987, size = Vector3.new(0.95, 0.901, 0.885), center = Vector3.new(0, 0, 0.017) },
	-- batch 9: pass gantry, topping rail, office
	HeatGantry = { assetId = 71595629320522, size = Vector3.new(5.32, 3.29, 2.4) },
	PrepRail = { assetId = 73026490156096, size = Vector3.new(7.4, 2.526, 0.986), center = Vector3.new(0, 0, -0.837) },
	OfficeDesk = { assetId = 73097168853578, size = Vector3.new(7.9, 3.1, 3.6) },
	OfficeChair = { assetId = 119032957325578, size = Vector3.new(2.16, 4.189, 2.06), center = Vector3.new(0, 0, -0.131) },
	-- batch 10: cardboard carton (supply deliveries + shelf stock)
	Carton = { assetId = 95027878322945, size = Vector3.new(2.054, 1.31, 1.557) },
	-- batch 11: bread/dough crate, wrap bag (supply deliveries)
	BreadCrate = { assetId = 111231115801169, size = Vector3.new(2.06, 0.85, 1.56) },
	WrapBag = { assetId = 135897378095810, size = Vector3.new(1.622, 0.379, 1.773), center = Vector3.new(0, 0, -0.033) },
	-- batch 12: dessert station
	SoftServe = { assetId = 93997739963883, size = Vector3.new(2.4, 3.06, 1.879), center = Vector3.new(0, 0, 0.14) },
	SundaeCup = { assetId = 73563700374291, size = Vector3.new(0.721, 1.239, 0.714) },
	-- batch 13: calzone (origin on the fold line, curved edge towards +Z)
	Calzone = { assetId = 100955893835592, size = Vector3.new(2.356, 0.512, 1.223), center = Vector3.new(0, 0, 0.567) },
	-- batch 14 (pass 10): kitchen mixer, office PC, staff room, storage shelving
	StandMixer = { assetId = 100311907493615, size = Vector3.new(1.3, 2.34, 1.555), center = Vector3.new(0, 0, 0.047) },
	Monitor = { assetId = 101145274556401, size = Vector3.new(4.0, 3.2, 0.95), center = Vector3.new(0, 0, -0.2) },
	Keyboard = { assetId = 109448988509586, size = Vector3.new(3.078, 0.13, 0.72), center = Vector3.new(0.339, 0, 0) },
	Locker = { assetId = 104714188522326, size = Vector3.new(1.5, 7.0, 1.61), center = Vector3.new(0, 0, 0.055) },
	Vending = { assetId = 74853889740033, size = Vector3.new(2.6, 7.2, 2.285), center = Vector3.new(0, 0, 0.042) },
	WireShelf = { assetId = 138164528767081, size = Vector3.new(7.68, 7.0, 2.48) },
} :: { [string]: MeshInfo }
