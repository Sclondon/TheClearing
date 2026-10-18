"""Builds the skinwalker and exports it for Godot.

Run from the game's root (it needs the ghoul's build, creatures/ghoul/tools/build_ghoul.py,
and the character controller's tools/build_character.py):
    blender --background --python creatures/skinwalker/tools/build_skinwalker.py [-- <folder for preview renders>]

Writes creatures/skinwalker/models/skinwalker.glb and skinwalker_lo.glb (and
editable .blend copies beside this file, which Godot does not import: this
folder has a .gdignore).

A creature of horror stories: something wearing a coyote's skin. Under it, a
figure far too tall and too thin, ash grey-brown, mottled and filthy, bare: the ghoul's
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
from mathutils import noise as mnoise

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
    ("skin", (0.37, 0.345, 0.31)),
    ("hollow", (0.03, 0.025, 0.025)),
    ("eyes", (0.85, 0.8, 0.55)),
    ("pelt", (0.25, 0.22, 0.19)),
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
# The coyote's head, worn: dried and shrunken over the top of the head, the
# snout pulled down over the brow, so that the face under it is in its shadow
MASK_SKULL = HEAD_TOP + V(0.0, 0.012, -0.004)
MASK_SIZE = V(0.074, 0.056, 0.085)
# (along the muzzle from its root: forward, height, half width, half height): shrunken to the bone
MUZZLE = [(0.0, 0.03, 0.048, 0.044), (0.035, 0.022, 0.037, 0.034), (0.075, 0.016, 0.029, 0.026), (0.115, 0.012, 0.024, 0.021),
          (0.155, 0.008, 0.019, 0.017), (0.186, 0.005, 0.015, 0.014), (0.204, 0.003, 0.011, 0.011)]
MUZZLE_ROOT = MASK_SKULL + V(0.0, -0.012, 0.062)
# (the snout is pulled down over the brow)
MUZZLE_TILT = Matrix.Rotation(0.4, 3, "X")
NOSE = MUZZLE_ROOT + MUZZLE_TILT @ V(0.0, 0.006, 0.212)
SOCKET = V(0.044, 0.032, 0.074)
# Its ears: root, middle, tip (the left one), gone limp and leaning out
EAR = [MASK_SKULL + V(0.045, 0.045, -0.02), MASK_SKULL + V(0.08, 0.1, -0.045), MASK_SKULL + V(0.125, 0.13, -0.085)]

# The hide, worn as a hooded cloak: over the crown and round the back and sides
# of the head (the hood, open at the face), over the shoulders, and down the back
# past the buttocks, its edges ragged.
CAPE_TOP = HEAD_TOP.y + 0.03
HOOD_BOTTOM = 1.2
CAPE_BOTTOM = 0.55
# The empty legs of the skin and its tail: (root, over, end), the left ones. The
# forelegs are draped over the shoulders and hang down the chest; the hind legs
# and the tail trail from the hem behind.
FORE_SKIN = (V(0.1, 1.19, -0.03), V(0.112, 1.15, 0.07), V(0.1, 0.88, 0.105))
HIND_SKIN = (V(0.11, 0.6, -0.115), V(0.118, 0.45, -0.125), V(0.12, 0.27, -0.12))
TAIL_SKIN = (V(0.0, 0.6, -0.125), V(0.0, 0.37, -0.165), V(0.0, 0.13, -0.14))


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
    shoulders = math.exp(-((y - 1.14) / 0.08) ** 2)
    rx = max(rx, 0.17 * shoulders + rx * (1.0 - shoulders))
    rz = rz + 0.014 * math.exp(-((y - 1.08) / 0.06) ** 2)
    # (the buttocks)
    rz = rz + 0.025 * math.exp(-((y - 0.68) / 0.06) ** 2)
    rx = max(rx, 0.11 * math.exp(-((y - 0.68) / 0.08) ** 2))
    return rx, rz, fwd


def hood_point(angle, y):
    """A point of the hood round the head, angle round from the back of the head."""
    c = ghoul.HEAD_CENTRE
    # (closing over the crown, flaring out below the jaw towards the shoulders)
    above = (y - c.y) / (CAPE_TOP - c.y + 0.015)
    shrink = math.sqrt(max(0.08, 1.0 - above * above)) if above > 0.0 else 1.0 + 0.6 * blend(c.y - 0.04, HOOD_BOTTOM, y)
    return V(math.sin(angle) * 0.1 * shrink, y, c.z - 0.012 - math.cos(angle) * 0.108 * shrink)


def cape_point(u, v):
    """A point of the cloak: u across (-1 its right edge, 1 its left), v down (0 the crown, 1 the hem)."""
    # (the hem is ragged: longer here, shorter there; and so are its edges)
    bottom = CAPE_BOTTOM + 0.06 * math.sin(u * 5.3 + 1.0) + 0.035 * math.sin(u * 13.1) + 0.02 * math.sin(u * 29.0) - 0.05 * (1.0 - abs(u))
    y = CAPE_TOP + (bottom - CAPE_TOP) * v
    ragged = 1.0 + 0.07 * math.sin(v * 31.0) + 0.05 * math.sin(v * 67.0 + 2.0) * abs(u)
    rx, rz, fwd = body_round(y)
    # How far round the body it reaches, either way: right round the shoulders, round the back
    reach = math.radians((72.0 + 55.0 * math.exp(-((y - 1.13) / 0.1) ** 2) + 15.0 * blend(1.0, 0.7, y)) * ragged)
    angle = u * reach
    gap = 0.03 + 0.07 * v * v
    body = V(math.sin(angle) * (rx + gap), y, fwd - math.cos(angle) * (rz + gap))
    hood = hood_point(u * math.radians(136.0 * ragged), y)
    k = blend(HOOD_BOTTOM - 0.07, HOOD_BOTTOM + 0.05, y)
    return body.lerp(hood, k)


def cape(b):
    across, down = (12, 12) if kit.LOW else (40, 44)
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
    rings = [(MUZZLE_ROOT + MUZZLE_TILT @ V(0.0, y, z), X * rx, MUZZLE_TILT @ (Y * ry)) for z, y, rx, ry in MUZZLE]
    b.tube(rings + kit.dome(rings[-1], MUZZLE_TILT @ Z, 0.01, 3), 16)
    # The brow over the empty eye holes
    for side in (1.0, -1.0):
        b.ellipsoid(MASK_SKULL + V(side * 0.038, 0.036, 0.068), V(0.018, 0.007, 0.02), Matrix.Rotation(0.3, 3, "X"), 10, 5)
        # The cheek skin hanging down beside the face, and the jowls of the ruff
        b.ellipsoid(MASK_SKULL + V(side * 0.074, -0.05, 0.02), V(0.012, 0.07, 0.042), Matrix.Rotation(side * 0.08, 3, "Z") @ Matrix.Rotation(-0.2, 3, "X"), 12, 6)
        b.ellipsoid(MASK_SKULL + V(side * 0.07, -0.11, 0.0), V(0.011, 0.04, 0.03), Matrix.Rotation(side * 0.05, 3, "Z"), 10, 5)
        # The ears: broad at the root, coming to a point, flattened, leaning out and back
        wide = V(side * 0.92, 0.0, -0.38).normalized()
        face = V(side * 0.38, 0.12, 0.92).normalized()
        ear = []
        for t, half, thick in ((0.0, 0.03, 0.012), (0.12, 0.033, 0.008), (0.35, 0.027, 0.006), (0.6, 0.019, 0.005), (0.82, 0.01, 0.004), (1.0, 0.003, 0.002)):
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
            base = MUZZLE_ROOT + MUZZLE_TILT @ V(side * rx * 0.62, y - ry * 0.72, z)
            kit.spike(b, base, base + MUZZLE_TILT @ V(0.0, -tall, 0.002), radius, 5)
        # (the dried lip along it, drawn back off the teeth)
        b.strand([MUZZLE_ROOT + MUZZLE_TILT @ V(side * m[2] * 0.82, m[1] - m[3] * 0.55, m[0]) for m in MUZZLE[1:-1]], [0.006, 0.0065, 0.006, 0.0055, 0.005], 6)


def skins(b):
    """Its empty legs (flat, wide tubes of hide, a paw at the end of each) and its tail."""
    for side in (1.0, -1.0):
        for line, width in ((FORE_SKIN, 0.046), (HIND_SKIN, 0.05)):
            a, m, c = (V(j.x * side, j.y, j.z) for j in line)
            rings = []
            for t, w in ((0.0, 1.0), (0.15, 1.1), (0.32, 0.95), (0.5, 0.78), (0.68, 0.66), (0.84, 0.6), (1.0, 0.52)):
                at = a.lerp(m, t * 2.0) if t < 0.5 else m.lerp(c, t * 2.0 - 1.0)
                ahead = (m - a).normalized() if t < 0.5 else (c - m).normalized()
                out = V(side, 0.0, 0.0)
                flat_way = ahead.cross(out).normalized()
                # (wrinkled: it is only skin)
                w *= 1.0 + 0.12 * math.sin(t * 23.0 + side)
                rings.append((at, out * width * w, flat_way * width * 0.3 * w))
            b.tube(rings, 12)
            b.ellipsoid(c + (c - m).normalized() * 0.014, V(0.017, 0.02, 0.01), None, 8, 5)
            for toe in (-1.0, 0.0, 1.0):
                b.ellipsoid(c + (c - m).normalized() * 0.036 + V(toe * 0.01, 0.0, 0.006), V(0.006, 0.012, 0.005), None, 6, 3)
    # The tail: thin at its root, a bushy brush, to a point
    points = [TAIL_SKIN[0], TAIL_SKIN[0].lerp(TAIL_SKIN[1], 0.5), TAIL_SKIN[1], TAIL_SKIN[1].lerp(TAIL_SKIN[2], 0.5), TAIL_SKIN[2]]
    b.strand(points, [0.018, 0.036, 0.048, 0.042, 0.016], 12)


# --- Colouring the hide, and its fur's lie ---

def pelt_colours(part, p, normal):
    """(open, dark, pale, tawny) at a point of the hide, by where it is (p: modelled, unsettled).
    Long dead: matted, dirty, the colour gone out of it, darker where it is worn."""
    q = p - MASK_SKULL
    grime = 0.5 + 0.5 * mnoise.noise(p * 11.0)
    if part == "mask":
        # Dried and dark: a little of the tawny left along the muzzle, the lips and ears darker still
        lower = blend(-0.02, -0.07, q.y)
        tawny = 0.6 * blend(0.04, 0.14, q.z) * blend(-0.04, 0.02, q.y) + 0.25
        dark = 0.2 + 0.35 * blend(0.1, 0.15, q.y) + 0.2 * grime
        return 0.9, min(dark, 1.0), 0.15 * lower, tawny
    if part == "skins":
        if p.y < 0.62 and abs(p.x) < 0.06:
            tip = blend(0.24, 0.16, p.y)
            return 1.0, max(tip, 0.4 + 0.2 * grime), 0.12, 0.15
        return 0.9, 0.2 + 0.3 * grime, 0.12, 0.45
    # The cloak: dark and matted down its middle (the coyote's back), dull at its
    # edges (its flanks); the inside of it, the dried hide, dark and leathery
    inside = normal.z > 0.2 and abs(normal.x) < 0.8 and p.y < HOOD_BOTTOM
    if inside:
        return 0.6, 0.3 + 0.3 * grime, 0.3, 0.15
    edge = min(abs(p.x) / 0.16, 1.0)
    return 1.0, 0.12 + 0.35 * blend(0.6, 0.0, edge) + 0.25 * grime, 0.12 * blend(0.7, 1.0, edge), 0.35 + 0.3 * blend(0.3, 0.9, edge)


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
        for name, line, parent in (("pelt_fore", FORE_SKIN, "chest"), ("pelt_hind", HIND_SKIN, "hips")):
            # (the foreleg hangs from where it comes over the shoulder)
            root, end = (line[1], line[2]) if name == "pelt_fore" else (line[0], line[2])
            listed.append((name + suffix, V(root.x * side, root.y, root.z), parent))
            listed.append((name + "_end" + suffix, V(end.x * side, end.y, end.z), name + suffix))
    listed.append(("pelt_tail", TAIL_SKIN[0], "hips"))
    listed.append(("pelt_tail_1", TAIL_SKIN[1], "pelt_tail"))
    listed.append(("pelt_tail_end", TAIL_SKIN[2], "pelt_tail_1"))
    return listed


def cape_weights(p):
    made = ghoul.trunk_weights(p)
    # (at the nape it is the mask's: it goes with the head)
    top = blend(HOOD_BOTTOM + 0.0, HOOD_BOTTOM + 0.09, p.y)
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
            line = [line[0], line[-1]] if name == "pelt_hind" else line
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


def dirt_of(part, p):
    """How filthy its skin is at a point (0..1): the hands and feet worst, up the
    shins and forearms, streaks and blotches elsewhere (p: modelled, unsettled)."""
    blotch = 0.5 + 0.5 * mnoise.noise(p * 13.0)
    if part in ("legs", "feet"):
        return min(1.0, blend(0.62, 0.12, p.y) * 0.9 + 0.3 * blotch * blotch)
    if part in ("hands", "fingers"):
        return 0.75 + 0.2 * blotch
    if part == "torso":
        arm = blend(0.12, 0.16, abs(p.x)) * blend(1.08, 0.95, p.y)
        return min(1.0, arm * blend(1.0, 0.5, p.y) * 0.9 + 0.5 * blotch * blotch * blotch)
    return 0.05 + 0.35 * blotch * blotch * blotch


def dirty(made_fn, part):
    """A part of its skin with its filth (green) and mottling (blue) put into its
    colour, beside how far each point is in a hollow (red)."""
    def made(b):
        mesh = made_fn(b)
        cavity = mesh.color_attributes.get(ghoul.CAVITY)
        if cavity is None:
            return mesh
        for vertex, item in zip(mesh.vertices, cavity.data):
            q = unsettled(part, kit.from_blender(vertex.co))
            mottle = 0.5 + 0.5 * mnoise.noise(q * 31.0 + Vector((3.1, 7.7, 1.3)))
            item.color = (item.color[0], dirt_of(part, q), mottle, 1.0)
        return mesh
    return made


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
    ("torso", SKIN, dirty(ghoul.shaded(lifted_trunk, ghoul.TRUNK_FUSE, -0.014, unlifted(ghoul.trunk_hollows)), "torso"), None),
    ("legs", SKIN, dirty(ghoul.shaded(ghoul.legs, (0.0032, 3, 4200), -0.006), "legs"), None),
    ("feet", SKIN, dirty(ghoul.shaded(ghoul.feet, (0.003, 3, 1600), 0.0), "feet"), None),
    ("hands", SKIN, dirty(ghoul.shaded(ghoul.hands, flat=0.0), "hands"), None),
    ("fingers", SKIN, dirty(ghoul.shaded(ghoul.fingers, flat=0.3), "fingers"), None),
    ("head", SKIN, dirty(ghoul.shaded(ghoul.head, None, -0.004, unlifted(ghoul.head_hollows)), "head"), None),
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
