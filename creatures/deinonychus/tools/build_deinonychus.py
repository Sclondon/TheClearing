"""Builds the deinonychus (creatures/deinonychus) and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/deinonychus/tools/build_deinonychus.py
    blender --background --python creatures/deinonychus/tools/build_deinonychus.py -- <preview folder>   # with pictures and a .blend

Writes creatures/deinonychus/models/deinonychus.glb and a demade
deinonychus_lo.glb. Nothing else is written (an editable .blend goes to the
preview folder, when there is one; this folder has a .gdignore so that Godot
does not try to import anything here).

It is Deinonychus antirrhopus as the bones and its living relatives say it
was, not the film raptor: about 3.3 m from snout to tail tip, the hip about
0.86 m off the ground (hip-high to a man), most of its length a stiff tail
held straight out behind for balance. A deep, narrow body; an S of a neck; a
long narrow skull with a big eye, the teeth covered by lips. Fully feathered:
a coat of contour feathers over the body, neck, head and thighs (the snout,
the lower shins and the feet bare and scaly); the arms are wings, with long
pennaceous flight feathers on the hands (primaries) and forearms
(secondaries), folded against its sides like a bird's, the palms facing in
(it cannot turn them down); a fan of long feathers spread flat either side of
the end of the tail. On each foot two toes take its weight (III and IV) and
the second is held up off the ground, its great sickle claw raised; a little
first toe (a dewclaw) behind. Three long clawed fingers on each hand.

The bones (each joint's name, from the hips):

    body (the hips) -> chest -> neck, neck_1, neck_2 -> head -> jaw
    body -> tail, tail_1, tail_2, tail_3 -> tail_end
    body -> thigh, shin, shank (the long foot, metatarsus), foot (toes III, IV and the dewclaw: each hangs
            from the body, the rig places them), foot -> sickle (toe II)
    chest -> arm (humerus), forearm, hand

(each leg and arm `_l` or `_r`). The rig (creatures/deinonychus/deinonychus_rig.gd)
reads every joint from the skeleton.

Three materials, so that it is a few draws: `coat` (the contour feathers and
the skin of the head and legs), `feathers` (the vanes of the wings and the
tail fan), `parts` (eyes, claws, scales, mouth, teeth: their colours in the
vertex colours).

The coat's vertex colours: red how open the surface is (dark in creases),
green how dark its markings are (the mask through its eye, the saddle down
its back, the bars across its tail), blue how pale (the throat, the belly and
under the tail), alpha how long its feathers are there (0: bare skin, scaly).
Its texture coordinates are metres along the lie of the feathers (towards
the tail, down the legs and arms) and across it, which the shader lays the
rows of feathers on.

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
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
import build_character as kit  # noqa: E402  (the character controller's shape-building tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
OUT = os.path.join(COMPONENT, "models")


def V(x, y, z):
    return Vector((x, y, z))


# --- How it is built ---

HIP = V(0.0, 0.86, 0.0)
CHEST = V(0.0, 0.90, 0.34)
NECK = V(0.0, 0.975, 0.60)
NECK_1 = V(0.0, 1.10, 0.70)
NECK_2 = V(0.0, 1.21, 0.79)
HEAD = V(0.0, 1.27, 0.90)
# (the hinge of the lower jaw, under the back of the skull)
JAW = HEAD + V(0.0, -0.055, 0.04)
TAIL = [V(0.0, 0.90, -0.14), V(0.0, 0.915, -0.55), V(0.0, 0.93, -0.98), V(0.0, 0.945, -1.42), V(0.0, 0.96, -1.93)]
TAIL_NAMES = ["tail", "tail_1", "tail_2", "tail_3", "tail_end"]

# The line of the body, from the tip of the tail to the head, and how big
# round it is there: (where, half width, half height, how far the middle is
# below the line). A deep narrow chest, the belly deepest under the ribs, the
# tail thick at its root with the muscle that pulls the thighs back, and
# thinning to a whip; the neck an S, rising from the shoulders and then on
# forward to the head.
SPINE = [
    (V(0.0, 0.962, -1.95), 0.010, 0.009, 0.0), (V(0.0, 0.955, -1.70), 0.016, 0.015, 0.0),
    (V(0.0, 0.947, -1.42), 0.022, 0.021, 0.0), (V(0.0, 0.940, -1.15), 0.029, 0.028, 0.0),
    (V(0.0, 0.932, -0.90), 0.037, 0.036, 0.0), (V(0.0, 0.922, -0.65), 0.050, 0.050, 0.002),
    (V(0.0, 0.913, -0.45), 0.066, 0.068, 0.006), (V(0.0, 0.905, -0.28), 0.084, 0.090, 0.014),
    (V(0.0, 0.902, -0.14), 0.102, 0.118, 0.030), (V(0.0, 0.905, 0.00), 0.120, 0.146, 0.046),
    (V(0.0, 0.910, 0.12), 0.128, 0.162, 0.060), (V(0.0, 0.915, 0.24), 0.132, 0.172, 0.070),
    (V(0.0, 0.925, 0.36), 0.132, 0.174, 0.070), (V(0.0, 0.937, 0.46), 0.122, 0.158, 0.060),
    (V(0.0, 0.952, 0.54), 0.104, 0.130, 0.040), (V(0.0, 0.978, 0.605), 0.086, 0.100, 0.020),
    (V(0.0, 1.030, 0.652), 0.080, 0.090, 0.008), (V(0.0, 1.100, 0.700), 0.072, 0.079, 0.002),
    (V(0.0, 1.160, 0.745), 0.066, 0.072, 0.0), (V(0.0, 1.210, 0.790), 0.062, 0.067, 0.0),
    (V(0.0, 1.248, 0.845), 0.058, 0.063, 0.0), (V(0.0, 1.268, 0.900), 0.052, 0.058, 0.0),
]
# Where each bone of the body's line begins, along it (the tail's tip first).
SPINE_BONES = [("tail_3", TAIL[3]), ("tail_2", TAIL[2]), ("tail_1", TAIL[1]), ("tail", TAIL[0]),
               ("body", HIP), ("chest", CHEST), ("neck", NECK), ("neck_1", NECK_1), ("neck_2", NECK_2), ("head", HEAD)]

# The left leg (the right is its mirror): hip, knee, ankle, ball of the foot.
# The thigh runs forward and down from the hip, the shin back down to the
# ankle, the long foot (the metatarsus, short and stout in Deinonychus)
# forward and down to the ball, on which the toes spread.
LEG = [V(0.105, 0.86, 0.0), V(0.125, 0.575, 0.185), V(0.118, 0.215, 0.02), V(0.108, 0.042, 0.105)]
LEG_NAMES = ["thigh", "shin", "shank", "foot"]
# The second toe (its root, the joint where it turns up, the root of its claw): held up off the ground.
SICKLE = [V(0.090, 0.046, 0.108), V(0.087, 0.072, 0.140), V(0.086, 0.100, 0.150)]
# The left arm: shoulder, elbow, wrist, and the tips of its fingers, folded
# like a bird's wing: the upper arm back along the side, the forearm forward,
# the hand bent back again beside it.
ARM = [V(0.098, 0.905, 0.515), V(0.150, 0.775, 0.385), V(0.160, 0.835, 0.565), V(0.170, 0.700, 0.405)]
ARM_NAMES = ["arm", "forearm", "hand"]

# The upper skull, from HEAD, along its length: (forward, middle height,
# half width, half height). Long and narrow, deepest behind the eye, the snout
# narrowing and coming down a little to its tip.
SKULL = [(-0.035, 0.004, 0.040, 0.046), (0.015, 0.002, 0.054, 0.066), (0.065, -0.002, 0.056, 0.070),
         (0.110, -0.008, 0.050, 0.066), (0.160, -0.019, 0.042, 0.059), (0.220, -0.029, 0.035, 0.051),
         (0.280, -0.037, 0.030, 0.043), (0.330, -0.043, 0.026, 0.036), (0.368, -0.048, 0.022, 0.029),
         (0.392, -0.052, 0.014, 0.019)]
# The lower jaw, from its hinge (JAW) to its tip: (along, half width, half height).
JAW_TIP = HEAD + V(0.0, -0.084, 0.380)
JAW_SHAPE = [(0.0, 0.056, 0.034), (0.1, 0.048, 0.030), (0.2, 0.039, 0.025), (0.3, 0.030, 0.019), (0.355, 0.018, 0.012)]
EYE = (V(0.042, 0.016, 0.104), 0.0185)
NOSTRIL = V(0.020, -0.030, 0.352)

rng = random.Random(7)


def mirror(p, side):
    return V(p.x * side, p.y, p.z)


def chain_param(p, joints):
    """The nearest point to `p` on a line of joints: (how far off it, how far along it counted in joints)."""
    best = (1e9, 0.0)
    for i in range(len(joints) - 1):
        a, b = joints[i], joints[i + 1]
        ab = b - a
        t = min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)
        d = (p - (a + ab * t)).length
        if d < best[0]:
            best = (d, i + t)
    return best


def chain_weights(along, names, soft=0.25):
    """Weights for a point `along` a line of joints (counted in joints): bone k
    has the stretch from joint k to joint k + 1, the two sharing it near a joint."""
    made = {}
    count = len(names)
    k = min(int(along), count - 1)
    t = along - k
    made[names[k]] = 1.0
    if k + 1 < count and t > 1.0 - soft:
        share = blend(1.0 - soft, 1.0 + soft, t) if t < 1.0 else 0.5
        made[names[k + 1]] = share
        made[names[k]] = 1.0 - share
    if k > 0 and t < soft:
        share = 0.5 * (1.0 - blend(0.0, soft, t))
        made[names[k - 1]] = share
        made[names[k]] = 1.0 - share
    return made


# --- Making shapes ---

class Part:
    """The vertices and faces of one part, with texture coordinates in metres."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()

    def vert(self, p):
        return self.bm.verts.new(kit.to_blender(p))

    def face(self, verts, coords):
        try:
            made = self.bm.faces.new(verts)
        except ValueError:
            return None
        for loop, uv in zip(made.loops, coords):
            loop[self.uv].uv = uv
        return made

    def tube(self, rings, segments=16, caps=(True, True), power=1.0):
        """A closed tube over rings of (centre, u, v): its texture coordinates are
        metres along it from its first ring, and metres round it. `power` under 1
        squares off its sections (a skull's, a jaw's)."""
        if kit.LOW:
            segments = max(4, segments // 2)
            if len(rings) > 8:
                rings = rings[:1] + rings[1:-1][::2] + rings[-1:]
        loops = []
        along = [0.0]
        for a, b in zip(rings, rings[1:]):
            along.append(along[-1] + (b[0] - a[0]).length)
        for centre, u, v in rings:
            loop = []
            for i in range(segments):
                c, s = math.cos(math.tau * i / segments), math.sin(math.tau * i / segments)
                if power != 1.0:
                    c, s = math.copysign(abs(c) ** power, c), math.copysign(abs(s) ** power, s)
                loop.append(self.vert(centre + u * c + v * s))
            loops.append(loop)
        made = []
        for r in range(len(loops) - 1):
            a, b = loops[r], loops[r + 1]
            ra = (rings[r][1].length + rings[r][2].length) * 0.5
            rb = (rings[r + 1][1].length + rings[r + 1][2].length) * 0.5
            for i in range(segments):
                j = (i + 1) % segments
                ua, ub = along[r], along[r + 1]
                coords = [(ua, i / segments * math.tau * ra), (ua, (i + 1) / segments * math.tau * ra),
                          (ub, (i + 1) / segments * math.tau * rb), (ub, i / segments * math.tau * rb)]
                made.append(self.face((a[i], a[j], b[j], b[i]), coords))
        for r, loop, (centre, u, v), cap in ((0, loops[0], rings[0], caps[0]), (len(loops) - 1, loops[-1], rings[-1], caps[1])):
            if not cap:
                continue
            pole = self.vert(centre)
            radius = (u.length + v.length) * 0.5
            for i in range(segments):
                made.append(self.face((loop[i], loop[(i + 1) % segments], pole),
                                      [(along[r], i / segments * math.tau * radius), (along[r], (i + 1) / segments * math.tau * radius), (along[r], (i + 0.5) / segments * math.tau * radius)]))
        bmesh.ops.recalc_face_normals(self.bm, faces=[f for f in made if f])

    def strand(self, points, radii, segments=8, flat=1.0, up=None):
        """A round-ended tube following a line of points (a toe, a finger), `flat` squashing it top to bottom."""
        rings = []
        for i, point in enumerate(points):
            ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
            side = ahead.cross(up or (Y if abs(ahead.y) < 0.9 else Z)).normalized()
            lift = side.cross(ahead).normalized()
            rings.append((point, side * radii[i], lift * radii[i] * flat))
        first = (points[0] - points[1]).normalized()
        last = (points[-1] - points[-2]).normalized()
        self.tube(kit.dome(rings[0], first, radii[0] * 0.8, 2)[::-1] + rings + kit.dome(rings[-1], last, radii[-1], 2), segments)

    def ellipsoid(self, centre, radii, axes=None, segments=12, rings=6):
        if kit.LOW:
            segments, rings = 8, 3
        ax = axes or (X, Y, Z)
        loops = []
        for k in range(1, rings + 1):
            phi = -math.pi / 2 + math.pi * k / (rings + 1)
            c, s = math.cos(phi), math.sin(phi)
            loops.append((centre + ax[2] * radii.z * s, ax[0] * radii.x * c, ax[1] * radii.y * c))
        start = (centre - ax[2] * radii.z, ax[0] * 0.0001, ax[1] * 0.0001)
        end = (centre + ax[2] * radii.z, ax[0] * 0.0001, ax[1] * 0.0001)
        self.tube([start] + loops + [end], segments, caps=(False, False))

    def claw(self, root, ahead, down, length, thick, curl=1.4, segments=6):
        """A curved claw from `root`: a cone along an arc from `ahead` round towards `down`."""
        points = []
        radii = []
        steps = 3 if kit.LOW else 5
        for k in range(steps + 1):
            t = k / steps
            a = curl * t
            points.append(root + (ahead * math.sin(a) + down * (1.0 - math.cos(a))) * length / curl)
            radii.append(thick * (1.0 - t * 0.9))
        rings = []
        for i, point in enumerate(points):
            way = (points[min(i + 1, steps)] - points[max(i - 1, 0)]).normalized()
            side = way.cross(down).normalized()
            lift = side.cross(way).normalized()
            # (narrow side to side, deep top to bottom: a claw's blade)
            rings.append((point, side * radii[i] * 0.6, lift * radii[i]))
        self.tube(rings, segments)

    def vane(self, root, way, normal, length, width, curve=0.0, narrow=0.5, rows=5):
        """A feather: its shaft from `root` along `way`, its vane flat across
        `normal`, bent towards `normal` by `curve` (of its length), the leading
        vane `narrow` as wide as the other. Texture coordinates: (along it 0..1,
        across it 0..1, the shaft at 0.5)."""
        if kit.LOW:
            rows = 3
        way = way.normalized()
        side = normal.cross(way).normalized()
        normal = way.cross(side).normalized()
        columns = []
        for r in range(rows + 1):
            t = r / rows
            half = 0.5 * width * (0.35 + 0.65 * math.sin(math.pi * min(0.12 + t * 0.85, 0.97)) ** 0.6)
            if r == rows:
                half *= 0.25
            middle = root + way * length * t + normal * curve * length * t * t
            columns.append([self.vert(middle - side * half * narrow * 2.0 * 0.5 - normal * 0.0005), self.vert(middle + normal * 0.002 * (1.0 - t)),
                            self.vert(middle + side * half - normal * 0.0005)])
        for r in range(rows):
            a, b = columns[r], columns[r + 1]
            ta, tb = r / rows, (r + 1) / rows
            self.face((a[0], b[0], b[1], a[1]), [(ta, 0.0), (tb, 0.0), (tb, 0.5), (ta, 0.5)])
            self.face((a[1], b[1], b[2], a[2]), [(ta, 0.5), (tb, 0.5), (tb, 1.0), (ta, 1.0)])

    def mesh(self):
        made = bpy.data.meshes.new("part")
        self.bm.to_mesh(made)
        self.bm.free()
        return made


# --- The parts ---

def body_rings():
    rings = []
    points = [s[0] for s in SPINE]
    for i, (point, half_w, half_h, drop) in enumerate(SPINE):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        side = ahead.cross(Y).normalized()
        up = side.cross(ahead).normalized()
        rings.append((point - up * drop, side * half_w, up * half_h))
    # (rounded off at the tail's tip, and closed inside the head at the other end)
    first = (points[0] - points[1]).normalized()
    return kit.dome(rings[0], first, 0.012, 2)[::-1] + rings


def coat():
    p = Part()
    # (from the head to the tail: the feathers lie that way, along the texture's first coordinate)
    p.tube(body_rings()[::-1], 20)
    return p


def skull():
    p = Part()
    rings = []
    for z, y, hw, hh in SKULL:
        rings.append((HEAD + V(0.0, y, z), X * hw, Y * hh))
    tip = rings[-1]
    p.tube((rings + kit.dome(tip, Z, 0.010, 2))[::-1], 18, power=0.78)
    return p


def lower_jaw():
    p = Part()
    way = (JAW_TIP - JAW).normalized()
    up = X.cross(way).normalized() * -1.0
    if up.y < 0.0:
        up = -up
    rings = []
    total = (JAW_TIP - JAW).length
    for along, hw, hh in JAW_SHAPE:
        rings.append((JAW + way * along * total / JAW_SHAPE[-1][0], X * hw, up * hh))
    p.tube((kit.dome(rings[0], -way, 0.012, 2)[::-1] + rings + kit.dome(rings[-1], way, 0.008, 2))[::-1], 14, power=0.75)
    return p


def mouth():
    """The inside of the mouth: a dark wedge between the jaws (seen when it gapes)."""
    p = Part()
    rings = []
    for z, hw, hh in ((0.03, 0.038, 0.012), (0.15, 0.028, 0.012), (0.30, 0.016, 0.008), (0.36, 0.008, 0.004)):
        rings.append((HEAD + V(0.0, -0.066 - z * 0.03, z), X * hw, Y * hh))
    p.tube(rings, 8)
    return p


def teeth(upper):
    """Its teeth, out of sight behind its lips: a row of small curved blades
    each side, the upper row coming down a little below the lips' edge
    inside the lower jaw, so that only a gape shows them."""
    p = Part()
    count = 7 if kit.LOW else 13
    for side in (1.0, -1.0):
        for k in range(count):
            t = (k + 0.5) / count
            z = 0.07 + t * 0.30
            if upper:
                ring = next(r for r in reversed(SKULL) if r[0] <= z) if z > SKULL[0][0] else SKULL[0]
                half = 0.0
                for a, b in zip(SKULL, SKULL[1:]):
                    if a[0] <= z <= b[0]:
                        u = (z - a[0]) / (b[0] - a[0])
                        half = a[2] + (b[2] - a[2]) * u
                        bottom = (a[1] - a[3]) + ((b[1] - b[3]) - (a[1] - a[3])) * u
                root = HEAD + V(side * half * 0.42, bottom + 0.008, z)
                tip = root + V(0.0, -0.016 * (1.0 - t * 0.4), -0.004)
            else:
                along = (z - 0.04) / 0.345
                centre = JAW.lerp(JAW_TIP, min(max(along, 0.0), 1.0))
                root = centre + V(side * 0.022 * (1.0 - along * 0.5), 0.010, 0.0)
                tip = root + V(0.0, 0.012 * (1.0 - t * 0.4), -0.003)
            kit.spike(p, root, tip, 0.0035, 4)
    return p


def eyes():
    p = Part()
    at, radius = EYE
    for side in (1.0, -1.0):
        centre = HEAD + mirror(at, side)
        out = V(side * 0.92, 0.12, 0.38).normalized()
        across = Y.cross(out).normalized()
        upward = out.cross(across).normalized()
        p.ellipsoid(centre, V(radius, radius, radius * 0.8), axes=(across, upward, out), segments=12, rings=6)
    return p


def nostrils():
    p = Part()
    for side in (1.0, -1.0):
        p.ellipsoid(HEAD + mirror(NOSTRIL, side), V(0.006, 0.005, 0.011), segments=6, rings=3)
    return p


def thighs():
    """The drumsticks: big, feathered, the muscle of them high on the hip."""
    p = Part()
    for side in (1.0, -1.0):
        hip, knee = mirror(LEG[0], side), mirror(LEG[1], side)
        way = (knee - hip).normalized()
        across = way.cross(X).normalized()
        rings = []
        for t, r_out, r_fore in ((-0.32, 0.060, 0.090), (-0.14, 0.098, 0.140), (0.06, 0.112, 0.150), (0.28, 0.104, 0.128),
                                 (0.52, 0.084, 0.100), (0.76, 0.064, 0.072), (0.96, 0.050, 0.054), (1.10, 0.036, 0.040)):
            centre = hip.lerp(knee, t) + V(-side * 0.030 * (1.0 - t), 0.0, -0.01 * (1.0 - t))
            rings.append((centre, X * r_out, across * r_fore))
        p.tube(rings, 14)
    return p


def shins():
    p = Part()
    for side in (1.0, -1.0):
        knee, ankle = mirror(LEG[1], side), mirror(LEG[2], side)
        way = (ankle - knee).normalized()
        across = way.cross(X).normalized()
        rings = []
        for t, r_out, r_fore in ((-0.10, 0.046, 0.050), (0.05, 0.058, 0.068), (0.28, 0.054, 0.064), (0.52, 0.042, 0.048),
                                 (0.78, 0.030, 0.033), (0.96, 0.024, 0.026), (1.06, 0.021, 0.023)):
            rings.append((knee.lerp(ankle, t), X * r_out, across * r_fore))
        p.tube(rings, 10)
    return p


def feet():
    """The long feet (scaly), the toes the weight is on, the dewclaw, and the
    second toe held up with its sickle claw."""
    p = Part()
    for side in (1.0, -1.0):
        ankle, ball = mirror(LEG[2], side), mirror(LEG[3], side)
        p.strand([ankle + V(0.0, 0.01, 0.0), ankle.lerp(ball, 0.5), ball + V(0.0, 0.006, 0.0)], [0.028, 0.025, 0.026], 8, flat=1.0, up=X)
        # Toes III (the longest, straight ahead) and IV (outside it, splayed out): their pads on the ground.
        for way, length, radius in ((V(side * 0.10, 0.0, 1.0), 0.130, 0.0175), (V(side * 0.42, 0.0, 1.0), 0.112, 0.016)):
            way = way.normalized()
            start = ball + V(side * 0.006 if length < 0.12 else 0.0, -0.016, 0.0)
            joints = [start + way * length * t + V(0.0, -0.008 * math.sin(math.pi * t) - 0.006 * t, 0.0) for t in (0.0, 0.16, 0.34, 0.5, 0.68, 0.84, 0.95)]
            p.strand(joints, [radius, radius * 0.82, radius * 0.92, radius * 0.74, radius * 0.82, radius * 0.62, radius * 0.55], 7, flat=0.8)
            tip = joints[-1]
            p.claw(tip - way * 0.004 + V(0.0, 0.004, 0.0), way, V(0.0, -1.0, 0.0), 0.030, 0.0065, curl=1.1)
        # The dewclaw (toe I): small, behind and inside, off the ground.
        dew = ankle.lerp(ball, 0.72) + V(-side * 0.016, 0.0, -0.012)
        p.strand([dew, dew + V(-side * 0.006, -0.010, -0.018)], [0.007, 0.006], 5)
        p.claw(dew + V(-side * 0.006, -0.012, -0.020), V(-side * 0.2, -0.3, -1.0).normalized(), V(0.0, -1.0, 0.0), 0.014, 0.004, curl=1.0)
        # Toe II: forward from the ball, then up, its great claw curving up and back over it.
        root, bend, claw = (mirror(j, side) for j in SICKLE)
        p.strand([root + V(0.0, -0.008, -0.005), bend, claw], [0.018, 0.016, 0.013], 6, flat=0.85)
        # (the sickle: a blade curving from pointing up-forward round to pointing down at the ground ahead)
        p.claw(claw + V(0.0, 0.004, 0.002), V(0.0, 1.0, 0.35).normalized(), V(0.0, -0.1, 1.0).normalized(), 0.115, 0.0125, curl=2.0, segments=8)
    return p


def arms():
    """Upper arms and forearms (feathered, in the coat)."""
    p = Part()
    for side in (1.0, -1.0):
        shoulder, elbow, wrist = (mirror(j, side) for j in ARM[:3])
        p.strand([shoulder + V(-side * 0.03, 0.0, 0.02), shoulder.lerp(elbow, 0.5) + V(-side * 0.012, 0.0, 0.0), elbow], [0.042, 0.036, 0.027], 10)
        p.strand([elbow, elbow.lerp(wrist, 0.5), wrist], [0.025, 0.022, 0.019], 8)
    return p


def hands():
    """The hands: three long fingers each, bent back along the forearm, the
    palm facing in against the body (it cannot turn it down), each finger
    ending in a big curved claw."""
    p = Part()
    for side in (1.0, -1.0):
        wrist, tips = mirror(ARM[2], side), mirror(ARM[3], side)
        way = (tips - wrist).normalized()
        inward = V(-side, 0.0, 0.0)
        flat_up = inward.cross(way).normalized()
        if flat_up.y < 0.0:
            flat_up = -flat_up
        hand = wrist + way * 0.07
        p.strand([wrist, hand], [0.017, 0.015], 6)
        # (finger I short and stout, II the longest, III thin; spread a little in the plane of the palm)
        for spread, length, radius in ((0.35, 0.075, 0.010), (0.0, 0.135, 0.009), (-0.28, 0.115, 0.0075)):
            finger_way = (way + flat_up * spread).normalized()
            joints = [hand + flat_up * spread * 0.02 + finger_way * length * t for t in (0.0, 0.4, 0.75, 1.0)]
            # (bent a little towards the palm, which faces in)
            joints = [j + inward * 0.012 * (k / 3.0) ** 2 for k, j in enumerate(joints)]
            p.strand(joints, [radius, radius * 0.9, radius * 0.8, radius * 0.7], 5)
            p.claw(joints[-1], finger_way, (inward * 0.8 - flat_up * 0.2).normalized(), 0.042 if length > 0.1 else 0.036, radius * 0.95, curl=1.5)
    return p


def wing_feathers():
    """The wings, folded: primaries along the hand, secondaries along the
    forearm, both lying back along its side, and a row of coverts over their
    roots; long, pennaceous, barred. Vanes flat against its flank."""
    p = Part()
    for side in (1.0, -1.0):
        shoulder, elbow, wrist, tips = (mirror(j, side) for j in ARM)
        out = V(side, 0.0, 0.0)
        hand_way = (tips - wrist).normalized()
        count = 5 if kit.LOW else 9
        for k in range(count):
            t = k / (count - 1)
            root = wrist.lerp(wrist + hand_way * 0.11, t) + out * 0.010
            way = V(side * 0.10, -0.16 - 0.16 * t, -1.0).normalized()
            length = 0.30 + 0.08 * math.sin(math.pi * min(t * 1.2, 1.0))
            p.vane(root + out * 0.004 * k, way, out, length, 0.060, curve=0.04, narrow=0.45)
        count = 6 if kit.LOW else 11
        for k in range(count):
            t = k / (count - 1)
            root = wrist.lerp(elbow, t) + V(0.0, -0.012, 0.0) + out * 0.012
            way = V(side * 0.08, -0.10 - 0.10 * t, -1.0).normalized()
            length = 0.27 - 0.06 * t
            p.vane(root + out * 0.003 * (count - k), way, out, length, 0.060, curve=0.05, narrow=0.6)
        # (coverts: shorter, over the roots of the rest)
        count = 5 if kit.LOW else 9
        for k in range(count):
            t = k / (count - 1)
            root = (wrist + hand_way * 0.05).lerp(elbow, t) + V(0.0, 0.004, 0.0) + out * 0.026
            way = V(side * 0.12, -0.25, -1.0).normalized()
            p.vane(root, way, out, 0.13 - 0.03 * t, 0.050, curve=0.06, narrow=0.8, rows=3)
            # (and a row of lesser coverts over those, up onto the forearm and the shoulder)
            p.vane(root + V(0.0, 0.03, 0.02) + out * 0.006, V(side * 0.14, -0.3, -1.0).normalized(), out, 0.09 - 0.02 * t, 0.042, curve=0.08, narrow=0.85, rows=2)
    return p


def tail_fan():
    """The frond of long feathers spread flat either side of the end of the
    tail, longer towards its tip, and a few out of the tip itself."""
    p = Part()
    count = 6 if kit.LOW else 10
    for k in range(count):
        t = k / (count - 1)
        z = -1.0 - t * 0.88
        root_line = chain_point_on_tail(z)
        half = tail_half_width(z)
        for side in (1.0, -1.0):
            way = V(side * (0.75 - 0.5 * t), 0.02, -1.0).normalized()
            length = 0.13 + 0.17 * t
            p.vane(root_line + V(side * half * 0.6, 0.0, 0.0), way, Y, length, 0.040 + 0.012 * t, curve=0.03, narrow=0.55)
    tip = chain_point_on_tail(-1.93)
    for spread in (-0.18, 0.0, 0.18):
        p.vane(tip + V(spread * 0.02, 0.0, 0.01), V(spread, 0.02, -1.0), Y, 0.30, 0.046, curve=0.02, narrow=0.9)
    return p


def chain_point_on_tail(z):
    points = [s[0] for s in SPINE]
    for a, b in zip(points, points[1:]):
        if a.z <= z <= b.z:
            return a.lerp(b, (z - a.z) / (b.z - a.z))
    return points[0]


def tail_half_width(z):
    for a, b in zip(SPINE, SPINE[1:]):
        if a[0].z <= z <= b[0].z:
            u = (z - a[0].z) / (b[0].z - a[0].z)
            return a[1] + (b[1] - a[1]) * u
    return SPINE[0][1]


def tufts():
    """A few loose contour feathers standing out of the coat: the nape and back
    of the neck, the back of the head, the hips: so that its outline is
    ragged and soft, not smooth."""
    p = Part()
    if kit.LOW:
        return p
    for k in range(9):
        t = k / 8.0
        base = HEAD.lerp(NECK, t) + V(0.0, 0.040 - 0.01 * t, -0.04 - 0.02 * t)
        for side in (1.0, -1.0, 0.0):
            way = V(side * 0.45, 0.06, -1.0).normalized()
            p.vane(base + V(side * 0.026, -0.008 * abs(side), 0.0), way, (V(0.0, 1.0, 0.0) if side == 0.0 else V(side, 0.6, 0.0)).normalized(), 0.040 + 0.02 * rng.random(), 0.024, curve=-0.25, narrow=0.9, rows=2)
    return p


# --- Weights ---

def weights():
    spine_points = [b[1] for b in SPINE_BONES]
    spine_names = [b[0] for b in SPINE_BONES]

    def on_spine(p):
        # (how far along the body's line, counted in its bones: the tail's tip end first)
        off, along = chain_param(p, [TAIL[4]] + spine_points)
        if along < 1.0:
            return {"tail_3": 1.0}
        return chain_weights(along - 1.0, spine_names, 0.3)

    def leg_of(p):
        side = 1.0 if p.x >= 0.0 else -1.0
        return side, ("_l" if side > 0.0 else "_r")

    def weigh(part, p):
        side, suffix = leg_of(p)
        if part in ("coat", "tufts"):
            made = on_spine(p)
            # (the thighs' muscle reaches into the hips)
            return made
        if part in ("skull", "eyes", "nostrils", "teeth_upper"):
            return {"head": 1.0}
        if part in ("jaw", "teeth_lower", "mouth"):
            return {"jaw": 1.0}
        if part == "thighs":
            joints = [mirror(j, side) for j in LEG[:3]]
            along = chain_param(p, joints)[1]
            # (high on the hip it is the body's as much as the thigh's)
            made = chain_weights(along, ["thigh", "shin"], 0.18)
            made = {name + suffix: w for name, w in made.items()}
            top = blend(0.86 + 0.06, 0.86 - 0.04, p.y) if along < 0.25 else 1.0
            top = 1.0 - (1.0 - top) * 0.5
            out = {k: v * top for k, v in made.items()}
            out["body"] = 1.0 - top
            return out
        if part == "shins":
            joints = [mirror(j, side) for j in LEG]
            along = chain_param(p, joints)[1]
            return {name + suffix: w for name, w in chain_weights(along, LEG_NAMES, 0.15).items()}
        if part == "feet":
            sickle = [mirror(j, side) for j in SICKLE]
            d_sickle = chain_param(p, sickle)[0]
            ball = mirror(LEG[3], side)
            if (p.y > 0.055 and p.z > ball.z + 0.03 and abs(p.x) < abs(ball.x) + 0.002) or d_sickle < 0.02:
                return {"sickle" + suffix: 1.0}
            joints = [mirror(j, side) for j in LEG]
            off, along = chain_param(p, joints)
            if p.z > ball.z - 0.005 and p.y < 0.06:
                return {"foot" + suffix: 1.0}
            made = chain_weights(min(along, 2.98), LEG_NAMES, 0.12)
            return {name + suffix: w for name, w in made.items()}
        if part in ("arms", "hands", "wing_feathers"):
            joints = [mirror(j, side) for j in ARM]
            if part == "hands":
                return {"hand" + suffix: 1.0}
            if part == "wing_feathers":
                # (by where its root is: the nearer of the forearm or the hand; the
                # tips lag behind the bone they grow from towards the one before,
                # so that the wing fans out as it opens rather than swinging round)
                return feather_weight(p, side, suffix)
            along = chain_param(p, joints[:3])[1]
            made = chain_weights(along, ARM_NAMES[:2], 0.2)
            made = {name + suffix: w for name, w in made.items()}
            if along < 0.25:
                share = blend(0.25, 0.0, along) * 0.6
                made = {k: v * (1.0 - share) for k, v in made.items()}
                made["chest"] = share
            return made
        if part == "tail_fan":
            off, along = chain_param(p, TAIL)
            return chain_weights(min(along, 3.99), TAIL_NAMES[:4], 0.25)
        return {"body": 1.0}

    return weigh


FEATHER_ROOTS = {}


def feather_weight(p, side, suffix):
    shoulder, elbow, wrist, tips = (mirror(j, side) for j in ARM)
    # (which bone the nearest feather root is on, and how far out along the feather this point is)
    on_hand = chain_param(p, [wrist, tips])
    on_fore = chain_param(p, [elbow, wrist])
    behind = max(0.0, min(1.0, (max(wrist.z, elbow.z) - p.z) / 0.28))
    if on_hand[0] < on_fore[0] * 0.9 and p.y < wrist.y - 0.02 and p.z > tips.z - 0.25:
        return {"hand" + suffix: 1.0 - 0.45 * behind, "forearm" + suffix: 0.45 * behind}
    return {"forearm" + suffix: 1.0 - 0.4 * behind, "arm" + suffix: 0.4 * behind}


def bones():
    listed = [
        ("body", HIP, None), ("chest", CHEST, "body"),
        ("neck", NECK, "chest"), ("neck_1", NECK_1, "neck"), ("neck_2", NECK_2, "neck_1"), ("head", HEAD, "neck_2"),
        ("jaw", JAW, "head"),
    ]
    parent = "body"
    for name, joint in zip(TAIL_NAMES, TAIL):
        listed.append((name, joint, parent))
        parent = name
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        # (the leg's bones all hang from the body: the rig places each in the body's space)
        for name, joint in zip(LEG_NAMES, LEG):
            listed.append((name + suffix, mirror(joint, side), "body"))
        listed.append(("sickle" + suffix, mirror(SICKLE[0], side), "foot" + suffix))
        listed.append(("toe_end" + suffix, mirror(LEG[3], side) + V(side * 0.012, -0.03, 0.13), "foot" + suffix))
        parent = "chest"
        for name, joint in zip(ARM_NAMES, ARM[:3]):
            listed.append((name + suffix, mirror(joint, side), parent))
            parent = name + suffix
        listed.append(("hand_end" + suffix, mirror(ARM[3], side), "hand" + suffix))
    return listed


# --- Colours ---

MATERIALS = [("coat", (0.30, 0.285, 0.265)), ("feathers", (1.0, 1.0, 1.0)), ("parts", (1.0, 1.0, 1.0))]
# (sRGB colour, and in alpha how wet it is: 1 is an eye)
PART_COLOURS = {
    "eyes": (0.70, 0.60, 0.40, 1.0), "nostrils": (0.03, 0.03, 0.03, 0.4), "mouth": (0.24, 0.11, 0.11, 0.6),
    "teeth_upper": (0.78, 0.75, 0.66, 0.3), "teeth_lower": (0.78, 0.75, 0.66, 0.3),
    "feet": (0.20, 0.19, 0.18, 0.02), "hands": (0.20, 0.19, 0.18, 0.02),
}
CLAW = (0.08, 0.075, 0.07, 0.3)


def paint(whole, part_of):
    """Vertex colours (see the top of this file), and the eyes' second texture
    coordinates (where on the eye's front a point is, for the pupil)."""
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    coated = [part in ("coat", "skull", "jaw", "thighs", "shins", "arms") for part in part_of]
    open_ = [1.0] * len(whole.verts)
    for vert in whole.verts:
        if not coated[vert.index] or not vert.link_edges:
            continue
        rise = 0.0
        for edge in vert.link_edges:
            step = edge.other_vert(vert).co - vert.co
            if step.length > 1e-6:
                rise += step.dot(vert.normal) / step.length
        open_[vert.index] = rise / len(vert.link_edges)
    for _ in range(3):
        spread = list(open_)
        for vert in whole.verts:
            if coated[vert.index] and vert.link_edges:
                around = [open_[e.other_vert(vert).index] for e in vert.link_edges]
                spread[vert.index] = 0.5 * open_[vert.index] + 0.5 * sum(around) / len(around)
        open_ = spread
    measured = sorted(open_[i] for i in range(len(open_)) if coated[i])
    middle = measured[len(measured) // 2] if measured else 0.0
    across_uv = {}
    tones = {}
    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part in FEATHER_PARTS:
            continue
        if part in PART_COLOURS or part in ("feet", "hands"):
            r, g, b, wet = PART_COLOURS.get(part, (0.2, 0.2, 0.2, 0.1))
            if part in ("feet", "hands"):
                # (the claws are horn, darker and glossier than the scaly skin)
                if is_claw(p, part):
                    r, g, b, wet = CLAW
                else:
                    # (rows of scutes down the front of the long foot and along the toes)
                    band = 0.5 + 0.5 * math.sin(p.y * 260.0 + p.z * 140.0)
                    tone = 0.85 + 0.25 * band ** 4
                    r, g, b = r * tone, g * tone, b * tone
            vert[layer] = (r, g, b, wet)
            if part == "eyes":
                side = 1.0 if p.x >= 0.0 else -1.0
                at, radius = EYE
                centre = HEAD + mirror(at, side)
                out = V(side * 0.92, 0.12, 0.38).normalized()
                across = Y.cross(out).normalized()
                upward = out.cross(across).normalized()
                q = p - centre
                if q.dot(out) > 0.0:
                    across_uv[vert.index] = (0.5 + q.dot(across) / radius * 0.4, 0.5 + q.dot(upward) / radius * 0.4)
                else:
                    across_uv[vert.index] = (0.95, 0.95)
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 4.0, 0.0), 1.0)
        dark = 0.0
        pale = 0.0
        plume = 1.0
        q = p - HEAD
        if part in ("skull", "jaw"):
            # A dark mask from the snout back through the eye; the throat and lips pale.
            at, radius = EYE
            eye_y = at.y
            mask = blend(0.030, 0.012, abs(q.y - eye_y + 0.004 * (q.z - at.z) * 10.0)) * blend(0.33, 0.24, q.z) * blend(-0.04, 0.02, q.z)
            dark = max(dark, mask * 0.85)
            pale = max(pale, blend(-0.03, -0.065, q.y) * 0.7 if part == "skull" else 0.75)
            # Feathered on the crown and cheeks, bare and scaly over the snout, a bare ring round each eye.
            plume = blend(0.30, 0.13, q.z)
            eye_gap = (q - mirror(at, 1.0 if q.x >= 0.0 else -1.0)).length
            plume *= blend(radius * 1.15, radius * 1.9, eye_gap)
            if part == "jaw":
                plume = blend(0.20, 0.06, q.z) * 0.8
                # (inside the mouth, seen when it gapes: dark, bare)
                along = min(max((q.z - 0.04) / 0.34, 0.0), 1.0)
                centre_y = (JAW.y + (JAW_TIP.y - JAW.y) * along) - HEAD.y
                inside = blend(0.004, 0.016, q.y - centre_y) * blend(0.33, 0.28, q.z)
                dark = max(dark, inside)
                plume *= 1.0 - inside
                pale *= 1.0 - inside
            else:
                inside = blend(-0.035, -0.06, q.y) * blend(0.004, 0.02, 0.03 - abs(q.x)) * blend(0.05, 0.1, q.z)
                dark = max(dark, inside * 0.9)
        elif part == "coat":
            off, along = chain_param(p, [s[0] for s in SPINE])
            centre = SPINE[min(int(along), len(SPINE) - 1)][0]
            up = p.y - centre.y
            # The saddle down its back and neck, a little darker.
            dark = blend(0.0, 0.08, up) * 0.35
            # The underside paler: throat, chest, belly, under the tail's root.
            pale = blend(-0.02, -0.12, up) * blend(-0.55, -0.2, p.z) * 0.75
            # Bars across the tail, darker towards its end.
            if p.z < -0.35:
                bars = 0.5 + 0.5 * math.cos((p.z + 0.35) / 0.17 * math.tau)
                dark = max(dark, blend(0.55, 0.9, bars) * blend(-0.35, -0.9, p.z) * 0.7)
                pale *= 0.6
            # (a faint dark streak down the side of the neck)
            if p.z > 0.55:
                dark = max(dark, blend(0.02, 0.0, abs(abs(p.x) - 0.045)) * blend(0.6, 0.75, p.z) * 0.25)
        elif part == "thighs":
            dark = 0.1
        elif part == "shins":
            plume = blend(0.12, 0.42, p.y)
            dark = 0.15
        elif part == "arms":
            dark = 0.25
        vert[layer] = (shade, dark, pale, plume)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))


def is_claw(p, part):
    if part == "hands":
        for side in (1.0, -1.0):
            wrist, tips = mirror(ARM[2], side), mirror(ARM[3], side)
            if (p - wrist).length > 0.14:
                return True
        return False
    side = 1.0 if p.x >= 0.0 else -1.0
    ball = mirror(LEG[3], side)
    claw_root = mirror(SICKLE[2], side)
    if (p - claw_root).length < 0.13 and p.y > claw_root.y - 0.005:
        return True
    if p.z > ball.z + 0.105 and p.y < 0.04:
        return True
    dew = mirror(LEG[2], side).lerp(ball, 0.72)
    if p.z < dew.z - 0.022 and p.y < dew.y - 0.006 and (p - dew).length < 0.05:
        return True
    return False


FEATHER_PARTS = ("wing_feathers", "tail_fan", "tufts")


def paint_feathers(whole, part_of, layer):
    """The vanes' colours: dark grey-brown, each a little different; alpha how
    strongly it is barred (the flight feathers and the tail fan: strongly)."""
    tone_of = {}
    for vert in whole.verts:
        part = part_of[vert.index]
        if part not in FEATHER_PARTS:
            continue
        p = kit.from_blender(vert.co)
        key = (part, round(p.x * 40.0) if part != "tail_fan" else 0)
        base = (0.24, 0.225, 0.205)
        vary = 0.9 + 0.2 * ((hash((part, round(p.x * 30), round(p.z * 12))) % 100) / 100.0)
        barred = {"wing_feathers": 0.85, "tail_fan": 1.0, "tufts": 0.0}[part]
        if part == "tufts":
            base = (0.28, 0.265, 0.245)
        vert[layer] = (base[0] * vary, base[1] * vary, base[2] * vary, barred)


def export(preview):
    low = kit.LOW
    name = "deinonychus" + ("_lo" if low else "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = kit.make_armature(bones())
    whole = bmesh.new()
    whole.loops.layers.uv.verify()
    part_of = []
    listed = [
        ("coat", 0, coat), ("skull", 0, skull), ("jaw", 0, lower_jaw), ("thighs", 0, thighs), ("shins", 0, shins), ("arms", 0, arms),
        ("wing_feathers", 1, wing_feathers), ("tail_fan", 1, tail_fan), ("tufts", 1, tufts),
        ("eyes", 2, eyes), ("nostrils", 2, nostrils), ("mouth", 2, mouth), ("teeth_upper", 2, lambda: teeth(True)),
        ("teeth_lower", 2, lambda: teeth(False)), ("feet", 2, feet), ("hands", 2, hands),
    ]
    for part, material, make in listed:
        built = make()
        mesh = built.mesh() if isinstance(built, Part) else kit.fused(built, None)
        first = len(whole.faces)
        whole.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        whole.faces.ensure_lookup_table()
        for face in whole.faces[first:]:
            face.material_index = material
            face.smooth = not (low and material == 2)
        part_of += [part] * (len(whole.verts) - len(part_of))
    paint(whole, part_of)
    paint_feathers(whole, part_of, whole.verts.layers.float_color["Color"])

    mesh = bpy.data.meshes.new(name)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    for label, srgb in MATERIALS:
        made = bpy.data.materials.new(label)
        made.use_nodes = True
        colour = tuple(kit.linear(c) for c in srgb) + (1.0,)
        bsdf = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Roughness"].default_value = 1.0
        made.diffuse_color = colour
        mesh.materials.append(made)
    groups = {bone.name: body.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
    deform = whole.verts.layers.deform.verify()
    weigh = weights()
    for vert, part in zip(whole.verts, part_of):
        for bone, weight in weigh(part, kit.from_blender(vert.co)).items():
            if weight > 0.001:
                vert[deform][groups[bone]] = weight
    whole.to_mesh(mesh)
    whole.free()
    for attribute in [a for a in mesh.color_attributes if a.name != "Color"]:
        mesh.color_attributes.remove(attribute)
    painted = mesh.color_attributes["Color"]
    mesh.color_attributes.active_color = painted
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    body.parent = armature
    body.modifiers.new("Armature", "ARMATURE").object = armature
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True,
        export_animations=False, export_skins=True, export_vertex_color="ACTIVE",
    )
    print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), kit.triangle_count(mesh)))
    if preview:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(preview, name + ".blend"))
        if not low:
            render(preview, name)


def render(folder, name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (view, direction to the camera in Blender space, what it looks at, how much it frames, colours)
    views = [("side", (1, 0, 0), (0.0, 0.2, 0.75), 3.6, "MATERIAL"), ("quarter", (0.7, -0.7, 0.25), (0.0, -0.1, 0.75), 3.4, "MATERIAL"),
             ("front", (0.02, -1, 0.1), (0.0, -0.6, 0.75), 1.6, "MATERIAL"), ("head", (0.75, -0.6, 0.1), (0.0, -1.05, 1.22), 0.65, "MATERIAL"),
             ("top", (0.0, 0.0, 1), (0.0, 0.2, 0.8), 3.6, "MATERIAL"), ("foot", (0.8, -0.5, 0.15), (0.11, -0.1, 0.12), 0.45, "MATERIAL"),
             ("shade", (0.8, -0.5, 0.2), (0.0, -0.1, 0.75), 3.4, "VERTEX")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 6.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        export(preview)
