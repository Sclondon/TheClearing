"""Builds the deer (creatures/deer) and the bull elk (creatures/elk) and exports them for Godot.

Run from the game's root (Blender 4.3):
    blender --background --python creatures/deer/tools/build_deer.py
    blender --background --python creatures/deer/tools/build_deer.py -- <preview folder> deer_doe   # one, with pictures

Writes creatures/deer/models/deer_doe.glb, deer_buck.glb and creatures/elk/models/elk_bull.glb, elk_cow.glb, and a demade `_lo`
version of each. Nothing else is written (an editable .blend and pictures go to the preview folder, when there is one).

They are real animals first, built from a deer's anatomy:
- A narrow deep chest slung between the shoulder blades, a level back, a rounded rump, and a belly that lifts to the
  flank.
- Long slender legs on the cervid plan. Fore: the shoulder joint low at the front of the chest, the elbow tucked up
  against the brisket, the forearm down to the knee (the carpus, a knob at the front), a long cannon, the fetlock,
  a sloping pastern and a cloven hoof of two pointed toes with the dewclaws behind. Hind: the hip high in the rump,
  the stifle forward at the flank, the long gaskin back down to a high hock (its point sticks out behind), and the
  long cannon straight down from it.
- The neck rising forward from the chest, deep at its base, carried up; a long tapering head carried with the face
  slanting down, big dark eyes at its sides, large ears, a black nose; the jaw is a bone of its own.
- White-tailed deer: grey-brown winter coat, white throat patch, eye ring and band behind the nose, white belly and
  inside the legs, and a broad tail brown on top, white under, with a white rump round it (the flag). The buck
  carries antlers: main beams that sweep back and out and curve forward, with tines standing up off them.
- The bull elk is half as big again, heavier: pale tan body, dark chocolate neck, head and legs, a buff rump patch
  round a stub of a tail, and a long shaggy dark mane hanging under its neck (material `mane`). Its antlers are a
  six-point rack: long beams sweeping back over its shoulders, brow and bez tines forward over its face, the royal
  (dagger) tine longest, and a fork at the top. The cow is smaller, with neither antlers nor mane.

The bones are the dog's (creatures/dog, tools/build_dog.py), with the same names, so the same kind of rig poses them
(creatures/deer/deer_rig.gd):

    body, chest, pelvis, neck, neck_1, head, jaw, ear(_tip, _end)_l/_r, tail, tail_1, tail_end
    fore: `upper` (shoulder to elbow), `lower` (forearm, to the knee), `hock` (the cannon, to the fetlock), `paw`
    hind: `upper` (thigh, hip to stifle), `lower` (gaskin, to the hock), `hock` (cannon, to the fetlock), `paw`
    `toe`: a marker under each paw, where the tip of the hoof meets the ground (nothing is weighted to it)

The `paw` bone is at the fetlock: the pastern and the hoof below it go with it.

Three surfaces: `coat` (fur), `mane` (the elk's long hair, and on the deer the tail's long fringe: nothing in the
deer, which has none), `parts` (eyes, nose, hooves, antlers, mouth, ear linings), the parts' colours in their vertex
colours. The coat's vertex colours: red how open the surface is (dark in creases), green how far it is the dark of the
coat (the elk's neck and legs, the deer's tail top, the nose), blue how far the pale (belly, throat, rump, eye ring).

Everything is in Godot space (metres, Y up, facing +Z, +X its left). Uses the character controller's
tools/build_character.py (from GameCommon) for its shape-building.
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
import build_character as kit  # noqa: E402  (the character controller's shape-building tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
SUFFIXES = ("_fl", "_fr", "_rl", "_rr")


def V(x, y, z):
    return Vector((x, y, z))


def rot_x(angle):
    return Matrix.Rotation(angle, 3, "X")


class Cervid:
    """One animal's measurements (at the size it is built, metres)."""

    def __init__(self, **spec):
        self.__dict__.update(spec)
        s = self.scale
        self.body = V(0.0, 0.76, -0.05) * s
        self.chest = V(0.0, 0.78, 0.20) * s
        self.pelvis = V(0.0, 0.78, -0.30) * s
        self.neck = V(0.0, 0.84, 0.32) * s
        self.head = self.atlas * s
        self.neck_1 = self.neck.lerp(self.head, 0.5)
        # The way the face points (down from level by `face_tilt`), and up from it.
        a = self.face_tilt
        self.face = V(0.0, -math.sin(a), math.cos(a))
        self.face_up = V(0.0, math.cos(a), math.sin(a))
        self.jaw = self.at(0.03, -0.035)
        self.legs = {}
        for suffix in SUFFIXES:
            side = 1.0 if suffix[2] == "l" else -1.0
            joints = self.fore if suffix[1] == "f" else self.hind
            self.legs[suffix] = [V(j.x * side, j.y, j.z) * s for j in joints]
        self.toes = {suffix: joints[3] + V(0.0, -joints[3].y, self.toe_ahead * s) for suffix, joints in self.legs.items()}
        self.ear = [self.at(-0.012, 0.046, 0.034), self.at(-0.048, 0.104, 0.082), self.at(-0.075, 0.150, 0.140)]
        self.ear = [V(p.x, p.y, p.z) for p in self.ear]
        tail_root = V(0.0, 0.86, -0.565) * s
        self.tail = [tail_root, tail_root + V(0.0, -0.075, -0.035) * s * self.tail_length,
                     tail_root + V(0.0, -0.17, -0.05) * s * self.tail_length]

    def at(self, along, up, out=0.0):
        """A point on the head: `along` the face from the atlas, `up` from its line, `out` to its left (deer units;
        the muzzle past the eyes drawn `muzzle` as long)."""
        s = self.scale * self.head_scale
        if along > 0.08:
            along = 0.08 + (along - 0.08) * self.muzzle
        return self.head + (self.face * along + self.face_up * up + X * out) * s

    def unmuzzle(self, along):
        """How far along the face a point is, in the measure `at` takes."""
        return along if along <= 0.08 else 0.08 + (along - 0.08) / self.muzzle


def deer(name, buck):
    return Cervid(
        name=name, kind="deer", buck=buck, scale=1.06 if buck else 1.0, head_scale=1.0, thick=1.07 if buck else 1.0, muzzle=0.86,
        # (along the body, centre height, half width, half height): a deep narrow chest, a level back, the belly
        # lifting to the flank, a rounded rump
        trunk=[(-0.585, 0.800, 0.040, 0.050), (-0.555, 0.790, 0.085, 0.115), (-0.49, 0.778, 0.118, 0.150),
               (-0.40, 0.770, 0.133, 0.165), (-0.29, 0.772, 0.136, 0.158), (-0.16, 0.758, 0.146, 0.178),
               (-0.02, 0.750, 0.152, 0.192), (0.10, 0.752, 0.146, 0.198), (0.21, 0.764, 0.126, 0.194),
               (0.30, 0.770, 0.098, 0.168), (0.37, 0.762, 0.070, 0.124), (0.41, 0.760, 0.040, 0.070)],
        # Shoulder (the point of it), elbow, knee, fetlock; hip, stifle, hock, fetlock (the left legs)
        fore=[V(0.086, 0.715, 0.300), V(0.088, 0.548, 0.212), V(0.080, 0.300, 0.240), V(0.078, 0.088, 0.248)],
        hind=[V(0.092, 0.785, -0.380), V(0.104, 0.580, -0.262), V(0.084, 0.430, -0.505), V(0.080, 0.090, -0.465)],
        toe_ahead=0.072,
        # (how far down the leg, counted in joints; half width; half depth; forward offset)
        fore_shape=[(0.45, 0.034, 0.050, -0.006), (0.7, 0.036, 0.056, -0.008), (0.92, 0.036, 0.056, -0.008),
                    (1.0, 0.034, 0.052, -0.004), (1.25, 0.030, 0.042, 0.002), (1.6, 0.022, 0.030, 0.0), (1.88, 0.0185, 0.025, 0.0),
                    (2.0, 0.021, 0.027, 0.003), (2.12, 0.0165, 0.022, 0.0), (2.5, 0.0145, 0.0195, -0.001), (2.85, 0.015, 0.020, -0.001),
                    (3.0, 0.0175, 0.024, -0.002)],
        hind_shape=[(0.5, 0.040, 0.070, -0.012), (0.7, 0.044, 0.078, -0.012), (0.85, 0.046, 0.082, -0.01),
                    (1.0, 0.042, 0.072, -0.004), (1.3, 0.036, 0.060, -0.008), (1.62, 0.026, 0.044, -0.010), (1.86, 0.019, 0.036, -0.012),
                    (2.0, 0.019, 0.038, -0.010), (2.12, 0.0165, 0.026, -0.002), (2.5, 0.0150, 0.0215, 0.0), (2.85, 0.015, 0.0205, -0.001),
                    (3.0, 0.0175, 0.024, -0.002)],
        # The neck: (how far up it, half width, half depth, how far the throat hangs under it)
        neck_shape=[(-0.25, 0.088, 0.135, 0.030), (0.0, 0.076, 0.112, 0.026), (0.3, 0.062, 0.088, 0.014),
                    (0.6, 0.053, 0.074, 0.006), (0.85, 0.050, 0.068, 0.0), (1.05, 0.050, 0.062, -0.004)],
        atlas=V(0.0, 1.175, 0.530), face_tilt=0.62,
        ear_size=(0.050, 0.150), tail_length=1.0, tail_width=0.050,
        mane=False, antlers="whitetail" if buck else None,
        colours=dict(coat=(0.33, 0.27, 0.215), dark=(0.20, 0.155, 0.12), pale=(0.80, 0.77, 0.72)),
    )


def elk(name, bull=True):
    return Cervid(
        name=name, kind="elk", buck=bull, scale=1.62 if bull else 1.46, head_scale=1.28 if bull else 1.16, thick=1.16 if bull else 1.04, muzzle=0.98,
        trunk=[(-0.585, 0.800, 0.042, 0.052), (-0.555, 0.790, 0.090, 0.120), (-0.49, 0.778, 0.124, 0.156),
               (-0.40, 0.770, 0.138, 0.170), (-0.29, 0.770, 0.140, 0.164), (-0.16, 0.756, 0.152, 0.186),
               (-0.02, 0.750, 0.160, 0.202), (0.10, 0.756, 0.156, 0.210), (0.21, 0.772, 0.138, 0.210),
               (0.30, 0.780, 0.108, 0.184), (0.37, 0.772, 0.078, 0.140), (0.41, 0.766, 0.044, 0.080)],
        fore=[V(0.088, 0.715, 0.300), V(0.090, 0.548, 0.212), V(0.082, 0.305, 0.240), V(0.080, 0.092, 0.248)],
        hind=[V(0.094, 0.785, -0.380), V(0.106, 0.580, -0.262), V(0.086, 0.430, -0.500), V(0.082, 0.094, -0.462)],
        toe_ahead=0.070,
        fore_shape=[(0.45, 0.034, 0.050, -0.006), (0.7, 0.036, 0.056, -0.008), (0.92, 0.038, 0.058, -0.008),
                    (1.0, 0.036, 0.054, -0.004), (1.25, 0.032, 0.045, 0.002), (1.6, 0.024, 0.032, 0.0), (1.88, 0.020, 0.027, 0.0),
                    (2.0, 0.023, 0.029, 0.003), (2.12, 0.018, 0.024, 0.0), (2.5, 0.016, 0.021, -0.001), (2.85, 0.0165, 0.022, -0.001),
                    (3.0, 0.019, 0.026, -0.002)],
        hind_shape=[(0.5, 0.040, 0.070, -0.012), (0.7, 0.044, 0.078, -0.012), (0.85, 0.048, 0.084, -0.01),
                    (1.0, 0.044, 0.074, -0.004), (1.3, 0.038, 0.062, -0.008), (1.62, 0.028, 0.046, -0.010), (1.86, 0.020, 0.038, -0.012),
                    (2.0, 0.020, 0.040, -0.010), (2.12, 0.018, 0.028, -0.002), (2.5, 0.016, 0.023, 0.0), (2.85, 0.0165, 0.022, -0.001),
                    (3.0, 0.019, 0.026, -0.002)],
        # A bull's neck: thick and deep, carried lower and further forward
        neck_shape=[(-0.25, 0.112, 0.160, 0.034), (0.0, 0.102, 0.140, 0.030), (0.3, 0.088, 0.118, 0.020),
                    (0.6, 0.076, 0.100, 0.010), (0.85, 0.066, 0.086, 0.0), (1.05, 0.062, 0.076, -0.004)],
        atlas=V(0.0, 1.165, 0.560), face_tilt=0.52,
        ear_size=(0.040, 0.118), tail_length=0.45, tail_width=0.034,
        mane=bull, antlers="elk" if bull else None,
        colours=dict(coat=(0.50, 0.40, 0.29), dark=(0.155, 0.105, 0.075), pale=(0.80, 0.70, 0.52)),
    )


ANIMALS = [deer("deer_doe", False), deer("deer_buck", True), elk("elk_bull"), elk("elk_cow", False)]


def out_folder(animal):
    return os.path.join(GAME, "creatures", "elk" if animal.kind == "elk" else "deer", "models")


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
    return r[0] * s, r[1] * s * c.thick, r[2] * s


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


def leg_share(c, p):
    """Which leg a point is nearest, and how much of it goes with that leg rather than the trunk."""
    s = c.scale
    suffix = ("_f" if p.z > -0.05 * s else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = c.legs[suffix]
    top = joints[0]
    off = chain_param(V(top.x, p.y, p.z), joints)[0]
    return suffix, blend(top.y + 0.03 * s, top.y - 0.10 * s, p.y) * blend(0.10 * s, 0.065 * s, math.hypot(p.x - top.x, off / 1.6))


def lay_fur(c, bm):
    """Texture coordinates for the fur shader: (along the lie of the hair, across it), in metres."""
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            suffix, leg = leg_share(c, p)
            joints = c.legs[suffix]
            trunk = (-p.z, math.atan2(p.x, p.y - c.body.y) * 0.12 * c.scale)
            limb_uv = (joints[0].y - p.y - joints[0].z, math.atan2(p.x - joints[0].x, p.z - joints[0].z) * 0.04 * c.scale)
            loop[uv].uv = (trunk[0] + (limb_uv[0] - trunk[0]) * leg, trunk[1] + (limb_uv[1] - trunk[1]) * leg)


def fuse(builder, fuse_with):
    """The builder's shapes as one surface (as kit.fused), smoothed so that the masses run into each other the way
    muscle does under a skin, without wasting away the thin parts: a Laplacian smooth that keeps the volume."""
    if fuse_with is None:
        return kit.fused(builder, None)
    voxel, passes, budget = fuse_with
    mesh = bpy.data.meshes.new("part")
    builder.bm.to_mesh(mesh)
    builder.bm.free()
    part = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(part)
    remesh = part.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    smooth = part.modifiers.new("smooth", "LAPLACIANSMOOTH")
    smooth.iterations = passes
    smooth.lambda_factor = 1.2
    smooth.lambda_border = 0.0
    smooth.use_volume_preserve = True
    smooth.use_normalized = True
    tidy = part.modifiers.new("tidy", "SMOOTH")
    tidy.factor = 0.5
    tidy.iterations = 2

    def evaluated():
        bpy.context.view_layer.update()
        return bpy.data.meshes.new_from_object(part.evaluated_get(bpy.context.evaluated_depsgraph_get()))

    dense = kit.triangle_count(evaluated())
    decimate = part.modifiers.new("decimate", "DECIMATE")
    decimate.ratio = min(1.0, budget / dense)
    result = evaluated()
    bpy.data.objects.remove(part)
    return result


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
    b.tube(dome(rings[0], -directions[0], 0.04 * scale)[::-1] + rings, segments)


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


def neck_frame(c):
    base, top = c.neck + V(0.0, -0.02, -0.01) * c.scale, c.head + V(0.0, -0.01, 0.0) * c.scale
    along = (top - base).normalized()
    throat = X.cross(along).normalized()  # (points forward and down, under the neck)
    return base, top, along, throat


def neck_at(c, t):
    """(centre, half width, half depth) of the neck `t` of the way up it."""
    base, top, along, throat = neck_frame(c)
    shape = c.neck_shape
    for a, n in zip(shape, shape[1:]):
        if t <= n[0] or n is shape[-1]:
            k = min(max((t - a[0]) / (n[0] - a[0]), 0.0), 1.0)
            vals = [a[i] + (n[i] - a[i]) * k for i in (1, 2, 3)]
            break
    s = c.scale
    return base.lerp(top, t) + throat * vals[2] * s, vals[0] * s * c.thick, vals[1] * s * c.thick


def side_mass(b, side, rows, segments=14):
    """A mass down one side of the body (a shoulder, a thigh): rings across it, level, from the top down;
    each (height, along, out, half width, half depth) at the built size."""
    rings = [(V(side * out, y, z), X * w, Z * d) for y, z, out, w, d in rows]
    b.tube(dome(rings[0], Y, rows[0][3] * 0.8)[::-1] + rings + dome(rings[-1], -Y, rows[-1][3] * 0.8), segments)


def mass(c):
    """The body's masses, fused and smoothed hard so that they run into each other as muscle does under a skin:
    the trunk, the withers, the shoulders and upper arms, the thighs, the root of the neck and the neck."""
    b = kit.Builder()
    low = kit.LOW
    s = c.scale
    th = c.thick
    rings = [(V(0.0, y * s, z * s), X * rx * s * th, Y * ry * s) for z, y, rx, ry in c.trunk]
    b.tube(dome(rings[0], -Z, 0.04 * s)[::-1] + rings + dome(rings[-1], Z, 0.03 * s), 20)
    top = trunk_at(c, 0.22 * s)
    # The withers: the tops of the shoulder blades, a long low rise over the back
    b.ellipsoid(V(0.0, top[0] + top[2] - 0.035 * s, 0.17 * s), V(0.050 * s * th, 0.040 * s, 0.15 * s))
    # The root of the neck, broad, running down into the brisket between the forelegs
    b.ellipsoid(V(0.0, 0.80 * s, 0.33 * s), V(0.082 * s * th, 0.13 * s, 0.10 * s), rot_x(-0.35))
    b.ellipsoid(V(0.0, 0.655 * s, 0.31 * s), V(0.072 * s * th, 0.090 * s, 0.078 * s))
    for side in (1.0, -1.0):
        # The shoulder and upper arm: from the withers down the blade to the point of the shoulder, then back down
        # to the elbow, the triceps filling in behind
        side_mass(b, side, [(0.90 * s, 0.205 * s, 0.050 * s * th, 0.045 * s * th, 0.070 * s),
                            (0.82 * s, 0.240 * s, 0.072 * s * th, 0.055 * s * th, 0.090 * s),
                            (0.73 * s, 0.262 * s, 0.084 * s * th, 0.058 * s * th, 0.095 * s),
                            (0.65 * s, 0.245 * s, 0.086 * s * th, 0.052 * s * th, 0.080 * s),
                            (0.585 * s, 0.220 * s, 0.086 * s * th, 0.040 * s * th, 0.055 * s)])
        # The thigh: the round of the rump over the hip, down to the stifle in front and, behind, the hamstrings
        # running down towards the hock
        side_mass(b, side, [(0.89 * s, -0.40 * s, 0.050 * s * th, 0.050 * s * th, 0.13 * s),
                            (0.80 * s, -0.41 * s, 0.072 * s * th, 0.068 * s * th, 0.170 * s),
                            (0.70 * s, -0.405 * s, 0.084 * s * th, 0.072 * s * th, 0.168 * s),
                            (0.61 * s, -0.385 * s, 0.092 * s * th, 0.064 * s * th, 0.138 * s),
                            (0.54 * s, -0.385 * s, 0.092 * s * th, 0.050 * s * th, 0.100 * s),
                            (0.49 * s, -0.405 * s, 0.090 * s * th, 0.036 * s * th, 0.066 * s)])
    # The neck, rising forward out of the chest, deep at its root
    nb, nt, along, throat = neck_frame(c)
    nrings = []
    for t, _, _, _ in c.neck_shape:
        centre, w, d = neck_at(c, t)
        nrings.append((centre, X * w, throat * d))
    b.tube(nrings, 16)
    if c.mane:
        # A bull's neck is maned all round: thicker hair over the crest and a dewlap of it under the throat
        for t in (0.15, 0.4, 0.65):
            centre, w, d = neck_at(c, t)
            b.ellipsoid(centre + throat * d * 0.55, V(w * 0.85, d * 0.65, d * 0.5), None, 12, 6)
    if low:
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
    smooth.iterations = 30
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
        # The tail: broad, short, flat
        tw = c.tail_width * s
        tube_along(b, c.tail, [tw * 0.75, tw, tw * 0.55], [tw * 0.45, tw * 0.42, tw * 0.3], 10)
        for suffix, joints in c.legs.items():
            fore = suffix[1] == "f"
            limb(b, joints, c.fore_shape if fore else c.hind_shape, s, th)
            knob_at = joints[2] + (V(0.0, 0.004 * s, 0.012 * s) if fore else V(0.0, 0.024 * s, -0.026 * s))
            # The knee is a knob at the front; the point of the hock sticks out behind
            b.ellipsoid(knob_at, V(0.019 * s, (0.024 if fore else 0.030) * s, 0.017 * s), None if fore else rot_x(-0.35), 10, 6)
            # The fetlock, and the pastern sloping forward from it to the hoof
            fet = joints[3]
            b.ellipsoid(fet + V(0.0, 0.0, -0.004 * s), V(0.0185 * s, 0.022 * s, 0.022 * s), None, 10, 6)
            toe = c.toes[suffix]
            coronet = V(fet.x, 0.036 * s, toe.z - 0.038 * s)
            tube_along(b, [fet, fet.lerp(coronet, 0.5), coronet], [0.0165 * s, 0.015 * s, 0.017 * s], [0.020 * s, 0.017 * s, 0.018 * s], 10)
        return furred(c, b, (0.0042 * s, 4, 24000 if c.kind == "deer" else 26000))
    return shapes


def head(c, b):
    """The head, on the coat: the skull, the face tapering to the nose, the cheeks, brows, lips and the chin."""
    s = c.scale * c.head_scale
    at = c.at
    elk_ = c.kind == "elk"
    # The cranium and the poll
    b.ellipsoid(at(0.035, 0.006), V(0.056 * s, 0.054 * s, 0.068 * s), rot_x(c.face_tilt), 16, 9)
    # The face: from the brow, tapering to the muzzle; deep, the nose blunt
    rows = [(0.02, 0.010, 0.054, 0.052), (0.08, 0.002, 0.048, 0.048), (0.13, -0.010, 0.037, 0.042),
            (0.175, -0.017, 0.031, 0.039), (0.215, -0.021, 0.028, 0.036), (0.245, -0.022, 0.027, 0.034), (0.262, -0.021, 0.024, 0.028)]
    if elk_:
        # (an elk's muzzle is longer and heavier, its nose broad)
        rows = [(0.02, 0.010, 0.054, 0.052), (0.08, 0.002, 0.048, 0.048), (0.14, -0.010, 0.039, 0.044),
                (0.19, -0.017, 0.033, 0.041), (0.235, -0.021, 0.031, 0.039), (0.27, -0.022, 0.029, 0.035), (0.29, -0.021, 0.025, 0.028)]
    tube_along(b, [at(a, u) for a, u, _, _ in rows], [w * s for _, _, w, _ in rows], [d * s for _, _, _, d in rows], 16)
    for side in (1.0, -1.0):
        b.ellipsoid(at(0.072, 0.030, side * 0.036), V(0.019 * s, 0.013 * s, 0.026 * s), rot_x(c.face_tilt))  # brow over the eye
        b.ellipsoid(at(0.085, -0.024, side * 0.035), V(0.020 * s, 0.028 * s, 0.045 * s), rot_x(c.face_tilt))  # cheek
        lip = 0.215 if not elk_ else 0.24
        b.ellipsoid(at(lip, -0.032, side * 0.018), V(0.013 * s, 0.015 * s, 0.034 * s), rot_x(c.face_tilt))  # upper lip
    # The throat latch, under the back of the jaw
    b.ellipsoid(at(0.0, -0.040), V(0.044 * s, 0.050 * s, 0.055 * s), rot_x(c.face_tilt))


def jaw(c):
    def shapes(b):
        s = c.scale * c.head_scale
        at = c.at
        k = 1.0 if c.kind == "deer" else 1.1
        pts = [at(0.03, -0.042), at(0.10, -0.050), at(0.17 * k, -0.049), at(0.22 * k, -0.044), at(0.245 * k, -0.040)]
        tube_along(b, pts, [0.036 * s, 0.028 * s, 0.021 * s, 0.017 * s, 0.014 * s], [0.018 * s, 0.015 * s, 0.013 * s, 0.012 * s, 0.010 * s], 12)
        return furred(c, b, (0.0035 * c.scale, 2, 900))
    return shapes


def nose(c):
    def shapes(b):
        s = c.scale * c.head_scale
        k = 0.262 if c.kind == "deer" else 0.29
        # The bare black nose (the rhinarium), wet, over the front of the muzzle, a nostril curling back at each side
        b.ellipsoid(c.at(k - 0.004, -0.011), V(0.024 * s, 0.019 * s, 0.015 * s), rot_x(c.face_tilt + 0.75), 12, 6)
        for side in (1.0, -1.0):
            b.ellipsoid(c.at(k - 0.01, -0.016, side * 0.016), V(0.006 * s, 0.012 * s, 0.008 * s), rot_x(c.face_tilt + 0.6), 8, 4)
    return shapes


EYE = (0.086, 0.031, 0.041)
EYE_SIZE = V(0.021, 0.0165, 0.0125)


def eye_basis(c, side):
    return Matrix.Rotation(side * 1.3, 3, "Y") @ rot_x(c.face_tilt - 0.15)


def eyes(c):
    def shapes(b):
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            # Big, dark, bulging, at the sides of the head (a deer sees nearly all the way round)
            b.ellipsoid(c.at(EYE[0], EYE[1], side * EYE[2]), EYE_SIZE * s, eye_basis(c, side), 12, 7)
    return shapes


def glands(c):
    def shapes(b):
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            # The dark slit of the gland in front of each eye
            b.ellipsoid(c.at(EYE[0] + 0.03, EYE[1] - 0.016, side * (EYE[2] - 0.006)), V(0.004 * s, 0.006 * s, 0.014 * s), Matrix.Rotation(side * 0.9, 3, "Y") @ rot_x(c.face_tilt + 0.4), 6, 4)
    return shapes


def ear_curve(c, t, side):
    root, mid, end = c.ear
    bend = mid * 2.0 - (root + end) * 0.5
    p = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(p.x * side, p.y, p.z)


# (how far along the ear, half its width, half its thickness): broad and rounded, a deer's or an elk's
EAR_RINGS = ((0.0, 0.40, 0.30), (0.10, 0.66, 0.24), (0.28, 0.92, 0.17), (0.45, 1.0, 0.14),
             (0.62, 0.92, 0.12), (0.78, 0.68, 0.10), (0.90, 0.40, 0.08), (0.97, 0.16, 0.06), (1.0, 0.04, 0.05))


def ear_axes(c, side, t):
    ahead = (ear_curve(c, min(t + 0.05, 1.0), side) - ear_curve(c, max(t - 0.05, 0.0), side)).normalized()
    # (the ear's opening faces forward and out)
    face = (V(side * 0.55, 0.0, 1.0) - ahead * V(side * 0.55, 0.0, 1.0).dot(ahead)).normalized()
    wide = ahead.cross(face).normalized()
    return wide, face


def ears(c):
    def shapes(b):
        width, length = c.ear_size
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            rings = []
            for t, half, thick in EAR_RINGS:
                wide, face = ear_axes(c, side, t)
                # (cupped: the middle of the ear is set back from its edges)
                rings.append((ear_curve(c, t, side) - face * 0.004 * s * math.sin(math.pi * t), wide * half * width * s, face * thick * 0.030 * s))
            b.tube(dome(rings[0], (ear_curve(c, 0.0, side) - ear_curve(c, 0.1, side)).normalized(), 0.01 * s, 2)[::-1] + rings, 12)
        lay_fur(c, b.bm)
    return shapes


def ear_linings(c):
    def shapes(b):
        width, length = c.ear_size
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            rings = []
            for t, half in ((0.12, 0.45), (0.3, 0.80), (0.52, 0.84), (0.72, 0.70), (0.88, 0.44), (0.95, 0.18)):
                wide, face = ear_axes(c, side, t)
                rings.append((ear_curve(c, t, side) + face * 0.0035 * s, wide * half * width * s, face * 0.0025 * s))
            b.tube(rings, 10)
    return shapes


def hooves(c):
    def shapes(b):
        s = c.scale
        for suffix, joints in c.legs.items():
            fet = joints[3]
            toe = c.toes[suffix]
            for half in (1.0, -1.0):
                # Each of the two toes: a hard wedge on the ground, deep at the heel, its front wall sloping down
                # to a point, the cleft between them
                heel = V(fet.x + half * 0.0098 * s, 0.0, toe.z - 0.052 * s)
                rings = []
                for k, (ahead, tall, wide) in enumerate(((0.0, 0.026, 0.0080), (0.010, 0.036, 0.0098), (0.022, 0.034, 0.0100),
                                                         (0.034, 0.025, 0.0090), (0.044, 0.014, 0.0068), (0.051, 0.005, 0.0035))):
                    lean = -half * 0.0025 * s * ahead / 0.051
                    rings.append((heel + V(lean, (tall * 0.5 + 0.0008) * s, ahead * s), X * wide * s, Y * tall * 0.5 * s))
                b.tube(dome(rings[0], -Z, 0.004 * s, 2)[::-1] + rings + dome(rings[-1], Z, 0.002 * s, 1), 10)
            # The dewclaws: two small hooves high at the back of the fetlock
            for half in (1.0, -1.0):
                b.ellipsoid(fet + V(half * 0.012 * s, -0.030 * s, -0.022 * s), V(0.006 * s, 0.008 * s, 0.006 * s), rot_x(0.6), 8, 4)
    return shapes


def mouth(c):
    def shapes(b):
        s = c.scale * c.head_scale
        # The inside of the mouth: palate, and a tongue in the jaw
        tube_along(b, [c.at(0.05, -0.034), c.at(0.13, -0.036), c.at(0.21, -0.032)], [0.022 * s, 0.018 * s, 0.012 * s], [0.008 * s] * 3, 8)
    return shapes


def tongue(c):
    def shapes(b):
        s = c.scale * c.head_scale
        tube_along(b, [c.at(0.06, -0.044), c.at(0.13, -0.046), c.at(0.20, -0.040)], [0.018 * s, 0.015 * s, 0.011 * s], [0.007 * s] * 3, 8)
    return shapes


def teeth(c):
    def shapes(b):
        s = c.scale * c.head_scale
        # Lower incisors only at the front (a deer has none above, only a hard pad); cheek teeth behind; an elk's
        # upper canines ("ivories")
        for side in (1.0, -1.0):
            for k in (0.25, 0.65, 1.0):
                base = c.at(0.236, -0.036, side * 0.006 * k)
                kit.spike(b, base, base + c.face * 0.006 * s + c.face_up * 0.007 * s, 0.0024 * s, 5)
            for k in range(4):
                base = c.at(0.10 + k * 0.025, -0.040, side * 0.011)
                kit.spike(b, base, base + c.face_up * 0.006 * s, 0.0045 * s, 5)
    return shapes


def ivories(c):
    def shapes(b):
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            for k in range(4):
                base = c.at(0.10 + k * 0.025, -0.031, side * 0.011)
                kit.spike(b, base, base - c.face_up * 0.006 * s, 0.0045 * s, 5)
            if c.kind == "elk":
                base = c.at(0.165, -0.028, side * 0.017)
                kit.spike(b, base, base - c.face_up * 0.008 * s, 0.004 * s, 5)
    return shapes


# --- Antlers ---

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
    """A tapering length of antler along a smooth curve, its tip rounded to a blunt point; a little knobbled."""
    curve = smooth_curve(points, 3 if not kit.LOW else 1)
    n = len(curve)
    radii = []
    for i in range(n):
        t = i / (n - 1)
        r = base_r + (tip_r - base_r) * (t ** 0.8)
        r *= 1.0 + gnarl * math.sin(i * 2.7 + seed) * (1.0 - t)
        radii.append(r)
    b.strand(curve, radii, segments)


def antler_set(c):
    """Each antler as (pedicle, [beam points], [(tine points)], beam radii): in the head's rest, the left one."""
    s = c.scale * c.head_scale
    ped = c.at(0.0, 0.058, 0.026)
    if c.antlers == "whitetail":
        # Main beam: out, back and up from the pedicle, then curving forward over the face; the tines stand up from it
        beam = [V(0.0, 0.0, 0.0), V(0.030, 0.035, -0.030), V(0.085, 0.075, -0.055), V(0.140, 0.100, -0.030),
                V(0.170, 0.112, 0.030), V(0.160, 0.118, 0.100), V(0.120, 0.120, 0.160), V(0.075, 0.118, 0.190)]
        tines = [
            ([V(0.022, 0.026, -0.022), V(0.026, 0.060, -0.012), V(0.030, 0.082, 0.002)], 0.0075, 0.0028),  # brow tine
            ([V(0.120, 0.094, -0.045), V(0.130, 0.150, -0.040), V(0.136, 0.205, -0.024), V(0.130, 0.235, -0.006)], 0.0085, 0.0028),  # G2
            ([V(0.168, 0.110, 0.045), V(0.172, 0.165, 0.050), V(0.170, 0.215, 0.066), V(0.160, 0.240, 0.080)], 0.0080, 0.0028),  # G3
            ([V(0.140, 0.118, 0.130), V(0.142, 0.155, 0.138), V(0.136, 0.180, 0.150)], 0.0065, 0.0025),  # G4
        ]
        return ped, beam, tines, (0.0135, 0.0045)
    # A bull elk's six points: the beam sweeps back and up over the shoulders, the tines stand up off it, the brow
    # and bez tines reach forward over the face, the royal (dagger) is the longest, the beam ends in a fork
    beam = [V(0.0, 0.0, 0.0), V(0.045, 0.070, -0.060), V(0.120, 0.170, -0.190), V(0.195, 0.265, -0.340),
            V(0.255, 0.350, -0.480), V(0.290, 0.440, -0.590), V(0.300, 0.545, -0.650), V(0.282, 0.650, -0.655)]
    tines = [
        ([V(0.020, 0.030, -0.020), V(0.042, 0.042, 0.070), V(0.055, 0.060, 0.160), V(0.058, 0.098, 0.230), V(0.052, 0.140, 0.262)], 0.0150 * 1.25, 0.0045 * 1.3),  # brow
        ([V(0.052, 0.082, -0.070), V(0.080, 0.100, 0.020), V(0.095, 0.125, 0.105), V(0.098, 0.168, 0.158)], 0.0130 * 1.25, 0.0040 * 1.3),  # bez
        ([V(0.165, 0.225, -0.270), V(0.190, 0.300, -0.200), V(0.210, 0.385, -0.150), V(0.214, 0.445, -0.128)], 0.0125 * 1.25, 0.0038 * 1.3),  # trez
        ([V(0.248, 0.340, -0.465), V(0.270, 0.440, -0.400), V(0.290, 0.560, -0.345), V(0.296, 0.660, -0.322), V(0.288, 0.720, -0.322)], 0.0140 * 1.25, 0.0040 * 1.3),  # royal (dagger)
        ([V(0.296, 0.520, -0.640), V(0.318, 0.600, -0.700), V(0.322, 0.680, -0.735), V(0.312, 0.745, -0.730)], 0.0115 * 1.25, 0.0036 * 1.3),  # fifth
    ]
    return ped, beam, tines, (0.0265, 0.0080)


def antlers(c):
    def shapes(b):
        s = c.scale * c.head_scale
        ped, beam, tines, (r0, r1) = antler_set(c)
        for side in (1.0, -1.0):
            m = V(side, 1.0, 1.0)

            def put(p):
                return ped + V(p.x * side, p.y, p.z) * s * (1.0 if c.kind == "deer" else 0.74)

            k = 1.0 if c.kind == "deer" else 0.74
            # The burr: a rough ring where the antler grows from the pedicle
            b.ellipsoid(put(V(0.004, 0.006, -0.002)), V(r0 * 1.55 * s * k, r0 * 0.9 * s * k, r0 * 1.55 * s * k), None, 10, 4)
            tine(b, [put(p) for p in beam], r0 * s * k, r1 * s * k, 10, 0.12, side)
            for points, a, z in tines:
                tine(b, [put(p) for p in points], a * s * k, z * s * k, 8, 0.10, side * 3.0)
        fuse = (0.0022 * c.scale, 1, 3000 if c.kind == "deer" else 6500)
        return kit.fused(b, None if kit.LOW else fuse)
    return shapes


def mane(c):
    """The bull elk's mane: long dark coarse hair hanging from under its neck and over its crest, in locks."""
    def shapes(b):
        low = kit.LOW
        s = c.scale
        nb, nt, along, throat = neck_frame(c)
        steps = 17 if not low else 6
        around = (-1.15, -0.8, -0.45, -0.15, 0.15, 0.45, 0.8, 1.15) if not low else (-0.7, 0.0, 0.7)
        for i in range(steps):
            t = 0.0 + 0.95 * i / (steps - 1)
            centre, w, d = neck_at(c, t)
            for k, a in enumerate(around):
                jitter = math.sin(i * 7.31 + k * 3.7)
                wave = math.sin(i * 3.1 + k * 5.3)
                # Under the neck: a long shaggy fringe, hanging; along the sides shorter, lying back and down;
                # each lock flat, thick at its root, waving a little, ragged at its end
                ang = a + jitter * 0.12
                root = centre + throat * d * math.cos(ang) * 0.9 + X * w * math.sin(ang) * 0.9
                hang = (0.20 - 0.10 * t) * s * (1.0 - min(abs(a), 1.0) * 0.55) * (1.0 + jitter * 0.22)
                down = (throat * 0.35 + V(0.0, -1.0, 0.0) * 0.8 - along * 0.45 + X * math.sin(ang) * 0.3).normalized()
                bend = (X * wave * 0.25 - along * 0.2).normalized() if not low else V(0.0, 0.0, 0.0)
                points = [root - down * 0.01 * s, root + down * hang * 0.45 + bend * hang * 0.12, root + down * hang]
                width = 0.020 * s * (1.0 - min(abs(a), 1.0) * 0.3)
                tube_along(b, points, [width, width * 0.7, width * 0.12], [width * 0.45, width * 0.35, width * 0.1], 6, sideways=X if abs(a) < 0.5 else down.cross(throat).normalized())
            # Over the crest of the neck: shorter, lying back along it
            for k in ((-0.5, 0.0, 0.5) if not low else (0.0,)):
                root = centre - throat * d * 0.92 + X * w * k * 0.6
                lie = (-along * 0.8 - throat * 0.35 + X * k * 0.2).normalized()
                tube_along(b, [root, root + lie * 0.045 * s, root + lie * 0.085 * s], [0.016 * s, 0.011 * s, 0.002 * s], [0.006 * s, 0.005 * s, 0.002 * s], 6)
    return shapes


def weights(c):
    s = c.scale
    tail_names = ["pelvis", "tail", "tail_1"]

    def weigh(part, p):
        if part in ("jaw", "tongue", "teeth"):
            return {"jaw": 1.0}
        if part in ("mouth", "ivories", "eyes", "nose", "antlers", "glands"):
            return {"head": 1.0}
        if part in ("ears", "linings"):
            suffix = "_l" if p.x >= 0.0 else "_r"
            side = 1.0 if p.x >= 0.0 else -1.0
            root, mid, end = (V(j.x * side, j.y, j.z) for j in c.ear)
            line = (end - root)
            along = (p - root).dot(line.normalized())
            joint = (mid - root).dot(line.normalized())
            hung = blend(0.0, 0.025 * s, along)
            tip = blend(joint - 0.03 * s, joint + 0.03 * s, along)
            return {"head": 1.0 - hung, "ear" + suffix: hung * (1.0 - tip), "ear_tip" + suffix: hung * tip}
        if part == "hooves":
            suffix = ("_f" if p.z > -0.05 * s else "_r") + ("l" if p.x >= 0.0 else "r")
            return {"paw" + suffix: 1.0}
        tail = c.tail
        off, along = chain_param(p, tail)
        if p.z < tail[0].z + 0.01 * s and off < c.tail_width * s * 1.4 and p.y > tail[-1].y - 0.03 * s:
            past = [1.0, blend(0.0, 0.4, along), blend(0.6, 1.3, along), 0.0]
            return {name: past[i] - past[i + 1] for i, name in enumerate(tail_names)}
        front = blend(-0.22 * s, 0.10 * s, p.z)
        trunk = {"chest": front, "pelvis": 1.0 - front}
        nb, nt, n_along, throat = neck_frame(c)
        reach = (p - nb).dot(n_along) / (nt - nb).length
        if part == "mane" or (reach > 0.0 and p.z > nb.z - 0.06 * s and p.y > 0.72 * s):
            neck = blend(0.0, 0.32, reach)
            upper = blend(0.30, 0.70, reach)
            head_w = blend(0.84, 1.0, reach)
            # (the face, forward of the atlas, is all the head's)
            ahead = (p - c.head).dot(c.face) / (s * c.head_scale)
            if reach > 0.7:
                head_w = max(head_w, blend(0.0, 0.05, ahead))
                neck = max(neck, blend(0.0, 0.05, ahead))
                upper = max(upper, blend(0.0, 0.05, ahead))
            return {"chest": 1.0 - neck, "neck": neck * (1.0 - upper), "neck_1": neck * upper * (1.0 - head_w), "head": neck * upper * head_w}
        suffix, leg = leg_share(c, p)
        joints = c.legs[suffix]
        along = chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        if p.y < joints[3].y + 0.012 * s:
            along = 3.0
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.05 * s / spans[0], 1.0 + 0.05 * s / spans[1], along)
        hock = blend(2.0 - 0.035 * s / spans[1], 2.0 + 0.035 * s / spans[2], along)
        paw = blend(joints[3].y + 0.03 * s, joints[3].y - 0.002 * s, p.y)
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
        ("neck", c.neck, "chest"), ("neck_1", c.neck_1, "neck"), ("head", c.head, "neck_1"), ("jaw", c.jaw, "head"),
    ]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root, mid, end = (V(j.x * side, j.y, j.z) for j in c.ear)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
    # Markers (nothing is weighted to them): the tip of its nose, and the front of its antlers (or its brow)
    listed.append(("nose", c.at(0.262 if c.kind == "deer" else 0.29, -0.012), "head"))
    if c.antlers:
        ped, beam, tines, _ = antler_set(c)
        k = (1.0 if c.kind == "deer" else 0.74) * c.scale * c.head_scale
        tip = tines[0][0][-1] if c.kind == "elk" else beam[-1]
        listed.append(("brow", ped + V(0.0, tip.y, tip.z) * k, "head"))
    else:
        listed.append(("brow", c.at(0.05, 0.07), "head"))
    chain = ["pelvis", "tail", "tail_1", "tail_end"]
    for i, joint in enumerate(c.tail):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in c.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
        listed.append(("toe" + suffix, c.toes[suffix], "paw" + suffix))
    return listed


MATERIALS = [("coat", (0.33, 0.27, 0.215)), ("mane", (0.12, 0.085, 0.06)), ("parts", (1.0, 1.0, 1.0))]


def part_colours(c):
    elk_ = c.kind == "elk"
    return {
        "mouth": (0.30, 0.12, 0.13, 0.5), "tongue": (0.40, 0.18, 0.20, 0.6), "teeth": (0.72, 0.68, 0.56, 0.4),
        "ivories": (0.66, 0.60, 0.48, 0.4), "eyes": (0.10, 0.075, 0.06, 1.0), "nose": (0.03, 0.028, 0.03, 0.85),
        "glands": (0.05, 0.04, 0.035, 0.6),
        "linings": (0.62, 0.58, 0.54, 0.0) if not elk_ else (0.36, 0.30, 0.24, 0.0),
        "hooves": (0.07, 0.065, 0.06, 0.25), "antlers": (0.30, 0.24, 0.17, 0.15),
    }


def parts(c):
    made = [("coat", 0, coat(c)), ("jaw", 0, jaw(c)), ("ears", 0, ears(c)),
            ("mouth", 2, mouth(c)), ("tongue", 2, tongue(c)), ("teeth", 2, teeth(c)), ("ivories", 2, ivories(c)),
            ("eyes", 2, eyes(c)), ("glands", 2, glands(c)), ("nose", 2, nose(c)), ("linings", 2, ear_linings(c)),
            ("hooves", 2, hooves(c))]
    if c.mane:
        made.append(("mane", 1, mane(c)))
    if c.antlers:
        made.append(("antlers", 2, antlers(c)))
    return made


def paint(c, whole, part_of):
    """Vertex colours: on the coat, red how open the surface is, green the dark of the coat, blue the pale; on the
    other parts their colours, and the antlers dark at the base and pale at the tips."""
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
    ped = antler_set(c)[0] if c.antlers else None
    elk_ = c.kind == "elk"
    hs = s * c.head_scale
    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part == "mane":
            vert[layer] = (1.0, 1.0, 1.0, (math.sin(vert.index // 18 * 12.9898) * 43758.5453) % 1.0)
            continue
        if part == "antlers":
            # Dark and ridged near the head, polished pale at the tips
            reach = (p - V(math.copysign(ped.x, p.x), ped.y, ped.z)).length / ((0.26 if not elk_ else 0.78) * hs)
            tip = blend(0.5, 1.0, reach)
            base = colours["antlers"]
            vert[layer] = (base[0] + (0.78 - base[0]) * tip, base[1] + (0.72 - base[1]) * tip, base[2] + (0.60 - base[2]) * tip, base[3] + 0.3 * tip)
            continue
        if part in colours:
            vert[layer] = colours[part]
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 5.0, 0.0), 1.0) if furred_[vert.index] else 1.0
        y, rx, ry = trunk_at(c, p.z)
        belly = blend(y - ry * 0.35, y - ry * 0.92, p.y) * blend(0.36 * s, 0.30 * s, p.z) * blend(-0.45 * s, -0.36 * s, p.z) * blend(y - ry - 0.07 * s, y - ry - 0.02 * s, p.y)
        # The inside of the legs is paler
        inside = 0.0
        if p.y < 0.62 * s:
            suffix, leg = leg_share(c, p)
            hip = c.legs[suffix][0]
            inside = blend(-0.006 * s, -0.016 * s, (abs(p.x) - abs(hip.x))) * leg * 0.8 * blend(0.30 * s, 0.42 * s, p.y)
        # Where it is on the head: along the face, up from its line, and how far out
        q = p - c.head
        along = c.unmuzzle(q.dot(c.face) / hs)
        up = q.dot(c.face_up) / hs
        out = abs(q.x) / hs
        on_head = (p - c.head).dot(V(0.0, 0.0, 1.0)) > -0.05 * hs and p.y > c.head.y - 0.14 * hs
        pale = max(belly, inside) if not elk_ else inside * 0.4
        dark = 0.0
        if elk_:
            dark = max(dark, belly * 0.6)
        if on_head:
            # The ring round each eye, the band behind the nose, the chin: white on a deer
            eye = c.at(*EYE)
            from_eye = (V(abs(p.x), p.y, p.z) - eye).length / hs
            ring = blend(0.030, 0.025, from_eye) * blend(0.018, 0.022, from_eye)
            band = blend(0.20, 0.215, along) * blend(0.245, 0.232, along) * blend(-0.004, -0.010, up)
            chin = blend(0.17, 0.23, along) * blend(-0.032, -0.044, up)
            face_dark = blend(0.06, 0.20, along) * blend(0.005, 0.03, up) * blend(0.03, 0.008, out) * 0.35
            if not elk_:
                pale = max(pale, ring * 0.9, band * 0.9, chin)
                dark = max(dark, face_dark)
            else:
                dark = max(dark, 0.85)
                pale = max(pale, chin * 0.25)
        # The throat
        nb, nt, n_along, throat = neck_frame(c)
        reach = (p - nb).dot(n_along) / (nt - nb).length
        below = (p - nb - n_along * (p - nb).dot(n_along)).dot(throat)
        if not elk_:
            patch = blend(0.68, 0.80, reach) * blend(0.98, 0.90, reach) * blend(0.0, 0.03 * s, below)
            pale = max(pale, patch)
        else:
            # A bull's neck and head are dark chocolate, the dark fading into the tan body over the shoulders
            neckness = blend(-0.05, 0.12, reach) if p.z > nb.z - 0.10 * s else 0.0
            dark = max(dark, neckness * 0.95)
            # ...and his legs dark below the elbow and the stifle
            legs = blend(0.56 * s, 0.44 * s, p.y)
            dark = max(dark, legs * 0.9)
        # The tail and rump: white under the tail and round it on a deer (the flag), buff on an elk
        rump = 0.0
        if p.z < -0.47 * s:
            behind = blend(-0.50 * s, -0.575 * s, p.z)
            centre = blend(0.085 * s, 0.03 * s, abs(p.x))
            rump = behind * centre * blend(0.62 * s, 0.70 * s, p.y) * blend(0.94 * s, 0.86 * s, p.y)
            if elk_:
                rump = blend(-0.44 * s, -0.53 * s, p.z) * blend(0.13 * s, 0.07 * s, abs(p.x)) * blend(0.58 * s, 0.68 * s, p.y)
        tail_off, tail_along = chain_param(p, c.tail)
        if tail_off < c.tail_width * s * 1.5 and p.z < c.tail[0].z + 0.01 * s:
            # (on the tail: brown on top, white underneath, against the rump)
            i = min(int(tail_along), len(c.tail) - 2)
            on_line = c.tail[i].lerp(c.tail[i + 1], tail_along - i)
            under = blend(-0.25, 0.35, (p - on_line).normalized().z)
            rump = max(rump, under)
            if not elk_:
                dark = max(dark, (1.0 - under) * 0.55)
        pale = max(pale, rump)
        if rump > 0.3:
            dark *= 1.0 - rump
        vert[layer] = (shade, dark, pale, 1.0)
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
                if local.z > -0.3 * 0.017 * hs:
                    uv2 = (0.5 + local.x / (EYE_SIZE.x * hs) * 0.4, 0.5 + local.y / (EYE_SIZE.y * hs) * 0.4)
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
            face.smooth = not low or part in ("antlers",)
        part_of += [part] * (len(whole.verts) - len(part_of))
    paint(c, whole, part_of)

    mesh = bpy.data.meshes.new(name)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    colours = c.colours
    for label, srgb in MATERIALS:
        srgb = colours.get(label, colours["dark"] if label == "mane" else srgb)
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
    folder = out_folder(c)
    os.makedirs(folder, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(folder, name + ".glb"), export_format="GLB", export_yup=True,
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
    scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    s = c.scale
    tall = 1.0 if c.kind == "deer" else 1.6
    middle = (0.0, -0.05 * s, 0.75 * s * tall / tall)
    head = kit.to_blender(c.at(0.12, 0.0))
    views = [("side", (1, 0, 0), middle, 2.0 * s * (1.3 if c.antlers == "elk" else 1.0), "MATERIAL"),
             ("quarter", (0.7, -0.7, 0.2), middle, 2.0 * s * (1.3 if c.antlers == "elk" else 1.0), "MATERIAL"),
             ("front", (0.05, -1, 0.1), middle, 1.8 * s * (1.3 if c.antlers == "elk" else 1.0), "VERTEX"),
             ("face", (0.6, -0.75, 0.2), tuple(head), 0.5 * s * (2.2 if c.antlers == "elk" else 1.0), "VERTEX"),
             ("back", (-0.6, 0.75, 0.3), middle, 2.0 * s, "VERTEX"),
             ("legs", (1, 0, 0), (0.0, -0.05 * s, 0.35 * s), 1.0 * s, "MATERIAL")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 6.0 * s
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


def main(only=None):
    preview = kit.PREVIEW_DIR or None
    if only:
        kit.ONLY = list(only) if not kit.ONLY else kit.ONLY
    for low in (False, True):
        kit.LOW = low
        for animal in ANIMALS:
            export(animal, preview)


if __name__ == "__main__":
    main()
