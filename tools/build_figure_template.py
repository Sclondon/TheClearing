"""A template for a new figure on the boy's skeleton. Copy it, rename it, reshape it.

Run from the project root:
    blender --background --python tools/build_figure_template.py
    blender --background --python tools/build_figure_template.py -- <folder>   # also renders previews there

Writes models/<NAME>.glb and models/<NAME>_lo.glb (and editable copies in tools/).
Then, before Godot can use them:
    godot --headless --path . --import
and to see it stand, walk and run on the rig:
    godot --path . --fixed-fps 60 --resolution 960x960 --script tools/figure_sheets.gd -- <folder> res://models/<NAME>.glb 1.4

The example is a night watchman: a stocky man in a short buttoned coat and a
peaked cap. He is built far more simply than the boy (tools/build_boy.py): each
part is a few tubes and ellipsoids, and the coat and the trousers are each fused
into one surface so that shoulders and hips flow.

What scripts/character_rig.gd needs of a figure (the whole contract):

- Godot space: metres, Y up, he faces +Z, +X is HIS left. `_l` bones are at +X.
- Every bone rests unrotated. kit.make_armature sees to that: do not rotate bones.
- These bones, with these parents:
      hips (root) > spine > chest > neck > head
      chest > upper_arm_l/r > forearm_l/r > hand_l/r
      hips > thigh_l/r,  hips > shin_l/r,  hips > foot_l/r > toe_l/r
  The three leg bones are SIBLINGS under hips: the rig places each with IK.
  chest and neck may be left out (then spine > head, and spine > upper_arm), but
  a figure with no chest does not shift and breathe when it stands.
- Proportions are read from the bones, so they are free. But: the ankle joint is
  0.05 above the sole; thigh, shin and foot are in a vertical line under the hip;
  the arm is straight, in the X-Y plane, anywhere from hanging to straight out
  (this one is a T-pose); and the figure should stand about as tall as the boy
  (1.25 m). Make an adult by scaling the rig (Figure.size), not the model.
- Optional bones, used if present: fingerNa/b/c_l/r and thumba/b_l/r (see
  build_boy.py), hem_0.. under spine, hair_f/l/b/r and cap under head.
- The mesh object is named for the figure, so NAME must not be the name of a bone.
"""

import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402  (Builder, export, previews)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

NAME = "watchman"

# --- Joints. Change these and the rig follows: it measures the skeleton. ---

ANKLE_Y = 0.05  # the rig stands every figure's ankle this far above the ground
THIGH = 0.25
SHIN = 0.24
HIP_X = 0.085
HIP_Y = ANKLE_Y + SHIN + THIGH
KNEE_Y = HIP_Y - THIGH
HIPS = Vector((0.0, HIP_Y + 0.03, 0.0))
SPINE = Vector((0.0, 0.66, 0.0))
CHEST = Vector((0.0, 0.80, 0.0))
NECK = Vector((0.0, 0.985, 0.0))
HEAD = Vector((0.0, 1.03, 0.0))
SHOULDER = Vector((0.175, 0.93, 0.0))
UPPER_ARM = 0.20
FOREARM = 0.18
ELBOW_X = SHOULDER.x + UPPER_ARM
WRIST_X = ELBOW_X + FOREARM
TOE = Vector((0.0, -0.035, 0.08))  # where the foot bends, from the ankle
HEAD_CENTRE = Vector((0.0, 1.115, 0.008))
HEAD_RADII = Vector((0.085, 0.105, 0.095))

# --- Colours (sRGB). The names matter to scripts/toon.gd: `hair` gets the hair
# shader, and `shirt` a pinstripe that needs texture coordinates this template
# does not write, so nothing here is called `shirt`. ---

COAT, TROUSERS, SKIN, HAIR, BOOTS, BRASS, BELT, HAT = range(8)
MATERIALS = [
    ("coat", (0.17, 0.21, 0.31)),
    ("trousers", (0.12, 0.13, 0.17)),
    ("skin", (0.80, 0.62, 0.52)),
    ("hair", (0.33, 0.26, 0.19)),
    ("boots", (0.10, 0.08, 0.07)),
    ("brass", (0.76, 0.60, 0.26)),
    ("belt", (0.24, 0.15, 0.09)),
    ("hat", (0.13, 0.16, 0.24)),
]


# --- Shapes. Each function fills a kit.Builder with closed shapes: b.tube(rings),
# b.ellipsoid(centre, radii), b.strand(points, radii). A ring is (centre, u, v):
# kit.upright(x, y, z, rx, rz) is a level one. ---

def coat(b):
    # (height, half width, half depth, forward offset), hem to collar: a barrel of a man
    profile = [(0.585, 0.120, 0.100, 0.004), (0.600, 0.152, 0.124, 0.008), (0.68, 0.154, 0.130, 0.014),
               (0.76, 0.152, 0.124, 0.010), (0.86, 0.164, 0.114, 0.004), (0.925, 0.168, 0.104, 0.0),
               (0.972, 0.118, 0.084, 0.0), (0.998, 0.062, 0.060, 0.0), (1.012, 0.052, 0.052, 0.0)]
    b.tube([kit.upright(0.0, y, z, rx, rz) for y, rx, rz, z in profile], 20)
    for side in (1.0, -1.0):
        # Sleeves, straight out to the cuff: (distance from the shoulder, radius)
        sleeve = [(-0.05, 0.050), (0.0, 0.064), (0.10, 0.058), (UPPER_ARM, 0.053), (0.30, 0.050), (0.345, 0.050), (0.36, 0.040)]
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * r, Z * r) for d, r in sleeve], 12)


def belt(b):
    b.tube([kit.upright(0.0, y, 0.011, rx, rz) for y, rx, rz in ((0.625, 0.150, 0.126), (0.632, 0.160, 0.136), (0.662, 0.161, 0.137), (0.669, 0.151, 0.127))], 20)
    b.ellipsoid(Vector((0.0, 0.647, 0.147)), Vector((0.024, 0.020, 0.006)), None, 8, 3)


def buttons(b):
    for y, z in ((0.72, 0.139), (0.79, 0.132), (0.86, 0.117), (0.92, 0.104)):
        b.ellipsoid(Vector((0.0, y, z)), Vector((0.011, 0.011, 0.006)), None, 8, 3)


def trousers(b):
    # The seat, up inside the coat, and a leg under each hip
    b.tube([kit.upright(0.0, y, 0.0, rx, rz) for y, rx, rz in ((0.47, 0.060, 0.060), (0.50, 0.124, 0.104), (0.56, 0.140, 0.114), (0.62, 0.134, 0.110))], 20)
    for side in (1.0, -1.0):
        leg = [(HIP_Y + 0.04, 0.070), (HIP_Y - 0.02, 0.081), (0.42, 0.077), (KNEE_Y, 0.065), (0.20, 0.061), (0.11, 0.051), (0.085, 0.049)]
        b.tube([kit.upright(side * HIP_X, y, 0.0, r, r * 1.06) for y, r in leg], 16)


def boots(b):
    for side in (1.0, -1.0):
        ankle = Vector((side * HIP_X, ANKLE_Y, 0.0))
        # The foot, heel to toe: (how far forward, centre height above the ankle, half width, half height)
        foot = [(-0.050, -0.018, 0.036, 0.032), (-0.020, -0.006, 0.044, 0.046), (0.020, -0.012, 0.047, 0.040),
                (0.060, -0.024, 0.050, 0.028), (0.105, -0.028, 0.049, 0.024), (0.140, -0.031, 0.040, 0.019)]
        rings = [(ankle + Vector((0.0, y, z)), X * rx, Y * ry) for z, y, rx, ry in foot]
        # (the last argument is a floor: nothing of it goes below the ground)
        b.tube(kit.dome(rings[0], -Z, 0.016, 3)[::-1] + rings + kit.dome(rings[-1], Z, 0.02, 3), 16, 0.0)
        # ...and the leg of the boot, up over the trouser end
        b.tube([kit.upright(ankle.x, y, z, r, r * 1.08) for y, r, z in ((0.03, 0.045, 0.004), (0.07, 0.050, 0.0), (0.125, 0.054, -0.003), (0.132, 0.046, -0.003))], 16)


def head(b):
    b.tube([kit.upright(0.0, y, 0.0, 0.044, 0.046) for y in (0.985, 1.02, 1.07)], 12)
    # An egg, narrowing to the chin
    rings = []
    for k in range(1, 12):
        phi = -math.pi / 2 + math.pi * k / 12
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        rings.append(kit.upright(0.0, HEAD_CENTRE.y + HEAD_RADII.y * s, HEAD_CENTRE.z + 0.010 * jaw,
                                 HEAD_RADII.x * c * (1.0 - 0.12 * jaw ** 1.5), HEAD_RADII.z * c))
    b.tube(rings, 20)
    b.ellipsoid(HEAD_CENTRE + Vector((0.0, -0.012, 0.094)), Vector((0.014, 0.020, 0.016)), None, 8, 5)  # nose
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.083, -0.010, -0.008)), Vector((0.011, 0.024, 0.016)), None, 8, 5)


def whiskers(b):
    # A moustache: two strands, so the hair shader has a direction to comb them in
    for side in (1.0, -1.0):
        root = HEAD_CENTRE + Vector((0.0, -0.040, 0.092))
        b.strand([root + Vector((side * x, y, z)) for x, y, z in ((0.0, 0.0, 0.0), (0.020, -0.004, -0.003), (0.040, -0.014, -0.014), (0.052, -0.026, -0.024))],
                 [0.012, 0.013, 0.011, 0.007])


def hat(b):
    # A peaked cap: band, flat crown standing out over it, and a stiff peak
    top = HEAD_CENTRE.y
    crown = [(0.030, 0.088, 0.098), (0.062, 0.090, 0.100), (0.070, 0.104, 0.114), (0.098, 0.108, 0.118), (0.114, 0.100, 0.110), (0.124, 0.050, 0.056)]
    b.tube([kit.upright(0.0, top + y, HEAD_CENTRE.z, rx, rz) for y, rx, rz in crown], 20)
    peak = [(HEAD_CENTRE + Vector((0.0, 0.040 - 0.25 * (z - 0.06), z)), X * half, Y * 0.006) for z, half in ((0.060, 0.086), (0.095, 0.084), (0.125, 0.072), (0.145, 0.050))]
    b.tube(peak + kit.dome(peak[-1], Z, 0.008, 2), 12)


def hands(b):
    # Mittens: palm down, fingers together, a thumb forward. (For real fingers,
    # and the bones that go with them, see build_boy.py.)
    for side in (1.0, -1.0):
        wrist = Vector((side * WRIST_X, SHOULDER.y, 0.0))
        # (distance past the wrist, half thickness, half width): it starts up inside the cuff
        palm = [(-0.05, 0.030, 0.032), (0.0, 0.022, 0.030), (0.035, 0.018, 0.040), (0.075, 0.016, 0.041), (0.105, 0.012, 0.032)]
        rings = [(wrist + X * side * d, Y * ry, Z * rz) for d, ry, rz in palm]
        b.tube(rings + kit.dome(rings[-1], X * side, 0.012, 2), 12)
        b.strand([wrist + Vector((side * x, y, z)) for x, y, z in ((0.020, -0.002, 0.022), (0.038, -0.006, 0.042), (0.058, -0.008, 0.054))], [0.013, 0.012, 0.010])


# --- Skin weights: which bones each point follows, from where it sits in the T-pose. ---

def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    if part in ("hat", "whiskers"):
        return {"head": 1.0}
    if part == "head":
        skull = blend(HEAD.y - 0.02, HEAD.y + 0.03, p.y)
        return {"neck": 1.0 - skull, "head": skull}
    if part == "hands":
        hand = blend(WRIST_X - 0.02, WRIST_X + 0.015, abs(p.x))
        return {"forearm" + suffix: 1.0 - hand, "hand" + suffix: hand}
    if part == "boots":
        # The top of the boot goes with the shin; the front of the foot with the toe.
        shin = blend(0.06, 0.105, p.y)
        toe = blend(TOE.z - 0.022, TOE.z + 0.022, p.z) * (1.0 - shin)
        return {"shin" + suffix: shin, "foot" + suffix: 1.0 - shin - toe, "toe" + suffix: toe}

    # The coat, the belt, the buttons and the trousers: every share is a smooth
    # step across a joint, so each joint bends over a few centimetres.
    reach = abs(p.x)
    arm = blend(SHOULDER.x - 0.035, SHOULDER.x + 0.035, reach) if p.y > CHEST.y else 0.0
    fore = blend(ELBOW_X - 0.035, ELBOW_X + 0.035, reach)
    leg = blend(HIP_Y + 0.035, HIP_Y - 0.05, p.y)
    left = blend(-0.012, 0.012, p.x)
    shin = blend(KNEE_Y + 0.04, KNEE_Y - 0.04, p.y)
    low = blend(SPINE.y + 0.05, SPINE.y - 0.05, p.y)
    high = blend(CHEST.y - 0.06, CHEST.y + 0.05, p.y)
    neck = blend(NECK.y - 0.03, NECK.y + 0.015, p.y) if reach < 0.09 else 0.0
    trunk = (1.0 - arm) * (1.0 - leg)
    result = {
        "hips": trunk * low,
        "spine": trunk * (1.0 - low) * (1.0 - high),
        "chest": trunk * (1.0 - low) * high * (1.0 - neck),
        "neck": trunk * (1.0 - low) * high * neck,
        "upper_arm" + suffix: arm * (1.0 - fore),
        "forearm" + suffix: arm * fore,
    }
    for name, share in (("_l", left), ("_r", 1.0 - left)):
        result["thigh" + name] = leg * share * (1.0 - shin)
        result["shin" + name] = leg * share * shin
    return result


# --- The skeleton: (bone, where its joint is, parent). ---

def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("chest", CHEST, "spine"), ("neck", NECK, "chest"), ("head", HEAD, "neck")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        shoulder = Vector((side * SHOULDER.x, SHOULDER.y, 0.0))
        listed.append(("upper_arm" + suffix, shoulder, "chest"))
        listed.append(("forearm" + suffix, shoulder + X * side * UPPER_ARM, "upper_arm" + suffix))
        listed.append(("hand" + suffix, shoulder + X * side * (UPPER_ARM + FOREARM), "forearm" + suffix))
        # Leg bones are siblings: the rig places each one directly with IK.
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        listed.append(("thigh" + suffix, hip, "hips"))
        listed.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        listed.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
    return listed


# (part, material, shapes, fuse). The part's name is what `weights` is asked about.
# `fuse` is None to keep the shapes as they are, or (voxel size, smoothing passes,
# triangle budget) to melt them into one surface, which loses their texture coordinates.
PARTS = [
    ("coat", COAT, coat, (0.006, 4, 5000)),
    ("belt", BELT, belt, None),
    ("buttons", BRASS, buttons, None),
    ("trousers", TROUSERS, trousers, (0.006, 4, 3500)),
    ("boots", BOOTS, boots, (0.004, 3, 2400)),
    ("head", SKIN, head, (0.004, 4, 2200)),
    ("whiskers", HAIR, whiskers, None),
    ("hat", HAT, hat, None),
    ("hands", SKIN, hands, (0.003, 2, 1600)),
]

kit.export(NAME, bones(), PARTS, weights, MATERIALS)
# The demade version: the same shapes lofted coarsely, left unfused and flat shaded.
kit.LOW = True
kit.export(NAME + "_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS)
