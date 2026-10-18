"""Builds the gargoyle and exports it for Godot.

Run from the game's root (Blender 4.3):
    blender --background --python creatures/gargoyle/tools/build_gargoyle.py [-- <folder for preview renders>]

Writes creatures/gargoyle/models/gargoyle.glb and gargoyle_lo.glb, and
creatures/gargoyle/gargoyle_rest.gd (GargoyleRest: where every bone stands in
the model, for Gargoyle to pose it from). Given a folder, it renders previews
of the model into it.

WHAT IT IS. A carved-stone grotesque that is alive: hunched and heavily
muscled, a great hump of shoulders with the head thrust forward and low
between them; long arms with clawed four-fingered hands; crouched,
long-footed hind legs with taloned toes; a long tail ending in a barbed
spade; a ridge of spikes down its back; and two bat wings from its shoulder
blades that are hands, as a bat's are: an upper arm, a forearm, a clawed thumb
at the wrist, and four long fingers (digits 2 to 5, each a metacarpal and a
phalanx) with the skin stretched between them, in front of the forearm and
back from the fifth finger to the elbow, scalloped between the fingertips.

The face is a snarling beast's: a heavy scowling brow over deep-set eyes, a
broad short muzzle wrinkled up over the nose with flared nostrils, the upper
lip drawn back from two long fangs, a jutting underslung jaw with two tusks
standing up from it in front of the lip, pointed ears swept back, two ribbed
horns curving back from the brow, spikes on the cheeks and chin.

It is modelled as it stands at rest, in Godot space (metres, Y up, facing +Z,
+X its left): crouched on its hind legs, the body leaning forward, the arms
hanging in front, the mouth a little open, the wings held straight out
level. Everything but the wings, the teeth, the claws and the eyes is one
piece of stone: the parts are put together from a Skin-modifier stick figure
and many ellipsoids and tubes, joined into one surface by a voxel remesh, cut
(eye sockets, nostrils, the mouth), and weathered (worn lumps and pits). The
wings are their own surface: rods for the bones, a thin sheet of stone for the
skin.

WHAT IT CARRIES. As vertex colour, masks for the shader (GargoyleLook): R the
dark inside the mouth and nostrils, G the eyes, B the skin of the wings. UV is
where a point is in the model at rest (x, y) and UV2 (z, how far it lies in a
hollow, 0..1): the shader lays its stone on by where it is at rest, so the
texture stays put on it however it moves.

THE SKELETON. Every bone stands alone (none is the child of another): Gargoyle
works out each one's place in the model and sets it straight, as Baboon does.
Every vertex of the body is weighted by how near it is to the bones (by their
thickness), smoothed over the surface; the jaw by where it is in the mouth;
the wings' skin by where it lies between two fingers (carried by the forearm
and the fingers only: skin shared with the upper arm, which turns almost the
opposite way as the wing folds, would be torn across it).
"""

import math
import time
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
ARGS = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []) if not a.startswith("--")]
PREVIEW_DIR = ARGS[0] if ARGS else None

# How fine the voxel remesh is (metres), and how many triangles each model keeps.
VOXEL = 0.0065
BODY_TRIS = {"gargoyle": 30000, "gargoyle_lo": 8000}


def V(*p):
    if len(p) == 1:
        p = p[0]
    return Vector((float(p[0]), float(p[1]), float(p[2])))


def to_b(p):
    return Vector((p.x, -p.z, p.y))


def from_b(p):
    return Vector((p.x, p.z, -p.y))


def mirror(p):
    return Vector((-p.x, p.y, p.z))


def smooth(a, b, x):
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def dist_segment(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length, t


# --- The skeleton (the left side; the right is its mirror) ---

# The head is modelled in a space of its own ("head space": its neck joint at
# A_HEAD, facing +Z) and put on the body at the atlas, a little bigger.
A_HEAD = V(0, 1.665, 0.30)
ATLAS = V(0, 1.40, 0.46)
HEAD_SCALE = 1.08


def hp(*p):
    """A point given in head space, where it is on the body."""
    return ATLAS + (V(*p) - A_HEAD) * HEAD_SCALE


def head_space(p):
    return A_HEAD + (p - ATLAS) / HEAD_SCALE


def hr(*r):
    """Radii given in head space."""
    return tuple(x * HEAD_SCALE for x in r)


R = V(0.17, 1.40, 0.02)  # where a wing grows from the back
J = {
    "hips": V(0, 0.86, -0.24), "belly": V(0, 1.05, -0.07), "chest": V(0, 1.22, 0.13),
    "neck": V(0, 1.33, 0.32), "atlas": ATLAS, "head_tip": hp(0, 1.70, 0.68),
    "jaw_hinge": hp(0, 1.69, 0.40), "chin": hp(0, 1.585, 0.63),
    "shoulder": V(0.34, 1.26, 0.2), "elbow": V(0.47, 0.86, 0.10), "wrist": V(0.45, 0.43, 0.30),
    "knuckles": V(0.45, 0.26, 0.38), "finger_tips": V(0.45, 0.10, 0.41),
    "hip": V(0.21, 0.82, -0.27), "knee": V(0.33, 0.55, 0.08), "hock": V(0.31, 0.20, -0.16),
    "ball": V(0.31, 0.05, 0.03), "toe_tips": V(0.31, 0.0, 0.22),
    "w_root": R, "w_elbow": R + V(0.42, 0.04, -0.17), "w_wrist": R + V(1.09, 0.06, 0.09),
    "w_thumb": R + V(1.07, 0.09, 0.20), "w_thumb_tip": R + V(1.03, 0.07, 0.29),
    "w_k2": R + V(1.56, 0.06, 0.13), "w_t2": R + V(1.93, 0.05, 0.04),
    "w_k3": R + V(1.66, 0.06, 0.0), "w_t3": R + V(2.45, 0.03, -0.38),
    "w_k4": R + V(1.56, 0.06, -0.24), "w_t4": R + V(1.95, 0.01, -1.0),
    "w_k5": R + V(1.37, 0.06, -0.33), "w_t5": R + V(1.30, 0.0, -1.24),
}
TAIL = [V(0, 0.84, -0.45), V(0, 0.74, -0.68), V(0, 0.58, -0.88), V(0, 0.40, -1.03), V(0.04, 0.22, -1.17),
        V(0.08, 0.09, -1.34), V(0.10, 0.045, -1.55), V(0.08, 0.035, -1.76), V(0.03, 0.05, -1.95)]
TAIL_R = [0.14, 0.115, 0.095, 0.078, 0.063, 0.05, 0.039, 0.03, 0.022]
# The trunk's own axes: along the spine (up it), out of its front (the chest and belly) and to its left.
SPINE = (J["neck"] - J["belly"]).normalized()
FRONT = V(1, 0, 0).cross(SPINE).normalized()
BACK = -FRONT

# Each bone: name, head, tail, and how thick the body is round it (for weighting).
BONES = [
    ("hips", J["hips"], J["belly"], 0.24), ("belly", J["belly"], J["chest"], 0.25), ("chest", J["chest"], J["neck"], 0.3),
    ("neck", J["neck"], J["atlas"], 0.16), ("head", J["atlas"], J["head_tip"], 0.18), ("jaw", J["jaw_hinge"], J["chin"], 0.08),
]
for k in range(8):
    BONES.append(("tail_%d" % (k + 1), TAIL[k], TAIL[k + 1], TAIL_R[k] * 1.1))
SIDED = [
    ("upperarm", "shoulder", "elbow", 0.12), ("forearm", "elbow", "wrist", 0.095), ("hand", "wrist", "knuckles", 0.07),
    ("fingers", "knuckles", "finger_tips", 0.04),
    ("thigh", "hip", "knee", 0.15), ("shin", "knee", "hock", 0.09), ("foot", "hock", "ball", 0.055), ("toes", "ball", "toe_tips", 0.04),
    ("wing_arm", "w_root", "w_elbow", 0.07), ("wing_fore", "w_elbow", "w_wrist", 0.05), ("wing_hand", "w_wrist", "w_thumb", 0.045),
    ("wing_d2a", "w_wrist", "w_k2", 0.03), ("wing_d2b", "w_k2", "w_t2", 0.02),
    ("wing_d3a", "w_wrist", "w_k3", 0.03), ("wing_d3b", "w_k3", "w_t3", 0.02),
    ("wing_d4a", "w_wrist", "w_k4", 0.03), ("wing_d4b", "w_k4", "w_t4", 0.02),
    ("wing_d5a", "w_wrist", "w_k5", 0.03), ("wing_d5b", "w_k5", "w_t5", 0.02),
]
for name, a, b, r in SIDED:
    BONES.append((name + "_l", J[a], J[b], r))
    BONES.append((name + "_r", mirror(J[a]), mirror(J[b]), r))
BONE_NAMES = [b[0] for b in BONES]
SEG = {b[0]: (b[1], b[2], b[3]) for b in BONES}
WING_BONES = [n for n in BONE_NAMES if n.startswith("wing_")]
BODY_BONES = [n for n in BONE_NAMES if not n.startswith("wing_") and n != "jaw"]


# --- Shapes (all built in Godot space and turned to Blender's as they are made) ---

def mesh_from_bm(bm, name="part"):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def obj_from_mesh(mesh, name="part"):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def evaluated(obj, keep=False):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    if not keep:
        bpy.data.objects.remove(obj)
    return mesh


def basis_along(axis, hint=None):
    """A basis (columns x, y, z) whose y is `axis`."""
    y = axis.normalized()
    hint = hint or (V(0, 0, 1) if abs(y.z) < 0.9 else V(1, 0, 0))
    x = y.cross(hint)
    if x.length < 1e-6:
        x = y.cross(V(1, 0, 0))
    x.normalize()
    z = x.cross(y).normalized()
    return Matrix((x, y, z)).transposed()


def ellipsoid(bm, centre, radii, axis=None, hint=None, segments=20, rings=12):
    """Adds an ellipsoid to bm: radii (x, y, z), its y along `axis` if given (x then across, z
    the third way)."""
    basis = basis_along(axis, hint) if axis is not None else Matrix.Identity(3)
    made = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in made["verts"]:
        local = V(v.co.x * radii[0], v.co.z * radii[1], v.co.y * radii[2])
        v.co = to_b(centre + basis @ local)


def frames_along(points):
    """A frame (tangent, side, up) at each point of a path, carried along it without twisting."""
    tangents = []
    for i in range(len(points)):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, len(points) - 1)]
        tangents.append((b - a).normalized())
    t0 = tangents[0]
    up = V(0, 1, 0) if abs(t0.y) < 0.9 else V(0, 0, 1)
    side = t0.cross(up).normalized()
    frames = []
    for t in tangents:
        side = (side - t * side.dot(t))
        if side.length < 1e-6:
            side = t.cross(V(0, 1, 0))
        side.normalize()
        frames.append((t, side, t.cross(side).normalized() * -1.0))
    return frames


def tube(bm, points, radius, sides=12, flat=1.0, cup=0.0, roll=None, cap_start=True, cap_end=True):
    """Adds a tube through `points` (Godot), each ring `radius(t)` across (t 0..1 along it) and `flat`
    times that deep; `cup` hollows one face; `roll(t)` turns the ring about the path (radians)."""
    frames = frames_along(points)
    lengths = [0.0]
    for i in range(1, len(points)):
        lengths.append(lengths[-1] + (points[i] - points[i - 1]).length)
    total = lengths[-1] or 1.0
    grid = []
    for i, p in enumerate(points):
        t = lengths[i] / total
        tangent, side, up = frames[i]
        if roll is not None:
            a = roll(t)
            side, up = side * math.cos(a) + up * math.sin(a), up * math.cos(a) - side * math.sin(a)
        r = radius(t)
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            x = math.cos(a) * r
            y = math.sin(a) * r * flat
            if cup > 0.0 and math.sin(a) > 0:
                y -= cup * r * flat * math.sin(a) ** 2
            ring.append(bm.verts.new(to_b(p + side * x + up * y)))
        grid.append(ring)
    for i in range(len(grid) - 1):
        for k in range(sides):
            bm.faces.new((grid[i][k], grid[i][(k + 1) % sides], grid[i + 1][(k + 1) % sides], grid[i + 1][k]))
    if cap_end:
        tip = bm.verts.new(to_b(points[-1] + frames[-1][0] * 0.0005))
        for k in range(sides):
            bm.faces.new((grid[-1][k], grid[-1][(k + 1) % sides], tip))
    if cap_start:
        tip = bm.verts.new(to_b(points[0] - frames[0][0] * 0.0005))
        for k in range(sides):
            bm.faces.new((grid[0][(k + 1) % sides], grid[0][k], tip))


def dense(path, steps=6):
    out = []
    for i in range(len(path) - 1):
        for k in range(steps):
            out.append(lerp(path[i], path[i + 1], k / steps))
    out.append(path[-1])
    return out


def arc(a, b, bend, count=8, bulge_dir=None):
    """Points from a to b bowed out by `bend` (metres) towards `bulge_dir`."""
    d = b - a
    bulge_dir = bulge_dir or V(0, 1, 0)
    out = (bulge_dir - d.normalized() * bulge_dir.dot(d.normalized())).normalized()
    return [a + d * (i / (count - 1)) + out * bend * math.sin(math.pi * i / (count - 1)) for i in range(count)]


def claw(bm, base, direction, length, radius, curl, curl_dir, sides=8):
    """A hooked claw from `base` along `direction`, curling towards `curl_dir`."""
    direction = direction.normalized()
    curl_dir = (curl_dir - direction * curl_dir.dot(direction)).normalized()
    pts = []
    for i in range(7):
        t = i / 6
        pts.append(base + direction * length * t + curl_dir * curl * length * t * t)
    tube(bm, pts, lambda t: radius * (1.0 - t) ** 0.9 + 0.0008, sides=sides, flat=0.8)


def cone(bm, base, tip, radius, sides=10):
    tube(bm, [base, base.lerp(tip, 0.5), tip], lambda t: radius * (1.0 - t) + 0.0006, sides=sides)


def sides():
    """The left side as it is, and the right as its mirror."""
    return ((lambda p: p), mirror)


# --- The body (one piece of stone) ---

def skin_figure(points, radii, edges, root):
    """A Skin-modifier surface over a stick figure (Godot points), smoothed."""
    bm = bmesh.new()
    verts = [bm.verts.new(to_b(p)) for p in points]
    for a, b in edges:
        bm.edges.new((verts[a], verts[b]))
    mesh = mesh_from_bm(bm, "figure")
    obj = obj_from_mesh(mesh, "figure")
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    for i, r in enumerate(radii):
        mesh.skin_vertices[0].data[i].radius = (r, r)
        mesh.skin_vertices[0].data[i].use_root = i == root
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 2
    return evaluated(obj)


class Figure:
    def __init__(self):
        self.points, self.radii, self.edges = [], [], []

    def add(self, p, r, link=None):
        self.points.append(p)
        self.radii.append(r)
        if link is not None:
            self.edges.append((link, len(self.points) - 1))
        return len(self.points) - 1

    def made(self, root=0):
        return skin_figure(self.points, self.radii, self.edges, root)


def stick_figure():
    """The Skin-modifier figures of the trunk, tail and neck, and of each arm and leg (the left
    made, the right its mirror, so that the two are alike), as one bmesh (Blender axes)."""
    trunk = Figure()
    last = None
    for k in range(len(TAIL) - 1, -1, -1):
        last = trunk.add(TAIL[k], TAIL_R[k], last)
    hips = trunk.add(J["hips"], 0.21, last)
    belly = trunk.add(J["belly"], 0.22, hips)
    chest = trunk.add(J["chest"], 0.27, belly)
    neck = trunk.add(J["neck"], 0.17, chest)
    atlas = trunk.add(J["atlas"], 0.12, neck)
    trunk.add(hp(0, 1.72, 0.36), 0.1, atlas)
    # Arm, from a collarbone; a big hand of three fingers and a thumb.
    arm = Figure()
    clav = arm.add(J["chest"] + V(0.1, 0.02, 0.0), 0.14)
    clav2 = arm.add(lerp(J["chest"], J["shoulder"], 0.55) + V(0, 0.04, 0.02), 0.14, clav)
    sh = arm.add(J["shoulder"], 0.13, clav2)
    u = arm.add(lerp(J["shoulder"], J["elbow"], 0.5), 0.1, sh)
    el = arm.add(J["elbow"], 0.075, u)
    f = arm.add(lerp(J["elbow"], J["wrist"], 0.38), 0.08, el)
    wr = arm.add(J["wrist"], 0.055, f)
    arm.add(lerp(J["wrist"], J["knuckles"], 0.55) + V(0, 0, 0.006), 0.064, wr)
    digits = bmesh.new()
    for dx in (-0.056, 0.0, 0.056):
        base = J["knuckles"] + V(dx, 0, 0)
        tube(digits, dense([lerp(J["knuckles"], base, 0.6) + V(0, 0.03, -0.02), base, base + V(dx * 0.15, -0.085, 0.04), base + V(dx * 0.2, -0.15, 0.035)], 3),
             lambda t: 0.034 - 0.01 * t + 0.004 * math.sin(math.pi * min(t * 2.0, 1.0)), sides=12)
    tube(digits, dense([J["wrist"] + V(-0.03, -0.04, 0.04), J["wrist"] + V(-0.06, -0.08, 0.09), J["wrist"] + V(-0.075, -0.13, 0.15), J["wrist"] + V(-0.075, -0.185, 0.16)], 3),
         lambda t: 0.036 - 0.012 * t, sides=12)
    ellipsoid(digits, lerp(J["wrist"], J["knuckles"], 0.6), (0.075, 0.08, 0.045), J["knuckles"] - J["wrist"])
    # Leg, and a foot of three taloned toes.
    leg = Figure()
    h0 = leg.add(J["hips"] + V(0.08, 0.0, -0.02), 0.17)
    hp_ = leg.add(J["hip"], 0.17, h0)
    t1 = leg.add(lerp(J["hip"], J["knee"], 0.5), 0.14, hp_)
    kn = leg.add(J["knee"], 0.085, t1)
    s1 = leg.add(lerp(J["knee"], J["hock"], 0.42), 0.08, kn)
    hk = leg.add(J["hock"], 0.055, s1)
    mt = leg.add(lerp(J["hock"], J["ball"], 0.5), 0.048, hk)
    leg.add(J["ball"], 0.056, mt)
    for dx in (-0.07, 0.0, 0.07):
        base = J["ball"] + V(dx, 0.0, 0.035)
        tube(digits, dense([J["ball"] + V(dx * 0.4, 0.01, -0.02), base, base + V(dx * 0.35, -0.012, 0.09), base + V(dx * 0.5, -0.025, 0.15)], 3),
             lambda t: 0.04 - 0.014 * t + 0.004 * math.sin(math.pi * min(t * 2.0, 1.0)), sides=12)
    ellipsoid(digits, J["ball"] + V(0, 0.01, 0.0), (0.09, 0.05, 0.07))
    out = bmesh.new()
    out.from_mesh(trunk.made(hips))
    for limb in (arm.made(), leg.made(), mesh_from_bm(digits, "digits")):
        out.from_mesh(limb)
        other = bmesh.new()
        other.from_mesh(limb)
        bmesh.ops.scale(other, vec=Vector((-1, 1, 1)), verts=other.verts)
        bmesh.ops.reverse_faces(other, faces=other.faces)
        out.from_mesh(mesh_from_bm(other, "mirrored"))
    return out


def muscles(bm):
    """The masses laid over the stick figure: a great hump of shoulders, chest, belly, limbs."""
    C, B, P, N = J["chest"], J["belly"], J["hips"], J["neck"]
    ellipsoid(bm, lerp(B, N, 0.42) + FRONT * 0.02, (0.29, 0.3, 0.25), SPINE)       # rib cage
    ellipsoid(bm, lerp(P, C, 0.42) + FRONT * 0.03, (0.21, 0.22, 0.2), SPINE)        # belly
    ellipsoid(bm, C + BACK * 0.13 + SPINE * 0.06, (0.25, 0.2, 0.16), SPINE)         # the hump
    ellipsoid(bm, N + BACK * 0.07, (0.15, 0.14, 0.12), SPINE)                        # the nape
    for m in sides():
        S, E, W = J["shoulder"], J["elbow"], J["wrist"]
        ellipsoid(bm, m(lerp(V(0.05, 1.42, 0.3), S, 0.5) + V(0, 0.04, -0.03)), (0.1, 0.21, 0.13), m(S - V(0.05, 1.42, 0.3)))  # trapezius
        ellipsoid(bm, m(C + FRONT * 0.15 + V(0.14, 0.02, 0.0) + SPINE * 0.13), (0.13, 0.13, 0.06), m(V(0.7, 0.5, 0.4)))     # pectoral
        ellipsoid(bm, m(C + V(0.2, 0, 0) + BACK * 0.03 - SPINE * 0.05), (0.09, 0.2, 0.15), SPINE)                            # lats
        ellipsoid(bm, m(R + V(-0.04, -0.02, -0.01)), (0.075, 0.16, 0.07), m(V(0.6, 0.6, -0.2)))                               # the wing's root
        ellipsoid(bm, m(S + (E - S).normalized() * 0.05 + V(0.01, 0.02, 0.0)), (0.13, 0.17, 0.13), m(E - S))                # deltoid
        for k in range(3):
            ellipsoid(bm, m(lerp(P, C, 0.25 + 0.2 * k) + FRONT * 0.19 + V(0.055, 0, 0)), (0.05, 0.045, 0.028), SPINE)       # belly muscles
        arm = (E - S).normalized()
        ellipsoid(bm, m(lerp(S, E, 0.5) + V(0, 0, 0.04)), (0.08, 0.16, 0.085), m(arm))                                        # biceps
        ellipsoid(bm, m(lerp(S, E, 0.42) + V(0.012, 0, -0.045)), (0.085, 0.18, 0.08), m(arm))                                 # triceps
        fore = (W - E).normalized()
        ellipsoid(bm, m(lerp(E, W, 0.27) + V(0.012, 0, 0.0)), (0.092, 0.18, 0.078), m(fore))                                  # forearm
        H, K, Hk = J["hip"], J["knee"], J["hock"]
        thigh = (K - H).normalized()
        ellipsoid(bm, m(H + V(-0.05, 0.05, -0.06)), (0.14, 0.14, 0.13))                                                         # haunch
        ellipsoid(bm, m(lerp(H, K, 0.52) + V(0.01, 0.02, 0.02)), (0.13, 0.25, 0.125), m(thigh))                               # thigh, front
        ellipsoid(bm, m(lerp(H, K, 0.4) + V(0.0, -0.06, -0.03)), (0.11, 0.22, 0.1), m(thigh))                                 # thigh, back
        shin = (Hk - K).normalized()
        behind = V(0, 0, -1) - shin * shin.z
        behind.normalize()
        ellipsoid(bm, m(lerp(K, Hk, 0.3) + behind * 0.035), (0.075, 0.16, 0.08), m(shin))                                     # calf
        ellipsoid(bm, m(K + V(0.0, 0.01, 0.05)), (0.05, 0.045, 0.035))                                                          # knee
        ellipsoid(bm, m(lerp(N, J["atlas"], 0.4) + V(0.07, -0.03, 0.03)), (0.05, 0.13, 0.05), m(J["atlas"] - N + V(0.1, -0.05, 0)))  # neck cords


def head(bm, sharp):
    """The skull and face, in head space (everything but what is cut out of it, the teeth and the
    eyes). Fine things (horns, ears, spikes) go to `sharp`, which is smoothed less."""
    E = ellipsoid
    E(bm, hp(0, 1.785, 0.37), hr(0.145, 0.13, 0.165))               # cranium
    E(bm, hp(0, 1.75, 0.29), hr(0.125, 0.12, 0.12))                 # back of the skull
    E(bm, hp(0, 1.705, 0.42), hr(0.135, 0.085, 0.12))               # cheeks and jowls
    E(bm, hp(0, 1.815, 0.49), hr(0.11, 0.05, 0.06))                 # the forehead behind the brow
    for m in sides():
        E(bm, m(hp(0.1, 1.728, 0.47)), hr(0.03, 0.075, 0.045), m(V(0.25, -0.1, 1.0)))   # cheekbone
        E(bm, m(hp(0.078, 1.668, 0.545)), hr(0.032, 0.028, 0.04))                         # corner of the lip
        # The brow: a heavy boss over each eye, low at the middle in a scowl and jutting.
        E(bm, m(hp(0.058, 1.806, 0.538)), hr(0.034, 0.068, 0.042), m(V(1.0, 0.42, -0.35)))   # the boss over the eye
        E(bm, m(hp(0.118, 1.818, 0.49)), hr(0.03, 0.05, 0.038), m(V(0.6, 0.2, -1.0)))        # running back to the temple
        # The snarl's folds, from the nostril round to the corner of the mouth.
        tube(bm, [m(p) for p in arc(hp(0.04, 1.745, 0.63), hp(0.088, 1.668, 0.54), 0.018, 8, V(1, 0.2, 0.6))],
             lambda t: (0.011 + 0.006 * math.sin(math.pi * t)) * HEAD_SCALE, sides=10)
        E(bm, m(hp(0.072, 1.722, 0.53)), hr(0.032, 0.022, 0.03))                              # the bag under the eye
        # Furrows up the forehead from the middle of the scowl.
        tube(bm, [m(p) for p in arc(hp(0.012, 1.81, 0.55), hp(0.03, 1.88, 0.5), 0.01, 6, V(0, 0, 1))], lambda t: 0.011 * (1 - t) + 0.004, sides=8)
        # Spikes on the cheeks, swept back.
        for k, (y, z, ln) in enumerate(((1.725, 0.43, 0.1), (1.69, 0.41, 0.11), (1.655, 0.4, 0.08))):
            base = hp(0.125 - 0.01 * k, y, z)
            cone(sharp, m(base), m(base + V(0.06, -0.015 - 0.012 * k, -0.06) * (ln / 0.085)), 0.027)
    # The muzzle: short and broad, its bridge wrinkled up in a snarl, a broad flat nose at its end.
    E(bm, hp(0, 1.712, 0.575), hr(0.1, 0.062, 0.088))
    E(bm, hp(0, 1.758, 0.57), hr(0.035, 0.07, 0.05), V(0, -0.35, 1.0))
    E(bm, hp(0, 1.73, 0.638), hr(0.05, 0.03, 0.028), V(0, -0.5, 1.0))                # the nose, turned down
    for m in sides():
        E(bm, m(hp(0.04, 1.722, 0.632)), hr(0.022, 0.024, 0.026))                      # nostril wing
    for k in range(4):
        z = 0.55 + 0.024 * k
        y = 1.792 - (z - 0.55) * 0.6
        w = 0.06 - 0.006 * k
        tube(sharp, arc(hp(-w, y - 0.026, z - 0.006), hp(w, y - 0.026, z - 0.006), 0.028 - 0.002 * k, 9, V(0, 1, 0.3)),
             lambda t: 0.0085 * (0.4 + 0.6 * math.sin(math.pi * t)) * HEAD_SCALE, sides=8)
    # The upper lip, drawn back.
    E(bm, hp(0, 1.686, 0.6), hr(0.088, 0.028, 0.058))
    # The jaw: heavy, underslung, a little open; a chin that juts.
    for m in sides():
        a, b = hp(0.1, 1.685, 0.41), hp(0.052, 1.6, 0.6)
        E(bm, m(lerp(a, b, 0.5)), hr(0.042, 0.13, 0.038), m(b - a))
    E(bm, hp(0, 1.588, 0.612), hr(0.074, 0.04, 0.05))
    E(bm, hp(0, 1.614, 0.6), hr(0.08, 0.022, 0.05))                 # lower lip
    E(bm, hp(0, 1.62, 0.49), hr(0.088, 0.048, 0.1))                 # under the jaw
    cone(sharp, hp(0, 1.578, 0.615), hp(0, 1.50, 0.645), 0.026)      # a spike of beard
    for m in sides():
        s = 1.0 if m(V(1, 0, 0)).x > 0 else -1.0
        # Ears: big and pointed, swept back and out, their hollow facing forward and out.
        ear = [hp(0.12, 1.8, 0.36), hp(0.165, 1.835, 0.34), hp(0.215, 1.88, 0.305), hp(0.265, 1.925, 0.265), hp(0.31, 1.965, 0.23), hp(0.345, 1.99, 0.21)]
        tube(sharp, [m(p) for p in dense(ear, 2)], lambda t: (0.068 * (1.0 - t ** 1.5) * (0.7 + 0.45 * math.sin(math.pi * min(t * 1.5, 1.0))) + 0.003) * HEAD_SCALE,
             sides=14, flat=0.32, cup=0.6, roll=lambda t, s=s: (1.35 + 0.2 * t) * s)
        # Horns: from the top of the brow, up and then sweeping back over the skull, ribbed.
        horn = [hp(0.068, 1.86, 0.475), hp(0.082, 1.94, 0.47), hp(0.105, 2.0, 0.43), hp(0.135, 2.035, 0.36), hp(0.165, 2.035, 0.28),
                hp(0.195, 2.0, 0.205), hp(0.225, 1.955, 0.155), hp(0.26, 1.925, 0.13)]
        tube(sharp, [m(p) for p in dense(horn, 6)],
             lambda t: (0.042 * (1.0 - t) ** 0.9 + 0.003) * (1.0 + 0.1 * max(0.0, math.sin(t * 52.0)) * (1.0 - t)) * HEAD_SCALE,
             sides=12, flat=0.9)


def back_spikes(bm):
    """A ridge of spikes down the back, from the nape to half way down the tail."""
    path = [J["atlas"] + BACK * 0.1 - SPINE * 0.04, J["neck"] + BACK * 0.18, J["chest"] + BACK * 0.3 + SPINE * 0.04,
            J["chest"] + BACK * 0.26 - SPINE * 0.12, J["belly"] + BACK * 0.22, J["hips"] + BACK * 0.18]
    path += [TAIL[k] + V(0, TAIL_R[k] * 0.85, 0) for k in range(5)]
    pts = dense(path, 3)
    for i, p in enumerate(pts):
        t = i / (len(pts) - 1)
        along = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        up = V(0, 1, 0) - along * along.y
        up.normalize()
        size = 0.085 * (1.0 - 0.6 * t) * (0.8 + 0.2 * math.sin(i * 2.3))
        cone(bm, p - up * 0.03, p + up * size - along * size * 0.7, size * 0.42, sides=8)


def limb_spurs(bm):
    for m in sides():
        cone(bm, m(J["elbow"] + V(0.0, 0.0, -0.035)), m(J["elbow"] + V(0.02, -0.02, -0.17)), 0.035)
        cone(bm, m(J["hock"] + V(0.0, 0.0, -0.025)), m(J["hock"] + V(0.01, 0.025, -0.13)), 0.026)


def tail_spade(bm):
    """The barbed spade at the end of the tail: flat, pointed, its barbs swept forward."""
    tip, before = TAIL[-1], TAIL[-2]
    along = (tip - before).normalized()
    side = along.cross(V(0, 1, 0)).normalized()
    pts = [tip - along * 0.03 + along * 0.28 * (i / 12) for i in range(13)]
    tube(bm, pts, lambda t: 0.014 + (0.085 * math.sin(0.5 * math.pi * t / 0.45) if t < 0.45 else 0.085 * (1.0 - (t - 0.45) / 0.55)),
         sides=14, flat=0.22)
    for s in (1.0, -1.0):
        base = tip + along * 0.07 + side * s * 0.065
        cone(bm, base, base - along * 0.11 + side * s * 0.05, 0.02, sides=6)


def cutters():
    """What is cut out of the head: the eye sockets, the nostrils, the mouth."""
    bm = bmesh.new()
    for m in sides():
        ellipsoid(bm, m(hp(0.06, 1.757, 0.535)), hr(0.031, 0.025, 0.036))
        ellipsoid(bm, m(hp(0.03, 1.712, 0.652)), hr(0.009, 0.018, 0.013), V(0.2, -0.6, 1))
    ellipsoid(bm, hp(0, 1.646, 0.56), hr(0.024, 0.11, 0.072), V(0, 0.15, 1.0))
    return mesh_from_bm(bm, "cutters")


# --- Teeth, claws, eyes (sharp: not remeshed) ---

def teeth_and_claws():
    """Returns [(mesh, bones of a vertex (callable on a Godot point), part)]."""
    pieces = []
    upper, lower, claws, eyes = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    k = HEAD_SCALE
    for m in sides():
        # Fangs from the upper jaw, tusks from the lower, jutting up in front of the lip.
        claw(upper, m(hp(0.058, 1.678, 0.612)), m(V(0.0, -1.0, 0.1)), 0.085 * k, 0.017 * k, 0.25, m(V(0, 0, -1)))
        claw(lower, m(hp(0.06, 1.608, 0.632)), m(V(0.12, 1.0, 0.05)), 0.1 * k, 0.019 * k, 0.3, m(V(0.3, 0, -1)))
        for x in (0.013, 0.034):
            cone(upper, m(hp(x, 1.672, 0.647 - x * 0.3)), m(hp(x, 1.642, 0.65 - x * 0.3)), 0.008, sides=6)
            cone(lower, m(hp(x * 0.9, 1.618, 0.647 - x * 0.3)), m(hp(x * 0.9, 1.64, 0.648 - x * 0.3)), 0.007, sides=6)
        for z in (0.56, 0.52):
            cone(upper, m(hp(0.07 - (0.6 - z) * 0.2, 1.664, z)), m(hp(0.07 - (0.6 - z) * 0.2, 1.64, z)), 0.009, sides=6)
            cone(lower, m(hp(0.062 - (0.6 - z) * 0.2, 1.628, z)), m(hp(0.062 - (0.6 - z) * 0.2, 1.65, z)), 0.009, sides=6)
        # Eyes, deep in their sockets under the brow.
        ellipsoid(eyes, m(hp(0.06, 1.757, 0.508)), hr(0.017, 0.015, 0.014), segments=12, rings=8)
        # Claws: fingers, thumb, toes.
        for dx in (-0.056, 0.0, 0.056):
            tip = J["knuckles"] + V(dx * 1.2, -0.15, 0.035)
            claw(claws, m(tip + V(0, -0.012, 0.014)), m(V(0, -0.6, 0.6)), 0.085, 0.023, 0.5, m(V(0, -1, -0.6)))
        claw(claws, m(J["wrist"] + V(-0.075, -0.195, 0.17)), m(V(0, -0.5, 0.6)), 0.07, 0.021, 0.5, m(V(0, -1, -0.5)))
        for dx in (-0.07, 0.0, 0.07):
            tip = J["ball"] + V(dx * 1.5, -0.025, 0.185)
            claw(claws, m(tip), m(V(dx * 1.5, -0.25, 1.0)), 0.09, 0.023, 0.55, m(V(0, -1, 0)))
    pieces.append((mesh_from_bm(upper, "upper"), lambda p: {"head": 1.0}, "stone"))
    pieces.append((mesh_from_bm(lower, "lower"), lambda p: {"jaw": 1.0}, "stone"))
    pieces.append((mesh_from_bm(eyes, "eyes"), lambda p: {"head": 1.0}, "eye"))

    def claw_bone(p):
        side = "_l" if p.x >= 0 else "_r"
        q = V(abs(p.x), p.y, p.z)
        return {("fingers" if (q - J["knuckles"]).length < (q - J["ball"]).length else "toes") + side: 1.0}
    pieces.append((mesh_from_bm(claws, "claws"), claw_bone, "stone"))
    return pieces


# --- The wings ---

def polyline_at(points, t):
    lengths = [0.0]
    for i in range(1, len(points)):
        lengths.append(lengths[-1] + (points[i] - points[i - 1]).length)
    goal = t * lengths[-1]
    for i in range(1, len(points)):
        if goal <= lengths[i] or i == len(points) - 1:
            span = lengths[i] - lengths[i - 1]
            k = 0.0 if span <= 0 else (goal - lengths[i - 1]) / span
            return lerp(points[i - 1], points[i], max(0.0, min(1.0, k))), i - 1, k
    return points[-1], len(points) - 2, 1.0


def wing_rods(levels=2):
    """The bones of the left wing, as a Skin-modifier figure: arm, thumb and four fingers."""
    points, radii, edges = [], [], []

    def add(p, r, link=None):
        points.append(p)
        radii.append(r)
        if link is not None:
            edges.append((link, len(points) - 1))
        return len(points) - 1

    root = add(J["w_root"] + V(-0.04, 0, 0), 0.07)
    a1 = add(lerp(J["w_root"], J["w_elbow"], 0.5), 0.058, root)
    el = add(J["w_elbow"], 0.056, a1)
    f1 = add(lerp(J["w_elbow"], J["w_wrist"], 0.5), 0.043, el)
    wr = add(J["w_wrist"], 0.05, f1)
    th = add(J["w_thumb"], 0.03, wr)
    add(J["w_thumb_tip"], 0.022, th)
    for k in (2, 3, 4, 5):
        K, T = J["w_k%d" % k], J["w_t%d" % k]
        m1 = add(lerp(J["w_wrist"], K, 0.5), 0.028, wr)
        kn = add(K, 0.032, m1)
        p1 = add(lerp(K, T, 0.5), 0.02, kn)
        add(T, 0.011, p1)
    bm = bmesh.new()
    verts = [bm.verts.new(to_b(p)) for p in points]
    for a, b in edges:
        bm.edges.new((verts[a], verts[b]))
    mesh = mesh_from_bm(bm, "rods")
    obj = obj_from_mesh(mesh, "rods")
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.3
    for i, r in enumerate(radii):
        mesh.skin_vertices[0].data[i].radius = (r, r * 0.85)
        mesh.skin_vertices[0].data[i].use_root = i == wr
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    return evaluated(obj)


def rod_weights(p):
    """The bones a point of the left wing's rods is carried by."""
    found = []
    for name in ("wing_arm", "wing_fore", "wing_hand", "wing_d2a", "wing_d2b", "wing_d3a", "wing_d3b", "wing_d4a", "wing_d4b", "wing_d5a", "wing_d5b"):
        a, b, r = SEG[name + "_l"]
        d, _ = dist_segment(p, a, b)
        found.append((d, name + "_l"))
    found.sort()
    w = {}
    for d, name in found[:2]:
        w[name] = 1.0 / (d ** 6 + 1e-12)
    return w


def membranes():
    """The skin of the left wing: panels stretched between the bones. Returns a bmesh and, per vertex,
    its weights, made as a single-sided sheet (thickened later)."""
    bm = bmesh.new()
    weights = []
    W = J["w_wrist"]
    arm = [J["w_root"], J["w_elbow"], W]
    digit = {k: [W, J["w_k%d" % k], J["w_t%d" % k]] for k in (2, 3, 4, 5)}
    knuckle_t = {k: (J["w_k%d" % k] - W).length / ((J["w_k%d" % k] - W).length + (J["w_t%d" % k] - J["w_k%d" % k]).length) for k in (2, 3, 4, 5)}
    elbow_t = (J["w_elbow"] - J["w_root"]).length / ((J["w_elbow"] - J["w_root"]).length + (W - J["w_elbow"]).length)

    def finger_bones(k, t):
        b = smooth(knuckle_t[k] - 0.04, knuckle_t[k] + 0.04, t)
        return {"wing_d%da_l" % k: 1.0 - b, "wing_d%db_l" % k: b}

    def arm_bones(t):
        b = smooth(elbow_t - 0.05, elbow_t + 0.05, t)
        return {"wing_arm_l": 1.0 - b, "wing_fore_l": b}

    def panel(edge_a, edge_b, bones_a, bones_b, scallop, toward, nu=16, nv=9, sag=0.03):
        grid = []
        for i in range(nu + 1):
            u = i / nu
            row = []
            for j in range(nv + 1):
                v = j / nv
                a = edge_a(u)
                b = edge_b(u)
                p = lerp(a, b, v)
                # (the free edge scalloped in, between the two bones)
                pull = scallop * math.sin(math.pi * v) * u ** 3
                p = lerp(p, toward(u), pull)
                p += V(0, -sag * math.sin(math.pi * v) * math.sin(math.pi * min(u * 1.2, 1.0)), 0)
                w = {}
                for name, x in bones_a(u).items():
                    w[name] = w.get(name, 0.0) + x * (1.0 - v)
                for name, x in bones_b(u).items():
                    w[name] = w.get(name, 0.0) + x * v
                row.append(bm.verts.new(to_b(p)))
                weights.append(w)
            grid.append(row)
        for i in range(nu):
            for j in range(nv):
                bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))

    # In front of the forearm, from the elbow to the wrist. (Only the forearm
    # carries skin: skin shared between the upper arm and a finger is torn
    # across the wing when it folds, the two turning almost opposite ways.)
    fore = [J["w_elbow"], W]
    lead_a, lead_b = J["w_elbow"] + V(0.0, 0.0, 0.06), W + V(0.0, 0.0, 0.045)
    panel(lambda u: polyline_at(fore, u)[0], lambda u: lerp(lead_a, lead_b, u) + V(0, 0, 0.07 * math.sin(math.pi * u)),
          lambda u: {"wing_fore_l": 1.0}, lambda u: {"wing_fore_l": 1.0}, 0.0, lambda u: W, nu=12, nv=3, sag=0.0)
    # Between the fingers.
    for k in (2, 3, 4):
        panel(lambda u, k=k: polyline_at(digit[k], u)[0], lambda u, k=k: polyline_at(digit[k + 1], u)[0],
              lambda u, k=k: finger_bones(k, u), lambda u, k=k: finger_bones(k + 1, u), 0.26, lambda u: W, nu=16, nv=8)
    # From the fifth finger back to the elbow.
    back = [W, J["w_elbow"] + V(0.0, 0.0, -0.04)]
    panel(lambda u: polyline_at(digit[5], u)[0], lambda u: polyline_at(back, u)[0],
          lambda u: finger_bones(5, u), lambda u: {"wing_fore_l": 1.0}, 0.3, lambda u: lerp(W, J["w_elbow"], 0.5), nu=16, nv=8)
    return bm, weights


# --- Putting it together ---

class Built:
    """The model as it is put together: one bmesh, with weights and masks per vertex."""

    def __init__(self):
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.weights = []  # per vertex: {bone: weight}
        self.mask = []     # per vertex: (mouth, eye, membrane)
        self.rest = []     # per vertex: Godot position

    def add(self, mesh, weights_of, mask_of):
        made = []
        for v in mesh.vertices:
            p = from_b(v.co)
            nv = self.bm.verts.new(v.co)
            made.append(nv)
            self.weights.append(weights_of(v.index, p))
            self.mask.append(mask_of(v.index, p))
            self.rest.append(p)
        for poly in mesh.polygons:
            try:
                face = self.bm.faces.new([made[i] for i in poly.vertices])
                face.smooth = True
            except ValueError:
                pass


def body_weights(mesh):
    """Weights for the remeshed body: by how near each bone is (for its thickness), the jaw by where
    a point is in the mouth; then smoothed over the surface."""
    count = len(mesh.vertices)
    hinge, chin = J["jaw_hinge"], J["chin"]
    jaw_axis = (chin - hinge).normalized()
    # (the line between the lips, in the side view: from the hinge forward between the teeth)
    mouth_normal = V(0, 1.0, 0.225).normalized()
    raw = []
    for v in mesh.vertices:
        p = from_b(v.co)
        found = []
        for name in BODY_BONES:
            a, b, r = SEG[name]
            d, _ = dist_segment(p, a, b)
            found.append((d / r, name))
        found.sort()
        w = {}
        for d, name in found[:4]:
            w[name] = 1.0 / (max(d, 0.05) ** 8)
        # The jaw: below the line of the mouth and in front of the hinge.
        q = head_space(p)
        rel = q - V(0, 1.69, 0.40)
        below = smooth(0.012, -0.012, rel.dot(mouth_normal))
        ahead = smooth(-0.06, 0.02, q.z - 0.4) * smooth(1.53, 1.58, q.y) * smooth(0.16, 0.11, abs(q.x))
        jaw = below * ahead
        if jaw > 0.0:
            total = sum(w.values())
            w = {k: x / total * (1.0 - jaw) for k, x in w.items()}
            w["jaw"] = jaw
        raw.append(w)
    # Smoothed over the surface: each a little towards its neighbours', a few times over.
    neighbours = [[] for _ in range(count)]
    for e in mesh.edges:
        a, b = e.vertices
        neighbours[a].append(b)
        neighbours[b].append(a)
    weights = []
    for w in raw:
        total = sum(w.values()) or 1.0
        weights.append({k: x / total for k, x in w.items()})
    for _ in range(5):
        smoothed = []
        for i in range(count):
            out = dict((k, x * 0.5) for k, x in weights[i].items())
            near = neighbours[i]
            if near:
                share = 0.5 / len(near)
                for n in near:
                    for k, x in weights[n].items():
                        out[k] = out.get(k, 0.0) + x * share
            smoothed.append(out)
        weights = smoothed
    final = []
    for w in weights:
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        total = sum(x for _, x in top) or 1.0
        final.append({k: x / total for k, x in top if x / total > 0.01})
    return final


def weather(mesh):
    """Wears the stone: soft lumps and hollows where rain has eaten at it, and pits."""
    # (all read first: reading a normal after a point has moved works every normal out again)
    count = len(mesh.vertices)
    cos = [0.0] * (count * 3)
    nos = [0.0] * (count * 3)
    mesh.vertices.foreach_get("co", cos)
    mesh.vertex_normals.foreach_get("vector", nos)
    out = [0.0] * (count * 3)
    for i in range(count):
        b = Vector((cos[3 * i], cos[3 * i + 1], cos[3 * i + 2]))
        nb = Vector((nos[3 * i], nos[3 * i + 1], nos[3 * i + 2]))
        p = from_b(b)
        lumps = noise.fractal(p * 9.0, 0.6, 2.2, 3) * 0.0042
        fine = noise.noise(p * 60.0 + Vector((3.1, 7.2, 1.4))) * 0.0011
        pit = noise.noise(p * 32.0 + Vector((11.0, 2.0, 5.0)))
        pits = -0.0028 * smooth(0.42, 0.62, pit)
        moved = b + nb * (lumps + fine + pits)
        out[3 * i], out[3 * i + 1], out[3 * i + 2] = moved.x, moved.y, moved.z
    mesh.vertices.foreach_set("co", out)
    mesh.update()


def cavities(bm_tree, points, normals, reach=0.09, rays=20):
    """How far each point lies in a hollow (0 open, 1 deep in), from rays out of it."""
    golden = math.pi * (3.0 - math.sqrt(5.0))
    dirs = []
    for i in range(rays):
        y = 1.0 - (i + 0.5) / rays
        r = math.sqrt(max(0.0, 1.0 - y * y))
        a = golden * i
        dirs.append(Vector((math.cos(a) * r, math.sin(a) * r, y)))
    out = []
    for p, n in zip(points, normals):
        rot = n.to_track_quat("Z", "Y")
        hit = 0.0
        for d in dirs:
            w = rot @ d
            loc, _, _, dist = bm_tree.ray_cast(p + n * 0.002, w, reach)
            if loc is not None:
                hit += 1.0 - dist / reach
        out.append(min(1.0, hit / rays * 2.2))
    return out


def decimated(mesh, tris):
    obj = obj_from_mesh(mesh, "dec")
    have = sum(len(p.vertices) - 2 for p in mesh.polygons)
    if have > tris:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = tris / have
        dec.use_collapse_triangulate = True
    return evaluated(obj)


def build_body_stone():
    """The body as one weathered piece of stone (a mesh, Blender axes), before decimating."""
    started = time.time()
    soft, sharp = bmesh.new(), bmesh.new()
    muscles(soft)
    head(soft, sharp)
    back_spikes(sharp)
    limb_spurs(sharp)
    tail_spade(sharp)
    sharp_mesh = mesh_from_bm(sharp, "sharp")
    sharp_tree = BVHTree.FromObject(obj_from_mesh(sharp_mesh, "sharp_obj"), bpy.context.evaluated_depsgraph_get())
    # Join the figure and the parts, and make them one surface.
    joined = stick_figure()
    joined.from_mesh(mesh_from_bm(soft, "soft"))
    joined.from_mesh(sharp_mesh)
    mesh = mesh_from_bm(joined, "joined")
    obj = obj_from_mesh(mesh, "joined")
    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = VOXEL
    remesh.adaptivity = 0.0
    mesh = evaluated(obj)
    print("remeshed %d faces (%.0fs)" % (len(mesh.polygons), time.time() - started))
    mesh = decimated(mesh, 260000)
    print("decimated (%.0fs)" % (time.time() - started))
    # Smoothed, so that the masses run into one another, but less near the fine things (horns,
    # ears, spikes), the hands and feet and the face.
    obj = obj_from_mesh(mesh, "stone")
    group = obj.vertex_groups.new(name="soft")
    for v in mesh.vertices:
        p = from_b(v.co)
        found = sharp_tree.find_nearest(v.co, 0.08)
        near_sharp = found[0] is not None and found[3] < 0.04
        q = V(abs(p.x), p.y, p.z)
        extremity = min((q - J["knuckles"]).length, (q - J["ball"]).length, (q - J["wrist"]).length + 0.05)
        face = (head_space(p) - V(0, 1.72, 0.58)).length
        w = smooth(0.0, 0.05, found[3]) if found[0] is not None else 1.0
        w *= smooth(0.1, 0.2, extremity) * (0.6 + 0.4 * smooth(0.08, 0.16, face))
        group.add([v.index], max(w, 0.0), "REPLACE")
    smoothing = obj.modifiers.new("Smooth", "LAPLACIANSMOOTH")
    smoothing.iterations = 14
    smoothing.lambda_factor = 0.9
    smoothing.use_volume_preserve = True
    smoothing.vertex_group = "soft"
    # Cut the sockets, nostrils and mouth.
    cut = obj_from_mesh(cutters(), "cutters")
    boolean = obj.modifiers.new("Cut", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.object = cut
    boolean.solver = "EXACT"
    mesh = evaluated(obj)
    bpy.data.objects.remove(cut)
    print("smoothed and cut (%.0fs)" % (time.time() - started))
    weather(mesh)
    print("weathered (%.0fs)" % (time.time() - started))
    return mesh


def mouth_mask(p):
    """Inside the mouth or a nostril (dark)."""
    p = head_space(p)
    rel = p - V(0, 1.646, 0.56)
    inside = (rel.x / 0.085) ** 2 + (rel.y / 0.036) ** 2 + (rel.z / 0.12) ** 2
    for s in (1.0, -1.0):
        q = p - V(0.03 * s, 1.712, 0.652)
        if (q.x / 0.018) ** 2 + (q.y / 0.016) ** 2 + (q.z / 0.024) ** 2 < 1.0:
            return 1.0
    return 1.0 if inside < 1.0 and p.z < 0.64 else 0.0


def build(stone, wings_bm, wing_w, rods, out_name):
    built = Built()
    body = decimated(stone.copy(), BODY_TRIS[out_name])
    weights = body_weights(body)
    built.add(body, lambda i, p: weights[i], lambda i, p: (mouth_mask(p), 0.0, 0.0))
    bpy.data.meshes.remove(body)
    for mesh, bone_of, part in teeth_and_claws():
        built.add(mesh, lambda i, p, f=bone_of: f(p), lambda i, p, part=part: (0.0, 1.0 if part == "eye" else 0.0, 0.0))
        bpy.data.meshes.remove(mesh)
    # The wings, left and its mirror.
    for side in (1.0, -1.0):
        rods_m = rods.copy()
        sheet = wings_bm.copy()
        if side < 0:
            bmesh.ops.scale(sheet, vec=Vector((-1, 1, 1)), verts=sheet.verts)
            bmesh.ops.reverse_faces(sheet, faces=sheet.faces)
            for v in rods_m.vertices:
                v.co.x = -v.co.x
            rods_m.flip_normals()
        sheet_mesh = mesh_from_bm(sheet, "sheet")
        sheet_obj = obj_from_mesh(sheet_mesh, "sheet")
        solid = sheet_obj.modifiers.new("Solid", "SOLIDIFY")
        solid.thickness = 0.026
        solid.offset = 0.0
        solid.use_rim = True
        thick = evaluated(sheet_obj)
        # (the solidified sheet keeps its first vertices in order, then their copies)
        n = len(wing_w)
        rename = (lambda w: w) if side > 0 else (lambda w: {k[:-2] + "_r": x for k, x in w.items()})
        built.add(thick, lambda i, p: rename(wing_w[i % n]), lambda i, p: (0.0, 0.0, 1.0))
        built.add(rods_m, lambda i, p: rename(rod_weights(V(abs(p.x), p.y, p.z))), lambda i, p: (0.0, 0.0, 0.0))
        bpy.data.meshes.remove(thick)
        bpy.data.meshes.remove(rods_m)
    return built


def export(built, out_name):
    bm = built.bm
    bm.verts.ensure_lookup_table()
    # Cavities, from the whole model at rest.
    tree = BVHTree.FromBMesh(bm)
    bm.normal_update()
    points = [v.co.copy() for v in bm.verts]
    normals = [v.normal.copy() for v in bm.verts]
    hollow = cavities(tree, points, normals)
    mesh = bpy.data.meshes.new(out_name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    # Masks, and where each point is at rest.
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, item in enumerate(col.data):
        m = built.mask[i]
        item.color = (m[0], m[1], m[2], 1.0)
    uv0 = mesh.uv_layers.new(name="UVMap")
    uv1 = mesh.uv_layers.new(name="UV2")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            p = built.rest[vi]
            uv0.data[li].uv = (p.x, 1.0 - p.y)
            uv1.data[li].uv = (p.z, 1.0 - hollow[vi])
    mesh.color_attributes.active_color = col
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
    mesh.uv_layers.active = uv0

    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for name, a, b, _ in BONES:
        eb = data.edit_bones.new(name)
        eb.head = to_b(a)
        eb.tail = to_b(b) if (b - a).length > 0.005 else to_b(a + V(0, 0.03, 0))
    bpy.ops.object.mode_set(mode="OBJECT")
    body = bpy.data.objects.new(out_name, mesh)
    bpy.context.collection.objects.link(body)
    groups = {name: body.vertex_groups.new(name=name) for name in BONE_NAMES}
    for i, w in enumerate(built.weights):
        total = sum(w.values()) or 1.0
        for name, x in w.items():
            if x / total > 0.001:
                groups[name].add([i], x / total, "REPLACE")
    body.parent = armature
    body.modifiers.new("Armature", "ARMATURE").object = armature
    for poly in mesh.polygons:
        poly.use_smooth = True
    os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
    path = os.path.join(FOLDER, "models", out_name + ".glb")
    options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=True,
                   export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    print("BUILT %s verts=%d faces=%d" % (out_name, len(mesh.vertices), len(mesh.polygons)))
    return body, hollow


def write_rest():
    """creatures/gargoyle/gargoyle_rest.gd: where each bone stands at rest, for Gargoyle."""
    def g(p):
        return "Vector3(%.4f, %.4f, %.4f)" % (p.x, p.y, p.z)
    lines = [
        "class_name GargoyleRest",
        "## Where every bone of the gargoyle's model stands at rest, in the model",
        "## (metres, Y up, facing +Z, +X its left). Written by",
        "## creatures/gargoyle/tools/build_gargoyle.py with the models: do not edit it",
        "## by hand, change the build and run it again.",
        "",
        "## The bones, in the model's order.",
        "const BONES: Array[String] = [%s]" % ", ".join('"%s"' % n for n in BONE_NAMES),
        "## Each bone's two ends.",
        "const HEADS := {",
    ]
    for name, a, b, _ in BONES:
        lines.append('\t"%s": %s,' % (name, g(a)))
    lines.append("}")
    lines.append("const TAILS := {")
    for name, a, b, _ in BONES:
        lines.append('\t"%s": %s,' % (name, g(b)))
    lines.append("}")
    lines.append("## The wing's thumb tip (left), the tail's points from root to tip.")
    lines.append("const THUMB_TIP := %s" % g(J["w_thumb_tip"]))
    lines.append("const TAIL: Array[Vector3] = [%s]" % ", ".join(g(p) for p in TAIL))
    with open(os.path.join(FOLDER, "gargoyle_rest.gd"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def previews(body, hollow, name):
    mesh = body.data
    shade = mesh.color_attributes.new("Preview", "FLOAT_COLOR", "POINT")
    col = mesh.color_attributes["Col"]
    for i, item in enumerate(shade.data):
        c = col.data[i].color
        g = 0.62 - 0.4 * hollow[i]
        if c[0] > 0.5:
            g = 0.08
        if c[1] > 0.5:
            g = 0.9
        item.color = (g, g * 0.98, g * 0.94, 1.0)
    mesh.color_attributes.active_color = shade
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 60
    scene.collection.objects.link(camera)
    scene.camera = camera
    face = hp(0, 1.74, 0.5)
    whole = V(0, 0.95, 0.0)
    views = [("whole_front", V(0.0, 0.15, 1.0), whole, 6.5), ("whole_quarter", V(0.8, 0.35, 0.8), whole, 6.5),
             ("whole_side", V(1.0, 0.1, 0.0), whole, 6.0), ("whole_top", V(0.05, 1.0, 0.3), whole, 7.0),
             ("body_quarter", V(0.7, 0.25, 0.9), V(0, 1.1, 0.1), 3.4),
             ("face_front", V(0.0, 0.1, 1.0), face, 0.9), ("face_quarter", V(0.7, 0.2, 0.8), face, 0.95),
             ("face_side", V(1.0, 0.05, 0.1), face, 1.0), ("hand", V(0.6, 0.2, 1.0), J["knuckles"], 0.7),
             ("foot", V(0.5, 0.4, 1.0), J["ball"], 0.7)]
    for view, direction, target, far in views:
        offset = to_b(direction.normalized()) * far
        camera.location = to_b(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    stone = build_body_stone()
    print("STONE verts=%d" % len(stone.vertices))
    sheet, sheet_w = membranes()
    rods = {"gargoyle": wing_rods(2), "gargoyle_lo": wing_rods(1)}
    write_rest()
    for out_name in (("gargoyle",) if "--quick" in sys.argv else ("gargoyle", "gargoyle_lo")):
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj)
        built = build(stone, sheet, sheet_w, rods[out_name], out_name)
        body, hollow = export(built, out_name)
        if PREVIEW_DIR and out_name == "gargoyle":
            previews(body, hollow, out_name)
