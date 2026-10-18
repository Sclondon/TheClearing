"""Builds the feral dogs (creatures/dog) and exports them for Godot.

Run from the project root:
    blender --background --python tools/build_dog.py
    blender --background --python tools/build_dog.py -- <preview folder> dog_a   # just one, with pictures

Writes creatures/dog/models/dog_a.glb and dog_b.glb, and a demade `_lo`
version of each. Nothing else is written (an editable .blend goes to the
preview folder, when there is one).

They are the half-starved hunting dogs of the maze: a mastiff crossed with a
lurcher. A sighthound's frame (a deep narrow chest tucked up hard to a thin
loin, long legs, a long low-carried tail) under a mastiff's head (a broad
skull, heavy brow and cheeks, a short deep muzzle, loose upper lips that can
be pulled back off the teeth). Hunger shows: the ribs stand out along the
flanks, the hip bones and the spine are knobs under the skin, and the coat is
dark grey-brown, matted, and bare in patches (the patches are the shader's,
see dog_fur.gd). Each has scars, and one ear cut short; `dog_a` and `dog_b`
differ in which ear and which scars.

Along its neck and back lies a crest of coarse hair (material `crest`) that
the shader raises when it bristles; its upper lips are weighted to bones of
their own (`lip_l`, `lip_r`) that the rig lifts to snarl, which bares gums
(`gum`) and a full set of teeth.

The bones are the hounds' (Outside's tools/build_hound.py), with the same
names, so the same kind of rig drives them (creatures/dog/dog_rig.gd). Each leg
is three bones and a paw, as a dog's is:

    fore: `upper` (shoulder to elbow), `lower` (forearm), `hock` (pastern), `paw`
    hind: `upper` (thigh, hip to stifle), `lower` (shank), `hock` (hock to paw), `paw`

The coat carries vertex colours the shader reads: red is how open the surface
is (dark in the grooves between the ribs, round the eyes, under the jaw), blue
how far it is the paler underside (chest, belly, inside the legs, the muzzle).

Everything is in Godot space (metres, Y up, facing +Z, +X its left). Uses
tools/build_character.py (from GameCommon's character-controller) for its
shape-building.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
SUFFIXES = ("_fl", "_fr", "_rl", "_rr")
ROOT = kit.ROOT
OUT = os.path.join(ROOT, "creatures", "dog", "models")


def V(x, y, z):
    return Vector((x, y, z))


class Breed:
    def __init__(self, **spec):
        self.__dict__.update(spec)
        self.skull = self.head + self.skull_at
        self.jaw = self.skull + self.jaw_at
        self.ear = [self.skull + offset for offset in self.ear_at]
        self.tail = [self.tail_root + V(*offset) for offset in self.tail_at]
        self.neck_1 = self.neck.lerp(self.head, 0.5)
        self.legs = {}
        for suffix in SUFFIXES:
            side = 1.0 if suffix[2] == "l" else -1.0
            self.legs[suffix] = [V(j.x * side, j.y, j.z) for j in (self.fore if suffix[1] == "f" else self.hind)]


def feral(name, cropped, scars):
    return Breed(
        name=name,
        # Which ear is cut short (1 its left, -1 its right), and which set of scars it has.
        cropped=cropped,
        scars=scars,
        body=V(0.0, 0.60, 0.0), chest=V(0.0, 0.62, 0.20), pelvis=V(0.0, 0.61, -0.22),
        # (along the body, centre height, half width, half height): a deep narrow chest,
        # the belly tucked up hard behind it into a thin loin, a slight arch over it
        trunk=[(-0.36, 0.650, 0.040, 0.050), (-0.31, 0.640, 0.068, 0.080), (-0.22, 0.630, 0.077, 0.090),
               (-0.12, 0.650, 0.056, 0.064), (-0.03, 0.634, 0.064, 0.086), (0.06, 0.594, 0.080, 0.128),
               (0.16, 0.562, 0.090, 0.166), (0.25, 0.574, 0.088, 0.152), (0.31, 0.606, 0.074, 0.116),
               (0.355, 0.638, 0.056, 0.082)],
        # Shoulder, elbow, wrist, paw; hip, stifle, hock, paw (the left legs: the right are their mirror)
        fore=[V(0.072, 0.565, 0.265), V(0.072, 0.395, 0.195), V(0.072, 0.150, 0.212), V(0.072, 0.030, 0.230)],
        hind=[V(0.068, 0.585, -0.260), V(0.068, 0.405, -0.160), V(0.068, 0.190, -0.350), V(0.068, 0.030, -0.343)],
        # (how far down the leg, counted in joints; half width; half depth; forward offset)
        fore_shape=[(-0.3, 0.033, 0.056, 0.0), (0.0, 0.036, 0.062, 0.0), (0.5, 0.033, 0.050, 0.0), (1.0, 0.028, 0.040, -0.004),
                    (1.25, 0.026, 0.035, 0.0), (1.6, 0.023, 0.028, 0.0), (2.0, 0.022, 0.026, 0.0), (2.5, 0.021, 0.024, 0.0),
                    (3.0, 0.023, 0.026, 0.003)],
        hind_shape=[(-0.25, 0.034, 0.074, 0.0), (0.0, 0.040, 0.092, 0.0), (0.45, 0.039, 0.082, 0.0), (0.85, 0.032, 0.054, 0.004),
                    (1.0, 0.029, 0.045, 0.004), (1.3, 0.026, 0.040, -0.004), (1.7, 0.020, 0.027, 0.0), (2.0, 0.020, 0.028, -0.003),
                    (2.3, 0.018, 0.022, 0.0), (2.7, 0.018, 0.021, 0.0), (3.0, 0.021, 0.024, 0.003)],
        paw=(0.030, 0.046),
        muscle=0.85,
        # A thick neck carried low and forward
        neck=V(0.0, 0.662, 0.295), head=V(0.0, 0.805, 0.470),
        # (how far up the neck, radius, how far the throat hangs under it)
        neck_shape=[(-0.3, 0.080, 0.0), (0.0, 0.074, 0.006), (0.35, 0.066, 0.010), (0.7, 0.060, 0.008), (1.0, 0.056, 0.0), (1.15, 0.048, 0.0)],
        skull_at=V(0.0, 0.024, 0.032), skull_size=V(0.068, 0.058, 0.082),
        # (along the muzzle from the skull, height, half width, half height): short, deep, a little blunt
        muzzle=[(0.035, -0.006, 0.052, 0.048), (0.09, -0.012, 0.046, 0.042), (0.145, -0.016, 0.041, 0.037), (0.192, -0.018, 0.035, 0.032)],
        nose=(V(0.0, -0.003, 0.204), V(0.022, 0.015, 0.013)),
        jaw_at=V(0.0, -0.034, 0.000),
        jaw_shape=[(-0.01, -0.045, 0.044, 0.020), (0.08, -0.054, 0.037, 0.016), (0.17, -0.056, 0.028, 0.013)],
        # The line the teeth meet on, the length of the mouth, and its half width at the fangs and at the back
        mouth=(-0.054, 0.188, 0.021, 0.035),
        eye=(V(0.039, 0.015, 0.062), 0.0108),
        # Each ear: where it roots, the joint part way along it, and its end. Rose ears:
        # they rise, and their tops fold back along the head.
        ear_at=[V(0.044, 0.040, -0.030), V(0.068, 0.080, -0.052), V(0.092, 0.084, -0.092)],
        tail_root=V(0.0, 0.645, -0.360),
        tail_at=[(0.0, 0.0, 0.0), (0.0, -0.09, -0.07), (0.0, -0.20, -0.105), (0.0, -0.31, -0.115), (0.0, -0.40, -0.095)],
        tail_shape=[0.026, 0.023, 0.019, 0.015, 0.011, 0.007],
    )


DOGS = [feral("dog_a", -1.0, 0), feral("dog_b", 1.0, 1)]


def trunk_at(breed, z):
    """The trunk's (centre height, half width, half height) at `z` along it."""
    rings = breed.trunk
    if z <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return rings[-1][1:]


def on_flank(breed, side, z, rise, out=0.0):
    """A point on the side of the trunk at `z`, `rise` of the way from its middle to its top (negative: down)."""
    y, rx, ry = trunk_at(breed, z)
    rise = max(min(rise, 0.98), -0.98)
    return V(side * (rx * math.sqrt(1.0 - rise * rise) + out), y + ry * rise, z)


def chain_param(p, joints):
    """The nearest point to `p` on a line of joints: (how far off it, how far along it counted in joints)."""
    best = (1e9, 0.0)
    for i in range(len(joints) - 1):
        a, b = joints[i], joints[i + 1]
        ab = b - a
        t = min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)
        d = (p - (a + ab * t)).length
        if d < best[0]:
            best = (d, i + t)
    return best


def leg_share(breed, p):
    """Which leg a point is nearest, and how much of it hangs from that leg rather than the trunk."""
    suffix = ("_f" if p.z > 0.0 else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = breed.legs[suffix]
    top = joints[0]
    off = chain_param(V(top.x, p.y, p.z), joints)[0]
    return suffix, blend(top.y + 0.03, top.y - 0.09, p.y) * blend(0.075, 0.045, math.hypot(p.x - top.x, off / 1.8))


def leg_axis(joints, y):
    for a, b in zip(joints, joints[1:]):
        if y >= b.y:
            return a.z + (b.z - a.z) * min(max((a.y - y) / (a.y - b.y), 0.0), 1.0)
    return joints[-1].z


def lay_fur(breed, bm, ears=False):
    """The texture coordinates the fur shader reads: (along the lie of the hair,
    across it), in metres. The hair lies back from the nose to the tail, and
    down each leg and ear (as Outside's hounds)."""
    uv = bm.loops.layers.uv.verify()

    def around(x, y, near_x, near_y, radius):
        near = math.atan2(near_x, near_y)
        return (near + (math.atan2(x, y) - near + math.pi) % math.tau - math.pi) * radius

    def axis(z):
        return breed.body.y + 0.01 + (breed.head.y + 0.02 - breed.body.y) * blend(breed.neck.z - 0.02, breed.head.z, z)

    for face in bm.faces:
        near = kit.from_blender(face.calc_center_median())
        suffix, _ = leg_share(breed, near)
        joints = breed.legs[suffix]
        hip = joints[0]
        out = 1.0 if hip.x > 0.0 else -1.0
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            if ears:
                root = breed.ear[0]
                loop[uv].uv = ((p - V(root.x * (1.0 if p.x >= 0.0 else -1.0), root.y, root.z)).length - 2.0, p.z)
                continue
            leg = leg_share(breed, p)[1]
            trunk = (-p.z, around(p.x, p.y - axis(p.z), near.x, near.y - axis(near.z), 0.10))
            limb_uv = (hip.y - p.y - hip.z, around(p.z - leg_axis(joints, p.y), (p.x - hip.x) * out,
                                                  near.z - leg_axis(joints, near.y), (near.x - hip.x) * out, 0.035))
            loop[uv].uv = (trunk[0] + (limb_uv[0] - trunk[0]) * leg, trunk[1] + (limb_uv[1] - trunk[1]) * leg)


def furred(breed, b, fuse):
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, 0.0)  # nothing goes through the ground
    mesh = kit.fused(b, None if kit.LOW else fuse)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    lay_fur(breed, bm)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def limb(b, joints, stations, segments=12):
    directions = [(q - p).normalized() for p, q in zip(joints, joints[1:])]
    last = len(directions) - 1
    rings = []
    for s, rx, rd, shift in stations:
        i = min(max(int(math.floor(s)), 0), last)
        t = s - i
        point = joints[i] + (joints[i + 1] - joints[i]) * t
        if t < 0.5:
            ahead = directions[max(i - 1, 0)].lerp(directions[i], min(0.5 + t, 1.0))
        else:
            ahead = directions[i].lerp(directions[min(i + 1, last)], t - 0.5)
        across = ahead.normalized().cross(X).normalized()
        rings.append((point + across * shift, X * rx, across * rd))
    b.tube(dome(rings[0], -directions[0], 0.04)[::-1] + rings, segments)


def coat(breed):
    def shapes(b):
        low = kit.LOW
        m = breed.muscle
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.04)[::-1] + rings + dome(rings[-1], Z, 0.04), 18)
        # Withers, the point of the chest, and the muscle over each shoulder and haunch
        top = breed.trunk[6][1] + breed.trunk[6][3]
        b.ellipsoid(V(0.0, top - 0.024, 0.20), V(0.040 * m, 0.028, 0.100))
        b.ellipsoid(V(0.0, breed.fore[0].y + 0.01, 0.330), V(0.052 * m, 0.068, 0.050))
        for side in (1.0, -1.0):
            arm = breed.fore[0].lerp(breed.fore[1], 0.3)
            b.ellipsoid(V(side * (arm.x + 0.004), arm.y + 0.03, arm.z - 0.01), V(0.030 * m, 0.100, 0.064 * m), Matrix.Rotation(0.40, 3, "X"))
            thigh = breed.hind[0].lerp(breed.hind[1], 0.3)
            b.ellipsoid(V(side * thigh.x, thigh.y + 0.02, thigh.z + 0.01), V(0.040 * m, 0.110, 0.088 * m), Matrix.Rotation(-0.45, 3, "X"))
            if low:
                continue
            # Hunger: the last ribs show along each flank, sweeping back as they go down
            # (not evenly: one is more sprung than the next)...
            for k, (z, reach) in enumerate(((0.150, 0.60), (0.118, 0.72), (0.088, 0.80), (0.060, 0.76), (0.034, 0.64), (0.010, 0.48))):
                points = []
                for a in (0.0, 0.33, 0.66, 1.0):
                    rise = 0.62 - a * (0.62 + reach * 0.6)
                    points.append(on_flank(breed, side, z - 0.030 * a, rise, 0.003 + 0.0015 * (k % 2)))
                b.strand(points, [0.004, 0.0075, 0.0075, 0.004], 6)
            # ...the hip bones are knobs under the skin...
            y, rx, ry = trunk_at(breed, -0.27)
            b.ellipsoid(V(side * 0.040, y + ry - 0.012, -0.27), V(0.014, 0.009, 0.024))
            # ...and the shoulder blades
            b.ellipsoid(V(side * 0.042, top - 0.024, 0.23), V(0.009, 0.016, 0.040), Matrix.Rotation(-0.5, 3, "X"))
        if not low:
            # The knuckles of its spine, from the withers back to the tail
            for k in range(9):
                z = 0.10 - k * 0.046
                y, rx, ry = trunk_at(breed, z)
                b.ellipsoid(V(0.0, y + ry - 0.005, z), V(0.009, 0.008, 0.013))

        # Neck, rising forward out of the chest, with a throat under it
        base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top, t) - across * sag, X * r, across * (r * 1.2)) for t, r, sag in breed.neck_shape], 14)

        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        # A mastiff's head: a heavy brow over each eye, the stop below it, and the
        # big muscles of the jaw bulging at the cheeks
        b.ellipsoid(skull + V(0.0, size.y * 0.55, size.z * 0.45), V(size.x * 0.82, size.y * 0.38, size.z * 0.42))
        for side in (1.0, -1.0):
            b.ellipsoid(skull + V(side * 0.030, 0.034, 0.058), V(0.020, 0.010, 0.018), Matrix.Rotation(0.3, 3, "X"))  # brow
            b.ellipsoid(skull + V(side * 0.042, -0.014, 0.010), V(0.018, 0.028, 0.036), Matrix.Rotation(0.3, 3, "X"))  # cheek
        b.ellipsoid(skull + V(0.0, 0.044, -0.046), V(0.020, 0.024, 0.036))  # the peak at the back of the skull
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull, X * size.x * 0.8, Y * size.y * 0.8)] + muzzle + dome(muzzle[-1], Z, muzzle[-1][1].x * 0.55, 3), 14)
        for side in (1.0, -1.0):
            # Loose upper lips (flews), hanging over the lower jaw: the rig pulls them back to snarl
            b.ellipsoid(skull + V(side * 0.031, -0.048, 0.128), V(0.011, 0.020, 0.064), None, 8, 5)
            b.ellipsoid(skull + V(side * 0.038, -0.046, 0.066), V(0.012, 0.022, 0.044), None, 8, 5)

        b.strand([breed.tail_root + V(0.0, 0.03, 0.05)] + breed.tail, breed.tail_shape, 10)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            limb(b, joints, breed.fore_shape if fore else breed.hind_shape)
            width, length = breed.paw
            paw = joints[3]
            if not low:
                knob = joints[1] + V(0.0, 0.012, -0.028) if fore else joints[2] + V(0.0, 0.020, -0.020)
                b.ellipsoid(knob, V(width * 0.62, 0.024, 0.020), None, 8, 5)
            b.ellipsoid(paw + V(0.0, -0.008, length * 0.5), V(width, 0.024, length), None, 10, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.42, -0.014, length * 1.22 - abs(toe) * length * 0.16), V(width * 0.27, 0.016, 0.022), None, 8, 5)
        return furred(breed, b, (0.0038, 4, 13000))
    return shapes


def jaw(breed):
    def shapes(b):
        rings = [(breed.skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.jaw_shape]
        b.tube(dome(rings[0], -Z, 0.012, 2)[::-1] + rings + dome(rings[-1], Z, 0.018, 3), 12)
        return furred(breed, b, (0.003, 2, 600))
    return shapes


def nose(breed):
    def shapes(b):
        at, size = breed.nose
        b.ellipsoid(breed.skull + at, size, None, 10, 6)
    return shapes


def ear_curve(breed, t, side):
    root, mid, end = breed.ear
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(at.x * side, at.y, at.z)


EAR_RINGS = ((0.0, 0.022, 0.012), (0.12, 0.029, 0.009), (0.35, 0.028, 0.007), (0.60, 0.021, 0.006),
             (0.82, 0.012, 0.005), (0.95, 0.006, 0.004), (1.0, 0.003, 0.003))


def ears(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide = V(side * 0.90, 0.0, -0.42).normalized()
            face = V(side * 0.42, 0.0, 0.90).normalized()
            rings = []
            if side == breed.cropped:
                # Cut short, and healed ragged: a blunt stump with a torn point
                for t, half, thick in EAR_RINGS[:2] + ((0.30, 0.028, 0.008), (0.40, 0.022, 0.008)):
                    rings.append((ear_curve(breed, t, side), wide * half, face * thick))
                b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings + dome(rings[-1], (ear_curve(breed, 0.5, side) - ear_curve(breed, 0.4, side)).normalized(), 0.006, 2), 10)
                base = ear_curve(breed, 0.38, side) + wide * 0.012
                kit.spike(b, base, ear_curve(breed, 0.5, side) + wide * 0.016, 0.007, 5)
            else:
                for t, half, thick in EAR_RINGS:
                    rings.append((ear_curve(breed, t, side), wide * half, face * thick))
                b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings, 10)
        lay_fur(breed, b.bm, True)
    return shapes


def ear_linings(breed):
    def shapes(b):
        for side in (1.0, -1.0):
            wide = V(side * 0.90, 0.0, -0.42).normalized()
            face = V(side * 0.42, 0.0, 0.90).normalized()
            rings = []
            shares = ((0.10, 0.010), (0.22, 0.018), (0.40, 0.019), (0.60, 0.014), (0.80, 0.007), (0.92, 0.003))
            if side == breed.cropped:
                shares = shares[:3]
            for t, half in shares:
                rings.append((ear_curve(breed, t, side) + face * 0.0045, wide * half, face * 0.0035))
            b.tube(rings, 8)
    return shapes


def crest(breed):
    """The coarse hair along the back of its neck and down its spine, lying
    back: the hackles. The shader stands it up (each tuft's texture
    coordinate runs from 0 at its root to 1 at its tip)."""
    def shapes(b):
        low = kit.LOW
        base, top = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        shape = breed.neck_shape

        def neck_r(t):
            for a, c in zip(shape, shape[1:]):
                if t <= c[0]:
                    return a[1] + (c[1] - a[1]) * (t - a[0]) / (c[0] - a[0])
            return shape[-1][1]

        rows = (-2.0, -1.0, 0.0, 1.0, 2.0) if not low else (-0.5, 0.5)
        steps = 14 if not low else 6
        for i in range(steps):
            t = 0.04 + 0.92 * i / (steps - 1)
            r = neck_r(t) * 1.2
            for k in rows:
                # (each a little out of line with the next, so they lie like hair)
                jitter = math.sin(i * 7.31 + k * 3.7)
                lean = k * 0.22 + jitter * 0.05
                root = base.lerp(top, t) + across * (r * math.cos(lean) * 0.80) + X * (r * math.sin(lean) * 0.75)
                length = (0.050 - 0.018 * t) * (1.0 - abs(k) * 0.12) * (1.0 + jitter * 0.15)
                lie = (-along * 0.95 + across * 0.16).normalized()
                kit.spike(b, root, root + lie * length + X * (k * 0.006 + jitter * 0.004), 0.0062, 5)
        # Down the back: long over the withers, shorter along the back, longer again at the rump
        steps = 22 if not low else 8
        for i in range(steps):
            z = 0.27 - 0.62 * i / (steps - 1)
            y, rx, ry = trunk_at(breed, z)
            reach = 0.046 if z > 0.1 else 0.030 if z > -0.15 else 0.036
            for k in rows:
                jitter = math.sin(i * 5.17 + k * 2.3)
                root = V(k * 0.010 + jitter * 0.003, y + ry * 0.975 - abs(k) * 0.004, z)
                kit.spike(b, root, root + V(k * 0.007 + jitter * 0.004, 0.007, -reach * (1.0 - abs(k) * 0.12) * (1.0 + jitter * 0.15)), 0.006, 5)
    return shapes


def palate(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y, length * 0.42), V(width * 0.8, 0.006, length * 0.36), None, 8, 5)
    return shapes


def tongue(breed):
    def shapes(b):
        y, length, _, width = breed.mouth
        b.ellipsoid(breed.skull + V(0.0, y + 0.012, length * 0.44), V(width * 0.62, 0.006, length * 0.42), None, 8, 5)
    return shapes


def gums(breed):
    def shapes(b):
        # Along the upper teeth, under the lips: they show only when it snarls
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            points = []
            for share in (0.98, 0.85, 0.70, 0.55, 0.40):
                x = back + (front - back) * share
                points.append(breed.skull + V(side * (x + 0.002), y + 0.010, length * share))
            b.strand(points, [0.006, 0.008, 0.008, 0.007, 0.006], 6)
        b.strand([breed.skull + V(side * front * 0.6, y + 0.010, length * 1.0) for side in (1.0, -1.0)], [0.006, 0.006], 6)
    return shapes


def fangs(breed):
    def shapes(b):
        # The upper teeth: six small ones across the front, a long fang at each
        # corner, and the cheek teeth behind
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            for k in (0.25, 0.55, 0.85):
                base = breed.skull + V(side * front * 0.55 * k, y + 0.006, length * (1.0 - 0.02 * k))
                kit.spike(b, base, base - Y * 0.010, 0.0032, 5)
            for share, tall, radius in ((0.86, 0.024, 0.0058), (0.70, 0.010, 0.0042), (0.58, 0.011, 0.0046), (0.46, 0.012, 0.0050), (0.34, 0.010, 0.0050)):
                x = back + (front - back) * share
                base = breed.skull + V(side * x, y + 0.006, length * share)
                kit.spike(b, base, base - Y * tall + V(0.0, 0.0, 0.003 if tall > 0.02 else 0.0), radius, 5)
    return shapes


def teeth(breed):
    def shapes(b):
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            for k in (0.3, 0.7):
                base = breed.skull + V(side * front * 0.45 * k, y + 0.006, length * 0.96)
                kit.spike(b, base, base + Y * 0.009, 0.003, 5)
            for share, tall, radius in ((0.78, 0.026, 0.0058), (0.62, 0.009, 0.0040), (0.49, 0.010, 0.0045), (0.36, 0.011, 0.0050)):
                x = (back + (front - back) * share) * 0.82
                base = breed.skull + V(side * x, y + 0.006, length * share)
                kit.spike(b, base, base + Y * tall, radius, 5)
    return shapes


def eyes(breed):
    def shapes(b):
        at, radius = breed.eye
        for side in (1.0, -1.0):
            b.ellipsoid(breed.skull + V(side * at.x, at.y, at.z), V(radius * 0.8, radius * 0.62, radius), Matrix.Rotation(-side * 0.35, 3, "Y"), 8, 5)
    return shapes


def scar_lines(breed):
    """Old wounds, healed bare: lines on the coat, each a list of points on it.
    They are painted into the coat (green in its vertex colours), and the
    shader shows them as pale scar tissue with no hair on it."""
    s = breed.skull
    lines = []
    if breed.scars == 0:
        # Across the muzzle, over its left eye, and three claw marks behind its right shoulder
        lines.append([s + V(0.052, 0.004, 0.040), s + V(0.048, -0.012, 0.090), s + V(0.040, -0.022, 0.135)])
        lines.append([s + V(0.060, 0.046, 0.018), s + V(0.052, 0.030, 0.052), s + V(0.040, 0.012, 0.080)])
        for k in range(3):
            z = 0.13 - k * 0.026
            lines.append([on_flank(breed, -1.0, z + 0.035, 0.60), on_flank(breed, -1.0, z, 0.10), on_flank(breed, -1.0, z - 0.025, -0.35)])
    else:
        # Down the bridge of its nose, a torn lip, and one long gash along its left flank
        lines.append([s + V(0.012, 0.050, 0.075), s + V(0.018, 0.036, 0.120), s + V(0.012, 0.022, 0.165)])
        lines.append([s + V(-0.046, -0.028, 0.080), s + V(-0.040, -0.050, 0.105)])
        lines.append([on_flank(breed, 1.0, 0.16, 0.30), on_flank(breed, 1.0, 0.06, 0.05), on_flank(breed, 1.0, -0.06, 0.15), on_flank(breed, 1.0, -0.14, 0.40)])
    made = []
    for points in lines:
        # (laid onto the coat as it was built, and filled in between so that they follow its curve)
        fine = []
        for a, c in zip(points, points[1:]):
            for k in range(6):
                fine.append(onto_coat(a.lerp(c, k / 6.0)))
        fine.append(onto_coat(points[-1]))
        made.append(fine)
    return made


# The coat as built, to lay things on: a tree of its faces (set by `export`).
COAT = None


def onto_coat(p, lift=0.0):
    if COAT is None:
        return p
    found, normal, _, _ = COAT.find_nearest(kit.to_blender(p))
    if found is None:
        return p
    return kit.from_blender(found + normal * lift)


def weights(breed):
    tail = breed.tail
    tail_names = ["pelvis", "tail", "tail_1", "tail_2", "tail_3"]

    def lips(p, made):
        # The upper lips hang from bones of their own, so that it can draw them up off its teeth
        q = p - breed.skull
        head = made.get("head", 0.0)
        if head <= 0.0 or q.z < 0.03:
            return made
        lip = blend(0.045, 0.09, q.z) * blend(-0.020, -0.036, q.y) * blend(-0.082, -0.070, q.y) * blend(0.008, 0.022, abs(q.x))
        if lip > 0.0:
            made["head"] = head * (1.0 - lip)
            made["lip_l" if q.x >= 0.0 else "lip_r"] = head * lip
        return made

    def weigh(part, p):
        if part in ("jaw", "tongue", "teeth"):
            return {"jaw": 1.0}
        if part in ("palate", "fangs", "eyes", "nose"):
            return {"head": 1.0}
        if part == "gums":
            return lips(p + V(0.0, -0.012, 0.0), {"head": 1.0})
        if part in ("ears", "linings"):
            suffix = "_l" if p.x >= 0.0 else "_r"
            side = 1.0 if p.x >= 0.0 else -1.0
            root, mid, end = (V(j.x * side, j.y, j.z) for j in breed.ear)
            along = (p - root).dot((end - root).normalized())
            joint = (mid - root).dot((end - root).normalized())
            hung = blend(0.0, 0.03, along)
            tip = blend(joint - 0.02, joint + 0.02, along)
            return {"head": 1.0 - hung, "ear" + suffix: hung * (1.0 - tip), "ear_tip" + suffix: hung * tip}
        off, along = chain_param(p, tail)
        if p.z < tail[0].z and off < 0.05:
            past = [1.0, blend(0.0, 0.6, along)] + [blend(k - 0.3, k + 0.3, along) for k in (1, 2, 3)] + [0.0]
            return {name: past[i] - past[i + 1] for i, name in enumerate(tail_names)}
        front = blend(-0.12, 0.08, p.z)
        trunk = {"chest": front, "pelvis": 1.0 - front}
        base, top = breed.neck, breed.head
        reach = (p - base).dot((top - base).normalized()) / (top - base).length
        if reach > 0.0 and p.z > base.z - 0.04:
            neck = blend(0.02, 0.36, reach)
            upper = blend(0.36, 0.70, reach)
            head = blend(0.74, 1.04, reach)
            made = {"chest": 1.0 - neck, "neck": neck * (1.0 - upper), "neck_1": neck * upper * (1.0 - head), "head": neck * upper * head}
            return lips(p, made) if part == "coat" else made
        suffix, leg = leg_share(breed, p)
        joints = breed.legs[suffix]
        along = chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.045 / spans[0], 1.0 + 0.045 / spans[1], along)
        hock = blend(2.0 - 0.035 / spans[1], 2.0 + 0.035 / spans[2], along)
        paw = blend(joints[3].y + 0.05, joints[3].y + 0.012, p.y)
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + suffix] = leg * (1.0 - low)
        made["lower" + suffix] = leg * low * (1.0 - hock)
        made["hock" + suffix] = leg * low * hock * (1.0 - paw)
        made["paw" + suffix] = leg * low * hock * paw
        return made
    return weigh


def bones(breed):
    listed = [
        ("body", breed.body, None), ("chest", breed.chest, "body"), ("pelvis", breed.pelvis, "body"),
        ("neck", breed.neck, "chest"), ("neck_1", breed.neck_1, "neck"), ("head", breed.head, "neck_1"), ("jaw", breed.jaw, "head"),
    ]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        listed.append(("lip" + suffix, breed.skull + V(side * 0.030, -0.030, 0.100), "head"))
        root, mid, end = (V(j.x * side, j.y, j.z) for j in breed.ear)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
    chain = ["pelvis", "tail", "tail_1", "tail_2", "tail_3", "tail_end"]
    for i, joint in enumerate(breed.tail):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in breed.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


## Three materials, so that a dog is few draws: the coat (with its fur), the
## crest, and everything else (`parts`), whose colours are in its vertex
## colours: (sRGB colour, and in alpha how wet it is: 1 shines like an eye).
MATERIALS = [("coat", (0.155, 0.135, 0.115)), ("crest", (0.13, 0.115, 0.10)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "palate": (0.36, 0.09, 0.10, 0.5), "tongue": (0.42, 0.13, 0.15, 0.6), "gums": (0.32, 0.10, 0.12, 0.6),
    "fangs": (0.80, 0.75, 0.60, 0.4), "teeth": (0.80, 0.75, 0.60, 0.4), "eyes": (0.80, 0.62, 0.22, 1.0),
    "linings": (0.30, 0.21, 0.20, 0.0), "nose": (0.035, 0.03, 0.03, 0.7),
}


def parts(breed):
    # (name, material index, shapes, fuse): the coat and the jaw fuse themselves
    return [
        ("coat", 0, coat(breed), None), ("jaw", 0, jaw(breed), None), ("ears", 0, ears(breed), None),
        ("crest", 1, crest(breed), None), ("palate", 2, palate(breed), None), ("tongue", 2, tongue(breed), None),
        ("gums", 2, gums(breed), None), ("fangs", 2, fangs(breed), None), ("teeth", 2, teeth(breed), None),
        ("eyes", 2, eyes(breed), None), ("linings", 2, ear_linings(breed), None), ("nose", 2, nose(breed), None),
    ]


# --- Shading baked into the coat ---

def paint(breed, whole, part_of):
    """Vertex colours. On the coat: red, how open the surface is (low in
    grooves and creases); blue, how far it is the paler underside (green is unused).
    On the other parts, their colours (see PART_COLOURS)."""
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred = [part in ("coat", "jaw", "ears") for part in part_of]
    scars = scar_lines(breed)
    crest_first = part_of.index("crest")
    across_uv = {}
    open_ = [1.0] * len(whole.verts)
    for vert in whole.verts:
        if not furred[vert.index] or not vert.link_edges:
            continue
        # How far its neighbours stand out past it, along its normal, for the size of the step to them
        rise = 0.0
        for edge in vert.link_edges:
            other = edge.other_vert(vert)
            step = other.co - vert.co
            if step.length > 1e-6:
                rise += step.dot(vert.normal) / step.length
        open_[vert.index] = rise / len(vert.link_edges)
    # (spread it a little, so that a groove is a soft band and not a speckle)
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
            # (each tuft its own: a number from its place in the list, the same in every build)
            spike = (vert.index - crest_first) // (18 if kit.LOW else 22)
            vert[layer] = (1.0, 1.0, 1.0, (math.sin(spike * 12.9898) * 43758.5453) % 1.0)
            continue
        if part in PART_COLOURS:
            vert[layer] = PART_COLOURS[part]
            if part == "eyes":
                # Where on the eye it is, from the front: for the pupil and the rim
                side = 1.0 if p.x >= 0.0 else -1.0
                at, radius = breed.eye
                centre = breed.skull + V(side * at.x, at.y, at.z)
                # (a dog's eyes look a little out to the side: so does the middle of its pupil)
                local = Matrix.Rotation(side * 0.6, 3, "Y").inverted() @ (p - centre)
                if local.z > 0.0:
                    across_uv[vert.index] = (0.5 + local.x / (radius * 0.8) * 0.4, 0.5 + local.y / (radius * 0.62) * 0.4)
                else:
                    across_uv[vert.index] = (0.95, 0.95)
            continue
        shade = 1.0
        pale = 0.0
        scar = 0.0
        if furred[vert.index]:
            # How far across the nearest scar it is, on which side of it (so that the
            # shader can draw a smooth line through the middle of a triangle), and how
            # far along it.
            # Two numbers for the nearest scar: how far across the line of its nearest
            # piece this is, on which side (so that, between two corners of a
            # triangle, the shader finds where the line runs through it), and how far
            # it truly is from the scar (to keep to the scar itself: that line runs on
            # past its ends, and sides change between one scar and the next).
            near = 1e9
            for line in scars:
                for a, c in zip(line, line[1:]):
                    ac = c - a
                    t = min(max((p - a).dot(ac) / max(ac.length_squared, 1e-9), 0.0), 1.0)
                    gap = (a + ac * t - p).length
                    if gap < near:
                        near = gap
                        way = ac.normalized()
                        off = (p - a) - way * (p - a).dot(way)
                        side = way.cross(kit.from_blender(vert.normal)).dot(off)
                        across = off.length if side >= 0.0 else -off.length
                        across_uv[vert.index] = (0.5 + max(min(across * 10.0, 0.45), -0.45), 0.5 + min(gap * 10.0, 0.45))
            # (against how open the surface is in general: it is all a little rounded)
            shade = min(max(1.0 - (open_[vert.index] - middle) * 6.0, 0.0), 1.0)
            y, rx, ry = trunk_at(breed, p.z)
            belly = blend(y - ry * 0.25, y - ry * 0.95, p.y) * blend(y - ry - 0.05, y - ry - 0.01, p.y) * blend(0.36, 0.30, p.z) * blend(-0.25, -0.15, p.z)
            q = p - breed.skull
            muzzle = blend(0.07, 0.15, q.z) * blend(-0.004, -0.03, q.y) if q.z > 0.0 and p.y > 0.7 else 0.0
            throat = blend(breed.neck.z - 0.05, breed.neck.z + 0.06, p.z) * blend(breed.neck.y + 0.06, breed.neck.y - 0.06, p.y) * blend(0.6, 0.45, p.y)
            legs = blend(0.30, 0.12, p.y) * 0.45
            pale = max(belly, muzzle * 0.8, throat, legs)
        vert[layer] = (shade, scar, pale, 1.0)
    # The second texture coordinates: across and along a scar on the coat (0.5 across is
    # its middle line, a tenth either side is a centimetre), and on an eye, where on its
    # front (0.5, 0.5 is the middle of the pupil). Anything else, far off (0.95).
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))


def _bm_of(mesh):
    made = bmesh.new()
    made.from_mesh(mesh)
    return made


def export(breed, preview):
    low = kit.LOW
    name = breed.name + ("_lo" if low else "")
    if kit.ONLY and breed.name not in kit.ONLY:
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = kit.make_armature(bones(breed))
    whole = bmesh.new()
    whole.loops.layers.uv.verify()
    part_of = []
    for part, material, shapes, fuse in parts(breed):
        builder = kit.Builder()
        ready = shapes(builder)
        mesh = ready if ready is not None else kit.fused(builder, fuse)
        if part == "coat":
            global COAT
            COAT = BVHTree.FromBMesh(_bm_of(mesh))
        first = len(whole.faces)
        whole.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        whole.faces.ensure_lookup_table()
        for face in whole.faces[first:]:
            face.material_index = material
            face.smooth = not low
        part_of += [part] * (len(whole.verts) - len(part_of))
    paint(breed, whole, part_of)

    mesh = bpy.data.meshes.new(name)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    for label, srgb in MATERIALS:
        made = bpy.data.materials.new(label)
        made.use_nodes = True
        colour = tuple(kit.linear(c) for c in srgb) + (1.0,)
        made.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = colour
        made.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
        made.diffuse_color = colour
        mesh.materials.append(made)
    groups = {bone.name: body.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
    deform = whole.verts.layers.deform.verify()
    weigh = weights(breed)
    for vert, part in zip(whole.verts, part_of):
        for bone, weight in weigh(part, kit.from_blender(vert.co)).items():
            if weight > 0.001:
                vert[deform][groups[bone]] = weight
    whole.to_mesh(mesh)
    whole.free()
    # (only the colours painted here: anything else that came in with the parts would be exported first)
    for attribute in [a for a in mesh.color_attributes if a.name != "Color"]:
        mesh.color_attributes.remove(attribute)
    painted = mesh.color_attributes["Color"]
    mesh.color_attributes.active_color = painted
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    body.parent = armature
    body.modifiers.new("Armature", "ARMATURE").object = armature
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True,
        export_animations=False, export_skins=True, export_vertex_color="ACTIVE",
    )
    print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), kit.triangle_count(mesh)))
    if preview:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(preview, name + ".blend"))
        if not low:
            render(preview, name)


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
    # (view, direction to the camera in Blender space, what it looks at, how much it frames, colours)
    views = [("side", (1, 0, 0), (0.0, -0.05, 0.5), 1.25, "MATERIAL"), ("quarter", (0.7, -0.7, 0.2), (0.0, -0.05, 0.5), 1.25, "MATERIAL"),
             ("front", (0.05, -1, 0.1), (0.0, -0.3, 0.55), 0.9, "MATERIAL"), ("face", (0.55, -0.8, 0.15), (0.0, -0.55, 0.85), 0.36, "MATERIAL"),
             ("face_other", (-0.55, -0.8, 0.15), (0.0, -0.55, 0.85), 0.36, "MATERIAL"), ("top", (0.2, 0.1, 1), (0.0, -0.05, 0.5), 1.25, "MATERIAL"),
             ("shade", (0.8, -0.5, 0.2), (0.0, -0.05, 0.5), 1.25, "VERTEX")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        for breed in DOGS:
            export(breed, preview)
