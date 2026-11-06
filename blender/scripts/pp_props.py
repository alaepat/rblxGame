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


# ---- quality: every primitive is built finer than its call asks for.
# Q = 1 reproduces the original medium-poly props; 2 = high-poly (default).
Q = float(os.environ.get("PP_QUALITY", "2"))
MAX_TRIS = 19000  # Roblox MeshPart limit is 20k triangles


def qv(n, cap=128):
    """Scale a vertex / segment count by the quality factor."""
    return int(min(cap, max(n, round(n * (0.5 + Q / 2) ** 1.25))))


def weighted_normals(o):
    """Face-weighted normals: flat faces stay flat, bevels catch the light."""
    m = o.modifiers.new("wn", "WEIGHTED_NORMAL")
    m.keep_sharp = True
    m.weight = 50
    apply_mods(o)


def rounded_box(n, sx, sy, sz, radius, segments=5, loc=(0, 0, 0)):
    """Box with rounded edges. sx/sy/sz are full sizes, loc = centre."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = active()
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    b = o.modifiers.new("bevel", "BEVEL")
    b.width = min(radius, sx / 2.05, sy / 2.05, sz / 2.05)
    b.segments = qv(segments, 12)
    b.limit_method = "NONE"
    b.harden_normals = False
    apply_mods(o)
    smooth(o)
    weighted_normals(o)
    return name(o, n)


def cylinder(n, r, depth, loc=(0, 0, 0), verts=40, r2=None, bevel=0.0, seg=3):
    verts = qv(verts, 96)
    seg = qv(seg, 8)
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
    maj_seg, min_seg = qv(maj_seg, 96), qv(min_seg, 32)
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=maj_seg,
                                     minor_segments=min_seg, location=loc)
    o = active()
    smooth(o, 80)
    return name(o, n)


def sphere(n, r, loc=(0, 0, 0), scale=(1, 1, 1), seg=32, rings=16):
    seg, rings = qv(seg, 64), qv(rings, 32)
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
        # keep every part under the Roblox per-MeshPart triangle limit
        o.data.calc_loop_triangles()
        t = len(o.data.loop_triangles)
        if t > MAX_TRIS:
            d = o.modifiers.new("dec", "DECIMATE")
            d.ratio = MAX_TRIS / t * 0.97
            apply_mods(o)
            print(f"[pp] {o.name}: decimated {t} -> {MAX_TRIS} tris")
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
    c = (hi + lo) / 2
    # Blender (x, y, z) -> Roblox (x, z, -y). size = bbox size; center = bbox
    # centre (x, z) relative to the prop origin, used by MeshLib to place it.
    print(f"[pp] exported {prop}: {len(objs)} parts, {tris} tris -> {path}")
    print(f"[pp-lua]\t{prop} = {{ assetId = 0, size = Vector3.new({d.x:.3f}, {d.z:.3f}, {d.y:.3f}), "
          f"center = Vector3.new({c.x:.3f}, 0, {-c.y:.3f}) }},")


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
    # flat orbit ring printed around the planet logo (an elliptical band)
    ring = torus("PizzaBox_Ring", 0.78, 0.03, (0, 0, H + 0.012))
    ring.scale = (1, 0.42, 0.25)
    ring.rotation_euler = (0, 0, math.radians(-18))
    select_only([ring])
    bpy.ops.object.transform_apply(location=False, scale=True, rotation=True)
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
    # Hand-stretched base: thin centre, puffy uneven cornicione with air bubbles.
    prof = [(0.0, 0.0), (0.9, 0.0), (1.1, 0.01), (1.18, 0.05), (1.2, 0.11), (1.18, 0.18), (1.12, 0.235),
            (1.04, 0.25), (0.97, 0.22), (0.93, 0.16), (0.9, 0.13), (0.5, 0.12), (0.0, 0.12)]
    crust = lathe("Pizza_Crust", prof, 96, jitter=0.02, seed=6)
    displace(crust, 0.012, 6, 5)
    sauce = cylinder("Pizza_Sauce", 0.97, 0.035, (0, 0, 0.14), 96, bevel=0.012, seg=2)
    wobble_edge(sauce, 0.025, 1)
    # melted cheese: bubbly top, uneven edge, a few runs toward the crust
    # dense lathe disc so the noise can raise real bubbles across the top
    cprof = [(0.0, 0.0), (0.86, 0.0), (0.885, 0.012), (0.885, 0.03), (0.86, 0.045)]
    cprof += [(0.86 - i * 0.0574, 0.05 + 0.004 * math.sin(i)) for i in range(1, 16)] + [(0.0, 0.05)]
    cheese = lathe("Pizza_Cheese", [(r, z + 0.145) for r, z in cprof], 96)
    wobble_edge(cheese, 0.07, 2)
    displace(cheese, 0.016, 2, 11)
    displace(cheese, 0.006, 7, 30)
    runs = []
    for i in range(7):
        a = i / 7 * math.tau + 0.3
        run = lumpy("r", 0.09, (1.4, 0.8, 0.22), 0.01, 20 + i, (math.cos(a) * 0.88, math.sin(a) * 0.88, 0.165), 9)
        run.rotation_euler = (0, 0, a)
        select_only([run])
        bpy.ops.object.transform_apply(rotation=True)
        runs.append(run)
    join([cheese] + runs, "Pizza_Cheese")


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


# ---- batch 2 helpers

def slab_x(n, sx, sy, sz, radius, seg=4, loc=(0, 0, 0)):
    """Box whose edges parallel to X are rounded and whose X ends stay square,
    so it can be stretched along X (counter tops) or tiled without seams."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = active()
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    edges = [e for e in bm.edges if abs(e.verts[0].co.x - e.verts[1].co.x) > 1e-5]
    bmesh.ops.bevel(bm, geom=edges, offset=radius, segments=seg, profile=0.5, affect="EDGES")
    bm.to_mesh(o.data)
    bm.free()
    smooth(o)
    return name(o, n)


def lathe(n, profile, segs=32, loc=(0, 0, 0), jitter=0.0, seed=0, ridges=0.0):
    """Revolve a list of (radius, z) points around Z. Optional organic jitter
    and horizontal ridges (doner meat layers)."""
    if segs >= 12:  # low counts are deliberate facets (hex lanterns)
        segs = qv(segs, 96)
    rnd = random.Random(seed)
    bm = bmesh.new()
    rings = []
    for i, (r, z) in enumerate(profile):
        ring = []
        for s in range(segs):
            a = s / segs * math.tau
            rr = r
            if r > 0:
                rr *= 1 + ridges * math.sin(i * 1.9) + jitter * (rnd.random() - 0.5)
            ring.append(bm.verts.new((loc[0] + math.cos(a) * rr, loc[1] + math.sin(a) * rr, loc[2] + z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(segs):
            a, b = rings[i][s], rings[i][(s + 1) % segs]
            c, d = rings[i + 1][(s + 1) % segs], rings[i + 1][s]
            try:
                bm.faces.new((a, b, c, d))
            except ValueError:
                pass
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        try:
            f = bm.faces.new(list(reversed(ring)) if flip else ring)
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(n)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(n, me)
    bpy.context.scene.collection.objects.link(o)
    smooth(o, 60)
    return name(o, n)


def arch_cutter(half_w, z0, z_spring, y0, y1):
    """Arch-shaped prism (box + half cylinder) between y0 and y1 for booleans."""
    depth = abs(y1 - y0)
    yc = (y0 + y1) / 2
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, yc, (z0 + z_spring) / 2))
    box = active()
    box.scale = (half_w * 2, depth, z_spring - z0)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=half_w, depth=depth, location=(0, yc, z_spring))
    cyl = active()
    cyl.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(rotation=True)
    # union into one manifold solid (a plain join of overlapping pieces breaks EXACT booleans)
    u = box.modifiers.new("u", "BOOLEAN")
    u.operation = "UNION"
    u.solver = "EXACT"
    u.object = cyl
    apply_mods(box)
    bpy.data.objects.remove(cyl, do_unlink=True)
    return name(box, "cut")


# ---- batch 2 props.  Front of every prop faces Blender -Y (= Roblox +Z).

def build_CounterModule():
    # One cabinet bay (one door). Tiled along X by the game, stretched to fit.
    W, D, H = 2.2, 2.6, 3.05
    rounded_box("CounterModule_Kick", W - 0.3, D - 0.3, 0.35, 0.04, 2, (0, 0, 0.175))
    rounded_box("CounterModule_Body", W - 0.02, D - 0.1, H - 0.35, 0.035, 3, (0, 0, 0.35 + (H - 0.35) / 2))
    door = rounded_box("CounterModule_Door", W - 0.22, 0.07, 2.4, 0.05, 4, (0, -(D - 0.1) / 2 - 0.02, 1.72))
    inset = rounded_box("cut", W - 0.5, 0.04, 2.1, 0.04, 3, (0, -(D - 0.1) / 2 - 0.06, 1.72))
    boolean_diff(door, inset)
    rounded_box("CounterModule_Handle", 0.8, 0.09, 0.11, 0.04, 3, (0, -(D - 0.1) / 2 - 0.13, 2.65))
    for x in (-0.33, 0.33):
        rounded_box("CounterModule_Handle", 0.06, 0.08, 0.06, 0.02, 2, (x, -(D - 0.1) / 2 - 0.07, 2.65))
    handles = [o for o in bpy.data.objects if o.name.startswith("CounterModule_Handle")]
    join(handles, "CounterModule_Handle")


def build_CounterTop():
    # Worktop for a 2.2-wide bay; the game stretches it along X to the full counter.
    slab_x("CounterTop_Top", 2.2, 2.72, 0.15, 0.05, 4, (0, -0.06, 0.075))
    slab_x("CounterTop_Edge", 2.2, 0.1, 0.12, 0.04, 3, (0, -1.38, 0.06))


def build_Oven():
    # Stone dome pizza oven on a brick plinth. Mouth faces -Y (Roblox +Z).
    rounded_box("Oven_Plinth", 5.8, 5.2, 3.2, 0.14, 5, (0, 0, 1.6))
    rounded_box("Oven_Slab", 6.1, 5.5, 0.3, 0.1, 4, (0, 0, 3.35))
    dome = sphere("Oven_Dome", 1.0, (0, 0.2, 3.5), (2.8, 2.6, 2.3), 48, 24)
    floor_cut = rounded_box("cut", 8, 8, 4, 0.01, 1, (0, 0, 1.5))
    boolean_diff(dome, floor_cut)
    boolean_diff(dome, arch_cutter(1.45, 3.5, 4.3, -4.0, 1.6))
    band = torus("Oven_Band", 2.72, 0.13, (0, 0.2, 3.7), 64, 12)
    band.scale = (1, 2.55 / 2.72, 1)
    select_only([band])
    bpy.ops.object.transform_apply(scale=True)
    arch = rounded_box("Oven_Arch", 4.4, 0.75, 2.75, 0.12, 4, (0, -2.25, 4.87))
    boolean_diff(arch, arch_cutter(1.45, 3.4, 4.3, -3.0, -1.5))
    rounded_box("Oven_Key", 0.8, 0.85, 0.55, 0.08, 3, (0, -2.3, 5.95))
    rounded_box("Oven_Soot", 3.0, 0.1, 1.6, 0.04, 2, (0, 1.65, 4.25))
    chim = cylinder("Oven_Chimney", 0.55, 4.0, (0, 0.6, 7.4), 32, bevel=0.03)
    torus("Oven_ChimneyCap", 0.6, 0.08, (0, 0.6, 9.4))
    join([chim, bpy.data.objects["Oven_ChimneyCap"]], "Oven_Chimney")
    rounded_box("Oven_Shelf", 4.8, 0.85, 0.16, 0.06, 3, (0, -3.0, 3.42))


def build_Fridge():
    # Tall two-door glass-front fridge/freezer. Front faces -Y.
    body = rounded_box("Fridge_Body", 4.0, 2.6, 8.0, 0.1, 4, (0, 0, 4))
    cavity = rounded_box("cut", 3.7, 1.2, 7.0, 0.06, 3, (0, -1.05, 4.1))
    boolean_diff(body, cavity)
    rounded_box("Fridge_Inside", 3.66, 0.05, 6.9, 0.02, 2, (0, -0.47, 4.1))
    for z in (1.6, 3.3, 5.0, 6.6):
        rounded_box("Fridge_Shelf", 3.62, 1.0, 0.06, 0.02, 2, (0, -0.95, z))
    join([o for o in bpy.data.objects if o.name.startswith("Fridge_Shelf")], "Fridge_Shelf")
    doors = []
    for x in (-0.96, 0.96):
        fr = rounded_box("door", 1.86, 0.12, 7.0, 0.06, 4, (x, -1.38, 4.1))
        win = rounded_box("cut", 1.5, 0.4, 6.6, 0.05, 3, (x, -1.38, 4.1))
        boolean_diff(fr, win)
        doors.append(fr)
        rounded_box("Fridge_Glass", 1.52, 0.02, 6.62, 0.01, 1, (x, -1.37, 4.1))
    join(doors, "Fridge_Door")
    join([o for o in bpy.data.objects if o.name.startswith("Fridge_Glass")], "Fridge_Glass")
    hs = []
    for x in (-0.22, 0.22):
        hs.append(rounded_box("h", 0.09, 0.1, 2.6, 0.04, 3, (x, -1.53, 4.3)))
    join(hs, "Fridge_Handle")


def build_MeatCone():
    # Doner meat on the vertical spit: layered, slightly lumpy, tapering up.
    prof = []
    n = 16
    for i in range(n + 1):
        t = i / n
        prof.append((0.8 + (0.46 - 0.8) * t, 0.1 + 3.4 * t))
    prof = [(0.0, 0.1)] + prof + [(0.0, 3.5)]
    lathe("MeatCone_Meat", prof, 36, jitter=0.05, seed=5, ridges=0.025)
    cylinder("MeatCone_Plate", 0.9, 0.08, (0, 0, 0.04), 36, bevel=0.02)
    cylinder("MeatCone_Cap", 0.3, 0.12, (0, 0, 3.56), 24, bevel=0.03)


def build_ChipsBasket():
    shell = rounded_box("ChipsBasket_Basket", 1.3, 0.9, 0.55, 0.08, 4, (0, 0, 0.275))
    inner = rounded_box("cut", 1.2, 0.8, 0.6, 0.06, 4, (0, 0, 0.35))
    boolean_diff(shell, inner)
    rim = rounded_box("ChipsBasket_Rim", 1.36, 0.96, 0.06, 0.03, 2, (0, 0, 0.55))
    hole = rounded_box("cut", 1.22, 0.82, 0.2, 0.05, 2, (0, 0, 0.55))
    boolean_diff(rim, hole)
    h = cylinder("ChipsBasket_Handle", 0.04, 1.0, (1.15, 0, 0.55), 12)
    h.rotation_euler = (0, math.radians(90), 0)
    select_only([h])
    bpy.ops.object.transform_apply(rotation=True)
    g = cylinder("ChipsBasket_Grip", 0.085, 0.55, (1.85, 0, 0.55), 20, bevel=0.03)
    g.rotation_euler = (0, math.radians(90), 0)
    select_only([g])
    bpy.ops.object.transform_apply(rotation=True)


def build_Pitta():
    bread = sphere("Pitta_Bread", 1.0, (0, 0, 0.16), (0.85, 0.53, 0.17), 40, 16)
    cut = rounded_box("cut", 4, 4, 1, 0.01, 1, (0, 0, -0.49))
    boolean_diff(bread, cut)
    wobble_edge(bread, 0.03, 9)
    toast = sphere("Pitta_Toast", 1.0, (0.05, 0.02, 0.2), (0.55, 0.32, 0.15), 32, 12)
    wobble_edge(toast, 0.08, 4)


def build_WrapRoll():
    # Wrapped wrap: bread roll along X, foil sleeve on one end, brand band.
    prof = [(0.0, 0.0), (0.18, 0.02), (0.27, 0.1), (0.3, 0.25)] + [(0.3, 0.25 + 1.2 * t / 6) for t in range(1, 7)] + \
           [(0.27, 1.6), (0.18, 1.68), (0.0, 1.7)]
    roll = lathe("WrapRoll_Bread", prof, 32)
    foil = lathe("WrapRoll_Foil", [(0.0, -0.02), (0.2, 0.0), (0.32, 0.12)] + [(0.33, 0.12 + 0.88 * t / 8) for t in range(1, 9)] + [(0.32, 1.02)],
                 32, jitter=0.06, seed=2)
    band = cylinder("WrapRoll_Band", 0.345, 0.12, (0, 0, 0.86), 32)
    for o in (roll, foil, band):
        o.rotation_euler = (0, math.radians(90), 0)
        o.location = (-0.85, 0, 0.3)
        select_only([o])
        bpy.ops.object.transform_apply(location=True, rotation=True)


def build_KebabPaper():
    # Pitta kebab in an open paper pocket, top left open for the fillings.
    paper = sphere("KebabPaper_Paper", 1.0, (0, 0, 0.31), (0.9, 0.55, 0.31), 40, 20)
    top = rounded_box("cut", 4, 4, 1, 0.01, 1, (0, 0, 0.5 + 0.5))
    boolean_diff(paper, top)
    inner = sphere("cut", 1.0, (0, 0, 0.36), (0.86, 0.51, 0.29), 40, 20)
    boolean_diff(paper, inner)
    band = sphere("KebabPaper_Band", 1.0, (0, 0, 0.31), (0.915, 0.565, 0.315), 40, 20)
    for z0, z1 in ((-1, 0.24), (0.36, 2)):
        c = rounded_box("cut", 4, 4, abs(z1 - z0), 0.01, 1, (0, 0, (z0 + z1) / 2))
        boolean_diff(band, c)
    bread = sphere("KebabPaper_Bread", 1.0, (0, 0, 0.45), (0.84, 0.48, 0.16), 36, 14)
    wobble_edge(bread, 0.03, 3)


# ---- batch 3: building + outdoor props

def sheet(n, pts_fn, nu, nv, thickness):
    """Surface from pts_fn(u, v) -> (x, y, z) on a nu x nv grid, solidified."""
    nu, nv = qv(nu, 128), qv(nv, 64)
    bm = bmesh.new()
    grid = [[bm.verts.new(pts_fn(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    me = bpy.data.meshes.new(n)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(n, me)
    bpy.context.scene.collection.objects.link(o)
    s = o.modifiers.new("solid", "SOLIDIFY")
    s.thickness = thickness
    s.offset = 0
    apply_mods(o)
    smooth(o, 50)
    return name(o, n)


def build_Awning():
    # One awning bay: a red and a white stripe, each 1 stud wide. The canopy
    # curves out from the wall (y = 0) to the front (y = -4); a scalloped
    # valance hangs from the front edge. Tiled + stretched along X in game.
    D, DROP = 4.0, 2.0

    def canopy(x0):
        def f(u, v):
            y = -D * v
            z = -DROP * (v ** 1.5) + 0.25 * math.sin(math.pi * v)
            return (x0 + u, y, z)
        return f

    def valance(x0):
        def f(u, v):
            z_top = -DROP
            scallop = 0.18 * abs(math.sin(math.pi * u))
            return (x0 + u, -D, z_top - v * (0.7 - scallop))
        return f

    for role, x0 in (("Red", -1.0), ("White", 0.0)):
        a = sheet("a", canopy(x0), 4, 16, 0.07)
        b = sheet("b", valance(x0), 8, 2, 0.06)
        join([a, b], "Awning_" + role)
    rod = cylinder("Awning_Rod", 0.06, 2.0, (0, 0.05, 0.05), 16)
    rod.rotation_euler = (0, math.radians(90), 0)
    select_only([rod])
    bpy.ops.object.transform_apply(rotation=True)


def build_DoorLeaf():
    # Glass shop door, 3.3 x 8.2, thin along Y. Hinge side doesn't matter.
    W, H = 3.3, 8.2
    fr = rounded_box("DoorLeaf_Frame", W, 0.16, H, 0.06, 3, (0, 0, H / 2))
    win = rounded_box("cut", W - 0.5, 0.6, H - 0.8, 0.05, 3, (0, 0, H / 2 + 0.1))
    boolean_diff(fr, win)
    rounded_box("DoorLeaf_Glass", W - 0.48, 0.03, H - 0.78, 0.01, 1, (0, 0, H / 2 + 0.1))
    bar = cylinder("DoorLeaf_Bar", 0.06, W - 0.7, (0, -0.22, 3.6), 16)
    bar.rotation_euler = (0, math.radians(90), 0)
    select_only([bar])
    bpy.ops.object.transform_apply(rotation=True)
    posts = [rounded_box("p", 0.08, 0.16, 0.08, 0.03, 2, (x, -0.14, 3.6)) for x in (-(W - 0.9) / 2, (W - 0.9) / 2)]
    join([bar] + posts, "DoorLeaf_Bar")
    rounded_box("DoorLeaf_Kick", W - 0.5, 0.18, 0.5, 0.05, 2, (0, 0, 0.3))


def build_Hood():
    # Extractor hood over the ovens: 12.8 long (X), 6.5 deep, wall at +Y.
    L, D = 12.8, 6.5
    skirt = rounded_box("Hood_Body", L, D, 1.0, 0.08, 3, (0, 0, 0.5))
    under = rounded_box("cut", L - 0.3, D - 0.3, 1.0, 0.06, 3, (0, 0, 0.2))
    boolean_diff(skirt, under)
    # tapered top: loft from the skirt to a narrower box near the wall
    bm = bmesh.new()
    lo = [(-L / 2, -D / 2, 1.0), (L / 2, -D / 2, 1.0), (L / 2, D / 2, 1.0), (-L / 2, D / 2, 1.0)]
    hi = [(-L / 2 + 0.8, D / 2 - 2.6, 2.4), (L / 2 - 0.8, D / 2 - 2.6, 2.4), (L / 2 - 0.8, D / 2, 2.4), (-L / 2 + 0.8, D / 2, 2.4)]
    vl = [bm.verts.new(p) for p in lo]
    vh = [bm.verts.new(p) for p in hi]
    for i in range(4):
        bm.faces.new((vl[i], vl[(i + 1) % 4], vh[(i + 1) % 4], vh[i]))
    bm.faces.new(vh)
    bm.faces.new(list(reversed(vl)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("t")
    bm.to_mesh(me)
    bm.free()
    top = bpy.data.objects.new("t", me)
    bpy.context.scene.collection.objects.link(top)
    b = top.modifiers.new("bevel", "BEVEL")
    b.width = 0.08
    b.segments = 3
    b.limit_method = "ANGLE"
    apply_mods(top)
    join([skirt, top], "Hood_Body")
    rounded_box("Hood_Duct", 3.0, 2.4, 3.2, 0.1, 3, (0, D / 2 - 1.3, 3.9))
    # baffle filters underneath
    fs = []
    for i in range(6):
        fs.append(rounded_box("f", 1.8, 0.9, 0.05, 0.02, 1, (-L / 2 + 1.3 + i * 2.05, -1.4, 0.92)))
    join(fs, "Hood_Filter")
    rounded_box("Hood_Light", L - 1.2, 0.3, 0.05, 0.02, 1, (0, -2.6, 0.9))


def build_WallLamp():
    # Lantern on a curved arm; back plate on the wall at y = 0, sticks out to -Y.
    rounded_box("WallLamp_Plate", 0.5, 0.08, 0.8, 0.04, 2, (0, 0.04, 1.3))
    arm = lathe("arm", [(0.0, 0.0), (0.05, 0.0), (0.05, 0.7), (0.0, 0.7)], 12)
    arm.rotation_euler = (math.radians(90), 0, 0)
    arm.location = (0, 0, 1.45)
    select_only([arm])
    bpy.ops.object.transform_apply(location=True, rotation=True)
    hook = cylinder("hook", 0.04, 0.3, (0, -0.7, 1.3), 10)
    join([arm, hook], "WallLamp_Plate2")
    join([bpy.data.objects["WallLamp_Plate"], bpy.data.objects["WallLamp_Plate2"]], "WallLamp_Metal")
    cap = lathe("WallLamp_Cap", [(0.0, 0.62), (0.32, 0.52), (0.36, 0.48), (0.24, 0.44), (0.0, 0.44)], 6, loc=(0, -0.7, 0.55))
    cage = lathe("WallLamp_Cage", [(0.0, 0.0), (0.2, 0.0), (0.24, 0.06), (0.24, 0.44), (0.0, 0.44)], 6, loc=(0, -0.7, 0.55))
    glow = lathe("WallLamp_Glow", [(0.0, 0.05), (0.18, 0.06), (0.2, 0.2), (0.17, 0.38), (0.0, 0.4)], 16, loc=(0, -0.7, 0.55))
    cyl = cylinder("b", 0.12, 0.08, (0, -0.7, 0.5), 6)
    join([cage, cyl], "WallLamp_Cage")


def build_StreetLamp():
    # Tapered pole with a curved arm reaching toward -Y and a lantern head.
    pole = lathe("StreetLamp_Pole", [(0.0, 0.0), (0.45, 0.0), (0.45, 0.25), (0.3, 0.45), (0.2, 0.7), (0.15, 12.6), (0.18, 12.8), (0.0, 12.9)], 20)
    # arm: a quarter circle swept out of a thin tube
    pts = []
    segs = 10
    for i in range(segs + 1):
        a = i / segs * math.pi / 2
        pts.append(Vector((0, -1.6 * (1 - math.cos(a)), 12.2 + 1.2 * math.sin(a))))
    parts = []
    for i in range(segs):
        p0, p1 = pts[i], pts[i + 1]
        mid = (p0 + p1) / 2
        d = p1 - p0
        c = cylinder("s", 0.08, d.length + 0.04, tuple(mid), 10)
        c.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        select_only([c])
        bpy.ops.object.transform_apply(rotation=True)
        parts.append(c)
    straight = cylinder("s", 0.08, 1.2, (0, -2.2, 13.4), 10)
    straight.rotation_euler = (math.radians(90), 0, 0)
    select_only([straight])
    bpy.ops.object.transform_apply(rotation=True)
    join(parts + [straight, pole], "StreetLamp_Pole")
    lathe("StreetLamp_Head", [(0.0, 13.7), (0.55, 13.5), (0.75, 13.3), (0.7, 13.2), (0.0, 13.2)], 24, loc=(0, -2.8, 0))
    lathe("StreetLamp_Lamp", [(0.0, 13.22), (0.55, 13.22), (0.45, 13.05), (0.0, 12.98)], 24, loc=(0, -2.8, 0))


def build_Planter():
    # Brick trough with a stone rim, soil and three lumpy shrubs. 5 x 2 x 1.6.
    rounded_box("Planter_Box", 5.0, 2.0, 1.45, 0.08, 3, (0, 0, 0.725))
    rim = rounded_box("Planter_Rim", 5.2, 2.2, 0.18, 0.07, 3, (0, 0, 1.52))
    hole = rounded_box("cut", 4.7, 1.7, 0.5, 0.05, 2, (0, 0, 1.55))
    boolean_diff(rim, hole)
    rounded_box("Planter_Soil", 4.7, 1.7, 0.1, 0.03, 1, (0, 0, 1.47))
    rnd = random.Random(12)
    shrubs = []
    for x in (-1.6, 0.0, 1.6):
        for k in range(4):
            r = rnd.uniform(0.42, 0.6)
            s = sphere("s", r, (x + rnd.uniform(-0.35, 0.35), rnd.uniform(-0.3, 0.3), 1.65 + r * 0.7 + rnd.uniform(0, 0.25)),
                       (1, 1, rnd.uniform(0.8, 1.0)), 16, 10)
            shrubs.append(s)
    join(shrubs, "Planter_Shrub")


def build_Parasol():
    # Patio umbrella: pole, octagonal canopy with ribs and a scalloped edge.
    cylinder("Parasol_Pole", 0.09, 7.8, (0, 0, 3.9), 12)
    cylinder("Parasol_Base", 0.6, 0.12, (0, 0, 0.06), 24, bevel=0.03)
    join([bpy.data.objects["Parasol_Pole"], bpy.data.objects["Parasol_Base"]], "Parasol_Pole")
    R, top, edge = 3.5, 7.9, 7.0
    n = 8

    def canopy(u, v):
        a = u * math.tau
        k = (math.cos(math.pi / n) / math.cos(((a % (math.tau / n)) - math.pi / n))) if v > 0 else 1
        r = R * v * (0.92 + 0.08 * k)
        z = top - (top - edge) * (v ** 0.8) - 0.12 * math.sin(math.pi * v)
        return (math.cos(a) * r, math.sin(a) * r, z)

    sheet("Parasol_Canopy", canopy, 64, 8, 0.06)
    val = []
    for i in range(n):
        a0, a1 = i / n * math.tau, (i + 1) / n * math.tau

        def f(u, v, a0=a0, a1=a1):
            a = a0 + (a1 - a0) * u
            rr = R * 0.995
            return (math.cos(a) * rr, math.sin(a) * rr, edge - v * (0.45 - 0.15 * abs(math.sin(math.pi * u))))
        val.append(sheet("v", f, 8, 1, 0.05))
    join(val, "Parasol_Valance")
    cylinder("Parasol_Finial", 0.12, 0.35, (0, 0, top + 0.15), 12, bevel=0.04)


def build_Bench():
    # Park bench: wooden slats on two curved iron frames. Faces -Y.
    L = 6.0
    slats = []
    for i in range(4):
        slats.append(rounded_box("s", L, 0.28, 0.09, 0.04, 2, (0, -0.55 + i * 0.36, 1.75)))
    for i in range(3):
        slats.append(rounded_box("s", L, 0.09, 0.3, 0.04, 2, (0, 0.72, 2.25 + i * 0.4)))
    join(slats, "Bench_Wood")
    legs = []
    for x in (-L / 2 + 0.5, L / 2 - 0.5):
        legs.append(rounded_box("l", 0.12, 0.12, 1.7, 0.04, 2, (x, -0.55, 0.85)))
        legs.append(rounded_box("l", 0.12, 0.12, 3.1, 0.04, 2, (x, 0.75, 1.55)))
        legs.append(rounded_box("l", 0.12, 1.4, 0.12, 0.04, 2, (x, 0.1, 1.65)))
        legs.append(rounded_box("l", 0.12, 0.5, 0.1, 0.04, 2, (x, -0.55, 2.3)))
    join(legs, "Bench_Iron")


# ---- batch 4: realistic food. Toppings are small meshes scattered by
# FoodVisuals; each is coloured per role from the ingredient colour.

def displace(o, amp, seed, freq=7.0):
    """Organic noise: push every vertex along its normal by smooth noise."""
    from mathutils import noise
    off = Vector((seed * 1.37, seed * 2.11, seed * 0.73))
    o.data.update()
    for v in o.data.vertices:
        p = v.co * freq + off
        d = noise.noise(p) * 0.65 + noise.noise(p * 2.3) * 0.35
        v.co += v.normal * (d * amp)
    o.data.update()
    smooth(o, 80)


def lumpy(n, r, scale, amp, seed, loc=(0, 0, 0), freq=7.0):
    o = sphere(n, r, loc, scale, 40, 20)
    displace(o, amp, seed, freq)
    return o


def tube(n, pts, radius, res=4):
    """Round tube along a polyline of (x, y, z) points (sauce, shreds)."""
    cu = bpy.data.curves.new(n, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = qv(res, 8)
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p[0], p[1], p[2], 1)
    sp.use_endpoint_u = True
    sp.order_u = 3
    sp.resolution_u = qv(6, 16)
    o = bpy.data.objects.new(n, cu)
    bpy.context.scene.collection.objects.link(o)
    select_only([o])
    bpy.ops.object.convert(target="MESH")
    o = active()
    smooth(o, 70)
    return name(o, n)


def outline(n, pts2d, thickness, z0=0.0, bevel=0.0):
    """Extrude a 2D outline (x, y) upward by `thickness`, with soft edges."""
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, z0)) for x, y in pts2d]
    face = bm.faces.new(bottom)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top, vec=(0, 0, thickness))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(n)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(n, me)
    bpy.context.scene.collection.objects.link(o)
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = qv(3, 6)
        b.limit_method = "ANGLE"
        apply_mods(o)
    # concave n-gon caps shade badly: triangulate them cleanly
    t = o.modifiers.new("tri", "TRIANGULATE")
    t.ngon_method = "BEAUTY"
    t.min_vertices = 5
    apply_mods(o)
    smooth(o, 60)
    return name(o, n)


def ring_pts(cx, cy, r, n):
    return [(cx + math.cos(i / n * math.tau) * r, cy + math.sin(i / n * math.tau) * r) for i in range(n)]


def build_Top_Pepperoni():
    # cupped slice: the rim curls up as it does in a hot oven
    lathe("Top_Pepperoni_Main", [(0.0, 0.0), (0.12, 0.004), (0.18, 0.02), (0.205, 0.04), (0.21, 0.052),
                                 (0.195, 0.058), (0.14, 0.04), (0.06, 0.034), (0.0, 0.033)], 40, jitter=0.03, seed=3)
    displace(bpy.data.objects["Top_Pepperoni_Main"], 0.004, 3, 22)
    # marbled fat flecks, mostly sunk into the surface so only a sliver shows
    rnd = random.Random(4)
    spots = []
    for _ in range(14):
        a, rr = rnd.uniform(0, math.tau), rnd.uniform(0.02, 0.15)
        s = rnd.uniform(0.008, 0.017)
        o = sphere("s", s, (math.cos(a) * rr, math.sin(a) * rr, 0.0335 + (rr / 0.15) ** 3 * 0.012),
                   (rnd.uniform(1, 1.8), 1, 0.12), 10, 5)
        o.rotation_euler = (0, 0, rnd.uniform(0, math.pi))
        spots.append(o)
    join(spots, "Top_Pepperoni_Fat")


def build_Top_Cucumber():
    cylinder("Top_Cucumber_Main", 0.195, 0.04, (0, 0, 0.02), 40, bevel=0.012)
    torus("Top_Cucumber_Rim", 0.195, 0.022, (0, 0, 0.02), 48, 10)
    seeds = []
    for i in range(10):
        a = i / 10 * math.tau
        seeds.append(sphere("s", 0.018, (math.cos(a) * 0.075, math.sin(a) * 0.075, 0.041), (1, 0.55, 0.25), 10, 6))
    join(seeds, "Top_Cucumber_Inner")


def build_Top_Jalapeno():
    ring = cylinder("Top_Jalapeno_Main", 0.18, 0.035, (0, 0, 0.0175), 40, bevel=0.01)
    hole = cylinder("cut", 0.13, 0.2, (0, 0, 0.02), 32)
    boolean_diff(ring, hole)
    core = cylinder("Top_Jalapeno_Inner", 0.13, 0.03, (0, 0, 0.015), 32, bevel=0.008)
    seeds = [sphere("s", 0.02, (math.cos(i * 1.26) * 0.06, math.sin(i * 1.26) * 0.06, 0.032), (1, 0.7, 0.3), 10, 6) for i in range(5)]
    join([core] + seeds, "Top_Jalapeno_Inner")


def build_Top_Tomato():
    lathe("Top_Tomato_Main", [(0.0, 0.0), (0.2, 0.0), (0.22, 0.02), (0.215, 0.045), (0.19, 0.05), (0.0, 0.05)], 40, jitter=0.03, seed=8)
    gel = []
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        gel.append(sphere("g", 0.07, (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.05), (1.25, 0.8, 0.18), 16, 8))
    join(gel, "Top_Tomato_Gel")
    seeds = []
    for i in range(12):
        a = i / 12 * math.tau
        seeds.append(sphere("s", 0.014, (math.cos(a) * 0.11, math.sin(a) * 0.11, 0.058), (1, 0.6, 0.35), 8, 5))
    join(seeds, "Top_Tomato_Seed")


def build_Top_Onion():
    a = torus("a", 0.14, 0.022, (0, 0, 0.022), 48, 10)
    b = torus("b", 0.095, 0.02, (0.012, -0.006, 0.02), 40, 10)
    for o in (a, b):
        o.scale = (1, 0.85, 0.7)
        select_only([o])
        bpy.ops.object.transform_apply(scale=True)
    displace(a, 0.006, 1, 9)
    join([a, b], "Top_Onion_Main")


def build_Top_Olive():
    o = torus("Top_Olive_Main", 0.085, 0.045, (0, 0, 0.04), 40, 16)
    o.scale = (1, 0.9, 0.75)
    select_only([o])
    bpy.ops.object.transform_apply(scale=True)


def build_Top_Ham():
    pts = [(-0.18, -0.15), (0.05, -0.17), (0.18, -0.12), (0.17, 0.1), (0.04, 0.16), (-0.16, 0.14)]
    o = outline("Top_Ham_Main", pts, 0.035, 0, 0.012)
    displace(o, 0.006, 2, 12)


def build_Top_Pepper():
    pts = []
    for i in range(13):
        t = i / 12
        a = (t - 0.5) * 1.6
        pts.append((math.sin(a) * 0.3, (1 - math.cos(a)) * 0.3, 0.025))
    o = tube("Top_Pepper_Main", pts, 0.03, 4)
    o.scale = (1, 1, 0.7)
    select_only([o])
    bpy.ops.object.transform_apply(scale=True)


def build_Top_Chicken():
    lumpy("Top_Chicken_Main", 0.12, (1.0, 0.85, 0.55), 0.02, 5, (0, 0, 0.065), 11)
    # grill marks: two thin seared stripes pressed into the top
    marks = []
    for dx in (-0.03, 0.03):
        m = rounded_box("m", 0.018, 0.13, 0.01, 0.004, 2, (dx, 0, 0.119))
        m.rotation_euler = (0, 0, 0.35)
        marks.append(m)
    join(marks, "Top_Chicken_Sear")


def build_Top_Mushroom():
    # slice through cap + stem: the classic mushroom silhouette
    # counter-clockwise: dome from right to left, then down the stem
    cap = [(math.cos(a) * 0.17, 0.02 + math.sin(a) * 0.12) for a in [i / 20 * math.pi for i in range(21)]]
    stem = [(-0.06, 0.0), (-0.05, -0.1), (-0.035, -0.13), (0.035, -0.13), (0.05, -0.1), (0.06, 0.0)]
    pts = [(x, y + 0.04) for x, y in cap + stem]
    o = outline("Top_Mushroom_Main", pts, 0.035, 0, 0.012)
    displace(o, 0.003, 5, 14)
    # dark gill band just under the cap, sitting a hair above the slice
    g = [(0.15 - i * 0.015, 0.06 + 0.006 * math.sin(i * 0.55)) for i in range(21)]
    g += [(x, y + 0.018) for x, y in reversed(g)]
    outline("Top_Mushroom_Gill", g, 0.004, 0.034, 0)


def build_Top_Beef():
    lumpy("Top_Beef_Main", 0.085, (1.0, 0.9, 0.7), 0.022, 7, (0, 0, 0.06), 16)


def build_Top_Shred():
    pts = []
    for i in range(9):
        t = i / 8
        pts.append(((t - 0.5) * 0.34, math.sin(t * math.pi * 1.6) * 0.035, 0.02 + math.sin(t * math.pi) * 0.012))
    o = tube("Top_Shred_Main", pts, 0.022, 3)
    o.scale = (1, 1.4, 0.7)
    select_only([o])
    bpy.ops.object.transform_apply(scale=True)


def build_Top_Leaf():
    def f(u, v):
        x = (u - 0.5) * 0.42
        w = 0.15 * math.sin(math.pi * u) ** 0.8
        y = (v - 0.5) * 2 * w
        edge = abs(v - 0.5) * 2
        z = 0.03 + 0.012 * math.sin(u * 23) * edge ** 2 + 0.018 * (1 - edge) ** 2
        return (x, y, z)
    sheet("Top_Leaf_Main", f, 24, 10, 0.012)
    tube("Top_Leaf_Vein", [(lambda p: (p[0], p[1], p[2] + 0.004))(f(u / 6, 0.5)) for u in range(1, 6)], 0.0045, 2)


def build_Top_Doner():
    def f(u, v):
        x = (u - 0.5) * 0.48
        y = (v - 0.5) * 0.17
        z = 0.035 + 0.02 * math.sin(u * 11 + v * 3) + 0.03 * math.sin(math.pi * v)
        return (x, y, z)
    o = sheet("Top_Doner_Main", f, 20, 8, 0.03)
    displace(o, 0.004, 9, 20)
    def g(u, v):
        x, y, z = f(u, v)
        return (x, y, z + 0.017)
    sheet("Top_Doner_Sear", lambda u, v: (lambda p: (p[0] * 0.9, p[1] * 0.5, p[2]))(g(u, v)), 12, 4, 0.004)


def build_Top_Chip():
    o = rounded_box("Top_Chip_Main", 0.1, 0.1, 0.5, 0.03, 3, (0, 0, 0.25))
    bend = o.modifiers.new("bend", "SIMPLE_DEFORM")
    bend.deform_method = "BEND"
    bend.angle = math.radians(14)
    bend.deform_axis = "X"
    apply_mods(o)
    displace(o, 0.004, 3, 18)
    o.rotation_euler = (math.radians(90), 0, 0)
    o.location = (0, 0.25, 0.05)
    select_only([o])
    bpy.ops.object.transform_apply(location=True, rotation=True)


def build_Top_Drizzle():
    pts = []
    for i in range(17):
        t = i / 16
        pts.append(((t - 0.5) * 0.5, math.sin(t * math.pi * 4) * 0.05, 0.02))
    tube("Top_Drizzle_Main", pts, 0.022, 3)


def build_Top_Cheese():
    o = lathe("Top_Cheese_Main", [(0.0, 0.0), (0.14, 0.0), (0.16, 0.012), (0.13, 0.03), (0.0, 0.035)], 32, jitter=0.25, seed=11)
    displace(o, 0.006, 4, 10)


def build_Dough():
    o = lumpy("Dough_Dough", 0.58, (1.0, 1.0, 0.5), 0.02, 2, (0, 0, 0.29), 4)
    # flour dusting: thin patches hugging the top of the dome
    rnd = random.Random(7)
    dust = []
    for _ in range(9):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(0, 0.35)
        z = 0.29 + 0.29 * math.sqrt(max(0, 1 - (r / 0.58) ** 2)) - 0.004
        d = sphere("d", rnd.uniform(0.06, 0.13), (math.cos(a) * r, math.sin(a) * r, z), (1, rnd.uniform(0.6, 1), 0.05), 20, 6)
        dust.append(d)
    join(dust, "Dough_Flour")


TOPPINGS = ["Top_Pepperoni", "Top_Cucumber", "Top_Jalapeno", "Top_Tomato", "Top_Onion", "Top_Olive", "Top_Ham",
            "Top_Pepper", "Top_Chicken", "Top_Mushroom", "Top_Beef", "Top_Shred", "Top_Leaf", "Top_Doner",
            "Top_Chip", "Top_Drizzle", "Top_Cheese", "Dough"]

PROPS = ["Tray", "PizzaBox", "Cup", "Pizza", "Pan", "Chair", "Table", "FoodBox", "Bottle",
         "CounterModule", "CounterTop", "Oven", "Fridge", "MeatCone", "ChipsBasket", "Pitta", "WrapRoll", "KebabPaper",
         "Awning", "DoorLeaf", "Hood", "WallLamp", "StreetLamp", "Planter", "Parasol", "Bench"] + TOPPINGS


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
             "Bottle_Body": (0.8, 0.12, 0.1),
             "CounterModule_Body": (0.78, 0.8, 0.82), "CounterModule_Door": (0.85, 0.87, 0.89),
             "CounterModule_Handle": (0.5, 0.52, 0.55), "CounterModule_Kick": (0.12, 0.12, 0.13),
             "CounterTop_Top": (0.8, 0.82, 0.84), "CounterTop_Edge": (0.5, 0.52, 0.55),
             "Oven_Plinth": (0.66, 0.3, 0.21), "Oven_Slab": (0.59, 0.55, 0.51), "Oven_Dome": (0.82, 0.47, 0.32),
             "Oven_Band": (0.59, 0.12, 0.12), "Oven_Arch": (0.66, 0.3, 0.21), "Oven_Key": (0.59, 0.55, 0.51), "Oven_Soot": (0.1, 0.06, 0.05),
             "Oven_Chimney": (0.5, 0.52, 0.55), "Oven_Shelf": (0.59, 0.55, 0.51),
             "Fridge_Body": (0.78, 0.8, 0.82), "Fridge_Door": (0.7, 0.72, 0.75), "Fridge_Glass": (0.7, 0.85, 1.0),
             "Fridge_Inside": (0.85, 0.93, 1.0), "Fridge_Shelf": (0.9, 0.9, 0.92), "Fridge_Handle": (0.5, 0.52, 0.55),
             "MeatCone_Meat": (0.84, 0.6, 0.35), "MeatCone_Plate": (0.78, 0.8, 0.82), "MeatCone_Cap": (0.78, 0.8, 0.82),
             "ChipsBasket_Basket": (0.78, 0.8, 0.82), "ChipsBasket_Rim": (0.85, 0.87, 0.89),
             "ChipsBasket_Handle": (0.78, 0.8, 0.82), "ChipsBasket_Grip": (0.85, 0.15, 0.15),
             "Pitta_Bread": (0.91, 0.77, 0.55), "Pitta_Toast": (0.82, 0.6, 0.35),
             "WrapRoll_Bread": (0.93, 0.81, 0.6), "WrapRoll_Foil": (0.84, 0.85, 0.89), "WrapRoll_Band": (0.85, 0.15, 0.15),
             "KebabPaper_Paper": (0.98, 0.96, 0.92), "KebabPaper_Band": (0.85, 0.15, 0.15), "KebabPaper_Bread": (0.91, 0.77, 0.55),
             "Awning_Red": (0.81, 0.16, 0.16), "Awning_White": (0.97, 0.96, 0.94), "Awning_Rod": (0.13, 0.13, 0.14),
             "DoorLeaf_Frame": (0.13, 0.13, 0.14), "DoorLeaf_Glass": (0.67, 0.82, 0.9), "DoorLeaf_Bar": (0.78, 0.8, 0.82),
             "DoorLeaf_Kick": (0.78, 0.8, 0.82), "Hood_Body": (0.78, 0.8, 0.82), "Hood_Duct": (0.7, 0.72, 0.75),
             "Hood_Filter": (0.5, 0.52, 0.55), "Hood_Light": (1.0, 0.95, 0.85), "WallLamp_Metal": (0.13, 0.13, 0.14),
             "WallLamp_Cap": (0.13, 0.13, 0.14), "WallLamp_Cage": (0.13, 0.13, 0.14), "WallLamp_Glow": (1.0, 0.85, 0.5),
             "StreetLamp_Pole": (0.13, 0.13, 0.14), "StreetLamp_Head": (0.13, 0.13, 0.14), "StreetLamp_Lamp": (1.0, 0.95, 0.8),
             "Planter_Box": (0.66, 0.3, 0.21), "Planter_Rim": (0.59, 0.55, 0.51), "Planter_Soil": (0.3, 0.2, 0.13),
             "Planter_Shrub": (0.27, 0.59, 0.27), "Parasol_Pole": (0.78, 0.8, 0.82), "Parasol_Canopy": (0.81, 0.16, 0.16),
             "Parasol_Valance": (0.97, 0.96, 0.94), "Parasol_Finial": (0.78, 0.8, 0.82),
             "Bench_Wood": (0.77, 0.55, 0.36), "Bench_Iron": (0.13, 0.13, 0.14),
             "Top_Pepperoni_Main": (0.67, 0.14, 0.12), "Top_Pepperoni_Fat": (0.85, 0.45, 0.4),
             "Top_Cucumber_Main": (0.75, 0.88, 0.6), "Top_Cucumber_Rim": (0.15, 0.4, 0.15), "Top_Cucumber_Inner": (0.9, 0.95, 0.8),
             "Top_Jalapeno_Main": (0.2, 0.5, 0.15), "Top_Jalapeno_Inner": (0.75, 0.85, 0.55),
             "Top_Tomato_Main": (0.85, 0.15, 0.12), "Top_Tomato_Gel": (0.95, 0.4, 0.3), "Top_Tomato_Seed": (0.98, 0.85, 0.5),
             "Top_Onion_Main": (0.65, 0.35, 0.6), "Top_Olive_Main": (0.1, 0.09, 0.1), "Top_Ham_Main": (0.92, 0.58, 0.58),
             "Top_Pepper_Main": (0.25, 0.6, 0.18), "Top_Chicken_Main": (0.9, 0.78, 0.58), "Top_Chicken_Sear": (0.7, 0.48, 0.25),
             "Top_Mushroom_Main": (0.85, 0.77, 0.66), "Top_Mushroom_Gill": (0.55, 0.42, 0.3), "Top_Beef_Main": (0.42, 0.23, 0.15),
             "Top_Shred_Main": (1.0, 0.67, 0.15), "Top_Leaf_Main": (0.45, 0.78, 0.27), "Top_Leaf_Vein": (0.75, 0.9, 0.55),
             "Top_Doner_Main": (0.8, 0.55, 0.3), "Top_Doner_Sear": (0.5, 0.28, 0.12), "Top_Chip_Main": (0.98, 0.78, 0.3),
             "Top_Drizzle_Main": (0.97, 0.96, 0.9), "Top_Cheese_Main": (1.0, 0.9, 0.6),
             "Dough_Dough": (0.95, 0.88, 0.75), "Dough_Flour": (0.99, 0.97, 0.94)}


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
