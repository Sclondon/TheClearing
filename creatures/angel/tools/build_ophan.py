"""Builds the parts of the ophan (the "biblically accurate" angel) and exports them for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/angel/tools/build_ophan.py [-- <folder for preview renders>]

Writes creatures/angel/models/ophan.glb, which holds four meshes, each a part
that Ophan (creatures/angel/ophan.gd) draws many times over as a MultiMesh:

- Eyeball: one eye, radius 1, looking down +Z, with the clear dome of its
  cornea standing proud of the white. Its rings of vertices run round the
  front pole, so that the shader, which paints the iris, the pupil, the
  limbus and the veins from where each point lies (no texture), has them
  round and even.
- Lids: the upper and lower lid round that eye, a shell of skin with a
  rounded wet margin and a crease above, leaving an almond-shaped opening;
  with a fringe of lashes on both. UV2.x says what a vertex is (1 the upper
  lid, 2 the lower, 3 an upper lash, 4 a lower lash), UV2.y how far (radians,
  about the eye's X axis) it turns when the eye is shut, so that the shader
  can blink it: each lid closes over the eye as a sheet that stretches, its
  margin travelling furthest, its far edge not at all. UV.x is how far from the
  margin a point is (0 at it), for its colour.
- Ring: a wheel's rim, the middle of it radius 1, its axis Y: a high band
  with beaded lips, a channel round its outside in which SEATS raised bezels
  hold the eyes, small studs between them, fine grooves along both faces,
  and ribs inside. (The eyes are not in it: Ophan seats them, at `seat(k)`.)
- Wing: a seraph's wing, open, in its own plane: from the shoulder at the
  origin the arm runs out along +X, the feathers hang towards -Y, and its
  outer face looks +Z. Ten primaries off the hand (the outer ones notched),
  twelve secondaries off the forearm, tertials, scapulars, rows of greater,
  median and lesser coverts shingled over their roots, an alula at the
  wrist, and the bar of the arm along the leading edge. Each feather is a
  cambered blade with a raised shaft (UV: x -1..1 across it, 0 the shaft;
  y 0 at the root, 1 at the tip). UV2.x is which bone carries it (0 the arm,
  1 the forearm, 2 the hand; the bar blends between them at the joints), UV2.y
  its row (0 flight feathers .. 4 lesser coverts), so the shader can fold the
  wing at its elbow and wrist (ELBOW and WRIST below, which Ophan keeps a copy
  of) and colour the rows.

All coordinates are in Godot space (Y up), converted on the way into Blender.
glTF flips V, so every UV is written as (u, 1 - v) to come out as (u, v).
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "creatures", "angel", "models", "ophan.glb")

# How many eyes each ring holds.
SEATS = 16
# The eye in the ring: its radius and how far out from the ring's middle line its centre is.
EYE = 0.08
EYE_OUT = 1.012
# The wing's joints (Godot space, the wing's own plane).
SHOULDER = Vector((0.0, 0.0, 0.0))
ELBOW = Vector((0.3, 0.035, 0.0))
WRIST = Vector((0.58, 0.0, 0.0))
HAND = Vector((0.7, -0.02, 0.0))


def B(p):
    """Godot (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def clear():
    for thing in list(bpy.data.objects):
        bpy.data.objects.remove(thing, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def material(name, colour):
    made = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    made.diffuse_color = (*colour, 1.0)
    made.use_nodes = True
    node = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    node.inputs[0].default_value = (*colour, 1.0)
    return made


class Builder:
    """A mesh being made: vertices in Godot space, each with a UV and a UV2."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.uv2 = self.bm.loops.layers.uv.new("UV2")
        self.data = {}

    def vert(self, p, uv=(0.0, 0.0), uv2=(0.0, 0.0)):
        v = self.bm.verts.new(B(p))
        self.data[v] = (uv, uv2)
        return v

    def face(self, verts, smooth=True):
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.smooth = smooth
        for loop in f.loops:
            uv, uv2 = self.data[loop.vert]
            loop[self.uv].uv = (uv[0], 1.0 - uv[1])
            loop[self.uv2].uv = (uv2[0], 1.0 - uv2[1])
        return f

    def grid(self, rows, closed=False, flip=False):
        """Quads between rows of vertices (each row a list, all as long)."""
        for i in range(len(rows) - 1):
            a, b = rows[i], rows[i + 1]
            n = len(a) if closed else len(a) - 1
            for j in range(n):
                k = (j + 1) % len(a)
                quad = [a[j], a[k], b[k], b[j]]
                self.face(list(reversed(quad)) if flip else quad)

    def object(self, name, colour):
        mesh = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(mesh)
        self.bm.free()
        thing = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(thing)
        thing.data.materials.append(material(name.lower(), colour))
        return thing


# --- The eye ---------------------------------------------------------------

def eyeball():
    made = Builder()
    rings = 11
    segments = 20
    cornea = 0.6

    def radius(theta):
        bump = max(0.0, 1.0 - (theta / cornea) ** 2)
        # (the dome of the cornea, with a faint crease where it meets the white)
        crease = math.exp(-((theta - cornea) / 0.06) ** 2) * 0.006
        return 1.0 + 0.085 * bump ** 1.6 - crease

    front = made.vert((0.0, 0.0, radius(0.0)), (0.0, 0.0))
    rows = []
    for i in range(1, rings):
        theta = math.pi * (i / rings) ** 1.25
        r = radius(theta)
        row = []
        for j in range(segments):
            phi = math.tau * j / segments
            row.append(made.vert((r * math.sin(theta) * math.cos(phi), r * math.sin(theta) * math.sin(phi), r * math.cos(theta)), (theta, phi)))
        rows.append(row)
    back = made.vert((0.0, 0.0, -1.0), (math.pi, 0.0))
    for j in range(segments):
        made.face([front, rows[0][j], rows[0][(j + 1) % segments]])
    made.grid(rows, closed=True)
    for j in range(segments):
        made.face([back, rows[-1][(j + 1) % segments], rows[-1][j]])
    bmesh.ops.recalc_face_normals(made.bm, faces=made.bm.faces)
    return made.object("Eyeball", (0.92, 0.9, 0.86))


def lids():
    """The two lids as shells about the eye's X axis: a point at lateral angle
    `beta` and angle `alpha` round X (0 straight ahead, + up) on a sphere of
    radius r is (r sin b, r cos b sin a, r cos b cos a)."""
    made = Builder()
    corner = math.radians(74.0)
    spread = math.radians(86.0)

    def rim(beta, upper):
        # the almond: highest a little towards the inner corner for the upper lid
        top = math.radians(50.0) if upper else math.radians(36.0)
        skew = math.radians(9.0) if upper else math.radians(-6.0)
        x = (beta - skew) / (corner - abs(skew) * (1 if (beta - skew) * skew > 0 else -1))
        x = max(-1.0, min(1.0, (beta - skew) / corner))
        return top * max(0.0, 1.0 - x * x) ** 0.75 + math.radians(1.5)

    def at(beta, alpha, r):
        return (r * math.sin(beta), r * math.cos(beta) * math.sin(alpha), r * math.cos(beta) * math.cos(alpha))

    # (t: from the margin (0) to the far edge (1); r: the radius there). The
    # first few run in under the margin, on the inside, against the eye.
    upper_profile = [(-0.22, 1.012), (-0.05, 1.018), (-0.012, 1.028), (0.0, 1.042), (0.008, 1.058), (0.03, 1.07), (0.09, 1.078),
                     (0.2, 1.082), (0.3, 1.074), (0.36, 1.086), (0.5, 1.1), (0.75, 1.1), (1.0, 1.085)]
    lower_profile = [(-0.22, 1.012), (-0.05, 1.018), (-0.012, 1.026), (0.0, 1.038), (0.01, 1.052), (0.04, 1.062), (0.12, 1.068),
                     (0.3, 1.075), (0.6, 1.078), (1.0, 1.07)]
    columns = 13
    lash_rows = {}
    for upper in (True, False):
        side = 1.0 if upper else 2.0
        far = math.radians(150.0)
        profile = upper_profile if upper else lower_profile
        rows = []
        margins = []
        for t, r in profile:
            row = []
            for j in range(columns):
                s = -1.0 + 2.0 * j / (columns - 1)
                beta = spread * math.copysign(abs(s) ** 0.85, s)
                edge = rim(beta, upper) if upper else rim(beta, False)
                other = rim(beta, not upper)
                # how far the margin travels to shut the eye (upper lid most)
                close = (edge + other) * (0.82 if upper else 0.2)
                alpha = edge + max(t, 0.0) * (far - edge) + min(t, 0.0) * 0.6
                # (under the margin, it lies just inside it)
                if t < 0.0:
                    alpha = edge + t * 0.5
                move = close * (1.0 - smoothstep(0.0, 0.7, max(t, 0.0)))
                sign = 1.0 if upper else -1.0
                # the lid hugs the eye less at the corners
                row.append(made.vert(at(beta, sign * alpha, r * (1.0 if upper else 0.998)), (max(t, 0.0), s), (side, move)))
            rows.append(row)
            if t == 0.008 or (not upper and t == 0.01):
                margins = row
        made.grid(rows, flip=not upper)
        lash_rows[upper] = (rows, margins)

    # Lashes: thin tapered blades from the outer edge of each margin, curling out and away.
    rnd = random.Random(3)
    for upper in (True, False):
        rows, _ = lash_rows[upper]
        margin = rows[4]
        count = 26 if upper else 14
        for k in range(count):
            s = -0.82 + 1.64 * (k + 0.5) / count
            j = (s + 1.0) * 0.5 * (columns - 1)
            j0 = int(j)
            f = j - j0
            v0 = margin[j0]
            v1 = margin[min(j0 + 1, columns - 1)]
            base = (v0.co.lerp(v1.co, f))
            gbase = Vector((base.x, base.z, -base.y))
            uv2_move = made.data[v0][1][1] * (1 - f) + made.data[v1][1][1] * f
            out = gbase.normalized()
            up = Vector((0.0, 1.0 if upper else -1.0, 0.0))
            length = (0.22 if upper else 0.12) * (1.0 - 0.55 * abs(s) ** 2) * rnd.uniform(0.8, 1.1)
            way = (out * 0.75 + up * 0.65).normalized()
            tip = gbase + way * length + up * length * 0.25
            side = Vector((1.0, 0.0, 0.0)) * 0.012
            kind = 3.0 if upper else 4.0
            a = made.vert(gbase - side, (0.0, 0.0), (kind, uv2_move))
            b = made.vert(gbase + side, (0.0, 0.0), (kind, uv2_move))
            mid = gbase + way * length * 0.55 + up * length * 0.05
            c = made.vert(mid + side * 0.5, (0.0, 0.6), (kind, uv2_move))
            d = made.vert(mid - side * 0.5, (0.0, 0.6), (kind, uv2_move))
            e = made.vert(tip, (0.0, 1.0), (kind, uv2_move))
            made.face([a, b, c, d])
            made.face([d, c, e])
    return made.object("Lids", (0.78, 0.6, 0.52))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


# --- The ring --------------------------------------------------------------

def seat_angle(k):
    return math.tau * k / SEATS


def ring():
    made = Builder()
    # Half the profile (radius, height), from the middle of the outside channel up and round to the middle of the inside.
    half = [
        (1.0, 0.0), (1.0, 0.03), (1.004, 0.052), (1.016, 0.058),
        (1.03, 0.06), (1.044, 0.064), (1.05, 0.072), (1.046, 0.08), (1.034, 0.085),   # the beaded lip
        (1.02, 0.086), (1.006, 0.086), (1.003, 0.081), (0.996, 0.081), (0.993, 0.086),  # a groove along the side
        (0.982, 0.086), (0.98, 0.081), (0.975, 0.081), (0.972, 0.086),                  # and another
        (0.962, 0.085), (0.954, 0.078), (0.951, 0.068),                                 # the inner edge
        (0.951, 0.05), (0.946, 0.044), (0.946, 0.032), (0.951, 0.026), (0.951, 0.012), (0.948, 0.0),
    ]
    half = [(r, y * 1.38) for r, y in half]
    profile = half + [(r, -y) for r, y in reversed(half[1:-1])]
    segments = 96
    rows = []
    for i in range(segments):
        a = math.tau * i / segments
        row = []
        for k, (r, y) in enumerate(profile):
            row.append(made.vert((r * math.cos(a), y, r * math.sin(a)), (k / len(profile), i / segments), (0.0, 0.0)))
        rows.append(row)
    rows.append(rows[0])
    made.grid(rows, closed=True, flip=True)

    def frame(k):
        a = seat_angle(k)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        along = Vector((-math.sin(a), 0.0, math.cos(a)))
        return out, along, Vector((0.0, 1.0, 0.0))

    # The bezels: a raised, rounded collar round each eye, standing out of the channel.
    for k in range(SEATS):
        out, along, up = frame(k)
        centre = out * 1.0
        tube = [(EYE * 1.06, 0.02), (EYE * 1.12, 0.066), (EYE * 1.24, 0.084), (EYE * 1.4, 0.076), (EYE * 1.55, 0.05), (EYE * 1.64, 0.016), (EYE * 1.66, -0.012)]
        rows = []
        n = 16
        for i in range(n):
            a = math.tau * i / n
            dir2 = along * math.cos(a) + up * math.sin(a)
            row = []
            for j, (r, h) in enumerate(tube):
                # (squeezed across the band, so it fits within the lips)
                squeeze = 1.0 - 0.18 * abs(math.sin(a))
                row.append(made.vert(centre + dir2 * r * squeeze + out * h, (j / len(tube), 0.5), (1.0, 0.0)))
            rows.append(row)
        rows.append(rows[0])
        made.grid(rows, flip=False)

    # Studs between the eyes: a small four-sided boss with a point.
    for k in range(SEATS):
        a = seat_angle(k + 0.5)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        along = Vector((-math.sin(a), 0.0, math.cos(a)))
        up = Vector((0.0, 1.0, 0.0))
        base = out * 1.0
        tip = made.vert(base + out * 0.028, (1.0, 0.5), (2.0, 0.0))
        corners = []
        for d in (along * 0.026, up * 0.03, -along * 0.026, -up * 0.03):
            corners.append(made.vert(base + d + out * 0.004, (0.0, 0.5), (2.0, 0.0)))
        mids = []
        for i in range(4):
            mid = (Vector(B_to_g(corners[i].co)) + Vector(B_to_g(corners[(i + 1) % 4].co))) * 0.5
            mids.append(made.vert(mid * 0.0 + base + (mid - base) * 0.55 + out * 0.017, (0.5, 0.5), (2.0, 0.0)))
        for i in range(4):
            made.face([corners[i], corners[(i + 1) % 4], mids[i]], smooth=False)
            made.face([mids[i], corners[(i + 1) % 4], tip], smooth=False)
            made.face([corners[i], mids[i], tip], smooth=False)

    # Ribs across the inside, every few degrees.
    for k in range(SEATS * 2):
        a = seat_angle(k * 0.5 + 0.25)
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        along = Vector((-math.sin(a), 0.0, math.cos(a)))
        quad = []
        for y in (-0.07, 0.07):
            for s in (-1, 1):
                quad.append(made.vert(out * 0.948 + Vector((0.0, y, 0.0)) + along * 0.006 * s - out * 0.008, (0.0, 0.0), (3.0, 0.0)))
        back = []
        for y in (-0.07, 0.07):
            for s in (-1, 1):
                back.append(made.vert(out * 0.951 + Vector((0.0, y, 0.0)) + along * 0.009 * s, (0.0, 0.0), (3.0, 0.0)))
        made.face([quad[0], quad[1], quad[3], quad[2]], smooth=False)
        made.face([back[0], quad[0], quad[2], back[2]], smooth=False)
        made.face([quad[1], back[1], back[3], quad[3]], smooth=False)
    return made.object("Ring", (0.85, 0.7, 0.42))


def B_to_g(v):
    return (v.x, v.z, -v.y)


# --- The wing --------------------------------------------------------------

def chain_at(x):
    """Which bone carries a point that far out along the arm (blended at the joints)."""
    return smoothstep(ELBOW.x - 0.03, ELBOW.x + 0.03, x) + smoothstep(WRIST.x - 0.03, WRIST.x + 0.03, x)


def wing():
    made = Builder()
    rnd = random.Random(7)
    layer_lift = 0.006

    def feather(root, angle, length, width, tier, chain, outer=0.4, curve=0.06, notch=0.0, round_tip=0.5, lift=0.0):
        d = Vector((math.cos(angle), math.sin(angle), 0.0))
        # (outward: the side of the feather towards the wing tip, +X-ish)
        o = Vector((d.y, -d.x, 0.0))
        if o.x < 0.0:
            o = -o
        rows = []
        steps = 7 if length > 0.12 else 4
        for i in range(steps + 1):
            s = 1.0 - (1.0 - i / steps) ** 1.5
            # the width along it: a quill, the vanes widening, a rounded or pointed tip
            w = width * smoothstep(0.0, 0.2, s) * (max(0.0, 1.0 - ((max(s, 0.3) - 0.3) / 0.7) ** (2.0 + 4.0 * round_tip))) ** 0.5
            w = max(w, width * 0.06 * (1.0 - s), width * 0.4 * round_tip * smoothstep(0.6, 1.0, s) * (1.0 - s ** 8) + width * 0.18 * round_tip * (s >= 1.0))
            inner_w = w * (1.0 - outer)
            outer_w = w * outer
            if notch > 0.0:
                # (the outer primaries narrow sharply part way out: their emarginations)
                inner_w *= 1.0 - notch * smoothstep(0.45, 0.6, s)
                outer_w *= 1.0 - notch * 0.6 * smoothstep(0.5, 0.62, s)
            shaft = root + d * length * s - o * curve * length * s * s
            z = lift + 0.012 * length * math.sin(math.pi * s)
            camber = 0.18 * w
            row = [
                made.vert(shaft - o * inner_w + Vector((0, 0, z - camber)), (-1.0, s), (chain, tier / 10.0)),
                made.vert(shaft + Vector((0, 0, z + 0.004 * length)), (0.0, s), (chain, tier / 10.0)),
                made.vert(shaft + o * outer_w + Vector((0, 0, z - camber * 0.6)), (1.0, s), (chain, tier / 10.0)),
            ]
            rows.append(row)
        made.grid(rows, flip=True)

    def row_code(row):
        return row / 10.0

    def along(a, b, t):
        return a.lerp(b, t)

    # Primaries, off the hand: P1 (inner) to P10 (outer), fanning from down to out.
    count = 10
    for k in range(count):
        t = k / (count - 1)
        root = along(WRIST, HAND, t) + Vector((0.0, -0.01, 0.0))
        angle = math.radians(-84.0 + 74.0 * t ** 1.15)
        length = 0.38 + 0.19 * math.sin(math.pi * 0.5 * min(t / 0.8, 1.0)) - (0.05 if k == count - 1 else 0.0)
        feather(root, angle, length * rnd.uniform(0.98, 1.02), 0.072 - 0.012 * t, 0, 2.0, outer=0.3 - 0.1 * t, curve=0.07,
                notch=0.45 if k >= 6 else 0.0, round_tip=0.3, lift=-0.0008 * k)
    # Secondaries, off the forearm: S1 at the wrist in to the elbow.
    count = 12
    for k in range(count):
        t = k / (count - 1)
        root = along(WRIST, ELBOW, t) + Vector((0.0, -0.012, 0.0))
        angle = math.radians(-88.0 - 10.0 * t)
        feather(root, angle, (0.33 - 0.02 * t) * rnd.uniform(0.97, 1.03), 0.074, 0, chain_at(root.x), outer=0.42, curve=-0.02,
                round_tip=0.8, lift=0.0008 * k)
    # Tertials, by the elbow, and scapulars over the arm.
    for k in range(4):
        root = along(ELBOW, SHOULDER, 0.08 + k * 0.17) + Vector((0.0, -0.005, 0.0))
        feather(root, math.radians(-102.0 - 6.0 * k), 0.3 - 0.035 * k, 0.07, 0, 0.0, outer=0.45, curve=-0.03, round_tip=0.9, lift=0.002 + 0.001 * k)
    for k in range(6):
        root = along(ELBOW, SHOULDER, 0.05 + k * 0.17) + Vector((0.0, 0.01, 0.0))
        feather(root, math.radians(-112.0 - 4.0 * k), 0.2 - 0.015 * k, 0.06, 1, 0.0, outer=0.5, curve=-0.03, round_tip=0.9, lift=layer_lift * 1.5 + 0.001 * k)
    # Greater coverts over the roots of the flight feathers.
    count = 18
    for k in range(count):
        t = k / (count - 1)
        if t < 0.35:
            root = along(HAND, WRIST, t / 0.35) + Vector((0.0, 0.012, 0.0))
            angle = math.radians(-50.0 + 40.0 * (1.0 - t / 0.35)) if t < 0.2 else math.radians(-75.0)
            angle = math.radians(-82.0 + 60.0 * (1.0 - t / 0.35) ** 1.5)
        else:
            root = along(WRIST, ELBOW, (t - 0.35) / 0.65) + Vector((0.0, 0.012, 0.0))
            angle = math.radians(-92.0 - 8.0 * (t - 0.35) / 0.65)
        feather(root, angle, 0.15 * rnd.uniform(0.95, 1.05), 0.05, 2, chain_at(root.x), outer=0.45, curve=-0.01, round_tip=0.9,
                lift=layer_lift * 2 + 0.0006 * k)
    # Median coverts.
    count = 22
    for k in range(count):
        t = k / (count - 1)
        root = along(HAND, ELBOW, t) + Vector((0.0, 0.028, 0.0)) if t > 0.0 else HAND + Vector((0.0, 0.028, 0.0))
        angle = math.radians(-95.0 + 35.0 * max(0.0, 1.0 - t / 0.3))
        feather(root, angle, 0.085 * rnd.uniform(0.92, 1.08), 0.036, 3, chain_at(root.x), outer=0.5, curve=0.0, round_tip=1.0,
                lift=layer_lift * 3 + 0.0005 * k)
    # Lesser coverts, small and many, in three rows along the leading edge.
    for line in range(3):
        count = 26 - line * 3
        for k in range(count):
            t = k / (count - 1)
            if t < 0.45:
                root = along(SHOULDER, ELBOW, t / 0.45)
            elif t < 0.85:
                root = along(ELBOW, WRIST, (t - 0.45) / 0.4)
            else:
                root = along(WRIST, HAND, (t - 0.85) / 0.15)
            root = root + Vector((rnd.uniform(-0.006, 0.006), 0.04 - line * 0.011, 0.0))
            feather(root, math.radians(-98.0 + rnd.uniform(-6, 6)), (0.05 + 0.01 * line) * rnd.uniform(0.9, 1.1), 0.03, 4,
                    chain_at(root.x), outer=0.5, curve=0.0, round_tip=1.0, lift=layer_lift * (4.6 - line * 0.35) + 0.0004 * k)
    # The alula, at the wrist.
    for k in range(3):
        feather(WRIST + Vector((0.0, 0.03 - 0.008 * k, 0.0)), math.radians(-12.0 - 10.0 * k), 0.13 - 0.025 * k, 0.03, 3, 2.0,
                outer=0.25, curve=0.05, round_tip=0.3, lift=layer_lift * 5 + 0.001 * k)

    # The bar of the arm: a flattened tube along the leading edge.
    points = [SHOULDER + Vector((-0.03, 0.0, 0.0))]
    for t in range(1, 13):
        points.append(along(SHOULDER, ELBOW, t / 12.0))
    for t in range(1, 11):
        points.append(along(ELBOW, WRIST, t / 10.0))
    for t in range(1, 6):
        points.append(along(WRIST, HAND, t / 5.0))
    points.append(HAND + (HAND - WRIST).normalized() * 0.04)
    rows = []
    n = 8
    for i, p in enumerate(points):
        if i == 0:
            d = (points[1] - points[0]).normalized()
        else:
            d = (p - points[i - 1]).normalized()
        side = Vector((-d.y, d.x, 0.0))
        t = i / (len(points) - 1)
        r = 0.032 * (1.0 - 0.5 * t)
        if i == len(points) - 1:
            r *= 0.3
        row = []
        for j in range(n):
            a = math.tau * j / n
            row.append(made.vert(p + Vector((0.0, 0.025, 0.0)) * (1.0 - t * 0.6) + side * math.cos(a) * r * 0.8 + Vector((0, 0, 1)) * math.sin(a) * r * 0.6 + Vector((0, 0, layer_lift * 3)),
                                 (0.0, 0.0), (chain_at(p.x), 0.5)))
        rows.append(row)
    made.grid(rows, closed=True, flip=True)
    return made.object("Wing", (0.93, 0.9, 0.82))


def preview(folder):
    """Workbench renders of each part, to look at."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    for thing in [o for o in bpy.data.objects if o.type == "MESH"]:
        for other in bpy.data.objects:
            if other.type == "MESH":
                other.hide_render = other != thing
        size = max(thing.dimensions)
        centre = sum((thing.matrix_world @ Vector(c) for c in thing.bound_box), Vector()) / 8.0
        for view, offset in (("front", Vector((0.0, -1.0, 0.0))), ("side", Vector((1.0, -0.5, 0.4))), ("back", Vector((0.0, 1.0, 0.0)))):
            cam.location = centre + offset.normalized() * size * 2.0
            direction = centre - cam.location
            cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(folder, "%s_%s.png" % (thing.name, view))
            bpy.ops.render.render(write_still=True)
    for other in bpy.data.objects:
        other.hide_render = False


def main():
    clear()
    made = [eyeball(), lids(), ring(), wing()]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for thing in made:
        thing.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False, use_selection=True,
                              export_texcoords=True, export_normals=True)
    for thing in made:
        tris = sum(len(p.vertices) - 2 for p in thing.data.polygons)
        print("BUILT %s: %d triangles, %s" % (thing.name, tris, tuple(round(d, 3) for d in thing.dimensions)))
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv:
        os.makedirs(argv[0], exist_ok=True)
        preview(argv[0])


main()
