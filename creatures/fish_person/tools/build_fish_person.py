"""Builds the fish person and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/fish_person/tools/build_fish_person.py [-- <folder for preview renders>]

(Set FISH_ONLY_FULL=1 to build only the full model, to look at it quicker.)

Writes creatures/fish_person/models/fish_person.glb and fish_person_lo.glb (and
editable .blend copies beside this file, which are not kept: this folder has a
.gdignore so that Godot does not try to import them).

A deep one, out of Innsmouth: a man gone over to the sea. Taller than a man and
stooped, on the boy's bones and bone names (so CharacterRig, and FishPersonRig
on it, can move it), with three more of its own: `jaw`, which hinges the lower
jaw from the back corners of the mouth, and `gill0`..`gill2` each side, the
flaps of its gills.

- A bulbous fish's head on a thick neck that is hardly a neck at all: a low
  sloping brow and crown, round glassy eyes set wide on mounds at the sides,
  two slits for a nose, and a mouth right across the front of it, lipless and
  downturned, with an underbite. Needle teeth all round both jaws, a few of
  the lower ones long enough to stand outside the upper lip when it is shut.
  Inside it, dark.
- Three gill slits down each side of the neck behind the jaw, each with a flap
  of skin over it that the rig lifts.
- A barrel of a body with a paunch, a hump of a back and sloping shoulders; a
  dorsal fin, a ragged membrane between spines, from the crown of the head
  over the back of the neck and down the spine; long arms with webbed,
  long-fingered, clawed hands; thick legs; long flat feet with four webbed toes.

It is all one skin material, the regions of it told apart by the model's vertex
colour (see `shaded`): r how far a point lies in a hollow (dark over 0.5, as
the ghoul's is), g how pale it is (the belly, the throat; 1 for teeth), b what
it is (0 scaled skin, 0.33 smooth, 0.66 fin and web, 1 tooth or claw). Its rest
position goes with it as its texture coordinates (UV x, z; UV2 x: y), so that
FishPersonRig's shader can lay scales over it that do not slide as it moves.
It is all one material (one draw): its eyes, the dark of its mouth and gills,
its teeth and claws are told apart by the vertex colour too (b 1, g says which).

As the ghoul is, it is modelled with its arms held out from its sides
(ARM_REST), in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
GAME = os.path.dirname(os.path.dirname(COMPONENT))
sys.path.insert(0, os.path.join(GAME, "tools"))
import build_character as kit  # noqa: E402  (the character controller's shape-building and export tools)

# (it writes its model into the component, not the game's models/)
kit.ROOT = COMPONENT

# The colour attribute (see the top of this file).
CAVITY = "cavity"


class _Export:
    """bpy as the kit sees it, but for its glTF export: that also writes the
    model's colour attribute (CAVITY), which by default it leaves out unless a
    material uses it, and first lays each point's rest position on it as two
    sets of texture coordinates (see the top of this file)."""

    class _Scene:
        def gltf(self, **options):
            for mesh in bpy.data.meshes:
                if CAVITY in mesh.color_attributes:
                    mesh.color_attributes.active_color_name = CAVITY
                    mesh.color_attributes.render_color_index = mesh.color_attributes.find(CAVITY)
                if len(mesh.loops) == 0:
                    continue
                while len(mesh.uv_layers) > 0:
                    mesh.uv_layers.remove(mesh.uv_layers[0])
                across = mesh.uv_layers.new(name="rest_xz")
                up = mesh.uv_layers.new(name="rest_y")
                first, second = [], []
                for loop in mesh.loops:
                    co = mesh.vertices[loop.vertex_index].co
                    # (Godot's x and z; then its y)
                    first += [co.x, -co.y]
                    second += [co.z, 0.0]
                across.data.foreach_set("uv", first)
                up.data.foreach_set("uv", second)
                mesh.uv_layers.active = across
            options.setdefault("export_vertex_color", "ACTIVE")
            options.setdefault("export_all_vertex_colors", False)
            options.setdefault("export_texcoords", True)
            return bpy.ops.export_scene.gltf(**options)

    class _Ops:
        export_scene = None

        def __getattr__(self, name):
            return getattr(bpy.ops, name)

    def __init__(self):
        self.ops = _Export._Ops()
        self.ops.export_scene = _Export._Scene()

    def __getattr__(self, name):
        return getattr(bpy, name)


kit.bpy = _Export()
os.makedirs(os.path.join(COMPONENT, "tools"), exist_ok=True)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

# --- Joints ---

ANKLE_Y = 0.055
THIGH = 0.34
SHIN = 0.36
HIP_X = 0.085
HIP_Y = ANKLE_Y + THIGH + SHIN
KNEE_Y = HIP_Y - THIGH
HIPS = Vector((0.0, HIP_Y + 0.02, 0.0))
SPINE = Vector((0.0, 0.89, 0.0))
CHEST = Vector((0.0, 1.05, -0.005))
NECK = Vector((0.0, 1.19, 0.0))
HEAD = Vector((0.0, 1.262, 0.022))
# The hinge of the lower jaw, at the back corners of the mouth.
JAW = Vector((0.0, 1.276, 0.028))
SHOULDER = Vector((0.168, 1.15, -0.012))
UPPER_ARM = 0.31
FOREARM = 0.32
ARM_REST = 0.6
TOE = Vector((0.0, -0.045, 0.088))

SKIN = 0
# One material, so one surface (one draw, and its shadows): everything that is
# not skin (its eyes, the dark of its mouth and gills, teeth and claws) is told
# apart by the vertex colour and coloured by FishPersonRig's shader.
MATERIALS = [
    # Wet grey-green (paler on the belly, scaled: see FishPersonRig)
    ("skin", (0.19, 0.235, 0.205)),
]

# What a point is, as the model's vertex colour's b (see the top of this file).
SCALED, SMOOTH, FIN, HARD = 0.0, 0.33, 0.66, 1.0
# What a HARD point is, as its g: a claw (or a pupil), the dark of its mouth and gills, an eye, a tooth.
CLAW, MAW, GLASS, TOOTH = 0.0, 0.3, 0.55, 1.0

# Fingers, index to little: (offset across the palm, length, thickness, how far it fans out).
FINGERS = [(0.026, 0.136, 0.0099, 0.26), (0.0088, 0.152, 0.0104, 0.09), (-0.0088, 0.145, 0.0101, -0.09), (-0.026, 0.124, 0.0092, -0.26)]
KNUCKLES = (0.0, 0.42, 0.74)
PALM = 0.086
THUMB_LENGTH = 0.082
# How far along each finger the web between it and the next reaches (and between its middles).
WEB_REACH = (0.74, 0.52)

RNG = random.Random(7)

# Surfaces made so far that later parts sit on (for ray casts): "trunk", "head".
SURFACES = {}


def shoulder_of(side):
    return Vector((side * SHOULDER.x, SHOULDER.y, SHOULDER.z))


def arm_out(side):
    """Moves a point modelled on an arm hanging straight down out to the rest pose."""
    shoulder = shoulder_of(side)
    turn = Matrix.Rotation(side * ARM_REST, 3, "Z")
    return lambda p: shoulder + turn @ (p - shoulder)


def arm_in(side, p):
    shoulder = shoulder_of(side)
    return shoulder + Matrix.Rotation(-side * ARM_REST, 3, "Z") @ (p - shoulder)


def hand_wrist(side):
    return shoulder_of(side) + Vector((0.0, -UPPER_ARM - FOREARM, 0.002))


def finger_line(side, index):
    z, _length, _radius, fan = FINGERS[index]
    return hand_wrist(side) + Vector((0.0, -PALM, z)), Vector((0.0, -math.cos(fan), math.sin(fan)))


def thumb_line(side):
    inward = -side
    return hand_wrist(side) + Vector((inward * 0.004, -0.02, 0.024)), Vector((inward * 0.2, -0.7, 0.68)).normalized()


def smooth_rings(x, z, profile, band=0.018):
    """Rings for an upright tube (kit.lapped with no laps)."""
    return kit.lapped(x, z, profile, band, 0.0)


def profile_at(profile, y):
    """(half width, half depth, forward) of a profile at height `y`."""
    for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(profile, profile[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return rx0 + (rx1 - rx0) * t, rz0 + (rz1 - rz0) * t, z0 + (z1 - z0) * t
    return profile[-1][1], profile[-1][2], profile[-1][3]


def profile_of(profile, t):
    """(half thickness, half width, forward) of a limb's profile (LEG, ARM) `t` along it."""
    ordered = sorted(profile)
    for (t0, rx0, rz0, z0), (t1, rx1, rz1, z1) in zip(ordered, ordered[1:]):
        if t0 <= t <= t1:
            u = (t - t0) / (t1 - t0)
            return rx0 + (rx1 - rx0) * u, rz0 + (rz1 - rz0) * u, z0 + (z1 - z0) * u
    return ordered[-1][1], ordered[-1][2], ordered[-1][3]


def noise(p, size):
    """A smooth number about 0 (-1..1) over space, in swells `size` across."""
    q = p / size
    return (math.sin(q.x * 1.7 + 0.3) * math.sin(q.y * 1.3 + 1.1) * math.sin(q.z * 1.9 + 2.3)
            + 0.5 * math.sin(q.x * 3.1 + q.z * 2.3 + 0.7) * math.sin(q.y * 2.9 + 0.4)) / 1.5


def ribbon(b, points, widths, normals, thickness, segments=8):
    """A thin flat strip along a line of points, `widths` across it (half,
    measured along each point's side direction: normal x the line), lying
    flat on a surface whose normal at each point is in `normals`."""
    rings = []
    for i, point in enumerate(points):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        across = normals[i].cross(ahead).normalized()
        rings.append((point, across * widths[i], normals[i] * thickness))
    first = (points[0] - points[1]).normalized()
    last = (points[-1] - points[-2]).normalized()
    b.tube(kit.dome(rings[0], first, widths[0] * 0.6, 2)[::-1] + rings + kit.dome(rings[-1], last, widths[-1] * 0.6, 2), segments)


def web(b, line_a, line_b, reach, thickness, normal, rings=7, place=None):
    """A web of skin between two lines (fingers, toes), each given as a
    function from how far along it (0..1) to a point; it reaches `reach`
    (along the lines, along their middle) and its free edge dips between them."""
    loops = []
    count = rings
    for k in range(count + 1):
        s = 0.04 + 0.92 * k / count
        top = reach[0] + (reach[1] - reach[0]) * math.sin(math.pi * s) ** 0.8
        start = line_a(0.0).lerp(line_b(0.0), s)
        end = line_a(top).lerp(line_b(top), s)
        middle = (start + end) * 0.5
        loops.append((middle, (end - start) * 0.5, normal(middle) * thickness))
    across = (loops[-1][0] - loops[0][0]).normalized()
    b.tube(kit.dome(loops[0], -across, thickness, 1)[::-1] + loops + kit.dome(loops[-1], across, thickness, 1), 8)


# --- The vertex colour ---

def concavity(bm):
    """How far each point of a surface lies in a hollow: the mean of how far its
    neighbours stand out over it, along its normal, as a share of their
    distance; smoothed over its neighbours twice."""
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    value = []
    for vert in bm.verts:
        total, count = 0.0, 0
        for edge in vert.link_edges:
            other = edge.other_vert(vert)
            span = other.co - vert.co
            if span.length > 1e-7:
                total += span.dot(vert.normal) / span.length
                count += 1
        value.append(total / max(count, 1))
    for _pass in range(2):
        value = [(value[vert.index] + sum(value[edge.other_vert(vert).index] for edge in vert.link_edges)) / (1 + len(vert.link_edges)) for vert in bm.verts]
    return value


def shaded(shapes, fuse=None, threshold=0.05, extra=None, flat=None, paint=None, keep=None):
    """A part made by shapes, fused as `fuse` says, with its vertex colour on
    it (CAVITY): r how far each point lies in a hollow, 0.5 exactly where it
    sinks in by `threshold` (see concavity), more where it sinks in further,
    less where it stands out, or more again where `extra`, given a point,
    says (0..1); or all `flat`. g and b are what `paint`, given a point and
    its normal, says it is: (how pale, what it is). `keep` names the surface
    in SURFACES that later parts are laid on."""
    def made(b):
        ready = shapes(b)
        mesh = ready if ready is not None else kit.fused(b, None if kit.LOW else fuse)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        deep = concavity(bm) if flat is None else None
        bm.verts.ensure_lookup_table()
        colours = []
        for i, vert in enumerate(bm.verts):
            p = kit.from_blender(vert.co)
            n = kit.from_blender(vert.normal)
            if flat is not None:
                value = flat
            else:
                value = 0.0 if kit.LOW else min(max(0.5 + (deep[i] - threshold) / 0.03, 0.0), 1.0)
            if extra:
                value = max(value, extra(p))
            pale, kind = paint(p, n) if paint else (0.0, SCALED)
            colours.append((value, pale, kind))
        if keep:
            bm.faces.ensure_lookup_table()
            SURFACES[keep] = BVHTree.FromPolygons([kit.from_blender(v.co) for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces])
        bm.free()
        cavity = mesh.color_attributes.new(CAVITY, "FLOAT_COLOR", "POINT")
        for item, (r, g, kind) in zip(cavity.data, colours):
            item.color = (r, g, kind, 1.0)
        return mesh
    return made


def surface_hit(names, origin, direction):
    """Where a ray first meets any of the named surfaces, and the surface's normal there (Godot space)."""
    best = None
    for name in names:
        tree = SURFACES.get(name)
        if tree is None:
            continue
        hit = tree.ray_cast(origin, direction.normalized())
        if hit[0] is not None and (best is None or hit[3] < best[2]):
            best = (hit[0], hit[1], hit[3])
    if best is None:
        print("build_fish_person: nothing under", origin, "on", names)
        return origin, -direction.normalized()
    normal = best[1]
    if normal.dot(direction) > 0.0:
        normal = -normal
    return best[0], normal


def painted(pale=0.0, kind=SCALED):
    return lambda _p, _n: (pale, kind)


# --- The head ---
#
# A fish's head, long from the back of the skull to the snout, its brow
# sloping straight back from the upper lip to a low crown. It is lofted from
# slices across it, back to front. The cranium's floor is the roof of the
# mouth (flat, where the jaws meet: `mouth_y`); the lower jaw is a second
# loft whose top is that same line, so that the jaw can drop away from it.

# The cranium: (how far forward, its top, its half width).
CRANIUM = [(-0.045, 1.33, 0.056), (-0.02, 1.366, 0.074), (0.015, 1.39, 0.086), (0.055, 1.401, 0.09), (0.095, 1.394, 0.087),
           (0.13, 1.372, 0.079), (0.158, 1.347, 0.068), (0.18, 1.324, 0.054), (0.194, 1.309, 0.036), (0.201, 1.302, 0.018)]
# The lower jaw: (how far forward, its underside, its half width). It juts past the snout.
JAWBONE = [(-0.01, 1.24, 0.066), (0.03, 1.232, 0.082), (0.08, 1.236, 0.087), (0.13, 1.246, 0.082), (0.17, 1.26, 0.06),
           (0.196, 1.274, 0.04), (0.208, 1.284, 0.022), (0.213, 1.29, 0.01)]
# The eyes: where each is (the left's), the way it looks, and its size.
EYE_AT = Vector((0.0, 1.364, 0.104))
EYE_WAY = Vector((0.86, 0.12, 0.5)).normalized()
EYE_RADIUS = 0.024
# Small lumps on the cranium: (where, height, breadth).
WARTS = []
for _k in range(46):
    WARTS.append((Vector((RNG.uniform(-0.09, 0.09), RNG.uniform(1.33, 1.41), RNG.uniform(-0.03, 0.17))), RNG.uniform(0.0018, 0.0042), RNG.uniform(0.006, 0.012)))


# The head is made at the size above and then drawn this much bigger about the
# head joint (`grown`); what is worked out from a point of it is worked out
# from where that point was made (`ungrown`).
HEAD_GROWTH = 1.13


def grown(p):
    return HEAD + (p - HEAD) * HEAD_GROWTH


def ungrown(p):
    return HEAD + (p - HEAD) / HEAD_GROWTH


def mouth_y(z):
    """The height of the line where the jaws meet, `z` forward: highest at the
    front, falling well down to the corners (it is downturned)."""
    return JAW.y - 0.012 + 0.04 * blend(JAW.z, 0.2, z) ** 0.55


def sliced(slices, z):
    """(edge, half width) of a list of slices at `z`."""
    for (z0, e0, w0), (z1, e1, w1) in zip(slices, slices[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            t = t * t * (3.0 - 2.0 * t) * 0.35 + t * 0.65
            return e0 + (e1 - e0) * t, w0 + (w1 - w0) * t
    first, last = slices[0], slices[-1]
    return (first[1], first[2]) if z < first[0] else (last[1], last[2])


def superellipse(t, power):
    """(across, up) round a superellipse, `t` round from the top towards +x."""
    s, c = math.sin(t), math.cos(t)
    return math.copysign(abs(s) ** (2.0 / power), s), math.copysign(abs(c) ** (2.0 / power), c)


def cranium_bottom(z):
    """The floor of the cranium: the mouth in front of the hinge, and down into the neck behind it."""
    return mouth_y(z) if z >= JAW.z else mouth_y(JAW.z) - 0.05 * blend(JAW.z, -0.045, z)


def cranium_section(z, t):
    """A point of the cranium in its slice at `z`, `t` round from the top towards its left."""
    top, w = sliced(CRANIUM, z)
    # (made to reach below the floor, and cut off flat there by cranium_point)
    bottom = cranium_bottom(z) - (0.022 if z >= JAW.z else 0.0)
    half = (top - bottom) * 0.5
    middle = bottom + half
    upper = math.cos(t) >= 0.0
    # (rounded over the top; below, boxy: flat cheeks over the corners of the mouth)
    x, y = superellipse(t, 2.3 if upper else 4.0)
    x *= w * (1.0 + 0.1 * max(-math.cos(t), 0.0))
    p = Vector((x, middle + half * y, z))
    return p, Vector((x / max(w, 0.001), y, 0.0)).normalized()


def eye_centre(side):
    """The middle of an eye, and the way it looks."""
    return Vector((side * EYE_AT.x, EYE_AT.y, EYE_AT.z)), Vector((side * EYE_WAY.x, EYE_WAY.y, EYE_WAY.z))


def _place_eyes():
    """Sets each eye half into the side of the head where it is widest at its height."""
    z, y = EYE_AT.z, EYE_AT.y
    best = 0.0
    for k in range(200):
        t = math.pi * k / 199
        p, _n = cranium_section(z, t)
        if abs(p.y - y) < 0.004:
            best = max(best, p.x)
    EYE_AT.x = best + 0.004


_place_eyes()


def cranium_point(z, t):
    p, out = cranium_section(z, t)
    d = 0.0
    for side in (1.0, -1.0):
        centre, way = eye_centre(side)
        # The mound each eye sits on, and a heavy ridge of brow over it
        d += 0.014 * math.exp(-((p - centre).length / 0.032) ** 2)
        d += 0.006 * math.exp(-((p - (centre + Vector((-side * 0.012, 0.024, -0.004)))).length / 0.016) ** 2)
        # The cheeks, swelling behind the corners of the mouth
        d += 0.006 * math.exp(-((p - Vector((side * 0.085, 1.3, 0.055))).length / 0.03) ** 2)
    # A groove down the middle of the brow, between the eyes
    d -= 0.004 * math.exp(-(p.x / 0.012) ** 2) * blend(1.33, 1.36, p.y) * blend(0.06, 0.12, p.z)
    if not kit.LOW:
        for wart, height, breadth in WARTS:
            d += height * math.exp(-((p - wart).length / breadth) ** 2)
    q = p + out * d
    if z >= JAW.z:
        q.y = max(q.y, cranium_bottom(z) + 0.0004)
    return q


def jaw_section(z, t):
    bottom, w = sliced(JAWBONE, z)
    # (made to reach above the mouth, and cut off flat there by jaw_point)
    top = (mouth_y(z) + 0.016) if z >= JAW.z else mouth_y(JAW.z)
    half = (top - bottom) * 0.5
    middle = bottom + half
    upper = math.cos(t) >= 0.0
    x, y = superellipse(t, 4.5 if upper else 1.9)
    x *= w
    return Vector((x, middle + half * y, z)), Vector((x / max(w, 0.001), y, 0.0)).normalized()


def jaw_point(z, t):
    p, out = jaw_section(z, t)
    d = 0.0
    # A knob of a chin, and a ridge along each lower edge of the jaw
    d += 0.005 * math.exp(-((p - Vector((0.0, 1.268, 0.205))).length / 0.016) ** 2)
    for side in (1.0, -1.0):
        d += 0.003 * math.exp(-((p - Vector((side * 0.075, 1.236, 0.1))).length / 0.03) ** 2)
    q = p + out * d
    if z >= JAW.z:
        q.y = min(q.y, mouth_y(z) - 0.0004)
    return q


def loft(b, slices, point, front_pole, back_pole, rows, around):
    """A closed surface through slices (`point(z, t)`) from back to front, each
    end closed on a pole."""
    first, last = slices[0][0], slices[-1][0]
    lines = []
    for k in range(rows):
        u = k / (rows - 1)
        # (slices crowd towards the snout, where the face is)
        z = first + (last - first) * (u * 0.55 + 0.45 * (1.0 - (1.0 - u) ** 2))
        lines.append([b._vert(point(z, math.tau * j / around), None) for j in range(around)])
    faces = []
    for lower, upper in zip(lines, lines[1:]):
        for j in range(around):
            n = (j + 1) % around
            faces.append(b.bm.faces.new((lower[j], lower[n], upper[n], upper[j])))
    for row, pole in ((lines[0], back_pole), (lines[-1], front_pole)):
        middle = b._vert(pole, None)
        for j in range(around):
            faces.append(b.bm.faces.new((row[j], row[(j + 1) % around], middle)))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def edge_of(point, z, upper):
    """How far out the line where the jaws meet is at `z` (on a section made by `section`)."""
    steps = 240
    best = 0.0
    for k in range(steps + 1):
        t = math.pi * (0.5 + 0.5 * k / steps) if upper else math.pi * 0.5 * k / steps
        p = point(z, t)
        if (upper and p.y <= mouth_y(z) + 0.0008) or (not upper and p.y >= mouth_y(z) - 0.0008):
            best = max(best, p.x)
    return best


def mouth_line(upper, inset=0.0, count=41):
    """Points along where the jaws meet, from the right corner round the snout
    to the left corner, `inset` in from the edge of the jaw (`upper` or lower)."""
    section = cranium_point if upper else jaw_point
    front = (CRANIUM if upper else JAWBONE)[-1][0] - 0.002
    zs = [JAW.z + 0.006 + (front - JAW.z - 0.006) * (1.0 - (1.0 - k / 24) ** 1.6) for k in range(25)]
    side_line = [Vector((edge_of(section, z, upper), mouth_y(z), z)) for z in zs]
    # (along the left side to the front, then across it, then back down the right)
    path = [Vector((-p.x, p.y, p.z)) for p in side_line] + [Vector((0.0, side_line[-1].y, side_line[-1].z + 0.003))] + list(reversed(side_line))
    # (evenly spaced, by the length along it)
    lengths = [0.0]
    for a, c in zip(path, path[1:]):
        lengths.append(lengths[-1] + (c - a).length)
    total = lengths[-1]
    points = []
    for k in range(count):
        want = total * k / (count - 1)
        for i in range(len(path) - 1):
            if lengths[i + 1] >= want:
                t = (want - lengths[i]) / max(lengths[i + 1] - lengths[i], 1e-9)
                points.append(path[i].lerp(path[i + 1], t))
                break
        else:
            points.append(path[-1])
    if inset:
        centre_z = 0.09
        moved = []
        for p in points:
            inward = Vector((-p.x, 0.0, centre_z - p.z))
            inward = inward.normalized() if inward.length > 1e-6 else Vector((0.0, 0.0, -1.0))
            moved.append(p + inward * inset)
        points = moved
    return points


def head(b):
    """The cranium and the snout, its hard rim of a lip, the lids of its eyes."""
    b.place = grown
    rows, around = (12, 14) if kit.LOW else (70, 72)
    middle_back = Vector((0.0, (CRANIUM[0][1] + cranium_bottom(CRANIUM[0][0])) * 0.5, CRANIUM[0][0] - 0.012))
    middle_front = Vector((0.0, (CRANIUM[-1][1] + mouth_y(CRANIUM[-1][0])) * 0.5 - 0.002, CRANIUM[-1][0] + 0.004))
    loft(b, CRANIUM, cranium_point, middle_front, middle_back, rows, around)
    if kit.LOW:
        return kit.fused(b, None)
    # The upper lip: a thin hard rim along where the jaws meet
    points = mouth_line(True, 0.001, 41)
    b.strand([p + Vector((0.0, 0.0018, 0.0)) for p in points], [0.0022 + 0.0008 * math.sin(math.pi * k / 40) for k in range(41)], 6)
    # A rim of skin round each eye where it bulges out of its socket, thicker over the top
    for side in (1.0, -1.0):
        centre, way = eye_centre(side)
        u = way.cross(Y).normalized()
        v = u.cross(way).normalized()
        if v.y < 0.0:
            v = -v
        ring = []
        for k in range(29):
            t = math.tau * k / 28
            ring.append(centre + way * (EYE_RADIUS * 0.4) + (u * math.cos(t) + v * math.sin(t)) * EYE_RADIUS * 0.93)
        b.strand(ring, [0.0026 + 0.0022 * max(math.sin(math.tau * k / 28), 0.0) for k in range(29)], 6)
    return kit.fused(b, None)


def jaw(b):
    """The lower jaw, and its lip."""
    b.place = grown
    rows, around = (10, 12) if kit.LOW else (54, 56)
    back = Vector((0.0, (JAWBONE[0][1] + mouth_y(JAW.z)) * 0.5, JAWBONE[0][0] - 0.01))
    front = Vector((0.0, (JAWBONE[-1][1] + mouth_y(JAWBONE[-1][0])) * 0.5, JAWBONE[-1][0] + 0.003))
    loft(b, JAWBONE, jaw_point, front, back, rows, around)
    if not kit.LOW:
        points = mouth_line(False, 0.001, 41)
        b.strand([p - Vector((0.0, 0.0016, 0.0)) for p in points], [0.0024 + 0.0008 * math.sin(math.pi * k / 40) for k in range(41)], 6)
    return kit.fused(b, None)


def head_paint(p, n):
    """A pale lip along the mouth; smooth skin round the eyes and the lips."""
    p = ungrown(p)
    lip = blend(0.009, 0.003, abs(p.y - mouth_y(p.z))) * blend(JAW.z - 0.005, JAW.z + 0.02, p.z)
    eye = 0.0
    for side in (1.0, -1.0):
        centre, _way = eye_centre(side)
        eye = max(eye, blend(EYE_RADIUS * 1.7, EYE_RADIUS * 1.15, (p - centre).length))
    return 0.0, SMOOTH if max(lip, eye) > 0.5 else SCALED


def jaw_paint(p, n):
    """Pale under the jaw and on the lip."""
    p = ungrown(p)
    lip = blend(0.009, 0.003, abs(p.y - mouth_y(p.z)))
    under = blend(0.15, -0.5, n.y + 0.2 * noise(p, 0.02))
    return under * (1.0 - lip), SMOOTH if lip > 0.5 else SCALED


def head_hollows(p):
    """Dark in the corners of the mouth, and in a crease under each eye."""
    p = ungrown(p)
    d = 0.0
    for side in (1.0, -1.0):
        corner = Vector((side * 0.08, mouth_y(JAW.z + 0.012), JAW.z + 0.012))
        d = max(d, blend(0.016, 0.006, (p - corner).length))
    # (and a dark line along the mouth: it has no lips to speak of)
    if p.z > JAW.z - 0.01:
        d = max(d, 0.75 * blend(0.0055, 0.0015, abs(p.y - mouth_y(p.z))))
    return d


def teeth(upper):
    """Needles all round a jaw, crooked, the front ones longest; and on the
    lower jaw a few fangs that stand outside the upper lip when it is shut."""
    def made(b):
        rng = random.Random(11 if upper else 12)
        b.place = grown
        count = (10 if upper else 8) if kit.LOW else (19 if upper else 15)
        rim = mouth_line(upper, 0.005 if upper else 0.012, count + 2)[1:-1]
        for k, root in enumerate(rim):
            inward = Vector((-root.x, 0.0, 0.09 - root.z)).normalized()
            front = blend(0.06, 0.19, root.z)
            length = (0.009 + 0.019 * front) * rng.uniform(0.45, 1.35)
            root = root + Vector((0.0, 0.003 if upper else -0.003, 0.0))
            down = Vector((0.0, -1.0 if upper else 1.0, 0.0))
            way = (down + inward * rng.uniform(0.05, 0.4) + Vector((rng.uniform(-0.18, 0.18), 0.0, rng.uniform(-0.18, 0.18)))).normalized()
            radius = 0.0015 + 0.0009 * front
            b.strand([root, root + way * length * 0.5, root + way * length], [radius, radius * 0.55, radius * 0.1], 5)
        if not upper:
            # The fangs, standing outside the upper lip
            line = mouth_line(False, 0.0025, 41)
            for k, length in ((15, 0.03), (25, 0.027), (8, 0.022), (33, 0.024), (19, 0.018)):
                root = line[k] - Vector((0.0, 0.006, 0.0))
                outward = Vector((root.x, 0.0, root.z - 0.09)).normalized()
                way = (Vector((0.0, 1.0, 0.0)) + outward * 0.3).normalized()
                b.strand([root, root + way * length * 0.5 + outward * 0.0015, root + way * length], [0.0032, 0.002, 0.0004], 5)
    return made


def sack(b):
    """The dark inside of its mouth: as deep as the jaws, out to the lips, and down its throat."""
    b.place = grown
    b.ellipsoid(Vector((0.0, mouth_y(0.12), 0.11)), Vector((0.072, 0.02, 0.086)), None, 24, 9)
    b.ellipsoid(Vector((0.0, mouth_y(JAW.z) - 0.004, 0.045)), Vector((0.062, 0.03, 0.056)), None, 16, 7)


def eyes(b):
    b.place = grown
    for side in (1.0, -1.0):
        centre, _way = eye_centre(side)
        b.ellipsoid(centre, Vector((EYE_RADIUS, EYE_RADIUS, EYE_RADIUS)), None, 22, 11)


def pupils(b):
    """A small round pupil in each pale eye, staring."""
    b.place = grown
    for side in (1.0, -1.0):
        centre, way = eye_centre(side)
        # (a disc lying on the eye where it bulges most, a little proud of it)
        tilt = Vector((0.0, 1.0, 0.0)).rotation_difference(way).to_matrix()
        b.ellipsoid(centre + way * (EYE_RADIUS - 0.0018), Vector((EYE_RADIUS * 0.6, 0.0034, EYE_RADIUS * 0.6)), tilt, 20, 4)


# The gills: each flap's line (front edge) as (top, bottom) (height, how far
# forward), on the side of the head and neck behind the corner of the mouth.
GILLS = [((1.334, 0.032), (1.262, 0.05)), ((1.328, 0.013), (1.257, 0.031)), ((1.319, -0.006), (1.253, 0.012))]


def gill_points(side, index, back=0.0, lift=0.0, steps=9):
    """Points down a gill's line (`back` behind its front edge), on the outside
    of the neck, and the neck's normal at each."""
    (y0, z0), (y1, z1) = GILLS[index]
    points, normals = [], []
    for k in range(steps):
        t = k / (steps - 1)
        y = y0 + (y1 - y0) * t
        z = z0 + (z1 - z0) * t - back + 0.006 * math.sin(math.pi * t)
        hit, normal = surface_hit(("trunk", "head"), Vector((side * 0.3, y, z)), Vector((-side, 0.0, 0.0)))
        points.append(hit + normal * lift)
        normals.append(normal)
    return points, normals


def gill_root(side, index):
    """Where a gill flap hinges: about the middle of its front edge (worked out
    from the neck's profile, as the bones are made before any surface)."""
    (y0, z0), (y1, z1) = GILLS[index]
    y, z = (y0 + y1) * 0.5, (z0 + z1) * 0.5
    rx, _rz, _fwd = profile_at(NECK_PROFILE, y)
    if z >= CRANIUM[0][0]:
        for k in range(120):
            p = cranium_point(z, math.pi * k / 119)
            if abs(p.y - y) < 0.004:
                rx = max(rx, p.x)
    return Vector((side * (rx + 0.002), y, z))


def gill_flaps(b):
    """A flap of skin over each slit, hinged at its front edge."""
    for side in (1.0, -1.0):
        for index in range(len(GILLS)):
            points, normals = gill_points(side, index, 0.009, 0.0008, 7 if kit.LOW else 11)
            count = len(points)
            widths = [0.0105 * math.sin(math.pi * (0.15 + 0.7 * k / (count - 1))) for k in range(count)]
            ribbon(b, points, widths, normals, 0.0018)


def holes(b):
    """The slits under the gill flaps; the nostrils."""
    for side in (1.0, -1.0):
        for index in range(len(GILLS)):
            points, _normals = gill_points(side, index, 0.016, -0.0026, 7 if kit.LOW else 11)
            count = len(points)
            b.strand(points, [0.0048 * math.sin(math.pi * (0.1 + 0.8 * k / (count - 1))) + 0.0012 for k in range(count)], 6)
        # A nostril: a slit on top of the snout
        at, normal = surface_hit(("head",), Vector((side * 0.017, 1.6, 0.174)), Vector((0.0, -1.0, 0.0)))
        b.ellipsoid(at - normal * 0.0015, Vector((0.0034, 0.0022, 0.0075)), Matrix.Rotation(side * 0.5, 3, "Y"), 10, 5)


# --- The fins ---

def fin_line(points, normals, heights, ray_lean, spines, b, thickness=0.0026):
    """A fin along a line of points on a body, standing out `heights` along
    each point's normal leant back down the line by `ray_lean`, a membrane
    whose edge is scalloped between `spines` (indices into the points)."""
    count = len(points)
    rays = []
    for i in range(count):
        ahead = (points[min(i + 1, count - 1)] - points[max(i - 1, 0)]).normalized()
        rays.append((normals[i] + ahead * ray_lean).normalized())
    scallop = []
    for i in range(count):
        near = min(abs(i - k) for k in spines)
        gap = max(count / max(len(spines), 1), 1.0)
        scallop.append(0.72 + 0.28 * math.exp(-(near / (gap * 0.22)) ** 2))
    rings = []
    for i in range(count):
        h = heights[i] * scallop[i]
        side = rays[i].cross(normals[i].cross(rays[i])).normalized()
        across = X if abs(normals[i].x) < 0.7 else side
        root = points[i] - normals[i] * 0.006
        rings.append((root + rays[i] * (h + 0.006) * 0.5, rays[i] * (h + 0.006) * 0.5, across * thickness * (1.0 - 0.4 * i / count)))
    first = (points[0] - points[1]).normalized()
    last = (points[-1] - points[-2]).normalized()
    b.tube(kit.dome(rings[0], first, 0.004, 1)[::-1] + rings + kit.dome(rings[-1], last, 0.004, 1), 6)
    for k in spines:
        h = heights[k] * 1.12
        root = points[k] - normals[k] * 0.006
        tip = root + rays[k] * (h + 0.006)
        bend = normals[k] * 0.0
        b.strand([root, root.lerp(tip, 0.5) + bend, tip], [0.0034, 0.0024, 0.0007], 5)


def back_fin(b):
    """From the nape down the spine, highest over the hump of its back."""
    steps = 24 if kit.LOW else 110
    points, normals, heights = [], [], []
    top, bottom = 1.33, 0.86
    for k in range(steps):
        t = k / (steps - 1)
        y = top + (bottom - top) * t
        hit, normal = surface_hit(("trunk", "head"), Vector((0.0, y, -0.5)), Vector((0.0, 0.0, 1.0)))
        normal = Vector((0.0, normal.y, normal.z)).normalized()
        points.append(hit)
        normals.append(normal)
        heights.append(0.088 * math.sin(math.pi * min(t * 1.08, 1.0)) ** 0.7 * (1.0 - 0.35 * t) + 0.004)
    spines = [int((steps - 1) * (0.03 + 0.94 * k / 13)) for k in range(14)]
    fin_line(points, normals, heights, 0.75, spines, b)


def crest(b):
    """A low fin from the brow back over the crown of the head, into the one down its back."""
    steps = 16 if kit.LOW else 70
    points, normals, heights = [], [], []
    for k in range(steps):
        t = k / (steps - 1)
        z = 0.125 + (-0.03 - 0.125) * t
        hit, normal = surface_hit(("head",), Vector((0.0, 1.7, z)), Vector((0.0, -1.0, 0.0)))
        normal = Vector((0.0, normal.y, normal.z)).normalized()
        points.append(hit)
        normals.append(normal)
        heights.append(0.03 * math.sin(math.pi * min(t * 1.1, 1.0)) ** 0.6 * (0.55 + 0.45 * t) + 0.003)
    spines = [int((steps - 1) * (0.06 + 0.9 * k / 6)) for k in range(7)]
    fin_line(points, normals, heights, 0.9, spines, b, 0.0022)


def arm_fins(b):
    """A ragged fin down the back edge of each forearm."""
    steps = 10 if kit.LOW else 40
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        points, normals, heights = [], [], []
        for k in range(steps):
            t = k / (steps - 1)
            along = 1.12 + 0.72 * t
            rx, rz, fwd = profile_of(ARM, along)
            points.append(arm_point(side, along, side * rx * 0.25, fwd - rz + 0.002))
            normals.append(Vector((side * 0.25, 0.0, -1.0)).normalized())
            heights.append(0.03 * math.sin(math.pi * t) ** 0.8 + 0.002)
        fin_line(points, normals, heights, 0.85, [int((steps - 1) * (0.1 + 0.8 * k / 4)) for k in range(5)], b, 0.002)
    b.place = None


def fin_paint(p, n):
    return 0.0, FIN


# --- The body ---

# (height, half width, half depth, how far forward): broad hips, a paunch, a
# barrel of a chest, shoulders that slope off a neck that is hardly a neck.
TORSO = [(0.7, 0.05, 0.05, 0.0), (0.74, 0.124, 0.09, 0.0), (0.8, 0.136, 0.096, 0.006), (0.87, 0.134, 0.104, 0.018),
         (0.94, 0.132, 0.108, 0.024), (1.0, 0.14, 0.104, 0.018), (1.06, 0.154, 0.098, 0.01), (1.11, 0.158, 0.09, 0.004),
         (1.145, 0.146, 0.08, 0.0), (1.175, 0.112, 0.07, 0.004), (1.2, 0.09, 0.066, 0.01)]
NECK_PROFILE = [(1.16, 0.096, 0.078, 0.004), (1.2, 0.088, 0.076, 0.012), (1.24, 0.08, 0.072, 0.018), (1.28, 0.072, 0.066, 0.022),
                (1.31, 0.062, 0.058, 0.024), (1.335, 0.048, 0.046, 0.026)]
TRUNK_FUSE = (0.0038, 3, 14000)

# An arm (0 the shoulder, 1 the elbow, 2 the wrist): (where, half thickness, half width, forward).
ARM = [(2.05, 0.024, 0.029, 0.0), (1.98, 0.028, 0.034, 0.0), (1.85, 0.032, 0.039, 0.0), (1.55, 0.037, 0.044, 0.0),
       (1.25, 0.042, 0.047, 0.0), (1.05, 0.037, 0.041, -0.003), (0.9, 0.041, 0.045, 0.0), (0.6, 0.047, 0.052, 0.0),
       (0.3, 0.052, 0.057, 0.0), (0.1, 0.055, 0.06, 0.0), (0.0, 0.052, 0.057, 0.0), (-0.05, 0.036, 0.04, 0.0)]


def arm_point(side, t, out=0.0, forward=0.0):
    """A point on an arm hanging straight down, `t` along it (as ARM), `out` from its middle and `forward`."""
    y = SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM)
    return Vector((side * (SHOULDER.x + out), y, SHOULDER.z + forward))


def trunk(_builder):
    """The trunk, the neck and the arms: one surface."""
    b = kit.Builder()
    b.tube(smooth_rings(0.0, 0.0, TORSO), 24)
    b.tube(smooth_rings(0.0, 0.0, NECK_PROFILE, 0.015), 16)
    # A hump of a back, and the paunch
    b.ellipsoid(Vector((0.0, 1.11, -0.042)), Vector((0.11, 0.08, 0.055)), None, 18, 8)
    b.ellipsoid(Vector((0.0, 0.9, 0.05)), Vector((0.1, 0.095, 0.068)), None, 18, 8)
    # The throat, swelling under the jaw
    b.ellipsoid(Vector((0.0, 1.238, 0.058)), Vector((0.062, 0.036, 0.046)), None, 16, 7)
    # The muscle from the back of the skull to the shoulders: it has hardly a neck
    for side in (1.0, -1.0):
        b.ellipsoid(Vector((side * 0.05, 1.215, -0.03)), Vector((0.06, 0.07, 0.048)), Matrix.Rotation(-side * 0.5, 3, "Z"), 14, 7)
    for side in (1.0, -1.0):
        # The slope of the shoulders off the neck, thick
        b.ellipsoid(Vector((side * 0.088, 1.168, -0.018)), Vector((0.082, 0.036, 0.054)), Matrix.Rotation(-side * 0.38, 3, "Z"), 16, 7)
        # The breast, heavy and low
        b.ellipsoid(Vector((side * 0.062, 1.06, 0.048)), Vector((0.066, 0.05, 0.04)), Matrix.Rotation(side * 0.2, 3, "Z"), 14, 7)
        # Shoulder blades
        b.ellipsoid(Vector((side * 0.07, 1.09, -0.07)), Vector((0.045, 0.055, 0.016)), Matrix.Rotation(side * 0.25, 3, "Z") @ Matrix.Rotation(0.25, 3, "X"), 12, 5)
        # The haunches
        b.ellipsoid(Vector((side * 0.062, 0.77, -0.04)), Vector((0.07, 0.068, 0.058)), None, 14, 7)
    # The knuckles of the spine down the back, under the fin
    for k in range(10):
        y = 0.86 + 0.03 * k
        rx, rz, fwd = profile_at(TORSO, y)
        b.ellipsoid(Vector((0.0, y, fwd - rz + 0.004)), Vector((0.014, 0.012, 0.01)), None, 8, 4)
    # The arms, out at their rest
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        rings = [(SHOULDER.y - (t * UPPER_ARM if t <= 1.0 else UPPER_ARM + (t - 1.0) * FOREARM), rx, rz, z) for t, rx, rz, z in ARM]
        b.tube(smooth_rings(side * SHOULDER.x, SHOULDER.z, rings, 0.016), 14)
        # The shoulder, a round knot of muscle over the top of the arm
        b.ellipsoid(arm_point(side, 0.12, 0.006, 0.0), Vector((0.044, 0.058, 0.046)), None, 14, 7)
        # Biceps and triceps, slack
        b.ellipsoid(arm_point(side, 0.55, 0.0, 0.016), Vector((0.03, 0.08, 0.026)), None, 12, 6)
        b.ellipsoid(arm_point(side, 0.5, 0.0, -0.018), Vector((0.032, 0.09, 0.026)), None, 12, 6)
        # The point of the elbow
        b.ellipsoid(arm_point(side, 1.0, 0.0, -0.026), Vector((0.022, 0.026, 0.018)), None, 10, 5)
        # The forearm's muscle, swelling below the elbow
        b.ellipsoid(arm_point(side, 1.25, 0.004, 0.006), Vector((0.036, 0.075, 0.034)), None, 12, 6)
    b.place = None
    return kit.fused(b, None if kit.LOW else TRUNK_FUSE)


def trunk_hollows(p):
    """Places on the trunk that are dark whatever their shape: the armpits."""
    ax = abs(p.x)
    return blend(1.03, 1.06, p.y) * blend(1.14, 1.1, p.y) * blend(0.1, 0.115, ax) * blend(0.15, 0.13, ax) * blend(0.04, 0.02, abs(p.z))


def trunk_paint(p, n):
    """The belly, the chest and the throat are pale, the back dark; the edge of
    the pale wanders; the inside of the arms is paler."""
    side = 1.0 if p.x >= 0.0 else -1.0
    share = arm_share(side, p)
    wander = 0.18 * noise(p, 0.035)
    belly = blend(0.42, 0.72, n.z + wander) * blend(0.72, 0.78, p.y) * blend(1.2, 1.14, p.y)
    throat = blend(0.35, 0.7, n.z - n.y * 0.6 + wander) * blend(1.15, 1.2, p.y)
    pale = max(belly, throat)
    if share > 0.0:
        q = arm_in(side, p)
        inside = blend(0.0, 0.6, -side * n.x * 0.6 + n.z * 0.6 + wander)
        pale = pale * (1.0 - share) + 0.65 * inside * share
    return pale, SCALED


# A leg by how far along it is (0 the ankle, 1 the knee, 2 the hip): (where, half thickness, half width, forward).
LEG = [(-0.02, 0.03, 0.034, 0.0), (0.06, 0.029, 0.032, 0.0), (0.3, 0.04, 0.044, -0.009), (0.55, 0.053, 0.057, -0.014),
       (0.8, 0.043, 0.046, -0.005), (1.0, 0.046, 0.048, 0.004), (1.2, 0.053, 0.057, 0.004), (1.5, 0.069, 0.074, 0.006),
       (1.8, 0.078, 0.084, 0.004), (2.0, 0.081, 0.087, 0.0), (2.13, 0.076, 0.082, 0.0)]


def leg_height(t):
    return ANKLE_Y + t * SHIN if t <= 1.0 else KNEE_Y + (t - 1.0) * THIGH


def legs(b):
    for side in (1.0, -1.0):
        x = side * HIP_X
        b.tube(smooth_rings(x, 0.0, [(leg_height(t), rx, rz, z) for t, rx, rz, z in LEG], 0.018), 16)
        # The kneecap, the knobs either side of the knee, and the calf
        b.ellipsoid(Vector((x, KNEE_Y + 0.006, 0.03)), Vector((0.026, 0.03, 0.017)), None, 10, 5)
        for across in (0.03, -0.028):
            b.ellipsoid(Vector((x + across, KNEE_Y - 0.004, 0.006)), Vector((0.016, 0.024, 0.02)), None, 8, 4)
        b.ellipsoid(Vector((x + side * 0.004, ANKLE_Y + SHIN * 0.62, -0.024)), Vector((0.034, 0.075, 0.03)), None, 12, 6)
        # The cord of the heel, and the knobs of the ankle
        b.strand([Vector((x, ANKLE_Y + 0.12, -0.03)), Vector((x, ANKLE_Y + 0.05, -0.032)), Vector((x, ANKLE_Y - 0.004, -0.034))], [0.009, 0.0085, 0.009], 6)
        for across in (0.024, -0.022):
            b.ellipsoid(Vector((x + across, ANKLE_Y + 0.006, 0.0)), Vector((0.011, 0.013, 0.012)), None, 8, 4)


def leg_paint(p, n):
    side = 1.0 if p.x >= 0.0 else -1.0
    inside = blend(0.55, 0.85, -side * n.x + 0.18 * noise(p, 0.03)) * blend(0.45, 0.7, p.y)
    return 0.6 * inside, SCALED


# The toes, inside to outside: (along the front of the foot, how far it fans out, length).
TOES = [(-0.028, -0.34, 0.058), (-0.01, -0.11, 0.074), (0.01, 0.12, 0.078), (0.029, 0.36, 0.064)]


def toe_line(side, index):
    """A toe's root and the way it points, and its length."""
    across, fan, length = TOES[index]
    root = Vector((side * HIP_X + side * across, 0.012, 0.074))
    return root, Vector((side * math.sin(fan), 0.0, math.cos(fan))), length


def toe_point(side, index, t):
    root, along, length = toe_line(side, index)
    # (arched a little, the tip pressed down)
    return root + along * length * t + Vector((0.0, 0.004 * math.sin(math.pi * t) - 0.006 * t, 0.0))


def feet(b):
    for side in (1.0, -1.0):
        ankle = Vector((side * HIP_X, ANKLE_Y, 0.0))
        # Long and flat: a heel, a low instep, broadening to the toes
        upper = [(ankle + Vector((0.0, y, z)), X * rx, Y * ry) for z, y, rx, ry in
                 ((-0.05, -0.03, 0.022, 0.02), (-0.03, -0.022, 0.028, 0.03), (0.0, -0.024, 0.031, 0.03), (0.03, -0.034, 0.035, 0.02),
                  (0.055, -0.041, 0.039, 0.013), (0.078, -0.044, 0.041, 0.009))]
        b.tube(kit.dome(upper[0], -Z, 0.014, 3)[::-1] + upper + kit.dome(upper[-1], Z, 0.008, 2), 16, 0.002)
        # The toes, long and knuckled
        for index in range(len(TOES)):
            _root, _along, _length = toe_line(side, index)
            points = [toe_point(side, index, t) for t in (-0.25, 0.0, 0.3, 0.55, 0.8, 1.0)]
            b.strand(points, [0.0125, 0.0118, 0.0102, 0.0094, 0.0072, 0.005], 8)


def foot_webs(b):
    for side in (1.0, -1.0):
        for index in range(len(TOES) - 1):
            first = index if side > 0 else index + 1
            web(b, lambda t, i=index: toe_point(side, i, t), lambda t, i=index: toe_point(side, i + 1, t), (0.88, 0.66), 0.0026,
                lambda _p: Y, 6 if kit.LOW else 8)


def toe_claws(b):
    for side in (1.0, -1.0):
        for index in range(len(TOES)):
            root, along, length = toe_line(side, index)
            tip = toe_point(side, index, 1.0)
            b.strand([tip - along * 0.004, tip + along * 0.01 - Y * 0.003, tip + along * 0.018 - Y * 0.008], [0.0042, 0.0026, 0.0006], 5)


def hands(b):
    """The palms, broad and thin."""
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        wrist = hand_wrist(side)
        palm = [(0.02, 0.018, 0.025), (0.0, 0.017, 0.03), (-0.035, 0.014, 0.037), (-0.07, 0.0115, 0.04), (-PALM - 0.002, 0.0104, 0.038)]
        rings = [(wrist + Y * dy, X * rx, Z * rz) for dy, rx, rz in palm]
        b.tube(rings + kit.dome(rings[-1], -Y, 0.006, 2), 14)
        if kit.LOW:
            # (demade, the fingers and their webs are one paddle)
            inward = -side
            mitt = [(-PALM, 0.0, 0.007, 0.032), (-PALM - 0.06, 0.004, 0.006, 0.04), (-PALM - 0.11, 0.012, 0.004, 0.03)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
    b.place = None


def finger_point(side, index, t):
    knuckle, along = finger_line(side, index)
    return knuckle + along * FINGERS[index][1] * t


def thumb_point(side, t):
    root, along = thumb_line(side)
    return root + along * THUMB_LENGTH * t


def fingers(b):
    """Long, a little swollen at each joint."""
    if kit.LOW:
        return
    spans = (-0.1, 0.0, 0.2, 0.42, 0.58, 0.74, 0.88, 1.0)
    knobs = (1.0, 1.15, 0.95, 1.05, 0.9, 0.95, 0.75, 0.5)
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        for index, (_z, _length, radius, _fan) in enumerate(FINGERS):
            b.strand([finger_point(side, index, t) for t in spans], [radius * knob for knob in knobs], 7)
        b.strand([thumb_point(side, t) for t in (-0.2, 0.0, 0.3, 0.5, 0.75, 1.0)], [0.011, 0.012, 0.0098, 0.0104, 0.008, 0.005], 7)
    b.place = None


def finger_webs(b):
    if kit.LOW:
        return
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        for index in range(len(FINGERS) - 1):
            web(b, lambda t, i=index: finger_point(side, i, t), lambda t, i=index: finger_point(side, i + 1, t), WEB_REACH, 0.0022, lambda _p: X)
        # (and between the thumb and the first finger)
        web(b, lambda t: thumb_point(side, t * 0.95), lambda t: finger_point(side, 0, t * 0.6), (0.85, 0.55), 0.0022, lambda _p: X)
    b.place = None


def claws(b):
    """Small, dark and hooked."""
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        inward = Vector((-side, 0.0, 0.0))
        lines = [(finger_line(side, i)[1], finger_point(side, i, 1.0)) for i in range(len(FINGERS))]
        lines.append((thumb_line(side)[1], thumb_point(side, 1.0)))
        if kit.LOW:
            lines = [(Vector((0.0, -1.0, 0.0)), hand_wrist(side) + Vector((-side * 0.012, -PALM - 0.115, z))) for z in (0.024, 0.008, -0.008, -0.024)]
        for along, tip in lines:
            b.strand([tip - along * 0.004, tip + along * 0.009 + inward * 0.002, tip + along * 0.016 + inward * 0.007], [0.0042, 0.0026, 0.0006], 5)
    b.place = None


def hand_paint(p, n):
    return 0.0, SMOOTH


def web_paint(p, n):
    return 0.0, FIN


def hard_paint(pale):
    return lambda _p, _n: (pale, HARD)


# --- Bones and weights ---

def arm_weights(side, p):
    suffix = "_l" if side > 0.0 else "_r"
    down = SHOULDER.y - arm_in(side, p).y
    fore = blend(UPPER_ARM - 0.04, UPPER_ARM + 0.04, down)
    hand = blend(UPPER_ARM + FOREARM - 0.022, UPPER_ARM + FOREARM + 0.012, down)
    return {"upper_arm" + suffix: 1.0 - fore, "forearm" + suffix: fore * (1.0 - hand), "hand" + suffix: fore * hand}


def arm_share(side, p):
    """How much a point of the trunk's surface belongs to the arm on `side`."""
    q = arm_in(side, p)
    down = SHOULDER.y - q.y
    off = Vector((q.x - side * SHOULDER.x, 0.0, q.z - SHOULDER.z)).length
    if off > 0.09:
        return 0.0
    return blend(-0.03, 0.06, down) * blend(0.09, 0.06, off)


def trunk_weights(p):
    low = blend(SPINE.y + 0.05, SPINE.y - 0.05, p.y)
    high = blend(CHEST.y - 0.07, CHEST.y + 0.05, p.y)
    middle = abs(p.x) < 0.1
    neck = blend(NECK.y - 0.015, NECK.y + 0.03, p.y) if middle else 0.0
    skull = blend(HEAD.y - 0.02, HEAD.y + 0.03, p.y) if middle else 0.0
    return {
        "hips": low,
        "spine": (1.0 - low) * (1.0 - high),
        "chest": (1.0 - low) * high * (1.0 - neck),
        "neck": neck * (1.0 - skull),
        "head": neck * skull,
    }


def line_weights(suffix, name, root, along, length, joints, q):
    t = (q - root).dot(along) / length
    soft = 0.005 / length
    shares = [blend(joint - soft, joint + soft, t) for joint in joints]
    result = {"hand" + suffix: 1.0 - shares[0]}
    for k, letter in enumerate("abc"[:len(joints)]):
        result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(shares) else 0.0)
    return result


def finger_lines(side):
    lines = [("finger%d" % index, finger_line(side, index), FINGERS[index][1], KNUCKLES) for index in range(len(FINGERS))]
    lines.append(("thumb", thumb_line(side), THUMB_LENGTH, (0.0, 0.5)))
    return lines


def mixed(a, b, share):
    result = {}
    for bone, weight in a.items():
        result[bone] = result.get(bone, 0.0) + weight * share
    for bone, weight in b.items():
        result[bone] = result.get(bone, 0.0) + weight * (1.0 - share)
    return result


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    if part in ("head", "eyes", "pupils", "upper_teeth", "holes", "crest"):
        return {"head": 1.0}
    if part in ("jaw", "lower_teeth"):
        return {"jaw": 1.0}
    if part == "sack":
        p = ungrown(p)
        up = blend(mouth_y(p.z) - 0.012, mouth_y(p.z) + 0.01, p.y) if p.z > JAW.z - 0.02 else 1.0
        return {"head": up, "jaw": 1.0 - up}
    if part == "gills":
        best, nearest = 0, 9.0
        for index in range(len(GILLS)):
            far = (p - gill_root(side, index)).length
            if far < nearest:
                best, nearest = index, far
        return {"gill%d%s" % (best, suffix): 1.0}
    if part in ("fin",):
        return trunk_weights(Vector((0.0, p.y, p.z)))
    if part in ("feet", "foot_webs", "toe_claws"):
        shin = blend(0.068, 0.11, p.y) * blend(0.03, 0.0, p.z)
        toe = blend(TOE.z - 0.018, TOE.z + 0.02, p.z)
        return {"shin" + suffix: shin, "foot" + suffix: (1.0 - shin) * (1.0 - toe), "toe" + suffix: (1.0 - shin) * toe}
    if part == "legs":
        leg = blend(HIP_Y + 0.05, HIP_Y - 0.05, p.y)
        shin = blend(KNEE_Y + 0.045, KNEE_Y - 0.045, p.y)
        foot = blend(0.09, 0.055, p.y)
        return {"hips": 1.0 - leg, "thigh" + suffix: leg * (1.0 - shin), "shin" + suffix: leg * shin * (1.0 - foot), "foot" + suffix: leg * shin * foot}
    if part in ("hands", "arm_fins"):
        return arm_weights(side, p)
    if part in ("fingers", "claws", "finger_webs"):
        q = arm_in(side, p)
        if kit.LOW and part != "finger_webs":
            return arm_weights(side, p)
        found = []
        for name, (root, along), length, joints in finger_lines(side):
            t = (q - root).dot(along)
            away = (q - root - along * min(max(t, 0.0), length)).length
            found.append((away, name, root, along, length, joints))
        found.sort(key=lambda one: one[0])
        first = line_weights(suffix, found[0][1], found[0][2], found[0][3], found[0][4], found[0][5], q)
        if part != "finger_webs":
            return first
        second = line_weights(suffix, found[1][1], found[1][2], found[1][3], found[1][4], found[1][5], q)
        share = found[1][0] / max(found[0][0] + found[1][0], 1e-6)
        return mixed(first, second, share)
    # The trunk (and the arms, which are one surface with it)
    share = arm_share(side, p)
    result = {bone: weight * (1.0 - share) for bone, weight in trunk_weights(p).items()}
    if share > 0.0:
        for bone, weight in arm_weights(side, p).items():
            result[bone] = result.get(bone, 0.0) + weight * share
    return result


def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("chest", CHEST, "spine"), ("neck", NECK, "chest"), ("head", HEAD, "neck"),
              ("jaw", grown(JAW), "head")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        for index in range(len(GILLS)):
            listed.append(("gill%d%s" % (index, suffix), gill_root(side, index), "head"))
        shoulder = shoulder_of(side)
        out = arm_out(side)
        listed.append(("upper_arm" + suffix, shoulder, "chest"))
        listed.append(("forearm" + suffix, out(shoulder - Y * UPPER_ARM), "upper_arm" + suffix))
        listed.append(("hand" + suffix, out(shoulder - Y * (UPPER_ARM + FOREARM)), "forearm" + suffix))
        for index in range(len(FINGERS)):
            knuckle, along = finger_line(side, index)
            parent = "hand" + suffix
            for letter, share in zip("abc", KNUCKLES):
                listed.append(("finger%d%s%s" % (index, letter, suffix), out(knuckle + along * FINGERS[index][1] * share), parent))
                parent = listed[-1][0]
        root, along = thumb_line(side)
        listed.append(("thumba" + suffix, out(root), "hand" + suffix))
        listed.append(("thumbb" + suffix, out(root + along * THUMB_LENGTH * 0.5), "thumba" + suffix))
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        listed.append(("thigh" + suffix, hip, "hips"))
        listed.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        listed.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
    return listed


# (part, material, shapes, how to fuse it). Each fuses itself, if at all (`shaded`).
# The trunk and the head come first: later parts are laid on them.
PARTS = [
    ("torso", SKIN, shaded(trunk, TRUNK_FUSE, -0.014, trunk_hollows, paint=trunk_paint, keep="trunk"), None),
    ("head", SKIN, shaded(head, None, -0.004, head_hollows, paint=head_paint, keep="head"), None),
    ("jaw", SKIN, shaded(jaw, None, -0.004, head_hollows, paint=jaw_paint), None),
    ("upper_teeth", SKIN, shaded(teeth(True), flat=0.0, paint=hard_paint(TOOTH)), None),
    ("lower_teeth", SKIN, shaded(teeth(False), flat=0.0, paint=hard_paint(TOOTH)), None),
    ("sack", SKIN, shaded(sack, flat=0.0, paint=hard_paint(MAW)), None),
    ("eyes", SKIN, shaded(eyes, flat=0.0, paint=hard_paint(GLASS)), None),
    ("pupils", SKIN, shaded(pupils, flat=0.0, paint=hard_paint(CLAW)), None),
    ("gills", SKIN, shaded(gill_flaps, flat=0.0, paint=painted(0.0, SMOOTH)), None),
    ("holes", SKIN, shaded(holes, flat=0.0, paint=hard_paint(MAW)), None),
    ("fin", SKIN, shaded(back_fin, flat=0.0, paint=fin_paint), None),
    ("crest", SKIN, shaded(crest, flat=0.0, paint=fin_paint), None),
    ("arm_fins", SKIN, shaded(arm_fins, flat=0.0, paint=fin_paint), None),
    ("legs", SKIN, shaded(legs, (0.0036, 3, 5000), -0.006, paint=leg_paint), None),
    ("feet", SKIN, shaded(feet, (0.0026, 3, 2400), 0.0, paint=painted(0.0, SMOOTH)), None),
    ("foot_webs", SKIN, shaded(foot_webs, flat=0.0, paint=web_paint), None),
    ("toe_claws", SKIN, shaded(toe_claws, flat=0.0, paint=hard_paint(CLAW)), None),
    ("hands", SKIN, shaded(hands, flat=0.0, paint=hand_paint), None),
    ("fingers", SKIN, shaded(fingers, flat=0.0, paint=hand_paint), None),
    ("finger_webs", SKIN, shaded(finger_webs, flat=0.0, paint=web_paint), None),
    ("claws", SKIN, shaded(claws, flat=0.0, paint=hard_paint(CLAW)), None),
]


def previews(folder, name):
    """Renders all round it, and the face close to."""
    scene = bpy.context.scene
    camera = scene.camera
    middle = kit.to_blender(Vector((0.0, 1.31, 0.08)))
    views = [("front", (0, -1, 0.05), (0.0, 0.0, 0.74), 1.6), ("back", (0.25, 1, 0.15), (0.0, 0.0, 0.74), 1.6),
             ("chest_front", (0.2, -1, 0.1), (0.0, 0.0, 1.05), 0.6), ("shoulder", (0.6, -1, 0.3), (0.1, 0.0, 1.15), 0.4),
             ("foot", (0.6, -0.7, 0.4), (0.09, -0.06, 0.04), 0.3), ("hand", (-0.6, -0.7, 0.1), kit.to_blender(arm_out(1.0)(hand_wrist(1.0) - Y * 0.1)), 0.3),
             ("face", (0, -1, 0.0), middle, 0.32), ("face_quarter", (0.7, -0.7, 0.1), middle, 0.32),
             ("face_side", (1, -0.05, 0.0), middle, 0.36), ("face_low", (0.3, -1, -0.5), middle, 0.32), ("face_top", (0.2, -0.5, 1.0), middle, 0.36)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    kit.export("fish_person", bones(), PARTS, weights, MATERIALS)
    if kit.PREVIEW_DIR:
        previews(kit.PREVIEW_DIR, "fish_person")
    if os.environ.get("FISH_ONLY_FULL") != "1":
        SURFACES.clear()
        kit.LOW = True
        kit.export("fish_person_lo", bones(), PARTS, weights, MATERIALS)
        if kit.PREVIEW_DIR:
            previews(kit.PREVIEW_DIR, "fish_person_lo")
