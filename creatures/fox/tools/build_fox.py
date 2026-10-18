"""Builds the red foxes (creatures/fox) and exports them for Godot.

Run from the game's root (it needs tools/build_dog.py, which needs the character
controller's tools/build_character.py):
    blender --background --python creatures/fox/tools/build_fox.py
    blender --background --python creatures/fox/tools/build_fox.py -- <preview folder> fox_a

Writes creatures/fox/models/fox_a.glb and fox_b.glb, and a demade `_lo`
version of each (and, with a preview folder, an editable .blend and pictures
there).

A red fox: small and slight, a long low body on slender legs that are short
for it, small neat oval feet, a narrow chest, a small head with a broad crown,
cheeks flared with fur, a long fine pointed muzzle, big upright triangular
ears, and a great bushy brush of a tail as long as its body is high and nearly
as thick as its chest. Its coat is rust red, darker and redder down the back,
ginger on the flanks and cheeks; white on the upper lips, the chin, the throat
and chest (a bib), greyish white under the belly; black stockings up its legs,
black backs to its ears, a dark line from each eye down the muzzle, a dusky
top to the brush and a white tip to it. `fox_a` is the redder dog fox, `fox_b`
the slighter, paler vixen, a notch out of one ear.

It is built on the dog's skeleton and with the dog's tools (tools/build_dog.py,
GameCommon's godot/dog): the same bones and names, so DogRig (FoxRig) moves
it. What is a fox's own is here: its shape (`coat`, `ears`), how the brush is
weighted to the tail's bones (it is far thicker than the dog's tail), and the
colours painted into its coat (`paint`): red how open the surface is (dark in
creases), green how dark its markings are (black), blue how pale (white), and
alpha how ginger (the paler orange of the flanks).

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

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

## How far off the line of the tail's bones the brush reaches (its fur), metres.
BRUSH_REACH = 0.095


def fox(name, notched, vixen):
    breed = dog.Breed(
        name=name,
        cropped=0.0,
        notched=notched,
        vixen=vixen,
        scars=-1,
        body=V(0.0, 0.40, 0.0), chest=V(0.0, 0.415, 0.19), pelvis=V(0.0, 0.415, -0.21),
        # (along the body, centre height, half width, half height): long and low, a
        # deep furry body for its legs, the belly hardly drawn up
        trunk=[(-0.36, 0.445, 0.042, 0.052), (-0.31, 0.440, 0.062, 0.076), (-0.22, 0.433, 0.068, 0.086),
               (-0.12, 0.440, 0.058, 0.076), (-0.02, 0.432, 0.060, 0.092), (0.07, 0.412, 0.066, 0.118),
               (0.16, 0.400, 0.070, 0.132), (0.25, 0.408, 0.068, 0.124), (0.31, 0.426, 0.059, 0.096),
               (0.355, 0.446, 0.046, 0.067)],
        # Shoulder, elbow, wrist, paw; hip, stifle, hock, paw (the left legs). Short, slender legs.
        fore=[V(0.058, 0.400, 0.262), V(0.058, 0.272, 0.205), V(0.056, 0.110, 0.214), V(0.056, 0.026, 0.230)],
        hind=[V(0.054, 0.415, -0.255), V(0.054, 0.282, -0.165), V(0.052, 0.132, -0.322), V(0.052, 0.026, -0.316)],
        # (how far down the leg, counted in joints; half width; half depth; forward offset): fine-boned
        fore_shape=[(-0.3, 0.030, 0.050, 0.0), (0.0, 0.032, 0.054, 0.0), (0.5, 0.028, 0.042, 0.0), (1.0, 0.023, 0.032, -0.004),
                    (1.25, 0.021, 0.028, 0.0), (1.6, 0.018, 0.022, 0.0), (2.0, 0.017, 0.020, 0.0), (2.5, 0.017, 0.020, 0.0),
                    (3.0, 0.019, 0.021, 0.003)],
        hind_shape=[(-0.25, 0.032, 0.066, 0.0), (0.0, 0.038, 0.082, 0.0), (0.45, 0.034, 0.068, 0.0), (0.85, 0.026, 0.042, 0.004),
                    (1.0, 0.023, 0.036, 0.004), (1.3, 0.020, 0.031, -0.004), (1.7, 0.016, 0.022, 0.0), (2.0, 0.016, 0.022, -0.003),
                    (2.3, 0.015, 0.019, 0.0), (2.7, 0.015, 0.018, 0.0), (3.0, 0.018, 0.020, 0.003)],
        paw=(0.021, 0.034),
        muscle=0.62,
        # The neck short and carried forward, the head held a little above the back
        neck=V(0.0, 0.468, 0.300), head=V(0.0, 0.585, 0.445),
        neck_shape=[(-0.3, 0.076, 0.0), (0.0, 0.073, 0.010), (0.35, 0.066, 0.014), (0.7, 0.057, 0.010), (1.0, 0.048, 0.0), (1.15, 0.040, 0.0)],
        skull_at=V(0.0, 0.020, 0.028), skull_size=V(0.052, 0.046, 0.060),
        # (along the muzzle from the skull, height, half width, half height): fine and pointed
        muzzle=[(0.024, -0.006, 0.034, 0.034), (0.054, -0.012, 0.027, 0.027), (0.082, -0.016, 0.020, 0.021),
                (0.106, -0.019, 0.015, 0.016), (0.126, -0.021, 0.011, 0.012)],
        nose=(V(0.0, -0.016, 0.136), V(0.0098, 0.0085, 0.0085)),
        jaw_at=V(0.0, -0.028, 0.000),
        jaw_shape=[(-0.01, -0.036, 0.029, 0.013), (0.045, -0.040, 0.021, 0.010), (0.09, -0.041, 0.014, 0.008), (0.119, -0.039, 0.009, 0.006)],
        mouth=(-0.035, 0.124, 0.010, 0.020),
        eye=(V(0.029, 0.013, 0.044), 0.0090),
        # Each ear: where it roots, the joint part way up it, and its tip. Big, broad-based, upright.
        ear_at=[V(0.029, 0.036, -0.010), V(0.043, 0.088, -0.021), V(0.051, 0.140, -0.031)],
        tail_root=V(0.0, 0.462, -0.352),
        # (the brush, carried low and out behind, its end lifted a little off the ground)
        tail_at=[(0.0, 0.0, 0.0), (0.0, -0.06, -0.085), (0.0, -0.125, -0.178), (0.0, -0.178, -0.275), (0.0, -0.21, -0.375)],
        tail_shape=[0.036, 0.056, 0.068, 0.073, 0.064, 0.030],
    )
    if vixen:
        # (slighter: a finer head and chest, a little longer in the ear)
        breed.skull_size = V(0.048, 0.043, 0.059)
        breed.trunk = [(z, y, rx * 0.95, ry * 0.96) for z, y, rx, ry in breed.trunk]
        breed.ear_at = [V(0.029, 0.036, -0.010), V(0.044, 0.094, -0.021), V(0.053, 0.150, -0.031)]
        breed.ear = [breed.skull + offset for offset in breed.ear_at]
        breed.tail_shape = [r * 0.94 for r in breed.tail_shape]
    return breed


FOXES = [fox("fox_a", 0.0, False), fox("fox_b", -1.0, True)]


def coat(breed):
    def shapes(b):
        low = kit.LOW
        m = breed.muscle
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.04)[::-1] + rings + dome(rings[-1], Z, 0.04), 18)
        top = breed.trunk[6][1] + breed.trunk[6][3]
        b.ellipsoid(V(0.0, top - 0.020, 0.19), V(0.032 * m, 0.022, 0.085))
        b.ellipsoid(V(0.0, breed.fore[0].y + 0.004, 0.318), V(0.044 * m, 0.056, 0.044))
        for side in (1.0, -1.0):
            arm = breed.fore[0].lerp(breed.fore[1], 0.3)
            b.ellipsoid(V(side * (arm.x + 0.004), arm.y + 0.040, arm.z - 0.012), V(0.028 * m, 0.072, 0.054 * m), Matrix.Rotation(0.40, 3, "X"))
            thigh = breed.hind[0].lerp(breed.hind[1], 0.3)
            b.ellipsoid(V(side * thigh.x, thigh.y + 0.02, thigh.z + 0.01), V(0.038 * m, 0.098, 0.082 * m), Matrix.Rotation(-0.45, 3, "X"))
            # (the fluffy "trousers" of fur at the back of the thigh)
            b.ellipsoid(V(side * (thigh.x - 0.004), thigh.y - 0.01, thigh.z - 0.04), V(0.030, 0.07, 0.04), Matrix.Rotation(-0.3, 3, "X"))

        # Neck, rising forward out of the chest, a soft ruff round it and the bib below
        base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top, t) - across * sag, X * r, across * (r * 1.2)) for t, r, sag in breed.neck_shape], 14)
        b.ellipsoid(base.lerp(top, 0.4) - across * 0.032, V(0.052, 0.054, 0.054), Matrix.Rotation(-0.6, 3, "X"))
        b.ellipsoid(base.lerp(top, 0.15) - across * 0.05, V(0.048, 0.05, 0.05), Matrix.Rotation(-0.4, 3, "X"))

        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        # A broad crown, a shallow stop, and the cheeks flared out with fur behind the jaw:
        # the fox's triangular face
        b.ellipsoid(skull + V(0.0, size.y * 0.5, size.z * 0.3), V(size.x * 0.84, size.y * 0.42, size.z * 0.5))
        for side in (1.0, -1.0):
            b.ellipsoid(skull + V(side * 0.024, 0.026, 0.046), V(0.014, 0.007, 0.014), Matrix.Rotation(0.3, 3, "X"))  # brow
            b.ellipsoid(skull + V(side * 0.040, -0.026, -0.016), V(0.024, 0.026, 0.034), Matrix.Rotation(0.6, 3, "X") @ Matrix.Rotation(side * 0.3, 3, "Y"))  # cheek ruff
            b.ellipsoid(skull + V(side * 0.034, -0.012, 0.026), V(0.013, 0.018, 0.026), Matrix.Rotation(0.3, 3, "X"))  # cheekbone
        b.ellipsoid(skull + V(0.0, 0.032, -0.036), V(0.020, 0.020, 0.030))
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull, X * size.x * 0.8, Y * size.y * 0.8)] + muzzle + dome(muzzle[-1], Z, muzzle[-1][1].x * 0.55, 3), 14)
        for side in (1.0, -1.0):
            b.ellipsoid(skull + V(side * 0.012, -0.031, 0.088), V(0.006, 0.009, 0.036), None, 8, 5)
            b.ellipsoid(skull + V(side * 0.021, -0.030, 0.050), V(0.0075, 0.011, 0.028), None, 8, 5)

        # The brush: long, very thick, fullest two thirds of the way along and
        # coming to a soft point; carried low and out behind
        b.strand([breed.tail_root + V(0.0, 0.03, 0.05)] + breed.tail, breed.tail_shape, 14 if not low else 10)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            dog.limb(b, joints, breed.fore_shape if fore else breed.hind_shape)
            width, length = breed.paw
            paw = joints[3]
            if not low:
                knob = joints[1] + V(0.0, 0.010, -0.020) if fore else joints[2] + V(0.0, 0.015, -0.015)
                b.ellipsoid(knob, V(width * 0.55, 0.019, 0.016), None, 8, 5)
            # Small neat oval feet, furred between the pads
            b.ellipsoid(paw + V(0.0, -0.008, length * 0.5), V(width, 0.019, length), None, 10, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.40, -0.013, length * 1.22 - abs(toe) * length * 0.2), V(width * 0.26, 0.013, 0.017), None, 8, 5)
        return dog.furred(breed, b, (0.0034, 4, 14000))
    return shapes


def ear_curve(breed, t, side):
    root, mid, end = breed.ear
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(at.x * side, at.y, at.z)


# (how far up, half width, half thickness): broad at the root, straight-sided to a point
EAR_RINGS = ((0.0, 0.034, 0.013), (0.10, 0.038, 0.010), (0.30, 0.033, 0.008), (0.52, 0.024, 0.006),
             (0.72, 0.015, 0.005), (0.88, 0.007, 0.004), (1.0, 0.0015, 0.0015))


def ear_frame(side):
    wide = V(side * 0.97, 0.0, -0.25).normalized()
    face = V(side * 0.25, 0.0, 0.97).normalized()
    return wide, face


def ears(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half, thick in EAR_RINGS:
                cup = math.sin(math.pi * t) * 0.006
                if side == breed.notched and 0.5 < t < 0.66:
                    half *= 0.68
                rings.append((ear_curve(breed, t, side) - face * cup, wide * half, face * thick))
            b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings, 10)
        dog.lay_fur(breed, b.bm, True)
    return shapes


def ear_linings(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide, face = ear_frame(side)
            rings = []
            for t, half in ((0.08, 0.013), (0.2, 0.026), (0.38, 0.025), (0.58, 0.017), (0.76, 0.009), (0.9, 0.003)):
                rings.append((ear_curve(breed, t, side) + face * 0.0055, wide * half, face * 0.0035))
            b.tube(rings, 8)
    return shapes


def gums(breed):
    def shapes(b):
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            points = []
            for share in (0.96, 0.82, 0.66, 0.5, 0.36):
                x = (back + (front - back) * share) * 0.78
                points.append(breed.skull + V(side * x, y + 0.008, length * share))
            b.strand(points, [0.003, 0.004, 0.004, 0.0035, 0.003], 6)
    return shapes


def parts(breed):
    return [
        ("coat", 0, coat(breed), None), ("jaw", 0, dog.jaw(breed), None), ("ears", 0, ears(breed), None),
        ("crest", 1, dog.crest(breed), None), ("palate", 2, dog.palate(breed), None), ("tongue", 2, dog.tongue(breed), None),
        ("gums", 2, gums(breed), None), ("fangs", 2, dog.fangs(breed), None), ("teeth", 2, dog.teeth(breed), None),
        ("eyes", 2, dog.eyes(breed), None), ("linings", 2, ear_linings(breed), None), ("nose", 2, dog.nose(breed), None),
    ]


MATERIALS = [("coat", (0.40, 0.19, 0.085)), ("crest", (0.33, 0.15, 0.07)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "palate": (0.36, 0.12, 0.13, 0.5), "tongue": (0.55, 0.22, 0.24, 0.6), "gums": (0.12, 0.07, 0.07, 0.6),
    "fangs": (0.88, 0.85, 0.74, 0.4), "teeth": (0.88, 0.85, 0.74, 0.4), "eyes": (0.84, 0.56, 0.14, 1.0),
    "linings": (0.62, 0.56, 0.48, 0.0), "nose": (0.025, 0.022, 0.022, 0.7),
}


def _brush_weights(base):
    """The dog's weights, but the brush (far thicker than a dog's tail) all on the tail's bones."""
    def make(breed):
        weigh = base(breed)
        tail = breed.tail
        names = ["pelvis", "tail", "tail_1", "tail_2", "tail_3"]

        def fox_weigh(part, p):
            if part == "coat":
                off, along = dog.chain_param(p, tail)
                if p.z < tail[0].z + 0.01 and off < BRUSH_REACH:
                    past = [1.0, blend(0.0, 0.6, along)] + [blend(k - 0.3, k + 0.3, along) for k in (1, 2, 3)] + [0.0]
                    return {name: past[i] - past[i + 1] for i, name in enumerate(names)}
            return weigh(part, p)
        return fox_weigh
    return make


def markings(breed, p, normal):
    """(dark, pale, ginger) at a point of the coat, 0..1 each."""
    s = breed.skull
    q = p - s
    up = normal.y
    y, rx, ry = dog.trunk_at(breed, p.z)
    on_head = p.z > breed.neck.z + 0.07 and p.y > breed.neck.y + 0.03
    off, along = dog.chain_param(p, breed.tail)
    if p.z < breed.tail[0].z + 0.01 and off < BRUSH_REACH:
        # The brush: red, dusky along its top with black-tipped hairs, a dark
        # spot over the gland near its root, paler under it, the tip white.
        tip = blend(3.25, 3.7, along)
        gland = math.exp(-((along - 0.5) / 0.22) ** 2) * blend(0.1, 0.7, up)
        dusk = 0.45 * blend(0.0, 0.8, up) * blend(0.6, 2.0, along) * (1.0 - tip)
        dark = max(0.5 * gland, dusk) * (1.0 - tip)
        pale = max(tip, 0.25 * blend(0.0, -0.8, up))
        return dark, pale, 0.25 * blend(-0.2, -0.8, up) * (1.0 - tip)
    if on_head:
        # White: the upper lips, the chin and throat, the cheeks below the eye
        # (bright against the red of the muzzle's top and the crown)
        lower = blend(-0.010, -0.026, q.y) if q.z > 0.02 else blend(-0.012, -0.036, q.y)
        cheek = blend(0.0, -0.022, q.y) * blend(0.018, 0.04, abs(q.x)) * blend(0.08, 0.0, q.z)
        pale = max(lower, cheek)
        # The dark line from the front of each eye down the side of the muzzle, and dark round the eye
        eye = breed.eye[0]
        ring = math.exp(-((Vector((abs(q.x), q.y, q.z)) - eye).length / 0.013) ** 2)
        start = eye + V(-0.004, -0.004, 0.006)
        end = V(0.016, -0.020, 0.080)
        line_off, line_along = dog.chain_param(Vector((abs(q.x), q.y, q.z)), [start, end])
        tear = math.exp(-(line_off / 0.0055) ** 2) * (1.0 - line_along * 0.4) * blend(0.0, 0.5, abs(normal.x))
        dark = max(0.6 * ring, 0.65 * tear) * (1.0 - pale)
        # Ginger over the cheeks and the side of the head
        ginger = 0.6 * blend(0.4, 0.0, up) * blend(-0.02, 0.0, q.y) * (1.0 - pale)
        return dark, pale, ginger
    # The body
    belly = blend(y - ry * 0.25, y - ry * 0.9, p.y) * blend(0.36, 0.28, p.z) * blend(-0.32, -0.2, p.z)
    throat = blend(breed.neck.z - 0.10, breed.neck.z + 0.04, p.z) * blend(breed.neck.y + 0.03, breed.neck.y - 0.08, p.y)
    bib = blend(0.18, 0.34, p.z) * blend(0.55, 0.44, p.y) * blend(0.055, 0.025, abs(p.x))
    suffix, leg = dog.leg_share(breed, p)
    fore = suffix[1] == "f"
    joints = breed.legs[suffix]
    inner = leg * blend(0.2, -0.6, normal.x * (1.0 if p.x >= 0.0 else -1.0)) * blend(0.45, 0.25, p.y)
    pale = max(belly * 0.75 * (1.0 - leg), throat, bib, inner * 0.3)
    # The black stockings: up the forelegs to the elbow (and a dark line on up the front),
    # up the hind legs to the hock and a little past it
    if fore:
        sock = blend(joints[1].y + 0.01, joints[1].y - 0.05, p.y)
        sock = max(sock, blend(0.2, 0.8, normal.z) * blend(joints[0].y - 0.02, joints[1].y, p.y) * 0.8)
    else:
        sock = blend(joints[2].y + 0.07, joints[2].y + 0.01, p.y)
    stocking = leg * sock
    # Redder and darker down the back, dusky over the shoulders (the "cross")
    saddle = blend(0.3, 0.9, up) * blend(-0.36, -0.2, p.z) * blend(0.34, 0.15, p.z) * (1.0 - leg)
    cross = blend(0.5, 0.95, up) * math.exp(-((p.z - 0.24) / 0.06) ** 2) * (1.0 - leg)
    dark = max(stocking, 0.18 * saddle, 0.22 * cross)
    # Ginger on the flanks and the upper legs
    ginger = max(0.6 * blend(0.55, -0.1, up) * (1.0 - leg), leg * 0.5 * blend(0.3, 0.45, p.y))
    return dark, pale * (1.0 - stocking), ginger * (1.0 - stocking)


def paint(breed, whole, part_of):
    """Vertex colours. On the coat: red, how open the surface is (low in
    grooves and creases); green, how dark its markings are; blue, how pale;
    alpha, how ginger. On the other parts, their colours (see PART_COLOURS)."""
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
            dark, pale, ginger = 0.0, 1.0, 0.0
        elif part == "ears":
            # Black on the backs of the ears; the fronts' edges red, their fur within pale
            root = breed.ear[0]
            up = (p.y - root.y) / (breed.ear[2].y - root.y)
            side = 1.0 if p.x >= 0.0 else -1.0
            wide, face = ear_frame(side)
            front = normal.dot(face)
            dark = blend(0.1, -0.35, front) * blend(0.05, 0.25, up) * 0.95
            pale = blend(0.3, 0.7, front) * blend(0.85, 0.5, up) * 0.6
            dark, pale, ginger = dark, pale * (1.0 - dark), 0.3 * (1.0 - dark)
        else:
            dark, pale, ginger = markings(breed, p, normal)
        if breed.vixen:
            ginger = min(1.0, ginger * 1.25 + 0.1)
        vert[layer] = (shade, dark, pale, ginger)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))


dog.parts = parts
dog.paint = paint
dog.weights = _brush_weights(dog.weights)
dog.MATERIALS = MATERIALS
dog.PART_COLOURS = PART_COLOURS


if __name__ == "__main__":
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        for breed in FOXES:
            dog.export(breed, preview)
