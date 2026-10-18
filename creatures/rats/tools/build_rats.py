"""Builds the rats (creatures/rats/) and exports them for Godot.

Run from the project root:
    blender --background --python creatures/rats/tools/build_rats.py
then, so that Godot takes up the new models:
    godot --headless --path . --import

Writes creatures/rats/models/rat.glb (the rat in full, about 1500 triangles, and the knot of a rat king's tails) and
creatures/rats/models/rat_lo.glb (the rat for a swarm, a few hundred at once: about 200 triangles). With
KEEP_BLEND=<path.blend> set, it saves a .blend there to look at and change by hand.

The rat is a brown rat (Rattus norvegicus), in metres, standing on the ground at the origin and facing the game's
+Z (x to its left, y up), about 24 cm from nose to rump with a tail nearly as long again:

    the body      a hunched, pear-shaped trunk, highest over the hips and heavy behind, a short thick neck, the head
                  tapering to a blunt snout (blunter than a mouse's), the rump rounding down into the tail
    the head      big rounded ears standing up and back, small black bead eyes, a pink nose, two yellow-orange
                  incisors under it, a lower jaw that opens (for squealing), whiskers fanning out from the snout
    the legs      short front legs with small pink hands; hind legs folded in big haunches, on long pink feet
    the tail      thick at the root and tapering to a point, scaly and near naked (the shader rings it)

The game draws them in one shader (rat.gdshader) that poses them: the gait, the arch of the back, rearing up to
sniff, the head, the jaw, the whiskers and the tail. It is told what each point is by the mesh's two UV maps:

    UV  (the first)   U: which part, in sixteenths (0 the body, 1 the head, 2 a whisker, 3 the jaw, 4 and 5 the
                      left and right front leg, 6 and 7 the left and right hind leg, 8 the tail, 15 not posed);
                      V: how far out along it (0 at the root, 1 at the tip; along the body, 0 at the rump and 1 at
                      the nose)
    UV2 (the second)  U: its colour, in eighths (0 fur, 1 bare pink skin, 2 the tail, 3 an eye, 4 a tooth,
                      5 a whisker, 6 the filth of a rat king's knot, 7 the inside of the mouth);
                      V: how pale the fur is there (0 on the back, 1 the belly)

(V is turned over on the way out of Blender: 1 - v here is v in the game.) Where the parts turn is printed and
written to models/rat.json; rat.gdshader has the same numbers (keep them in step).
"""

import bpy
import json
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BODY, HEAD, WHISKER, JAW, FORE_L, FORE_R, HIND_L, HIND_R, TAIL, RIGID = 0, 1, 2, 3, 4, 5, 6, 7, 8, 15
FUR, SKIN, TAIL_SKIN, EYE, TOOTH, WHISKER_HAIR, FILTH, MOUTH = 0, 1, 2, 3, 4, 5, 6, 7

# Where the parts turn (the shader's constants).
PIVOTS = {
    "shoulder_l": (0.019, 0.047, 0.04),
    "hip_l": (0.026, 0.05, -0.058),
    "neck": (0.0, 0.056, 0.07),
    "jaw": (0.0, 0.037, 0.11),
    "tail": (0.0, 0.04, -0.104),
    "haunch": (0.0, 0.02, -0.07),
}


def to_blender(p):
    return (p[0], -p[2], p[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def times(a, by):
    return (a[0] * by, a[1] * by, a[2] * by)


def mix(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def length(a):
    return math.sqrt(dot(a, a))


def unit(a):
    size = length(a)
    return (a[0] / size, a[1] / size, a[2] / size) if size > 1e-9 else (0.0, 1.0, 0.0)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def spline(points, t):
    """A Catmull-Rom curve through `points`, at `t` (0 to 1) of the way along it."""
    count = len(points) - 1
    f = max(0.0, min(0.99999, t)) * count
    k = int(f)
    u = f - k
    p0 = points[max(k - 1, 0)]
    p1 = points[k]
    p2 = points[min(k + 1, count)]
    p3 = points[min(k + 2, count)]
    out = []
    for c in range(3):
        a, b, cc, d = p0[c], p1[c], p2[c], p3[c]
        out.append(0.5 * ((2 * b) + (-a + cc) * u + (2 * a - 5 * b + 4 * cc - d) * u * u + (-a + 3 * b - 3 * cc + d) * u * u * u))
    return tuple(out)


class Shape:
    """Points and faces being gathered for one model. Each point has its place and its two UVs (as the game reads
    them); parts made separately share no points, so each is smoothed on its own."""

    def __init__(self):
        self.points = []
        self.uv = []
        self.uv2 = []
        self.faces = []

    def point(self, p, uv, uv2):
        self.points.append(p)
        self.uv.append(uv)
        self.uv2.append(uv2)
        return len(self.points) - 1

    def face(self, corners):
        self.faces.append(corners)

    def loft(self, rings, part, paint, along=None, pale=None, cap_start=True, cap_end=True):
        """A tube through `rings`: each a list of points the same length, going round. `along`(k) is how far out
        along the part ring k is, `pale`(point) how pale the fur is there. The ends are closed to a point."""
        around = len(rings[0])
        index = []
        for k, ring in enumerate(rings):
            row = []
            a = along(k) if along else k / max(len(rings) - 1, 1)
            for p in ring:
                row.append(self.point(p, (part, a), (paint, pale(p) if pale else 0.0)))
            index.append(row)
        for k in range(len(rings) - 1):
            for j in range(around):
                n = (j + 1) % around
                self.face([index[k][j], index[k][n], index[k + 1][n], index[k + 1][j]])
        for end, row, forward in ((cap_start, index[0], False), (cap_end, index[-1], True)):
            if not end:
                continue
            ring = [self.points[i] for i in row]
            middle = tuple(sum(p[c] for p in ring) / around for c in range(3))
            k = 0 if not forward else len(rings) - 1
            a = along(k) if along else (1.0 if forward else 0.0)
            tip = self.point(middle, (part, a), (paint, pale(middle) if pale else 0.0))
            for j in range(around):
                n = (j + 1) % around
                self.face([row[j], tip, row[n]] if not forward else [row[n], tip, row[j]])


def ring_at(centre, side, up, half_w, half_h, around, flat_belly=0.0, phase=0.0):
    """Points round an ellipse at `centre`, in the plane of `side` and `up` (half widths `half_w`, `half_h`); its
    lower half flattened by `flat_belly`."""
    points = []
    for j in range(around):
        turn = math.tau * j / around + phase
        c = math.cos(turn)
        s = math.sin(turn)
        if s < 0.0:
            s *= 1.0 - flat_belly
        # (a little squarer than an ellipse: fur over muscle, not a tube)
        cs = math.copysign(abs(c) ** 0.85, c)
        ss = math.copysign(abs(s) ** 0.9, s)
        points.append(add(centre, add(times(side, cs * half_w), times(up, ss * half_h))))
    return points


# --- The rat ---

# The body and head, from the root of the tail to the tip of the nose, in the side view: [z, the middle's height,
# half the height, half the width]. Highest over the hips, the head tapering to a blunt snout.
PROFILE = [
    (-0.112, 0.041, 0.010, 0.010),
    (-0.104, 0.046, 0.024, 0.022),
    (-0.09, 0.052, 0.035, 0.032),
    (-0.07, 0.058, 0.041, 0.039),
    (-0.048, 0.061, 0.043, 0.041),
    (-0.024, 0.06, 0.04, 0.037),
    (0.0, 0.057, 0.035, 0.032),
    (0.024, 0.054, 0.031, 0.028),
    (0.046, 0.053, 0.027, 0.024),
    (0.066, 0.054, 0.023, 0.021),
    (0.082, 0.055, 0.021, 0.021),
    (0.096, 0.052, 0.018, 0.018),
    (0.11, 0.0485, 0.0145, 0.0135),
    (0.122, 0.0445, 0.011, 0.0098),
    (0.132, 0.0415, 0.0078, 0.007),
    (0.139, 0.0398, 0.0048, 0.0044),
]
NECK_Z = 0.07


def body(s, lo):
    """The trunk and the head in one loft (the head is its own part from the neck on, so that it turns; the rings
    either side of the neck are both, half and half, by their points)."""
    profile = PROFILE if not lo else [PROFILE[i] for i in (0, 2, 4, 6, 8, 10, 12, 15)]
    around = 12 if not lo else 6
    trunk = []
    head = []
    for z, y, hh, hw in profile:
        ring = ring_at((0.0, y, z), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), hw, hh, around, 0.22 if z < 0.06 else 0.1, math.pi * 0.5 / around if lo else 0.0)
        if z <= NECK_Z + 0.001:
            trunk.append(ring)
        else:
            if not head:
                # (the head starts from the last ring of the trunk: the shader turns it less the nearer the neck)
                head.append(trunk[-1])
            head.append(ring)
    span = profile[-1][0] - profile[0][0]

    def pale(p):
        # (paler down the flanks and on the belly and throat)
        return smooth((0.052 - p[1]) / 0.03) * 0.9 + (0.1 if p[2] > 0.09 and p[1] < 0.045 else 0.0)
    count = len(trunk)
    s.loft(trunk, BODY, FUR, lambda k: (profile[k][0] - profile[0][0]) / span, pale, True, False)
    first = len(profile) - len(head)
    s.loft(head, HEAD, FUR, lambda k: 0.0, pale, False, lo)
    if lo:
        return
    # The pink nose: a little rounded pad over the end of the snout.
    tip_z, tip_y, tip_h, tip_w = profile[-1]
    nose = []
    for k, (zz, hh) in enumerate(((tip_z - 0.003, 1.0), (tip_z + 0.002, 0.9), (tip_z + 0.006, 0.55), (tip_z + 0.008, 0.0))):
        nose.append(ring_at((0.0, tip_y + 0.001, zz), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), 0.0058 * hh + 0.0004, 0.0052 * hh + 0.0004, 8 if not lo else 4))
    s.loft(nose, HEAD, SKIN, lambda k: 0.0, None, True, True)
    return count


def ears(s, lo):
    """Big, rounded, thin ears, standing up and a little back and out, cupped forward; pink-grey inside."""
    for side in (-1.0, 1.0):
        root = (side * 0.013, 0.069, 0.083)
        # (the way the ear faces: forward and out; its up: up and back)
        facing = unit((side * 0.55, 0.15, 1.0))
        up = unit((side * 0.35, 1.0, -0.45))
        across = unit(cross(up, facing))
        steps = 7 if not lo else 3
        rim = []
        for j in range(steps + 1):
            t = j / steps
            turn = math.pi * t
            # (rounder at the top, a broad root)
            high = 0.0155 * math.sin(turn) ** 0.8
            rim.append(add(root, add(times(across, math.cos(turn) * 0.0103), times(up, high))))
        middle = add(root, times(up, 0.006))
        cup = times(facing, -0.003)
        for paint, out, flip in ((FUR, times(facing, -0.0012), False), (SKIN, times(facing, 0.0006), True)):
            centre = s.point(add(add(middle, cup), out), (HEAD, 0.0), (paint, 1.0 if paint == SKIN else 0.3))
            points = [s.point(add(p, out), (HEAD, 0.0), (paint, 1.0 if paint == SKIN else 0.3)) for p in rim]
            for j in range(steps):
                if flip:
                    s.face([centre, points[j], points[j + 1]])
                else:
                    s.face([centre, points[j + 1], points[j]])
            base = [points[0], points[-1]]
            if flip:
                s.face([centre, base[1], base[0]])
            else:
                s.face([centre, base[0], base[1]])


def eyes(s, lo):
    """Small black bead eyes, set into the sides of the head."""
    for side in (-1.0, 1.0):
        middle = (side * 0.0122, 0.0585, 0.102)
        radius = 0.0036
        if lo:
            # (far off, a dark diamond on the side of the head)
            out = add(middle, (side * 0.0022, 0.0, 0.0))
            corners = [add(out, (0.0, radius, 0.0)), add(out, (0.0, 0.0, radius)), add(out, (0.0, -radius, 0.0)), add(out, (0.0, 0.0, -radius))]
            idx = [s.point(p, (HEAD, 0.0), (EYE, 0.0)) for p in corners]
            s.face(idx if side > 0 else list(reversed(idx)))
            continue
        steps = 4
        rings = []
        for k in range(steps + 1):
            a = math.pi * k / steps
            r = max(math.sin(a) * radius, 0.0002)
            rings.append(ring_at(add(middle, (0.0, 0.0, -math.cos(a) * radius)), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), r, r, 8 if not lo else 4))
        s.loft(rings, HEAD, EYE, lambda k: 0.0, None, False, False)


def mouth(s, lo):
    """The incisors, two yellow-orange chisels under the nose; and the lower jaw (its own part, that opens), with its
    two lower incisors and the dark of the mouth behind."""
    tip_z = PROFILE[-1][0]
    for side in (-1.0, 1.0):
        x = side * 0.0016
        top = (x, 0.0345, tip_z - 0.0045)
        low = (x + side * 0.0002, 0.0285, tip_z - 0.0025)
        w = 0.0014
        corners = [add(top, (-w, 0.0, 0.0)), add(top, (w, 0.0, 0.0)), add(low, (w, 0.0, 0.001)), add(low, (-w, 0.0, 0.001))]
        idx = [s.point(p, (HEAD, 0.0), (TOOTH, 0.0)) for p in corners]
        s.face(idx)
        if not lo:
            s.face(list(reversed(idx)))
    # The lower jaw: a short, narrow wedge under the snout, from the jaw's hinge to just behind the nose.
    jaw = PIVOTS["jaw"]
    rings = []
    count = 3 if not lo else 1
    for k in range(count + 1):
        t = k / count
        z = lerp(jaw[2] - 0.006, tip_z - 0.007, t)
        y = lerp(jaw[1] - 0.003, 0.0305, t)
        half = lerp(0.0075, 0.0026, t)
        rings.append(ring_at((0.0, y, z), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), half, half * 0.55, 8 if not lo else 4, 0.0))
    if lo:
        return
    s.loft(rings, JAW, FUR, lambda k: k / count, lambda p: 1.0, True, True)
    if not lo:
        # (the dark of the open mouth, a pad on top of the jaw seen when it drops; and its two lower teeth)
        roof = [(-0.005, 0.0345, jaw[2] - 0.004), (0.005, 0.0345, jaw[2] - 0.004), (0.0025, 0.032, tip_z - 0.006), (-0.0025, 0.032, tip_z - 0.006)]
        idx = [s.point(p, (JAW, 0.5), (MOUTH, 0.0)) for p in roof]
        s.face(idx)
        s.face(list(reversed(idx)))
        for side in (-1.0, 1.0):
            x = side * 0.0013
            corners = [(x - 0.001, 0.0305, tip_z - 0.0068), (x + 0.001, 0.0305, tip_z - 0.0068), (x + 0.001, 0.034, tip_z - 0.005), (x - 0.001, 0.034, tip_z - 0.005)]
            idx = [s.point(p, (JAW, 1.0), (TOOTH, 0.0)) for p in corners]
            s.face(idx)
            s.face(list(reversed(idx)))


def whiskers(s):
    """Long whiskers fanning out from the snout, each a thin strip on edge, curving back a little."""
    rng = random.Random(7)
    for side in (-1.0, 1.0):
        for k in range(6):
            root = (side * 0.0075, 0.037 - k * 0.0012, 0.129 - (k % 3) * 0.003)
            spread = lerp(-0.35, 0.45, k / 5.0) + rng.uniform(-0.08, 0.08)
            long = rng.uniform(0.04, 0.058)
            out = unit((side * 1.0, spread, 0.55 - k * 0.12))
            bend = unit((side * 0.6, spread * 0.7 - 0.2, -0.6))
            steps = 3
            strip = []
            for j in range(steps + 1):
                t = j / steps
                p = add(root, add(times(out, long * t), times(bend, long * 0.25 * t * t)))
                w = lerp(0.0007, 0.00012, t)
                strip.append((add(p, (0.0, w, 0.0)), add(p, (0.0, -w, 0.0)), t))
            idx = []
            for a, b, t in strip:
                idx.append((s.point(a, (WHISKER, t), (WHISKER_HAIR, 0.0)), s.point(b, (WHISKER, t), (WHISKER_HAIR, 0.0))))
            for j in range(steps):
                s.face([idx[j][0], idx[j + 1][0], idx[j + 1][1], idx[j][1]])
                s.face([idx[j][1], idx[j + 1][1], idx[j + 1][0], idx[j][0]])


def limb(s, part, chain, radii, paint_at, around, along_at):
    """A leg: a tube through the points of `chain` (smoothed), `radii` at each, the colour each ring takes from
    `paint_at`(t) (fur down to the wrist or the heel, then the pink of the hand or the foot)."""
    rings = []
    count = (len(chain) - 1) * (3 if around > 4 else 1)
    pieces = []
    for k in range(count + 1):
        t = k / count
        p = spline(chain, t)
        q = spline(chain, min(t + 0.02, 1.0)) if t < 1.0 else p
        d = unit(sub(q, p)) if t < 1.0 else unit(sub(p, spline(chain, t - 0.02)))
        side = unit(cross(d, (0.0, 1.0, 0.0)))
        if length(cross(d, (0.0, 1.0, 0.0))) < 0.2:
            side = unit(cross(d, (0.0, 0.0, 1.0)))
        up = unit(cross(side, d))
        f = t * (len(radii) - 1)
        i = min(int(f), len(radii) - 2)
        r = lerp(radii[i], radii[i + 1], f - i)
        rings.append(ring_at(p, side, up, r, r * 0.9, around, 0.0))
        pieces.append(t)
    # (each ring its own colour: split where the fur ends)
    start = 0
    for k in range(1, len(rings) + 1):
        if k == len(rings) or paint_at(pieces[k]) != paint_at(pieces[start]):
            stop = min(k, len(rings) - 1)
            part_rings = rings[start:stop + 1]
            ts = pieces[start:stop + 1]
            if len(part_rings) >= 2:
                s.loft(part_rings, part, paint_at(pieces[start]), lambda j, ts=ts: along_at(ts[j]), lambda p: 0.5, start == 0 and around > 3, stop == len(rings) - 1)
            start = stop
            if k == len(rings):
                break


def toes(s, part, at, forward, count, long, wide, around, along):
    """Small pink toes fanning out from `at` along `forward`."""
    side = unit(cross(forward, (0.0, 1.0, 0.0)))
    for k in range(count):
        spread = lerp(-1.0, 1.0, k / max(count - 1, 1))
        way = unit(add(forward, times(side, spread * 0.45)))
        root = add(at, times(side, spread * wide))
        end = add(root, times(way, long * (1.0 - abs(spread) * 0.25)))
        end = (end[0], 0.0015, end[2])
        rings = [ring_at(mix(root, end, t), side, (0.0, 1.0, 0.0), 0.0016 * (1.0 - t * 0.5), 0.0014 * (1.0 - t * 0.5), around, 0.0) for t in (0.0, 1.0)]
        s.loft(rings, part, SKIN, lambda j: along, None, False, True)


def legs(s, lo):
    around = 6 if not lo else 3
    for side in (-1.0, 1.0):
        m = lambda p: (p[0] * side, p[1], p[2])
        fore = FORE_L if side > 0 else FORE_R
        hind = HIND_L if side > 0 else HIND_R
        sh = PIVOTS["shoulder_l"]
        # The front leg: out of the chest, the elbow back, the wrist forward, the little hand flat on the ground.
        chain = [m(sh), m((0.022, 0.03, 0.03)), m((0.022, 0.012, 0.046)), m((0.021, 0.004, 0.056))] if not lo else [m(sh), m((0.022, 0.026, 0.032)), m((0.021, 0.004, 0.056))]
        limb(s, fore, chain, [0.0095, 0.0068, 0.0042, 0.0034] if not lo else [0.009, 0.006, 0.0035], lambda t: (FUR if t < 0.68 else SKIN) if not lo else FUR, around, lambda t: t * 0.92)
        if not lo:
            toes(s, fore, m((0.021, 0.0025, 0.057)), unit((side * 0.15, 0.0, 1.0)), 4, 0.0065, 0.0024, 4, 1.0)
        # The hind leg: the haunch (a broad thigh folded against the body), the shin down and back to the heel,
        # and the long pink foot flat on the ground, forward.
        hp = PIVOTS["hip_l"]
        haunch = [m(hp), m((0.031, 0.036, -0.045)), m((0.03, 0.02, -0.07)), m((0.028, 0.006, -0.082))] if not lo else [m(hp), m((0.031, 0.032, -0.05)), m((0.028, 0.006, -0.082))]
        limb(s, hind, haunch, [0.02, 0.016, 0.0085, 0.0045] if not lo else [0.019, 0.013, 0.005], lambda t: FUR, around, lambda t: t * 0.5)
        foot = [m((0.028, 0.005, -0.084)), m((0.029, 0.0035, -0.066)), m((0.03, 0.003, -0.05))] if not lo else [m((0.028, 0.005, -0.084)), m((0.03, 0.003, -0.05))]
        limb(s, hind, foot, [0.0048, 0.0046, 0.0036], lambda t: SKIN, around if not lo else 3, lambda t: 0.6 + t * 0.4)
        if not lo:
            toes(s, hind, m((0.03, 0.0028, -0.051)), unit((side * 0.2, 0.0, 1.0)), 5, 0.009, 0.0032, 4, 1.0)


def tail(s, lo):
    """From the rump back and down to the ground, then lying along it in a slight curve: thick at the root, to a
    point. It is all one colour (the shader rings it with scales)."""
    root = PIVOTS["tail"]
    chain = [(0.0, root[1], root[2] + 0.004), (0.0, 0.03, -0.122), (0.0, 0.012, -0.148), (0.006, 0.006, -0.19), (0.014, 0.005, -0.24), (0.012, 0.004, -0.285), (0.004, 0.0035, -0.31)]
    count = 22 if not lo else 5
    around = 6 if not lo else 3
    rings = []
    for k in range(count + 1):
        t = k / count
        p = spline(chain, t)
        q = spline(chain, min(t + 0.01, 1.0))
        d = unit(sub(q, p)) if t < 1.0 else unit(sub(p, spline(chain, t - 0.01)))
        side = unit(cross(d, (0.0, 1.0, 0.0)))
        up = unit(cross(side, d))
        r = lerp(0.0068, 0.0009, t ** 0.85)
        rings.append(ring_at(p, side, up, r, r, around, 0.0))
    s.loft(rings, TAIL, TAIL_SKIN, lambda k: k / count, None, not lo, True)
    return chain


def rat(lo):
    s = Shape()
    body(s, lo)
    ears(s, lo)
    eyes(s, lo)
    mouth(s, lo)
    if not lo:
        whiskers(s)
    legs(s, lo)
    tail(s, lo)
    return s


# --- The knot of a rat king ---

def knot():
    """Where the tails of a rat king are fused and tangled: a matted lump of tails, dirt and old blood at the
    middle, and tails looping round and through it every way, each tapering off into the tangle. Not posed (part
    15), about 14 cm across and 6 high, standing on the ground at the origin."""
    s = Shape()
    rng = random.Random(13)
    # The matted lump: a squashed ball, its surface lumped and creased.
    rings = []
    around = 14
    for k in range(1, 8):
        a = math.pi * k / 8.0
        ring = []
        for j in range(around):
            turn = math.tau * j / around
            lump = 1.0 + 0.18 * math.sin(turn * 3.0 + k * 1.7) * math.sin(a * 2.0) + rng.uniform(-0.08, 0.08)
            r = math.sin(a) * 0.03 * lump
            ring.append((math.cos(turn) * r, 0.028 - math.cos(a) * 0.024 * lump, math.sin(turn) * r))
        rings.append(ring)
    s.loft(list(reversed(rings)), RIGID, FILTH, lambda k: 0.0, None, True, True)
    # Tails: loops of tail through and round it, each a tube on a curve through points about the lump.
    for strand in range(13):
        points = []
        start_turn = rng.uniform(0.0, math.tau)
        for k in range(6):
            turn = start_turn + k * rng.uniform(0.7, 1.3) * (1.0 if strand % 2 else -1.0)
            far = rng.uniform(0.02, 0.062)
            points.append((math.cos(turn) * far, rng.uniform(0.006, 0.058), math.sin(turn) * far))
        count = 11
        tube = []
        for k in range(count + 1):
            t = k / count
            p = spline(points, t)
            q = spline(points, min(t + 0.01, 1.0))
            d = unit(sub(q, p)) if t < 1.0 else unit(sub(p, spline(points, t - 0.01)))
            side = unit(cross(d, (0.0, 1.0, 0.0)))
            up = unit(cross(side, d))
            r = 0.0062 * (1.0 - 0.75 * abs(t - 0.4) / 0.6)
            tube.append(ring_at(p, side, up, r, r, 5, 0.0))
        # (its scales as close as on a rat's own tail: along it by its length)
        span = sum(length(sub(spline(points, (k + 1) / 20.0), spline(points, k / 20.0))) for k in range(20)) / 0.21
        s.loft(tube, RIGID, TAIL_SKIN, lambda k, count=count, span=span: k / count * span, None, True, True)
    return s


# --- Putting it together ---

def mesh_of(name, shape):
    points = [to_blender(p) for p in shape.points]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], shape.faces)
    mesh.validate()
    mesh.update()
    first = mesh.uv_layers.new(name="part")
    second = mesh.uv_layers.new(name="paint")
    for poly in mesh.polygons:
        poly.use_smooth = True
        for loop in poly.loop_indices:
            v = mesh.loops[loop].vertex_index
            u1 = shape.uv[v]
            u2 = shape.uv2[v]
            # (the part in sixteenths, the colour in eighths, taken from their middles; V turned over)
            first.data[loop].uv = ((u1[0] + 0.5) / 16.0, 1.0 - u1[1])
            second.data[loop].uv = ((u2[0] + 0.5) / 8.0, 1.0 - u2[1])
    material = bpy.data.materials.get("rat") or bpy.data.materials.new("rat")
    mesh.materials.append(material)
    return mesh


def export(objects, path):
    bpy.ops.object.select_all(action="DESELECT")
    for made in objects:
        made.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        use_selection=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="PLACEHOLDER",
    )


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    counts = {}
    made = {}
    for name, shape, x in (("rat", rat(False), 0.0), ("rat_lo", rat(True), 0.3), ("knot", knot(), 0.6)):
        thing = bpy.data.objects.new(name, mesh_of(name, shape))
        bpy.context.collection.objects.link(thing)
        thing.data.calc_loop_triangles()
        counts[name] = len(thing.data.loop_triangles)
        made[name] = thing
    models = os.path.join(ROOT, "models")
    os.makedirs(models, exist_ok=True)
    if os.environ.get("KEEP_BLEND"):
        bpy.ops.wm.save_as_mainfile(filepath=os.environ["KEEP_BLEND"])
    export([made["rat"], made["knot"]], os.path.join(models, "rat.glb"))
    export([made["rat_lo"]], os.path.join(models, "rat_lo.glb"))
    pivots = dict(PIVOTS)
    with open(os.path.join(models, "rat.json"), "w") as out:
        json.dump({"pivots": pivots, "triangles": counts}, out, indent=1)
    print("PIVOTS", pivots)
    print("BUILT rats: the rat %d triangles, the low one %d, the knot %d" % (counts["rat"], counts["rat_lo"], counts["knot"]))


build()
