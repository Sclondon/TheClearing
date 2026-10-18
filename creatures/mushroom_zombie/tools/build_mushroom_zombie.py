"""Builds the mushroom zombie and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py and tools/build_boy.py, and
the mushrooms' growths, creatures/mushrooms/models/growths.glb, built first by build_mushrooms.py):
    blender --background --python creatures/mushroom_zombie/tools/build_mushroom_zombie.py
then, so that Godot takes up the new model:
    godot --headless --path . --import

Writes creatures/mushroom_zombie/models/mushroom_zombie.glb and mushroom_zombie_lo.glb (and an editable .blend copy
beside this file, which is not kept: this folder has a .gdignore so that Godot does not try to import it).

He is the boy (the same bones, the same shapes, made by build_boy.py: his shirt and long trousers, the plain head,
the basin cut of hair, his hands and boots), made into ONE mesh with ONE material, so that he costs a single draw
(and its shadow) where the boy, dressed by the game, costs a dozen. What tells his parts apart is painted into his
vertex colours instead: an ashen, mottled skin, the shirt and trousers faded and filthy, the hair matted; and over
him, spreading from where the fungus has broken through (the crown, the shoulders, the spine, the side of the face),
pale patches and threads of mycelium. The growths (creatures/mushrooms/models/growths.glb: the crown, a clump on
each shoulder, shelves down the back, mats on the neck, chest and face) are joined into the same mesh, each held
wholly by the bone it grows from (the head, or the chest), so that they move with him.

Every point's UV is (how far it glows in the dark, how high it is on its growth); his body's is (0, 0).
MushroomLook's shader draws him (vertex colours, cel shaded); MushroomZombieRig moves him.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
GAME = os.path.dirname(os.path.dirname(COMPONENT))
sys.path.insert(0, os.path.join(GAME, "tools"))
import build_boy as boy  # noqa: E402  (the boy's shapes and weights)

kit = boy.kit
# (it writes its model into the component, not the game's models/)
kit.ROOT = COMPONENT
GROWTHS = os.path.join(GAME, "creatures", "mushrooms", "models")

# The parts of the boy he is made of.
WANTED = ("body__long", "head__base", "hair__bowl", "hairtop__bowl", "hands", "fingers", "boots")

# His colours, by the boy's material (sRGB): all gone grey.
COLOURS = {
    "shirt": (0.52, 0.5, 0.45), "overalls": (0.3, 0.3, 0.28), "skin": (0.62, 0.62, 0.56), "hair": (0.24, 0.22, 0.19),
    "socks": (0.32, 0.31, 0.28), "boots": (0.24, 0.21, 0.18), "brass": (0.4, 0.37, 0.3), "patch": (0.3, 0.28, 0.25),
}
MYCELIUM = (0.74, 0.73, 0.68)
ROT = (0.32, 0.3, 0.24)

# Where the fungus has broken through, in the game's directions (x his left, y up, z ahead), and how far from each
# its threads spread over him: the crown, the left side of the face, the shoulders, the spine, the front of the neck.
SITES = [((0.0, 1.21, -0.03), 0.16), ((0.06, 1.1, 0.09), 0.08), ((0.12, 0.9, -0.01), 0.14), ((-0.12, 0.9, -0.01), 0.12),
         ((0.0, 0.86, -0.1), 0.2), ((0.0, 0.96, 0.06), 0.07), ((0.04, 0.85, 0.09), 0.08)]

# The growths: (the piece in growths.glb, the bone that holds it, its place from that bone's joint (game space):
# a turn (axis, angle) and a scale, and where).
HEAD_AT = Vector((0.0, 1.012, 0.0))
CHEST_AT = Vector((0.0, 0.79, 0.0))
PIECES = [
    ("crown", "head", HEAD_AT, ((0, 1, 0), 0.0), 1.0, (0.0, 0.0, 0.0)),
    ("mat", "head", HEAD_AT, None, 0.8, (0.045, 0.08, 0.085)),
    ("back", "chest", CHEST_AT, ((0, 1, 0), 0.0), 1.0, (0.0, 0.0, 0.0)),
    ("shoulder", "chest", CHEST_AT, ((0, 1, 0), 0.0), 1.0, (0.115, 0.11, -0.01)),
    ("shoulder", "chest", CHEST_AT, ((0, 1, 0), math.pi), 1.0, (-0.115, 0.1, -0.015)),
    ("mat", "chest", CHEST_AT, "chest", 1.0, (0.05, 0.06, 0.085)),
    ("mat", "chest", CHEST_AT, "chest", 0.8, (-0.02, 0.17, 0.06)),
    ("mat", "chest", CHEST_AT, "back", 1.0, (-0.03, 0.02, -0.09)),
]
# The mats' own turns, as columns (x, y, z) in game space: +y the way it faces, its threads running off along -z.
MAT_TURNS = {
    None: ((-0.8, 0.0, 0.6), (0.6, 0.0, 0.8), (0.0, 1.0, 0.0)),
    "chest": ((-1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)),
    "back": ((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)),
}

# Game space <-> Blender's.
TO_BLENDER = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0)))


def srgb_to_linear(c):
    return tuple(kit.linear(v) for v in c)


def smooth(a, b, t):
    t = min(max((t - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def noise(p, scale):
    """A cheap smooth noise of a point (game space), -1..1."""
    x, y, z = p.x * scale, p.y * scale, p.z * scale
    return (math.sin(x * 1.7 + y * 2.3 + 0.5) * math.sin(y * 1.3 - z * 2.9 + 1.1) + math.sin(z * 2.1 + x * 0.7 + 2.0) * 0.5) / 1.5


def painted(material, p, rng_value):
    """His colour at a point (game space) of a part made of `material`."""
    base = COLOURS.get(material, (0.4, 0.4, 0.38))
    # Mottling: the skin blotched and bruised, the cloth stained
    blotch = noise(p, 23.0) * 0.5 + noise(p, 61.0) * 0.25
    tone = 1.0 + blotch * (0.16 if material == "skin" else 0.1) + (rng_value - 0.5) * 0.04
    colour = tuple(c * tone for c in base)
    # The rot round where it broke through, and the threads of mycelium spreading from there
    reach = 0.0
    for site, spread in SITES:
        d = (p - Vector(site)).length
        reach = max(reach, 1.0 - d / (spread * 1.7))
    if reach > 0.0:
        colour = tuple(c + (r - c) * smooth(0.0, 0.6, reach) * 0.4 for c, r in zip(colour, ROT))
        # (threads: thin ridges of a noise, a little thicker near the site; and a felt of it at the site)
        threads = 1.0 - abs(noise(p, 170.0))
        line = smooth(0.94 - 0.06 * reach, 0.985, threads) * smooth(0.15, 0.5, reach)
        felt = smooth(0.72, 0.95, reach)
        white = max(line * 0.75, felt * 0.85)
        colour = tuple(c + (m - c) * white for c, m in zip(colour, MYCELIUM))
    return colour


class _Export:
    """bpy as the kit sees it, but for its glTF export: before the figure is written, he is made one mesh of one
    material, his colours painted on him, the growths joined to him; and the export writes the colours."""

    class _Scene:
        def gltf(self, **options):
            finish()
            options.setdefault("export_vertex_color", "ACTIVE")
            options.setdefault("export_all_vertex_colors", False)
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


def finish():
    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent and o.parent.type == "ARMATURE")
    armature = body.parent
    mesh = body.data
    names = [m.name for m in mesh.materials]
    rng = random.Random(5)
    # His colours, painted by part, corner by corner
    if "Color" not in mesh.color_attributes:
        mesh.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    paint = mesh.color_attributes["Color"]
    for polygon in mesh.polygons:
        material = names[polygon.material_index] if polygon.material_index < len(names) else "skin"
        for k in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[k].vertex_index]
            p = TO_BLENDER.inverted() @ vertex.co
            c = srgb_to_linear(painted(material, p, rng.random()))
            paint.data[k].color = (c[0], c[1], c[2], 1.0)
    # His UVs: nothing glows, nothing sways
    for layer in list(mesh.uv_layers)[1:]:
        mesh.uv_layers.remove(layer)
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    for loop in mesh.uv_layers[0].data:
        loop.uv = (0.0, 1.0)
    # One material for all of him
    zombie = bpy.data.materials.new("zombie")
    zombie.use_nodes = True
    mesh.materials.clear()
    mesh.materials.append(zombie)
    for polygon in mesh.polygons:
        polygon.material_index = 0
    # The growths, joined to him, each held by its bone
    bpy.ops.import_scene.gltf(filepath=os.path.join(GROWTHS, "growths_lo.glb" if kit.LOW else "growths.glb"))
    found = {o.name.split(".")[0]: o for o in bpy.context.selected_objects if o.type == "MESH"}
    joined = []
    for name, bone, joint, turn, scale, at in PIECES:
        source = found.get(name)
        if source is None:
            continue
        piece = source.copy()
        piece.data = source.data.copy()
        bpy.context.collection.objects.link(piece)
        if name == "mat":
            columns = MAT_TURNS[turn]
            basis = Matrix(((columns[0][0], columns[1][0], columns[2][0]), (columns[0][1], columns[1][1], columns[2][1]),
                            (columns[0][2], columns[1][2], columns[2][2])))
        else:
            basis = Matrix.Rotation(turn[1], 3, Vector(turn[0]))
        place = Matrix.Translation(TO_BLENDER @ (joint + Vector(at))) @ (TO_BLENDER @ (basis * scale) @ TO_BLENDER.inverted()).to_4x4()
        piece.matrix_world = Matrix.Identity(4)
        piece.data.transform(place @ source.matrix_world)
        piece.parent = None
        group = piece.vertex_groups.new(name=bone)
        group.add(list(range(len(piece.data.vertices))), 1.0, "REPLACE")
        piece.data.materials.clear()
        piece.data.materials.append(zombie)
        joined.append(piece)
    for source in found.values():
        bpy.data.objects.remove(source)
    bpy.ops.object.select_all(action="DESELECT")
    for piece in joined:
        piece.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    mesh = body.data
    for layer in list(mesh.uv_layers)[1:]:
        mesh.uv_layers.remove(layer)
    mesh.color_attributes.active_color_name = "Color"
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    print("ZOMBIE %s: %d triangles, %d materials" % (body.name, sum(len(p.vertices) - 2 for p in mesh.polygons), len(mesh.materials)))


kit.bpy = _Export()
os.makedirs(os.path.join(COMPONENT, "tools"), exist_ok=True)


def parts():
    chosen = []
    for part, material, shapes, fuse in boy.PARTS:
        if part in WANTED:
            chosen.append((part, material, shapes, fuse if not kit.LOW else None))
    return chosen


if __name__ == "__main__":
    kit.PREVIEW_DIR = None
    kit.export("mushroom_zombie", boy.bones(), parts(), boy.weights, boy.MATERIALS)
    kit.LOW = True
    kit.export("mushroom_zombie_lo", boy.bones(), parts(), boy.weights, boy.MATERIALS)
