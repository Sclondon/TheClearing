"""Builds the corvids (an American crow, a common raven and a blue jay) and exports them for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/crow/tools/build_corvids.py
    blender --background --python creatures/crow/tools/build_corvids.py -- <folder>   # and pictures

Writes creatures/crow/models/crow.glb, raven.glb and creatures/blue_jay/models/
blue_jay.glb, each with a low-detail twin (_lo.glb: about a third of the
triangles, fewer and bigger feathers and coarser tubes) for phones and for
birds far off. CorvidBody (creatures/crow/corvid_body.gd) reads them and merges
each into one mesh, telling the parts apart by their object and material names,
and the joints by the empties named `joint_*`. There is no armature: the shader
(corvid.gdshader) poses the parts from where each vertex is.

All coordinates below are in Godot space (metres, Y up, the bird facing +Z, +X
its left), converted on the way into Blender. The three are built by one
builder with each kind's proportions (KINDS): the same anatomy, as all three
are corvids.

THE BIRD, standing (on a ledge, a branch or the ground), its body tipped up at
the breast by FLIGHT_PITCH (the shader levels it to fly):
- body: the core, one smooth surface (a metaball family) from the rump over the
  back and the breast, up the neck to the skull and the forehead. Material
  `down` (the dark under-layer that shows between feathers).
- feathers: contour feathers in overlapping rows over the body, the neck and the
  head, each a small curved vane with a raised shaft, laid on the surface
  pointing back (down on the breast); scapulars over the shoulders; on the head,
  tiny ones flowing back from the bill. Material `feather`; UV is (across,
  along) the vane, UV2 (a number for the feather, its region / 16).
- bristles: the nasal bristles, stiff narrow feathers lying forward over the
  base of the bill and its nostrils (corvids' and jays'); the raven's throat
  hackles (long lanceolate feathers, shaggy); the jay's crest (`crest`).
- tail: twelve rectrices, closed (the central pair on top), rounded in the
  crow, wedge-shaped in the raven, long and square-ended in the jay, with upper
  and under tail coverts over their roots. UV2.x of each is where it is across
  the tail (0 to 1), for the shader's fan.
- wing_<side>_<bone>: each wing in three pieces by the bone that carries them
  (arm: the humerus, from the shoulder to the elbow; fore: the forearm, the
  ulna, to the wrist; hand: the carpometacarpus and digits). Ten primaries on
  the hand (the outer five emarginated, so they part into fingers when spread;
  UV2.x is how far out each is, 0 to 1, for the shader's fan), the alula and the
  primary coverts; ten secondaries on the forearm, three tertials at the elbow,
  greater, median and lesser coverts in rows over their roots up to the leading
  edge; and a core (`wing_<side>_core`) of skin and bone under them, the
  leading edge. Each piece is modelled twice: folded against the flank (the
  mesh: the bend of the wing at the shoulder, the coverts over the secondaries,
  the primaries under them reaching back over the tail) and spread (the shape
  key `open`: the wing out straight, level when the body is levelled, every
  feather where it is in flight). The core folds away inside the body.
- legs: feathered tibia ("trousers") down to the hock, the scaled tarsus, three
  toes forward and the strong hind toe back, each jointed and padded, with
  hooked nails (material `claw`).
- beak (upper mandible: deep, the culmen arched to the tip), jaw (the lower,
  opened by the shader), mouth (the inside of the gape, dark), eye (beads with
  UV.y the angle off their axis).

Empties `joint_<name>` mark the joints the shader poses about (hip, knee, hock,
foot, neck, head, hinge of the jaw, crest, tail, shoulder; the elbow, wrist and
hand's tip of the spread wing in its level frame, from the shoulder), and
`meta_flight_pitch` (its x) the pitch that levels the body to fly.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# How much of its radius a lone metaball's surface is at (threshold 0.6, stiffness 2).
SHRINK = 0.672

# Regions, as the shader colours them (UV2.y * 16).
(UNDER, BACK, CROWN, FACE, THROAT, CREST, NECKLACE, BRIDLE, COVERT, PRIMARY, SECONDARY, TERTIAL, TAIL, RUMP,
 NASAL, SCAPULAR) = range(16)

# The body is tipped up at the breast by this much when it stands (radians);
# the shader pitches it down by this to fly level.
FLIGHT_PITCH = 0.3

rng = random.Random(7)
LOW = False
K = {}


def L(high, low):
    return low if LOW else high


def B(p):
    """Godot (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def G(v):
    """Blender to Godot."""
    return Vector((v.x, v.z, -v.y))


def V(x, y, z):
    return Vector((x, y, z))


def S(p):
    """A point in crow units, scaled to the kind's size."""
    return Vector(p) * K["size"]


def clear():
    for thing in list(bpy.data.objects):
        bpy.data.objects.remove(thing, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for made in list(bpy.data.materials):
        bpy.data.materials.remove(made)
    for ball in list(bpy.data.metaballs):
        bpy.data.metaballs.remove(ball)


COLOURS = {
    "down": (0.05, 0.05, 0.06), "feather": (0.08, 0.08, 0.1), "beak": (0.04, 0.04, 0.045), "mouth": (0.2, 0.12, 0.13),
    "leg": (0.05, 0.05, 0.05), "claw": (0.03, 0.03, 0.03), "eye": (0.02, 0.015, 0.01),
}
MATERIALS = {}


def mat(name):
    if name not in MATERIALS or MATERIALS[name].name not in bpy.data.materials:
        made = bpy.data.materials.new(name)
        made.diffuse_color = (*COLOURS[name], 1.0)
        made.use_nodes = True
        shader = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs[0].default_value = (*COLOURS[name], 1.0)
        MATERIALS[name] = made
    return MATERIALS[name]


class Part:
    """A mesh being made: vertices (Godot space), each with UV and UV2 and,
    for a wing, where it goes with the wing open; faces as lists of indices."""

    def __init__(self, name, material):
        self.name = name
        self.material = material
        self.points = []
        self.uv = []
        self.uv2 = []
        self.open = []
        self.faces = []

    def v(self, p, uv=(0.0, 0.0), uv2=(0.0, 0.0), open_p=None):
        self.points.append(Vector(p))
        self.uv.append(uv)
        self.uv2.append(uv2)
        self.open.append(Vector(open_p) if open_p is not None else Vector(p))
        return len(self.points) - 1

    def f(self, idx):
        self.faces.append(list(idx))

    def make(self, with_open=False):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([B(p) for p in self.points], [], self.faces)
        mesh.update()
        uv = mesh.uv_layers.new(name="UVMap")
        uv2 = mesh.uv_layers.new(name="UV2")
        for poly in mesh.polygons:
            poly.use_smooth = True
            for loop in poly.loop_indices:
                vi = mesh.loops[loop].vertex_index
                uv.data[loop].uv = self.uv[vi]
                uv2.data[loop].uv = self.uv2[vi]
        made = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(made)
        made.data.materials.append(mat(self.material))
        if with_open:
            made.shape_key_add(name="Basis")
            key = made.shape_key_add(name="open")
            for i, p in enumerate(self.open):
                key.data[i].co = B(p)
        return made


def blobs(name, balls, faces, resolution=0.004):
    """One fused surface from `balls` ((x, y, z), surface radius, (sx, sy, sz)
    stretch), in crow units: a metaball family, made a mesh, smoothed and
    thinned to about `faces` triangles."""
    ball_data = bpy.data.metaballs.new(name)
    ball_data.resolution = resolution * K["size"]
    ball_data.render_resolution = resolution * K["size"]
    ball_data.threshold = 0.6
    holder = bpy.data.objects.new(name, ball_data)
    bpy.context.scene.collection.objects.link(holder)
    for ball in balls:
        at, radius = S(ball[0]), ball[1] * K["size"]
        stretch = ball[2] if len(ball) > 2 else (1.0, 1.0, 1.0)
        element = ball_data.elements.new(type="ELLIPSOID" if stretch != (1.0, 1.0, 1.0) else "BALL")
        element.co = B(at)
        element.radius = radius / SHRINK
        element.stiffness = 2.0
        if stretch != (1.0, 1.0, 1.0):
            element.size_x = stretch[0]
            element.size_y = stretch[2]
            element.size_z = stretch[1]
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(holder.evaluated_get(depsgraph))
    bpy.data.objects.remove(holder, do_unlink=True)
    made = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(made)
    bpy.context.view_layer.objects.active = made
    made.select_set(True)
    smooth = made.modifiers.new("smooth", "SMOOTH")
    smooth.factor = 0.5
    smooth.iterations = 3
    bpy.ops.object.modifier_apply(modifier="smooth")
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    thin = made.modifiers.new("thin", "DECIMATE")
    thin.ratio = min(1.0, faces / max(tris, 1))
    bpy.ops.object.modifier_apply(modifier="thin")
    made.select_set(False)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.uv_layers.new(name="UVMap")
    mesh.uv_layers.new(name="UV2")
    return made


# --- Feathers ---

def frame(d, n):
    """An orthonormal frame: along `d`, `n` made square to it, and the side."""
    d = Vector(d).normalized()
    n = (Vector(n) - d * Vector(n).dot(d)).normalized()
    s = n.cross(d).normalized()
    return d, n, s


def vane_points(root, d, n, length, width, kind="round", lift=0.18, bend=0.0, cup=0.12, rows=3, twist=0.0, skew=0.0,
                notch=0.0, arc=0.0):
    """A feather's vertices: rows of three (one vane edge, the shaft, the other
    edge) out from `root` along `d`, the vane square to `n`, lifted off the
    surface towards the tip by `lift` of its length, bent towards `n` by
    `bend`, cupped (edges down) by `cup` of its width, twisted, and a tip.
    `kind`: round (contour feathers), lance (hackles, crest, bristles: narrow,
    pointed), flight (long, the vanes unequal by `skew`), broad (the tail: wide
    to a rounded end). `notch` (0..1) narrows the outer part of a flight
    feather (the emargination of a corvid's outer primaries, that parts the tips
    into fingers). Returns the points and their (across, along)."""
    d, n, s = frame(d, n)
    points = []
    uvs = []
    for r in range(rows + 1):
        t = r / (rows + 0.6)
        if kind == "round":
            half = 0.5 * width * (0.45 + 0.55 * math.sin(math.pi * min(0.18 + t * 0.95, 0.98)) ** 0.7)
        elif kind == "lance":
            half = 0.5 * width * (0.4 + 0.6 * (1.0 - t) ** 0.8) * min(1.0, 0.55 + t * 3.0)
        elif kind == "flight":
            half = 0.5 * width * (0.62 + 0.38 * math.sin(math.pi * min(0.3 + t * 0.7, 0.97)))
            if notch > 0.0:
                half *= 1.0 - notch * 0.55 * min(max((t - 0.45) / 0.2, 0.0), 1.0)
        else:
            half = 0.5 * width * (0.62 + 0.38 * math.sin(math.pi * min(0.15 + t * 0.8, 0.97)))
        along = length * t
        up = lift * length * t ** 1.6 + bend * length * t * t
        middle = Vector(root) + d * along + n * up
        if arc > 0.0:
            middle = Vector(root) + (d * math.sin(arc * t) + n * (1.0 - math.cos(arc * t))) * length / arc
        tw = twist * t
        side = s * math.cos(tw) + n * math.sin(tw)
        lean = n * math.cos(tw) - s * math.sin(tw)
        left = half * (1.0 - skew)
        right = half * (1.0 + skew)
        points.append(middle + side * left - lean * cup * left)
        uvs.append((-1.0, t))
        points.append(middle + lean * width * 0.06)
        uvs.append((0.0, t))
        points.append(middle - side * right - lean * cup * right)
        uvs.append((1.0, t))
    up = lift * length + bend * length
    if arc > 0.0:
        tip = Vector(root) + (d * math.sin(arc) + n * (1.0 - math.cos(arc))) * length / arc
    else:
        tip = Vector(root) + d * length + n * up
    # (a broad or flight feather ends round, not in a point)
    if kind in ("broad", "flight"):
        tip = tip - d * length * 0.02
    points.append(tip)
    uvs.append((0.0, 1.0))
    return points, uvs


def vane_faces(base, rows=3):
    faces = []
    for r in range(rows):
        a = base + r * 3
        b = a + 3
        faces.append([a, b, b + 1, a + 1])
        faces.append([a + 1, b + 1, b + 2, a + 2])
    last = base + rows * 3
    tip = last + 3
    faces.append([last, tip, last + 1])
    faces.append([last + 1, tip, last + 2])
    return faces


def feather(part, root, d, n, length, width, region, kind="round", open_frame=None, rows=3, tag=None, **shape):
    """Adds one feather to `part` (and, for a wing, where it is when open:
    `open_frame` = (root, d, n)). Low detail, it has half the rows and the
    contour feathers are bigger (there are fewer of them)."""
    if LOW:
        rows = max(1, rows // 2)
        if kind == "round" and region not in (COVERT,):
            length *= 1.3
            width *= 1.45
    pts, uvs = vane_points(root, d, n, length, width, kind, rows=rows, **shape)
    opened = vane_points(open_frame[0], open_frame[1], open_frame[2], length, width, kind, rows=rows, **shape)[0] if open_frame else pts
    tag = rng.random() if tag is None else tag
    base = len(part.points)
    for p, uv, q in zip(pts, uvs, opened):
        part.v(p, uv, (tag, (region + 0.5) / 16.0), q)
    for face in vane_faces(base, rows):
        part.f(face)


# --- Solid pieces ---

def tube(part, line, radii, sides=8, uv2=(0.0, 0.0), cap_end=True, cap_start=False, squash=1.0, up=Vector((0, 1, 0)), open_line=None, open_up=None):
    """A round tube along the points of `line` with a radius at each; with
    `open_line`, its open shape follows that line instead."""
    if LOW:
        sides = max(4, sides - 2)

    def rings_of(points, upward):
        rings = []
        total = sum((points[i + 1] - points[i]).length for i in range(len(points) - 1))
        run = 0.0
        for i, at in enumerate(points):
            if i > 0:
                run += (points[i] - points[i - 1]).length
            ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
            side = ahead.cross(upward)
            if side.length < 0.1:
                side = ahead.cross(Vector((0, 0, 1)))
            side = side.normalized()
            top = side.cross(ahead).normalized()
            ring = []
            for k in range(sides):
                a = math.tau * k / sides
                ring.append((at + (side * math.cos(a) + top * math.sin(a) * squash) * radii[i], (k / sides, run / max(total, 1e-6))))
            rings.append(ring)
        return rings

    shut = rings_of(line, up)
    opened = rings_of(open_line, open_up or up) if open_line else shut
    rings = []
    for ring, oring in zip(shut, opened):
        rings.append([part.v(p, uv, uv2, q) for (p, uv), (q, _) in zip(ring, oring)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            a, b = rings[i][k], rings[i][(k + 1) % sides]
            c, d = rings[i + 1][(k + 1) % sides], rings[i + 1][k]
            part.f([a, d, c, b])
    for cap, at_end in ((cap_end, True), (cap_start, False)):
        if not cap:
            continue
        pts = line if not open_line else open_line
        i0, i1 = (-1, -2) if at_end else (0, 1)
        out = (line[i0] - line[i1]).normalized()
        out_o = (pts[i0] - pts[i1]).normalized()
        tip = part.v(line[i0] + out * radii[i0] * 0.6, (0.0, 1.0 if at_end else 0.0), uv2, pts[i0] + out_o * radii[i0] * 0.6)
        ring = rings[i0]
        for k in range(sides):
            if at_end:
                part.f([ring[k], tip, ring[(k + 1) % sides]])
            else:
                part.f([ring[(k + 1) % sides], tip, ring[k]])


def ball(part, middle, radii, segments=8, rings=6, axis=Vector((0, 0, 1)), uv2=(0.0, 0.0), polar_uv=False):
    """An ellipsoid; with `polar_uv`, UV.y is the angle off `axis` (0 at the
    pole that faces along it), for an eye."""
    if LOW:
        segments = max(5, segments - 2)
        rings = max(3, rings - 1)
    middle = Vector(middle)
    axis = Vector(axis).normalized()
    one = axis.cross(Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))).normalized()
    two = axis.cross(one).normalized()
    top = part.v(middle + axis * radii[2], (0.0, 0.0), uv2)
    rows = []
    for r in range(1, rings):
        a = math.pi * r / rings
        row = []
        for s in range(segments):
            b = math.tau * s / segments
            p = middle + axis * math.cos(a) * radii[2] + (one * math.cos(b) * radii[0] + two * math.sin(b) * radii[1]) * math.sin(a)
            row.append(part.v(p, (s / segments, a / math.pi if polar_uv else r / rings), uv2))
        rows.append(row)
    bottom = part.v(middle - axis * radii[2], (0.0, 1.0), uv2)
    for s in range(segments):
        t = (s + 1) % segments
        part.f([top, rows[0][s], rows[0][t]])
        part.f([bottom, rows[-1][t], rows[-1][s]])
    for r in range(len(rows) - 1):
        for s in range(segments):
            t = (s + 1) % segments
            part.f([rows[r][s], rows[r + 1][s], rows[r + 1][t], rows[r][t]])


# --- The kinds ---

KINDS = {
    "crow": {
        "size": 1.0,
        "out": os.path.join(ROOT, "creatures", "crow", "models", "crow"),
        "head": (0.0, 0.226, 0.104), "skull": 0.026, "skull_stretch": (0.92, 0.88, 1.22),
        "forehead": ((0.0, 0.229, 0.124), 0.017), "neck_len": 1.0,
        "bill": {"length": 0.052, "depth": 0.0165, "width": 0.0125, "curve": 0.0075, "lower": 0.0068},
        "bristles": 10, "throat_hackles": 0, "crest": 0,
        "tail": {"length": 0.165, "width": 0.034, "graduation": 0.09, "droop": 0.36},
        "primaries": [0.148, 0.156, 0.168, 0.182, 0.196, 0.21, 0.222, 0.228, 0.222, 0.16],
        "notched": 5, "secondary": 0.128, "hand": 0.25, "wrist": 0.178, "elbow": 0.084,
        "tarsus": 1.0, "breast": 1.0,
    },
    "raven": {
        "size": 1.32,
        "out": os.path.join(ROOT, "creatures", "crow", "models", "raven"),
        "head": (0.0, 0.228, 0.107), "skull": 0.0265, "skull_stretch": (0.92, 0.93, 1.2),
        "forehead": ((0.0, 0.236, 0.122), 0.019), "neck_len": 1.08,
        "bill": {"length": 0.058, "depth": 0.0215, "width": 0.0135, "curve": 0.0115, "lower": 0.0085},
        "bristles": 14, "throat_hackles": 18, "crest": 0,
        "tail": {"length": 0.18, "width": 0.033, "graduation": 0.3, "droop": 0.34},
        "primaries": [0.15, 0.158, 0.17, 0.186, 0.202, 0.218, 0.232, 0.24, 0.236, 0.172],
        "notched": 6, "secondary": 0.13, "hand": 0.255, "wrist": 0.18, "elbow": 0.086,
        "tarsus": 1.02, "breast": 1.0,
    },
    "blue_jay": {
        "size": 0.62,
        "out": os.path.join(ROOT, "creatures", "blue_jay", "models", "blue_jay"),
        "head": (0.0, 0.232, 0.1), "skull": 0.031, "skull_stretch": (0.95, 0.95, 1.12),
        "forehead": ((0.0, 0.236, 0.118), 0.021), "neck_len": 0.9,
        "bill": {"length": 0.04, "depth": 0.0145, "width": 0.012, "curve": 0.0045, "lower": 0.0062},
        "bristles": 8, "throat_hackles": 0, "crest": 13,
        "tail": {"length": 0.2, "width": 0.036, "graduation": 0.05, "droop": 0.26},
        "primaries": [0.12, 0.125, 0.13, 0.135, 0.14, 0.142, 0.14, 0.133, 0.12, 0.085],
        "notched": 0, "secondary": 0.118, "hand": 0.205, "wrist": 0.15, "elbow": 0.074,
        "tarsus": 1.05, "breast": 1.08,
    },
}


# The joints at rest, in crow units (scaled by the kind; the head, bill and
# wing's own come from KINDS).
HIP = (0.0, 0.13, -0.005)
NECK_BASE = (0.0, 0.186, 0.064)
TAIL_ROOT = (0.0, 0.132, -0.102)
SHOULDER = (0.034, 0.176, 0.042)
KNEE = (0.028, 0.105, 0.016)
HOCK = (0.024, 0.058, -0.012)
FOOT = (0.022, 0.006, 0.008)


def head():
    return S(K["head"])


def body_balls():
    b = K["breast"]
    h = K["head"]
    neck = K["neck_len"]
    # (the neck from its base up to under the skull)
    nb = Vector(NECK_BASE)
    hd = Vector(h)
    balls = [
        # The body: deep in the breast, the back sloping to the rump.
        ((0.0, 0.158, 0.048), 0.05 * b, (1.0, 1.02, 1.08)),
        ((0.0, 0.135, 0.0), 0.052 * b, (1.04, 1.0, 1.15)),
        ((0.0, 0.142, -0.055), 0.044, (1.0, 0.95, 1.2)),
        ((0.0, 0.135, -0.092), 0.028, (1.0, 0.9, 1.1)),
        ((0.028, 0.168, 0.034), 0.03), ((-0.028, 0.168, 0.034), 0.03),
        ((0.0, 0.112, -0.03), 0.04, (1.05, 1.0, 1.2)),
    ]
    for k in range(4):
        t = (k + 0.5) / 4.0
        p = nb.lerp(hd + Vector((0.0, -0.016, -0.014)), t)
        balls.append(((p.x, p.y, p.z), 0.03 - 0.008 * t))
    balls.append((K["head"], K["skull"], K["skull_stretch"]))
    balls.append(K["forehead"])
    return balls


def body_part():
    body = blobs("body", body_balls(), L(1400, 520))
    body.data.materials.append(mat("down"))
    return body


def surface_hit(tree, origin, toward):
    hit, normal, _, _ = tree.ray_cast(B(origin), B((toward - origin).normalized()))
    if hit is None:
        return None, None
    return G(hit), G(normal).normalized()


def jay_region(at, default):
    """The blue jay's pattern on the head and neck: the black necklace and the
    bridle through the eye, the white face and throat."""
    if K is not KINDS["blue_jay"]:
        return default
    s = K["size"]
    hd = head()
    rel = (at - hd) / s
    # The necklace: a ring round the neck, high at the nape (under the crest)
    # and low in front (across the upper breast), passing behind the cheeks.
    ring_n = Vector((0.0, 0.62, 0.78)).normalized()
    centre = Vector((0.0, -0.032, -0.012))
    dist = (rel - centre).dot(ring_n)
    if abs(dist) < 0.0075 and rel.y < 0.006:
        return NECKLACE
    # The bridle: from the base of the bill back through the eye.
    if rel.z > -0.005 and rel.z < 0.04 and abs(rel.y - 0.004 - (rel.z - 0.012) * 0.25) < 0.0045 and abs(rel.x) > 0.008:
        return BRIDLE
    if dist < -0.0075 and rel.z > -0.04:
        return UNDER
    if dist > 0.0075 and rel.y < -0.0 and rel.z > -0.012:
        return FACE
    return default


def body_feathers(tree):
    """Contour feathers over the body, in rings round its length from the
    breast to the rump, each laid on the surface pointing back (down on the
    breast's front), and scapulars over the shoulders."""
    part = Part("feathers", "feather")
    s = K["size"]
    axis_from = S((0.0, 0.16, 0.085))
    axis_to = S((0.0, 0.14, -0.1))
    rows = L(16, 9)
    for r in range(rows):
        u = (r + 0.5) / rows
        middle = axis_from.lerp(axis_to, u)
        around = L(20, 12)
        for k in range(around):
            a = math.tau * (k + 0.5 * (r % 2)) / around
            out = V(math.sin(a), math.cos(a), 0.0)
            at, nrm = surface_hit(tree, middle + out * 0.3 * s, middle)
            if at is None:
                continue
            below = -out.y
            flow = V(0.0, -0.35 - 0.5 * max(below, 0.0), -1.0)
            if nrm.z > 0.6:
                flow = V(0.0, -1.0, -0.3)
            flow = flow - nrm * flow.dot(nrm)
            if flow.length < 0.05:
                flow = V(0.0, -1.0, 0.0)
            flow = (flow.normalized() + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.08, 0.08), rng.uniform(-0.1, 0.1)))).normalized()
            length = (0.044 + 0.008 * max(below, 0.0)) * rng.uniform(0.9, 1.12) * s
            width = 0.036 * rng.uniform(0.9, 1.1) * s
            on_back = out.y > 0.25 and at.z < 0.05 * s
            region = BACK if on_back else UNDER
            if at.z < -0.075 * s and on_back:
                region = RUMP
            region = jay_region(at, region)
            feather(part, at - nrm * 0.002 * s, flow, nrm, length, width, region, "round",
                    lift=0.03 + 0.04 * max(below, 0.0) + rng.uniform(0.0, 0.03), cup=0.12, twist=rng.uniform(-0.12, 0.12), rows=2)
    # The breast's front, down from the throat: shingled, the higher over the lower.
    for row in range(L(7, 4)):
        y = (0.19 - row * 0.014) * s
        for k in range(L(5, 3)):
            x = ((k - 2) * 0.016 + (0.008 if row % 2 else 0.0)) * s
            at, nrm = surface_hit(tree, V(x, y, 0.4 * s), V(x, y, 0.0))
            if at is None or nrm.z < 0.4:
                continue
            flow = V(0.0, -1.0, -0.25)
            flow = (flow - nrm * flow.dot(nrm)).normalized()
            flow = (flow + V(rng.uniform(-0.2, 0.2), 0.0, 0.0)).normalized()
            feather(part, at - nrm * 0.002 * s, flow, nrm, 0.036 * rng.uniform(0.9, 1.15) * s, 0.03 * s, jay_region(at, UNDER), "round",
                    lift=0.05, cup=0.12, rows=2, twist=rng.uniform(-0.12, 0.12))
    # Scapulars: a cape of long feathers from the shoulders back over the
    # folded wing's top edge.
    for side in (1.0, -1.0):
        for row in range(L(3, 2)):
            for k in range(L(5, 3)):
                z = (0.045 - 0.02 * k - 0.006 * row) * s
                x = side * (0.012 + 0.009 * row) * s
                origin = V(x * 4.0, 0.3 * s, z)
                at, nrm = surface_hit(tree, origin, V(0.0, 0.14 * s, z))
                if at is None:
                    continue
                flow = V(side * 0.08, -0.25, -1.0)
                flow = (flow - nrm * flow.dot(nrm)).normalized()
                feather(part, at - nrm * 0.002 * s, flow, nrm, (0.052 + 0.006 * row) * s, 0.034 * s, SCAPULAR, "round",
                        lift=0.03, cup=0.1, rows=2, twist=side * 0.1)
    return part


def neck_head_feathers(tree):
    """Feathers on the neck (rings from the shoulders up) and the head (from
    the bill back over the crown and the nape, down the cheeks and throat),
    small and close, flowing back; they go with the head as the neck bends."""
    part = Part("feathers_neck", "feather")
    s = K["size"]
    hd = head()
    nb = S(NECK_BASE)
    rings = L(8, 4)
    for r in range(rings):
        u = r / max(rings - 1, 1)
        middle = nb.lerp(hd + S((0.0, -0.012, -0.012)), 0.1 + 0.8 * u)
        around = L(16, 10)
        for k in range(around):
            a = math.tau * (k + 0.5 * (r % 2)) / around
            out = V(math.sin(a), math.cos(a) * 0.35, math.cos(a)).normalized()
            out = V(math.sin(a), 0.0, math.cos(a))
            at, nrm = surface_hit(tree, middle + out * 0.2 * s, middle)
            if at is None:
                continue
            down = (nb - hd).normalized()
            if out.z > 0.4:
                down = V(0.0, -1.0, 0.25)
            down = (down - nrm * down.dot(nrm)).normalized()
            down = (down + V(rng.uniform(-0.15, 0.15), 0.0, rng.uniform(-0.1, 0.1))).normalized()
            region = jay_region(at, THROAT if out.z > 0.3 else CROWN)
            if region == THROAT and K["throat_hackles"] == 0:
                region = jay_region(at, UNDER)
            feather(part, at - nrm * 0.002 * s, down, nrm, (0.03 + 0.008 * (1 - u)) * s * rng.uniform(0.9, 1.1), 0.026 * s, region, "round",
                    lift=0.04, cup=0.1, rows=2, twist=rng.uniform(-0.12, 0.12))
    # The head: points over it, each ray-cast in from outside, the feather laid
    # back along the surface.
    count = L(190, 60)
    for k in range(count):
        # (a spiral over the head, from the bill round to the nape)
        t = (k + 0.5) / count
        yaw = math.tau * k * 0.618034
        pitch = math.acos(1.0 - 1.6 * t)
        out = V(math.sin(pitch) * math.sin(yaw), math.cos(pitch), math.sin(pitch) * math.cos(yaw) * 0.9 + 0.35)
        out = out.normalized()
        at, nrm = surface_hit(tree, hd + out * 0.15 * s, hd)
        if at is None:
            continue
        rel = (at - hd) / s
        # (none on the bill's root, under the bristles, nor round the eye itself)
        if rel.z > 0.03:
            continue
        flow = V(0.0, -0.15, -1.0) if rel.y > -0.008 else V(0.0, -0.8, -0.55)
        flow = (flow - nrm * flow.dot(nrm))
        if flow.length < 0.05:
            continue
        flow = (flow.normalized() + V(rng.uniform(-0.15, 0.15), 0.0, 0.0)).normalized()
        region = CROWN if rel.y > -0.006 else FACE
        region = jay_region(at, region)
        if region == FACE and K is not KINDS["blue_jay"]:
            region = CROWN
        feather(part, at - nrm * 0.0015 * s, flow, nrm, 0.022 * s * rng.uniform(0.9, 1.15), 0.018 * s, region, "round",
                lift=0.04, cup=0.08, rows=2)
    return part


def bristles(tree):
    """The nasal bristles (stiff narrow feathers lying forward over the base of
    the bill), the raven's throat hackles, the jay's crest."""
    part = Part("bristles", "feather")
    s = K["size"]
    hd = head()
    bill = K["bill"]
    base = hd + S((0.0, -0.002, 0.026))
    for k in range(L(K["bristles"], max(4, K["bristles"] // 2))):
        u = (k + 0.5) / K["bristles"] if not LOW else (k + 0.5) / max(4, K["bristles"] // 2)
        a = (u - 0.5) * 2.6
        root = base + S((math.sin(a) * 0.0085, 0.006 + 0.004 * math.cos(a), -0.004))
        d = V(math.sin(a) * 0.12, -0.12 - 0.05 * abs(math.sin(a)), 1.0).normalized()
        n = V(math.sin(a), math.cos(a), 0.0)
        feather(part, root, d, n, bill["length"] * 0.36 * s * rng.uniform(0.9, 1.1), 0.006 * s, NASAL, "lance",
                lift=-0.06, cup=0.05, rows=2)
    # The raven's hackles: long, pointed, lying down the throat and standing a
    # little off it, shaggy.
    for k in range(L(K["throat_hackles"], K["throat_hackles"] // 2)):
        row = k % 3
        a = (rng.random() - 0.5) * 1.9
        origin = hd + S((math.sin(a) * 0.05, -0.03 - 0.012 * row, 0.05))
        at, nrm = surface_hit(tree, origin, hd + S((0.0, -0.03 - 0.012 * row, -0.02)))
        if at is None:
            continue
        flow = V(0.0, -1.0, -0.45)
        flow = (flow - nrm * flow.dot(nrm)).normalized()
        flow = (flow + V(math.sin(a) * 0.15, 0.0, 0.0)).normalized()
        feather(part, at - nrm * 0.002 * s, flow, nrm, (0.036 + 0.008 * row) * s * rng.uniform(0.85, 1.15), 0.012 * s, THROAT, "lance",
                lift=0.16, cup=0.05, rows=3, twist=rng.uniform(-0.4, 0.4))
    # The jay's crest: long narrow feathers from the crown, swept up and back.
    crest = Part("crest", "feather")
    for k in range(L(K["crest"], max(K["crest"] // 2, 0))):
        n_all = K["crest"] if not LOW else max(K["crest"] // 2, 1)
        u = (k + 0.5) / n_all
        a = (rng.random() - 0.5) * 1.4
        root = hd + S((math.sin(a) * 0.012, 0.022 + 0.003 * math.cos(a), 0.016 - 0.026 * u))
        d = V(math.sin(a) * 0.25, 0.75 - 0.5 * u, -1.0).normalized()
        n = V(math.sin(a), 1.0, 0.4).normalized()
        feather(crest, root, d, n, (0.034 + 0.024 * math.sin(math.pi * min(u * 1.1, 1.0))) * s, 0.015 * s, CREST, "lance",
                lift=0.0, bend=-0.08, cup=0.08, rows=3, twist=rng.uniform(-0.3, 0.3))
    return [part, crest]


def tail():
    """Twelve rectrices from the tail's root, closed (the central pair on top,
    each pair outward a layer under), with their coverts over the root."""
    part = Part("tail", "feather")
    s = K["size"]
    t = K["tail"]
    root0 = S(TAIL_ROOT)
    droop = t["droop"]
    d0 = V(0.0, -math.sin(droop), -math.cos(droop))
    count = 6
    for side in (1.0, -1.0):
        for k in range(count):
            u = (k + 0.5) / count
            across = 0.5 + 0.5 * side * u
            d = (d0 + V(side * 0.035 * u, 0.0, 0.0)).normalized()
            n = V(0.0, math.cos(droop), -math.sin(droop))
            root = root0 + S((side * (0.003 + 0.008 * u), -0.002 * k, 0.003 * k))
            length = t["length"] * (1.0 - t["graduation"] * u ** 1.4) * s * rng.uniform(0.98, 1.02)
            feather(part, root, d, n, length, t["width"] * s, TAIL, "broad", rows=5, tag=across,
                    lift=0.0, bend=0.03, cup=-0.04, twist=side * 0.04)
    # Upper tail coverts over the root, and under tail coverts beneath it.
    covers = Part("tail_coverts", "feather")
    for under in (False, True):
        for k in range(L(7, 4)):
            u = (k + 0.5) / L(7, 4) * 2.0 - 1.0
            root = root0 + S((u * 0.014, -0.016 if under else 0.006, 0.02))
            d = (d0 + V(u * 0.1, 0.12 if under else -0.05, 0.0)).normalized()
            n = V(0.0, -1.0 if under else 1.0, -0.3)
            feather(covers, root, d, n, t["length"] * (0.36 if under else 0.42) * s, 0.034 * s, UNDER if under else RUMP, "round",
                    lift=0.05, cup=0.12, rows=2, tag=0.5 + 0.5 * u)
    return [part, covers]


def rot_x(v, a):
    c, si = math.cos(a), math.sin(a)
    return Vector((v.x, v.y * c - v.z * si, v.y * si + v.z * c))


def wing(side, tree):
    """A wing in its three bones' pieces, folded against the flank and (the
    shape key) spread. See the module's notes."""
    s = K["size"]
    name = "l" if side > 0 else "r"
    pieces = {bone: Part("wing_%s_%s" % (name, bone), "feather") for bone in ("arm", "fore", "hand")}
    sh = S(SHOULDER)
    # The spread wing's joints, in the level frame, from the shoulder.
    E = V(K["elbow"], 0.0, -0.012) * s
    W = V(K["wrist"], 0.002, 0.004) * s
    H = V(K["hand"], 0.0, -0.006) * s

    def mx(p):
        return V(p.x * side, p.y, p.z)

    def level_to_rest(p):
        """A point of the level wing (from the shoulder) to where it is on the standing bird."""
        return sh + rot_x(p, -FLIGHT_PITCH)

    def flank(p, layer):
        """`p` (on the +X side, crow units) put on the body's surface, `layer` out from it, and the way out there."""
        p = S(p)
        at, out = surface_hit(tree, V(0.4 * s, p.y, p.z), V(0.0, p.y, p.z))
        if at is None or at.z < -0.09 * s:
            # (behind the body: over the rump and tail, closing in to meet over it)
            behind = min(max((-p.z / s - 0.08) / 0.13, 0.0), 1.0)
            return V((0.034 - 0.024 * behind) * s + layer, p.y, p.z), V(1.0, 0.25, 0.0).normalized()
        return at + out * layer, out

    def bone_of(x):
        return "arm" if x < E.x - 0.004 * s else ("fore" if x < W.x - 0.002 * s else "hand")

    def add(fold_root, fold_aim, layer, root_o, d_o, length, width, region, kind, bone=None, y_o=0.0, tag=None, **shape):
        """One feather: folded at `fold_root` (crow units, on the flank,
        `layer` out from it) pointing `fold_aim`; spread at `root_o` (level
        frame, from the shoulder, `y_o` up) pointing `d_o`."""
        root_f, n_f = flank(fold_root, layer)
        tip_f, _ = flank(Vector(fold_root) + Vector(fold_aim).normalized() * length / s, layer + 0.004 * s)
        d_f = tip_f - root_f
        ro = level_to_rest(root_o + V(0.0, y_o, 0.0))
        do = rot_x(d_o, -FLIGHT_PITCH)
        no = rot_x(V(0.0, 1.0, 0.0), -FLIGHT_PITCH)
        if side < 0:
            root_f, d_f, n_f = mx(root_f), mx(d_f), mx(n_f)
            ro, do, no = mx(ro), mx(do), mx(no)
            if "skew" in shape:
                shape["skew"] = -shape["skew"]
            if "twist" in shape:
                shape["twist"] = -shape["twist"]
        piece = pieces[bone or bone_of(root_o.x)]
        feather(piece, root_f, d_f, n_f, length, width, region, kind, open_frame=(ro, do, no), tag=tag, **shape)

    prim = K["primaries"]
    sec = K["secondary"]
    # Primaries, from the inner (P1, by the wrist) out to the outer (P10, at
    # the hand's tip). Spread they fan from pointing back to pointing out, the
    # inner over the outer; folded they lie under the secondaries, the outer
    # lowest, reaching back over the rump.
    for j in range(10):
        u = j / 9.0
        root_o = W.lerp(H, u) + V(0.0, 0.0, -0.004 * s)
        a = 0.22 + 1.2 * u ** 1.15
        d_o = V(math.sin(a), 0.0, -math.cos(a))
        length = prim[j] * s
        fold_root = V(0.044, 0.152 - 0.002 * u, 0.024 - 0.042 * u)
        notch = 1.0 if j >= 10 - K["notched"] else 0.0
        add(fold_root, V(0.0, -0.14, -1.0), (0.002 + 0.0005 * (9 - j)) * s, root_o, d_o, length, 0.036 * s * (1.0 - 0.12 * u), PRIMARY,
            "flight", bone="hand", y_o=-0.0015 * s - 0.0006 * j * s, tag=u, lift=0.0, bend=-0.025, cup=0.05, rows=4, skew=0.35,
            notch=notch, twist=0.05)
    # Secondaries, along the forearm from the wrist in to the elbow: spread,
    # pointing back, the inner over the outer; folded, along the top of the flank.
    for j in range(10):
        u = j / 9.0
        root_o = W.lerp(E, u) + V(0.0, 0.0, -0.003 * s)
        a = 0.2 - 0.26 * u
        d_o = V(math.sin(a), 0.0, -math.cos(a))
        fold_root = V(0.046, 0.164 - 0.002 * u, 0.034 - 0.07 * u)
        add(fold_root, V(0.0, -0.2, -1.0), (0.0055 + 0.0005 * j) * s, root_o, d_o, sec * (1.0 - 0.06 * u) * s, 0.038 * s, SECONDARY,
            "flight", bone="fore", y_o=0.0005 * j * s, lift=0.0, bend=-0.02, cup=0.07, rows=3, skew=0.18)
    # Tertials: at the elbow, broad, lying back over the inner secondaries.
    for j in range(3):
        u = j / 2.0
        root_o = E.lerp(V(0.03, 0.0, -0.02) * s, 0.3 + 0.35 * u)
        d_o = V(-0.12 - 0.1 * u, 0.0, -1.0).normalized()
        fold_root = V(0.04 - 0.004 * j, 0.168, -0.034 - 0.012 * j)
        add(fold_root, V(-0.1, -0.12, -1.0), (0.011 + 0.0015 * j) * s, root_o, d_o, sec * 0.88 * s, 0.042 * s, TERTIAL,
            "flight", bone="arm", y_o=(0.006 + 0.001 * j) * s, lift=0.0, cup=0.08, rows=3, skew=0.0)
    # Greater coverts over the secondaries' roots, then median and lesser
    # coverts in rows up to the leading edge (from the shoulder to the wrist),
    # the primary coverts over the primaries' roots and the alula at the wrist.
    for row, (length, width, forward, lay) in enumerate(((0.06, 0.04, 0.016, 0.007), (0.044, 0.036, 0.028, 0.01), (0.032, 0.03, 0.038, 0.013), (0.024, 0.024, 0.045, 0.015))):
        count = L(14, 8) - row
        for j in range(count):
            u = j / (count - 1)
            start = W + V(0.0, 0.0, forward * s * 0.6)
            end = V(0.012, 0.0, -0.008 + forward * 0.55) * s
            root_o = start.lerp(end, u) + V(0.0, 0.0, forward * s * 0.4)
            d_o = V(0.08 - 0.12 * u, 0.0, -1.0).normalized()
            fold_root = V(0.046, 0.166 + 0.005 * row, 0.038 - 0.07 * u + 0.004 * row)
            add(fold_root, V(0.0, -0.25, -1.0), (0.0105 + 0.002 * row) * s, root_o, d_o, length * s, width * s, COVERT, "round",
                y_o=lay * s, lift=0.08, cup=0.12, rows=2)
    for j in range(L(8, 5)):
        u = j / (L(8, 5) - 1)
        root_o = W.lerp(H, u * 0.85) + V(0.0, 0.0, 0.012 * s)
        a = 0.35 + 1.0 * u
        d_o = V(math.sin(a), 0.0, -math.cos(a))
        fold_root = V(0.046, 0.158, 0.03 - 0.03 * u)
        add(fold_root, V(0.0, -0.18, -1.0), 0.008 * s, root_o, d_o, 0.056 * s, 0.028 * s, COVERT, "round", bone="hand",
            y_o=0.004 * s, lift=0.06, cup=0.1, rows=2)
    for j in range(3):
        root_o = W + V(0.004 * j, 0.0, 0.016) * s
        d_o = V(0.55, 0.0, -0.84).normalized()
        add(V(0.047, 0.172, 0.044 - 0.004 * j), V(0.0, -0.3, -1.0), 0.016 * s, root_o, d_o, (0.04 - 0.006 * j) * s, 0.012 * s, COVERT, "lance",
            bone="hand", y_o=0.011 * s, lift=0.02, cup=0.05, rows=2)
    # The core: skin and bone along the leading edge, from the shoulder to the
    # hand's tip, a thin round-nosed blade under the coverts. Folded, it shrinks
    # away inside the body.
    core = Part("wing_%s_core" % name, "down")
    line_o = [V(0.004, 0.0, 0.004) * s, E + V(0.0, 0.0, 0.016) * s, W + V(0.0, 0.0, 0.018) * s, H + V(0.0, 0.0, 0.006) * s]
    fine = []
    for i in range(len(line_o) - 1):
        for k in range(3):
            fine.append(line_o[i].lerp(line_o[i + 1], k / 3.0))
    fine.append(line_o[-1])
    radii = [(0.018 if i < 7 else 0.018 - 0.0016 * (i - 6)) * s for i in range(len(fine))]
    level = [level_to_rest(p) for p in fine]
    inside = [S((0.022, 0.158, 0.02)) + (p - level[0]) * 0.08 for p in level]
    if side < 0:
        level = [mx(p) for p in level]
        inside = [mx(p) for p in inside]
    tube(core, inside, radii, sides=6, cap_end=True, cap_start=True, squash=0.3, up=V(0, 1, 0), open_line=level, open_up=rot_x(V(0, 1, 0), -FLIGHT_PITCH))
    return list(pieces.values()) + [core]


def leg(side):
    """A leg: the feathered tibia down to the hock, the scaled tarsus and the toes."""
    s = K["size"]
    tl = K["tarsus"]
    k = S((KNEE[0] * side, KNEE[1], KNEE[2]))
    a = S((HOCK[0] * side, HOCK[1] * tl, HOCK[2]))
    f = S((FOOT[0] * side, FOOT[1], FOOT[2]))
    name = "l" if side > 0 else "r"
    thigh = Part("thigh_" + name, "feather")
    down = (a - k).normalized()
    side_v = down.cross(V(0, 0, 1)).normalized()
    front_v = side_v.cross(down).normalized()
    for r in range(L(3, 2)):
        u = r / 3.0
        centre = k.lerp(a, 0.05 + 0.62 * u)
        radius = 0.016 * s * (1.0 - 0.45 * u)
        for q in range(L(7, 5)):
            ang = math.tau * (q + 0.5 * (r % 2)) / L(7, 5)
            out = side_v * math.cos(ang) + front_v * math.sin(ang)
            d = (down + out * 0.12 + V(0, 0, -0.06)).normalized()
            feather(thigh, centre + out * radius, d, out, rng.uniform(0.026, 0.032) * s, 0.02 * s, UNDER, "round", lift=0.16, cup=0.16, rows=2)
    ball(thigh, k.lerp(a, 0.4), (0.014 * s, 0.014 * s, 0.03 * s), 7, 4, axis=down, uv2=(0.5, (UNDER + 0.5) / 16.0))
    shank = Part("shank_" + name, "leg")
    steps = L(6, 3)
    line = [a.lerp(f + V(0, 0.004 * s, 0), t / float(steps)) for t in range(steps + 1)]
    radii = [(0.0042 - 0.0006 * (t / float(steps))) * s for t in range(steps + 1)]
    radii[0] = 0.0055 * s
    tube(shank, line, radii, sides=6, cap_end=False, cap_start=True, squash=0.85, up=V(side, 0, 0))
    ball(shank, a + V(0, 0.001, -0.0015) * s, (0.0055 * s, 0.0055 * s, 0.0065 * s), 6, 4)
    toes = Part("toes_" + name, "leg")
    claws = Part("claws_" + name, "claw")
    for (turn, length, joints) in ((0.0, 0.036, 3), (0.42, 0.027, 3), (-0.42, 0.029, 3), (math.pi, 0.03, 2)):
        ang = turn * side
        d = V(math.sin(ang), 0.0, math.cos(ang))
        if turn == math.pi:
            d = V(0.1 * side, 0.0, -1.0).normalized()
        start = V(f.x, 0.0035 * s, f.z)
        pts = []
        rad = []
        n_seg = L(joints * 2, joints)
        for j in range(n_seg + 1):
            t = j / float(n_seg)
            pts.append(start + d * length * s * t + V(0, (0.0012 * math.sin(math.pi * t) - 0.0015 * t) * s, 0))
            rad.append((0.0032 - 0.0012 * t) * s * (1.1 if j % 2 == 0 else 0.95))
        tube(toes, pts, rad, sides=5, cap_end=False, squash=0.75, up=V(0, 1, 0))
        nail = pts[-1]
        tube(claws, [nail, nail + d * 0.006 * s + V(0, -0.001, 0) * s, nail + d * 0.009 * s + V(0, -0.0045, 0) * s], [0.0022 * s, 0.0015 * s, 0.0004 * s], sides=4)
    ball(toes, V(f.x, 0.004 * s, f.z), (0.006 * s, 0.0038 * s, 0.006 * s), 6, 4, axis=V(0, 1, 0))
    return [thigh, shank, toes, claws]


def beak():
    """The upper mandible (deep at the base, the culmen arched down to a
    point), the lower under it, and the inside of the mouth between."""
    upper = Part("beak", "beak")
    lower = Part("jaw", "beak")
    mouth = Part("mouth", "mouth")
    s = K["size"]
    hd = head()
    b = K["bill"]
    base = hd + S((0.0, -0.003, 0.024))
    rows = L(7, 4)
    sides = L(10, 6)
    for part, top in ((upper, True), (lower, False)):
        rings = []
        for r in range(rows + 1):
            t = r / rows
            width = b["width"] * 0.5 * (1.0 - t) ** 0.75 * s + 0.0006 * s
            depth = (b["depth"] * 0.62 if top else b["lower"]) * (1.0 - t) ** 0.7 * s + 0.0005 * s
            # (the lower mandible a little shorter, closing under the hooked tip)
            z = base.z + b["length"] * s * t * (1.0 if top else 0.9)
            # (the culmen arches down towards the tip; the lower follows under it)
            y = base.y - b["curve"] * s * t ** 2.2
            if not top:
                y -= 0.0012 * s + 0.0025 * s * t
            ring = []
            for k in range(sides):
                a = math.tau * k / sides
                cy = math.sin(a)
                if top:
                    cy = cy * depth if cy > 0 else cy * 0.0012 * s
                else:
                    cy = cy * 0.0012 * s if cy > 0 else cy * depth
                ring.append(part.v((math.cos(a) * width, y + cy, z), (k / sides, t)))
            rings.append(ring)
        for r in range(rows):
            for k in range(sides):
                a, c = rings[r][k], rings[r][(k + 1) % sides]
                d, e = rings[r + 1][(k + 1) % sides], rings[r + 1][k]
                part.f([a, c, d, e])
        drop = b["curve"] * s * (1.12 if top else 0.8) + (0.0 if top else 0.0025 * s)
        tip = part.v((0.0, base.y - drop - 0.0008 * s, base.z + b["length"] * s * (1.02 if top else 0.91)), (0.0, 1.0))
        for k in range(sides):
            part.f([rings[-1][k], rings[-1][(k + 1) % sides], tip])
        # (closing the back)
        back = part.v((0.0, base.y + (0.004 if top else -0.004) * s, base.z - 0.004 * s), (0.0, 0.0))
        for k in range(sides):
            part.f([rings[0][(k + 1) % sides], rings[0][k], back])
    # The mouth: a dark tongue lying in the lower mandible.
    for r in range(L(4, 2)):
        t0 = r / L(4, 2)
        t1 = (r + 1) / L(4, 2)
        for t in (t0,):
            pass
    pts = []
    for r in range(L(4, 2) + 1):
        t = r / L(4, 2) * 0.7
        w = b["width"] * 0.36 * (1.0 - t) * s
        y = base.y - b["curve"] * s * t ** 2.2 - 0.0008 * s
        z = base.z + b["length"] * s * t
        pts.append(((-w, y, z), (w, y, z)))
    idx = []
    for (l, r) in pts:
        idx.append((mouth.v(l, (0.0, 0.0)), mouth.v(r, (1.0, 0.0))))
    for i in range(len(idx) - 1):
        mouth.f([idx[i][0], idx[i + 1][0], idx[i + 1][1], idx[i][1]])
    return [upper, lower, mouth]


def eyes():
    part = Part("eye", "eye")
    s = K["size"]
    hd = head()
    for side in (1.0, -1.0):
        axis = V(side, 0.06, 0.32).normalized()
        ball(part, hd + S((side * K["skull"] * 0.72, 0.006, 0.012)), (0.0058 * s, 0.0058 * s, 0.004 * s), 8, 5, axis=axis, polar_uv=True)
    return part


def joints():
    """Empties at the joints the shader poses about (see the module's notes)."""
    s = K["size"]
    hd = head()
    marks = {
        "hip": S(HIP), "knee": S(KNEE), "hock": S((HOCK[0], HOCK[1] * K["tarsus"], HOCK[2])), "foot": S(FOOT),
        "neck": S(NECK_BASE), "head": hd, "hinge": hd + S((0.0, -0.004, 0.022)),
        "crest": hd + S((0.0, 0.022, 0.0)), "tail": S(TAIL_ROOT), "shoulder": S(SHOULDER),
        "elbow": V(K["elbow"], 0.0, -0.012) * s, "wrist": V(K["wrist"], 0.002, 0.004) * s, "tip": V(K["hand"], 0.0, -0.006) * s,
        "beak_tip": hd + S((0.0, -0.003 - K["bill"]["curve"], 0.024 + K["bill"]["length"])),
    }
    made = []
    for key, at in marks.items():
        empty = bpy.data.objects.new("joint_" + key, None)
        empty.location = B(at)
        bpy.context.scene.collection.objects.link(empty)
        made.append(empty)
    meta = bpy.data.objects.new("meta_flight_pitch", None)
    meta.location = B(V(FLIGHT_PITCH, 0.0, 0.0))
    bpy.context.scene.collection.objects.link(meta)
    made.append(meta)
    return made


def build(kind, out):
    clear()
    MATERIALS.clear()
    made = []
    body = body_part()
    made.append(body)
    tree = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    parts = [body_feathers(tree), neck_head_feathers(tree)] + bristles(tree) + tail()
    for side in (1.0, -1.0):
        parts.extend(leg(side))
    parts += [eyes()] + beak()
    for part in parts:
        if part.points:
            made.append(part.make())
    for side in (1.0, -1.0):
        for piece in wing(side, tree):
            made.append(piece.make(with_open=True))
    triangles = 0
    bpy.ops.object.select_all(action="DESELECT")
    for thing in made:
        count = sum(len(p.vertices) - 2 for p in thing.data.polygons)
        triangles += count
        thing.select_set(True)
    for empty in joints():
        empty.select_set(True)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_animations=False,
                              use_selection=True, export_morph=True, export_morph_normal=True, export_apply=False)
    print("BUILT %s: %d triangles in %d objects -> %s" % (kind, triangles, len(made), out))
    return made


def previews(folder, made, kind):
    """Flat pictures from Blender: side, front, three quarters, back, the head."""
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 700
    scene.render.resolution_y = 700
    for thing in made:
        name = thing.name
        tint = (0.3, 0.3, 0.32, 1)
        if name.startswith("wing"):
            tint = (0.25, 0.35, 0.6, 1) if "hand" in name else ((0.3, 0.55, 0.35, 1) if "fore" in name else (0.6, 0.4, 0.3, 1))
        elif name.startswith("tail"):
            tint = (0.55, 0.5, 0.3, 1)
        elif name in ("beak", "jaw"):
            tint = (0.1, 0.1, 0.1, 1)
        elif name == "body":
            tint = (0.6, 0.2, 0.2, 1)
        thing.color = tint
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 85
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    s = K["size"]
    target = B(V(0.0, 0.15 * s, -0.02 * s))
    for view, offset in (("side", V(1.4, 0.2, 0.0)), ("front", V(0.0, 0.2, 1.4)), ("three_quarter", V(1.0, 0.45, 1.0)), ("back", V(-0.6, 0.6, -1.2)), ("top", V(0.0, 1.5, -0.05))):
        where = target + B(offset * s)
        cam.location = where
        direction = target - where
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (kind, view))
        bpy.ops.render.render(write_still=True)
    # The wing spread (the shape key at full), from above.
    for thing in made:
        if thing.data.shape_keys:
            thing.data.shape_keys.key_blocks["open"].value = 1.0
    where = target + B(V(0.0, 1.6, -0.1) * s)
    cam.location = where
    cam.rotation_euler = (target - where).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(folder, "%s_spread_top.png" % kind)
    bpy.ops.render.render(write_still=True)
    where = target + B(V(0.0, 0.1, 1.6) * s)
    cam.location = where
    cam.rotation_euler = (target - where).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(folder, "%s_spread_front.png" % kind)
    bpy.ops.render.render(write_still=True)


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = args[1].split(",") if len(args) > 1 else list(KINDS.keys())
for kind_name in only:
    K = KINDS[kind_name]
    for low in (True, False):
        LOW = low
        rng.seed(7)
        made_now = build(kind_name, K["out"] + ("_lo.glb" if low else ".glb"))
        if args and not low:
            previews(args[0], made_now, kind_name)
