"""Builds the ghoul and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/ghoul/tools/build_ghoul.py [-- <folder for preview renders>]

Writes creatures/ghoul/models/ghoul.glb and ghoul_lo.glb (and editable .blend
copies beside this file, which are not kept: this folder has a .gdignore so
that Godot does not try to import them).

It is a mummy with nothing left on: the same bones and names as the mummy and
the boy (so CharacterRig, and GhoulRig on it, can move it), and a body of the
same wrong proportions, made bare. Long, thin and hunched; arms that hang with
the wrists at the knees and long bony fingers below them; shoulders that slope
off a stringy neck to points of bone, collarbones across the top of a cage of
ribs, a belly fallen in under it; wasted limbs with the shin bones, the
tendons and the knobs of knees and elbows standing out; a ridge of spine and
shoulder blades behind. Its skin is raw, dried, red-brown flesh, darker in
every hollow of it (see `shaded`).

The head is a skull under skin made into a mask, after the ReDeads of Zelda:
a tall oval of a cranium, a heavy flat brow over two deep dark holes, cheek
bones over hollow cheeks, a long narrow jaw hanging slack and a long mouth
open in it, low in the face, and only two holes for a nose. Nothing is drawn
on it: the dark in its holes is shapes of its own (`hollows`).

As the mummy is, it is modelled with its arms held out from its sides
(ARM_REST), in Godot space (metres, Y up, facing +Z, +X its left). The arms are
one surface with the trunk (so the shoulders are flesh and not joins); their
weights are worked out by `arm_share`.
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
SHOULDER = Vector((0.126, 1.145, 0.006))
UPPER_ARM = 0.36
FOREARM = 0.38
ARM_REST = 0.6
TOE = Vector((0.0, -0.035, 0.09))
# The cranium, half its width, height (above the middle) and depth; the jaw hangs below.
HEAD_RADII = Vector((0.068, 0.074, 0.08))
HEAD_CENTRE = HEAD + Vector((0.0, 0.085, 0.016))
JAW = 1.62

SKIN, SHADE, HOLLOW = range(3)
MATERIALS = [
    # Raw, dried flesh, and the same darker where it sinks in
    ("skin", (0.33, 0.135, 0.105)),
    ("skin_shade", (0.17, 0.05, 0.042)),
    ("hollow", (0.04, 0.008, 0.008)),
]

# Fingers, index to little: (offset across the palm, length, thickness, how far it fans out).
FINGERS = [(0.0205, 0.118, 0.0058, 0.24), (0.0068, 0.134, 0.006, 0.08), (-0.0068, 0.124, 0.0058, -0.08), (-0.0205, 0.1, 0.0052, -0.24)]
KNUCKLES = (0.0, 0.42, 0.74)
PALM = 0.078
THUMB_LENGTH = 0.072


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


def profile_of(profile, t):
    """(half thickness, half width, forward) of a limb's profile (LEG, ARM) `t` along it."""
    ordered = sorted(profile)
    for (t0, rx0, rz0, z0), (t1, rx1, rz1, z1) in zip(ordered, ordered[1:]):
        if t0 <= t <= t1:
            u = (t - t0) / (t1 - t0)
            return rx0 + (rx1 - rx0) * u, rz0 + (rz1 - rz0) * u, z0 + (z1 - z0) * u
    return ordered[-1][1], ordered[-1][2], ordered[-1][3]


# --- The dark in its hollows ---

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


def shaded(shapes, fuse, threshold=0.05, extra=None):
    """A part made by `shapes`, fused as `fuse` says, its faces skin where they
    stand out and shade where they sink in (and where `extra`, given the middle
    of a face, says)."""
    def made(b):
        ready = shapes(b)
        mesh = ready if ready is not None else kit.fused(b, None if kit.LOW else fuse)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        deep = concavity(bm)
        bm.faces.ensure_lookup_table()
        chosen = []
        for face in bm.faces:
            sunk = sum(deep[vert.index] for vert in face.verts) / len(face.verts)
            dark = sunk > threshold and not kit.LOW
            if extra and extra(kit.from_blender(face.calc_center_median())):
                dark = True
            chosen.append(SHADE if dark else SKIN)
        bm.free()
        for _index in range(SHADE + 1):
            mesh.materials.append(None)
        for polygon, material in zip(mesh.polygons, chosen):
            polygon.material_index = material
        return mesh
    return made


# --- Shapes ---

# (height, half width, half depth, how far forward): a flare of pelvis, the
# belly fallen in to nothing, a cage of ribs, and shoulders that slope.
TORSO = [(0.66, 0.040, 0.040, 0.0), (0.70, 0.082, 0.058, 0.0), (0.76, 0.086, 0.056, -0.004), (0.82, 0.058, 0.038, -0.014),
         (0.88, 0.057, 0.04, -0.012), (0.94, 0.079, 0.058, 0.0), (1.01, 0.097, 0.07, 0.008), (1.07, 0.108, 0.067, 0.010),
         (1.11, 0.106, 0.06, 0.010), (1.145, 0.082, 0.05, 0.012), (1.175, 0.056, 0.043, 0.014), (1.2, 0.04, 0.038, 0.016)]
NECK_PROFILE = [(1.16, 0.042, 0.038, 0.010), (1.2, 0.032, 0.032, 0.020), (1.245, 0.028, 0.03, 0.032), (1.29, 0.027, 0.029, 0.044), (1.31, 0.027, 0.028, 0.05)]
TRUNK_FUSE = (0.0034, 3, 12000)

# An arm (0 the shoulder, 1 the elbow, 2 the wrist): (where, half thickness, half width, forward).
# Stringy: a wasted upper arm under a point of shoulder, a knob of elbow, a
# forearm of tendon narrowing to a bony wrist.
ARM = [(2.05, 0.015, 0.02, 0.0), (1.98, 0.018, 0.024, 0.0), (1.9, 0.016, 0.021, 0.0), (1.6, 0.02, 0.026, 0.0),
       (1.3, 0.025, 0.031, 0.0), (1.12, 0.023, 0.027, 0.0), (1.0, 0.027, 0.029, -0.004), (0.88, 0.022, 0.024, 0.0),
       (0.55, 0.025, 0.027, 0.0), (0.25, 0.03, 0.032, 0.0), (0.08, 0.033, 0.035, 0.0), (0.0, 0.03, 0.032, 0.0), (-0.04, 0.022, 0.024, 0.0)]


def arm_point(side, t, out=0.0, forward=0.0):
    """A point on an arm hanging straight down, `t` along it (as ARM), `out` from its middle and `forward`."""
    y = SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM)
    return Vector((side * (SHOULDER.x + out), y, SHOULDER.z + forward))


def trunk(_builder):
    """The trunk, the neck and the arms, and the bones that show through them: one surface."""
    b = kit.Builder()
    b.tube(smooth_rings(0.0, 0.0, TORSO), 24)
    b.tube(smooth_rings(0.0, 0.0, NECK_PROFILE, 0.015), 12)
    # The cords of the neck, from behind the ear down to the top of the breastbone
    for side in (1.0, -1.0):
        b.strand([Vector((side * 0.026, 1.29, 0.03)), Vector((side * 0.022, 1.235, 0.042)), Vector((side * 0.012, 1.18, 0.05))], [0.007, 0.0075, 0.007], 6)
    # Ribs: each from beside the spine round the side to the breastbone,
    # dropping as it comes round; the low ones stop short (floating).
    for k in range(7):
        y = 1.09 - 0.035 * k
        reach = 0.82 if k < 5 else 0.45
        for side in (1.0, -1.0):
            points, radii = [], []
            for m in range(13):
                t = m / 12.0
                angle = math.pi * (0.9 - reach * t)
                level = y - 0.035 * t * t
                rx, rz, fwd = profile_at(TORSO, level)
                points.append(Vector((side * math.sin(angle) * rx, level, math.cos(angle) * rz + fwd)))
                radii.append(0.006 * (1.0 - 0.35 * t))
            b.strand(points, radii, 6)
    # The breastbone
    b.strand([Vector((0.0, y, profile_at(TORSO, y)[1] + profile_at(TORSO, y)[2] - 0.002)) for y in (0.94, 0.99, 1.05, 1.1, 1.14)], [0.006, 0.008, 0.008, 0.009, 0.008], 6)
    for side in (1.0, -1.0):
        # Collarbones, from the top of the breastbone out to the points of the shoulders
        b.strand([Vector((side * 0.014, 1.152, 0.052)), Vector((side * 0.06, 1.156, 0.05)), Vector((side * 0.1, 1.158, 0.03)), Vector((side * 0.124, 1.16, 0.012))], [0.007, 0.0065, 0.0065, 0.008], 6)
        # The slope of the shoulder, from the neck down to its point
        b.ellipsoid(Vector((side * 0.07, 1.158, -0.008)), Vector((0.058, 0.02, 0.034)), Matrix.Rotation(-side * 0.32, 3, "Z"), 14, 6)
        # The point of the shoulder, bone standing out
        b.ellipsoid(Vector((side * 0.124, 1.158, 0.006)), Vector((0.022, 0.016, 0.026)), None, 10, 5)
        # Shoulder blades, standing out of the back
        b.ellipsoid(Vector((side * 0.058, 1.08, -0.054)), Vector((0.038, 0.05, 0.012)), Matrix.Rotation(side * 0.25, 3, "Z") @ Matrix.Rotation(0.2, 3, "X"), 12, 5)
        # The points of the pelvis, at the front of the hips
        b.ellipsoid(Vector((side * 0.074, 0.76, 0.036)), Vector((0.018, 0.022, 0.016)), None, 10, 5)
    # The knuckles of the spine down the back
    b.ellipsoid(Vector((0.0, 1.11, -0.034)), Vector((0.05, 0.045, 0.03)), None, 14, 7)
    for k in range(12):
        y = 0.80 + 0.03 * k
        rx, rz, fwd = profile_at(TORSO, y)
        b.ellipsoid(Vector((0.0, y, fwd - rz + 0.003)), Vector((0.011, 0.011, 0.009)), None, 8, 4)
    # The arms, out at their rest
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        rings = [(SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM), rx, rz, z) for t, rx, rz, z in ARM]
        b.tube(smooth_rings(side * SHOULDER.x, SHOULDER.z, rings, 0.016), 12)
        # The shoulder's last muscle, over the top of the arm
        b.ellipsoid(arm_point(side, 0.12, 0.004, 0.0), Vector((0.034, 0.05, 0.036)), None, 12, 6)
        # The point of the elbow, and the knobs either side of it
        b.ellipsoid(arm_point(side, 1.0, 0.0, -0.022), Vector((0.02, 0.026, 0.017)), None, 10, 5)
        b.ellipsoid(arm_point(side, 0.97, 0.022, -0.004), Vector((0.012, 0.014, 0.012)), None, 8, 4)
        b.ellipsoid(arm_point(side, 0.97, -0.02, -0.004), Vector((0.011, 0.013, 0.011)), None, 8, 4)
        # Tendons down the forearm, standing out of it front and back, and the knob of the wrist
        for across, way in ((0.4, 1.0), (-0.4, 1.0), (0.1, -1.0)):
            points = []
            for t in (1.2, 1.45, 1.7, 1.93):
                rx, rz, fwd = profile_of(ARM, t)
                points.append(arm_point(side, t, across * rx, fwd + way * (rz - 0.0015)))
            b.strand(points, [0.0055, 0.006, 0.0058, 0.005], 6)
        b.ellipsoid(arm_point(side, 1.96, 0.018, -0.008), Vector((0.009, 0.01, 0.009)), None, 8, 4)
        # The cords of the upper arm, front and back
        for way in (1.0, -1.0):
            b.strand([arm_point(side, t, 0.0, way * (profile_of(ARM, t)[1] - 0.002)) for t in (0.25, 0.5, 0.78)], [0.0065, 0.0075, 0.0055], 6)
    b.place = None
    return kit.fused(b, None if kit.LOW else TRUNK_FUSE)


def trunk_hollows(p):
    """Places on the trunk that are dark whatever their shape: the hollows above the collarbones, the armpits."""
    ax = abs(p.x)
    above_collar = 1.16 < p.y < 1.19 and 0.03 < ax < 0.095 and p.z > 0.02
    armpit = 1.03 < p.y < 1.12 and 0.085 < ax < 0.125 and abs(p.z) < 0.03
    return above_collar or armpit


# A leg by how far along it is (0 the ankle, 1 the knee, 2 the hip): (where, half thickness, half width, forward).
# Wasted, but not sticks: what muscle is left still swells the calf, and every joint is a knob.
LEG = [(-0.015, 0.022, 0.025, 0.0), (0.06, 0.019, 0.022, 0.0), (0.3, 0.024, 0.028, -0.008), (0.55, 0.031, 0.037, -0.014),
       (0.8, 0.026, 0.03, -0.006), (0.92, 0.028, 0.03, 0.0), (1.0, 0.036, 0.036, 0.006), (1.1, 0.03, 0.031, 0.004),
       (1.4, 0.036, 0.04, 0.006), (1.75, 0.042, 0.048, 0.004), (2.0, 0.046, 0.052, 0.0), (2.13, 0.042, 0.048, 0.0)]


def leg_height(t):
    return ANKLE_Y + t * SHIN if t <= 1.0 else KNEE_Y + (t - 1.0) * THIGH


def legs(b):
    for side in (1.0, -1.0):
        x = side * HIP_X
        b.tube(smooth_rings(x, 0.0, [(leg_height(t), rx, rz, z) for t, rx, rz, z in LEG], 0.018), 14)
        # The kneecap, and the knobs of bone either side of the knee
        b.ellipsoid(Vector((x, KNEE_Y + 0.004, 0.026)), Vector((0.022, 0.026, 0.015)), None, 10, 5)
        for across in (0.026, -0.024):
            b.ellipsoid(Vector((x + across, KNEE_Y - 0.004, 0.006)), Vector((0.013, 0.02, 0.016)), None, 8, 4)
        def skin(t, across, way, x=x):
            """A point on the leg's surface `t` along it, `across` (a share of its width) and in front (way 1) or behind (-1)."""
            rx, rz, fwd = profile_of(LEG, t)
            return Vector((x + across * rx, leg_height(t), fwd + way * rz * math.sqrt(max(1.0 - across * across, 0.0))))

        # The shin bone down the front, sharp under the skin
        b.strand([skin(t, side * 0.15, 1.0) for t in (0.92, 0.7, 0.45, 0.2, 0.06)], [0.0085, 0.008, 0.0075, 0.007, 0.0065], 6)
        # The tendons behind the knee, and the heel's cord
        for across in (0.55, -0.55):
            b.strand([skin(t, across, -1.0) for t in (1.4, 1.15, 0.9)], [0.006, 0.0068, 0.006], 6)
        b.strand([skin(t, 0.0, -1.0) for t in (0.42, 0.25, 0.08)] + [Vector((x, ANKLE_Y - 0.008, -0.03))], [0.0075, 0.007, 0.0068, 0.0075], 6)
        # Sinews down the front and side of the thigh
        for across, way in ((0.25, 1.0), (side * 0.85, 1.0)):
            b.strand([skin(t, across, way) for t in (1.15, 1.45, 1.75, 2.0)], [0.0065, 0.0075, 0.0075, 0.006], 6)
        # The knobs of the ankle
        for across in (0.02, -0.018):
            b.ellipsoid(Vector((x + across, ANKLE_Y + 0.006, 0.0)), Vector((0.009, 0.011, 0.01)), None, 8, 4)


def feet(b):
    for side in (1.0, -1.0):
        ankle = Vector((side * HIP_X, ANKLE_Y, 0.0))
        # Long and bony: a heel, a high thin instep, long toes
        upper = [(ankle + Vector((0.0, y, z)), X * rx, Y * ry) for z, y, rx, ry in
                 ((-0.044, -0.022, 0.019, 0.024), (-0.02, -0.010, 0.022, 0.034), (0.012, -0.014, 0.024, 0.03), (0.05, -0.026, 0.027, 0.02),
                  (0.095, -0.034, 0.031, 0.014), (0.135, -0.039, 0.029, 0.011), (0.168, -0.041, 0.021, 0.009))]
        b.tube(kit.dome(upper[0], -Z, 0.012, 3)[::-1] + upper + kit.dome(upper[-1], Z, 0.012, 3), 14, 0.0)
        # The bones of the top of the foot
        for across in (-0.012, 0.0, 0.012):
            b.strand([ankle + Vector((across * 0.4, -0.012, 0.02)), ankle + Vector((across, -0.024, 0.08)), ankle + Vector((across * 1.2, -0.034, 0.14))], [0.006, 0.0055, 0.005], 6)


def hands(b):
    """The palms, long and thin, the bones of the back of the hand standing out of them."""
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        wrist = hand_wrist(side)
        palm = [(0.02, 0.012, 0.016), (0.0, 0.011, 0.018), (-0.03, 0.0088, 0.023), (-0.06, 0.0078, 0.027), (-PALM - 0.002, 0.0072, 0.026)]
        rings = [(wrist + Y * dy, X * rx, Z * rz) for dy, rx, rz in palm]
        b.tube(rings + kit.dome(rings[-1], -Y, 0.006, 2), 12)
        if kit.LOW:
            inward = -side
            mitt = [(-PALM, 0.0, 0.007, 0.026), (-PALM - 0.06, 0.004, 0.006, 0.025), (-PALM - 0.12, 0.012, 0.004, 0.015)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
        else:
            outward = side
            for index in range(len(FINGERS)):
                knuckle, _along = finger_line(side, index)
                back = Vector((outward * 0.0062, 0.0, 0.0))
                b.strand([wrist + Vector((0.0, -0.012, knuckle.z - wrist.z)) * 0.6 + back, knuckle + back * 1.1], [0.004, 0.0062], 6)
    b.place = None


def fingers(b):
    """Long, and swollen at every joint."""
    if kit.LOW:
        return
    spans = (-0.1, 0.0, 0.06, 0.2, 0.36, 0.42, 0.48, 0.6, 0.69, 0.74, 0.79, 0.9, 1.0)
    knobs = (0.95, 1.3, 1.05, 0.72, 0.9, 1.15, 0.9, 0.66, 0.84, 1.02, 0.8, 0.6, 0.38)
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        for index, (_z, length, radius, _fan) in enumerate(FINGERS):
            knuckle, along = finger_line(side, index)
            b.strand([knuckle + along * length * t for t in spans], [radius * knob for knob in knobs], 6)
        root, along = thumb_line(side)
        b.strand([root + along * THUMB_LENGTH * t for t in (-0.2, 0.0, 0.25, 0.5, 0.62, 0.8, 1.0)], [0.0085, 0.0095, 0.007, 0.0085, 0.0068, 0.006, 0.004], 6)
    b.place = None


# --- The head ---

# The mask's holes: (x, y) on the face from the head's middle, their radii
# (across, up), how deep the pit each sits in is, and the dark in it as a share of its size.
EYE = (0.027, -0.004, 0.0158, 0.0165, 0.02, 1.0)
MOUTH = (0.0, -0.083, 0.0145, 0.027, 0.02, 1.0)
NOSE = (0.0068, -0.042, 0.0042, 0.0062, 0.006, 1.0)
HOLES = (EYE, MOUTH, NOSE)


def hole_reach(x, y):
    """How far a point of the face (x, y from the head's middle) is from the
    middle of the nearest hole, as a share of that hole's size (0 its middle, 1
    its edge); and that hole."""
    nearest, which = 9.0, None
    for hole in HOLES:
        hx, hy, rx, ry = hole[:4]
        u = (abs(x) - hx) / rx if hx else x / rx
        r = math.sqrt(u * u + ((y - hy) / ry) ** 2)
        if r < nearest:
            nearest, which = r, hole
    return nearest, which


def face_xy(angle, phi):
    """Where a point of the head is on the face, before it is shaped (x, y from
    the head's middle): an oval above, and below, a jaw longer and narrower."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    return math.sin(angle) * HEAD_RADII.x * c * (1.0 - 0.24 * jaw ** 1.6), HEAD_RADII.y * s * (JAW if s < 0.0 else 1.0)


def skull_point(angle, phi):
    """A point of the head: `angle` round from the front (towards its left), `phi` up from its middle."""
    c, s = math.cos(phi), math.sin(phi)
    jaw = max(0.0, -s)
    front = math.cos(angle)
    x, y = face_xy(angle, phi)
    # (the back of the skull is long, and below it there is only the neck: the jaw is all in front)
    behind = 0.12 * max(s, -0.2) + 0.08 if front < 0.0 else 0.0
    z = front * HEAD_RADII.z * c * (1.0 + behind) * (1.0 - (0.35 * jaw ** 1.5 if front < 0.0 else 0.08 * jaw)) + 0.01 * jaw
    p = Vector((x, y, z))
    out = Vector((x / HEAD_RADII.x ** 2, y / (HEAD_RADII.y * (JAW if s < 0.0 else 1.0)) ** 2, z / HEAD_RADII.z ** 2)).normalized()
    facing = blend(0.15, 0.6, front * c)
    ax = abs(x)

    def bump(u, v, cu, cv, su, sv):
        return math.exp(-((u - cu) / su) ** 2 - ((v - cv) / sv) ** 2)

    d = 0.0
    # A mask: the face flattened...
    d -= 0.008 * blend(0.55, 1.0, front * c)
    # ...a heavy brow, flat along its front and cut off square over the eyes...
    d += 0.009 * blend(0.004, 0.014, y) * blend(0.048, 0.03, y) * blend(0.064, 0.044, ax)
    # ...a narrow ridge of nose falling in to its holes...
    d += 0.004 * math.exp(-(x / 0.006) ** 2) * blend(0.0, -0.012, y) * blend(-0.042, -0.03, y)
    # ...cheekbones, and the cheeks fallen in under them...
    d += 0.007 * bump(ax, y, 0.047, -0.028, 0.017, 0.011)
    d -= 0.011 * bump(ax, y, 0.04, -0.064, 0.015, 0.024)
    # ...the corners of a long jaw, and a chin
    d += 0.004 * bump(ax, y, 0.04, -0.095, 0.012, 0.016)
    d += 0.004 * bump(x, y, 0.0, -0.114, 0.016, 0.009)
    reach, hole = hole_reach(x, y)
    # (demade, the head is too coarse for pits: the dark lies on the face instead)
    if not kit.LOW:
        d -= hole[4] * (1.0 - blend(0.6, 1.15, reach))
    d *= facing
    # The temples, fallen in
    d -= 0.006 * bump(z, y, 0.03, 0.022, 0.022, 0.02) * blend(0.5, 0.9, abs(math.sin(angle)) * c)
    return HEAD_CENTRE + p + out * d


def head(b):
    """The skull, its mask of a face shaped into it."""
    segments, rows = (18, 14) if kit.LOW else (96, 72)
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
    return kit.fused(b, None)


def head_hollows(p):
    """Dark down the walls of the eyes and the mouth, whatever the shape says."""
    x, y, z = p.x - HEAD_CENTRE.x, p.y - HEAD_CENTRE.y, p.z - HEAD_CENTRE.z
    if z < 0.02:
        return False
    reach, hole = hole_reach(x, y)
    return (hole is EYE and reach < 1.2) or (hole is MOUTH and reach < 1.08)


def face_place(x, y):
    """The (angle, phi) of the head that is at (x, y) on the face."""
    if y < 0.0:
        phi = math.asin(max(-1.0, y / (HEAD_RADII.y * JAW)))
    else:
        phi = math.asin(min(1.0, y / HEAD_RADII.y))
    c = math.cos(phi)
    jaw = max(0.0, -math.sin(phi))
    return math.asin(max(-1.0, min(1.0, x / (HEAD_RADII.x * c * (1.0 - 0.24 * jaw ** 1.6))))), phi


def hollows(b):
    """The dark in each hole: a thin disc lying in the bottom of its pit, its
    edge under the skin, so that the edge of the dark is where the pit meets it."""
    for hole in HOLES:
        hx, hy, rx, ry, depth, share = hole
        for side in ((1.0, -1.0) if hx else (1.0,)):
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
            lift = 0.0016 if kit.LOW else 0.0024
            b.ellipsoid(bottom + normal * lift, Vector((rx, ry, 0.0022)) * share * (0.9 if kit.LOW else 1.0), tilt, 20, 4)


# --- Bones and weights ---

def arm_weights(side, p):
    suffix = "_l" if side > 0.0 else "_r"
    down = SHOULDER.y - arm_in(side, p).y
    fore = blend(UPPER_ARM - 0.04, UPPER_ARM + 0.04, down)
    hand = blend(UPPER_ARM + FOREARM - 0.022, UPPER_ARM + FOREARM + 0.012, down)
    return {"upper_arm" + suffix: 1.0 - fore, "forearm" + suffix: fore * (1.0 - hand), "hand" + suffix: fore * hand}


def arm_share(side, p):
    """How much a point of the trunk's surface belongs to the arm on `side`: all
    of it a little way down the arm, none of it in the body, shared over the shoulder."""
    q = arm_in(side, p)
    down = SHOULDER.y - q.y
    off = Vector((q.x - side * SHOULDER.x, 0.0, q.z - SHOULDER.z)).length
    if off > 0.075:
        return 0.0
    return blend(-0.025, 0.05, down) * blend(0.075, 0.05, off)


def trunk_weights(p):
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
    if part == "hands":
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
        soft = 0.005 / length
        shares = [blend(joint - soft, joint + soft, t) for joint in joints]
        result = {"hand" + suffix: 1.0 - shares[0]}
        for k, letter in enumerate("abc"[:len(joints)]):
            result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(shares) else 0.0)
        return result
    # The trunk (and the arms, which are one surface with it)
    share = arm_share(side, p)
    result = {bone: weight * (1.0 - share) for bone, weight in trunk_weights(p).items()}
    if share > 0.0:
        for bone, weight in arm_weights(side, p).items():
            result[bone] = result.get(bone, 0.0) + weight * share
    return result


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


# (part, material, shapes, how to fuse it). Material None: the part paints its own faces (`shaded`).
PARTS = [
    ("torso", None, shaded(trunk, TRUNK_FUSE, -0.014, trunk_hollows), None),
    ("legs", None, shaded(legs, (0.0032, 3, 4200), -0.006), None),
    ("feet", None, shaded(feet, (0.003, 3, 1600), 0.0), None),
    ("hands", SKIN, hands, None),
    ("fingers", SHADE, fingers, None),
    ("head", None, shaded(head, None, -0.004, head_hollows), None),
    ("hollows", HOLLOW, hollows, None),
]


def previews(folder, name):
    """Renders all round it, and the face close to."""
    scene = bpy.context.scene
    camera = scene.camera
    middle = kit.to_blender(HEAD_CENTRE + Vector((0.0, -0.03, 0.0)))
    views = [("front", (0, -1, 0.05), (0.0, 0.0, 0.72), 1.6), ("back", (0.25, 1, 0.15), (0.0, 0.0, 0.72), 1.6),
             ("chest_front", (0.2, -1, 0.1), (0.0, 0.0, 1.0), 0.5), ("shoulder", (0.6, -1, 0.3), (0.1, 0.0, 1.1), 0.35),
             ("leg", (0.6, -1, 0.1), (0.06, 0.0, 0.35), 0.6), ("hand", (-0.6, -0.7, 0.1), kit.to_blender(arm_out(1.0)(hand_wrist(1.0) - Y * 0.1)), 0.3),
             ("face", (0, -1, 0.0), middle, 0.3), ("face_quarter", (0.7, -0.7, 0.1), middle, 0.3),
             ("face_side", (1, -0.05, 0.0), middle, 0.3), ("face_low", (0.3, -1, -0.5), middle, 0.3)]
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
    kit.export("ghoul_lo", bones(), PARTS, weights, MATERIALS)
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "ghoul_lo")
