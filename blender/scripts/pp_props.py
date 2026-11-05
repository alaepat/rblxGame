"""
Pizza Planet - procedural prop generator for Blender 3.4+.

Builds smooth, bevelled, stylised props and exports one FBX per prop to
blender/export/<Prop>.fbx. Run headless from the repo root:

    "C:/Program Files/Blender Foundation/Blender 3.4/blender.exe" -b --factory-startup \
        --python blender/scripts/pp_props.py -- [PropName ...]

Conventions (see docs/ART_STYLE.md):
  * 1 Blender unit = 1 Roblox stud, Z up in Blender (exported as Y up).
  * Each prop is a set of objects named  <Prop>_<Role>; the game colours each
    MeshPart by its Role (see src/shared/Config/MeshIds.luau), so no textures
    are needed and one mesh can be re-coloured (raw/cooked crust etc).
  * Origin of every prop = bottom centre (z = 0 at the bottom).
"""

import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXPORT_DIR = os.path.join(ROOT, "blender", "export")


# --------------------------------------------------------------- helpers

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def active():
    return bpy.context.view_layer.objects.active


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def apply_mods(obj):
    select_only([obj])
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def smooth(obj, angle=40):
    select_only([obj])
    bpy.ops.object.shade_smooth()
    obj.data.use_auto_smooth = True
    obj.data.auto_smooth_angle = math.radians(angle)


def name(obj, n):
    obj.name = n
    obj.data.name = n
    return obj


def rounded_box(n, sx, sy, sz, radius, segments=5, loc=(0, 0, 0)):
    """Box with rounded edges. sx/sy/sz are full sizes, loc = centre."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = active()
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    b = o.modifiers.new("bevel", "BEVEL")
    b.width = min(radius, sx / 2.05, sy / 2.05, sz / 2.05)
    b.segments = segments
    b.limit_method = "NONE"
    apply_mods(o)
    smooth(o)
    return name(o, n)


def cylinder(n, r, depth, loc=(0, 0, 0), verts=40, r2=None, bevel=0.0, seg=3):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc)
    o = active()
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = seg
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(50)
        apply_mods(o)
    smooth(o, 50)
    return name(o, n)


def torus(n, major, minor, loc=(0, 0, 0), maj_seg=48, min_seg=16):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=maj_seg,
                                     minor_segments=min_seg, location=loc)
    o = active()
    smooth(o, 80)
    return name(o, n)


def sphere(n, r, loc=(0, 0, 0), scale=(1, 1, 1), seg=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    o = active()
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    smooth(o, 80)
    return name(o, n)


def boolean_diff(target, cutter):
    m = target.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.solver = "EXACT"
    m.object = cutter
    apply_mods(target)
    bpy.data.objects.remove(cutter, do_unlink=True)
    smooth(target)
    return target


def join(objs, n):
    select_only(objs)
    bpy.ops.object.join()
    o = active()
    smooth(o)
    return name(o, n)


def wobble_edge(obj, amount, seed):
    """Push outer-ring vertices in/out a little for an organic edge (sauce, cheese)."""
    rnd = random.Random(seed)
    me = obj.data
    phase = [rnd.uniform(0, math.tau) for _ in range(3)]
    for v in me.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if r > 0.05:
            a = math.atan2(v.co.y, v.co.x)
            k = 1 + amount * (0.6 * math.sin(3 * a + phase[0]) + 0.3 * math.sin(7 * a + phase[1])
                              + 0.2 * math.sin(13 * a + phase[2]))
            v.co.x *= k
            v.co.y *= k


def export(prop):
    objs = [o for o in bpy.data.objects if o.name.startswith(prop + "_")]
    for o in objs:
        apply_mods(o)
    select_only(objs)
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, prop + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
    )
    tris = 0
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    d = hi - lo
    # Roblox size: X, Y(up) = Blender Z, Z = Blender Y
    print(f"[pp] exported {prop}: {len(objs)} parts, {tris} tris, size=Vector3.new({d.x:.3f}, {d.z:.3f}, {d.y:.3f}) -> {path}")


# --------------------------------------------------------------- props

def build_Tray():
    # Serving tray: rounded dish with a raised rim and a paper liner.
    L, W, H = 2.6, 1.9, 0.22
    body = rounded_box("Tray_Body", L, W, H, 0.16, 6, (0, 0, H / 2))
    cut = rounded_box("cut", L - 0.22, W - 0.22, H, 0.12, 6, (0, 0, H / 2 + 0.07))
    boolean_diff(body, cut)
    rounded_box("Tray_Liner", L - 0.36, W - 0.36, 0.02, 0.08, 3, (0, 0, 0.085))
    # printed red border on the liner
    border = rounded_box("Tray_Print", L - 0.5, W - 0.5, 0.01, 0.07, 3, (0, 0, 0.1))
    inner = rounded_box("cut", L - 0.62, W - 0.62, 0.05, 0.05, 3, (0, 0, 0.1))
    boolean_diff(border, inner)
    # small grip slots on the short ends
    for sx in (-1, 1):
        slot = rounded_box("cut", 0.06, 0.6, 0.3, 0.03, 3, (sx * (L / 2 - 0.05), 0, H * 0.7))
        boolean_diff(body, slot)


def build_PizzaBox():
    S, H = 2.7, 0.42
    rounded_box("PizzaBox_Body", S, S, H, 0.05, 3, (0, 0, H / 2))
    band = rounded_box("PizzaBox_Trim", S + 0.02, S + 0.02, 0.07, 0.035, 2, (0, 0, H * 0.55))
    cut = rounded_box("cut", S - 0.05, S - 0.05, 0.2, 0.03, 2, (0, 0, H * 0.55))
    boolean_diff(band, cut)
    cylinder("PizzaBox_Logo", 0.52, 0.02, (0, 0, H + 0.005), 48)
    ring = torus("PizzaBox_Ring", 0.78, 0.045, (0, 0, H + 0.02))
    ring.scale = (1, 0.32, 0.25)
    ring.rotation_euler = (0, 0, math.radians(-18))
    select_only([ring])
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    # vent tab on the front edge
    rounded_box("PizzaBox_Tab", 0.5, 0.04, 0.12, 0.02, 2, (0, -S / 2 - 0.01, H * 0.7))


def build_Cup():
    h = 1.1
    cylinder("Cup_Body", 0.25, h, (0, 0, h / 2), 40, r2=0.31, bevel=0.02)
    cylinder("Cup_Band", 0.268, 0.26, (0, 0, 0.42), 40, r2=0.285)
    torus("Cup_Rim", 0.312, 0.025, (0, 0, h))
    cylinder("Cup_Lid", 0.335, 0.05, (0, 0, h + 0.03), 40, bevel=0.015)
    dome = sphere("Cup_Dome", 0.3, (0, 0, h + 0.05), (1, 1, 0.22))
    cut = rounded_box("cut", 1, 1, 0.5, 0.01, 1, (0, 0, h + 0.05 - 0.25))
    boolean_diff(dome, cut)
    straw = cylinder("Cup_Straw", 0.035, 0.75, (0.06, 0, h + 0.33), 16)
    straw.rotation_euler = (0, math.radians(-8), 0)
    select_only([straw])
    bpy.ops.object.transform_apply(rotation=True)


def build_Pizza():
    # Crust with a rolled rim + organic sauce + cheese layers (coloured in game).
    base = cylinder("Pizza_Crust", 1.18, 0.12, (0, 0, 0.06), 48, bevel=0.03, seg=2)
    rim = torus("rim", 1.08, 0.12, (0, 0, 0.13), 48, 12)
    rim.scale = (1, 1, 0.85)
    select_only([rim])
    bpy.ops.object.transform_apply(scale=True)
    join([base, rim], "Pizza_Crust")
    sauce = cylinder("Pizza_Sauce", 0.98, 0.035, (0, 0, 0.14), 48, bevel=0.012, seg=2)
    wobble_edge(sauce, 0.025, 1)
    cheese = cylinder("Pizza_Cheese", 0.9, 0.05, (0, 0, 0.165), 48, bevel=0.02, seg=2)
    wobble_edge(cheese, 0.06, 2)


def build_Pan():
    # Steel gastronorm pan used on every topping rail.
    W, D, H = 0.95, 0.86, 0.34
    body = rounded_box("Pan_Body", W, D, H, 0.06, 4, (0, 0, H / 2))
    cut = rounded_box("cut", W - 0.07, D - 0.07, H, 0.04, 4, (0, 0, H / 2 + 0.04))
    boolean_diff(body, cut)
    lip = rounded_box("Pan_Lip", W + 0.08, D + 0.08, 0.035, 0.03, 2, (0, 0, H - 0.015))
    hole = rounded_box("cut", W - 0.07, D - 0.07, 0.2, 0.04, 3, (0, 0, H))
    boolean_diff(lip, hole)
    rounded_box("Pan_Fill", W - 0.09, D - 0.09, H * 0.55, 0.05, 3, (0, 0, H * 0.34))


def build_Chair():
    # Modern cafe chair: moulded seat + curved back + tube legs.
    seat = rounded_box("Chair_Shell", 1.7, 1.6, 0.18, 0.08, 4, (0, 0, 1.85))
    back = rounded_box("back", 1.7, 0.16, 1.55, 0.07, 4, (0, -0.78, 2.75))
    bend = back.modifiers.new("bend", "SIMPLE_DEFORM")
    bend.deform_method = "BEND"
    bend.angle = math.radians(25)
    bend.deform_axis = "Z"
    apply_mods(back)
    back.rotation_euler = (math.radians(-8), 0, 0)
    select_only([back])
    bpy.ops.object.transform_apply(rotation=True)
    join([seat, back], "Chair_Shell")
    legs = []
    for x in (-0.68, 0.68):
        for y in (-0.62, 0.62):
            lg = cylinder("leg", 0.065, 1.78, (x, y, 0.89), 16)
            lg.rotation_euler = (math.radians(4 if y > 0 else -4), math.radians(-4 if x > 0 else 4), 0)
            legs.append(lg)
    for lg in legs:
        select_only([lg])
        bpy.ops.object.transform_apply(rotation=True)
    join(legs, "Chair_Legs")


def build_Table():
    top = rounded_box("Table_Top", 3.2, 3.2, 0.2, 0.09, 4, (0, 0, 2.95))
    edge = rounded_box("Table_Edge", 3.24, 3.24, 0.08, 0.05, 3, (0, 0, 2.84))
    hole = rounded_box("cut", 3.0, 3.0, 0.3, 0.05, 3, (0, 0, 2.84))
    boolean_diff(edge, hole)
    base = cylinder("b", 0.8, 0.1, (0, 0, 0.05), 40, bevel=0.03)
    pole = cylinder("p", 0.14, 2.75, (0, 0, 1.45), 24)
    join([base, pole], "Table_Base")


def build_FoodBox():
    W, D, H = 1.7, 1.25, 0.65
    body = rounded_box("FoodBox_Body", W, D, H, 0.05, 3, (0, 0, H / 2))
    # taper the box (wider at the top) like a takeaway clamshell
    for v in body.data.vertices:
        t = max(0.0, min(1.0, v.co.z / H))
        k = 0.88 + 0.12 * t
        v.co.x *= k
        v.co.y *= k
    cut = rounded_box("cut", W - 0.1, D - 0.1, H, 0.04, 3, (0, 0, H / 2 + 0.06))
    boolean_diff(body, cut)
    band = rounded_box("FoodBox_Band", W + 0.01, D + 0.01, 0.12, 0.04, 2, (0, 0, H * 0.35))
    cut2 = rounded_box("cut", W - 0.12, D - 0.12, 0.3, 0.04, 2, (0, 0, H * 0.35))
    boolean_diff(band, cut2)
    rounded_box("FoodBox_Lid", W + 0.04, D + 0.04, 0.07, 0.04, 3, (0, 0, H + 0.035))


def build_Bottle():
    body = cylinder("Bottle_Body", 0.25, 0.85, (0, 0, 0.425), 32, bevel=0.06, seg=4)
    shoulder = sphere("s", 0.25, (0, 0, 0.85), (1, 1, 0.55))
    join([body, shoulder], "Bottle_Body")
    cylinder("Bottle_Cap", 0.13, 0.16, (0, 0, 1.03), 24, bevel=0.02)
    cylinder("Bottle_Nozzle", 0.06, 0.22, (0, 0, 1.2), 16, r2=0.02)


PROPS = ["Tray", "PizzaBox", "Cup", "Pizza", "Pan", "Chair", "Table", "FoodBox", "Bottle"]


PREVIEW_COLORS = {
    "Body": (0.85, 0.15, 0.15), "Liner": (0.98, 0.95, 0.88), "Print": (0.85, 0.15, 0.15),
    "Trim": (0.85, 0.15, 0.15), "Logo": (0.85, 0.15, 0.15), "Ring": (1.0, 0.75, 0.15),
    "Tab": (0.95, 0.92, 0.85), "Band": (0.85, 0.15, 0.15), "Rim": (0.97, 0.97, 0.97),
    "Lid": (0.97, 0.97, 0.97), "Dome": (0.97, 0.97, 0.97), "Straw": (0.85, 0.15, 0.15),
    "Crust": (0.88, 0.65, 0.36), "Sauce": (0.75, 0.15, 0.1), "Cheese": (1.0, 0.85, 0.45),
    "Fill": (1.0, 0.9, 0.6), "Shell": (0.95, 0.95, 0.95), "Legs": (0.12, 0.12, 0.13),
    "Top": (0.77, 0.55, 0.36), "Edge": (0.43, 0.28, 0.19), "Base": (0.12, 0.12, 0.13),
    "Cap": (0.95, 0.95, 0.95), "Nozzle": (0.95, 0.95, 0.95),
}
OVERRIDES = {"PizzaBox_Body": (0.98, 0.96, 0.92), "Pan_Body": (0.78, 0.8, 0.82), "Pan_Lip": (0.85, 0.87, 0.89),
             "Cup_Body": (0.98, 0.97, 0.95), "FoodBox_Body": (0.98, 0.97, 0.95), "FoodBox_Lid": (0.98, 0.97, 0.95),
             "Bottle_Body": (0.8, 0.12, 0.1)}


def render_preview(prop):
    """Workbench render of the prop to blender/export/<Prop>.png (for review)."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 480
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    scene.world = world
    objs = [o for o in bpy.data.objects if o.name.startswith(prop + "_")]
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        role = o.name.split("_", 1)[1]
        c = OVERRIDES.get(o.name, PREVIEW_COLORS.get(role, (0.8, 0.8, 0.8)))
        o.color = (c[0], c[1], c[2], 1)
        for v in o.bound_box:
            w = o.matrix_world @ Vector(v)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    centre = (lo + hi) / 2
    size = max((hi - lo).length, 0.5)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = centre + Vector((0.9, -1.3, 0.9)).normalized() * size * 1.35
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = os.path.join(EXPORT_DIR, prop + ".png")
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_render = "--render" in argv
    wanted = [a for a in argv if not a.startswith("--")] or PROPS
    for prop in wanted:
        reset()
        globals()["build_" + prop]()
        export(prop)
        if do_render:
            render_preview(prop)


if __name__ == "__main__":
    main()
