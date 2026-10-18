"""Builds the psychic child and exports her for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/psychic_child/tools/build_psychic_child.py [-- <folder for preview renders>]

Writes creatures/psychic_child/models/psychic_child.glb and psychic_child_lo.glb.

A small, thin child of six or so, on the boy's and the mummy's bone names (so
CharacterRig, and PsychicChildRig on it, can move her), a good head shorter
than the boy: a big head on a thin neck, narrow shoulders, sticks of arms and
legs, bare feet. She wears one plain, washed-out smock, as a hospital would
give out: a round neck, short loose sleeves, cut straight and wide to just
above the knee, tied twice at the back, hanging in a few soft folds. Her head
is shaved, the stubble a grey shadow over the scalp down to a child's
hairline; her face is the boy's kind of mask, only softer: a brow, shallow
hollows for eyes, the least of a nose, a small chin, and no mouth.

Everything but the blood is one material (one draw): each part's colour is
baked into the model as its vertex colour, and how far each point lies in a
fold or a hollow (or how dirty it is: her soles, the hem) as the colour's
alpha (see `painted`); PsychicChildRig darkens it in one soft step. The
nosebleed is an object of its own (`psychic_child_blood`, a second material):
two thin trickles from her nose over where a mouth would be and down off the
chin, laid on the face. Each runs along its texture's U from 0 at the nose to
1 at its end, so the game can let it run as far as it likes (and hides it
while there is none).

As the clown and the mummy are, it is modelled with its arms held out from its
sides (ARM_REST), in Godot space (metres, Y up, facing +Z, +X her left).
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
    """bpy as the kit sees it, but for two things: its glTF export also writes
    the model's colour attribute (PAINT), which by default it leaves out unless
    a material uses it; and the editable .blend it would save is not saved."""

    class _Scene:
        def gltf(self, **options):
            for mesh in bpy.data.meshes:
                if PAINT in mesh.color_attributes:
                    mesh.color_attributes.active_color_name = PAINT
                    mesh.color_attributes.render_color_index = mesh.color_attributes.find(PAINT)
            options.setdefault("export_vertex_color", "ACTIVE")
            options.setdefault("export_all_vertex_colors", False)
            return bpy.ops.export_scene.gltf(**options)

    class _Wm:
        def save_as_mainfile(self, **_options):
            return {"FINISHED"}

        def __getattr__(self, name):
            return getattr(bpy.ops.wm, name)

    class _Ops:
        export_scene = None
        wm = None

        def __getattr__(self, name):
            return getattr(bpy.ops, name)

    def __init__(self):
        self.ops = _Export._Ops()
        self.ops.export_scene = _Export._Scene()
        self.ops.wm = _Export._Wm()

    def __getattr__(self, name):
        return getattr(bpy, name)


kit.bpy = _Export()

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

# --- Joints ---

ANKLE_Y = 0.042
SHIN = 0.21
THIGH = 0.22
HIP_X = 0.048
HIP_Y = ANKLE_Y + SHIN + THIGH
KNEE_Y = HIP_Y - THIGH
HIPS = Vector((0.0, HIP_Y + 0.018, 0.0))
SPINE = Vector((0.0, 0.55, 0.0))
CHEST = Vector((0.0, 0.64, 0.0))
NECK = Vector((0.0, 0.735, 0.0))
HEAD = Vector((0.0, 0.775, 0.004))
SHOULDER = Vector((0.084, 0.705, 0.0))
UPPER_ARM = 0.145
FOREARM = 0.13
ARM_REST = 0.35
TOE = Vector((0.0, -0.03, 0.055))
# The head: half its width, its height above the middle, its depth; the chin is JAW times as far below.
# (a child's: big, round, the face small and low on it)
HEAD_RADII = Vector((0.078, 0.085, 0.083))
HEAD_CENTRE = HEAD + Vector((0.0, 0.08, 0.008))
JAW = 1.0

MATERIALS = [("child", (1.0, 1.0, 1.0)), ("blood", (0.36, 0.06, 0.05))]

# The colours, sRGB. Nothing saturated: the smock washed out to a grey with a
# breath of green in it, the skin pale, the stubble a cold grey shadow.
SMOCK = (0.67, 0.685, 0.68)
TIES = (0.61, 0.625, 0.62)
SKIN = (0.74, 0.715, 0.7)
STUBBLE = (0.44, 0.435, 0.435)
BLOOD = (0.36, 0.06, 0.05)

# Fingers, index to little: (offset across the palm, length, thickness, how far it fans out).
FINGERS = [(0.0115, 0.03, 0.0052, 0.22), (0.0039, 0.034, 0.0055, 0.07), (-0.0039, 0.032, 0.0054, -0.07), (-0.0115, 0.026, 0.005, -0.22)]
KNUCKLES = (0.0, 0.45, 0.75)
PALM = 0.034
THUMB_LENGTH = 0.026


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
    return hand_wrist(side) + Vector((inward * 0.004, -0.012, 0.013)), Vector((inward * 0.25, -0.7, 0.66)).normalized()


def smooth_rings(x, z, profile, band=0.014):
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
    """(half thickness, half width, forward) of a limb's profile `t` along it."""
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
    """A part made by `shapes` (fused as `fuse` says), of one colour (or of the
    colour `colour` gives for each point, if it is a function), with how much
    grime is in each point as the colour's alpha: 0.5 exactly where it sinks in
    by `threshold` (see concavity), more where further, less where it stands
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
        attribute = mesh.color_attributes.new(PAINT, "FLOAT_COLOR", "POINT")
        for index, (item, vertex) in enumerate(zip(attribute.data, mesh.vertices)):
            p = kit.from_blender(vertex.co)
            grime = 0.0
            if deep is not None:
                grime = min(max(0.5 + (deep[index] - threshold) / 0.03, 0.0), 1.0)
            if stains:
                grime = max(grime, stains(p))
            rgb = colour(p) if callable(colour) else colour
            item.color = tuple(linear(c) for c in rgb) + (grime,)
        return mesh
    return made


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# --- The smock ---

# (height, half width, half depth, how far forward): from the hem, just above
# her knees, up the straight wide skirt, over a child's body with no waist to
# speak of, to narrow shoulders and a round neck.
TORSO = [(0.3, 0.113, 0.093, 0.008), (0.34, 0.108, 0.088, 0.006), (0.4, 0.099, 0.08, 0.003), (0.46, 0.09, 0.07, 0.0),
         (0.52, 0.081, 0.062, 0.0), (0.58, 0.077, 0.059, 0.003), (0.635, 0.078, 0.059, 0.006), (0.68, 0.077, 0.055, 0.004),
         (0.705, 0.07, 0.048, 0.0), (0.726, 0.052, 0.04, 0.0), (0.744, 0.034, 0.031, 0.004)]
SMOCK_FUSE = (0.0026, 3, 7000)

# A sleeve (0 the shoulder, 1 the elbow): (where, half thickness, half width, forward). Short and loose.
SLEEVE = [(-0.14, 0.026, 0.029, 0.0), (0.0, 0.029, 0.031, 0.0), (0.18, 0.028, 0.03, 0.0), (0.38, 0.0285, 0.0305, 0.0), (0.43, 0.026, 0.028, 0.0)]


def arm_point(side, t, out=0.0, forward=0.0):
    """A point on an arm hanging straight down, `t` along it (0 the shoulder, 1 the elbow, 2 the wrist)."""
    y = SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM)
    return Vector((side * (SHOULDER.x + out), y, SHOULDER.z + forward))


def torso_point(angle, y, out=0.0):
    """A point on the smock's body, `angle` round from the front (towards her left), at height `y`."""
    rx, rz, fwd = profile_at(TORSO, y)
    return Vector((math.sin(angle) * (rx + out), y, math.cos(angle) * (rz + out) + fwd))


def smock(_builder):
    """The smock's body and its sleeves, the soft folds it hangs in and the hem: one surface."""
    b = kit.Builder()
    b.tube(smooth_rings(0.0, 0.0, TORSO), 24)
    # A few soft folds down the skirt from the chest, and two at the back from the ties
    # (demade, there are none: they would stand out of it as sticks)
    rng = random.Random(5)
    for angle in () if kit.LOW else (0.42, -0.5, 1.15, -1.2, 2.2, -2.15, 2.85, -2.9):
        top = 0.6 - 0.06 * abs(math.sin(angle)) + rng.uniform(-0.02, 0.02)
        points = [torso_point(angle + 0.05 * math.sin(k * 1.1), top - (top - 0.305) * k / 5.0, -0.003) for k in range(6)]
        b.strand(points, [0.003, 0.005, 0.0065, 0.0075, 0.0075, 0.006], 6)
    # The hem, turned up
    if not kit.LOW:
        b.tube([(Vector((0.0, 0.3, 0.008)), X * 0.114, Z * 0.094), (Vector((0.0, 0.307, 0.008)), X * 0.115, Z * 0.095),
                (Vector((0.0, 0.316, 0.007)), X * 0.112, Z * 0.092)], 24)
    # The sleeves, out at their rest
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        rings = sorted((SHOULDER.y - t * UPPER_ARM, rx, rz, z) for t, rx, rz, z in SLEEVE)
        b.tube(smooth_rings(side * SHOULDER.x, SHOULDER.z, rings, 0.012), 14)
        b.ellipsoid(arm_point(side, 0.06), Vector((0.029, 0.026, 0.031)), None, 14, 6)
    b.place = None
    return kit.fused(b, None if kit.LOW else SMOCK_FUSE)


def smock_stains(p):
    """The smock is clean but for what the maze has put on it: mud soaked up the
    hem, a smear on the front where she has wiped her hands, and a dark drop or two
    on the chest under her chin (old nosebleeds)."""
    stain = 0.0
    for (cx, cy, cz, r) in ((0.04, 0.42, 0.085, 0.03), (-0.05, 0.37, 0.09, 0.022), (0.006, 0.66, 0.06, 0.009), (-0.01, 0.645, 0.062, 0.007)):
        d = (p - Vector((cx, cy, cz))).length / r
        wobble = 0.25 * math.sin(p.x * 160.0 + p.y * 110.0) * math.sin(p.z * 130.0 - p.y * 70.0)
        stain = max(stain, blend(1.0 + wobble, 0.7 + wobble, d))
    hem = blend(0.33, 0.305, p.y) * (0.8 + 0.2 * math.sin(math.atan2(p.x, p.z) * 7.0))
    return max(stain * 0.9, hem * 0.8)


def ties(b):
    """The two ties at the back: at the neck and the middle, a small knot and two short ends hanging."""
    for y in (0.715, 0.55):
        _rx, rz, fwd = profile_at(TORSO, y)
        back = fwd - rz - 0.0015
        b.ellipsoid(Vector((0.0, y, back)), Vector((0.007, 0.006, 0.005)), None, 10, 5)
        for side in (1.0, -1.0):
            points = [Vector((side * 0.004, y - 0.002, back - 0.001)), Vector((side * 0.008, y - 0.022, back + 0.0005)),
                      Vector((side * 0.01, y - 0.042, back + 0.0015))]
            b.strand(points, [0.0032, 0.0028, 0.0024], 5)


# --- Her bare arms and legs ---

# A bare arm (0 the shoulder, 1 the elbow, 2 the wrist): (where, half thickness, half width, forward).
ARM = [(0.12, 0.02, 0.021, 0.0), (0.5, 0.0175, 0.0185, 0.0), (0.92, 0.0155, 0.0162, 0.0), (1.05, 0.0158, 0.016, 0.0),
       (1.3, 0.0158, 0.0168, 0.0), (1.7, 0.0128, 0.0138, 0.0), (1.97, 0.0106, 0.0118, 0.0), (2.04, 0.0102, 0.0114, 0.0)]


def arms(b):
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        rings = sorted((SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM), rx, rz, z) for t, rx, rz, z in ARM)
        b.tube(smooth_rings(side * SHOULDER.x, SHOULDER.z, rings, 0.012), 12)
        # (the bump of the elbow)
        if not kit.LOW:
            b.ellipsoid(arm_point(side, 1.0, 0.0, -0.008), Vector((0.011, 0.012, 0.01)), None, 10, 5)
    b.place = None


def hands(b):
    """Small hands: a palm, widening to the knuckles."""
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        wrist = hand_wrist(side)
        palm = [(0.012, 0.0098, 0.0118), (0.0, 0.0094, 0.0125), (-0.012, 0.0088, 0.0158), (-0.024, 0.0082, 0.0175), (-PALM - 0.001, 0.0072, 0.016)]
        rings = [(wrist + Y * dy, X * rx, Z * rz) for dy, rx, rz in palm]
        b.tube(rings + kit.dome(rings[-1], -Y, 0.005, 2), 12)
        if kit.LOW:
            inward = -side
            mitt = [(-PALM, 0.0, 0.0072, 0.016), (-PALM - 0.024, 0.002, 0.0066, 0.014), (-PALM - 0.036, 0.004, 0.005, 0.009)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
    b.place = None


def fingers(b):
    if kit.LOW:
        return
    spans = (-0.15, 0.0, 0.2, 0.45, 0.6, 0.75, 0.9, 1.0)
    knobs = (1.0, 1.05, 0.96, 1.0, 0.92, 0.94, 0.85, 0.6)
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        for index, (_z, length, radius, _fan) in enumerate(FINGERS):
            knuckle, along = finger_line(side, index)
            b.strand([knuckle + along * length * t for t in spans], [radius * knob for knob in knobs], 7)
        root, along = thumb_line(side)
        b.strand([root + along * THUMB_LENGTH * t for t in (-0.2, 0.0, 0.3, 0.6, 0.85, 1.0)], [0.0062, 0.0062, 0.0058, 0.0054, 0.0048, 0.0032], 7)
    b.place = None


# A bare leg by how far along it is (0 the ankle, 1 the knee, 2 the hip): (where, half thickness, half width, forward).
LEG = [(-0.05, 0.0145, 0.0155, -0.002), (0.15, 0.0158, 0.0172, 0.0), (0.45, 0.021, 0.0218, -0.003), (0.8, 0.019, 0.0198, 0.0),
       (1.0, 0.0198, 0.0205, 0.002), (1.15, 0.0205, 0.021, 0.0), (1.5, 0.0245, 0.0255, 0.0), (1.9, 0.029, 0.031, 0.0), (2.12, 0.029, 0.03, 0.0)]


def leg_height(t):
    return ANKLE_Y + t * SHIN if t <= 1.0 else KNEE_Y + (t - 1.0) * THIGH


def legs(b):
    for side in (1.0, -1.0):
        x = side * HIP_X
        b.tube(smooth_rings(x, 0.0, [(leg_height(t), rx, rz, z) for t, rx, rz, z in LEG], 0.014), 12)
        if not kit.LOW:
            # (the knee, a knob on a thin leg)
            b.ellipsoid(Vector((x, KNEE_Y + 0.004, 0.009)), Vector((0.0145, 0.016, 0.011)), None, 10, 5)


def feet(b):
    """Bare feet, small and narrow, with toes."""
    for side in (1.0, -1.0):
        x = side * HIP_X
        rings = [(-0.03, 0.019, 0.0118, 0.013), (-0.02, 0.021, 0.0155, 0.019), (0.0, 0.024, 0.0172, 0.021), (0.022, 0.017, 0.0195, 0.0135),
                 (0.045, 0.0118, 0.0215, 0.0098), (0.06, 0.0102, 0.021, 0.0082)]
        tube = [(Vector((x + side * 0.002 * max(z, 0.0) / 0.06, y, z)), X * rx, Y * ry) for z, y, rx, ry in rings]
        b.tube(kit.dome(tube[0], -Z, 0.008, 3)[::-1] + tube + kit.dome(tube[-1], Z, 0.006, 3), 14)
        # The toes, the big one inside
        if kit.LOW:
            continue
        # ((across, inward negative), how far ahead, how big)
        for across, ahead, r in ((-0.012, 0.073, 0.0058), (-0.003, 0.071, 0.0046), (0.005, 0.068, 0.0042), (0.012, 0.064, 0.0038), (0.018, 0.059, 0.0034)):
            b.ellipsoid(Vector((x + side * across, 0.0075 + r * 0.25, ahead)), Vector((r, r * 0.85, r * 1.15)), None, 8, 4)


def foot_dirt(p):
    """The soles black with the maze's mud, and dirt up over the toes and ankles."""
    return max(blend(0.009, 0.004, p.y), blend(0.075, 0.03, p.y) * 0.62)


def leg_dirt(p):
    return blend(0.08, 0.05, p.y) * 0.62 + blend(KNEE_Y + 0.02, KNEE_Y - 0.01, p.y) * blend(KNEE_Y - 0.04, KNEE_Y - 0.01, p.y) * 0.0


def neck(b):
    b.tube(smooth_rings(0.0, 0.0, [(0.715, 0.029, 0.028, 0.002), (0.75, 0.026, 0.025, 0.006), (0.78, 0.0245, 0.024, 0.01), (0.8, 0.025, 0.026, 0.012)], 0.012), 12)


# --- The head ---

# The hollows of the eyes: (x, y) on the face from the head's middle, radii (across, up), how deep.
EYE = (0.027, -0.012, 0.014, 0.0125, 0.0038)


def face_xy(angle, phi):
    """Where a point of the head is on the face, before it is shaped (x, y from
    the head's middle): a round dome above, and below, a small soft chin."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    return math.sin(angle) * HEAD_RADII.x * c * (1.0 - 0.17 * jaw ** 1.6), HEAD_RADII.y * s * (JAW if s < 0.0 else 1.0)


def head_point(angle, phi):
    """A point of the head: `angle` round from the front (towards her left), `phi` up from its middle."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    front = math.cos(angle)
    x, y = face_xy(angle, phi)
    # (a child's skull: full behind, over the nape)
    behind = 0.14 * max(s + 0.2, 0.0) + 0.05 if front < 0.0 else 0.0
    z = front * HEAD_RADII.z * c * (1.0 + behind * (-front)) * (1.0 - (0.32 * jaw ** 1.5 if front < 0.0 else 0.06 * jaw)) + 0.006 * jaw
    p = Vector((x, y, z))
    out = Vector((x / HEAD_RADII.x ** 2, y / (HEAD_RADII.y * (JAW if s < 0.0 else 1.0)) ** 2, z / HEAD_RADII.z ** 2)).normalized()
    facing = blend(0.15, 0.6, front * c)
    ax = abs(x)

    def bump(u, v, cu, cv, su, sv):
        return math.exp(-((u - cu) / su) ** 2 - ((v - cv) / sv) ** 2)

    d = 0.0
    # A mask: the face a little flattened...
    d -= 0.004 * blend(0.55, 1.0, front * c)
    # ...a soft brow...
    d += 0.0032 * bump(ax, y, 0.026, 0.014, 0.024, 0.008)
    # ...shallow hollows for eyes...
    u = (ax - EYE[0]) / EYE[2]
    v = (y - EYE[1]) / EYE[3]
    d -= EYE[4] * math.exp(-(u * u + v * v) * 1.4)
    # ...the least of a nose...
    d += 0.0028 * bump(x, y, 0.0, -0.034, 0.0065, 0.01)
    # ...round cheeks...
    d += 0.0035 * bump(ax, y, 0.038, -0.042, 0.018, 0.016)
    # ...and a small chin; no mouth
    d += 0.003 * bump(x, y, 0.0, -0.074, 0.015, 0.01)
    d *= facing
    return HEAD_CENTRE + p + out * d


def scalp_colour(p):
    """The shaved head: stubble down to a child's hairline (high on the brow, round
    over the ears, low at the nape), skin below it."""
    q = p - HEAD_CENTRE
    angle = math.atan2(q.x, q.z)
    front = math.cos(angle)
    line = -0.062 + 0.105 * blend(-0.75, 0.95, front)
    # (round over the ears, and in at the temples)
    line += 0.01 * math.exp(-((abs(angle) - 1.45) / 0.3) ** 2) + 0.012 * math.exp(-((abs(angle) - 0.85) / 0.22) ** 2)
    return mix(SKIN, STUBBLE, blend(line - 0.007, line + 0.007, q.y) * 0.85)


def head(b):
    """The shaved dome and the mask of a face shaped into it."""
    segments, rows = (16, 12) if kit.LOW else (56, 42)
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
    # The ears, small, standing out a little from the shaved head
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.076, -0.018, -0.008)), Vector((0.0085, 0.019, 0.013)), Matrix.Rotation(side * 0.35, 3, "Y"), 10, 5)
    return kit.fused(b, None)


def face_place(x, y):
    """The (angle, phi) of the head that is at (x, y) on the face."""
    if y < 0.0:
        phi = math.asin(max(-1.0, y / (HEAD_RADII.y * JAW)))
    else:
        phi = math.asin(min(1.0, y / HEAD_RADII.y))
    c = math.cos(phi)
    jaw = max(0.0, -math.sin(phi))
    return math.asin(max(-1.0, min(1.0, x / (HEAD_RADII.x * c * (1.0 - 0.17 * jaw ** 1.6))))), phi


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
    """A thin flat band lying on the face along a line of points ((x, y) each), `widths` across it."""
    rings = []
    for k, ((x, y), w) in enumerate(zip(line, widths)):
        at, normal = on_face(x, y)
        ahead = Vector(line[min(k + 1, len(line) - 1)]) - Vector(line[max(k - 1, 0)])
        ahead = Vector((ahead.x, ahead.y, 0.0)).normalized()
        across = normal.cross(ahead).normalized()
        rings.append((at + normal * lift, across * w, normal * thick))
    b.tube(rings, 6)


def blood(b):
    """The nosebleed: two trickles from under the nose, over where a mouth would be,
    to the chin and down off it, the left one further. U runs 0 at the nose to 1 at the end."""
    lift = 0.0026 if kit.LOW else 0.0011
    steps = 6 if kit.LOW else 14
    for side, reach, wander in ((1.0, 1.0, 0.0035), (-1.0, 0.72, 0.0025)):
        line, widths = [], []
        for k in range(steps):
            t = k / (steps - 1)
            y = -0.041 - (0.05 * reach) * t
            x = side * (0.0045 + 0.002 * t) + wander * math.sin(t * 9.0 + side) * t
            line.append((x, y))
            widths.append(0.0016 * (1.0 - 0.3 * t) + 0.0006 * math.sin(t * 13.0) ** 2)
        ribbon(b, line, widths, lift, 0.0009)
        if reach > 0.9:
            # (a drop hanging from the chin)
            at, normal = on_face(line[-1][0], line[-1][1])
            b.ellipsoid(at + normal * 0.0015 - Y * 0.002, Vector((0.0026, 0.0034, 0.0024)), None, 8, 4)


# --- Bones and weights ---

def arm_weights(side, p):
    suffix = "_l" if side > 0.0 else "_r"
    down = SHOULDER.y - arm_in(side, p).y
    fore = blend(UPPER_ARM - 0.03, UPPER_ARM + 0.03, down)
    hand = blend(UPPER_ARM + FOREARM - 0.016, UPPER_ARM + FOREARM + 0.008, down)
    return {"upper_arm" + suffix: 1.0 - fore, "forearm" + suffix: fore * (1.0 - hand), "hand" + suffix: fore * hand}


def arm_share(side, p):
    """How much a point of the smock belongs to the sleeve on `side`: all of it a
    little way down the arm, none of it in the body, shared over the shoulder."""
    q = arm_in(side, p)
    down = SHOULDER.y - q.y
    off = Vector((q.x - side * SHOULDER.x, 0.0, q.z - SHOULDER.z)).length
    if off > 0.06:
        return 0.0
    return blend(-0.02, 0.04, down) * blend(0.06, 0.042, off)


def trunk_weights(p):
    low = blend(SPINE.y + 0.04, SPINE.y - 0.05, p.y)
    high = blend(CHEST.y - 0.05, CHEST.y + 0.04, p.y)
    middle = abs(p.x) < 0.05
    neck = blend(NECK.y - 0.008, NECK.y + 0.022, p.y) if middle else 0.0
    skull = blend(HEAD.y - 0.02, HEAD.y + 0.015, p.y) if middle else 0.0
    return {
        "hips": low,
        "spine": (1.0 - low) * (1.0 - high),
        "chest": (1.0 - low) * high * (1.0 - neck),
        "neck": neck * (1.0 - skull),
        "head": neck * skull,
    }


def skirt_weights(p):
    """Below the hips the skirt goes with the thighs too, more towards the hem, each side with its own."""
    result = trunk_weights(p)
    down = blend(HIP_Y + 0.03, HIP_Y - 0.15, p.y)
    if down <= 0.0:
        return result
    left = blend(-0.035, 0.035, p.x)
    share = 0.72 * down
    result = {bone: weight * (1.0 - share) for bone, weight in result.items()}
    result["thigh_l"] = share * left
    result["thigh_r"] = share * (1.0 - left)
    return result


def leg_weights(p, suffix):
    leg = blend(HIP_Y + 0.035, HIP_Y - 0.045, p.y)
    shin = blend(KNEE_Y + 0.03, KNEE_Y - 0.03, p.y)
    foot = blend(0.07, 0.04, p.y)
    return {"hips": 1.0 - leg, "thigh" + suffix: leg * (1.0 - shin), "shin" + suffix: leg * shin * (1.0 - foot), "foot" + suffix: leg * shin * foot}


def smock_weights(side, p):
    share = arm_share(side, p)
    result = {bone: weight * (1.0 - share) for bone, weight in skirt_weights(p).items()}
    if share > 0.0:
        for bone, weight in arm_weights(side, p).items():
            result[bone] = result.get(bone, 0.0) + weight * share
    return result


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    if part in ("head", "blood"):
        return {"head": 1.0}
    if part == "feet":
        shin = blend(0.05, 0.075, p.y) * blend(0.02, 0.0, p.z)
        toe = blend(TOE.z - 0.02, TOE.z + 0.012, p.z)
        return {"shin" + suffix: shin, "foot" + suffix: (1.0 - shin) * (1.0 - toe), "toe" + suffix: (1.0 - shin) * toe}
    if part == "legs":
        return leg_weights(p, suffix)
    if part in ("arms", "hands"):
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
        soft = 0.004 / length
        shares = [blend(joint - soft, joint + soft, t) for joint in joints]
        result = {"hand" + suffix: 1.0 - shares[0]}
        for k, letter in enumerate("abc"[:len(joints)]):
            result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(shares) else 0.0)
        return result
    if part == "ties":
        return skirt_weights(p)
    # The smock and the sleeves, and the neck
    return smock_weights(side, p)


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
    ("smock", 0, painted(smock, SMOCK, SMOCK_FUSE, -0.02, smock_stains), None),
    ("ties", 0, painted(ties, TIES), None),
    ("arms", 0, painted(arms, SKIN, (0.0022, 2, 2400), -0.01), None),
    ("hands", 0, painted(hands, SKIN, (0.0016, 2, 1200), 0.0), None),
    ("fingers", 0, painted(fingers, SKIN, (0.0014, 2, 2400), 0.0), None),
    ("legs", 0, painted(legs, SKIN, (0.0022, 2, 3000), -0.01, leg_dirt), None),
    ("feet", 0, painted(feet, SKIN, (0.0018, 2, 2400), -0.006, foot_dirt), None),
    ("neck", 0, painted(neck, SKIN), None),
    ("head", 0, painted(head, scalp_colour), None),
    ("blood", 1, painted(blood, BLOOD), None),
]


def previews(folder, name):
    """Renders all round her, and the face close to, in her own colours."""
    scene = bpy.context.scene
    scene.display.shading.color_type = "VERTEX"
    camera = scene.camera
    middle = kit.to_blender(HEAD_CENTRE + Vector((0.0, -0.015, 0.0)))
    views = [("front", (0, -1, 0.05), (0.0, 0.0, 0.5), 1.15), ("side", (1, 0, 0.05), (0.0, 0.0, 0.5), 1.15),
             ("quarter", (0.7, -0.7, 0.2), (0.0, 0.0, 0.5), 1.15), ("back", (0.25, 1, 0.15), (0.0, 0.0, 0.5), 1.15),
             ("feet", (0.7, -0.7, 0.4), (0.0, -0.03, 0.04), 0.35),
             ("hand", (-0.6, -0.7, 0.1), kit.to_blender(arm_out(1.0)(hand_wrist(1.0) - Y * 0.03)), 0.2),
             ("face", (0, -1, 0.0), middle, 0.26), ("face_quarter", (0.7, -0.7, 0.1), middle, 0.26), ("face_side", (1, -0.05, 0.0), middle, 0.26)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    kit.export("psychic_child", bones(), PARTS, weights, MATERIALS, apart=("blood",))
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "psychic_child")
    kit.LOW = True
    kit.export("psychic_child_lo", bones(), PARTS, weights, MATERIALS, apart=("blood",))
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "psychic_child_lo")
