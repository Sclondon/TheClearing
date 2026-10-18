"""Builds the bat's body and head and exports them for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/bats/tools/build_bat.py

Writes creatures/bats/models/bat_body.glb. BatBody (creatures/bats/bat_body.gd)
reads it and merges its triangles into the colony's mesh, by material: the
wings, legs and tail are not here (BatBody makes those in code, as bones and
skin the shader poses).

All coordinates below are in Godot space, in the bat's units (wingspan 1: the
body from rump to nose is about 0.27), Y up, the bat facing +Z, and converted
on the way into Blender (Blender's -Y is Godot's +Z).

What is made, each with its own material (BatBody tells the parts apart by it):
- fur: the torso (rump, belly, chest, shoulder humps), a short neck, the head
  (cranium, brow, cheeks) and a short fox-like snout, one fused surface made
  from overlapping balls (a metaball family) and thinned to a few hundred
  triangles;
- jaw: the lower jaw, its own surface, hinged under the cheeks (the shader
  opens it to shriek); jaw_teeth: its two canines; tongue: the inside of it;
- teeth: two upper canines and the little teeth between; mouth: the palate;
- nose: the wet nose pad, with a nose leaf standing up from it and two
  nostrils;
- ear, ear_inner: the ears, tall, cupped forward and curving back at the
  tip, thin shells with ridges across the inside, a tragus standing in front
  of each hollow (ear_inner is the hollow side, ear the back);
- eye: small dark beads;
- tuft: a ragged fringe of small tapered tufts on the ruff, the shoulders,
  the flanks and the belly.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "creatures", "bats", "models", "bat_body.glb")

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


def material(name, colour):
    made = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    made.diffuse_color = (*colour, 1.0)
    return made


MATERIALS = {}


def mat(name):
    colours = {
        "fur": (0.13, 0.115, 0.11), "jaw": (0.13, 0.115, 0.11), "tuft": (0.15, 0.13, 0.12),
        "ear": (0.1, 0.086, 0.085), "ear_inner": (0.36, 0.26, 0.25), "eye": (0.02, 0.02, 0.02),
        "teeth": (0.9, 0.86, 0.76), "jaw_teeth": (0.9, 0.86, 0.76), "mouth": (0.18, 0.05, 0.05),
        "tongue": (0.3, 0.09, 0.09), "nose": (0.05, 0.04, 0.04),
    }
    if name not in MATERIALS:
        MATERIALS[name] = material(name, colours[name])
    return MATERIALS[name]


def blobs(name, balls, faces):
    """One fused surface from `balls` ((x, y, z), surface radius): a metaball
    family, made a mesh, smoothed and thinned to about `faces` triangles."""
    ball_data = bpy.data.metaballs.new(name)
    ball_data.resolution = 0.004
    ball_data.render_resolution = 0.004
    ball_data.threshold = 0.6
    holder = bpy.data.objects.new(name, ball_data)
    bpy.context.scene.collection.objects.link(holder)
    for at, radius in balls:
        element = ball_data.elements.new(type="BALL")
        element.co = B(at)
        element.radius = radius / SHRINK
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
    smooth.iterations = 4
    bpy.ops.object.modifier_apply(modifier="smooth")
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    thin = made.modifiers.new("thin", "DECIMATE")
    thin.ratio = min(1.0, faces / max(tris, 1))
    bpy.ops.object.modifier_apply(modifier="thin")
    made.select_set(False)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return made


def part(name, build):
    """A new object `name` whose mesh `build`(bm) makes."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.to_mesh(mesh)
    bm.free()
    made = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(made)
    return made


def face(bm, points, smooth=True):
    verts = [bm.verts.new(B(p)) for p in points]
    made = bm.faces.new(verts)
    made.smooth = smooth
    return made


def cone(bm, base, tip, radius, sides=4):
    """A little tapering spike (a tooth, a claw) from `base` to `tip`."""
    along = (Vector(tip) - Vector(base)).normalized()
    one = along.cross(Vector((0, 1, 0)) if abs(along.y) < 0.9 else Vector((1, 0, 0))).normalized()
    two = along.cross(one).normalized()
    ring = [Vector(base) + (one * math.cos(k * math.tau / sides) + two * math.sin(k * math.tau / sides)) * radius for k in range(sides)]
    for k in range(sides):
        face(bm, [ring[k], ring[(k + 1) % sides], tip], smooth=False)


def ball(bm, middle, radii, segments=6, rings=4):
    """A small ellipsoid (an eye, a nose pad)."""
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


# --- The parts ---

BODY_BALLS = [
    # The rump and the belly, the chest, and the humps of the shoulders.
    ((0.0, 0.0, -0.092), 0.026), ((0.0, 0.002, -0.06), 0.04), ((0.0, 0.003, -0.025), 0.049),
    ((0.0, 0.002, 0.012), 0.051), ((0.0, 0.006, 0.036), 0.042),
    ((0.028, 0.024, 0.03), 0.026), ((-0.028, 0.024, 0.03), 0.026),
    # The neck, short and thick.
    ((0.0, 0.012, 0.058), 0.03),
    # The head: cranium and brow, the cheeks, the snout tapering to the nose.
    ((0.0, 0.02, 0.085), 0.033), ((0.0, 0.022, 0.098), 0.029),
    ((0.017, 0.006, 0.1), 0.018), ((-0.017, 0.006, 0.1), 0.018),
    ((0.0, 0.01, 0.118), 0.019), ((0.0, 0.009, 0.133), 0.0135), ((0.0, 0.009, 0.143), 0.01),
]
JAW_BALLS = [((0.0, -0.005, 0.108), 0.015), ((0.0, -0.006, 0.124), 0.0105), ((0.0, -0.005, 0.137), 0.0075)]


def ear(bm, side, inner):
    """An ear: a tall shell from the top of the head, leaning out and a little
    forward, its hollow facing forward, curving back at the tip, with ridges
    across the inside of it."""
    base = Vector((0.019 * side, 0.044, 0.08))
    up = Vector((0.4 * side, 1.0, 0.05)).normalized()
    across = (Vector((1.0, 0.0, 0.0)) - up * up.x).normalized()
    back = across.cross(up).normalized()
    if back.z > 0.0:
        back = -back
    if side < 0:
        across = -across
    height = 0.074
    rows = []
    count = 6
    for r in range(count + 1):
        t = r / count
        half = 0.021 * (1.0 - t ** 1.25 * 0.82) + 0.0015
        row = []
        for c in (-1.0, -0.5, 0.0, 0.5, 1.0):
            hollow = (1.0 - c * c) * 0.021 * (1.0 - 0.45 * t) - abs(c) ** 3 * 0.006
            ridge = 0.0016 * math.sin(t * math.pi * 6.0) * (1.0 - c * c) * (1.0 - t) if inner else 0.0
            curl = 0.016 * t * t
            thick = 0.0 if inner else 0.0022
            row.append(base + up * height * t + across * c * half + back * (hollow + ridge + curl + thick))
        rows.append(row)
    tip = base + up * height * 1.1 + back * 0.02
    for r in range(count):
        for c in range(4):
            quad = [rows[r][c], rows[r][c + 1], rows[r + 1][c + 1], rows[r + 1][c]]
            face(bm, quad if (side > 0) == inner else list(reversed(quad)))
    for c in range(4):
        tri = [rows[count][c], rows[count][c + 1], tip]
        face(bm, tri if (side > 0) == inner else list(reversed(tri)))
    if inner:
        # The tragus: a small pointed flap standing up in front of the hollow.
        root = base + up * 0.006 + across * (-0.01) + back * 0.004
        face(bm, [root, root + across * 0.009, root + up * 0.024 + across * 0.002 - back * 0.006])
    else:
        # The rim, joining the back to the hollow along the edges.
        for r in range(count):
            for c in (0, 4):
                outer = [rows[r][c], rows[r + 1][c]]
                inward = [p - back * 0.0022 for p in outer]
                quad = [outer[0], outer[1], inward[1], inward[0]]
                face(bm, quad if (c == 0) == (side > 0) else list(reversed(quad)))


def build():
    clear()
    made = []
    body = blobs("fur", BODY_BALLS, 470)
    body.data.materials.append(mat("fur"))
    made.append(body)
    jaw = blobs("jaw", JAW_BALLS, 70)
    jaw.data.materials.append(mat("jaw"))
    made.append(jaw)

    # The ears.
    for side in (1, -1):
        for inner in (True, False):
            name = "ear_inner" if inner else "ear"
            shell = part("%s_%d" % (name, side), lambda bm, s=side, i=inner: ear(bm, s, i))
            shell.data.materials.append(mat(name))
            made.append(shell)

    # The eyes: small dark beads at the sides of the face, a little forward.
    def eyes(bm):
        for side in (1, -1):
            ball(bm, (0.02 * side, 0.026, 0.112), (0.0045, 0.0042, 0.0045), 6, 4)
    thing = part("eye", eyes)
    thing.data.materials.append(mat("eye"))
    made.append(thing)

    # The nose: a pad at the end of the snout, a leaf standing up from it, nostrils.
    def nose(bm):
        ball(bm, (0.0, 0.011, 0.151), (0.0085, 0.0065, 0.006), 6, 4)
        leaf = [(-0.006, 0.014, 0.152), (0.006, 0.014, 0.152), (0.0, 0.03, 0.146)]
        face(bm, leaf)
        for side in (1, -1):
            ball(bm, (0.0042 * side, 0.0115, 0.1565), (0.0022, 0.0018, 0.0012), 4, 2)
    thing = part("nose", nose)
    thing.data.materials.append(mat("nose"))
    made.append(thing)

    # Teeth: two upper canines and small teeth between; the lower canines on the jaw.
    def teeth(bm):
        for side in (1, -1):
            cone(bm, (0.0068 * side, 0.0035, 0.137), (0.0064 * side, -0.007, 0.138), 0.0018)
            cone(bm, (0.0034 * side, 0.004, 0.143), (0.0032 * side, -0.0015, 0.144), 0.001)
    thing = part("teeth", teeth)
    thing.data.materials.append(mat("teeth"))
    made.append(thing)

    def jaw_teeth(bm):
        for side in (1, -1):
            cone(bm, (0.0058 * side, -0.0035, 0.133), (0.0056 * side, 0.0045, 0.134), 0.0015)
    thing = part("jaw_teeth", jaw_teeth)
    thing.data.materials.append(mat("jaw_teeth"))
    made.append(thing)

    # The inside of the mouth: the palate (dark) above, the tongue in the jaw.
    def palate(bm):
        face(bm, [(-0.008, 0.0015, 0.112), (0.008, 0.0015, 0.112), (0.006, 0.002, 0.142), (-0.006, 0.002, 0.142)])
    thing = part("mouth", palate)
    thing.data.materials.append(mat("mouth"))
    made.append(thing)

    def tongue(bm):
        face(bm, [(-0.007, -0.002, 0.112), (-0.005, -0.0015, 0.138), (0.005, -0.0015, 0.138), (0.007, -0.002, 0.112)])
    thing = part("tongue", tongue)
    thing.data.materials.append(mat("tongue"))
    made.append(thing)

    # The fringe of tufts, standing out of the fur where it is ragged.
    tree = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())

    def tufts(bm):
        def tuft(origin, towards, size, lean):
            hit, normal, _, _ = tree.ray_cast(B(origin), (B(towards) - B(origin)).normalized())
            if hit is None:
                return
            at = G(hit)
            out = Vector((normal.x, normal.z, -normal.y)).normalized()
            side = out.cross(Vector((0.0, 0.0, 1.0)))
            if side.length < 0.1:
                side = Vector((1.0, 0.0, 0.0))
            side = side.normalized()
            tip = at + (out + lean).normalized() * size
            face(bm, [at + side * size * 0.32 - out * 0.002, tip, at - side * size * 0.32 - out * 0.002], smooth=False)
        # The ruff, all round the neck, lying back.
        for k in range(18):
            a = math.tau * (k + 0.5) / 18
            middle = Vector((0.0, 0.012, 0.064))
            origin = middle + Vector((math.cos(a), math.sin(a), 0.0)) * 0.1
            tuft(origin, middle, 0.021 + 0.007 * (k % 2), Vector((0.0, 0.0, -0.9)))
        # Along the shoulders and flanks.
        for k in range(10):
            z = -0.075 + k * 0.012
            for side in (1, -1):
                a = 0.5 + 0.35 * (k % 2)
                middle = Vector((0.0, 0.004, z))
                origin = middle + Vector((math.cos(a) * side, math.sin(a), 0.0)) * 0.1
                tuft(origin, middle, 0.015 + 0.005 * (k % 3 == 0), Vector((0.0, 0.0, -1.0)))
        # The belly.
        for k in range(8):
            z = -0.07 + k * 0.014
            for x in (-0.018, 0.0, 0.018):
                origin = Vector((x, -0.1, z))
                tuft(origin, Vector((x * 0.5, 0.0, z)), 0.013 + 0.004 * ((k + int(x * 100)) % 2), Vector((0.0, -0.3, -1.0)))
    thing = part("tuft", tufts)
    thing.data.materials.append(mat("tuft"))
    made.append(thing)

    triangles = 0
    for thing in made:
        triangles += sum(len(p.vertices) - 2 for p in thing.data.polygons)
        thing.select_set(True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False, use_selection=True)
    low = Vector((1e9, 1e9, 1e9))
    high = -low
    for vertex in body.data.vertices:
        p = G(vertex.co)
        low = Vector((min(low.x, p.x), min(low.y, p.y), min(low.z, p.z)))
        high = Vector((max(high.x, p.x), max(high.y, p.y), max(high.z, p.z)))
    print("BUILT bat_body: %d triangles; the body from %s to %s" % (triangles, tuple(round(v, 4) for v in low), tuple(round(v, 4) for v in high)))


build()
