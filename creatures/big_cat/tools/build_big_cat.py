"""Builds the big cats (creatures/big_cat): a Eurasian lynx and a black panther.

Run from the game's root (it needs tools/build_dog.py, which needs the character
controller's tools/build_character.py):
    blender --background --python creatures/big_cat/tools/build_big_cat.py
    blender --background --python creatures/big_cat/tools/build_big_cat.py -- <preview folder> lynx

Writes creatures/big_cat/models/lynx.glb and panther.glb, and a demade `_lo`
version of each (and, with a preview folder, an editable .blend and pictures
there).

THE LYNX (Eurasian): long in the leg, short in the body, its rump a little
higher than its shoulders; huge furry paws; a short bobbed tail, black at the
end; a broad short face with a ruff of long fur flaring from the cheeks (barred
dark), white about the mouth, the chin and round the eyes; tall pointed ears,
black behind, with long black tufts at their tips. Grey-brown, paler and
warmer on the flanks, cream under the belly and inside the legs, spotted dark
all over, most on the legs and flanks.

THE PANTHER (a melanistic leopard): long and low, heavy in the forequarters,
short thick legs, broad paws, a long thick tail carried low with its end
curled up; a broad round head, a short muzzle with full whisker pads, small
round ears set wide; big forward-looking eyes, green-gold. All black: the
leopard's rosettes are there in the coat, a shade darker than the rest, seen
only where the light falls on it (the shader's: big_cat_look.gd).

Both are built on the dog's skeleton and with the dog's tools (tools/build_dog.py,
GameCommon's godot/dog): the same bones and names, so DogRig (BigCatRig) moves
them. Two surfaces only, so that a cat is few draws: the coat (with its fur
shells) and everything else (`parts`, coloured by vertex colour). The coat's
vertex colours are what big_cat_look.gd reads: red, how open the surface is
(dark in creases); green, how dark its markings are (ear backs, tufts, the tail's
end, the bars on the ruff); blue, how pale (the underside, the lips, round the
eyes); alpha, its spots: 0 to 0.5 solid spots (none to strongest), 0.5 to 1
rosettes (none to strongest).

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

import bmesh  # noqa: F401  (Blender's)
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
GAME = os.path.dirname(os.path.dirname(COMPONENT))
sys.path.insert(0, os.path.join(GAME, "tools"))
import build_dog as dog  # noqa: E402  (the dog's build: its skeleton, fur and export)
import build_character as kit  # noqa: E402

X, Y, Z = kit.X, kit.Y, kit.Z
V = dog.V
blend = kit.blend
dome = kit.dome
dog.OUT = os.path.join(COMPONENT, "models")
# (the dog's own, before they are replaced with the cats' below)
_dog_bones = dog.bones
_dog_weights = dog.weights


def lynx():
    breed = dog.Breed(
        name="lynx",
        kind="lynx",
        cropped=0.0,
        scars=-1,
        body=V(0.0, 0.56, 0.0), chest=V(0.0, 0.56, 0.20), pelvis=V(0.0, 0.60, -0.22),
        # (along the body, centre height, half width, half height): short and deep, the rump
        # high, the belly loose under the loin
        trunk=[(-0.38, 0.634, 0.052, 0.058), (-0.33, 0.626, 0.088, 0.098), (-0.24, 0.610, 0.096, 0.114),
               (-0.12, 0.586, 0.092, 0.120), (0.0, 0.568, 0.096, 0.138), (0.10, 0.552, 0.100, 0.158),
               (0.20, 0.554, 0.098, 0.154), (0.29, 0.570, 0.086, 0.124), (0.36, 0.592, 0.062, 0.084)],
        # Shoulder, elbow, wrist, paw; hip, stifle, hock, paw (the left legs). Long legs, the
        # elbows tucked in under the chest, the hocks high.
        fore=[V(0.078, 0.530, 0.235), V(0.076, 0.365, 0.185), V(0.074, 0.130, 0.205), V(0.074, 0.036, 0.236)],
        hind=[V(0.074, 0.595, -0.285), V(0.078, 0.400, -0.170), V(0.074, 0.190, -0.380), V(0.074, 0.036, -0.342)],
        # (how far down the leg, counted in joints; half width; half depth; forward offset)
        fore_shape=[(-0.3, 0.048, 0.076, 0.0), (0.0, 0.052, 0.080, 0.0), (0.5, 0.050, 0.068, 0.004), (1.0, 0.045, 0.055, -0.004),
                    (1.3, 0.044, 0.052, 0.004), (1.7, 0.039, 0.045, 0.0), (2.0, 0.037, 0.042, 0.0), (2.5, 0.040, 0.042, 0.004),
                    (3.0, 0.044, 0.044, 0.006)],
        hind_shape=[(-0.25, 0.048, 0.092, 0.0), (0.0, 0.054, 0.108, 0.0), (0.45, 0.052, 0.098, 0.0), (0.85, 0.042, 0.068, 0.004),
                    (1.0, 0.040, 0.060, 0.004), (1.3, 0.037, 0.055, -0.006), (1.7, 0.032, 0.042, 0.0), (2.0, 0.032, 0.041, -0.003),
                    (2.4, 0.034, 0.039, 0.0), (2.8, 0.038, 0.041, 0.004), (3.0, 0.042, 0.042, 0.006)],
        # Huge round furry paws (half width, half length)
        paw=(0.048, 0.050),
        muscle=1.0,
        neck=V(0.0, 0.612, 0.318), head=V(0.0, 0.690, 0.432),
        neck_shape=[(-0.3, 0.090, 0.0), (0.0, 0.086, 0.010), (0.35, 0.080, 0.014), (0.7, 0.072, 0.010), (1.0, 0.064, 0.0), (1.15, 0.056, 0.0)],
        skull_at=V(0.0, 0.022, 0.030), skull_size=V(0.056, 0.052, 0.060),
        # The face, as (where from the skull's middle, half sizes, tilt forward): a round
        # cranium with the brow over the eyes, broad cheekbones, a short broad muzzle, the
        # bridge of the nose, full whisker pads
        face=[("cranium", V(0.0, 0.004, -0.004), V(0.056, 0.052, 0.060), 0.0),
              ("forehead", V(0.0, 0.020, 0.032), V(0.046, 0.034, 0.038), 0.0),
              ("cheeks", V(0.040, -0.014, 0.022), V(0.028, 0.030, 0.038), 0.15),
              ("jowls", V(0.034, -0.030, -0.008), V(0.026, 0.028, 0.034), 0.0),
              ("muzzle", V(0.0, -0.028, 0.062), V(0.036, 0.027, 0.032), 0.0),
              ("bridge", V(0.0, -0.002, 0.064), V(0.019, 0.018, 0.030), 0.25),
              ("pads", V(0.018, -0.036, 0.084), V(0.019, 0.017, 0.016), 0.0)],
        # (the middle of the whisker pad on its left, from the skull's middle)
        pad=V(0.018, -0.036, 0.084),
        nose=(V(0.0, -0.014, 0.097), V(0.012, 0.008, 0.007)),
        jaw_at=V(0.0, -0.032, 0.000),
        jaw_shape=[(-0.01, -0.046, 0.036, 0.016), (0.04, -0.050, 0.030, 0.014), (0.076, -0.050, 0.020, 0.011)],
        # The line the teeth meet on, the length of the mouth, its half width at the fangs and at the back
        mouth=(-0.046, 0.086, 0.015, 0.030),
        eye=(V(0.025, 0.010, 0.056), 0.0115),
        # Each ear: where it roots, part way up it, and its tip. Tall, pointed, a little out.
        ear_at=[V(0.032, 0.044, -0.010), V(0.040, 0.078, -0.018), V(0.046, 0.108, -0.024)],
        # (the long black tuft standing up off the tip)
        tuft=0.042,
        tail_root=V(0.0, 0.630, -0.385),
        # A short bob, carried down
        tail_at=[(0.0, 0.0, 0.0), (0.0, -0.030, -0.035), (0.0, -0.062, -0.058), (0.0, -0.094, -0.072), (0.0, -0.122, -0.078)],
        tail_shape=[0.030, 0.034, 0.034, 0.031, 0.025, 0.014],
        whiskers=0.06,
        fur=(0.0036, 10, 15000),
    )
    return breed


def panther():
    breed = dog.Breed(
        name="panther",
        kind="panther",
        cropped=0.0,
        scars=-1,
        body=V(0.0, 0.54, 0.0), chest=V(0.0, 0.53, 0.25), pelvis=V(0.0, 0.57, -0.29),
        # Long and low, deep at the chest, the back level, the belly loose under the loin
        trunk=[(-0.50, 0.600, 0.056, 0.064), (-0.45, 0.594, 0.094, 0.106), (-0.36, 0.580, 0.106, 0.124),
               (-0.24, 0.566, 0.102, 0.124), (-0.10, 0.556, 0.104, 0.138), (0.04, 0.546, 0.110, 0.160),
               (0.16, 0.540, 0.114, 0.178), (0.28, 0.546, 0.108, 0.172), (0.38, 0.560, 0.092, 0.140),
               (0.46, 0.580, 0.068, 0.096)],
        # Short, heavy legs: the forearms thick, the elbows in under the chest
        fore=[V(0.088, 0.520, 0.300), V(0.084, 0.350, 0.250), V(0.080, 0.112, 0.270), V(0.080, 0.036, 0.302)],
        hind=[V(0.080, 0.565, -0.385), V(0.084, 0.370, -0.270), V(0.080, 0.165, -0.490), V(0.080, 0.036, -0.455)],
        fore_shape=[(-0.3, 0.058, 0.088, 0.0), (0.0, 0.061, 0.092, 0.0), (0.5, 0.058, 0.080, 0.006), (1.0, 0.052, 0.064, -0.004),
                    (1.3, 0.051, 0.060, 0.006), (1.7, 0.045, 0.052, 0.0), (2.0, 0.040, 0.045, 0.0), (2.5, 0.042, 0.045, 0.004),
                    (3.0, 0.046, 0.046, 0.006)],
        hind_shape=[(-0.25, 0.054, 0.100, 0.0), (0.0, 0.060, 0.118, 0.0), (0.45, 0.058, 0.106, 0.0), (0.85, 0.046, 0.076, 0.004),
                    (1.0, 0.041, 0.064, 0.004), (1.3, 0.038, 0.058, -0.008), (1.7, 0.031, 0.042, 0.0), (2.0, 0.030, 0.040, -0.003),
                    (2.4, 0.033, 0.038, 0.0), (2.8, 0.037, 0.040, 0.004), (3.0, 0.041, 0.042, 0.006)],
        paw=(0.054, 0.054),
        muscle=1.15,
        # The neck thick, the head carried low, level with the back
        neck=V(0.0, 0.584, 0.410), head=V(0.0, 0.650, 0.580),
        neck_shape=[(-0.3, 0.106, 0.0), (0.0, 0.100, 0.012), (0.35, 0.092, 0.016), (0.7, 0.084, 0.012), (1.0, 0.076, 0.0), (1.15, 0.068, 0.0)],
        skull_at=V(0.0, 0.022, 0.030), skull_size=V(0.072, 0.062, 0.076),
        face=[("cranium", V(0.0, 0.004, -0.004), V(0.072, 0.062, 0.076), 0.0),
              ("forehead", V(0.0, 0.024, 0.040), V(0.058, 0.040, 0.046), 0.0),
              ("cheeks", V(0.050, -0.018, 0.028), V(0.034, 0.036, 0.046), 0.15),
              ("jowls", V(0.042, -0.038, -0.010), V(0.032, 0.036, 0.042), 0.0),
              ("muzzle", V(0.0, -0.034, 0.080), V(0.046, 0.034, 0.042), 0.0),
              ("bridge", V(0.0, -0.004, 0.084), V(0.025, 0.022, 0.038), 0.25),
              ("pads", V(0.023, -0.044, 0.106), V(0.025, 0.021, 0.020), 0.0)],
        pad=V(0.023, -0.044, 0.106),
        nose=(V(0.0, -0.016, 0.122), V(0.016, 0.011, 0.008)),
        jaw_at=V(0.0, -0.040, 0.004),
        jaw_shape=[(-0.01, -0.058, 0.046, 0.020), (0.05, -0.064, 0.038, 0.017), (0.096, -0.064, 0.025, 0.013)],
        mouth=(-0.058, 0.108, 0.020, 0.040),
        eye=(V(0.031, 0.012, 0.070), 0.0135),
        # Small round ears set wide
        ear_at=[V(0.048, 0.048, -0.016), V(0.058, 0.070, -0.024), V(0.063, 0.090, -0.030)],
        tuft=0.0,
        tail_root=V(0.0, 0.596, -0.515),
        # Long and thick, hanging low, its end curled up
        tail_at=[(0.0, 0.0, 0.0), (0.0, -0.160, -0.150), (0.0, -0.350, -0.230), (0.0, -0.470, -0.360), (0.0, -0.455, -0.560)],
        tail_shape=[0.040, 0.037, 0.033, 0.030, 0.028, 0.026],
        whiskers=0.075,
        fur=(0.0044, 10, 17000),
    )
    return breed


CATS = [lynx(), panther()]


def is_lynx(breed):
    return breed.kind == "lynx"


def smooth_line(points, between=3):
    """More points along a line, curving smoothly through the given ones (Catmull-Rom)."""
    made = []
    ends = [points[0] * 2.0 - points[1]] + list(points) + [points[-1] * 2.0 - points[-2]]
    for i in range(1, len(ends) - 2):
        p0, p1, p2, p3 = ends[i - 1], ends[i], ends[i + 1], ends[i + 2]
        for k in range(between):
            t = k / between
            t2, t3 = t * t, t * t * t
            made.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
    made.append(points[-1])
    return made


def smooth_radii(radii, between=3):
    made = []
    for a, b in zip(radii, radii[1:]):
        for k in range(between):
            made.append(a + (b - a) * k / between)
    made.append(radii[-1])
    return made


# --- The shapes ---

def coat(breed):
    def shapes(b):
        low = kit.LOW
        m = breed.muscle
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.05)[::-1] + rings + dome(rings[-1], Z, 0.04), 18)
        shoulder = breed.fore[0]
        hip = breed.hind[0]
        for side in (1.0, -1.0):
            # The forearm's great muscle, from the shoulder to the elbow, and the haunch
            arm = shoulder.lerp(breed.fore[1], 0.35)
            b.ellipsoid(V(side * (arm.x + 0.006), arm.y + 0.04, arm.z), V(0.040 * m, 0.105, 0.072 * m), Matrix.Rotation(0.30, 3, "X"))
            thigh = hip.lerp(breed.hind[1], 0.35)
            b.ellipsoid(V(side * (thigh.x + 0.004), thigh.y + 0.02, thigh.z - 0.01), V(0.048 * m, 0.124, 0.100 * m), Matrix.Rotation(-0.40, 3, "X"))
            # (and the muscle of the second thigh, behind the shank)
            shank = breed.hind[1].lerp(breed.hind[2], 0.35)
            b.ellipsoid(V(side * shank.x, shank.y, shank.z - 0.02), V(0.030 * m, 0.060, 0.042 * m), Matrix.Rotation(0.6, 3, "X"))
        # The point of the chest, and the loose skin of the belly (a cat's pouch) under the loin
        b.ellipsoid(V(0.0, shoulder.y + 0.01, shoulder.z + 0.06), V(0.050 * m, 0.050, 0.045))
        y, rx, ry = dog.trunk_at(breed, hip.z + 0.12)
        b.ellipsoid(V(0.0, y - ry + 0.035, hip.z + 0.12), V(rx * 0.7, 0.035, 0.10))

        # Neck, rising forward out of the chest
        base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top, t) - across * sag, X * r, across * (r * 1.15)) for t, r, sag in breed.neck_shape], 14)

        # The head: a round cranium, a flat short face, broad cheeks, a short broad muzzle, full whisker pads
        skull = breed.skull
        for name, at, size, tilt in breed.face:
            turn = Matrix.Rotation(tilt, 3, "X") if tilt else None
            if at.x != 0.0:
                for side in (1.0, -1.0):
                    b.ellipsoid(skull + V(side * at.x, at.y, at.z), size, turn, 12, 7)
            else:
                b.ellipsoid(skull + at, size, turn, 16 if name == "cranium" else 12, 9 if name == "cranium" else 7)
        size = breed.skull_size
        if is_lynx(breed) and not low:
            # The ruff: long fur flaring out and down from each cheek in a fringe, longest at its lowest
            for side in (1.0, -1.0):
                for k in range(11):
                    t = k / 10.0
                    root = skull + V(side * (size.x * 0.80 - 0.010 * t), -size.y * (0.05 + 0.85 * t), size.z * (0.05 - 0.50 * t))
                    out = V(side * (0.80 - 0.40 * t), -0.25 - 0.85 * t, -0.35 - 0.15 * t).normalized()
                    length = 0.045 + 0.040 * math.sin(math.pi * min(t * 1.1, 1.0))
                    kit.spike(b, root, root + out * length, 0.016, 6)
        if is_lynx(breed) and low:
            for side in (1.0, -1.0):
                b.ellipsoid(skull + V(side * size.x * 0.92, -size.y * 0.55, -size.z * 0.10), V(0.024, 0.044, 0.032), Matrix.Rotation(0.4, 3, "X"))

        # The tail, curving smoothly through its joints
        line = [breed.tail_root + V(0.0, 0.03, 0.05)] + breed.tail
        b.strand(smooth_line(line, 2 if low else 3), smooth_radii(breed.tail_shape, 2 if low else 3), 12)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            dog.limb(b, joints, breed.fore_shape if fore else breed.hind_shape)
            width, length = breed.paw
            paw = joints[3]
            if not low:
                # (the point of the elbow, and of the hock)
                knob = joints[1] + V(0.0, 0.010, -0.032) if fore else joints[2] + V(0.0, 0.016, -0.024)
                b.ellipsoid(knob, V(width * 0.5, 0.028, 0.024), None, 8, 5)
            # A round cat's paw, the four toes round its front
            b.ellipsoid(paw + V(0.0, -0.004, length * 0.30), V(width, 0.030, length), None, 12, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.43, -0.010, length * 1.02 - abs(toe) * length * 0.18), V(width * 0.30, 0.022, 0.026), None, 8, 5)
        return dog.furred(breed, b, breed.fur)
    return shapes


def jaw(breed):
    def shapes(b):
        rings = [(breed.skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.jaw_shape]
        b.tube(dome(rings[0], -Z, 0.012, 2)[::-1] + rings + dome(rings[-1], Z, 0.016, 3), 12)
        return dog.furred(breed, b, (0.003, 2, 700))
    return shapes


def ear_curve(breed, t, side):
    root, mid, end = breed.ear
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(at.x * side, at.y, at.z)


def ear_rings(breed):
    """(how far up, half width, half thickness): the lynx's tall and pointed, the panther's small and round."""
    if is_lynx(breed):
        return ((0.0, 0.026, 0.012), (0.12, 0.029, 0.009), (0.35, 0.025, 0.007), (0.58, 0.018, 0.006),
                (0.78, 0.011, 0.005), (0.92, 0.005, 0.004), (1.0, 0.002, 0.002))
    return ((0.0, 0.026, 0.012), (0.15, 0.030, 0.010), (0.40, 0.030, 0.008), (0.65, 0.025, 0.007),
            (0.85, 0.016, 0.006), (0.96, 0.008, 0.005), (1.0, 0.003, 0.003))


def ear_frame(side):
    """Across the ear, and the way its opening faces (forward and a little out)."""
    wide = V(side * 0.95, 0.0, -0.31).normalized()
    face = V(side * 0.31, 0.0, 0.95).normalized()
    return wide, face


def ears(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half, thick in ear_rings(breed):
                # (cupped: the back of the ear bowed out behind)
                cup = math.sin(math.pi * t) * 0.006
                rings.append((ear_curve(breed, t, side) - face * cup, wide * half, face * thick))
            b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings, 10)
            if breed.tuft > 0.0:
                # The lynx's tuft: a few long black hairs standing up off the tip
                tip = ear_curve(breed, 0.97, side)
                up = (ear_curve(breed, 1.0, side) - ear_curve(breed, 0.8, side)).normalized()
                for k, lean in enumerate((-0.12, 0.0, 0.12)):
                    end = tip + (up + wide * lean + Y * 0.3).normalized() * breed.tuft * (1.0 - 0.15 * abs(k - 1))
                    kit.spike(b, tip - up * 0.006, end, 0.0034, 5)
        dog.lay_fur(breed, b.bm, True)
    return shapes


def ear_linings(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half in ((0.08, 0.012), (0.2, 0.021), (0.38, 0.021), (0.58, 0.016), (0.76, 0.009), (0.9, 0.003)):
                rings.append((ear_curve(breed, t, side) + face * 0.0055, wide * half, face * 0.0035))
            b.tube(rings, 8)
    return shapes


def palate(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y, length * 0.40), V(width * 0.8, 0.006, length * 0.38), None, 8, 5)
    return shapes


def tongue(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y + 0.010, length * 0.42), V(width * 0.62, 0.006, length * 0.42), None, 8, 5)
    return shapes


def gums(breed):
    def shapes(b):
        # Along the upper teeth, under the lips: they show when it hisses
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            points = []
            for share in (0.96, 0.8, 0.62, 0.45):
                x = (back + (front - back) * share) * 0.85
                points.append(breed.skull + V(side * x, y + 0.008, length * share))
            b.strand(points, [0.004, 0.005, 0.005, 0.004], 6)
    return shapes


def fangs(breed):
    def shapes(b):
        # The upper teeth: six tiny ones across the front, a long dagger of a canine at each
        # corner, and the shearing cheek teeth behind
        y, length, front, back = breed.mouth
        long = 0.017 if is_lynx(breed) else 0.023
        for side in (1.0, -1.0):
            for k in (0.25, 0.55, 0.85):
                base = breed.skull + V(side * front * 0.55 * k, y + 0.005, length * (1.0 - 0.02 * k))
                kit.spike(b, base, base - Y * 0.006, 0.0024, 5)
            base = breed.skull + V(side * front * 0.92, y + 0.006, length * 0.90)
            kit.spike(b, base, base - Y * long + V(0.0, 0.0, 0.002), 0.0052 if is_lynx(breed) else 0.0068, 6)
            for share, tall, radius in ((0.62, 0.010, 0.0045), (0.46, 0.012, 0.0052)):
                x = back + (front - back) * share
                base = breed.skull + V(side * x, y + 0.005, length * share)
                kit.spike(b, base, base - Y * tall, radius, 5)
    return shapes


def teeth(breed):
    def shapes(b):
        y, length, front, back = breed.mouth
        long = 0.013 if is_lynx(breed) else 0.017
        for side in (1.0, -1.0):
            for k in (0.3, 0.7):
                base = breed.skull + V(side * front * 0.45 * k, y + 0.004, length * 0.95)
                kit.spike(b, base, base + Y * 0.006, 0.0022, 5)
            base = breed.skull + V(side * front * 0.78, y + 0.004, length * 0.86)
            kit.spike(b, base, base + Y * long, 0.0048 if is_lynx(breed) else 0.006, 6)
            base = breed.skull + V(side * (back + (front - back) * 0.5) * 0.82, y + 0.004, length * 0.5)
            kit.spike(b, base, base + Y * 0.010, 0.0048, 5)
    return shapes


def eyes(breed):
    def shapes(b):
        at, radius = breed.eye
        for side in (1.0, -1.0):
            # (a cat's eyes look forward: only a little out to the side)
            b.ellipsoid(breed.skull + V(side * at.x, at.y, at.z), V(radius * 0.86, radius * 0.72, radius), Matrix.Rotation(-side * 0.22, 3, "Y"), 10, 6)
    return shapes


def nose(breed):
    def shapes(b):
        at, size = breed.nose
        b.ellipsoid(breed.skull + at, size, None, 10, 6)
    return shapes


def whiskers(breed):
    """Long stiff whiskers from the pads, fanned out and back."""
    def shapes(b):
        reach = breed.whiskers
        for side in (1.0, -1.0):
            pad = breed.skull + V(side * (breed.pad.x + 0.012), breed.pad.y + 0.002, breed.pad.z - 0.004)
            for k in range(4 if not kit.LOW else 2):
                drop = (k - 1.5) * 0.25
                out = V(side * 0.85, -0.05 + drop * 0.35, -0.45 + abs(drop) * 0.2).normalized()
                start = pad + V(0.0, drop * 0.012, 0.0)
                kit.spike(b, start, start + out * reach * (1.0 - 0.12 * abs(k - 1.5)), 0.0011, 4)
    return shapes


def parts(breed):
    # (name, material index, shapes, fuse): the coat and the jaw fuse themselves
    return [
        ("coat", 0, coat(breed), None), ("jaw", 0, jaw(breed), None), ("ears", 0, ears(breed), None),
        ("palate", 1, palate(breed), None), ("tongue", 1, tongue(breed), None), ("gums", 1, gums(breed), None),
        ("fangs", 1, fangs(breed), None), ("teeth", 1, teeth(breed), None), ("eyes", 1, eyes(breed), None),
        ("linings", 1, ear_linings(breed), None), ("nose", 1, nose(breed), None), ("whiskers", 1, whiskers(breed), None),
    ]


# --- The skeleton and the skin's weights ---

def bones(breed):
    listed = _dog_bones(breed)
    # (the lips are the whisker pads and the upper lip under them, over the fangs)
    for i, (name, at, parent) in enumerate(listed):
        if name in ("lip_l", "lip_r"):
            side = 1.0 if name == "lip_l" else -1.0
            listed[i] = (name, breed.skull + V(side * breed.pad.x, breed.pad.y - 0.006, breed.pad.z - 0.01), parent)
    return listed


def weights(breed):
    weigh = _dog_weights(breed)
    pad = breed.pad
    mouth_y = breed.mouth[0]

    def lips(p, made):
        # The whisker pads and the upper lip hang from bones of their own, so that it can draw
        # them up off its fangs to hiss
        q = p - breed.skull
        head = made.get("head", 0.0)
        if head <= 0.0 or q.z < pad.z - 0.05:
            return made
        lip = blend(pad.z - 0.05, pad.z - 0.025, q.z) * blend(pad.y + 0.022, pad.y + 0.008, q.y) \
            * blend(mouth_y - 0.014, mouth_y - 0.004, q.y) * blend(0.003, 0.012, abs(q.x))
        if lip > 0.0:
            made["head"] = head * (1.0 - lip)
            made["lip_l" if q.x >= 0.0 else "lip_r"] = head * lip
        return made

    def cat_weigh(part, p):
        if part == "whiskers":
            return lips(p, {"head": 1.0})
        if part == "gums":
            return lips(p + V(0.0, -0.008, 0.0), {"head": 1.0})
        made = weigh(part, p)
        if "lip_l" in made or "lip_r" in made:
            # (put back as the dog's lips were, and weighed again as a cat's)
            made["head"] = made.get("head", 0.0) + made.pop("lip_l", 0.0) + made.pop("lip_r", 0.0)
        if part == "coat" and made.get("head", 0.0) > 0.0:
            made = lips(p, made)
        return made
    return cat_weigh


def leg_share(breed, p):
    """Which leg a point is nearest, and how much of it hangs from that leg rather than the trunk
    (as the dog's, for a cat's thicker legs)."""
    suffix = ("_f" if p.z > breed.body.z + (breed.fore[0].z + breed.hind[0].z) * 0.5 else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = breed.legs[suffix]
    top = joints[0]
    off = dog.chain_param(V(top.x, p.y, p.z), joints)[0]
    thick = 1.25 if breed.kind == "panther" else 1.1
    return suffix, blend(top.y + 0.03, top.y - 0.10, p.y) * blend(0.075 * thick, 0.045 * thick, math.hypot(p.x - top.x, off / 1.8))


# --- The colours painted into the coat ---

MATERIALS = [("coat", (0.40, 0.355, 0.30)), ("parts", (1.0, 1.0, 1.0))]
COLOURS = {
    "lynx": {
        "palate": (0.42, 0.20, 0.22, 0.5), "tongue": (0.62, 0.32, 0.34, 0.6), "gums": (0.40, 0.20, 0.22, 0.6),
        "fangs": (0.88, 0.85, 0.74, 0.4), "teeth": (0.88, 0.85, 0.74, 0.4), "eyes": (0.78, 0.62, 0.26, 1.0),
        "linings": (0.62, 0.58, 0.52, 0.0), "nose": (0.30, 0.22, 0.21, 0.7), "whiskers": (0.86, 0.85, 0.80, 0.0),
    },
    "panther": {
        "palate": (0.30, 0.10, 0.12, 0.5), "tongue": (0.52, 0.22, 0.25, 0.6), "gums": (0.10, 0.06, 0.06, 0.6),
        "fangs": (0.86, 0.83, 0.72, 0.4), "teeth": (0.86, 0.83, 0.72, 0.4), "eyes": (0.56, 0.62, 0.22, 1.0),
        "linings": (0.06, 0.055, 0.05, 0.0), "nose": (0.03, 0.028, 0.028, 0.7), "whiskers": (0.70, 0.70, 0.68, 0.0),
    },
}
COAT_COLOURS = {"lynx": (0.40, 0.355, 0.30), "panther": (0.050, 0.046, 0.044)}


def spots_solid(strength):
    return 0.5 * min(max(strength, 0.0), 1.0)


def spots_rosette(strength):
    return 0.5 + 0.5 * min(max(strength, 0.0), 1.0)


def markings(breed, p, normal):
    """(dark, pale, spots) at a point of the coat, each 0..1 (spots as the alpha says: see the top)."""
    s = breed.skull
    q = p - s
    up = normal.y
    y, rx, ry = dog.trunk_at(breed, p.z)
    lynx_ = is_lynx(breed)
    on_head = p.z > breed.neck.z + 0.06 and p.y > breed.neck.y + 0.03
    off, along = dog.chain_param(p, breed.tail)
    tail = p.z < breed.tail[0].z + 0.02 and off < 0.07
    if tail:
        if lynx_:
            # The bob: black at the end, spotted above, pale under
            tip = blend(2.2, 3.2, along)
            return tip, 0.6 * blend(0.1, -0.7, up) * (1.0 - tip), spots_solid(0.6 * (1.0 - tip))
        # (rings of rosettes down the tail, joining into bands near its end)
        return 0.0, 0.0, spots_rosette(0.9)
    if on_head:
        if lynx_:
            lower = blend(-0.016, -0.034, q.y) if q.z > 0.02 else 0.0
            chin = blend(-0.03, -0.05, q.y)
            # (white rings round the eyes)
            eye = breed.eye[0]
            ring_at = (Vector((abs(q.x), q.y, q.z)) - eye).length
            ring = math.exp(-((ring_at - 0.016) / 0.006) ** 2)
            # The ruff: barred dark in two lines across it
            cheek = blend(0.035, 0.055, abs(q.x)) * blend(0.01, -0.02, q.y) * blend(0.03, -0.01, q.z)
            bars = cheek * (0.5 + 0.5 * math.cos((q.y + q.z * 0.5) * 140.0)) * 0.8
            # (a dark line from the inner corner of each eye up over the brow, and spots on the crown)
            brow = blend(0.025, 0.04, q.y) * math.exp(-((abs(q.x) - 0.016) / 0.008) ** 2) * blend(0.06, 0.02, q.z) * 0.6
            pale = max(lower, chin, ring * 0.9, blend(0.04, 0.09, q.z) * blend(-0.015, -0.035, q.y))
            return max(bars, brow), min(pale, 1.0), spots_solid(0.5 * blend(0.03, 0.05, q.y) * blend(0.06, 0.0, q.z))
        # The panther's face: solid spots small on the head, none on the muzzle
        return 0.0, 0.25 * blend(-0.03, -0.05, q.y), spots_solid(0.7 * blend(0.08, 0.04, q.z))
    belly = blend(y - ry * 0.25, y - ry * 0.9, p.y)
    throat = blend(breed.neck.z - 0.08, breed.neck.z + 0.05, p.z) * blend(breed.neck.y + 0.02, breed.neck.y - 0.08, p.y)
    suffix, leg = leg_share(breed, p)
    inner = leg * blend(0.2, -0.6, normal.x * (1.0 if p.x >= 0.0 else -1.0)) * blend(0.5, 0.2, p.y)
    if lynx_:
        pale = max(belly, throat, inner * 0.8)
        # Spots: strongest on the legs and the lower flanks, fainter along the back
        flank = blend(0.9, 0.2, up)
        spots = max(0.55 + 0.45 * flank, leg) * (1.0 - 0.6 * belly)
        # (the backs of the forelegs barred dark near the top)
        return 0.0, pale, spots_solid(spots)
    pale = 0.25 * max(belly, throat)
    # Rosettes on the body, solid spots down the legs and on the belly
    if leg > 0.5 or belly > 0.6:
        return 0.0, pale, spots_solid(0.85)
    return 0.0, pale, spots_rosette(0.95)


def paint(breed, whole, part_of):
    """Vertex colours. On the coat: red, how open the surface is (low in
    grooves and creases); green, how dark its markings are; blue, how pale;
    alpha, its spots. On the other parts, their colours."""
    colours = COLOURS[breed.kind]
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred = [part in ("coat", "jaw", "ears") for part in part_of]
    across_uv = {}
    open_ = [1.0] * len(whole.verts)
    for vert in whole.verts:
        if not furred[vert.index] or not vert.link_edges:
            continue
        rise = 0.0
        for edge in vert.link_edges:
            other = edge.other_vert(vert)
            step = other.co - vert.co
            if step.length > 1e-6:
                rise += step.dot(vert.normal) / step.length
        open_[vert.index] = rise / len(vert.link_edges)
    for _ in range(3):
        spread = list(open_)
        for vert in whole.verts:
            if furred[vert.index] and vert.link_edges:
                around = [open_[e.other_vert(vert).index] for e in vert.link_edges]
                spread[vert.index] = 0.5 * open_[vert.index] + 0.5 * sum(around) / len(around)
        open_ = spread
    measured = sorted(open_[i] for i in range(len(open_)) if furred[i])
    middle = measured[len(measured) // 2] if measured else 0.0
    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part in colours:
            vert[layer] = colours[part]
            if part == "eyes":
                side = 1.0 if p.x >= 0.0 else -1.0
                at, radius = breed.eye
                centre = breed.skull + V(side * at.x, at.y, at.z)
                local = Matrix.Rotation(side * 0.22, 3, "Y").inverted() @ (p - centre)
                across_uv[vert.index] = (0.5 + local.x / (radius * 0.86) * 0.4, 0.5 + local.y / (radius * 0.72) * 0.4) if local.z > 0.0 else (0.95, 0.95)
            continue
        normal = kit.from_blender(vert.normal)
        shade = min(max(1.0 - (open_[vert.index] - middle) * 6.0, 0.0), 1.0)
        if part == "jaw":
            dark, pale, spots = 0.0, 1.0 if is_lynx(breed) else 0.2, 0.0
        elif part == "ears":
            root = breed.ear[0]
            up = (p.y - root.y) / max(breed.ear[2].y - root.y, 0.01)
            if is_lynx(breed):
                # Black on the back of the ear, the tuft black; the front of it pale
                front = blend(-0.2, 0.4, normal.dot(ear_frame(1.0 if p.x >= 0.0 else -1.0)[1]))
                dark = max(0.85 * (1.0 - front), blend(0.95, 1.05, up))
                pale = 0.6 * front * (1.0 - blend(0.9, 1.0, up))
                dark, pale, spots = min(dark, 1.0), pale, 0.0
            else:
                dark, pale, spots = 0.0, 0.0, 0.0
        else:
            dark, pale, spots = markings(breed, p, normal)
        vert[layer] = (shade, dark, pale, spots)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))


def export(breed, preview):
    global MATERIALS
    MATERIALS = [("coat", COAT_COLOURS[breed.kind]), ("parts", (1.0, 1.0, 1.0))]
    dog.MATERIALS = MATERIALS
    dog.export(breed, preview)


def render(folder, name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    big = 1.9 if name.startswith("panther") else 1.45
    head = (0.0, -0.62, 0.70) if name.startswith("panther") else (0.0, -0.50, 0.78)
    # (view, direction to the camera in Blender space, what it looks at, how much it frames, colours)
    views = [("side", (1, 0, 0), (0.0, -0.05, 0.45), big, "MATERIAL"), ("quarter", (0.7, -0.7, 0.2), (0.0, -0.05, 0.45), big, "MATERIAL"),
             ("front", (0.05, -1, 0.1), (0.0, -0.3, 0.45), 0.9, "MATERIAL"), ("face", (0.55, -0.8, 0.15), head, 0.34, "MATERIAL"),
             ("face_front", (0.0, -1, 0.1), head, 0.34, "MATERIAL"), ("top", (0.2, 0.1, 1), (0.0, -0.05, 0.5), big, "MATERIAL"),
             ("shade", (0.8, -0.5, 0.2), (0.0, -0.05, 0.45), big, "VERTEX")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


dog.parts = parts
dog.paint = paint
dog.bones = bones
dog.weights = weights
dog.leg_share = leg_share
dog.render = render


if __name__ == "__main__":
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        for breed in CATS:
            export(breed, preview)
