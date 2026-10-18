"""Builds the imp and exports it for Godot; and the low-poly imp the swarm is
drawn with.

Run from the project root (Blender 4.3):
    blender --background --python creatures/imp/tools/build_imp.py [-- <preview folder>]

Writes creatures/imp/models/imp.glb and imp_lo.glb (skinned, for Imp), and
creatures/imp_swarm/models/imp_swarm.glb with imp_swarm.json (one static mesh on
all fours, for ImpSwarm's MultiMesh); given a folder, renders previews into it.

What it models round is the skeleton Imp (creatures/imp/imp.gd) works out for
itself as it stands, written out by rest_joints.gd into rest_imp.json beside
this file (its own units, one to the crown of its head; Godot's axes: Y up,
facing +Z, +X its left). Everything is in those units and axes here, and turned
to Blender's (Z up) only as it is made.

- The body is the Skin modifier over a stick figure of the skeleton (hips, pot
  belly, a narrow chest, the neck; wiry arms with knobby elbows, three long
  fingers and a thumb on each hand; short bowed legs on their toes, three toes
  each and a spur at the heel; the whip of the tail), smoothed with a
  Subdivision Surface, then shaped: the belly pushed out round and low, the
  ribs and the knobs of the spine showing through the skin.
- The head: a broad skull, a heavy brow cut down in a V over small slanted
  glowing eyes with slit pupils, gaunt cheekbones, a short upturned snout; the
  mouth a wide grin, its lips drawn back at the corners so that two rows of
  needle teeth show even shut, a dark mouth inside, a hinged lower jaw ending
  in a pointed chin. Big bat's ears, cupped and ribbed. Two small ridged horns
  curving back.
- Stubby leathery wings on the shoulder blades (an arm and three fingers with
  skin between, scalloped), claws on every finger and toe, a barbed spade on
  the end of the tail.
- Colours are vertex colours: sooty red-brown skin, charcoal along the back
  and on the hands, feet, horns and ear tips, a duller warmer belly; bone
  teeth and claws; the dark mouth. The first UV is how much a point glows (the
  eyes) and how wet it is (eyes, teeth, mouth); the second where it was on the
  standing body (for the shader's creases).
- The skeleton is Imp.BONES, none the child of another, each where Imp puts it
  as it stands. Every vertex is weighted by how near it is to each bone (two
  or three at most); the head's parts go to the head, the jaw's to the jaw.

The swarm's imp is the same imp made coarser, posed on all fours mid-scuttle
(by the bones rest_joints.gd writes as `fours_bones`), and baked: one static
mesh whose first UV says which limb a point is on and how far out along it
(for the swarm's shader to swing the limbs), and whose second UV its colour
(how sooty, or a part: eye, teeth, mouth, claw, wing), because the web does not
give a MultiMesh's points their vertex colours dependably. imp_swarm.json says
where each limb turns.
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
SWARM_FOLDER = os.path.join(os.path.dirname(FOLDER), "imp_swarm")
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

SKIN = (0.2, 0.085, 0.06)
BELLY = (0.26, 0.13, 0.09)
SOOT = (0.07, 0.055, 0.05)
LIP = (0.1, 0.03, 0.03)
EYE = (1.0, 0.62, 0.12)
PUPIL = (0.02, 0.01, 0.0)
SOCKET = (0.05, 0.02, 0.02)
TOOTH = (0.8, 0.74, 0.58)
CLAW = (0.16, 0.13, 0.1)
MOUTH = (0.16, 0.03, 0.03)
EAR_IN = (0.3, 0.12, 0.1)
WING = (0.15, 0.06, 0.045)
HORN = (0.2, 0.16, 0.12)

# The swarm's colour codes (second UV x): 0..1 how sooty the skin is; then parts.
CODE_EYE = 2.0
CODE_TOOTH = 3.0
CODE_MOUTH = 4.0
CODE_CLAW = 5.0
CODE_WING = 6.0
CODE_EAR = 7.0
# The swarm's limb tags (first UV x).
TAG_BODY, TAG_ARM_L, TAG_ARM_R, TAG_LEG_L, TAG_LEG_R, TAG_TAIL, TAG_WINGS, TAG_JAW, TAG_HEAD = range(9)
# How much of the swarm build its imp keeps (a Decimate).
SWARM_RATIO = 0.2


def V(p):
    return Vector((p[0], p[1], p[2]))


def to_b(p):
    return Vector((p.x, -p.z, p.y))


def from_b(p):
    return Vector((p.x, p.z, -p.y))


def xform(d):
    b = d["basis"]
    return Matrix((
        (b[0][0], b[1][0], b[2][0], d["origin"][0]),
        (b[0][1], b[1][1], b[2][1], d["origin"][1]),
        (b[0][2], b[1][2], b[2][2], d["origin"][2]),
        (0, 0, 0, 1)))


def basis3(b):
    return Matrix(((b[0][0], b[1][0], b[2][0]), (b[0][1], b[1][1], b[2][1]), (b[0][2], b[1][2], b[2][2])))


def smooth(a, b, x):
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def dist_segment(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def along_segment(p, a, b):
    ab = b - a
    return 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))


class Model:
    """The mesh as it is put together: one bmesh, with per-vertex data."""

    def __init__(self, bones):
        self.bm = bmesh.new()
        self.uv0 = self.bm.loops.layers.uv.new("UVMap")
        self.uv1 = self.bm.loops.layers.uv.new("UV2")
        self.col = self.bm.verts.layers.float_color.new("Col")
        self.deform = self.bm.verts.layers.deform.verify()
        self.bones = bones
        self.vert_uv = []
        self.weights = []  # per vertex: {bone: weight}
        self.colours = []
        self.codes = []  # per vertex: the swarm's colour code

    def add(self, mesh, info):
        """Adds a Blender mesh (in Blender's axes). info(index, godot_position, godot_normal) ->
        (colour, uv0, uv1, {bone: weight}, code)."""
        made = []
        for v in mesh.vertices:
            nv = self.bm.verts.new(v.co)
            colour, uv0, uv1, weights, code = info(v.index, from_b(v.co), from_b(v.normal))
            nv[self.col] = (colour[0], colour[1], colour[2], 1.0)
            total = sum(weights.values()) or 1.0
            clean = {}
            for bone, w in weights.items():
                if w / total > 0.001:
                    nv[self.deform][self.bones.index(bone)] = w / total
                    clean[bone] = w / total
            made.append(nv)
            self.vert_uv.append((uv0, uv1))
            self.weights.append(clean)
            self.colours.append(colour)
            self.codes.append(code)
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
        return base


def mesh_from_bm(bm):
    mesh = bpy.data.meshes.new("part")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def evaluated(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    bpy.data.objects.remove(obj)
    return mesh


def subdivided(mesh, levels):
    if levels <= 0:
        return mesh
    obj = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(obj)
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return evaluated(obj)


def skinned(points, edges, radii, root, levels):
    """A Skin-modifier surface over a stick figure (Godot points), smoothed."""
    bm = bmesh.new()
    verts = [bm.verts.new(to_b(p)) for p in points]
    for a, b in edges:
        bm.edges.new((verts[a], verts[b]))
    mesh = mesh_from_bm(bm)
    obj = bpy.data.objects.new("skin", mesh)
    bpy.context.collection.objects.link(obj)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    skin.use_smooth_shade = True
    for i, r in enumerate(radii):
        rx, ry = (r, r) if not isinstance(r, tuple) else r
        mesh.skin_vertices[0].data[i].radius = (rx, ry)
        mesh.skin_vertices[0].data[i].use_root = i == root
    if levels > 0:
        sub = obj.modifiers.new("Subsurf", "SUBSURF")
        sub.levels = levels
        sub.render_levels = levels
    return evaluated(obj)


def ellipsoid(centre, basis, radii, segments=16, rings=10):
    """A UV sphere (Godot space: centre, a 3x3 basis as a Matrix, radii)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        local = Vector((v.co.x * radii[0], v.co.z * radii[1], -v.co.y * radii[2]))
        v.co = to_b(centre + basis @ local)
    return mesh_from_bm(bm)


def tube(points, radii, sides=6, closed_end=True, closed_start=True):
    """A tube along a polyline of Godot points, a radius at each, its end closed to a point."""
    bm = bmesh.new()
    rings = []
    n = len(points)
    prev_across = None
    for i, p in enumerate(points):
        ahead = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
        across = ahead.cross(Vector((0, 1, 0))) if prev_across is None else prev_across - ahead * prev_across.dot(ahead)
        if across.length < 1e-6:
            across = ahead.cross(Vector((1, 0, 0)))
        across.normalize()
        prev_across = across
        lift = ahead.cross(across).normalized()
        r = radii[i]
        if i == n - 1 and closed_end:
            rings.append([bm.verts.new(to_b(p))])
            continue
        rings.append([bm.verts.new(to_b(p + (across * math.cos(a) + lift * math.sin(a)) * r)) for a in [math.tau * k / sides for k in range(sides)]])
    for i in range(n - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(sides):
            if len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % sides], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if closed_start and len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    return mesh_from_bm(bm)


def loft(rings_pts, closed_end=True, closed_start=False):
    """A tube through rings of Godot points (each a list, all the same length)."""
    bm = bmesh.new()
    grid = [[bm.verts.new(to_b(p)) for p in ring] for ring in rings_pts]
    n = len(grid[0])
    for i in range(len(grid) - 1):
        for k in range(n):
            bm.faces.new((grid[i][k], grid[i][(k + 1) % n], grid[i + 1][(k + 1) % n], grid[i + 1][k]))
    if closed_end:
        tip = sum((p for p in rings_pts[-1]), Vector()) / n
        prev = sum((p for p in rings_pts[-2]), Vector()) / n
        centre = bm.verts.new(to_b(tip + (tip - prev).normalized() * 0.002))
        for k in range(n):
            bm.faces.new((grid[-1][k], grid[-1][(k + 1) % n], centre))
    if closed_start:
        bm.faces.new(list(reversed(grid[0])))
    return mesh_from_bm(bm)


def sheet(grid_pts, thickness, normal_of):
    """A thin two-sided sheet: a grid of Godot points (rows of columns), given
    thickness along normal_of(point) (one side out, one side in), edges closed."""
    bm = bmesh.new()
    rows, cols = len(grid_pts), len(grid_pts[0])
    front = [[bm.verts.new(to_b(p + normal_of(p) * thickness * 0.5)) for p in row] for row in grid_pts]
    back = [[bm.verts.new(to_b(p - normal_of(p) * thickness * 0.5)) for p in row] for row in grid_pts]
    for i in range(rows - 1):
        for k in range(cols - 1):
            bm.faces.new((front[i][k], front[i][k + 1], front[i + 1][k + 1], front[i + 1][k]))
            bm.faces.new((back[i][k], back[i + 1][k], back[i + 1][k + 1], back[i][k + 1]))
    edge = [(i, 0) for i in range(rows)] + [(rows - 1, k) for k in range(1, cols)] + [(i, cols - 1) for i in range(rows - 2, -1, -1)] + [(0, k) for k in range(cols - 2, 0, -1)]
    for e in range(len(edge)):
        a, b = edge[e], edge[(e + 1) % len(edge)]
        try:
            bm.faces.new((front[a[0]][a[1]], back[a[0]][a[1]], back[b[0]][b[1]], front[b[0]][b[1]]))
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    return mesh_from_bm(bm)


class Imp:
    def __init__(self, detail):
        """detail: "hi" (imp.glb), "lo" (imp_lo.glb) or "swarm"."""
        self.detail = detail
        with open(os.path.join(HERE, "rest_imp.json")) as f:
            self.j = json.load(f)
        self.bones = self.j["bones"]
        self.levels = {"hi": 2, "lo": 1, "swarm": 1}[detail]
        self.model = Model(self.bones)
        j = self.j
        self.torso = basis3(j["torso"])
        self.side = V(j["torso"][0])
        self.spine = V(j["torso"][1])
        self.front = V(j["torso"][2])
        self.head = xform(j["head_xform"])
        self.jaw = xform(j["jaw_xform"])
        self.rng_state = 17
        self.segments = {}
        pel, bel, che, nec = V(j["pelvis"]), V(j["belly"]), V(j["chest"]), V(j["neck"])
        self.segments["hips"] = (pel - self.spine * 0.06, pel)
        self.segments["belly"] = (pel, bel)
        self.segments["chest"] = (bel, che)
        self.segments["neck"] = (che, nec)
        self.segments["head"] = (nec, V(j["head_xform"]["origin"]))
        for i, s in enumerate(["l", "r"]):
            self.segments["arm_" + s] = (V(j["roots"][i]), V(j["mids"][i]))
            self.segments["forearm_" + s] = (V(j["mids"][i]), V(j["ends"][i]))
            wrist, knuckle = V(j["ends"][i]), V(j["knuckles"][i])
            hand_y = basis3(j["hands"][i]).col[1]
            self.segments["hand_" + s] = (wrist, knuckle)
            self.segments["fingers_" + s] = (knuckle, knuckle + hand_y * 0.07)
            self.segments["thigh_" + s] = (V(j["roots"][i + 2]), V(j["mids"][i + 2]))
            self.segments["shin_" + s] = (V(j["mids"][i + 2]), V(j["ends"][i + 2]))
            self.segments["foot_" + s] = (V(j["ends"][i + 2]), V(j["balls"][i]))
            self.segments["wing_" + s] = (V(j["wing_roots"][i]), V(j["wing_mids"][i]))
            self.segments["wingtip_" + s] = (V(j["wing_mids"][i]), V(j["wing_tips"][i]))
            ear = xform(j["ears"][i])
            self.segments["ear_" + s] = (ear.translation, ear.translation + ear.to_3x3().col[1] * j["ear_long"])
        self.segments["jaw"] = (self.jaw.translation, self.jaw @ Vector((0, -0.03, 0.1)))
        tail = [V(p) for p in j["tail"]]
        for k in range(7):
            self.segments["tail_%d" % (k + 1)] = (tail[k], tail[k + 1])
        self.body_bones = [b for b in self.bones if not (b.startswith("ear") or b.startswith("wing") or b == "jaw")]

    def rand(self):
        self.rng_state = (self.rng_state * 1103515245 + 12345) % 2147483648
        return self.rng_state / 2147483648.0

    def uniform(self, a, b):
        return a + (b - a) * self.rand()

    def h(self, x, y, z):
        return self.head @ Vector((x, y, z))

    def hb(self, v):
        return self.head.to_3x3() @ Vector(v)

    def jw(self, x, y, z):
        return self.jaw @ Vector((x, y, z))

    def nearest(self, p, among=None, count=3):
        found = []
        for bone, (a, b) in self.segments.items():
            if among is not None and bone not in among:
                continue
            found.append((dist_segment(p, a, b), bone))
        found.sort()
        found = found[:count]
        weights = {}
        for d, bone in found:
            weights[bone] = 1.0 / (d ** 4 + 1e-10)
        best = max(weights.values())
        return {k: w for k, w in weights.items() if w > best * 0.02}

    @staticmethod
    def noise_uv(p):
        return (p.x * 2.0 + p.z * 1.4, p.y * 2.0 + p.z * 0.7)

    def put(self, mesh, colour, weights, uv0=(0.0, 0.0), code=0.0):
        def info(i, p, n):
            c = colour(p, n) if callable(colour) else colour
            w = weights(p) if callable(weights) else weights
            k = code(p, n) if callable(code) else code
            return c, uv0, self.noise_uv(p), w, k
        self.model.add(mesh, info)
        bpy.data.meshes.remove(mesh)

    # --- The body ---

    def skin_colour(self, p, n):
        """Its skin at a point (Godot) with a normal (Godot): (colour, how sooty)."""
        dorsal = smooth(-0.2, 0.8, -n.dot(self.front))  # (its back)
        if p.y > V(self.j["chest"]).y + 0.02:
            dorsal *= 0.6
        soot = dorsal * 0.55
        belly = smooth(0.25, 0.9, n.dot(self.front)) * smooth(0.62, 0.45, p.y) * smooth(0.3, 0.42, p.y)
        # The hands, forearms, shins and feet go charcoal; the tail darkens towards its end.
        low = smooth(0.24, 0.06, p.y) if abs(p.x) > 0.04 or p.y < 0.2 else 0.0
        for i in range(2):
            wrist = V(self.j["ends"][i])
            elbow = V(self.j["mids"][i])
            reach = along_segment(p, elbow, wrist + (wrist - elbow).normalized() * 0.15)
            if dist_segment(p, elbow, wrist + (wrist - elbow).normalized() * 0.15) < 0.05:
                low = max(low, smooth(0.2, 0.9, reach))
        tail = [V(q) for q in self.j["tail"]]
        for k in range(7):
            if dist_segment(p, tail[k], tail[k + 1]) < 0.035:
                low = max(low, k / 7.0 * 0.9)
        soot = max(soot, low)
        c = mix(SKIN, BELLY, belly * (1.0 - soot))
        c = mix(c, SOOT, soot)
        return c, soot

    def body(self):
        j = self.j
        P = lambda k: V(j[k])
        points, radii, edges = [], [], []

        def add(p, r, link=None):
            points.append(p)
            radii.append(r)
            if link is not None:
                edges.append((link, len(points) - 1))
            return len(points) - 1

        pel, bel, che, nec = P("pelvis"), P("belly"), P("chest"), P("neck")
        hd = V(j["head_xform"]["origin"])
        sp, fr, sd = self.spine, self.front, self.side
        t0 = add(pel - sp * 0.05 - fr * 0.03, 0.05)
        pv = add(pel, 0.068, t0)
        b1 = add(pel.lerp(bel, 0.5) + fr * 0.006, 0.078, pv)
        bl = add(bel + fr * 0.01, 0.084, b1)
        c1 = add(bel.lerp(che, 0.5), 0.066, bl)
        ch = add(che, 0.064, c1)
        sh = add(che + sp * 0.025, 0.06, ch)
        n1 = add(che.lerp(nec, 0.6) + sp * 0.01, 0.034, sh)
        nk = add(nec, 0.03, n1)
        add(nec.lerp(hd, 0.55), 0.034, nk)
        hand_tips = []
        for i in range(4):
            arm = i < 2
            sign = 1.0 if i % 2 == 0 else -1.0
            root, mid, end = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            if arm:
                a = add(root, 0.034, sh)
                a2 = add(root.lerp(mid, 0.45), 0.021, a)
                m = add(mid, 0.021, a2)
                m2 = add(mid.lerp(end, 0.4), 0.022, m)
                e = add(end, 0.0145, m2)
                hand = basis3(j["hands"][i])
                hy, hx, hz = hand.col[1], hand.col[0], hand.col[2]
                palm = add(end + hy * 0.03, 0.018, e)
                knuckle = V(j["knuckles"][i])
                tips = []
                # Three long fingers, fanned, and a thumb.
                for f, (fan, lengths) in enumerate([(-0.28, (0.034, 0.028, 0.022)), (0.0, (0.038, 0.032, 0.025)), (0.28, (0.032, 0.027, 0.021))]):
                    way = (hy * math.cos(fan) + hz * math.sin(fan)).normalized()
                    at = knuckle + hz * fan * 0.03
                    last = add(at, 0.0085, palm)
                    for k, length in enumerate(lengths):
                        # (each joint bending a little in, as long fingers hang)
                        way = (way - hx * sign * 0.12).normalized()
                        at = at + way * length
                        last = add(at, 0.0075 - k * 0.0012, last)
                    tips.append((at, way))
                tway = (hy * 0.6 + hz * 0.75 - hx * sign * 0.3).normalized()
                t1 = add(end + hy * 0.022 + hz * 0.012, 0.009, palm)
                tat = end + hy * 0.022 + hz * 0.012 + tway * 0.028
                t2 = add(tat, 0.007, t1)
                add(tat + tway * 0.022, 0.0055, t2)
                tips.append((tat + tway * 0.022, tway))
                hand_tips.append(tips)
            else:
                a = add(root, 0.046, pv)
                a2 = add(root.lerp(mid, 0.45), 0.037, a)
                m = add(mid, 0.022, a2)
                m2 = add(mid.lerp(end, 0.4), 0.021, m)
                e = add(end, 0.014, m2)
                ball = V(j["balls"][i - 2])
                b2 = add(end.lerp(ball, 0.5), 0.013, e)
                bb = add(ball + Vector((0, 0.012, 0)), 0.016, b2)
                tips = []
                for f, x in enumerate([-0.016, 0.0, 0.016]):
                    way = Vector((x * 6.0 * sign, -0.12, 1.0)).normalized()
                    at = ball + Vector((x, 0.01, 0.012))
                    last = add(at, 0.0095, bb)
                    for k, length in enumerate((0.026, 0.02)):
                        at = at + way * length
                        last = add(at, 0.0082 - k * 0.0015, last)
                    tips.append((at, way))
                hand_tips.append(tips)
        tail = [V(p) for p in j["tail"]]
        last = t0
        for k in range(1, 8):
            last = add(tail[k], 0.028 * (1.0 - k / 8.0) ** 0.9 + 0.005, last)
        mesh = skinned(points, edges, radii, pv, self.levels)
        self.shape_body(mesh)

        def info(i, p, n):
            c, soot = self.skin_colour(p, n)
            return c, (0.0, 0.08), self.noise_uv(p), self.nearest(p, self.body_bones, 3), soot
        self.model.add(mesh, info)
        bpy.data.meshes.remove(mesh)
        self.surface = self.model.bm.copy()
        self.bvh = BVHTree.FromBMesh(self.surface)
        self.claws(hand_tips)
        self.tail_barb(tail)
        self.spine_knobs()

    def shape_body(self, mesh):
        """The pot belly pushed out, ribs and the spine's knobs showing, sharp shoulders."""
        j = self.j
        pel, bel, che = V(j["pelvis"]), V(j["belly"]), V(j["chest"])
        sp, fr = self.spine, self.front
        belly_at = bel + fr * 0.055 - sp * 0.03
        for v in mesh.vertices:
            p = from_b(v.co)
            n = from_b(v.normal).normalized()
            push = 0.0
            # The belly: round and low, hanging forward.
            d = (p - belly_at).length
            push += 0.034 * math.exp(-(d / 0.07) ** 2) * max(0.0, n.dot(fr) * 0.8 + 0.3)
            # Ribs, round the sides and front of the chest.
            u = along_segment(p, bel, che + sp * 0.03)
            if 0.15 < u < 0.98 and dist_segment(p, bel, che) < 0.11:
                lateral = abs(n.dot(self.side))
                frontal = max(0.0, n.dot(fr))
                rib = 0.5 + 0.5 * math.cos(u * math.tau * 4.5)
                push += (rib - 0.5) * 0.007 * (lateral * 0.8 + frontal * 0.5) * smooth(0.15, 0.4, u)
            # The knobs of the spine down its back.
            back = -n.dot(fr)
            if back > 0.6 and abs(p.x) < 0.03:
                u2 = along_segment(p, pel - sp * 0.05, che + sp * 0.06)
                knob = max(0.0, math.cos(u2 * math.tau * 7.0)) ** 3
                push += knob * 0.006 * (back - 0.6) / 0.4 * (1.0 - smooth(0.012, 0.03, abs(p.x)))
            v.co = to_b(p + n * push)
        mesh.update()

    def spine_knobs(self):
        j = self.j
        pel, che = V(j["pelvis"]), V(j["chest"])
        for k in range(12):
            u = k / 11.0
            axis = (pel - self.spine * 0.03).lerp(che + self.spine * 0.07, u)
            root = self.on_body(axis, -self.front)
            if root is None:
                continue
            size = 0.0045 + 0.002 * math.sin(u * math.pi)
            self.put(ellipsoid(root - self.front * 0.002, self.torso, Vector((size, size * 1.3, size * 0.9)), 8, 6),
                     mix(SKIN, SOOT, 0.7), self.nearest(root, self.body_bones, 2), (0.0, 0.15), 0.7)

    def on_body(self, axis, out):
        hit = self.bvh.ray_cast(to_b(axis + out * 0.3), to_b(-out))
        if hit[0] is None:
            return None
        return from_b(hit[0])

    def claws(self, tips):
        """A hooked claw on the end of every finger and toe."""
        for limb, tip_list in enumerate(tips):
            for at, way in tip_list:
                down = Vector((0, -1, 0)) if limb >= 2 else (way.cross(self.side).normalized() if way.cross(self.side).length > 0.1 else Vector((0, 0, 1)))
                long = 0.024 if limb < 2 else 0.018
                pts = [at - way * 0.004, at + way * long * 0.45, at + way * long * 0.8 + down * long * 0.25, at + way * long + down * long * 0.6]
                radii = [0.0055, 0.0045, 0.0025, 0.0]
                self.put(tube(pts, radii, 5), CLAW, self.nearest(at, self.body_bones, 1), (0.0, 0.55), CODE_CLAW)

    def tail_barb(self, tail):
        """A barbed spade on the end of the tail: flat, pointed, its two barbs hooked back."""
        end, before = tail[7], tail[6]
        way = (end - before).normalized()
        flat_normal = way.cross(self.side).normalized() if way.cross(self.side).length > 0.1 else self.front
        across = flat_normal.cross(way).normalized()
        outline = [(0.0, -0.005), (0.012, 0.0), (0.03, 0.006), (0.024, 0.026), (0.0, 0.052)]
        # (a diamond with hooks: the points of its outline, along and across)
        pts_top, pts_bot = [], []
        bm = bmesh.new()
        ring = []
        shape = [(-0.004, 0.0), (0.004, 0.009), (-0.016, 0.03), (0.012, 0.022), (0.05, 0.0), (0.012, -0.022), (-0.016, -0.03), (0.004, -0.009)]
        thick = 0.005
        top = [bm.verts.new(to_b(end + way * a + across * b + flat_normal * thick)) for a, b in shape]
        bot = [bm.verts.new(to_b(end + way * a + across * b - flat_normal * thick)) for a, b in shape]
        mid_t = bm.verts.new(to_b(end + way * 0.012 + flat_normal * thick * 2.0))
        mid_b = bm.verts.new(to_b(end + way * 0.012 - flat_normal * thick * 2.0))
        n = len(shape)
        for k in range(n):
            bm.faces.new((top[k], top[(k + 1) % n], mid_t))
            bm.faces.new((bot[(k + 1) % n], bot[k], mid_b))
            bm.faces.new((top[(k + 1) % n], top[k], bot[k], bot[(k + 1) % n]))
        mesh = mesh_from_bm(bm)
        self.put(mesh, mix(SOOT, LIP, 0.4), {"tail_7": 1.0}, (0.0, 0.3), 1.0)

    # --- The head ---

    def head_parts(self):
        H = self.head.to_3x3().normalized()
        HEAD = {"head": 1.0}
        JAW = {"jaw": 1.0}
        to_head = self.head.inverted()
        hi = self.detail == "hi"
        sub = 2 if hi else 1

        def skull_colour(p, n):
            local = to_head @ p
            soot = self.skull_soot(local, (H.inverted() @ n).normalized())
            return mix(SKIN, SOOT, soot)

        def skull_code(p, n):
            return self.skull_soot(to_head @ p, (H.inverted() @ n).normalized())

        # The skull: broad and low, flat on top, big at the back.
        self.put(subdivided(ellipsoid(self.h(0.0, 0.016, -0.02), H, Vector((0.097, 0.07, 0.096)), 20, 12), sub - 1),
                 skull_colour, HEAD, (0.0, 0.1), skull_code)
        # Gaunt cheekbones, high under the eyes.
        for s in (1.0, -1.0):
            tilt = H @ Matrix.Rotation(0.35 * s, 3, "Y") @ Matrix.Rotation(-0.2 * s, 3, "Z")
            self.put(ellipsoid(self.h(0.055 * s, 0.008, 0.048), tilt, Vector((0.024, 0.015, 0.024)), 14, 8), skull_colour, HEAD, (0.0, 0.1), skull_code)
        # The brow: a heavy ridge, cut down in a V to the top of the nose, overhanging the eyes.
        for s in (1.0, -1.0):
            tilt = H @ Matrix.Rotation(0.42 * s, 3, "Z") @ Matrix.Rotation(-0.32 * s, 3, "Y") @ Matrix.Rotation(0.3, 3, "X")
            self.put(ellipsoid(self.h(0.037 * s, 0.043, 0.072), tilt, Vector((0.035, 0.0105, 0.021)), 16, 8), mix(SKIN, SOOT, 0.5), HEAD, (0.0, 0.1), 0.5)
            # (the creases of the scowl between them)
            self.put(ellipsoid(self.h(0.0075 * s, 0.05, 0.082), H @ Matrix.Rotation(-0.25 * s, 3, "Z"), Vector((0.0022, 0.011, 0.003)), 6, 6), SOCKET, HEAD, (0.0, 0.1), 0.9)
        # Small slanted eyes in deep sockets, glowing, with slit pupils, squinting.
        for s in (1.0, -1.0):
            slant = H @ Matrix.Rotation(0.36 * s, 3, "Z")
            self.put(ellipsoid(self.h(0.04 * s, 0.027, 0.07), slant, Vector((0.024, 0.0145, 0.012)), 14, 8), SOCKET, HEAD, (0.0, 0.0), 0.9)
            self.put(ellipsoid(self.h(0.04 * s, 0.027, 0.0745), slant, Vector((0.017, 0.0095, 0.009)), 14, 8), EYE, HEAD, (1.0, 1.0), CODE_EYE)
            self.put(ellipsoid(self.h(0.04 * s, 0.027, 0.0832), slant, Vector((0.0026, 0.0088, 0.0018)), 8, 6), PUPIL, HEAD, (0.0, 1.0), CODE_MOUTH)
            self.put(ellipsoid(self.h(0.041 * s, 0.0165, 0.0755), slant, Vector((0.02, 0.0058, 0.011)), 12, 6), mix(SKIN, SOOT, 0.4), HEAD, (0.0, 0.1), 0.4)
        # A sharp nose, hooked down at the tip, flared nostrils.
        nose = [self.h(0.0, 0.032, 0.076), self.h(0.0, 0.026, 0.092), self.h(0.0, 0.012, 0.108), self.h(0.0, -0.002, 0.117), self.h(0.0, -0.01, 0.114)]
        self.put(tube(nose, [0.011, 0.012, 0.011, 0.006, 0.0], 8 if hi else 6), mix(SKIN, SOOT, 0.25), HEAD, (0.0, 0.2), 0.25)
        for s in (1.0, -1.0):
            self.put(ellipsoid(self.h(0.0085 * s, 0.003, 0.101), H, Vector((0.0085, 0.006, 0.009)), 10, 6), mix(SKIN, SOOT, 0.3), HEAD, (0.0, 0.2), 0.3)
            self.put(ellipsoid(self.h(0.009 * s, -0.0015, 0.106), H @ Matrix.Rotation(0.4 * s, 3, "Z"), Vector((0.0032, 0.0022, 0.003)), 8, 6), PUPIL, HEAD, (0.0, 0.6), CODE_MOUTH)
        # The mouth: a wide grin, its line curving up into the cheeks, the lips
        # drawn back at the corners. t runs from the corner (0) to the front (1).
        z0, length = -0.028, 0.124

        def middle(t):
            return -0.04 + 0.034 * (1.0 - t) ** 1.5

        def gap(t):
            return 0.008 + 0.014 * (1.0 - t) ** 1.2

        def up_lip(t):
            return middle(t) + gap(t) * 0.5

        def low_lip(t):
            return middle(t) - gap(t) * 0.5

        def up_width(t):
            return 0.078 * (1.0 - 0.5 * t ** 1.6)

        def low_width(t):
            return 0.071 * (1.0 - 0.52 * t ** 1.6)

        ring_count, sides = (12, 18) if hi else (8, 12)
        rings = []
        for i in range(ring_count):
            t = i / (ring_count - 1)
            z = z0 + length * t
            top = 0.016 * (1.0 - 0.3 * t)
            r = []
            for k in range(sides):
                a = math.tau * k / sides
                c, sn = math.cos(a), math.sin(a)
                y = up_lip(t) + 0.003 + (top * sn if sn > 0 else 0.003 * sn)
                r.append(self.h(up_width(t) * c, y, z))
            rings.append(r)
        mesh = subdivided(loft(rings, closed_end=True), sub)

        def muzzle_colour(p, n):
            local = to_head @ p
            t = max(0.0, min(1.0, (local.z - z0) / length))
            lip = smooth(0.008, 0.0, local.y - up_lip(t))
            return mix(mix(SKIN, SOOT, 0.2), LIP, lip)

        def muzzle_code(p, n):
            local = to_head @ p
            t = max(0.0, min(1.0, (local.z - z0) / length))
            return 0.2 + 0.7 * smooth(0.008, 0.0, local.y - up_lip(t))
        self.put(mesh, muzzle_colour, HEAD, (0.0, 0.15), muzzle_code)
        # Inside the mouth: dark, wet.
        self.put(ellipsoid(self.h(0.0, -0.032, 0.025), H, Vector((0.064, 0.016, 0.068)), 14, 8), MOUTH, HEAD, (0.0, 0.7), CODE_MOUTH)
        self.put(ellipsoid(self.h(0.0, -0.025, -0.03), H, Vector((0.05, 0.03, 0.025)), 10, 6), mix(MOUTH, (0, 0, 0), 0.6), HEAD, (0.0, 0.3), CODE_MOUTH)
        # The lower jaw, narrower, to a pointed chin.
        J = self.jaw.to_3x3().normalized()
        to_jaw = self.jaw.inverted()
        hinge = V(self.j["hinge"])
        rings = []
        for i in range(ring_count):
            t = i / (ring_count - 1)
            z = z0 + 0.003 + (length - 0.006) * t
            depth = 0.024 * (1.0 - 0.2 * t)
            r = []
            for k in range(sides):
                a = math.tau * k / sides
                c, sn = math.cos(a), math.sin(a)
                y = low_lip(t) - 0.003 + (0.003 * sn if sn > 0 else depth * sn)
                r.append(self.jaw @ (Vector((low_width(t) * c, y, z)) - hinge))
            rings.append(r)
        mesh = subdivided(loft(rings, closed_end=True), sub)

        def jaw_colour(p, n):
            local = to_jaw @ p + hinge
            t = max(0.0, min(1.0, (local.z - z0) / length))
            lip = smooth(-0.008, 0.0, local.y - low_lip(t))
            return mix(mix(SKIN, BELLY, 0.3), LIP, lip)

        def jaw_code(p, n):
            local = to_jaw @ p + hinge
            t = max(0.0, min(1.0, (local.z - z0) / length))
            return 0.15 + 0.7 * smooth(-0.008, 0.0, local.y - low_lip(t))
        self.put(mesh, jaw_colour, JAW, (0.0, 0.15), jaw_code)
        self.put(ellipsoid(self.jaw @ (Vector((0.0, low_lip(0.5) - 0.006, 0.03)) - hinge), J, Vector((0.05, 0.009, 0.06)), 12, 6), MOUTH, JAW, (0.0, 0.7), CODE_MOUTH)
        chin = self.jaw @ (Vector((0.0, low_lip(1.0) - 0.022, 0.085)) - hinge)
        chin_tip = self.jaw @ (Vector((0.0, low_lip(1.0) - 0.048, 0.08)) - hinge)
        self.put(tube([chin + J @ Vector((0, 0.012, -0.008)), chin, chin.lerp(chin_tip, 0.6), chin_tip], [0.016, 0.014, 0.008, 0.0], 8), mix(SKIN, SOOT, 0.45), JAW, (0.0, 0.1), 0.45)
        # Needle teeth: a row along each lip, the upper ones over the lower lip.
        count = 13 if hi else (10 if self.detail == "lo" else 6)
        for upper in (True, False):
            for s in (1.0, -1.0):
                for k in range(count):
                    u = (k + (0.5 if upper else 0.0)) / count
                    t = 0.985 - 0.93 * u
                    z = z0 + length * t
                    if upper:
                        base = Vector((up_width(t) * 0.9 * s, up_lip(t) + 0.003, z))
                        long = (0.018 + 0.01 * math.sin(min(u * 2.2, 1.0) * math.pi)) * (1.4 if k in (1, 4) else 1.0) * self.uniform(0.85, 1.12)
                        tip = base + Vector((-0.1 * s, -1.0, 0.1)).normalized() * long
                        pts = [self.h(*(base + Vector((0, 0.004, 0)))), self.h(*base), self.h(*base.lerp(tip, 0.55)), self.h(*tip)]
                        weights = HEAD
                    else:
                        base = Vector((low_width(t) * 0.9 * s, low_lip(t) - 0.003, z + 0.002))
                        long = (0.013 + 0.007 * math.sin(min(u * 2.2, 1.0) * math.pi)) * self.uniform(0.85, 1.12)
                        tip = base + Vector((-0.08 * s, 1.0, 0.1)).normalized() * long
                        pts = [self.jaw @ (q - hinge) for q in [base + Vector((0, -0.004, 0)), base, base.lerp(tip, 0.55), tip]]
                        weights = JAW
                    r0 = 0.0038 if upper else 0.0034
                    self.put(tube(pts, [r0, r0, r0 * 0.5, 0.0], 5), TOOTH, weights, (0.0, 0.85), CODE_TOOTH)
        # Horns: two small, ridged, curving up and back.
        for s in (1.0, -1.0):
            base = Vector((0.034 * s, 0.062, 0.04))
            pts, radii = [], []
            steps = 10 if hi else 6
            for k in range(steps + 1):
                q = k / steps
                at = base + Vector((0.016 * s * q, 0.058 * q - 0.02 * q * q, -0.06 * q * q))
                pts.append(self.h(*(at - Vector((0, 0.014, 0)) * (1.0 if k == 0 else 0.0))))
                ridge = 1.0 + 0.1 * math.sin(q * 28.0)
                radii.append((0.0125 * (1.0 - q) ** 0.85 + 0.0006) * ridge if k < steps else 0.0)
            colour = lambda p, n: mix(HORN, SOOT, smooth(0.07, 0.11, (to_head @ p).y))
            self.put(tube(pts, radii, 7 if hi else 5), colour, HEAD, (0.0, 0.45), CODE_CLAW)

    def skull_soot(self, local, ln):
        """How sooty the skull is: dark round the eyes and on the crown, down the back of the head."""
        soot = 0.2 + 0.3 * smooth(0.0, 0.07, local.y) + 0.25 * smooth(0.3, 1.0, -ln.z)
        for s in (1.0, -1.0):
            eye_d = (local - Vector((0.04 * s, 0.027, 0.072))).length
            soot = max(soot, 0.7 * smooth(0.04, 0.018, eye_d))
        return min(soot, 0.85)

    def ears(self):
        """Big bat's ears: a pointed blade, cupped forward, ribbed inside, sooty at the tip."""
        hi = self.detail == "hi"
        rows, cols = (14, 9) if hi else (8, 5)
        head_up = self.head.to_3x3().col[1].normalized()
        for i, s in enumerate(["l", "r"]):
            sign = 1.0 if i == 0 else -1.0
            ear = xform(self.j["ears"][i])
            root = ear.translation
            out = ear.to_3x3().col[1].normalized()
            width = (head_up - out * head_up.dot(out)).normalized()
            face = out.cross(width).normalized() * sign
            # (the cupped face turned forward)
            if face.dot(self.head.to_3x3().col[2]) < 0:
                face = -face
            L = self.j["ear_long"]
            grid = []
            for r in range(rows):
                t = r / (rows - 1)
                notch = 1.0 - 0.18 * math.exp(-((t - 0.68) / 0.06) ** 2)
                half = 0.06 * (t ** 0.55) * (1.0 - t) ** 0.85 * 2.1 * notch + 0.004 * (1.0 - t)
                row = []
                for c in range(cols):
                    v = (c / (cols - 1)) * 2.0 - 1.0
                    # (a little more of it towards the back; cupped; three ribs in it)
                    across = half * (v * 0.9 + 0.15) * (1.0 if v < 0 else 1.15)
                    cup = -0.022 * (1.0 - v * v) * math.sin(math.pi * min(t * 1.1, 1.0))
                    rib = 0.0025 * math.cos(v * math.pi * 2.0) * math.sin(math.pi * t) if abs(v) < 0.9 else 0.0
                    # (the tip bending back over)
                    bend = -0.02 * t ** 3
                    row.append(root + out * (L * t) + width * across + face * (cup + rib + bend))
                grid.append(row)
            mesh = sheet(grid, 0.005, lambda p: face)
            if hi:
                mesh = subdivided(mesh, 1)
            to_ear = (root, out, face)

            def ear_colour(p, n, root=root, out=out, face=face):
                t = (p - root).dot(out) / L
                inside = smooth(-0.2, 0.4, n.dot(face))
                c = mix(SKIN, EAR_IN, inside * 0.85 * smooth(0.95, 0.6, t))
                return mix(c, SOOT, smooth(0.6, 0.95, t) * 0.85 + (1.0 - inside) * 0.2)

            def ear_weight(p, root=root, out=out, s=s):
                t = (p - root).dot(out) / L
                return {"ear_" + s: smooth(0.0, 0.25, t) + 0.001, "head": 1.0 - smooth(0.0, 0.25, t) + 0.001}
            self.put(mesh, ear_colour, ear_weight, (0.0, 0.1), CODE_EAR)

    def wings(self):
        """Stubby leathery wings: an arm and three fingers from the wrist, skin between, scalloped."""
        j = self.j
        for i, s in enumerate(["l", "r"]):
            sign = 1.0 if i == 0 else -1.0
            root, mid, tip = V(j["wing_roots"][i]), V(j["wing_mids"][i]), V(j["wing_tips"][i])
            arm = (mid - root).normalized()
            main = (tip - mid).normalized()
            plane = arm.cross(main).normalized()
            if plane.length < 0.5:
                plane = -self.front
            # Fingers fanning from the wrist, down towards the body.
            toward = (root - self.spine * 0.07 - mid).normalized()
            fingers = []
            for f, (k, long) in enumerate([(0.0, 0.1), (0.42, 0.085), (0.8, 0.065)]):
                way = (main * (1.0 - k) + toward * k).normalized()
                fingers.append(mid + way * long)
            attach = root - self.spine * 0.075 - self.front * 0.01
            rods = [(root, mid, 0.0065)] + [(mid, fp, 0.004) for fp in fingers]
            for a, b, r in rods:
                pts = [a, a.lerp(b, 0.5), b]
                self.put(tube(pts + [b + (b - a).normalized() * 0.004], [r, r * 0.8, r * 0.6, 0.0], 5), SOOT,
                         lambda p, a=a, b=b, s=s: {("wing_" if (a - root).length < 1e-6 else "wingtip_") + s: 1.0}, (0.0, 0.2), 0.95)
            # The claw at the wrist.
            self.put(tube([mid, mid + arm * 0.012 - plane * 0.003, mid + arm * 0.02 + toward * 0.006], [0.004, 0.002, 0.0], 5), CLAW, {"wing_" + s: 1.0}, (0.0, 0.55), CODE_CLAW)
            # The skin: a fan from the wrist, panel by panel, its edge scalloped.
            outline = [fingers[0], fingers[1], fingers[2], attach]
            bm_pts = []
            panels = []
            steps = 6 if self.detail == "hi" else 4
            for pi in range(len(outline) - 1):
                a, b = outline[pi], outline[pi + 1]
                for k in range(steps + (1 if pi == len(outline) - 2 else 0)):
                    q = k / steps
                    edge = a.lerp(b, q)
                    centre = mid.lerp(edge, 0.5)
                    # (scalloped: the skin's edge falls short between the fingertips)
                    scallop = 0.3 * math.sin(math.pi * q)
                    bm_pts.append(mid.lerp(edge, 1.0 - scallop))
            # The leading panel, between the arm and the first finger, root to wrist to tip.
            grid = []
            for r in range(4):
                q = r / 3.0
                grid.append([mid.lerp(p, q) if q > 0 else mid for p in bm_pts])
            mesh = sheet(grid, 0.003, lambda p, plane=plane: plane)
            self.put(mesh, lambda p, n: mix(WING, SOOT, 0.25), lambda p, s=s, mid=mid: {"wingtip_" + s: 0.7, "wing_" + s: 0.3}, (0.0, 0.2), CODE_WING)
            # And the skin between the arm and the body.
            grid = []
            for r in range(4):
                q = r / 3.0
                grid.append([root.lerp(mid, c / 3.0).lerp(attach.lerp(mid, c / 3.0 * 0.4), q) for c in range(4)])
            mesh = sheet(grid, 0.003, lambda p, plane=plane: plane)
            self.put(mesh, lambda p, n: mix(WING, SOOT, 0.3), lambda p, s=s: {"wing_" + s: 0.8, "chest": 0.2}, (0.0, 0.2), CODE_WING)

    # --- Putting it out ---

    def make(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.model = Model(self.bones)
        self.body()
        self.head_parts()
        self.ears()
        self.wings()
        self.surface.free()

    def build(self, out_name):
        self.make()
        data = bpy.data.armatures.new("Armature")
        armature = bpy.data.objects.new("Armature", data)
        bpy.context.collection.objects.link(armature)
        bpy.context.view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode="EDIT")
        for bone in self.bones:
            if bone in ("head", "jaw"):
                m = self.head if bone == "head" else self.jaw
                at = m.translation
                tail = at + m.to_3x3().normalized() @ Vector((0, 0, 0.05))
            else:
                at, end = self.segments[bone]
                tail = end if (end - at).length > 0.004 else at + Vector((0, 0.02, 0))
            eb = data.edit_bones.new(bone)
            eb.head = to_b(at)
            eb.tail = to_b(tail)
        bpy.ops.object.mode_set(mode="OBJECT")
        mesh = bpy.data.meshes.new(out_name)
        body = bpy.data.objects.new(out_name, mesh)
        bpy.context.collection.objects.link(body)
        for bone in self.bones:
            body.vertex_groups.new(name=bone)
        self.model.bm.to_mesh(mesh)
        self.model.bm.free()
        mesh.update()
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]
        mesh.color_attributes.active_color_index = mesh.color_attributes.find("Col")
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]
        body.parent = armature
        body.modifiers.new("Armature", "ARMATURE").object = armature
        os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
        path = os.path.join(FOLDER, "models", out_name + ".glb")
        export(path, True)
        print("BUILT %s verts=%d faces=%d" % (out_name, len(mesh.vertices), len(mesh.polygons)))
        if PREVIEW_DIR and self.detail == "hi":
            self.previews(body, out_name)

    def build_swarm(self):
        """The swarm's imp: posed on all fours, baked to one static mesh, its limbs tagged."""
        self.make()
        j = self.j
        moves = [xform(m) for m in j["fours_bones"]]
        fj = j["fours_joints"]
        groups = {}
        for b in self.bones:
            if b.endswith("_l") and (b.startswith("arm") or b.startswith("forearm") or b.startswith("hand") or b.startswith("fingers")):
                groups[b] = TAG_ARM_L
            elif b.endswith("_r") and (b.startswith("arm") or b.startswith("forearm") or b.startswith("hand") or b.startswith("fingers")):
                groups[b] = TAG_ARM_R
            elif b.endswith("_l") and (b.startswith("thigh") or b.startswith("shin") or b.startswith("foot")):
                groups[b] = TAG_LEG_L
            elif b.endswith("_r") and (b.startswith("thigh") or b.startswith("shin") or b.startswith("foot")):
                groups[b] = TAG_LEG_R
            elif b.startswith("tail"):
                groups[b] = TAG_TAIL
            elif b.startswith("wing"):
                groups[b] = TAG_WINGS
            elif b == "jaw":
                groups[b] = TAG_JAW
            elif b in ("head", "ear_l", "ear_r"):
                groups[b] = TAG_HEAD
            else:
                groups[b] = TAG_BODY
        pivots = {
            TAG_ARM_L: V(fj["roots"][0]), TAG_ARM_R: V(fj["roots"][1]), TAG_LEG_L: V(fj["roots"][2]), TAG_LEG_R: V(fj["roots"][3]),
            TAG_TAIL: V(fj["tail"][0]), TAG_WINGS: V(fj["wing_roots"][0]).lerp(V(fj["wing_roots"][1]), 0.5),
            TAG_JAW: V(fj["jaw_xform"]["origin"]), TAG_HEAD: V(fj["neck"]), TAG_BODY: V(fj["pelvis"]),
        }
        reach = {TAG_ARM_L: 0.6, TAG_ARM_R: 0.6, TAG_LEG_L: 0.42, TAG_LEG_R: 0.42, TAG_TAIL: 0.62, TAG_WINGS: 0.2, TAG_JAW: 0.13, TAG_HEAD: 0.2, TAG_BODY: 1.0}
        # Made coarser (a Decimate), each point keeping the bones and colour of
        # the nearest point it was made from.
        from mathutils.kdtree import KDTree
        whole = self.model.bm
        whole.verts.ensure_lookup_table()
        tree = KDTree(len(whole.verts))
        for vi, v in enumerate(whole.verts):
            tree.insert(v.co, vi)
        tree.balance()
        dense = bpy.data.meshes.new("dense")
        whole.to_mesh(dense)
        whole.free()
        obj = bpy.data.objects.new("dense", dense)
        bpy.context.collection.objects.link(obj)
        cut = obj.modifiers.new("Decimate", "DECIMATE")
        cut.ratio = SWARM_RATIO
        coarse = evaluated(obj)
        bm = bmesh.new()
        bm.from_mesh(coarse)
        bm.verts.ensure_lookup_table()
        bm.verts.index_update()
        uv0 = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
        uv1 = bm.loops.layers.uv.get("UV2") or bm.loops.layers.uv.new("UV2")
        tag_of = []
        code_of = []
        for v in bm.verts:
            near = tree.find(v.co)[1]
            p = from_b(v.co)
            weights = self.model.weights[near]
            posed = Vector()
            score = {}
            for bone, w in weights.items():
                posed += (moves[self.bones.index(bone)] @ p) * w
                g = groups[bone]
                score[g] = score.get(g, 0.0) + w
            tag = max(score, key=score.get) if score else TAG_BODY
            v.co = to_b(posed)
            out = min(1.0, (posed - pivots[tag]).length / reach[tag]) if tag != TAG_BODY else 0.0
            tag_of.append((tag, out))
            code_of.append(self.model.codes[near])
        for face in bm.faces:
            face.smooth = True
            for loop in face.loops:
                vi = loop.vert.index
                tag, out = tag_of[vi]
                loop[uv0].uv = ((tag + 0.5) / 16.0, 1.0 - out)
                code = code_of[vi]
                glow = 1.0 if code == CODE_EYE else 0.0
                loop[uv1].uv = (code / 8.0, 1.0 - glow)
        for layer in list(bm.verts.layers.float_color.values()):
            bm.verts.layers.float_color.remove(layer)
        mesh = bpy.data.meshes.new("imp_swarm")
        obj = bpy.data.objects.new("imp_swarm", mesh)
        bpy.context.collection.objects.link(obj)
        bm.normal_update()
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        # (the first UV, the limbs, must go out as the first: it is the active one)
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]
        mesh.uv_layers["UVMap"].active_render = True
        mesh.shade_smooth()
        os.makedirs(os.path.join(SWARM_FOLDER, "models"), exist_ok=True)
        export(os.path.join(SWARM_FOLDER, "models", "imp_swarm.glb"), False)
        info = {"pivots": {str(k): [v.x, v.y, v.z] for k, v in pivots.items()}, "tags": {
            "body": TAG_BODY, "arm_l": TAG_ARM_L, "arm_r": TAG_ARM_R, "leg_l": TAG_LEG_L, "leg_r": TAG_LEG_R,
            "tail": TAG_TAIL, "wings": TAG_WINGS, "jaw": TAG_JAW, "head": TAG_HEAD}, "codes": {
            "eye": CODE_EYE, "tooth": CODE_TOOTH, "mouth": CODE_MOUTH, "claw": CODE_CLAW, "wing": CODE_WING, "ear": CODE_EAR}}
        with open(os.path.join(SWARM_FOLDER, "models", "imp_swarm.json"), "w") as f:
            json.dump(info, f, indent="\t")
        print("BUILT imp_swarm verts=%d faces=%d" % (len(mesh.vertices), len(mesh.polygons)))
        if PREVIEW_DIR:
            self.previews(obj, "imp_swarm", swarm=True)

    def previews(self, body, name, swarm=False):
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX" if not swarm else "SINGLE"
        scene.display.shading.show_cavity = False
        scene.render.resolution_x, scene.render.resolution_y = 700, 700
        scene.world = bpy.data.worlds.new("World")
        scene.world.color = (0.35, 0.38, 0.42)
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.lens = 70
        scene.collection.objects.link(camera)
        scene.camera = camera
        head = to_b(self.h(0.0, 0.0, 0.04))
        whole = to_b(Vector((0.0, 0.48, 0.0)))
        views = [("whole_front", Vector((0.0, 0.15, 1.0)), whole, 2.4), ("whole_quarter", Vector((0.8, 0.3, 0.8)), whole, 2.4),
                 ("whole_side", Vector((1.0, 0.1, 0.0)), whole, 2.4), ("whole_back", Vector((-0.4, 0.3, -1.0)), whole, 2.4),
                 ("face_front", Vector((0.0, 0.05, 1.0)), head, 0.85), ("face_quarter", Vector((0.7, 0.15, 0.8)), head, 0.85),
                 ("face_side", Vector((1.0, 0.05, 0.05)), head, 0.95), ("face_low", Vector((0.3, -0.35, 1.0)), head, 0.85)]
        if swarm:
            views = views[:3]
        for view, direction, target, far in views:
            offset = to_b(direction.normalized()) * far
            camera.location = target + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)


def export(path, skins):
    options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=skins,
                   export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True, use_selection=False)
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)


if __name__ == "__main__":
    Imp("hi").build("imp")
    Imp("lo").build("imp_lo")
    Imp("swarm").build_swarm()
