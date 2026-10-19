"""Builds the woodsman's head and hat, his coat, his axe and his oil lantern, and exports them for Godot.

    blender --background --python creatures/woodsman/tools/build_woodsman.py [-- <folder for preview renders>]

Writes, into creatures/woodsman/models/:
- woodsman.glb and woodsman_lo.glb, one object each:
  - `head`: an old man's gaunt head, long grey beard and battered top hat, in the space of the
    boy's head joint (Godot space: metres, Y up, the face looking down +Z), so it is simply hung
    on that joint in place of the boy's own head.
  - `coat`: the long skirts of his coat, open at the front, in the space of the boy's hips joint.
  - `collar`: its collar turned up round his neck, in the space of the boy's chest joint.
  - `axe`: a felling axe, its grip at the origin, the haft down -Z to the head, the blade's edge
    towards -Y (the knuckles' way, in his fist).
  - `lantern`: an oil lantern's frame, the top of its bail (where it is held) at the origin, the
    lantern hanging down -Y; `lantern_glass`: its glass, which the game lights.

Everything but the glass is one material whose tones are vertex colours (the figures' cel
shading reads them), so each is one surface: one draw. Hung on the boy, not skinned to him:
nothing here needs the character controller's tools.

After the woodsman of Over the Garden Wall, in Warren's near colourless greys (the user,
2026-10-18: "Lets add a woodsmen with an axe and top hat and lantern").
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
MODELS = os.path.join(COMPONENT, "models")

SKIN = (0.64, 0.59, 0.54)
SKIN_DARK = (0.47, 0.42, 0.38)
SOCKET = (0.24, 0.2, 0.18)
EYE = (0.62, 0.6, 0.55)
BEARD = (0.68, 0.665, 0.64)
BEARD_DARK = (0.52, 0.505, 0.48)
HAT = (0.12, 0.115, 0.11)
HAT_WORN = (0.2, 0.19, 0.175)
BAND = (0.06, 0.055, 0.05)
COAT = (0.32, 0.29, 0.26)
COAT_WORN = (0.4, 0.37, 0.33)
LINING = (0.1, 0.09, 0.085)
HAFT = (0.4, 0.34, 0.27)
HAFT_DARK = (0.26, 0.22, 0.18)
IRON = (0.24, 0.24, 0.25)
EDGE = (0.6, 0.6, 0.6)
RUST = (0.3, 0.2, 0.15)
TIN = (0.19, 0.18, 0.17)
GLASS = (1.0, 0.85, 0.55)


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


def bump(x, centre, width):
    """1 at `centre`, falling smoothly to 0 `width` either side of it."""
    return smooth(width, 0.0, abs(x - centre))


def noise(x, y, seed=0.0):
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
        for j in range(len(rows) - 1):
            a, b = rows[j], rows[j + 1]
            n = len(a)
            for i in range(n if closed else n - 1):
                k = (i + 1) % n
                quad = (a[i], a[k], b[k], b[i])
                self.face(tuple(reversed(quad)) if flip else quad, flat)

    def tube(self, points, radii, sides, colour, cap_start=True, cap_end=True, flat=False):
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
                a = math.tau * s / sides
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

    def strip(self, points, widths, normal, colour, two_sided=True):
        normal = Vector(normal).normalized()
        left, right = [], []
        along = Vector((0, -1, 0))
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

    def build(self, name, recalc=True, mat=None):
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
        if recalc:
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        for f in bm.faces:
            for loop in f.loops:
                c = self.colours[loop.vert.index]
                loop[layer] = (c[0], c[1], c[2], 1.0)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mat or material())
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


_materials = {}


def material(name="woodsman"):
    """One material for all of it: white, its tones from the vertex colour (so the glTF has COLOR_0)."""
    if name in _materials:
        return _materials[name]
    made = bpy.data.materials.new(name)
    made.use_nodes = True
    nodes = made.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    attribute = nodes.new("ShaderNodeVertexColor")
    attribute.layer_name = "Col"
    made.node_tree.links.new(attribute.outputs[0], bsdf.inputs[0])
    _materials[name] = made
    return made


def shell(b, rows_y, sides, radius_at, colour_at, close_top=True, close_bottom=True, centre_z=0.0):
    """A closed surface of rings, one per height in `rows_y` (bottom up): `radius_at(y, a)` is
    (how far out, how far forward of `centre_z` it is pushed) at angle `a` (0 the front, +Z),
    and `colour_at(y, a, out)` its tone."""
    rings = []
    for y in rows_y:
        ring = []
        for s in range(sides):
            a = math.tau * s / sides
            r, push = radius_at(y, a)
            p = Vector((math.sin(a) * r[0], y, centre_z + math.cos(a) * r[1] + push))
            ring.append(b.vert(p, colour_at(y, a, push)))
        rings.append(ring)
    b.grid(rings, closed=True, flip=True)
    if close_bottom:
        c = b.vert((0.0, rows_y[0] - 0.002, centre_z), colour_at(rows_y[0], 0.0, 0.0))
        for s in range(sides):
            b.face((c, rings[0][s], rings[0][(s + 1) % sides]))
    if close_top:
        c = b.vert((0.0, rows_y[-1] + 0.002, centre_z), colour_at(rows_y[-1], 0.0, 0.0))
        for s in range(sides):
            b.face((c, rings[-1][(s + 1) % sides], rings[-1][s]))
    return rings


# --- The head ----------------------------------------------------------------------
#
# Head joint space. The boy's head (hidden) was a big round child's head; this one is an old
# man's, small for his shoulders as a grown man's is, gaunt: a long jaw under a long grey
# beard, hollow cheeks, a long thin nose, the eyes deep in their sockets under a heavy brow,
# and a battered top hat pulled down over them.

def head(b, q):
    sides = 14 + 10 * q
    rows = [k / (10 + 12 * q) for k in range(11 + 12 * q)]
    chin, crown = -0.004, 0.168

    def width(y):
        # (jaw, cheek, cheekbone, temple, dome)
        w = 0.026 + 0.022 * smooth(-0.004, 0.03, y) + 0.008 * smooth(0.05, 0.085, y)
        return w * math.sqrt(max(0.0, 1.0 - smooth(0.12, crown, y) ** 2 * 0.98))

    def radius_at(y, a):
        x = math.sin(a)
        front = max(0.0, math.cos(a))
        w = width(y)
        d = w * 1.22
        push = 0.0
        sx = x * w
        # The nose: long and thin, down from the brow.
        push += 0.032 * front ** 6 * smooth(0.048, 0.062, y) * smooth(0.106, 0.075, y) * smooth(0.014, 0.0, abs(sx))
        push += 0.012 * front ** 6 * bump(y, 0.058, 0.012) * smooth(0.01, 0.0, abs(sx))
        # The brow over the eyes, heavy; the eyes sunk under it.
        push += 0.008 * front ** 2 * bump(y, 0.108, 0.012)
        for side in (1.0, -1.0):
            eye = smooth(0.013, 0.0, math.hypot(sx - side * 0.022, (y - 0.092) * 0.8))
            push -= 0.009 * eye * front
            # (hollow cheeks under the cheekbones)
            push -= 0.008 * smooth(0.02, 0.0, math.hypot(sx - side * 0.034, y - 0.045)) * front
        # The chin, a little out.
        push += 0.006 * front ** 3 * bump(y, 0.01, 0.015)
        r = (w * (1.0 + 0.04 * noise(a, y * 9.0, 2.0) * q), d)
        return r, push

    def colour_at(y, a, push):
        x = math.sin(a) * width(y)
        front = max(0.0, math.cos(a))
        c = mix(SKIN, SKIN_DARK, 0.4 + 0.3 * noise(a * 2.0, y * 20.0, 5.0))
        for side in (1.0, -1.0):
            c = mix(c, SOCKET, smooth(0.012, 0.004, math.hypot(x - side * 0.022, (y - 0.092) * 0.8)) * front)
        # (grey hair round the back and sides, under the hat)
        c = mix(c, BEARD_DARK, smooth(-0.2, -0.6, math.cos(a)) * smooth(0.06, 0.1, y))
        return c

    shell(b, [chin + (crown - chin) * t for t in rows], sides, radius_at, colour_at, centre_z=0.012)
    # His eyes, small and pale, deep in their sockets under the brim.
    for side in (1.0, -1.0):
        b.blob((side * 0.022, 0.092, 0.064), (0.0065, 0.0045, 0.004), EYE, 6 + 2 * q, 4)
    # Ears, long and thin, the old man's.
    for side in (1.0, -1.0):
        b.blob((side * 0.054, 0.082, 0.004), (0.008, 0.022, 0.014), SKIN_DARK, 6 + 2 * q, 4)
    # The beard: long, thin and grey, from the jaw to the middle of his chest, a moustache over it.
    rng = random.Random(7)
    locks = 8 + 8 * q
    for k in range(locks):
        u = (k / (locks - 1)) * 2.0 - 1.0
        a = u * 1.2
        root = Vector((math.sin(a) * 0.044, 0.035 - 0.022 * (1.0 - abs(u)), 0.012 + math.cos(a) * 0.05))
        long = 0.13 * (1.0 - 0.55 * abs(u) ** 1.5) * rng.uniform(0.85, 1.1)
        out = Vector((math.sin(a) * 0.5, 0.0, math.cos(a))).normalized()
        pts = []
        for t in (0.0, 0.3, 0.6, 1.0):
            p = root + Vector((0.0, -long * t, 0.0)) + out * (0.012 * math.sin(t * math.pi) + 0.006 * t)
            p.x *= 1.0 - 0.45 * t
            p.x += 0.006 * math.sin(k * 2.7 + t * 4.0) * t
            pts.append(p)
        tone = BEARD if k % 3 else BEARD_DARK
        b.strip(pts, [0.012, 0.011, 0.008, 0.002], out, lambda t, tone=tone: mix(tone, BEARD_DARK, 0.4 * t))
    # (a mass under it, so that it is not a fringe of strips from below)
    b.blob((0.0, -0.012, 0.045), (0.034, 0.05, 0.022), BEARD_DARK, 6 + 3 * q, 4 + q)
    for side in (1.0, -1.0):
        pts = [Vector((side * 0.002, 0.046, 0.076)), Vector((side * 0.02, 0.04, 0.072)), Vector((side * 0.034, 0.024, 0.064))]
        b.strip(pts, [0.006, 0.007, 0.002], Vector((0, 0.2, 1)), BEARD)
    # Wisps of grey hair at the back, over his collar.
    for k in range(5 + 3 * q):
        a = math.pi + (k / (4 + 3 * q) - 0.5) * 2.2
        root = Vector((math.sin(a) * 0.056, 0.115, 0.012 + math.cos(a) * 0.062))
        out = Vector((math.sin(a), 0.0, math.cos(a)))
        pts = [root, root + out * 0.012 + Vector((0, -0.04, 0)), root + out * 0.016 + Vector((0, -0.075, 0))]
        b.strip(pts, [0.012, 0.01, 0.003], out, BEARD_DARK)
    hat(b, q)


def hat(b, q):
    """A battered top hat, pulled down to his brows and tipped forward: the crown dented and
    leaning, a little caved at the top, the brim warped, a band of darker cloth round it."""
    sides = 12 + 10 * q
    tip = -0.16  # (forward, radians: over his eyes)
    base_y = 0.124
    pivot = Vector((0.0, base_y, 0.012))

    def put(p):
        # (tipped forward about the brim's middle, and over a little to his left)
        p = Vector(p) - pivot
        c, s = math.cos(tip), math.sin(tip)
        p = Vector((p.x, p.y * c - p.z * s, p.y * s + p.z * c))
        c2, s2 = math.cos(0.05), math.sin(0.05)
        p = Vector((p.x * c2 - p.y * s2, p.x * s2 + p.y * c2, p.z))
        return p + pivot

    height = 0.13
    rings = []
    count = 5 + 4 * q
    for j in range(count + 1):
        t = j / count
        y = base_y + height * t
        ring = []
        for s in range(sides):
            a = math.tau * s / sides
            r = 0.062 + 0.006 * t
            # (a dent in its side, and the crown leaning back a little as it goes up)
            r -= 0.009 * smooth(0.5, 0.0, abs(a - 2.2)) * bump(t, 0.6, 0.35)
            r *= 1.0 + 0.025 * noise(a * 1.5, t * 3.0, 4.0)
            p = Vector((math.sin(a) * r, y, 0.012 + math.cos(a) * r * 1.12 - 0.012 * t * t))
            tone = mix(HAT, HAT_WORN, 0.35 + 0.35 * noise(a * 3.0, t * 6.0, 1.0))
            if 0.04 < t < 0.24:
                tone = BAND
            ring.append(b.vert(put(p), tone))
        rings.append(ring)
    b.grid(rings, closed=True, flip=True)
    # The top, a little caved in.
    top_c = b.vert(put((0.0, base_y + height - 0.012, -0.0)), HAT_WORN)
    for s in range(sides):
        b.face((top_c, rings[-1][(s + 1) % sides], rings[-1][s]))
    # The brim: warped, curled up at the sides, drooping a little at the front.
    inner, outer, under_i, under_o = [], [], [], []
    for s in range(sides):
        a = math.tau * s / sides
        lift = 0.016 * abs(math.sin(a)) ** 2 - 0.006 * max(0.0, math.cos(a)) + 0.004 * noise(a * 2.0, 0.0, 8.0)
        ri, ro = 0.061, 0.104 + 0.006 * noise(a * 3.0, 1.0, 9.0)
        pi = Vector((math.sin(a) * ri, base_y + 0.002, 0.012 + math.cos(a) * ri * 1.12))
        po = Vector((math.sin(a) * ro, base_y + lift, 0.012 + math.cos(a) * ro * 1.1))
        tone = mix(HAT, HAT_WORN, 0.5 + 0.5 * noise(a * 4.0, 2.0, 3.0))
        inner.append(b.vert(put(pi), tone))
        outer.append(b.vert(put(po), tone))
        under_i.append(b.vert(put(pi - Vector((0, 0.006, 0))), BAND))
        under_o.append(b.vert(put(po - Vector((0, 0.005, 0))), BAND))
    b.grid([inner, outer], closed=True, flip=True)
    b.grid([under_i, under_o], closed=True)
    b.grid([outer, under_o], closed=True, flip=True)


# --- The coat ----------------------------------------------------------------------

def coat(b, q):
    """The long skirts of his coat, from his waist to his shins, open in front, flared and
    ragged at the hem, worn shiny along it. Hips joint space (the hips joint is a little
    below his waist). Two layers, the inside dark."""
    sides = 12 + 10 * q
    rows = 4 + 4 * q
    top_y, bottom_y = 0.1, -0.43
    gap_top, gap_bottom = 0.28, 0.6  # (half the opening in front, radians)
    outer_rows, inner_rows = [], []
    for j in range(rows + 1):
        t = j / rows
        y = top_y + (bottom_y - top_y) * t
        gap = gap_top + (gap_bottom - gap_top) * t
        rx = 0.118 + 0.075 * t ** 1.2
        rz = 0.094 + 0.07 * t ** 1.2
        orow, irow = [], []
        for s in range(sides + 1):
            a = gap + (math.tau - 2.0 * gap) * s / sides
            ragged = 0.0
            if j == rows:
                ragged = 0.03 * (noise(a * 3.0, 1.0, 6.0) * 0.5 + 0.5) + 0.012 * (s % 3 == 0)
            wave = 1.0 + 0.04 * math.sin(a * 5.0 + 1.0) * t
            p = Vector((math.sin(a) * rx * wave, y + ragged, 0.005 + math.cos(a) * rz * wave))
            tone = mix(COAT, COAT_WORN, 0.3 + 0.3 * noise(a * 2.0, t * 4.0, 2.0) + 0.4 * smooth(0.8, 1.0, t))
            orow.append(b.vert(p, tone))
            n = Vector((math.sin(a) * rz, 0.0, math.cos(a) * rx)).normalized()
            irow.append(b.vert(p - n * 0.006, LINING))
        outer_rows.append(orow)
        inner_rows.append(irow)
    b.grid(outer_rows, flip=True)
    b.grid(inner_rows)
    # (the front edges and the hem, closing the two layers)
    b.grid([[r[0] for r in outer_rows], [r[0] for r in inner_rows]])
    b.grid([[r[-1] for r in outer_rows], [r[-1] for r in inner_rows]], flip=True)
    b.grid([outer_rows[-1], inner_rows[-1]])
    # A belt of rope round the waist over it.
    ring = [Vector((math.sin(math.tau * k / 14) * 0.124, 0.09, 0.005 + math.cos(math.tau * k / 14) * 0.1)) for k in range(15)]
    b.tube(ring, [0.009] * 15, 4 + q, HAFT_DARK, cap_start=False, cap_end=False)


def collar(b, q):
    """His coat's collar turned up round his neck against the cold, open at the throat. Chest
    joint space."""
    sides = 10 + 8 * q
    gap = 0.55
    rows = []
    for j in range(3):
        t = j / 2
        y = 0.1 + 0.085 * t
        r = 0.088 - 0.012 * t
        row = []
        for s in range(sides + 1):
            a = gap + (math.tau - 2.0 * gap) * s / sides
            row.append(b.vert((math.sin(a) * r * 1.05, y + 0.012 * math.cos(a) * t, -0.008 + math.cos(a) * r * 0.95), mix(COAT, COAT_WORN, 0.5 * t)))
        rows.append(row)
    b.grid(rows, flip=True)
    inner = [[b.vert(b.verts[i] * 0.94 + Vector((0, 0.006 * 0.0, 0)), LINING) for i in row] for row in rows]
    b.grid(inner)


# --- The axe -----------------------------------------------------------------------

def axe(b, q):
    """A felling axe, long in the haft and worn dark where it is held: its grip at the origin
    (a hand's breadth up from the butt), the haft down -Z to the head, the head's edge
    towards -Y and its poll towards +Y; a nick in the edge, rust on the cheeks."""
    count = 6 + 6 * q
    pts, radii = [], []
    for k in range(count + 1):
        t = k / count
        z = 0.1 - 0.62 * t
        # (the haft's curve, and its swell at the butt)
        pts.append(Vector((0.0, -0.012 * math.sin(t * math.pi) + 0.008 * smooth(0.85, 1.0, t), z)))
        radii.append(0.0125 * (1.0 + 0.35 * smooth(0.06, 0.0, t)) * (1.0 - 0.15 * smooth(0.7, 0.95, t)))
    b.tube(pts, radii, 5 + 3 * q, lambda t, a: mix(HAFT, HAFT_DARK, smooth(0.35, 0.1, t) * 0.8 + 0.2 * noise(t * 9.0, a, 3.0)))
    # The head: a wedge from the poll (+Y) to the edge (-Y), flaring along the haft at the edge.
    z0 = -0.49
    sections = []
    for k, y in enumerate((0.032, 0.015, -0.01, -0.045, -0.08, -0.105)):
        t = k / 5
        half_z = 0.019 + 0.035 * smooth(0.35, 1.0, t)
        half_x = 0.016 * (1.0 - smooth(0.2, 1.0, t)) + 0.0015
        tone = mix(IRON, EDGE, smooth(0.8, 1.0, t))
        tone = mix(tone, RUST, 0.35 * bump(t, 0.5, 0.3))
        ring = [b.vert((half_x, y, z0 + half_z), tone), b.vert((half_x, y, z0 - half_z), tone),
                b.vert((-half_x, y, z0 - half_z), tone), b.vert((-half_x, y, z0 + half_z), tone)]
        sections.append(ring)
    b.grid(sections, closed=True, flat=True)
    for ring, flip in ((sections[0], False), (sections[-1], True)):
        quad = (ring[0], ring[1], ring[2], ring[3])
        b.face(tuple(reversed(quad)) if flip else quad, True)


# --- The lantern -------------------------------------------------------------------

def lantern(b, q):
    """An oil lantern (a hurricane lamp) of dark tin: the top of its wire bail at the origin, the
    lantern hanging under it; a chimney cap, a guard of wires round the glass, the fount
    beneath. The glass is `lantern_glass`."""
    sides = 8 + 6 * q
    # The bail: a loop of wire from one side of the cap over to the other.
    arc = [Vector((math.sin(a) * 0.036, -0.058 + math.cos(a) * 0.058, 0.0)) for a in [(-0.5 + k / (6 + 4 * q)) * math.pi for k in range(7 + 4 * q)]]
    b.tube(arc, [0.003] * len(arc), 4, TIN)
    # The cap and chimney.
    b.tube([Vector((0, -0.04, 0)), Vector((0, -0.05, 0)), Vector((0, -0.062, 0)), Vector((0, -0.074, 0))],
           [0.012, 0.016, 0.034, 0.04], sides, lambda t, a: mix(TIN, RUST, 0.3 * noise(a * 3.0, t, 1.0)))
    # The guard: wires round the glass, two rings.
    for k in range(4 + 2 * q):
        a = math.tau * k / (4 + 2 * q) + 0.4
        b.tube([Vector((math.sin(a) * 0.04, -0.074, math.cos(a) * 0.04)), Vector((math.sin(a) * 0.043, -0.125, math.cos(a) * 0.043)),
                Vector((math.sin(a) * 0.04, -0.172, math.cos(a) * 0.04))], [0.0028] * 3, 4, TIN)
    for y in (-0.1, -0.15):
        ring = [Vector((math.sin(math.tau * k / sides) * 0.0425, y, math.cos(math.tau * k / sides) * 0.0425)) for k in range(sides + 1)]
        b.tube(ring, [0.0025] * (sides + 1), 3, TIN, cap_start=False, cap_end=False)
    # The fount (the oil) and its foot.
    b.tube([Vector((0, -0.172, 0)), Vector((0, -0.178, 0)), Vector((0, -0.2, 0)), Vector((0, -0.205, 0))],
           [0.034, 0.046, 0.046, 0.04], sides, lambda t, a: mix(TIN, RUST, 0.4 * noise(a * 2.0, t * 3.0, 4.0)))


def lantern_glass(b, q):
    """The lantern's glass globe, swelling in the middle (the game lights it, from within)."""
    sides = 8 + 6 * q
    pts = [Vector((0, -0.074, 0)), Vector((0, -0.095, 0)), Vector((0, -0.125, 0)), Vector((0, -0.155, 0)), Vector((0, -0.172, 0))]
    b.tube(pts, [0.024, 0.033, 0.037, 0.033, 0.026], sides, GLASS)


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


PARTS = [("head", head), ("coat", coat), ("collar", collar), ("axe", axe), ("lantern", lantern), ("lantern_glass", lantern_glass)]


def build(q, suffix):
    clear()
    made = []
    for name, fn in PARTS:
        b = Builder()
        fn(b, q)
        made.append(b.build(name, mat=material("glass" if name == "lantern_glass" else "woodsman")))
    export(made, os.path.join(MODELS, "woodsman%s.glb" % suffix))
    for obj in made:
        print("  %s: %d triangles" % (obj.name, sum(len(p.vertices) - 2 for p in obj.data.polygons)))


def previews(folder):
    """Renders the parts in Workbench, with their vertex colours, for a quick look."""
    clear()
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    for k, (name, fn) in enumerate(PARTS):
        b = Builder()
        fn(b, 2)
        obj = b.build(name)
        obj.location = ((k - 2.5) * 0.32, 0.0, 0.0)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, at, rot in (("front", (0.0, -2.6, 0.0), (math.radians(90), 0, 0)), ("quarter", (1.6, -2.0, 0.4), (math.radians(82), 0, math.radians(38)))):
        cam.location = at
        cam.rotation_euler = rot
        cam_data.lens = 50
        scene.render.filepath = os.path.join(folder, "woodsman_%s.png" % name)
        bpy.ops.render.render(write_still=True)
    # The head close to.
    clear()
    b = Builder()
    head(b, 2)
    b.build("head")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, at, rot in (("head_front", (0.0, -0.75, 0.09), (math.radians(90), 0, 0)), ("head_side", (0.65, -0.4, 0.1), (math.radians(88), 0, math.radians(58)))):
        cam.location = at
        cam.rotation_euler = rot
        scene.render.filepath = os.path.join(folder, "woodsman_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(MODELS, exist_ok=True)
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(2, "")
    build(0, "_lo")
    if args:
        previews(args[0])


if __name__ == "__main__":
    main()
