"""Builds the frogs and exports them for Godot: the giant toad (rigged) and the
little frog the swarms are made of (two poses baked in as morph targets).

Run from the project root (Blender 4.3):
    blender --background --python creatures/frog/tools/build_frogs.py [-- <preview folder>]

Writes creatures/frog/models/toad.glb and toad_lo.glb (a skinned mesh on an
armature, plus the tongue's shaft and its sticky tip as two loose meshes) and
frog.glb (one small mesh with the shape keys "leap" and "croak"), and, given a
folder, renders previews of each into it.

Everything here is in Godot's axes (Y up, the frog facing +Z, +X its left), in
the frog's own units (1 is its length from snout to rump), and turned into
Blender's (Z up) only as it is made.

THE ANATOMY, after real toads (Bufo, Rhinella) and frogs (Rana, Lithobates):
- a squat body, broad and flat, sitting up at the front with the back sloping
  down to the rump and the belly near the ground;
- a broad flat head as wide as the body, a short rounded snout, and a wide
  mouth whose line runs right round the head to below the eardrum: the upper
  head and the lower jaw are separate surfaces, so the jaw opens on a pink
  mouth (whatever of one is inside the other is coloured as the mouth);
- big bulging eyes high on top of the head on turrets of skin, with gold
  irises and a horizontal pupil (painted in Godot's shader from where on the
  eye each point is); behind each a round eardrum (the tympanum);
- on the toad, a big kidney-shaped paratoid gland behind each eye, and warts
  all over its back, flanks and legs (real bumps, pushed out of the surface;
  finer ones are added in the shader); the frog is smooth;
- a pale throat that inflates (the throat bone is scaled; the frog's is a
  morph);
- long hind legs folded in a Z under and beside the body (thigh forward, shin
  back, the long ankle forward again), with five long toes, the fourth the
  longest, webbed between (the frog all the way, the toad half);
- short forelegs with four splayed fingers turned in, knobbed at the tips.

Colours are vertex colours: muddy olive and brown with darker blotches, dark
bands across the legs, a pale cream belly and throat, wart tips darker and
ochre, a thin pale stripe down the toad's back, a dark mask through the eye to
the eardrum, the mouth pink. The first UV says what a point is (x: 0 skin, 1
eye, 2 mouth, 3 tongue; and on the skin y is its height at rest, for the
shader's fine warts), the second where it is (on the skin, its x and z at
rest; on an eye, where on the eye it is: across and up, as seen from the way
the eye looks, with y of the first UV how far it faces that way).

THE TOAD'S SKELETON: body, head, jaw, throat, and on each side (L is +X) the
thigh, shin, tarsus (the long ankle) and foot, and the arm, forearm and hand.
No bone is the child of another; Godot's GiantToad poses each in its own
right. Each limb's bone runs from its joint to the next (its rest direction
is the bone's Y axis), and every vertex is weighted by how near it is to the
bones of the part it belongs to.

THE LITTLE FROG has no skeleton: the same bones pose it once into the leap
(hind legs thrown out straight behind, forelegs tucked back) and once with its
throat blown up, and those go into shape keys. Godot's FrogSwarm draws them
all as one MultiMesh and blends the poses in its shader.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector, noise
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

# How far out a lone metaball ellipsoid's surface is, as a share of its size (threshold 0.6, stiffness 2).
META = 0.5725

SKIN, EYE, MOUTH, TONGUE = 0.0, 1.0, 2.0, 3.0

KINDS = {
    "toad": dict(
        wide=0.94, leg=1.0, arm=1.0, eye=0.062, head=1.0, warts=420, paratoid=True, web=0.5, toe_bulb=0.0,
        toes=[0.05, 0.075, 0.11, 0.16, 0.1], fingers=[0.04, 0.05, 0.06, 0.045],
        back=(0.15, 0.13, 0.055), blotch=(0.055, 0.047, 0.022), belly=(0.42, 0.37, 0.23), ochre=(0.28, 0.17, 0.05),
        tympanum=0.036, stripe=True, faces=8500, limb_faces=1600, resolution=0.011,
    ),
    "frog": dict(
        wide=0.78, leg=1.28, arm=1.05, eye=0.074, head=0.92, warts=0, paratoid=False, web=0.85, toe_bulb=0.012,
        toes=[0.07, 0.1, 0.15, 0.23, 0.14], fingers=[0.06, 0.08, 0.095, 0.065],
        back=(0.11, 0.14, 0.05), blotch=(0.04, 0.05, 0.02), belly=(0.45, 0.42, 0.27), ochre=(0.28, 0.21, 0.06),
        tympanum=0.045, stripe=False, faces=420, limb_faces=90, resolution=0.022,
    ),
}


def B(p):
    """Godot (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def G(v):
    """Blender to Godot."""
    return Vector((v[0], v[2], -v[1]))


def V(*a):
    return Vector(a)


def smooth(a, b, x):
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def segment_t(p, a, b):
    ab = b - a
    if ab.length_squared < 1e-12:
        return 0.0, (p - a).length
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return t, (a + ab * t - p).length


def along(y, side):
    """A frame (3x3, columns x y z) whose Y is `y`, with X as near `side` as can be (as GiantToad's `_along`)."""
    z = side.cross(y)
    if z.length < 0.05:
        z = Vector((0, 1, 0)).cross(y) if abs(y.y) < 0.9 else Vector((0, 0, -1))
    z.normalize()
    x = y.cross(z).normalized()
    return Matrix((x, y, z)).transposed()


# --- The skeleton ---

def skeleton(k):
    """The joints (Godot space, frog units) and the bones: name -> (head, tail, side hint)."""
    w = k["wide"]
    j = {}
    bones = {}
    bones["body"] = (V(0, 0.25, -0.22), V(0, 0.32, 0.12), V(1, 0, 0))
    bones["head"] = (V(0, 0.38, 0.13), V(0, 0.36, 0.55), V(1, 0, 0))
    bones["jaw"] = (V(0, 0.335, 0.17), V(0, 0.3, 0.52), V(1, 0, 0))
    bones["throat"] = (V(0, 0.29, 0.29), V(0, 0.19, 0.29), V(1, 0, 0))
    for s, tag in ((1.0, "L"), (-1.0, "R")):
        legs = k["leg"]
        hip = V(0.1 * s * w, 0.2, -0.36)
        knee = hip + V(0.31 * s, -0.03, 0.32) * legs
        ankle = knee + V(-0.06 * s, -0.09, -0.38) * legs
        ankle.y = max(ankle.y, 0.06)
        ball = ankle + V(0.1 * s, 0.0, 0.26 * legs)
        ball.y = 0.028
        foot_dir = V(0.45 * s, -0.06, 1.0).normalized()
        toe_end = ball + foot_dir * 0.12 * legs
        arms = k["arm"]
        shoulder = V(0.18 * s * w, 0.27, 0.13)
        elbow = shoulder + V(0.08 * s, -0.11, -0.05) * arms
        wrist = elbow + V(-0.02 * s, 0.0, 0.14 * arms)
        wrist.y = 0.042
        hand_dir = V(-0.25 * s, -0.12, 1.0).normalized()
        hand_end = wrist + hand_dir * 0.07 * arms
        j[tag] = dict(hip=hip, knee=knee, ankle=ankle, ball=ball, toe_end=toe_end, foot_dir=foot_dir,
                      shoulder=shoulder, elbow=elbow, wrist=wrist, hand_end=hand_end, hand_dir=hand_dir)
        up = V(0, 1, 0)
        side = V(1, 0, 0)
        bones["thigh_" + tag] = (hip, knee, up)
        bones["shin_" + tag] = (knee, ankle, up)
        bones["tarsus_" + tag] = (ankle, ball, up)
        bones["foot_" + tag] = (ball, toe_end, up)
        bones["arm_" + tag] = (shoulder, elbow, side)
        bones["forearm_" + tag] = (elbow, wrist, side)
        bones["hand_" + tag] = (wrist, hand_end, side)
    return j, bones


BONE_ORDER = ["body", "head", "jaw", "throat"] + [p + "_" + t for t in ("L", "R") for p in ("thigh", "shin", "tarsus", "foot", "arm", "forearm", "hand")]

# The leap, as directions in the body's frame (s: +1 left, -1 right): the hind
# legs thrown out straight behind and a little down, the forelegs tucked back
# along the flanks.
LEAP = {
    "thigh": (0.3, -0.28, -1.0), "shin": (0.14, -0.32, -1.0), "tarsus": (0.06, -0.36, -1.0), "foot": (0.04, -0.2, -1.0),
    "arm": (0.45, -0.35, -1.0), "forearm": (0.25, -0.25, -1.0), "hand": (0.1, -0.2, -1.0),
}
CHAINS = {"leg": ["thigh", "shin", "tarsus", "foot"], "arm": ["arm", "forearm", "hand"]}


def posed(bones, directions, throat=0.0):
    """Each bone's 4x4 from rest to `directions` (part -> (x, y, z), x mirrored on the right), in Godot space."""
    out = {name: Matrix.Identity(4) for name in bones}
    for tag, s in (("L", 1.0), ("R", -1.0)):
        for chain in CHAINS.values():
            head = bones[chain[0] + "_" + tag][0].copy()
            for part in chain:
                name = part + "_" + tag
                rest_head, rest_tail, hint = bones[name]
                length = (rest_tail - rest_head).length
                rest_dir = (rest_tail - rest_head).normalized()
                d = directions.get(part)
                new_dir = V(d[0] * s, d[1], d[2]).normalized() if d else rest_dir
                rotation = along(new_dir, hint) @ along(rest_dir, hint).inverted()
                out[name] = Matrix.Translation(head) @ rotation.to_4x4() @ Matrix.Translation(-rest_head)
                head = head + new_dir * length
    if throat > 0.0:
        c = bones["throat"][0]
        scale = Matrix.Diagonal((1.0 + 0.55 * throat, 1.0 + 1.6 * throat, 1.0 + 0.45 * throat, 1.0))
        out["throat"] = Matrix.Translation(c + V(0, -0.012 * throat, 0)) @ scale @ Matrix.Translation(-c)
    return out


# --- Making surfaces ---

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def obj_mesh(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    bpy.data.objects.remove(obj, do_unlink=True)
    return mesh


def link(mesh, name="part"):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def apply_modifiers(mesh, mods):
    obj = link(mesh)
    for kind, settings in mods:
        m = obj.modifiers.new(kind, kind)
        for key, value in settings.items():
            setattr(m, key, value)
    return obj_mesh(obj)


def blobs(elements, resolution):
    """One fused surface from metaball ellipsoids: (centre, half extents, (pitch, yaw, roll) degrees)."""
    data = bpy.data.metaballs.new("blob")
    data.resolution = resolution
    data.render_resolution = resolution
    data.threshold = 0.6
    holder = bpy.data.objects.new("blob", data)
    bpy.context.scene.collection.objects.link(holder)
    for centre, extents, turn in elements:
        e = data.elements.new(type="ELLIPSOID")
        e.co = B(centre)
        e.radius = 1.0
        e.stiffness = 2.0
        # (Godot x, y, z extents are Blender x, z, y)
        e.size_x = extents[0] / META
        e.size_y = extents[2] / META
        e.size_z = extents[1] / META
        pitch, yaw, roll = (math.radians(a) for a in turn)
        # (pitch about Godot X is Blender X; yaw about Godot Y is Blender Z; roll about Godot Z is Blender -Y)
        q = Quaternion((0, 0, 1), yaw) @ Quaternion((1, 0, 0), pitch) @ Quaternion((0, -1, 0), roll)
        e.rotation = q
    bpy.context.view_layer.update()
    mesh = obj_mesh(holder)
    bpy.data.metaballs.remove(data)
    return apply_modifiers(mesh, [("SMOOTH", dict(factor=0.5, iterations=3))])


def thin(mesh, faces):
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    if tris <= faces:
        return mesh
    return apply_modifiers(mesh, [("DECIMATE", dict(ratio=faces / tris))])


def skinned(points, edges, radii, levels=2):
    """A Skin-modifier tube over a stick figure (Godot points), smoothed."""
    bm = bmesh.new()
    verts = [bm.verts.new(B(p)) for p in points]
    for a, b in edges:
        bm.edges.new((verts[a], verts[b]))
    mesh = bpy.data.meshes.new("skin")
    bm.to_mesh(mesh)
    bm.free()
    obj = link(mesh, "skin")
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    skin.use_smooth_shade = True
    for i, r in enumerate(radii):
        rr = r if isinstance(r, tuple) else (r, r)
        mesh.skin_vertices[0].data[i].radius = rr
        mesh.skin_vertices[0].data[i].use_root = i == 0
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return obj_mesh(obj)


def ellipsoid(centre, radii, segments=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        g = G(v.co)
        v.co = B(centre + V(g.x * radii[0], g.y * radii[1], g.z * radii[2]))
    mesh = bpy.data.meshes.new("ellipsoid")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def sheet(rows, thickness):
    """A thin two-sided sheet through rows of Godot points (a grid), made solid."""
    bm = bmesh.new()
    grid = [[bm.verts.new(B(p)) for p in row] for row in rows]
    for i in range(len(grid) - 1):
        for k in range(len(grid[0]) - 1):
            bm.faces.new((grid[i][k], grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]))
    mesh = bpy.data.meshes.new("sheet")
    bm.to_mesh(mesh)
    bm.free()
    return apply_modifiers(mesh, [("SOLIDIFY", dict(thickness=thickness, offset=0.0))])


def inside_of(tree, p):
    """Whether Godot point `p` is inside the closed surface in `tree` (Blender space)."""
    hit, normal, _, _ = tree.find_nearest(B(p))
    if hit is None:
        return False, 1.0
    gap = B(p) - hit
    return gap.dot(normal) < 0.0, gap.length


# --- Warts ---

def warts(mesh, count, rng, k, region):
    """Scatters `count` warts over the parts of `mesh` that `region`(p, n) allows
    (weight 0..1: how big there), pushes them out of the surface and returns them
    as a list of (centre, radius) for the colouring."""
    mesh.update()
    verts = [(G(v.co), G(v.normal)) for v in mesh.vertices]
    found = []
    tree = KDTree(max(count, 1))
    for attempt in range(count * 30):
        if len(found) >= count:
            break
        p, n = verts[rng.randrange(len(verts))]
        size = region(p, n)
        if size <= 0.0:
            continue
        r = (0.009 + 0.024 * size * rng.random() ** 0.7) * (1.0 if k["paratoid"] else 0.7)
        clash = False
        for (co, index, dist) in (tree.find_range(B(p), 0.06) if found else []):
            if dist < (r + found[index][1]) * 0.85:
                clash = True
                break
        if clash:
            continue
        tree.insert(B(p), len(found))
        found.append((p, r))
        tree.balance()
    if not found:
        return found
    # Push them out: a smooth round bump each, its height a little over half its radius.
    lookup = KDTree(len(found))
    for i, (p, r) in enumerate(found):
        lookup.insert(B(p), i)
    lookup.balance()
    for v in mesh.vertices:
        p = G(v.co)
        rise = 0.0
        for (co, index, dist) in lookup.find_range(v.co, 0.05):
            r = found[index][1]
            if dist < r:
                q = 1.0 - (dist / r) ** 2
                rise = max(rise, q * q * r * 0.62)
        if rise > 0.0:
            v.co = v.co + v.normal * rise
    mesh.update()
    return found


def wart_at(lookup, found, p):
    """How much of a wart `p` is on (1 at the top of one), 0 if none."""
    best = 0.0
    if lookup is None:
        return 0.0
    for (co, index, dist) in lookup.find_range(B(p), 0.05):
        r = found[index][1]
        if dist < r:
            best = max(best, 1.0 - dist / r)
    return best


# --- The frog ---

class Model:
    """The mesh as it is put together: one bmesh, with per-vertex colour, two UVs and bone weights."""

    def __init__(self, bone_names):
        self.bm = bmesh.new()
        self.uv0 = self.bm.loops.layers.uv.new("UVMap")
        self.uv1 = self.bm.loops.layers.uv.new("UV2")
        self.col = self.bm.verts.layers.float_color.new("Col")
        self.deform = self.bm.verts.layers.deform.verify()
        self.bones = bone_names
        self.vert_uv = []
        self.weights = []

    def add(self, mesh, info):
        """info(godot_position, godot_normal) -> (colour, uv0, uv1, {bone: weight})."""
        mesh.update()
        made = []
        for v in mesh.vertices:
            nv = self.bm.verts.new(v.co)
            colour, uv0, uv1, weights = info(G(v.co), G(v.normal).normalized())
            nv[self.col] = (colour[0], colour[1], colour[2], 1.0)
            total = sum(weights.values()) or 1.0
            kept = {b: w / total for b, w in weights.items() if w / total > 0.002}
            for bone, w in kept.items():
                nv[self.deform][self.bones.index(bone)] = w
            made.append(nv)
            self.vert_uv.append((uv0, uv1))
            self.weights.append(kept)
        base = len(self.vert_uv) - len(made)
        for poly in mesh.polygons:
            try:
                face = self.bm.faces.new([made[i] for i in poly.vertices])
            except ValueError:
                continue
            face.smooth = True
            for loop, i in zip(face.loops, poly.vertices):
                uv0, uv1 = self.vert_uv[base + i]
                loop[self.uv0].uv = (uv0[0], 1.0 - uv0[1])  # (glTF turns V over)
                loop[self.uv1].uv = (uv1[0], 1.0 - uv1[1])
        bpy.data.meshes.remove(mesh)


class Frog:
    def __init__(self, kind, low=False):
        self.kind = kind
        self.k = dict(KINDS[kind])
        self.low = low
        self.rng = random.Random(7 if kind == "toad" else 11)
        self.j, self.bones = skeleton(self.k)
        self.found = []
        self.lookup = None

    # Where the eyes are, and the eardrums.
    def eye_centre(self, s):
        k = self.k
        return V(0.13 * s * k["head"], 0.455, 0.31)

    def eye_look(self, s):
        return V(0.75 * s, 0.35, 0.55).normalized()

    def tympanum(self, s):
        k = self.k
        return V(0.228 * s * k["head"], 0.395, 0.185)

    # --- Colour ---

    def blotches(self, p, scale=7.0):
        return noise.noise(V(p.x * scale + 3.1, p.y * scale, p.z * scale - 1.7))

    def skin_colour(self, p, n, limb=None):
        k = self.k
        back = k["back"]
        # Big soft blotches, darker; some greener, some browner.
        b = self.blotches(p, 6.0)
        c = mix(back, k["blotch"], smooth(0.05, 0.35, b))
        hue = self.blotches(p + V(5.0, 2.0, 1.0), 3.0)
        c = mix(c, (c[0] * 1.15, c[1] * 0.92, c[2] * 0.8), smooth(-0.2, 0.4, hue))
        if limb is not None:
            # Dark bands across the legs.
            t = limb
            band = 0.5 + 0.5 * math.sin(t * math.tau * 1.6 + 0.6)
            c = mix(c, k["blotch"], smooth(0.62, 0.8, band) * 0.85 * smooth(-0.4, 0.2, n.y))
        # The pale belly and the undersides of everything.
        under = smooth(0.05, -0.55, n.y) * (1.0 if limb is not None else smooth(0.26, 0.16, p.y) * 0.6 + 0.4)
        if limb is None:
            under = max(under, smooth(0.2, 0.1, p.y))
        c = mix(c, k["belly"], under)
        # (speckles on the belly)
        if under > 0.3 and self.blotches(p, 30.0) > 0.4:
            c = mix(c, k["blotch"], 0.35 * under)
        return c

    def head_marks(self, p, n, c):
        k = self.k
        s = 1.0 if p.x >= 0 else -1.0
        # The eardrum: a dark disc with a paler rim.
        d = (p - self.tympanum(s)).length
        r = k["tympanum"]
        if d < r * 1.25 and abs(n.x) > 0.3:
            c = mix(c, mix(k["back"], k["belly"], 0.4), smooth(r * 1.25, r * 1.05, d))
            c = mix(c, (k["blotch"][0] * 0.8, k["blotch"][1] * 0.8, k["blotch"][2] * 0.8), smooth(r * 0.95, r * 0.8, d))
        # A dark mask from the nostril through the eye to the eardrum and on down the side.
        eye = self.eye_centre(s)
        nose = V(0.05 * s, 0.37, 0.53)
        t, dist = segment_t(p, nose, self.tympanum(s) + V(0.01 * s, -0.04, -0.06))
        if abs(n.x) > 0.25 and p.y < eye.y:
            c = mix(c, k["blotch"], smooth(0.04, 0.02, dist) * 0.7)
        # The thin pale line down the toad's back.
        if k["stripe"] and n.y > 0.4 and p.z < 0.3:
            c = mix(c, (0.26, 0.24, 0.09), smooth(0.014, 0.006, abs(p.x)) * 0.7)
        # The nostrils: two dark dots.
        for side in (1.0, -1.0):
            if (p - V(0.045 * side, 0.375, 0.535)).length < 0.011:
                c = (0.02, 0.018, 0.01)
        return c

    def wart_colour(self, p, c, n):
        w = wart_at(self.lookup, self.found, p)
        if w > 0.0:
            k = self.k
            tip = mix(k["ochre"], k["blotch"], 0.5 + 0.5 * self.blotches(p, 40.0))
            c = mix(c, tip, smooth(0.15, 0.7, w) * 0.85 * smooth(-0.3, 0.2, n.y))
        return c

    # --- Weights ---

    def limb_weights(self, p, names):
        """Weights for a point on a limb: by how near it is to each bone of it, blended at the joints."""
        dist = []
        for name in names:
            a, b, _ = self.bones[name]
            t, d = segment_t(p, a, b)
            dist.append((d, name, t))
        dist.sort()
        out = {dist[0][1]: 1.0}
        if len(dist) > 1:
            d2 = dist[1][0] - dist[0][0]
            out[dist[1][1]] = max(0.0, 1.0 - d2 / 0.035) * 0.5
        return out

    def body_weights(self, p):
        head = smooth(0.07, 0.2, p.z) * smooth(0.27, 0.33, p.y)
        return {"head": head, "body": 1.0 - head}

    # --- The parts ---

    def body_elements(self):
        k = self.k
        w = k["wide"]
        h = k["head"]
        e = [
            # The torso, sitting up at the front; the chest; the rump; the belly near the ground.
            (V(0, 0.27, -0.03), V(0.28 * w, 0.19, 0.22), (-8, 0, 0)),
            (V(0, 0.26, -0.24), V(0.2 * w, 0.18, 0.2), (-4, 0, 0)),
            (V(0, 0.29, 0.07), V(0.25 * w, 0.15, 0.17), (0, 0, 0)),
            (V(0, 0.235, -0.38), V(0.135 * w, 0.13, 0.1), (0, 0, 0)),
            (V(0, 0.15, -0.08), V(0.22 * w, 0.09, 0.24), (0, 0, 0)),
            # The broad flat head, and the short round snout.
            (V(0, 0.38, 0.27), V(0.24 * h, 0.08, 0.165), (6, 0, 0)),
            (V(0, 0.36, 0.43), V(0.15 * h, 0.055, 0.105), (10, 0, 0)),
            # The upper lip: a broad flat rim round the sides at the height of the mouth, over the jaw.
            (V(0, 0.335, 0.29), V(0.235 * h, 0.032, 0.17), (8, 0, 0)),
            # The brow between the eyes.
            (V(0, 0.415, 0.3), V(0.08 * h, 0.04, 0.09), (0, 0, 0)),
        ]
        for s in (1.0, -1.0):
            # The cheeks, out to the corners of the mouth.
            e.append((V(0.165 * s * h, 0.355, 0.21), V(0.095 * h, 0.065, 0.1), (0, 0, 0)))
            # The turrets the eyes sit in.
            c = self.eye_centre(s)
            e.append((c + V(0.0, -0.03, 0.0), V(k["eye"] * 1.05, k["eye"] * 0.8, k["eye"] * 1.1), (0, 0, 0)))
            # The upper eyelid: a crest of skin over the back and inside of the eye.
            e.append((c + V(-0.012 * s, 0.022, -0.022), V(k["eye"] * 0.8, k["eye"] * 0.42, k["eye"] * 0.75), (-15, 0, 0)))
            if k["paratoid"]:
                # The paratoid glands: long swellings from behind the eye back over the shoulder.
                e.append((V(0.165 * s, 0.415, 0.12), V(0.062, 0.05, 0.12), (6, 16 * s, 0)))
            else:
                # (a frog's back has ridges down either side instead)
                e.append((V(0.15 * s * w, 0.37, -0.08), V(0.035, 0.03, 0.28), (-8, 5 * s, 0)))
        return e

    def jaw_elements(self):
        h = self.k["head"]
        return [
            (V(0, 0.31, 0.32), V(0.2 * h, 0.034, 0.17), (8, 0, 0)),
            (V(0, 0.316, 0.44), V(0.11 * h, 0.028, 0.075), (10, 0, 0)),
            (V(0, 0.285, 0.22), V(0.185 * h, 0.055, 0.13), (0, 0, 0)),
        ]

    def body(self, model):
        k = self.k
        res = k["resolution"] * (1.4 if self.low else 1.0)
        upper = blobs(self.body_elements(), res)
        jaw = blobs(self.jaw_elements(), res)
        if k["warts"]:
            eyes = [self.eye_centre(1.0), self.eye_centre(-1.0)]

            def region(p, n):
                if n.y < -0.35 or p.y < 0.14:
                    return 0.0
                if min((p - e).length for e in eyes) < k["eye"] * 1.25:
                    return 0.0
                if p.z > 0.46:
                    return 0.0
                if p.z > 0.15 and p.y < 0.345:
                    return 0.0  # (not on the lips)
                big = 1.0 if p.z < 0.12 else 0.45
                return big * smooth(-0.35, 0.3, n.y)
            self.found = warts(upper, k["warts"], self.rng, k, region)
            self.lookup = KDTree(max(len(self.found), 1))
            for i, (p, r) in enumerate(self.found):
                self.lookup.insert(B(p), i)
            self.lookup.balance()
        upper = thin(upper, k["faces"] * (0.45 if self.low else 1.0))
        jaw = thin(jaw, k["faces"] * 0.16 * (0.45 if self.low else 1.0))
        jaw_tree = BVHTree.FromObject(link(jaw.copy(), "jaw_probe"), bpy.context.evaluated_depsgraph_get())
        upper_tree = BVHTree.FromObject(link(upper.copy(), "upper_probe"), bpy.context.evaluated_depsgraph_get())

        mouth = (0.3, 0.07, 0.065)

        def upper_info(p, n):
            inside, gap = inside_of(jaw_tree, p)
            if inside and p.z > 0.15:
                return mouth, (MOUTH, 0.0), (p.x, p.z), self.body_weights(p)
            c = self.skin_colour(p, n)
            c = self.head_marks(p, n, c)
            c = self.wart_colour(p, c, n)
            # (the lip: a dark line along the mouth)
            if gap < 0.008 and p.z > 0.12:
                c = mix(c, (0.04, 0.035, 0.02), 0.8)
            return c, (SKIN, p.y), (p.x, p.z), self.body_weights(p)

        def jaw_info(p, n):
            inside, gap = inside_of(upper_tree, p)
            w = self.throat_weights(p)
            if inside and p.z > 0.18:
                return mouth, (MOUTH, 0.0), (p.x, p.z), w
            c = mix(self.skin_colour(p, n), k["belly"], smooth(0.0, -0.5, n.y))
            c = self.head_marks(p, n, c)
            if gap < 0.008:
                c = mix(c, (0.04, 0.035, 0.02), 0.8)
            # (a throat a little paler and yellower, with grey speckles)
            if n.y < -0.3:
                c = mix(c, (0.38, 0.35, 0.21), 0.5)
                if self.blotches(p, 34.0) > 0.45:
                    c = mix(c, (0.2, 0.19, 0.14), 0.4)
            return c, (SKIN, p.y), (p.x, p.z), w
        model.add(upper, upper_info)
        model.add(jaw, jaw_info)
        for name in ("jaw_probe", "upper_probe"):
            obj = bpy.data.objects.get(name)
            if obj:
                bpy.data.objects.remove(obj, do_unlink=True)

    def throat_weights(self, p):
        c = self.bones["throat"][0]
        sac = smooth(0.0, 0.035, c.y - p.y + 0.02) * smooth(0.1, 0.18, p.z) * (1.0 - smooth(0.4, 0.47, p.z)) * (1.0 - smooth(0.15, 0.22, abs(p.x)))
        back = 1.0 - smooth(0.1, 0.2, p.z)
        jaw = max(0.0, 1.0 - sac) * (1.0 - back)
        return {"throat": sac, "jaw": jaw, "body": back * (1.0 - sac)}

    def eyes(self, model):
        k = self.k
        for s in (1.0, -1.0):
            c = self.eye_centre(s)
            look = self.eye_look(s)
            up = (V(0, 1, 0) - look * look.y).normalized()
            across = up.cross(look).normalized() * s
            r = k["eye"]
            mesh = ellipsoid(c, (r, r * 0.92, r), 18 if self.kind == "toad" and not self.low else (12 if self.kind == "toad" else 8), 12 if self.kind == "toad" and not self.low else (8 if self.kind == "toad" else 5))

            def info(p, n, c=c, look=look, up=up, across=across, r=r):
                d = (p - c) / r
                return (0.5, 0.4, 0.1), (EYE, d.dot(look)), (d.dot(across), d.dot(up)), {"head": 1.0}
            model.add(mesh, info)

    def limbs(self, model):
        k = self.k
        for tag, s in (("L", 1.0), ("R", -1.0)):
            j = self.j[tag]
            legs = k["leg"]
            # The hind leg: thigh, shin, the long ankle, the foot.
            # (the thigh swells in the middle, and so, less, does the shin)
            thigh_mid = j["hip"].lerp(j["knee"], 0.45) + V(0.0, 0.012, 0.0)
            shin_mid = j["knee"].lerp(j["ankle"], 0.35) + V(0.0, 0.006, 0.0)
            pts = [j["hip"] + V(-0.03 * s, 0.01, -0.01), j["hip"], thigh_mid, j["knee"], shin_mid, j["ankle"], j["ball"], j["ball"] + j["foot_dir"] * 0.03]
            radii = [0.08, 0.09, 0.098, 0.064, 0.06, 0.042, 0.03, 0.026]
            if self.kind == "frog":
                radii = [0.065, 0.072, 0.08, 0.05, 0.048, 0.032, 0.022, 0.018]
            mesh = skinned(pts, [(i, i + 1) for i in range(len(pts) - 1)], radii, 2 if not self.low else 1)
            leg_names = [n + "_" + tag for n in ("thigh", "shin", "tarsus", "foot")]
            if k["warts"]:
                def region(p, n):
                    return 0.55 * smooth(-0.1, 0.5, n.y) if p.y > 0.06 else 0.0
                more = warts(mesh, int(k["warts"] * 0.1), self.rng, k, region)
                self.found += more
                self.lookup = KDTree(max(len(self.found), 1))
                for i, (p, r) in enumerate(self.found):
                    self.lookup.insert(B(p), i)
                self.lookup.balance()
            mesh = thin(mesh, k["limb_faces"] * (0.45 if self.low else 1.0))
            total = sum((self.bones[n][1] - self.bones[n][0]).length for n in leg_names[:3])

            def leg_info(p, n, names=leg_names, total=total, tag=tag):
                w = self.limb_weights(p, names)
                # (how far down the leg, for the bands)
                along_leg = 0.0
                for name in names[:3]:
                    a, b, _ = self.bones[name]
                    t, d = segment_t(p, a, b)
                    if name in w and w[name] >= 0.5:
                        along_leg += t * (b - a).length
                        break
                    along_leg += (b - a).length
                c = self.skin_colour(p, n, along_leg / total * 3.0)
                c = self.wart_colour(p, c, n)
                return c, (SKIN, p.y), (p.x, p.z), w
            model.add(mesh, leg_info)

            # The toes, fanned out forward and outward from the ball of the foot, the fourth the longest.
            foot = j["foot_dir"]
            toe_lines = []
            for i, length in enumerate(k["toes"]):
                # (turned about the up axis: the first toe, innermost, turned in)
                spread = math.radians(-38 + i * 19) * s
                d = (Quaternion((0, 1, 0), spread) @ foot).normalized()
                base = j["ball"] + d * 0.015 + V(0, -0.006, 0)
                tip = base + d * length * legs ** 0.5 + V(0, -0.014, 0)
                mid = base.lerp(tip, 0.55) + V(0, 0.006, 0)
                tip.y = max(tip.y, 0.008)
                toe_lines.append((base, mid, tip))
                pts = [base - d * 0.02, base, mid, tip]
                rad = [0.022, 0.019, 0.014, 0.0105]
                if k["toe_bulb"] > 0.0:
                    pts.append(tip + d * 0.008)
                    rad = [0.017, 0.014, 0.0105, 0.009, 0.013]
                else:
                    pts.append(tip + d * 0.006)
                    rad.append(0.012)
                mesh = skinned(pts, [(a, a + 1) for a in range(len(pts) - 1)], rad, 1)
                if self.kind == "frog" or self.low:
                    mesh = thin(mesh, 14 if self.kind == "frog" else 60)
                foot_bone = "foot_" + tag

                def toe_info(p, n, foot_bone=foot_bone):
                    c = mix(self.skin_colour(p, n, 0.0), k["blotch"], 0.25)
                    return c, (SKIN, p.y), (p.x, p.z), {foot_bone: 1.0}
                model.add(mesh, toe_info)
            # The webbing between the toes, scalloped back between the tips.
            for i in range(len(toe_lines) - 1):
                a = toe_lines[i]
                b = toe_lines[i + 1]
                rows = []
                cells = 4 if self.kind == "toad" else 1
                for u in range(cells + 1):
                    row = []
                    uu = u / cells
                    for v in range(cells + 1):
                        vv = v / cells
                        reach = k["web"] * (1.0 - 0.45 * math.sin(math.pi * vv))
                        t = uu * reach
                        pa = a[0].lerp(a[2], t)
                        pb = b[0].lerp(b[2], t)
                        row.append(pa.lerp(pb, vv) + V(0, -0.002, 0))
                    rows.append(row)
                mesh = sheet(rows, 0.003)
                foot_bone = "foot_" + tag

                def web_info(p, n, foot_bone=foot_bone):
                    c = mix(self.skin_colour(p, n, 0.0), (0.35, 0.3, 0.2), 0.3)
                    return c, (SKIN, p.y), (p.x, p.z), {foot_bone: 1.0}
                model.add(mesh, web_info)

            # The foreleg: arm, forearm, the hand flat on the ground, fingers splayed and turned in.
            pts = [j["shoulder"] + V(-0.03 * s, 0.02, 0.0), j["shoulder"], j["elbow"], j["wrist"], j["wrist"] + j["hand_dir"] * 0.02]
            radii = [0.062, 0.06, 0.046, 0.032, 0.027] if self.kind == "toad" else [0.05, 0.046, 0.034, 0.024, 0.02]
            mesh = skinned(pts, [(i, i + 1) for i in range(len(pts) - 1)], radii, 2 if not self.low else 1)
            mesh = thin(mesh, k["limb_faces"] * 0.5 * (0.45 if self.low else 1.0))
            arm_names = [n + "_" + tag for n in ("arm", "forearm", "hand")]

            def arm_info(p, n, names=arm_names):
                c = self.skin_colour(p, n, 0.25)
                return c, (SKIN, p.y), (p.x, p.z), self.limb_weights(p, names)
            model.add(mesh, arm_info)
            hand = j["hand_dir"]
            for i, length in enumerate(k["fingers"]):
                spread = math.radians(-45 + i * 30) * s
                d = (Quaternion((0, 1, 0), spread) @ hand).normalized()
                base = j["wrist"] + d * 0.012
                tip = base + d * length * k["arm"] + V(0, -0.02, 0)
                tip.y = max(tip.y, 0.008)
                pts = [base - d * 0.015, base, base.lerp(tip, 0.5) + V(0, 0.004, 0), tip, tip + d * 0.007]
                rad = [0.02, 0.017, 0.014, 0.012, 0.015]
                mesh = skinned(pts, [(a, a + 1) for a in range(len(pts) - 1)], rad, 1)
                if self.kind == "frog" or self.low:
                    mesh = thin(mesh, 14 if self.kind == "frog" else 60)
                hand_bone = "hand_" + tag

                def finger_info(p, n, hand_bone=hand_bone):
                    c = mix(self.skin_colour(p, n, 0.0), k["blotch"], 0.2)
                    return c, (SKIN, p.y), (p.x, p.z), {hand_bone: 1.0}
                model.add(mesh, finger_info)

    # --- The tongue (the toad's): a shaft a unit long, and the sticky tip ---

    def tongue(self):
        made = []
        rings = []
        sides = 10
        for i in range(9):
            t = i / 8.0
            r = 0.03 * (1.0 - 0.25 * t) * (1.0 + 0.12 * math.sin(t * 9.0))
            ring = [V(math.cos(a) * r * 1.25, math.sin(a) * r * 0.75, t) for a in [math.tau * q / sides for q in range(sides)]]
            rings.append(ring)
        bm = bmesh.new()
        grid = [[bm.verts.new(B(p)) for p in ring] for ring in rings]
        for i in range(len(grid) - 1):
            for q in range(sides):
                bm.faces.new((grid[i][q], grid[i][(q + 1) % sides], grid[i + 1][(q + 1) % sides], grid[i + 1][q]))
        # (the root end closed; the faces turned to face out)
        bm.faces.new(list(reversed(grid[0])))
        bm.faces.new(grid[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new("tongue")
        bm.to_mesh(mesh)
        bm.free()
        made.append(("tongue", mesh))
        # The tip: a broad sticky pad, flattened and a little two-lobed, wet.
        tip = blobs([(V(0, 0, 0.0), V(0.075, 0.045, 0.06), (0, 0, 0)),
                     (V(0.04, 0.0, 0.03), V(0.045, 0.035, 0.04), (0, 0, 0)),
                     (V(-0.04, 0.0, 0.03), V(0.045, 0.035, 0.04), (0, 0, 0))], 0.01)
        tip = thin(tip, 400)
        made.append(("tongue_tip", tip))
        out = []
        for name, mesh in made:
            m = Model(BONE_ORDER)

            def info(p, n):
                c = mix((0.42, 0.12, 0.12), (0.55, 0.22, 0.2), smooth(-0.2, 0.8, n.y))
                return c, (TONGUE, 0.0), (p.x, p.z), {}
            m.add(mesh, info)
            me = bpy.data.meshes.new(name)
            m.bm.to_mesh(me)
            m.bm.free()
            obj = link(me, name)
            set_colour_attr(me)
            out.append(obj)
        return out

    # --- Putting it out ---

    def build(self, out_name):
        clear()
        model = Model(BONE_ORDER)
        self.body(model)
        self.eyes(model)
        self.limbs(model)
        mesh = bpy.data.meshes.new(out_name)
        body = link(mesh, out_name)
        for bone in BONE_ORDER:
            body.vertex_groups.new(name=bone)
        weights = model.weights
        model.bm.to_mesh(mesh)
        model.bm.free()
        mesh.update()
        set_colour_attr(mesh)
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]
        os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
        path = os.path.join(FOLDER, "models", out_name + ".glb")
        if self.kind == "toad":
            data = bpy.data.armatures.new("Armature")
            armature = bpy.data.objects.new("Armature", data)
            bpy.context.collection.objects.link(armature)
            bpy.context.view_layer.objects.active = armature
            bpy.ops.object.mode_set(mode="EDIT")
            for name in BONE_ORDER:
                head, tail, _ = self.bones[name]
                eb = data.edit_bones.new(name)
                eb.head = B(head)
                eb.tail = B(tail)
            bpy.ops.object.mode_set(mode="OBJECT")
            body.parent = armature
            body.modifiers.new("Armature", "ARMATURE").object = armature
            tongue = self.tongue()
            export(path, [armature, body] + tongue, skins=True, morphs=False)
        else:
            # The two poses, as shape keys: the leap, and the throat blown up.
            rest = [G(v.co) for v in mesh.vertices]
            body.shape_key_add(name="Basis")
            for key_name, pose in (("leap", posed(self.bones, LEAP)), ("croak", posed(self.bones, {}, 1.0))):
                key = body.shape_key_add(name=key_name)
                for i, p in enumerate(rest):
                    moved = Vector((0, 0, 0))
                    total = 0.0
                    for bone, w in weights[i].items():
                        moved += (pose[bone] @ p) * w
                        total += w
                    moved = moved / total if total > 0 else p
                    key.data[i].co = B(moved)
            export(path, [body], skins=False, morphs=True)
        print("BUILT %s verts=%d tris=%d" % (out_name, len(mesh.vertices), sum(len(p.vertices) - 2 for p in mesh.polygons)))
        if PREVIEW_DIR and not self.low:
            previews(out_name, self.kind)


def set_colour_attr(mesh):
    mesh.color_attributes.active_color = mesh.color_attributes["Col"]
    mesh.color_attributes.active_color_index = mesh.color_attributes.find("Col")
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")


def export(path, objects, skins, morphs):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=skins,
                   export_morph=morphs, export_materials="NONE", export_normals=True, export_texcoords=True, use_selection=True)
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)


def previews(name, kind):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.render.resolution_x, scene.render.resolution_y = 700, 700
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 60
    scene.collection.objects.link(camera)
    scene.camera = camera
    for obj in bpy.data.objects:
        if obj.name.startswith("tongue"):
            obj.hide_render = True
    centre = B(V(0, 0.25, 0.0))
    head = B(V(0, 0.38, 0.33))
    views = [("quarter", V(0.8, 0.45, 0.8), centre, 2.6), ("side", V(1.0, 0.12, 0.0), centre, 2.6),
             ("front", V(0.0, 0.2, 1.0), centre, 2.4), ("top", V(0.02, 1.0, 0.1), centre, 2.6),
             ("head", V(0.6, 0.3, 0.9), head, 1.1), ("back", V(-0.6, 0.6, -0.9), centre, 2.6)]
    for view, direction, target, far in views:
        offset = B(direction.normalized()) * far
        camera.location = target + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    only = os.environ.get("FROGS_ONLY", "")
    for kind, name, low in (("toad", "toad", False), ("toad", "toad_lo", True), ("frog", "frog", False)):
        if only and only != name:
            continue
        Frog(kind, low).build(name)
