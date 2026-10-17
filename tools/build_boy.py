"""Builds the boy and exports him for Godot.

Run from the project root:
    blender --background --python tools/build_boy.py

Writes models/boy.glb and models/boy_lo.glb, with editable copies in tools/.

He is a boy of the 1910s: a cream shirt with the sleeves shoved up past the
elbow, faded grey-blue overalls cut as knickerbockers (full at the hip, gathered
below the knee) with a patch on one knee, long socks, ankle boots and a flat
cap over curly brown hair.

He is modelled in a T-pose. His body (torso, arms to the sleeve roll, legs to
the ankle, and neck) is ONE continuous surface: a stick figure of points, each
with a thickness, is skinned and then smoothed, so shoulders and hips are
real joins rather than parts pushed together. The waistband, the rolled
sleeves, the knee bands and the collar are steps in that one surface, where a
thick point sits right beside a thin one. The bib and braces of the overalls
are laid on that surface afterwards. Each forearm and hand is one surface too,
from inside the sleeve to the knuckles, so there is no join at the wrist.
Head, hair, fingers and boots are separate shapes, and the cap is an object of
its own, on a bone of its own, so it can ride loose on his head, or be left
off: the curls on top of his head, which it hides, are another (`boy_crown`),
shown only then.

Besides the bones that carry him he has bones that only follow: one down each
finger joint and a few through his hair, which the rig lets swing on springs.

Everything is in Godot space (metres, Y up, facing +Z, +X his left). The rig
(scripts/character_rig.gd) reads his proportions from the bones, so nothing
here needs copying anywhere else.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (shared shape-building and export tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

# --- Joints ---

# He is growing: long in the leg and short in the body for his height.
ANKLE_Y = 0.05
THIGH = SHIN = 0.275
HIP_X = 0.074
HIP_Y = ANKLE_Y + THIGH + SHIN
HIPS = Vector((0.0, HIP_Y + 0.02, 0.0))
SPINE = Vector((0.0, 0.665, 0.0))
CHEST = Vector((0.0, 0.79, 0.0))
NECK = Vector((0.0, 0.95, 0.0))
HEAD = Vector((0.0, 1.012, 0.0))
SHOULDER = Vector((0.135, 0.895, 0.0))
UPPER_ARM = 0.185
FOREARM = 0.165
ELBOW_X = SHOULDER.x + UPPER_ARM
WRIST_X = ELBOW_X + FOREARM
KNEE_Y = HIP_Y - THIGH
TOE = Vector((0.0, -0.035, 0.075))
HEAD_CENTRE = Vector((0.0, 1.108, 0.006))
HEAD_RADII = Vector((0.103, 0.136, 0.113))

SHIRT, DENIM, SKIN, HAIR, SOCKS, LEATHER, BRASS, PATCH, TWEED, EYES, MOUTH, JACKET, WAISTCOAT, APRON, BRACES, EYEWHITE, IRIS, PUPIL, HAIRWAVY = range(19)
MATERIALS = [
    ("shirt", (0.90, 0.85, 0.72)),
    ("overalls", (0.47, 0.55, 0.65)),
    ("skin", (0.82, 0.66, 0.55)),
    ("hair", (0.23, 0.165, 0.12)),
    ("socks", (0.60, 0.56, 0.50)),
    ("boots", (0.25, 0.15, 0.09)),
    ("brass", (0.76, 0.60, 0.26)),
    ("patch", (0.55, 0.45, 0.34)),
    ("cap", (0.39, 0.46, 0.55)),
    # What he does not wear as he is made, but may be given (see "Other turn-outs" below).
    ("eyes", (0.13, 0.09, 0.07)),
    ("mouth", (0.60, 0.37, 0.32)),
    ("jacket", (0.40, 0.34, 0.27)),
    ("waistcoat", (0.31, 0.30, 0.33)),
    ("apron", (0.93, 0.91, 0.84)),
    ("braces", (0.56, 0.40, 0.25)),
    # The eyes of the sculpted face: the white of each, the ring of colour and the dark of it.
    ("eyewhite", (0.93, 0.91, 0.86)),
    ("iris", (0.36, 0.25, 0.16)),
    ("pupil", (0.05, 0.04, 0.04)),
    # Hair again, for the cuts that are waved rather than curled: the game shades
    # whatever has this material with its other hair shader (Toon.WAVY_HAIR_SHADER),
    # in the colour of his hair.
    ("hairwavy", (0.23, 0.165, 0.12)),
]

# Where one garment ends and the next begins on the body.
WAIST_Y = 0.703
BAND_Y = 0.231
COLLAR_Y = 0.957
NECK_RADIUS = 0.039
SLEEVE_X = ELBOW_X + 0.046

# Hair bones: (name, angle round the head from the front, how far up the head it roots).
HAIR_BONES = [("hair_f", 0.0, 0.085), ("hair_l", math.pi / 2, 0.05), ("hair_b", math.pi, 0.03), ("hair_r", -math.pi / 2, 0.05)]

# Fingers, index to little: (offset across the palm, length, thickness, how far it
# fans out from the middle of the hand). They are modelled straight and spread, so
# each is its own shape; the rig gathers and curls them.
FINGERS = [(0.0245, 0.042, 0.0079, 0.30), (0.0082, 0.046, 0.0081, 0.10), (-0.0082, 0.043, 0.0079, -0.10), (-0.0245, 0.034, 0.0072, -0.30)]
# Where a finger bends, as shares of its length.
KNUCKLES = (0.0, 0.42, 0.74)
PALM = 0.058
THUMB_LENGTH = 0.05

# What another figure built on these shapes may want otherwise (tools/build_brother.py does).
# Where the body is flattened front to back: fully inside the first distance from his
# middle and not at all beyond the second, and from the first height up to the second.
FLAT = (0.12, 0.17, 0.5, 0.64)
# The bare forearm and palm: (height above the wrist, half thickness, half width).
# Round in the forearm, flattening through the wrist and widening to the knuckles.
FOREARM_SHAPE = [(0.132, 0.0270, 0.0275), (0.100, 0.0268, 0.0275), (0.066, 0.0235, 0.0255), (0.038, 0.0190, 0.0228),
                 (0.016, 0.0158, 0.0212), (0.0, 0.0142, 0.0218), (-0.022, 0.0128, 0.0288), (-0.045, 0.0116, 0.0330), (-0.058, 0.0105, 0.0320)]
# His curls, in rows: (how far down from the cap towards the hairline, how many round the head, length)
HAIR_ROWS = ((0.97, 17, 0.036), (0.66, 17, 0.042), (0.36, 16, 0.044), (0.06, 14, 0.046))
# How much longer it is left down the back of his head than over his ears: a
# mullet as it is cut now, short at the sides and only a little long behind.
MULLET = 0.12
# The rows at the nape, down over his collar: (how far below the hairline, how many, length)
NAPE = ((-0.1, 9, 0.034), (-0.3, 7, 0.04))
# The forelock: (angle round from the front, how far down from the cap, length)
FORELOCK = ((-0.66, 0.5, 0.040), (-0.40, 0.3, 0.046), (-0.14, 0.5, 0.040), (0.14, 0.8, 0.032), (0.42, 0.9, 0.030), (-0.90, 0.4, 0.038), (0.70, 0.7, 0.032))

# The finished body, to lay the bib and braces on (see `body` and `onto_body`),
# and to cut a garment out of (see `shell`).
SURFACE = None
BODY = None


def body_graph():
    """The stick figure: points (position, thickness) and the lines joining them.

    A thick point right beside a thin one makes a step in the surface: that is
    how the waistband, the sleeve rolls, the knee bands and the collar are made.
    """
    points = []
    lines = []

    def chain(start, steps):
        last = start
        for position, thickness in steps:
            points.append((Vector(position), thickness))
            if last is not None:
                lines.append((last, len(points) - 1))
            last = len(points) - 1
        return last

    # Up the middle: a full seat, the waistband, the shirt tucked into it, chest, collar, neck
    chain(None, [((0.0, 0.612, 0.0), 0.106)])
    hips = 0
    chain(hips, [((0.0, 0.66, 0.0), 0.107), ((0.0, 0.692, 0.0), 0.106), ((0.0, 0.701, 0.0), 0.105),
                 ((0.0, 0.709, 0.0), 0.097), ((0.0, 0.75, 0.0), 0.100), ((0.0, 0.82, 0.0), 0.107)])
    chest = chain(len(points) - 1, [((0.0, 0.888, 0.0), 0.103)])
    # The collar is a soft band round the base of a neck that carries on up into the head.
    chain(chest, [((0.0, 0.936, 0.0), 0.064), ((0.0, 0.950, 0.0), 0.056), ((0.0, 0.958, 0.0), 0.046),
                  ((0.0, 0.966, 0.0), NECK_RADIUS), ((0.0, 1.00, 0.0), NECK_RADIUS - 0.002), ((0.0, 1.06, 0.0), NECK_RADIUS - 0.002)])
    for side in (1.0, -1.0):
        # Arm: a loose sleeve from the shoulder, shoved up past the elbow, where it
        # bunches in a couple of uneven rolls. The bare forearm comes out of it
        # as part of the hand (see `hands`).
        chain(chest, [((side * 0.118, 0.893, 0.0), 0.062), ((side * 0.175, 0.895, 0.0), 0.052),
                      ((side * 0.25, 0.893, 0.0), 0.049), ((side * ELBOW_X, 0.894, -0.004), 0.046),
                      ((side * (SLEEVE_X - 0.022), 0.895, -0.003), 0.045), ((side * (SLEEVE_X - 0.014), 0.897, -0.003), 0.053),
                      ((side * (SLEEVE_X - 0.005), 0.894, -0.002), 0.049), ((side * (SLEEVE_X + 0.003), 0.895, -0.004), 0.055),
                      ((side * (SLEEVE_X + 0.011), 0.895, -0.003), 0.051), ((side * (SLEEVE_X + 0.018), 0.895, -0.003), 0.033)])
        # Leg: knickerbockers, full from the hip and bagging over the band that
        # gathers them below the knee; then a long sock over the calf
        chain(hips, [((side * HIP_X, 0.585, 0.0), 0.083), ((side * 0.084, 0.49, 0.002), 0.080),
                     ((side * 0.084, 0.38, 0.004), 0.073), ((side * 0.083, 0.305, 0.008), 0.069),
                     ((side * 0.082, 0.268, 0.004), 0.064), ((side * 0.08, 0.252, 0.0), 0.046),
                     ((side * 0.08, 0.238, 0.0), 0.045), ((side * 0.08, 0.229, 0.0), 0.037),
                     ((side * 0.08, 0.185, -0.005), 0.040), ((side * 0.08, 0.11, -0.002), 0.031),
                     ((side * 0.08, 0.02, 0.0), 0.027)])
    return points, lines


def region(p):
    """Which cloth a point of the body is: shirt, overalls, sock or the skin of his neck."""
    if p.y > COLLAR_Y and math.hypot(p.x, p.z) < NECK_RADIUS + 0.012:
        return SKIN
    if p.y < BAND_Y:
        return SOCKS
    if p.y < WAIST_Y and abs(p.x) < 0.25:
        return DENIM
    return SHIRT


def body(_builder, graph=None, cloth=None, striped=True, slits=()):
    """Skins the stick figure into one surface, smooths it, and colours its regions.
    (`graph` and `cloth` make another body than his own: see "Other turn-outs".)"""
    global SURFACE, BODY
    points, lines = (graph or body_graph)()
    mesh = bpy.data.meshes.new("body")
    mesh.from_pydata([kit.to_blender(position) for position, _ in points], lines, [])
    figure = bpy.data.objects.new("body", mesh)
    bpy.context.collection.objects.link(figure)
    skin = figure.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    # Smoothing afterwards draws the surface in a little; start slightly thick.
    swell = 1.0 if kit.LOW else 1.12
    for index, (_, thickness) in enumerate(points):
        vertex = mesh.skin_vertices[0].data[index]
        vertex.radius = (thickness * swell, thickness * swell)
        vertex.use_root = index == 0
    smooth = figure.modifiers.new("smooth", "SUBSURF")
    smooth.levels = 1 if kit.LOW else 2
    bpy.context.view_layer.update()
    skinned = bpy.data.meshes.new_from_object(figure.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(figure)

    for vertex in skinned.vertices:
        p = kit.from_blender(vertex.co)
        # A chest is wider than it is deep; arms and legs stay round.
        flatten = 1.0 - (0.18 - 0.18 * blend(FLAT[0], FLAT[1], abs(p.x))) * blend(FLAT[2], FLAT[3], p.y)
        vertex.co = kit.to_blender(Vector((p.x, p.y, p.z * flatten)))
    if slits:
        # The surface is slit along lines (each a point on a plane, the way it
        # faces, and which faces it may cut), so that cloth can change along them cleanly.
        slit = bmesh.new()
        slit.from_mesh(skinned)
        for at, facing, where in slits:
            faces = [face for face in slit.faces if where(kit.from_blender(face.calc_center_median()))]
            geom = set(faces) | {edge for face in faces for edge in face.edges} | {vertex for face in faces for vertex in face.verts}
            bmesh.ops.bisect_plane(slit, geom=list(geom), dist=1e-6, plane_co=kit.to_blender(Vector(at)), plane_no=kit.to_blender(Vector(facing)))
        slit.to_mesh(skinned)
        slit.free()
        skinned.update()
    for face in skinned.polygons:
        face.material_index = (cloth or region)(kit.from_blender(face.center))
    SURFACE = BVHTree.FromPolygons([vertex.co.copy() for vertex in skinned.vertices], [tuple(face.vertices) for face in skinned.polygons])
    # Which way the cloth runs, for the stripe in his shirt (see Toon): the first
    # texture coordinate is how far round him a point is, in metres, so a stripe
    # is a line of it. Down his body that is side to side; along a sleeve, round it.
    # (written through a bmesh, as every other part's are, so the layer is the one they share)
    marked = bmesh.new()
    marked.from_mesh(skinned)
    stripes = marked.loops.layers.uv.verify()
    for face in marked.faces:
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            sleeve = blend(0.13, 0.17, abs(p.x)) if p.y > 0.8 else 0.0
            round_arm = math.atan2(p.z, p.y - SHOULDER.y) * 0.05
            loop[stripes].uv = (p.x * (1.0 - sleeve) + round_arm * sleeve if striped else 0.0, p.y)
    marked.to_mesh(skinned)
    if BODY is not None:
        BODY.free()
    BODY = marked
    return skinned


def onto_body(point):
    """The place on the body's surface nearest `point` (which is outside it), and which way the surface faces there."""
    location, normal, _index, _distance = SURFACE.find_nearest(kit.to_blender(point))
    at, facing = kit.from_blender(location), kit.from_blender(normal).normalized()
    return at, (facing if facing.dot(point - at) >= 0.0 else -facing)


def rounded(guides, widths, passes=2):
    """Cuts the corners off a line of points (and the widths that go with them)."""
    for _ in range(passes):
        points, wide = [guides[0]], [widths[0]]
        for i in range(len(guides) - 1):
            for t in (0.25, 0.75):
                points.append(guides[i].lerp(guides[i + 1], t))
                wide.append(widths[i] + (widths[i + 1] - widths[i]) * t)
        guides, widths = points + [guides[-1]], wide + [widths[-1]]
    return guides, widths


def ribbon(b, guides, widths, lift, steps, columns=4):
    """A strip of cloth lying on the body: it follows `guides` (points just outside
    him), is as wide as `widths` says at each, stands `lift` off the surface, and
    its edges are turned under so it has a thickness."""
    if kit.LOW:
        steps, columns = max(steps // 2, 2), 2
    guides, widths = rounded([Vector(guide) for guide in guides], list(widths))
    lengths = [0.0]
    for a, c in zip(guides, guides[1:]):
        lengths.append(lengths[-1] + (c - a).length)
    centres = []
    for k in range(steps + 1):
        distance = lengths[-1] * k / steps
        i = max(j for j in range(len(guides) - 1) if lengths[j] <= distance + 1e-9)
        t = (distance - lengths[i]) / max(lengths[i + 1] - lengths[i], 1e-9)
        at, facing = onto_body(guides[i].lerp(guides[i + 1], t))
        centres.append((at, facing, widths[i] + (widths[i + 1] - widths[i]) * t))
    top, under = [], []
    for k, (at, facing, width) in enumerate(centres):
        along = (centres[min(k + 1, steps)][0] - centres[max(k - 1, 0)][0]).normalized()
        across = facing.cross(along).normalized()
        row, below = [], []
        for m in range(columns + 1):
            p, n = onto_body(at + facing * 0.02 + across * width * (m / columns - 0.5))
            row.append(b._vert(p + n * lift, None))
            below.append(p - n * 0.006)
        top.append(row)
        under.append(below)
    faces = []
    for k in range(steps):
        for m in range(columns):
            faces.append(b.bm.faces.new((top[k][m], top[k][m + 1], top[k + 1][m + 1], top[k + 1][m])))
    rim = ([(k, 0) for k in range(steps + 1)] + [(steps, m) for m in range(1, columns + 1)]
           + [(k, columns) for k in range(steps - 1, -1, -1)] + [(0, m) for m in range(columns - 1, 0, -1)])
    turned = {at: b._vert(under[at[0]][at[1]], None) for at in rim}
    for a, c in zip(rim, rim[1:] + rim[:1]):
        faces.append(b.bm.faces.new((top[a[0]][a[1]], top[c[0]][c[1]], turned[c], turned[a])))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    faces[0].normal_update()
    if faces[0].normal.dot(kit.to_blender(centres[0][1])) < 0.0:
        bmesh.ops.reverse_faces(b.bm, faces=faces)


# Where each brace leaves the bib, and where it is buttoned to the waistband behind.
BIB_TOP = 0.792
BRACE_X = 0.072


def bib(b):
    """The front of the overalls and the braces that hold it up, crossed behind."""
    out = 0.115
    # (a low, broad flap: it comes barely a hand above the waistband, and nearly as wide as he is)
    ribbon(b, [(0.0, 0.690, out), (0.0, 0.74, out), (0.0, BIB_TOP + 0.008, out)], [0.198, 0.19, 0.178], 0.0045, 8, 8)
    # A patch pocket, wider than it is deep
    ribbon(b, [(0.0, 0.726, out), (0.0, 0.76, out)], [0.084, 0.088], 0.008, 3, 4)
    for side in (1.0, -1.0):
        # Up from the corner of the bib, over the shoulder, and down across the
        # back to the other hip. One lies over the other where they cross.
        # (over the middle of the shoulder, well out from his collar and his neck)
        ribbon(b, [(side * BRACE_X, BIB_TOP - 0.03, out), (side * 0.082, 0.87, 0.11), (side * 0.098, 0.95, 0.07), (side * 0.104, 1.0, 0.0),
                   (side * 0.096, 0.95, -0.08), (side * 0.070, 0.88, -out), (side * 0.030, 0.81, -out), (-side * 0.022, 0.75, -out), (-side * 0.058, 0.688, -out)],
               [0.030] * 9, 0.0095 if side > 0.0 else 0.007, 30, 3)


def knee_patch(b):
    """A big square of other cloth sewn over the left knee, where he has been through it."""
    out = 0.12
    ribbon(b, [(0.084, 0.378, out), (0.084, 0.328, out), (0.084, 0.278, out)], [0.12, 0.12, 0.12], 0.004, 6, 6)


def buttons(b):
    for side in (1.0, -1.0):
        for point, lift in (((side * BRACE_X, BIB_TOP - 0.014, 0.115), 0.0125), ((-side * 0.058, 0.70, -0.115), 0.012)):
            at, facing = onto_body(Vector(point))
            b.ellipsoid(at + facing * lift, Vector((0.0085, 0.0085, 0.0045)), None, 8, 3)


def head(b):
    # An egg, narrowing to the chin. No face.
    rings = []
    for k in range(1, 14):
        phi = -math.pi / 2 + math.pi * k / 14
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        rings.append(kit.upright(0.0, HEAD_CENTRE.y + HEAD_RADII.y * s, HEAD_CENTRE.z + 0.012 * jaw,
                                 HEAD_RADII.x * c * (1.0 - 0.2 * jaw ** 1.5), HEAD_RADII.z * c))
    b.tube(rings, 24)
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.099, -0.016, -0.012)), Vector((0.012, 0.027, 0.018)), None, 8, 5)


def on_head(angle, height, lift=0.0):
    """A point on the head's surface: `angle` round from the front, `height` above its middle."""
    across = math.sqrt(max(0.0, 1.0 - (height / HEAD_RADII.y) ** 2)) + lift
    return HEAD_CENTRE + Vector((math.sin(angle) * HEAD_RADII.x * across, height, math.cos(angle) * HEAD_RADII.z * across))


# The cap sits a little back on his head: its band is higher over the brow than at the nape.
CAP_TILT = -0.16
CAP_BAND = 0.050


def cap(b):
    """A flat cap: a band, a full soft crown pulled forward over it, a broad stiff peak and a button."""
    tilt = Matrix.Rotation(CAP_TILT, 3, "X")

    def ring(y, rx, rz, forward=0.0, dip=0.0):
        lean = Matrix.Rotation(dip, 3, "X")
        return (HEAD_CENTRE + tilt @ Vector((0.0, y, forward)), tilt @ (X * rx), tilt @ lean @ (Z * rz))

    # (the crown stands out all round over the band, most of all in front, and slopes down to the peak)
    crown = [ring(CAP_BAND - 0.006, 0.107, 0.117), ring(CAP_BAND, 0.110, 0.120), ring(CAP_BAND + 0.020, 0.107, 0.117, 0.002),
             ring(CAP_BAND + 0.030, 0.124, 0.134, 0.010, 0.08), ring(CAP_BAND + 0.050, 0.130, 0.142, 0.016, 0.14),
             ring(CAP_BAND + 0.076, 0.118, 0.132, 0.017, 0.20), ring(CAP_BAND + 0.096, 0.088, 0.100, 0.014, 0.22),
             ring(CAP_BAND + 0.104, 0.042, 0.048, 0.012, 0.22)]
    b.tube(crown, 24)
    # The peak: flush with the band at its root, a crescent beyond it, dipping a little
    peak = []
    for z, half in ((0.058, 0.102), (0.088, 0.102), (0.117, 0.096), (0.145, 0.083), (0.169, 0.063), (0.185, 0.038)):
        peak.append((HEAD_CENTRE + tilt @ Vector((0.0, CAP_BAND + 0.004 - 0.16 * (z - 0.058), z)), tilt @ (X * half), tilt @ (Y * 0.0055)))
    b.tube(peak + kit.dome(peak[-1], tilt @ Z, 0.008, 2), 12)
    b.ellipsoid(HEAD_CENTRE + tilt @ Vector((0.0, CAP_BAND + 0.107, 0.011)), Vector((0.012, 0.006, 0.012)), tilt, 8, 3)


# His other cut, kept as a choice (see `hair_long`, and Settings.hair in the
# game): long curls, full over his ears and down past his collar. As MULLET
# and NAPE; then how long and how full it is over his ears and behind
# (each: at the side, and how much more behind), and how far the nape stands off.
LONG_CURLS = (0.9, ((-0.1, 9, 0.085), (-0.3, 7, 0.105)), (0.62, 0.73), (0.72, 0.28), (2.6, 0.8))


def press_under_cap(b):
    """Flattens whatever hair is built so far where the band of the cap sits on it."""
    cap_tilt = Matrix.Rotation(CAP_TILT, 3, "X")
    for vertex in b.bm.verts:
        q = cap_tilt.inverted() @ (kit.from_blender(vertex.co) - HEAD_CENTRE)
        wide = math.hypot(q.x / 0.101, q.z / 0.111)
        pressed = blend(CAP_BAND - 0.022, CAP_BAND - 0.008, q.y)
        if wide > 1.0 and pressed > 0.0:
            squeeze = 1.0 + (1.0 / wide - 1.0) * pressed
            vertex.co = kit.to_blender(HEAD_CENTRE + cap_tilt @ Vector((q.x * squeeze, q.y, q.z * squeeze)))


def hair(b, crown_only=False, long=False, forelock="with"):
    # (`forelock`: the curls loose over his brow under the peak of his cap are
    # made "with" the rest, or left out ("without"), or are all that is made
    # ("only"). The boy has them as an object of their own, shown with his cap:
    # bareheaded, his hair is combed up off his forehead instead.)
    mullet_by, nape, lengths, bulks, stand = LONG_CURLS if long else (MULLET, NAPE, (0.28, 0.5), (0.5, 0.35), (1.1, 0.3))
    # A close layer over the scalp, tilted back so it sits high on the brow and
    # comes down to the nape: what shows of it, under the cap, is dark between the curls.
    tilt = Matrix.Rotation(-0.6, 3, "X")
    cap_tilt = Matrix.Rotation(CAP_TILT, 3, "X")
    crown = HEAD_CENTRE + Vector((0.0, 0.010, -0.004))
    grown = HEAD_RADII + Vector((0.008, 0.009, 0.009))
    rim = -0.22

    def on_scalp(angle, phi, lift=0.0):
        c, s = math.cos(phi), math.sin(phi)
        if crown_only and phi > 0.0:
            # (bareheaded, his hair is fullest above his temples, not an egg coming to a point: see ROUND)
            lift += (grown.y + lift) * ROUND * math.sin(2.0 * phi) ** 2
        return crown + tilt @ Vector((math.sin(angle) * (grown.x + lift) * c, (grown.y + lift) * s, math.cos(angle) * (grown.z + lift) * c))

    scalp = []
    for k in range(10):
        phi = rim + (math.pi / 2 - rim) * k / 10
        c, s = math.cos(phi), math.sin(phi)
        scalp.append((crown + tilt @ (Y * grown.y * s), tilt @ (X * grown.x * c), tilt @ (Z * grown.z * c)))
    if forelock == "only":
        pass
    elif crown_only:
        # (bareheaded: the same scalp, a shade fuller, not pressed down by anything)
        # (from above where the hairline is: lower down, the hair he always has covers him)
        b.tube([(centre, u * 1.01, v * 1.01) for centre, u, v in scalp[3:]], 24)
    else:
        b.tube(scalp, 24)
    # Where the cap sits on it, it is pressed flat: it must not show through the band.
    if not crown_only and forelock != "only":
        press_under_cap(b)

    # ...and the curls: ringlets crowding out from under the cap, over his ears and
    # thick down the back of his neck, with a few got loose over his forehead. No
    # two are alike in length, in how tightly they are wound, or in which way.
    rng = random.Random(23 if crown_only else 11)

    def under_cap(angle):
        # How far up the scalp the cap's band comes at this angle (it is lower in front)
        return 0.38 - 0.44 * math.cos(angle)

    def under(point, radius):
        """Keeps a curl out of the cap: nothing of it comes above the band, or the peak in front."""
        q = cap_tilt.inverted() @ (point - HEAD_CENTRE)
        ceiling = min(CAP_BAND - 0.006, CAP_BAND - 0.0015 - 0.16 * (q.z - 0.058)) - radius - 0.002
        if q.y <= ceiling:
            return point
        return HEAD_CENTRE + cap_tilt @ Vector((q.x, ceiling, q.z))

    def ringlet(angle, share, length, loose, bulk=1.0, flare=1.0, top=None, sweep=None):
        phi = rim + (under_cap(angle) - rim) * share
        if top is not None:
            phi = top
        # (it roots below the band of the cap, not up inside it)
        while top is None and phi > rim and under(on_scalp(angle, phi, 0.006), 0.009) != on_scalp(angle, phi, 0.006):
            phi -= 0.02
        root = on_scalp(angle, phi, -0.002)
        out = (root - HEAD_CENTRE).normalized()
        down = (on_scalp(angle + rng.uniform(-0.25, 0.25), phi - 0.25) - root).normalized()
        down = (down * (1.0 - loose) + Vector((0.0, -1.0, 0.0)) * loose).normalized()
        if sweep is not None:
            # (combed, not left to fall: it lies the way it is swept)
            down = (sweep - out * sweep.dot(out) * 0.6).normalized()
        across = down.cross(out).normalized()
        if kit.LOW:
            b.ellipsoid(root + down * length * 0.45 + out * 0.012 * bulk, Vector((0.022, 0.026, 0.022)) * (0.5 + 0.5 * bulk), None, 6, 2)
            return
        wound = rng.uniform(0.95, 1.4) * rng.choice((-1.0, 1.0))
        start = rng.uniform(0.0, math.tau)
        coil = rng.uniform(0.011, 0.015) * bulk
        thick = rng.uniform(0.0115, 0.0145) * (0.4 + 0.6 * bulk)
        count = 11
        points, radii = [], []
        for k in range(count):
            t = k / (count - 1)
            turn = start + math.tau * wound * t
            centre = root + down * length * t + out * (0.004 + 0.016 * t * bulk * flare)
            # (it starts tight against the scalp and opens out, so its root does not push up into the cap)
            points.append(centre + (out * math.cos(turn) + across * math.sin(turn)) * coil * (0.2 + 0.8 * min(t * 2.0, 1.0)))
            radii.append(thick * (1.0 - 0.4 * t * t))
            if top is None:
                points[-1] = under(points[-1], radii[-1])
        b.strand(points, radii, 5)

    if forelock == "only":
        for angle, share, length in (() if kit.LOW else FORELOCK):
            ringlet(angle, share, length, 0.5)
        return
    if crown_only:
        # What his cap hides: curls all over his head from where its band sat
        # to the crown, close enough together that no scalp shows between them;
        # and in front a quiff, as boys wore it in the twenties: the hair over
        # his brow combed up and back in a wave, a little to one side.
        # Short and lying close everywhere but the front.
        for phi, count in ((0.08, 22), (0.3, 20), (0.52, 17), (0.78, 14), (1.05, 10), (1.3, 6)):
            for k in range(count // 2 if kit.LOW else count):
                angle = math.tau * (k + rng.uniform(0.1, 0.9)) / count
                angle = (angle + math.pi) % math.tau - math.pi
                at = phi + rng.uniform(-0.07, 0.07)
                if abs(angle) < 0.85 and phi < 0.7:
                    # The quiff: longest at the front and in the middle, standing up off his forehead
                    front = (1.0 - abs(angle) / 0.85) * (1.0 - blend(0.3, 0.7, phi))
                    # (combed back over his head and lying on it: stood straight up, it made a peak of his crown)
                    sweep = Vector((-0.3, 0.45 - 0.45 * blend(0.05, 0.6, phi), -0.75 - 0.2 * blend(0.05, 0.6, phi))).normalized()
                    ringlet(angle, 0.0, rng.uniform(0.04, 0.05) * (0.6 + 0.7 * front), 0.0, 0.55 + 0.4 * front, 0.2, at + 0.12, sweep)
                else:
                    ringlet(angle, 0.0, rng.uniform(0.022, 0.03), 0.0, 0.45, 0.15, at)
        # (and along his hairline, short ones brushed up into it, so no scalp shows under the quiff)
        for row, low in enumerate((-0.12, 0.0, 0.14)):
            for k in range(5 if kit.LOW else 11):
                angle = -0.95 + 1.9 * (k + rng.uniform(0.2, 0.8)) / (5 if kit.LOW else 11)
                ringlet(angle, 0.0, rng.uniform(0.024, 0.032), 0.0, 0.5, 0.15, low + rng.uniform(-0.04, 0.04), Vector((-0.15, 1.0, -0.1)).normalized())
        return

    for share, count, length in HAIR_ROWS:
        if kit.LOW:
            count = count // 2
        for k in range(count):
            angle = math.tau * (k + rng.uniform(0.15, 0.85)) / count
            angle = (angle + math.pi) % math.tau - math.pi
            # Not over the face
            if abs(angle) < 1.12 + 0.2 * share:
                continue
            behind = blend(1.6, 2.6, abs(angle))
            # Cut shorter and closer over his ears than behind, where it is left long:
            # the further down the back of his head, the longer.
            mullet = behind * (1.0 - share) * mullet_by
            ringlet(angle, share, length * rng.uniform(0.8, 1.2) * (lengths[0] + lengths[1] * behind + mullet), 0.25 + 0.3 * (1.0 - share) + 0.2 * mullet, bulks[0] + bulks[1] * behind, 1.0 + mullet)
    # And longest at the nape, down over his collar and standing off his neck
    for row, (share, count, length) in enumerate(nape):
        for k in range(count // 2 if kit.LOW else count):
            ringlet(math.pi + (k - (count - 1) / 2) * 0.2 + rng.uniform(-0.06, 0.06), share, length * rng.uniform(0.85, 1.15), 0.7, 1.0, stand[0] + stand[1] * row)
    # The forelock, off to his right under the peak of the cap
    for angle, share, length in (() if kit.LOW or forelock != "with" else FORELOCK):
        ringlet(angle, share, length, 0.5)


def hair_short(b):
    hair(b, False, False, "without")


def hair_forelock(b):
    hair(b, False, False, "only")


def hair_crown(b):
    hair(b, True)


def hair_long(b):
    hair(b, False, True, "without")


def arm_out(side):
    """Moves a point modelled on an arm hanging at his side out to the T-pose."""
    shoulder = Vector((side * SHOULDER.x, SHOULDER.y, 0.0))
    turn = Matrix.Rotation(side * math.pi / 2, 3, "Z")
    return lambda p: shoulder + turn @ (p - shoulder)


def hand_wrist(side):
    """The wrist of an arm hanging at his side, which is how the hand is modelled."""
    return Vector((side * SHOULDER.x, SHOULDER.y - UPPER_ARM - FOREARM, 0.003))


def finger_line(side, index):
    """A finger's knuckle and the way it points, on the hanging arm."""
    z, _length, _radius, fan = FINGERS[index]
    return hand_wrist(side) + Vector((0.0, -PALM, z)), Vector((0.0, -math.cos(fan), math.sin(fan)))


def thumb_line(side):
    inward = -side
    return hand_wrist(side) + Vector((inward * 0.004, -0.014, 0.020)), Vector((inward * 0.22, -0.72, 0.66)).normalized()


def hands(b):
    """Each bare forearm and the palm it ends in, as one surface: it starts up
    inside the rolled sleeve, so the only edge to see is cloth against skin."""
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        wrist = hand_wrist(side)
        inward = -side  # hanging, the palm faces the body; held out, it faces down
        rings = [(wrist + Y * dy - Z * 0.003 * blend(0.0, 0.1, dy), X * rx, Z * rz) for dy, rx, rz in FOREARM_SHAPE]
        b.tube(rings + kit.dome(rings[-1], -Y, 0.008, 2), 12)
        if kit.LOW:
            # Demade: the fingers are a single curled mitt
            mitt = [(-0.058, 0.0, 0.0105, 0.030), (-0.082, 0.006, 0.0095, 0.028), (-0.100, 0.016, 0.008, 0.022)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
            root = wrist + Vector((inward * 0.003, -0.012, 0.018))
            b.strand([root, root + Vector((inward * 0.004, -0.018, 0.016)), root + Vector((inward * 0.011, -0.036, 0.022)),
                      root + Vector((inward * 0.018, -0.050, 0.022))], [0.0115, 0.0108, 0.0096, 0.0084])
    b.place = None


def fingers(b):
    """Straight and spread, with a ring of points either side of each joint so they bend cleanly."""
    if kit.LOW:
        return
    spans = (-0.12, 0.0, 0.14, 0.30, 0.42, 0.54, 0.64, 0.74, 0.84, 1.0)
    for side in (1.0, -1.0):
        b.place = arm_out(side)
        for index, (_z, length, radius, _fan) in enumerate(FINGERS):
            knuckle, along = finger_line(side, index)
            b.strand([knuckle + along * length * t for t in spans], [radius * (1.0 - 0.22 * max(t, 0.0)) for t in spans])
        root, along = thumb_line(side)
        b.strand([root + along * THUMB_LENGTH * t for t in (-0.2, 0.0, 0.25, 0.5, 0.75, 1.0)], [0.0105, 0.0108, 0.0102, 0.0096, 0.009, 0.0082])
    b.place = None


BOOT_TOP = 0.122


def boots(b):
    for side in (1.0, -1.0):
        ankle = Vector((side * 0.08, ANKLE_Y, 0.0))
        floor = 0.0

        def across(z, y, rx, ry, ankle=ankle):
            return (ankle + Vector((0.0, y, z)), X * rx, Y * ry)

        # Stout: a heel cup, a blunt toe cap, on a thick sole with a heel to it...
        upper = [
            across(-0.044, -0.018, 0.034, 0.034), across(-0.020, -0.004, 0.041, 0.050), across(0.012, -0.010, 0.043, 0.044),
            across(0.044, -0.022, 0.046, 0.031), across(0.078, -0.027, 0.047, 0.027), across(0.110, -0.029, 0.045, 0.025),
            across(0.132, -0.032, 0.038, 0.020),
        ]
        b.tube(kit.dome(upper[0], -Z, 0.016, 3)[::-1] + upper + kit.dome(upper[-1], Z, 0.02, 3), 16, floor)
        b.tube([(Vector((ankle.x, y, 0.047)), X * 0.050, Z * 0.104) for y in (floor, floor + 0.008, floor + 0.016)], 24)
        b.tube([(Vector((ankle.x, y, -0.022)), X * 0.046, Z * 0.036) for y in (floor, floor + 0.012, floor + 0.024)], 16)
        # ...and laced up over the ankle, the top standing a little open round the sock
        shaft = [(0.030, 0.038, 0.044, 0.004), (0.066, 0.036, 0.041, 0.0), (0.098, 0.0355, 0.040, -0.003),
                 (BOOT_TOP - 0.006, 0.0375, 0.042, -0.004), (BOOT_TOP, 0.0365, 0.041, -0.004), (BOOT_TOP - 0.01, 0.030, 0.034, -0.004)]
        b.tube([kit.upright(ankle.x, y, z, rx, rz) for y, rx, rz, z in shaft], 16)
    for vertex in b.bm.verts:
        vertex.co.z = max(vertex.co.z, 0.0)


def ring_share(angle, count, index):
    """How much of a point at `angle` round a ring of `count` bones belongs to bone `index`."""
    apart = abs((angle - math.tau * index / count + math.pi) % math.tau - math.pi)
    return max(0.0, 1.0 - apart / (math.tau / count))


# How much further down the thigh takes over at the back of his seat than at the
# front: (where it starts to, where it has it all), in metres.
SEAT = (0.02, 0.10)


def seat_share(p):
    """How far round behind the hip joint a point is: 0 in front of it, 1 at the back of his seat."""
    return blend(0.005, -0.055, p.z)


def skirt_weights(p):
    """A skirt hangs from the hips and is carried by both thighs: each side by its own, the middle by both."""
    hang = blend(SKIRT_TOP - 0.01, 0.55, p.y) * 0.85
    low = blend(0.72, 0.62, p.y)
    left = blend(-0.10, 0.10, p.x)
    return {"hips": (1.0 - hang) * low, "spine": (1.0 - hang) * (1.0 - low), "thigh_l": hang * left, "thigh_r": hang * (1.0 - left)}


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    # (a part that is one choice of several is named `<slot>__<option>`)
    kind, _, option = part.partition("__")
    if part == "face__sculpt":
        # (his eyeballs, each on a bone of its own, which the rig turns to look)
        return {"eye_l" if p.x >= 0.0 else "eye_r": 1.0}
    if part in ("head", "crown", "hairtop__crown") or kind in ("face", "head"):
        return {"head": 1.0}
    if part == "cap":
        return {"cap": 1.0}
    if kind == "skirt" or (part == "over__pinafore" and p.y < SKIRT_TOP):
        return skirt_weights(p)
    if option == "plaits" and p.y < HEAD_CENTRE.y - 0.05 and abs(p.x) > 0.045:
        # A plait hangs from her head and lies on her chest: it belongs to each
        # at its own end, and swings a little between.
        down = blend(HEAD_CENTRE.y - 0.05, 0.86, p.y)
        return {"head": (1.0 - down) * 0.8, "chest": down * 0.75, "hair" + suffix: 0.2 + 0.05 * down}
    if option == "waves" and p.y < HEAD_CENTRE.y - 0.09 and p.z < 0.0:
        # Hair down her back hangs from her head and lies on her shoulders, as a plait does.
        down = blend(HEAD_CENTRE.y - 0.09, 0.84, p.y)
        held = (1.0 - down) * 0.82 + down * 0.7
        return {"head": (1.0 - down) * 0.82, "chest": down * 0.7, "hair_b": 1.0 - held}
    if kind in ("hair", "hair_long", "forelock", "hairtop"):
        # A curl belongs to the head at its root and, the further it stands off,
        # to whichever hair bones it hangs nearest.
        q = p - HEAD_CENTRE
        off = math.sqrt((q.x / HEAD_RADII.x) ** 2 + (q.y / HEAD_RADII.y) ** 2 + (q.z / HEAD_RADII.z) ** 2)
        loose = blend(1.10, 1.34, off) * 0.9
        if option in FIRM:
            # (combed, oiled or pinned up: it does not swing, however far it stands off)
            loose *= 0.25
        angle = math.atan2(q.x, q.z)
        result = {"head": 1.0 - loose}
        for index, (name, _angle, _height) in enumerate(HAIR_BONES):
            result[name] = loose * ring_share(angle, len(HAIR_BONES), index)
        return result
    if part == "hands":
        # Forearm above the wrist, hand below it, shared across the wrist itself
        hand = blend(WRIST_X - 0.026, WRIST_X + 0.014, abs(p.x))
        return {"forearm" + suffix: 1.0 - hand, "hand" + suffix: hand}
    if part == "fingers":
        # Back on the hanging arm, find the finger this point is on and how far along it.
        shoulder = Vector((side * SHOULDER.x, SHOULDER.y, 0.0))
        q = shoulder + Matrix.Rotation(-side * math.pi / 2, 3, "Z") @ (p - shoulder)
        lines = [("finger%d" % index, finger_line(side, index), FINGERS[index][1], KNUCKLES) for index in range(len(FINGERS))]
        lines.append(("thumb", thumb_line(side), THUMB_LENGTH, (0.0, 0.5)))
        best = None
        for name, (root, along), length, joints in lines:
            t = (q - root).dot(along)
            away = (q - root - along * min(max(t, 0.0), length)).length
            if best is None or away < best[0]:
                best = (away, name, t / length, joints, length)
        _away, name, t, joints, length = best
        soft = 0.005 / length
        shares = [blend(joint - soft, joint + soft, t) for joint in joints]
        result = {"hand" + suffix: 1.0 - shares[0]}
        for k, letter in enumerate("abc"[:len(joints)]):
            result[name + letter + suffix] = shares[k] - (shares[k + 1] if k + 1 < len(joints) else 0.0)
        return result
    if part == "boots":
        # The top of the boot goes with the shin, as the sock inside it does.
        # (over the instep the upper goes with the foot higher up than at the heel, or it parts from the shaft when the ankle bends)
        instep = blend(0.0, 0.05, p.z)
        shin = 1.0 - blend(0.105 + 0.045 * instep, 0.06 + 0.035 * instep, p.y)
        toe = blend(TOE.z - 0.022, TOE.z + 0.022, p.z) * (1.0 - shin)
        return {"shin" + suffix: shin, "foot" + suffix: 1.0 - shin - toe, "toe" + suffix: toe}

    # The body, and what is laid on it: everything is decided by where the point sits in the T-pose.
    reach = abs(p.x)
    arm = blend(0.115, 0.19, reach) if p.y > 0.75 else 0.0
    fore = blend(ELBOW_X - 0.035, ELBOW_X + 0.035, reach)
    # His seat stays with his hips: the further behind the hip joint a point is,
    # the further down it is before the thigh takes it, so that when the thigh
    # comes up (sneaking, sliding) the back of his breeches is not carried
    # forward with it and flattened.
    behind = seat_share(p)
    # (The change from hips to thigh is a long, gentle one, longest behind: a
    # short one folds like card when the thigh comes right up, and leaves his
    # seat a flat flap. In front it is shorter, where the crease of the hip is.)
    leg = blend(HIP_Y + 0.06 - SEAT[0] * behind, HIP_Y - 0.06 - SEAT[1] * behind, p.y)
    # (and from one leg to the other, so the seam between them does not tear into pleats when his knees go apart)
    # (only there, though: below his crotch each leg is its own, or the inside of
    # a thigh that comes up is held back by the other and the leg is pulled flat)
    seam = 0.004 + 0.026 * blend(HIP_Y - 0.17, HIP_Y - 0.10, p.y)
    left = blend(-seam, seam, p.x)
    # The knee likewise: a long change over the kneecap, which is the outside of
    # the bend and must stay round, and a shorter one in the crook behind it.
    kneecap = blend(-0.03, 0.035, p.z)
    knee_span = 0.035 + 0.045 * kneecap
    shin = blend(KNEE_Y + knee_span, KNEE_Y - knee_span, p.y)
    # (trousers that come down over the boot hang from the shin: the foot moves inside them)
    foot = 0.0 if option in ("long", "suit", "braceslong", "waistcoatlong") else blend(0.09, 0.055, p.y)
    # (his waist bends over a long stretch too: the waistband is a step in the
    # surface, and a short bend there stands it out behind him like a shelf)
    low = blend(0.78, 0.58, p.y)
    high = blend(0.73, 0.84, p.y)
    central = reach < 0.09
    neck = blend(0.928, 0.968, p.y) if central else 0.0
    skull = blend(0.99, 1.035, p.y) if central else 0.0
    trunk = (1.0 - arm) * (1.0 - leg)
    result = {
        "hips": trunk * low,
        "spine": trunk * (1.0 - low) * (1.0 - high),
        "chest": trunk * (1.0 - low) * high * (1.0 - neck),
        "neck": trunk * (1.0 - low) * high * neck * (1.0 - skull),
        "head": trunk * (1.0 - low) * high * neck * skull,
        "upper_arm" + suffix: arm * (1.0 - fore),
        "forearm" + suffix: arm * fore,
    }
    # Two helper bones to each leg, which the rig turns half as far as the joint
    # they sit at: `knee` between thigh and shin, `seat` between hips and thigh.
    # What is near a joint is given mostly to its helper, so no part of him has
    # to go the whole angle in one fold: that is what crushed his knees and the
    # seat of his breeches flat when he crouched or brought a knee up.
    at_knee = bump(p.y, KNEE_Y - 0.01, 0.1) * 0.85
    at_hip = bump(p.y, HIP_Y - 0.03 - 0.03 * behind, 0.12) * 0.75
    hips_share = result["hips"]
    result["hips"] = 0.0
    for name, share in (("_l", left), ("_r", 1.0 - left)):
        thigh = leg * share * (1.0 - shin)
        lower = leg * share * shin * (1.0 - foot)
        pelvis = hips_share * share
        result["knee" + name] = (thigh + lower) * at_knee
        result["seat" + name] = (thigh * (1.0 - at_knee) + pelvis) * at_hip
        result["thigh" + name] = thigh * (1.0 - at_knee) * (1.0 - at_hip)
        result["shin" + name] = lower * (1.0 - at_knee)
        result["foot" + name] = leg * share * shin * foot
        result["hips"] += pelvis * (1.0 - at_hip)
    return result


def bump(value, middle, reach):
    """1 at `middle`, falling smoothly to 0 at `reach` either side of it."""
    t = max(0.0, 1.0 - abs(value - middle) / reach)
    return t * t * (3.0 - 2.0 * t)


def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("chest", CHEST, "spine"), ("neck", NECK, "chest"), ("head", HEAD, "neck")]
    for name, angle, height in HAIR_BONES:
        listed.append((name, on_head(angle, height), "head"))
    # The cap turns about the middle of its band.
    listed.append(("cap", HEAD_CENTRE + Matrix.Rotation(CAP_TILT, 3, "X") @ Vector((0.0, CAP_BAND, 0.0)), "head"))
    # His eyes turn about their own middles (the sculpted face has eyeballs; the rig looks with them).
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        listed.append(("eye" + suffix, eye_centre(side), "head"))
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        shoulder = Vector((side * SHOULDER.x, SHOULDER.y, 0.0))
        listed.append(("upper_arm" + suffix, shoulder, "chest"))
        listed.append(("forearm" + suffix, shoulder + X * side * UPPER_ARM, "upper_arm" + suffix))
        listed.append(("hand" + suffix, shoulder + X * side * (UPPER_ARM + FOREARM), "forearm" + suffix))
        out = arm_out(side)
        for index in range(len(FINGERS)):
            knuckle, along = finger_line(side, index)
            parent = "hand" + suffix
            for letter, share in zip("abc", KNUCKLES):
                listed.append(("finger%d%s%s" % (index, letter, suffix), out(knuckle + along * FINGERS[index][1] * share), parent))
                parent = listed[-1][0]
        root, along = thumb_line(side)
        listed.append(("thumba" + suffix, out(root), "hand" + suffix))
        listed.append(("thumbb" + suffix, out(root + along * THUMB_LENGTH * 0.5), "thumba" + suffix))
        # Leg bones are siblings: the rig places each one directly with IK.
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        listed.append(("thigh" + suffix, hip, "hips"))
        listed.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        listed.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
        # (helpers: the rig turns each half as far as its joint; see `weights`)
        listed.append(("knee" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("seat" + suffix, hip, "hips"))
    return listed


# --- Other turn-outs ---
#
# Everything below is a choice: another face, another cut of hair, other clothes.
# Each is an object of its own, named `boy_<slot>__<option>`, and the game shows
# one option for each slot (CharacterRig.restyle; the lists the game offers are
# in scripts/character_look.gd, which must name the options built here). The
# option called `base` is the boy as he was first made.
#
#   body     base (shirt and knickerbockers), long (shirt and long trousers),
#            suit (jacket and long trousers), dress (bodice and stockings: wants a skirt)
#   skirt    dress (base: none)
#   over     base (bib and braces), braces, waistcoat (both on the base body),
#            braceslong, waistcoatlong (on the long one), pinafore (on the dress)
#   patch    base (his knee patch)
#   head     base (an egg, for the faces below), sculpt (a head with a face modelled into it)
#   face     full, light, dots: features set on the egg (base: none, his plain face);
#            sculpt: the eyeballs of the sculpted head
#   hair     base (the mullet), long, and each of CUTS: what of each cut shows
#            whether or not a cap is on
#   hairtop  base (the forelock under the peak of his cap), crown (his curls
#            without it), and for each other cut what a cap would hide
#
# A whole body is made for each kind of clothes, rather than clothes over one
# body, because he is one skinned surface with his clothes as steps in it:
# nothing can be taken off him, and a second surface over the first shows
# through it wherever he bends.

def loft(b, rows, strands=1.0, close=(True, False)):
    """Skins a surface over rows of points, each row going once round. Its texture
    coordinates run (from the first row to the last, round it), as a tube's do;
    `strands` is how many times round the hair shader's streaks repeat."""
    count, last = len(rows[0]), len(rows) - 1
    verts = [[b._vert(point, None) for point in row] for row in rows]
    faces = []

    def face(corners, coords):
        made = b.bm.faces.new(corners)
        for loop, (along, around) in zip(made.loops, coords):
            loop[b.uv].uv = (along / last, around / count * strands)
        faces.append(made)

    for r in range(last):
        for j in range(count):
            k = (j + 1) % count
            face((verts[r][j], verts[r][k], verts[r + 1][k], verts[r + 1][j]), ((r, j), (r, j + 1), (r + 1, j + 1), (r + 1, j)))
    for r, wanted in ((0, close[0]), (last, close[1])):
        if wanted:
            pole = b._vert(sum(rows[r], Vector()) / count, None)
            for j in range(count):
                face((verts[r][j], verts[r][(j + 1) % count], pole), ((r, j), (r, j + 1), (r, j + 0.5)))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)


# --- Faces ---

def face_at(x, h, lift=0.0):
    """A point on the front of his head, `x` across and `h` above its middle, and which way his face looks there."""
    def at(x, h):
        s = max(-0.99, min(0.99, h / HEAD_RADII.y))
        c, jaw = math.sqrt(1.0 - s * s), max(0.0, -s)
        rx = HEAD_RADII.x * c * (1.0 - 0.2 * jaw ** 1.5)
        return HEAD_CENTRE + Vector((x, h, 0.012 * jaw + HEAD_RADII.z * c * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2))))

    out = (at(x + 0.002, h) - at(x - 0.002, h)).cross(at(x, h + 0.002) - at(x, h - 0.002)).normalized()
    return at(x, h) + out * lift, out


def nose(b):
    # A child's: hardly a bridge, and a round end
    b.strand([face_at(0.0, 0.014, -0.005)[0], face_at(0.0, -0.002, 0.0)[0], face_at(0.0, -0.016, 0.004)[0]], [0.0055, 0.007, 0.0085], 6)
    tip, out = face_at(0.0, -0.023)
    b.ellipsoid(tip + out * 0.0045, Vector((0.0115, 0.0100, 0.0115)), None, 8, 4)


def eyes(b, size=1.0, tall=1.4):
    # Dark ovals, set in the surface so that only their fronts show
    for side in (1.0, -1.0):
        at, out = face_at(side * 0.037, 0.003, -0.002)
        b.ellipsoid(at, Vector((0.0092 * size, 0.0092 * size * tall, 0.0052)), Z.rotation_difference(out).to_matrix(), 10, 4)


def brows(b):
    for side in (1.0, -1.0):
        line = [face_at(side * x, h, 0.0008)[0] for x, h in ((0.019, 0.0275), (0.031, 0.0325), (0.045, 0.0315), (0.056, 0.0255))]
        b.strand(line, [0.0030, 0.0040, 0.0038, 0.0026], 5)


def mouth(b):
    # A line, turned up a little at the ends
    line = [face_at(x, -0.060 + 0.005 * (abs(x) / 0.021) ** 2, 0.0003)[0] for x in (-0.021, -0.012, 0.0, 0.012, 0.021)]
    b.strand(line, [0.0019, 0.0027, 0.0029, 0.0027, 0.0019], 5)


def eyes_small(b):
    eyes(b, 0.72, 1.0)


# --- The sculpted face ---
#
# The faces above are features stuck on an egg. This one is a head of its own
# (`head__sculpt`, shown in place of `head__base`), with the face modelled into
# it as form: a brow ridge over hollowed sockets, a nose with a bridge and a
# tip, cheeks, lips, and a chin above a flat jaw. It is kept simple, a few
# broad shapes as a carver would rough a face out, and cheap: one grid of
# points, finer over the face than behind.
#
# Above the brow it is the same egg as the plain head, so every cut of hair and
# the cap fit it. Its eyes are balls set in the sockets (`face__sculpt`): white,
# with a ring of colour and a dark middle, each on a bone of its own
# (`eye_l`, `eye_r`), so that the rig can turn them to what he looks at.

# Where an eye is: how far across from the middle of his face and how far above
# the middle of his head. Then the opening between its lids (half its width,
# and how far the upper lid and the lower are from the middle of the eye: the
# upper comes down over the top of the ring of colour, which is what makes an
# eye look easy rather than startled), and the size of the ball behind them.
EYE = Vector((0.037, 0.003, 0.0))
EYE_HALF = (0.0175, 0.0086, 0.0098)
EYE_RADIUS = 0.0245
# His lips: the height of the line between them, half their width, and how
# thick the upper and the lower are.
LIPS = (-0.067, 0.0255, 0.0048, 0.0064)
# How far the corners of his mouth are turned up.
SMILE = 0.0036
# How strongly each feature is cut (metres it stands out, or in).
SCULPT = {"brow": 0.0058, "socket": 0.0072, "bridge": 0.0034, "nose": 0.0180, "wings": 0.0070, "cheek": 0.0050, "chin": 0.0058}
# How far the rings of an eyeball are from where it looks, in degrees: the dark
# middle, the ring of colour, and the white.
PUPIL_RINGS = (5.0, 10.5)
IRIS_RINGS = (10.5, 18.0, 25.5)
WHITE_RINGS = (25.5, 37.0, 52.0, 70.0, 90.0)


def skull_ring(h):
    """The ring round his head `h` above its middle: its true height (he is flat
    under the jaw, where the egg came to a point), how far forward its middle
    is, and its half width and half depth."""
    s = max(-0.999, min(0.999, h / HEAD_RADII.y))
    c, jaw = math.sqrt(1.0 - s * s), max(0.0, -s)
    y = h if h > -0.105 else -0.105 - 0.017 * math.tanh((-0.105 - h) / 0.017)
    return y, 0.012 * jaw, HEAD_RADII.x * c * (1.0 - 0.2 * jaw ** 1.5), HEAD_RADII.z * c


def eye_depth():
    """How far forward of the middle of his head the middle of an eyeball is: it sits just behind where his face would be."""
    _y, forward, rx, rz = skull_ring(EYE.y)
    return forward + rz * math.sqrt(1.0 - (EYE.x / rx) ** 2) - 0.0035 - EYE_RADIUS


def eye_centre(side):
    return HEAD_CENTRE + Vector((side * EYE.x, EYE.y, eye_depth()))


def swell(distance, spread):
    """1 at no `distance`, falling away smoothly over `spread`."""
    return math.exp(-(distance / spread) ** 2)


def face_relief(x, h, cut=SCULPT):
    """How far the sculpted face stands forward of the egg (or back from it) `x` across and `h` above the middle of his head."""
    ax = abs(x)
    # The brow: a ridge arched over each eye, running out into the temple
    arch = 0.0300 + 0.0035 * swell(ax - EYE.x, 0.02)
    out = cut["brow"] * swell(h - arch, 0.0085) * blend(0.003, 0.02, ax) * (1.0 - 0.75 * blend(0.05, 0.075, ax))
    # ...over the sockets, hollowed either side of the nose
    out -= cut["socket"] * swell(ax - EYE.x, 0.027) * swell(h - EYE.y, 0.019)
    # The nose: a narrow bridge from between the brows, widening and standing
    # further out down to the tip, and cut away sharply under it
    top, tip = 0.020, -0.029
    along = min(max((top - h) / (top - tip), 0.0), 1.0)
    stands = cut["bridge"] + (cut["nose"] - cut["bridge"]) * along ** 1.35
    if h > top:
        stands *= swell(h - top, 0.011)
    if h < tip:
        stands *= swell(h - tip, 0.0062)
    out += stands * swell(x, 0.0066 + 0.0062 * along)
    # (and the wings of the nostrils either side of the tip)
    out += cut["wings"] * swell(ax - 0.0105, 0.0058) * swell(h + 0.0315, 0.0058)
    # Cheeks, full under the eyes
    out += cut["cheek"] * swell(ax - 0.047, 0.022) * swell(h + 0.032, 0.022)
    # The mouth sits on a low mound; the lips are two rolls with a furrow between
    # them, tucked in at the corners
    line = LIPS[0] + smile(x)
    out += 0.0038 * swell(x, 0.030) * swell(h - line, 0.020)
    out += (0.0022 * swell(h - line - 0.0028, 0.0030) + 0.0028 * swell(h - line + 0.0036, 0.0036)) * swell(x, 0.021)
    out -= 0.0020 * swell(h - line, 0.0016) * swell(x, 0.028)
    out -= 0.0014 * swell(ax - LIPS[1] - 0.002, 0.007) * swell(h - line, 0.007)
    # A dip under the lower lip, and the ball of the chin
    out -= 0.0010 * swell(x, 0.020) * swell(h + 0.0815, 0.008)
    out += cut["chin"] * swell(x, 0.022) * swell(h + 0.104, 0.016)
    return out


def smile(x):
    """How far the line of his mouth is lifted `x` across from its middle."""
    return SMILE * min((x / LIPS[1]) ** 2, 1.6)


def drawn_rows(h, x):
    """The rows of the grid are drawn together so that one runs along each lid of
    his eyes and each edge of his lips: the opening of an eye and the red of the
    lips then have clean edges however coarse the grid is. Gives the height a
    point `x` across on the row at `h` is moved to."""
    wide, upper, lower = EYE_HALF
    off = h - EYE.y
    tall = upper if off > 0.0 else lower
    if abs(off) <= tall + 0.0045:
        open_by = max(0.16, 1.0 - ((abs(x) - EYE.x) / wide) ** 2)
        return EYE.y + math.copysign(min(abs(off), tall) * open_by + max(abs(off) - tall, 0.0), off)
    line, half, upper, lower = LIPS
    off = h - line
    if -lower <= off <= upper:
        full = max(0.1, 1.0 - (x / half) ** 2)
        if off > 0.0:
            # (the upper lip dips in the middle)
            full *= 1.0 - 0.22 * swell(x, 0.0045)
        return line + smile(x) + off * full
    return h + smile(x) * (1.0 - blend(0.0, 0.012, min(abs(off - upper), abs(off + lower))))


def sculpted(angle, h, cut=SCULPT, drawn=True):
    """A point of the sculpted head: `angle` round from the front, on the row at `h` above its middle."""
    if drawn:
        h = drawn_rows(h, math.sin(angle) * skull_ring(h)[2])
    y, forward, rx, rz = skull_ring(h)
    q = Vector((math.sin(angle) * rx, y, forward + math.cos(angle) * rz))
    q.z += face_relief(q.x, q.y, cut) * blend(0.2, 0.5, math.cos(angle))
    # His lids: inside the opening the surface is sunk behind the eyeball, which
    # shows through it; round the opening it lies just over the ball, and runs
    # out from there into the socket.
    wide, upper, lower = EYE_HALF
    dx, dh = abs(q.x) - EYE.x, q.y - EYE.y
    tall = upper if dh > 0.0 else lower
    if math.cos(angle) > 0.0 and abs(dx) < 2.2 * wide and abs(dh) < 0.03:
        closed = abs(dh) / tall + (dx / wide) ** 2
        inside = EYE_RADIUS ** 2 - dx * dx - dh * dh
        ball = eye_depth() + math.sqrt(max(inside, 0.0))
        if closed < 0.985:
            q.z = ball - 0.0045
        elif inside > 0.0:
            lid = ball + 0.0014
            q.z = max(lid + (q.z - lid) * blend(1.0, 2.1, closed), lid)
    return HEAD_CENTRE + q


def sculpted_at(x, h, lift=0.0, cut=SCULPT):
    """The point of the sculpted face `x` across and `h` above the middle of his head, stood `lift` off it."""
    def at(x, h):
        return sculpted(math.asin(max(-0.99, min(0.99, x / skull_ring(h)[2]))), h, cut, False)

    out = (at(x + 0.002, h) - at(x - 0.002, h)).cross(at(x, h + 0.002) - at(x, h - 0.002)).normalized()
    return at(x, h) + out * lift


def sculpt_grid():
    """Where the rows and columns of the sculpted head are: the heights of the
    rows from the crown down, and the angles of the columns round one side from
    the front to the back. They are close together where there is a face to model."""
    wide, above, below = EYE_HALF
    line, _half, upper, lower = LIPS
    if kit.LOW:
        rows = [0.115, 0.072, 0.040, 0.031, EYE.y + above + 0.004, EYE.y + above, EYE.y, EYE.y - below, EYE.y - below - 0.004, -0.021, -0.029, -0.037,
                -0.053, line + upper, line, line - lower, -0.085, -0.104, -0.120, -0.131]
        across = [0.0, 0.008, EYE.x - wide, EYE.x, EYE.x + wide, 0.066, 0.081, 0.096]
        behind = [90.0, 125.0, 160.0, 180.0]
    else:
        rows = [0.130, 0.115, 0.095, 0.072, 0.055, 0.044, 0.037, 0.031, 0.025, EYE.y + above + 0.004]
        rows += [EYE.y + above, EYE.y + above * 0.5, EYE.y, EYE.y - below * 0.5, EYE.y - below]
        rows += [EYE.y - below - 0.004, -0.018, -0.022, -0.026, -0.029, -0.033, -0.037, -0.042, -0.048, -0.055]
        rows += [line + upper, line + upper * 0.5, line, line - lower * 0.5, line - lower]
        rows += [-0.079, -0.085, -0.093, -0.101, -0.109, -0.116, -0.122, -0.128, -0.133]
        across = [0.0, 0.004, 0.008, 0.0125] + [EYE.x + wide * t for t in (-1.0, -0.68, -0.34, 0.0, 0.34, 0.68, 1.0)] + [0.060, 0.066, 0.073, 0.081, 0.089, 0.096]
        behind = [90.0, 106.0, 124.0, 142.0, 161.0, 180.0]
    return rows, [math.asin(x / HEAD_RADII.x) for x in across] + [math.radians(angle) for angle in behind]


def head_sculpt(b):
    """The sculpted head, in skin, with his lips in their own colour. (It colours itself.)"""
    rows, side = sculpt_grid()
    angles = side + [-angle for angle in side[-2:0:-1]]
    count = len(angles)
    verts = [[b._vert(sculpted(angle, h), None) for angle in angles] for h in rows]
    line, half, upper, lower = LIPS
    faces = []

    def face(corners, h, columns):
        made = b.bm.faces.new(corners)
        # (his lips are the faces between the rows drawn along their edges, in front, and no wider than they are)
        j, k = columns
        across = abs(math.sin(angles[j]) + math.sin(angles[k])) * 0.5 * skull_ring(h)[2]
        lips = line - lower < h < line + upper and across < half and math.cos(angles[j]) + math.cos(angles[k]) > 0.0
        made.material_index = MOUTH if lips else SKIN
        faces.append(made)

    for r in range(len(rows) - 1):
        for j in range(count):
            k = (j + 1) % count
            face((verts[r][j], verts[r][k], verts[r + 1][k], verts[r + 1][j]), (rows[r] + rows[r + 1]) * 0.5, (j, k))
    for r, h in ((0, HEAD_RADII.y), (len(rows) - 1, -HEAD_RADII.y)):
        pole = b._vert(HEAD_CENTRE + Vector((0.0, skull_ring(h)[0], skull_ring(h)[1])), None)
        for j in range(count):
            face((verts[r][j], verts[r][(j + 1) % count], pole), h, (j, (j + 1) % count))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def sculpt_ears(b):
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.099, -0.016, -0.012)), Vector((0.012, 0.027, 0.018)), None, 8, 5)


def sculpt_brows(b):
    """Eyebrows, lying along the ridge of the brow."""
    for side in (1.0, -1.0):
        line = [sculpted_at(side * x, h, 0.0004) for x, h in ((0.0140, 0.0292), (0.026, 0.0330), (0.039, 0.0344), (0.052, 0.0322), (0.062, 0.0272))]
        b.strand(line, [0.0024, 0.0034, 0.0034, 0.0028, 0.0016], 5)


def sculpt_lashes(b):
    """A dark line along each upper lid, which is what gives an eye its shape from any way off, and one between his lips."""
    wide, tall, _lower = EYE_HALF
    for side in (1.0, -1.0):
        line = []
        for t in (-1.0, -0.6, -0.2, 0.2, 0.6, 1.0, 1.22):
            # (it runs on a little past the outer corner)
            x = EYE.x + wide * t
            h = EYE.y + tall * max(1.0 - t * t, 0.0) + (0.0006 if t <= 1.0 else -0.0016)
            line.append(sculpted_at(side * x, h, 0.0006))
        b.strand(line, [0.0007, 0.0011, 0.0013, 0.0013, 0.0012, 0.0010, 0.0005], 4)
    # (and the line between his lips, which is what gives a mouth its expression)
    half = LIPS[1] * 0.96
    line = [sculpted_at(half * t, LIPS[0] + smile(half * t), 0.0004) for t in (-1.0, -0.6, -0.2, 0.2, 0.6, 1.0)]
    b.strand(line, [0.0005, 0.0008, 0.0009, 0.0009, 0.0008, 0.0005], 4)


def eyeballs(rings, closed=False):
    """Part of both eyeballs: the bands between `rings` (degrees from where the eye looks), and with `closed` the middle as well."""
    def made(b):
        segments = 8 if kit.LOW else 12
        for side in (1.0, -1.0):
            centre = eye_centre(side)
            loops = []
            for ring in (rings[::len(rings) - 1] if kit.LOW else rings):
                off = math.radians(ring)
                loops.append([b._vert(centre + Vector((math.cos(math.tau * k / segments) * math.sin(off), math.sin(math.tau * k / segments) * math.sin(off), math.cos(off))) * EYE_RADIUS, None)
                              for k in range(segments)])
            faces = []
            for near, far in zip(loops, loops[1:]):
                for k in range(segments):
                    faces.append(b.bm.faces.new((near[k], near[(k + 1) % segments], far[(k + 1) % segments], far[k])))
            if closed:
                pole = b._vert(centre + Z * EYE_RADIUS, None)
                for k in range(segments):
                    faces.append(b.bm.faces.new((loops[0][k], loops[0][(k + 1) % segments], pole)))
            for made_face in faces:
                # (an open band has no inside for its faces to be turned out of: each is turned by hand)
                made_face.normal_update()
                if made_face.normal.dot(made_face.calc_center_median() - kit.to_blender(centre)) < 0.0:
                    made_face.normal_flip()
    return made


# --- Hair ---
#
# Cuts of hair other than his own curls are made as a game makes stylised hair:
# one closed surface over the head (`helmet`) rather than strands, modelled in
# locks (a ridge down each, a crease between, and each ending where it will at
# the hem), with whatever stands off it (a bun, a plait, a tail) as shapes of
# its own. Three things keep it from looking like a cone set on his head:
#
# - The crown is rounder than his skull. A head of hair is fullest above and
#   behind the temples, so the surface is filled out there (ROUND) and comes no
#   higher on top than it must.
# - The hair grows from somewhere real. Either from a whorl at the back of the
#   crown, a little off the middle, combed out from it in every direction (a
#   crop, a fringe); or from a parting, a line it falls away from to either
#   side; or it is drawn back from the hairline to where it is tied. The rows of
#   the surface run that way, and so do the streaks and the lights of the shader.
# - What is combed or pinned (FIRM) stays put, and only loose hair swings.
#
# After period photographs and guides to the hair of 1900-1925. Boys and men:
# cropped; a pudding-basin fringe; a side parting with the long side combed over
# and the sides short above the ears; oiled and combed straight back; a centre
# parting with the front falling in curtains; a pompadour combed up off the
# brow. Girls and women: a bob with a fringe; a finger-waved bob with a side
# parting; plaits; hair drawn back to a tail, or to a low knot at the nape; the
# full soft pompadour of the Gibson girl with its knot on the crown; and a
# girl's long loose waves under a big ribbon bow.

# How much fuller than an egg the crown of a head of hair is, half way between its top and its sides.
ROUND = 0.12
# The cuts that do not swing (see `weights`).
FIRM = ("crop", "bowl", "parting", "slick", "quiff", "waved", "bun", "gibson", "ponytail", "plaits")


def hairline(brow, side, nape, face=1.05, soft=0.35):
    """How far down the hair comes at each angle round his head (heights above its
    middle): to `brow` in front, to `side` over the ears from `face` radians
    round, and to `nape` behind."""
    def hem(angle):
        round_by = abs((angle + math.pi) % math.tau - math.pi)
        front = 1.0 - blend(face - soft, face, round_by)
        return brow * front + (side + (nape - side) * blend(1.5, 2.6, round_by)) * (1.0 - front)
    return hem


def hair_shape(grow):
    return HEAD_CENTRE + Vector((0.0, 0.006, -0.003)), HEAD_RADII + Vector(grow)


def aim(back, side=0.0):
    """A direction out from the middle of his head: straight up, tipped `back`
    radians towards the back of it (forwards, if less than nothing) and `side`
    towards his left."""
    return Vector((math.sin(side), math.cos(side) * math.cos(back), -math.cos(side) * math.sin(back)))


def towards(d, direction, spread):
    """1 where `d` is `direction`, falling away smoothly over `spread` radians round it."""
    return math.exp(-(d.angle(direction) / spread) ** 2)


def helmet(b, hem, grow, drop=0.0, flare=0.0, curl=0.0, rows=9, count=28, whorl=None, parting=None, drawn=False,
           locks=0, relief=0.004, ragged=0.0, body=None):
    """Hair as one surface over his head, down to `hem` (see `hairline`), standing
    `grow` off his skull. Below the widest part of his head it follows the head
    in (`drop` 0) or hangs straight (1), and may `flare` out on the way and
    `curl` under at the end.

    It grows from `whorl` (a direction out from the middle of his head, see
    `aim`); or, with `parting` (how far round from the front the parting meets
    his hairline, and the direction of its other end, on his crown), from a
    line, which shows as a furrow. With `drawn` it runs the other way: from the
    hairline back to the whorl, which is then where it is tied.

    `locks` is how many locks it is modelled in, each standing `relief` proud of
    the creases between them and ending up to `ragged` (a share of its length)
    short of the hem. `body`, given a direction and how far along the hair that
    is, says how much further the hair stands off there: a wave over the brow."""
    if kit.LOW:
        rows, count = max(rows // 2, 4), max(locks, 6) * 2
    elif locks:
        count = locks * 4
    centre, radii = hair_shape(grow)
    rng = random.Random(7)
    lengths = [rng.random() for _ in range(max(locks, 1))]

    def end_of(angle):
        return math.acos(max(-0.97, min(0.97, hem(angle) / radii.y)))

    def rim(angle):
        end = end_of(angle)
        return Vector((math.sin(angle) * math.sin(end), math.cos(end), math.cos(angle) * math.sin(end)))

    def place(d, lift):
        angle = math.atan2(d.x, d.z)
        theta = math.acos(max(-1.0, min(1.0, d.y)))
        end = end_of(angle)
        out, up = math.sin(theta), math.cos(theta)
        if theta < math.pi / 2:
            # (fuller than an egg over the crown; but not at the hem, where it lies on his head)
            full = 1.0 + ROUND * math.sin(2.0 * theta) ** 2 * blend(0.0, 0.5, end - theta)
            out, up = out * full, up * full
        else:
            # (hair that crosses his brow on its way down is outside the hem for a while: it does not hang there)
            u = min((theta - math.pi / 2) / max(end - math.pi / 2, 1e-6), 1.0) if end > math.pi / 2 else 0.0
            out = out + (1.0 - out) * drop * u ** 0.5 + flare * u - curl * u * u
        p = Vector((math.sin(angle) * radii.x * out, radii.y * up, math.cos(angle) * radii.z * out))
        return centre + p + p.normalized() * lift

    if parting is not None:
        first, last = rim(parting[0]), parting[1]
    elif whorl is None:
        whorl = aim(0.55, 0.12)

    grid = [[None] * count for _ in range(rows + 1)]
    for j in range(count):
        tip = rim(math.tau * j / count)
        if parting is None:
            root = whorl
        else:
            # (from the place along the parting it is level with, front to back:
            # what is in front falls from the front end of it, what is behind from the back)
            root = first.slerp(last, blend(0.85, -0.85, math.cos(math.tau * j / count)))
        at = j / count * locks
        ridge = abs(math.sin(math.pi * at)) if locks else 0.5
        short = ragged * (0.55 * lengths[int(at) % len(lengths)] + 0.45 * (1.0 - ridge))
        for i in range(rows + 1):
            share = i / rows
            if parting is None:
                share = max(share, 0.07)
            d = root.slerp(tip, share * (1.0 - short)) if root.angle(tip) > 1e-4 else tip
            lift = relief * (ridge ** 0.6 - 0.5) * blend(0.05, 0.45, share) if locks else 0.0
            if parting is not None:
                # (it rises out of the parting)
                lift -= 0.0045 * (1.0 - blend(0.0, 0.12, share))
            if body is not None:
                lift += body(d, share)
            grid[i][j] = place(d, lift)
    # (turned under at the hem, so that it has a thickness)
    under = [centre + Vector(((p.x - centre.x) * 0.88, p.y - centre.y + 0.007, (p.z - centre.z) * 0.88)) for p in grid[-1]]
    lofted, close = grid + [under], (parting is None, False)
    if drawn:
        lofted, close = lofted[::-1], (False, parting is None)
    loft(b, lofted, 6.0, close)


def hair_crop(b):
    """Cropped close all over: a boy's, in any year."""
    helmet(b, hairline(0.080, 0.016, -0.100, 1.2, 0.5), (0.0075, 0.006, 0.009), locks=10, relief=0.002)


def hair_bowl(b):
    """A pudding-basin cut: combed forward from the crown into a fringe cut straight
    across above his brows, and the same length all round, over the tops of his ears."""
    helmet(b, hairline(0.036, -0.010, -0.066, 1.3, 0.2), (0.014, 0.007, 0.014), 0.85, 0.0, 0.06, 10, whorl=aim(0.5, 0.1), locks=14, relief=0.005, ragged=0.07)


def hair_bob(b):
    """A bob: straight, to the jaw all round, with a fringe cut across the brow."""
    helmet(b, hairline(0.036, -0.080, -0.092, 1.0, 0.2), (0.017, 0.008, 0.017), 1.0, 0.05, 0.10, 10, whorl=aim(0.45), locks=16, relief=0.004, ragged=0.03)


def hair_parting(b):
    """Parted on his left, the long side combed over the top and lifted in a
    wave off his forehead, the sides short above his ears."""
    wave = aim(-0.85, -0.3)
    helmet(b, hairline(0.072, 0.014, -0.100, 1.2, 0.5), (0.010, 0.007, 0.010), parting=(0.62, aim(0.75, 0.38)), locks=11, relief=0.004, ragged=0.04,
           body=lambda d, share: 0.011 * towards(d, wave, 0.45))


def hair_slick(b):
    """Oiled and combed straight back off his forehead, as young men wore it: the marks of the comb in it, and no parting."""
    front = aim(-0.75)
    helmet(b, hairline(0.086, 0.022, -0.098, 1.1, 0.55), (0.006, 0.006, 0.010), whorl=aim(1.7), drawn=True, locks=15, relief=0.003,
           body=lambda d, share: 0.006 * towards(d, front, 0.5))


def hair_curtains(b):
    """Parted in the middle and left to fall either side of his forehead, in waves, to his cheekbones."""
    def hem(angle):
        round_by = abs((angle + math.pi) % math.tau - math.pi)
        front = 0.084 - 0.070 * blend(0.04, 0.72, round_by)
        back = 0.002 + (-0.088 - 0.002) * blend(1.5, 2.6, round_by)
        share = blend(0.78, 1.12, round_by)
        return front * (1.0 - share) + back * share

    falls = (aim(-0.7, 0.5), aim(-0.7, -0.5))
    helmet(b, hem, (0.013, 0.007, 0.012), 0.5, 0.0, 0.03, 10, parting=(0.0, aim(0.8)), locks=12, relief=0.005, ragged=0.10,
           body=lambda d, share: 0.008 * (towards(d, falls[0], 0.4) + towards(d, falls[1], 0.4)))


def hair_quiff(b):
    """A pompadour: left long on top and combed up and back off his brow in a full
    wave, a little to one side, short at the sides."""
    wave = aim(-0.62, -0.12)
    helmet(b, hairline(0.088, 0.018, -0.098, 1.1, 0.5), (0.008, 0.007, 0.010), whorl=aim(1.3, 0.15), drawn=True, locks=11, relief=0.005,
           body=lambda d, share: 0.021 * towards(d, wave, 0.5))


def hair_waved(b):
    """A waved bob: parted on her left and set in waves close to her head, across
    her forehead and down over her ears to the jaw."""
    def hem(angle):
        turned = (angle + math.pi) % math.tau - math.pi
        round_by = abs(turned)
        # (it sweeps across her brow from the parting, lowest over the far temple)
        sweep = 0.076 - 0.052 * blend(0.5, -0.95, turned)
        side = -0.064 + (-0.086 + 0.064) * blend(1.5, 2.6, round_by)
        front = blend(-1.25, -0.95, turned) * (1.0 - blend(0.5, 0.85, turned))
        return sweep * front + side * (1.0 - front)

    helmet(b, hem, (0.011, 0.006, 0.012), 0.7, 0.0, 0.10, 10, parting=(0.5, aim(0.8, 0.3)), locks=10, relief=0.003, ragged=0.02)


def hair_plaits(b):
    """Parted in the middle, drawn back over her ears, and in two plaits that hang forward over her shoulders."""
    def hem(angle):
        round_by = abs((angle + math.pi) % math.tau - math.pi)
        front = 0.090 - 0.062 * blend(0.0, 1.0, round_by)
        back = -0.038 - 0.060 * blend(1.5, 2.6, round_by)
        share = blend(0.85, 1.15, round_by)
        return front * (1.0 - share) + back * share

    helmet(b, hem, (0.010, 0.007, 0.011), 0.35, parting=(0.0, aim(1.0)), locks=12, relief=0.003)
    for side in (1.0, -1.0):
        path = [Vector((side * x, y, z)) for x, y, z in ((0.095, 1.064, -0.018), (0.102, 1.025, -0.004), (0.101, 0.990, 0.020),
                                                         (0.095, 0.957, 0.050), (0.089, 0.918, 0.071), (0.084, 0.878, 0.079), (0.081, 0.838, 0.081))]
        lengths = [0.0]
        for a, c in zip(path, path[1:]):
            lengths.append(lengths[-1] + (c - a).length)
        step = 0.034 if kit.LOW else 0.0185
        count = int(lengths[-1] / step)
        for k in range(count + 1):
            # Each turn of the plait is a lump lying across it, one way and then the other
            distance = lengths[-1] * k / count
            i = max(j for j in range(len(path) - 1) if lengths[j] <= distance + 1e-9)
            at = path[i].lerp(path[i + 1], (distance - lengths[i]) / (lengths[i + 1] - lengths[i]))
            along = (path[i + 1] - path[i]).normalized()
            thin = 1.0 - 0.3 * blend(0.75, 1.0, k / count)
            turn = along.rotation_difference(Y).inverted().to_matrix() @ Matrix.Rotation((0.55 if k % 2 else -0.55), 3, "Z")
            b.ellipsoid(at, Vector((0.0175, 0.0135, 0.0150)) * thin, turn, 8, 4)
        # (and the loose end below where it is tied)
        b.strand([path[-1], path[-1] - Y * 0.022, path[-1] - Y * 0.044], [0.008, 0.013, 0.006], 6)


def hair_ponytail(b):
    """Drawn straight back and tied at the nape, the tail hanging down her back."""
    helmet(b, hairline(0.078, -0.010, -0.080, 1.12, 0.4), (0.009, 0.006, 0.010), whorl=aim(1.64), drawn=True, locks=14, relief=0.003)
    centre = HEAD_CENTRE
    for x, lean in ((0.0, 0.0), (0.011, 0.5), (-0.011, -0.5)):
        line = [centre + Vector((x * s, y, z)) for s, y, z in ((0.3, -0.004, -0.108), (0.6, -0.016, -0.140), (1.0, -0.055, -0.160),
                                                               (1.2, -0.115, -0.160 - 0.006 * abs(lean)), (1.0, -0.175, -0.148), (0.5, -0.222, -0.136))]
        thick = [0.013, 0.022, 0.026, 0.025, 0.019, 0.008]
        b.strand(line, [r * (1.0 if x == 0.0 else 0.8) for r in thick], 6)
    # (what ties it)
    b.ellipsoid(centre + Vector((0.0, -0.008, -0.122)), Vector((0.021, 0.012, 0.016)), None, 8, 3)


def knot(b, grow, where, radius, thick):
    """A knot of hair pinned on her head: a rope of it wound flat round on itself,
    out from the middle of her head in the direction `where`."""
    centre, radii = hair_shape(grow)
    at = centre + Vector((where.x * radii.x, where.y * radii.y, where.z * radii.z))
    across = where.cross(X).normalized()
    up = across.cross(where)
    count = 8 if kit.LOW else 16
    points, thicks = [], []
    for k in range(count):
        t = k / (count - 1)
        turn = math.tau * 1.7 * t
        points.append(at + (across * math.cos(turn) + up * math.sin(turn)) * radius * (1.0 - 0.8 * t) + where * thick * (0.25 + 0.75 * t))
        thicks.append(thick * (0.95 - 0.25 * t))
    b.strand(points, thicks, 6)
    # (and what it is wound on, so that nothing shows through the middle of it)
    b.ellipsoid(at + where * thick * 0.2, Vector((radius * 0.9, thick * 0.8, radius * 0.9)), Y.rotation_difference(where).to_matrix(), 8, 3)


def hair_bun(b):
    """Drawn back over the tops of her ears to a low knot at the nape: how most women wore it by the war."""
    grow = (0.011, 0.007, 0.011)
    helmet(b, hairline(0.074, -0.004, -0.086, 1.12, 0.4), grow, 0.2, whorl=aim(1.92), drawn=True, locks=14, relief=0.003)
    knot(b, grow, aim(1.92), 0.033, 0.019)


def hair_gibson(b):
    """The Gibson girl's: all of it brushed up from the hairline into a full soft
    roll that stands out round her face, and wound into a knot on the back of her crown."""
    grow = (0.015, 0.010, 0.016)
    # (the roll: fullest a little way in from the hairline, all the way round)
    helmet(b, hairline(0.076, 0.002, -0.074, 1.1, 0.4), grow, 0.3, 0.0, 0.10, 10, whorl=aim(0.62), drawn=True, locks=14, relief=0.005,
           body=lambda d, share: 0.021 * swell(share - 0.70, 0.24))
    knot(b, grow, aim(0.62), 0.036, 0.020)


def hair_waves(b):
    """A girl's: parted in the middle and left long, in loose waves over her ears and down her back."""
    helmet(b, hairline(0.076, -0.040, -0.095, 1.05, 0.35), (0.012, 0.007, 0.012), 0.5, parting=(0.0, aim(0.9)), locks=12, relief=0.004, ragged=0.05)
    # What hangs down her back: a thick fall of it from ear to ear, to below her
    # shoulder blades, swaying from side to side as waved hair does on its way down.
    count = 6 if kit.LOW else 14
    rows = []
    for i in range(count + 1):
        t = i / count
        y = HEAD_CENTRE.y - 0.035 - 0.245 * t
        sway = 0.006 * math.sin(math.tau * 2.4 * t) * blend(0.0, 0.3, t)
        wide = (0.088 + 0.012 * math.sin(math.pi * t)) * (1.0 - 0.45 * blend(0.75, 1.0, t))
        deep = 0.058 - 0.012 * t + 0.004 * math.sin(math.tau * 2.4 * t + 1.0)
        middle = -0.060 - 0.006 * blend(0.0, 0.5, t) - 0.012 * blend(0.5, 1.0, t)
        thick = 0.022 * (1.0 - 0.5 * blend(0.7, 1.0, t))
        ring = []
        for inner in (False, True):
            for k in range(9):
                turn = math.pi * (k / 8 - 0.5) * (-1.0 if inner else 1.0)
                lock = 0.003 * abs(math.sin(4.0 * turn)) * (0.0 if inner else 1.0)
                less = thick if inner else 0.0
                ring.append(Vector((sway + math.sin(turn) * (wide - less), y, middle - math.cos(turn) * (deep - less + lock))))
        rows.append(ring)
    loft(b, rows, 4.0, (False, True))


def bow(b):
    """The big ribbon bow a girl's hair was tied with, on the back of her crown."""
    where = aim(0.95)
    centre, radii = hair_shape((0.012, 0.007, 0.012))
    at = centre + Vector((where.x * radii.x, where.y * radii.y, where.z * radii.z)) + where * 0.006
    lean = Y.rotation_difference(where).to_matrix()
    for side in (1.0, -1.0):
        # (a loop either side of the knot, and an end hanging from it)
        b.ellipsoid(at + lean @ Vector((side * 0.046, 0.004, 0.008)), Vector((0.044, 0.012, 0.027)), lean @ Matrix.Rotation(side * 0.35, 3, "Y"), 8, 3)
        b.ellipsoid(at + lean @ Vector((side * 0.016, 0.0, -0.034)), Vector((0.011, 0.006, 0.030)), lean @ Matrix.Rotation(-side * 0.3, 3, "Y"), 6, 3)
    b.ellipsoid(at + where * 0.004, Vector((0.012, 0.011, 0.012)), lean, 8, 3)


def hair_curls(b):
    """Big natural curls, standing out all round the head."""
    hem = hairline(0.066, -0.030, -0.095, 1.02, 0.3)
    grow = (0.012, 0.008, 0.012)
    helmet(b, hem, grow)
    centre, radii = hair_shape(grow)
    rng = random.Random(5)
    count = 44 if kit.LOW else 96
    for k in range(count):
        # (spread evenly over a ball, and kept where there is hair)
        y = 1.0 - 2.0 * (k + 0.5) / count
        ring = math.sqrt(1.0 - y * y)
        angle = k * 2.399963
        out = Vector((math.sin(angle) * ring, y, math.cos(angle) * ring))
        if out.y * radii.y < hem(math.atan2(out.x, out.z)) - 0.004:
            continue
        # (they stand as far off his head on top as at the sides, and the whole
        # is fullest above his temples, as the other cuts are: not piled to a point)
        stand = 0.012 + 0.003 * max(out.y, 0.0) + rng.uniform(-0.003, 0.004)
        full = 1.0 + ROUND * (2.0 * ring * max(out.y, 0.0)) ** 2
        size = rng.uniform(0.029, 0.037)
        b.ellipsoid(centre + Vector((out.x * (radii.x + stand), out.y * (radii.y + stand), out.z * (radii.z + stand))) * full,
                    Vector((size, size * rng.uniform(0.85, 1.0), size)), None, 8, 4)


def cap_plane(level):
    """The plane across his head `level` above the middle of it, as the cap sits (in Blender's space)."""
    tilt = Matrix.Rotation(CAP_TILT, 3, "X")
    return kit.to_blender(HEAD_CENTRE + tilt @ (Y * level)), kit.to_blender(tilt @ Y)


def under_cap(shapes):
    """What of a cut of hair shows whether or not he has his cap on: all of it
    from the band down, pressed flat where the band sits."""
    def made(b):
        shapes(b)
        at, facing = cap_plane(CAP_BAND + 0.004)
        bmesh.ops.bisect_plane(b.bm, geom=b.bm.verts[:] + b.bm.edges[:] + b.bm.faces[:], dist=1e-6, plane_co=at, plane_no=facing, clear_outer=True)
        press_under_cap(b)
    return made


def above_cap(shapes):
    """The rest of it, which a cap would hide. (It starts lower than the other
    ends, so that bareheaded it covers where that one is pressed in.)"""
    def made(b):
        shapes(b)
        at, facing = cap_plane(CAP_BAND - 0.03)
        bmesh.ops.bisect_plane(b.bm, geom=b.bm.verts[:] + b.bm.edges[:] + b.bm.faces[:], dist=1e-6, plane_co=at, plane_no=facing, clear_inner=True)
    return made


# (cut, its shapes, and its material: HAIRWAVY for those that are waved, which the game shades with its other hair shader)
CUTS = [("crop", hair_crop, HAIR), ("bowl", hair_bowl, HAIR), ("parting", hair_parting, HAIR), ("slick", hair_slick, HAIR),
        ("curtains", hair_curtains, HAIRWAVY), ("quiff", hair_quiff, HAIRWAVY), ("curls", hair_curls, HAIR),
        ("bob", hair_bob, HAIR), ("waved", hair_waved, HAIRWAVY), ("plaits", hair_plaits, HAIR), ("ponytail", hair_ponytail, HAIR),
        ("bun", hair_bun, HAIR), ("gibson", hair_gibson, HAIRWAVY), ("waves", hair_waves, HAIRWAVY)]


# --- Clothes ---

def stick(root, trunk, arm, leg):
    """A stick figure for `body` to skin: its root at the hips, the points up to
    the chest, and a function each for the points along an arm and down a leg."""
    points = []
    lines = []

    def chain(start, steps):
        last = start
        for position, thickness in steps:
            points.append((Vector(position), thickness))
            if last is not None:
                lines.append((last, len(points) - 1))
            last = len(points) - 1
        return last

    chain(None, [root])
    chest = chain(0, trunk)
    # (the collar and the neck, as his own)
    chain(chest, [((0.0, 0.936, 0.0), 0.064), ((0.0, 0.950, 0.0), 0.056), ((0.0, 0.958, 0.0), 0.046),
                  ((0.0, 0.966, 0.0), NECK_RADIUS), ((0.0, 1.00, 0.0), NECK_RADIUS - 0.002), ((0.0, 1.06, 0.0), NECK_RADIUS - 0.002)])
    for side in (1.0, -1.0):
        chain(chest, arm(side))
        chain(0, leg(side))
    return points, lines


SHIRT_TRUNK = [((0.0, 0.66, 0.0), 0.107), ((0.0, 0.692, 0.0), 0.106), ((0.0, 0.701, 0.0), 0.105),
               ((0.0, 0.709, 0.0), 0.097), ((0.0, 0.75, 0.0), 0.100), ((0.0, 0.82, 0.0), 0.107), ((0.0, 0.888, 0.0), 0.103)]


def rolled_sleeve(side):
    return [((side * 0.118, 0.893, 0.0), 0.062), ((side * 0.175, 0.895, 0.0), 0.052),
            ((side * 0.25, 0.893, 0.0), 0.049), ((side * ELBOW_X, 0.894, -0.004), 0.046),
            ((side * (SLEEVE_X - 0.022), 0.895, -0.003), 0.045), ((side * (SLEEVE_X - 0.014), 0.897, -0.003), 0.053),
            ((side * (SLEEVE_X - 0.005), 0.894, -0.002), 0.049), ((side * (SLEEVE_X + 0.003), 0.895, -0.004), 0.055),
            ((side * (SLEEVE_X + 0.011), 0.895, -0.003), 0.051), ((side * (SLEEVE_X + 0.018), 0.895, -0.003), 0.033)]


def long_leg(side):
    # Long trousers, straight from the knee, with a turn-up that sits on the boot
    return [((side * HIP_X, 0.585, 0.0), 0.081), ((side * 0.082, 0.49, 0.002), 0.071),
            ((side * 0.082, 0.38, 0.004), 0.062), ((side * 0.081, 0.30, 0.006), 0.057),
            ((side * 0.08, 0.20, 0.002), 0.054), ((side * 0.08, 0.142, 0.0), 0.053),
            ((side * 0.08, 0.132, 0.0), 0.061), ((side * 0.08, 0.104, 0.0), 0.061),
            ((side * 0.08, 0.096, 0.0), 0.038), ((side * 0.08, 0.07, 0.0), 0.030)]


def neck_skin(p):
    return p.y > COLLAR_Y and math.hypot(p.x, p.z) < NECK_RADIUS + 0.012


def body_long(b):
    """His shirt, with long trousers."""
    def cloth(p):
        return SKIN if neck_skin(p) else DENIM if p.y < WAIST_Y and abs(p.x) < 0.25 else SHIRT
    return body(b, lambda: stick(((0.0, 0.612, 0.0), 0.106), SHIRT_TRUNK, rolled_sleeve, long_leg), cloth)


JACKET_HEM = 0.633
OPENING = 0.80  # where the front of the jacket closes


def body_suit(b):
    """A jacket buttoned high, its sleeves down to the wrist, over long trousers."""
    def sleeve(side):
        return [((side * 0.118, 0.893, 0.0), 0.066), ((side * 0.175, 0.895, 0.0), 0.056),
                ((side * 0.25, 0.893, 0.0), 0.050), ((side * ELBOW_X, 0.894, -0.004), 0.046),
                ((side * 0.40, 0.895, -0.003), 0.043), ((side * (WRIST_X - 0.036), 0.895, -0.003), 0.040),
                ((side * (WRIST_X - 0.018), 0.895, -0.003), 0.040), ((side * (WRIST_X - 0.010), 0.895, -0.003), 0.027)]

    def cloth(p):
        if neck_skin(p):
            return SKIN
        if p.y < JACKET_HEM and abs(p.x) < 0.25:
            return DENIM
        # (his shirt shows at the collar, and in the opening below it)
        if (p.y > 0.936 and math.hypot(p.x, p.z) < 0.075) or (p.z > 0.0 and p.y > OPENING and abs(p.x) < (p.y - OPENING) * 0.42):
            return SHIRT
        return JACKET

    trunk = [((0.0, 0.626, 0.0), 0.103), ((0.0, 0.638, 0.0), 0.117), ((0.0, 0.70, 0.0), 0.110),
             ((0.0, 0.76, 0.0), 0.108), ((0.0, 0.82, 0.0), 0.112), ((0.0, 0.888, 0.0), 0.108)]
    def front(p):
        return p.z > 0.0 and OPENING - 0.03 < p.y < 0.97 and abs(p.x) < 0.1

    return body(b, lambda: stick(((0.0, 0.600, 0.0), 0.101), trunk, sleeve, long_leg), cloth,
                slits=[((0.0, OPENING, 0.0), (1.0, -0.42, 0.0), front), ((0.0, OPENING, 0.0), (-1.0, -0.42, 0.0), front)])


def suit_buttons(b):
    for y in (0.665, 0.72, 0.775):
        at, facing = onto_body(Vector((0.0, y, 0.14)))
        b.ellipsoid(at + facing * 0.003, Vector((0.0085, 0.0085, 0.0045)), None, 8, 3)


SKIRT_TOP = 0.700
# Her skirt: (height, half width, half depth), from the waistband to the hem at the knee.
SKIRT = [(0.716, 0.090, 0.074), (0.704, 0.101, 0.086), (0.66, 0.120, 0.110), (0.60, 0.140, 0.136),
         (0.50, 0.158, 0.160), (0.40, 0.171, 0.178), (0.345, 0.178, 0.188)]


def skirt_at(angle, y, lift=0.0):
    """A point on her skirt: `angle` round from the front, at height `y`."""
    i = max(k for k in range(len(SKIRT) - 1) if SKIRT[k][0] >= y - 1e-9)
    t = (SKIRT[i][0] - y) / (SKIRT[i][0] - SKIRT[i + 1][0])
    rx = SKIRT[i][1] + (SKIRT[i + 1][1] - SKIRT[i][1]) * t
    rz = SKIRT[i][2] + (SKIRT[i + 1][2] - SKIRT[i][2]) * t
    # (it falls in folds, deeper towards the hem)
    fold = 1.0 + 0.045 * blend(0.67, 0.40, y) * math.cos(angle * 11.0)
    return Vector((math.sin(angle) * (rx * fold + lift), y, math.cos(angle) * (rz * fold + lift)))


def body_dress(b):
    """A bodice with sleeves to the elbow and a white collar, and stockings: her skirt goes over it."""
    def sleeve(side):
        return [((side * 0.118, 0.893, 0.0), 0.060), ((side * 0.172, 0.897, 0.0), 0.058),
                ((side * 0.235, 0.894, 0.0), 0.047), ((side * ELBOW_X, 0.894, -0.004), 0.042),
                ((side * (SLEEVE_X - 0.016), 0.895, -0.003), 0.041), ((side * (SLEEVE_X - 0.006), 0.895, -0.003), 0.048),
                ((side * (SLEEVE_X + 0.008), 0.895, -0.003), 0.048), ((side * (SLEEVE_X + 0.018), 0.895, -0.003), 0.032)]

    def leg(side):
        return [((side * HIP_X, 0.585, 0.0), 0.058), ((side * 0.079, 0.49, 0.002), 0.052),
                ((side * 0.08, 0.38, 0.003), 0.047), ((side * 0.08, 0.325, 0.004), 0.044),
                ((side * 0.08, 0.25, 0.0), 0.040), ((side * 0.08, 0.185, -0.005), 0.041),
                ((side * 0.08, 0.11, -0.002), 0.031), ((side * 0.08, 0.02, 0.0), 0.027)]

    def cloth(p):
        if neck_skin(p):
            return SKIN
        if p.y < 0.60 and abs(p.x) < 0.25:
            return SOCKS
        if p.y < WAIST_Y and abs(p.x) < 0.25:
            return DENIM
        return APRON if p.y > 0.934 and math.hypot(p.x, p.z) < 0.078 else SHIRT

    trunk = [((0.0, 0.66, 0.0), 0.090), ((0.0, 0.70, 0.0), 0.090), ((0.0, 0.75, 0.0), 0.094), ((0.0, 0.82, 0.0), 0.102), ((0.0, 0.888, 0.0), 0.099)]
    # (no stripe in it: it is to be the colour of her skirt, or a plain blouse)
    return body(b, lambda: stick(((0.0, 0.612, 0.0), 0.086), trunk, sleeve, leg), cloth, False)


def skirt(b):
    count = 10 if kit.LOW else 44
    heights = [y for y, _rx, _rz in SKIRT] + ([] if kit.LOW else [0.55, 0.45, 0.37])
    outside = [[skirt_at(math.tau * j / count, y) for j in range(count)] for y in sorted(heights, reverse=True)]
    # (and up inside from the hem, to a ceiling over her legs, so that it is not hollow from below)
    inside = [[skirt_at(math.tau * j / count, y, -0.008) for j in range(count)] for y in (0.345, 0.40, 0.50)]
    loft(b, outside + inside, 1.0, (True, True))


def sheet(b, top, under):
    """A piece of cloth from a grid of points, with its edge turned in to `under` (a grid of the same size)."""
    steps, columns = len(top) - 1, len(top[0]) - 1
    verts = [[b._vert(p, None) for p in row] for row in top]
    faces = []
    for k in range(steps):
        for m in range(columns):
            faces.append(b.bm.faces.new((verts[k][m], verts[k][m + 1], verts[k + 1][m + 1], verts[k + 1][m])))
    rim = ([(k, 0) for k in range(steps + 1)] + [(steps, m) for m in range(1, columns + 1)]
           + [(k, columns) for k in range(steps - 1, -1, -1)] + [(0, m) for m in range(columns - 1, 0, -1)])
    turned = {at: b._vert(under[at[0]][at[1]], None) for at in rim}
    for a, c in zip(rim, rim[1:] + rim[:1]):
        faces.append(b.bm.faces.new((verts[a[0]][a[1]], verts[c[0]][c[1]], turned[c], turned[a])))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    faces[0].normal_update()
    middle = kit.from_blender(faces[0].calc_center_median())
    if faces[0].normal.dot(kit.to_blender(Vector((middle.x, 0.0, middle.z)))) < 0.0:
        bmesh.ops.reverse_faces(b.bm, faces=faces)


def shell(b, keep, lift, cuts=()):
    """A garment cut out of the body's own surface and stood `lift` off it: the
    faces whose middles `keep` accepts, after the surface has been slit along
    each of `cuts` (a point on a plane and the way it faces), so that an edge
    which follows one of those is clean. Being the same surface, it bends as the
    body under it does."""
    cut = BODY.copy()
    for at, facing in cuts:
        bmesh.ops.bisect_plane(cut, geom=cut.verts[:] + cut.edges[:] + cut.faces[:], dist=1e-6, plane_co=kit.to_blender(Vector(at)), plane_no=kit.to_blender(Vector(facing)))
    bmesh.ops.delete(cut, geom=[face for face in cut.faces if not keep(kit.from_blender(face.calc_center_median()))], context="FACES")
    cut.normal_update()
    out = {tuple(round(c, 6) for c in vertex.co): vertex.normal.copy() for vertex in cut.verts}
    stood = list(cut.verts)
    made = bmesh.ops.extrude_edge_only(cut, edges=[edge for edge in cut.edges if edge.is_boundary])["geom"]
    # (its edge is turned in under it, down into the body)
    for vertex in made:
        if isinstance(vertex, bmesh.types.BMVert):
            vertex.co -= out[tuple(round(c, 6) for c in vertex.co)] * 0.005
    for vertex in stood:
        vertex.co += out[tuple(round(c, 6) for c in vertex.co)] * lift
    bmesh.ops.recalc_face_normals(cut, faces=cut.faces[:])
    cut.faces.ensure_lookup_table()
    cut.normal_update()
    probe = cut.faces[0]
    centre = kit.from_blender(probe.calc_center_median())
    if probe.normal.dot(kit.to_blender(Vector((centre.x, 0.0, centre.z)))) < 0.0:
        bmesh.ops.reverse_faces(cut, faces=cut.faces[:])
    mesh = bpy.data.meshes.new("shell")
    cut.to_mesh(mesh)
    cut.free()
    b.bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def braces(b):
    """Braces from the front of his waistband over each shoulder, crossed behind."""
    out = 0.115
    for side in (1.0, -1.0):
        ribbon(b, [(side * 0.056, WAIST_Y - 0.014, out), (side * 0.066, 0.80, 0.11), (side * 0.082, 0.87, 0.11), (side * 0.098, 0.95, 0.07), (side * 0.104, 1.0, 0.0),
                   (side * 0.096, 0.95, -0.08), (side * 0.070, 0.88, -out), (side * 0.030, 0.81, -out), (-side * 0.022, 0.75, -out), (-side * 0.058, WAIST_Y - 0.014, -out)],
               [0.028] * 10, 0.0085 if side > 0.0 else 0.006, 32, 3)


def brace_buttons(b):
    for side in (1.0, -1.0):
        for point, lift in (((side * 0.056, WAIST_Y - 0.006, 0.115), 0.011), ((-side * 0.058, WAIST_Y - 0.006, -0.115), 0.009)):
            at, facing = onto_body(Vector(point))
            b.ellipsoid(at + facing * lift, Vector((0.008, 0.008, 0.0045)), None, 8, 3)


WAISTCOAT_CUT = (0.668, 0.80)  # its hem, and the bottom of its opening


def waistcoat(b):
    """A waistcoat: cut high under the arm, open in a V to the breastbone, over the shoulders and whole behind."""
    hem, opening = WAISTCOAT_CUT
    slope = 0.52

    def keep(p):
        if p.y < hem or abs(p.x) > 0.109 or (p.y > 0.922 and abs(p.x) < 0.07):
            return False
        return not (p.z > 0.0 and abs(p.x) < (p.y - opening) * slope)

    shell(b, keep, 0.006, [((0.0, hem, 0.0), Y), ((0.109, 0.0, 0.0), X), ((-0.109, 0.0, 0.0), X),
                           ((0.0, opening, 0.0), (1.0, -slope, 0.0)), ((0.0, opening, 0.0), (-1.0, -slope, 0.0)), ((0.0, 0.0, 0.0), Z),
                           ((0.07, 0.0, 0.0), X), ((-0.07, 0.0, 0.0), X), ((0.0, 0.922, 0.0), Y)])


def waistcoat_buttons(b):
    for y in (0.695, 0.735, 0.775):
        at, facing = onto_body(Vector((0.0, y, 0.14)))
        b.ellipsoid(at + facing * 0.0085, Vector((0.007, 0.007, 0.004)), None, 8, 3)


def pinafore(b):
    """A pinafore over her dress: a bib, broad straps over the shoulders crossed behind, a sash, and an apron down the front of the skirt."""
    out = 0.115
    shell(b, lambda p: p.z > 0.0 and abs(p.x) < 0.064 and SKIRT_TOP < p.y < 0.855, 0.006,
          [((0.064, 0.0, 0.0), X), ((-0.064, 0.0, 0.0), X), ((0.0, 0.855, 0.0), Y), ((0.0, SKIRT_TOP, 0.0), Y)])
    shell(b, lambda p: SKIRT_TOP - 0.004 < p.y < SKIRT_TOP + 0.02 and abs(p.x) < 0.2, 0.0085, [((0.0, SKIRT_TOP - 0.004, 0.0), Y), ((0.0, SKIRT_TOP + 0.02, 0.0), Y)])
    for side in (1.0, -1.0):
        ribbon(b, [(side * 0.046, 0.835, out), (side * 0.074, 0.90, 0.10), (side * 0.096, 0.95, 0.07), (side * 0.104, 1.0, 0.0),
                   (side * 0.096, 0.95, -0.08), (side * 0.070, 0.88, -out), (side * 0.030, 0.81, -out), (-side * 0.022, 0.75, -out), (-side * 0.054, SKIRT_TOP + 0.012, -out)],
                   [0.038] * 9, 0.0095 if side > 0.0 else 0.007, 30, 3)
    # The apron lies on the skirt, fold for fold
    steps, columns, spread = (3, 4, 0.95) if kit.LOW else (9, 16, 0.95)
    top, under = [], []
    for k in range(steps + 1):
        y = SKIRT_TOP - 0.004 - (SKIRT_TOP - 0.004 - 0.385) * k / steps
        angles = [spread * (2.0 * m / columns - 1.0) for m in range(columns + 1)]
        top.append([skirt_at(angle, y, 0.007) for angle in angles])
        under.append([skirt_at(angle, y, -0.004) for angle in angles])
    sheet(b, top, under)


# (part, material or None if the part colours itself, shapes, how to fuse them)
# Each body comes before what is laid on it: his bib and its buttons, a waistcoat, a pinafore.
PARTS = [
    ("body__base", None, body, None),
    ("over__base", DENIM, bib, None),
    ("over__base", BRASS, buttons, None),
    ("patch__base", PATCH, knee_patch, None),
    ("over__braces", BRACES, braces, None),
    ("over__braces", BRASS, brace_buttons, None),
    ("over__waistcoat", WAISTCOAT, waistcoat, None),
    ("over__waistcoat", BRASS, waistcoat_buttons, None),
    ("body__long", None, body_long, None),
    ("over__braceslong", BRACES, braces, None),
    ("over__braceslong", BRASS, brace_buttons, None),
    ("over__waistcoatlong", WAISTCOAT, waistcoat, None),
    ("over__waistcoatlong", BRASS, waistcoat_buttons, None),
    ("body__suit", None, body_suit, None),
    ("body__suit", BRASS, suit_buttons, None),
    ("body__dress", None, body_dress, None),
    ("skirt__dress", DENIM, skirt, None),
    ("over__pinafore", APRON, pinafore, None),
    ("head__base", SKIN, head, (0.004, 4, 2000)),
    ("head__sculpt", None, head_sculpt, None),
    ("head__sculpt", SKIN, sculpt_ears, None),
    ("head__sculpt", HAIR, sculpt_brows, None),
    ("head__sculpt", EYES, sculpt_lashes, None),
    ("face__sculpt", PUPIL, eyeballs(PUPIL_RINGS, True), None),
    ("face__sculpt", IRIS, eyeballs(IRIS_RINGS), None),
    ("face__sculpt", EYEWHITE, eyeballs(WHITE_RINGS), None),
    ("face__full", SKIN, nose, None),
    ("face__full", EYES, eyes, None),
    ("face__full", HAIR, brows, None),
    ("face__full", MOUTH, mouth, None),
    ("face__light", SKIN, nose, None),
    ("face__light", HAIR, brows, None),
    ("face__dots", SKIN, nose, None),
    ("face__dots", EYES, eyes_small, None),
    ("hair__base", HAIR, hair_short, None),
    ("hairtop__base", HAIR, hair_forelock, None),
    ("hair__long", HAIR, hair_long, None),
    ("cap", TWEED, cap, None),
    ("hairtop__crown", HAIR, hair_crown, None),
] + [("hair__" + cut, material, under_cap(shapes), None) for cut, shapes, material in CUTS] + [("hairtop__" + cut, material, above_cap(shapes), None) for cut, shapes, material in CUTS] + [
    ("hairtop__waves", APRON, bow, None),
    ("hands", SKIN, hands, None),
    ("fingers", SKIN, fingers, None),
    ("boots", LEATHER, boots, (0.003, 3, 3000)),
]
APART = tuple(sorted({part for part, _material, _shapes, _fuse in PARTS if "__" in part})) + ("cap",)

# Turn-outs to render when a folder for previews is given: (name, what is chosen for each slot, cap on).
PREVIEWS = [
    ("base", {}, True),
    ("bare_full", {"hairtop": "crown", "face": "full"}, False),
    ("crop_light", {"hair": "crop", "hairtop": "crop", "face": "light", "body": "long", "over": "waistcoatlong", "patch": ""}, False),
    ("parting_suit", {"hair": "parting", "hairtop": "parting", "face": "full", "body": "suit", "over": "", "patch": ""}, False),
    ("bob_dress", {"hair": "bob", "hairtop": "bob", "face": "dots", "body": "dress", "skirt": "dress", "over": "", "patch": ""}, False),
    ("plaits_pinafore", {"hair": "plaits", "hairtop": "plaits", "face": "full", "body": "dress", "skirt": "dress", "over": "pinafore", "patch": ""}, False),
    ("ponytail_braces", {"hair": "ponytail", "hairtop": "ponytail", "face": "full", "over": "braces", "patch": ""}, False),
    ("curls_waistcoat", {"hair": "curls", "hairtop": "curls", "face": "full", "over": "waistcoat", "patch": ""}, False),
    ("curls_cap", {"hair": "curls", "hairtop": "", "face": "full", "body": "long", "over": "braceslong", "patch": ""}, True),
    ("bob_cap", {"hair": "bob", "hairtop": "", "face": "full", "body": "dress", "skirt": "dress", "over": "", "patch": ""}, True),
    ("sculpt_bowl", {"hair": "bowl", "hairtop": "bowl", "head": "sculpt", "face": "sculpt"}, False),
    ("sculpt_quiff", {"hair": "quiff", "hairtop": "quiff", "head": "sculpt", "face": "sculpt", "body": "suit", "over": "", "patch": ""}, False),
    ("sculpt_gibson", {"hair": "gibson", "hairtop": "gibson", "head": "sculpt", "face": "sculpt", "body": "dress", "skirt": "dress", "over": "", "patch": ""}, False),
    ("sculpt_waves", {"hair": "waves", "hairtop": "waves", "head": "sculpt", "face": "sculpt", "body": "dress", "skirt": "dress", "over": "pinafore", "patch": ""}, False),
]


def previews(name, folder):
    """Renders the turn-outs in PREVIEWS, showing for each only what the game would."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 700, 700
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (PREVIEW_ONLY in the environment, a list of their names, renders just those)
    wanted = os.environ.get("PREVIEW_ONLY", "").split()
    for label, chosen, capped in PREVIEWS:
        if wanted and label not in wanted:
            continue
        for thing in scene.objects:
            if thing.type != "MESH":
                continue
            slot, found, option = thing.name.partition("__")
            if found:
                thing.hide_render = chosen.get(slot.split("_")[-1], "base") != option
            elif thing.name.endswith("_cap"):
                thing.hide_render = not capped
        for view, direction, target, frame in (("front", (0.25, -1, 0.1), (0.0, 0.0, 0.67), 1.5), ("back", (-0.5, 1, 0.15), (0.0, 0.0, 0.67), 1.5),
                                               ("head", (0.5, -0.85, 0.12), (0.0, 0.0, 1.10), 0.46), ("headback", (-0.6, 0.8, 0.2), (0.0, 0.0, 1.08), 0.5),
                                               ("face", (0.0, -1, 0.03), (0.0, 0.0, 1.09), 0.3), ("profile", (1, 0, 0.0), (0.0, 0.0, 1.09), 0.34),
                                               ("top", (0.0, -0.08, 1), (0.0, 0.0, 1.1), 0.5)):
            offset = Vector(direction).normalized() * 4.0
            camera.data.ortho_scale = frame
            camera.location = Vector(target) + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(folder, "%s_%s_%s.png" % (name, label, view))
            bpy.ops.render.render(write_still=True)


# (not when another figure's script has imported this one for its shapes)
if __name__ == "__main__":
    # (the kit's own previews show every object at once, which is no use for a figure with choices)
    folder, kit.PREVIEW_DIR = kit.PREVIEW_DIR, None
    kit.export("boy", bones(), PARTS, weights, MATERIALS, apart=APART)
    if folder:
        previews("boy", folder)
    kit.LOW = True
    kit.export("boy_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS, apart=APART)
    if folder and os.environ.get("PREVIEW_LO"):
        previews("boy_lo", folder)
