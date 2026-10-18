"""Builds the things lying about the clearing and the maze, and the camps, and
exports each for Godot.

Run from the project root (Blender 4.3):
    blender --background --python props/tools/build_props.py
    blender --background --python props/tools/build_props.py -- <folder>   # and pictures of each

Writes props/models/<name>.glb. Each is one object of flat-coloured materials
(their names are what Godot shades them by: `Toon.surface` of the colour), low
in triangles and faceted on purpose, so that the house cel light bands them.

All coordinates below are in Godot space (metres, Y up, +Z forward), converted on
the way into Blender. Each model stands on its origin unless said otherwise.

What there is to find (scripts/loot/):
- hook: a coil of hemp rope lying on the ground with a three-fluked iron grapnel on it.
- spear: a sapling shaft, a little crooked, sharpened, a shard of scrap iron lashed
  to its head with cord and a grip bound with rag. Along +Y, its origin where it is
  held (0.85 m up from the butt).
- torch: a stick with a head of rag wound round and round and tied, dark with old
  pitch. Along +Y, its origin where it is held.
- flare: a road flare, red paper over a tube, a white band, a black striker cap.
  Along +Y, its origin in its middle.
- map: a torn page of an exercise book, folded once, curling, pencil lines on it.
- ladder: a rope ladder rolled up and tied, its rungs sticking out of the roll.
- pack: a canvas rucksack lying where it was dropped (worn, it is models/worn/backpack.glb).

The camps (scripts/loot/campsite.gd):
- fire_ring: a ring of stones round a bed of ash, charred stubs of wood in it (cold).
- fire_logs: a tepee of split wood, its feet charred, to burn in the ring.
- lean_to: two forked uprights, a ridge pole, a tarp over it pegged down behind.
- lean_to_fallen: the same fallen in: an upright snapped, the pole down, the tarp crumpled.
- bedroll: a blanket rolled and strapped; bedroll_open: one laid out, a rolled pillow.
- log_seat: a log to sit on, its ends sawn.
- pot: a dented cooking pot with a bail handle; crate: a broken crate of planks; sack.
- marker: a post with a board nailed across it, tally marks cut into the board.
- stick, pebble: one each, for scattering as MultiMeshes.
"""

import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix, Quaternion

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "props", "models")

COLOURS = {
    "hemp": (0.47, 0.39, 0.26), "hemp_dark": (0.33, 0.27, 0.18), "iron": (0.17, 0.16, 0.16),
    "rust": (0.36, 0.2, 0.12), "wood": (0.42, 0.31, 0.2), "wood_pale": (0.62, 0.52, 0.38), "canvas": (0.42, 0.4, 0.29),
    "canvas_dark": (0.32, 0.3, 0.21),
    "bark": (0.27, 0.21, 0.16), "char": (0.07, 0.06, 0.055), "ash": (0.27, 0.26, 0.25),
    "ash_dark": (0.15, 0.15, 0.14), "stone": (0.33, 0.33, 0.31), "stone_dark": (0.23, 0.23, 0.22),
    "rag": (0.5, 0.45, 0.36), "pitch": (0.12, 0.09, 0.07), "cord": (0.3, 0.24, 0.15),
    "flare": (0.62, 0.1, 0.07), "flare_band": (0.85, 0.83, 0.76), "cap": (0.08, 0.08, 0.08),
    "paper": (0.8, 0.77, 0.66), "ink": (0.25, 0.25, 0.28),
    "tarp": (0.25, 0.29, 0.22), "tarp_dark": (0.17, 0.2, 0.15), "blanket": (0.33, 0.27, 0.22),
    "blanket_dark": (0.22, 0.18, 0.15), "strap": (0.2, 0.14, 0.09), "tin": (0.38, 0.38, 0.37),
    "sack": (0.52, 0.45, 0.32), "ember": (0.85, 0.32, 0.08),
}
MATERIALS = {}
rng = random.Random(11)


def B(p):
    """Godot (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def mat(name):
    if name not in MATERIALS:
        made = bpy.data.materials.new(name)
        # (the colours above are as seen, sRGB; Blender and glTF want them linear)
        linear = tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in COLOURS[name])
        made.diffuse_color = (*linear, 1.0)
        made.use_nodes = True
        shader = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs[0].default_value = (*linear, 1.0)
        shader.inputs["Roughness"].default_value = 1.0
        MATERIALS[name] = made
    return MATERIALS[name]


class Model:
    """A model being made: vertices in Godot space and faces, each face with a material."""

    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.mats = []
        self.smooth = []

    def add(self, verts, faces, material, smooth=False):
        base = len(self.verts)
        self.verts.extend(Vector(v) for v in verts)
        for f in faces:
            self.faces.append([base + i for i in f])
            self.mats.append(material)
            self.smooth.append(smooth)

    def make(self):
        mesh = bpy.data.meshes.new(self.name)
        names = sorted(set(self.mats))
        mesh.from_pydata([B(v) for v in self.verts], [], self.faces)
        for n in names:
            mesh.materials.append(mat(n))
        for poly, m, s in zip(mesh.polygons, self.mats, self.smooth):
            poly.material_index = names.index(m)
            poly.use_smooth = s
        # (round things shaded round, but a sawn end or a fold left sharp)
        mesh.set_sharp_from_angle(angle=math.radians(48.0))
        mesh.validate()
        thing = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(thing)
        return thing


# --- Shapes -------------------------------------------------------------------

def frame(d):
    """Two directions square to `d`."""
    d = d.normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
    a = d.cross(up).normalized()
    b = d.cross(a).normalized()
    return a, b


def tube(model, line, radii, material, sides=6, lobes=0, twist=0.0, cap_start=True, cap_end=True, wobble=0.0, seed=0):
    """A tube along `line` (points), `radii` one each (or a number). With `lobes`, the
    cross-section has that many bumps that turn round `twist` times a metre: rope."""
    r = random.Random(seed)
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(line)
    line = [Vector(p) for p in line]
    verts = []
    faces = []
    along = 0.0
    a_prev = None
    for i, p in enumerate(line):
        if i > 0:
            along += (line[i] - line[i - 1]).length
        d = (line[min(i + 1, len(line) - 1)] - line[max(i - 1, 0)])
        if d.length < 1e-6:
            d = Vector((0, 1, 0))
        a, b = frame(d)
        if a_prev is not None:
            # (keep the frame from flipping along the tube)
            a = (a_prev - a_prev.project(d.normalized())).normalized()
            b = d.normalized().cross(a).normalized()
        a_prev = a
        for k in range(sides):
            angle = math.tau * k / sides
            rr = radii[i]
            if lobes:
                rr *= 1.0 + 0.13 * math.cos(lobes * (math.tau * k / sides) - along * twist * math.tau)
            if wobble:
                rr *= 1.0 + r.uniform(-wobble, wobble)
            verts.append(p + (a * math.cos(angle) + b * math.sin(angle)) * rr)
    n = len(line)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append([i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k])
    if cap_start:
        faces.append([k for k in reversed(range(sides))])
    if cap_end:
        faces.append([(n - 1) * sides + k for k in range(sides)])
    model.add(verts, faces, material, smooth=True)


def rock(model, at, size, material, seed, flat=0.4, detail=2):
    """A rough stone: a squashed, dented icosphere sat on the ground at `at`."""
    r = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=detail, radius=1.0)
    verts = []
    sx, sy, sz = size
    turn = r.uniform(0, math.tau)
    for v in bm.verts:
        p = Vector(v.co)
        p *= 1.0 + r.uniform(-0.22, 0.18)
        p = Vector((p.x * sx, p.z * sy, p.y * sz))
        if p.y < -sy * flat:
            p.y = -sy * flat + (p.y + sy * flat) * 0.15
        p = Vector((p.x * math.cos(turn) - p.z * math.sin(turn), p.y + sy * flat, p.x * math.sin(turn) + p.z * math.cos(turn)))
        verts.append(Vector(at) + p)
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    # (Blender's winding, through the swap of axes, is inside out: turn each face)
    model.add(verts, [list(reversed(f)) for f in faces], material)


def box(model, middle, size, material, turn=(0.0, 0.0, 0.0)):
    """A box, `size` (x, y, z), turned by Euler angles (radians) about its middle."""
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    corners = [Vector((x, y, z)) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
    rot = rotation(turn)
    verts = [Vector(middle) + rot @ c for c in corners]
    faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    model.add(verts, faces, material)


def rotation(turn):
    x, y, z = turn
    return (Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(z, 3, "Z"))


def sheet(model, nx, ny, at, material, back=None):
    """A sheet (cloth, paper) from a function `at(u, v)` -> point, u and v 0..1, two-sided
    (the back face in `back`'s material, or the same)."""
    verts = []
    for j in range(ny + 1):
        for i in range(nx + 1):
            verts.append(Vector(at(i / nx, j / ny)))
    faces = []
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append([a, a + nx + 1, a + nx + 2, a + 1])
    model.add(verts, faces, material, smooth=True)
    # (its back a hair under its front, so that the two never fight over the same place)
    under = [v - Vector((0.0, 0.003, 0.0)) for v in verts]
    model.add(under, [list(reversed(f)) for f in faces], back or material, smooth=True)


def ring_of_rope(model, middle, radius, height, material, turns=1.0, thickness=0.016, seed=0, lean=(0.0, 0.0), steps=40):
    """A loop (or loops) of rope lying round `middle`."""
    r = random.Random(seed)
    line = []
    wob = [r.uniform(-1, 1) for _ in range(5)]
    for i in range(int(steps * turns) + 1):
        t = i / steps * math.tau
        rr = radius * (1.0 + 0.06 * math.sin(t * 2 + wob[0]) + 0.04 * math.sin(t * 3 + wob[1]))
        y = height + thickness * 0.8 * math.sin(t + wob[2]) + lean[0] * math.cos(t) + lean[1] * math.sin(t)
        line.append(Vector(middle) + Vector((math.cos(t) * rr, y, math.sin(t) * rr)))
    tube(model, line, thickness, material, sides=9, lobes=3, twist=7.0, cap_start=turns < 0.99, cap_end=turns < 0.99)


def log(model, a, b, radius, material, end_material, seed, sides=7, charred=None):
    """A log from `a` to `b`, its bark lumpy, its ends cut (`end_material`); `charred`:
    which end (0 or 1) is burnt black, or None."""
    r = random.Random(seed)
    a, b = Vector(a), Vector(b)
    count = 5
    line = [a.lerp(b, i / (count - 1)) for i in range(count)]
    radii = [radius * r.uniform(0.92, 1.06) for _ in line]
    start = len(model.verts)
    tube(model, line, radii, material, sides=sides, wobble=0.08, seed=seed, cap_start=False, cap_end=False)
    # the ends: a cut face each
    for i, end in ((0, 0), (count - 1, 1)):
        ring = [start + i * sides + k for k in range(sides)]
        m = "char" if charred == end else end_material
        centre = len(model.verts)
        model.verts.append(line[i] + ((line[1] - line[0]).normalized() * (0.01 if end else -0.01)))
        for k in range(sides):
            k2 = (k + 1) % sides
            face = [ring[k], ring[k2], centre] if end else [ring[k2], ring[k], centre]
            model.faces.append(face)
            model.mats.append(m)
            model.smooth.append(False)
    if charred is not None:
        # (the bark near the burnt end black too)
        row = 0 if charred == 0 else count - 2
        first = len(model.faces) - 2 * sides - (count - 1) * sides
        for k in range(sides):
            model.mats[first + row * sides + k] = "char"


# --- What there is to find -----------------------------------------------------

def grapnel(model, at, turn):
    """A three-fluked grapnel lying on its side, its eye towards `turn`."""
    rot = Matrix.Rotation(turn, 3, "Y") @ Matrix.Rotation(math.pi * 0.5 - 0.15, 3, "Z")
    o = Vector(at)
    def P(p):
        return o + rot @ Vector(p)
    tube(model, [P((0, 0.0, 0)), P((0, 0.26, 0))], 0.013, "iron", sides=6)
    # the eye
    eye = [P((0.0, 0.29 + 0.03 * math.cos(t), 0.03 * math.sin(t))) for t in [i / 10 * math.tau for i in range(11)]]
    tube(model, eye, 0.007, "iron", sides=5, cap_start=False, cap_end=False)
    for f in range(3):
        a = math.tau * f / 3 + 0.4
        out = Vector((math.cos(a), 0, math.sin(a)))
        line = []
        for i in range(7):
            t = i / 6
            # (out from the foot of the shank and curving back up to a point)
            reach = math.sin(t * math.pi * 0.62) * 0.11
            up = -0.02 + t * t * 0.13
            line.append(P(tuple(out * reach + Vector((0, up, 0)))))
        tube(model, line, [0.012 * (1.0 - 0.75 * (i / 6)) for i in range(7)], "iron", sides=5)
    # a few turns of the line tied to the eye
    knot = [P((0.0, 0.3 + 0.012 * math.sin(t * 3), 0.0)) + rot @ Vector((0.022 * math.cos(t), 0, 0.022 * math.sin(t))) for t in [i / 12 * math.tau for i in range(25)]]
    tube(model, knot, 0.009, "hemp_dark", sides=5)


def build_hook():
    m = Model("hook")
    for k in range(5):
        ring_of_rope(m, (0.01 * k, 0.0, -0.008 * k), 0.17 - 0.012 * k, 0.018 + 0.02 * k, "hemp" if k % 2 == 0 else "hemp_dark",
                     seed=k, lean=(0.006 * k, -0.004 * k))
    # the end of the line, off the coil to the grapnel
    end = [Vector((0.16, 0.03, 0.05)), Vector((0.22, 0.02, 0.1)), Vector((0.28, 0.025, 0.12)), Vector((0.33, 0.04, 0.1))]
    tube(m, end, 0.015, "hemp", sides=9, lobes=3, twist=7.0)
    grapnel(m, (0.36, 0.035, 0.08), -0.5)
    return m


def build_spear():
    m = Model("spear")
    butt = -0.85
    top = 1.25
    r = random.Random(3)
    line = []
    for i in range(9):
        t = i / 8
        y = butt + (top - butt) * t
        line.append(Vector((0.012 * math.sin(t * 5.0) + r.uniform(-0.004, 0.004), y, 0.01 * math.sin(t * 3.3 + 1.0))))
    radii = [0.019 - 0.004 * (i / 8) for i in range(9)]
    radii[0] = 0.012
    tube(m, line, radii, "wood", sides=6)
    # a knot or two on the shaft
    for y in (-0.35, 0.55):
        rock(m, (line[0].x + 0.016, y, 0.0), (0.012, 0.016, 0.012), "bark", seed=int(y * 100), flat=1.0, detail=1)
    # the grip, bound in rag
    for k in range(7):
        y = -0.12 + k * 0.035
        ring = [Vector((0.023 * math.cos(t), y + 0.012 * math.sin(t), 0.023 * math.sin(t))) for t in [i / 8 * math.tau for i in range(9)]]
        tube(m, ring, 0.008, "rag", sides=4, cap_start=False, cap_end=False)
    # the blade: a shard of iron, a long flat diamond, a little uneven
    base = top - 0.03
    blade = [
        Vector((0.0, base, 0.0)), Vector((0.042, base + 0.09, 0.0)), Vector((0.03, base + 0.2, 0.0)),
        Vector((0.0, base + 0.34, 0.0)), Vector((-0.025, base + 0.19, 0.0)), Vector((-0.038, base + 0.08, 0.0)),
    ]
    front = [v + Vector((0, 0, 0.007)) for v in blade]
    back = [v + Vector((0, 0, -0.007)) for v in blade]
    ridge_f = Vector((0.003, base + 0.15, 0.012))
    ridge_b = Vector((0.003, base + 0.15, -0.012))
    verts = front + back + [ridge_f, ridge_b]
    n = len(blade)
    faces = []
    for i in range(n):
        i2 = (i + 1) % n
        faces.append([i, i2, 2 * n])
        faces.append([n + i2, n + i, 2 * n + 1])
        faces.append([i2, i, n + i, n + i2])
    m.add(verts, faces, "rust")
    # lashed on with cord, over the foot of the blade
    for k in range(6):
        y = top - 0.06 + k * 0.016
        ring = [Vector((0.026 * math.cos(t), y + 0.006 * math.sin(t * 1.0), 0.02 * math.sin(t))) for t in [i / 8 * math.tau for i in range(9)]]
        tube(m, ring, 0.005, "cord", sides=4, cap_start=False, cap_end=False)
    return m


def build_torch():
    m = Model("torch")
    r = random.Random(5)
    line = [Vector((r.uniform(-0.006, 0.006), -0.22 + i * 0.1, r.uniform(-0.006, 0.006))) for i in range(8)]
    tube(m, line, [0.017, 0.018, 0.019, 0.02, 0.02, 0.021, 0.022, 0.02], "wood", sides=6)
    # the head: rag wound round and round, in a lumpy spiral, black with pitch at the top
    turns = 5.0
    steps = 70
    spiral = []
    radii = []
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * math.tau
        y = 0.36 + t * 0.2
        bulge = 0.032 + 0.018 * math.sin(t * math.pi) + 0.004 * math.sin(a * 2.3)
        spiral.append(Vector((math.cos(a) * bulge, y, math.sin(a) * bulge)))
        radii.append(0.016 + 0.004 * math.sin(t * math.pi))
    half = steps // 2
    tube(m, spiral[: half + 1], radii[: half + 1], "rag", sides=5)
    tube(m, spiral[half:], radii[half:], "pitch", sides=5)
    # a cap over the top, and a tie round the foot of the head
    rock(m, (0.0, 0.53, 0.0), (0.045, 0.04, 0.045), "pitch", seed=8, flat=0.2)
    ring = [Vector((0.03 * math.cos(t), 0.355, 0.03 * math.sin(t))) for t in [i / 10 * math.tau for i in range(11)]]
    tube(m, ring, 0.006, "cord", sides=4, cap_start=False, cap_end=False)
    return m


def build_flare():
    m = Model("flare")
    tube(m, [Vector((0, -0.13, 0)), Vector((0, 0.08, 0))], 0.019, "flare", sides=8)
    tube(m, [Vector((0, 0.08, 0)), Vector((0, 0.11, 0))], 0.0195, "flare_band", sides=8, cap_start=False)
    tube(m, [Vector((0, 0.11, 0)), Vector((0, 0.135, 0))], 0.019, "flare", sides=8, cap_start=False)
    tube(m, [Vector((0, 0.133, 0)), Vector((0, 0.16, 0)), Vector((0, 0.165, 0))], [0.021, 0.021, 0.017], "cap", sides=8)
    tube(m, [Vector((0, -0.15, 0)), Vector((0, -0.128, 0))], [0.016, 0.019], "cap", sides=8)
    return m


def build_map():
    m = Model("map")
    w, h = 0.2, 0.15
    r = random.Random(9)
    tear = [r.uniform(-0.006, 0.006) for _ in range(12)]

    def at(u, v):
        x = (u - 0.5) * w
        z = (v - 0.5) * h
        # (torn along one side, folded once down the middle, its corners curling up)
        if u > 0.95:
            x += tear[int(v * 11)]
        fold = abs(u - 0.5) * 2.0
        y = 0.006 + 0.012 * fold + 0.02 * max(0.0, fold - 0.7) ** 2 * 8.0 + 0.012 * max(0.0, abs(v - 0.5) * 2 - 0.6)
        return (x, y, z)
    sheet(m, 8, 6, at, "paper")
    # pencil lines: the walls of a few cells, and the way through them
    strokes = [((0.12, 0.2), (0.12, 0.8)), ((0.12, 0.8), (0.42, 0.8)), ((0.3, 0.2), (0.3, 0.6)), ((0.3, 0.6), (0.62, 0.6)),
               ((0.62, 0.6), (0.62, 0.3)), ((0.45, 0.8), (0.86, 0.8)), ((0.86, 0.8), (0.86, 0.2)), ((0.48, 0.42), (0.78, 0.42))]
    for (u1, v1), (u2, v2) in strokes:
        a = Vector(at(u1, v1))
        b = Vector(at(u2, v2))
        side = (b - a).cross(Vector((0, 1, 0))).normalized() * 0.0016
        lift = Vector((0, 0.0012, 0))
        m.add([a - side + lift, a + side + lift, b + side + lift, b - side + lift], [[0, 1, 2, 3]], "ink")
    # an X
    for (u1, v1), (u2, v2) in (((0.7, 0.24), (0.78, 0.34)), ((0.78, 0.24), (0.7, 0.34))):
        a, b = Vector(at(u1, v1)), Vector(at(u2, v2))
        side = (b - a).cross(Vector((0, 1, 0))).normalized() * 0.0022
        lift = Vector((0, 0.0013, 0))
        m.add([a - side + lift, a + side + lift, b + side + lift, b - side + lift], [[0, 1, 2, 3]], "ink")
    return m


def build_ladder():
    """A rope ladder folded up: its rungs in a stack, the two ropes zig-zagging
    from each to the next in loops at the ends, the rest of the rope in a coil."""
    m = Model("ladder")
    r = random.Random(21)
    count = 7
    rungs = []
    for k in range(count):
        y = 0.022 + k * 0.034
        z = r.uniform(-0.015, 0.015)
        turn = r.uniform(-0.07, 0.07)
        d = Vector((math.cos(turn), 0.0, math.sin(turn)))
        mid = Vector((r.uniform(-0.01, 0.01), y, z))
        rungs.append((mid, d))
        tube(m, [mid - d * 0.25, mid + d * 0.25], 0.017, "wood_pale", sides=6)
    for side in (-1.0, 1.0):
        for k in range(count):
            mid, d = rungs[k]
            end = mid + d * 0.21 * side
            # a knot round the rung
            ring = [end + Vector((0.0, 0.021 * math.cos(t), 0.021 * math.sin(t))) for t in [i / 8 * math.tau for i in range(9)]]
            tube(m, ring, 0.008, "hemp_dark", sides=4, cap_start=False, cap_end=False)
            if k + 1 < count:
                nxt = rungs[k + 1][0] + rungs[k + 1][1] * 0.21 * side
                out = 0.07 * (1.0 if k % 2 == 0 else -1.0)
                line = []
                for i in range(9):
                    t = i / 8
                    p = end.lerp(nxt, t)
                    p += Vector((side * 0.03 * math.sin(t * math.pi), 0.0, out * math.sin(t * math.pi)))
                    line.append(p)
                tube(m, line, 0.012, "hemp", sides=6)
    # the rest of the two ropes, from the top rung, in a loose coil beside the stack
    top_mid, top_d = rungs[-1]
    start = top_mid + top_d * 0.21
    coil = [start, start + Vector((0.08, -0.05, 0.06)), Vector((0.36, 0.03, 0.12))]
    tube(m, coil, 0.012, "hemp", sides=6)
    for k in range(2):
        ring_of_rope(m, (0.42, 0.0, 0.02), 0.11 - 0.012 * k, 0.014 + 0.022 * k, "hemp" if k == 0 else "hemp_dark",
                     seed=30 + k, thickness=0.012)
    return m


def blob(model, middle, radii, material, n=0.45, segments=14, rings=9, sag=0.0, smooth=True):
    """A rounded box (a superellipsoid): `n` near 0 a box, 1 an egg. `sag` lets
    its top fall in a little, as a full sack's does."""
    def sgn_pow(c, e):
        return math.copysign(abs(c) ** e, c)
    verts = []
    for j in range(rings + 1):
        lat = -math.pi * 0.5 + math.pi * j / rings
        for i in range(segments):
            lon = -math.pi + math.tau * i / segments
            x = radii[0] * sgn_pow(math.cos(lat), n) * sgn_pow(math.cos(lon), n)
            z = radii[2] * sgn_pow(math.cos(lat), n) * sgn_pow(math.sin(lon), n)
            y = radii[1] * sgn_pow(math.sin(lat), n)
            if y > 0.0:
                y -= sag * (1.0 - (x / radii[0]) ** 2) * (1.0 - (z / radii[2]) ** 2) * (y / radii[1])
            verts.append(Vector(middle) + Vector((x, y, z)))
    faces = []
    for j in range(rings):
        for i in range(segments):
            i2 = (i + 1) % segments
            faces.append([j * segments + i, (j + 1) * segments + i, (j + 1) * segments + i2, j * segments + i2])
    model.add(verts, faces, material, smooth=smooth)


def build_pack():
    """A canvas rucksack lying on its back as it was dropped: a slumped body, a
    flap over its top held by two leather straps with iron buckles, a pocket on
    one side, a grab loop, one shoulder strap trailing out from under it."""
    m = Model("pack")
    blob(m, (0.0, 0.1, 0.0), (0.18, 0.1, 0.24), "canvas", n=0.42, sag=0.025)
    # the pocket on its side
    blob(m, (0.19, 0.08, -0.02), (0.035, 0.07, 0.12), "canvas_dark", n=0.5)

    # the flap: a sheet over the top end, draped down over it
    def flap(u, v):
        x = (u - 0.5) * 0.37
        z = 0.25 - v * 0.2
        y = 0.205 - 0.02 * (2.0 * abs(u - 0.5)) ** 2 + 0.008
        if v < 0.25:
            # (over the end, falling down it)
            t = (0.25 - v) / 0.25
            z = 0.2 + 0.05 * math.sin(t * math.pi * 0.5) + 0.0
            y -= 0.12 * t * t
            z = 0.2 + 0.055 * math.sin(t * 1.4)
        return (x * (1.0 - 0.08 * v), y, z)
    sheet(m, 8, 6, flap, "canvas_dark", back="canvas_dark")
    for side in (-1.0, 1.0):
        x = side * 0.09
        # a strap down the flap and the body
        line = [Vector((x, 0.215, 0.07)), Vector((x, 0.218, 0.16)), Vector((x, 0.2, 0.235)), Vector((x, 0.13, 0.262)), Vector((x, 0.06, 0.26))]
        for a, b in zip(line, line[1:]):
            mid = (a + b) * 0.5
            along = b - a
            length = along.length
            pitch = math.atan2(-along.y, along.z)
            box(m, mid, (0.028, 0.006, length + 0.004), "strap", turn=(pitch, 0.0, 0.0))
        box(m, (x, 0.222, 0.1), (0.036, 0.01, 0.026), "iron")
    # the grab loop at the top
    loop = [Vector((math.cos(t) * 0.04, 0.12 + math.sin(t) * 0.035, 0.265 + 0.01 * math.sin(t))) for t in [math.pi * i / 8 for i in range(9)]]
    tube(m, loop, 0.007, "strap", sides=4)
    # a shoulder strap trailing out from under it onto the ground
    trail = [Vector((-0.12, 0.012, -0.08)), Vector((-0.2, 0.01, -0.14)), Vector((-0.28, 0.008, -0.1)), Vector((-0.3, 0.008, 0.02)),
             Vector((-0.24, 0.01, 0.1)), Vector((-0.16, 0.012, 0.08))]
    for a, b in zip(trail, trail[1:]):
        mid = (a + b) * 0.5
        along = b - a
        box(m, mid, (0.032, 0.007, along.length + 0.006), "strap", turn=(0.0, math.atan2(along.x, along.z), 0.0))
    return m


# --- The camps ------------------------------------------------------------------

def stones_round(m, radius, count, seed, size=0.13):
    r = random.Random(seed)
    for k in range(count):
        a = math.tau * k / count + r.uniform(-0.12, 0.12)
        rr = radius * r.uniform(0.94, 1.06)
        s = size * r.uniform(0.8, 1.25)
        rock(m, (math.cos(a) * rr, -0.02, math.sin(a) * rr), (s * r.uniform(1.0, 1.4), s * r.uniform(0.7, 1.0), s),
             "stone" if k % 3 else "stone_dark", seed=seed * 100 + k, flat=0.35)


def ash_bed(m, radius, seed):
    r = random.Random(seed)
    edge = [radius * r.uniform(0.85, 1.05) for _ in range(14)]

    def at(u, v):
        a = u * math.tau
        k = int(u * 14) % 14
        rr = v * edge[k]
        return (math.cos(a) * rr, 0.02 + 0.03 * (1.0 - v * v), math.sin(a) * rr)
    verts = [Vector(at(i / 14, j / 3)) for j in range(4) for i in range(14)]
    faces = []
    for j in range(3):
        for i in range(14):
            i2 = (i + 1) % 14
            faces.append([j * 14 + i, j * 14 + i2, (j + 1) * 14 + i2, (j + 1) * 14 + i])
    m.add(verts, faces, "ash")
    # the darker middle, where it burnt longest
    for k in range(5):
        rock(m, (r.uniform(-0.15, 0.15), 0.0, r.uniform(-0.15, 0.15)), (0.09, 0.03, 0.07), "ash_dark", seed=seed + k, flat=0.6)


def build_fire_ring():
    m = Model("fire_ring")
    stones_round(m, 0.58, 11, 30)
    ash_bed(m, 0.5, 31)
    r = random.Random(32)
    for k in range(4):
        a = r.uniform(0, math.tau)
        mid = Vector((r.uniform(-0.15, 0.15), 0.05, r.uniform(-0.15, 0.15)))
        d = Vector((math.cos(a), 0.05, math.sin(a)))
        log(m, mid - d * 0.17, mid + d * 0.17, 0.035, "char", "char", seed=40 + k)
    return m


def build_fire_logs():
    m = Model("fire_logs")
    for k in range(6):
        a = math.tau * k / 6 + 0.2
        foot = Vector((math.cos(a) * 0.32, 0.03, math.sin(a) * 0.32))
        head = Vector((math.cos(a) * 0.04, 0.48, math.sin(a) * 0.04))
        log(m, foot, head, 0.035 + 0.006 * (k % 2), "bark", "wood_pale", seed=50 + k, charred=1, sides=6)
    rock(m, (0.0, 0.0, 0.0), (0.22, 0.05, 0.2), "ember", seed=60, flat=0.7)
    return m


def build_lean_to(fallen=False):
    m = Model("lean_to_fallen" if fallen else "lean_to")
    span = 2.3
    tall = 1.3
    deep = 1.7
    r = random.Random(70 if fallen else 71)
    left = Vector((-span * 0.5, 0, 0))
    right = Vector((span * 0.5, 0, 0))
    if not fallen:
        for foot in (left, right):
            tube(m, [foot, foot + Vector((0.02, tall, 0.0))], [0.04, 0.034], "bark", sides=6, wobble=0.05, seed=int(foot.x * 10) + 3)
            # the fork at its top
            top = foot + Vector((0.02, tall, 0.0))
            for side in (-1, 1):
                tube(m, [top - Vector((0, 0.08, 0)), top + Vector((side * 0.07, 0.12, 0.0))], [0.026, 0.018], "bark", sides=5)
        tube(m, [left + Vector((-0.2, tall + 0.04, 0.0)), right + Vector((0.2, tall + 0.04, 0.0))], 0.036, "bark", sides=6, wobble=0.06, seed=7)

        # the tarp: from over the ridge (a lip hanging in front) down to the ground behind, sagging, pegged
        def at(u, v):
            x = (u - 0.5) * (span + 0.3)
            if v < 0.12:
                t = v / 0.12
                y = tall + 0.08 - (1.0 - t) * 0.3
                z = 0.05 + (1.0 - t) * 0.06
            else:
                t = (v - 0.12) / 0.88
                y = (tall + 0.08) * (1.0 - t) - math.sin(t * math.pi) * 0.12 * (1.0 - abs(u - 0.5) * 1.4) + 0.02
                z = -t * deep
            y -= 0.04 * math.sin(u * math.pi * 3.0) * math.sin(v * math.pi)
            return (x, max(y, 0.015), z)
        sheet(m, 12, 10, at, "tarp", back="tarp_dark")
        # pegs and guy lines at the back corners
        for x in (-span * 0.5 - 0.1, span * 0.5 + 0.1):
            peg = Vector((x, 0.0, -deep - 0.08))
            tube(m, [peg + Vector((0, -0.02, 0)), peg + Vector((0, 0.12, 0))], [0.012, 0.016], "wood_pale", sides=4)
            tube(m, [peg + Vector((0, 0.1, 0)), Vector((x * 0.95, 0.03, -deep + 0.02))], 0.005, "cord", sides=4)
        # a log laid along the back edge to hold it down
        log(m, (-span * 0.45, 0.06, -deep + 0.1), (span * 0.45, 0.07, -deep + 0.1), 0.06, "bark", "wood_pale", seed=72)
    else:
        # one upright stands, snapped; the other lies; the ridge pole slants to the ground
        tube(m, [right, right + Vector((0.03, 0.62, 0.02))], [0.04, 0.036], "bark", sides=6, wobble=0.05, seed=5)
        rock(m, (right.x + 0.03, 0.63, 0.02), (0.04, 0.05, 0.04), "wood_pale", seed=6, flat=0.0, detail=1)
        tube(m, [right + Vector((0.4, 0.04, 0.5)), right + Vector((0.6, 0.06, 1.7))], 0.034, "bark", sides=6, wobble=0.05, seed=8)
        tube(m, [left + Vector((-0.25, 0.04, 0.2)), right + Vector((0.05, 0.6, 0.0))], 0.036, "bark", sides=6, wobble=0.06, seed=9)
        # the tarp crumpled down over the pole and the ground, folds in it
        folds = [r.uniform(0.0, math.tau) for _ in range(4)]

        def at(u, v):
            x = (u - 0.5) * (span + 0.1)
            z = -v * (deep * 0.9) + 0.25
            pole = 0.04 + 0.56 * ((u * span) / span) ** 1.5 * (1.0 - v) ** 2
            y = pole + 0.07 * abs(math.sin(u * 7.0 + folds[0])) * (1.0 - v * 0.5) + 0.05 * math.sin(v * 9.0 + folds[1] + u * 2.0)
            return (x + 0.06 * math.sin(v * 6.0 + folds[2]), max(y, 0.015), z)
        sheet(m, 14, 10, at, "tarp", back="tarp_dark")
    return m


def build_bedroll():
    m = Model("bedroll")
    length = 0.72
    radius = 0.13
    sides = 9
    line = [Vector((-length * 0.5 + length * i / 4, radius, 0.0)) for i in range(5)]
    tube(m, line, [radius * (1.0 + 0.04 * math.sin(i * 2.0)) for i in range(5)], "blanket", sides=sides, cap_start=False, cap_end=False, seed=1)
    # the ends: the roll seen end on, a spiral of the darker underside
    for side in (-1, 1):
        x = side * length * 0.5
        for k in range(3):
            rr = radius * (0.85 - k * 0.28)
            ring = [Vector((x + side * 0.004 * (k + 1), radius + rr * math.cos(t), rr * math.sin(t))) for t in [i / sides * math.tau for i in range(sides)]]
            faces = [list(range(sides))] if side > 0 else [list(reversed(range(sides)))]
            m.add(ring, faces, "blanket_dark" if k % 2 == 0 else "blanket")
    # two straps
    for x in (-0.2, 0.2):
        ring = [Vector((x, radius + (radius + 0.008) * math.cos(t), (radius + 0.008) * math.sin(t))) for t in [i / 12 * math.tau for i in range(13)]]
        tube(m, ring, 0.009, "strap", sides=4, cap_start=False, cap_end=False)
    return m


def build_bedroll_open():
    m = Model("bedroll_open")
    r = random.Random(81)
    lumps = [r.uniform(0, math.tau) for _ in range(3)]

    def at(u, v):
        x = (u - 0.5) * 0.78
        z = (v - 0.5) * 1.85
        y = 0.025 + 0.02 * math.sin(u * 5.0 + lumps[0]) * math.sin(v * 7.0 + lumps[1])
        # (the top corner turned back)
        if u > 0.6 and v > 0.78:
            t = min((u - 0.6) / 0.4, (v - 0.78) / 0.22)
            y += 0.02 + t * 0.03
        return (x, y, z)
    sheet(m, 6, 10, at, "blanket", back="blanket_dark")
    # a rolled pillow at its head
    tube(m, [Vector((-0.28, 0.07, 0.86)), Vector((0.0, 0.08, 0.88)), Vector((0.28, 0.07, 0.86))], 0.07, "blanket_dark", sides=7)
    return m


def build_log_seat():
    m = Model("log_seat")
    log(m, (-0.8, 0.17, 0.0), (0.8, 0.16, 0.03), 0.17, "bark", "wood_pale", seed=90, sides=8)
    # a stub of a branch
    tube(m, [Vector((0.25, 0.25, 0.1)), Vector((0.32, 0.36, 0.2))], [0.04, 0.03], "bark", sides=5)
    return m


def build_pot():
    m = Model("pot")
    sides = 10
    r = random.Random(91)
    profile = [(0.0, 0.0), (0.1, 0.0), (0.115, 0.03), (0.12, 0.14), (0.125, 0.15)]
    verts = []
    for y_i, (rr, y) in enumerate(profile):
        for k in range(sides):
            a = math.tau * k / sides
            dent = 1.0 - (0.12 if k == 3 and 1 <= y_i <= 3 else 0.0)
            verts.append(Vector((math.cos(a) * rr * dent, y, math.sin(a) * rr * dent)))
    faces = []
    for j in range(len(profile) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append([j * sides + k2, j * sides + k, (j + 1) * sides + k, (j + 1) * sides + k2])
    m.add(verts, faces, "tin")
    # inside, darker (seen over the rim)
    inner = [Vector((math.cos(math.tau * k / sides) * 0.112, 0.14, math.sin(math.tau * k / sides) * 0.112)) for k in range(sides)]
    bottom = [Vector((math.cos(math.tau * k / sides) * 0.1, 0.012, math.sin(math.tau * k / sides) * 0.1)) for k in range(sides)]
    faces = [[sides + k, sides + (k + 1) % sides, (k + 1) % sides, k] for k in range(sides)]
    faces.append([sides + k for k in reversed(range(sides))])
    m.add(inner + bottom, faces, "char")
    # the bail handle, lying down to one side
    arc = [Vector((math.cos(t) * 0.125, 0.14 + 0.02 * math.sin(t * 0.5), math.sin(t) * 0.125 * 0.3 - 0.1 * math.sin(t))) for t in [math.pi * i / 10 for i in range(11)]]
    tube(m, arc, 0.004, "iron", sides=4)
    return m


def build_crate():
    m = Model("crate")
    w, d, h = 0.55, 0.4, 0.34
    r = random.Random(92)
    # planks round the sides, a gap between each
    for k in range(3):
        y = 0.06 + k * 0.11
        for side in (-1, 1):
            box(m, (0.0, y, side * d * 0.5), (w, 0.095, 0.02), "wood", turn=(0.0, r.uniform(-0.01, 0.01), 0.0))
            if not (k == 2 and side == 1):
                box(m, (side * w * 0.5, y, 0.0), (0.02, 0.095, d), "wood_pale" if k == 1 else "wood")
    # corner posts and a floor
    for x in (-1, 1):
        for z in (-1, 1):
            box(m, (x * (w * 0.5 - 0.02), h * 0.5, z * (d * 0.5 - 0.02)), (0.035, h, 0.035), "wood")
    box(m, (0.0, 0.015, 0.0), (w, 0.02, d), "wood")
    # the lid: one plank prised off and lying against it, the other askew
    box(m, (0.05, h + 0.012, -0.08), (w * 0.95, 0.02, 0.13), "wood_pale", turn=(0.0, 0.12, 0.04))
    box(m, (w * 0.5 + 0.07, 0.17, 0.05), (0.02, 0.34, 0.13), "wood", turn=(0.0, 0.3, -0.35))
    return m


def build_sack():
    m = Model("sack")
    sides = 9
    rows = [(0.0, 0.14), (0.04, 0.18), (0.12, 0.19), (0.22, 0.16), (0.3, 0.1), (0.34, 0.045), (0.38, 0.05), (0.43, 0.065)]
    r = random.Random(93)
    verts = []
    for j, (y, rr) in enumerate(rows):
        for k in range(sides):
            a = math.tau * k / sides
            slump = 1.0 + 0.12 * math.sin(a * 2.0 + j) + r.uniform(-0.05, 0.05)
            lean = 0.05 * (y / 0.43) ** 2
            verts.append(Vector((math.cos(a) * rr * slump + lean, y, math.sin(a) * rr * slump * 0.9)))
    faces = []
    for j in range(len(rows) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append([j * sides + k2, j * sides + k, (j + 1) * sides + k, (j + 1) * sides + k2])
    faces.append([k for k in range(sides)])
    faces.append([(len(rows) - 1) * sides + k for k in reversed(range(sides))])
    m.add(verts, faces, "sack")
    ring = [Vector((0.03 + 0.05 * math.cos(t), 0.345, 0.045 * math.sin(t))) for t in [i / 10 * math.tau for i in range(11)]]
    tube(m, ring, 0.007, "cord", sides=4, cap_start=False, cap_end=False)
    return m


def build_marker():
    m = Model("marker")
    tube(m, [Vector((0, -0.2, 0)), Vector((0.01, 1.35, 0.01))], [0.045, 0.04], "bark", sides=6, wobble=0.05, seed=4)
    box(m, (0.0, 1.05, 0.05), (0.62, 0.17, 0.025), "wood_pale", turn=(0.0, 0.0, 0.04))
    # nails
    for x in (-0.03, 0.03):
        box(m, (x, 1.05, 0.065), (0.008, 0.008, 0.008), "iron")
    # tally marks cut in: fives, the fifth across
    marks = 0
    for group in range(4):
        x0 = -0.26 + group * 0.13
        for k in range(4 if group < 3 else 2):
            box(m, (x0 + k * 0.022, 1.05, 0.063), (0.006, 0.11, 0.004), "char", turn=(0.0, 0.0, 0.04))
            marks += 1
        if group < 3:
            box(m, (x0 + 0.033, 1.05, 0.064), (0.006, 0.13, 0.004), "char", turn=(0.0, 0.0, 1.0))
    return m


def build_stick():
    m = Model("stick")
    tube(m, [Vector((-0.3, 0.02, 0.0)), Vector((0.0, 0.025, 0.02)), Vector((0.32, 0.02, -0.01))], [0.016, 0.014, 0.01], "bark", sides=5)
    tube(m, [Vector((0.05, 0.023, 0.02)), Vector((0.16, 0.025, 0.11))], [0.009, 0.006], "bark", sides=4)
    return m


def build_pebble():
    m = Model("pebble")
    rock(m, (0.0, -0.01, 0.0), (0.07, 0.045, 0.055), "stone", seed=95, flat=0.4)
    return m


BUILDERS = {
    "hook": build_hook, "spear": build_spear, "torch": build_torch, "flare": build_flare, "map": build_map,
    "ladder": build_ladder, "pack": build_pack, "fire_ring": build_fire_ring, "fire_logs": build_fire_logs, "lean_to": build_lean_to,
    "lean_to_fallen": lambda: build_lean_to(True), "bedroll": build_bedroll, "bedroll_open": build_bedroll_open,
    "log_seat": build_log_seat, "pot": build_pot, "crate": build_crate, "sack": build_sack, "marker": build_marker,
    "stick": build_stick, "pebble": build_pebble,
}


def clear():
    for thing in list(bpy.data.objects):
        bpy.data.objects.remove(thing, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def export(thing, path):
    bpy.ops.object.select_all(action="DESELECT")
    thing.select_set(True)
    bpy.context.view_layer.objects.active = thing
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_animations=False,
                              use_selection=True, export_apply=False)


def picture(thing, path):
    """A flat-coloured picture of a model, three-quarter view, for checking it."""
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.6, 0.62, 0.6)
    lo = Vector(thing.bound_box[0])
    hi = Vector(thing.bound_box[6])
    middle = (lo + hi) * 0.5
    size = max((hi - lo).length, 0.2)
    cam_data = bpy.data.cameras.new("c")
    cam = bpy.data.objects.new("c", cam_data)
    scene.collection.objects.link(cam)
    cam.location = middle + Vector((size * 0.9, -size * 1.1, size * 0.8))
    direction = middle - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun_data = bpy.data.lights.new("s", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("s", sun_data)
    sun.rotation_euler = (0.7, 0.2, 0.6)
    scene.collection.objects.link(sun)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.objects.remove(sun, do_unlink=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folder = args[0] if args else ""
    only = args[1:] if len(args) > 1 else list(BUILDERS)
    os.makedirs(OUT, exist_ok=True)
    for name in only:
        clear()
        model = BUILDERS[name]()
        thing = model.make()
        export(thing, os.path.join(OUT, name + ".glb"))
        print("BUILT %s: %d faces" % (name, len(model.faces)))
        if folder:
            os.makedirs(folder, exist_ok=True)
            picture(thing, os.path.join(folder, name + ".png"))


main()
