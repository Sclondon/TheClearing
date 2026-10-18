"""Builds the woolly mammoth (creatures/mammoth): a grown cow and a calf, and exports them for Godot.

Run from the game's root (Blender 4.3):
    blender --background --python creatures/mammoth/tools/build_mammoth.py
    blender --background --python creatures/mammoth/tools/build_mammoth.py -- <preview folder> mammoth   # one, with pictures

Writes creatures/mammoth/models/mammoth.glb, mammoth_calf.glb and a demade `_lo` version of each. Nothing else is
written (an editable .blend and pictures go to the preview folder, when there is one).

A woolly mammoth, true to the frozen ones and the cave paintings:
- The head is the highest point of it: a tall single dome, a deep notch behind it at the neck, then the high hump over
  the shoulders, and the back sloping steeply down to low, narrow hindquarters and a short tail.
- A short thick neck; small ears, close to the head and furred; small eyes; the trunk long and heavy, ringed with
  creases, hanging nearly to the ground, its tip with two "fingers" (a long one above, a short one below).
- The tusks: long, heavy and spiralling, out and down from the face, then out to the sides, forward and up, and in at
  their tips; a calf has none.
- Column legs, nearly straight, on broad round feet with blunt nails.
- The coat: a dense under-wool and over it long coarse guard hair, hanging in a skirt from the flanks, the belly, the
  neck and the shoulders, longest low on the sides (to well below the belly), a mantle over the shoulders, a tuft on
  the dome of the head. The skirt is cards of hair (material `hair`), each a strip from its root to a ragged end, so
  that it is cheap and its shader can sway it; the body under it is `coat` (wool, with a shell or two).

Bones (each bone's rest has no turn, as the character controller's):
    body, chest, pelvis, neck, head, jaw, trunk_0 .. trunk_7, trunk_end (a marker: the tip), ear_l, ear_r,
    tail, tail_1, tail_end (marker)
    each leg (_fl, _fr, _rl, _rr): upper (shoulder or hip), lower (elbow or knee), foot (wrist or ankle), toe (a
    marker on the ground under the middle of the foot)
    tusk_l, tusk_r: markers at the tusks' tips (nothing weighted to them: the tusks go with the head)

Three surfaces: `coat`, `hair` (the guard hair: cards, their texture coordinates x from root 0 to end 1, y across;
vertex colour alpha their own number), `parts` (tusks, eyes, nails, the inside of the mouth, the trunk's bare tip; their
colours in the vertex colours, alpha how wet). The coat's vertex colours: red how open the surface is, green how dark.

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
import build_character as kit  # noqa: E402  (the character controller's shape-building tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
SUFFIXES = ("_fl", "_fr", "_rl", "_rr")
TRUNK_BONES = 8


def V(x, y, z):
    return Vector((x, y, z))


def rot_x(angle):
    return Matrix.Rotation(angle, 3, "X")


class Mammoth:
    """One animal's measurements, in metres at the size it is built (a grown cow stands 2.9 m at the shoulder)."""

    def __init__(self, name, calf=False):
        self.name = name
        self.calf = calf
        # (a calf is built small, with its own proportions: a big head, short legs, no tusks, all fuzz)
        s = 0.42 if calf else 1.0
        self.s = s
        leg = 0.82 if calf else 1.0
        head = 1.35 if calf else 1.1
        self.leg = leg
        self.head_k = head
        lift = (leg - 1.0) * 1.0 * s  # (shorter legs bring the whole body down)
        self.lift = lift
        # The barrel: (along, centre height, half width, half height)
        self.trunk = [(z * s, y * s + lift * 0.95, w * s, h * s) for z, y, w, h in [
            (-1.45, 1.70, 0.24, 0.28), (-1.32, 1.72, 0.52, 0.48), (-1.05, 1.78, 0.70, 0.58), (-0.65, 1.88, 0.80, 0.68),
            (-0.15, 2.00, 0.86, 0.77), (0.35, 2.12, 0.87, 0.82), (0.85, 2.15, 0.80, 0.78), (1.20, 2.12, 0.64, 0.66),
            (1.42, 2.08, 0.40, 0.46)]]
        # The hump over the shoulders: (centre, radii)
        self.hump = (V(0.0, 2.66 * s + lift, 0.45 * s), V(0.52 * s, 0.42 * s, 0.70 * s))
        # The head: the dome's middle and its radii; where the trunk begins
        hk = head
        self.head = V(0.0, 2.80 * s + lift - (0.25 * s if calf else 0.0), 1.80 * s + (0.05 * s if calf else 0.0))
        self.dome = (self.head + V(0.0, 0.10 * s * hk, -0.02 * s * hk), V(0.46 * s * hk, 0.60 * s * hk, 0.50 * s * hk))
        self.neck = V(0.0, 2.50 * s + lift, 1.30 * s)
        self.chest = V(0.0, 2.15 * s + lift, 0.65 * s)
        self.pelvis = V(0.0, 1.85 * s + lift, -0.95 * s)
        self.body = V(0.0, 2.02 * s + lift, -0.20 * s)
        self.trunk_root = self.head + V(0.0, -0.42 * s * hk, 0.48 * s * hk)
        self.jaw = self.head + V(0.0, -0.52 * s * hk, 0.18 * s * hk)
        self.eye = self.head + V(0.34 * s * hk, -0.08 * s * hk, 0.30 * s * hk)
        self.ear = self.head + V(0.40 * s * hk, 0.02 * s * hk, -0.22 * s * hk)
        # The trunk: from its root, down and a little forward, curling forward at the tip
        length = (2.05 * s if not calf else 2.05 * s * 0.75 * hk)
        self.trunk_length = length
        tip_down = self.trunk_root.y - 0.30 * s
        line = []
        for i in range(TRUNK_BONES + 1):
            t = i / TRUNK_BONES
            # (the bones evenly along its length, hanging: out a little, then down, the tip turned forward)
            line.append(self.trunk_root + V(0.0, -length * (t * 0.97), (0.20 * math.sin(math.pi * 0.5 * min(t * 2.0, 1.0)) - 0.06 * t + 0.16 * t * t * t) * s * hk))
        self.trunk_line = line
        # Legs: shoulder (or hip), elbow (or knee), wrist (or ankle), the middle of the foot on the ground
        fore = [V(0.55, 2.20, 0.95), V(0.57, 1.28, 0.86), V(0.55, 0.42, 0.94), V(0.55, 0.0, 0.98)]
        hind = [V(0.52, 1.80, -0.95), V(0.56, 1.00, -0.82), V(0.53, 0.40, -0.98), V(0.53, 0.0, -0.94)]
        self.legs = {}
        for suffix in SUFFIXES:
            side = 1.0 if suffix[2] == "l" else -1.0
            joints = fore if suffix[1] == "f" else hind
            made = []
            for k, j in enumerate(joints):
                y = j.y * s
                if k < 3:
                    # (shorter legs: everything above the foot comes down)
                    y = j.y * s * leg if k > 0 else j.y * s + lift
                made.append(V(j.x * side * s, y, j.z * s))
            self.legs[suffix] = made
        self.tail = [V(0.0, 2.10 * s + lift, -1.42 * s), V(0.0, 1.84 * s + lift, -1.53 * s), V(0.0, 1.54 * s + lift, -1.57 * s)]
        self.colours = dict(coat=(0.29, 0.24, 0.20), dark=(0.15, 0.12, 0.10))

    def trunk_at(self, z):
        """The barrel's (centre height, half width, half height) at `z`."""
        rings = self.trunk
        if z <= rings[0][0]:
            return rings[0][1:]
        for a, b in zip(rings, rings[1:]):
            if z <= b[0]:
                t = (z - a[0]) / (b[0] - a[0])
                return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
        return rings[-1][1:]

    def top_at(self, z):
        """The top of its back at `z`: the barrel, the hump, and the neck and dome before them."""
        y, w, h = self.trunk_at(z)
        top = y + h
        centre, radii = self.hump
        k = (z - centre.z) / radii.z
        if abs(k) < 1.0:
            top = max(top, centre.y + radii.y * math.sqrt(1.0 - k * k))
        return top


ANIMALS = [Mammoth("mammoth"), Mammoth("mammoth_calf", True)]


def chain_param(p, joints):
    best = (1e9, 0.0)
    for i in range(len(joints) - 1):
        a, b = joints[i], joints[i + 1]
        ab = b - a
        t = min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)
        d = (p - (a + ab * t)).length
        if d < best[0]:
            best = (d, i + t)
    return best


def tube_along(b, points, widths, depths, segments=12, sideways=X, caps=True):
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


def smooth_curve(points, steps=4):
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


def leg_rings(c, suffix):
    """The leg's rings: (point, half width, half depth), thick columns tapering to the ankle and swelling to the foot."""
    j = c.legs[suffix]
    fore = suffix[1] == "f"
    s = c.s
    if fore:
        stations = [(0.0, 0.34, 0.40), (0.35, 0.32, 0.36), (0.8, 0.27, 0.30), (1.0, 0.25, 0.27), (1.4, 0.23, 0.24),
                    (1.85, 0.22, 0.23), (2.0, 0.23, 0.24), (2.55, 0.26, 0.27), (2.85, 0.27, 0.28), (3.0, 0.26, 0.27)]
    else:
        stations = [(0.0, 0.32, 0.46), (0.35, 0.33, 0.42), (0.8, 0.27, 0.32), (1.0, 0.25, 0.27), (1.4, 0.22, 0.24),
                    (1.85, 0.21, 0.23), (2.0, 0.22, 0.23), (2.55, 0.25, 0.27), (2.85, 0.26, 0.28), (3.0, 0.25, 0.27)]
    out = []
    for t, w, d in stations:
        i = min(int(t), 2)
        f = t - i
        p = j[i].lerp(j[i + 1], f)
        if t >= 3.0:
            p = j[3] + V(0.0, 0.04 * s, 0.0)
        k = (1.15 if c.calf else 1.0)
        out.append((p, w * s * k, d * s * k))
    return out


def mass(c):
    """The body: the barrel, the hump, the neck, the head's dome and face, the legs and the base of the trunk, fused."""
    b = kit.Builder()
    s = c.s
    rings = [(V(0.0, y, z), X * w, Y * h) for z, y, w, h in c.trunk]
    b.tube(dome(rings[0], -Z, 0.06 * s)[::-1] + rings + dome(rings[-1], Z, 0.05 * s), 20)
    centre, radii = c.hump
    b.ellipsoid(centre, radii, None, 16, 9)
    # The neck: short, thick
    b.ellipsoid(c.neck + V(0.0, -0.05 * s, 0.05 * s), V(0.55 * s, 0.62 * s, 0.45 * s), rot_x(-0.3), 16, 9)
    # The head: the dome; the brow and the face sloping down to the trunk; the cheeks
    d_centre, d_radii = c.dome
    b.ellipsoid(d_centre, d_radii, rot_x(0.15), 16, 10)
    hk = c.head_k
    b.ellipsoid(c.head + V(0.0, -0.22 * s * hk, 0.26 * s * hk), V(0.36 * s * hk, 0.36 * s * hk, 0.34 * s * hk), rot_x(0.5), 14, 8)
    for side in (1.0, -1.0):
        b.ellipsoid(c.head + V(side * 0.22 * s * hk, -0.32 * s * hk, 0.18 * s * hk), V(0.20 * s * hk, 0.26 * s * hk, 0.26 * s * hk), None, 12, 7)
        if not c.calf:
            # (the tusks' sheaths, swelling out of the face either side of the trunk)
            root = tusk_line(c, side)[0]
            b.ellipsoid(root + V(-side * 0.02 * s, 0.10 * s, -0.08 * s), V(0.16 * s, 0.22 * s, 0.18 * s), rot_x(0.6), 12, 7)
    # The legs
    for suffix in SUFFIXES:
        rings = []
        for p, w, d in leg_rings(c, suffix):
            rings.append((p, X * w, Z * d))
        b.tube(dome(rings[0], Y, rings[0][1].length * 0.6)[::-1] + rings + dome(rings[-1], -Y, 0.03 * s, 1), 14, floor=0.0)
        j = c.legs[suffix]
        # (the round of the haunch and the top of the foreleg into the body)
        fore = suffix[1] == "f"
        b.ellipsoid(j[0] + V(0.0, -0.05 * s, 0.0 if fore else -0.05 * s), V(0.30 * s, 0.55 * s, 0.42 * s if fore else 0.52 * s), None, 12, 7)
    # The root of the trunk
    line = c.trunk_line
    tube_along(b, [line[0] + V(0.0, 0.18 * s, -0.10 * s), line[0], line[1]], [0.28 * s * c.head_k, 0.24 * s, 0.21 * s],
               [0.26 * s * c.head_k, 0.22 * s, 0.19 * s], 14)
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, 0.0)
    if kit.LOW:
        return kit.fused(b, None)
    mesh = bpy.data.meshes.new("part")
    b.bm.to_mesh(mesh)
    b.bm.free()
    part = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(part)
    remesh = part.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.025 * s
    remesh.adaptivity = 0.0
    smooth = part.modifiers.new("smooth", "SMOOTH")
    smooth.factor = 1.0
    smooth.iterations = 24
    bpy.context.view_layer.update()
    dense = bpy.data.meshes.new_from_object(part.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    decimate = part.modifiers.new("decimate", "DECIMATE")
    decimate.ratio = min(1.0, 16000 / max(kit.triangle_count(dense), 1))
    bpy.data.meshes.remove(dense)
    bpy.context.view_layer.update()
    result = bpy.data.meshes.new_from_object(part.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(part)
    return result


def coat(c):
    def shapes(b):
        body = mass(c)
        b.bm.from_mesh(body)
        bpy.data.meshes.remove(body)
        lay_wool(c, b.bm)
        return None
    return shapes


def lay_wool(c, bm):
    """Texture coordinates for the wool: (down the lie of the hair, round it), in metres."""
    uv = bm.loops.layers.uv.verify()
    for face in bm.faces:
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            loop[uv].uv = (-p.y + p.z * 0.2, math.atan2(p.x, p.z + 3.0) * 2.0 + p.z * 0.3)


def trunk(c):
    """The trunk below its root: a heavy ringed tube, tapering, its tip flattened, with its two fingers."""
    def shapes(b):
        s = c.s
        line = smooth_curve(c.trunk_line, 3 if not kit.LOW else 1)
        n = len(line)
        rings = []
        for i, p in enumerate(line):
            t = i / (n - 1)
            r = (0.235 - 0.155 * t) * s * (1.1 if c.calf else 1.0)
            # (ringed with creases)
            r *= 1.0 + 0.04 * math.sin(t * 60.0) * (1.0 - t * 0.5) if not kit.LOW else 1.0
            ahead = (line[min(i + 1, n - 1)] - line[max(i - 1, 0)]).normalized()
            across = ahead.cross(X).normalized()
            rings.append((p, X * r, across * r * (0.9 + 0.1 * t)))
        b.tube(dome(rings[0], (line[0] - line[1]).normalized(), 0.02 * s, 1)[::-1] + rings, 12)
        # The fingers at its tip: a long one in front (above, as it hangs) and a short one behind
        tip = line[-1]
        ahead = (line[-1] - line[-3]).normalized()
        front = ahead.cross(X).normalized()
        kit.spike(b, tip - ahead * 0.02 * s - front * 0.03 * s, tip + ahead * 0.10 * s - front * 0.05 * s, 0.035 * s, 8)
        kit.spike(b, tip - ahead * 0.02 * s + front * 0.04 * s, tip + ahead * 0.05 * s + front * 0.05 * s, 0.03 * s, 8)
        return kit.fused(b, None if kit.LOW else (0.012 * s, 2, 3500))
    return shapes


def tusk_line(c, side):
    """A tusk's curve, out of the face, down and forward, out to the side, then forward, up and in."""
    s = c.s
    pts = [V(0.22, 2.30, 2.12), V(0.30, 1.92, 2.42), V(0.50, 1.60, 2.80), V(0.70, 1.52, 3.25), V(0.68, 1.72, 3.68),
           V(0.48, 2.02, 3.88), V(0.30, 2.22, 3.82)]
    return [V(p.x * side * s, p.y * s + c.lift, p.z * s) for p in pts]


def tusks(c):
    def shapes(b):
        s = c.s
        for side in (1.0, -1.0):
            curve = smooth_curve(tusk_line(c, side), 5 if not kit.LOW else 2)
            n = len(curve)
            radii = [(0.115 - 0.09 * (i / (n - 1)) ** 0.9) * s for i in range(n)]
            b.strand(curve, radii, 12)
        return None
    return shapes


def eyes(c):
    def shapes(b):
        s = c.s * c.head_k
        for side in (1.0, -1.0):
            e = c.eye
            b.ellipsoid(V(e.x * side, e.y, e.z), V(0.035 * s, 0.028 * s, 0.035 * s), Matrix.Rotation(side * 1.1, 3, "Y"), 10, 6)
    return shapes


def ears(c):
    def shapes(b):
        s = c.s * c.head_k
        for side in (1.0, -1.0):
            e = c.ear
            # Small, round and close to the head, set back, furred
            b.ellipsoid(V(e.x * side, e.y, e.z), V(0.07 * s, 0.17 * s, 0.15 * s), Matrix.Rotation(side * 0.4, 3, "Y"), 10, 6)
        return None
    return shapes


def nails(c):
    def shapes(b):
        s = c.s
        for suffix in SUFFIXES:
            foot = c.legs[suffix][3]
            for k in (-1.0, 0.0, 1.0):
                a = k * 0.45
                at = foot + V(math.sin(a) * 0.24 * s, 0.05 * s, math.cos(a) * 0.25 * s)
                b.ellipsoid(at, V(0.055 * s, 0.04 * s, 0.03 * s), Matrix.Rotation(a, 3, "Y"), 8, 4)
    return shapes


def mouth(c):
    def shapes(b):
        s = c.s * c.head_k
        # The lower lip, a pointed spout under the trunk's root, and the dark mouth over it
        j = c.jaw
        tube_along(b, [j + V(0.0, 0.02 * s, -0.06 * s), j + V(0.0, -0.04 * s, 0.10 * s), j + V(0.0, -0.06 * s, 0.22 * s)],
                   [0.16 * s, 0.10 * s, 0.04 * s], [0.07 * s, 0.06 * s, 0.03 * s], 10)
    return shapes


def lip(c):
    def shapes(b):
        s = c.s * c.head_k
        j = c.jaw
        tube_along(b, [j + V(0.0, -0.03 * s, -0.04 * s), j + V(0.0, -0.08 * s, 0.10 * s), j + V(0.0, -0.10 * s, 0.24 * s)],
                   [0.17 * s, 0.11 * s, 0.04 * s], [0.06 * s, 0.05 * s, 0.025 * s], 10)
        return None
    return shapes


# --- The guard hair: cards ---

# Where each lock of hair grows from, for each of its points in turn (it is weighted as its root is)
HAIR_ROOTS = []


def outside(c, p, margin):
    """`p` pushed out of the body (the barrel, the hump, the neck, the dome, the tops of the legs) to `margin` off it."""
    s = c.s
    y, w, h = c.trunk_at(p.z)
    if c.trunk[0][0] < p.z < c.trunk[-1][0]:
        q = Vector((p.x / (w + margin), (p.y - y) / (h + margin)))
        if 1e-4 < q.length < 1.0:
            q = q.normalized()
            p = V(q.x * (w + margin), y + q.y * (h + margin), p.z)
    ellipsoids = [c.hump, (c.neck + V(0.0, -0.05 * s, 0.05 * s), V(0.55 * s, 0.62 * s, 0.45 * s)), c.dome]
    for suffix in SUFFIXES:
        j = c.legs[suffix]
        ellipsoids.append((j[0] + V(0.0, -0.05 * s, 0.0), V(0.30 * s, 0.55 * s, 0.45 * s)))
        ellipsoids.append((j[0].lerp(j[1], 0.6), V(0.30 * s, 0.6 * s, 0.34 * s)))
    for centre, radii in ellipsoids:
        grown = radii + V(margin, margin, margin)
        d = p - centre
        q = V(d.x / grown.x, d.y / grown.y, d.z / grown.z)
        if 1e-4 < q.length < 1.0:
            q = q.normalized()
            p = centre + V(q.x * grown.x, q.y * grown.y, q.z * grown.z)
    return p


def card(b, c, root, down, out, length, width, kink=0.0, lift=0.04):
    """A lock of hair as a strip of quads from its root, `length` along `down`, draped over the body (each point kept
    `lift` and more off it), `width` across, facing out of the body. Texture coordinates: x from root 0 to end 1, y
    across 0 to 1. Its ends are ragged in the shader."""
    rows = 5 if not kit.LOW else 2
    s = c.s
    points = [root]
    for r in range(1, rows):
        t = r / (rows - 1)
        step = down * (length / (rows - 1))
        bend = X.cross(down).normalized() * kink * length / (rows - 1) * t
        points.append(outside(c, points[-1] + step + bend, (lift + 0.035 * t) * s))
    verts = []
    for r, p in enumerate(points):
        t = r / (rows - 1)
        ahead = (points[min(r + 1, rows - 1)] - points[max(r - 1, 0)]).normalized()
        across = ahead.cross(out)
        across = across.normalized() if across.length > 0.3 else X
        w = width * (1.0 - 0.4 * t)
        verts.append((b._vert(p - across * w * 0.5, None), b._vert(p + across * w * 0.5, None), t))
        HAIR_ROOTS.extend((root, root))
    for (a0, a1, t0), (b0, b1, t1) in zip(verts, verts[1:]):
        face = b.bm.faces.new((a0, a1, b1, b0))
        for loop, (u, v) in zip(face.loops, ((t0, 0.0), (t0, 1.0), (t1, 1.0), (t1, 0.0))):
            loop[b.uv].uv = (u, v)


def hair(c):
    """The coat of long guard hair, over the under-wool: from the spine it falls down the sides, draped over the
    body, longest low on the flanks, to hang in a skirt to well below the belly; a heavier mantle over the hump and
    the shoulders, falling over the tops of the forelegs; a bib down the neck and chest; a fringe off the back of the
    head and a tuft on its dome; shaggy down the upper legs; a tuft at the end of the tail."""
    def shapes(b):
        s = c.s
        low = kit.LOW
        k = 1.0 if not low else 2.4  # (the low one: fewer, wider locks)
        seed = [c.s * 7.0]

        def rnd():
            seed[0] += 1.0
            return (math.sin(seed[0] * 12.9898 + 78.233) * 43758.5453) % 1.0

        hang = 1.0 if not c.calf else 0.6
        wide = (0.15 if not c.calf else 0.13) * s * k
        # The sides and the belly: rows along the body, each lock rooted round the barrel from the spine down
        z0, z1 = c.trunk[0][0] + 0.10 * s, c.trunk[-1][0] - 0.05 * s
        rows = int((z1 - z0) / (0.11 * s * k))
        for i in range(rows + 1):
            z = z0 + (z1 - z0) * i / rows
            steps = int(2.9 / (0.15 * k))
            for j in range(-steps, steps + 1):
                around = j * 0.15 * k + (rnd() - 0.5) * 0.1 * k
                y, w, h = c.trunk_at(z)
                root = V(math.sin(around) * w, y + math.cos(around) * h, z + (rnd() - 0.5) * 0.06 * s)
                root = outside(c, root, 0.0)
                out = V(math.sin(around) / max(w, 0.01), math.cos(around) / max(h, 0.01), 0.0).normalized()
                side = abs(around)
                # (down the sides, longest low on the flanks; lying back along the spine on top)
                length = (0.28 + 0.52 * blend(0.2, 1.9, side)) * s * hang * (0.85 + 0.3 * rnd())
                if side > 2.0:
                    length *= 0.65
                if side < 0.5:
                    down = (V(0.0, -0.3, 0.0) - Z * 0.7 + X * math.sin(around) * 0.8).normalized()
                    length *= 0.6
                else:
                    down = V(0.0, -1.0, -0.05).normalized()
                card(b, c, root, down, out, length, wide, (rnd() - 0.5) * 0.25)
        # The mantle over the hump and shoulders, falling over the forelegs
        centre, radii = c.hump
        for i in range(int(70 / k)):
            a = (rnd() - 0.5) * 3.0
            kz = (rnd() - 0.5) * 1.5
            p = centre + V(math.sin(a) * radii.x, math.cos(a) * radii.y * math.sqrt(max(1.0 - kz * kz * 0.6, 0.2)), kz * radii.z * 0.8)
            out = (p - centre).normalized()
            card(b, c, outside(c, p, 0.0), V(0.0, -1.0, 0.1).normalized(), out, (0.45 + 0.25 * abs(math.sin(a))) * s * hang, wide * 1.1, (rnd() - 0.5) * 0.3)
        # The bib: down the neck and the front of the chest
        for i in range(int(90 / k)):
            a = (rnd() - 0.5) * 3.8
            at = c.neck.lerp(c.chest + V(0.0, 0.0, 0.6 * s), rnd() * 0.8) + V(0.0, (rnd() - 0.4) * 0.5 * s, 0.0)
            p = outside(c, at + V(math.sin(a) * 0.6 * s, math.cos(a) * 0.4 * s, 0.4 * s), 0.0)
            out = V(math.sin(a), math.cos(a) * 0.3, 0.7).normalized()
            length = (0.38 + 0.3 * blend(0.5, 1.9, abs(a))) * s * hang
            card(b, c, p, V(0.0, -1.0, 0.05).normalized(), out, length, wide, (rnd() - 0.5) * 0.3)
        # The head: a fringe down the back of the dome and its sides, the tuft on its top
        d_centre, d_radii = c.dome
        for i in range(int(150 / k)):
            a = (rnd() - 0.5) * 3.5
            back = rnd() * 1.9 - 0.85
            p = d_centre + V(math.sin(a) * d_radii.x, math.cos(a) * d_radii.y, -back * d_radii.z * 0.9)
            out = (p - d_centre).normalized()
            if abs(a) < 0.3 and -0.2 < back < 0.4:
                # (the tuft on its crown, standing up and back)
                down = (out * 0.8 - Z * 0.4).normalized()
                length = (0.14 + 0.12 * rnd()) * s * (1.3 if c.calf else 1.0)
            elif back < -0.2:
                # (none down its face: the wool alone)
                continue
            else:
                down = V(0.0, -0.8, -0.5).normalized()
                length = (0.22 + 0.22 * rnd()) * s * (1.2 if c.calf else 1.0)
            card(b, c, outside(c, p, 0.0), down, out, length, wide * 0.7, (rnd() - 0.5) * 0.4, 0.02)
        # Short hair all over the dome and down the face, lying down it
        for i in range(int(260 / k)):
            u = V(rnd() - 0.5, rnd() * 1.3 - 0.45, rnd() * 1.5 - 0.45).normalized()
            p = d_centre + V(u.x * d_radii.x, u.y * d_radii.y, u.z * d_radii.z)
            out = u
            down = V(0.0, -1.0, 0.0) - out * (-out.y)
            down = down.normalized() if down.length > 0.2 else -Z
            card(b, c, p, down, out, (0.12 + 0.1 * rnd()) * s * (1.2 if c.calf else 1.0), 0.055 * s * k, (rnd() - 0.5) * 0.3, 0.012)
        # The legs: shaggy down the upper legs, less down the lower
        for suffix in SUFFIXES:
            j = c.legs[suffix]
            for i in range(int(34 / k)):
                t = rnd() * 1.5
                a = rnd() * math.tau
                at = j[0].lerp(j[1], min(t, 1.0)) if t <= 1.0 else j[1].lerp(j[2], t - 1.0)
                r = 0.31 * s * (1.0 - 0.15 * min(t, 1.4))
                out = V(math.cos(a), 0.0, math.sin(a))
                card(b, c, at + out * r, V(0.0, -1.0, 0.0), out, (0.28 + 0.25 * (1.0 - t / 1.5)) * s * hang, wide * 0.8, 0.0, 0.0)
        # The tail's tuft
        for i in range(int(12 / k) + 2):
            a = rnd() * math.tau
            at = c.tail[1].lerp(c.tail[2], rnd())
            out = V(math.cos(a), 0.0, math.sin(a) * 0.5 - 0.5).normalized()
            card(b, c, at, V(0.0, -1.0, -0.15).normalized(), out, 0.32 * s, 0.07 * s, 0.0, 0.0)
        return None
    return shapes


def tail(c):
    def shapes(b):
        s = c.s
        tube_along(b, c.tail, [0.09 * s, 0.06 * s, 0.035 * s], [0.08 * s, 0.05 * s, 0.03 * s], 8)
        return None
    return shapes


# --- Weights, bones, colours ---

def weights(c):
    s = c.s
    hk = c.head_k

    def head_share(p):
        """How much of a point goes with the head rather than the neck."""
        return blend(c.neck.z + 0.15 * s, c.head.z - 0.15 * s * hk, p.z) * blend(c.trunk_at(p.z)[0] - 0.2 * s, c.neck.y - 0.3 * s, p.y)

    def body(p):
        front = blend(-0.6 * s, 0.4 * s, p.z)
        made = {"chest": front, "pelvis": 1.0 - front}
        # (up the neck, and on into the head: the face and the dome all the head's)
        rising = blend(1.4 * s + c.lift, 1.9 * s + c.lift, p.y) if p.z < c.head.z - 0.3 * s * hk else 1.0
        neck = blend(c.chest.z + 0.2 * s, c.neck.z, p.z) * rising
        if neck > 0.0:
            head = blend(c.neck.z + 0.05 * s, c.head.z - 0.2 * s * hk, p.z)
            made = {bone: w * (1.0 - neck) for bone, w in made.items()}
            made["neck"] = made.get("neck", 0.0) + neck * (1.0 - head)
            made["head"] = made.get("head", 0.0) + neck * head
        return made

    def leg(p):
        """(which leg, how much of the point goes with it, how far down it counted in joints)."""
        suffix = ("_f" if p.z > -0.2 * s else "_r") + ("l" if p.x >= 0.0 else "r")
        joints = c.legs[suffix]
        off, along = chain_param(p, joints)
        share = blend(joints[0].y + 0.05 * s, joints[0].y - 0.40 * s, p.y) * blend(0.62 * s, 0.38 * s, off)
        if p.y < joints[2].y:
            share = max(share, blend(0.6 * s, 0.4 * s, off))
        return suffix, share, along

    def weigh(part, p):
        if part in ("tusks", "eyes", "mouth"):
            return {"head": 1.0}
        if part == "lip":
            return {"jaw": 1.0}
        if part == "ears":
            return {"ear_l" if p.x >= 0.0 else "ear_r": 0.8, "head": 0.2}
        if part == "nails":
            suffix = ("_f" if p.z > -0.2 * s else "_r") + ("l" if p.x >= 0.0 else "r")
            return {"foot" + suffix: 1.0}
        if part == "tail" or (part == "hair" and p.z < c.tail[0].z + 0.05 * s and abs(p.x) < 0.15 * s and p.y < c.tail[0].y):
            off, along = chain_param(p, c.tail)
            t = min(along, 1.999)
            return {"tail": 1.0 - (t % 1.0) if t < 1.0 else 0.0, "tail_1": t if t < 1.0 else 1.0} if t < 1.0 else {"tail_1": 1.0}
        line = c.trunk_line
        off, along = chain_param(p, line)
        if part == "trunk" or (part == "coat" and off < 0.30 * s and p.y < line[0].y - 0.02 * s and p.z > c.head.z):
            i = min(int(along), TRUNK_BONES - 1)
            f = along - i
            made = {"trunk_%d" % i: 1.0 - f * 0.5}
            if i + 1 < TRUNK_BONES:
                made["trunk_%d" % (i + 1)] = f * 0.5
            if i == 0 and f < 0.3:
                made = {"head": 1.0 - f / 0.3, "trunk_0": f / 0.3}
            return made
        suffix, share, along = leg(p)
        made = {bone: w * (1.0 - share) for bone, w in body(p).items()}
        if share > 0.0:
            joints = c.legs[suffix]
            spans = [(b - a).length for a, b in zip(joints, joints[1:])]
            low = blend(1.0 - 0.15 * s / spans[0], 1.0 + 0.15 * s / spans[1], along)
            foot = blend(2.0 - 0.12 * s / spans[1], 2.0 + 0.08 * s / spans[2], along)
            made["upper" + suffix] = share * (1.0 - low)
            made["lower" + suffix] = share * low * (1.0 - foot)
            made["foot" + suffix] = share * low * foot
        return made
    return weigh


def bones(c):
    listed = [
        ("body", c.body, None), ("chest", c.chest, "body"), ("pelvis", c.pelvis, "body"),
        ("neck", c.neck, "chest"), ("head", c.head, "neck"), ("jaw", c.jaw, "head"),
    ]
    parent = "head"
    for i in range(TRUNK_BONES):
        listed.append(("trunk_%d" % i, c.trunk_line[i], parent))
        parent = "trunk_%d" % i
    listed.append(("trunk_end", c.trunk_line[-1], parent))
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        listed.append(("ear" + suffix, V(c.ear.x * side, c.ear.y, c.ear.z), "head"))
        tip = tusk_line(c, side)[-1] if not c.calf else c.head + V(0.3 * side * c.s, -0.5 * c.s, 0.7 * c.s)
        listed.append(("tusk" + suffix, tip, "head"))
    listed.append(("tail", c.tail[0], "pelvis"))
    listed.append(("tail_1", c.tail[1], "tail"))
    listed.append(("tail_end", c.tail[2], "tail_1"))
    for suffix, joints in c.legs.items():
        for bone, joint in zip(("upper", "lower", "foot"), joints[:3]):
            listed.append((bone + suffix, joint, "body"))
        listed.append(("toe" + suffix, joints[3], "foot" + suffix))
    return listed


PART_COLOURS = {
    "tusks": (0.46, 0.43, 0.37, 0.04), "eyes": (0.05, 0.04, 0.035, 1.0), "nails": (0.20, 0.18, 0.15, 0.2),
    "mouth": (0.10, 0.08, 0.07, 0.6), "lip": (0.20, 0.16, 0.14, 0.4),
}
MATERIALS = [("coat", (0.29, 0.24, 0.20)), ("hair", (0.24, 0.19, 0.15)), ("parts", (1.0, 1.0, 1.0))]


def parts(c):
    made = [("coat", 0, coat(c)), ("trunk", 0, trunk(c)), ("ears", 0, ears(c)), ("tail", 0, tail(c)),
            ("eyes", 2, eyes(c)), ("nails", 2, nails(c)), ("mouth", 2, mouth(c)), ("lip", 2, lip(c)),
            ("hair", 1, hair(c))]
    if not c.calf:
        made.append(("tusks", 2, tusks(c)))
    return made


def paint(c, whole, part_of):
    first_hair = part_of.index("hair") if "hair" in part_of else 0
    s = c.s
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred_ = [part in ("coat", "trunk", "ears", "tail") for part in part_of]
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
    measured = sorted(open_[i] for i in range(len(open_)) if furred_[i])
    middle = measured[len(measured) // 2] if measured else 0.0
    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part == "hair":
            # (each lock its own number: shared by the verts of one card)
            own = (math.sin(((vert.index - first_hair) // (4 if kit.LOW else 10)) * 12.9898 + 1.0) * 43758.5453) % 1.0
            # (darker low down and on the legs, paler, sun-bleached, over the back)
            dark = blend(c.top_at(p.z) - 0.2 * s, 0.6 * s, p.y) * 0.6
            vert[layer] = (1.0, dark, 0.0, own)
            continue
        if part == "tusks":
            # (stained dark brown where they come out of the face, the ivory paler towards the tips)
            root = tusk_line(c, 1.0 if p.x >= 0.0 else -1.0)[0]
            pale = blend(0.15 * s, 0.9 * s, (p - root).length)
            base = PART_COLOURS["tusks"]
            vert[layer] = (base[0] * (0.45 + 0.55 * pale), base[1] * (0.45 + 0.55 * pale), base[2] * (0.42 + 0.58 * pale), base[3])
            continue
        if part in PART_COLOURS:
            vert[layer] = PART_COLOURS[part]
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 5.0, 0.0), 1.0) if furred_[vert.index] else 1.0
        dark = blend(1.2 * s, 0.2 * s, p.y) * 0.7
        if part == "trunk":
            dark = max(dark, 0.4) * (1.0 - blend(0.5, 0.0, p.y / s) * 0.3)
        vert[layer] = (shade, dark, 0.0, 1.0)
    return layer


def export(c, preview):
    low = kit.LOW
    name = c.name + ("_lo" if low else "")
    if kit.ONLY and c.name not in kit.ONLY:
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = kit.make_armature(bones(c))
    HAIR_ROOTS.clear()
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
            face.smooth = (not low or part == "tusks") and part != "hair"
        part_of += [part] * (len(whole.verts) - len(part_of))
    paint(c, whole, part_of)
    mesh = bpy.data.meshes.new(name)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    for label, srgb in MATERIALS:
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
    first_hair = part_of.index("hair") if "hair" in part_of else 0
    for vert, part in zip(whole.verts, part_of):
        at = HAIR_ROOTS[vert.index - first_hair] if part == "hair" else kit.from_blender(vert.co)
        for bone, weight in weigh(part, at).items():
            if weight > 0.001:
                vert[deform][groups[bone]] = weight
    whole.to_mesh(mesh)
    whole.free()
    for attribute in [a for a in mesh.color_attributes if a.name != "Color"]:
        mesh.color_attributes.remove(attribute)
    mesh.color_attributes.active_color = mesh.color_attributes["Color"]
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    body.parent = armature
    body.modifiers.new("Armature", "ARMATURE").object = armature
    folder = os.path.join(COMPONENT, "models")
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
    s = c.s
    middle = (0.0, 0.3 * s, 1.7 * s)
    head = kit.to_blender(c.head + V(0.0, -0.4 * s, 0.6 * s))
    views = [("side", (1, 0, 0), middle, 6.5 * s, "MATERIAL"), ("quarter", (0.7, -0.7, 0.2), middle, 6.5 * s, "MATERIAL"),
             ("front", (0.05, -1, 0.1), middle, 5.0 * s, "MATERIAL"), ("face", (0.6, -0.75, 0.2), tuple(head), 2.4 * s, "VERTEX"),
             ("back", (-0.6, 0.75, 0.3), middle, 6.5 * s, "MATERIAL")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 12.0 * s
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


def main():
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        for animal in ANIMALS:
            export(animal, preview)


if __name__ == "__main__":
    main()
