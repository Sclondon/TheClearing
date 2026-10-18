"""Builds the rabbit, the brown hare and the jackalope (creatures/rabbit), and the two kinds of warren, and exports
them for Godot.

Run from the game's root (Blender 4.3):
    blender --background --python creatures/rabbit/tools/build_rabbit.py
    blender --background --python creatures/rabbit/tools/build_rabbit.py -- <preview folder> rabbit   # one, with pictures

Writes creatures/rabbit/models/rabbit.glb, hare.glb, jackalope.glb and a demade `_lo` version of each, and
warren_mound.glb and warren_bank.glb. Nothing else is written (an editable .blend and pictures go to the preview
folder, when there is one).

They are real animals first, built from a leporid's anatomy:
- A short, deep trunk carried hunched: the back rising to the loins, a great round rump, a narrower chest, the belly
  low between the legs.
- Short forelegs nearly straight under the chest (the elbow tucked back, the wrist, a short hand of five toes, four
  reaching the ground). Long hind legs folded in a Z: the hip high in the rump, the stifle forward against the flank
  under the haunch, the long shank back down to the hock, and the very long hind foot forward from the hock along the
  ground, furred all over, four long toes at its end. At rest the whole foot lies flat, hock to toe.
- A short thick neck, the head round with broad cheeks and a blunt muzzle, the upper lip split into two whisker pads
  under a small nose (a bone of its own: it twitches), big dark eyes high at the sides, the long ears from the top of
  the skull (each with three bones, so that it can turn, fold and lie back), and the scut: a short tail, dark on top,
  white beneath, that is held up and flashes white as it runs.
- The rabbit (European rabbit) is small, grey-brown and round. The brown hare is half as big again and lean, with
  long legs, longer ears with black tips, a tawny coat, a black top to its tail and big amber eyes. The jackalope is a
  hare, greyer, with a pair of small polished antlers (a roe buck's, two tines and a fork) rising from in front of its
  ears.

The bones (the dog's and the deer's names, creatures/deer):

    body, chest, pelvis, neck, head, jaw, lip, ear(_tip, _end)_l/_r, tail, tail_end
    fore: `upper` (shoulder to elbow), `lower` (forearm, to the wrist), `hock` (the hand, to the knuckles), `paw`
    hind: `upper` (thigh, hip to stifle), `lower` (shank, to the hock), `hock` (the long foot, to the toes), `paw`
    `toe`: a marker past each paw, where the tips of its toes are on the ground (nothing is weighted to it)
    `nose`, `brow`: markers at the tip of its nose and the top of its head (the antlers' points on a jackalope)

Three surfaces: `coat` (fur), `parts` (eyes, nose, claws, ear linings, teeth, antlers: their colours in the vertex
colours, alpha how wet), and nothing else. The coat's vertex colours: red how open the surface is (dark in creases),
green the dark of the coat (its back, the top of the tail), blue the pale (belly, chin, the ring round the eye, under
the tail), alpha the black (a hare's ear tips and tail).

The warrens are earth: a hummock with five holes dug into its flanks (warren_mound) and a bank that lies against the
foot of a wall with four holes in its face (warren_bank), loose earth fanned out before each hole and the tunnels
going in, dark, out of sight. Vertex colours only (surface `earth`). Each hole is marked by two empties, `hole_<n>` at
its mouth and `deep_<n>` inside it, along the tunnel.

Everything is in Godot space (metres, Y up, facing +Z, +X its left). Uses the character controller's
tools/build_character.py (from GameCommon) for its shape-building.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
GAME = os.path.dirname(os.path.dirname(COMPONENT))
sys.path.insert(0, os.path.join(GAME, "tools"))
import build_character as kit  # noqa: E402  (the character controller's shape-building tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
SUFFIXES = ("_fl", "_fr", "_rl", "_rr")
OUT = os.path.join(COMPONENT, "models")


def V(x, y, z):
    return Vector((x, y, z))


def rot_x(angle):
    return Matrix.Rotation(angle, 3, "X")


def rot_y(angle):
    return Matrix.Rotation(angle, 3, "Y")


class Leporid:
    """One animal's measurements. Everything is given for a rabbit, and grown: `scale` all over, `leg` the legs
    (longer legs stand it taller: the trunk and head go up with them), `ear` the ears' length."""

    def __init__(self, **spec):
        self.__dict__.update(spec)
        s = self.scale
        lift = self.lift()
        self.body = V(0.0, 0.118 + lift, -0.030) * s
        self.chest = V(0.0, 0.115 + lift, 0.045) * s
        self.pelvis = V(0.0, 0.128 + lift, -0.090) * s
        self.neck = V(0.0, 0.136 + lift, 0.080) * s
        self.head = self.atlas() * s
        a = self.face_tilt
        self.face = V(0.0, -math.sin(a), math.cos(a))
        self.face_up = V(0.0, math.cos(a), math.sin(a))
        self.jaw = self.at(0.026, -0.016)
        self.lip = self.at(0.058, -0.004)
        self.legs = {}
        for suffix in SUFFIXES:
            side = 1.0 if suffix[2] == "l" else -1.0
            fore = suffix[1] == "f"
            joints = self.fore_joints() if fore else self.hind_joints()
            self.legs[suffix] = [V(j.x * side, j.y, j.z) * s for j in joints]
        self.toes = {}
        for suffix, joints in self.legs.items():
            ahead = (0.016 if suffix[1] == "f" else 0.034 * self.leg) * s
            self.toes[suffix] = V(joints[3].x, 0.0, joints[3].z + ahead)
        # The ears: from the top of the back of the skull, up and back, splayed a little
        root = self.at(-0.006, 0.024, 0.009)
        length = 0.084 * self.ear * s
        way = V(0.18, math.cos(0.42), -math.sin(0.42)).normalized()
        self.ear_points = [root, root + way * length * 0.5 + V(0.0, 0.0, 0.003 * s), root + way * length]
        tail_root = V(0.0, 0.150 + lift, -0.160) * s
        k = self.tail_size
        self.tail = [tail_root, tail_root + V(0.0, -0.018, -0.020) * s * k, tail_root + V(0.0, -0.034, -0.026) * s * k]

    def lift(self):
        """How much higher the body stands on longer legs (rabbit units)."""
        return (self.leg - 1.0) * 0.10

    def atlas(self):
        return V(0.0, 0.163 + self.lift(), 0.112)

    def fore_joints(self):
        """Shoulder, elbow, wrist, knuckles (the left leg, rabbit units; longer legs are longer down from the shoulder)."""
        k = self.leg
        top = V(0.035, 0.105 + self.lift(), 0.075)
        return [top, top + V(0.005, -0.045, -0.020) * k, V(0.035, 0.018 * k, 0.075), V(0.034, 0.006, 0.088 + 0.010 * (k - 1.0))]

    def hind_joints(self):
        """Hip, stifle, hock, the root of the toes (the left leg, rabbit units)."""
        k = self.leg
        hip = V(0.040, 0.130 + self.lift(), -0.100)
        return [hip, hip + V(0.015, -0.055, 0.055) * k, V(0.044, 0.018 * k, -0.100 - 0.045 * k), V(0.043, 0.006, -0.100 + 0.025 * k)]

    def at(self, along, up, out=0.0):
        """A point on the head: `along` the face from the atlas, `up` from its line, `out` to its left (rabbit units;
        the muzzle past the eyes drawn `muzzle` as long)."""
        s = self.scale * self.head_scale
        if along > 0.036:
            along = 0.036 + (along - 0.036) * self.muzzle
        return self.head + (self.face * along + self.face_up * up + X * out) * s

    def unmuzzle(self, along):
        return along if along <= 0.036 else 0.036 + (along - 0.036) / self.muzzle


def rabbit():
    return Leporid(
        name="rabbit", kind="rabbit", scale=1.0, leg=1.0, ear=1.0, head_scale=1.12, thick=1.0, muzzle=1.0, face_tilt=0.78,
        tail_size=1.0, antlers=False, hare=False,
        # (along the body, centre height, half width, half height): the round rump, the back hunched highest over
        # the loins, the chest narrower and lower
        trunk=[(-0.172, 0.118, 0.018, 0.026), (-0.160, 0.120, 0.048, 0.058), (-0.140, 0.124, 0.064, 0.074),
               (-0.110, 0.126, 0.068, 0.080), (-0.070, 0.124, 0.066, 0.079), (-0.025, 0.118, 0.061, 0.073),
               (0.020, 0.112, 0.056, 0.067), (0.055, 0.110, 0.051, 0.061), (0.080, 0.113, 0.043, 0.051),
               (0.096, 0.118, 0.030, 0.036), (0.106, 0.122, 0.014, 0.018)],
        colours=dict(coat=(0.40, 0.35, 0.29), dark=(0.24, 0.20, 0.16), pale=(0.80, 0.77, 0.71)),
        eye=(0.20, 0.13, 0.09),
    )


def hare(name="hare", antlers=False):
    return Leporid(
        name=name, kind="hare", scale=1.36, leg=1.25, ear=1.36, head_scale=1.06, thick=0.86, muzzle=1.15, face_tilt=0.66,
        tail_size=1.15, antlers=antlers, hare=True,
        trunk=[(-0.172, 0.118, 0.016, 0.024), (-0.160, 0.120, 0.045, 0.055), (-0.140, 0.123, 0.060, 0.071),
               (-0.110, 0.125, 0.064, 0.077), (-0.070, 0.124, 0.062, 0.075), (-0.025, 0.119, 0.057, 0.069),
               (0.020, 0.114, 0.053, 0.064), (0.055, 0.112, 0.049, 0.059), (0.080, 0.114, 0.041, 0.049),
               (0.096, 0.118, 0.029, 0.035), (0.106, 0.122, 0.013, 0.017)],
        colours=dict(coat=(0.47, 0.37, 0.26), dark=(0.27, 0.21, 0.15), pale=(0.82, 0.78, 0.70)) if not antlers else
        dict(coat=(0.42, 0.36, 0.29), dark=(0.25, 0.21, 0.17), pale=(0.78, 0.75, 0.70)),
        eye=(0.62, 0.40, 0.12) if not antlers else (0.55, 0.42, 0.18),
    )


ANIMALS = [rabbit(), hare(), hare("jackalope", True)]


def trunk_at(c, z):
    """The trunk's (centre height, half width, half height) at `z` along it (built size)."""
    s = c.scale
    rings = c.trunk
    z /= s
    if z <= rings[0][0]:
        r = rings[0][1:]
    else:
        r = rings[-1][1:]
        for a, b in zip(rings, rings[1:]):
            if z <= b[0]:
                t = (z - a[0]) / (b[0] - a[0])
                r = tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
                break
    return (r[0] + c.lift()) * s, r[1] * s * c.thick, r[2] * s


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


def leg_of(c, p):
    s = c.scale
    return ("_f" if p.z > -0.02 * s else "_r") + ("l" if p.x >= 0.0 else "r")


def leg_share(c, p):
    """Which leg a point is nearest, and how much of it goes with that leg rather than the trunk."""
    s = c.scale
    suffix = leg_of(c, p)
    joints = c.legs[suffix]
    fore = suffix[1] == "f"
    off, along = chain_param(p, joints)
    top = joints[0]
    if fore:
        # (the foreleg leaves the chest below the elbow's height; above, the shoulder is the trunk's)
        share = blend(top.y - 0.025 * s, top.y - 0.070 * s, p.y) * blend(0.034 * s, 0.022 * s, off)
    else:
        # (the thigh: the haunch round the hip goes with it, the trunk above and in front of it stays)
        femur = chain_param(p, joints[0:2])[0]
        share = blend(0.050 * s, 0.030 * s, femur) * blend(top.y + 0.01 * s, top.y - 0.02 * s, p.y) * blend(0.015 * s, 0.032 * s, abs(p.x))
        share = max(share, blend(0.030 * s, 0.020 * s, off) * blend(0.8, 1.2, along), blend(top.y - 0.06 * s, top.y - 0.09 * s, p.y))
    return suffix, min(max(share, 0.0), 1.0)


def lay_fur(c, bm):
    """Texture coordinates for the fur shader: (along the lie of the hair, across it), in metres."""
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            suffix, leg = leg_share(c, p)
            joints = c.legs[suffix]
            trunk = (-p.z, math.atan2(p.x, p.y - c.body.y) * 0.05 * c.scale)
            limb_uv = (joints[0].y - p.y - joints[0].z, math.atan2(p.x - joints[0].x, p.z - joints[0].z) * 0.02 * c.scale)
            loop[uv].uv = (trunk[0] + (limb_uv[0] - trunk[0]) * leg, trunk[1] + (limb_uv[1] - trunk[1]) * leg)


def furred(c, b, fuse_with):
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, 0.0)  # nothing goes through the ground
    mesh = kit.fused(b, None if kit.LOW else fuse_with)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    lay_fur(c, bm)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def limb(b, joints, stations, scale, thick, segments=12):
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
        rings.append((point + across * shift * scale, X * rx * scale * thick, across * rd * scale * thick))
    b.tube(dome(rings[0], -directions[0], 0.01 * scale)[::-1] + rings, segments)


def tube_along(b, points, widths, depths, segments=12, sideways=X, caps=True):
    """A tube through `points`, `widths` across (along `sideways`) and `depths` the other way."""
    rings = []
    for i, p in enumerate(points):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        across = ahead.cross(sideways).normalized()
        side = across.cross(ahead).normalized()
        rings.append((p, side * widths[i], across * depths[i]))
    if caps:
        first = (points[0] - points[1]).normalized()
        last = (points[-1] - points[-2]).normalized()
        rings = dome(rings[0], first, min(widths[0], depths[0]) * 0.8, 2)[::-1] + rings + dome(rings[-1], last, min(widths[-1], depths[-1]) * 0.8, 2)
    b.tube(rings, segments)


def side_mass(b, side, rows, segments=14):
    """A mass down one side of the body (a shoulder, a haunch): rings across it, level, from the top down;
    each (height, along, out, half width, half depth) at the built size."""
    rings = [(V(side * out, y, z), X * w, Z * d) for y, z, out, w, d in rows]
    b.tube(dome(rings[0], Y, rows[0][3] * 0.8)[::-1] + rings + dome(rings[-1], -Y, rows[-1][3] * 0.8), segments)


def neck_frame(c):
    base, top = c.neck, c.head + V(0.0, -0.004, 0.0) * c.scale
    along = (top - base).normalized()
    throat = X.cross(along).normalized()  # (points forward and down, under the neck)
    return base, top, along, throat


def mass(c):
    """The body's masses, fused and smoothed hard so that they run into each other under the fur: the trunk, the
    shoulders, the haunches, the neck."""
    b = kit.Builder()
    s = c.scale
    th = c.thick
    L = c.lift()
    rings = [(V(0.0, (y + L) * s, z * s), X * rx * s * th, Y * ry * s) for z, y, rx, ry in c.trunk]
    b.tube(dome(rings[0], -Z, 0.012 * s)[::-1] + rings + dome(rings[-1], Z, 0.01 * s), 20)
    for side in (1.0, -1.0):
        # The shoulder: the blade down the side of the chest to the point of the shoulder
        side_mass(b, side, [((0.140 + L) * s, 0.068 * s, 0.026 * s * th, 0.016 * s * th, 0.026 * s),
                            ((0.120 + L) * s, 0.075 * s, 0.034 * s * th, 0.018 * s * th, 0.030 * s),
                            ((0.098 + L) * s, 0.076 * s, 0.038 * s * th, 0.017 * s * th, 0.028 * s),
                            ((0.076 + L) * s, 0.070 * s, 0.038 * s * th, 0.013 * s * th, 0.020 * s)])
        # The haunch: the great round of the thigh over the hip, down to the stifle against the flank
        side_mass(b, side, [((0.188 + L) * s, -0.100 * s, 0.020 * s * th, 0.030 * s * th, 0.046 * s),
                            ((0.168 + L) * s, -0.097 * s, 0.034 * s * th, 0.034 * s * th, 0.058 * s),
                            ((0.140 + L) * s, -0.090 * s, 0.042 * s * th, 0.035 * s * th, 0.064 * s),
                            ((0.110 + L) * s, -0.080 * s, 0.045 * s * th, 0.031 * s * th, 0.060 * s),
                            ((0.080 + L) * s, -0.074 * s, 0.045 * s * th, 0.024 * s * th, 0.048 * s),
                            ((0.056 + L) * s, -0.078 * s, 0.042 * s * th, 0.018 * s * th, 0.036 * s),
                            ((0.036 + L) * s, -0.092 * s, 0.040 * s * th, 0.012 * s * th, 0.028 * s)])
    # The neck, short and thick, out of the chest into the head
    nb, nt, along, throat = neck_frame(c)
    nrings = []
    for t, w, d in ((-0.4, 0.044, 0.054), (0.0, 0.041, 0.048), (0.45, 0.035, 0.040), (0.85, 0.029, 0.033), (1.0, 0.027, 0.031)):
        nrings.append((nb.lerp(nt, t) + throat * 0.004 * s, X * w * s * th, throat * d * s))
    b.tube(nrings, 16)
    if kit.LOW:
        return kit.fused(b, None)
    mesh = bpy.data.meshes.new("part")
    b.bm.to_mesh(mesh)
    b.bm.free()
    part = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(part)
    remesh = part.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.0025 * s
    remesh.adaptivity = 0.0
    smooth = part.modifiers.new("smooth", "SMOOTH")
    smooth.factor = 1.0
    smooth.iterations = 30
    bpy.context.view_layer.update()
    result = bpy.data.meshes.new_from_object(part.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(part)
    return result


def coat(c):
    def shapes(b):
        s = c.scale
        body = mass(c)
        b.bm.from_mesh(body)
        bpy.data.meshes.remove(body)
        head(c, b)
        # The scut: a short tail of soft fur
        ts = s * c.tail_size
        tube_along(b, c.tail, [0.012 * ts, 0.016 * ts, 0.010 * ts], [0.010 * ts, 0.014 * ts, 0.008 * ts], 10)
        b.ellipsoid(c.tail[1] + V(0.0, 0.002, -0.004) * ts, V(0.019 * ts, 0.019 * ts, 0.022 * ts), rot_x(-0.6), 12, 6)
        for suffix, joints in c.legs.items():
            fore = suffix[1] == "f"
            k = c.leg
            if fore:
                stations = [(0.25, 0.018, 0.022, 0.0), (0.7, 0.016, 0.020, -0.002), (1.0, 0.0135, 0.017, -0.001),
                            (1.5, 0.0105, 0.0125, 0.0), (1.95, 0.0088, 0.0105, 0.001), (2.3, 0.0092, 0.0095, 0.001), (3.0, 0.0090, 0.0075, 0.001)]
            else:
                stations = [(0.35, 0.026, 0.038, -0.004), (0.75, 0.023, 0.032, 0.0), (1.0, 0.021, 0.031, -0.004),
                            (1.4, 0.017, 0.025, -0.007), (1.8, 0.0125, 0.0175, -0.006), (2.0, 0.0108, 0.0130, -0.002),
                            (2.35, 0.0118, 0.0090, 0.0), (2.75, 0.0122, 0.0084, 0.0), (3.0, 0.0122, 0.0080, 0.0)]
            limb(b, joints, stations, s, c.thick ** 0.5)
            paw, toe = joints[3], c.toes[suffix]
            if fore:
                # The hand: a small rounded paw, the toes together, furred to their claws
                tip = toe + V(0.0, 0.004 * s, 0.0)
                tube_along(b, [paw + V(0.0, 0.0015 * s, -0.004 * s), paw.lerp(tip, 0.5) + V(0.0, 0.0015 * s, 0.0), tip],
                           [0.0090 * s, 0.0085 * s, 0.0060 * s], [0.0065 * s, 0.0058 * s, 0.0040 * s], 10)
            else:
                # The point of the hock, and the long foot to the toes, flat and narrow, furred beneath too
                hock = joints[2]
                b.ellipsoid(hock + V(0.0, 0.003 * s, -0.006 * s), V(0.0095 * s, 0.011 * s, 0.010 * s), None, 10, 5)
                tip = toe + V(0.0, 0.0045 * s, 0.0)
                tube_along(b, [paw + V(0.0, 0.0005 * s, -0.008 * s), paw.lerp(tip, 0.5) + V(0.0, 0.0012 * s, 0.0), tip],
                           [0.0118 * s, 0.0105 * s, 0.0070 * s], [0.0075 * s, 0.0065 * s, 0.0045 * s], 10)
        return furred(c, b, (0.0019 * s, 3, 5200 if c.hare else 4400))
    return shapes


def head(c, b):
    """The head, on the coat: the round skull, the broad cheeks, the blunt muzzle, the whisker pads, the throat."""
    s = c.scale * c.head_scale
    at = c.at
    a = c.face_tilt
    # The skull: round and high, broad between the ears
    b.ellipsoid(at(0.018, 0.007), V(0.026 * s, 0.027 * s, 0.034 * s), rot_x(a), 16, 9)
    # The muzzle: short and blunt, deep, the nose at its front
    rows = [(0.028, 0.002, 0.022, 0.022), (0.044, -0.002, 0.019, 0.019), (0.057, -0.005, 0.0155, 0.0160),
            (0.067, -0.006, 0.0115, 0.0122), (0.073, -0.006, 0.0075, 0.0080)]
    tube_along(b, [at(al, u) for al, u, _, _ in rows], [w * s for _, _, w, _ in rows], [d * s for _, _, _, d in rows], 16)
    for side in (1.0, -1.0):
        b.ellipsoid(at(0.030, -0.011, side * 0.016), V(0.015 * s, 0.019 * s, 0.023 * s), rot_x(a))  # cheek
        b.ellipsoid(at(0.032, 0.017, side * 0.016), V(0.010 * s, 0.006 * s, 0.013 * s), rot_x(a))  # brow
    # The throat and jowl, under the back of the head
    b.ellipsoid(at(0.002, -0.019), V(0.024 * s, 0.024 * s, 0.025 * s), rot_x(a))


def lip(c):
    """The nose's fur and the split upper lip: two whisker pads under the nose (on the `lip` bone, that twitches)."""
    def shapes(b):
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            b.ellipsoid(c.at(0.066, -0.012, side * 0.0062), V(0.0074 * s, 0.0084 * s, 0.0092 * s), rot_x(c.face_tilt + 0.3), 12, 6)
        b.ellipsoid(c.at(0.069, -0.004), V(0.0088 * s, 0.0070 * s, 0.0080 * s), rot_x(c.face_tilt), 12, 6)
        return furred(c, b, (0.0014 * c.scale, 2, 900))
    return shapes


def jaw(c):
    def shapes(b):
        s = c.scale * c.head_scale
        at = c.at
        tube_along(b, [at(0.024, -0.016), at(0.044, -0.018), at(0.058, -0.016)], [0.015 * s, 0.0095 * s, 0.0055 * s], [0.007 * s, 0.0055 * s, 0.004 * s], 12)
        return furred(c, b, (0.0014 * c.scale, 2, 500))
    return shapes


EYE = (0.034, 0.012, 0.0205)
EYE_SIZE = V(0.0105, 0.0102, 0.0086)


def eye_basis(c, side):
    # (high at the sides of the head, looking out and a little forward: a rabbit sees all the way round)
    turn = 1.22 if c.kind == "rabbit" else 1.18
    return rot_y(side * turn) @ rot_x(c.face_tilt - 0.25)


def eyes(c):
    def shapes(b):
        s = c.scale * c.head_scale
        size = EYE_SIZE * (1.08 if c.hare else 1.0)
        for side in (1.0, -1.0):
            b.ellipsoid(c.at(EYE[0], EYE[1], side * EYE[2]), size * s, eye_basis(c, side), 14, 8)
    return shapes


def nose(c):
    def shapes(b):
        s = c.scale * c.head_scale
        # The small bare nose, a soft Y, the nostrils slits at its sides
        b.ellipsoid(c.at(0.0755, -0.0045), V(0.0052 * s, 0.0036 * s, 0.0030 * s), rot_x(c.face_tilt + 0.9), 10, 5)
        for side in (1.0, -1.0):
            b.ellipsoid(c.at(0.0742, -0.0072, side * 0.0038), V(0.0016 * s, 0.0032 * s, 0.0018 * s), rot_x(c.face_tilt + 0.5), 6, 4)
    return shapes


def teeth(c):
    def shapes(b):
        s = c.scale * c.head_scale
        # The two upper incisors, just showing under the split lip
        for side in (1.0, -1.0):
            base = c.at(0.068, -0.017, side * 0.0019)
            kit.spike(b, base, base - c.face_up * 0.0055 * s + c.face * 0.0008 * s, 0.0017 * s, 5)
    return shapes


def ear_curve(c, t, side):
    root, mid, end = c.ear_points
    bend = mid * 2.0 - (root + end) * 0.5
    p = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(p.x * side, p.y, p.z)


# (how far along the ear, half its width, its thickness): narrow and rolled at the root, broadest past the middle,
# a rounded tip; a hare's narrower for its length
EAR_RINGS = ((0.0, 0.40, 0.55), (0.10, 0.60, 0.42), (0.25, 0.85, 0.30), (0.45, 1.0, 0.24), (0.62, 1.0, 0.20),
             (0.78, 0.88, 0.17), (0.90, 0.64, 0.14), (0.97, 0.34, 0.12), (1.0, 0.10, 0.10))


def ear_axes(c, side, t):
    ahead = (ear_curve(c, min(t + 0.05, 1.0), side) - ear_curve(c, max(t - 0.05, 0.0), side)).normalized()
    # (the ear's opening faces forward and out)
    face = (V(side * 0.6, 0.0, 1.0) - ahead * V(side * 0.6, 0.0, 1.0).dot(ahead)).normalized()
    wide = ahead.cross(face).normalized()
    return wide, face


def ear_width(c):
    return 0.0168 * (1.0 if not c.hare else 0.90) * c.scale * c.head_scale * (c.ear ** 0.45)


def ears(c):
    def shapes(b):
        width = ear_width(c)
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            rings = []
            for t, half, thick in EAR_RINGS:
                wide, face = ear_axes(c, side, t)
                # (cupped: the middle of the ear is set back from its edges)
                rings.append((ear_curve(c, t, side) - face * 0.0025 * s * math.sin(math.pi * t), wide * half * width, face * thick * 0.010 * s))
            b.tube(dome(rings[0], (ear_curve(c, 0.0, side) - ear_curve(c, 0.1, side)).normalized(), 0.004 * s, 2)[::-1] + rings, 12)
        lay_fur(c, b.bm)
    return shapes


def ear_linings(c):
    def shapes(b):
        width = ear_width(c)
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            rings = []
            for t, half in ((0.10, 0.36), (0.25, 0.64), (0.45, 0.76), (0.65, 0.74), (0.82, 0.56), (0.93, 0.26)):
                wide, face = ear_axes(c, side, t)
                rings.append((ear_curve(c, t, side) + face * 0.0012 * s, wide * half * width, face * 0.0014 * s))
            b.tube(rings, 10)
    return shapes


def claws(c):
    def shapes(b):
        s = c.scale
        for suffix, joints in c.legs.items():
            fore = suffix[1] == "f"
            toe = c.toes[suffix]
            for k in range(4):
                off = (k - 1.5) * (0.0035 if fore else 0.0042) * s
                base = toe + V(off, 0.003 * s, -0.001 * s)
                kit.spike(b, base, base + V(off * 0.15, -0.0028 * s, (0.0045 if fore else 0.0065) * s), (0.0011 if fore else 0.0013) * s, 5)
    return shapes


def antler_set(c):
    """The left antler as (pedicle, [beam points], [(tine points, base radius, tip radius)], beam radii), in metres
    from the pedicle: a roe buck's, small, on a hare: up and a little back from in front of the ears, the brow tine
    forward low, a rear tine high, and a fork at the top."""
    hs = c.scale * c.head_scale
    ped = c.at(0.014, 0.028, 0.012)
    k = hs
    beam = [V(0.0, 0.0, 0.0), V(0.004, 0.030, 0.002), V(0.010, 0.064, -0.004), V(0.017, 0.098, -0.012), V(0.021, 0.126, -0.016)]
    tines = [
        ([V(0.006, 0.036, 0.0), V(0.009, 0.050, 0.020), V(0.010, 0.060, 0.034)], 0.0034, 0.0013),  # brow tine, forward
        ([V(0.017, 0.092, -0.012), V(0.019, 0.104, -0.030), V(0.019, 0.112, -0.042)], 0.0030, 0.0012),  # rear tine
        ([V(0.020, 0.118, -0.014), V(0.026, 0.132, -0.002), V(0.028, 0.142, 0.004)], 0.0026, 0.0011),  # the fork
    ]
    beam = [p * k for p in beam]
    tines = [([p * k for p in pts], r0 * k, r1 * k) for pts, r0, r1 in tines]
    return ped, beam, tines, (0.0048 * k, 0.0014 * k)


def smooth_curve(points, steps=4):
    """A Catmull-Rom curve through `points`."""
    out = []
    pts = [points[0]] + list(points) + [points[-1]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(points[-1])
    return out


def tine(b, points, base_r, tip_r, segments=8, gnarl=0.0, seed=0.0):
    """A tapering length of antler along a smooth curve, its tip rounded to a blunt point; a little knobbled
    (pearled) near its base."""
    curve = smooth_curve(points, 3 if not kit.LOW else 1)
    n = len(curve)
    radii = []
    for i in range(n):
        t = i / (n - 1)
        r = base_r + (tip_r - base_r) * (t ** 0.8)
        r *= 1.0 + gnarl * math.sin(i * 2.7 + seed) * (1.0 - t)
        radii.append(r)
    b.strand(curve, radii, segments)


def antlers(c):
    def shapes(b):
        ped, beam, tines, (r0, r1) = antler_set(c)
        for side in (1.0, -1.0):
            def put(p, side=side):
                return V(ped.x * side, ped.y, ped.z) + V(p.x * side, p.y, p.z)
            # The burr: a rough ring where the antler grows from the pedicle
            b.ellipsoid(put(V(0.0, 0.003 * c.scale, 0.0)), V(r0 * 1.5, r0 * 0.75, r0 * 1.5), None, 10, 4)
            tine(b, [put(p) for p in beam], r0, r1, 10, 0.16, side)
            for points, a, z in tines:
                tine(b, [put(p) for p in points], a, z, 8, 0.10, side * 3.0)
        return kit.fused(b, None if kit.LOW else (0.0011 * c.scale, 1, 1400))
    return shapes


def weights(c):
    s = c.scale
    def weigh(part, p):
        if part in ("jaw",):
            return {"jaw": 1.0}
        if part in ("lip", "nose", "teeth"):
            return {"lip": 1.0}
        if part in ("eyes", "antlers"):
            return {"head": 1.0}
        if part in ("ears", "linings"):
            suffix = "_l" if p.x >= 0.0 else "_r"
            side = 1.0 if p.x >= 0.0 else -1.0
            root, mid, end = (V(j.x * side, j.y, j.z) for j in c.ear_points)
            line = (end - root)
            along = (p - root).dot(line.normalized())
            joint = (mid - root).dot(line.normalized())
            hung = blend(-0.002 * s, 0.010 * s, along)
            tip = blend(joint - 0.012 * s, joint + 0.012 * s, along)
            return {"head": 1.0 - hung, "ear" + suffix: hung * (1.0 - tip), "ear_tip" + suffix: hung * tip}
        if part == "claws":
            return {"paw" + leg_of(c, p): 1.0}
        tail = c.tail
        off, along = chain_param(p, tail)
        if p.z < tail[0].z + 0.004 * s and off < 0.026 * s * c.tail_size:
            end = blend(0.4, 1.2, along)
            return {"tail": 1.0 - end, "tail_end": end}
        front = blend(-0.10 * s, 0.03 * s, p.z)
        trunk = {"chest": front, "pelvis": 1.0 - front}
        nb, nt, n_along, throat = neck_frame(c)
        reach = (p - nb).dot(n_along) / (nt - nb).length
        if reach > -0.1 and p.z > nb.z - 0.02 * s and p.y > nb.y - 0.035 * s:
            neck = blend(-0.1, 0.35, reach)
            head_w = blend(0.55, 0.95, reach)
            ahead = (p - c.head).dot(c.face) / (s * c.head_scale)
            if ahead > 0.0:
                head_w = max(head_w, blend(0.0, 0.02, ahead))
                neck = max(neck, blend(0.0, 0.02, ahead))
            made = {"chest": 1.0 - neck, "neck": neck * (1.0 - head_w), "head": neck * head_w}
            # (the chin, under the muzzle, goes with the jaw; the whisker pads and the nose with the lip)
            q = p - c.head
            hs = s * c.head_scale
            along_face = c.unmuzzle(q.dot(c.face) / hs)
            up = q.dot(c.face_up) / hs
            chin = blend(0.030, 0.045, along_face) * blend(-0.013, -0.018, up)
            lipped = blend(0.054, 0.062, along_face) * blend(0.010, 0.004, up) * (1.0 - chin)
            if chin > 0.0 or lipped > 0.0:
                h = made["head"]
                made["head"] = h * (1.0 - chin - lipped)
                made["jaw"] = h * chin
                made["lip"] = h * lipped
            return made
        suffix, leg = leg_share(c, p)
        joints = c.legs[suffix]
        off, along = chain_param(p, joints)
        if part == "coat" and (p - c.toes[suffix]).length < (p - joints[2]).length and along > 2.5:
            along = 3.0
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.012 * s / spans[0], 1.0 + 0.012 * s / spans[1], along)
        hock = blend(2.0 - 0.008 * s / spans[1], 2.0 + 0.008 * s / spans[2], along)
        paw = blend(3.0 - 0.006 * s / spans[2], 3.0 + 0.0001, along)
        if (p - joints[3]).dot(c.toes[suffix] - joints[3]) > 0.0:
            paw = 1.0
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + suffix] = leg * (1.0 - low)
        made["lower" + suffix] = leg * low * (1.0 - hock)
        made["hock" + suffix] = leg * low * hock * (1.0 - paw)
        made["paw" + suffix] = leg * low * hock * paw
        return made
    return weigh


def bones(c):
    listed = [
        ("body", c.body, None), ("chest", c.chest, "body"), ("pelvis", c.pelvis, "body"),
        ("neck", c.neck, "chest"), ("head", c.head, "neck"), ("jaw", c.jaw, "head"), ("lip", c.lip, "head"),
    ]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root, mid, end = (V(j.x * side, j.y, j.z) for j in c.ear_points)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
    listed.append(("nose", c.at(0.077, -0.004), "head"))
    if c.antlers:
        ped, beam, tines, _ = antler_set(c)
        listed.append(("brow", ped + V(0.0, beam[-1].y * 0.6, 0.012 * c.scale), "head"))
    else:
        listed.append(("brow", c.at(0.02, 0.03), "head"))
    listed.append(("tail", c.tail[0], "pelvis"))
    listed.append(("tail_end", c.tail[2], "tail"))
    for suffix, joints in c.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
        listed.append(("toe" + suffix, c.toes[suffix], "paw" + suffix))
    return listed


MATERIALS = [("coat", (0.40, 0.35, 0.29)), ("parts", (1.0, 1.0, 1.0))]


def part_colours(c):
    return {
        "eyes": tuple(c.eye) + (1.0,), "nose": (0.36, 0.27, 0.27, 0.75) if not c.hare else (0.24, 0.19, 0.18, 0.75),
        "teeth": (0.80, 0.76, 0.66, 0.4), "linings": (0.52, 0.46, 0.44, 0.0) if not c.hare else (0.48, 0.43, 0.39, 0.0),
        "claws": (0.10, 0.09, 0.08, 0.2), "antlers": (0.30, 0.24, 0.18, 0.18),
    }


def parts(c):
    made = [("coat", 0, coat(c)), ("lip", 0, lip(c)), ("jaw", 0, jaw(c)), ("ears", 0, ears(c)),
            ("eyes", 1, eyes(c)), ("nose", 1, nose(c)), ("linings", 1, ear_linings(c)), ("claws", 1, claws(c))]
    if not kit.LOW:
        made.append(("teeth", 1, teeth(c)))
    if c.antlers:
        made.append(("antlers", 1, antlers(c)))
    return made


def paint(c, whole, part_of):
    """Vertex colours: on the coat, red how open the surface is, green the dark of the coat, blue the pale, alpha
    the black; on the other parts their colours, and the antlers dark at the burr and polished pale at the tips."""
    s = c.scale
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred_ = [part in ("coat", "jaw", "ears", "lip") for part in part_of]
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
    hs = s * c.head_scale
    ped = antler_set(c)[0] if c.antlers else None
    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part == "antlers":
            reach = (p - V(math.copysign(ped.x, p.x), ped.y, ped.z)).length / (0.13 * hs)
            tip = blend(0.35, 1.0, reach)
            base = colours["antlers"]
            vert[layer] = (base[0] + (0.80 - base[0]) * tip, base[1] + (0.75 - base[1]) * tip, base[2] + (0.64 - base[2]) * tip, base[3] + 0.4 * tip)
            continue
        if part in colours:
            vert[layer] = colours[part]
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 5.0, 0.0), 1.0) if furred_[vert.index] else 1.0
        y, rx, ry = trunk_at(c, p.z)
        pale = 0.0
        dark = 0.0
        black = 0.0
        # The belly and the chest beneath, pale (the trunk's, not the legs'); the back darker, along the spine
        suffix, leg = leg_share(c, p)
        on_trunk = 1.0 - leg
        pale = max(pale, blend(y - ry * 0.3, y - ry * 0.85, p.y) * blend(0.085 * s, 0.06 * s, p.z) * blend(-0.15 * s, -0.11 * s, p.z) * blend(rx * 1.05, rx * 0.7, abs(p.x)) * on_trunk)
        dark = max(dark, blend(y + ry * 0.45, y + ry * 0.95, p.y) * 0.55 * blend(0.11 * s, 0.08 * s, p.z) * on_trunk)
        # The insides of the legs, and the undersides of the feet, pale; their fronts and outsides the coat's
        if leg > 0.0:
            joints = c.legs[suffix]
            off, along = chain_param(p, joints)
            i = min(int(along), 2)
            line_x = abs(joints[i].x + (joints[i + 1].x - joints[i].x) * (along - i))
            inside = blend(-0.001 * s, -0.006 * s, abs(p.x) - line_x) * leg
            pale = max(pale, inside * 0.65)
            if p.y < 0.006 * s:
                pale = max(pale, 0.5 * leg)
        if part == "ears":
            side = 1.0 if p.x >= 0.0 else -1.0
            root, mid, end = (V(j.x * side, j.y, j.z) for j in c.ear_points)
            along = (p - root).dot((end - root).normalized()) / (end - root).length
            wide, face = ear_axes(c, side, min(max(along, 0.0), 1.0))
            centre = ear_curve(c, min(max(along, 0.0), 1.0), side)
            edge = abs((p - centre).dot(wide)) / ear_width(c)
            if c.hare:
                # A hare's ears are black at their tips, outside and in, and darker along their back edges
                black = blend(0.70, 0.80, along)
                dark = max(dark, blend(0.6, 0.95, edge) * 0.6)
            else:
                # A rabbit's ears are rimmed dark at the tip, paler at the back of their roots
                dark = max(dark, blend(0.75, 0.97, edge) * blend(0.5, 0.9, along) * 0.8)
                black = blend(0.86, 0.97, along) * blend(0.5, 0.9, edge) * 0.5
        on_head = p.y > c.neck.y - 0.01 * s and p.z > c.neck.z - 0.02 * s and (p - c.head).length < 0.07 * hs
        if on_head and part != "ears":
            q = p - c.head
            along = c.unmuzzle(q.dot(c.face) / hs)
            up = q.dot(c.face_up) / hs
            out = abs(q.x) / hs
            eye = c.at(*EYE)
            from_eye = (V(abs(p.x), p.y, p.z) - eye).length / hs
            ring = blend(0.0150, 0.0118, from_eye) * blend(0.0098, 0.0112, from_eye)
            chin = blend(-0.014, -0.022, up) * blend(0.025, 0.045, along) * blend(0.022, 0.014, out)
            muzzle = blend(0.058, 0.072, along) * blend(0.004, -0.008, up) * 0.6
            pale = max(pale, ring * 0.7, chin, muzzle)
            # The throat, pale; the top of the head and the bridge of the nose a little darker
            pale = max(pale, blend(-0.010, -0.025, up) * blend(-0.005, 0.015, along) * blend(0.02, 0.012, out) * 0.8)
            dark = max(dark, blend(0.012, 0.03, up) * blend(0.01, 0.05, along) * blend(0.015, 0.004, out) * 0.45)
        # The scut: dark (a hare's black) on top, white beneath and round its sides
        tail_off, tail_along = chain_param(p, c.tail)
        if tail_off < 0.028 * s * c.tail_size and p.z < c.tail[0].z + 0.002 * s:
            i = min(int(tail_along), len(c.tail) - 2)
            on_line = c.tail[i].lerp(c.tail[i + 1], tail_along - i)
            n = (p - on_line)
            n = n.normalized() if n.length > 1e-6 else V(0.0, -1.0, 0.0)
            # (the tail lies along the rump: its top faces back and up, its underside down and forward)
            top = blend(-0.1, 0.5, n.dot(V(0.0, 0.6, -0.8).normalized()))
            pale = max(pale, 1.0 - top)
            if c.hare:
                black = max(black, top * 0.9)
            else:
                dark = max(dark, top * 0.9)
        if pale > 0.3:
            dark *= 1.0 - pale
        vert[layer] = (shade, dark, pale, black)
    # The second texture coordinates: on an eye, where on its front (0.5, 0.5 the middle of the pupil)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            vert = loop.vert
            uv2 = (0.95, 0.95)
            if part_of[vert.index] == "eyes":
                p = kit.from_blender(vert.co)
                side = 1.0 if p.x >= 0.0 else -1.0
                centre = c.at(EYE[0], EYE[1], side * EYE[2])
                local = eye_basis(c, side).inverted() @ (p - centre)
                size = EYE_SIZE * (1.08 if c.hare else 1.0) * hs
                if local.z > -0.3 * size.z:
                    uv2 = (0.5 + local.x / size.x * 0.4, 0.5 + local.y / size.y * 0.4)
            loop[second].uv = uv2
    return layer


def export(c, preview):
    low = kit.LOW
    name = c.name + ("_lo" if low else "")
    if kit.ONLY and c.name not in kit.ONLY:
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = kit.make_armature(bones(c))
    whole = bmesh.new()
    whole.loops.layers.uv.verify()
    part_of = []
    for part, material, shapes in parts(c):
        builder = kit.Builder()
        ready = shapes(builder)
        mesh = ready if ready is not None else kit.fused(builder, None)
        first = len(whole.faces)
        whole.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        whole.faces.ensure_lookup_table()
        for face in whole.faces[first:]:
            face.material_index = material
            face.smooth = not low or part in ("antlers", "eyes")
        part_of += [part] * (len(whole.verts) - len(part_of))
    paint(c, whole, part_of)
    mesh = bpy.data.meshes.new(name)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    for label, srgb in MATERIALS:
        srgb = c.colours.get(label, srgb)
        made = bpy.data.materials.new(label)
        made.use_nodes = True
        colour = tuple(kit.linear(v) for v in srgb) + (1.0,)
        made.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = colour
        made.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
        made.diffuse_color = colour
        mesh.materials.append(made)
    groups = {bone.name: body.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
    deform = whole.verts.layers.deform.verify()
    weigh = weights(c)
    for vert, part in zip(whole.verts, part_of):
        for bone, weight in weigh(part, kit.from_blender(vert.co)).items():
            if weight > 0.001:
                vert[deform][groups[bone]] = weight
    whole.to_mesh(mesh)
    whole.free()
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
            render(preview, name, c)


def render(folder, name, c):
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
    s = c.scale
    middle = (0.0, 0.0, 0.17 * s)
    head = kit.to_blender(c.at(0.04, 0.0))
    views = [("side", (1, 0, 0), middle, 0.55 * s, "MATERIAL"), ("side_paint", (1, 0, 0), middle, 0.55 * s, "VERTEX"),
             ("quarter", (0.7, -0.7, 0.25), middle, 0.6 * s, "VERTEX"), ("front", (0.05, -1, 0.1), middle, 0.5 * s, "VERTEX"),
             ("face", (0.6, -0.75, 0.2), tuple(head), 0.17 * s * (1.5 if c.antlers else 1.0), "VERTEX"),
             ("back", (-0.6, 0.75, 0.35), middle, 0.6 * s, "VERTEX"), ("top", (0.0, 0.0, 1.0), (0.0, 0.0, 0.0), 0.6 * s, "VERTEX")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 3.0 * s
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y" if view != "top" else "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


# --- The warrens ---

EARTH = (0.30, 0.255, 0.20)
TURF = (0.29, 0.35, 0.23)
SPOIL = (0.43, 0.36, 0.27)
DARK = (0.035, 0.03, 0.025)


def warren(name, bank, preview):
    """A warren: a hummock (or a bank against a wall, its back flat on the wall's face at z = 0) with holes dug
    into its flanks. Each hole is a short tunnel, dark inside, going in and down into the earth, its mouth rimmed
    with an earthen lip, a worn trench in front of it and its earth fanned out round that."""
    if kit.ONLY and name not in kit.ONLY:
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(7 if bank else 3)
    if bank:
        half = (1.7, 1.45)
        top = 0.62
        count = 4
    else:
        half = (2.6, 2.1)
        top = 0.50
        count = 5

    def base(x, z):
        """The height of the earth at (x, z), before the holes are dug."""
        if bank:
            u = min(max(z / half[1], 0.0), 1.0)
            across = abs(x) / half[0]
            if across >= 1.0 or z > half[1]:
                return 0.0
            h = top * (1.0 - u) ** 1.25 * (1.0 - across ** 3) ** 1.2
        else:
            r = math.hypot(x / half[0], z / half[1])
            if r >= 1.0:
                return 0.0
            h = top * (1.0 - r * r) ** 0.9
            h = min(h, top * 0.86 + (h - top * 0.86) * 0.35)  # (the top worn flat by them sitting on it)
        return h + 0.022 * math.sin(x * 4.1 + z * 2.3) * math.sin(z * 3.7 - x * 1.3) * (h / top)

    # The holes: the middle of the mouth's floor (x, floor, z), and the way in (flat)
    radius = 0.072
    holes = []
    for i in range(count):
        if bank:
            x = -1.15 + 2.3 * (i + 0.5) / count + rng.uniform(-0.15, 0.15)
            z = rng.uniform(0.5, 0.95)
            inward = V(rng.uniform(-0.3, 0.3), 0.0, -1.0).normalized()
        else:
            angle = math.tau * (i + rng.uniform(-0.2, 0.2)) / count + 0.4
            r = rng.uniform(0.62, 0.8)
            x, z = math.cos(angle) * half[0] * r, math.sin(angle) * half[1] * r
            inward = V(-x / half[0], 0.0, -z / half[1]).normalized().lerp(V(rng.uniform(-1, 1), 0.0, rng.uniform(-1, 1)), 0.15).normalized()
        floor = max(base(x, z) - 0.04 - radius * 2.0, 0.0)
        holes.append((V(x, floor, z), inward))

    def shape(x, z):
        h = base(x, z)
        for mouth, inward in holes:
            out = V(x - mouth.x, 0.0, z - mouth.z)
            ahead = -out.dot(inward)  # (out in front of the mouth)
            side = (out + inward * ahead).length
            # The spoil: earth thrown out in front of each hole, a low fan
            if ahead > -0.15:
                h += blend(0.8, 0.0, math.hypot(ahead * 0.75, side * 1.3)) * 0.09
            lane = blend(radius * 3.4, radius * 1.3, side)
            if lane > 0.0 and -0.75 < ahead < 0.7:
                # The trench worn in front of the mouth, rising out of it; behind the mouth the earth rises
                # again, smoothly, over the tunnel to bury it
                floor = mouth.y + 0.025 + max(ahead - 0.04, 0.0) * 0.5
                cover = mouth.y + 0.04 + radius * 2.6 + 0.03
                rise = blend(-0.04, -0.4, ahead)
                want = floor + (cover - floor) * rise
                if ahead > -0.04:
                    h = h + (min(h, want) - h) * lane
                else:
                    h = h + (want - h) * lane * blend(-0.75, -0.5, ahead) if want > h or ahead > -0.4 else h
        return h - 0.04

    n = 84 if not kit.LOW else 34
    bm = bmesh.new()
    colour = bm.verts.layers.float_color.new("Color")
    grid = {}
    x0, x1 = -half[0] - 0.4, half[0] + 0.4
    z0, z1 = (0.0, half[1] + 0.8) if bank else (-half[1] - 0.4, half[1] + 0.4)
    for i in range(n + 1):
        for j in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            z = z0 + (z1 - z0) * j / n
            grid[(i, j)] = bm.verts.new(kit.to_blender(V(x, shape(x, z), z)))
    for i in range(n):
        for j in range(n):
            bm.faces.new((grid[(i, j)], grid[(i, j + 1)], grid[(i + 1, j + 1)], grid[(i + 1, j)]))
    for vert in bm.verts:
        p = kit.from_blender(vert.co)
        h = max(base(p.x, p.z), 0.0) / top
        col = [EARTH[k] + (TURF[k] - EARTH[k]) * blend(0.45, 0.85, h) for k in range(3)]
        for mouth, inward in holes:
            flat = V(p.x - mouth.x, 0.0, p.z - mouth.z)
            ahead = -flat.dot(inward)
            fresh = blend(0.8, 0.12, flat.length) * blend(-0.25, 0.1, ahead)
            col = [col[k] + (SPOIL[k] - col[k]) * fresh for k in range(3)]
            worn = blend(radius * 2.0, radius * 1.0, (flat + inward * ahead).length) * blend(0.4, 0.0, ahead) * blend(-0.08, 0.0, ahead)
            col = [col[k] * (1.0 - 0.35 * worn) for k in range(3)]
            # (under the hood of the mouth, where the ground steps up over the tunnel: dark, as the tunnel is)
            within = blend(radius * 2.0, radius * 1.2, (flat + inward * ahead).length) * blend(0.0, -0.06, ahead) * blend(-0.75, -0.6, ahead) * blend(mouth.y + radius * 2.3, mouth.y + radius * 1.7, p.y)
            col = [col[k] + (DARK[k] - col[k]) * within for k in range(3)]
        noise = 0.9 + 0.2 * ((math.sin(p.x * 37.1 + p.z * 11.3) * 43758.5453) % 1.0)
        vert[colour] = (col[0] * noise, col[1] * noise, col[2] * noise, 1.0)
    # The tunnels: each an open tube, its mouth a little out in the trench, dark within, an earthen lip round it
    markers = []
    segments = 16 if not kit.LOW else 8
    down = math.radians(12.0)
    for mouth, inward in holes:
        axis = (inward * math.cos(down) + V(0.0, -math.sin(down), 0.0)).normalized()
        across = V(0.0, 1.0, 0.0).cross(inward).normalized()
        up = axis.cross(across).normalized()
        if up.y < 0.0:
            up = -up
        centre0 = mouth + V(0.0, radius, 0.0)
        stations = [(-0.05, 1.0), (0.0, 1.0), (0.12, 0.97), (0.26, 0.92), (0.42, 0.85), (0.56, 0.7)]
        inner = []
        for t, k in stations:
            ring = []
            c0 = centre0 + axis * t
            for s in range(segments):
                a = math.tau * s / segments
                p = c0 + across * math.cos(a) * radius * 1.3 * k + up * math.sin(a) * radius * k
                ring.append(bm.verts.new(kit.to_blender(p)))
                dark = blend(-0.08, 0.10, t)
                ring[-1][colour] = tuple(SPOIL[q] * 0.6 + (DARK[q] - SPOIL[q] * 0.6) * dark for q in range(3)) + (1.0,)
            inner.append(ring)
        # (the far end, shut, darkest)
        end = bm.verts.new(kit.to_blender(centre0 + axis * 0.62))
        end[colour] = DARK + (1.0,)
        lip = []
        for s in range(segments):
            a = math.tau * s / segments
            wobble = 1.0 + 0.08 * math.sin(a * 3.0 + mouth.x * 9.0)
            p = centre0 + axis * 0.02 + (across * math.cos(a) * radius * 1.3 + up * math.sin(a) * radius) * 1.28 * wobble
            lip.append(bm.verts.new(kit.to_blender(p + V(0.0, -0.01 if math.sin(a) < 0.0 else 0.0, 0.0))))
            lip[-1][colour] = SPOIL + (1.0,)
        back = []
        for s in range(segments):
            a = math.tau * s / segments
            p = centre0 + axis * 0.26 + (across * math.cos(a) * radius * 1.3 + up * math.sin(a) * radius) * 1.75
            back.append(bm.verts.new(kit.to_blender(p)))
            back[-1][colour] = EARTH + (1.0,)
        for r in range(len(inner) - 1):
            for s in range(segments):
                q = (s + 1) % segments
                # (inside: facing in)
                bm.faces.new((inner[r][s], inner[r + 1][s], inner[r + 1][q], inner[r][q]))
        for s in range(segments):
            q = (s + 1) % segments
            bm.faces.new((inner[-1][s], end, inner[-1][q]))
            # the lip: from the mouth's edge out and back over the outside, into the earth
            bm.faces.new((lip[s], inner[0][s], inner[0][q], lip[q]))
            bm.faces.new((back[s], lip[s], lip[q], back[q]))
        markers.append((mouth + axis * 0.02 + V(0.0, 0.01, 0.0), mouth + axis * 0.45 + V(0.0, 0.01, 0.0) - V(0.0, math.sin(down) * 0.45, 0.0) * 0.0))
    for face in bm.faces:
        face.smooth = True
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mound = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(mound)
    material = bpy.data.materials.new("earth")
    material.use_nodes = True
    mesh.materials.append(material)
    mesh.color_attributes.active_color = mesh.color_attributes["Color"]
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    for k, (mouth, deep) in enumerate(markers):
        for label, at in (("hole_%d" % k, mouth), ("deep_%d" % k, deep)):
            empty = bpy.data.objects.new(label, None)
            empty.location = kit.to_blender(at)
            bpy.context.collection.objects.link(empty)
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True,
                              export_vertex_color="ACTIVE")
    print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), kit.triangle_count(mesh)))
    if preview:
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_backface_culling = False
        scene.render.resolution_x, scene.render.resolution_y = 1000, 700
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        scene.collection.objects.link(camera)
        scene.camera = camera
        for view, target, offset in (("", Vector((0.0, -0.6 if bank else 0.0, 0.2)), Vector((2.6, -6.5, 2.4))),
                                     ("_hole", kit.to_blender(markers[0][0]), kit.to_blender(V(0.0, 0.25, 0.0) - holes[0][1] * 0.9) + Vector((0.2, 0.0, 0.0)))):
            camera.location = target + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(preview, name + view + ".png")
            bpy.ops.render.render(write_still=True)


def main():
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        for animal in ANIMALS:
            export(animal, preview)
    for low in (False, True):
        kit.LOW = low
        warren("warren_mound" + ("_lo" if low else ""), False, preview if not low else None)
        warren("warren_bank" + ("_lo" if low else ""), True, preview if not low else None)


if __name__ == "__main__":
    main()
