"""Builds the mushrooms (creatures/mushrooms/) and the growths of the mushroom zombies, and exports them for Godot.

Run from the game's root:
    blender --background --python creatures/mushrooms/tools/build_mushrooms.py
then, so that Godot takes up the new models:
    godot --headless --path . --import

Writes creatures/mushrooms/models/mushrooms.glb and mushrooms_lo.glb (the kinds a patch is made of, each drawn as a
MultiMesh by MushroomPatch) and growths.glb and growths_lo.glb (what bursts out of a zombie, MushroomZombie). In
metres, real size (the game makes them as big as it likes), in the game's own directions (x to its left, y up, z the
way it faces), turned to Blender's as they are made.

    honey      One honey fungus (Armillaria): a honey-brown cap, darker in the middle, cream gills under it, a pale
               stem with a ring on it, darker to its foot. They grow in tufts (the game puts them so).
    bracket    A bracket fungus, a shelf growing out of a wall (+z out of it, its back flat on the wall at z 0):
               banded in browns and ochres, a cream rim, pale pores underneath.
    stalk      A tall pale stem with a small bell of a cap (after the bonnets, Mycena), the kind that glows.
    puffball   A giant puffball: a white-grey ball, warty, a dark pore at its top that the spores come out of.

    crown      Bursting out of the top of a head (the head's joint at the origin, its top 0.23 up): a lumpy fruiting
               mass and a spray of stalked caps of all sizes splaying up and out, and shelves out of one temple.
    shoulder   A clump of small caps and a shelf, out of a shoulder (the origin on the shoulder's top, +x outward).
    back       Shelves in a row down the spine and a few stalked caps, out of the back (the origin at the chest's
               joint, the back's surface at z -0.09).
    mat        A mat of mycelium: a lumpy white felt with threads off it, to lie on the skin (+y its outside, the
               threads running off towards -z).

Every point carries a colour (its vertex colour) and a UV: x how far it glows in the dark (the gills and the bonnets'
caps), y how high up it is on what it is part of (0 at its foot, 1 at its top), which the game squashes and sways.
"""

import math
import os
import random
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)


# --- Little sums, in the game's directions ---

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
    return times(a, 1.0 / size) if size > 1e-9 else (0.0, 1.0, 0.0)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(a, b, t):
    t = min(max((t - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def turn_y(p, angle):
    c, s = math.cos(angle), math.sin(angle)
    return (p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c)


def turn_x(p, angle):
    c, s = math.cos(angle), math.sin(angle)
    return (p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c)


def turn_z(p, angle):
    c, s = math.cos(angle), math.sin(angle)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])


def linear(srgb):
    """A colour as it is seen (sRGB), as it is stored (linear)."""
    def one(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (one(srgb[0]), one(srgb[1]), one(srgb[2]))


def to_blender(p):
    return (p[0], -p[2], p[1])


class Shape:
    """Faces being gathered: each a list of corners (point, colour, uv, uv2). Corners of one `part` that lie together
    are one point (so it is smooth there); parts are kept apart (so they are not)."""

    def __init__(self):
        self.faces = []
        self.part = 0

    def new_part(self):
        self.part += 1

    def face(self, corners):
        self.faces.append((self.part, corners))

    def both(self, corners):
        """A face seen from both sides: itself, and itself turned over (kept apart, so their normals are their own)."""
        self.faces.append((self.part, corners))
        self.faces.append((-1 - self.part, list(reversed(corners))))

    def grid(self, at, rows, columns, wrap=False, flip=False):
        """A sheet: `at(i, j)` gives the corner (point, colour, uv, uv2) at row i (0..rows), column j (0..columns)."""
        cols = columns if wrap else columns + 1
        table = [[at(i, j % columns if wrap else j) for j in range(cols)] for i in range(rows + 1)]
        for i in range(rows):
            for j in range(columns):
                a = table[i][j]
                b = table[i][(j + 1) % cols] if wrap else table[i][j + 1]
                c = table[i + 1][(j + 1) % cols] if wrap else table[i + 1][j + 1]
                d = table[i + 1][j]
                self.face([a, d, c, b] if flip else [a, b, c, d])

    def tube(self, path, radius, colour, sides=6, uv_y=None, wet=0.0, uv2=(0.0, 0.0), cap=True, flat=1.0):
        """A tube along `path` (points), `radius(t)` thick at t (0..1 along it), `colour(t)`; uv y from `uv_y(t)`."""
        self.new_part()
        n = len(path)
        frames = []
        up = (0.0, 1.0, 0.0)
        for k in range(n):
            ahead = unit(sub(path[min(k + 1, n - 1)], path[max(k - 1, 0)]))
            if abs(dot(ahead, up)) > 0.95:
                up = (1.0, 0.0, 0.0)
            side = unit(cross(ahead, up))
            top = cross(side, ahead)
            frames.append((side, top))

        def at(i, j):
            t = i / (n - 1)
            angle = math.tau * j / sides
            side, top = frames[i]
            r = radius(t)
            offset = add(times(side, math.cos(angle) * r), times(top, math.sin(angle) * r * flat))
            return (add(path[i], offset), colour(t), (wet, uv_y(t) if uv_y else 0.0), uv2)
        self.grid(at, n - 1, sides, wrap=True, flip=True)
        if cap and radius(1.0) > 1e-4:
            tip = path[-1]
            self.face([at(n - 1, j) for j in reversed(range(sides))])
        return path[-1]

    def blob(self, middle, radii, colour, around=8, rings=6, wet=0.0, uv_y=0.0, uv2=(0.0, 0.0), squash=None):
        """An egg: `colour(p)` at each point of it (p: the point on a unit sphere)."""
        self.new_part()

        def at(i, j):
            high = math.pi * (i / rings - 0.5)
            turn = math.tau * j / around
            p = (math.cos(high) * math.cos(turn), math.sin(high), math.cos(high) * math.sin(turn))
            if squash:
                p = squash(p)
            return (add(middle, (p[0] * radii[0], p[1] * radii[1], p[2] * radii[2])), colour(p), (wet, uv_y), uv2)
        self.grid(at, rings, around, wrap=True, flip=True)


def mesh_of(name, shape):
    points = []
    found = {}
    faces = []
    colours = []
    uvs = []
    uv2s = []
    for part, corners in shape.faces:
        face = []
        for point, colour, uv, uv2 in corners:
            key = (part,) + tuple(round(c, 5) for c in point)
            if key not in found:
                found[key] = len(points)
                points.append(to_blender(point))
            index = found[key]
            if index in face:
                continue
            face.append(index)
            colours.append(colour)
            uvs.append(uv)
            uv2s.append(uv2)
        if len(face) < 3:
            # (a face that came to nothing: drop what was kept for its corners)
            for _ in face:
                colours.pop()
                uvs.pop()
                uv2s.pop()
            continue
        faces.append(face)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    if len(mesh.loops) != len(colours):
        raise RuntimeError("%s: %d loops for %d corners" % (name, len(mesh.loops), len(colours)))
    mesh.uv_layers.new(name="look")
    mesh.uv_layers.new(name="bend")
    mesh.color_attributes.new(name="colour", type="FLOAT_COLOR", domain="CORNER")
    # (fetched again only now: adding a layer moves the others, and what was fetched before points nowhere)
    layer = mesh.uv_layers["look"]
    second = mesh.uv_layers["bend"]
    paint = mesh.color_attributes["colour"]
    mesh.uv_layers.active = layer
    for k in range(len(mesh.loops)):
        # (Godot's UV v runs the other way to Blender's)
        layer.data[k].uv = (uvs[k][0], 1.0 - uvs[k][1])
        second.data[k].uv = (uv2s[k][0], 1.0 - uv2s[k][1])
        c = colours[k]
        paint.data[k].color = (c[0], c[1], c[2], 1.0)
    mesh.color_attributes.active_color_name = "colour"
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("colour")
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    material = bpy.data.materials.get("plant") or bpy.data.materials.new("plant")
    mesh.materials.append(material)
    return mesh


def put(name, shape):
    made = bpy.data.objects.new(name, mesh_of(name, shape))
    bpy.context.collection.objects.link(made)
    made.data.calc_loop_triangles()
    return len(made.data.loop_triangles)


def export(filename):
    os.makedirs(os.path.join(COMPONENT, "models"), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(COMPONENT, "models", filename),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_normals=True,
        export_texcoords=True,
    )


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# --- The mushrooms ---

HONEY_CAP = linear((0.62, 0.54, 0.42))
HONEY_DARK = linear((0.48, 0.38, 0.26))
GILLS = linear((0.78, 0.72, 0.6))
STEM = linear((0.72, 0.68, 0.58))
STEM_FOOT = linear((0.46, 0.4, 0.32))
BRACKET_BANDS = [linear(c) for c in ((0.44, 0.38, 0.3), (0.58, 0.5, 0.36), (0.5, 0.44, 0.34), (0.66, 0.6, 0.46), (0.54, 0.47, 0.35))]
BRACKET_RIM = linear((0.8, 0.74, 0.6))
PORES = linear((0.76, 0.7, 0.58))
BONNET = linear((0.72, 0.74, 0.7))
PUFF = linear((0.8, 0.78, 0.72))
PUFF_DARK = linear((0.42, 0.38, 0.32))
PALE = linear((0.82, 0.8, 0.74))
ROT = linear((0.5, 0.46, 0.38))


def revolve(shape, profile, colour, glow, around, place, flip=False, uv_y=1.0):
    """A surface turned round y: `profile` a list of (radius, height); `colour(k)` and `glow(k)` for point k of it.
    Every point is moved by `place`."""
    shape.new_part()

    def at(i, j):
        r, h = profile[i]
        a = math.tau * j / around
        p = (math.sin(a) * r, h, math.cos(a) * r)
        return (place(p), colour(i), (glow(i), uv_y), (0.0, 0.0))
    shape.grid(at, len(profile) - 1, around, wrap=True, flip=flip)


def mushroom(shape, lo, cap_r, cap_h, stem_h, stem_r, cap_colour, dark, gills, stem, foot, glow_cap=0.0, glow_gills=0.0,
             ring=True, bell=False, lean=(0.0, 0.0), place=None):
    """One mushroom, its foot at the origin (or where `place` puts it): a stem, a ring, a cap and gills."""
    place = place or (lambda p: p)
    around = 6 if lo else 10
    segments = 3 if lo else 5
    # The stem: a slight curve, thicker at its foot
    path = []
    for k in range(segments + 1):
        t = k / segments
        path.append((lean[0] * t * t * stem_h, stem_h * t, lean[1] * t * t * stem_h))
    top = path[-1]
    shape.tube([place(p) for p in path], lambda t: stem_r * (1.25 - 0.35 * t), lambda t: mix(foot, stem, smooth(0.0, 0.5, t)),
               sides=5 if lo else 7, uv_y=lambda t: t * 0.75, cap=False)
    if ring and not lo:
        ring_at = mix(path[-2], top, 0.3)
        shape.tube([place(add(ring_at, (0.0, -0.004, 0.0))), place(add(ring_at, (0.0, -0.012, 0.0)))],
                   lambda t: stem_r * (1.7 + 0.5 * t), lambda t: PALE, sides=7, cap=False, uv_y=lambda t: 0.7)
    # The cap, over the top of the stem: its top, and the gills under it
    rings = 3 if lo else 6
    upper = []
    under = []
    for k in range(rings + 1):
        t = k / rings
        r = cap_r * t
        h = cap_h * (1.0 - t ** 1.6) if bell else cap_h * ((1.0 - t * t) * 0.8 + 0.2 * (1.0 - t))
        upper.append((r, h))
        under.append((max(r, stem_r), -cap_h * 0.15 * (1.0 - t)))

    def on_top(p):
        return place(add(top, p))
    revolve(shape, upper, lambda k: mix(dark, cap_colour, smooth(0.0, 0.8, k / rings)), lambda k: glow_cap, around, on_top, flip=True)
    revolve(shape, under, lambda k: gills, lambda k: glow_gills, around, on_top, uv_y=0.95)
    return top


def bracket(shape, lo, width=0.25, out=0.2, thick=0.05, place=None, bands=None):
    """A shelf: its back on the wall (z 0), half a disc out from it along +z, banded, pored underneath."""
    place = place or (lambda p: p)
    bands = bands or BRACKET_BANDS
    around = 7 if lo else 14
    rings = 3 if lo else 6
    shape.new_part()

    def top(i, j):
        t = i / rings
        a = math.pi * (j / around - 0.5)
        wave = 0.008 * math.sin(a * 7.0) * t
        p = (math.sin(a) * width * t, thick * (1.0 - t * t) + wave, math.cos(a) * out * t)
        band = bands[min(int(t * len(bands)), len(bands) - 1)]
        colour = mix(band, BRACKET_RIM, smooth(0.86, 1.0, t))
        return (place(p), colour, (0.0, t), (0.0, 0.0))

    def under(i, j):
        t = i / rings
        a = math.pi * (j / around - 0.5)
        wave = 0.008 * math.sin(a * 7.0) * t
        p = (math.sin(a) * width * t, wave - thick * 0.25 * (1.0 - t), math.cos(a) * out * t)
        return (place(p), mix(PORES, BRACKET_RIM, t), (0.15, t), (0.0, 0.0))
    shape.grid(top, rings, around, flip=True)
    shape.new_part()
    shape.grid(under, rings, around)


def puffball(shape, lo, radius=0.15, place=None):
    place = place or (lambda p: p)
    around = 9 if lo else 16
    rings = 5 if lo else 10
    rng = random.Random(3)
    bumps = [(rng.uniform(0, math.tau), rng.uniform(-0.2, 1.2)) for _ in range(40)]
    shape.new_part()

    def at(i, j):
        high = math.pi * (i / rings - 0.5)
        a = math.tau * j / around
        p = (math.cos(high) * math.sin(a), math.sin(high), math.cos(high) * math.cos(a))
        wart = 0.0
        if not lo:
            for ba, bh in bumps:
                d = abs(math.atan2(math.sin(a - ba), math.cos(a - ba))) + abs(high - bh)
                wart += 0.05 * max(0.0, 1.0 - d / 0.25)
        # (a dimple at the top, where the pore is)
        up = high / (math.pi * 0.5)
        dimple = 0.18 * smooth(0.82, 1.0, up)
        y = (p[1] * 0.8 - dimple + 0.8) * radius
        q = (p[0] * radius * (1.0 + wart), y + wart * radius * 0.3, p[2] * radius * (1.0 + wart))
        colour = mix(PUFF, PUFF_DARK, smooth(0.9, 1.0, up) if up > 0 else 0.25 * smooth(-0.2, -1.0, up))
        return (place(q), colour, (0.0, y / (1.6 * radius)), (0.0, 0.0))
    shape.grid(at, rings, around, wrap=True)


def mushrooms(lo):
    clear()
    counts = {}
    honey = Shape()
    mushroom(honey, lo, 0.055, 0.03, 0.11, 0.008, HONEY_CAP, HONEY_DARK, GILLS, STEM, STEM_FOOT, glow_gills=0.35, lean=(0.15, 0.0))
    counts["honey"] = put("honey", honey)
    shelf = Shape()
    bracket(shelf, lo)
    counts["bracket"] = put("bracket", shelf)
    stalk = Shape()
    mushroom(stalk, lo, 0.03, 0.045, 0.36, 0.006, BONNET, mix(BONNET, HONEY_DARK, 0.4), BONNET, BONNET, mix(BONNET, STEM_FOOT, 0.5),
             glow_cap=1.0, glow_gills=1.0, ring=False, bell=True, lean=(0.25, 0.1))
    counts["stalk"] = put("stalk", stalk)
    ball = Shape()
    puffball(ball, lo)
    counts["puffball"] = put("puffball", ball)
    export("mushrooms_lo.glb" if lo else "mushrooms.glb")
    print("BUILT mushrooms%s: %s" % ("_lo" if lo else "", counts))


# --- What grows out of a zombie ---

ZOMBIE_CAP = linear((0.62, 0.55, 0.44))
ZOMBIE_DARK = linear((0.32, 0.26, 0.2))


def splay(shape, lo, at, count, sizes, rng, spread=0.9, up=(0.0, 1.0, 0.0), glow=0.4):
    """A spray of stalked caps from `at`, each leaning out from `up` by up to `spread`."""
    for k in range(count):
        turn = math.tau * k / count + rng.uniform(-0.4, 0.4)
        tilt = rng.uniform(0.2, spread)
        size = rng.uniform(*sizes)
        u = unit(up)
        across = unit(cross(u, (0.0, 0.0, 1.0)) if abs(u[2]) < 0.9 else (1.0, 0.0, 0.0))
        other = cross(across, u)
        direction = unit(add(times(u, math.cos(tilt)), add(times(across, math.sin(turn) * math.sin(tilt)), times(other, math.cos(turn) * math.sin(tilt)))))
        side = unit(cross(direction, (0.0, 0.0, 1.0)) if abs(direction[2]) < 0.9 else (1.0, 0.0, 0.0))
        ahead = cross(side, direction)

        def place(p, direction=direction, side=side, ahead=ahead):
            return add(at, add(add(times(side, p[0]), times(direction, p[1])), times(ahead, p[2])))
        cap = mix(ZOMBIE_CAP, HONEY_CAP, rng.random() * 0.5)
        mushroom(shape, lo, 0.03 * size, 0.018 * size, 0.07 * size * rng.uniform(0.7, 1.5), 0.0045 * size, cap, ZOMBIE_DARK, GILLS,
                 STEM, ROT, glow_gills=glow, ring=size > 1.2 and not lo, bell=rng.random() < 0.3,
                 lean=(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)), place=place)


def lump(shape, lo, at, radii, rng, colour=ROT):
    """A lumpy mass: the knot of the fruiting body, where it has broken through."""
    shape.blob(at, radii, lambda p: mix(colour, PALE, 0.35 + 0.3 * math.sin(p[0] * 9.0 + p[2] * 7.0)), around=6 if lo else 10,
               rings=4 if lo else 7, uv_y=0.0)


def mat(shape, lo, rng, size=0.07):
    """A mat of mycelium on the skin: a lumpy felt, and threads running off it."""
    shape.new_part()
    around = 7 if lo else 12
    rings = 2 if lo else 4

    def at(i, j):
        t = i / rings
        a = math.tau * j / around
        r = size * t * (1.0 + 0.25 * math.sin(a * 3.0 + 1.0) + 0.15 * math.sin(a * 5.0))
        y = 0.012 * (1.0 - t * t) + 0.004 * math.sin(a * 7.0) * t
        return ((math.sin(a) * r, y, math.cos(a) * r), mix(PALE, ROT, 0.15 + 0.2 * t), (0.15, 0.0), (0.0, 0.0))
    shape.grid(at, rings, around, wrap=True, flip=True)
    for k in range(3 if lo else 7):
        a = rng.uniform(0, math.tau)
        start = (math.sin(a) * size * 0.8, 0.004, math.cos(a) * size * 0.8)
        run = rng.uniform(0.04, 0.11)
        path = [start, add(start, (math.sin(a) * 0.01, 0.0, -run * 0.5)), add(start, (math.sin(a) * 0.016, -0.002, -run))]
        shape.tube(path, lambda t: 0.0018 * (1.0 - 0.6 * t), lambda t: PALE, sides=3, cap=False, uv_y=lambda t: 0.0)


def growths(lo):
    clear()
    counts = {}
    rng = random.Random(21)
    crown = Shape()
    # The knot it broke through at, over the crown and down the back of the skull, and the caps crowded out of it:
    # a big one at the top, a ring of others splaying out round it, small ones bursting between
    lump(crown, lo, (0.0, 0.19, -0.02), (0.1, 0.065, 0.095), rng)
    lump(crown, lo, (-0.04, 0.13, -0.08), (0.07, 0.06, 0.05), rng)
    lump(crown, lo, (0.06, 0.16, 0.04), (0.05, 0.04, 0.05), rng)
    splay(crown, lo, (0.0, 0.23, -0.02), 1, (2.8, 3.0), rng, spread=0.25)
    splay(crown, lo, (0.0, 0.21, -0.02), 5 if lo else 9, (1.3, 2.4), rng, spread=0.8)
    splay(crown, lo, (0.03, 0.2, 0.03), 3 if lo else 7, (0.6, 1.2), rng, spread=1.3)
    splay(crown, lo, (-0.05, 0.13, -0.11), 2 if lo else 4, (0.8, 1.6), rng, spread=0.8, up=(-0.3, 0.4, -1.0))
    # (shelves out of one temple, and the back of the skull)
    bracket(crown, lo, width=0.12, out=0.1, thick=0.032, place=lambda p: add((-0.1, 0.09, 0.0), turn_y(turn_z(p, 0.25), -math.pi * 0.5)))
    bracket(crown, lo, width=0.08, out=0.065, thick=0.024, place=lambda p: add((-0.105, 0.03, 0.035), turn_y(turn_z(p, 0.2), -math.pi * 0.5)))
    bracket(crown, lo, width=0.1, out=0.08, thick=0.028, place=lambda p: add((0.0, 0.06, -0.115), turn_y(p, math.pi)))
    counts["crown"] = put("crown", crown)
    shoulder = Shape()
    lump(shoulder, lo, (0.0, 0.0, 0.0), (0.065, 0.04, 0.06), rng)
    splay(shoulder, lo, (0.0, 0.03, 0.0), 4 if lo else 8, (0.9, 1.9), rng, spread=1.0, up=(0.4, 1.0, 0.0))
    bracket(shoulder, lo, width=0.1, out=0.085, thick=0.03, place=lambda p: add((0.05, -0.035, 0.0), turn_y(p, math.pi * 0.5)))
    counts["shoulder"] = put("shoulder", shoulder)
    back = Shape()
    for k in range(4 if lo else 7):
        y = 0.16 - k * 0.055
        x = 0.035 * math.sin(k * 2.3)
        bracket(back, lo, width=0.08 + 0.025 * (k % 3), out=0.075, thick=0.026, place=lambda p, x=x, y=y: add((x, y, -0.085), turn_y(p, math.pi)))
    lump(back, lo, (0.03, 0.07, -0.09), (0.07, 0.08, 0.035), rng)
    splay(back, lo, (0.03, 0.1, -0.11), 3 if lo else 6, (1.2, 2.3), rng, spread=0.8, up=(0.2, 0.8, -1.0))
    counts["back"] = put("back", back)
    felt = Shape()
    mat(felt, lo, rng)
    counts["mat"] = put("mat", felt)
    export("growths_lo.glb" if lo else "growths.glb")
    print("BUILT growths%s: %s" % ("_lo" if lo else "", counts))


for low in (False, True):
    mushrooms(low)
    growths(low)
