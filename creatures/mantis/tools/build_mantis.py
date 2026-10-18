"""Builds the giant praying mantis (creatures/mantis/) and exports it for Godot.

Run from the game's root:
    blender --background --python creatures/mantis/tools/build_mantis.py [-- <folder for pictures>]
then, so that Godot takes up the new models:
    godot --headless --path . --import

Writes creatures/mantis/models/mantis.glb and the demade mantis_lo.glb (an editable .blend and pictures go to the
preview folder, when there is one).

A praying mantis after the European mantis and the giant Asian mantises (Mantis religiosa, Hierodula), at its real
proportions, made huge: it stands about three metres to the top of its head, its long prothorax reared up and its head
on top of it, its abdomen held level behind on four long thin walking legs. Everything is in the game's own directions
(metres, x to its left, y up, z the way it faces) and turned to Blender's as it is made.

    head       a flat triangle, wide at the top where the two great compound eyes bulge from its corners, narrowing
               down to the mouth (small jaws, palps); three tiny ocelli between the eyes; two long thread-like
               feelers from between them.
    prothorax  the long "neck": a thin stalk reared up from the body, widening a little just behind the head where
               the forelegs are hinged on.
    forelegs   raptorial: a long coxa hanging from the front of the prothorax; a heavy femur with two rows of spines
               along its underside and a groove between them; a tibia, spined too and ending in a hooked claw, that
               shuts back against the femur like a jack-knife; a short tarsus. Held folded together in front of it,
               "in prayer"; on the inside of each coxa a dark spot, shown in its threat display.
    body       the meso- and metathorax, from which the four walking legs (each a femur, a tibia, a beaded tarsus) and
               the wings come.
    wings      two long leathery forewings (tegmina), leaf-like, laid one over the other along its back; under them
               the broad hindwings, folded (the game spreads them, as fans, in the threat display).
    abdomen    long, broad in the middle, of overlapping segments, a little upturned at its tip, with two short cerci.

It is rigged on bones that each move a part whole, as an insect's hard parts do (every bone points straight up with
no roll, so its rest in Godot is the identity; creatures/mantis/mantis.gd poses them):

    root, body, abdomen, abdomen_2, pronotum, head, antenna_l/r, antenna_tip_l/r,
    coxa_l/r, femur_l/r, tibia_l/r, tarsus_l/r                         (the forelegs)
    mid_femur_l/r, mid_tibia_l/r, hind_femur_l/r, hind_tibia_l/r       (the walking legs; the tarsus goes with the tibia)
    tegmen_l/r, hindwing_l/r                                           (the wings: a hindwing spreads by scaling its bone in x)

Vertex colours: the colour of each part (pale grey-green, the eyes paler, the coxal spots dark, the hindwings
smoky), and in alpha what it is to the shader: 1 hard body, 0.5 an eye (the shader gives it its false pupil, the
dark spot that seems to follow whoever looks at it), 0 a wing (the shader draws its veins from its UV: u along the
wing, v across it).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
OUT = os.path.join(COMPONENT, "models")
PREVIEW = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

LOW = False


def V(x, y, z):
    return Vector((x, y, z))


def to_blender(p):
    return Vector((p.x, -p.z, p.y))


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# --- Where it all is ---

BODY = V(0.0, 1.36, 0.05)
ABDOMEN = V(0.0, 1.4, -0.12)
ABDOMEN_2 = V(0.0, 1.3, -1.05)
PRONOTUM = V(0.0, 1.47, 0.2)
NECK = V(0.0, 2.72, 0.8)
HEAD = V(0.0, 2.84, 0.86)

# Foreleg (left; the right is its mirror): shoulder, end of coxa, knee, end of tibia, claw tip; folded in prayer
FORE = [V(0.085, 2.56, 0.76), V(0.115, 2.02, 1.0), V(0.1, 2.46, 1.55), V(0.095, 2.02, 1.27), V(0.09, 1.82, 1.31)]
# Walking legs: hip, knee, end of tibia, foot
MID = [V(0.12, 1.3, 0.16), V(0.8, 1.62, 0.55), V(1.06, 0.3, 0.8), V(1.18, 0.0, 0.92)]
HIND = [V(0.12, 1.3, -0.04), V(0.85, 1.66, -0.55), V(1.13, 0.3, -1.08), V(1.26, 0.0, -1.24)]
WING_ROOT = V(0.0, 1.5, 0.02)

PALE = (0.58, 0.63, 0.53)
PALER = (0.61, 0.66, 0.56)
LEG = (0.55, 0.6, 0.5)
EYE = (0.6, 0.63, 0.54)
SPOT = (0.12, 0.11, 0.1)
SMOKE = (0.6, 0.6, 0.56)
TEGMEN = (0.6, 0.65, 0.53)


class Shape:
    """Faces with, for each corner, a colour and alpha (what it is) and a UV; and which bone each point goes with."""

    def __init__(self):
        self.faces = []

    def add(self, corners, colour, kind, bone, uvs=None):
        self.faces.append((corners, colour, kind, bone, uvs))

    def rings(self, rings, colour, kind, bone, start_tip=None, end_tip=None, uv_rows=None):
        sides = len(rings[0])
        for r in range(len(rings) - 1):
            a, b = rings[r], rings[r + 1]
            for k in range(sides):
                n = (k + 1) % sides
                uvs = None
                if uv_rows:
                    uvs = [(uv_rows[r], k / sides), (uv_rows[r], n / sides), (uv_rows[r + 1], n / sides), (uv_rows[r + 1], k / sides)]
                self.add([a[k], a[n], b[n], b[k]], colour, kind, bone, uvs)
        if start_tip is not None:
            for k in range(sides):
                n = (k + 1) % sides
                self.add([start_tip, rings[0][n], rings[0][k]], colour, kind, bone)
        if end_tip is not None:
            for k in range(sides):
                n = (k + 1) % sides
                self.add([rings[-1][k], rings[-1][n], end_tip], colour, kind, bone)


def frames(points, hint=V(0.0, 1.0, 0.0)):
    out = []
    side = None
    for i, p in enumerate(points):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        if side is None:
            side = ahead.cross(hint)
            if side.length < 1e-4:
                side = ahead.cross(V(1.0, 0.0, 0.0))
            side.normalize()
        else:
            side = (side - ahead * side.dot(ahead)).normalized()
        up = side.cross(ahead).normalized()
        out.append((side, up))
    return out


def tube(shape, points, radii, colour, bone, sides, hint=V(0.0, 1.0, 0.0), caps=(True, True), kind=1.0):
    fr = frames(points, hint)
    rings = []
    for p, (side, up), r in zip(points, fr, radii):
        rx, ry = r if isinstance(r, tuple) else (r, r)
        rings.append([p + side * math.cos(math.tau * k / sides) * rx + up * math.sin(math.tau * k / sides) * ry for k in range(sides)])
    r0 = radii[0][0] if isinstance(radii[0], tuple) else radii[0]
    r1 = radii[-1][0] if isinstance(radii[-1], tuple) else radii[-1]
    start = points[0] - (points[1] - points[0]).normalized() * r0 * 0.7 if caps[0] else None
    end = points[-1] + (points[-1] - points[-2]).normalized() * r1 * 0.7 if caps[1] else None
    shape.rings(rings, colour, kind, bone, start, end)
    return fr


def path(points, count):
    """A smooth curve through `points` (Catmull-Rom), `count` points along it."""
    out = []
    n = len(points) - 1
    for i in range(count):
        t = i / (count - 1) * n
        k = min(int(t), n - 1)
        f = t - k
        p0, p1, p2, p3 = points[max(k - 1, 0)], points[k], points[k + 1], points[min(k + 2, n)]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f))
    return out


def ellipsoid(shape, centre, radii, colour, kind, bone, rings, sides, turn=None, squash=None):
    rx, ry, rz = radii
    made = []
    for i in range(1, rings):
        t = math.pi * i / rings
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            p = V(math.cos(a) * math.sin(t) * rx, math.sin(a) * math.sin(t) * ry, -math.cos(t) * rz)
            if squash:
                p = squash(p)
            ring.append(centre + (turn @ p if turn else p))
        made.append(ring)
    back = centre + (turn @ V(0.0, 0.0, -rz) if turn else V(0.0, 0.0, -rz))
    front = centre + (turn @ V(0.0, 0.0, rz) if turn else V(0.0, 0.0, rz))
    shape.rings(made, colour, kind, bone, back, front)


def spines(shape, along, count, out_way, length, base, colour, bone, lean=V(0.0, 0.0, 0.0)):
    """Small cones along a segment (`along`: a function of t giving a point on its underside)."""
    for i in range(count):
        t = 0.12 + 0.8 * i / max(count - 1, 1)
        root = along(t)
        tip = root + (out_way * length * (0.7 + 0.5 * ((i * 37) % 5) / 4.0)) + lean
        sides = 3 if LOW else 4
        axis = (tip - root).normalized()
        side = axis.cross(V(0.0, 1.0, 0.0))
        if side.length < 1e-3:
            side = axis.cross(V(1.0, 0.0, 0.0))
        side.normalize()
        up = side.cross(axis)
        ring = [root + side * math.cos(math.tau * k / sides) * base + up * math.sin(math.tau * k / sides) * base for k in range(sides)]
        shape.rings([ring], colour, 1.0, bone, None, tip)


# --- The parts ---

def head(shape):
    """A flat triangle: wide at the top, the eyes on its upper corners, down to the jaws."""
    sides = 8 if LOW else 14
    rings = 5 if LOW else 9
    # (a squashed, triangular disc: a lofted shape across its width)
    top = 0.11
    bottom = -0.25
    stations = []
    count = 6 if LOW else 10
    for i in range(count + 1):
        t = i / count
        y = top + (bottom - top) * t
        # (wide across the top, where it runs out into the eyes; a wedge down to the jaws)
        width = 0.2 * (1.0 - t) ** 1.15 + 0.03
        depth = 0.06 * (1.0 - 0.45 * t) + 0.01
        stations.append((y, width, depth))
    ringlist = []
    for y, width, depth in stations:
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            # (a lens across: rounded front, flatter back, the face a little forward of the eyes)
            p = V(math.cos(a) * width, y, math.sin(a) * depth + 0.02 * (1.0 - abs(math.cos(a))))
            ring.append(HEAD + p)
        ringlist.append(ring)
    shape.rings(ringlist, PALE, 1.0, "head", HEAD + V(0.0, top + 0.03, 0.0), HEAD + V(0.0, bottom - 0.02, 0.01))
    # The eyes: great bulging ovals on the top corners, looking forward and out
    for side in (1.0, -1.0):
        at = HEAD + V(side * 0.175, 0.065, 0.02)
        ellipsoid(shape, at, (0.07, 0.1, 0.095), EYE, 0.5, "head", rings, sides,
                  Matrix.Rotation(side * math.radians(10.0), 3, "Y") @ Matrix.Rotation(side * math.radians(-12.0), 3, "Z"))
    # Ocelli: three tiny beads between the eyes
    if not LOW:
        for x, y in ((0.0, 0.1), (0.035, 0.075), (-0.035, 0.075)):
            ellipsoid(shape, HEAD + V(x, y, 0.07), (0.012, 0.012, 0.008), (0.8, 0.8, 0.7), 1.0, "head", 3, 5)
    # The frons plate between the eyes, and the jaws and palps at the bottom
    ellipsoid(shape, HEAD + V(0.0, 0.0, 0.06), (0.06, 0.06, 0.025), PALER, 1.0, "head", 4, 8 if not LOW else 6)
    for side in (1.0, -1.0):
        tube(shape, [HEAD + V(side * 0.03, -0.22, 0.04), HEAD + V(side * 0.012, -0.27, 0.06)], [0.016, 0.006], (0.5, 0.5, 0.42), "head", 5)
        palp = path([HEAD + V(side * 0.045, -0.2, 0.05), HEAD + V(side * 0.07, -0.26, 0.08), HEAD + V(side * 0.06, -0.31, 0.1)], 5 if not LOW else 3)
        tube(shape, palp, [0.01] * len(palp), PALE, "head", 4)


def antennae(shape):
    sides = 3 if LOW else 4
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root = HEAD + V(side * 0.035, 0.1, 0.06)
        mid = root + V(side * 0.18, 0.42, 0.18)
        tip = mid + V(side * 0.28, 0.32, 0.4)
        tube(shape, path([root, root.lerp(mid, 0.5) + V(0.0, 0.0, 0.03), mid], 4), [0.012, 0.011, 0.01, 0.009], PALE, "antenna" + suffix, sides, caps=(True, False))
        tube(shape, path([mid, mid.lerp(tip, 0.5) + V(0.0, 0.04, 0.0), tip], 5), [0.009, 0.008, 0.007, 0.006, 0.004], PALE, "antenna_tip" + suffix, sides, caps=(False, True))


def prothorax(shape):
    sides = 7 if LOW else 11
    count = 8 if LOW else 14
    radii = []
    points = []
    for i in range(count):
        t = i / (count - 1)
        p = PRONOTUM.lerp(NECK, t) + V(0.0, 0.0, 0.03 * math.sin(math.pi * t))
        points.append(p)
        # (thin, widening just behind the head where the forelegs hang: the supracoxal dilation)
        r = 0.062 + 0.012 * t + 0.05 * math.exp(-((t - 0.86) / 0.07) ** 2) - 0.02 * math.exp(-((t - 0.98) / 0.04) ** 2)
        radii.append((r * 1.25, r * 0.85))
    tube(shape, points, radii, PALE, "pronotum", sides, hint=V(0.0, 0.0, 1.0))
    # A keel down its back, and the neck
    tube(shape, [NECK + V(0.0, -0.02, -0.02), HEAD + V(0.0, -0.06, -0.03)], [0.045, 0.04], PALE, "head", 6)


def body(shape):
    sides = 8 if LOW else 12
    tube(shape, path([PRONOTUM + V(0.0, -0.04, -0.02), BODY + V(0.0, 0.02, 0.06), BODY + V(0.0, 0.03, -0.12), ABDOMEN + V(0.0, 0.0, -0.05)], 6),
         [(0.1, 0.09), (0.13, 0.11), (0.14, 0.12), (0.13, 0.12), (0.12, 0.11), (0.12, 0.11)], PALE, "body", sides, hint=V(0.0, 1.0, 0.0))


def abdomen(shape):
    sides = 9 if LOW else 14
    count = 10 if LOW else 22
    front, back = ABDOMEN.z, -2.05
    split = ABDOMEN_2.z
    rings = [[], []]
    for i in range(count + 1):
        t = i / count
        z = front + (back - front) * t
        s = math.sin(math.pi * min(max(t * 0.95 + 0.04, 0.0), 1.0)) ** 0.55
        # (segments: each a little fuller at its back edge)
        plates = 0.0 if LOW else 0.04 * (((t * 7.0) % 1.0) ** 2.5)
        rx = 0.3 * s * (1.0 + plates) * (1.0 - 0.25 * t)
        ry = 0.19 * s * (1.0 + plates)
        # (it hangs a little behind the body, its tip turned up)
        y = ABDOMEN.y - 0.12 * math.sin(math.pi * t * 0.8) + 0.18 * smooth((t - 0.75) / 0.25)
        ring = [V(math.cos(math.tau * k / sides) * rx, y + math.sin(math.tau * k / sides) * ry - 0.04 * (1.0 if math.sin(math.tau * k / sides) < 0 else 0.0), z) for k in range(sides)]
        rings[0 if z > split else 1].append(ring)
    # (the two halves meet at the split: the back half begins with the front half's last ring)
    rings[1].insert(0, rings[0][-1])
    shape.rings(rings[0], PALE, 1.0, "abdomen", ABDOMEN + V(0.0, 0.0, 0.03))
    shape.rings(rings[1], PALE, 1.0, "abdomen_2", None, V(0.0, rings[1][-1][0].y, back - 0.03))
    tip = V(0.0, rings[1][-1][0].y, back)
    for side in (1.0, -1.0):
        tube(shape, [tip + V(side * 0.03, 0.02, 0.02), tip + V(side * 0.09, 0.07, -0.2)], [0.02, 0.008], PALE, "abdomen_2", 4)


def forelegs(shape):
    sides = 6 if LOW else 9
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        j = [V(p.x * side, p.y, p.z) for p in FORE]
        # Coxa: long, a little flattened, with the dark spot on its inner face
        pts = path([j[0], j[0].lerp(j[1], 0.5) + V(side * 0.01, 0.0, 0.01), j[1]], 6 if not LOW else 3)
        tube(shape, pts, [(0.055, 0.045)] + [(0.05, 0.04)] * (len(pts) - 2) + [(0.042, 0.036)], PALE, "coxa" + suffix, sides, hint=V(side, 0.0, 0.0))
        spot_at = j[0].lerp(j[1], 0.42) + V(-side * 0.04, 0.0, 0.0)
        ellipsoid(shape, spot_at, (0.006, 0.05, 0.035), SPOT, 1.0, "coxa" + suffix, 3, 6)
        ellipsoid(shape, spot_at + V(-side * 0.003, 0.0, 0.0), (0.004, 0.022, 0.015), (0.8, 0.8, 0.75), 1.0, "coxa" + suffix, 3, 6)
        # Femur: heavy, its underside (facing the tibia) grooved and spined
        femur = path([j[1], j[1].lerp(j[2], 0.5) + V(0.0, 0.0, 0.03), j[2]], 7 if not LOW else 3)
        r = [(0.05, 0.06), (0.058, 0.072), (0.058, 0.07), (0.052, 0.062), (0.045, 0.052), (0.04, 0.045), (0.034, 0.038)]
        if LOW:
            r = [r[0], r[3], r[6]]
        fr = tube(shape, femur, r, PALE, "femur" + suffix, sides, hint=V(side, 0.0, 0.0))
        under = (j[3] - femur[len(femur) // 2]).normalized()

        def along_femur(t, femur=femur, under=under, side=side):
            p = femur[0].lerp(femur[-1], t)
            return p + under * 0.05

        if not LOW:
            spines(shape, lambda t, f=along_femur, s=side: f(t) + V(s * 0.022, 0.0, 0.0), 6, under, 0.06, 0.009, (0.42, 0.42, 0.36), "femur" + suffix)
            spines(shape, lambda t, f=along_femur, s=side: f(t) - V(s * 0.022, 0.0, 0.0), 6, under, 0.05, 0.008, (0.42, 0.42, 0.36), "femur" + suffix)
        # Tibia: folded back under the femur, spined along its edge, ending in a hooked claw
        tibia = path([j[2], j[2].lerp(j[3], 0.5) + under * -0.01, j[3]], 5 if not LOW else 3)
        tube(shape, tibia, [0.036, 0.034, 0.03, 0.027, 0.024][: len(tibia)] if not LOW else [0.036, 0.03, 0.024], PALE, "tibia" + suffix, sides - 1, hint=V(side, 0.0, 0.0))
        out = (femur[len(femur) // 2] - j[3]).normalized()
        if not LOW:
            spines(shape, lambda t, a=j[2], b=j[3], o=out: a.lerp(b, t) + o * 0.025, 6, out, 0.035, 0.006, (0.42, 0.42, 0.36), "tibia" + suffix)
        claw = path([j[3], j[3] + (j[3] - j[2]).normalized() * 0.08 + out * 0.02, j[3] + (j[3] - j[2]).normalized() * 0.12 + out * 0.07], 4)
        tube(shape, claw, [0.022, 0.016, 0.01, 0.004], (0.45, 0.45, 0.38), "tibia" + suffix, 5)
        # Tarsus: a short beaded foot hanging from the tibia
        tars = path([j[3] + out * 0.01, j[3].lerp(j[4], 0.5) + V(0.0, 0.0, 0.02), j[4]], 5 if not LOW else 3)
        tube(shape, tars, [0.016, 0.013, 0.014, 0.011, 0.008][: len(tars)] if not LOW else [0.016, 0.012, 0.008], LEG, "tarsus" + suffix, 5)


def walking_legs(shape):
    sides = 5 if LOW else 7
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        for name, joints in (("mid", MID), ("hind", HIND)):
            j = [V(p.x * side, p.y, p.z) for p in joints]
            femur = path([j[0], j[0].lerp(j[1], 0.5) + V(0.0, 0.05, 0.0), j[1]], 6 if not LOW else 3)
            tube(shape, femur, [0.045, 0.042, 0.04, 0.036, 0.033, 0.03][: len(femur)] if not LOW else [0.045, 0.038, 0.03], LEG, name + "_femur" + suffix, sides)
            tibia = path([j[1], j[1].lerp(j[2], 0.5) + V(side * 0.03, 0.0, 0.0), j[2]], 6 if not LOW else 3)
            tube(shape, tibia, [0.028, 0.026, 0.024, 0.022, 0.021, 0.02][: len(tibia)] if not LOW else [0.028, 0.024, 0.02], LEG, name + "_tibia" + suffix, sides)
            # (a knee joint, and spurs at the tibia's end)
            ellipsoid(shape, j[1], (0.04, 0.04, 0.04), LEG, 1.0, name + "_femur" + suffix, 3, sides)
            beads = 5 if not LOW else 2
            tars = [j[2].lerp(j[3], b / beads) + V(0.0, 0.03 * math.sin(math.pi * b / beads), 0.0) for b in range(beads + 1)]
            tube(shape, tars, [0.016 * (0.75 if b % 2 else 1.0) for b in range(beads + 1)], LEG, name + "_tibia" + suffix, max(sides - 2, 4))


def wings(shape):
    """The tegmina laid over the back, left over right, and the folded hindwings under them."""
    steps = 6 if LOW else 12
    for side, suffix, lift in ((1.0, "_l", 0.012), (-1.0, "_r", 0.0)):
        # Hindwing: a fan spread out to the side (the game folds it, scaling its bone in x, to lie under the tegmen)
        fan_rows = []
        uv_rows = []
        for i in range(steps + 1):
            t = i / steps
            a = math.radians(-8.0 + 115.0 * t)
            length = 1.75 * (1.0 - 0.45 * smooth(t))
            row = []
            for k in range(5):
                f = k / 4.0
                r = length * f
                # (it lies under the tegmen, sloping down its length as the tegmen does)
                p = WING_ROOT + V(side * (0.06 + math.sin(a) * r), 0.05 - 0.09 * (r / 1.75) * max(math.cos(a), 0.0), -math.cos(a) * r)
                row.append(p)
            fan_rows.append(row)
            uv_rows.append(t)
        for i in range(steps):
            for k in range(4):
                corners = [fan_rows[i][k], fan_rows[i + 1][k], fan_rows[i + 1][k + 1], fan_rows[i][k + 1]]
                uvs = [(k / 4.0, uv_rows[i]), (k / 4.0, uv_rows[i + 1]), ((k + 1) / 4.0, uv_rows[i + 1]), ((k + 1) / 4.0, uv_rows[i])]
                if side < 0:
                    corners.reverse()
                    uvs.reverse()
                shape.add(corners, SMOKE, 0.0, "hindwing" + suffix, uvs)
        # Tegmen: a long leaf, arched over the abdomen, from the wing root to past its middle
        long = 1.8
        rows = []
        uvs = []
        across = 5 if LOW else 8
        for i in range(steps + 1):
            t = i / steps
            width = 0.33 * math.sin(math.pi * min(max(t * 0.95 + 0.04, 0.0), 1.0)) ** 0.6
            z = WING_ROOT.z - long * t
            row = []
            for k in range(across + 1):
                f = k / across
                x = side * (0.02 + width * f) - side * 0.16 * (1.0 - t) * 0.0
                # (it lies over the abdomen's back and down its side; the inner edge overlaps the other wing)
                inner = -side * 0.09 * (1.0 - f)
                y = WING_ROOT.y + 0.1 + lift - 0.12 * t - 0.2 * f * f + 0.05 * math.sin(math.pi * t)
                row.append(V(x + inner, y, z))
            rows.append(row)
            uvs.append(t)
        for i in range(steps):
            for k in range(across):
                corners = [rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]]
                uv = [(k / across, uvs[i]), (k / across, uvs[i + 1]), ((k + 1) / across, uvs[i + 1]), ((k + 1) / across, uvs[i])]
                if side < 0:
                    corners.reverse()
                    uv.reverse()
                shape.add(corners, TEGMEN, 0.0, "tegmen" + suffix, uv)


def bones():
    listed = [("root", V(0.0, 0.0, 0.0), None), ("body", BODY, "root"), ("abdomen", ABDOMEN, "body"), ("abdomen_2", ABDOMEN_2, "abdomen"),
              ("pronotum", PRONOTUM, "body"), ("head", NECK, "pronotum")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        m = lambda p: V(p.x * side, p.y, p.z)
        root = HEAD + V(side * 0.035, 0.1, 0.06)
        listed += [("antenna" + suffix, root, "head"), ("antenna_tip" + suffix, root + V(side * 0.18, 0.42, 0.18), "antenna" + suffix)]
        listed += [("coxa" + suffix, m(FORE[0]), "pronotum"), ("femur" + suffix, m(FORE[1]), "coxa" + suffix),
                   ("tibia" + suffix, m(FORE[2]), "femur" + suffix), ("tarsus" + suffix, m(FORE[3]), "tibia" + suffix)]
        listed += [("mid_femur" + suffix, m(MID[0]), "body"), ("mid_tibia" + suffix, m(MID[1]), "mid_femur" + suffix),
                   ("hind_femur" + suffix, m(HIND[0]), "body"), ("hind_tibia" + suffix, m(HIND[1]), "hind_femur" + suffix)]
        listed += [("tegmen" + suffix, m(WING_ROOT + V(0.06, 0.0, 0.0)), "body"), ("hindwing" + suffix, m(WING_ROOT + V(0.06, 0.0, 0.0)), "body")]
    return listed


def make_armature(listed):
    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for name, at, parent in listed:
        bone = data.edit_bones.new(name)
        bone.head = to_blender(at)
        bone.tail = to_blender(at + V(0.0, 0.06, 0.0))
        bone.roll = 0.0
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def build_one(low):
    global LOW
    LOW = low
    name = "mantis" + ("_lo" if low else "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = make_armature(bones())
    shape = Shape()
    head(shape)
    antennae(shape)
    prothorax(shape)
    body(shape)
    abdomen(shape)
    forelegs(shape)
    walking_legs(shape)
    wings(shape)
    points = []
    found = {}
    faces = []
    loops_colour = []
    loops_uv = []
    point_bone = []
    for corners, colour, kind, bone, uvs in shape.faces:
        face = []
        for k, corner in enumerate(corners):
            key = (round(corner.x, 5), round(corner.y, 5), round(corner.z, 5), bone, kind)
            if key not in found:
                found[key] = len(points)
                points.append(to_blender(corner))
                point_bone.append(bone)
            face.append(found[key])
        if len(set(face)) < len(face):
            continue
        faces.append(face)
        for k in range(len(corners)):
            loops_colour.append((linear(colour[0]), linear(colour[1]), linear(colour[2]), kind))
            loops_uv.append(uvs[k] if uvs else (0.0, 0.0))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    colours = mesh.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
    for k, c in enumerate(loops_colour):
        colours.data[k].color = c
    mesh.color_attributes.active_color = colours
    uv = mesh.uv_layers.new(name="wings")
    for k, value in enumerate(loops_uv):
        uv.data[k].uv = value
    for polygon in mesh.polygons:
        polygon.use_smooth = not low
    material = bpy.data.materials.new("mantis")
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.3, 0.35, 0.27, 1.0)
    mesh.materials.append(material)
    body_object = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body_object)
    groups = {bone.name: body_object.vertex_groups.new(name=bone.name) for bone in armature.data.bones}
    for index, bone in enumerate(point_bone):
        groups[bone].add([index], 1.0, "REPLACE")
    body_object.parent = armature
    body_object.modifiers.new("Armature", "ARMATURE").object = armature
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True,
                              export_animations=False, export_skins=True, export_vertex_color="ACTIVE")
    mesh.calc_loop_triangles()
    print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), len(mesh.loop_triangles)))
    if PREVIEW and not low:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(PREVIEW, name + ".blend"))
        render(PREVIEW, name)


def render(folder, name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    views = [("side", (1, 0, 0.05), (0.0, 0.0, 1.5), 4.2), ("quarter", (0.7, -0.7, 0.25), (0.0, 0.0, 1.5), 4.2),
             ("front", (0.02, -1, 0.1), (0.0, 0.0, 1.6), 3.4), ("top", (0.05, 0.0, 1), (0.0, 0.0, 1.0), 4.2),
             ("head", (0.4, -0.9, 0.1), (0.0, -0.9, 2.65), 1.2)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 8.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for low in (False, True):
        build_one(low)
