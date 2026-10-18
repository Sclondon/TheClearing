"""Builds the masked tribe's masks, spears and totem, and exports them for Godot.

    blender --background --python creatures/masked_tribe/tools/build_tribe.py [-- <folder for preview renders>]

Writes, into creatures/masked_tribe/models/:
- masks.glb and masks_lo.glb: five masks, one object each (`mask0`..`mask4`), in the
  space of the boy's head joint (Godot space: metres, Y up, the face looking down +Z),
  so a mask is simply hung on that joint.
- spears.glb and spears_lo.glb: two spears (`spear_stone`, `spear_bone`), their grip
  (the balance) at the origin and the point down -Z.
- totem.glb and totem_lo.glb: a pole in a cairn of stones with a skull on top (`totem`),
  its foot at the origin.

Everything is one material whose tones are vertex colours (MaskLook shades them), so
each mask, each spear and the totem is one surface: one draw. Nothing here needs the
character controller's tools: these are hung on the boy, not skinned to him.

What they are: the maze's own lost boys gone wild long ago (Lord of the Flies), not
any people that ever was. The masks are crude and carved from what the maze has: grey
dead wood, bark, bone, sticks, the feathers and teeth of its creatures; each is
different, each hides the face entirely, and every eye of them is a hole into the dark.
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
MODELS = os.path.join(COMPONENT, "models")

# Tones (near colourless, as the maze is: greys with a little warmth in them).
WOOD = (0.40, 0.355, 0.30)
DEAD_WOOD = (0.56, 0.53, 0.48)
BARK = (0.2, 0.175, 0.155)
BONE = (0.80, 0.77, 0.70)
OLD_BONE = (0.66, 0.62, 0.54)
CLAY = (0.84, 0.83, 0.79)
ASH = (0.16, 0.155, 0.15)
HOLE = (0.018, 0.016, 0.015)
FEATHER = (0.11, 0.11, 0.12)
STONE = (0.40, 0.405, 0.41)
FLINT = (0.27, 0.27, 0.29)
CORD = (0.26, 0.21, 0.17)
RUST = (0.33, 0.17, 0.13)
CLOTH = (0.42, 0.40, 0.36)
MATTED = (0.11, 0.1, 0.09)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(c, k):
    return tuple(max(0.0, min(1.0, c[i] * k)) for i in range(3))


def smooth(e0, e1, x):
    if e1 == e0:
        return 0.0 if x < e0 else 1.0
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def noise(x, y, seed=0.0):
    """A cheap smooth noise: sums of sines (enough for grain and wobble)."""
    return (math.sin(x * 12.9 + seed * 3.1 + math.sin(y * 7.3 + seed)) * 0.5
            + math.sin(y * 17.7 - seed * 1.7 + math.sin(x * 5.1)) * 0.3
            + math.sin((x + y) * 31.0 + seed * 5.3) * 0.2)


class Builder:
    """Vertices (Godot space) with a colour each, and faces; becomes one Blender object."""

    def __init__(self):
        self.verts = []
        self.colours = []
        self.faces = []
        self.flat = []

    def vert(self, p, c):
        self.verts.append(Vector(p))
        self.colours.append(c)
        return len(self.verts) - 1

    def face(self, idx, flat=False):
        self.faces.append(tuple(idx))
        self.flat.append(flat)

    def grid(self, rows, closed=False, flat=False, flip=False):
        """Quads between rows of vertex indices (each row the same length)."""
        for j in range(len(rows) - 1):
            a, b = rows[j], rows[j + 1]
            n = len(a)
            for i in range(n if closed else n - 1):
                k = (i + 1) % n
                quad = (a[i], a[k], b[k], b[i])
                self.face(tuple(reversed(quad)) if flip else quad, flat)

    def tube(self, points, radii, sides, colour, cap_start=True, cap_end=True, flat=False, twist=0.0):
        """A tube along a polyline (Godot space), `radii` one per point; colour(t, angle) or a tuple."""
        rings = []
        normal = None
        for k, p in enumerate(points):
            p = Vector(p)
            if k == 0:
                along = (Vector(points[1]) - p).normalized()
            elif k == len(points) - 1:
                along = (p - Vector(points[k - 1])).normalized()
            else:
                along = (Vector(points[k + 1]) - Vector(points[k - 1])).normalized()
            if normal is None:
                guess = Vector((0, 1, 0)) if abs(along.y) < 0.9 else Vector((1, 0, 0))
                normal = along.cross(guess).normalized()
            else:
                normal = (normal - along * normal.dot(along)).normalized()
            binormal = along.cross(normal)
            t = k / max(1, len(points) - 1)
            ring = []
            for s in range(sides):
                a = math.tau * s / sides + twist * t
                offset = normal * math.cos(a) + binormal * math.sin(a)
                c = colour(t, a) if callable(colour) else colour
                ring.append(self.vert(p + offset * radii[k], c))
            rings.append(ring)
        self.grid(rings, closed=True, flat=flat)
        if cap_start and radii[0] > 0.0005:
            c = colour(0.0, 0.0) if callable(colour) else colour
            centre = self.vert(points[0], c)
            for s in range(sides):
                self.face((centre, rings[0][(s + 1) % sides], rings[0][s]), flat)
        if cap_end and radii[-1] > 0.0005:
            c = colour(1.0, 0.0) if callable(colour) else colour
            centre = self.vert(points[-1], c)
            for s in range(sides):
                self.face((centre, rings[-1][s], rings[-1][(s + 1) % sides]), flat)
        return rings

    def blob(self, centre, radii, colour, nu=8, nv=5, rough=0.0, seed=0.0):
        centre = Vector(centre)
        rows = []
        top = None
        for j in range(1, nv):
            phi = -math.pi / 2 + math.pi * j / nv
            row = []
            for i in range(nu):
                th = math.tau * i / nu
                d = Vector((math.cos(phi) * math.cos(th), math.sin(phi), math.cos(phi) * math.sin(th)))
                k = 1.0 + rough * noise(d.x * 2 + seed, d.y * 2 + d.z, seed)
                c = colour(d) if callable(colour) else colour
                row.append(self.vert(centre + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2])) * k, c))
            rows.append(row)
        self.grid(rows, closed=True, flip=True)
        c = colour(Vector((0, -1, 0))) if callable(colour) else colour
        bottom = self.vert(centre - Vector((0, radii[1], 0)), c)
        c = colour(Vector((0, 1, 0))) if callable(colour) else colour
        top = self.vert(centre + Vector((0, radii[1], 0)), c)
        n = len(rows[0])
        for i in range(n):
            self.face((bottom, rows[0][i], rows[0][(i + 1) % n]))
            self.face((top, rows[-1][(i + 1) % n], rows[-1][i]))

    def blade(self, base, tip, width, thickness, colour, side_hint=(0, 1, 0), flat=True, waist=0.35):
        """A knapped point: a flattened double pyramid from `base` to `tip`, widest `waist` along it."""
        base, tip = Vector(base), Vector(tip)
        along = tip - base
        length = along.length
        along.normalize()
        across = along.cross(Vector(side_hint)).normalized()
        up = across.cross(along).normalized()
        widest = base + along * length * waist
        ring = [widest + across * width, widest + up * thickness, widest - across * width, widest - up * thickness]
        # (two more rings either side of the widest, a little uneven, as flaked stone is)
        ring2 = [base + along * length * (waist + 0.32) + across * width * 0.62, base + along * length * (waist + 0.3) + up * thickness * 0.7,
                 base + along * length * (waist + 0.34) - across * width * 0.58, base + along * length * (waist + 0.3) - up * thickness * 0.7]
        ids = [self.vert(p, colour) for p in ring]
        ids2 = [self.vert(p, shade(colour, 0.92)) for p in ring2]
        b = self.vert(base, colour)
        t = self.vert(tip, shade(colour, 1.1))
        for i in range(4):
            k = (i + 1) % 4
            self.face((b, ids[k], ids[i]), flat)
            self.face((ids[i], ids[k], ids2[k], ids2[i]), flat)
            self.face((ids2[i], ids2[k], t), flat)

    def strip(self, points, widths, normal, colour, two_sided=True):
        """A flat ribbon along points, `normal` its face (a feather, a strip of bark or rag)."""
        normal = Vector(normal).normalized()
        left, right = [], []
        for k, p in enumerate(points):
            p = Vector(p)
            if k < len(points) - 1:
                along = (Vector(points[k + 1]) - p).normalized()
            across = along.cross(normal).normalized()
            t = k / max(1, len(points) - 1)
            c = colour(t) if callable(colour) else colour
            left.append(self.vert(p + across * widths[k], c))
            right.append(self.vert(p - across * widths[k], c))
        self.grid([left, right])
        if two_sided:
            back_l = [self.vert(self.verts[i] - normal * 0.002, self.colours[i]) for i in left]
            back_r = [self.vert(self.verts[i] - normal * 0.002, self.colours[i]) for i in right]
            self.grid([back_l, back_r], flip=True)

    def build(self, name):
        bm = bmesh.new()
        layer = bm.loops.layers.color.new("Col")
        bverts = [bm.verts.new((p.x, -p.z, p.y)) for p in self.verts]
        bm.verts.ensure_lookup_table()
        for idx, flat in zip(self.faces, self.flat):
            if len(set(idx)) < 3:
                continue
            try:
                f = bm.faces.new([bverts[i] for i in idx])
            except ValueError:
                continue
            f.smooth = not flat
        # (every closed part faces outward, whichever way round it was put together)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        for f in bm.faces:
            for loop in f.loops:
                c = self.colours[loop.vert.index]
                loop[layer] = (c[0], c[1], c[2], 1.0)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(material())
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


_material = None


def material():
    """One material for all of it: white, its tones from the vertex colour (so the glTF has COLOR_0)."""
    global _material
    if _material:
        return _material
    _material = bpy.data.materials.new("tribe")
    _material.use_nodes = True
    nodes = _material.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Col"
    _material.node_tree.links.new(attribute.outputs[0], bsdf.inputs[0])
    return _material


# --- The masks ---------------------------------------------------------------------
#
# Head joint space: the middle of the boy's head is HEAD above the joint, and the head
# is an egg of HEAD_RADII (the boy's, from tools/build_boy.py, drawn a little larger on
# the game's rounder head). A mask is a carved shell wrapped round the front of a
# cylinder (or a ball) a little bigger than the head, thick, with its relief pushed out
# of it and its holes pushed deep into it and painted the dark.

HEAD = Vector((0.0, 0.096, 0.006))
HEAD_RADII = Vector((0.11, 0.14, 0.12))


def ellipse(x, y, cx, cy, rx, ry, tilt=0.0):
    """How far inside an ellipse a point is: 1 at its middle, 0 on its edge, negative outside."""
    dx, dy = x - cx, y - cy
    if tilt:
        c, s = math.cos(tilt), math.sin(tilt)
        dx, dy = dx * c - dy * s, dx * s + dy * c
    return 1.0 - math.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)


class Hole:
    """An eye, a mouth or a nostril: pushed back `depth` and dark inside, its lip raised a little."""

    def __init__(self, cx, cy, rx, ry, depth=0.05, lip=0.006, tilt=0.0, mirror=True):
        self.cx, self.cy, self.rx, self.ry, self.depth, self.lip, self.tilt, self.mirror = cx, cy, rx, ry, depth, lip, tilt, mirror

    def at(self, x, y):
        best = -9.0
        for side in ((1.0, -1.0) if self.mirror else (1.0,)):
            best = max(best, ellipse(x, y, self.cx * side, self.cy, self.rx, self.ry, self.tilt * side))
        return best


def mask_shell(b, q, half_angle, top, bottom, radius, width_at, relief, colour_at, thickness=0.03, wrap=1.0, forward_at=None,
               round_top=0.8, round_bottom=0.5):
    """A mask: a thick shell over the front of the head. `width_at(v)` (v 0 at the bottom, 1 at
    the top) is how much of `half_angle` it spans at that height; `relief(x, y)` is how far each
    point stands out (or sinks in) and `colour_at(x, y, out)` its tone. `wrap` bends it round
    the head top and bottom too (0 flat up and down). `forward_at(y)` pushes it out (a snout).
    `round_top` and `round_bottom` round its outline off there (0 square, 1 a half circle)."""
    nu = 9 + 11 * q
    nv = 11 + 14 * q
    front_rows, back_rows = [], []
    for j in range(nv + 1):
        v = j / nv
        y = bottom + (top - bottom) * v
        span = half_angle * width_at(v)
        # (its outline rounded off at the top and the bottom, as a carved thing is)
        top_round = math.sqrt(max(0.0, 1.0 - (max(0.0, v - 0.68) / 0.32) ** 2))
        bottom_round = math.sqrt(max(0.0, 1.0 - (max(0.0, 0.3 - v) / 0.3) ** 2))
        span *= (1.0 - round_top + round_top * max(0.2, top_round)) * (1.0 - round_bottom + round_bottom * max(0.3, bottom_round))
        frow, brow = [], []
        for i in range(nu + 1):
            u = -1.0 + 2.0 * i / nu
            a = u * span
            # (curved top and bottom: round the head like a helmet's brim, not a flat board)
            bend = wrap * 0.5 * ((y - HEAD.y) / max(top - HEAD.y, HEAD.y - bottom, 0.01)) ** 2
            r = radius * (1.0 - 0.12 * bend)
            x = math.sin(a) * r
            z = HEAD.z - 0.03 + math.cos(a) * r - bend * 0.06
            if forward_at:
                z += forward_at(x, y)
            out = relief(x, y)
            normal = Vector((math.sin(a), 0.0, math.cos(a)))
            p = Vector((x, y, z)) + normal * out
            frow.append(b.vert(p, colour_at(x, y, out)))
            back = Vector((x, y, z)) - normal * thickness
            brow.append(b.vert(back, shade(colour_at(x, y, 0.0), 0.55)))
        front_rows.append(frow)
        back_rows.append(brow)
    b.grid(front_rows)
    b.grid(back_rows, flip=True)
    # The rim: the shell's edge, all round.
    edge = [r[0] for r in front_rows] + front_rows[-1][1:] + [r[-1] for r in reversed(front_rows)][1:] + list(reversed(front_rows[0]))[1:-1]
    back_edge = [r[0] for r in back_rows] + back_rows[-1][1:] + [r[-1] for r in reversed(back_rows)][1:] + list(reversed(back_rows[0]))[1:-1]
    n = len(edge)
    for i in range(n):
        k = (i + 1) % n
        b.face((edge[k], edge[i], back_edge[i], back_edge[k]))
    return front_rows


def grain(base, x, y, seed, amount=0.12, along_y=True):
    g = noise(x * (6.0 if along_y else 40.0), y * (40.0 if along_y else 6.0), seed)
    return shade(base, 1.0 + amount * g)


def stick(b, q, start, end, radius, colour, bend=Vector((0, 0, 0)), knots=0, seed=0.0, tip=True):
    """A crooked stick, sharpened to a point at its end."""
    start, end = Vector(start), Vector(end)
    count = 4 + 2 * q
    points, radii = [], []
    rng = random.Random(seed)
    for k in range(count + 1):
        t = k / count
        p = start.lerp(end, t) + bend * math.sin(math.pi * t) + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * radius * 0.4 * (0 < k < count)
        points.append(p)
        r = radius * (1.0 - 0.35 * t)
        if tip:
            r *= 1.0 - smooth(0.75, 1.0, t) * 0.98
        radii.append(r)
    b.tube(points, radii, 4 + q, lambda t, a: grain(colour, t * 3.0, a, seed, 0.15), cap_end=not tip)


def eye_mark(holes, x, y):
    return max(h.at(x, y) for h in holes) if holes else -9.0


def hole_relief(holes, x, y):
    """Holes go deep, their lips stand up a little."""
    out = 0.0
    for h in holes:
        inside = h.at(x, y)
        if inside > 0.0:
            out -= min(h.depth, 0.024) * smooth(0.0, 0.35, inside)
        else:
            out += h.lip * max(0.0, 1.0 + inside * 6.0)
    return out


def hole_colour(holes, x, y, base):
    inside = eye_mark(holes, x, y)
    return mix(base, HOLE, smooth(-0.01, 0.05, inside))


def mask_long_face(b, q):
    """Mask 0: a long face of grey wood hanging to the chest, two round holes for eyes under a
    heavy brow, a nose ridge down the whole length of it, a small round mouth ringed with bone
    teeth, the chin grooved across; two crooked horns of stick out of its crown."""
    holes = [Hole(0.052, 0.112, 0.030, 0.034, 0.06), Hole(0.0, -0.20, 0.022, 0.03, 0.05, mirror=False)]

    def width(v):
        return 0.55 + 0.45 * smooth(0.0, 0.62, v) - 0.25 * smooth(0.86, 1.0, v)

    def relief(x, y):
        out = hole_relief(holes, x, y)
        out += 0.022 * smooth(0.03, 0.0, abs(y - 0.158)) * smooth(0.13, 0.05, abs(x))  # brow
        out += 0.03 * smooth(0.016, 0.0, abs(x)) * smooth(-0.15, -0.1, y) * smooth(0.12, 0.07, y)  # nose ridge
        out -= 0.006 * (math.sin((y + 0.3) * 120.0) > 0.6) * smooth(-0.1, -0.14, y)  # grooves on the chin
        return out

    def colour(x, y, out):
        c = grain(WOOD, x, y, 1.0, 0.18)
        c = mix(c, CLAY, 0.85 * (abs(x) < 0.012 and y > 0.16))  # a stripe of white clay up the brow
        c = mix(c, ASH, 0.8 * smooth(0.0, -0.005, out) * smooth(-0.1, -0.14, y))
        c = mix(c, CLAY, 0.7 * (abs(abs(x) - 0.052) < 0.006 and y < 0.07 and y > -0.05))  # tears of clay under the eyes
        return hole_colour(holes, x, y, c)

    mask_shell(b, q, 1.2, 0.29, -0.3, 0.165, width, relief, colour, wrap=0.6, round_top=0.9, round_bottom=0.7)
    hood(b, q, 1.0)
    # Bone teeth round the mouth, points in.
    for k in range(6 + 2 * q):
        a = math.tau * k / (6 + 2 * q)
        base = Vector((math.sin(a) * 0.034, -0.20 + math.cos(a) * 0.042, 0.135))
        b.tube([base, base + Vector((-math.sin(a) * 0.018, -math.cos(a) * 0.022, 0.012))], [0.006, 0.0], 3 + q, BONE, flat=True)
    for side in (1.0, -1.0):
        stick(b, q, (side * 0.07, 0.24, 0.07), (side * 0.2, 0.47, 0.02), 0.012, DEAD_WOOD, Vector((side * 0.05, 0.0, 0.0)), seed=3 + side)


def mask_skull(b, q):
    """Mask 1: the skull of one of the maze's beasts, bleached: a dome of bone, two great dark
    sockets, a hole for a nose, a muzzle running down with a row of teeth along it; antler
    prongs of stick bound to its brow."""
    holes = [Hole(0.056, 0.10, 0.042, 0.046, 0.07, 0.008, tilt=-0.3), Hole(0.0, 0.0, 0.016, 0.028, 0.05, mirror=False)]

    def width(v):
        return 0.45 + 0.55 * smooth(0.0, 0.55, v) - 0.3 * smooth(0.8, 1.0, v)

    def forward(x, y):
        # (its muzzle stands out below the sockets)
        return 0.05 * smooth(0.06, -0.06, y) * smooth(0.09, 0.02, abs(x))

    def relief(x, y):
        out = hole_relief(holes, x, y)
        out += 0.012 * smooth(0.025, 0.0, abs(y - 0.16)) * smooth(0.12, 0.04, abs(x))
        # a crack across it
        out -= 0.004 * smooth(0.004, 0.0, abs(y - 0.2 - 0.3 * x + 0.02 * math.sin(x * 90.0)))
        return out

    def colour(x, y, out):
        c = mix(BONE, OLD_BONE, 0.5 + 0.5 * noise(x * 8.0, y * 8.0, 2.0))
        c = mix(c, ASH, smooth(0.0, -0.004, out) * (1.0 - smooth(0.0, 0.1, eye_mark(holes, x, y) + 0.2)))
        c = mix(c, RUST, 0.55 * smooth(0.03, 0.0, abs(x - 0.0)) * smooth(0.23, 0.2, y) * smooth(0.12, 0.15, y))  # a smear
        return hole_colour(holes, x, y, c)

    mask_shell(b, q, 1.3, 0.27, -0.12, 0.16, width, relief, colour, wrap=1.0, forward_at=forward, round_top=1.0, round_bottom=0.6)
    hood(b, q, 2.0, OLD_BONE)
    # The teeth along the bottom of the muzzle.
    for k in range(7 + 2 * q):
        x = -0.06 + 0.12 * k / (6 + 2 * q)
        y = -0.115
        z = HEAD.z - 0.03 + 0.16 * math.cos(x / 0.16) + 0.05 * smooth(0.09, 0.02, abs(x)) + 0.004
        long = 0.03 + 0.02 * (k % 2) + (0.02 if abs(x) > 0.045 else 0.0)
        b.tube([(x, y + 0.01, z), (x, y - long, z + 0.004)], [0.007, 0.0], 3 + q, BONE, flat=True)
    for side in (1.0, -1.0):
        stick(b, q, (side * 0.09, 0.2, 0.06), (side * 0.25, 0.42, -0.06), 0.011, DEAD_WOOD, Vector((side * 0.04, 0.03, 0.0)), seed=5 + side)
        stick(b, q, (side * 0.17, 0.32, 0.0), (side * 0.13, 0.46, 0.05), 0.008, DEAD_WOOD, seed=7 + side)
        # (bound on with cord)
        b.blob((side * 0.095, 0.205, 0.08), (0.016, 0.014, 0.016), CORD, 5 + q, 4)


def mask_sun_crest(b, q):
    """Mask 2: a round face of dark bark ringed with clay, two narrow slits for eyes and a
    square mouth full of teeth, and a crown of sharpened sticks standing out all round it."""
    holes = [Hole(0.05, 0.115, 0.034, 0.011, 0.05, 0.004, tilt=0.25), Hole(0.0, 0.0, 0.05, 0.022, 0.05, mirror=False)]

    def width(v):
        return math.sqrt(max(0.0, 1.0 - (2.0 * v - 1.0) ** 2)) * 0.98 + 0.02

    def relief(x, y):
        r = math.hypot(x, y - 0.1)
        out = hole_relief(holes, x, y)
        out += 0.01 * smooth(0.01, 0.0, abs(r - 0.15))  # a raised ring
        out += 0.016 * smooth(0.02, 0.0, abs(x)) * smooth(0.02, 0.05, y) * smooth(0.13, 0.09, y)  # a short nose
        return out

    def colour(x, y, out):
        r = math.hypot(x, y - 0.1)
        c = grain(BARK, x, y, 4.0, 0.25, along_y=False)
        c = mix(c, CLAY, 0.9 * smooth(0.008, 0.0, abs(r - 0.15)))
        c = mix(c, CLAY, 0.8 * smooth(0.007, 0.0, abs(r - 0.18)))
        c = mix(c, CLAY, 0.75 * (abs(x) > 0.02 and abs(x) < 0.09 and abs(y - 0.06) < 0.006))  # a bar under the eyes
        return hole_colour(holes, x, y, c)

    mask_shell(b, q, 1.25, 0.3, -0.1, 0.16, width, relief, colour, wrap=0.3, round_top=0.0, round_bottom=0.0)
    hood(b, q, 3.0)
    # Teeth in the mouth: up from below and down from above.
    for k in range(5 + q):
        x = -0.036 + 0.072 * k / (4 + q)
        for top, sign in ((0.02, -1.0), (-0.02, 1.0)):
            b.tube([(x, top, 0.155), (x, top + sign * 0.02, 0.15)], [0.007, 0.0], 3 + q, BONE, flat=True)
    # The crown: sharpened sticks all round, longest at the top.
    count = 11 + 4 * q
    for k in range(count):
        a = -math.pi * 0.95 + math.pi * 1.9 * k / (count - 1)
        d = Vector((math.sin(a), math.cos(a), 0.0))
        long = 0.11 + 0.1 * smooth(1.6, 0.0, abs(a)) + 0.03 * (k % 2)
        start = Vector((0.0, 0.1, 0.1)) + d * 0.17
        stick(b, q, start, start + d * long + Vector((0, 0, -0.03)), 0.008, DEAD_WOOD if k % 3 else BONE, seed=11 + k)


def mask_feathered(b, q):
    """Mask 3: a pale oval of wood daubed white, with stripes of ash across it, eye slits
    slanting down to the middle, a fan of black feathers out of its top and strings of teeth
    hanging from its chin."""
    holes = [Hole(0.05, 0.105, 0.036, 0.014, 0.055, 0.005, tilt=-0.42), Hole(0.0, -0.06, 0.03, 0.008, 0.04, 0.003, mirror=False)]

    def width(v):
        return 0.5 + 0.5 * math.sin(math.pi * (0.15 + 0.7 * v))

    def relief(x, y):
        out = hole_relief(holes, x, y)
        out += 0.02 * smooth(0.02, 0.0, abs(x)) * smooth(-0.04, 0.0, y) * smooth(0.11, 0.06, y)
        out += 0.01 * smooth(0.06, 0.0, math.hypot(abs(x) - 0.07, y - 0.0))  # cheeks
        return out

    def colour(x, y, out):
        c = mix(CLAY, DEAD_WOOD, 0.35 + 0.3 * noise(x * 5.0, y * 9.0, 6.0))
        stripe = math.sin((y + abs(x) * 0.6) * 70.0)
        c = mix(c, ASH, 0.85 * smooth(0.55, 0.75, stripe) * smooth(0.04, 0.0, y))  # ash stripes below the eyes
        c = mix(c, ASH, 0.9 * smooth(0.012, 0.0, abs(x)) * smooth(0.16, 0.2, y))  # and one up the brow
        return hole_colour(holes, x, y, c)

    mask_shell(b, q, 1.2, 0.26, -0.17, 0.162, width, relief, colour, wrap=0.8, round_top=0.9, round_bottom=0.9)
    hood(b, q, 4.0)
    # Feathers, fanned out of its top.
    count = 5 + 2 * q
    for k in range(count):
        a = -0.75 + 1.5 * k / (count - 1)
        root = Vector((math.sin(a) * 0.08, 0.22, 0.06 - abs(a) * 0.03))
        d = Vector((math.sin(a) * 0.8, math.cos(a), -0.15)).normalized()
        long = 0.24 - 0.06 * abs(a)
        pts = [root + d * long * t + Vector((0, 0, -0.04)) * t * t for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        widths = [0.004, 0.022, 0.026, 0.02, 0.004]
        b.strip(pts, widths, Vector((0, 0, 1)), lambda t: mix(FEATHER, CLAY, smooth(0.8, 0.9, t)))
        b.tube([root, root + d * long * 0.9], [0.003, 0.002], 3, BONE, cap_start=False, cap_end=False)
    # Strings of teeth from its chin.
    for side in (-1.0, 0.0, 1.0):
        top = Vector((side * 0.045, -0.16, 0.12 - abs(side) * 0.02))
        long = 0.12 if side == 0 else 0.09
        b.tube([top, top + Vector((0, -long, 0.01))], [0.0025, 0.0025], 3, CORD, cap_start=False)
        for k in range(2 + q):
            at = top + Vector((0, -long * (k + 1) / (2 + q), 0.012))
            b.tube([at + Vector((0, 0.008, 0)), at + Vector((0, -0.022, 0.006))], [0.006, 0.0], 3 + q, BONE, flat=True)


def mask_tusked(b, q):
    """Mask 4: a beast's face of dark wood with a snout jutting out of it, two nostrils, small
    deep eyes close together, curved tusks of some creature's teeth either side of the snout,
    and a shag of bark strips hanging from its brow over its back."""
    holes = [Hole(0.04, 0.12, 0.022, 0.024, 0.06, 0.006), Hole(0.018, 0.005, 0.009, 0.012, 0.04, 0.004)]

    def width(v):
        return 0.6 + 0.4 * smooth(0.0, 0.5, v) - 0.2 * smooth(0.85, 1.0, v)

    def forward(x, y):
        return 0.08 * smooth(0.1, 0.0, y) * smooth(-0.11, -0.04, y) * smooth(0.075, 0.015, abs(x))

    def relief(x, y):
        out = hole_relief(holes, x, y)
        out += 0.025 * smooth(0.03, 0.0, abs(y - 0.155)) * smooth(0.12, 0.03, abs(x))
        out -= 0.01 * smooth(0.012, 0.0, abs(y + 0.07)) * smooth(0.06, 0.02, abs(x))  # its mouth line
        return out

    def colour(x, y, out):
        c = grain(shade(WOOD, 0.95), x, y, 9.0, 0.3)
        c = mix(c, CLAY, 0.8 * (abs(abs(x) - 0.04) < 0.006 and y > 0.15 and y < 0.24))  # two clay marks over the eyes
        c = mix(c, CLAY, 0.85 * smooth(0.012, 0.004, abs(math.hypot(abs(x) - 0.04, (y - 0.12) * 0.9) - 0.036)))  # rings of clay round them
        c = mix(c, HOLE, 0.8 * smooth(0.0, -0.006, out) * smooth(-0.05, -0.08, y))
        return hole_colour(holes, x, y, c)

    mask_shell(b, q, 1.25, 0.26, -0.15, 0.165, width, relief, colour, wrap=0.7, forward_at=forward, round_top=0.8, round_bottom=0.6)
    hood(b, q, 5.0, BARK)
    for side in (1.0, -1.0):
        root = Vector((side * 0.055, -0.04, 0.2))
        pts = [root + Vector((side * 0.01 * t, 0.09 * t * t, 0.05 * t - 0.03 * t * t)) for t in (0.0, 0.33, 0.66, 1.0)]
        pts = [root] + [p + Vector((side * 0.02, 0.0, 0.0)) * k for k, p in enumerate(pts[1:], 1)]
        b.tube(pts, [0.013, 0.01, 0.006, 0.0], 4 + q, OLD_BONE, flat=False)
    count = 6 + 3 * q
    for k in range(count):
        a = -1.2 + 2.4 * k / (count - 1)
        root = Vector((math.sin(a) * 0.15, 0.22 - abs(a) * 0.04, HEAD.z + math.cos(a) * 0.1))
        long = 0.18 + 0.06 * ((k * 7) % 3) / 2.0
        out = Vector((math.sin(a), 0.0, math.cos(a)))
        pts = [root + out * 0.02 * t - Vector((0, long * t, 0)) - Vector((0, 0, 0.09 * t)) for t in (0.0, 0.3, 0.6, 1.0)]
        b.strip(pts, [0.012, 0.016, 0.013, 0.006], out, lambda t: grain(BARK, t, k, 2.0 + k, 0.3))


def hood(b, q, seed, tone=None):
    """What a mask is tied on with, behind it: a matted mass of hair, dead grass and cord over the
    whole of the boy's head, and a shag of it hanging down his neck, so nothing of him shows."""
    tone = tone or MATTED
    def colour(d):
        return shade(mix(MATTED, tone, 0.35), 0.8 + 0.4 * (0.5 + 0.5 * noise(d.x * 3.0 + seed, d.y * 4.0 + d.z, seed)))
    b.blob(HEAD + Vector((0.0, 0.01, -0.02)), (HEAD_RADII.x * 1.16, HEAD_RADII.y * 1.08, HEAD_RADII.z * 1.12), colour, 9 + 4 * q, 6 + 2 * q, rough=0.09, seed=seed)
    count = 5 + 3 * q
    for k in range(count):
        a = math.pi * (0.55 + 0.9 * k / (count - 1))
        out = Vector((math.sin(a), 0.0, math.cos(a)))
        root = HEAD + Vector((math.sin(a) * HEAD_RADII.x * 1.05, -0.04, math.cos(a) * HEAD_RADII.z * 1.05 - 0.02))
        long = 0.13 + 0.06 * ((k * 5 + int(seed)) % 3) / 2.0
        pts = [root + out * 0.025 * t - Vector((0.0, long * t, 0.0)) for t in (0.0, 0.4, 0.75, 1.0)]
        b.strip(pts, [0.02, 0.022, 0.016, 0.004], out, lambda t: shade(MATTED, 0.9 + 0.3 * t))


def rags(b, q):
    """A fringe of torn cloth knotted round his waist over the breeches: what is left of a shirt,
    in strips. In the space of the boy's hips joint."""
    rng = random.Random(61)
    count = 9 + 5 * q
    for k in range(count):
        a = math.tau * k / count + rng.uniform(-0.12, 0.12)
        out = Vector((math.sin(a), 0.0, math.cos(a)))
        root = Vector((math.sin(a) * 0.118, 0.07, math.cos(a) * 0.092 + 0.005))
        long = rng.uniform(0.1, 0.24)
        pts = [root + out * (0.012 + 0.03 * t * t) - Vector((0.0, long * t, 0.0)) for t in (0.0, 0.35, 0.7, 1.0)]
        tone = CLOTH if k % 3 else shade(CLOTH, 0.6)
        b.strip(pts, [0.03, 0.028, 0.02, 0.006], out, lambda t: shade(tone, 1.0 - 0.25 * t))
    # (the band they hang from)
    ring = [Vector((math.sin(math.tau * k / 12) * 0.122, 0.072, math.cos(math.tau * k / 12) * 0.096 + 0.005)) for k in range(13)]
    b.tube(ring, [0.012] * 13, 4, shade(CLOTH, 0.7), cap_start=False, cap_end=False)


MASKS = [mask_long_face, mask_skull, mask_sun_crest, mask_feathered, mask_tusked]


# --- The spears ----------------------------------------------------------------------

def spear(b, q, point):
    """A sharpened stick of a spear, 1.75 m: its grip (the balance) at the origin, the point
    down -Z. A little crooked, knotted, bound with cord below its head; the head knapped
    stone or a splinter of bone."""
    rng = random.Random(21 if point == "stone" else 23)
    count = 8 + 6 * q
    points, radii = [], []
    for k in range(count + 1):
        t = k / count
        z = 0.72 - 1.75 * t * 0.97
        wobble = Vector((math.sin(t * 7.0 + 1.0) * 0.008, math.sin(t * 5.0) * 0.006, 0.0))
        points.append(Vector((0.0, 0.0, z)) + wobble * (0 < k < count))
        radii.append(0.016 * (1.0 - 0.3 * t) * (1.0 + 0.12 * (rng.random() > 0.8)))
    b.tube(points, radii, 5 + 2 * q, lambda t, a: grain(DEAD_WOOD if point == "bone" else WOOD, t * 4.0, a, 3.0, 0.2))
    # The binding below the head, and a strip of rag tied by the butt.
    neck = points[-1]
    for k in range(3 + 2 * q):
        z = neck.z + 0.02 + 0.012 * k
        b.blob((neck.x, neck.y, z), (0.0125, 0.0125, 0.007), CORD, 5 + 2 * q, 3)
    if point == "stone":
        b.blade(neck + Vector((0, 0, 0.03)), neck + Vector((0, 0, -0.17)), 0.03, 0.009, FLINT, side_hint=(0, 1, 0))
    else:
        b.blade(neck + Vector((0, 0, 0.04)), neck + Vector((0, 0, -0.22)), 0.016, 0.009, BONE, side_hint=(0, 1, 0), waist=0.2)
    knot = Vector((0.0, 0.0, 0.62))
    b.blob(knot, (0.014, 0.014, 0.012), CORD, 5 + q, 3)
    b.strip([knot + Vector((0.012, 0.0, 0.0)), knot + Vector((0.03, -0.08, 0.02)), knot + Vector((0.04, -0.17, 0.05))],
            [0.012, 0.014, 0.008], Vector((1, 0, 0.3)), CLOTH)


# --- The totem -----------------------------------------------------------------------

def totem(b, q):
    """What a hunting party leaves in its dead end: a pole of dead wood in a cairn of stones,
    a great beast's skull on top, a crossbar of sticks hung with strings of bones and teeth,
    a rag; sharpened sticks driven in round its foot, points out."""
    rng = random.Random(31)
    # The pole.
    pts = [Vector((0.03 * math.sin(t * 5.0), 2.5 * t, 0.025 * math.sin(t * 3.0 + 1.0))) for t in [k / (6 + 4 * q) for k in range(7 + 4 * q)]]
    b.tube(pts, [0.07 - 0.03 * k / len(pts) for k in range(len(pts))], 6 + 2 * q, lambda t, a: grain(DEAD_WOOD, t * 3.0, a, 8.0, 0.2))
    # The cairn.
    for k in range(9 + 5 * q):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.12, 0.42)
        size = rng.uniform(0.09, 0.16)
        b.blob((math.cos(a) * r, size * 0.6 + (0.1 if r < 0.25 and k % 2 else 0.0), math.sin(a) * r), (size, size * 0.75, size * 0.9),
               shade(STONE, rng.uniform(0.8, 1.15)), 6 + q, 4, rough=0.15, seed=k)
    # The skull at the top: mask 1, drawn half again as big, looking out (+Z).
    skull = Builder()
    mask_skull(skull, q)
    lift = Matrix.Translation((0.0, 2.3, 0.02)) @ Matrix.Scale(1.7, 4)
    base = len(b.verts)
    for p, c in zip(skull.verts, skull.colours):
        b.vert(lift @ p, c)
    for f, flat in zip(skull.faces, skull.flat):
        b.face(tuple(i + base for i in f), flat)
    # The crossbar, with what hangs from it.
    bar_y = 1.75
    stick(b, q, (-0.42, bar_y + 0.04, 0.03), (0.44, bar_y - 0.03, 0.02), 0.022, DEAD_WOOD, Vector((0, 0.03, 0)), seed=41, tip=False)
    b.blob((0.0, bar_y, 0.05), (0.06, 0.04, 0.05), CORD, 6, 4)
    for k, x in enumerate((-0.36, -0.18, 0.2, 0.38)):
        top = Vector((x, bar_y - 0.01, 0.03))
        long = 0.28 + 0.12 * (k % 2)
        b.tube([top, top - Vector((0, long, 0))], [0.004, 0.004], 3, CORD, cap_start=False)
        for j in range(2 + q):
            at = top - Vector((0, long * (j + 1) / (2 + q), 0))
            if j % 2:
                b.blob(at, (0.012, 0.03, 0.012), BONE, 5, 3)
            else:
                b.tube([at + Vector((0, 0.01, 0)), at + Vector((0.004, -0.045, 0.004))], [0.009, 0.0], 3 + q, BONE, flat=True)
    # A rag tied to the pole, and a feather or two.
    rag = [Vector((0.06, 1.45, 0.0)), Vector((0.16, 1.3, 0.05)), Vector((0.2, 1.1, 0.04)), Vector((0.22, 0.95, 0.08))]
    b.strip(rag, [0.04, 0.05, 0.045, 0.02], Vector((0, 0, 1)), shade(CLOTH, 0.8))
    for side in (1.0, -1.0):
        root = Vector((side * 0.06, 2.12, 0.0))
        d = Vector((side * 0.5, 1.0, 0.1)).normalized()
        pts = [root + d * 0.3 * t for t in (0.0, 0.33, 0.66, 1.0)]
        b.strip(pts, [0.005, 0.03, 0.026, 0.004], Vector((0, 0, 1)), lambda t: mix(FEATHER, CLAY, smooth(0.8, 0.95, t)))
    # Sharpened sticks driven in round its foot, leaning out.
    for k in range(6 + 3 * q):
        a = math.tau * k / (6 + 3 * q) + rng.uniform(-0.2, 0.2)
        foot = Vector((math.cos(a) * 0.5, 0.0, math.sin(a) * 0.5))
        top = foot + Vector((math.cos(a) * 0.35, rng.uniform(0.55, 0.9), math.sin(a) * 0.35))
        stick(b, q, foot, top, 0.016, DEAD_WOOD, seed=51 + k)


# --- Export --------------------------------------------------------------------------

def clear():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def export(objects, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_normals=True, export_materials="EXPORT", export_animations=False, export_skins=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)
    print("wrote %s (%d triangles)" % (path, tris))


def build(q, suffix):
    clear()
    made = []
    for k, fn in enumerate(MASKS):
        b = Builder()
        fn(b, q)
        made.append(b.build("mask%d" % k))
    b = Builder()
    rags(b, q)
    made.append(b.build("rags"))
    export(made, os.path.join(MODELS, "masks%s.glb" % suffix))
    for obj in made:
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print("  %s: %d triangles" % (obj.name, tris))
    clear()
    made = []
    for point in ("stone", "bone"):
        b = Builder()
        spear(b, q, point)
        made.append(b.build("spear_" + point))
    export(made, os.path.join(MODELS, "spears%s.glb" % suffix))
    clear()
    b = Builder()
    totem(b, q)
    export([b.build("totem")], os.path.join(MODELS, "totem%s.glb" % suffix))


def previews(folder):
    """Renders each mask and the spears in Workbench, with their vertex colours, for a quick look."""
    clear()
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 600
    world = bpy.data.worlds.new("w") if not scene.world else scene.world
    scene.world = world
    objs = []
    for k, fn in enumerate(MASKS):
        b = Builder()
        fn(b, 2)
        obj = b.build("mask%d" % k)
        obj.location = ((k - 2) * 0.55, 0.0, 0.0)
        objs.append(obj)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, at, rot in (("front", (0.0, -3.4, 0.1), (math.radians(90), 0, 0)), ("quarter", (2.2, -2.6, 0.5), (math.radians(82), 0, math.radians(40)))):
        cam.location = at
        cam.rotation_euler = rot
        cam_data.lens = 50
        scene.render.filepath = os.path.join(folder, "masks_%s.png" % name)
        bpy.ops.render.render(write_still=True)
    clear()
    b = Builder()
    totem(b, 2)
    b.build("totem")
    for point, x in (("stone", 0.6), ("bone", 0.8)):
        s = Builder()
        spear(s, 2, point)
        o = s.build("spear_" + point)
        o.location = (x, 0.0, 1.0)
        o.rotation_euler = (math.radians(-90), 0, 0)
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0.3, -5.0, 1.4)
    cam.rotation_euler = (math.radians(88), 0, 0)
    scene.render.filepath = os.path.join(folder, "totem.png")
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(MODELS, exist_ok=True)
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(2, "")
    build(0, "_lo")
    if args:
        previews(args[0])


main()
