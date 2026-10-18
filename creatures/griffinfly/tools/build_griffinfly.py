"""Builds the griffinfly (creatures/griffinfly/): a giant dragonfly of the coal forests, a Meganeura, and exports
it for Godot, at full detail and low.

Run from the project root (Blender 4.3):
    blender --background --python creatures/griffinfly/tools/build_griffinfly.py
then, so that Godot takes up the new models:
    godot --headless --path . --import

Writes creatures/griffinfly/models/griffinfly.glb (about 3,500 triangles) and griffinfly_lo.glb (about 1,000).

It is ONE UNIT across the wings (the game scales it to its wingspan), facing the game's +Z, back up (+Y), its four
wings spread flat out along X, its legs folded forward under its head as it holds them in flight. One object, its
parts told apart by their material's name (GriffinflyLook, creatures/griffinfly/griffinfly_look.gd, reads them so;
the shader moves each about its own joint):

    body      the thorax: the small prothorax behind the head and the great slanted synthorax the wings and legs are on
    head      the face between the eyes and over the jaws (it turns with the eyes)
    eye       the two huge compound eyes, nearly meeting over the head
    jaw       the mandibles, toothed, under the face (they open and snap)
    antenna   two short bristles of feelers
    abdomen   the long abdomen of ten segments, swollen at the base, a little clubbed near the tip, and its two cerci
    leg_fore, leg_mid, leg_hind
              each pair of legs (with their double rows of spines), held forward as a basket to take prey in the air
    wing      the forewings, long and narrow
    hindwing  the hindwings, broader at the base

The shader beats each wing about its hinge (where it meets the thorax), so a wing's points must all be on its own
side of the middle (x > 0 on the right). The hinges, the legs' hips and the neck are where griffinfly_look.gd says
(HINGES, HIPS, NECK): keep them the same.

All coordinates below are in Godot space (x right, y up, z forward) and turned to Blender's as they are made.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "creatures", "griffinfly", "models")

# How much of its radius a lone metaball's surface is at (threshold 0.6, stiffness 2).
SHRINK = 0.672

# Where the wings are hinged (the right side), the hips of the legs, and the neck: as griffinfly_look.gd has them.
HINGE_FORE = (0.012, 0.043, 0.13)
HINGE_HIND = (0.012, 0.041, 0.088)
HIPS = {"leg_fore": (0.009, -0.03, 0.163), "leg_mid": (0.012, -0.032, 0.138), "leg_hind": (0.014, -0.03, 0.112)}
NECK = (0.0, 0.004, 0.19)


def B(p):
    """Godot (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def clear():
    for thing in list(bpy.data.objects):
        bpy.data.objects.remove(thing, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for ball_data in list(bpy.data.metaballs):
        bpy.data.metaballs.remove(ball_data)
    # (and the materials, so that each model's are named plainly, not "body.001")
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)


COLOURS = {
    "body": (0.17, 0.14, 0.1), "head": (0.2, 0.17, 0.12), "eye": (0.08, 0.1, 0.08), "jaw": (0.1, 0.08, 0.06),
    "antenna": (0.1, 0.09, 0.07), "abdomen": (0.16, 0.13, 0.1), "leg_fore": (0.08, 0.07, 0.06),
    "leg_mid": (0.08, 0.07, 0.06), "leg_hind": (0.08, 0.07, 0.06), "wing": (0.7, 0.68, 0.62),
    "hindwing": (0.7, 0.68, 0.62),
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
        big = max(radii)
        element = ball_data.elements.new(type="ELLIPSOID")
        element.co = B(at)
        element.radius = big / SHRINK
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
    """A tapering spike from `base` to `tip` (a spine, a jaw's tooth, a cercus)."""
    base = Vector(base)
    tip = Vector(tip)
    along = (tip - base).normalized()
    one = along.cross(Vector((0, 1, 0)) if abs(along.y) < 0.9 else Vector((1, 0, 0))).normalized()
    two = along.cross(one).normalized()
    ring = [base + (one * math.cos(k * math.tau / sides) + two * math.sin(k * math.tau / sides)) * radius for k in range(sides)]
    for k in range(sides):
        face(bm, [ring[k], ring[(k + 1) % sides], tip], smooth=False)


def tube(bm, points, radii, sides=4, cap=True, flat=None):
    """A tube along `points` (Godot space), as thick as `radii` at each (and as
    much flatter up and down as `flat` says at each, 1 round)."""
    rings = []
    for i, p in enumerate(points):
        p = Vector(p)
        ahead = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])
        ahead.normalize()
        one = ahead.cross(Vector((0, 1, 0)) if abs(ahead.y) < 0.9 else Vector((1, 0, 0))).normalized()
        two = ahead.cross(one).normalized()
        squash = flat[i] if flat else 1.0
        rings.append([p + (one * math.cos(k * math.tau / sides) + two * math.sin(k * math.tau / sides) * squash) * radii[i] for k in range(sides)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            j = (k + 1) % sides
            face(bm, [rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]])
    if cap and radii[-1] > 0.0:
        face(bm, list(reversed(rings[-1])))
    if cap and radii[0] > 0.0:
        face(bm, rings[0])


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


# --- The wings ---

def wing(bm, hinge, length, lead, trail, side, spans, chords, droop):
    """A long flat wing out from `hinge` (x, y, z) along +x to `length` from the
    middle of the body, a grid of `spans` by `chords`: its leading edge `lead`(u)
    in front of the hinge's line and its trailing edge `trail`(u) behind (u 0 at
    the root to 1 at the tip), rounded off at the tip; the outer part drooping
    and the trailing edge a little lower (a camber). Mirrored by `side`."""
    hx, hy, hz = hinge
    rows = []
    for i in range(spans + 1):
        u = i / spans
        # (spaced closer near the tip, where it rounds off)
        u = 1.0 - (1.0 - u) ** 1.25
        x = hx + (length - hx) * u
        round_off = math.sqrt(max(1.0 - max(u - 0.82, 0.0) / 0.18 * max(u - 0.82, 0.0) / 0.18 * 0.92, 0.0))
        front = hz + lead(u) * round_off
        back = hz - trail(u) * round_off
        # (the tip of the leading edge sweeps back a little to meet the trailing edge)
        if u > 0.82:
            back += (front - back) * 0.25 * (u - 0.82) / 0.18
        row = []
        for k in range(chords + 1):
            c = k / chords
            z = front + (back - front) * c
            y = hy - droop * (u ** 2) - 0.004 * c * c * (0.3 + u)
            row.append((x * side, y, z))
        rows.append(row)
    for i in range(spans):
        for k in range(chords):
            quad = [rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]]
            if side < 0:
                quad.reverse()
            face(bm, quad, smooth=False)


def fore_lead(u):
    return 0.012 + 0.018 * math.sin(math.pi * min(u * 1.3, 1.0)) ** 0.5 * (1.0 - 0.3 * u)


def fore_trail(u):
    return 0.012 + 0.05 * math.sin(math.pi * min(u * 1.25 + 0.05, 1.0)) ** 0.6 * (1.0 - 0.25 * u)


def hind_lead(u):
    return 0.01 + 0.016 * math.sin(math.pi * min(u * 1.3, 1.0)) ** 0.5 * (1.0 - 0.3 * u)


def hind_trail(u):
    # (broad at the base: the anal field)
    return 0.016 + 0.05 * math.sin(math.pi * min(u * 1.2 + 0.08, 1.0)) ** 0.6 * (1.0 - 0.2 * u) + 0.03 * max(0.0, 1.0 - u * 3.0)


# --- The legs ---

def leg(bm, hip, knee, ankle, foot, thick, side, sides, spines):
    """A leg from its hip (where it meets the thorax) through the knee and ankle
    to the tip of its claw: a stout femur, a thinner tibia, a short tarsus,
    with `spines` pairs of long spines down the inside of femur and tibia."""
    def m(p):
        return (p[0] * side, p[1], p[2])
    hip, knee, ankle, foot = Vector(m(hip)), Vector(m(knee)), Vector(m(ankle)), Vector(m(foot))
    tube(bm, [hip, hip.lerp(knee, 0.5), knee, knee.lerp(ankle, 0.5), ankle, foot],
         [thick, thick * 1.05, thick * 0.8, thick * 0.7, thick * 0.55, thick * 0.25], sides=sides)
    if spines <= 0:
        return
    # The spines: down the inner side (towards the middle and forward, into the basket).
    middle = Vector((0.0, (hip.y + foot.y) * 0.5 - 0.01, (hip.z + foot.z) * 0.5 + 0.03))
    for a, b, n, size in ((hip, knee, spines, 0.011), (knee, ankle, spines + 1, 0.013)):
        for k in range(n):
            t = (k + 0.7) / (n + 0.4)
            at = a.lerp(b, t)
            inward = (middle - at)
            inward.x *= 1.6
            inward.normalize()
            along = (b - a).normalized()
            for twist in (-1, 1):
                # (two rows, a little either side of the inner line, raked towards the foot)
                out = (inward + along * 0.55 + Vector((0.0, 0.25 * twist, 0.0))).normalized()
                cone(bm, at, at + out * size * (0.8 + 0.4 * t), thick * 0.35)


def legs_of(bm, which, sides, spines):
    hip = HIPS[which]
    shapes = {
        # (knee, ankle, claw) out from the hip: folded forward under the head, the
        # front pair shortest, the hind longest; the tibiae reaching forward.
        "leg_fore": ((0.034, -0.056, 0.182), (0.03, -0.05, 0.228), (0.022, -0.042, 0.252)),
        "leg_mid": ((0.05, -0.064, 0.152), (0.042, -0.062, 0.218), (0.03, -0.056, 0.246)),
        "leg_hind": ((0.062, -0.07, 0.118), (0.052, -0.074, 0.2), (0.038, -0.07, 0.236)),
    }
    knee, ankle, foot = shapes[which]
    for side in (1, -1):
        leg(bm, hip, knee, ankle, foot, 0.0052 if which != "leg_fore" else 0.0046, side, sides, spines)


# --- The whole ---

def griffinfly(low):
    things = []
    name = "griffinfly_lo" if low else "griffinfly"
    # The thorax: the prothorax, a neck behind the head, and the great synthorax
    # slanted back (the legs forward under it, the wings back on top of it).
    thorax = blobs(name + "_thorax", [
        ((0.0, 0.0, 0.178), (0.02, 0.02, 0.014)),        # the prothorax
        ((0.0, -0.012, 0.16), (0.026, 0.03, 0.022)),     # the synthorax, from its foot forward under the head ...
        ((0.0, 0.002, 0.138), (0.037, 0.045, 0.033)),
        ((0.0, 0.013, 0.11), (0.038, 0.04, 0.034)),     # ... to its top back where the wings are
        ((0.0, 0.017, 0.086), (0.03, 0.032, 0.027)),
        ((0.0, 0.01, 0.066), (0.02, 0.022, 0.02)),       # the waist into the abdomen
    ], 380 if low else 1500, 0.012 if low else 0.0045)
    things.append(coloured(thorax, "body"))
    face_ = blobs(name + "_face", [
        ((0.0, 0.006, 0.226), (0.022, 0.026, 0.02)),     # the frons
        ((0.0, -0.014, 0.234), (0.02, 0.016, 0.016)),    # the clypeus and labrum over the jaws
        ((0.0, 0.0, 0.205), (0.024, 0.024, 0.018)),      # the back of the head
    ], 120 if low else 420, 0.012 if low else 0.005)
    things.append(coloured(face_, "head"))

    def eyes(bm):
        segments, rings = (10, 7) if low else (20, 14)
        for side in (1, -1):
            # (huge, wrapping round the sides and top of the head, pressed together over it)
            ball(bm, (0.025 * side, 0.021, 0.214), (0.031, 0.039, 0.037), segments, rings)
    things.append(part(name + "_eyes", eyes, "eye"))

    def jaws(bm):
        # Two toothed mandibles that close across each other under the labrum.
        for side in (1, -1):
            root = Vector((0.016 * side, -0.022, 0.232))
            tip = Vector((-0.004 * side, -0.03, 0.252))
            bend = Vector((0.012 * side, -0.028, 0.252))
            tube(bm, [root, bend, tip], [0.006, 0.0045, 0.0012], sides=3 if low else 5, flat=[0.6, 0.6, 0.6])
            if not low:
                for k in range(3):
                    at = bend.lerp(tip, 0.2 + k * 0.28)
                    cone(bm, at, at + Vector((-0.004 * side, -0.003, -0.002)), 0.0012)
    things.append(part(name + "_jaws", jaws, "jaw"))

    def feelers(bm):
        for side in (1, -1):
            tube(bm, [(0.008 * side, 0.024, 0.236), (0.014 * side, 0.032, 0.246), (0.022 * side, 0.036, 0.258)],
                 [0.0016, 0.0012, 0.0005], sides=3)
    things.append(part(name + "_feelers", feelers, "antenna"))

    def abdomen(bm):
        # Ten segments, swollen at the base, thinnest in the middle, a little
        # clubbed at the eighth and ninth; a ridge of a joint at each.
        points, radii = [], []
        start, end = 0.072, -0.37
        steps = 40 if not low else 20
        for k in range(steps + 1):
            t = k / steps
            z = start + (end - start) * t
            seg = t * 10.0
            width = 0.021 * (1.0 - 0.32 * math.sin(math.pi * min(t * 1.35, 1.0))) * (1.0 - 0.25 * t)
            width *= 1.0 + 0.12 * math.exp(-((t - 0.8) / 0.08) ** 2)
            if not low:
                joint = 1.0 - min(abs(seg - round(seg)) * 4.0, 1.0)
                width *= 1.0 + 0.09 * joint
            points.append((0.0, 0.008 - 0.018 * t * t, z))
            radii.append(width)
        radii[-1] = 0.006
        tube(bm, points, radii, sides=5 if low else 10, flat=[0.88] * len(points))
        # The two cerci at its tip.
        for side in (1, -1):
            cone(bm, (0.004 * side, -0.01, end + 0.004), (0.014 * side, -0.014, end - 0.04), 0.003, 3 if low else 4)
    things.append(part(name + "_abdomen", abdomen, "abdomen"))

    for which in ("leg_fore", "leg_mid", "leg_hind"):
        things.append(part(name + "_" + which, lambda bm, w=which: legs_of(bm, w, 3 if low else 5, 0 if low else 3), which))

    spans, chords = (6, 2) if low else (14, 4)
    for side in (1, -1):
        things.append(part(name + "_fore%d" % side, lambda bm, s=side: wing(bm, HINGE_FORE, 0.5, fore_lead, fore_trail, s, spans, chords, 0.012), "wing"))
        things.append(part(name + "_hind%d" % side, lambda bm, s=side: wing(bm, HINGE_HIND, 0.485, hind_lead, hind_trail, s, spans, chords, 0.012), "hindwing"))
    return join(things, name)


def export(thing, path):
    bpy.ops.object.select_all(action="DESELECT")
    thing.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_animations=False,
                              use_selection=True, export_materials="EXPORT")


def build():
    for low in (False, True):
        clear()
        MATERIALS.clear()
        made = griffinfly(low)
        made.location = (0, 0, 0)
        print("BUILT %s: %d triangles" % (made.name, triangles(made)))
        export(made, os.path.join(OUT, made.name + ".glb"))


build()
