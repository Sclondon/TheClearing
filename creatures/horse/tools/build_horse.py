"""Builds the horse (creatures/horse) and exports it for Godot.

Run from the game's root (Blender 4.3):
    blender --background --python creatures/horse/tools/build_horse.py
    blender --background --python creatures/horse/tools/build_horse.py -- <preview folder> horse   # one, with pictures

Writes creatures/horse/models/horse.glb and horse_haltered.glb (the same horse in an old rope halter with a frayed
end of lead rope hanging from it), and a demade `_lo` version of each. Nothing else is written (an editable .blend
and pictures go to the preview folder, when there is one).

A feral horse that has been out a long time, built from a horse's anatomy (about 15 hands, 1.5 m at the withers):
- A deep barrel slung between the shoulders and the hindquarters, the withers standing up over the shoulder blades
  (sharp, on a horse this thin), a long back, the croup rounding over to the root of the tail, and the belly lifting
  up into the flank. Thin: the points of the hips stand out, the ribs show along the flank (in the vertex colours).
- Legs on the equine plan. Fore: the point of the shoulder low at the front of the chest, the elbow tucked against
  the girth, the muscled forearm down to the knee (the carpus), a short flat cannon, the round fetlock, a sloping
  pastern and one hoof, rounded, its wall sloping down and out to the ground; a chestnut inside each forearm.
  Hind: the hip joint deep in the quarters, the stifle forward at the flank, the gaskin back down to the hock (its
  point standing out behind), the cannon straight down from it.
- The neck long and deep, rising forward out of the chest under a crest, the head long and heavy: a broad flat
  forehead, the eyes high on its sides, the great round jowls, the long straight face narrowing to the muzzle and
  widening again at the nostrils, soft lips, small pointed ears close together on the poll.
- The mane long and tangled, falling down the right side of the neck in locks and mats, a forelock down the face to
  the eyes, and the tail hanging from the dock nearly to the fetlocks, matted, knotted, burred.

The bones are the deer's (creatures/deer, tools/build_deer.py), with the same names, so a rig of the same kind poses
them (creatures/horse/horse_rig.gd); the tail has a bone more, for the long hair:

    body, chest, pelvis, neck, neck_1, head, jaw, ear(_tip, _end)_l/_r, tail, tail_1, tail_2, tail_end
    fore: `upper`, `lower`, `hock` (the cannon), `paw` (at the fetlock: the pastern and hoof go with it); hind the same
    markers (nothing weighted to them): `toe` under each hoof, `nose`, `brow`, `seat` (where a rider sits, on the back
    behind the withers) and `grip` (the top of the neck at its root, where a rider holds the mane)

Three surfaces: `coat`, `mane` (the mane, forelock and tail: locks whose texture coordinates run root to tip),
`parts` (eyes, nostrils, mouth, hooves, chestnuts, halter and rope, ear linings), the parts' colours in their vertex
colours. The coat's vertex colours: red how open the surface is (dark in creases, and between the ribs), green how
far it is the dark of the coat (the points: lower legs, muzzle, ear rims; the dorsal stripe), blue how far the pale.

Uses build_deer.py's tools (and so the character controller's tools/build_character.py) for its shape-building.
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
sys.path.insert(0, os.path.join(GAME, "creatures", "deer", "tools"))
import build_deer as deer  # noqa: E402  (the deer's builder, and through it the character controller's tools)

kit = deer.kit
X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
V = deer.V
rot_x = deer.rot_x
tube_along = deer.tube_along
SUFFIXES = deer.SUFFIXES

# Built at this size (a horse of about 15 hands); in the deer's measure below.
SCALE = 1.55
# (the deer's own weights, which the horse's build on: main() puts the horse's in their place)
DEER_WEIGHTS = deer.weights


def horse(name, halter):
    c = deer.Cervid(
        name=name, kind="horse", buck=False, scale=SCALE, head_scale=1.0, thick=1.1, muzzle=1.0, halter=halter,
        # (along the body, centre height, half width, half height): deep through the girth, a long back, the belly
        # tucked up into the flank (a thin horse), big rounded quarters
        trunk=[(-0.600, 0.805, 0.045, 0.060), (-0.575, 0.795, 0.098, 0.135), (-0.51, 0.780, 0.148, 0.172),
               (-0.42, 0.770, 0.160, 0.188), (-0.31, 0.772, 0.150, 0.184), (-0.18, 0.760, 0.160, 0.205),
               (-0.04, 0.748, 0.170, 0.222), (0.08, 0.746, 0.168, 0.230), (0.19, 0.752, 0.150, 0.232),
               (0.29, 0.756, 0.122, 0.214), (0.36, 0.748, 0.090, 0.170), (0.42, 0.742, 0.052, 0.095)],
        # Point of the shoulder, elbow, knee, fetlock; hip, stifle, hock, fetlock (the left legs)
        fore=[V(0.100, 0.700, 0.330), V(0.106, 0.520, 0.226), V(0.086, 0.300, 0.246), V(0.081, 0.150, 0.252)],
        hind=[V(0.110, 0.800, -0.360), V(0.124, 0.588, -0.250), V(0.090, 0.372, -0.468), V(0.085, 0.150, -0.440)],
        toe_ahead=0.074,
        # (how far down the leg, counted in joints; half width; half depth; forward offset)
        fore_shape=[(0.45, 0.050, 0.066, -0.008), (0.75, 0.054, 0.072, -0.008), (0.95, 0.055, 0.074, -0.006),
                    (1.05, 0.052, 0.070, -0.004), (1.3, 0.045, 0.058, 0.0), (1.65, 0.033, 0.044, 0.0), (1.9, 0.029, 0.038, 0.0),
                    (2.0, 0.032, 0.039, 0.003), (2.12, 0.025, 0.034, -0.002), (2.5, 0.0215, 0.031, -0.004), (2.85, 0.0235, 0.032, -0.004),
                    (3.0, 0.028, 0.036, -0.004)],
        hind_shape=[(0.5, 0.058, 0.098, -0.015), (0.7, 0.062, 0.106, -0.015), (0.85, 0.062, 0.106, -0.012),
                    (1.0, 0.056, 0.092, -0.006), (1.3, 0.048, 0.078, -0.012), (1.62, 0.035, 0.058, -0.014), (1.86, 0.029, 0.049, -0.014),
                    (2.0, 0.029, 0.050, -0.012), (2.12, 0.024, 0.035, -0.002), (2.5, 0.0215, 0.031, 0.0), (2.85, 0.0235, 0.032, -0.002),
                    (3.0, 0.028, 0.036, -0.003)],
        # The neck: (how far up it, half width, half depth, how far the throat hangs under it)
        neck_shape=[(-0.3, 0.084, 0.190, 0.030), (0.0, 0.077, 0.160, 0.018), (0.3, 0.066, 0.126, 0.004),
                    (0.6, 0.058, 0.106, -0.006), (0.85, 0.050, 0.090, -0.010), (1.05, 0.048, 0.082, -0.010)],
        atlas=V(0.0, 1.100, 0.715), face_tilt=0.98,
        ear_size=(0.024, 0.11), tail_length=1.0, tail_width=0.040,
        mane=True, antlers=None,
        colours=dict(coat=(0.50, 0.44, 0.34), dark=(0.12, 0.10, 0.09), pale=(0.62, 0.56, 0.46), mane=(0.10, 0.09, 0.08)),
    )
    s = c.scale
    c.body = V(0.0, 0.752, -0.05) * s
    c.chest = V(0.0, 0.77, 0.20) * s
    c.pelvis = V(0.0, 0.78, -0.32) * s
    c.neck = V(0.0, 0.85, 0.37) * s
    c.neck_1 = c.neck.lerp(c.head, 0.5)
    c.jaw = c.at(0.10, -0.055)
    # Small pointed ears, close together on the poll, standing up and a little forward
    root = c.at(0.0, 0.050, 0.030)
    c.ear = [root, root + V(0.008, 0.052, 0.010) * s, root + V(0.013, 0.100, 0.020) * s]
    # The dock (the bone of the tail): short, from the croup down; the hair hangs from it nearly to the fetlocks
    tail_root = V(0.0, 0.862, -0.592) * s
    c.tail = [tail_root, tail_root + V(0.0, -0.070, -0.040) * s, tail_root + V(0.0, -0.165, -0.050) * s]
    c.hair = [c.tail[2], tail_root + V(0.0, -0.40, -0.085) * s, tail_root + V(0.0, -0.64, -0.075) * s]
    c.seat = V(0.0, 0.990, 0.06) * s
    return c


ANIMALS = [horse("horse", False), horse("horse_haltered", True)]


def out_folder(_c):
    return os.path.join(COMPONENT, "models")


# --- The body ---

# The head's measurements: (along the face from the poll, up from its line, half width, half depth), deer units
FACE = [(-0.02, 0.004, 0.054, 0.056), (0.03, -0.004, 0.066, 0.070), (0.08, -0.014, 0.070, 0.082),
        (0.13, -0.022, 0.066, 0.080), (0.18, -0.022, 0.054, 0.064), (0.24, -0.019, 0.046, 0.052),
        (0.30, -0.019, 0.043, 0.046), (0.345, -0.022, 0.046, 0.044), (0.38, -0.026, 0.044, 0.038), (0.398, -0.029, 0.034, 0.027)]
EYE = (0.112, 0.024, 0.064)
EYE_SIZE = V(0.025, 0.0195, 0.016)
# (how far along the ear, half its width, half its thickness): a horse's, narrow and pointed
EAR_RINGS = ((0.0, 0.62, 0.30), (0.10, 0.86, 0.26), (0.28, 1.0, 0.20), (0.45, 0.98, 0.16),
             (0.62, 0.84, 0.13), (0.78, 0.60, 0.10), (0.90, 0.34, 0.08), (0.97, 0.12, 0.06), (1.0, 0.03, 0.05))


def face_at(along):
    """(up, half width, half depth) of the face `along` it."""
    for a, b in zip(FACE, FACE[1:]):
        if along <= b[0] or b is FACE[-1]:
            t = min(max((along - a[0]) / (b[0] - a[0]), 0.0), 1.0)
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return FACE[-1][1:]


def mass(c):
    """The body's masses, fused and smoothed hard so that they run into each other as muscle does under a skin:
    the trunk, the withers, the shoulders, the quarters, the points of the hips, the chest and the neck."""
    b = kit.Builder()
    s = c.scale
    th = c.thick
    rings = [(V(0.0, y * s, z * s), X * rx * s * th, Y * ry * s) for z, y, rx, ry in c.trunk]
    b.tube(dome(rings[0], -Z, 0.04 * s)[::-1] + rings + dome(rings[-1], Z, 0.03 * s), 20)
    # The withers: the tops of the shoulder blades standing up over the back (sharp on a thin horse)
    b.ellipsoid(V(0.0, 0.952 * s, 0.17 * s), V(0.036 * s * th, 0.050 * s, 0.150 * s))
    b.ellipsoid(V(0.0, 0.928 * s, 0.05 * s), V(0.040 * s * th, 0.032 * s, 0.12 * s))
    # The breast, between the forelegs, running up into the root of the neck
    b.ellipsoid(V(0.0, 0.660 * s, 0.375 * s), V(0.088 * s * th, 0.105 * s, 0.075 * s))
    b.ellipsoid(V(0.0, 0.800 * s, 0.360 * s), V(0.090 * s * th, 0.140 * s, 0.100 * s), rot_x(-0.45))
    for side in (1.0, -1.0):
        # The shoulder: down the blade from the withers to the point of the shoulder, then back down to the elbow
        deer.side_mass(b, side, [(0.93 * s, 0.200 * s, 0.050 * s * th, 0.046 * s * th, 0.080 * s),
                                 (0.84 * s, 0.245 * s, 0.096 * s * th, 0.062 * s * th, 0.100 * s),
                                 (0.75 * s, 0.290 * s, 0.112 * s * th, 0.066 * s * th, 0.106 * s),
                                 (0.66 * s, 0.290 * s, 0.116 * s * th, 0.062 * s * th, 0.096 * s),
                                 (0.585 * s, 0.250 * s, 0.112 * s * th, 0.048 * s * th, 0.070 * s)])
        # The quarters: the round of the rump over the hip down to the stifle in front and the second thigh behind
        deer.side_mass(b, side, [(0.905 * s, -0.385 * s, 0.056 * s * th, 0.060 * s * th, 0.13 * s),
                                 (0.835 * s, -0.405 * s, 0.108 * s * th, 0.082 * s * th, 0.180 * s),
                                 (0.740 * s, -0.405 * s, 0.132 * s * th, 0.088 * s * th, 0.188 * s),
                                 (0.640 * s, -0.385 * s, 0.138 * s * th, 0.078 * s * th, 0.160 * s),
                                 (0.555 * s, -0.375 * s, 0.132 * s * th, 0.062 * s * th, 0.120 * s),
                                 (0.490 * s, -0.390 * s, 0.114 * s * th, 0.042 * s * th, 0.078 * s)])
        # The point of the hip, standing out under the skin (it is thin)
        b.ellipsoid(V(side * 0.122 * s * th, 0.868 * s, -0.262 * s), V(0.026 * s, 0.024 * s, 0.034 * s))
        # The point of the buttock
        b.ellipsoid(V(side * 0.060 * s * th, 0.800 * s, -0.585 * s), V(0.036 * s, 0.050 * s, 0.030 * s))
    # The neck, rising forward out of the chest, deep at its root, under a crest along its top
    nb, nt, along, throat = deer.neck_frame(c)
    nrings = []
    for t, _, _, _ in c.neck_shape:
        centre, w, d = deer.neck_at(c, t)
        nrings.append((centre, X * w, throat * d))
    b.tube(nrings, 16)
    for t in (0.2, 0.45, 0.7):
        centre, w, d = deer.neck_at(c, t)
        b.ellipsoid(centre - throat * d * 0.62, V(w * 0.62, d * 0.42, d * 0.85), rot_x(-math.atan2(along.y, along.z)), 12, 6)
    if kit.LOW:
        return kit.fused(b, None)
    mesh = bpy.data.meshes.new("part")
    b.bm.to_mesh(mesh)
    b.bm.free()
    part = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(part)
    remesh = part.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.008 * s
    remesh.adaptivity = 0.0
    smooth = part.modifiers.new("smooth", "SMOOTH")
    smooth.factor = 1.0
    smooth.iterations = 26
    bpy.context.view_layer.update()
    result = bpy.data.meshes.new_from_object(part.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(part)
    return result


def coat(c):
    def shapes(b):
        s = c.scale
        th = c.thick
        body = mass(c)
        b.bm.from_mesh(body)
        bpy.data.meshes.remove(body)
        head(c, b)
        # The dock: a short thick root to the tail
        tw = c.tail_width * s
        tube_along(b, c.tail, [tw * 0.95, tw * 0.85, tw * 0.6], [tw * 0.8, tw * 0.75, tw * 0.55], 10)
        for suffix, joints in c.legs.items():
            fore = suffix[1] == "f"
            deer.limb(b, joints, c.fore_shape if fore else c.hind_shape, s, th)
            # The knee is broad and flat in front; the point of the hock stands out behind
            knob_at = joints[2] + (V(0.0, 0.004 * s, 0.014 * s) if fore else V(0.0, 0.030 * s, -0.034 * s))
            b.ellipsoid(knob_at, V(0.030 * s, (0.032 if fore else 0.036) * s, 0.024 * s), None if fore else rot_x(-0.35), 10, 6)
            # The fetlock (the ergot at the back of it), and the pastern sloping forward from it to the coronet
            fet = joints[3]
            b.ellipsoid(fet + V(0.0, -0.004 * s, -0.008 * s), V(0.030 * s, 0.034 * s, 0.040 * s), None, 10, 6)
            toe = c.toes[suffix]
            coronet = V(fet.x, 0.060 * s, toe.z - 0.050 * s)
            tube_along(b, [fet, fet.lerp(coronet, 0.5), coronet], [0.027 * s, 0.025 * s, 0.031 * s], [0.032 * s, 0.028 * s, 0.034 * s], 10)
        return deer.furred(c, b, (0.0042 * s, 4, 30000))
    return shapes


def head(c, b):
    """The head, on the coat: the poll and forehead, the jowls, the long face, the muzzle and nostrils."""
    s = c.scale
    at = c.at
    tilt = rot_x(c.face_tilt)
    tube_along(b, [at(a, u) for a, u, _, _ in FACE], [w * s for _, _, w, _ in FACE], [d * s for _, _, _, d in FACE], 16)
    # The poll and the broad flat forehead between the eyes
    b.ellipsoid(at(0.03, 0.022), V(0.058 * s, 0.040 * s, 0.070 * s), tilt, 16, 8)
    b.ellipsoid(at(0.13, 0.010), V(0.056 * s, 0.026 * s, 0.075 * s), tilt, 14, 6)
    for side in (1.0, -1.0):
        b.ellipsoid(at(EYE[0] - 0.004, EYE[1] + 0.017, side * (EYE[2] - 0.010)), V(0.018 * s, 0.010 * s, 0.026 * s), tilt)  # brow over the eye
        b.ellipsoid(at(0.095, -0.052, side * 0.046), V(0.026 * s, 0.060 * s, 0.064 * s), tilt)  # the great round jowl
        b.ellipsoid(at(0.205, -0.030, side * 0.036), V(0.016 * s, 0.024 * s, 0.050 * s), tilt)  # the cheek bone's ridge
        b.ellipsoid(at(0.372, -0.010, side * 0.027), V(0.017 * s, 0.022 * s, 0.024 * s), tilt)  # the flare of the nostril
    # The soft upper lip, hanging a little over the lower
    b.ellipsoid(at(0.388, -0.047), V(0.036 * s, 0.022 * s, 0.020 * s), tilt, 12, 6)
    # The throat latch, under the back of the head
    b.ellipsoid(at(0.0, -0.050), V(0.050 * s, 0.050 * s, 0.050 * s), tilt)


def jaw(c):
    def shapes(b):
        s = c.scale
        at = c.at
        # The lower lip and chin (the jaw's branches are in the jowls, on the head)
        pts = [at(0.20, -0.070), at(0.28, -0.070), at(0.345, -0.068), at(0.378, -0.062), at(0.392, -0.056)]
        tube_along(b, pts, [0.030 * s, 0.026 * s, 0.027 * s, 0.024 * s, 0.018 * s], [0.016 * s, 0.015 * s, 0.017 * s, 0.015 * s, 0.011 * s], 12)
        b.ellipsoid(at(0.352, -0.080), V(0.022 * s, 0.014 * s, 0.020 * s), rot_x(c.face_tilt))  # the chin
        return deer.furred(c, b, (0.0035 * s, 2, 1100))
    return shapes


def nostrils(c):
    def shapes(b):
        s = c.scale
        for side in (1.0, -1.0):
            # Big comma-shaped nostrils, dark and wet inside
            b.ellipsoid(c.at(0.384, -0.014, side * 0.024), V(0.008 * s, 0.016 * s, 0.010 * s), Matrix.Rotation(side * 0.5, 3, "Y") @ rot_x(c.face_tilt + 0.9), 8, 4)
    return shapes


def eyes(c):
    def shapes(b):
        s = c.scale
        for side in (1.0, -1.0):
            b.ellipsoid(c.at(EYE[0], EYE[1], side * EYE[2]), EYE_SIZE * s, deer.eye_basis(c, side), 12, 7)
    return shapes


def mouth(c):
    def shapes(b):
        s = c.scale
        tube_along(b, [c.at(0.22, -0.052), c.at(0.30, -0.054), c.at(0.37, -0.050)], [0.026 * s, 0.022 * s, 0.016 * s], [0.008 * s] * 3, 8)
    return shapes


def tongue(c):
    def shapes(b):
        s = c.scale
        tube_along(b, [c.at(0.24, -0.062), c.at(0.31, -0.064), c.at(0.365, -0.060)], [0.020 * s, 0.017 * s, 0.012 * s], [0.007 * s] * 3, 8)
    return shapes


def teeth(c):
    def shapes(b):
        s = c.scale
        # The incisors, upper and lower, at the front; worn and yellow (an old horse)
        for k in (-1.0, -0.5, 0.0, 0.5, 1.0):
            for up, way in ((-0.044, 1.0), (-0.058, -1.0)):
                base = c.at(0.377, up, k * 0.012)
                kit.spike(b, base, base + c.face * 0.004 * s - c.face_up * way * 0.008 * s, 0.0035 * s, 5)
    return shapes


def hooves(c):
    def shapes(b):
        s = c.scale
        for suffix, joints in c.legs.items():
            toe = c.toes[suffix]
            fet = joints[3]
            # One hoof: the wall sloping down and out from the coronet to the ground, the toe in front, the heels
            # lower behind; worn and chipped at the ground
            rings = []
            for k, (up, wide, deep, back) in enumerate(((0.000, 0.042, 0.046, 0.000), (0.006, 0.043, 0.047, 0.002),
                                                        (0.022, 0.040, 0.043, 0.010), (0.040, 0.036, 0.038, 0.020),
                                                        (0.056, 0.031, 0.033, 0.030), (0.064, 0.029, 0.030, 0.033))):
                centre = V(fet.x, max(up, 0.0005) * s, toe.z - (deep + back) * s)
                rings.append((centre, X * wide * s, Z * deep * s))
            b.tube(dome(rings[0], -Y, 0.003 * s, 1)[::-1] + rings + dome(rings[-1], Y, 0.006 * s, 2), 14)
    return shapes


def chestnuts(c):
    def shapes(b):
        s = c.scale
        for suffix, joints in c.legs.items():
            fore = suffix[1] == "f"
            side = 1.0 if suffix[2] == "l" else -1.0
            # The horny chestnut inside each forearm above the knee, and inside each hock
            at = joints[1].lerp(joints[2], 0.72) if fore else joints[2] + V(0.0, 0.03 * s, 0.01 * s)
            b.ellipsoid(at + V(-side * 0.030 * s, 0.0, 0.0), V(0.006 * s, 0.016 * s, 0.010 * s), None, 8, 4)
    return shapes


def ears(c):
    return deer.ears(c)


def ear_linings(c):
    return deer.ear_linings(c)


# --- The hair ---

def wobble(i, k):
    return math.sin(i * 7.31 + k * 3.7), math.sin(i * 3.1 + k * 5.3), math.sin(i * 1.77 + k * 9.1)


def lock(b, points, width, flat=0.55, segments=6, sideways=X):
    """One lock of hair along `points`, thick at its root and ragged at its end (`flat` as deep as it is wide,
    its width lying across `sideways`)."""
    n = len(points)
    widths = [width * (1.0 - 0.7 * (i / (n - 1)) ** 1.6) for i in range(n)]
    widths[-1] = width * 0.15
    tube_along(b, points, widths, [w * flat for w in widths], segments, sideways=sideways)


def mane(c):
    """The mane: long and tangled, down the right side of the neck (some of it over to the left), in broad locks
    lying over each other like shingles, some of them grown together into thick mats; the forelock down the face."""
    def shapes(b):
        low = kit.LOW
        s = c.scale
        nb, nt, along, throat = deer.neck_frame(c)
        steps = 30 if not low else 9
        for i in range(steps):
            t = 0.0 + 0.95 * i / (steps - 1)
            centre, w, d = deer.neck_at(c, t)
            per = (-0.5, -0.15, 0.2, 0.5) if not low else (-0.2, 0.3)
            for k, spread in enumerate(per):
                j1, j2, j3 = wobble(i, k)
                # Most of it falls to the right; now and then a lock goes over to the left
                side = -1.0 if (i * 5 + k * 3) % 11 != 4 else 1.0
                mat = (i * 3 + k) % 7 == 0  # a mat: locks grown together into a thick rope
                length = (0.25 + 0.07 * j1) * s * (1.0 - 0.3 * t) * (1.2 if mat else 1.0) * (0.6 if (i + k) % 13 == 5 else 1.0)
                width = (0.022 if mat else 0.034) * s * (1.0 + 0.2 * j2) * (1.0 - 0.3 * t)
                root = centre - throat * d * 0.98 + X * w * spread * 0.45
                points = [root + (centre - root).normalized() * 0.006 * s]
                # Over the crest and down the side of the neck, lying on it, then hanging free under it
                gone = 0.0
                theta = spread * 0.3 * side
                last = root
                lift = 1.04 + 0.03 * k
                while gone < length and theta < math.pi * 0.6:
                    theta += 0.3
                    p = centre + (-throat * d * math.cos(theta) * 1.08 + X * side * w * math.sin(theta) * 1.06) * lift - along * 0.014 * s * theta
                    gone += (p - last).length
                    points.append(p)
                    last = p
                hang = length - gone
                if hang > 0.01 * s:
                    down = (V(0.0, -1.0, 0.0) + X * side * 0.3 - along * 0.25).normalized()
                    for q in (0.35, 0.7, 1.0):
                        wave = X * side * (0.004 + math.sin(q * 5.0 + j1 * 3.0) * 0.008) * s + along * math.sin(q * 4.0 + j2) * 0.010 * s
                        points.append(last + down * hang * q + wave)
                if low and len(points) > 5:
                    points = points[::2] + ([points[-1]] if len(points) % 2 == 0 else [])
                lock(b, points, width, 0.8 if mat else 0.32, 6, along)
        # The forelock: from the poll, between the ears, down the forehead to the eyes
        for k in ((-1.0, -0.45, 0.1, 0.6, 1.0) if not low else (-0.4, 0.4)):
            j1, j2, _ = wobble(int(k * 7 + 3), 2)
            pts = []
            for a in (-0.03, 0.02, 0.07, 0.115 + 0.02 * j1, 0.150 + 0.025 * j1):
                up, hw, hd = face_at(max(a, -0.02))
                top = hd + (0.034 if a < 0.04 else 0.014)
                pts.append(c.at(a, up + top, k * 0.016 + 0.005 * j2 * max(a, 0.0) / 0.15))
            lock(b, pts, 0.020 * s, 0.4, 6, X)
    return shapes


def tail_hair(c):
    """The tail: a heavy fall of hair from the dock nearly to the fetlocks, matted into ropes here and there,
    knotted and burred, a few locks broken short."""
    def shapes(b):
        low = kit.LOW
        s = c.scale
        count = 64 if not low else 12
        top, mid, end = c.hair
        for i in range(count):
            j1, j2, j3 = wobble(i, 1)
            f = (i % 8) / 7.0  # where along the dock it grows from
            round_about = (i * 2.399) % math.tau
            # (off the top and sides of the dock, not underneath it)
            a = -math.pi * 0.5 + math.cos(round_about) * math.pi * 0.7
            k = min(int(f * 2), 1)
            u = f * 2 - k
            on_dock = c.tail[k].lerp(c.tail[k + 1], u)
            tw = c.tail_width * s
            root = on_dock + V(math.cos(a) * tw * 0.7, -math.sin(a) * tw * 0.6, 0.0)
            short = 0.6 if i % 13 == 7 else (0.85 if i % 5 == 1 else 1.0)
            spread = V(j1 * 0.045 * s, 0.0, j2 * 0.028 * s)
            pts = [root, root + V(math.cos(a) * 0.016 * s, -0.012 * s, -0.020 * s)]
            for q in (0.25, 0.5, 0.75, 1.0):
                q2 = q * short
                p = (mid.lerp(end, (q2 - 0.5) * 2.0) if q2 > 0.5 else top.lerp(mid, q2 * 2.0)) + spread * (0.4 + q2) + V(0.0, 0.0, -0.016 * s)
                p += V(math.sin(q * 6.0 + j3 * 4.0) * 0.012 * s, 0.0, math.cos(q * 5.0 + j1 * 3.0) * 0.010 * s)
                pts.append(p)
            if low:
                pts = [pts[0], pts[2], pts[4], pts[5]]
            mat = i % 6 == 0
            lock(b, pts, (0.022 if mat else 0.024) * s, 0.9 if mat else 0.45, 6, X)
            if not low and i % 9 == 4:
                # (a knot, or a burr caught in it)
                knot = pts[3].lerp(pts[4], 0.4)
                b.ellipsoid(knot, V(0.011 * s, 0.015 * s, 0.011 * s), None, 8, 4)
    return shapes


# --- The halter ---

def halter(c):
    """An old rope halter: a noseband round the face, cheek pieces up to the crown behind the ears, a throat latch,
    a knot under the chin, and a short end of lead rope hanging from it, frayed."""
    def shapes(b):
        s = c.scale
        at = c.at
        r = 0.0075 * s
        loop_at = 0.285
        up, hw, hd = face_at(loop_at)
        ring = []
        for k in range(17):
            a = math.tau * k / 16
            ring.append(at(loop_at, up + math.sin(a) * (hd + 0.006), math.cos(a) * (hw + 0.006)))
        b.strand(ring, [r] * len(ring), 6)
        for side in (1.0, -1.0):
            # Up the cheek, past the eye, behind the ear and over the poll
            pts = [at(loop_at, up, side * (hw + 0.006))]
            for a, extra in ((0.20, 0.007), (0.13, 0.008), (0.06, 0.008)):
                u, w, d = face_at(a)
                pts.append(at(a, u - d * 0.25, side * (w + extra)))
            pts.append(at(-0.03, 0.035, side * 0.050))
            pts.append(at(-0.045, 0.068, side * 0.010))
            b.strand(pts, [r] * len(pts), 6)
            # The throat latch, from the cheek piece round under the throat
            b.strand([at(0.03, -0.01, side * 0.066), at(0.02, -0.06, side * 0.04), at(0.015, -0.085, 0.0)], [r * 0.9] * 3, 6)
        # The knot under the chin
        knot = at(loop_at, up - hd - 0.008)
        b.ellipsoid(knot, V(r * 2.2, r * 2.0, r * 2.4), None, 8, 5)
        # The end of the lead rope: hanging from the knot, frayed at its end into strands
        hang = [knot, knot + V(0.0, -0.06, -0.012) * s, knot + V(0.004, -0.13, -0.02) * s, knot + V(0.008, -0.19, -0.018) * s]
        b.strand(hang, [r * 1.15] * len(hang), 6)
        end = hang[-1]
        for k in range(5 if not kit.LOW else 2):
            a = math.tau * k / 5
            b.strand([end, end + V(math.cos(a) * 0.012, -0.03, math.sin(a) * 0.012) * s, end + V(math.cos(a) * 0.022, -0.055 - 0.01 * (k % 2), math.sin(a) * 0.02) * s],
                     [r * 0.4, r * 0.3, r * 0.15], 4)
    return shapes


# --- Assembly ---

HAIR = ("mane", "forelock", "tail_hair")


def parts(c):
    made = [("coat", 0, coat(c)), ("jaw", 0, jaw(c)), ("ears", 0, ears(c)),
            ("mouth", 2, mouth(c)), ("tongue", 2, tongue(c)), ("teeth", 2, teeth(c)), ("eyes", 2, eyes(c)),
            ("nose", 2, nostrils(c)), ("linings", 2, ear_linings(c)), ("hooves", 2, hooves(c)), ("chestnuts", 2, chestnuts(c)),
            ("mane", 1, mane(c)), ("tail_hair", 1, tail_hair(c))]
    if c.halter:
        made.append(("halter", 2, halter(c)))
    return made


def part_colours(_c):
    return {
        "mouth": (0.26, 0.13, 0.13, 0.5), "tongue": (0.36, 0.18, 0.19, 0.6), "teeth": (0.58, 0.52, 0.38, 0.3),
        "eyes": (0.075, 0.05, 0.035, 1.0), "nose": (0.035, 0.03, 0.03, 0.8),
        "linings": (0.16, 0.14, 0.12, 0.0), "hooves": (0.20, 0.185, 0.16, 0.12), "chestnuts": (0.10, 0.09, 0.08, 0.1),
        "halter": (0.30, 0.27, 0.21, 0.0),
    }


def weights(c):
    base = DEER_WEIGHTS(c)
    s = c.scale

    def weigh(part, p):
        if part in ("halter", "nose", "teeth"):
            # (the lower incisors and the lead rope go with the head, near enough)
            return {"head": 1.0} if part != "teeth" or p.y > c.at(0.377, -0.051).y else {"jaw": 1.0}
        if part == "chestnuts":
            return base("coat", p)
        if part == "mane":
            # The forelock is the head's; the mane goes with the neck
            q = p - c.head
            if q.dot(c.face) > -0.02 * s and q.dot(c.face_up) > 0.0 and p.z > c.head.z - 0.04 * s:
                return {"head": 1.0}
            return base("mane", p)
        if part == "tail_hair":
            # Hair along the dock goes with the dock; below it, down the hair's own bones
            if p.y > c.hair[0].y + 0.02 * s:
                return base("coat", p) if p.z < c.tail[0].z + 0.01 * s else {"pelvis": 1.0}
            off, along = deer.chain_param(p, c.hair)
            first = 1.0 - blend(0.0, 0.9, along)
            return {"tail_1": first, "tail_2": 1.0 - first}
        return base(part, p)
    return weigh


def bones(c):
    s = c.scale
    listed = [
        ("body", c.body, None), ("chest", c.chest, "body"), ("pelvis", c.pelvis, "body"),
        ("neck", c.neck, "chest"), ("neck_1", c.neck_1, "neck"), ("head", c.head, "neck_1"), ("jaw", c.jaw, "head"),
    ]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root, mid, end = (V(j.x * side, j.y, j.z) for j in c.ear)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
    listed.append(("nose", c.at(0.40, -0.02), "head"))
    listed.append(("brow", c.at(0.10, 0.07), "head"))
    listed.append(("seat", c.seat, "body"))
    centre, w, d = deer.neck_at(c, 0.12)
    listed.append(("grip", centre - deer.neck_frame(c)[3] * d * 1.05, "neck"))
    listed.append(("tail", c.tail[0], "pelvis"))
    listed.append(("tail_1", c.tail[2], "tail"))
    listed.append(("tail_2", c.hair[1], "tail_1"))
    listed.append(("tail_end", c.hair[2], "tail_2"))
    for suffix, joints in c.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
        listed.append(("toe" + suffix, c.toes[suffix], "paw" + suffix))
    return listed


def paint(c, whole, part_of):
    """Vertex colours: on the coat, red how open the surface is (darker between the ribs), green the dark of the
    points and the dorsal stripe, blue the pale; on the hair each lock its own number; on the other parts their colours."""
    s = c.scale
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred_ = [part in ("coat", "jaw", "ears") for part in part_of]
    open_ = [1.0] * len(whole.verts)
    for vert in whole.verts:
        if not furred_[vert.index] or not vert.link_edges:
            continue
        rise = 0.0
        for edge in vert.link_edges:
            step = edge.other_vert(vert).co - vert.co
            if step.length > 1e-6:
                rise += step.dot(vert.normal) / step.length
        open_[vert.index] = rise / len(vert.link_edges)
    for _ in range(3):
        spread = list(open_)
        for vert in whole.verts:
            if furred_[vert.index] and vert.link_edges:
                around = [open_[e.other_vert(vert).index] for e in vert.link_edges]
                spread[vert.index] = 0.5 * open_[vert.index] + 0.5 * sum(around) / len(around)
        open_ = spread
    measured = sorted(open_[i] for i in range(len(open_)) if furred_[i])
    middle = measured[len(measured) // 2] if measured else 0.0
    colours = part_colours(c)
    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part in HAIR:
            vert[layer] = (1.0, 1.0, 1.0, (math.sin(vert.index // 18 * 12.9898) * 43758.5453) % 1.0)
            continue
        if part in colours:
            vert[layer] = colours[part]
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 5.0, 0.0), 1.0) if furred_[vert.index] else 1.0
        y, rx, ry = deer.trunk_at(c, p.z)
        # The ribs, showing along the flank: dark furrows between them
        if -0.20 * s < p.z < 0.20 * s and y - ry * 0.75 < p.y < y + ry * 0.55 and part == "coat":
            ribs = 0.5 + 0.5 * math.cos((p.z + (p.y - y) * 0.35) / (0.052 * s) * math.tau)
            showing = blend(-0.20 * s, -0.10 * s, p.z) * blend(0.20 * s, 0.08 * s, p.z) * blend(y + ry * 0.55, y + ry * 0.2, p.y) * blend(y - ry * 0.75, y - ry * 0.35, p.y)
            shade *= 1.0 - 0.22 * ribs * showing
        dark = 0.0
        pale = 0.0
        # The points: the legs dark from above the knees and the hocks down
        dark = max(dark, blend(0.40 * s, 0.30 * s, p.y) if p.z > -0.05 * s else blend(0.47 * s, 0.37 * s, p.y))
        # The dorsal stripe down the middle of the back, from the withers to the tail
        if part == "coat" and -0.6 * s < p.z < 0.25 * s:
            top = y + ry
            dark = max(dark, blend(0.024 * s, 0.010 * s, abs(p.x)) * blend(top - 0.05 * s, top - 0.01 * s, p.y) * 0.7)
        # The head: the muzzle dark (the skin shows through), round the eyes, the ears' rims and tips
        q = p - c.head
        along = q.dot(c.face) / s
        up = q.dot(c.face_up) / s
        on_head = q.z > -0.05 * s and p.y > c.head.y - 0.25 * s and part != "coat" or (q.z > -0.04 * s and part == "coat" and along > -0.02 and abs(p.x) < 0.09 * s and p.y > c.head.y - 0.3 * s)
        if part in ("coat", "jaw") and on_head:
            dark = max(dark, blend(0.31, 0.37, along) * 0.85)
            eye = c.at(*EYE)
            from_eye = (V(abs(p.x), p.y, p.z) - eye).length / s
            dark = max(dark, blend(0.040, 0.026, from_eye) * 0.45)
            # (a dun's face is darker than its body)
            dark = max(dark, blend(0.0, 0.12, along) * 0.25)
        if part == "ears":
            root, mid, end = c.ear
            reach = (V(abs(p.x), p.y, p.z) - root).length / (end - root).length
            dark = max(dark, blend(0.55, 0.95, reach) * 0.9, 0.35)
        # The belly and the insides of the legs a little paler
        belly = blend(y - ry * 0.55, y - ry * 0.95, p.y) * blend(0.30 * s, 0.22 * s, p.z) * blend(-0.45 * s, -0.36 * s, p.z)
        pale = max(pale, belly * 0.55)
        if dark > 0.3:
            pale *= 1.0 - dark
        vert[layer] = (shade, dark, pale, 1.0)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            vert = loop.vert
            uv2 = (0.95, 0.95)
            if part_of[vert.index] == "eyes":
                p = kit.from_blender(vert.co)
                side = 1.0 if p.x >= 0.0 else -1.0
                centre = c.at(EYE[0], EYE[1], side * EYE[2])
                local = deer.eye_basis(c, side).inverted() @ (p - centre)
                if local.z > -0.3 * 0.017 * s:
                    uv2 = (0.5 + local.x / (EYE_SIZE.x * s) * 0.4, 0.5 + local.y / (EYE_SIZE.y * s) * 0.4)
            loop[second].uv = uv2
    return layer


def render(folder, name, c):
    deer.render(folder, name, c)


def main():
    # (the deer's builder does the building, with the horse's parts in place of its own)
    deer.EYE = EYE
    deer.EYE_SIZE = EYE_SIZE
    deer.EAR_RINGS = EAR_RINGS
    deer.parts = parts
    deer.paint = paint
    deer.weights = weights
    deer.bones = bones
    deer.out_folder = out_folder
    deer.MATERIALS = [("coat", (0.50, 0.44, 0.34)), ("mane", (0.10, 0.09, 0.08)), ("parts", (1.0, 1.0, 1.0))]
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        for animal in ANIMALS:
            deer.export(animal, preview)


if __name__ == "__main__":
    main()
