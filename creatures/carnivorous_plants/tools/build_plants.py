"""Builds the giant carnivorous plants (creatures/carnivorous_plants/) and exports them for Godot.

Run from the game's root:
    blender --background --python creatures/carnivorous_plants/tools/build_plants.py [-- lo]
then, so that Godot takes up the new models:
    godot --headless --path . --import

Writes creatures/carnivorous_plants/models/flytrap.glb, sundew.glb and pitcher.glb, and each again with _lo (fewer
points; `lo` builds only those). Everything is in metres, in the game's own directions (x to its left, y up, z the
way it faces), and is turned to Blender's as it is made.

Giant versions of real plants, as a botanist would know them, made big:

    flytrap   A Venus flytrap (Dionaea). `flytrap_lobe_l` and `flytrap_lobe_r` are the two halves of the trap, each
              hinged on the midrib along z through its origin and lying open flat out to its side (+x the left,
              -x the right): the game turns each about z to open and shut it. The inside is dull red, darkest in the
              middle, with three trigger hairs standing up on each half; round the rim a pale band where the
              nectar is, and the long teeth (cilia) that the two halves' interlock when it shuts (those of the
              right half come between those of the left). `flytrap_base` is the rest: the leaf (a winged
              petiole) that carries the trap, the thick midrib under the hinge, four more leaves round the
              rosette with small traps on them (two shut), and a tall flower stalk with a head of white flowers.
              The trap's hinge runs from z -1.1 to 1.1, 0.3 up; the rosette is at z -1.95 (put it to the wall).
    sundew    A sundew (Drosera, after the Cape sundew): a rosette of long strap leaves, arching up and lying out
              over the ground, every one thick with red tentacles, each tipped with a drop of glue that catches
              the light; and a flower stalk, hooked over at the top, of small pale flowers. The game bends the
              tentacles (by UV y, how far up one a point is) and the leaves (by UV2 x, how far along) over
              whatever is held.
    pitcher   A pitcher plant (Nepenthes, a ground pitcher) sunk to its mouth in the mud: a wide mouth at the
              ground with a ribbed, striped, slippery lip (the peristome) sloping down towards the front, black
              fluid inside it, the swell of the urn round it, two fringed wings down its front, a tendril coiled
              behind, and two small pitchers beside it. `pitcher_lid` is the lid, hinged on x at its back edge
              (its origin), held up over the mouth: the game drops it shut.

Every point carries a colour (its vertex colour, linear) and a UV: x how wet it is (where the light glints off it:
nectar, glue, the lip, the fluid), y what the game may move (above). The game shades them (PlantLook).
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


# --- The flytrap ---

FLY_LENGTH = 2.2
FLY_WIDTH = 1.0
FLY_HINGE_Y = 0.3
GREEN_OUT = linear((0.42, 0.46, 0.3))
GREEN_DARK = linear((0.3, 0.34, 0.21))
RIM_PALE = linear((0.6, 0.6, 0.4))
RED_DEEP = linear((0.36, 0.05, 0.05))
RED = linear((0.55, 0.12, 0.09))
HAIR = linear((0.72, 0.62, 0.5))


def lobe_point(s, u, side, length_, width, cup):
    """A point of a flytrap lobe lying open flat: s along the hinge (-1..1), u out from it (0..1)."""
    w = width * (1.0 - s * s) ** 0.55
    x = side * u * w
    z = s * length_ * 0.5 * (1.0 - 0.06 * u)
    y = cup * (u ** 1.7) * (0.6 + 0.4 * (1.0 - s * s)) - 0.06 * cup * u * s * s
    return (x, y, z)


def lobe(shape, side, length_=FLY_LENGTH, width=FLY_WIDTH, cup=0.36, thick=0.07, teeth=21, lo=False, place=None,
         seed=0):
    """One half of a trap, hinged on z at the origin and lying open to +x (side 1) or -x (side -1)."""
    rng = random.Random(seed + (7 if side > 0 else 13))
    place = place or (lambda p: p)
    rows, cols = (10, 5) if lo else (22, 11)

    def inner(i, j):
        s = -1.0 + 2.0 * i / rows
        u = j / cols
        p = lobe_point(s, u, side, length_, width, cup)
        # (darkest red in the middle, paler towards the rim, and a pale band of nectar round it)
        middle = mix(RED_DEEP, RED, smooth(0.0, 0.85, u + 0.25 * abs(s)))
        band = smooth(0.82, 0.95, u)
        colour = mix(middle, RIM_PALE, band * 0.75)
        return (place(p), colour, (0.25 + 0.75 * band, 0.0), (0.0, 0.0))

    def outer(i, j):
        s = -1.0 + 2.0 * i / rows
        u = j / cols
        p = lobe_point(s, u, side, length_, width, cup)
        p = add(p, (0.0, -thick * (1.0 - 0.6 * u), 0.0))
        colour = mix(GREEN_DARK, GREEN_OUT, smooth(0.0, 1.0, u))
        return (place(p), colour, (0.0, 0.0), (0.0, 0.0))
    shape.new_part()
    shape.grid(inner, rows, cols, flip=side > 0)
    shape.new_part()
    shape.grid(outer, rows, cols, flip=side < 0)
    # The rim between them
    shape.new_part()

    def rim(i, j):
        s = -1.0 + 2.0 * i / rows
        p = lobe_point(s, 1.0, side, length_, width, cup)
        if j == 1:
            p = add(p, (0.0, -thick * 0.4, 0.0))
        return (place(p), RIM_PALE if j == 0 else GREEN_OUT, (0.6 if j == 0 else 0.0, 0.0), (0.0, 0.0))
    shape.grid(rim, rows, 1, flip=side > 0)
    # The teeth: long, tapering, carrying on from the lobe's own curve and a little up
    count = max(teeth // (2 if lo else 1), 7)
    shift = 0.5 / count if side < 0 else 0.0
    for k in range(count):
        s = -0.92 + 1.84 * (k + 0.5) / count + shift * 1.84
        if abs(s) > 0.95:
            continue
        root = lobe_point(s, 1.0, side, length_, width, cup)
        before = lobe_point(s, 0.9, side, length_, width, cup)
        out = unit(sub(root, before))
        # (they splay out a little along the trap at its ends)
        out = unit(add(out, (0.0, 0.25, s * 0.35)))
        long = width * (0.42 + 0.1 * rng.random()) * (1.0 - 0.45 * s * s)
        tip = add(root, times(out, long))
        bend = add(mix(root, tip, 0.6), (0.0, long * 0.08, 0.0))
        path = [root, bend, tip]
        thick_root = 0.028 * width
        shape.tube([place(p) for p in path], lambda t: thick_root * (1.0 - t) + 0.002,
                   lambda t: mix(RIM_PALE, mix(GREEN_OUT, RED, 0.35), t), sides=3 if lo else 4, cap=False)
    # The trigger hairs: three on each half, standing up off the inside
    if not lo or True:
        for s in (-0.38, 0.02, 0.4):
            u = 0.42 + 0.06 * rng.random()
            root = lobe_point(s + 0.04 * rng.random(), u, side, length_, width, cup)
            a = lobe_point(s, u + 0.02, side, length_, width, cup)
            b = lobe_point(s + 0.02, u, side, length_, width, cup)
            normal = unit(cross(sub(a, root), sub(b, root)))
            if normal[1] < 0.0:
                normal = times(normal, -1.0)
            tall = 0.2 * width
            path = [root, add(root, times(normal, tall * 0.5)), add(root, add(times(normal, tall), (side * 0.01, 0.0, 0.0)))]
            shape.tube([place(p) for p in path], lambda t: 0.012 * width * (1.0 - 0.85 * t),
                       lambda t: mix(RED, HAIR, t), sides=3, cap=False, wet=0.2)


def leaf_blade(shape, start, end, width, lift, colour_root, colour_tip, rows=8, cols=4):
    """A winged petiole: a flat blade from `start` to `end`, widest towards its end, a little cupped."""
    shape.new_part()
    along = sub(end, start)
    flat = unit((along[0], 0.0, along[2]))
    side = (flat[2], 0.0, -flat[0])

    def at(i, j):
        t = i / rows
        v = -1.0 + 2.0 * j / cols
        w = width * (0.15 + 0.85 * math.sin(math.pi * min(t * 1.15, 1.0) * 0.5) ** 1.5) * (1.0 - 0.6 * smooth(0.85, 1.0, t))
        p = add(start, times(along, t))
        p = add(p, times(side, v * w))
        p = add(p, (0.0, lift * math.sin(math.pi * t) + 0.05 * w * v * v, 0.0))
        return (p, mix(colour_root, colour_tip, t), (0.05, 0.0), (0.0, 0.0))
    shape.grid(at, rows, cols, flip=True)
    shape.new_part()
    shape.grid(lambda i, j: (add(at(i, j)[0], (0.0, -0.025, 0.0)), GREEN_DARK, (0.0, 0.0), (0.0, 0.0)), rows, cols, )


def flytrap(lo):
    clear()
    left = Shape()
    lobe(left, 1.0, lo=lo, seed=1)
    right = Shape()
    lobe(right, -1.0, lo=lo, seed=1)
    counts = {"flytrap_lobe_l": put("flytrap_lobe_l", left), "flytrap_lobe_r": put("flytrap_lobe_r", right)}

    base = Shape()
    rng = random.Random(5)
    rosette = (0.0, 0.0, -1.95)
    # The leaf that carries the trap, and the thick midrib under the hinge
    leaf_blade(base, add(rosette, (0.0, 0.04, 0.05)), (0.0, FLY_HINGE_Y - 0.06, -1.12), 0.42, 0.1, GREEN_DARK, GREEN_OUT,
               rows=5 if lo else 9, cols=3 if lo else 4)
    keel = [(0.0, FLY_HINGE_Y - 0.08, -1.18 + 2.36 * k / 6.0) for k in range(7)]
    keel = [(p[0], p[1] - 0.05 * (1.0 - ((p[2] / 1.18) ** 2)), p[2]) for p in keel]
    base.tube(keel, lambda t: 0.09 * (1.0 - 0.5 * abs(2.0 * t - 1.0) ** 2), lambda t: GREEN_DARK, sides=5 if lo else 7,
              flat=0.7)
    # (it rests on the ground under the trap: a prop of the same green)
    # Four more leaves round the rosette, with small traps: two open, two shut
    for k, (turn, size, shut) in enumerate(((1.5, 0.42, False), (-1.45, 0.5, True), (2.5, 0.36, True), (-2.4, 0.4, False))):
        reach = 0.8 + size * 1.2
        end = add(rosette, turn_y((0.0, 0.18 * size, reach), turn))
        leaf_blade(base, add(rosette, (0.0, 0.03, 0.0)), end, 0.3 * size + 0.08, 0.08, GREEN_DARK, GREEN_OUT,
                   rows=4 if lo else 7, cols=2 if lo else 3)
        mid = add(rosette, turn_y((0.0, 0.18 * size + 0.12 * size, reach + FLY_LENGTH * size * 0.5), turn))
        for side in (1.0, -1.0):
            angle = (1.38 if shut else 0.62) * side

            def place(p, angle=angle, turn=turn, mid=mid):
                return add(mid, turn_y(turn_z(p, angle), turn))
            lobe(base, side, length_=FLY_LENGTH * size, width=FLY_WIDTH * size, cup=0.3 * size, thick=0.05 * size,
                 teeth=15, lo=True, place=place, seed=k)
    # The flower stalk, from the rosette, with a head of white flowers
    tall = 3.1
    stalk = [add(rosette, (0.05 * math.sin(t * 3.0), tall * t, 0.12 * t * t)) for t in [k / 8.0 for k in range(9)]]
    top = base.tube(stalk, lambda t: 0.035 * (1.0 - 0.4 * t), lambda t: GREEN_OUT, sides=4 if lo else 5, uv_y=lambda t: t * 0.0)
    for k in range(5 if lo else 7):
        turn = math.tau * k / (5 if lo else 7) + rng.random() * 0.4
        stem_end = add(top, (math.sin(turn) * 0.18, 0.05 + 0.08 * rng.random(), math.cos(turn) * 0.18))
        base.tube([top, mix(top, stem_end, 0.5), stem_end], lambda t: 0.012, lambda t: GREEN_OUT, sides=3, cap=False)
        # (five white petals round a greenish eye)
        facing = unit(sub(stem_end, add(top, (0.0, -0.15, 0.0))))
        side = unit(cross(facing, (0.0, 1.0, 0.0)) if abs(facing[1]) < 0.95 else (1.0, 0.0, 0.0))
        up = cross(side, facing)
        base.new_part()
        petals = 5
        for p in range(petals):
            a0 = math.tau * p / petals
            a1 = a0 + math.tau / petals * 0.8
            mid_a = (a0 + a1) * 0.5
            def ring(a, r):
                return add(stem_end, add(add(times(side, math.cos(a) * r), times(up, math.sin(a) * r)), times(facing, r * 0.25)))
            white = linear((0.82, 0.82, 0.76))
            eye = linear((0.55, 0.6, 0.42))
            base.both([(stem_end, eye, (0.1, 0.0), (0.0, 0.0)), (ring(a0, 0.09), white, (0.1, 0.0), (0.0, 0.0)),
                       (ring(mid_a, 0.11), white, (0.1, 0.0), (0.0, 0.0)), (ring(a1, 0.09), white, (0.1, 0.0), (0.0, 0.0))])
    counts["flytrap_base"] = put("flytrap_base", base)
    export("flytrap_lo.glb" if lo else "flytrap.glb")
    print("BUILT flytrap%s: %s" % ("_lo" if lo else "", counts))


# --- The sundew ---

DEW_LEAF = linear((0.45, 0.47, 0.28))
DEW_LEAF_RED = linear((0.48, 0.15, 0.11))
DEW_STALK = linear((0.55, 0.13, 0.1))
DEW_DROP = linear((0.85, 0.72, 0.68))


def sundew(lo):
    clear()
    shape = Shape()
    rng = random.Random(11)
    leaves = 7 if lo else 10
    for k in range(leaves):
        turn = math.tau * k / leaves + rng.uniform(-0.25, 0.25)
        long = rng.uniform(1.5, 2.2)
        # How it goes: up out of the rosette, arching over, and out along the ground (or held up, now and then)
        held = rng.random() < 0.3
        rise = rng.uniform(0.45, 0.7) * (1.4 if held else 1.0)
        samples = 6 if lo else 14

        def spine(t, long=long, rise=rise, held=held):
            out = long * t
            y = rise * math.sin(math.pi * min(t / 0.55, 1.0) * 0.5) * (1.0 - (0.0 if held else 0.75) * smooth(0.45, 1.0, t))
            y += 0.04
            # (the tip curls over a little, as a sundew's does)
            curl = 0.12 * smooth(0.85, 1.0, t)
            return (0.0, y - curl, out - curl * 0.5)

        def width(t):
            return 0.022 + 0.055 * smooth(0.12, 0.35, t) * (1.0 - 0.5 * smooth(0.88, 1.0, t))

        def frame(t):
            here = spine(t)
            ahead = unit(sub(spine(min(t + 0.01, 1.0)), spine(max(t - 0.01, 0.0))))
            side = unit(cross((0.0, 1.0, 0.0), ahead))
            up = cross(ahead, side)
            return here, side, up
        shape.new_part()

        def blade(i, j, top=True):
            t = i / samples
            v = -1.0 + 2.0 * j / 2
            here, side, up = frame(t)
            p = add(here, times(side, v * width(t)))
            p = add(p, times(up, 0.006 - 0.012 * v * v - (0.0 if top else 0.008)))
            colour = mix(DEW_LEAF, DEW_LEAF_RED, smooth(0.2, 0.7, t) * 0.85)
            return (turn_y(p, turn), colour if top else mix(colour, (0.05, 0.05, 0.03), 0.3), (0.05, 0.0), (t, 0.0))
        shape.grid(lambda i, j: blade(i, j, True), samples, 2, flip=True)
        shape.new_part()
        shape.grid(lambda i, j: blade(i, j, False), samples, 2)
        # The tentacles: rows across it, the ones at its edges longest and leaning out
        along = 0.07 if lo else 0.032
        t = 0.22
        row = 0
        while t < 1.0:
            here, side, up = frame(t)
            across = 3 if lo else 5
            row += 1
            for c in range(across):
                # (each row a little offset from the last, so that they lie staggered)
                v = -1.0 + 2.0 * (c + (0.5 if row % 2 else 0.0) * (0.0 if c == across - 1 else 1.0)) / (across - 1)
                v = max(-1.0, min(1.0, v))
                edge = abs(v)
                root = add(here, times(side, v * width(t) * 0.95))
                root = add(root, times(up, 0.004))
                lean = unit(add(times(up, 1.0 - 0.75 * edge), times(side, v * 1.1)))
                lean = unit(add(lean, times(sub(spine(min(t + 0.05, 1.0)), here), 0.6 * smooth(0.9, 1.0, t))))
                tall = (0.035 + 0.11 * edge ** 2) * (0.75 + 0.5 * rng.random()) * (1.4 if t > 0.93 else 1.0)
                tip = add(root, times(lean, tall))
                path = [turn_y(p, turn) for p in (root, tip)]
                shape.tube(path, lambda q: 0.0045 * (1.0 - 0.45 * q), lambda q: mix(DEW_LEAF_RED, DEW_STALK, q), sides=3,
                           uv_y=lambda q: q, uv2=(t, 0.0), cap=False)
                drop = 0.012 + 0.007 * rng.random()
                shape.blob(path[-1], (drop, drop * 0.9, drop), lambda p: DEW_DROP, around=3 if lo else 4, rings=2,
                           wet=1.0, uv_y=1.0, uv2=(t, 0.0))
            t += along * (0.85 + 0.3 * rng.random())
    # The flower stalk, hooked over at its top, with small pale flowers along the hook
    tall = 1.9
    stalk = []
    for k in range(10):
        t = k / 9.0
        hook = smooth(0.75, 1.0, t)
        stalk.append((0.04 * math.sin(t * 4.0), tall * t - 0.25 * hook * hook, 0.32 * hook))
    shape.tube(stalk, lambda t: 0.018 * (1.0 - 0.4 * t), lambda t: DEW_LEAF_RED, sides=4 if lo else 5)
    for k in range(4 if lo else 6):
        t = 0.72 + 0.27 * k / 5.0
        i = min(int(t * 9.0), 8)
        at = mix(stalk[i], stalk[i + 1], t * 9.0 - i)
        shape.blob(add(at, (0.0, 0.03, 0.0)), (0.05, 0.03, 0.05), lambda p: linear((0.82, 0.74, 0.74)), around=5, rings=2)
    counts = {"sundew": put("sundew", shape)}
    export("sundew_lo.glb" if lo else "sundew.glb")
    print("BUILT sundew%s: %s" % ("_lo" if lo else "", counts))


# --- The pitcher ---

PIT_BODY = linear((0.38, 0.4, 0.25))
PIT_BLOTCH = linear((0.35, 0.14, 0.15))
PIT_LIP_RED = linear((0.46, 0.1, 0.1))
PIT_LIP_PALE = linear((0.66, 0.5, 0.4))
PIT_THROAT = linear((0.2, 0.06, 0.07))
PIT_FLUID = linear((0.03, 0.035, 0.02))
MOUTH_X = 0.72
MOUTH_Z = 0.6


def mouth_point(a, r=1.0, inward=0.0):
    """A point on the mouth's rim at angle `a` (0 the front, +z), `r` times out, sloping down towards the front."""
    x = math.sin(a) * MOUTH_X * r
    z = math.cos(a) * MOUTH_Z * r
    y = 0.28 - 0.2 * math.cos(a) + 0.05 * math.cos(2.0 * a)
    return (x, y - inward, z)


def blotched(p, rng_seed=3):
    n = math.sin(p[0] * 9.1 + 1.3) * math.sin(p[2] * 7.7 + 0.4) + 0.5 * math.sin(p[1] * 13.0 + p[0] * 5.0)
    return mix(PIT_BODY, PIT_BLOTCH, smooth(0.35, 0.8, n))


def pitcher_body(shape, lo, scale=1.0, at=(0.0, 0.0, 0.0), turn=0.0):
    around = 28 if lo else 64

    def place(p):
        return add(at, turn_y(times(p, scale), turn))
    # The lip: a ribbed collar, rolled in over the throat, striped pale and red
    shape.new_part()
    sections = 4 if lo else 7

    def lip(i, j):
        a = math.tau * i / around
        s = j / sections
        # across the collar: from its outer edge, over its crest, down in to the throat
        roll = math.pi * s
        out = 1.0 + 0.24 * math.cos(roll)
        up = 0.09 * math.sin(roll) + (0.05 if s > 0.5 else 0.0) * (s - 0.5)
        rib = 0.006 * (0.5 + 0.5 * math.cos(a * (around / 4.0))) * math.sin(roll) ** 2
        p = mouth_point(a, out - 0.12, -up - rib)
        stripe = 0.5 + 0.5 * math.cos(a * (around / 4.0))
        colour = mix(PIT_LIP_RED, PIT_LIP_PALE, smooth(0.55, 0.95, stripe) * 0.6 * math.sin(roll) ** 0.5)
        colour = mix(colour, PIT_THROAT, smooth(0.75, 1.0, s) * 0.6)
        return (place((p[0], p[1] + 2.0 * up + rib, p[2])), colour, (0.8, 0.0), (0.0, 0.0))
    # (the grid's rows are round the mouth; it wraps)
    table = [[lip(i, j) for j in range(sections + 1)] for i in range(around)]
    for i in range(around):
        for j in range(sections):
            a, b = table[i][j], table[i][j + 1]
            c, d = table[(i + 1) % around][j + 1], table[(i + 1) % around][j]
            shape.face([a, d, c, b])
    # The throat, down from the lip to the fluid
    shape.new_part()
    for i in range(around):
        a0 = math.tau * i / around
        a1 = math.tau * (i + 1) / around
        top0, top1 = mouth_point(a0, 0.76, 0.0), mouth_point(a1, 0.76, 0.0)
        low0, low1 = mouth_point(a0, 0.7, 0.18), mouth_point(a1, 0.7, 0.18)
        low0 = (low0[0], 0.06, low0[2])
        low1 = (low1[0], 0.06, low1[2])
        shape.face([(place(top0), PIT_THROAT, (0.5, 0.0), (0, 0)), (place(top1), PIT_THROAT, (0.5, 0.0), (0, 0)),
                    (place(low1), PIT_FLUID, (0.6, 0.0), (0, 0)), (place(low0), PIT_FLUID, (0.6, 0.0), (0, 0))])
    # The fluid: black, still, a little below the ground's level at the front
    shape.new_part()
    middle = place((0.0, 0.07, 0.0))
    for i in range(around):
        a0 = math.tau * i / around
        a1 = math.tau * (i + 1) / around
        p0 = mouth_point(a0, 0.7, 0.0)
        p1 = mouth_point(a1, 0.7, 0.0)
        shape.face([(middle, PIT_FLUID, (0.9, 0.0), (0, 0)), (place((p0[0], 0.06, p0[2])), PIT_FLUID, (0.9, 0.0), (0, 0)),
                    (place((p1[0], 0.06, p1[2])), PIT_FLUID, (0.9, 0.0), (0, 0))])
    # The swell of the urn round it, down to the mud, higher behind
    shape.new_part()
    skirt_rows = 3 if lo else 5

    def skirt(i, j):
        a = math.tau * i / around
        t = j / skirt_rows
        rim = mouth_point(a, 1.12, -0.02)
        out = mouth_point(a, 1.12 + 0.45 * t + 0.25 * t * t * (0.5 - 0.5 * math.cos(a)), 0.0)
        y = lerp(rim[1], -0.05, t ** 1.4) + 0.12 * math.sin(math.pi * t) * (0.6 - 0.4 * math.cos(a))
        p = (out[0], y, out[2])
        return (place(p), blotched(p), (0.0, 0.0), (0.0, 0.0))
    table = [[skirt(i, j) for j in range(skirt_rows + 1)] for i in range(around)]
    for i in range(around):
        for j in range(skirt_rows):
            a, b = table[i][j], table[i][j + 1]
            c, d = table[(i + 1) % around][j + 1], table[(i + 1) % around][j]
            shape.face([a, b, c, d])
    # The two wings down its front, fringed
    for side in (1.0, -1.0):
        a = 0.32 * side
        top = mouth_point(a, 1.18, -0.02)
        low = mouth_point(a, 1.8, 0.0)
        low = (low[0], -0.02, low[2])
        shape.new_part()
        steps = 4 if lo else 8
        for k in range(steps):
            t0, t1 = k / steps, (k + 1) / steps
            p0, p1 = mix(top, low, t0), mix(top, low, t1)
            p0 = add(p0, (0.0, 0.06 * math.sin(math.pi * t0), 0.0))
            p1 = add(p1, (0.0, 0.06 * math.sin(math.pi * t1), 0.0))
            fin = 0.09
            q0, q1 = add(p0, (0.0, fin, 0.0)), add(p1, (0.0, fin, 0.0))
            shape.both([(place(p0), PIT_BODY, (0, 0), (0, 0)), (place(p1), PIT_BODY, (0, 0), (0, 0)),
                        (place(q1), PIT_BLOTCH, (0, 0), (0, 0)), (place(q0), PIT_BLOTCH, (0, 0), (0, 0))])
            # (a tooth of the fringe on each)
            tip = add(mix(q0, q1, 0.5), (0.0, 0.06, 0.0))
            shape.both([(place(q0), PIT_BLOTCH, (0, 0), (0, 0)), (place(q1), PIT_BLOTCH, (0, 0), (0, 0)),
                        (place(tip), PIT_LIP_RED, (0, 0), (0, 0))])
    # The column at the back of the mouth, up to where the lid is hinged
    back = mouth_point(math.pi, 1.05, -0.04)
    hinge = (0.0, back[1] + 0.32, back[2] - 0.08)
    shape.tube([place(p) for p in (add(back, (0.0, -0.1, 0.06)), mix(back, hinge, 0.5), hinge)],
               lambda t: 0.14 * (1.0 - 0.3 * t), lambda t: mix(PIT_LIP_RED, PIT_BODY, t), sides=5 if lo else 8, flat=0.55)
    return hinge


def pitcher_lid(shape, lo, scale=1.0, open_angle=1.05, place=None):
    """The lid: an oval leaf hinged at its back edge on x through the origin, made held up `open_angle` from shut
    (shut, it lies over the mouth, forward of the hinge). `place` moves it where it goes (by default nowhere)."""
    place = place or (lambda p: p)
    shape.new_part()
    rows, cols = (5, 6) if lo else (9, 12)
    rx, rz = 0.62, 0.56

    def at_(i, j, top):
        u = -1.0 + 2.0 * j / cols
        v = i / rows
        x = u * rx * math.sqrt(max(1.0 - (2.0 * v - 1.0) ** 2, 0.0) ** 0.8 + 0.02)
        z = v * rz * 2.0
        y = 0.08 * math.sin(math.pi * v) * (1.0 - u * u) * (1.0 if top else 0.85)
        p = (x, y - (0.0 if top else 0.03), z)
        p = times(turn_x(p, -open_angle), scale)
        colour = mix(PIT_BODY, PIT_BLOTCH, 0.4 + 0.3 * math.sin(x * 11.0 + z * 7.0)) if top else mix(PIT_BODY, PIT_LIP_RED, 0.45)
        return (place(p), colour, (0.0 if top else 0.85, 0.0), (0.0, 0.0))
    shape.grid(lambda i, j: at_(i, j, True), rows, cols, flip=True)
    shape.new_part()
    shape.grid(lambda i, j: at_(i, j, False), rows, cols)


def pitcher(lo):
    clear()
    shape = Shape()
    hinge = pitcher_body(shape, lo)
    # A tendril coiled behind it, back to the plant
    coil = []
    for k in range(16 if not lo else 8):
        t = k / (15.0 if not lo else 7.0)
        a = t * math.tau * 1.6
        coil.append((0.25 * math.sin(a) * (1.0 - t * 0.5), 0.25 + 0.5 * t + 0.15 * math.cos(a), -1.0 - 0.9 * t))
    shape.tube(coil, lambda t: 0.035 * (1.0 - 0.6 * t), lambda t: PIT_BODY, sides=4 if lo else 5)
    # Two small pitchers beside it, standing up
    for k, (x, z, size, turn) in enumerate(((1.25, -0.55, 0.42, 0.6), (-1.15, -0.85, 0.34, -0.9))):
        at = (x, 0.0, z)
        shape.new_part()
        around = 10 if lo else 18
        rows = 5 if lo else 9

        def urn(i, j, size=size, at=at, turn=turn):
            a = math.tau * j / around
            t = i / rows
            r = size * (0.45 + 0.45 * math.sin(math.pi * min(t * 1.25, 1.0)) - 0.15 * smooth(0.8, 1.0, t))
            p = (math.sin(a) * r, size * 2.0 * t, math.cos(a) * r * 0.9)
            colour = blotched(p) if t < 0.9 else mix(PIT_LIP_RED, PIT_LIP_PALE, 0.5 + 0.5 * math.cos(a * 8.0))
            return (add(at, turn_y(p, turn)), colour, (0.6 if t > 0.9 else 0.0, 0.0), (0.0, 0.0))
        shape.grid(urn, rows, around, wrap=True)
        top = add(at, (0.0, size * 2.0, 0.0))
        shape.new_part()
        for j in range(around):
            a0 = math.tau * j / around
            a1 = math.tau * (j + 1) / around
            r = size * 0.55
            shape.face([(add(top, (0.0, -0.06, 0.0)), PIT_FLUID, (0.9, 0.0), (0, 0)),
                        (add(top, turn_y((math.sin(a0) * r, 0.0, math.cos(a0) * r * 0.9), turn)), PIT_THROAT, (0.5, 0.0), (0, 0)),
                        (add(top, turn_y((math.sin(a1) * r, 0.0, math.cos(a1) * r * 0.9), turn)), PIT_THROAT, (0.5, 0.0), (0, 0))])
        pitcher_lid(shape, True, scale=size * 1.2, open_angle=1.2,
                    place=lambda p, at=at, size=size, turn=turn: add(at, turn_y(add(p, (0.0, size * 2.0, -size * 0.5)), turn)))
    counts = {"pitcher": put("pitcher", shape)}
    lid = Shape()
    pitcher_lid(lid, lo)
    counts["pitcher_lid"] = put("pitcher_lid", lid)
    # (the lid's hinge, where the game is to put it)
    print("PITCHER LID HINGE %.3f %.3f %.3f" % hinge)
    export("pitcher_lo.glb" if lo else "pitcher.glb")
    print("BUILT pitcher%s: %s" % ("_lo" if lo else "", counts))


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for low in ((True,) if "lo" in args else (False, True)):
    flytrap(low)
    sundew(low)
    pitcher(low)
