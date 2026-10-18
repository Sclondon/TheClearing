"""Builds the ghoul and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/ghoul/tools/build_ghoul.py [-- <folder for preview renders>]

Writes creatures/ghoul/models/ghoul.glb and ghoul_lo.glb (and editable .blend
copies beside this file, which are not kept: this folder has a .gdignore so
that Godot does not try to import them).

It is a mummy with nothing left on: the same bones and names as the mummy and
the boy (so CharacterRig, and GhoulRig on it, can move it), and a body of the
same wrong proportions, made bare. Long, thin and hunched; arms that hang with
the wrists at the knees and fingers well below them; a pinched belly under a
cage of ribs that stand out through dry skin; knobs of knees and elbows on
sticks of limbs; a ridge of spine and shoulder blades behind. All it wears is a
rag tied round its hips.

The face is not a face but a mask of one, after the ReDeads of Zelda: smooth,
with no nose and no brow to speak of, two round holes for eyes and a round
mouth hanging open, all three going back into dark. Nothing is drawn on it.

As the mummy is, it is modelled with its arms held out from its sides
(ARM_REST), in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
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
os.makedirs(os.path.join(COMPONENT, "tools"), exist_ok=True)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

# --- Joints ---

ANKLE_Y = 0.05
THIGH = 0.30
SHIN = 0.36
HIP_X = 0.06
HIP_Y = ANKLE_Y + THIGH + SHIN
KNEE_Y = HIP_Y - THIGH
HIPS = Vector((0.0, HIP_Y + 0.02, 0.0))
SPINE = Vector((0.0, 0.83, 0.0))
CHEST = Vector((0.0, 1.03, 0.0))
NECK = Vector((0.0, 1.19, 0.02))
HEAD = Vector((0.0, 1.27, 0.04))
SHOULDER = Vector((0.132, 1.16, 0.008))
UPPER_ARM = 0.36
FOREARM = 0.38
ARM_REST = 0.6
TOE = Vector((0.0, -0.035, 0.09))
HEAD_RADII = Vector((0.077, 0.088, 0.085))
HEAD_CENTRE = HEAD + Vector((0.0, 0.062, 0.018))

SKIN, DARK, HOLLOW, RAG = range(4)
MATERIALS = [
    ("skin", (0.35, 0.33, 0.3)),
    ("dark_skin", (0.2, 0.18, 0.16)),
    ("hollow", (0.015, 0.012, 0.012)),
    ("rag", (0.31, 0.28, 0.23)),
]

# Fingers, index to little: (offset across the palm, length, thickness, how far it fans out).
FINGERS = [(0.0205, 0.10, 0.0062, 0.26), (0.0068, 0.115, 0.0064, 0.08), (-0.0068, 0.105, 0.0062, -0.08), (-0.0205, 0.084, 0.0056, -0.26)]
KNUCKLES = (0.0, 0.42, 0.74)
PALM = 0.072
THUMB_LENGTH = 0.066


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
    return hand_wrist(side) + Vector((inward * 0.004, -0.02, 0.02)), Vector((inward * 0.22, -0.72, 0.66)).normalized()


def smooth_rings(x, z, profile, band=0.018):
    """Rings for an upright tube with nothing wound on it (kit.lapped with no laps)."""
    return kit.lapped(x, z, profile, band, 0.0)


def profile_at(profile, y):
    """(half width, half depth, forward) of a profile at height `y`."""
    for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(profile, profile[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return rx0 + (rx1 - rx0) * t, rz0 + (rz1 - rz0) * t, z0 + (z1 - z0) * t
    return profile[-1][1], profile[-1][2], profile[-1][3]


# --- Shapes ---

# (height, half width, half depth, how far forward): a flare of pelvis, the
# belly fallen in to nothing, and a cage of ribs.
TORSO = [(0.66, 0.040, 0.040, 0.0), (0.70, 0.084, 0.060, 0.0), (0.76, 0.088, 0.058, -0.004), (0.82, 0.060, 0.040, -0.012),
         (0.88, 0.058, 0.042, -0.010), (0.94, 0.080, 0.060, 0.0), (1.01, 0.098, 0.072, 0.008), (1.08, 0.112, 0.068, 0.010),
         (1.13, 0.118, 0.060, 0.010), (1.165, 0.088, 0.048, 0.012), (1.195, 0.042, 0.038, 0.016)]
NECK_PROFILE = [(1.16, 0.044, 0.04, 0.010), (1.2, 0.035, 0.034, 0.020), (1.245, 0.031, 0.032, 0.032), (1.29, 0.03, 0.031, 0.044), (1.31, 0.03, 0.03, 0.05)]
TORSO_FUSE = (0.0035, 3, 7000)


def torso(_builder):
    """The trunk and neck, and the bones that show through them: one surface."""
    b = kit.Builder()
    b.tube(smooth_rings(0.0, 0.0, TORSO), 22)
    b.tube(smooth_rings(0.0, 0.0, NECK_PROFILE, 0.015), 12)
    # Ribs: each from beside the spine round the side to the breastbone,
    # dropping as it comes round; the low ones stop short (floating).
    for k in range(7):
        y = 1.10 - 0.036 * k
        reach = 0.82 if k < 5 else 0.45
        for side in (1.0, -1.0):
            points, radii = [], []
            for m in range(13):
                t = m / 12.0
                angle = math.pi * (0.9 - reach * t)
                level = y - 0.035 * t * t
                rx, rz, fwd = profile_at(TORSO, level)
                points.append(Vector((side * math.sin(angle) * rx * 1.0, level, math.cos(angle) * rz + fwd)))
                radii.append(0.0058 * (1.0 - 0.35 * t))
            b.strand(points, radii, 6)
    # The breastbone
    b.strand([Vector((0.0, y, profile_at(TORSO, y)[1] + profile_at(TORSO, y)[2] - 0.002)) for y in (0.94, 0.99, 1.05, 1.11, 1.15)], [0.006, 0.008, 0.008, 0.009, 0.008], 6)
    # Collarbones, from the top of the breastbone out to the shoulders
    for side in (1.0, -1.0):
        b.strand([Vector((side * 0.015, 1.162, 0.05)), Vector((side * 0.06, 1.172, 0.045)), Vector((side * 0.1, 1.172, 0.022))], [0.007, 0.0065, 0.008], 6)
        # Shoulder blades, standing out of the back
        b.ellipsoid(Vector((side * 0.06, 1.09, -0.056)), Vector((0.04, 0.05, 0.012)), Matrix.Rotation(side * 0.25, 3, "Z") @ Matrix.Rotation(0.2, 3, "X"), 12, 5)
        # The points of the pelvis, at the front of the hips
        b.ellipsoid(Vector((side * 0.074, 0.76, 0.036)), Vector((0.018, 0.022, 0.016)), None, 10, 5)
        # The knobs of the shoulders
        b.ellipsoid(Vector((side * 0.108, 1.162, 0.008)), Vector((0.036, 0.03, 0.036)), None, 12, 6)
    # A hump, and the knuckles of the spine down the back
    b.ellipsoid(Vector((0.0, 1.12, -0.038)), Vector((0.06, 0.055, 0.035)), None, 14, 7)
    for k in range(12):
        y = 0.80 + 0.03 * k
        rx, rz, fwd = profile_at(TORSO, y)
        b.ellipsoid(Vector((0.0, y, fwd - rz + 0.003)), Vector((0.011, 0.011, 0.009)), None, 8, 4)
    return kit.fused(b, None if kit.LOW else TORSO_FUSE)


# A leg by how far along it is (0 the ankle, 1 the knee, 2 the hip): (where, half thickness, half width, forward).
# Wasted, but not sticks: what muscle is left still swells the calf and the
# thigh, and every joint is a knob.
LEG = [(-0.015, 0.024, 0.026, 0.0), (0.06, 0.021, 0.024, 0.0), (0.3, 0.026, 0.03, -0.006), (0.55, 0.034, 0.04, -0.012),
       (0.8, 0.03, 0.034, -0.006), (0.92, 0.032, 0.033, 0.0), (1.0, 0.04, 0.04, 0.008), (1.1, 0.035, 0.036, 0.006),
       (1.4, 0.044, 0.048, 0.006), (1.75, 0.05, 0.056, 0.004), (2.0, 0.052, 0.058, 0.0), (2.13, 0.046, 0.052, 0.0)]
# An arm (0 the shoulder, 1 the elbow, 2 the wrist).
ARM = [(2.05, 0.017, 0.021, 0.0), (1.98, 0.02, 0.025, 0.0), (1.9, 0.018, 0.022, 0.0), (1.6, 0.024, 0.03, 0.0),
       (1.3, 0.028, 0.034, 0.0), (1.1, 0.026, 0.03, 0.0), (1.0, 0.032, 0.033, -0.004), (0.85, 0.027, 0.029, 0.0),
       (0.5, 0.032, 0.034, 0.0), (0.2, 0.04, 0.042, 0.0), (0.0, 0.046, 0.046, 0.0), (-0.08, 0.034, 0.036, 0.0)]


def leg_height(t):
    return ANKLE_Y + t * SHIN if t <= 1.0 else KNEE_Y + (t - 1.0) * THIGH


def legs(b):
    for side in (1.0, -1.0):
        b.tube(smooth_rings(side * HIP_X, 0.0, [(leg_height(t), rx, rz, z) for t, rx, rz, z in LEG], 0.02), 14)
        # The kneecap
        b.ellipsoid(Vector((side * HIP_X, KNEE_Y + 0.005, 0.026)), Vector((0.025, 0.029, 0.017)), None, 10, 5)


def arms(b):
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        rings = [(SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM), rx, rz, z) for t, rx, rz, z in ARM]
        b.tube(smooth_rings(side * SHOULDER.x, SHOULDER.z, rings, 0.018), 12)
        # The point of the elbow
        b.ellipsoid(Vector((side * SHOULDER.x, SHOULDER.y - UPPER_ARM, SHOULDER.z - 0.024)), Vector((0.026, 0.03, 0.02)), None, 10, 5)
    b.place = None


def feet(b):
    for side in (1.0, -1.0):
        ankle = Vector((side * HIP_X, ANKLE_Y, 0.0))
        # Long and bony: a heel, a high thin instep, long toes
        upper = [(ankle + Vector((0.0, y, z)), X * rx, Y * ry) for z, y, rx, ry in
                 ((-0.044, -0.022, 0.019, 0.024), (-0.02, -0.010, 0.023, 0.036), (0.012, -0.014, 0.025, 0.032), (0.05, -0.026, 0.028, 0.022),
                  (0.095, -0.034, 0.032, 0.015), (0.135, -0.039, 0.03, 0.011), (0.165, -0.041, 0.022, 0.009))]
        b.tube(kit.dome(upper[0], -Z, 0.012, 3)[::-1] + upper + kit.dome(upper[-1], Z, 0.012, 3), 14, 0.0)


def hands(b):
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        wrist = hand_wrist(side)
        palm = [(0.02, 0.013, 0.016), (0.0, 0.012, 0.018), (-0.03, 0.0098, 0.024), (-0.058, 0.0086, 0.0285), (-PALM - 0.002, 0.0078, 0.027)]
        rings = [(wrist + Y * dy, X * rx, Z * rz) for dy, rx, rz in palm]
        b.tube(rings + kit.dome(rings[-1], -Y, 0.006, 2), 12)
        if kit.LOW:
            inward = -side
            mitt = [(-PALM, 0.0, 0.007, 0.027), (-PALM - 0.055, 0.004, 0.006, 0.026), (-PALM - 0.105, 0.012, 0.004, 0.016)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
    b.place = None


def fingers(b):
    """Long, and swollen at every joint."""
    if kit.LOW:
        return
    spans = (-0.1, 0.0, 0.06, 0.2, 0.36, 0.42, 0.48, 0.6, 0.69, 0.74, 0.79, 0.9, 1.0)
    knobs = (0.9, 1.25, 1.05, 0.72, 0.9, 1.12, 0.9, 0.66, 0.84, 1.0, 0.8, 0.6, 0.42)
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        for index, (_z, length, radius, _fan) in enumerate(FINGERS):
            knuckle, along = finger_line(side, index)
            b.strand([knuckle + along * length * t for t in spans], [radius * knob for knob in knobs], 6)
        root, along = thumb_line(side)
        b.strand([root + along * THUMB_LENGTH * t for t in (-0.2, 0.0, 0.25, 0.5, 0.62, 0.8, 1.0)], [0.0085, 0.0095, 0.007, 0.0085, 0.0068, 0.006, 0.0042], 6)
    b.place = None


# The mask's holes: (x, y) on the face from the head's middle, their radii
# (across, up), and how deep the bowl each sits in is.
EYE = (0.031, 0.008, 0.0165, 0.0155, 0.009)
MOUTH = (0.0, -0.047, 0.018, 0.025, 0.016)


def hole_reach(x, y):
    """How far a point of the face (x, y from the head's middle, before shaping)
    is from the middle of the nearest hole, as a share of that hole's size: 0 at
    its middle, 1 at its edge; and that hole."""
    nearest, which = 9.0, None
    for hole in (EYE, MOUTH):
        hx, hy, rx, ry, _depth = hole
        u = (abs(x) - hx) / rx if hx else x / rx
        r = math.sqrt(u * u + ((y - hy) / ry) ** 2)
        if r < nearest:
            nearest, which = r, hole
    return nearest, which


def face_xy(angle, phi):
    """Where a point of the head is on the face, before it is shaped (x, y from the head's middle)."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    return math.sin(angle) * HEAD_RADII.x * c * (1.0 - 0.12 * jaw ** 1.4), HEAD_RADII.y * s


def skull_point(angle, phi):
    """A point of the head: `angle` round from the front (towards its left), `phi` up from its middle."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    front = math.cos(angle)
    x, y = face_xy(angle, phi)
    z = front * HEAD_RADII.z * c * (1.0 + (0.12 * max(s, -0.2) + 0.08 if front < 0.0 else 0.0)) + 0.006 * jaw
    p = Vector((x, y, z))
    out = Vector((x / HEAD_RADII.x ** 2, y / HEAD_RADII.y ** 2, z / HEAD_RADII.z ** 2)).normalized()
    facing = blend(0.15, 0.6, front * c)
    ax = abs(x)

    def bump(u, v, cu, cv, su, sv):
        return math.exp(-((u - cu) / su) ** 2 - ((v - cv) / sv) ** 2)

    d = 0.0
    # The face is a mask: flattened...
    d -= 0.007 * blend(0.55, 1.0, front * c)
    # ...a heavy brow over the eyes, cheekbones under them, a ledge of chin...
    # (kept slight: any heavier and its shadow draws the frown of a face on it)
    d += 0.0025 * math.exp(-((y - 0.03) / 0.009) ** 2) * blend(0.062, 0.035, ax)
    d += 0.0025 * bump(ax, y, 0.045, -0.018, 0.018, 0.014)
    d -= 0.002 * bump(ax, y, 0.036, -0.05, 0.016, 0.02)
    d += 0.004 * bump(x, y, 0.0, -0.08, 0.02, 0.01)
    # ...and each hole a bowl, with a lip standing up round it, as round the
    # holes cut in a mask. (The dark in each is `hollows`.)
    reach, hole = hole_reach(x, y)
    d += 0.0012 * math.exp(-((reach - 1.15) / 0.2) ** 2)
    # (demade, the head is too coarse for bowls: the dark lies on the face instead)
    if not kit.LOW:
        d -= hole[4] * (1.0 - blend(0.55, 1.25, reach))
    d *= facing
    # The temples, fallen in
    d -= 0.005 * bump(z, y, 0.03, 0.026, 0.022, 0.018) * blend(0.5, 0.9, abs(math.sin(angle)) * c)
    return HEAD_CENTRE + p + out * d


def head(b):
    """The skull, its mask of a face shaped into it."""
    segments, rows = (16, 12) if kit.LOW else (88, 56)
    grid = []
    for k in range(1, rows):
        phi = -math.pi / 2 + math.pi * k / rows
        row = []
        for j in range(segments):
            t = math.tau * j / segments - math.pi
            # (points crowd towards the front, where the face is)
            row.append(b._vert(skull_point(t - (0.0 if kit.LOW else 0.45) * math.sin(t), phi), None))
        grid.append(row)
    faces = []
    for lower, upper in zip(grid, grid[1:]):
        for j in range(segments):
            n = (j + 1) % segments
            faces.append(b.bm.faces.new((lower[j], lower[n], upper[n], upper[j])))
    for row, phi in ((grid[0], -math.pi / 2), (grid[-1], math.pi / 2)):
        pole = b._vert(skull_point(0.0, phi), None)
        for j in range(segments):
            faces.append(b.bm.faces.new((row[j], row[(j + 1) % segments], pole)))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def face_place(x, y):
    """The (angle, phi) of the head that is at (x, y) on the face."""
    phi = math.asin(max(-1.0, min(1.0, y / HEAD_RADII.y)))
    c = math.cos(phi)
    jaw = max(0.0, -math.sin(phi))
    return math.asin(max(-1.0, min(1.0, x / (HEAD_RADII.x * c * (1.0 - 0.12 * jaw ** 1.4))))), phi


def hollows(b):
    """The dark in each hole: a thin disc lying in the bottom of its bowl, its
    edge under the skin, so that the edge of the dark is where the bowl meets it."""
    for hole, sides in ((EYE, (1.0, -1.0)), (MOUTH, (1.0,))):
        hx, hy, rx, ry, depth = hole
        for side in sides:
            angle, phi = face_place(side * hx, hy)
            bottom = skull_point(angle, phi)
            step = 0.01
            along = skull_point(angle + step, phi) - skull_point(angle - step, phi)
            up = skull_point(angle, phi + step) - skull_point(angle, phi - step)
            normal = along.cross(up).normalized()
            if normal.dot(bottom - HEAD_CENTRE) < 0.0:
                normal = -normal
            across = up.cross(normal).normalized()
            upward = normal.cross(across).normalized()
            tilt = Matrix((across, upward, normal)).transposed()
            lift = 0.0016 if kit.LOW else 0.0022
            b.ellipsoid(bottom + normal * lift, Vector((rx, ry, 0.0022)) * (0.9 if kit.LOW else 1.0), tilt, 20, 4)


def loincloth(b):
    """A rag tied round the hips, and its ends hanging in front and behind."""
    b.tube([kit.upright(0.0, y, z, rx + 0.006, rz + 0.006) for y, rx, rz, z in ((0.70, 0.086, 0.062, 0.0), (0.735, 0.09, 0.062, -0.002), (0.77, 0.084, 0.058, -0.004))], 22)
    for front, top, bottom, width, lean in ((1.0, 0.72, 0.5, 0.06, 0.012), (-1.0, 0.72, 0.53, 0.066, 0.0)):
        rings = []
        steps = 8
        for k in range(steps + 1):
            t = k / steps
            y = top + (bottom - top) * t
            z = front * (0.066 + lean * t)
            # (it frays as it goes: narrower, and its edge not straight)
            wide = width * (1.0 - 0.3 * t) * (0.85 + 0.15 * math.sin(t * 17.0 + front))
            rings.append((Vector((0.006 * math.sin(t * 9.0), y, z)), X * wide, Z * 0.0065))
        b.tube(rings, 6)


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    if part in ("head", "hollows"):
        return {"head": 1.0}
    if part == "feet":
        shin = blend(0.062, 0.1, p.y) * blend(0.03, 0.0, p.z)
        toe = blend(TOE.z - 0.022, TOE.z + 0.022, p.z)
        return {"shin" + suffix: shin, "foot" + suffix: (1.0 - shin) * (1.0 - toe), "toe" + suffix: (1.0 - shin) * toe}
    if part == "legs":
        leg = blend(HIP_Y + 0.045, HIP_Y - 0.05, p.y)
        shin = blend(KNEE_Y + 0.04, KNEE_Y - 0.04, p.y)
        foot = blend(0.085, 0.05, p.y)
        return {"hips": 1.0 - leg, "thigh" + suffix: leg * (1.0 - shin), "shin" + suffix: leg * shin * (1.0 - foot), "foot" + suffix: leg * shin * foot}
    if part == "loin":
        # The band goes with the hips; the hanging ends are carried half by the thighs.
        hang = blend(0.69, 0.56, p.y) * 0.5
        return {"hips": 1.0 - hang, "thigh_l": hang * 0.5, "thigh_r": hang * 0.5}
    if part in ("arms", "hands"):
        down = SHOULDER.y - arm_in(side, p).y
        fore = blend(UPPER_ARM - 0.04, UPPER_ARM + 0.04, down)
        hand = blend(UPPER_ARM + FOREARM - 0.022, UPPER_ARM + FOREARM + 0.012, down)
        return {"upper_arm" + suffix: 1.0 - fore, "forearm" + suffix: fore * (1.0 - hand), "hand" + suffix: fore * hand}
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
        soft = 0.005 / length
        shares = [blend(joint - soft, joint + soft, t) for joint in joints]
        result = {"hand" + suffix: 1.0 - shares[0]}
        for k, letter in enumerate("abc"[:len(joints)]):
            result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(shares) else 0.0)
        return result
    # The trunk: by height alone.
    low = blend(SPINE.y + 0.05, SPINE.y - 0.05, p.y)
    high = blend(CHEST.y - 0.07, CHEST.y + 0.05, p.y)
    middle = abs(p.x) < 0.07
    neck = blend(NECK.y - 0.015, NECK.y + 0.03, p.y) if middle else 0.0
    skull = blend(HEAD.y - 0.03, HEAD.y + 0.02, p.y) if middle else 0.0
    return {
        "hips": low,
        "spine": (1.0 - low) * (1.0 - high),
        "chest": (1.0 - low) * high * (1.0 - neck),
        "neck": neck * (1.0 - skull),
        "head": neck * skull,
    }


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


PARTS = [
    ("torso", SKIN, torso, None),
    ("legs", SKIN, legs, (0.0035, 3, 3600)),
    ("feet", SKIN, feet, (0.003, 3, 1400)),
    ("arms", SKIN, arms, (0.003, 3, 4200)),
    ("hands", SKIN, hands, None),
    ("fingers", DARK, fingers, None),
    ("head", SKIN, head, None),
    ("hollows", HOLLOW, hollows, None),
    ("loin", RAG, loincloth, None),
]


def previews(folder, name):
    """Renders all round it, and the face close to."""
    scene = bpy.context.scene
    camera = scene.camera
    middle = kit.to_blender(HEAD_CENTRE)
    views = [("front", (0, -1, 0.05), (0.0, 0.0, 0.72), 1.6), ("back", (0.25, 1, 0.15), (0.0, 0.0, 0.72), 1.6),
             ("chest_front", (0.2, -1, 0.1), (0.0, 0.0, 1.0), 0.5),
             ("face", (0, -1, 0.0), middle, 0.28), ("face_quarter", (0.7, -0.7, 0.1), middle, 0.28),
             ("face_side", (1, -0.05, 0.0), middle, 0.28), ("face_low", (0.3, -1, -0.5), middle, 0.28)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    kit.export("ghoul", bones(), PARTS, weights, MATERIALS)
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "ghoul")
    kit.LOW = True
    kit.export("ghoul_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS)
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "ghoul_lo")
