"""Builds the beast's head and antlers, its eyes, and the shroud of dark it wears, for Godot.

    blender --background --python creatures/beast/tools/build_beast.py [-- <folder for preview renders>]

Writes, into creatures/beast/models/:
- beast.glb and beast_lo.glb, one object each:
  - `head`: a long dark head, something between a stag's skull and a mask of bark, under great
    branching antlers like dead boughs; in the space of the boy's head joint (Godot space:
    metres, Y up, the face looking down +Z).
  - `eyes`: its two eyes, pale almonds the game burns (a material of their own).
  - `cape`: a ragged shroud of dark over its shoulders, in the space of the boy's chest joint.
  - `shroud`: its long skirts, ragged into strips at the hem, to the ground, in the space of
    the boy's hips joint.

The body under them is the boy's, drawn far taller and black; nothing here is skinned. Uses
the woodsman's builder (creatures/woodsman/tools/build_woodsman.py), the same one material of
vertex colours. Its lantern is the woodsman's (OilLantern).

After the Beast of Over the Garden Wall: a tall shadow in the woods, antlers, two burning
eyes and a lantern, seen mostly as a silhouette (the user, 2026-10-18: "a the Beast inspired
character from Over the Garden Wall").
"""

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
MODELS = os.path.join(COMPONENT, "models")
sys.path.insert(0, os.path.join(os.path.dirname(COMPONENT), "woodsman", "tools"))

sys.dont_write_bytecode = True

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import build_woodsman as kit  # noqa: E402
from build_woodsman import Builder, mix, shade, smooth, bump, noise  # noqa: E402

DARK = (0.03, 0.028, 0.027)
DARKER = (0.012, 0.011, 0.011)
BOUGH = (0.07, 0.062, 0.055)
BOUGH_TIP = (0.12, 0.11, 0.1)
EYE = (0.95, 0.96, 0.9)


def head(b, q):
    """The head: long, narrow, sloping to a blunt muzzle, ridged like bark; hollows where eyes
    would be, its own eyes (`eyes`) set in them; great antlers out of its crown."""
    sides = 12 + 8 * q
    rows = [k / (8 + 10 * q) for k in range(9 + 10 * q)]
    low, high = -0.02, 0.2

    def radius_at(y, a):
        front = max(0.0, math.cos(a))
        t = (y - low) / (high - low)
        w = 0.07 * math.sqrt(max(0.0, 1.0 - (2.0 * t - 1.0) ** 4)) + 0.004
        d = w * 1.25
        # (the muzzle: pushed far out in front, low)
        push = 0.09 * front ** 3 * smooth(0.0, 0.25, t) * smooth(0.7, 0.35, t)
        # (the brow ridge, and the hollows under it)
        push += 0.012 * front ** 2 * bump(t, 0.68, 0.08)
        for side in (1.0, -1.0):
            sx = math.sin(a) * w
            push -= 0.014 * smooth(0.02, 0.0, math.hypot(sx - side * 0.034, y - 0.112)) * front
        # (ridged, like bark)
        w *= 1.0 + 0.05 * noise(a * 3.0, t * 9.0, 4.0) * (q > 0)
        return (w, d), push

    def colour_at(y, a, push):
        return mix(DARK, DARKER, 0.5 + 0.5 * noise(a * 4.0, y * 30.0, 2.0))

    kit.shell(b, [low + (high - low) * t for t in rows], sides, radius_at, colour_at, centre_z=0.01)
    rng = random.Random(5)
    for side in (1.0, -1.0):
        bough(b, q, Vector((side * 0.045, 0.17, -0.01)), Vector((side * 0.85, 0.55, -0.12)).normalized(), 0.46, 0.022, 1 + min(q, 1), rng, side)
    # A ruff of dark round its throat, joining it to the shroud.
    for k in range(7 + 5 * q):
        a = math.tau * k / (7 + 5 * q)
        out = Vector((math.sin(a), 0.0, math.cos(a)))
        root = Vector((math.sin(a) * 0.06, 0.02, 0.01 + math.cos(a) * 0.07))
        pts = [root, root + out * 0.04 + Vector((0, -0.07, 0)), root + out * 0.06 + Vector((0, -0.15, 0))]
        b.strip(pts, [0.03, 0.03, 0.006], out, DARK)


def bough(b, q, root, direction, length, radius, depth, rng, side):
    """A crooked bough of antler from `root` along `direction`: tines off it, each a smaller
    bough, `depth` times over, fanned out up, out and forward (the woods' dead boughs as much
    as a stag's), gnarled and wandering."""
    count = 3 + 2 * q
    points, radii = [root], [radius]
    p = Vector(root)
    d = Vector(direction)
    for k in range(1, count + 1):
        t = k / count
        # (it lifts a little as it goes, and wanders)
        d = (d + Vector((0.0, 0.06, 0.0)) + Vector((rng.uniform(-1, 1), rng.uniform(-0.6, 1), rng.uniform(-1, 1))) * 0.1).normalized()
        p = p + d * (length / count)
        points.append(p)
        radii.append(radius * (1.0 - 0.7 * t) + 0.0015)
    b.tube(points, radii, 4 + q, lambda t, a: mix(BOUGH, BOUGH_TIP, t * 0.6 + 0.2 * noise(t * 7.0, a, side)))
    if depth <= 0:
        return
    tines = 3 if depth > 1 else 2
    # (each tine turned off the bough: up, out, forward, by turns)
    ways = [Vector((0.0, 1.0, 0.15)), Vector((side, 0.35, -0.2)), Vector((0.0, 0.55, 0.9)), Vector((side * 0.5, 0.8, -0.6))]
    for k in range(tines):
        at = 0.28 + 0.62 * (k + rng.uniform(0.0, 0.5)) / tines
        i = min(len(points) - 2, int(at * (len(points) - 1)))
        base = points[i]
        along = (points[i + 1] - points[i]).normalized()
        way = ways[(k + depth) % len(ways)]
        tine_dir = (along * 0.45 + way.normalized()).normalized()
        bough(b, q, base, tine_dir, length * rng.uniform(0.45, 0.62), radii[i] * 0.72, depth - 1, rng, side)


def eyes(b, q):
    """Two pale almonds, a little proud of the hollows they sit in."""
    for side in (1.0, -1.0):
        b.blob((side * 0.034, 0.112, 0.094), (0.019, 0.009, 0.01), EYE, 6 + 2 * q, 4)


def cape(b, q):
    """A shroud of dark over its shoulders and down its back to its waist, ragged into long
    strips at the hem. Chest joint space (its shoulders are about 0.1 up, 0.14 out)."""
    sides = 12 + 8 * q
    rows = []
    shape = [(0.19, 0.07, 0.06), (0.13, 0.19, 0.14), (0.08, 0.2, 0.15), (-0.1, 0.21, 0.16), (-0.3, 0.23, 0.18)]
    for j, (y, rx, rz) in enumerate(shape):
        row = []
        for s in range(sides):
            a = math.tau * s / sides
            hem = 0.0
            if j == len(shape) - 1:
                hem = -0.12 * (0.5 + 0.5 * noise(a * 5.0, 0.0, 3.0)) * (s % 2)
            row.append(b.vert((math.sin(a) * rx, y + hem, math.cos(a) * rz - 0.01), mix(DARK, DARKER, 0.5 + 0.5 * noise(a * 3.0, y * 9.0, 1.0))))
        rows.append(row)
    b.grid(rows, closed=True, flip=True)
    inner = [[b.vert(b.verts[i] * 0.96, DARKER) for i in row] for row in rows]
    b.grid(inner, closed=True)


def shroud(b, q):
    """Its long skirts, from its waist to the ground, flared, ragged into strips that trail on
    the ground. Hips joint space (the ground is about 0.62 under it, as the boy is built). Open
    a little in front, for its legs."""
    sides = 14 + 10 * q
    gap = 0.35
    rows_n = 5 + 4 * q
    outer, inner = [], []
    for j in range(rows_n + 1):
        t = j / rows_n
        y = 0.06 - 0.66 * t
        rx = 0.15 + 0.12 * t
        rz = 0.12 + 0.1 * t
        o, i_ = [], []
        for s in range(sides + 1):
            a = gap + (math.tau - 2.0 * gap) * s / sides
            hem = 0.0
            if j == rows_n:
                hem = (0.04 + 0.08 * (0.5 + 0.5 * noise(a * 4.0, 2.0, 7.0))) * (s % 2)
            p = Vector((math.sin(a) * rx, y + hem, math.cos(a) * rz))
            c = mix(DARK, DARKER, 0.5 + 0.5 * noise(a * 3.0, t * 5.0, 9.0))
            o.append(b.vert(p, c))
            n = Vector((math.sin(a) * rz, 0.0, math.cos(a) * rx)).normalized()
            i_.append(b.vert(p - n * 0.006, DARKER))
        outer.append(o)
        inner.append(i_)
    b.grid(outer, flip=True)
    b.grid(inner)
    b.grid([[r[0] for r in outer], [r[0] for r in inner]])
    b.grid([[r[-1] for r in outer], [r[-1] for r in inner]], flip=True)


PARTS = [("head", head), ("eyes", eyes), ("cape", cape), ("shroud", shroud)]


def build(q, suffix):
    kit.clear()
    made = []
    for name, fn in PARTS:
        b = Builder()
        fn(b, q)
        made.append(b.build(name, mat=kit.material("eyes" if name == "eyes" else "beast")))
    kit.export(made, os.path.join(MODELS, "beast%s.glb" % suffix))
    for obj in made:
        print("  %s: %d triangles" % (obj.name, sum(len(p.vertices) - 2 for p in obj.data.polygons)))


def previews(folder):
    kit.clear()
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    b = Builder()
    head(b, 2)
    eyes(b, 2)
    b.build("head")
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, at, rot in (("front", (0.0, -1.6, 0.3), (math.radians(90), 0, 0)), ("quarter", (1.1, -1.1, 0.4), (math.radians(85), 0, math.radians(45)))):
        cam.location = at
        cam.rotation_euler = rot
        scene.render.filepath = os.path.join(folder, "beast_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(MODELS, exist_ok=True)
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(2, "")
    build(0, "_lo")
    if args:
        previews(args[0])


main()
