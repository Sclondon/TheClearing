"""Builds the grey wolves (creatures/wolf) and exports them for Godot.

Run from the game's root (it needs tools/build_dog.py, which needs the character
controller's tools/build_character.py):
    blender --background --python creatures/wolf/tools/build_wolf.py
    blender --background --python creatures/wolf/tools/build_wolf.py -- <preview folder> wolf_a

Writes creatures/wolf/models/wolf_a.glb and wolf_b.glb, and a demade `_lo`
version of each (and, with a preview folder, an editable .blend and pictures
there).

A grey wolf (Canis lupus): big and long-legged, the chest deep and narrow as a
keel (the elbows tucked in to it, so that it runs on one line), a long level
back, big feet, a thick neck in a mane of long fur that goes on over the
shoulders, a broad head made broader by the ruff of its cheeks, a long, deep,
blunt muzzle with a big black nose, shortish thick ears with rounded tips, small
amber eyes set slanting, and a straight bushy tail that hangs to its hocks. Its
coat is grizzled grey (each guard hair banded, many tipped black: see
wolf_look.gd), a dark saddle over its back and down its tail, black at the tip
of the tail and on the scent gland near its root; buff on its legs and the backs
of its ears; and pale cream about its face (the mask: the lips, the sides of the
muzzle, the cheeks, a spot over each eye), down the throat and chest, under the
belly and inside the legs. `wolf_a` is the greyer and slighter (a she-wolf);
`wolf_b` darker, heavier in the head and neck (a big male), with a notch out of
one ear.

It is built on the dog's skeleton and with the dog's tools (tools/build_dog.py,
GameCommon's godot/dog): the same bones and names, so DogRig (WolfRig) moves
it. What is a wolf's own is here: its shape (`coat`, `ears`), and the colours
painted into its coat (`paint`): red how open the surface is (dark in creases),
green how dark its markings are, blue how pale (the cream mask and underside),
and alpha how buff.

It is modelled small (about two thirds of a metre at the withers) and drawn half
as big again (WolfRig, Wolf): the dog's gaits are worked out at the size of the
model, and a wolf so drawn trots where it would otherwise break into a gallop.

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

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


def wolf(name, notched, big):
    breed = dog.Breed(
        name=name,
        cropped=0.0,
        # (which ear has a notch out of it, if any)
        notched=notched,
        big=big,
        scars=-1,
        body=V(0.0, 0.54, 0.0), chest=V(0.0, 0.555, 0.17), pelvis=V(0.0, 0.555, -0.19),
        # (along the body, centre height, half width, half height): a chest deep and narrow as a
        # keel, the belly drawn up behind it, a long back, the withers a little over the croup
        trunk=[(-0.33, 0.585, 0.040, 0.048), (-0.285, 0.582, 0.061, 0.072), (-0.20, 0.578, 0.067, 0.082),
               (-0.10, 0.586, 0.057, 0.066), (-0.02, 0.578, 0.061, 0.086), (0.06, 0.555, 0.066, 0.120),
               (0.14, 0.540, 0.069, 0.140), (0.22, 0.550, 0.067, 0.128), (0.28, 0.570, 0.060, 0.098),
               (0.325, 0.592, 0.048, 0.070)],
        # Shoulder, elbow, wrist, paw; hip, stifle, hock, paw (the left legs). Long legs, the
        # elbows in against the chest, the paws close together under it.
        fore=[V(0.056, 0.515, 0.235), V(0.052, 0.375, 0.190), V(0.050, 0.135, 0.198), V(0.050, 0.027, 0.214)],
        hind=[V(0.056, 0.530, -0.235), V(0.058, 0.370, -0.150), V(0.052, 0.165, -0.300), V(0.052, 0.027, -0.272)],
        # (how far down the leg, counted in joints; half width; half depth; forward offset)
        fore_shape=[(-0.3, 0.034, 0.056, 0.0), (0.0, 0.037, 0.062, 0.0), (0.5, 0.035, 0.052, 0.0), (1.0, 0.030, 0.042, -0.004),
                    (1.25, 0.028, 0.037, 0.0), (1.6, 0.025, 0.030, 0.0), (2.0, 0.023, 0.027, 0.0), (2.5, 0.023, 0.026, 0.0),
                    (3.0, 0.025, 0.028, 0.003)],
        hind_shape=[(-0.25, 0.036, 0.074, 0.0), (0.0, 0.042, 0.090, 0.0), (0.45, 0.040, 0.080, 0.0), (0.85, 0.032, 0.054, 0.004),
                    (1.0, 0.029, 0.045, 0.004), (1.3, 0.026, 0.040, -0.004), (1.7, 0.022, 0.029, 0.0), (2.0, 0.021, 0.028, -0.003),
                    (2.3, 0.020, 0.025, 0.0), (2.7, 0.020, 0.025, 0.0), (3.0, 0.023, 0.027, 0.003)],
        # Big feet
        paw=(0.031, 0.047),
        muscle=0.78,
        # The neck thick and carried low and forward, the head a little above the back
        neck=V(0.0, 0.595, 0.270), head=V(0.0, 0.705, 0.418),
        neck_shape=[(-0.3, 0.088, 0.0), (0.0, 0.086, 0.012), (0.35, 0.080, 0.016), (0.7, 0.070, 0.012), (1.0, 0.060, 0.0), (1.15, 0.050, 0.0)],
        skull_at=V(0.0, 0.020, 0.026), skull_size=V(0.060, 0.052, 0.070),
        # (along the muzzle from the skull, height, half width, half height): long, deep and blunt
        muzzle=[(0.030, -0.004, 0.045, 0.043), (0.070, -0.010, 0.039, 0.037), (0.108, -0.015, 0.034, 0.032),
                (0.140, -0.019, 0.029, 0.027), (0.164, -0.021, 0.024, 0.023)],
        nose=(V(0.0, -0.010, 0.176), V(0.0128, 0.0098, 0.0105)),
        jaw_at=V(0.0, -0.030, 0.000),
        jaw_shape=[(-0.01, -0.040, 0.038, 0.017), (0.06, -0.046, 0.032, 0.014), (0.12, -0.048, 0.025, 0.012), (0.158, -0.046, 0.018, 0.009)],
        mouth=(-0.040, 0.160, 0.015, 0.029),
        eye=(V(0.036, 0.016, 0.047), 0.0088),
        # Each ear: where it roots, the joint part way up it, and its tip. Shortish, set up and a little apart.
        ear_at=[V(0.033, 0.040, -0.014), V(0.044, 0.077, -0.024), V(0.049, 0.110, -0.031)],
        tail_root=V(0.0, 0.585, -0.325),
        # (hanging straight down behind it, to about its hocks; under 5 cm round, so that the
        # dog's weights give all of it to the tail bones: the fur shells make it bushy)
        tail_at=[(0.0, 0.0, 0.0), (0.0, -0.09, -0.045), (0.0, -0.19, -0.068), (0.0, -0.285, -0.078), (0.0, -0.36, -0.068)],
        tail_shape=[0.020, 0.034, 0.042, 0.044, 0.039, 0.022],
    )
    if big:
        # (a big male: a broader head, a heavier neck and chest)
        breed.skull_size = V(0.063, 0.054, 0.072)
        breed.neck_shape = [(t, r * 1.07, s) for t, r, s in breed.neck_shape]
        breed.trunk = [(z, y, rx * 1.05, ry * 1.02) for z, y, rx, ry in breed.trunk]
        breed.muzzle = [(z, y, rx * 1.05, ry * 1.04) for z, y, rx, ry in breed.muzzle]
    return breed


WOLVES = [wolf("wolf_a", 0.0, False), wolf("wolf_b", -1.0, True)]


def coat(breed):
    def shapes(b):
        low = kit.LOW
        m = breed.muscle
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.04)[::-1] + rings + dome(rings[-1], Z, 0.04), 18)
        # Withers (the mane stands over them), the point of the chest, and the muscle over each shoulder and haunch
        top = breed.trunk[6][1] + breed.trunk[6][3]
        b.ellipsoid(V(0.0, top - 0.016, 0.17), V(0.040 * m, 0.030, 0.105))
        b.ellipsoid(V(0.0, breed.fore[0].y + 0.004, 0.292), V(0.044 * m, 0.060, 0.044))
        for side in (1.0, -1.0):
            arm = breed.fore[0].lerp(breed.fore[1], 0.3)
            b.ellipsoid(V(side * (arm.x + 0.004), arm.y + 0.042, arm.z - 0.010), V(0.028 * m, 0.078, 0.056 * m), Matrix.Rotation(0.40, 3, "X"))
            thigh = breed.hind[0].lerp(breed.hind[1], 0.3)
            b.ellipsoid(V(side * thigh.x, thigh.y + 0.02, thigh.z + 0.01), V(0.038 * m, 0.100, 0.082 * m), Matrix.Rotation(-0.45, 3, "X"))

        # Neck, rising forward out of the chest, in a mane of long fur
        base, top_of_neck = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top_of_neck - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top_of_neck, t) - across * sag, X * r, across * (r * 1.2)) for t, r, sag in breed.neck_shape], 14)
        # The mane: thick round the throat, standing over the nape and on over the shoulders
        big = 1.08 if breed.big else 1.0
        b.ellipsoid(base.lerp(top_of_neck, 0.45) - across * 0.040, V(0.070 * big, 0.068, 0.066), Matrix.Rotation(-0.6, 3, "X"))
        b.ellipsoid(base.lerp(top_of_neck, 0.25) + across * 0.042, V(0.068 * big, 0.056, 0.090), Matrix.Rotation(-0.5, 3, "X"))
        b.ellipsoid(base + across * 0.03 + V(0.0, 0.02, -0.05), V(0.064 * big, 0.046, 0.075), Matrix.Rotation(-0.3, 3, "X"))

        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        # A broad head: a flat wide brow, a gentle stop, the cheeks fluffed out wide behind the eyes
        b.ellipsoid(skull + V(0.0, size.y * 0.48, size.z * 0.32), V(size.x * 0.84, size.y * 0.42, size.z * 0.5))
        for side in (1.0, -1.0):
            b.ellipsoid(skull + V(side * 0.024, 0.026, 0.044), V(0.016, 0.008, 0.015), Matrix.Rotation(0.3, 3, "X"))  # brow
            b.ellipsoid(skull + V(side * 0.052, -0.026, -0.018), V(0.030, 0.038, 0.044), Matrix.Rotation(0.5, 3, "X"))  # the cheek ruff
            b.ellipsoid(skull + V(side * 0.066, -0.046, -0.036), V(0.022, 0.033, 0.036), Matrix.Rotation(0.6, 3, "X"))  # its flare
            b.ellipsoid(skull + V(side * 0.038, -0.010, 0.028), V(0.018, 0.022, 0.030), Matrix.Rotation(0.3, 3, "X"))  # cheekbone
        b.ellipsoid(skull + V(0.0, 0.032, -0.036), V(0.022, 0.022, 0.032))  # the back of the skull
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull, X * size.x * 0.8, Y * size.y * 0.8)] + muzzle + dome(muzzle[-1], Z, muzzle[-1][1].x * 0.6, 3), 14)
        for side in (1.0, -1.0):
            # Close lips along the jaw: the rig still draws them back to snarl
            b.ellipsoid(skull + V(side * 0.020, -0.034, 0.110), V(0.008, 0.012, 0.044), None, 8, 5)
            b.ellipsoid(skull + V(side * 0.030, -0.032, 0.062), V(0.010, 0.014, 0.032), None, 8, 5)

        # The tail: straight and bushy, hanging
        b.strand([breed.tail_root + V(0.0, 0.03, 0.05)] + breed.tail, breed.tail_shape, 12)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            dog.limb(b, joints, breed.fore_shape if fore else breed.hind_shape)
            width, length = breed.paw
            paw = joints[3]
            if not low:
                knob = joints[1] + V(0.0, 0.012, -0.022) if fore else joints[2] + V(0.0, 0.016, -0.016)
                b.ellipsoid(knob, V(width * 0.5, 0.020, 0.017), None, 8, 5)
            # Big feet: broad and long, the two middle toes well ahead of the others
            b.ellipsoid(paw + V(0.0, -0.007, length * 0.5), V(width, 0.021, length), None, 10, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.42, -0.012, length * 1.22 - abs(toe) * length * 0.22), V(width * 0.30, 0.015, 0.021), None, 8, 5)
        return dog.furred(breed, b, (0.0034, 4, 15000))
    return shapes


def ear_curve(breed, t, side):
    root, mid, end = breed.ear
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(at.x * side, at.y, at.z)


# (how far up, half width, half thickness): broad at the root, thick with fur, the tip rounded
EAR_RINGS = ((0.0, 0.028, 0.014), (0.10, 0.029, 0.012), (0.30, 0.025, 0.010), (0.52, 0.019, 0.008),
             (0.72, 0.013, 0.006), (0.87, 0.0075, 0.005), (0.96, 0.0035, 0.003), (1.0, 0.001, 0.001))


def ear_frame(side):
    """Across the ear, and the way its opening faces (forward and a little out)."""
    wide = V(side * 0.96, 0.0, -0.28).normalized()
    face = V(side * 0.28, 0.0, 0.96).normalized()
    return wide, face


def ears(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half, thick in EAR_RINGS:
                cup = math.sin(math.pi * t) * 0.005
                if side == breed.notched and 0.4 < t < 0.56:
                    half *= 0.72
                rings.append((ear_curve(breed, t, side) - face * cup, wide * half, face * thick))
            b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings, 10)
        dog.lay_fur(breed, b.bm, True)
    return shapes


def ear_linings(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half in ((0.08, 0.012), (0.2, 0.022), (0.38, 0.021), (0.58, 0.016), (0.76, 0.010), (0.9, 0.004)):
                rings.append((ear_curve(breed, t, side) + face * 0.0058, wide * half, face * 0.0035))
            b.tube(rings, 8)
    return shapes


def gums(breed):
    def shapes(b):
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            points = []
            for share in (0.96, 0.82, 0.66, 0.5, 0.36):
                x = (back + (front - back) * share) * 0.8
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


MATERIALS = [("coat", (0.37, 0.362, 0.345)), ("crest", (0.17, 0.165, 0.155)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "palate": (0.34, 0.12, 0.13, 0.5), "tongue": (0.52, 0.22, 0.24, 0.6), "gums": (0.12, 0.08, 0.08, 0.6),
    "fangs": (0.88, 0.85, 0.74, 0.4), "teeth": (0.88, 0.85, 0.74, 0.4), "eyes": (0.84, 0.62, 0.20, 1.0),
    "linings": (0.46, 0.44, 0.41, 0.0), "nose": (0.025, 0.022, 0.022, 0.7),
}


def markings(breed, p, normal):
    """(dark, pale, buff) at a point of the coat, 0..1 each."""
    s = breed.skull
    q = p - s
    up = normal.y
    y, rx, ry = dog.trunk_at(breed, p.z)
    on_head = p.z > breed.neck.z + 0.07 and p.y > breed.neck.y + 0.04
    # The tail: the saddle's dark down its top, the scent gland a dark spot near its root, black at the end
    off, along = dog.chain_param(p, breed.tail)
    tail = p.z < breed.tail[0].z + 0.02 and off < 0.065
    if tail:
        tip = blend(3.0, 3.6, along)
        gland = math.exp(-((along - 0.5) / 0.28) ** 2) * blend(-0.2, 0.6, -normal.z * 0.3 + up)
        dark = max(tip, 0.6 * gland, 0.35 * blend(-0.3, 0.6, up))
        pale = 0.5 * blend(0.1, -0.7, up) * (1.0 - tip)
        return dark, pale, 0.25 * (1.0 - tip)
    if on_head:
        # The mask: cream on the lips and chin and the sides of the muzzle, up the cheeks
        # to below the eye and out over the cheek ruff, and a spot over each eye; buff
        # behind the ears and along the top of the muzzle; grizzled on the crown.
        side = abs(q.x)
        lips = blend(-0.008, -0.026, q.y) if q.z > 0.0 else blend(-0.016, -0.042, q.y)
        muzzle_side = blend(0.012, 0.026, side) * blend(0.02, 0.06, q.z) * blend(0.0, -0.012, q.y)
        cheek = blend(-0.002, -0.024, q.y) * blend(0.018, 0.04, side) * blend(0.07, 0.0, q.z)
        ruff = blend(0.03, 0.06, side) * blend(0.0, -0.03, q.y) * blend(0.03, -0.02, q.z)
        eye = breed.eye[0]
        brow = math.exp(-((Vector((side, q.y, q.z)) - (eye + V(-0.004, 0.016, -0.004))).length / 0.0095) ** 2)
        pale = max(lips, muzzle_side * 0.85, cheek * 0.95, ruff * 0.8, brow * 0.8)
        buff = blend(0.0, -0.035, q.z) * blend(0.0, 0.036, q.y) * 0.75 + blend(0.04, 0.12, q.z) * blend(0.0, 0.012, q.y) * 0.55
        # (a dark line from the eye back, dark grizzle down the bridge of the nose and over the crown)
        ring = math.exp(-((Vector((side, q.y, q.z)) - eye).length / 0.013) ** 2)
        bridge = blend(0.04, 0.14, q.z) * blend(0.004, 0.02, q.y) * blend(0.018, 0.006, side)
        crown = blend(0.02, 0.05, q.y) * blend(0.04, -0.01, q.z) * blend(0.03, 0.0, side)
        dark = max(0.5 * ring, 0.32 * bridge, 0.25 * crown) * (1.0 - pale)
        return dark, pale, min(buff, 1.0) * (1.0 - pale)
    # The body: pale throat, chest, belly and the insides of the legs
    belly = blend(y - ry * 0.25, y - ry * 0.9, p.y) * blend(0.36, 0.28, p.z) * blend(-0.28, -0.16, p.z)
    throat = blend(breed.neck.z - 0.08, breed.neck.z + 0.05, p.z) * blend(breed.neck.y + 0.03, breed.neck.y - 0.08, p.y)
    chest = blend(0.18, 0.33, p.z) * blend(0.55, 0.44, p.y) * blend(0.05, 0.02, abs(p.x))
    suffix, leg = dog.leg_share(breed, p)
    inner = leg * blend(0.2, -0.6, normal.x * (1.0 if p.x >= 0.0 else -1.0)) * blend(0.45, 0.2, p.y)
    lower_leg = leg * blend(0.22, 0.08, p.y)
    pale = max(belly, throat, chest * 0.9, inner * 0.6, lower_leg * 0.22)
    # The saddle: black-tipped guard hairs from behind the shoulders down the back to the
    # tail, and a dark mane along the top of the neck and over the withers
    saddle = blend(0.2, 0.85, up) * blend(-0.34, -0.22, p.z) * blend(0.30, 0.10, p.z) * (1.0 - leg)
    nape = blend(0.25, 0.9, up) * blend(breed.neck.z - 0.08, breed.neck.z + 0.08, p.z) * (1.0 - leg)
    # (a dark line down the front of each foreleg, as many wolves have)
    stripe = 0.0
    if suffix[1] == "f" and p.y < breed.fore[1].y + 0.03 and p.y > breed.fore[3].y + 0.05:
        stripe = leg * blend(0.25, 0.8, normal.z) * blend(breed.fore[3].y + 0.05, breed.fore[3].y + 0.10, p.y)
    deep = 0.85 if breed.big else 0.7
    dark = max(deep * saddle, 0.45 * nape, 0.5 * stripe)
    # Buff legs, the flanks a little warmer than the back
    buff = max(leg * blend(0.52, 0.28, p.y), 0.3 * blend(0.5, -0.3, up) * (1.0 - leg))
    return dark, pale * (1.0 - stripe), buff * (1.0 - pale)


def paint(breed, whole, part_of):
    """Vertex colours. On the coat: red, how open the surface is (low in
    grooves and creases); green, how dark its markings are; blue, how pale;
    alpha, how buff. On the other parts, their colours (see PART_COLOURS)."""
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
            dark, pale, buff = 0.0, 1.0, 0.0
        elif part == "ears":
            # Buff on the back of the ear, the rims dark, the fur in front of the opening pale
            root = breed.ear[0]
            up = (p.y - root.y) / (breed.ear[2].y - root.y)
            front = blend(0.2, 0.8, normal.z)
            dark = 0.55 * blend(0.75, 1.0, up) * (1.0 - front)
            dark, pale, buff = dark, 0.5 * front * (1.0 - blend(0.7, 1.0, up)), 0.85 * (1.0 - blend(0.7, 1.0, up)) * (1.0 - front)
        else:
            dark, pale, buff = markings(breed, p, normal)
        vert[layer] = (shade, dark, pale, buff)
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
        for breed in WOLVES:
            dog.export(breed, preview)
