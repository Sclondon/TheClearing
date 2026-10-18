"""Builds the moose (creatures/moose): a bull and a cow, and exports them for Godot.

Run from the game's root (Blender 4.3):
    blender --background --python creatures/moose/tools/build_moose.py
    blender --background --python creatures/moose/tools/build_moose.py -- <preview folder> moose_bull   # one, with pictures

Writes creatures/moose/models/moose_bull.glb, moose_cow.glb and a demade `_lo` version of each. Nothing else is written
(an editable .blend and pictures go to the preview folder, when there is one).

A moose is a deer (the deer's builder, creatures/deer/tools/build_deer.py, does most of the work, on the same bones, so
the deer's rig poses it), built from a moose's anatomy rather than a deer's:
- Long legs under a short, deep body: the chest is deep and the belly high, so that it looks all legs; a tall hump over
  the shoulders (the long spines of the withers) with a crest of long coarse hair along it (the hackles, which stand
  up when it is angry: bone `hackles`), and the back sloping down from it to a low narrow rump and a stub of a tail.
- A short, thick neck carried forward, and a long heavy head hung low from it: a long face, a broad overhanging muzzle
  that swells at its end (the upper lip droops over the lower, and the big nostrils are slits in the sides of it),
  small eyes set high and far back, and big ears.
- The bell (dewlap): a flap of skin and hair hanging from the throat, long on a bull (bone `bell`, so it swings).
- A bull's antlers are palmate: a short beam out sideways from each side of the head, a small brow palm forward with
  its points over the face, and the great main palm, broad and cupped, rising out and back, ringed with points.
- The coat: dark brown, nearly black, a little greyer over the back and hump; the legs pale grey-brown below the elbow
  and the stifle (its stockings); a cow's face lighter. A long coarse coat, so its fur shells are long.

Bones: the deer's (see build_deer.py), and `bell` (the dewlap, under the head), `hackles` (the crest of hair over
the hump, on the chest: moved up, its hair stands on end) and `tongue` (in the jaw).

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
CREATURES = os.path.dirname(COMPONENT)
GAME = os.path.dirname(CREATURES)
sys.path.insert(0, os.path.join(CREATURES, "deer", "tools"))
import build_deer as bd  # noqa: E402  (the deer's builder, and through it the character controller's tools)

kit = bd.kit
X, Y, Z = kit.X, kit.Y, kit.Z
V = bd.V
blend = kit.blend
dome = kit.dome
rot_x = bd.rot_x


class Moose(bd.Cervid):
    """A moose's measurements: the deer's, with the body set higher on longer legs."""

    def __init__(self, **spec):
        super().__init__(**spec)
        s = self.scale
        self.body = V(0.0, 0.80, -0.05) * s
        self.chest = V(0.0, 0.83, 0.20) * s
        self.pelvis = V(0.0, 0.79, -0.30) * s
        self.neck = V(0.0, 0.92, 0.33) * s
        self.neck_1 = self.neck.lerp(self.head, 0.5)
        tail_root = V(0.0, 0.875, -0.57) * s
        self.tail = [tail_root, tail_root + V(0.0, -0.06, -0.03) * s * self.tail_length,
                     tail_root + V(0.0, -0.14, -0.04) * s * self.tail_length]
        # (the ears sit high at the back of the head, behind the antlers, standing out to the sides)
        self.ear = [self.at(-0.020, 0.040, 0.040), self.at(-0.050, 0.085, 0.100), self.at(-0.070, 0.112, 0.165)]


def moose(name, bull=True):
    return Moose(
        name=name, kind="moose", buck=bull, scale=1.95 if bull else 1.80, head_scale=1.25 if bull else 1.18,
        thick=1.10 if bull else 1.02, muzzle=1.06,
        # (along, centre height, half width, half height): a short deep body, the belly high, the front deepest,
        # the rump low and narrow
        trunk=[(-0.585, 0.835, 0.038, 0.048), (-0.555, 0.826, 0.080, 0.106), (-0.49, 0.814, 0.110, 0.140),
               (-0.40, 0.806, 0.124, 0.154), (-0.29, 0.806, 0.130, 0.160), (-0.16, 0.802, 0.144, 0.184),
               (-0.02, 0.804, 0.154, 0.204), (0.10, 0.810, 0.152, 0.216), (0.21, 0.824, 0.136, 0.214),
               (0.30, 0.832, 0.106, 0.188), (0.37, 0.826, 0.076, 0.142), (0.41, 0.820, 0.044, 0.082)],
        # Shoulder (the point of it), elbow, knee, fetlock; hip, stifle, hock, fetlock (the left legs): long
        fore=[V(0.090, 0.770, 0.300), V(0.094, 0.600, 0.215), V(0.084, 0.332, 0.240), V(0.080, 0.094, 0.250)],
        hind=[V(0.096, 0.800, -0.372), V(0.108, 0.600, -0.256), V(0.088, 0.446, -0.494), V(0.082, 0.096, -0.462)],
        toe_ahead=0.074,
        fore_shape=[(0.45, 0.036, 0.052, -0.006), (0.7, 0.038, 0.058, -0.008), (0.92, 0.039, 0.059, -0.008),
                    (1.0, 0.037, 0.055, -0.004), (1.25, 0.032, 0.045, 0.002), (1.6, 0.024, 0.032, 0.0), (1.86, 0.021, 0.028, 0.0),
                    (2.0, 0.025, 0.031, 0.003), (2.12, 0.0185, 0.0245, 0.0), (2.5, 0.016, 0.021, -0.001), (2.85, 0.017, 0.0225, -0.001),
                    (3.0, 0.0195, 0.027, -0.002)],
        hind_shape=[(0.5, 0.040, 0.068, -0.012), (0.7, 0.043, 0.074, -0.012), (0.85, 0.045, 0.078, -0.01),
                    (1.0, 0.042, 0.070, -0.004), (1.3, 0.036, 0.058, -0.008), (1.62, 0.027, 0.044, -0.010), (1.86, 0.021, 0.038, -0.012),
                    (2.0, 0.021, 0.041, -0.010), (2.12, 0.0185, 0.028, -0.002), (2.5, 0.0165, 0.0225, 0.0), (2.85, 0.017, 0.0225, -0.001),
                    (3.0, 0.0195, 0.027, -0.002)],
        # A short thick neck, deep at its root
        neck_shape=[(-0.25, 0.112, 0.170, 0.030), (0.0, 0.104, 0.150, 0.028), (0.3, 0.090, 0.126, 0.018),
                    (0.6, 0.078, 0.106, 0.008), (0.85, 0.068, 0.090, 0.0), (1.05, 0.062, 0.078, -0.004)],
        atlas=V(0.0, 1.085, 0.59), face_tilt=0.86,
        ear_size=(0.034, 0.130), tail_length=0.35, tail_width=0.032,
        mane=True, antlers="moose" if bull else None, bell=0.23 if bull else 0.12,
        colours=dict(coat=(0.24, 0.17, 0.115), dark=(0.075, 0.055, 0.045), pale=(0.44, 0.41, 0.36)),
    )


ANIMALS = [moose("moose_bull"), moose("moose_cow", False)]

# Its eyes are small for its head, high and far back
bd.EYE = (0.070, 0.036, 0.044)
bd.EYE_SIZE = V(0.016, 0.0125, 0.0095)
# A moose's ears are long and leaf-shaped, narrowing to a point
bd.EAR_RINGS = ((0.0, 0.34, 0.30), (0.10, 0.52, 0.24), (0.26, 0.74, 0.17), (0.42, 0.80, 0.14), (0.58, 0.72, 0.12),
                (0.74, 0.54, 0.10), (0.87, 0.32, 0.08), (0.96, 0.12, 0.06), (1.0, 0.02, 0.05))


def out_folder(c):
    return os.path.join(COMPONENT, "models")


# --- The hump and the hackles ---

HUMP = (0.16, 0.050, 0.068, 0.19)  # (along, how far it rises over the back, half width, half length): deer units


def hump_top(c, z):
    """How high the top of the back is at `z` (built size), with the hump."""
    s = c.scale
    y, rx, ry = bd.trunk_at(c, z)
    top = y + ry
    along, rise, _, half = HUMP
    k = (z / s - along) / half
    if abs(k) < 1.0:
        top = max(top, top + rise * s * math.sqrt(1.0 - k * k) * (0.6 + 0.4 * (1.0 - max(k, 0.0))))
    return top


def crest(c, z):
    """The top line of the neck and back at `z` (built size): where the hackles grow."""
    nb, nt, along, throat = bd.neck_frame(c)
    back = hump_top(c, z)
    if z > nb.z - 0.02 * c.scale:
        # (up the neck: its top line)
        t = min(max((z - nb.z) / max(nt.z - nb.z, 0.001), 0.0), 1.0)
        centre, w, d = bd.neck_at(c, t)
        neck_top = (centre - throat * d).y
        back = max(back if z < nb.z + 0.05 * c.scale else -1.0, neck_top)
    return back


def mass(c):
    """The body's masses, fused and smoothed hard: the trunk, the hump over the withers, the shoulders and upper arms,
    the thighs, the root of the neck and the neck."""
    b = kit.Builder()
    low = kit.LOW
    s = c.scale
    th = c.thick
    rings = [(V(0.0, y * s, z * s), X * rx * s * th, Y * ry * s) for z, y, rx, ry in c.trunk]
    b.tube(dome(rings[0], -Z, 0.04 * s)[::-1] + rings + dome(rings[-1], Z, 0.03 * s), 20)
    # The hump: the long spines of the withers, high over the shoulders, falling away behind
    along, rise, wide, half = HUMP
    top = bd.trunk_at(c, along * s)
    b.ellipsoid(V(0.0, top[0] + top[2] - 0.05 * s + rise * s * 0.5, along * s), V(wide * s * th, (rise + 0.05) * s, half * s))
    b.ellipsoid(V(0.0, top[0] + top[2] - 0.03 * s, (along - 0.13) * s), V(0.07 * s * th, 0.045 * s, 0.16 * s))
    # The root of the neck, broad, running down into the brisket between the forelegs
    b.ellipsoid(V(0.0, 0.86 * s, 0.34 * s), V(0.090 * s * th, 0.14 * s, 0.10 * s), rot_x(-0.25))
    b.ellipsoid(V(0.0, 0.70 * s, 0.31 * s), V(0.074 * s * th, 0.090 * s, 0.078 * s))
    for side in (1.0, -1.0):
        # The shoulder and upper arm
        side_rows = [(0.95, 0.205, 0.052, 0.046, 0.072), (0.87, 0.240, 0.074, 0.056, 0.092),
                     (0.78, 0.262, 0.086, 0.058, 0.096), (0.70, 0.245, 0.088, 0.052, 0.080), (0.635, 0.220, 0.088, 0.040, 0.055)]
        bd.side_mass(b, side, [(y * s, z * s, out * s * th, w * s * th, d * s) for y, z, out, w, d in side_rows])
        # The thigh: a moose's haunches are narrow and its rump falls away
        thigh_rows = [(0.90, -0.40, 0.046, 0.044, 0.12), (0.82, -0.41, 0.068, 0.062, 0.160),
                      (0.72, -0.40, 0.080, 0.066, 0.160), (0.645, -0.375, 0.088, 0.062, 0.140),
                      (0.585, -0.360, 0.094, 0.052, 0.112), (0.53, -0.385, 0.090, 0.036, 0.072)]
        bd.side_mass(b, side, [(y * s, z * s, out * s * th, w * s * th, d * s) for y, z, out, w, d in thigh_rows])
    # The neck
    nb, nt, n_along, throat = bd.neck_frame(c)
    nrings = []
    for t, _, _, _ in c.neck_shape:
        centre, w, d = bd.neck_at(c, t)
        nrings.append((centre, X * w, throat * d))
    b.tube(nrings, 16)
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


# --- The head ---

def head(c, b):
    """The head, on the coat: the skull, the long face, the muzzle swelling at its end and the upper lip hanging
    over the lower, the cheeks, the brows and the throat."""
    s = c.scale * c.head_scale
    at = c.at
    b.ellipsoid(at(0.035, 0.010), V(0.056 * s, 0.056 * s, 0.070 * s), rot_x(c.face_tilt), 16, 9)
    # The face: long, narrowing past the eyes, then swelling again into the great nose (a moose's "Roman" nose, the
    # bridge arched)
    rows = [(0.02, 0.012, 0.054, 0.052), (0.08, 0.006, 0.047, 0.049), (0.13, -0.002, 0.037, 0.045),
            (0.18, -0.006, 0.032, 0.045), (0.22, -0.008, 0.034, 0.048), (0.255, -0.013, 0.041, 0.054),
            (0.28, -0.022, 0.044, 0.053), (0.298, -0.034, 0.037, 0.042)]
    tube_along = bd.tube_along
    tube_along(b, [at(a, u) for a, u, _, _ in rows], [w * s for _, _, w, _ in rows], [d * s for _, _, _, d in rows], 16)
    # The upper lip: broad and heavy, hanging down over the front of the lower jaw and past it
    b.ellipsoid(at(0.272, -0.050), V(0.043 * s, 0.032 * s, 0.044 * s), rot_x(c.face_tilt + 0.2), 14, 7)
    for side in (1.0, -1.0):
        b.ellipsoid(at(0.068, 0.034, side * 0.037), V(0.017 * s, 0.012 * s, 0.024 * s), rot_x(c.face_tilt))  # brow
        b.ellipsoid(at(0.085, -0.022, side * 0.036), V(0.021 * s, 0.030 * s, 0.050 * s), rot_x(c.face_tilt))  # cheek
        b.ellipsoid(at(0.262, -0.044, side * 0.030), V(0.016 * s, 0.026 * s, 0.040 * s), rot_x(c.face_tilt + 0.25))  # the lip's fold
    # The throat latch
    b.ellipsoid(at(0.0, -0.044), V(0.046 * s, 0.052 * s, 0.058 * s), rot_x(c.face_tilt))


def jaw(c):
    def shapes(b):
        s = c.scale * c.head_scale
        at = c.at
        pts = [at(0.03, -0.046), at(0.10, -0.054), at(0.17, -0.056), at(0.22, -0.056), at(0.245, -0.054)]
        bd.tube_along(b, pts, [0.036 * s, 0.028 * s, 0.022 * s, 0.020 * s, 0.018 * s], [0.018 * s, 0.015 * s, 0.013 * s, 0.013 * s, 0.011 * s], 12)
        return bd.furred(c, b, (0.0035 * c.scale, 2, 900))
    return shapes


def nose(c):
    def shapes(b):
        s = c.scale * c.head_scale
        # Its nostrils: long dark slits in the sides of the swollen end of the muzzle, and a small bare patch between
        for side in (1.0, -1.0):
            b.ellipsoid(c.at(0.287, -0.034, side * 0.028), V(0.006 * s, 0.020 * s, 0.009 * s), Matrix.Rotation(side * 0.5, 3, "Y") @ rot_x(c.face_tilt + 0.15), 8, 5)
        b.ellipsoid(c.at(0.296, -0.036), V(0.010 * s, 0.010 * s, 0.006 * s), rot_x(c.face_tilt + 0.7), 8, 4)
    return shapes


def mouth(c):
    def shapes(b):
        s = c.scale * c.head_scale
        bd.tube_along(b, [c.at(0.05, -0.038), c.at(0.14, -0.042), c.at(0.23, -0.046)], [0.022 * s, 0.018 * s, 0.014 * s], [0.008 * s] * 3, 8)
    return shapes


def tongue(c):
    def shapes(b):
        s = c.scale * c.head_scale
        bd.tube_along(b, [c.at(0.07, -0.050), c.at(0.14, -0.052), c.at(0.215, -0.050)], [0.018 * s, 0.016 * s, 0.012 * s], [0.007 * s] * 3, 8)
    return shapes


def teeth(c):
    def shapes(b):
        s = c.scale * c.head_scale
        for side in (1.0, -1.0):
            for k in (0.25, 0.65, 1.0):
                base = c.at(0.236, -0.050, side * 0.007 * k)
                kit.spike(b, base, base + c.face * 0.006 * s + c.face_up * 0.007 * s, 0.0024 * s, 5)
            for k in range(4):
                base = c.at(0.10 + k * 0.025, -0.046, side * 0.012)
                kit.spike(b, base, base + c.face_up * 0.006 * s, 0.0045 * s, 5)
    return shapes


# --- The bell ---

def bell_line(c):
    """The bell's root (in the throat, under the angle of the jaw) and where it hangs to, at rest."""
    hs = c.scale * c.head_scale
    root = c.at(0.03, -0.074)
    return root, root + V(0.0, -c.bell * c.scale, 0.012 * c.scale)


def bell(c):
    """The dewlap: a flap of hide hanging from the throat, flat side to side, broad front to back, rounded below."""
    def shapes(b):
        s = c.scale
        root, end = bell_line(c)
        points = [root + V(0.0, 0.02 * s, -0.01 * s), root.lerp(end, 0.3), root.lerp(end, 0.65), end]
        k = c.bell / 0.23
        bd.tube_along(b, points, [0.028 * s, 0.019 * s, 0.015 * s, 0.010 * s],
                      [0.045 * s, 0.034 * s * (0.8 + 0.2 * k), 0.028 * s * (0.8 + 0.2 * k), 0.012 * s], 12, sideways=X)
        return bd.furred(c, b, (0.0035 * c.scale, 2, 1400))
    return shapes


# --- Hair: the hackles and the tassel of the bell ---

def hair(c):
    """Long coarse hair (material `mane`): the hackles, a crest along the top of the neck and over the hump, lying
    back; and a tassel of it hanging off the end of the bell."""
    def shapes(b):
        low = kit.LOW
        s = c.scale
        steps = 26 if not low else 8
        start, finish = 0.58 * s, -0.10 * s
        for i in range(steps):
            z = start + (finish - start) * i / (steps - 1)
            top = crest(c, z)
            # (longest over the hump)
            hump = blend(-0.12, 0.10, z / s) * blend(0.48, 0.28, z / s)
            length = (0.045 + 0.055 * hump) * s * (1.0 if c.buck else 0.75)
            for k in ((-0.6, -0.2, 0.2, 0.6) if not low else (-0.3, 0.3)):
                jitter = math.sin(i * 7.31 + k * 13.7)
                root = V(k * 0.022 * s * c.thick, top - 0.006 * s, z + jitter * 0.008 * s)
                lie = V(k * 0.35, 0.42 + 0.08 * jitter, -1.0).normalized()
                bend = V(k * 0.2, -0.15, 0.0)
                points = [root - lie * 0.008 * s, root + lie * length * 0.5 + bend * length * 0.1, root + lie * length]
                width = 0.016 * s
                bd.tube_along(b, points, [width, width * 0.7, width * 0.12], [width * 0.35, width * 0.28, width * 0.08], 6, sideways=X)
        # The bell's tassel
        root, end = bell_line(c)
        for k in range(7 if not low else 3):
            a = (k / 6.0 - 0.5) * 2.0 if not low else (k - 1.0)
            at = root.lerp(end, 0.75 + 0.2 * abs(a) * 0.3) + V(0.0, 0.0, a * 0.018 * s)
            hang = (0.05 + 0.03 * (1.0 - abs(a))) * s * (c.bell / 0.23 + 0.3) / 1.3
            down = V(0.0, -1.0, 0.15 * a).normalized()
            bd.tube_along(b, [at, at + down * hang * 0.5, at + down * hang], [0.012 * s, 0.009 * s, 0.002 * s], [0.005 * s, 0.004 * s, 0.002 * s], 6)
    return shapes


# --- The antlers ---

def palm_frame():
    """The main palm's breadth (back and a little up) and its face (out of it: up and forward), for the left antler."""
    breadth = V(0.0, 0.32, -0.95).normalized()
    face = X.cross(breadth).normalized()
    return breadth, face


def palm_at(t):
    """The main palm `t` of the way out along it (metres from the pedicle, the left antler): (the middle of it there,
    the way across it, half its breadth). It rises gently as it goes out, widens fast, and its far part curls up."""
    breadth, face = palm_frame()
    x = 0.10 + 0.58 * t
    centre = V(x, 0.045 + 0.13 * t + 0.06 * t * t, -0.02 - 0.05 * t)
    half = 0.05 + 0.17 * math.sin(math.pi * 0.5 * min(t / 0.65, 1.0)) - 0.05 * max(t - 0.8, 0.0) / 0.2
    way = (breadth + face * 0.35 * (t - 0.3)).normalized()
    return centre + way * half * 0.45, way, half


def antlers(c):
    """A bull's palmate antlers, in metres from each pedicle: a short beam out sideways, a small brow palm forward
    with three points over the face, and the broad cupped main palm, nearly flat, out and back, ringed with points."""
    def shapes(b):
        ped = c.at(0.0, 0.054, 0.030)
        k = c.scale / 1.95
        breadth, face = palm_frame()
        low = kit.LOW
        for side in (1.0, -1.0):
            base = V(ped.x * side, ped.y, ped.z)

            def put(p):
                return base + V(p.x * side, p.y, p.z) * k

            def way_of(w):
                return V(w.x * side, w.y, w.z)

            b.ellipsoid(put(V(0.006, 0.008, 0.0)), V(0.036 * k, 0.020 * k, 0.036 * k), None, 10, 4)  # the burr
            bd.tine(b, [put(V(0.0, 0.0, 0.0)), put(V(0.05, 0.02, -0.005)), put(V(0.10, 0.04, -0.02)), put(V(0.13, 0.05, -0.03))], 0.032 * k, 0.030 * k, 10, 0.08, side)
            # The main palm: rings out along it, each a broad thin lens
            rings = []
            count = 9 if not low else 5
            for i in range(count):
                t = i / (count - 1)
                centre, way, half = palm_at(t)
                thick = 0.024 - 0.010 * t
                rings.append((put(centre), way_of(way) * half * k, way_of(face) * thick * k))
            b.tube(dome(rings[0], (rings[0][0] - rings[1][0]).normalized(), 0.02 * k, 2)[::-1] + rings + dome(rings[-1], (rings[-1][0] - rings[-2][0]).normalized(), 0.05 * k, 2), 12)
            # Its points: round the back edge and off its outer end, standing up and out
            for j, (t, length) in enumerate(((0.22, 0.08), (0.36, 0.11), (0.5, 0.13), (0.63, 0.14), (0.76, 0.13), (0.88, 0.12), (0.99, 0.12))):
                centre, way, half = palm_at(t)
                edge = centre + way * half * 0.92
                if j == 6:
                    edge = centre + way * half * 0.2 + X * 0.03
                out = (way * 0.5 + X * (0.15 + 0.6 * t) + face * 0.35 + Y * 0.2).normalized()
                tip = edge + out * length + face * 0.015 * math.sin(j * 2.1)
                bd.tine(b, [put(edge - out * 0.03), put(edge.lerp(tip, 0.5) + face * 0.008), put(tip)], 0.022 * k, 0.006 * k, 8, 0.06, side * 2.0 + j)
            # The brow palm: off the beam's root, forward over the face, its three points ahead and up
            fore = V(0.42, 0.22, 0.88).normalized()
            root = V(0.07, 0.035, -0.012)
            end = root + fore * 0.20
            bd.tine(b, [put(root), put(root.lerp(end, 0.5) + V(0.0, 0.01, 0.0)), put(end)], 0.026 * k, 0.020 * k, 10, 0.05, side * 5.0)
            b.ellipsoid(put(root.lerp(end, 0.7)), V(0.045 * k, 0.014 * k, 0.050 * k), Matrix.Rotation(side * 0.45, 3, "Y") @ rot_x(-0.25), 10, 4)
            for j, way in enumerate((V(0.2, 0.45, 0.87), V(0.55, 0.35, 0.76), V(0.75, 0.55, 0.37))):
                way = way.normalized()
                start = end + way * -0.01
                bd.tine(b, [put(start), put(start + way * 0.06), put(start + way * 0.11 + V(0.0, 0.015, 0.0))], 0.018 * k, 0.005 * k, 8, 0.05, side * 7.0 + j)
        return kit.fused(b, None if low else (0.0045 * k, 1, 7000))
    return shapes


# --- Weights, bones, colours ---

DEER_WEIGHTS = bd.weights


def weights(c):
    deer_weigh = DEER_WEIGHTS(c)
    s = c.scale

    def weigh(part, p):
        if part == "tongue":
            return {"tongue": 1.0}
        if part in ("bell", "tassel"):
            root, end = bell_line(c)
            down = blend(root.y + 0.01 * s, root.y - 0.06 * s, p.y) if part == "bell" else 1.0
            return {"head": 1.0 - down, "bell": down}
        if part == "hair":
            root, end = bell_line(c)
            if p.y < root.y - 0.02 * s and abs(p.z - root.z) < 0.12 * s and p.y < c.head.y - 0.05 * s and p.z > c.neck.z:
                return {"bell": 1.0}
            # (a hackle: from its root on the crest, more of it with the hackles bone the further it stands off)
            up = blend(0.0, 0.06 * s, p.y - crest(c, p.z) + 0.006 * s)
            under = deer_weigh("coat", V(p.x, crest(c, p.z) - 0.01 * s, p.z))
            made = {bone: weight * (1.0 - up) for bone, weight in under.items()}
            made["hackles"] = made.get("hackles", 0.0) + up
            return made
        return deer_weigh(part, p)
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
    listed.append(("nose", c.at(0.30, -0.040), "head"))
    # (what a charge strikes with: the brow, between the antlers' roots)
    listed.append(("brow", c.at(0.06, 0.07), "head"))
    root, _ = bell_line(c)
    listed.append(("bell", root, "head"))
    listed.append(("hackles", V(0.0, hump_top(c, HUMP[0] * c.scale), HUMP[0] * c.scale), "chest"))
    listed.append(("tongue", c.at(0.07, -0.050), "jaw"))
    chain = ["pelvis", "tail", "tail_1", "tail_end"]
    for i, joint in enumerate(c.tail):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in c.legs.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
        listed.append(("toe" + suffix, c.toes[suffix], "paw" + suffix))
    return listed


def part_colours(c):
    return {
        "mouth": (0.20, 0.10, 0.10, 0.5), "tongue": (0.24, 0.14, 0.14, 0.7), "teeth": (0.66, 0.62, 0.50, 0.4),
        "eyes": (0.08, 0.06, 0.05, 1.0), "nose": (0.025, 0.022, 0.022, 0.85), "glands": (0.04, 0.035, 0.03, 0.6),
        "linings": (0.30, 0.25, 0.20, 0.0), "hooves": (0.06, 0.055, 0.05, 0.25), "antlers": (0.27, 0.23, 0.18, 0.1),
    }


def parts(c):
    made = [("coat", 0, bd.coat(c)), ("jaw", 0, jaw(c)), ("ears", 0, bd.ears(c)), ("bell", 0, bell(c)),
            ("mouth", 2, mouth(c)), ("tongue", 2, tongue(c)), ("teeth", 2, teeth(c)),
            ("eyes", 2, bd.eyes(c)), ("glands", 2, bd.glands(c)), ("nose", 2, nose(c)), ("linings", 2, bd.ear_linings(c)),
            ("hooves", 2, bd.hooves(c)), ("hair", 1, hair(c))]
    if c.antlers:
        made.append(("antlers", 2, antlers(c)))
    return made


def paint(c, whole, part_of):
    """Vertex colours: on the coat, red how open the surface is, green the dark of the coat, blue the pale; on the
    other parts their colours, and the antlers pale and weathered, darker in the hollows near their roots."""
    s = c.scale
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred_ = [part in ("coat", "jaw", "ears", "bell") for part in part_of]
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
    ped = c.at(0.0, 0.054, 0.030)
    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part == "hair":
            vert[layer] = (1.0, 1.0, 1.0, (math.sin(vert.index // 18 * 12.9898) * 43758.5453) % 1.0)
            continue
        if part == "antlers":
            reach = (p - V(math.copysign(ped.x, p.x), ped.y, ped.z)).length / (0.55 * c.scale / 1.95)
            pale = blend(0.1, 0.9, reach)
            base = colours["antlers"]
            vert[layer] = (base[0] + (0.50 - base[0]) * pale, base[1] + (0.46 - base[1]) * pale, base[2] + (0.40 - base[2]) * pale, base[3] + 0.15 * pale)
            continue
        if part in colours:
            vert[layer] = colours[part]
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 5.0, 0.0), 1.0) if furred_[vert.index] else 1.0
        # Dark nearly all over
        dark = 0.85
        pale = 0.0
        # A little greyer over the back and the hump (a saddle), more so on a bull
        top = hump_top(c, p.z)
        saddle = blend(top - 0.14 * s, top - 0.03 * s, p.y) * blend(-0.50 * s, -0.30 * s, p.z) * blend(0.40 * s, 0.26 * s, p.z)
        dark -= saddle * (0.45 if c.buck else 0.3)
        # The stockings: the legs pale below the elbow and the stifle, paler still down to the hooves
        if p.y < 0.66 * s:
            suffix, leg = bd.leg_share(c, p)
            joints = c.legs[suffix]
            fore = suffix[1] == "f"
            knee = joints[1] if fore else joints[2]
            below = blend(knee.y - (0.0 if fore else -0.12) * s, knee.y - (0.22 if fore else 0.06) * s, p.y)
            stocking = below * blend(0.3, 0.8, leg)
            pale = max(pale, stocking * 0.85)
            dark *= 1.0 - stocking
            # (the inside of the upper legs too)
            hip = joints[0]
            inside = blend(-0.004 * s, -0.016 * s, (abs(p.x) - abs(hip.x))) * leg * 0.5
            pale = max(pale, inside)
        # The head: as dark as the body on a bull; a cow's face lighter, grey-brown
        q = p - c.head
        along = c.unmuzzle(q.dot(c.face) / hs)
        on_head = q.z > -0.05 * hs and p.y > c.head.y - 0.20 * hs
        if on_head and not c.buck:
            face = blend(0.04, 0.16, along) * (1.0 - blend(0.24, 0.29, along))
            pale = max(pale, face * 0.32)
            dark *= 1.0 - face * 0.5
        if on_head:
            # (the end of the muzzle darkest)
            dark = max(dark, blend(0.22, 0.28, along) * 0.95)
        if part == "bell":
            dark = 0.9
        vert[layer] = (shade, max(dark, 0.0), pale, 1.0)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            vert = loop.vert
            uv2 = (0.95, 0.95)
            if part_of[vert.index] == "eyes":
                p = kit.from_blender(vert.co)
                side = 1.0 if p.x >= 0.0 else -1.0
                centre = c.at(bd.EYE[0], bd.EYE[1], side * bd.EYE[2])
                local = bd.eye_basis(c, side).inverted() @ (p - centre)
                if local.z > -0.3 * 0.017 * hs:
                    uv2 = (0.5 + local.x / (bd.EYE_SIZE.x * hs) * 0.4, 0.5 + local.y / (bd.EYE_SIZE.y * hs) * 0.4)
            loop[second].uv = uv2
    return layer


# The deer's builder, with the moose's own parts
bd.out_folder = out_folder
bd.mass = mass
bd.head = head
bd.parts = parts
bd.bones = bones
bd.weights = weights
bd.paint = paint
bd.part_colours = part_colours
bd.MATERIALS = [("coat", (0.24, 0.17, 0.115)), ("mane", (0.09, 0.07, 0.055)), ("parts", (1.0, 1.0, 1.0))]


def main():
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        for animal in ANIMALS:
            bd.export(animal, preview)


if __name__ == "__main__":
    main()
