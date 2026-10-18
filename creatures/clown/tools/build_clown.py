"""Builds the clown and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/clown/tools/build_clown.py [-- <folder for preview renders>]

Writes creatures/clown/models/clown.glb and clown_lo.glb (and editable .blend
copies beside this file, which are not kept: this folder has a .gdignore so
that Godot does not try to import them).

A horror clown, too tall and too thin, on the boy's and the mummy's bone names
(so CharacterRig, and ClownRig on it, can move him). Legs and arms too long for
him: the gloved fingertips hang by his knees. A faded, stained, baggy one-piece
suit with faded dots on it and fat pom-poms down the front, hanging off a frame
with nothing in it: narrow sloping shoulders, the cloth gathered in folds at
the belly, the sleeves and the trouser legs ballooning and ruffled at the
cuffs. A pleated ruff round a long thin neck. Long flat shoes with bulbous toes
that flap. White gloves, the fingers fat.

The head is a mask of greasepaint: a tall bald dome, white, with tufts of thin
hair standing out over the ears; tall dark diamonds painted through the eyes
(the eyes are only pits in the paint, dark in them); and a painted grin, much
wider than any mouth, its corners curling up into the cheeks, a thin dark line
of closed lips along it. Nothing moves in the face: the grin is paint.

Everything is one material (one draw): each part's colour is baked into the
model as its vertex colour, and how far each point lies in a fold (or a stain)
as the colour's alpha (see `painted`); ClownRig darkens the grime in one soft
step, as the ghoul's hollows are. The only colour near him is his balloon,
which is not part of this model (Clown makes it).

As the mummy is, it is modelled with its arms held out from its sides
(ARM_REST), in Godot space (metres, Y up, facing +Z, +X its left). The sleeves
are one surface with the suit (so the shoulders are cloth and not joins); their
weights are worked out by `arm_share`.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
GAME = os.path.dirname(os.path.dirname(COMPONENT))
sys.path.insert(0, os.path.join(GAME, "tools"))
import build_character as kit  # noqa: E402  (the character controller's shape-building and export tools)

# (it writes its model into the component, not the game's models/)
kit.ROOT = COMPONENT

# The colour attribute: each point's colour (linear), and in its alpha how much grime is in it.
PAINT = "paint"


class _Export:
    """bpy as the kit sees it, but for one thing: its glTF export also writes the
    model's colour attribute (PAINT), which by default it leaves out unless a
    material uses it."""

    class _Scene:
        def gltf(self, **options):
            for mesh in bpy.data.meshes:
                if PAINT in mesh.color_attributes:
                    mesh.color_attributes.active_color_name = PAINT
                    mesh.color_attributes.render_color_index = mesh.color_attributes.find(PAINT)
            options.setdefault("export_vertex_color", "ACTIVE")
            options.setdefault("export_all_vertex_colors", False)
            return bpy.ops.export_scene.gltf(**options)

    class _Ops:
        export_scene = None

        def __getattr__(self, name):
            return getattr(bpy.ops, name)

    def __init__(self):
        self.ops = _Export._Ops()
        self.ops.export_scene = _Export._Scene()

    def __getattr__(self, name):
        return getattr(bpy, name)


kit.bpy = _Export()

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

# --- Joints ---

ANKLE_Y = 0.05
SHIN = 0.37
THIGH = 0.36
HIP_X = 0.066
HIP_Y = ANKLE_Y + SHIN + THIGH
KNEE_Y = HIP_Y - THIGH
HIPS = Vector((0.0, HIP_Y + 0.02, 0.0))
SPINE = Vector((0.0, 0.92, 0.0))
CHEST = Vector((0.0, 1.07, 0.0))
NECK = Vector((0.0, 1.225, 0.0))
HEAD = Vector((0.0, 1.335, 0.012))
SHOULDER = Vector((0.098, 1.2, 0.0))
UPPER_ARM = 0.30
FOREARM = 0.31
ARM_REST = 0.5
TOE = Vector((0.0, -0.035, 0.12))
# The head: half its width, its height above the middle, its depth; the chin is JAW times as far below.
HEAD_RADII = Vector((0.066, 0.09, 0.076))
HEAD_CENTRE = HEAD + Vector((0.0, 0.092, 0.014))
JAW = 1.28

MATERIALS = [("clown", (1.0, 1.0, 1.0))]

# The colours, sRGB. Nothing saturated: the suit faded to a dirty grey-white, the paint chalky.
SUIT = (0.62, 0.6, 0.55)
DOTS = (0.47, 0.455, 0.43)
GREASEPAINT = (0.8, 0.79, 0.75)
GLOVE = (0.74, 0.73, 0.69)
RUFF = (0.78, 0.77, 0.73)
RUFF_SHADE = (0.6, 0.59, 0.57)
DARK = (0.055, 0.052, 0.056)
ROUGE = (0.3, 0.15, 0.14)
SHOES = (0.14, 0.13, 0.13)
STOCKING = (0.2, 0.19, 0.19)
POMPOM = (0.3, 0.29, 0.28)
HAIR = (0.37, 0.33, 0.29)

# Glove fingers, index to little: (offset across the palm, length, thickness, how far it fans out).
FINGERS = [(0.017, 0.058, 0.0098, 0.22), (0.0058, 0.066, 0.0102, 0.07), (-0.0058, 0.062, 0.01, -0.07), (-0.017, 0.052, 0.0094, -0.22)]
KNUCKLES = (0.0, 0.45, 0.75)
PALM = 0.06
THUMB_LENGTH = 0.046


def linear(c):
    return kit.linear(c)


def shoulder_of(side):
    return Vector((side * SHOULDER.x, SHOULDER.y, SHOULDER.z))


def arm_out(side):
    """Moves a point modelled on an arm hanging straight down out to the rest pose."""
    shoulder = shoulder_of(side)
    turn = Matrix.Rotation(side * ARM_REST, 3, "Z")
    return lambda p: shoulder + turn @ (p - shoulder)


def arm_in(side, p):
    shoulder = shoulder_of(side)
    return shoulder + Matrix.Rotation(-side * ARM_REST, 3, "Z") @ (p - shoulder)


def hand_wrist(side):
    return shoulder_of(side) + Vector((0.0, -UPPER_ARM - FOREARM, 0.002))


def finger_line(side, index):
    z, _length, _radius, fan = FINGERS[index]
    return hand_wrist(side) + Vector((0.0, -PALM, z)), Vector((0.0, -math.cos(fan), math.sin(fan)))


def thumb_line(side):
    inward = -side
    return hand_wrist(side) + Vector((inward * 0.006, -0.018, 0.02)), Vector((inward * 0.25, -0.7, 0.66)).normalized()


def smooth_rings(x, z, profile, band=0.018):
    """Rings for an upright tube (kit.lapped with no laps)."""
    return kit.lapped(x, z, profile, band, 0.0)


def profile_at(profile, y):
    """(half width, half depth, forward) of a profile at height `y`."""
    for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(profile, profile[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return rx0 + (rx1 - rx0) * t, rz0 + (rz1 - rz0) * t, z0 + (z1 - z0) * t
    return profile[-1][1], profile[-1][2], profile[-1][3]


def profile_of(profile, t):
    """(half thickness, half width, forward) of a limb's profile (LEG, ARM) `t` along it."""
    ordered = sorted(profile)
    for (t0, rx0, rz0, z0), (t1, rx1, rz1, z1) in zip(ordered, ordered[1:]):
        if t0 <= t <= t1:
            u = (t - t0) / (t1 - t0)
            return rx0 + (rx1 - rx0) * u, rz0 + (rz1 - rz0) * u, z0 + (z1 - z0) * u
    return ordered[-1][1], ordered[-1][2], ordered[-1][3]


# --- Colour and grime ---

def concavity(bm):
    """How far each point of a surface lies in a hollow: the mean of how far its
    neighbours stand out over it, along its normal, as a share of their
    distance; smoothed over its neighbours twice."""
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    value = []
    for vert in bm.verts:
        total, count = 0.0, 0
        for edge in vert.link_edges:
            other = edge.other_vert(vert)
            span = other.co - vert.co
            if span.length > 1e-7:
                total += span.dot(vert.normal) / span.length
                count += 1
        value.append(total / max(count, 1))
    for _pass in range(2):
        value = [(value[vert.index] + sum(value[edge.other_vert(vert).index] for edge in vert.link_edges)) / (1 + len(vert.link_edges)) for vert in bm.verts]
    return value


def painted(shapes, colour, fuse=None, threshold=None, stains=None):
    """A part made by `shapes` (fused as `fuse` says), all of one colour, with how
    much grime is in each point as the colour's alpha: 0.5 exactly where it sinks
    in by `threshold` (see concavity), more where further, less where it stands
    out (with no threshold, none); or more where `stains`, given a point, says
    (0..1). The game's shader darkens the colour where the alpha is over 0.5, in
    one soft step, so the edge of the dirt is a clean curve wherever it falls."""
    def made(b):
        ready = shapes(b)
        mesh = ready if ready is not None else kit.fused(b, None if kit.LOW else fuse)
        deep = None
        if threshold is not None and not kit.LOW:
            bm = bmesh.new()
            bm.from_mesh(mesh)
            deep = concavity(bm)
            bm.free()
        rgb = tuple(linear(c) for c in colour)
        attribute = mesh.color_attributes.new(PAINT, "FLOAT_COLOR", "POINT")
        for index, (item, vertex) in enumerate(zip(attribute.data, mesh.vertices)):
            grime = 0.0
            if deep is not None:
                grime = min(max(0.5 + (deep[index] - threshold) / 0.03, 0.0), 1.0)
            if stains:
                grime = max(grime, stains(kit.from_blender(vertex.co)))
            item.color = rgb + (grime,)
        return mesh
    return made


# --- The suit ---

# (height, half width, half depth, how far forward): the crotch, the cloth
# ballooning and sagging over a belly that is not there, narrow sloping shoulders.
TORSO = [(0.72, 0.046, 0.046, 0.0), (0.76, 0.098, 0.08, 0.0), (0.83, 0.114, 0.09, 0.004), (0.9, 0.12, 0.095, 0.012),
         (0.98, 0.113, 0.088, 0.01), (1.05, 0.102, 0.077, 0.004), (1.12, 0.098, 0.068, 0.0), (1.17, 0.088, 0.06, 0.0),
         (1.2, 0.064, 0.048, 0.0), (1.225, 0.034, 0.032, 0.0)]
SUIT_FUSE = (0.0036, 3, 7500)

# A sleeve (0 the shoulder, 1 the elbow, 2 the wrist): (where, half thickness, half width, forward).
# Baggy, puffed at the shoulder, flaring to the cuff.
ARM = [(1.93, 0.04, 0.043, 0.0), (1.86, 0.05, 0.052, 0.0), (1.72, 0.046, 0.048, 0.0), (1.4, 0.038, 0.04, 0.0),
       (1.05, 0.035, 0.037, 0.0), (0.7, 0.04, 0.042, 0.0), (0.35, 0.045, 0.048, 0.0), (0.12, 0.048, 0.05, 0.0), (-0.03, 0.038, 0.04, 0.0)]


def arm_point(side, t, out=0.0, forward=0.0):
    """A point on an arm hanging straight down, `t` along it (as ARM), `out` from its middle and `forward`."""
    y = SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM)
    return Vector((side * (SHOULDER.x + out), y, SHOULDER.z + forward))


def torso_point(angle, y, out=0.0):
    """A point on the suit's body, `angle` round from the front (towards its left), at height `y`."""
    rx, rz, fwd = profile_at(TORSO, y)
    return Vector((math.sin(angle) * (rx + out), y, math.cos(angle) * (rz + out) + fwd))


def suit(_builder):
    """The suit's body and its sleeves, and the folds the cloth hangs in: one surface."""
    b = kit.Builder()
    b.tube(smooth_rings(0.0, 0.0, TORSO), 24)
    # Folds hanging down the front and back from the shoulders, and gathered round the belly
    # (demade, there are none: they would stand out of it as sticks)
    rng = random.Random(7)
    for angle in () if kit.LOW else (0.35, -0.3, 0.95, -1.05, 1.6, -1.6, 2.4, -2.3, 3.1):
        top = 1.15 - 0.05 * abs(math.sin(angle)) + rng.uniform(-0.02, 0.02)
        points = [torso_point(angle + 0.06 * math.sin(k * 1.3), top - (top - 0.77) * k / 5.0, -0.002) for k in range(6)]
        b.strand(points, [0.006, 0.009, 0.011, 0.012, 0.011, 0.008], 6)
    for k in range(0 if kit.LOW else 3):
        y = 0.86 + 0.06 * k
        points = [torso_point(-1.2 + 2.4 * m / 8.0, y + 0.02 * math.sin(m * 1.7 + k), -0.003) for m in range(9)]
        b.strand(points, [0.006, 0.009, 0.01, 0.01, 0.011, 0.01, 0.01, 0.009, 0.006], 6)
    # The sleeves, out at their rest
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        rings = [(SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM), rx, rz, z) for t, rx, rz, z in ARM]
        b.tube(smooth_rings(side * SHOULDER.x, SHOULDER.z, rings, 0.016), 14)
        # The puff of the shoulder, and the creases where the sleeve bags at the elbow
        b.ellipsoid(arm_point(side, 0.1, 0.0, 0.0), Vector((0.05, 0.05, 0.052)), None, 14, 6)
        for t, tilt in () if kit.LOW else ((0.85, 0.3), (1.1, -0.25), (1.65, 0.2)):
            rx, rz, _f = profile_of(ARM, t)
            b.ellipsoid(arm_point(side, t), Vector((rx + 0.004, 0.009, rz + 0.004)), Matrix.Rotation(tilt, 3, "X"), 14, 4)
    b.place = None
    return kit.fused(b, None if kit.LOW else SUIT_FUSE)


def suit_stains(p):
    """Old stains on the cloth (dark, whatever its shape): down the front from the
    collar, at the belly, the knees, the seat, the cuffs."""
    ax = abs(p.x)
    stain = 0.0
    for (cx, cy, cz, r) in ((0.03, 1.12, 0.07, 0.028), (0.05, 0.92, 0.1, 0.03), (-0.07, 0.82, 0.08, 0.024),
                            (0.0, 0.8, -0.09, 0.05), (0.06, 0.44, 0.06, 0.04), (-0.06, 0.4, 0.06, 0.035), (0.08, 0.98, -0.07, 0.03)):
        d = (Vector((p.x, p.y, p.z)) - Vector((cx, cy, cz))).length / r
        # (a ragged edge: the stain's reach wavers round it)
        wobble = 0.25 * math.sin(p.x * 140.0 + p.y * 90.0) * math.sin(p.z * 120.0 - p.y * 60.0)
        stain = max(stain, blend(1.0 + wobble, 0.7 + wobble, d))
    # (dirt soaked up the hems)
    hems = blend(0.2, 0.14, p.y) if p.y < 0.3 else 0.0
    cuffs = blend(0.6, 0.66, SHOULDER.y - p.y) * blend(0.06, 0.1, ax) if p.y < 0.75 and ax > 0.12 else 0.0
    return max(stain * 0.95, hems * 0.85, cuffs * 0.0)


# A trouser leg by how far along it is (0 the ankle, 1 the knee, 2 the hip): (where, half thickness, half width, forward).
LEG = [(0.2, 0.046, 0.062, 0.004), (0.32, 0.048, 0.066, 0.002), (0.6, 0.044, 0.06, 0.0), (1.0, 0.042, 0.058, 0.004),
       (1.35, 0.045, 0.062, 0.0), (1.75, 0.05, 0.07, 0.0), (2.0, 0.053, 0.074, 0.0), (2.12, 0.048, 0.064, 0.0)]


def leg_height(t):
    return ANKLE_Y + t * SHIN if t <= 1.0 else KNEE_Y + (t - 1.0) * THIGH


def legs(b):
    for side in (1.0, -1.0):
        x = side * HIP_X
        b.tube(smooth_rings(x, 0.0, [(leg_height(t), rx, rz, z) for t, rx, rz, z in LEG], 0.018), 16)
        # The cloth bagging at the knee and gathered above the cuff
        for t, tilt in () if kit.LOW else ((0.95, 0.25), (1.15, -0.3), (0.4, 0.15), (0.26, -0.1)):
            rx, rz, _f = profile_of(LEG, t)
            b.ellipsoid(Vector((x, leg_height(t), 0.0)), Vector((rx + 0.004, 0.01, rz + 0.004)), Matrix.Rotation(tilt, 3, "X"), 16, 4)


def ankles(b):
    """Thin dark stockings between the cuffs and the shoes: there is nothing to his legs."""
    for side in (1.0, -1.0):
        b.tube(smooth_rings(side * HIP_X, 0.0, [(0.04, 0.02, 0.022, 0.0), (0.1, 0.018, 0.02, 0.0), (0.16, 0.02, 0.022, 0.0)], 0.03), 10)


def shoes(b):
    """Long flat shoes with fat round toes (the front, past TOE, bends with the toe bone and flaps)."""
    for side in (1.0, -1.0):
        x = side * (HIP_X + 0.006)
        rings = [(z, y, rx, ry) for z, y, rx, ry in
                 ((-0.055, 0.04, 0.026, 0.028), (-0.035, 0.042, 0.036, 0.042), (0.0, 0.044, 0.04, 0.046), (0.05, 0.038, 0.042, 0.038),
                  (0.1, 0.034, 0.046, 0.034), (0.14, 0.036, 0.052, 0.036), (0.19, 0.042, 0.06, 0.042), (0.225, 0.042, 0.056, 0.04), (0.25, 0.04, 0.034, 0.03))]
        tube = [(Vector((x, y, z)), X * rx, Y * ry) for z, y, rx, ry in rings]
        b.tube(kit.dome(tube[0], -Z, 0.012, 3)[::-1] + tube + kit.dome(tube[-1], Z, 0.014, 3), 18, 0.004)
        # The fat round toe
        b.ellipsoid(Vector((x + side * 0.004, 0.038, 0.2)), Vector((0.052, 0.038, 0.06)), None, 18, 8)
        # The heel
        b.ellipsoid(Vector((x, 0.022, -0.03)), Vector((0.03, 0.022, 0.03)), None, 12, 5)


# --- Hands ---

def gloves(b):
    """White gloves: a cuff, and a puffy palm."""
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        wrist = hand_wrist(side)
        palm = [(0.05, 0.026, 0.03), (0.02, 0.022, 0.026), (0.0, 0.018, 0.024), (-0.025, 0.016, 0.03), (-0.045, 0.015, 0.031), (-PALM - 0.002, 0.013, 0.028)]
        rings = [(wrist + Y * dy, X * rx, Z * rz) for dy, rx, rz in palm]
        b.tube(rings + kit.dome(rings[-1], -Y, 0.008, 2), 14)
        if kit.LOW:
            inward = -side
            mitt = [(-PALM, 0.0, 0.013, 0.028), (-PALM - 0.04, 0.003, 0.012, 0.026), (-PALM - 0.065, 0.008, 0.009, 0.018)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
        else:
            # (three seams down the back of the glove)
            outward = side
            for index in range(1, 4):
                knuckle, _along = finger_line(side, index)
                back = Vector((outward * 0.013, 0.0, 0.0))
                b.strand([wrist + Vector((0.0, -0.01, (knuckle.z - wrist.z) * 0.5)) + back, knuckle + back * 0.9 + Vector((0.0, 0.006, 0.0))], [0.0018, 0.0018], 4)
    b.place = None


def fingers(b):
    """Fat, gloved."""
    if kit.LOW:
        return
    spans = (-0.15, 0.0, 0.2, 0.45, 0.6, 0.75, 0.9, 1.0)
    knobs = (1.0, 1.05, 0.98, 1.02, 0.95, 0.97, 0.88, 0.6)
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        for index, (_z, length, radius, _fan) in enumerate(FINGERS):
            knuckle, along = finger_line(side, index)
            b.strand([knuckle + along * length * t for t in spans], [radius * knob for knob in knobs], 8)
        root, along = thumb_line(side)
        b.strand([root + along * THUMB_LENGTH * t for t in (-0.2, 0.0, 0.3, 0.6, 0.85, 1.0)], [0.011, 0.011, 0.0105, 0.01, 0.009, 0.006], 8)
    b.place = None


# --- Ruffs and pom-poms ---

def ruff_lobes(centre, inner, outer, height, count, parity, axis=None, place=None):
    """A ring of pleats round `centre` (round Y, or `axis`): `count` flat lobes
    from `inner` out to `outer`, tilted up and down by turns; only those whose
    index is `parity` mod 2 (the ring is made in two parts, of two shades)."""
    shapes = []
    up = Vector(axis) if axis else Y
    side = (X if abs(up.dot(X)) < 0.9 else Z).cross(up).normalized()
    front = up.cross(side).normalized()
    for k in range(count):
        if k % 2 != parity:
            continue
        a = math.tau * k / count
        radial = side * math.sin(a) + front * math.cos(a)
        tangent = up.cross(radial).normalized()
        tilt = 0.3 if k % 2 == 0 else -0.22
        r = radial * math.cos(tilt) + up * math.sin(tilt)
        u = up * math.cos(tilt) - radial * math.sin(tilt)
        middle = (inner + outer) * 0.5
        shapes.append((centre + radial * middle + up * (math.sin(tilt) * middle * 0.5), Vector(((outer - inner) * 0.5 + 0.006, height, math.tau * middle / count * 0.62)), Matrix((r, u, tangent)).transposed()))
    return shapes


def ruffs(parity):
    def made(b):
        neck = Vector((0.0, 1.212, 0.004))
        for at, radii, tilt in ruff_lobes(neck, 0.026, 0.142, 0.02, 14 if kit.LOW else 26, parity):
            b.ellipsoid(at, radii, tilt, 12, 5)
        for side in (1.0, -1.0):
            # The cuffs of the sleeves, round the arm as it hangs (then out to its rest)
            b.place = arm_out(side)
            wrist = arm_point(side, 1.9)
            for at, radii, tilt in ruff_lobes(wrist, 0.02, 0.07, 0.013, 8 if kit.LOW else 16, parity):
                b.ellipsoid(at, radii, tilt, 10, 4)
            b.place = None
            # Round the ankles, over the shoes
            ankle = Vector((side * HIP_X, 0.132, 0.0))
            for at, radii, tilt in ruff_lobes(ankle, 0.018, 0.062, 0.012, 10 if kit.LOW else 16, parity):
                b.ellipsoid(at, radii, tilt, 10, 4)
    return made


def pompoms(b):
    """Fat pom-poms down the front of the suit."""
    for y in (1.12, 1.0, 0.88):
        _rx, rz, fwd = profile_at(TORSO, y)
        b.ellipsoid(Vector((0.0, y, rz + fwd + 0.008)), Vector((0.026, 0.024, 0.02)), None, 14, 7)


def dots(b):
    """Big faded dots on the suit, lying on the cloth."""
    rng = random.Random(3)
    for angle, y in ((0.6, 1.08), (-0.5, 0.95), (0.4, 0.83), (-1.3, 1.1), (1.5, 0.92), (2.4, 1.05), (-2.5, 0.86), (3.1, 1.0), (-0.9, 0.78)):
        normal = Vector((math.sin(angle), 0.0, math.cos(angle)))
        at = torso_point(angle, y, 0.001)
        across = Y.cross(normal).normalized()
        r = rng.uniform(0.03, 0.038)
        b.ellipsoid(at, Vector((r, r, 0.004)), Matrix((across, Y, normal)).transposed(), 12, 4)
    # On the trouser legs (demade, none)
    for side in () if kit.LOW else (1.0, -1.0):
        for t, angle in ((1.6, 0.4 * side), (0.7, -0.6 * side), (1.2, 2.6)):
            rx, rz, fwd = profile_of(LEG, t)
            normal = Vector((math.sin(angle), 0.0, math.cos(angle)))
            at = Vector((side * HIP_X + math.sin(angle) * (rx + 0.002), leg_height(t), math.cos(angle) * (rz + 0.002) + fwd))
            across = Y.cross(normal).normalized()
            b.ellipsoid(at, Vector((0.03, 0.03, 0.004)), Matrix((across, Y, normal)).transposed(), 12, 4)


def neck(b):
    b.tube(smooth_rings(0.0, 0.0, [(1.19, 0.03, 0.03, 0.004), (1.24, 0.024, 0.025, 0.008), (1.29, 0.023, 0.024, 0.014), (1.34, 0.024, 0.026, 0.02)], 0.015), 12)


# --- The head ---

# The pits of the eyes: (x, y) on the face from the head's middle, radii (across, up), how deep.
EYE = (0.025, 0.004, 0.0115, 0.014, 0.0035)


def face_xy(angle, phi):
    """Where a point of the head is on the face, before it is shaped (x, y from
    the head's middle): a tall dome above, and below, a long narrowing chin."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    return math.sin(angle) * HEAD_RADII.x * c * (1.0 - 0.22 * jaw ** 1.5), HEAD_RADII.y * s * (JAW if s < 0.0 else 1.0)


def head_point(angle, phi):
    """A point of the head: `angle` round from the front (towards its left), `phi` up from its middle."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    front = math.cos(angle)
    x, y = face_xy(angle, phi)
    behind = 0.1 * max(s, -0.1) + 0.06 if front < 0.0 else 0.0
    z = front * HEAD_RADII.z * c * (1.0 + behind) * (1.0 - (0.3 * jaw ** 1.5 if front < 0.0 else 0.05 * jaw)) + 0.008 * jaw
    p = Vector((x, y, z))
    out = Vector((x / HEAD_RADII.x ** 2, y / (HEAD_RADII.y * (JAW if s < 0.0 else 1.0)) ** 2, z / HEAD_RADII.z ** 2)).normalized()
    facing = blend(0.15, 0.6, front * c)
    ax = abs(x)

    def bump(u, v, cu, cv, su, sv):
        return math.exp(-((u - cu) / su) ** 2 - ((v - cv) / sv) ** 2)

    d = 0.0
    # A mask: the face flattened...
    d -= 0.007 * blend(0.55, 1.0, front * c)
    # ...a soft brow...
    d += 0.004 * bump(ax, y, 0.026, 0.026, 0.024, 0.008)
    # ...the pits of the eyes...
    u = (ax - EYE[0]) / EYE[2]
    v = (y - EYE[1]) / EYE[3]
    d -= EYE[4] * math.exp(-(u * u + v * v) * 1.4)
    # ...a small nose...
    d += 0.007 * bump(x, y, 0.0, -0.024, 0.008, 0.012)
    # ...the cheeks bunched up high, as a grin pushes them...
    d += 0.008 * bump(ax, y, 0.04, -0.034, 0.016, 0.014)
    # ...and a long chin
    d += 0.004 * bump(x, y, 0.0, -0.094, 0.018, 0.012)
    d *= facing
    # The temples, a little fallen in
    d -= 0.004 * bump(z, y, 0.026, 0.024, 0.022, 0.02) * blend(0.5, 0.9, abs(math.sin(angle)) * c)
    return HEAD_CENTRE + p + out * d


def head(b):
    """The bald dome and the mask of a face shaped into it."""
    segments, rows = (16, 12) if kit.LOW else (64, 48)
    grid = []
    for k in range(1, rows):
        phi = -math.pi / 2 + math.pi * k / rows
        row = []
        for j in range(segments):
            t = math.tau * j / segments - math.pi
            # (points crowd towards the front, where the face is)
            row.append(b._vert(head_point(t - (0.0 if kit.LOW else 0.42) * math.sin(t), phi), None))
        grid.append(row)
    faces = []
    for lower, upper in zip(grid, grid[1:]):
        for j in range(segments):
            n = (j + 1) % segments
            faces.append(b.bm.faces.new((lower[j], lower[n], upper[n], upper[j])))
    for row, phi in ((grid[0], -math.pi / 2), (grid[-1], math.pi / 2)):
        pole = b._vert(head_point(0.0, phi), None)
        for j in range(segments):
            faces.append(b.bm.faces.new((row[j], row[(j + 1) % segments], pole)))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    # The ears, small and flat to the head
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.061, -0.012, -0.008)), Vector((0.008, 0.02, 0.013)), Matrix.Rotation(side * 0.25, 3, "Y"), 10, 5)
    return kit.fused(b, None)


def face_place(x, y):
    """The (angle, phi) of the head that is at (x, y) on the face."""
    if y < 0.0:
        phi = math.asin(max(-1.0, y / (HEAD_RADII.y * JAW)))
    else:
        phi = math.asin(min(1.0, y / HEAD_RADII.y))
    c = math.cos(phi)
    jaw = max(0.0, -math.sin(phi))
    return math.asin(max(-1.0, min(1.0, x / (HEAD_RADII.x * c * (1.0 - 0.22 * jaw ** 1.5))))), phi


def on_face(x, y):
    """The point of the head at (x, y) on the face, and the way out of it there."""
    angle, phi = face_place(x, y)
    at = head_point(angle, phi)
    step = 0.01
    along = head_point(angle + step, phi) - head_point(angle - step, phi)
    up = head_point(angle, phi + step) - head_point(angle, phi - step)
    normal = along.cross(up).normalized()
    if normal.dot(at - HEAD_CENTRE) < 0.0:
        normal = -normal
    return at, normal


def ribbon(b, line, widths, lift, thick=0.0012):
    """Paint along a line of points on the face ((x, y) each), `widths` across it:
    a thin flat band lying on the face, following it round."""
    rings = []
    for k, ((x, y), w) in enumerate(zip(line, widths)):
        at, normal = on_face(x, y)
        ahead = Vector(line[min(k + 1, len(line) - 1)]) - Vector(line[max(k - 1, 0)])
        ahead = Vector((ahead.x, ahead.y, 0.0)).normalized()
        across = normal.cross(ahead).normalized()
        rings.append((at + normal * lift, across * w, normal * thick))
    b.tube(rings, 8)


def grin_line(s, reach=0.058):
    """The grin, `s` from -1 (its right corner) to 1: low in the middle, curling up into the cheeks."""
    x = reach * s
    return (x, -0.058 + 0.026 * s * s + 0.02 * s ** 4)


def eye_paint(b):
    """Tall dark diamonds painted through the eyes."""
    lift = 0.0028 if kit.LOW else 0.0011
    for side in (1.0, -1.0):
        steps = 9 if not kit.LOW else 5
        line, widths = [], []
        for k in range(steps):
            t = -1.0 + 2.0 * k / (steps - 1)
            line.append((side * (EYE[0] + 0.001 * t), EYE[1] + 0.008 + 0.044 * t))
            widths.append(0.0145 * (1.0 - abs(t)) ** 0.9 + 0.0008)
        ribbon(b, line, widths, lift)


def grin(b):
    """The painted grin, much wider than a mouth."""
    lift = 0.003 if kit.LOW else 0.0012
    steps = 21 if not kit.LOW else 9
    line, widths = [], []
    for k in range(steps):
        s = -1.0 + 2.0 * k / (steps - 1)
        line.append(grin_line(s))
        widths.append(0.0105 * (1.0 - s * s) ** 0.55 + 0.0012)
    ribbon(b, line, widths, lift)


def lips(b):
    """A thin dark line of closed lips along the middle of the grin."""
    lift = 0.0036 if kit.LOW else 0.0018
    steps = 13 if not kit.LOW else 7
    line, widths = [], []
    for k in range(steps):
        s = -1.0 + 2.0 * k / (steps - 1)
        x, y = grin_line(s * 0.7)
        line.append((x, y + 0.0008))
        widths.append(0.0024 * (1.0 - 0.6 * s * s) + 0.0006)
    ribbon(b, line, widths, lift, 0.0008)


def hair(b):
    """Tufts of thin hair standing out over the ears and round the back of the dome."""
    rng = random.Random(11)
    tufts = [(side * a, ph) for side in (1.0, -1.0) for a, ph in ((1.35, 0.18), (1.6, 0.3), (1.85, 0.22), (2.2, 0.3))] + [(math.pi, 0.25), (2.7, 0.4), (-2.7, 0.4)]
    for angle, phi in tufts:
        root = head_point(angle, phi)
        out = (root - HEAD_CENTRE)
        out = Vector((out.x, 0.0, out.z)).normalized()
        count = 3 if kit.LOW else 5
        for k in range(count):
            a = angle + rng.uniform(-0.14, 0.14)
            p = phi + rng.uniform(-0.1, 0.1)
            start = head_point(a, p)
            way = (out + Y * rng.uniform(0.1, 0.6) + Vector((rng.uniform(-0.3, 0.3), 0.0, rng.uniform(-0.3, 0.3)))).normalized()
            length = rng.uniform(0.035, 0.07)
            # (each wisp kinks and curls back on itself, as thin dry hair does)
            curl = way.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))).normalized()
            twist = rng.uniform(2.5, 4.5)
            points = [start - way * 0.005]
            for m in range(1, 7):
                t = m / 6.0
                points.append(start + way * length * t + curl * length * 0.3 * math.sin(t * twist) + Y * length * 0.25 * t * t)
            radius = 0.0019 if not kit.LOW else 0.0042
            b.strand(points, [radius, radius, radius * 0.95, radius * 0.85, radius * 0.7, radius * 0.5, radius * 0.3], 4)


# --- Bones and weights ---

def arm_weights(side, p):
    suffix = "_l" if side > 0.0 else "_r"
    down = SHOULDER.y - arm_in(side, p).y
    fore = blend(UPPER_ARM - 0.04, UPPER_ARM + 0.04, down)
    hand = blend(UPPER_ARM + FOREARM - 0.022, UPPER_ARM + FOREARM + 0.012, down)
    return {"upper_arm" + suffix: 1.0 - fore, "forearm" + suffix: fore * (1.0 - hand), "hand" + suffix: fore * hand}


def arm_share(side, p):
    """How much a point of the suit belongs to the sleeve on `side`: all of it a
    little way down the arm, none of it in the body, shared over the shoulder."""
    q = arm_in(side, p)
    down = SHOULDER.y - q.y
    off = Vector((q.x - side * SHOULDER.x, 0.0, q.z - SHOULDER.z)).length
    if off > 0.085:
        return 0.0
    return blend(-0.03, 0.06, down) * blend(0.085, 0.06, off)


def trunk_weights(p):
    low = blend(SPINE.y + 0.05, SPINE.y - 0.06, p.y)
    high = blend(CHEST.y - 0.07, CHEST.y + 0.05, p.y)
    middle = abs(p.x) < 0.07
    neck = blend(NECK.y - 0.01, NECK.y + 0.03, p.y) if middle else 0.0
    skull = blend(HEAD.y - 0.03, HEAD.y + 0.02, p.y) if middle else 0.0
    return {
        "hips": low,
        "spine": (1.0 - low) * (1.0 - high),
        "chest": (1.0 - low) * high * (1.0 - neck),
        "neck": neck * (1.0 - skull),
        "head": neck * skull,
    }


def leg_weights(p, suffix):
    leg = blend(HIP_Y + 0.05, HIP_Y - 0.06, p.y)
    shin = blend(KNEE_Y + 0.04, KNEE_Y - 0.04, p.y)
    foot = blend(0.085, 0.05, p.y)
    return {"hips": 1.0 - leg, "thigh" + suffix: leg * (1.0 - shin), "shin" + suffix: leg * shin * (1.0 - foot), "foot" + suffix: leg * shin * foot}


def suit_weights(side, p):
    share = arm_share(side, p)
    result = {bone: weight * (1.0 - share) for bone, weight in trunk_weights(p).items()}
    if share > 0.0:
        for bone, weight in arm_weights(side, p).items():
            result[bone] = result.get(bone, 0.0) + weight * share
    return result


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    if part in ("head", "eyes", "grin", "lips", "hair"):
        return {"head": 1.0}
    if part == "shoes":
        shin = blend(0.075, 0.11, p.y) * blend(0.03, 0.0, p.z)
        toe = blend(TOE.z - 0.03, TOE.z + 0.02, p.z)
        return {"shin" + suffix: shin, "foot" + suffix: (1.0 - shin) * (1.0 - toe), "toe" + suffix: (1.0 - shin) * toe}
    if part in ("legs", "ankles"):
        return leg_weights(p, suffix)
    if part == "gloves":
        return arm_weights(side, p)
    if part in ("ruff", "ruff_shade"):
        # (the collar on the chest, the cuffs on the forearms, the ankle ruffs on the shins)
        if p.y > 1.1:
            return {"chest": 0.75, "neck": 0.25}
        if p.y < 0.3:
            return {"shin" + suffix: 1.0}
        return arm_weights(side, p)
    if part == "fingers":
        q = arm_in(side, p)
        lines = [("finger%d" % index, finger_line(side, index), FINGERS[index][1], KNUCKLES) for index in range(len(FINGERS))]
        lines.append(("thumb", thumb_line(side), THUMB_LENGTH, (0.0, 0.5)))
        best = None
        for name, (root, along), length, joints in lines:
            t = (q - root).dot(along)
            away = (q - root - along * min(max(t, 0.0), length)).length
            if best is None or away < best[0]:
                best = (away, name, t / length, joints, length)
        _away, name, t, joints, length = best
        soft = 0.006 / length
        shares = [blend(joint - soft, joint + soft, t) for joint in joints]
        result = {"hand" + suffix: 1.0 - shares[0]}
        for k, letter in enumerate("abc"[:len(joints)]):
            result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(shares) else 0.0)
        return result
    if part == "dots" and p.y < HIP_Y - 0.02 and abs(p.x) < 0.14:
        return leg_weights(p, suffix)
    # The suit and the sleeves, what lies on it, and the neck
    return suit_weights(side, p)


def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("chest", CHEST, "spine"), ("neck", NECK, "chest"), ("head", HEAD, "neck")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        shoulder = shoulder_of(side)
        out = arm_out(side)
        listed.append(("upper_arm" + suffix, shoulder, "chest"))
        listed.append(("forearm" + suffix, out(shoulder - Y * UPPER_ARM), "upper_arm" + suffix))
        listed.append(("hand" + suffix, out(shoulder - Y * (UPPER_ARM + FOREARM)), "forearm" + suffix))
        for index in range(len(FINGERS)):
            knuckle, along = finger_line(side, index)
            parent = "hand" + suffix
            for letter, share in zip("abc", KNUCKLES):
                listed.append(("finger%d%s%s" % (index, letter, suffix), out(knuckle + along * FINGERS[index][1] * share), parent))
                parent = listed[-1][0]
        root, along = thumb_line(side)
        listed.append(("thumba" + suffix, out(root), "hand" + suffix))
        listed.append(("thumbb" + suffix, out(root + along * THUMB_LENGTH * 0.5), "thumba" + suffix))
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        listed.append(("thigh" + suffix, hip, "hips"))
        listed.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        listed.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
    return listed


# (part, material, shapes, how to fuse it). Each fuses itself, if at all (`painted`).
PARTS = [
    ("suit", 0, painted(suit, SUIT, SUIT_FUSE, -0.012, suit_stains), None),
    ("legs", 0, painted(legs, SUIT, (0.0034, 3, 4000), -0.01, suit_stains), None),
    ("ankles", 0, painted(ankles, STOCKING), None),
    ("shoes", 0, painted(shoes, SHOES, (0.003, 3, 2400), -0.004), None),
    ("gloves", 0, painted(gloves, GLOVE, (0.0022, 2, 1400), 0.0), None),
    ("fingers", 0, painted(fingers, GLOVE, (0.002, 2, 2200), 0.0), None),
    ("ruff", 0, painted(ruffs(0), RUFF, (0.0026, 2, 2400)), None),
    ("ruff_shade", 0, painted(ruffs(1), RUFF_SHADE, (0.0026, 2, 2400)), None),
    ("dots", 0, painted(dots, DOTS), None),
    ("pompoms", 0, painted(pompoms, POMPOM), None),
    ("neck", 0, painted(neck, GREASEPAINT), None),
    ("head", 0, painted(head, GREASEPAINT, None, -0.003), None),
    ("eyes", 0, painted(eye_paint, DARK), None),
    ("grin", 0, painted(grin, ROUGE), None),
    ("lips", 0, painted(lips, DARK), None),
    ("hair", 0, painted(hair, HAIR), None),
]


def previews(folder, name):
    """Renders all round it, and the face close to, in its own colours."""
    scene = bpy.context.scene
    scene.display.shading.color_type = "VERTEX"
    camera = scene.camera
    middle = kit.to_blender(HEAD_CENTRE + Vector((0.0, -0.02, 0.0)))
    views = [("front", (0, -1, 0.05), (0.0, 0.0, 0.76), 1.7), ("side", (1, 0, 0.05), (0.0, 0.0, 0.76), 1.7),
             ("quarter", (0.7, -0.7, 0.2), (0.0, 0.0, 0.76), 1.7), ("back", (0.25, 1, 0.15), (0.0, 0.0, 0.76), 1.7),
             ("chest", (0.3, -1, 0.15), (0.0, 0.0, 1.1), 0.6), ("shoes", (0.7, -0.7, 0.4), (0.0, -0.08, 0.08), 0.6),
             ("hand", (-0.6, -0.7, 0.1), kit.to_blender(arm_out(1.0)(hand_wrist(1.0) - Y * 0.04)), 0.3),
             ("face", (0, -1, 0.0), middle, 0.3), ("face_quarter", (0.7, -0.7, 0.1), middle, 0.3), ("face_side", (1, -0.05, 0.0), middle, 0.3)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    os.makedirs(os.path.join(COMPONENT, "tools"), exist_ok=True)
    kit.export("clown", bones(), PARTS, weights, MATERIALS)
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "clown")
    kit.LOW = True
    kit.export("clown_lo", bones(), PARTS, weights, MATERIALS)
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "clown_lo")
