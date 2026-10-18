"""Builds the coyotes (creatures/coyote) and exports them for Godot.

Run from the game's root (it needs tools/build_dog.py, which needs the character
controller's tools/build_character.py):
    blender --background --python creatures/coyote/tools/build_coyote.py
    blender --background --python creatures/coyote/tools/build_coyote.py -- <preview folder> coyote_a

Writes creatures/coyote/models/coyote_a.glb and coyote_b.glb, and a demade
`_lo` version of each (and, with a preview folder, an editable .blend and
pictures there).

A coyote: lean and rangy, long in the leg, with a deep narrow chest, small
neat feet, a ruff of thick fur round the neck and cheeks, a narrow head with a
long pointed muzzle, big upright pointed ears, and a bushy tail carried low.
Its coat is grizzled grey and tan (the guard hairs banded, some tipped black:
see coyote_look.gd), darker along the back, tawny on the legs, the backs of
the ears and the muzzle, cream under the jaw, down the throat and chest and
under the belly, with a dark line down the front of each foreleg and a black
tip to the tail. `coyote_a` is the greyer, `coyote_b` redder and slighter, with
a notch out of one ear.

It is built on the dog's skeleton and with the dog's tools (tools/build_dog.py,
GameCommon's godot/dog): the same bones and names, so DogRig (CoyoteRig) moves
it. What is a coyote's own is here: its shape (`coat`, `ears`), and the colours
painted into its coat (`paint`): red how open the surface is (dark in creases),
green how dark its markings are, blue how pale (the cream underside), and alpha
how tawny.

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
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
import build_dog as dog  # noqa: E402  (the dog's build: its skeleton, weights, fur and export)
import build_character as kit  # noqa: E402

X, Y, Z = kit.X, kit.Y, kit.Z
V = dog.V
blend = kit.blend
dome = kit.dome
dog.OUT = os.path.join(COMPONENT, "models")


def coyote(name, notched, ruddy):
    breed = dog.Breed(
        name=name,
        # (no ear is cut; which one has a notch out of it, if any)
        cropped=0.0,
        notched=notched,
        ruddy=ruddy,
        scars=-1,
        body=V(0.0, 0.60, 0.0), chest=V(0.0, 0.62, 0.19), pelvis=V(0.0, 0.62, -0.21),
        # (along the body, centre height, half width, half height): deep and narrow at the
        # chest, the belly drawn up behind it into a slim loin, a level back
        trunk=[(-0.35, 0.655, 0.040, 0.050), (-0.30, 0.650, 0.062, 0.074), (-0.21, 0.642, 0.069, 0.084),
               (-0.11, 0.652, 0.055, 0.068), (-0.02, 0.636, 0.061, 0.090), (0.07, 0.606, 0.070, 0.126),
               (0.16, 0.588, 0.076, 0.150), (0.25, 0.598, 0.074, 0.138), (0.31, 0.624, 0.063, 0.104),
               (0.355, 0.650, 0.049, 0.072)],
        # Shoulder, elbow, wrist, paw; hip, stifle, hock, paw (the left legs). Long legs.
        fore=[V(0.066, 0.570, 0.262), V(0.066, 0.410, 0.200), V(0.064, 0.160, 0.214), V(0.064, 0.030, 0.232)],
        hind=[V(0.062, 0.590, -0.255), V(0.062, 0.410, -0.155), V(0.060, 0.190, -0.345), V(0.060, 0.030, -0.338)],
        # (how far down the leg, counted in joints; half width; half depth; forward offset): slender
        fore_shape=[(-0.3, 0.032, 0.054, 0.0), (0.0, 0.035, 0.060, 0.0), (0.5, 0.032, 0.048, 0.0), (1.0, 0.027, 0.038, -0.004),
                    (1.25, 0.025, 0.033, 0.0), (1.6, 0.022, 0.026, 0.0), (2.0, 0.021, 0.024, 0.0), (2.5, 0.020, 0.023, 0.0),
                    (3.0, 0.022, 0.024, 0.003)],
        hind_shape=[(-0.25, 0.034, 0.072, 0.0), (0.0, 0.040, 0.090, 0.0), (0.45, 0.038, 0.078, 0.0), (0.85, 0.030, 0.050, 0.004),
                    (1.0, 0.027, 0.042, 0.004), (1.3, 0.024, 0.037, -0.004), (1.7, 0.019, 0.026, 0.0), (2.0, 0.019, 0.026, -0.003),
                    (2.3, 0.017, 0.022, 0.0), (2.7, 0.017, 0.021, 0.0), (3.0, 0.020, 0.023, 0.003)],
        paw=(0.024, 0.040),
        muscle=0.72,
        # The neck carried low and forward, thick with its ruff
        neck=V(0.0, 0.665, 0.300), head=V(0.0, 0.790, 0.462),
        neck_shape=[(-0.3, 0.086, 0.0), (0.0, 0.084, 0.012), (0.35, 0.077, 0.016), (0.7, 0.066, 0.012), (1.0, 0.055, 0.0), (1.15, 0.046, 0.0)],
        skull_at=V(0.0, 0.022, 0.030), skull_size=V(0.052, 0.049, 0.068),
        # (along the muzzle from the skull, height, half width, half height): long, narrow, pointed
        muzzle=[(0.030, -0.004, 0.041, 0.041), (0.068, -0.010, 0.033, 0.033), (0.106, -0.015, 0.026, 0.027),
                (0.140, -0.019, 0.020, 0.022), (0.166, -0.021, 0.015, 0.017)],
        nose=(V(0.0, -0.013, 0.178), V(0.0125, 0.0105, 0.010)),
        jaw_at=V(0.0, -0.030, 0.000),
        jaw_shape=[(-0.01, -0.040, 0.034, 0.016), (0.06, -0.045, 0.026, 0.012), (0.12, -0.047, 0.018, 0.010), (0.158, -0.045, 0.012, 0.007)],
        mouth=(-0.040, 0.160, 0.012, 0.024),
        eye=(V(0.031, 0.014, 0.050), 0.0098),
        # Each ear: where it roots, the joint part way up it, and its tip. Big, pointed, upright.
        ear_at=[V(0.030, 0.040, -0.008), V(0.046, 0.092, -0.020), V(0.056, 0.146, -0.030)],
        tail_root=V(0.0, 0.640, -0.352),
        # (hanging low behind its hocks, its end lifted a little)
        tail_at=[(0.0, 0.0, 0.0), (0.0, -0.10, -0.055), (0.0, -0.21, -0.085), (0.0, -0.315, -0.095), (0.0, -0.405, -0.080)],
        tail_shape=[0.018, 0.032, 0.044, 0.048, 0.041, 0.020],
    )
    if ruddy:
        # (slighter: a narrower head and chest, bigger ears)
        breed.skull_size = V(0.050, 0.048, 0.067)
        breed.trunk = [(z, y, rx * 0.95, ry * 0.97) for z, y, rx, ry in breed.trunk]
        breed.ear_at = [V(0.030, 0.040, -0.008), V(0.047, 0.102, -0.020), V(0.058, 0.166, -0.030)]
        breed.ear = [breed.skull + offset for offset in breed.ear_at]
    return breed


COYOTES = [coyote("coyote_a", 0.0, False), coyote("coyote_b", 1.0, True)]


def coat(breed):
    def shapes(b):
        low = kit.LOW
        m = breed.muscle
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.04)[::-1] + rings + dome(rings[-1], Z, 0.04), 18)
        # Withers, the point of the chest, and the muscle over each shoulder and haunch
        top = breed.trunk[6][1] + breed.trunk[6][3]
        b.ellipsoid(V(0.0, top - 0.022, 0.19), V(0.036 * m, 0.026, 0.095))
        b.ellipsoid(V(0.0, breed.fore[0].y + 0.005, 0.322), V(0.048 * m, 0.064, 0.048))
        for side in (1.0, -1.0):
            arm = breed.fore[0].lerp(breed.fore[1], 0.3)
            b.ellipsoid(V(side * (arm.x + 0.004), arm.y + 0.045, arm.z - 0.012), V(0.030 * m, 0.082, 0.060 * m), Matrix.Rotation(0.40, 3, "X"))
            thigh = breed.hind[0].lerp(breed.hind[1], 0.3)
            b.ellipsoid(V(side * thigh.x, thigh.y + 0.02, thigh.z + 0.01), V(0.040 * m, 0.108, 0.088 * m), Matrix.Rotation(-0.45, 3, "X"))

        # Neck, rising forward out of the chest, its ruff thick round it
        base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top, t) - across * sag, X * r, across * (r * 1.2)) for t, r, sag in breed.neck_shape], 14)
        # The ruff: the thick fur of the throat and the mane over the shoulders
        b.ellipsoid(base.lerp(top, 0.4) - across * 0.035, V(0.058, 0.06, 0.06), Matrix.Rotation(-0.6, 3, "X"))
        b.ellipsoid(base.lerp(top, 0.2) + across * 0.035, V(0.056, 0.045, 0.075), Matrix.Rotation(-0.5, 3, "X"))

        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        # A narrow head: a rounded brow, a shallow stop, the cheeks fluffed out behind the jaw
        b.ellipsoid(skull + V(0.0, size.y * 0.5, size.z * 0.35), V(size.x * 0.78, size.y * 0.42, size.z * 0.5))
        for side in (1.0, -1.0):
            b.ellipsoid(skull + V(side * 0.026, 0.028, 0.050), V(0.016, 0.008, 0.016), Matrix.Rotation(0.3, 3, "X"))  # brow
            b.ellipsoid(skull + V(side * 0.036, -0.03, -0.022), V(0.02, 0.03, 0.036), Matrix.Rotation(0.5, 3, "X"))  # the cheek ruff
            b.ellipsoid(skull + V(side * 0.036, -0.012, 0.030), V(0.014, 0.020, 0.030), Matrix.Rotation(0.3, 3, "X"))  # cheekbone
        b.ellipsoid(skull + V(0.0, 0.036, -0.040), V(0.020, 0.022, 0.032))  # the back of the skull
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull, X * size.x * 0.8, Y * size.y * 0.8)] + muzzle + dome(muzzle[-1], Z, muzzle[-1][1].x * 0.55, 3), 14)
        for side in (1.0, -1.0):
            # Tight lips along the jaw: the rig still draws them back to snarl
            b.ellipsoid(skull + V(side * 0.014, -0.034, 0.112), V(0.0065, 0.010, 0.045), None, 8, 5)
            b.ellipsoid(skull + V(side * 0.024, -0.032, 0.062), V(0.008, 0.012, 0.032), None, 8, 5)

        # The brush: thick, carried low
        b.strand([breed.tail_root + V(0.0, 0.03, 0.05)] + breed.tail, breed.tail_shape, 12)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            dog.limb(b, joints, breed.fore_shape if fore else breed.hind_shape)
            width, length = breed.paw
            paw = joints[3]
            if not low:
                knob = joints[1] + V(0.0, 0.012, -0.024) if fore else joints[2] + V(0.0, 0.018, -0.018)
                b.ellipsoid(knob, V(width * 0.6, 0.022, 0.018), None, 8, 5)
            # Small neat oval feet, the two middle toes ahead of the others
            b.ellipsoid(paw + V(0.0, -0.008, length * 0.5), V(width, 0.022, length), None, 10, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.40, -0.014, length * 1.24 - abs(toe) * length * 0.2), V(width * 0.26, 0.015, 0.02), None, 8, 5)
        return dog.furred(breed, b, (0.0036, 4, 14000))
    return shapes


def ear_curve(breed, t, side):
    root, mid, end = breed.ear
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(at.x * side, at.y, at.z)


# (how far up, half width, half thickness): broad at the root, coming to a point
EAR_RINGS = ((0.0, 0.031, 0.013), (0.10, 0.035, 0.010), (0.30, 0.031, 0.008), (0.52, 0.023, 0.006),
             (0.72, 0.015, 0.005), (0.88, 0.007, 0.004), (1.0, 0.0015, 0.0015))


def ear_frame(side):
    """Across the ear, and the way its opening faces (forward and a little out)."""
    wide = V(side * 0.97, 0.0, -0.25).normalized()
    face = V(side * 0.25, 0.0, 0.97).normalized()
    return wide, face


def ears(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half, thick in EAR_RINGS:
                # (cupped: the back of the ear bowed out behind)
                cup = math.sin(math.pi * t) * 0.006
                if side == breed.notched and 0.45 < t < 0.6:
                    half *= 0.7
                rings.append((ear_curve(breed, t, side) - face * cup, wide * half, face * thick))
            b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings, 10)
        dog.lay_fur(breed, b.bm, True)
    return shapes


def ear_linings(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half in ((0.08, 0.012), (0.2, 0.024), (0.38, 0.023), (0.58, 0.016), (0.76, 0.009), (0.9, 0.003)):
                rings.append((ear_curve(breed, t, side) + face * 0.0055, wide * half, face * 0.0035))
            b.tube(rings, 8)
    return shapes


def gums(breed):
    def shapes(b):
        # Along the upper teeth, under the tight lips: they show only when it snarls
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            points = []
            for share in (0.96, 0.82, 0.66, 0.5, 0.36):
                x = (back + (front - back) * share) * 0.78
                points.append(breed.skull + V(side * x, y + 0.009, length * share))
            b.strand(points, [0.0035, 0.0045, 0.0045, 0.004, 0.0035], 6)
    return shapes


def parts(breed):
    # (name, material index, shapes, fuse): the coat and the jaw fuse themselves
    return [
        ("coat", 0, coat(breed), None), ("jaw", 0, dog.jaw(breed), None), ("ears", 0, ears(breed), None),
        ("crest", 1, dog.crest(breed), None), ("palate", 2, dog.palate(breed), None), ("tongue", 2, dog.tongue(breed), None),
        ("gums", 2, gums(breed), None), ("fangs", 2, dog.fangs(breed), None), ("teeth", 2, dog.teeth(breed), None),
        ("eyes", 2, dog.eyes(breed), None), ("linings", 2, ear_linings(breed), None), ("nose", 2, dog.nose(breed), None),
    ]


MATERIALS = [("coat", (0.37, 0.325, 0.27)), ("crest", (0.20, 0.18, 0.15)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "palate": (0.36, 0.12, 0.13, 0.5), "tongue": (0.55, 0.22, 0.24, 0.6), "gums": (0.20, 0.10, 0.10, 0.6),
    "fangs": (0.86, 0.82, 0.70, 0.4), "teeth": (0.86, 0.82, 0.70, 0.4), "eyes": (0.86, 0.66, 0.22, 1.0),
    "linings": (0.52, 0.47, 0.42, 0.0), "nose": (0.03, 0.025, 0.025, 0.7),
}


def markings(breed, p, normal):
    """(dark, pale, tawny) at a point of the coat, 0..1 each."""
    s = breed.skull
    q = p - s
    up = normal.y
    y, rx, ry = dog.trunk_at(breed, p.z)
    on_head = p.z > breed.neck.z + 0.08 and p.y > breed.neck.y + 0.04
    # The tail: grizzled above, a dark spot near the root (the scent gland), black at the end
    off, along = dog.chain_param(p, breed.tail)
    tail = p.z < breed.tail[0].z + 0.02 and off < 0.065
    dark = pale = tawny = 0.0
    if tail:
        tip = blend(3.0, 3.55, along)
        gland = math.exp(-((along - 0.45) / 0.25) ** 2) * blend(0.0, 0.6, up)
        dark = max(tip, 0.55 * gland, 0.25 * blend(-0.2, 0.7, up))
        pale = 0.55 * blend(0.1, -0.7, up) * (1.0 - tip)
        return dark, pale, 0.2 * (1.0 - tip)
    if on_head:
        # Cream on the lips, chin and throat and the cheeks below the eye; tawny
        # along the muzzle and behind the ears; grizzled on the crown.
        lower = blend(-0.012, -0.032, q.y) if q.z > 0.0 else blend(-0.02, -0.05, q.y)
        cheek = blend(-0.005, -0.03, q.y) * blend(0.02, 0.045, abs(q.x)) * blend(0.07, 0.0, q.z)
        pale = max(lower, cheek * 0.9)
        tawny = blend(0.02, 0.09, q.z) * blend(-0.03, 0.0, q.y) * 0.8 + blend(0.0, -0.03, q.z) * blend(0.0, 0.04, q.y) * 0.6
        # (a dark line round each eye, grizzle on the bridge of the nose)
        eye = breed.eye[0]
        ring = math.exp(-((Vector((abs(q.x), q.y, q.z)) - eye).length / 0.016) ** 2)
        dark = max(0.45 * ring, 0.2 * blend(0.06, 0.12, q.z) * blend(0.0, 0.02, q.y))
        return dark, pale, min(tawny, 1.0)
    # The body
    belly = blend(y - ry * 0.2, y - ry * 0.9, p.y) * blend(0.38, 0.30, p.z) * blend(-0.30, -0.18, p.z)
    throat = blend(breed.neck.z - 0.08, breed.neck.z + 0.05, p.z) * blend(breed.neck.y + 0.04, breed.neck.y - 0.08, p.y)
    chest = blend(0.2, 0.36, p.z) * blend(0.62, 0.5, p.y) * blend(0.05, 0.02, abs(p.x))
    suffix, leg = dog.leg_share(breed, p)
    inner = leg * blend(0.2, -0.6, normal.x * (1.0 if p.x >= 0.0 else -1.0)) * blend(0.5, 0.25, p.y)
    pale = max(belly, throat, chest * 0.85, inner * 0.45)
    # Darker down the back (a saddle of black-tipped guard hairs), grizzled along the top of the neck
    saddle = blend(0.25, 0.85, up) * blend(-0.36, -0.25, p.z) * blend(0.32, 0.12, p.z) * (1.0 - leg)
    nape = blend(0.3, 0.9, up) * blend(breed.neck.z - 0.04, breed.neck.z + 0.1, p.z) * (1.0 - leg)
    # A dark line down the front of each foreleg
    stripe = 0.0
    if suffix[1] == "f" and p.y < breed.fore[1].y + 0.04 and p.y > breed.fore[3].y + 0.03:
        stripe = leg * blend(0.2, 0.75, normal.z) * blend(breed.fore[3].y + 0.03, breed.fore[3].y + 0.08, p.y)
    dark = max(0.55 * saddle, 0.35 * nape, 0.7 * stripe)
    # Tawny legs, and the flanks a little warmer than the back
    tawny = max(leg * blend(0.58, 0.32, p.y), 0.35 * blend(0.6, -0.2, up) * (1.0 - leg))
    return dark, pale * (1.0 - stripe), tawny


def paint(breed, whole, part_of):
    """Vertex colours. On the coat: red, how open the surface is (low in
    grooves and creases); green, how dark its markings are; blue, how pale;
    alpha, how tawny. On the other parts, their colours (see PART_COLOURS)."""
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred = [part in ("coat", "jaw", "ears") for part in part_of]
    crest_first = part_of.index("crest")
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
        if part == "crest":
            spike = (vert.index - crest_first) // (18 if kit.LOW else 22)
            vert[layer] = (1.0, 1.0, 1.0, (math.sin(spike * 12.9898) * 43758.5453) % 1.0)
            continue
        if part in PART_COLOURS:
            vert[layer] = PART_COLOURS[part]
            if part == "eyes":
                side = 1.0 if p.x >= 0.0 else -1.0
                at, radius = breed.eye
                centre = breed.skull + V(side * at.x, at.y, at.z)
                local = Matrix.Rotation(side * 0.5, 3, "Y").inverted() @ (p - centre)
                across_uv[vert.index] = (0.5 + local.x / (radius * 0.8) * 0.4, 0.5 + local.y / (radius * 0.62) * 0.4) if local.z > 0.0 else (0.95, 0.95)
            continue
        normal = kit.from_blender(vert.normal)
        shade = min(max(1.0 - (open_[vert.index] - middle) * 6.0, 0.0), 1.0)
        if part == "jaw":
            dark, pale, tawny = 0.0, 1.0, 0.0
        elif part == "ears":
            # Tawny on the back of the ear, the edges dark
            root = breed.ear[0]
            up = (p.y - root.y) / (breed.ear[2].y - root.y)
            dark, pale, tawny = 0.5 * blend(0.8, 1.0, up), 0.0, 0.9 * (1.0 - blend(0.75, 1.0, up))
        else:
            dark, pale, tawny = markings(breed, p, normal)
        if breed.ruddy:
            tawny = min(1.0, tawny * 1.3 + 0.15)
        vert[layer] = (shade, dark, pale, tawny)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))


def render(folder, name):
    dog.render(folder, name)


dog.parts = parts
dog.paint = paint
dog.MATERIALS = MATERIALS
dog.PART_COLOURS = PART_COLOURS


if __name__ == "__main__":
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        for breed in COYOTES:
            dog.export(breed, preview)
