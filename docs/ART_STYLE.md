# Art Style Guide

Target: polished, stylised, "medium-poly" props in the spirit of modern Roblox restaurant simulators. Not photoreal, not blocky default Roblox. **Everything must be original.**

## Principles

1. **Clean primitives, soft shapes.** Build food from discs, ellipsoids (sphere meshes) and thin slabs that overlap slightly so nothing floats. Use bevel strips (thin darker or lighter edge parts) on counters and furniture.
2. **SmoothPlastic for food**, Metal/DiamondPlate for kitchen steel, Wood/WoodPlanks for tables and floors, CeramicTiles for the kitchen, Brick/Plaster for the building.
3. **Warm, saturated palette** (see `Build.C` and `Theme.Colors`):
   brand red `#D62828`, brand yellow `#FFC428`, steel `#C8CCD2`, terracotta floor `#C6603C`, cream `#F6EAD0`.
4. **Readable silhouettes.** A player should recognise every ingredient from 6 studs away. Toppings use a distinct *shape* per ingredient (`Ingredients.shape`): disc, slice, ring, strip, chunk, mushroom, crumble, shred, leaf, meat, drizzle.
5. **Scale**: a character is about 5 studs tall, counters are 3.2 studs high, a pizza is 2.4 studs across, ceilings are 13 studs.
6. **Lighting**: warm interior SurfaceLights, orange glows (heat lamps, oven embers), neon only for signs and lamps.

## Blender pipeline (for assets that need real meshes)

When a prop needs curves primitives can't do (pizza box hinge, kebab wrap folds, chairs with curved backs):

1. Model in Blender at **1 Blender unit = 1 stud** (Scene → Unit Scale 1.0, Metric, but treat metres as studs).
2. Keep it under ~2k tris per prop and ~500 per food item. Apply all transforms, and put the origin at the **bottom centre**.
3. Use flat colours or a small palette texture (one material per colour region), no PBR maps unless needed.
4. Export FBX (Apply Scalings: FBX All, Forward -Z, Up Y), then import with **Studio → 3D Importer**. Upload it as a MeshPart and record the asset id in `src/shared/Config/` (planned file: `MeshIds.luau`, with a fallback to the procedural model).
5. Commit the `.blend` source under `blender/` and the generation script under `blender/scripts/` when you use Blender Python.

Until a mesh exists, the procedural builders in `FoodVisuals` / `RestaurantBuilder` are the shipped look, so keep them looking good.
