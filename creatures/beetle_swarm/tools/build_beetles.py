"""Builds the beetles of a swarm (creatures/beetle_swarm/) and exports them for Godot.

Run from the project root:
    blender --background --python creatures/beetle_swarm/tools/build_beetles.py
then, so that Godot takes up the new model:
    godot --headless --path . --import

Writes creatures/beetle_swarm/models/beetles.glb (and, with KEEP_BLEND=<path.blend> set, a .blend there to look at and
change by hand). Made from Outside's small scarab (Outside: tools/build_khepri.py), which is where the way the legs
are told to move comes from.

Two beetles, each ONE UNIT long and facing the game's +Z, standing on the ground:

    ground_beetle   a big carabid, after the violet ground beetle (Carabus violaceus): long oval wing cases with
                    a flattened margin, a heart-shaped shield over the thorax, a narrow waist, a small head with
                    jaws, long running legs and long thin feelers. Glossy black; the game gives it an oily sheen.
    dor_beetle      a dumpy dung beetle, after the dor beetle (Geotrupes): Outside's scarab with the teeth of its
                    head shield rounded off, short legs, all dome.

The game draws a few hundred of them as one MultiMesh, both kinds in one mesh (BeetleLook), and moves their legs in
a shader, which is told what to move by the mesh's UV map: U is how far down a leg a point is (0 at the hip, 1 at
the foot: the body, the jaws and the feelers are all 0), and V says which three legs it steps with (1, or 0.5 for
the other three; in Godot that is 0 and 0.5). Points added to a leg must take these from the points they are made
from. Each is all one colour (the game's); its materials only say how much each part shines, by their Roughness
(0: wholly; 1: not at all). Keep each to about 200 triangles: there are a great many of them.

Everything below is written in the game's own directions (x to its left, y up, z the way it faces) and turned to
Blender's as it is made.
"""

import bpy
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# How much each part shines (its roughness: 0 wholly, 1 not at all). The colour is the game's.
ROUGHNESS = {
    "shell": 0.1,
    "margin": 0.0,
    "thorax": 0.25,
    "head": 0.6,
    "leg": 1.0,
}
BLACK = (0.03, 0.03, 0.035, 1.0)


def to_blender(p):
    return (p[0], -p[2], p[1])


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


def unit(a):
    size = math.sqrt(sum(c * c for c in a))
    return tuple(c / size for c in a)


def lerp(a, b, t):
    return a + (b - a) * t


class Shape:
    """Faces being gathered for one beetle: each a list of points, a material, and what each corner's normal and
    UV are to be (None: the face's own normal, and a UV of the body)."""

    def __init__(self):
        self.faces = []

    def face(self, points, material, normals=None, uvs=None):
        self.faces.append((points, material, normals, uvs))

    def dome(self, middle, radii, material, around, rings, squeeze=None):
        """Half of an egg, standing on its cut face, each point with the egg's own normal. `squeeze`(z) is how
        much narrower it is at a place along it (1: not at all), for a waist or a shield that is heart-shaped."""
        def corner(ring, k):
            high = math.pi * 0.5 * ring / rings
            turn = math.tau * k / around
            return (math.cos(turn) * math.cos(high), math.sin(high), math.sin(turn) * math.cos(high))

        def put(corners):
            points = []
            for c in corners:
                wide = squeeze(c[2]) if squeeze else 1.0
                points.append((middle[0] + c[0] * radii[0] * wide, middle[1] + c[1] * radii[1], middle[2] + c[2] * radii[2]))
            normals = [unit((c[0] / radii[0], c[1] / radii[1], c[2] / radii[2])) for c in corners]
            self.face(points, material, normals, [(0.0, 1.0)] * len(points))
        for ring in range(rings):
            for k in range(around):
                if ring == rings - 1:
                    put([corner(ring, k), corner(rings, 0), corner(ring, k + 1)])
                else:
                    put([corner(ring, k), corner(ring + 1, k), corner(ring + 1, k + 1), corner(ring, k + 1)])

    def belly(self, middle, radii, material, around, squeeze=None):
        """The flat underside of a dome, facing down."""
        points = []
        for k in range(around):
            turn = math.tau * k / around
            c = (math.cos(turn), math.sin(turn))
            wide = squeeze(c[1]) if squeeze else 1.0
            points.append((middle[0] + c[0] * radii[0] * wide, middle[1], middle[2] + c[1] * radii[2]))
        self.face(points, material, [(0.0, -1.0, 0.0)] * around, [(0.0, 1.0)] * around)

    def limb(self, start, end, thick, low, high, step, lean, tip=0.6):
        """A piece of a leg (or a feeler): two flat strips crossed, one lying and one standing on edge, from `low`
        to `high` of the way down the leg. The strip on edge is lit as if it leant a little to `lean`'s side."""
        along = unit(sub(end, start))
        across = unit(cross(along, (0.0, 1.0, 0.0)))
        over = cross(across, along)
        for way in (across, over):
            lie = unit(cross(way, along))
            if (lie[1] < 0.0) if way is across else (lie[0] * lean < 0.0):
                lie = times(lie, -1.0)
            lie = unit(mix(lie, (0.0, 1.0, 0.0), 0.5))
            points = [sub(start, times(way, thick)), add(start, times(way, thick)), add(end, times(way, thick * tip)), sub(end, times(way, thick * tip))]
            # (V is turned over on the way out of Blender: 1 - step here is step in the game)
            self.face(points, "leg", [lie] * 4, [(low, 1.0 - step), (low, 1.0 - step), (high, 1.0 - step), (high, 1.0 - step)])

    def leg(self, side, hip, knee, ankle, toe, thick, step):
        """A whole leg of three pieces: thigh up to the knee, shin down to the ankle, and the foot along the ground."""
        lean = side
        self.limb(hip, knee, thick, 0.0, 0.4, step, lean, 0.85)
        self.limb(knee, ankle, thick * 0.85, 0.4, 0.85, step, lean, 0.6)
        self.limb(ankle, toe, thick * 0.5, 0.85, 1.0, step, lean, 0.5)


# --- The ground beetle ---

def ground_beetle():
    """A carabid: long, flat-domed wing cases with a margin that stands out a little all round, a narrow waist,
    a heart-shaped shield over the thorax, a small head with jaws, long legs and long feelers."""
    s = Shape()
    # The wing cases: an egg cut long, a little flattened, narrower at the shoulders.
    def shoulders(z):
        return 1.0 - 0.18 * max(z, 0.0) ** 2
    s.dome((0.0, 0.05, -0.19), (0.19, 0.15, 0.31), "shell", 14, 3, shoulders)
    # (the margin: a lip a little wider than the wing cases, lying almost flat, that catches the sheen)
    s.dome((0.0, 0.045, -0.19), (0.205, 0.035, 0.32), "margin", 14, 1, shoulders)
    s.belly((0.0, 0.045, -0.19), (0.205, 0.0, 0.32), "leg", 14, shoulders)
    # The shield over the thorax: heart-shaped, wide at the front and narrow at the back.
    def heart(z):
        return 0.72 + 0.28 * (z + 1.0) * 0.5 + 0.12 * (1.0 - z * z)
    s.dome((0.0, 0.045, 0.165), (0.14, 0.095, 0.1), "thorax", 10, 2, heart)
    s.belly((0.0, 0.045, 0.165), (0.14, 0.0, 0.1), "leg", 10, heart)
    # The head, and its jaws, curved in to cross at their tips.
    s.dome((0.0, 0.035, 0.305), (0.08, 0.065, 0.075), "head", 8, 2)
    for side in (-1.0, 1.0):
        root_out = (side * 0.055, 0.03, 0.35)
        root_in = (side * 0.02, 0.03, 0.36)
        tip = (-side * 0.012, 0.028, 0.43)
        bend = (side * 0.05, 0.03, 0.41)
        s.face([root_out, bend, tip, root_in], "leg", [(0.0, 1.0, 0.0)] * 4, [(0.0, 1.0)] * 4)
    # Six long running legs, each in three pieces. (The legs of one side step in turn, and each with its opposite
    # of the next pair.)
    legs = (
        # hip, knee, ankle, toe (for the left side; x is mirrored for the right), how thick
        ((0.08, 0.04, 0.17), (0.17, 0.09, 0.24), (0.22, 0.015, 0.32), (0.24, 0.0, 0.38), 0.032),
        ((0.1, 0.04, 0.05), (0.21, 0.1, 0.06), (0.3, 0.015, 0.02), (0.34, 0.0, -0.02), 0.03),
        ((0.1, 0.04, -0.04), (0.21, 0.1, -0.14), (0.27, 0.015, -0.32), (0.29, 0.0, -0.4), 0.032),
    )
    for side in (-1.0, 1.0):
        for pair, (hip, knee, ankle, toe, thick) in enumerate(legs):
            step = 0.5 if (pair % 2 == 0) == (side > 0.0) else 0.0
            m = lambda p: (p[0] * side, p[1], p[2])
            s.leg(side, m(hip), m(knee), m(ankle), m(toe), thick, step)
        # The feelers: long and thin, out and forward, a bend a third of the way along. (They do not step.)
        base = (side * 0.055, 0.06, 0.34)
        bend = (side * 0.12, 0.1, 0.47)
        tip = (side * 0.21, 0.08, 0.6)
        s.limb(base, bend, 0.012, 0.0, 0.0, 0.0, side, 0.8)
        s.limb(bend, tip, 0.01, 0.0, 0.0, 0.0, side, 0.6)
    return s


# --- The dor beetle ---

def dor_beetle():
    """A dor beetle: Outside's scarab, its head shield rounded (no teeth), squat and domed, short strong legs."""
    s = Shape()
    s.dome((0.0, 0.06, -0.19), (0.33, 0.29, 0.33), "shell", 8, 3)
    s.belly((0.0, 0.06, -0.19), (0.33, 0.0, 0.33), "leg", 8)
    s.dome((0.0, 0.06, 0.2), (0.31, 0.21, 0.16), "thorax", 8, 2)
    s.belly((0.0, 0.06, 0.2), (0.31, 0.0, 0.16), "leg", 8)
    # The head shield: a plate sloping down to a round front edge.
    edge = []
    for k in range(9):
        turn = lerp(-math.pi * 0.5, math.pi * 0.5, k / 8.0)
        edge.append((math.sin(turn) * 0.19, 0.05, 0.31 + math.cos(turn) * 0.15))
    # (rounded: each point of its edge lit as if the plate curved down there, so that the light on it is a small
    # glint and not the whole plate at once)
    lie = unit((0.0, 0.94, 0.34))
    def bent(p):
        return unit(mix(lie, unit((p[0], 0.0, p[2] - 0.31)), 0.6))
    for k in range(8):
        s.face([(0.0, 0.13, 0.3), edge[k], edge[k + 1]], "head", [lie, bent(edge[k]), bent(edge[k + 1])], [(0.0, 1.0)] * 3)
    for side in (-1.0, 1.0):
        for pair in range(3):
            along = (0.2, 0.02, -0.16)[pair]
            hip = (side * 0.22, 0.08, along)
            knee = (side * 0.37, 0.15, along + (0.1, -0.02, -0.12)[pair])
            foot = (side * (0.4, 0.47, 0.42)[pair], 0.0, along + (0.24, -0.06, -0.34)[pair])
            step = 0.5 if (pair % 2 == 0) == (side > 0.0) else 0.0
            thick = (0.06, 0.04, 0.045)[pair]
            s.limb(hip, knee, thick, 0.0, 0.45, step, side)
            s.limb(knee, foot, thick * 0.8, 0.45, 1.0, step, -side)
    return s


# --- Putting it together ---

def material_of(label, rough):
    material = bpy.data.materials.new(label)
    material.use_nodes = True
    shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = BLACK
    shader.inputs["Roughness"].default_value = rough
    material.diffuse_color = BLACK
    material.roughness = rough
    material.use_backface_culling = False
    return material


def mesh_of(name, shape, materials):
    """A mesh every corner of which has the normal and the UV it was given. Points that lie together are one point."""
    used = []
    for face in shape.faces:
        if face[1] not in used:
            used.append(face[1])
    points = []
    found = {}
    faces = []
    normals = []
    uvs = []
    for corners, _material, face_normals, face_uvs in shape.faces:
        face = []
        if face_normals is None:
            flat = unit(cross(sub(corners[1], corners[0]), sub(corners[2], corners[0])))
            face_normals = [flat] * len(corners)
        if face_uvs is None:
            face_uvs = [(0.0, 1.0)] * len(corners)
        for k, corner in enumerate(corners):
            key = tuple(round(c, 5) for c in corner)
            if key not in found:
                found[key] = len(points)
                points.append(to_blender(corner))
            face.append(found[key])
            normals.append(to_blender(face_normals[k]))
            uvs.append(face_uvs[k])
        faces.append(face)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    if len(mesh.loops) != len(normals):
        raise RuntimeError("%s: a face was not made as it was given" % name)
    layer = mesh.uv_layers.new(name="legs")
    for k, uv in enumerate(uvs):
        layer.data[k].uv = uv
    for k, (_corners, material, _n, _u) in enumerate(shape.faces):
        mesh.polygons[k].material_index = used.index(material)
        mesh.polygons[k].use_smooth = True
    mesh.normals_split_custom_set(normals)
    for label in used:
        mesh.materials.append(materials[label])
    return mesh


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = {}
    for label, rough in ROUGHNESS.items():
        materials[label] = material_of("beetle_" + label, rough)
    counts = {}
    for name, shape, x in (("ground_beetle", ground_beetle(), 0.0), ("dor_beetle", dor_beetle(), 1.5)):
        made = bpy.data.objects.new(name, mesh_of(name, shape, materials))
        bpy.context.collection.objects.link(made)
        made.location = to_blender((x, 0.0, 0.0))
        made.data.calc_loop_triangles()
        counts[name] = len(made.data.loop_triangles)
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    if os.environ.get("KEEP_BLEND"):
        bpy.ops.wm.save_as_mainfile(filepath=os.environ["KEEP_BLEND"])
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "beetles.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
    )
    print("BUILT beetles: the ground beetle %d triangles, the dor beetle %d" % (counts["ground_beetle"], counts["dor_beetle"]))


build()
