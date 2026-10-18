"""Builds the colossus and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/colossus/tools/build_colossus.py [-- <preview folder>]

Writes creatures/colossus/models/colossus.glb and colossus_lo.glb, and (given a
folder) renders previews into it.

A giant after Shadow of the Colossus: a hunched, heavy body of dark, matted fur
over earth, armoured in slabs of weathered, carved stone with moss and grass
growing on them, and a pale glow in its eyes and in the runes cut into its
stone. It is modelled 10 units tall (each unit is 10 m in The Clearing), in
Godot's axes (Y up, facing +Z, +X its left), turned to Blender's only as it is
made.

- The body is a metaball sculpture (capsules for the limbs and the trunk,
  ellipsoids for the great muscles: the hump of its back, the chest, the
  shoulders, calves and forearms), made into a mesh, roughened by noise into
  lumps of earth and matted shag (`shag`), and decimated.
- The armour is shells of stone fitted to the body by casting rays out to it
  from the bone inside (`plate`): each a curved slab with a broken, chipped
  outline, a bevelled edge, bands cut across it, and on some a line of runes
  cut into it that glow. Flat-shaded, so that it reads as cut stone. Moss on
  whatever faces up, rain stains running down.
- Hands of stone: a hide palm and thick fingers of stone blocks. Feet: great
  blocks of stone like the footings of a wall.
- The head is a stone mask: a heavy brow over two deep holes with pale eyes
  in them, a flat face, a jaw; fur hangs round it in a mane and a beard.
- Fur: clumps (tapering three-sided strands) hanging from everywhere the stone
  does not cover; grass in tufts, and vines hanging, on the stone; a small
  gnarled tree on its left shoulder.
- Colours are vertex colours. The first UV says how much a point glows (x)
  and what it is (y: 0 fur or hide, 1 stone, 2 a plant); the second is where
  it was on the standing body, for the shader's grain and streaks
  (ColossusLook).
- The skeleton is the BONES below, none the child of another (Colossus poses
  each where it is to be), each from one joint to the next. The body is
  weighted by how near each point is to each bone; the stone, the hands'
  fingers and the feet go each with one bone, so they stay rigid.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector, noise
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

# --- The skeleton (Godot space, units of 10 m) ---

PELVIS = Vector((0.0, 7.0, 0.0))
WAIST = Vector((0.0, 7.55, -0.08))
CHEST = Vector((0.0, 8.3, -0.2))
NECK = Vector((0.0, 9.1, -0.12))
HEAD = Vector((0.0, 10.2, 0.22))
HEAD_TIP = Vector((0.0, 10.9, 0.38))
ARM_OUT = math.radians(18.0)
# How big its head is, as a share of the mask modelled in `head` (small, on a long neck).
HEAD_SCALE = 0.55


def side_v(v, s):
    return Vector((v.x * s, v.y, v.z))


SHOULDER = Vector((0.78, 8.95, -0.14))
# (arms and legs far longer than its body: a spindly thing that crawls like a spider)
UPPER_ARM = 3.3
FOREARM = 3.3
PALM = 0.55
# Half the width of the palm.
PALM_HALF = 0.26
FINGERS = 0.8
# The index finger, long and slender: what it crushes with.
INDEX = 1.1
HIP = Vector((0.38, 6.9, 0.0))
KNEE = Vector((0.46, 3.55, 0.14))
ANKLE = Vector((0.5, 0.36, -0.04))
TOE = Vector((0.52, 0.04, 1.05))


def arm_dir(s):
    return Vector((s * math.sin(ARM_OUT), -math.cos(ARM_OUT), 0.06)).normalized()


def arm_joints(s):
    sh = side_v(SHOULDER, s)
    d = arm_dir(s)
    el = sh + d * UPPER_ARM
    wr = el + d * FOREARM
    kn = wr + d * PALM
    tip = kn + d * FINGERS
    return sh, el, wr, kn, tip


def index_joints(s):
    """The index finger's knuckle and tip (beside the thumb, on the inside of the hand)."""
    sh, el, wr, kn, tip = arm_joints(s)
    d = arm_dir(s)
    # (the hand's own left, square to it: see frame_of)
    y = -d
    x = (Vector((1, 0, 0)) - y * y.x)
    z = Vector((0, 0, 1)) - y * y.z
    z.normalize()
    x = (x - z * z.x).normalized()
    base = kn + x * (-s) * PALM_HALF * 0.78
    return base, base + d * INDEX


def leg_joints(s):
    return side_v(HIP, s), side_v(KNEE, s), side_v(ANKLE, s), side_v(TOE, s)


SIDES = (("l", 1.0), ("r", -1.0))


def bone_segments():
    seg = {
        "pelvis": (PELVIS, WAIST),
        "spine": (WAIST, CHEST),
        "chest": (CHEST, NECK),
        "neck": (NECK, HEAD),
        "head": (HEAD, HEAD_TIP),
    }
    for name, s in SIDES:
        sh, el, wr, kn, tip = arm_joints(s)
        seg["upper_arm_" + name] = (sh, el)
        seg["forearm_" + name] = (el, wr)
        seg["hand_" + name] = (wr, kn)
        seg["fingers_" + name] = (kn, tip)
        seg["index_" + name] = index_joints(s)
        hp, k, a, t = leg_joints(s)
        seg["thigh_" + name] = (hp, k)
        seg["shin_" + name] = (k, a)
        seg["foot_" + name] = (a, t)
    return seg


BONES = ["pelvis", "spine", "chest", "neck", "head"]
for _n, _s in SIDES:
    BONES += ["upper_arm_" + _n, "forearm_" + _n, "hand_" + _n, "fingers_" + _n, "thigh_" + _n, "shin_" + _n, "foot_" + _n]
BONES += ["index_l", "index_r"]
SEGMENTS = bone_segments()

# --- Colours ---

FUR = (0.075, 0.062, 0.05)
FUR_WARM = (0.13, 0.095, 0.065)
FUR_MOSS = (0.11, 0.12, 0.07)
EARTH = (0.16, 0.12, 0.085)
STONE = (0.34, 0.335, 0.31)
STONE_DARK = (0.18, 0.18, 0.17)
STONE_PALE = (0.47, 0.46, 0.42)
MOSS = (0.2, 0.26, 0.1)
MOSS_DARK = (0.12, 0.17, 0.07)
GRASS = (0.34, 0.37, 0.18)
GLOW = (0.78, 0.92, 1.0)
HIDE = (0.17, 0.15, 0.13)
BARK = (0.2, 0.17, 0.13)
LEAF = (0.2, 0.25, 0.13)

FUR_KIND, STONE_KIND, PLANT_KIND = 0.0, 1.0, 2.0


def to_b(p):
    return Vector((p.x, -p.z, p.y))


def from_b(p):
    return Vector((p.x, p.z, -p.y))


def smooth(a, b, x):
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def scale_c(c, k):
    return tuple(min(1.0, c[i] * k) for i in range(3))


def dist_segment(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def fbm(p, octaves=3):
    return noise.fractal(p, 0.6, 2.1, octaves, noise_basis="PERLIN_ORIGINAL")


def frame_of(axis):
    """(left, along, front) for a bone along `axis`: its own left (+X) and front
    (+Z) made square to it, whichever way it points. An angle round it of 0 is
    its front and of pi/2 its left."""
    y = axis.normalized()
    z = Vector((0, 0, 1)) - y * y.z
    if z.length < 1e-3:
        z = Vector((0, 1, 0)) - y * y.y
    z.normalize()
    x = Vector((1, 0, 0)) - y * y.x - z * z.x
    x.normalize()
    return x, y, z


def basis_along(y, side):
    """A basis (columns x, y, z) whose y is `y`, with x as near `side` as can be."""
    y = y.normalized()
    z = side.cross(y)
    if z.length < 1e-4:
        z = Vector((0, 0, 1)).cross(y)
    z.normalize()
    x = y.cross(z).normalized()
    return x, y, z


class Model:
    """The mesh as it is put together, in Godot space, with each vertex's colour,
    UVs, normal and weights."""

    def __init__(self):
        self.co = []
        self.normal = []
        self.colour = []
        self.uv0 = []
        self.uv1 = []
        self.weights = []
        self.faces = []

    def vert(self, p, n, colour, uv0, weights):
        self.co.append(p.copy())
        self.normal.append(n.normalized() if n.length > 1e-8 else Vector((0, 1, 0)))
        self.colour.append(colour)
        self.uv0.append(uv0)
        # (where it was on the standing body, seen along whichever axis it faces
        # most: for the shader's grain, which so stays put on it)
        a = self.normal[-1]
        if abs(a.y) >= abs(a.x) and abs(a.y) >= abs(a.z):
            self.uv1.append((p.x, p.z))
        elif abs(a.x) >= abs(a.z):
            self.uv1.append((p.z, p.y))
        else:
            self.uv1.append((p.x, p.y))
        total = sum(weights.values()) or 1.0
        self.weights.append({k: w / total for k, w in weights.items() if w / total > 0.01})
        return len(self.co) - 1

    def face(self, idx):
        self.faces.append(tuple(idx))

    def flat(self, points, colour, uv0, weights, normal=None):
        """A face with vertices of its own, its normal its own (cut stone)."""
        a, b, c = points[0], points[1], points[2]
        n = normal if normal is not None else (b - a).cross(c - a)
        if n.length < 1e-10 and len(points) > 3:
            n = (c - a).cross(points[3] - a)
        idx = [self.vert(p, n, colour, uv0, weights) for p in points]
        self.face(idx)

    def tris(self):
        return sum(len(f) - 2 for f in self.faces)


def nearest_bones(p, among=None, count=3, power=4.0):
    found = []
    for bone, (a, b) in SEGMENTS.items():
        if among is not None and bone not in among:
            continue
        found.append((dist_segment(p, a, b), bone))
    found.sort()
    weights = {}
    for d, bone in found[:count]:
        weights[bone] = 1.0 / (d ** power + 1e-6)
    best = max(weights.values())
    return {k: w for k, w in weights.items() if w > best * 0.03}


def evaluated_mesh(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    return mesh


class Colossus:
    def __init__(self, low):
        self.low = low
        self.model = Model()
        self.rng = random.Random(7)
        self.plate_bms = []

    def uniform(self, a, b):
        return self.rng.uniform(a, b)

    # --- The body -------------------------------------------------------

    def body(self):
        mball = bpy.data.metaballs.new("Body")
        mball.resolution = 0.1 if self.low else 0.05
        mball.render_resolution = mball.resolution
        mball.threshold = 0.6
        obj = bpy.data.objects.new("BodyBall", mball)
        bpy.context.collection.objects.link(obj)

        def ball(at, radius, stiff=2.0):
            e = mball.elements.new(type="BALL")
            e.co = to_b(at)
            e.radius = radius / 0.575
            e.stiffness = stiff

        def ellipsoid(at, radii, along=None, side=Vector((1, 0, 0)), stiff=2.0):
            e = mball.elements.new(type="ELLIPSOID")
            e.co = to_b(at)
            r = max(radii)
            e.radius = r / 0.575
            e.size_x, e.size_y, e.size_z = radii[0] / r, radii[2] / r, radii[1] / r
            if along is not None:
                x, y, z = basis_along(along, side)
                m = Matrix((to_b(x), to_b(-z), to_b(y))).transposed()
                e.rotation = m.to_quaternion()
            e.stiffness = stiff

        def capsule(a, b, radius, stiff=2.0):
            e = mball.elements.new(type="CAPSULE")
            d = b - a
            e.co = to_b((a + b) * 0.5)
            e.radius = radius / 0.575
            # (a capsule's length is its own, not a share of its radius)
            e.size_x = d.length * 0.5
            e.rotation = Vector((1, 0, 0)).rotation_difference(to_b(d).normalized())
            e.stiffness = stiff

        # A narrow cage of ribs over a sunken belly and a small pelvis; a hunched
        # spine of knobs down its back; a long, stringy neck.
        ellipsoid(PELVIS + Vector((0, -0.05, -0.04)), (0.46, 0.34, 0.32))
        capsule(PELVIS, CHEST, 0.2)
        ellipsoid(WAIST + Vector((0, 0.05, 0.02)), (0.3, 0.32, 0.24))
        ellipsoid(CHEST + Vector((0, 0.15, 0.05)), (0.56, 0.62, 0.4))
        ellipsoid(CHEST + Vector((0, 0.55, -0.05)), (0.62, 0.32, 0.36))
        for k in range(9):
            at = WAIST.lerp(NECK, k / 8.0) + Vector((0, 0, -0.3 - 0.12 * math.sin(math.pi * k / 8.0)))
            ball(at, 0.11 + 0.03 * math.sin(math.pi * k / 8.0))
        capsule(NECK, HEAD + Vector((0, 0.15, 0)), 0.12)
        for k in range(4):
            ball(NECK.lerp(HEAD, (k + 0.5) / 4.0) + Vector((0, 0, -0.1)), 0.13)
        for name, s in SIDES:
            sh, el, wr, kn, tip = arm_joints(s)
            hp, k_, a, t = leg_joints(s)
            # Collarbones and points of shoulder; long thin arms with knobs of elbows.
            capsule(NECK + Vector((0.1 * s, -0.1, 0.05)), sh, 0.08)
            ball(sh, 0.21)
            capsule(sh, el, 0.15)
            ball(el, 0.22)
            capsule(el, wr, 0.13)
            ellipsoid(el.lerp(wr, 0.22), (0.17, 0.5, 0.17), along=wr - el)
            ball(wr, 0.15)
            # Long thin legs, knobs of knees, stringy shins.
            ball(hp, 0.26)
            capsule(hp, k_, 0.19)
            ellipsoid(hp.lerp(k_, 0.3), (0.24, 0.8, 0.24), along=k_ - hp)
            ball(k_, 0.27)
            capsule(k_, a, 0.14)
            ellipsoid(k_.lerp(a, 0.25) + Vector((0, 0, -0.06)), (0.18, 0.6, 0.18), along=a - k_)
            ball(a, 0.17)

        bpy.context.view_layer.update()
        mesh = evaluated_mesh(obj)
        bpy.data.objects.remove(obj)
        body = bpy.data.objects.new("Body", mesh)
        bpy.context.collection.objects.link(body)
        # Even it out a little, and bring it down to its count of faces.
        sm = body.modifiers.new("Smooth", "SMOOTH")
        sm.factor = 0.5
        sm.iterations = 4
        dec = body.modifiers.new("Decimate", "DECIMATE")
        target = 2200 if self.low else 7000
        dec.ratio = min(1.0, target / max(len(mesh.polygons), 1))
        final = evaluated_mesh(body)
        bpy.data.objects.remove(body)
        bpy.data.meshes.remove(mesh)

        bm = bmesh.new()
        bm.from_mesh(final)
        bpy.data.meshes.remove(final)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.normal_update()
        # Earth and shag: lumps all over, and the fur matted into long streaks
        # that run down it.
        for v in bm.verts:
            p = from_b(v.co)
            n = from_b(v.normal)
            lump = fbm(p * 2.4, 3) * 0.025
            streak = noise.noise(Vector((p.x * 12.0, p.y * 1.5, p.z * 12.0))) * 0.018
            v.co = to_b(p + n * (lump + streak))
        bm.normal_update()
        self.body_bm = bm.copy()
        self.body_bvh = BVHTree.FromBMesh(self.body_bm)

        index = {}
        for v in bm.verts:
            p = from_b(v.co)
            n = from_b(v.normal)
            index[v] = self.model.vert(p, n, self.fur_colour(p, n), (0.0, FUR_KIND), nearest_bones(p))
        for f in bm.faces:
            self.model.face([index[v] for v in f.verts])
        bm.free()

    def fur_colour(self, p, n):
        k = fbm(p * 0.9, 2)
        c = mix(FUR, FUR_WARM, smooth(-0.3, 0.6, k))
        # (moss in the fur of its back and shoulders, earth low down)
        c = mix(c, FUR_MOSS, smooth(0.2, 0.9, n.y) * smooth(6.0, 7.8, p.y) * 0.7)
        c = mix(c, EARTH, smooth(2.5, 0.6, p.y) * 0.5)
        return c

    def on_body(self, origin, direction):
        """Where a ray from inside the body leaves it (Godot), or None."""
        hit = self.body_bvh.ray_cast(to_b(origin), to_b(direction).normalized(), 6.0)
        if hit[0] is None:
            return None, None
        return from_b(hit[0]), from_b(hit[1])

    # --- Stone ----------------------------------------------------------

    def stone_colour(self, p, n, edge=0.0, groove=0.0):
        k = fbm(p * 0.7, 3)
        c = mix(STONE_DARK, STONE, smooth(-0.7, 0.2, k))
        c = mix(c, STONE_PALE, smooth(0.2, 0.9, k) * 0.5)
        # Rain stains running down from its edges and joints.
        stain = noise.noise(Vector((p.x * 3.0, p.y * 0.35, p.z * 3.0)))
        c = scale_c(c, 1.0 - smooth(0.1, 0.7, stain) * 0.25)
        c = scale_c(c, 1.0 - 0.35 * smooth(-0.1, 0.5, fbm(p * 0.45 + Vector((3.0, 0, 0)), 2)))
        c = mix(c, STONE_PALE, edge * 0.4)
        c = scale_c(c, 1.0 - groove * 0.5)
        # Moss on whatever faces up.
        up = n.y + fbm(p * 1.6, 2) * 0.6
        moss = smooth(0.4, 0.8, up)
        c = mix(c, mix(MOSS_DARK, MOSS, smooth(-0.3, 0.5, fbm(p * 2.0, 2))), moss)
        return c, moss

    def plate(self, bone, along, angles, gap=0.04, thick=0.16, cells=(14, 10), runes=0, bands=(),
              roughness=0.6, tufts=0.0, vines=0, seed=0, tilt=0.0, cap=None, fringe=0.0):
        """A slab of stone fitted over the body round bone `bone`'s segment from
        `along[0]` to `along[1]` (shares of it), round it from `angles[0]` to
        `angles[1]` (radians from its front towards its left), standing `gap`
        off the body, `thick` thick. `runes`: a line of that many glyphs cut
        down the middle of it that glow; `bands`: shares across it with a
        groove cut along them. `cap`: (centre, axis, half angle across, half
        angle along) to fit it as a cap over a joint instead, by rays from
        `centre` round `axis` (a pauldron, a knee)."""
        a, b = SEGMENTS[bone]
        axis = b - a
        x, y, z = frame_of(axis)
        rng = random.Random(seed + 1000 * len(self.plate_bms))
        nu, nt = cells
        if self.low:
            nu, nt = max(4, nu // 2), max(3, nt // 2)
        # The outline: a rounded square in (u, t), broken by noise at its edge.
        grid = []
        for j in range(nt + 1):
            row = []
            for i in range(nu + 1):
                su = i / nu * 2.0 - 1.0
                st = j / nt * 2.0 - 1.0
                # (corners rounded off)
                cu = su * math.sqrt(max(0.0, 1.0 - 0.35 * st * st))
                ct = st * math.sqrt(max(0.0, 1.0 - 0.35 * su * su))
                edge = max(abs(su), abs(st))
                chip = noise.noise(Vector((su * 2.3 + seed, st * 2.3, 0.5 + len(self.plate_bms)))) * 0.12 * smooth(0.6, 1.0, edge)
                cu *= 1.0 + chip
                ct *= 1.0 + chip
                u = angles[0] + (angles[1] - angles[0]) * (cu + 1.0) * 0.5
                t = along[0] + (along[1] - along[0]) * (ct + 1.0) * 0.5
                row.append((u, t, edge, cu, ct))
            grid.append(row)
        # How far out the body is under each point, smoothed so that the slab is
        # a clean curve and not every lump of the body.
        dist = []
        dirs = []
        origins = []
        for j in range(nt + 1):
            drow, dirrow, orow = [], [], []
            for i in range(nu + 1):
                u, t, _e, cu, ct = grid[j][i]
                if cap is not None:
                    o = cap[0]
                    e1 = cap[1].cross(Vector((0, 1, 0)) if abs(cap[1].y) < 0.9 else Vector((0, 0, 1))).normalized()
                    e2 = e1.cross(cap[1]).normalized()
                    d = (cap[1].normalized() + e1 * math.tan(cu * cap[2]) + e2 * math.tan(ct * cap[3])).normalized()
                else:
                    o = a + axis * t
                    d = z * math.cos(u) + x * math.sin(u)
                    d = (d + y * tilt).normalized()
                hit, _n = self.on_body(o, d)
                r = (hit - o).length if hit is not None else 0.8
                drow.append(r)
                dirrow.append(d)
                orow.append(o)
            dist.append(drow)
            dirs.append(dirrow)
            origins.append(orow)
        raw = [row[:] for row in dist]
        for _pass in range(4):
            new = [row[:] for row in dist]
            for j in range(nt + 1):
                for i in range(nu + 1):
                    acc, cnt = dist[j][i] * 2.0, 2.0
                    for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        jj, ii = j + dj, i + di
                        if 0 <= jj <= nt and 0 <= ii <= nu:
                            acc += dist[jj][ii]
                            cnt += 1.0
                    new[j][i] = max(acc / cnt, raw[j][i])
            dist = new
        # Runes: glyphs down the middle line, each a few strokes on a 3 x 4 grid of cells.
        glyph = set()
        if runes and not self.low:
            per = nt // max(runes, 1)
            mid = nu // 2
            for g in range(runes):
                j0 = g * per + max(0, (per - 4) // 2)
                strokes = [((1, 0), (1, 3))]
                for _k in range(rng.randint(1, 3)):
                    r0 = rng.randint(0, 3)
                    c0 = rng.choice((0, 2))
                    strokes.append(((c0, r0), (1, min(3, r0 + rng.choice((0, 1))))))
                for (c0, r0), (c1, r1) in strokes:
                    steps = max(abs(c1 - c0), abs(r1 - r0)) + 1
                    for k in range(steps):
                        f = k / max(steps - 1, 1)
                        ci = round(c0 + (c1 - c0) * f)
                        ri = round(r0 + (r1 - r0) * f)
                        glyph.add((mid - 1 + ci, j0 + ri))
        band_rows = set(round(bnd * nt) for bnd in bands)

        outer = []
        inner = []
        for j in range(nt + 1):
            orow, irow = [], []
            for i in range(nu + 1):
                o, d, r = origins[j][i], dirs[j][i], dist[j][i]
                base = o + d * (r + gap)
                # (worn and broken: lumps, and the odd chip out of it)
                lump = fbm(base * 2.6 + Vector((seed, 0, 0)), 3) * roughness * thick
                lump -= smooth(0.45, 0.8, noise.noise(base * 5.0 + Vector((0, seed, 0)))) * thick * 0.35
                rim = i in (0, nu) or j in (0, nt)
                # (the rim cut off in a narrow chamfer)
                bevel = thick * 0.5 if rim else 0.0
                cut = thick * 0.4 if j in band_rows and not rim else 0.0
                orow.append(base + d * (thick + lump - bevel - cut))
                irow.append(base)
            outer.append(orow)
            inner.append(irow)

        weights = {bone: 1.0}
        bm_faces = []

        def put(points, colour, glow=0.0):
            self.model.flat(points, colour, (glow, STONE_KIND), weights)
            bm_faces.append(points)

        def quad_at(j, i):
            quad = [outer[j][i], outer[j][i + 1], outer[j + 1][i + 1], outer[j + 1][i]]
            n = (quad[2] - quad[0]).cross(quad[3] - quad[1])
            if n.dot(dirs[j][i]) < 0:
                n = -n
            return quad, n.normalized()

        def interior(j, i):
            return 0 < i < nu - 1 and 0 < j < nt - 1 and (i, j) not in glyph

        # The face of it: one smooth surface (so that it reads as worn stone, not
        # as facets), each point's normal the mean of the faces round it.
        normals = {}
        for j in range(nt):
            for i in range(nu):
                if interior(j, i):
                    _q, n = quad_at(j, i)
                    for key in ((j, i), (j, i + 1), (j + 1, i + 1), (j + 1, i)):
                        normals[key] = normals.get(key, Vector()) + n
        index = {}
        for key, n in normals.items():
            j, i = key
            p = outer[j][i]
            groove = 1.0 if j in band_rows else 0.0
            c, moss = self.stone_colour(p, n.normalized(), 0.0, groove)
            index[key] = self.model.vert(p, n, c, (0.0, STONE_KIND), weights)
        for j in range(nt):
            for i in range(nu):
                quad, n = quad_at(j, i)
                centre = sum(quad, Vector()) / 4.0
                if (i, j) in glyph:
                    # (cut in, and lit from inside)
                    depth = thick * 0.45
                    sunk = [p - dirs[j][i] * depth for p in quad]
                    put(sunk, GLOW, 1.0)
                    for k in range(4):
                        p0, p1 = quad[k], quad[(k + 1) % 4]
                        put([p0, p1, sunk[(k + 1) % 4], sunk[k]], STONE_DARK)
                    continue
                if interior(j, i):
                    self.model.face([index[(j, i)], index[(j, i + 1)], index[(j + 1, i + 1)], index[(j + 1, i)]])
                    bm_faces.append(quad)
                    c, moss = self.stone_colour(centre, n)
                    if tufts > 0.0 and moss > 0.5 and rng.random() < tufts:
                        self.tuft(centre, n, weights, rng)
                    continue
                # The chamfer round its edge: flat, pale where it is worn.
                c, _m = self.stone_colour(centre, n, 0.7)
                put(quad, c)
        # The rim, down to the body (its underside lies against the body, unseen).
        ring = [(i, 0) for i in range(nu)] + [(nu, j) for j in range(nt)] + [(i, nt) for i in range(nu, 0, -1)] + [(0, j) for j in range(nt, 0, -1)]
        for k in range(len(ring)):
            i0, j0 = ring[k]
            i1, j1 = ring[(k + 1) % len(ring)]
            quad = [outer[j0][i0], outer[j1][i1], inner[j1][i1], inner[j0][i0]]
            mid = sum(quad, Vector()) / 4.0
            n = (quad[1] - quad[0]).cross(quad[3] - quad[0])
            out = mid - (origins[j0][i0] + origins[j1][i1]) * 0.5
            out = out - y * out.dot(y)
            if n.dot(out) < 0:
                quad.reverse()
            c, _m = self.stone_colour(mid, Vector((0, -0.2, 0)), 0.6)
            self.model.flat(quad, scale_c(c, 0.8), (0.0, STONE_KIND), weights)
        # Its lowest edge: vines hang from it, and fur from under it.
        edges = [[(i, 0) for i in range(nu + 1)], [(i, nt) for i in range(nu + 1)], [(0, j) for j in range(nt + 1)], [(nu, j) for j in range(nt + 1)]]
        lowest = min(edges, key=lambda e: sum(outer[j][i].y for i, j in e) / len(e))
        for _v in range(vines if not self.low else vines // 2):
            i, j = lowest[rng.randint(1, len(lowest) - 2)]
            self.vine(outer[j][i], dirs[j][i], rng.uniform(0.6, 1.5), weights, rng)
        if fringe > 0.0:
            for i, j in lowest[1:-1]:
                if rng.random() > fringe * (0.5 if self.low else 1.0):
                    continue
                root = inner[j][i] + dirs[j][i] * thick * 0.3
                length = rng.uniform(0.45, 1.0)
                colour = scale_c(mix(FUR, FUR_WARM, rng.random() * 0.7), rng.uniform(0.8, 1.15))
                self.clump(root, Vector((0, -1, 0)), length, length * 0.32, dirs[j][i], colour, weights, rings=2 if self.low else 3)
        self.plate_bms.append(bm_faces)

    # --- Plants ----------------------------------------------------------

    def tuft(self, at, n, weights, rng):
        """A tuft of grass: a few thin bent blades, each a folded pair of triangles."""
        blades = 3 if self.low else 5
        for _k in range(blades):
            a = rng.uniform(0, math.tau)
            base = at + Vector((math.cos(a), 0, math.sin(a))) * rng.uniform(0.0, 0.08)
            lean = Vector((math.cos(a), 0, math.sin(a))) * rng.uniform(0.02, 0.09)
            h = rng.uniform(0.09, 0.2)
            up = (n * 0.5 + Vector((0, 1, 0))).normalized()
            tip = base + up * h + lean
            across = up.cross(Vector((math.cos(a + 1.3), 0, math.sin(a + 1.3)))).normalized() * 0.012
            mid = base + up * h * 0.5 + lean * 0.3 + n * 0.006
            c = mix(GRASS, MOSS, rng.random())
            self.model.flat([base - across, base + across, tip], c, (0.0, PLANT_KIND), weights, normal=up)
            self.model.flat([base + across, mid, tip], scale_c(c, 0.8), (0.0, PLANT_KIND), weights, normal=up)
            self.model.flat([mid, base - across, tip], scale_c(c, 0.9), (0.0, PLANT_KIND), weights, normal=up)

    def vine(self, start, out, length, weights, rng):
        """A vine hanging down from `start`, a little out from the surface, with leaves."""
        segs = 4 if self.low else 7
        sides = 3 if self.low else 4
        r = 0.022
        pts = []
        sway = rng.uniform(-0.15, 0.15)
        for k in range(segs + 1):
            f = k / segs
            pts.append(start + out * (0.03 + 0.08 * math.sin(f * 2.5)) + Vector((sway * f * f, -length * f, sway * 0.5 * f)))
        rings = []
        for k, p in enumerate(pts):
            d = (pts[min(k + 1, segs)] - pts[max(k - 1, 0)]).normalized()
            x, y, z = basis_along(d, Vector((1, 0, 0)))
            rr = r * (1.0 - 0.6 * k / segs)
            rings.append([p + (x * math.cos(math.tau * s / sides) + z * math.sin(math.tau * s / sides)) * rr for s in range(sides)])
        for k in range(segs):
            for s in range(sides):
                quad = [rings[k][s], rings[k][(s + 1) % sides], rings[k + 1][(s + 1) % sides], rings[k + 1][s]]
                n = (sum(quad, Vector()) / 4.0) - (pts[k] + pts[k + 1]) * 0.5
                self.model.flat(quad, scale_c(LEAF, 0.7), (0.0, PLANT_KIND), weights, normal=n)
            if not self.low:
                a = rng.uniform(0, math.tau)
                leaf_dir = Vector((math.cos(a), -0.4, math.sin(a))).normalized()
                p = pts[k]
                w = leaf_dir.cross(Vector((0, 1, 0))).normalized() * 0.03
                self.model.flat([p, p + leaf_dir * 0.07 + w, p + leaf_dir * 0.12], LEAF, (0.0, PLANT_KIND), weights, normal=Vector((0, 1, 0)))
                self.model.flat([p, p + leaf_dir * 0.12, p + leaf_dir * 0.07 - w], scale_c(LEAF, 0.85), (0.0, PLANT_KIND), weights, normal=Vector((0, 1, 0)))

    def tree(self, at, weights):
        """A small, gnarled, wind-bent tree, rooted in the moss on its shoulder."""
        rng = random.Random(3)
        sides = 5
        pts = [at + Vector((0.03 * k, 0.11 * k, -0.025 * k * k)) for k in range(6)]
        for k in range(5):
            r0 = 0.05 * (1.0 - k / 6.0)
            r1 = 0.05 * (1.0 - (k + 1) / 6.0)
            for s in range(sides):
                a0, a1 = math.tau * s / sides, math.tau * (s + 1) / sides
                q = [pts[k] + Vector((math.cos(a0), 0, math.sin(a0))) * r0, pts[k] + Vector((math.cos(a1), 0, math.sin(a1))) * r0,
                     pts[k + 1] + Vector((math.cos(a1), 0, math.sin(a1))) * r1, pts[k + 1] + Vector((math.cos(a0), 0, math.sin(a0))) * r1]
                q.reverse()
                self.model.flat(q, BARK, (0.0, PLANT_KIND), weights)
        # The crown: lumps of leaves.
        for c in range(4 if self.low else 7):
            centre = pts[-1] + Vector((rng.uniform(-0.14, 0.14), rng.uniform(-0.08, 0.08), rng.uniform(-0.14, 0.1)))
            radius = rng.uniform(0.07, 0.12)
            bm = bmesh.new()
            bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
            for v in bm.verts:
                v.co = v.co * Vector((1.0, 0.75, 1.0)) + v.co * rng.uniform(-0.15, 0.15)
            for f in bm.faces:
                pts_f = [centre + Vector((v.co.x, v.co.z, -v.co.y)) for v in f.verts]
                nn = sum(pts_f, Vector()) / len(pts_f) - centre
                shade = 0.7 + 0.5 * max(0.0, nn.normalized().y)
                pts_f.reverse()
                self.model.flat(pts_f, scale_c(LEAF, shade), (0.0, PLANT_KIND), weights)
            bm.free()

    # --- Fur ---------------------------------------------------------------

    def clump(self, root, hang, length, width, out, colour, weights, rings=3):
        """A tapering strand of fur from `root`, hanging along `hang` and lying
        over `out` (laid along the surface, standing off it only a little).
        Its normals are bent out from the body, so a coat of them takes the
        light as one soft mass and only its edge is ragged."""
        sides = 3
        out = out.normalized()
        hang = hang.normalized()
        hang = (hang - out * hang.dot(out) + out * 0.12).normalized()
        across = out.cross(hang)
        if across.length < 1e-6:
            across = Vector((1, 0, 0))
        across.normalize()
        lift = hang.cross(across).normalized()
        if lift.dot(out) < 0:
            lift = -lift
        normal = (out + hang * 0.15).normalized()
        ring_idx = []
        for r in range(rings):
            s = r / rings
            centre = root + hang * length * s + lift * width * 0.3 * s - Vector((0, 1, 0)) * length * 0.15 * s * s
            w = width * (1.0 - s * 0.8)
            ring = []
            for k in range(sides):
                a = math.tau * k / sides + 0.5
                p = centre + across * math.cos(a) * w * 0.5 + lift * math.sin(a) * w * 0.4
                ring.append(self.model.vert(p, normal, mix(colour, scale_c(colour, 1.35), s), (0.0, FUR_KIND), weights))
            ring_idx.append(ring)
        tip = root + hang * length + lift * width * 0.3 - Vector((0, 1, 0)) * length * 0.15
        ti = self.model.vert(tip, normal, scale_c(colour, 1.5), (0.0, FUR_KIND), weights)
        for r in range(rings - 1):
            for k in range(sides):
                self.model.face((ring_idx[r][k], ring_idx[r + 1][k], ring_idx[r + 1][(k + 1) % sides], ring_idx[r][(k + 1) % sides]))
        for k in range(sides):
            self.model.face((ring_idx[-1][k], ti, ring_idx[-1][(k + 1) % sides]))

    def fur(self):
        """Clumps hanging from the body wherever the stone does not cover it."""
        faces = [f for f in self.body_bm.faces]
        areas = [f.calc_area() for f in faces]
        total = sum(areas)
        count = 120 if self.low else 380
        stone = self.stone_bvh
        made = 0
        tries = 0
        rng = random.Random(11)
        cumulative = []
        acc = 0.0
        for a in areas:
            acc += a
            cumulative.append(acc)
        import bisect
        while made < count and tries < count * 6:
            tries += 1
            f = faces[min(bisect.bisect_left(cumulative, rng.random() * total), len(faces) - 1)]
            r1, r2 = rng.random(), rng.random()
            if r1 + r2 > 1.0:
                r1, r2 = 1.0 - r1, 1.0 - r2
            vs = [v.co for v in f.verts]
            pb = vs[0] + (vs[1] - vs[0]) * r1 + (vs[2] - vs[0]) * r2
            p = from_b(pb)
            n = from_b(f.normal)
            if p.y < 0.75 or n.y < -0.85:
                continue
            # (none from under the stone)
            loc, _nn, _i, d = stone.find_nearest(pb)
            if loc is not None and d < 0.22:
                continue
            bone = max(nearest_bones(p, count=1).items(), key=lambda kv: kv[1])[0]
            a, b = SEGMENTS[bone]
            down = Vector((0, -1, 0))
            if bone.startswith(("upper_arm", "forearm", "thigh", "shin")):
                down = (b - a).normalized() * 0.6 + down * 0.4
            # (tatters: long thin strands hanging off the bones)
            length = rng.uniform(0.2, 0.5)
            if bone in ("chest", "neck") and n.z < 0.0:
                length *= 1.6
            if bone.startswith("forearm") and n.y < 0.0:
                length *= 2.0
            if bone.startswith(("thigh", "pelvis")) and n.z < 0.0:
                length *= 1.5
            width = length * rng.uniform(0.18, 0.28)
            colour = scale_c(self.fur_colour(p, n), rng.uniform(0.75, 1.15))
            self.clump(p - n * 0.02, down, length, width, n, colour, nearest_bones(p), rings=2 if self.low else 3)
            made += 1
        # Shaggy fur round the ankles, hanging over the stone of the feet.
        for _name, s in SIDES:
            ankle = leg_joints(s)[2]
            for k in range(8 if self.low else 18):
                a = math.tau * k / (8 if self.low else 18) + rng.uniform(-0.1, 0.1)
                d = Vector((math.cos(a), 0.0, math.sin(a)))
                hit, hn = self.on_body(ankle + Vector((0, 0.35, 0)), d)
                if hit is None:
                    continue
                length = rng.uniform(0.3, 0.55)
                colour = scale_c(mix(FUR, EARTH, rng.random() * 0.6), rng.uniform(0.8, 1.15))
                self.clump(hit - hn * 0.03, Vector((0, -1, 0)), length, length * 0.4, hn, colour, nearest_bones(hit, count=2), rings=2 if self.low else 3)
        # The mane: long hair hanging from the neck, round and under the mask.
        mane = 24 if self.low else 70
        for k in range(mane):
            # (round the sides and the back of the mask, and a beard under it)
            a = rng.uniform(0.9, 2.9) * rng.choice((1.0, -1.0)) if k % 4 else rng.uniform(-0.8, 0.8)
            h = rng.uniform(0.0, 1.0) if k % 4 else rng.uniform(0.0, 0.3)
            base = NECK.lerp(HEAD, 0.4 + h * 0.6) + Vector((0, 0.1, 0))
            d = Vector((math.sin(a), 0.1, math.cos(a))).normalized()
            hit, hn = self.on_body(base, d)
            if hit is None:
                continue
            length = rng.uniform(0.5, 1.0) * (1.3 if abs(a) < 1.0 else 1.0)
            colour = scale_c(mix(FUR, FUR_WARM, rng.random() * 0.6), rng.uniform(0.8, 1.2))
            self.clump(hit - hn * 0.03, Vector((0, -1, 0.15)), length, length * 0.3, hn, colour, {"neck": 0.6, "chest": 0.4}, rings=2 if self.low else 3)

    # --- Head, hands and feet -------------------------------------------

    def head(self):
        """A stone mask, long and heavy like the heads of Rapa Nui: a flat brow
        over two deep holes with pale eyes in them, a long nose, a thin hard
        mouth, a jutting chin; flat sides, a flat top grown over with moss."""
        weights = {"head": 1.0}
        centre = HEAD + Vector((0, 0.55, 0.42))
        segs, rings = (14, 10) if self.low else (30, 24)
        half = Vector((0.44, 0.72, 0.46))

        def front_relief(x, y):
            """How far the face stands out (or sinks in) at (x, y) across its front."""
            r = 0.0
            # A heavy flat brow, overhanging.
            r += 0.12 * smooth(0.12, 0.2, y) * smooth(0.46, 0.3, y)
            # Deep holes under it, either side of the nose.
            for ex in (0.2, -0.2):
                e2 = ((x - ex) / 0.12) ** 2 + ((y - 0.06) / 0.075) ** 2
                r -= 0.3 * math.exp(-e2 * 1.1)
            # The long nose: narrow between the eyes, broad and out at the bottom.
            w = 0.05 + 0.08 * smooth(0.15, -0.25, y)
            ridge = math.exp(-(x / w) ** 2) * smooth(0.16, 0.05, y) * smooth(-0.33, -0.24, y)
            r += ridge * (0.04 + 0.16 * smooth(0.15, -0.25, y))
            # The mouth: a hard line, lips pressed.
            r -= 0.05 * math.exp(-((y + 0.42) / 0.025) ** 2) * smooth(0.26, 0.18, abs(x))
            r += 0.025 * math.exp(-((y + 0.37) / 0.04) ** 2) * smooth(0.24, 0.12, abs(x))
            # The chin, jutting.
            r += 0.08 * smooth(-0.5, -0.6, y) * smooth(0.3, 0.15, abs(x))
            # Cheekbones under the holes, hollows under them.
            for ex in (0.27, -0.27):
                r += 0.035 * math.exp(-(((x - ex) / 0.1) ** 2 + ((y + 0.08) / 0.08) ** 2))
            return r

        grid = []
        normals = []
        for j in range(rings + 1):
            row = []
            v = j / rings
            phi = math.pi * (1.0 - v)
            for i in range(segs + 1):
                th = -math.pi + math.tau * i / segs
                d = Vector((math.sin(th) * math.sin(phi), math.cos(phi), math.cos(th) * math.sin(phi)))
                k = 5.0
                denom = (abs(d.x / half.x) ** k + abs(d.y / half.y) ** k + abs(d.z / half.z) ** k) ** (1.0 / k)
                p = d / denom
                # (the jaw narrower than the brow, the back of the head rounder)
                p.x *= 1.0 - 0.18 * smooth(0.1, -0.7, p.y)
                if p.z > 0.0:
                    front = smooth(0.25, 0.42, p.z)
                    p.z += front_relief(p.x, p.y) * front
                else:
                    p.z *= 0.85
                row.append(centre + p)
            grid.append(row)
        # Smooth normals over the face, so that it reads as carved and worn.
        vn = [[Vector() for _i in range(segs + 1)] for _j in range(rings + 1)]
        for j in range(rings):
            for i in range(segs):
                q = [grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]]
                n = (q[2] - q[0]).cross(q[3] - q[1])
                if n.dot(sum(q, Vector()) / 4.0 - centre) < 0:
                    n = -n
                for jj, ii in ((j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1)):
                    vn[jj][ii] += n
        # (the seam round the back shares its normals)
        for j in range(rings + 1):
            total = vn[j][0] + vn[j][segs]
            vn[j][0] = vn[j][segs] = total
        index = {}
        for j in range(rings + 1):
            for i in range(segs + 1):
                p = grid[j][i]
                n = vn[j][i].normalized() if vn[j][i].length > 1e-9 else (p - centre).normalized()
                c, moss = self.stone_colour(p, n)
                local = p - centre
                # (dark in the holes and under the brow)
                hole = 0.0
                for ex in (0.2, -0.2):
                    hole = max(hole, smooth(0.16, 0.06, math.hypot(local.x - ex, (local.y - 0.06) * 1.4)))
                hole *= smooth(0.2, 0.4, local.z)
                c = scale_c(c, 1.0 - hole * 0.9)
                c = scale_c(c, 1.0 - 0.3 * smooth(-0.3, -0.5, n.y))
                index[(j, i)] = self.model.vert(p, n, c, (0.0, STONE_KIND), weights)
        for j in range(rings):
            for i in range(segs):
                self.model.face([index[(j, i)], index[(j + 1, i)], index[(j + 1, i + 1)], index[(j, i + 1)]])
                mid = sum((grid[j][i], grid[j + 1][i + 1]), Vector()) / 2.0
                n = vn[j][i].normalized()
                if n.y > 0.6 and (mid - centre).y > 0.5 and self.rng.random() < 0.35:
                    self.tuft(mid, n, weights, self.rng)
        # The eyes: pale, deep in the holes.
        for ex in (0.2, -0.2):
            bm = bmesh.new()
            bmesh.ops.create_icosphere(bm, subdivisions=1 if self.low else 2, radius=1.0)
            at = centre + Vector((ex, 0.06, half.z - 0.2))
            for f in bm.faces:
                pts = [at + Vector((v.co.x * 0.07, v.co.z * 0.04, -v.co.y * 0.045)) for v in f.verts]
                self.model.flat(pts, GLOW, (1.0, STONE_KIND), weights, normal=sum(pts, Vector()) / 3.0 - at)
            bm.free()
        # A rune cut into the brow, glowing.
        if not self.low:
            z = centre.z + half.z + 0.1
            for (x0, y0, x1, y1) in ((0.0, 0.42, 0.0, 0.3), (-0.06, 0.4, 0.0, 0.36), (0.06, 0.4, 0.0, 0.36), (-0.04, 0.3, 0.04, 0.3)):
                a = Vector((x0, y0, 0.0))
                b = Vector((x1, y1, 0.0))
                along = (b - a).normalized()
                w = Vector((-along.y, along.x, 0.0)) * 0.012
                pts = [a - w, b - w, b + w, a + w]
                pts = [centre + Vector((p.x, p.y, 0.0)) + Vector((0, 0, half.z + front_relief(p.x, p.y) + 0.004)) for p in pts]
                self.model.flat(pts, GLOW, (0.8, STONE_KIND), weights, normal=Vector((0, 0, 1)))

    def hand(self, name, s):
        """A long bony hand: a narrow palm of hide with a sliver of stone on its
        back, three long knuckled fingers curled a little, a thumb, and the index
        finger longer than the rest, on a bone of its own (it crushes with it)."""
        sh, el, wr, kn, tip = arm_joints(s)
        d = arm_dir(s)
        x, y, z = frame_of(-d)
        palm_w = PALM_HALF
        hand_w = {"hand_" + name: 1.0}
        self.box(wr.lerp(kn, 0.5), (x, y, z), (palm_w, PALM * 0.55, 0.075), HIDE, hand_w, FUR_KIND, round_k=0.3)
        self.box(wr.lerp(kn, 0.45) + z * -0.07, (x, y, z), (palm_w * 0.8, PALM * 0.42, 0.03), STONE, hand_w, STONE_KIND, round_k=0.2, chunky=True)

        def finger(base, length, bend, width, weights, joints=3):
            along = -y
            p0 = base
            for k in range(joints):
                seg = length * (0.4, 0.33, 0.27)[k]
                p1 = p0 + (along + z * bend * (k + 1)).normalized() * seg
                c = mix(HIDE, STONE_DARK, 0.4 + 0.3 * random.Random(int(abs(base.x) * 1000) + k).random())
                w = width * (1.0 - 0.15 * k)
                self.box(p0.lerp(p1, 0.5), basis_along(p0 - p1, x), (w, seg * 0.5, w), c, weights, FUR_KIND, round_k=0.35)
                # (a knob of knuckle at each joint)
                self.box(p1, (x, y, z), (w * 1.25, w * 1.1, w * 1.2), scale_c(c, 1.1), weights, FUR_KIND, round_k=0.45)
                p0 = p1

        for f in range(4):
            u = (f - 1.5) / 1.5
            base = kn + x * u * palm_w * 0.78 + y * 0.03
            if abs(u + s) < 0.01:
                # The index finger: long, slender, straight.
                finger(base, INDEX, 0.02, 0.05, {"index_" + name: 1.0})
            else:
                finger(base, FINGERS * (0.85 + 0.15 * (1.0 - abs(u))), 0.14, 0.048, {"fingers_" + name: 1.0})
        tb = wr.lerp(kn, 0.3) + x * (-s * palm_w * 0.95) + z * 0.05
        mid = tb - y * 0.22 + x * (-s * 0.08) + z * 0.12
        tt = mid - y * 0.2 + z * 0.1
        self.box(tb.lerp(mid, 0.5), basis_along(tb - mid, z), (0.05, 0.13, 0.05), HIDE, hand_w, FUR_KIND, round_k=0.35)
        self.box(mid.lerp(tt, 0.5), basis_along(mid - tt, z), (0.045, 0.11, 0.045), STONE_DARK, hand_w, FUR_KIND, round_k=0.35)

    def foot(self, name, s):
        """A long bony foot: a narrow sole of hide, a heel like a knob of stone,
        four long toes."""
        hp, k, a, t = leg_joints(s)
        w = {"foot_" + name: 1.0}
        X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
        self.box(Vector((a.x, 0.14, 0.3)), (X, Y, Z), (0.17, 0.09, 0.45), HIDE, w, FUR_KIND, round_k=0.35)
        self.box(Vector((a.x, 0.16, -0.14)), (X, Y, Z), (0.15, 0.13, 0.13), STONE, w, STONE_KIND, round_k=0.35, chunky=True)
        self.box(Vector((a.x, 0.22, 0.32)), (X, Y, Z), (0.13, 0.04, 0.32), STONE_DARK, w, STONE_KIND, round_k=0.25, chunky=True)
        for f in range(4):
            off = (f - 1.5) * 0.09
            base = Vector((a.x + off, 0.08, 0.72))
            p0 = base
            for j in range(2):
                p1 = p0 + Vector((off * 0.15, -0.02 * j, 0.17 - 0.03 * j))
                self.box(p0.lerp(p1, 0.5), basis_along(p0 - p1, X), (0.04, 0.09, 0.04), mix(HIDE, STONE_DARK, 0.5), w, FUR_KIND, round_k=0.35)
                p0 = p1

    def box(self, centre, axes, half, colour, weights, kind, round_k=0.3, chunky=False):
        """A block of stone (or hide): a cube with its edges cut off, a little out of true."""
        x, y, z = axes
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=2.0)
        bmesh.ops.bevel(bm, geom=bm.verts[:] + bm.edges[:], offset=round_k, segments=1, affect="EDGES", profile=0.5)
        rng = random.Random(int(abs(centre.x * 1000 + centre.y * 77 + centre.z * 13)))
        for v in bm.verts:
            jitter = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * (0.06 if chunky else 0.03)
            v.co = v.co + jitter
        for f in bm.faces:
            pts = []
            for v in f.verts:
                c = v.co
                pts.append(centre + x * c.x * half[0] + y * c.z * half[1] + z * -c.y * half[2])
            pts.reverse()
            mid = sum(pts, Vector()) / len(pts)
            n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
            if n.dot(mid - centre) < 0:
                pts.reverse()
            if kind == STONE_KIND:
                col, _m = self.stone_colour(mid, n.normalized())
                col = mix(col, colour, 0.4)
            else:
                col = colour
            self.model.flat(pts, col, (0.0, kind), weights)
        bm.free()

    # --- All of it -------------------------------------------------------

    def armour(self):
        """Where the stone is: a few slabs on the thin frame, as if the stone came
        first and the thing grew round it, and wasted away."""
        P = math.pi
        # A slab on the chest with runes, slabs down the hunched back (moss, grass, vines).
        self.plate("chest", (0, 1), (0, 1), thick=0.08, cells=(14, 12), runes=2, bands=(0.15,), seed=1, tufts=0.2, fringe=0.3,
                   cap=(CHEST + Vector((0, 0.2, -0.1)), Vector((0, 0.1, 1)), 0.6, 0.55))
        self.plate("chest", (0, 1), (0, 1), thick=0.1, cells=(12, 12), bands=(0.45,), seed=2, tufts=0.7, vines=3, fringe=0.4,
                   cap=(CHEST + Vector((0, 0.35, 0.1)), Vector((0, 0.7, -1)), 0.62, 0.55))
        self.plate("spine", (0, 1), (0, 1), thick=0.08, cells=(8, 8), seed=3, tufts=0.3,
                   cap=(WAIST + Vector((0, 0.2, 0.05)), Vector((0, 0.1, -1)), 0.5, 0.5))
        self.plate("pelvis", (0.1, 0.75), (-1.2, 1.2), thick=0.07, cells=(14, 5), seed=4, tufts=0.2, vines=2, fringe=0.9)
        for name, s in SIDES:
            out = s * P * 0.5
            sh = arm_joints(s)[0]
            k = leg_joints(s)[1]
            side = Vector((s, 0, 0))

            def round_out(centre, half):
                return (centre - half, centre + half)

            # A cap of stone on each shoulder, mossed, grassed, hung with vines.
            self.plate("upper_arm_" + name, (0, 1), (0, 1), thick=0.1, cells=(12, 10), seed=10 + int(s), tufts=0.85, vines=3, fringe=0.5,
                       cap=(sh - side * 0.08, (side * 0.5 + Vector((0, 0.85, -0.05))).normalized(), 0.85, 0.8))
            # A bracer on each forearm, with runes; greaves on the shins; caps on the knees.
            self.plate("forearm_" + name, (0.3, 0.72), round_out(out * 0.8, 1.2), thick=0.06, cells=(10, 14), runes=2, bands=(0.08, 0.92), seed=20 + int(s), fringe=0.4)
            self.plate("shin_" + name, (0, 1), (0, 1), thick=0.08, cells=(8, 8), seed=40 + int(s), tufts=0.4,
                       cap=(k + Vector((0, 0.0, -0.1)), Vector((0, 0.2, 1)), 0.8, 0.7))
            self.plate("shin_" + name, (0.25, 0.7), round_out(out * 0.15, 0.95), thick=0.07, cells=(10, 12), seed=50 + int(s), tufts=0.15, fringe=0.4)
            self.plate("thigh_" + name, (0.15, 0.55), round_out(out * 0.8, 0.8), thick=0.07, cells=(8, 10), runes=1, seed=30 + int(s), tufts=0.2)
        # (everything made of stone, to keep the fur out from under it)
        bm = bmesh.new()
        for faces in self.plate_bms:
            for pts in faces:
                verts = [bm.verts.new(to_b(p)) for p in pts]
                try:
                    bm.faces.new(verts)
                except ValueError:
                    pass
        self.stone_bvh = BVHTree.FromBMesh(bm)
        bm.free()

    def build(self, out_name):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        counts = []
        self.body()
        counts.append(("body", self.model.tris()))
        self.armour()
        counts.append(("stone", self.model.tris()))
        first = len(self.model.co)
        self.head()
        for i in range(first, len(self.model.co)):
            self.model.co[i] = HEAD + (self.model.co[i] - HEAD) * HEAD_SCALE
        counts.append(("head", self.model.tris()))
        for name, s in SIDES:
            self.hand(name, s)
            self.foot(name, s)
        counts.append(("hands and feet", self.model.tris()))
        self.fur()
        counts.append(("fur", self.model.tris()))
        print("  " + ", ".join("%s %d" % (n, c - (counts[k - 1][1] if k else 0)) for k, (n, c) in enumerate(counts)))

        data = bpy.data.armatures.new("Armature")
        armature = bpy.data.objects.new("Armature", data)
        bpy.context.collection.objects.link(armature)
        bpy.context.view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode="EDIT")
        for bone in BONES:
            a, b = SEGMENTS[bone]
            eb = data.edit_bones.new(bone)
            eb.head = to_b(a)
            eb.tail = to_b(b)
        bpy.ops.object.mode_set(mode="OBJECT")

        m = self.model
        # (every face turned to face the way its points' normals do, so that none
        # is drawn inside out)
        for k, f in enumerate(m.faces):
            if len(f) < 3:
                continue
            a, b, c = m.co[f[0]], m.co[f[1]], m.co[f[2]]
            n = (b - a).cross(c - a)
            if len(f) > 3:
                n = n + (c - a).cross(m.co[f[3]] - a)
            if n.dot(sum((m.normal[i] for i in f), Vector())) < 0.0:
                m.faces[k] = tuple(reversed(f))
        mesh = bpy.data.meshes.new(out_name)
        mesh.from_pydata([to_b(p) for p in m.co], [], m.faces)
        mesh.update()
        body = bpy.data.objects.new(out_name, mesh)
        bpy.context.collection.objects.link(body)
        groups = {bone: body.vertex_groups.new(name=bone) for bone in BONES}
        for i, w in enumerate(m.weights):
            for bone, value in w.items():
                groups[bone].add([i], value, "REPLACE")
        col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i, c in enumerate(m.colour):
            col.data[i].color = (c[0], c[1], c[2], 1.0)
        uv0 = mesh.uv_layers.new(name="UVMap")
        uv1 = mesh.uv_layers.new(name="UV2")
        for loop in mesh.loops:
            vi = loop.vertex_index
            uv0.data[loop.index].uv = (m.uv0[vi][0], 1.0 - m.uv0[vi][1])
            uv1.data[loop.index].uv = (m.uv1[vi][0], 1.0 - m.uv1[vi][1])
        for poly in mesh.polygons:
            poly.use_smooth = True
        mesh.normals_split_custom_set_from_vertices([to_b(n) for n in m.normal])
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
        mesh.uv_layers.active = uv0
        body.parent = armature
        body.modifiers.new("Armature", "ARMATURE").object = armature

        os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
        path = os.path.join(FOLDER, "models", out_name + ".glb")
        options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=True,
                       export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True)
        try:
            bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
        except TypeError:
            bpy.ops.export_scene.gltf(**options, export_colors=True)
        print("BUILT %s verts=%d tris=%d" % (out_name, len(m.co), m.tris()))
        if PREVIEW_DIR and not self.low:
            self.previews(out_name)

    def previews(self, name):
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = True
        scene.render.resolution_x, scene.render.resolution_y = 900, 900
        scene.world = bpy.data.worlds.new("World")
        scene.world.color = (0.55, 0.58, 0.6)
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.lens = 50
        camera.data.clip_end = 500
        scene.collection.objects.link(camera)
        scene.camera = camera
        views = [("front", Vector((0.0, 0.25, 1.0)), Vector((0, 5.5, 0)), 24.0), ("quarter", Vector((0.8, 0.3, 0.7)), Vector((0, 5.0, 0)), 19.0),
                 ("back", Vector((-0.5, 0.4, -1.0)), Vector((0, 5.5, 0)), 19.0), ("side", Vector((1.0, 0.1, 0.0)), Vector((0, 5.0, 0)), 19.0),
                 ("face", Vector((0.35, 0.1, 1.0)), HEAD + Vector((0, 0.6, 0.4)), 4.5), ("low", Vector((0.4, -0.25, 1.0)), Vector((0, 6.0, 0)), 12.0)]
        for view, direction, target, far in views:
            offset = to_b(direction.normalized()) * far
            camera.location = to_b(target) + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    only = os.environ.get("COLOSSUS_ONLY", "")
    for low in (False, True):
        if only == "hi" and low:
            continue
        Colossus(low).build("colossus" + ("_lo" if low else ""))
