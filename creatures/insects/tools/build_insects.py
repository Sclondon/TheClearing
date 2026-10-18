"""Builds the flying insects (creatures/insects/) and a carcass for flies to gather on, and exports them for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/insects/tools/build_insects.py
then, so that Godot takes up the new models:
    godot --headless --path . --import

Writes creatures/insects/models/insects.glb (the three insects) and creatures/insects/models/carcass.glb.

The insects are each ONE UNIT across the wings (the game scales them to their wingspan), facing the game's +Z, back
up (+Y), wings spread flat out along X at rest. Each is one object made of parts told apart by their material's
name (InsectLook, creatures/insects/insect_look.gd, reads them so):

    body      the head, thorax and abdomen (one colour, the insect's own; fused smooth from balls)
    fuzz      tufts of hair on a moth's thorax and abdomen, bristles on a fly (a lighter tone, with a rim of light)
    abdomen   a dragonfly's long abdomen and a fly's (banded, and with a metal sheen)
    eye       the eyes (a moth's dark, a fly's red, a dragonfly's great blue-green ones)
    antenna   the feelers (a moth's feathery, combed both sides)
    leg       the six legs
    wing      the forewings (the moth's patterned, the fly's and dragonfly's clear and veined; the shader draws that)
    hindwing  the hindwings (the moth's, the dragonfly's; a fly has none)
    tail      the long tails of a luna moth's hindwings (shown only on a luna moth)

The shader beats the wings by turning each about its hinge (where it meets the thorax), so a wing's points must all
be on its own side of the middle (x > 0 on the right). Keep each insect to a few hundred triangles: they are drawn
many at once.

The carcass is in metres: a dead deer lying on its side, bloated, the hide torn open along the flank on its ribs and
red meat, legs stiff, the skull showing through the face. Materials: hide, hide_pale, flesh, bone, hoof.

All coordinates below are in Godot space (x right, y up, z forward) and turned to Blender's as they are made.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "creatures", "insects", "models", "insects.glb")
OUT_CARCASS = os.path.join(ROOT, "creatures", "insects", "models", "carcass.glb")

# How much of its radius a lone metaball's surface is at (threshold 0.6, stiffness 2).
SHRINK = 0.672


def B(p):
    """Godot (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def G(v):
    """Blender to Godot."""
    return Vector((v.x, v.z, -v.y))


def clear():
    for thing in list(bpy.data.objects):
        bpy.data.objects.remove(thing, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for ball in list(bpy.data.metaballs):
        bpy.data.metaballs.remove(ball)


COLOURS = {
    "body": (0.5, 0.45, 0.4), "fuzz": (0.6, 0.55, 0.5), "abdomen": (0.2, 0.3, 0.35), "eye": (0.05, 0.05, 0.05),
    "antenna": (0.4, 0.35, 0.3), "leg": (0.15, 0.13, 0.12), "wing": (0.7, 0.68, 0.62), "hindwing": (0.66, 0.64, 0.6),
    "tail": (0.6, 0.75, 0.55),
    "hide": (0.33, 0.24, 0.17), "hide_pale": (0.55, 0.47, 0.38), "flesh": (0.42, 0.1, 0.09), "bone": (0.8, 0.76, 0.66),
    "hoof": (0.08, 0.07, 0.06),
}
MATERIALS = {}


def mat(name):
    if name not in MATERIALS:
        made = bpy.data.materials.new(name)
        made.diffuse_color = (*COLOURS[name], 1.0)
        made.use_nodes = True
        bsdf = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs[0].default_value = (*COLOURS[name], 1.0)
        MATERIALS[name] = made
    return MATERIALS[name]


def blobs(name, balls, faces, resolution):
    """One fused surface from `balls` ((x, y, z), (rx, ry, rz)): a metaball
    family (ellipsoids), made a mesh, smoothed and thinned to about `faces` triangles."""
    ball_data = bpy.data.metaballs.new(name)
    ball_data.resolution = resolution
    ball_data.render_resolution = resolution
    ball_data.threshold = 0.6
    holder = bpy.data.objects.new(name, ball_data)
    bpy.context.scene.collection.objects.link(holder)
    for at, radii in balls:
        if not isinstance(radii, (tuple, list)):
            radii = (radii, radii, radii)
        big = max(radii)
        element = ball_data.elements.new(type="ELLIPSOID")
        element.co = B(at)
        element.radius = big / SHRINK
        # (Blender's ellipsoid sizes are in its own axes: x, y = -z, z = y)
        element.size_x = radii[0] / big
        element.size_y = radii[2] / big
        element.size_z = radii[1] / big
        element.stiffness = 2.0
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(holder.evaluated_get(depsgraph))
    bpy.data.objects.remove(holder, do_unlink=True)
    made = bpy.data.objects.new(name + "_mesh", mesh)
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
    return made


def part(name, build, material):
    """A new object `name` whose mesh `build`(bm) makes, all in `material`."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(mesh)
    bm.free()
    made = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(made)
    made.data.materials.append(mat(material))
    return made


def coloured(thing, material):
    thing.data.materials.clear()
    thing.data.materials.append(mat(material))
    return thing


def face(bm, points, smooth=True):
    verts = [bm.verts.new(B(p)) for p in points]
    made = bm.faces.new(verts)
    made.smooth = smooth
    return made


def cone(bm, base, tip, radius, sides=3):
    """A little tapering spike (a bristle, a tuft) from `base` to `tip`."""
    base = Vector(base)
    tip = Vector(tip)
    along = (tip - base).normalized()
    one = along.cross(Vector((0, 1, 0)) if abs(along.y) < 0.9 else Vector((1, 0, 0))).normalized()
    two = along.cross(one).normalized()
    ring = [base + (one * math.cos(k * math.tau / sides) + two * math.sin(k * math.tau / sides)) * radius for k in range(sides)]
    for k in range(sides):
        face(bm, [ring[k], ring[(k + 1) % sides], tip], smooth=False)


def tube(bm, points, radii, sides=4, cap=True):
    """A tube along `points` (Godot space), as thick as `radii` at each: a leg, a feeler."""
    rings = []
    for i, p in enumerate(points):
        p = Vector(p)
        ahead = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])
        ahead.normalize()
        one = ahead.cross(Vector((0, 1, 0)) if abs(ahead.y) < 0.9 else Vector((1, 0, 0))).normalized()
        two = ahead.cross(one).normalized()
        rings.append([p + (one * math.cos(k * math.tau / sides) + two * math.sin(k * math.tau / sides)) * radii[i] for k in range(sides)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            j = (k + 1) % sides
            face(bm, [rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]])
    if cap and radii[-1] > 0.0:
        face(bm, list(reversed(rings[-1])))


def ball(bm, middle, radii, segments=6, rings=4):
    """A small ellipsoid (an eye)."""
    middle = Vector(middle)
    rows = []
    for r in range(rings + 1):
        a = math.pi * r / rings
        row = []
        for s in range(segments):
            b = math.tau * s / segments
            row.append(middle + Vector((math.sin(a) * math.cos(b) * radii[0], math.cos(a) * radii[1], math.sin(a) * math.sin(b) * radii[2])))
        rows.append(row)
    for r in range(rings):
        for s in range(segments):
            t = (s + 1) % segments
            if r == 0:
                face(bm, [rows[0][0], rows[1][t], rows[1][s]])
            elif r == rings - 1:
                face(bm, [rows[r][s], rows[r][t], rows[rings][0]])
            else:
                face(bm, [rows[r][s], rows[r][t], rows[r + 1][t], rows[r + 1][s]])


def wing(bm, outline, y, side, droop=0.0, hinge_x=None):
    """A flat wing from its outline (x, z) on the right side, mirrored by `side`,
    at height `y`, as a fan from a point a little way out from its hinge (the
    first point), with a ring between so it can be cambered: the outer part
    drooping by `droop` per unit out."""
    hub = (outline[0][0] * 0.6 + sum(p[0] for p in outline) / len(outline) * 0.4,
           outline[0][1] * 0.6 + sum(p[1] for p in outline) / len(outline) * 0.4)

    def at(x, z):
        return (x * side, y - droop * max(x - root, 0.0) ** 2, z)
    root = outline[0][0] if hinge_x is None else hinge_x
    middle = [((p[0] + hub[0]) * 0.5, (p[1] + hub[1]) * 0.5) for p in outline]
    n = len(outline)
    for k in range(n):
        j = (k + 1) % n
        tri = [at(*hub), at(*middle[k]), at(*middle[j])]
        quad = [at(*middle[k]), at(*outline[k]), at(*outline[j]), at(*middle[j])]
        if side < 0:
            tri.reverse()
            quad.reverse()
        face(bm, tri, smooth=False)
        face(bm, quad, smooth=False)


def leg(bm, hip, knee, foot, thick, side):
    def m(p):
        return (p[0] * side, p[1], p[2])
    tube(bm, [m(hip), m(knee), m(foot)], [thick, thick * 0.8, thick * 0.35], sides=3)


def join(things, name):
    bpy.ops.object.select_all(action="DESELECT")
    for thing in things:
        thing.select_set(True)
    bpy.context.view_layer.objects.active = things[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = name
    return joined


def triangles(thing):
    return sum(len(p.vertices) - 2 for p in thing.data.polygons)


# --- The moth ---

def moth():
    """A moth, wingspan 1: a stout furry body, a collar of tufts, feathery
    feelers, broad forewings over rounded hindwings (and a luna's long tails)."""
    things = []
    body = blobs("moth_body", [
        ((0.0, 0.0, 0.135), (0.04, 0.038, 0.036)),       # the head
        ((0.0, 0.004, 0.06), (0.062, 0.058, 0.07)),       # the thorax
        ((0.0, 0.0, -0.03), (0.052, 0.048, 0.06)),        # the abdomen, tapering back
        ((0.0, -0.002, -0.1), (0.045, 0.04, 0.055)),
        ((0.0, -0.004, -0.17), (0.034, 0.03, 0.045)),
        ((0.0, -0.006, -0.22), (0.018, 0.016, 0.025)),
    ], 160, 0.008)
    things.append(coloured(body, "body"))

    def fuzz(bm):
        # The collar: a ruff of tufts round the front of the thorax, lying back
        # like shingles (rooted a little under the surface, so only their tips show).
        for k in range(12):
            a = math.pi * (0.05 + 0.9 * k / 11)
            root = Vector((math.cos(a) * 0.046, math.sin(a) * 0.044 + 0.004, 0.105))
            cone(bm, root, root + Vector((math.cos(a) * 0.01, math.sin(a) * 0.01, -0.038)), 0.014)
        # Over the thorax's back and down the abdomen's flanks, lying back.
        def girth(z):
            return 0.055 if z > 0.0 else max(0.05 + z * 0.12, 0.02)
        for k in range(9):
            z = 0.07 - k * 0.032
            for a in (0.25, 0.85, 1.57) if k < 3 else (0.35, 1.0):
                for side in ((1, -1) if a < 1.5 else (1,)):
                    r = girth(z) * 0.85
                    root = Vector((math.cos(a) * r * side, math.sin(a) * r, z))
                    cone(bm, root, root + Vector((math.cos(a) * 0.008 * side, math.sin(a) * 0.006, -0.036)), 0.012)
        # The tuft at the tip of the abdomen.
        cone(bm, (0.0, -0.006, -0.215), (0.0, -0.004, -0.26), 0.014, 4)
    things.append(part("moth_fuzz", fuzz, "fuzz"))

    def eyes(bm):
        for side in (1, -1):
            ball(bm, (0.03 * side, 0.002, 0.15), (0.02, 0.022, 0.02))
    things.append(part("moth_eyes", eyes, "eye"))

    def feelers(bm):
        # Feathery: a rod curving out and forward, combed with teeth both sides
        # that are longest a third of the way along.
        for side in (1, -1):
            points = []
            for k in range(7):
                t = k / 6
                points.append((side * (0.018 + 0.13 * t), 0.03 + 0.06 * t - 0.03 * t * t, 0.16 + 0.17 * t))
            tube(bm, points, [0.0045 * (1.0 - 0.6 * k / 6) for k in range(7)], sides=3)
            for k in range(1, 12):
                t = k / 12
                u = t * 6
                i = min(int(u), 5)
                f = u - i
                p = Vector(points[i]).lerp(Vector(points[i + 1]), f)
                ahead = (Vector(points[i + 1]) - Vector(points[i])).normalized()
                out = ahead.cross(Vector((0, 1, 0))).normalized()
                length = 0.032 * math.sin(math.pi * (0.15 + 0.85 * t)) ** 0.7
                for s in (1, -1):
                    tip = p + out * s * length + ahead * 0.012 + Vector((0, 0.004, 0))
                    face(bm, [p - ahead * 0.004, p + ahead * 0.004, tip], smooth=False)
    things.append(part("moth_feelers", feelers, "antenna"))

    def legs(bm):
        # Thick at the haunch and shoulder, thin and stiff below the knee.
        for side in (1, -1):
            leg(bm, (0.03, -0.03, 0.09), (0.08, -0.03, 0.13), (0.1, -0.06, 0.16), 0.007, side)
            leg(bm, (0.03, -0.035, 0.06), (0.1, -0.025, 0.06), (0.13, -0.065, 0.05), 0.007, side)
            leg(bm, (0.025, -0.035, 0.03), (0.09, -0.03, -0.01), (0.12, -0.065, -0.05), 0.007, side)
    things.append(part("moth_legs", legs, "leg"))

    fore = [(0.045, 0.105), (0.15, 0.13), (0.28, 0.12), (0.4, 0.085), (0.49, 0.03), (0.475, -0.04),
            (0.43, -0.12), (0.36, -0.19), (0.25, -0.18), (0.14, -0.12), (0.06, -0.03)]
    hind = [(0.045, 0.045), (0.16, 0.0), (0.28, -0.07), (0.34, -0.15), (0.32, -0.24), (0.25, -0.3),
            (0.15, -0.31), (0.08, -0.24), (0.045, -0.12)]
    tail = [(0.2, -0.29), (0.28, -0.27), (0.3, -0.4), (0.33, -0.56), (0.31, -0.62), (0.27, -0.58), (0.25, -0.44)]
    for side in (1, -1):
        things.append(part("moth_fore%d" % side, lambda bm, s=side: wing(bm, fore, 0.035, s, 0.06), "wing"))
        things.append(part("moth_hind%d" % side, lambda bm, s=side: wing(bm, hind, 0.028, s, 0.06), "hindwing"))
        things.append(part("moth_tail%d" % side, lambda bm, s=side: wing(bm, [(0.2, -0.26)] + tail, 0.027, s, 0.06, 0.045), "tail"))
    return join(things, "moth")


# --- The fly ---

def fly():
    """A blowfly, wingspan 1: a big head almost all red eye, a bristly thorax,
    a round metallic abdomen, clear wings that lie back over it at rest."""
    things = []
    body = blobs("fly_body", [
        ((0.0, 0.01, 0.17), (0.055, 0.05, 0.04)),         # the head (between the eyes)
        ((0.0, 0.02, 0.07), (0.07, 0.068, 0.075)),        # the thorax
    ], 110, 0.008)
    things.append(coloured(body, "body"))
    belly = blobs("fly_abdomen", [
        ((0.0, 0.004, -0.06), (0.078, 0.06, 0.07)),
        ((0.0, 0.0, -0.13), (0.065, 0.05, 0.06)),
        ((0.0, -0.004, -0.18), (0.035, 0.03, 0.035)),
    ], 110, 0.008)
    things.append(coloured(belly, "abdomen"))

    def eyes(bm):
        for side in (1, -1):
            ball(bm, (0.04 * side, 0.02, 0.18), (0.042, 0.05, 0.042), 7, 5)
    things.append(part("fly_eyes", eyes, "eye"))

    def bristles(bm):
        for k in range(14):
            a = math.pi * (0.15 + 0.7 * (k % 7) / 6)
            z = 0.09 if k < 7 else 0.04
            root = Vector((math.cos(a) * 0.06, math.sin(a) * 0.06 + 0.02, z))
            cone(bm, root, root + Vector((math.cos(a) * 0.02, 0.03, -0.02)), 0.004)
        for k in range(8):
            a = math.pi * (0.2 + 0.6 * (k % 4) / 3)
            z = -0.09 if k < 4 else -0.15
            root = Vector((math.cos(a) * 0.06, math.sin(a) * 0.05, z))
            cone(bm, root, root + Vector((math.cos(a) * 0.015, 0.02, -0.025)), 0.0035)
    things.append(part("fly_bristles", bristles, "fuzz"))

    def legs(bm):
        # Thick at the haunch and shoulder, thin and stiff below the knee.
        for side in (1, -1):
            leg(bm, (0.03, -0.03, 0.1), (0.11, -0.0, 0.15), (0.15, -0.07, 0.19), 0.008, side)
            leg(bm, (0.035, -0.035, 0.07), (0.14, 0.0, 0.06), (0.18, -0.07, 0.04), 0.008, side)
            leg(bm, (0.03, -0.035, 0.04), (0.13, 0.0, -0.04), (0.17, -0.07, -0.1), 0.008, side)
    things.append(part("fly_legs", legs, "leg"))

    outline = [(0.04, 0.085), (0.17, 0.1), (0.32, 0.085), (0.44, 0.045), (0.5, -0.005), (0.47, -0.06),
               (0.37, -0.1), (0.23, -0.115), (0.12, -0.09), (0.06, -0.03), (0.045, 0.03)]
    for side in (1, -1):
        things.append(part("fly_wing%d" % side, lambda bm, s=side: wing(bm, outline, 0.08, s, 0.0), "wing"))
    return join(things, "fly")


# --- The dragonfly ---

def dragonfly():
    """A dragonfly, wingspan 1: great eyes meeting over the head, a stout
    slanted thorax, a long thin abdomen of ten segments, four long narrow
    veined wings, short legs held forward."""
    things = []
    body = blobs("dragonfly_body", [
        ((0.0, 0.0, 0.31), (0.03, 0.03, 0.025)),          # the face
        ((0.0, 0.01, 0.22), (0.045, 0.055, 0.06)),        # the thorax
        ((0.0, 0.005, 0.16), (0.032, 0.04, 0.035)),
    ], 100, 0.008)
    things.append(coloured(body, "body"))

    def eyes(bm):
        for side in (1, -1):
            ball(bm, (0.032 * side, 0.02, 0.3), (0.04, 0.042, 0.04), 8, 5)
    things.append(part("dragonfly_eyes", eyes, "eye"))

    def abdomen(bm):
        # Ten segments, each a little swollen at its joint, thinnest in the middle.
        points = []
        radii = []
        start, end = 0.15, -0.5
        for k in range(21):
            t = k / 20
            z = start + (end - start) * t
            width = 0.022 * (1.0 - 0.45 * math.sin(math.pi * min(t * 1.4, 1.0))) * (1.0 - 0.3 * t)
            if k % 2 == 0:
                width *= 1.18
            points.append((0.0, 0.005 - 0.02 * t * t, z))
            radii.append(width)
        radii[-1] = 0.008
        tube(bm, points, radii, sides=5)
        # The claspers at its tip.
        for side in (1, -1):
            cone(bm, (0.004 * side, -0.015, -0.5), (0.008 * side, -0.018, -0.535), 0.004)
    things.append(part("dragonfly_abdomen", abdomen, "abdomen"))

    def legs(bm):
        # Thick at the haunch and shoulder, thin and stiff below the knee.
        for side in (1, -1):
            leg(bm, (0.015, -0.03, 0.25), (0.05, -0.04, 0.3), (0.06, -0.07, 0.33), 0.005, side)
            leg(bm, (0.015, -0.035, 0.22), (0.06, -0.04, 0.24), (0.075, -0.075, 0.22), 0.005, side)
            leg(bm, (0.015, -0.035, 0.19), (0.06, -0.04, 0.17), (0.075, -0.075, 0.13), 0.005, side)
    things.append(part("dragonfly_legs", legs, "leg"))

    fore = [(0.02, 0.255), (0.15, 0.27), (0.32, 0.27), (0.46, 0.255), (0.5, 0.235), (0.48, 0.205),
            (0.36, 0.19), (0.2, 0.19), (0.07, 0.205), (0.025, 0.225)]
    hind = [(0.02, 0.18), (0.15, 0.19), (0.32, 0.18), (0.46, 0.155), (0.49, 0.13), (0.46, 0.1),
            (0.32, 0.085), (0.16, 0.07), (0.07, 0.065), (0.025, 0.12)]
    for side in (1, -1):
        things.append(part("dragonfly_fore%d" % side, lambda bm, s=side: wing(bm, fore, 0.05, s, 0.08), "wing"))
        things.append(part("dragonfly_hind%d" % side, lambda bm, s=side: wing(bm, hind, 0.046, s, 0.08), "hindwing"))
    return join(things, "dragonfly")


# --- The carcass ---

def carcass():
    """A dead deer on its side, in metres (about 1.5 long), facing +Z, its
    back to -X: bloated, the hide torn open along the flank on red meat and
    the ribs, its legs out stiff, the skull showing through the face."""
    things = []
    hide = blobs("carcass_hide", [
        ((0.0, 0.26, 0.05), (0.3, 0.26, 0.42)),            # the belly, bloated
        ((-0.05, 0.22, -0.4), (0.24, 0.22, 0.22)),         # the haunch
        ((-0.02, 0.2, 0.45), (0.2, 0.2, 0.2)),             # the shoulder
        ((-0.06, 0.16, 0.72), (0.08, 0.08, 0.16)),         # the neck, thrown back
        ((-0.1, 0.12, 0.92), (0.07, 0.07, 0.12)),          # the head, lying flat
        ((-0.12, 0.09, 1.04), (0.04, 0.05, 0.07)),
    ], 600, 0.03)
    things.append(coloured(hide, "hide"))
    belly = blobs("carcass_belly", [((0.17, 0.16, 0.0), (0.12, 0.13, 0.3)), ((0.15, 0.13, -0.3), (0.1, 0.1, 0.12))], 120, 0.03)
    things.append(coloured(belly, "hide_pale"))
    meat = blobs("carcass_meat", [((0.05, 0.43, 0.05), (0.2, 0.08, 0.22)), ((0.0, 0.45, -0.12), (0.12, 0.06, 0.1))], 140, 0.025)
    things.append(coloured(meat, "flesh"))

    def bones(bm):
        # The ribs, arching up out of the torn flank.
        for k in range(8):
            z = -0.14 + k * 0.055
            arc = []
            for j in range(6):
                a = math.pi * (0.1 + 0.8 * j / 5)
                arc.append((0.2 * math.cos(a) * 0.9 + 0.03, 0.4 + 0.12 * math.sin(a), z + 0.02 * math.sin(a)))
            tube(bm, arc, [0.012] * 6, sides=3, cap=False)
        # The skull's brow and eye socket through the face, and a jaw.
        ball(bm, (-0.1, 0.18, 0.95), (0.05, 0.035, 0.08), 6, 4)
        tube(bm, [(-0.08, 0.08, 0.88), (-0.1, 0.06, 1.0), (-0.12, 0.06, 1.1)], [0.02, 0.016, 0.01], sides=4)
    things.append(part("carcass_bones", bones, "bone"))

    def legs(bm):
        # Thick at the haunch and shoulder, thin and stiff below the knee.
        for root, out in (((0.1, 0.18, 0.5), (0.55, 0.06, 0.62)), ((0.08, 0.2, 0.35), (0.52, 0.1, 0.3)),
                          ((0.08, 0.15, -0.38), (0.55, 0.05, -0.35)), ((0.06, 0.2, -0.5), (0.48, 0.12, -0.7))):
            mid = Vector(root).lerp(Vector(out), 0.45)
            tube(bm, [Vector(root), mid, Vector(out)], [0.07, 0.035, 0.022], sides=5)
    things.append(part("carcass_legs", legs, "hide"))

    def hooves(bm):
        for out in ((0.55, 0.06, 0.62), (0.52, 0.1, 0.3), (0.55, 0.05, -0.35), (0.48, 0.12, -0.7)):
            o = Vector(out)
            tube(bm, [o, o + (o - Vector((0.1, o.y, o.z))).normalized() * 0.07], [0.03, 0.02], sides=4)
    things.append(part("carcass_hooves", hooves, "hoof"))
    return join(things, "carcass")


def export(thing, path):
    bpy.ops.object.select_all(action="DESELECT")
    for one in thing:
        one.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_animations=False,
                              use_selection=True, export_materials="EXPORT")


def build():
    clear()
    insects = [moth(), fly(), dragonfly()]
    for thing in insects:
        thing.location = (0, 0, 0)
        print("BUILT %s: %d triangles" % (thing.name, triangles(thing)))
    export(insects, OUT)
    for thing in insects:
        bpy.data.objects.remove(thing, do_unlink=True)
    dead = carcass()
    print("BUILT carcass: %d triangles" % triangles(dead))
    export([dead], OUT_CARCASS)


build()
