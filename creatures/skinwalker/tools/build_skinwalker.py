"""Builds the skinwalker and exports it for Godot.

Run from the game's root (it needs the ghoul's build, creatures/ghoul/tools/build_ghoul.py,
and the character controller's tools/build_character.py):
    blender --background --python creatures/skinwalker/tools/build_skinwalker.py [-- <folder for preview renders>]

Writes creatures/skinwalker/models/skinwalker.glb and skinwalker_lo.glb (and
editable .blend copies beside this file, which Godot does not import: this
folder has a .gdignore).

A creature of horror stories: something wearing a coyote's skin. Under it, a
figure far too tall and too thin, pale grey-white and bare: the ghoul's
starved frame (build_ghoul.py: the same bones and names as the boy, so
CharacterRig can move it) with legs half as long again as they should be
(`LEG_STRETCH`), long thin arms, and fingers far too long. Its face is a gaunt
human face, a heavy brow over small deep-set eyes that shine (`eyes`), a
too-wide lipless slit of a mouth.

Over it, the skin (material `pelt`, furred in the game by CoyoteLook):
- the coyote's head worn as a mask over the top of its head (`mask`), the
  muzzle jutting out over its brow, the coyote's eye holes empty and dark, its
  big ears gone limp, the cheek skin hanging down beside the face it hides;
- the hide hanging from the back of the mask down its neck and back like a
  hooded cloak (`cape`), over its shoulders, down past its buttocks, the lower
  edge ragged;
- the coyote's empty forelegs draped over its shoulders and hanging down its
  chest, its hind legs hanging at its hips, and its tail hanging behind
  (`skins`), each on a bone of its own (`pelt_*`) that the rig swings.

Its vertex colours (`cavity`, as the ghoul's) are, on the skin, how far each
point lies in a hollow; on the pelt, a coyote's markings as coyote_look.gd
reads them (red how open, green how dark, blue how pale, alpha how tawny).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
GAME = os.path.dirname(os.path.dirname(COMPONENT))
sys.path.insert(0, os.path.join(GAME, "creatures", "ghoul", "tools"))
sys.path.insert(0, os.path.join(GAME, "tools"))
import build_ghoul as ghoul  # noqa: E402  (the ghoul: its frame, its weights, its export)
import build_character as kit  # noqa: E402

kit.ROOT = COMPONENT
X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
V = lambda x, y, z: Vector((x, y, z))  # noqa: E731

# --- The frame under the skin: the ghoul's, longer ---

## How much longer its legs are than the ghoul's (between ankle and hip).
LEG_STRETCH = 1.36
ghoul.UPPER_ARM = 0.40
ghoul.FOREARM = 0.44
ghoul.PALM = 0.088
ghoul.THUMB_LENGTH = 0.085
ghoul.FINGERS = [(z, length * 1.55, radius * 0.95, fan) for z, length, radius, fan in ghoul.FINGERS]
# The face: small deep-set eyes, and a lipless slit of a mouth from cheek to cheek
ghoul.EYE = (0.026, -0.006, 0.0135, 0.0105, 0.018, 1.0)
ghoul.MOUTH = (0.0, -0.082, 0.036, 0.0055, 0.014, 1.0)
ghoul.HOLES = (ghoul.EYE, ghoul.MOUTH, ghoul.NOSE)
LIFT = (ghoul.HIP_Y - ghoul.ANKLE_Y) * (LEG_STRETCH - 1.0)
LEG_PARTS = ("legs", "feet", "trousers")


def settled(part, p):
    """Brings a point of the ghoul's frame to the skinwalker's: the legs drawn
    out between ankle and hip, everything above lifted with them."""
    if part in LEG_PARTS and p.y < ghoul.HIP_Y:
        y = ghoul.ANKLE_Y + (p.y - ghoul.ANKLE_Y) * LEG_STRETCH if p.y > ghoul.ANKLE_Y else p.y
    else:
        y = p.y + LIFT
    return Vector((p.x, y, p.z))


def unsettled(part, p):
    if part in LEG_PARTS and p.y < ghoul.HIP_Y + LIFT:
        y = ghoul.ANKLE_Y + (p.y - ghoul.ANKLE_Y) / LEG_STRETCH if p.y > ghoul.ANKLE_Y else p.y
    else:
        y = p.y - LIFT
    return Vector((p.x, y, p.z))


kit.settled = settled
kit.unsettled = unsettled

SKIN, HOLLOW, EYES, PELT = range(4)
MATERIALS = [
    # Pale dirty grey, a corpse's (darker where it sinks in: see SkinwalkerRig)
    ("skin", (0.43, 0.41, 0.385)),
    ("hollow", (0.03, 0.025, 0.025)),
    ("eyes", (0.85, 0.8, 0.55)),
    ("pelt", (0.37, 0.325, 0.27)),
]

# --- Its eyes ---


def eyes(b):
    """A small wet eye at the bottom of each pit (they shine in the game)."""
    hx, hy, rx, ry, depth, _share = ghoul.EYE
    for side in (1.0, -1.0):
        angle, phi = ghoul.face_place(side * hx, hy)
        bottom = ghoul.skull_point(angle, phi)
        out = (bottom - ghoul.HEAD_CENTRE).normalized()
        b.ellipsoid(bottom + out * 0.004 - Y * 0.001, Vector((rx * 0.85, ry * 0.9, 0.008)), None, 12, 6)


# --- The skin it wears ---

HEAD_TOP = ghoul.HEAD_CENTRE + V(0.0, 0.04, -0.004)
# The coyote's head, worn: its skull over the top of the head, the muzzle out over the brow
MASK_SKULL = HEAD_TOP + V(0.0, 0.012, -0.006)
MASK_SIZE = V(0.078, 0.06, 0.09)
# (along the muzzle from the front of the mask's skull: forward, height, half width, half height)
MUZZLE = [(0.0, 0.032, 0.052, 0.048), (0.035, 0.024, 0.041, 0.038), (0.075, 0.018, 0.033, 0.03), (0.115, 0.014, 0.027, 0.025),
          (0.155, 0.010, 0.022, 0.021), (0.188, 0.007, 0.018, 0.018), (0.207, 0.005, 0.013, 0.014)]
MUZZLE_ROOT = MASK_SKULL + V(0.0, 0.0, 0.07)
NOSE = MUZZLE_ROOT + V(0.0, 0.012, 0.22)
SOCKET = V(0.045, 0.036, 0.078)
# Its ears: root, middle, tip (the left one), gone limp and leaning out
EAR = [MASK_SKULL + V(0.045, 0.05, -0.02), MASK_SKULL + V(0.075, 0.115, -0.04), MASK_SKULL + V(0.115, 0.16, -0.075)]

# The cloak of hide, from the nape down the back: (height, how far round from the
# middle of the back either way, radians)
CAPE_TOP = ghoul.HEAD_CENTRE.y - 0.03
CAPE_BOTTOM = 0.6
# The empty legs of the skin and its tail: (root, end), the left ones
FORE_SKIN = (V(0.085, 1.165, 0.045), V(0.095, 0.915, 0.095))
HIND_SKIN = (V(0.11, 0.70, -0.085), V(0.12, 0.42, -0.08))
TAIL_SKIN = (V(0.0, 0.67, -0.105), V(0.0, 0.47, -0.13), V(0.0, 0.29, -0.11))


def body_round(y):
    """(half width, half depth, forward) of what the cloak hangs round at height y."""
    if y >= 1.2:
        rx, rz, fwd = ghoul.profile_at(ghoul.NECK_PROFILE, y)
        rx, rz = rx + 0.02, rz + 0.012
    elif y >= ghoul.TORSO[0][0]:
        rx, rz, fwd = ghoul.profile_at(ghoul.TORSO, y)
    else:
        rx, rz, fwd = 0.105, 0.075, 0.0
    # (over the shoulders, and the shoulder blades behind)
    shoulders = math.exp(-((y - 1.14) / 0.07) ** 2)
    rx = max(rx, 0.16 * shoulders + rx * (1.0 - shoulders))
    rz = rz + 0.012 * math.exp(-((y - 1.08) / 0.06) ** 2)
    # (the buttocks)
    rz = rz + 0.025 * math.exp(-((y - 0.68) / 0.06) ** 2)
    rx = max(rx, 0.11 * math.exp(-((y - 0.68) / 0.08) ** 2))
    return rx, rz, fwd


def cape_point(u, v):
    """A point of the cloak: `u` across (-1 its right edge, 1 its left), `v` down (0 the nape, 1 the hem)."""
    # (the hem is ragged: longer here, shorter there)
    bottom = CAPE_BOTTOM + 0.05 * math.sin(u * 5.3 + 1.0) + 0.03 * math.sin(u * 13.1) - 0.04 * (1.0 - abs(u))
    y = CAPE_TOP + (bottom - CAPE_TOP) * v
    rx, rz, fwd = body_round(y)
    # How far round the body it reaches, either way: narrow at the nape, over the shoulders, round the back
    reach = math.radians(62.0 + 28.0 * math.exp(-((y - 1.12) / 0.1) ** 2) + 20.0 * blend(1.0, 0.7, y))
    angle = u * reach
    gap = 0.026 + 0.06 * v * v
    x = math.sin(angle) * (rx + gap)
    z = fwd - math.cos(angle) * (rz + gap)
    # (at the nape it gathers into the back of the mask)
    gather = blend(CAPE_TOP + 0.0, CAPE_TOP - 0.1, y)
    x *= 0.55 + 0.45 * gather
    z = z * (0.5 + 0.5 * gather) + (MASK_SKULL.z - 0.05) * (0.5 - 0.5 * gather)
    return V(x, y, z)


def cape(b):
    across, down = (10, 8) if kit.LOW else (34, 30)
    grid = []
    for j in range(down + 1):
        row = []
        for i in range(across + 1):
            u = -1.0 + 2.0 * i / across
            row.append(b._vert(cape_point(u, j / down), None))
        grid.append(row)
    faces = []
    for j in range(down):
        for i in range(across):
            faces.append(b.bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1])))
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)
    # (outwards: away from the back)
    middle = grid[down // 2][across // 2]
    face = middle.link_faces[0]
    face.normal_update()
    if kit.from_blender(face.normal).z > 0.0:
        bmesh.ops.reverse_faces(b.bm, faces=faces)
    bmesh.ops.solidify(b.bm, geom=faces, thickness=0.008)


def ear_point(t, side):
    root, mid, end = EAR
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return V(at.x * side, at.y, at.z)


def mask(b):
    """The coyote's head, worn: a skull of hide over the top of the head, the
    muzzle out over the brow, the cheek skin hanging down beside the face, the
    ears gone limp."""
    b.ellipsoid(MASK_SKULL, MASK_SIZE, None, 18, 10)
    rings = [(MUZZLE_ROOT + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in MUZZLE]
    b.tube(rings + kit.dome(rings[-1], Z, 0.012, 3), 16)
    # The brow over the empty eye holes
    for side in (1.0, -1.0):
        b.ellipsoid(MASK_SKULL + V(side * 0.042, 0.052, 0.075), V(0.022, 0.012, 0.024), Matrix.Rotation(0.3, 3, "X"), 10, 5)
        # The cheek skin hanging down beside the face, and the jowls of the ruff
        b.ellipsoid(MASK_SKULL + V(side * 0.074, -0.05, 0.02), V(0.012, 0.07, 0.042), Matrix.Rotation(side * 0.08, 3, "Z") @ Matrix.Rotation(-0.2, 3, "X"), 12, 6)
        b.ellipsoid(MASK_SKULL + V(side * 0.07, -0.11, 0.0), V(0.011, 0.04, 0.03), Matrix.Rotation(side * 0.05, 3, "Z"), 10, 5)
        # The ears: broad at the root, coming to a point, flattened, leaning out and back
        wide = V(side * 0.92, 0.0, -0.38).normalized()
        face = V(side * 0.38, 0.12, 0.92).normalized()
        ear = []
        for t, half, thick in ((0.0, 0.034, 0.014), (0.12, 0.038, 0.009), (0.35, 0.032, 0.007), (0.6, 0.022, 0.006), (0.82, 0.011, 0.004), (1.0, 0.002, 0.002)):
            ear.append((ear_point(t, side), wide * half, face * thick))
        b.tube(kit.dome(ear[0], -Y, 0.008, 2)[::-1] + ear, 10)
    # The back of the head of it, running into the cloak
    b.ellipsoid(MASK_SKULL + V(0.0, -0.02, -0.07), V(0.07, 0.07, 0.05), None, 12, 6)


def mask_holes(b):
    """The empty eye holes of the coyote's head, and its nose."""
    for side in (1.0, -1.0):
        b.ellipsoid(MASK_SKULL + V(side * SOCKET.x, SOCKET.y, SOCKET.z), V(0.012, 0.007, 0.004), Matrix.Rotation(side * 0.55, 3, "Y") @ Matrix.Rotation(-side * 0.25, 3, "Z"), 10, 5)
    b.ellipsoid(NOSE, V(0.0115, 0.009, 0.009), None, 10, 6)


def mask_teeth(b):
    """The coyote's upper teeth, dry, along the underside of the muzzle over the brow."""
    for side in (1.0, -1.0):
        for z, tall, radius in ((0.185, 0.008, 0.0028), (0.165, 0.024, 0.0048), (0.14, 0.009, 0.0034), (0.115, 0.01, 0.0038), (0.09, 0.011, 0.0042), (0.065, 0.009, 0.0042)):
            ring = [m for m in MUZZLE if m[0] >= z - 0.04][0]
            _z, y, rx, ry = ring
            base = MUZZLE_ROOT + V(side * rx * 0.62, y - ry * 0.72, z)
            kit.spike(b, base, base - Y * tall + V(0.0, 0.0, 0.002), radius, 5)
        # (the dried lip along it)
        b.strand([MUZZLE_ROOT + V(side * m[2] * 0.82, m[1] - m[3] * 0.6, m[0]) for m in MUZZLE[1:-1]], [0.006, 0.0065, 0.006, 0.0055, 0.005], 6)


def skins(b):
    """Its empty legs and its tail."""
    for side in (1.0, -1.0):
        for (root, end), width in ((FORE_SKIN, 0.026), (HIND_SKIN, 0.03)):
            a = V(root.x * side, root.y, root.z)
            c = V(end.x * side, end.y, end.z)
            along = (c - a).normalized()
            out = V(side, 0.0, 0.0)
            flat = along.cross(out).normalized()
            rings = []
            for t, w in ((0.0, 1.0), (0.2, 1.05), (0.45, 0.8), (0.7, 0.62), (0.9, 0.6), (1.0, 0.5)):
                rings.append((a.lerp(c, t), out * width * w, flat * width * 0.38 * w))
            b.tube(rings, 10)
            # (the paw at its end, hanging)
            b.ellipsoid(c + along * 0.015 + flat * 0.006, V(0.019, 0.024, 0.016), None, 8, 5)
    # The tail: thin at its root, bushy, to a point
    points = [TAIL_SKIN[0], TAIL_SKIN[0].lerp(TAIL_SKIN[1], 0.5), TAIL_SKIN[1], TAIL_SKIN[1].lerp(TAIL_SKIN[2], 0.5), TAIL_SKIN[2]]
    b.strand(points, [0.016, 0.03, 0.04, 0.036, 0.016], 12)


# --- Colouring the hide, and its fur's lie ---

def pelt_colours(part, p, normal):
    """(open, dark, pale, tawny) at a point of the hide, by where it is (p: modelled, unsettled)."""
    q = p - MASK_SKULL
    if part == "mask":
        lower = blend(-0.01, -0.06, q.y)
        tawny = blend(0.05, 0.15, q.z) * blend(-0.02, 0.03, q.y) * 0.9 + 0.6 * blend(0.03, 0.09, q.y) * blend(0.0, -0.05, q.z)
        dark = 0.6 * blend(0.17, 0.21, q.y) + 0.25 * blend(0.1, 0.2, q.z) * blend(0.02, 0.05, q.y)
        return 1.0, min(dark, 1.0), 0.75 * lower, min(tawny, 1.0)
    if part == "skins":
        _off, along = ghoul_chain(p, list(TAIL_SKIN))
        if p.y < 0.68 and abs(p.x) < 0.06:
            tip = blend(0.36, 0.3, p.y)
            return 1.0, max(tip, 0.3 * blend(-0.2, 0.6, normal.z * -1.0)), 0.3 * (1.0 - tip), 0.15
        return 0.9, 0.15, 0.25, 0.85
    # The cloak: grizzled down its middle (the coyote's back), tawny to its edges
    # (its flanks), the inside of it paler (the belly hide)
    inside = normal.z > 0.2 and abs(normal.x) < 0.8
    if inside:
        return 0.8, 0.0, 0.85, 0.15
    edge = min(abs(p.x) / 0.16, 1.0)
    saddle = blend(0.5, 0.0, edge) * blend(CAPE_TOP - 0.05, CAPE_TOP - 0.2, p.y)
    return 1.0, 0.55 * saddle, 0.35 * blend(0.75, 1.0, edge), 0.45 * blend(0.3, 0.9, edge)


def ghoul_chain(p, joints):
    best = (1e9, 0.0)
    for i in range(len(joints) - 1):
        a, c = joints[i], joints[i + 1]
        ac = c - a
        t = min(max((p - a).dot(ac) / ac.length_squared, 0.0), 1.0)
        d = (p - (a + ac * t)).length
        if d < best[0]:
            best = (d, i + t)
    return best


def lie_of(part, p):
    """The fur's lie, in metres (along it, across it), at a point of the hide."""
    if part == "mask":
        q = p - MASK_SKULL
        return -q.z, math.atan2(q.x, q.y) * 0.08
    if part == "skins":
        return -p.y, math.atan2(p.x - (0.1 if p.x > 0.05 else -0.1 if p.x < -0.05 else 0.0), p.z) * 0.03
    return -p.y + 1.5, math.atan2(p.x, -p.z) * 0.12


def hide(name, shapes, fuse=None):
    """A part of the hide: built, (fused if `fuse` says), coloured and laid for the fur."""
    def made(b):
        shapes(b)
        mesh = kit.fused(b, None if kit.LOW else fuse)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.normal_update()
        uv = bm.loops.layers.uv.verify()
        for face in bm.faces:
            for loop in face.loops:
                p = unsettled(name, kit.from_blender(loop.vert.co))
                loop[uv].uv = lie_of(name, p)
        bm.to_mesh(mesh)
        bm.free()
        colour = mesh.color_attributes.new(ghoul.CAVITY, "FLOAT_COLOR", "POINT")
        for vertex, item in zip(mesh.vertices, colour.data):
            p = unsettled(name, kit.from_blender(vertex.co))
            item.color = pelt_colours(name, p, kit.from_blender(vertex.normal))
        return mesh
    return made


def flat(shapes, value):
    return ghoul.shaded(shapes, flat=value)


# --- Bones and weights ---

def bones():
    listed = ghoul.bones()
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        for name, (root, end), parent in (("pelt_fore", FORE_SKIN, "chest"), ("pelt_hind", HIND_SKIN, "hips")):
            listed.append((name + suffix, V(root.x * side, root.y, root.z), parent))
            listed.append((name + "_end" + suffix, V(end.x * side, end.y, end.z), name + suffix))
    listed.append(("pelt_tail", TAIL_SKIN[0], "hips"))
    listed.append(("pelt_tail_1", TAIL_SKIN[1], "pelt_tail"))
    listed.append(("pelt_tail_end", TAIL_SKIN[2], "pelt_tail_1"))
    return listed


def cape_weights(p):
    made = ghoul.trunk_weights(p)
    # (at the nape it is the mask's: it goes with the head)
    top = blend(CAPE_TOP - 0.08, CAPE_TOP - 0.01, p.y)
    if top > 0.0:
        made = {bone: weight * (1.0 - top) for bone, weight in made.items()}
        made["head"] = made.get("head", 0.0) + top
    # (below the hips it is carried by them)
    return made


def weights(part, p):
    if part in ("mask", "mask_holes", "mask_teeth", "eyes"):
        return {"head": 1.0}
    if part == "cape":
        return cape_weights(p)
    if part == "skins":
        side = 1.0 if p.x >= 0.0 else -1.0
        suffix = "_l" if side > 0.0 else "_r"
        best = None
        for name, joints, parent in (("pelt_fore", FORE_SKIN, "chest"), ("pelt_hind", HIND_SKIN, "hips")):
            line = [V(j.x * side, j.y, j.z) for j in joints]
            off, along = ghoul_chain(p, line)
            if best is None or off < best[0]:
                best = (off, name + suffix, parent, along)
        off, along = ghoul_chain(p, list(TAIL_SKIN))
        if off < best[0]:
            hung = blend(0.0, 0.25, along)
            second = blend(0.8, 1.2, along)
            return {"hips": 1.0 - hung, "pelt_tail": hung * (1.0 - second), "pelt_tail_1": hung * second}
        _off, bone, parent, along = best
        hung = blend(0.0, 0.2, along)
        return {parent: 1.0 - hung, bone: hung}
    return ghoul.weights(part, p)


def lifted_trunk(b):
    """The ghoul's trunk (with the arms), lifted with the rest above the hips
    (it is built on a builder of its own, which the settling never sees)."""
    mesh = ghoul.trunk(b)
    for vertex in mesh.vertices:
        vertex.co.z += LIFT
    return mesh


def unlifted(extra):
    return lambda p: extra(p - Y * LIFT)


PARTS = [
    ("torso", SKIN, ghoul.shaded(lifted_trunk, ghoul.TRUNK_FUSE, -0.014, unlifted(ghoul.trunk_hollows)), None),
    ("legs", SKIN, ghoul.shaded(ghoul.legs, (0.0032, 3, 4200), -0.006), None),
    ("feet", SKIN, ghoul.shaded(ghoul.feet, (0.003, 3, 1600), 0.0), None),
    ("hands", SKIN, ghoul.shaded(ghoul.hands, flat=0.0), None),
    ("fingers", SKIN, ghoul.shaded(ghoul.fingers, flat=0.3), None),
    ("head", SKIN, ghoul.shaded(ghoul.head, None, -0.004, unlifted(ghoul.head_hollows)), None),
    ("hollows", HOLLOW, ghoul.shaded(ghoul.hollows, flat=1.0), None),

    ("eyes", EYES, flat(eyes, 1.0), None),
    ("mask", PELT, hide("mask", mask, (0.0028, 2, 7000)), None),
    ("cape", PELT, hide("cape", cape), None),
    ("skins", PELT, hide("skins", skins), None),
    ("mask_holes", HOLLOW, flat(mask_holes, 1.0), None),
    ("mask_teeth", SKIN, flat(mask_teeth, 0.0), None),
]


def previews(folder, name):
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
    face = kit.to_blender(settled("head", ghoul.HEAD_CENTRE + V(0.0, 0.0, 0.03)))
    middle = (0.0, 0.0, 0.92)
    views = [("front", (0, -1, 0.05), middle, 2.0), ("side", (1, 0, 0.05), middle, 2.0), ("back", (0.3, 1, 0.15), middle, 2.0),
             ("quarter", (0.7, -0.7, 0.2), middle, 2.0), ("face", (0.1, -1, -0.05), face, 0.42), ("face_quarter", (0.7, -0.7, 0.0), face, 0.42),
             ("face_low", (0.25, -1, -0.45), face, 0.42), ("head_side", (1, 0, 0.0), face, 0.5)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    os.makedirs(os.path.join(COMPONENT, "models"), exist_ok=True)
    preview = kit.PREVIEW_DIR
    kit.PREVIEW_DIR = None
    for low in (False, True):
        kit.LOW = low
        name = "skinwalker_lo" if low else "skinwalker"
        kit.export(name, bones(), PARTS, weights, MATERIALS, settle=True)
        if preview and not low:
            previews(preview, name)
