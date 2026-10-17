"""Builds the mummy and exports it for Godot, and holds the tools build_boy.py
and build_hound.py use to build the boy and the hounds.

Run from the project root:
    blender --background --python tools/build_character.py

Writes models/<name>.glb (used by the game) and tools/<name>.blend (for hand
edits). If you edit a .blend by hand, export it over its .glb as glTF Binary
with +Y up; re-running this script overwrites both files.

How a figure is made: each part is lofted as simple overlapping shapes, the
shapes of one garment are fused into a single surface (voxel remesh, smooth,
decimate) so shoulders, hips and necks flow into each other, and skin weights
are then worked out from where each vertex sits.

All coordinates below are in Godot space (metres, Y up, the figure faces +Z and
+X is its left) and converted on the way into Blender.

Every bone points straight up with no roll, which makes each bone's rest
orientation the identity in Godot. scripts/character_rig.gd and
scripts/hound_rig.gd rely on that.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None
# Build only some figures: pass their names after the preview folder, e.g. `-- "" mummy`.
ONLY = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
LOW = False  # True while building the demade, low-poly versions


def to_blender(p):
    return Vector((p.x, -p.z, p.y))


def from_blender(p):
    return Vector((p.x, p.z, -p.y))


def blend(edge0, edge1, x):
    """Smoothstep that also works with edge0 > edge1."""
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# The boy (and the mummy, on his skeleton) is modelled with long legs and then
# brought to his real proportions: the legs are shortened between hip and ankle
# and everything above comes down with them. Doing it as a last step keeps every
# measurement below valid. character_rig.gd's THIGH, SHIN and HIP_HEIGHT are the
# settled values.
LEG_SCALE = 0.27 / 0.32
MODELLED_HIP_Y, ANKLE_Y = 0.665, 0.025
DROP = (MODELLED_HIP_Y - ANKLE_Y) * (1.0 - LEG_SCALE)
LEG_PARTS = ("trousers", "ankles", "shoes")


def settled(part, p):
    y = p.y - DROP
    if part in LEG_PARTS and p.y < MODELLED_HIP_Y:
        y = ANKLE_Y + (p.y - ANKLE_Y) * LEG_SCALE if p.y > ANKLE_Y else p.y
    return Vector((p.x, y, p.z))


def unsettled(part, p):
    """Where a settled point was modelled, which is what the weights are written for."""
    y = p.y + DROP
    if part in LEG_PARTS and p.y < MODELLED_HIP_Y - DROP:
        y = ANKLE_Y + (p.y - ANKLE_Y) / LEG_SCALE if p.y > ANKLE_Y else p.y
    return Vector((p.x, y, p.z))


class Builder:
    """Collects the closed shapes that make up one part of a figure."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()
        self.place = None  # optional function applied to every point
        self.settle = None  # optional last step, bringing a figure to its final proportions

    def tube(self, rings, segments=16, floor=None):
        """Skins a closed surface over rings of (centre, u, v) and caps both ends.

        Its texture coordinates run (along it from first ring to last, round it),
        which is what tells the hair shader which way a lock lies.
        """
        if LOW:
            segments = 8 if segments >= 20 else 6 if segments >= 16 else 5 if segments >= 12 else 4
            if len(rings) > 7:
                rings = rings[:1] + rings[1:-1][::2] + rings[-1:]
        loops = []
        for centre, u, v in rings:
            loop = []
            for i in range(segments):
                angle = math.tau * i / segments
                loop.append(self._vert(centre + u * math.cos(angle) + v * math.sin(angle), floor))
            loops.append(loop)
        faces = []
        last = max(len(loops) - 1, 1)

        def face(verts, coords):
            made = self.bm.faces.new(verts)
            for loop, (along, around) in zip(made.loops, coords):
                loop[self.uv].uv = (along / last, around / segments)
            faces.append(made)

        for r, (a, b) in enumerate(zip(loops, loops[1:])):
            for i in range(segments):
                j = (i + 1) % segments
                face((a[i], a[j], b[j], b[i]), ((r, i), (r, i + 1), (r + 1, i + 1), (r + 1, i)))
        for r, loop, (centre, _, _) in ((0, loops[0], rings[0]), (last, loops[-1], rings[-1])):
            pole = self._vert(centre, floor)
            for i in range(segments):
                face((loop[i], loop[(i + 1) % segments], pole), ((r, i), (r, i + 1), (r, i + 0.5)))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)

    def ellipsoid(self, centre, radii, tilt=None, segments=12, rings=7):
        if LOW:
            segments, rings = 16, 3
        loops = []
        for k in range(1, rings + 1):
            phi = -math.pi / 2 + math.pi * k / (rings + 1)
            c, s = math.cos(phi), math.sin(phi)
            ring = (Y * radii.y * s, X * radii.x * c, Z * radii.z * c)
            if tilt:
                ring = tuple(tilt @ part for part in ring)
            loops.append((centre + ring[0], ring[1], ring[2]))
        self.tube(loops, segments)

    def strand(self, points, radii, segments=8):
        """A round-ended tube following a line of points (a finger, a tail)."""
        rings = []
        for i, point in enumerate(points):
            ahead = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
            ahead.normalize()
            u = ahead.cross(Z if abs(ahead.z) < 0.9 else X).normalized()
            rings.append((point, u * radii[i], ahead.cross(u) * radii[i]))
        first = (points[0] - points[1]).normalized()
        last = (points[-1] - points[-2]).normalized()
        self.tube(dome(rings[0], first, radii[0], 2)[::-1] + rings + dome(rings[-1], last, radii[-1], 2), segments)

    def _vert(self, position, floor):
        # (see `settled`: runs after everything else)
        if floor is not None and position.y < floor:
            position = Vector((position.x, floor, position.z))
        if self.place:
            position = self.place(position)
        if self.settle:
            position = self.settle(position)
        return self.bm.verts.new(to_blender(position))


def dome(ring, axis, height, steps=4):
    """Rings that round off the end of a tube, starting just past `ring`."""
    if LOW:
        steps = 1
    centre, u, v = ring
    out = []
    for k in range(1, steps + 1):
        angle = math.pi / 2 * k / (steps + 0.6)
        out.append((centre + axis * height * math.sin(angle), u * math.cos(angle), v * math.cos(angle)))
    return out


def upright(x, y, z, rx, rz):
    return (Vector((x, y, z)), X * rx, Z * rz)


def lengthwise(z, y, rx, ry):
    return (Vector((0.0, y, z)), X * rx, Y * ry)


# --- The first boy. The boy is now built by build_boy.py; what is left here is the layout the mummy is built on. ---

HIPS = Vector((0.0, 0.685, 0.0))
SPINE = HIPS + Vector((0.0, 0.03, 0.0))
HEAD = SPINE + Vector((0.0, 0.35, 0.0))
SHOULDER_X, SHOULDER_Y = 0.155, SPINE.y + 0.28
HIP_X, HIP_Y = 0.075, HIPS.y - 0.02
UPPER_ARM = 0.2
FOREARM = 0.175
THIGH = SHIN = 0.32
SOLE_DROP = 0.05  # ankle joint height above the sole
TOE = Vector((0.0, -0.035, 0.075))  # where the foot bends, from the ankle
# The arms are modelled held slightly away from the body so the sleeves do not
# fuse to the shirt; the rig turns them back (ARM_REST in character_rig.gd).
ARM_REST = 0.22

BOY_MATERIALS = [
    ("shirt", (0.44, 0.12, 0.13)),
    ("trousers", (0.05, 0.05, 0.06)),
    ("skin", (0.76, 0.66, 0.56)),
    ("hair", (0.05, 0.045, 0.04)),
    ("socks", (0.86, 0.86, 0.83)),
]


def shoulder_of(side):
    return Vector((side * SHOULDER_X, SHOULDER_Y, 0.0))


def arm_rest(side):
    """Moves a point modelled on a straight-hanging arm to the arm's rest pose."""
    turn = Matrix.Rotation(side * ARM_REST, 3, "Z")
    pivot = shoulder_of(side)
    return lambda p: pivot + turn @ (p - pivot)


def boy_shirt(b):
    # (height, half width, half depth, forward offset). Starts tucked up inside the hem.
    profile = [
        (0.700, 0.094, 0.078, 0.000), (0.672, 0.097, 0.081, 0.000),
        # A loose hem hanging clear of the trousers, a boxy body, soft sloping
        # shoulders, and a crew neck standing off the neck
        (0.668, 0.115, 0.100, 0.002), (0.682, 0.116, 0.101, 0.002), (0.74, 0.110, 0.096, 0.002),
        (0.82, 0.104, 0.090, 0.003), (0.89, 0.104, 0.090, 0.004), (0.935, 0.112, 0.088, 0.003),
        # The shoulders are part of the body of the shirt, sloping out over the
        # tops of the arms, so the sleeves grow out of it rather than sit on it
        (0.962, 0.162, 0.074, 0.001), (0.985, 0.178, 0.068, 0.000), (1.004, 0.158, 0.066, -0.001),
        (1.020, 0.120, 0.064, -0.002), (1.036, 0.088, 0.062, -0.002), (1.048, 0.068, 0.060, -0.002),
        (1.058, 0.060, 0.057, -0.001), (1.066, 0.057, 0.056, 0.000),
        (1.072, 0.051, 0.051, 0.000), (1.060, 0.045, 0.045, 0.000), (1.040, 0.043, 0.043, 0.000),
    ]
    b.tube([upright(0, y, z, rx, rz) for y, rx, rz, z in profile], 20)
    for side in (1.0, -1.0):
        b.place = arm_rest(side)
        x = side * SHOULDER_X
        # (distance down the arm, radius); the elbow sits slightly back
        # Pushed up: the sleeve stops in a bunched roll just past the elbow
        sleeve = [(0.00, 0.034), (0.025, 0.041), (0.06, 0.044), (0.13, 0.043), (0.17, 0.042), (0.20, 0.042),
                  (0.222, 0.044), (0.238, 0.048), (0.252, 0.047), (0.258, 0.040), (0.236, 0.034)]
        rings = [upright(x, SHOULDER_Y - d, -0.004 * math.sin(math.pi * min(d / 0.4, 1.0)), r, r) for d, r in sleeve]
        rings = dome(rings[0], Y, 0.026)[::-1] + rings
        b.tube(rings)
    b.place = None


def boy_trousers(b):
    seat = upright(0, 0.635, -0.004, 0.100, 0.086)
    b.tube(dome(seat, -Y, 0.045)[::-1] + [seat, upright(0, 0.69, -0.002, 0.104, 0.089), upright(0, 0.74, 0, 0.099, 0.083)]
           + dome(upright(0, 0.74, 0, 0.099, 0.083), Y, 0.03))
    for side in (1.0, -1.0):
        x = side * HIP_X
        # (distance below the hip, radius, forward offset): thigh, knee, calf, hem
        profile = [
            (0.00, 0.072, 0.000), (0.08, 0.071, 0.001), (0.18, 0.066, 0.003), (0.25, 0.062, 0.005),
            (0.29, 0.060, 0.007), (0.32, 0.060, 0.009), (0.35, 0.058, 0.006), (0.39, 0.056, -0.001),
            (0.46, 0.054, -0.006), (0.53, 0.047, -0.003), (0.562, 0.039, 0.000), (0.574, 0.034, 0.000), (0.588, 0.033, 0.001),
        ]
        rings = [upright(x, HIP_Y - d, z, r, r * 1.06) for d, r, z in profile]
        rings = dome(rings[0], Y, 0.05)[::-1] + rings
        rings.append(upright(x, HIP_Y - 0.590, 0.002, 0.029, 0.030))
        rings.append(upright(x, HIP_Y - 0.565, 0.0, 0.026, 0.027))
        b.tube(rings)


def boy_head(b):
    b.tube([upright(0, y, 0.002, 0.033, 0.035) for y in (1.02, 1.06, 1.11)], 12)
    centre = HEAD + Vector((0.0, 0.146, 0.008))
    rings = []
    count = 13
    for k in range(1, count + 1):
        phi = -math.pi / 2 + math.pi * k / (count + 1)
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        # Narrower towards a chin that sits slightly forward.
        rings.append(upright(0.0, centre.y + 0.148 * s, centre.z + 0.016 * jaw - 0.008 * max(0.0, s),
                             0.110 * c * (1.0 - 0.2 * jaw ** 1.5), 0.124 * c))
    b.tube(rings, 24)
    for side in (1.0, -1.0):
        b.ellipsoid(centre + Vector((side * 0.110, -0.013, -0.013)), Vector((0.014, 0.030, 0.020)), None, 8, 5)


def spike(b, base, tip, radius, segments=8):
    """A lock of hair: a cone from `base` to a point at `tip`."""
    ahead = (tip - base).normalized()
    u = ahead.cross(X if abs(ahead.x) < 0.9 else Y).normalized()
    v = ahead.cross(u)
    b.tube([(base.lerp(tip, t), u * radius * (1.0 - t), v * radius * (1.0 - t)) for t in (0.0, 0.35, 0.7, 0.96)], segments)


def boy_hair(b):
    # A cap tilted so the hairline is high on the brow and low at the nape...
    centre = HEAD + Vector((0.0, 0.146, 0.008))
    tilt = Matrix.Rotation(-0.5, 3, "X")
    crown = centre + Vector((0.0, 0.012, -0.004))
    cap = []
    for k in range(10):
        phi = -0.30 + (math.pi / 2 + 0.30) * k / 10
        c, s = math.cos(phi), math.sin(phi)
        cap.append((crown + tilt @ (Y * 0.150 * s), tilt @ (X * 0.116 * c), tilt @ (Z * 0.131 * c)))
    b.tube(cap, 24)
    if LOW:
        return
    # ...broken into jagged locks: a ragged fringe over the brow, points down
    # the sides and the nape, and a tuft at the crown.
    for x, drop, radius in ((-0.082, 0.062, 0.034), (-0.046, 0.098, 0.036), (-0.006, 0.070, 0.040), (0.040, 0.108, 0.036), (0.080, 0.066, 0.034)):
        base = centre + Vector((x, 0.090, 0.078 - abs(x) * 0.3))
        spike(b, base, base + Vector((x * 0.2 + 0.012, -drop, 0.040 - abs(x) * 0.12)), radius)
    for angle, drop in ((1.25, 0.075), (1.75, 0.095), (2.3, 0.085), (2.85, 0.105), (3.43, 0.085), (3.98, 0.095), (4.53, 0.075), (5.03, 0.075)):
        out = Vector((math.sin(angle), 0.0, math.cos(angle)))
        base = centre + out * 0.098 + Y * (-0.012 if math.cos(angle) < 0.3 else 0.03)
        spike(b, base, base + out * 0.026 - Y * drop, 0.034)
    spike(b, centre + Vector((0.01, 0.125, -0.04)), centre + Vector((0.025, 0.160, -0.085)), 0.045)


def boy_forearms(b):
    # Bare below the pushed-up sleeves, tapering to the wrist
    for side in (1.0, -1.0):
        b.place = arm_rest(side)
        x = side * SHOULDER_X
        b.tube([upright(x, SHOULDER_Y - d, -0.003, r, r * 1.08) for d, r in
                ((0.215, 0.030), (0.25, 0.029), (0.30, 0.025), (0.345, 0.020), (0.38, 0.017))], 12)
    b.place = None


def boy_hands(b):
    for side in (1.0, -1.0):
        b.place = arm_rest(side)
        wrist = shoulder_of(side) - Y * (UPPER_ARM + FOREARM) + Z * 0.003
        inward = -side  # the palm faces the body

        # Palm: thin across the hand, widening to the knuckles
        palm = [(0.022, 0.015, 0.018), (0.0, 0.0135, 0.022), (-0.022, 0.0125, 0.029), (-0.045, 0.0115, 0.033), (-0.058, 0.0105, 0.032)]
        rings = [(wrist + Y * dy, X * rx, Z * rz) for dy, rx, rz in palm]
        b.tube(rings + dome(rings[-1], -Y, 0.008, 2), 12)

        # Fingers, little finger (back) to index (front), loosely curled towards the palm
        for z, length, radius in (() if LOW else ((-0.0245, 0.034, 0.0080), (-0.0082, 0.043, 0.0088), (0.0082, 0.046, 0.0090), (0.0245, 0.042, 0.0088))):
            point = wrist + Vector((0.0, -0.058, z))
            points = [point]
            for curl, share in ((0.12, 0.42), (0.45, 0.33), (0.85, 0.25)):
                point = point + Vector((inward * math.sin(curl), -math.cos(curl), 0.0)) * (length * share)
                points.append(point)
            b.strand(points, [radius, radius * 0.97, radius * 0.9, radius * 0.8])

        if LOW:
            # Demade: the fingers are a single curled mitt
            mitt = [(-0.058, 0.0, 0.0095, 0.027), (-0.082, 0.006, 0.0085, 0.025), (-0.102, 0.016, 0.007, 0.020)]
            b.tube([(wrist + Vector((inward * x, dy, 0.0)), X * rx, Z * rz) for dy, x, rx, rz in mitt], 12)
        # Thumb, off the front edge of the palm
        root = wrist + Vector((inward * 0.003, -0.012, 0.018))
        b.strand([root, root + Vector((inward * 0.004, -0.018, 0.016)), root + Vector((inward * 0.011, -0.036, 0.022)),
                  root + Vector((inward * 0.018, -0.050, 0.022))], [0.0115, 0.0108, 0.0096, 0.0084])
    b.place = None


def ankle_of(side):
    return Vector((side * HIP_X, HIP_Y - THIGH - SHIN, 0.0))


def boy_ankles(b):
    # Bare ankle between the trouser hem and the shoe
    for side in (1.0, -1.0):
        ankle = ankle_of(side)
        b.tube([upright(ankle.x, ankle.y + dy, z, r, r * 1.12) for dy, r, z in
                ((0.11, 0.030, -0.002), (0.07, 0.026, -0.003), (0.035, 0.024, -0.002), (0.005, 0.027, 0.0), (-0.02, 0.028, 0.004))], 12)


def boy_shoes(b):
    for side in (1.0, -1.0):
        ankle = ankle_of(side)
        floor = ankle.y - SOLE_DROP

        def across(z, y, rx, ry, ankle=ankle):
            return (ankle + Vector((0.0, y, z)), X * rx, Y * ry)

        # The upper, heel to toe: a heel cup, sides that come up round the ankle, a rounded toe box
        upper = [
            across(-0.040, -0.018, 0.031, 0.032), across(-0.018, -0.006, 0.037, 0.046), across(0.012, -0.011, 0.039, 0.040),
            across(0.040, -0.023, 0.042, 0.028), across(0.072, -0.030, 0.043, 0.021), across(0.103, -0.033, 0.040, 0.018),
            across(0.124, -0.034, 0.033, 0.015),
        ]
        b.tube(dome(upper[0], -Z, 0.014, 3)[::-1] + upper + dome(upper[-1], Z, 0.018, 3), 16, floor)
        # The sole: a slab standing proud of the upper all round
        b.tube([(Vector((ankle.x, y, 0.045)), X * 0.046, Z * 0.096) for y in (floor, floor + 0.007, floor + 0.014)], 24)
    # Sit exactly on the ground
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, ankle_of(1.0).y - SOLE_DROP)


def boy_weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    side = 1.0 if p.x >= 0.0 else -1.0
    if part == "hair":
        return {"head": 1.0}
    if part == "head":
        upper = blend(1.045, 1.085, p.y)
        return {"spine": 1.0 - upper, "head": upper}
    if part == "hands":
        return {"hand" + suffix: 1.0}
    if part == "shoes":
        toe = blend(TOE.z - 0.015, TOE.z + 0.015, p.z)
        return {"foot" + suffix: 1.0 - toe, "toe" + suffix: toe}
    if part == "ankles":
        ankle_y = HIP_Y - THIGH - SHIN
        foot = blend(ankle_y + 0.05, ankle_y, p.y)
        return {"shin" + suffix: 1.0 - foot, "foot" + suffix: foot}
    if part == "trousers":
        leg = blend(HIP_Y + 0.05, HIP_Y - 0.07, p.y)
        left = blend(-0.012, 0.012, p.x)
        knee_y = HIP_Y - THIGH
        shin = blend(knee_y + 0.05, knee_y - 0.05, p.y)
        return {
            "hips": 1.0 - leg,
            "thigh_l": leg * left * (1.0 - shin), "shin_l": leg * left * shin,
            "thigh_r": leg * (1.0 - left) * (1.0 - shin), "shin_r": leg * (1.0 - left) * shin,
        }
    # The shirt: body below, an arm wherever the point is close to that arm's axis
    shoulder = shoulder_of(side)
    axis = Matrix.Rotation(side * ARM_REST, 3, "Z") @ -Y
    along = min(max((p - shoulder).dot(axis), 0.0), UPPER_ARM + FOREARM)
    arm = blend(0.078, 0.046, (p - shoulder - axis * along).length)
    if part == "forearms":
        arm = 1.0
    fore = blend(UPPER_ARM - 0.04, UPPER_ARM + 0.04, along)
    low = blend(0.81, 0.71, p.y)
    return {
        "hips": low * (1.0 - arm), "spine": (1.0 - low) * (1.0 - arm),
        "upper_arm" + suffix: arm * (1.0 - fore), "forearm" + suffix: arm * fore,
    }


def boy_bones():
    bones = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("head", HEAD, "spine")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        shoulder = shoulder_of(side)
        bones.append(("upper_arm" + suffix, shoulder, "spine"))
        bones.append(("forearm" + suffix, arm_rest(side)(shoulder - Y * UPPER_ARM), "upper_arm" + suffix))
        bones.append(("hand" + suffix, arm_rest(side)(shoulder - Y * (UPPER_ARM + FOREARM)), "forearm" + suffix))
        # Leg bones are siblings: the rig places each one directly with IK.
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        bones.append(("thigh" + suffix, hip, "hips"))
        bones.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        bones.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        bones.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
    return bones


# (part, material, shapes, fuse as (voxel size, smoothing passes, triangle budget) or None)
BOY_PARTS = [
    ("shirt", 0, boy_shirt, (0.005, 8, 4800)),
    ("trousers", 1, boy_trousers, (0.005, 6, 4000)),
    ("head", 2, boy_head, (0.004, 5, 2600)),
    ("hands", 2, boy_hands, (0.0016, 2, 2400)),
    ("forearms", 2, boy_forearms, (0.003, 3, 800)),
    ("hair", 3, boy_hair, (0.004, 2, 1800)),
    ("ankles", 4, boy_ankles, (0.003, 3, 700)),
    ("shoes", 3, boy_shoes, (0.003, 3, 3000)),
]
BOY_PARTS_LOW = [(part, material, shapes, None) for part, material, shapes, _fuse in BOY_PARTS]


# (The hounds are built by tools/build_hound.py.)


# --- The mummy. Laid out like the boy (same bone names, so the same rig animates it) but with its own proportions. ---

MUMMY_MATERIALS = [("linen", (0.50, 0.45, 0.36)), ("hollow", (0.03, 0.025, 0.02))]


def lapped(x, z, profile, band=0.03, lap=0.005):
    """Rings for an upright tube wound in bandage: each turn overlaps the one below.

    `profile` is (height, half width, half depth, forward offset) from the bottom up.
    """
    rings = []
    y = profile[0][0]
    while y < profile[-1][0]:
        for level, scale in ((y, lap), (min(y + band, profile[-1][0]) - 0.001, 0.0)):
            for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(profile, profile[1:]):
                if y0 <= level <= y1:
                    t = (level - y0) / (y1 - y0)
                    rings.append(upright(x, level, z + z0 + (z1 - z0) * t, rx0 + (rx1 - rx0) * t + scale, rz0 + (rz1 - rz0) * t + scale))
                    break
        y += band
    return rings


def mummy_torso(b):
    # Sunken belly, a ribcage, shoulders hunched forward
    profile = [(0.69, 0.084, 0.070, 0.0), (0.78, 0.076, 0.064, 0.0), (0.86, 0.092, 0.076, 0.006), (0.94, 0.112, 0.084, 0.010),
               (0.99, 0.130, 0.078, 0.004), (1.02, 0.116, 0.068, -0.004), (1.045, 0.060, 0.050, -0.004), (1.068, 0.034, 0.034, 0.0)]
    b.tube(lapped(0.0, 0.0, profile), 20)
    for side in (1.0, -1.0):
        b.place = arm_rest(side)
        arm = [(-0.41, 0.022, 0.022, 0.0), (-0.38, 0.021, 0.021, 0.0), (-0.24, 0.025, 0.025, -0.002), (-0.21, 0.030, 0.030, -0.004),
               (-0.19, 0.026, 0.026, -0.002), (-0.10, 0.030, 0.030, 0.0), (0.0, 0.035, 0.035, 0.0), (0.02, 0.030, 0.030, 0.0)]
        b.tube(lapped(side * SHOULDER_X, 0.0, [(SHOULDER_Y + y, rx, rz, z) for y, rx, rz, z in arm], 0.026, 0.004))
    b.place = None


def mummy_legs(b):
    b.tube(lapped(0.0, -0.002, [(0.60, 0.050, 0.045, 0.0), (0.64, 0.088, 0.074, 0.0), (0.70, 0.090, 0.076, 0.0), (0.75, 0.080, 0.066, 0.0)]))
    for side in (1.0, -1.0):
        leg = [(-0.645, 0.028, 0.030, 0.0), (-0.62, 0.026, 0.028, 0.0), (-0.50, 0.031, 0.033, -0.004), (-0.36, 0.035, 0.036, 0.0),
               (-0.33, 0.039, 0.041, 0.006), (-0.30, 0.037, 0.039, 0.004), (-0.15, 0.045, 0.047, 0.0), (0.0, 0.052, 0.054, 0.0), (0.04, 0.040, 0.042, 0.0)]
        b.tube(lapped(side * HIP_X, 0.0, [(HIP_Y + y, rx, rz, z) for y, rx, rz, z in leg]))


def mummy_skull():
    return HEAD + Vector((0.0, 0.115, 0.006))


def mummy_head(b):
    b.tube([upright(0, y, 0.0, 0.028, 0.030) for y in (1.02, 1.06, 1.11)], 12)
    centre = mummy_skull()
    rings = []
    for k in range(1, 13):
        phi = -math.pi / 2 + math.pi * k / 13
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        # A long skull, hollow at the cheeks, with the jaw hanging
        rings.append(upright(0.0, centre.y + 0.108 * s, centre.z + 0.012 * jaw, 0.083 * c * (1.0 - 0.34 * jaw ** 1.3), 0.094 * c * (1.0 - 0.12 * jaw)))
    b.tube(rings, 20)
    # Turns of bandage crossing the head at angles
    for tilt, y in ((0.2, 0.04), (-0.16, -0.005), (0.1, -0.055)):
        b.ellipsoid(centre + Y * y, Vector((0.085, 0.012, 0.096)), Matrix.Rotation(tilt, 3, "Z") @ Matrix.Rotation(tilt * 0.6, 3, "X"), 16, 5)


def mummy_hollows(b):
    centre = mummy_skull()
    for side in (1.0, -1.0):
        b.ellipsoid(centre + Vector((side * 0.032, 0.008, 0.071)), Vector((0.023, 0.019, 0.017)), None, 10, 5)
    b.ellipsoid(centre + Vector((0.0, -0.052, 0.072)), Vector((0.022, 0.009, 0.014)), None, 8, 5)


def mummy_wrist_tatters(b):
    # Loose ends of bandage hanging from the wrists
    for side in (1.0, -1.0):
        b.place = arm_rest(side)
        wrist = shoulder_of(side) - Y * 0.36
        b.tube([(wrist + Vector((side * 0.014, -d, sway)), X * 0.004, Z * w)
                for d, w, sway in ((0.0, 0.013, 0.0), (0.06, 0.014, 0.006), (0.12, 0.012, -0.004), (0.17, 0.006, 0.004))], 4)
    b.place = None


def mummy_hip_tatter(b):
    b.tube([(Vector((0.088, 0.70 - d, 0.02 + sway)), X * 0.004, Z * w)
            for d, w, sway in ((0.0, 0.017, 0.0), (0.08, 0.018, 0.008), (0.17, 0.015, -0.006), (0.24, 0.007, 0.006))], 4)


MUMMY_PARTS = [
    ("shirt", 0, mummy_torso, (0.004, 3, 5000)),
    ("trousers", 0, mummy_legs, (0.004, 3, 3500)),
    ("head", 0, mummy_head, (0.004, 3, 2200)),
    ("hands", 0, boy_hands, (0.0016, 2, 1600)),
    ("shoes", 0, boy_shoes, (0.003, 3, 1200)),
    ("hair", 1, mummy_hollows, None),
    # (weighted as hands, so they hang from the forearm whatever the arm does)
    ("hands", 0, mummy_wrist_tatters, None),
    ("trousers", 0, mummy_hip_tatter, None),
]


# --- Assembly and export ---

def triangle_count(mesh):
    return sum(len(polygon.vertices) - 2 for polygon in mesh.polygons)


def fused(builder, fuse):
    """The builder's shapes as a mesh; with `fuse`, merged into one smooth surface."""
    mesh = bpy.data.meshes.new("part")
    builder.bm.to_mesh(mesh)
    builder.bm.free()
    if fuse is None:
        return mesh
    voxel, passes, budget = fuse
    part = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(part)
    remesh = part.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    smooth = part.modifiers.new("smooth", "SMOOTH")
    smooth.factor = 0.5
    smooth.iterations = passes

    def evaluated():
        bpy.context.view_layer.update()
        return bpy.data.meshes.new_from_object(part.evaluated_get(bpy.context.evaluated_depsgraph_get()))

    dense = triangle_count(evaluated())
    decimate = part.modifiers.new("decimate", "DECIMATE")
    decimate.ratio = min(1.0, budget / dense)
    result = evaluated()
    bpy.data.objects.remove(part)
    return result


def make_armature(bones):
    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for name, at, parent in bones:
        bone = data.edit_bones.new(name)
        bone.head = to_blender(at)
        bone.tail = to_blender(at + Y * 0.06)
        bone.roll = 0.0
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def export(name, bones, parts, weigh, materials, settle=False, apart=()):
    """Builds a figure and writes it out. Parts named in `apart` are each made an
    object of their own (on the same skeleton) instead of part of the body."""
    if ONLY and name not in ONLY:
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if settle:
        legs = ("thigh", "shin", "foot", "toe")
        bones = [(bone, settled("trousers" if bone.split("_")[0] in legs else "shirt", at), parent) for bone, at, parent in bones]
    armature = make_armature(bones)

    # (object name -> its mesh so far, and which part each of its points came from)
    wholes = {}
    for part, material, shapes, fuse in parts:
        builder = Builder()
        if settle:
            builder.settle = lambda p, part=part: settled(part, p)
        ready = shapes(builder)  # most parts fill the builder; one may hand back a finished mesh
        # (not named for the part alone: a bone may have that name)
        label = "%s_%s" % (name, part) if part in apart else name
        if label not in wholes:
            made = bmesh.new()
            made.loops.layers.uv.verify()
            wholes[label] = (made, [])
        whole, part_of = wholes[label]
        first = len(whole.faces)
        mesh = ready if ready is not None else fused(builder, fuse)
        whole.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        whole.faces.ensure_lookup_table()
        for face in whole.faces[first:]:
            # (a part that brings its own mesh may already have its faces assigned)
            if material is not None:
                face.material_index = material
            face.smooth = not LOW
        part_of += [part] * (len(whole.verts) - len(part_of))

    made_materials = []
    for label, srgb in materials:
        material = bpy.data.materials.new(label)
        material.use_nodes = True
        color = tuple(linear(c) for c in srgb) + (1.0,)
        shader = material.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = 1.0
        material.diffuse_color = color
        made_materials.append(material)

    vertices = triangles = 0
    for label, (whole, part_of) in wholes.items():
        mesh = bpy.data.meshes.new(label)
        body = bpy.data.objects.new(label, mesh)
        bpy.context.collection.objects.link(body)
        for material in made_materials:
            mesh.materials.append(material)
        groups = {bone.name: body.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
        layer = whole.verts.layers.deform.verify()
        for vert, part in zip(whole.verts, part_of):
            for bone, weight in weigh(part, unsettled(part, from_blender(vert.co)) if settle else from_blender(vert.co)).items():
                if weight > 0.001:
                    vert[layer][groups[bone]] = weight
        whole.to_mesh(mesh)
        whole.free()
        body.parent = armature
        body.modifiers.new("Armature", "ARMATURE").object = armature
        vertices += len(mesh.vertices)
        triangles += triangle_count(mesh)

    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", name + ".blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", name + ".glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_skins=True,
    )
    print("BUILT %s verts=%d tris=%d" % (name, vertices, triangles))
    if PREVIEW_DIR:
        render_previews(PREVIEW_DIR, name)


def render_previews(folder, name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (view, direction to the camera, what it looks at, how much it frames)
    views = [("side", (1, 0, 0), (0.0, 0.0, 0.67), 1.5), ("quarter", (0.7, -0.7, 0.25), (0.0, 0.0, 0.67), 1.5)]
    if name == "boy":
        views.append(("front", (0, -1, 0.05), (0.0, 0.0, 0.67), 1.5))
        views.append(("back", (0.25, 1, 0.15), (0.0, 0.0, 0.67), 1.5))
        views.append(("head", (0.6, -0.8, 0.15), (0.0, 0.0, 1.12), 0.5))
        views.append(("headback", (-0.5, 0.85, 0.2), (0.0, 0.0, 1.12), 0.5))
    if name in ("boy", "mummy"):
        views.append(("hand", (-0.6, -0.7, 0.1), (0.22, 0.0, 0.57), 0.22))
        views.append(("chest", (0.5, -0.8, 0.2), (0.0, 0.0, 0.95), 0.6))
        views.append(("foot", (0.75, -0.6, 0.3), (0.075, -0.04, 0.04), 0.32))
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    # The mummy keeps the long legs it is modelled with: its skeleton is its own.
    # (It is laid out with the measurements above headed "the boy", which were
    # the first boy's; the boy himself is now built by build_boy.py.)
    # (That was the first mummy. The mummy is now built by build_mummy.py, which
    # writes models/mummy.glb and mummy_lo.glb; nothing is built from here.)
    pass
