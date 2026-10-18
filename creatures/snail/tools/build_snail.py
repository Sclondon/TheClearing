"""Builds the giant snail (creatures/snail) and exports it for Godot.

Run from the game's root:
    blender --background --python creatures/snail/tools/build_snail.py
    blender --background --python creatures/snail/tools/build_snail.py -- <preview folder>   # with pictures and a .blend

Writes creatures/snail/models/snail.glb and a demade snail_lo.glb. Nothing else
is written (an editable .blend goes to the preview folder, when there is one;
this folder has a .gdignore so that Godot does not try to import anything here).
It needs nothing but Blender (no other component's tools).

A land snail, after the garden snail and the Roman snail, made as big as a
car: the foot some 8 m long, the shell nearly 4 m across.

- THE SHELL (material `shell`): a tube coiled round its axis, growing as it
  goes (each whorl about twice as wide as the one inside it, as a real shell
  grows: Raup's coiling), right-handed (dextral: clockwise seen from the apex),
  four and a half whorls from a small blunt apex to a wide mouth (the aperture)
  with a thickened, flared lip (the peristome). Low ridges across the whorls
  are its growth lines. It is carried tilted back and over to the snail's
  left, the mouth forward and low, over the middle of the foot. Its texture
  coordinates are (turns from the mouth, round the tube) for the shader's
  bands and growth lines.
- THE BODY (material `skin`): one long foot, flat-soled with a fringe (the
  skirt) a little proud all round, tapering to a pointed tail with a keel on
  top, rising under the shell into the mouth, where the mantle's thick collar
  fills it (with the breathing pore, the pneumostome, on the right). In front
  of the shell the neck runs down into a rounded head with two long eye stalks
  (the upper tentacles, an eye at each tip) and two short feelers (the lower
  tentacles) over the mouth. Its texture coordinates are metres (along it,
  round it) for the shader's grooved, wet skin.

Vertex colours. On the skin: red, how open the surface is (dark in creases,
round the mouth); green, how far down the foot's fringe it is (where the
muscle waves show); blue, the paler skin (the mantle collar, the sole, the
underside of the head); alpha 1 an eye, 0.5 the dark of the breathing pore and
the mouth. On the shell: red, how open (dark down the sutures between whorls);
blue, the lip; alpha 1 the inside of the mouth.

THE BONES (every one points straight up with no roll, so that its rest is the
identity in Godot, and none has a parent: SnailRig places each in the model's
space itself):

    foot_0 .. foot_9   down the middle of the sole, tail to neck
    head               in the head, low, where it rears from
    eye_l_0 .. eye_l_3 up the left eye stalk, root to eye (and eye_r_ ..)
    feel_l_0, feel_l_1 the left feeler, root and tip (and feel_r_ ..)
    shell              in the shell (it is carried by it, and so is the collar)
    pore               the breathing pore (it opens and closes)

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
OUT = os.path.join(COMPONENT, "models")
PREVIEW = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None
LOW = False
TAU = math.tau


def V(x, y, z):
    return Vector((x, y, z))


def to_blender(p):
    return Vector((p.x, -p.z, p.y))


def from_blender(p):
    return Vector((p.x, p.z, -p.y))


def smooth(edge0, edge1, x):
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def keyed(keys, x):
    """Piecewise smooth through (x, value) keys."""
    if x <= keys[0][0]:
        return keys[0][1]
    for (x0, v0), (x1, v1) in zip(keys, keys[1:]):
        if x <= x1:
            t = (x - x0) / (x1 - x0)
            t = t * t * (3.0 - 2.0 * t)
            return v0 + (v1 - v0) * t
    return keys[-1][1]


def hash3(x, y, z):
    h = math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453
    return h - math.floor(h)


def noise1(x, seed=0.0):
    i = math.floor(x)
    f = x - i
    f = f * f * (3.0 - 2.0 * f)
    return lerp(hash3(i, seed, 1.3), hash3(i + 1, seed, 1.3), f)


# --- The shell ---

# Raup's coiling: the tube's middle is R0 * W^(turns) from the axis (W, how
# much wider each whorl is than the one inside it), and goes down the axis
# T times as far as it is out from it; the tube is K times as thick as it is
# far out (a little taller than it is wide: ASPECT).
R0 = 1.42
W = 2.1
B = math.log(W) / TAU
T = 1.45
K = 0.74
ASPECT = 1.1
TURNS = 4.6
SLANT = 0.3
SLANT_TURN = 0.0
# How it is carried: tipped back and over to its left, the mouth's middle here.
SHELL_TILT = (-25.0, -10.0)
MOUTH_AT = V(0.15, 1.4, 0.95)


def shell_basis():
    back = Matrix.Rotation(math.radians(SHELL_TILT[0]), 3, "X")
    over = Matrix.Rotation(math.radians(SHELL_TILT[1]), 3, "Z")
    return back @ over


def coil_centre(theta):
    r = R0 * math.exp(B * theta)
    return V(r * math.cos(theta), -T * r, r * math.sin(theta)), r


def growth(theta):
    """The tube's thickness wavers a little: now and then a check (a rest in its growing). (The fine growth lines are the shader's.)"""
    turns = theta / TAU
    checks = 0.022 * max(0.0, noise1(turns * 4.0, 2.0) - 0.55) / 0.45
    return 1.0 - checks


def shell_point(theta, phi, scale=1.0):
    # The mouth is cut on a slant (its upper side further on than its lower), as a real one is.
    theta += SLANT * smooth(-0.6 * TAU, 0.0, theta) * math.sin(phi + SLANT_TURN)
    centre, r = coil_centre(theta)
    radial = V(math.cos(theta), 0.0, math.sin(theta))
    rho = K * r * growth(theta) * scale
    # (the mouth flares out to its lip)
    rho *= 1.0 + 0.05 * smooth(-0.4, 0.0, theta)
    # On its inner side it reaches in to the axis (no open navel: the whorls close round it).
    # (but round at the mouth: the navel closes further in)
    inner = rho if math.cos(phi) >= 0.0 else lerp(rho, max(rho, 0.97 * r * scale), smooth(-0.15 * TAU, -0.7 * TAU, theta))
    return centre + radial * (inner * math.cos(phi)) + V(0, 1, 0) * (rho * ASPECT * math.sin(phi))


def shell_mesh(bm, uv, colours, place):
    """The coiled tube, its lip and a little of its inside (dark), into `bm`.
    `place` takes a point from the shell's own space to the snail's."""
    segments = 12 if LOW else 28
    per_turn = 14 if LOW else 52
    rings = int(TURNS * per_turn)
    lip_rings = 2 if LOW else 4
    inside_rings = 2 if LOW else 3
    loops = []

    def ring(theta, scale, lip, inner, open_):
        verts = []
        for i in range(segments + 1):
            phi = TAU * i / segments
            p = shell_point(theta, phi, scale)
            v = bm.verts.new(to_blender(place(p)))
            verts.append((v, (theta / TAU, i / segments), (open_(theta, phi), 0.0, lip, inner)))
        return verts

    def openness(theta, phi):
        # Dark down the suture, where it lies against the whorl inside it.
        p = shell_point(theta, phi)
        inner_centre, inner_r = coil_centre(theta - TAU)
        rel = p - inner_centre
        radial = V(math.cos(theta), 0.0, math.sin(theta))
        d = math.hypot(rel.dot(radial), rel.y / ASPECT) - K * inner_r
        return smooth(0.0, 0.05 * max(inner_r, 0.05) + 0.03, d) * 0.45 + 0.55

    for k in range(rings + 1):
        theta = -TURNS * TAU * (1.0 - k / rings)
        loops.append(ring(theta, 1.0, 0.0, 0.0, openness))
    # The lip: rolled out, then back in over its edge, into the mouth.
    for k in range(1, lip_rings + 1):
        t = k / lip_rings
        roll = math.sin(t * math.pi)
        loops.append(ring(0.01 * roll, 1.0 + 0.03 * roll - 0.06 * t, 1.0, 0.0, lambda th, ph: 1.0))
    for k in range(1, inside_rings + 1):
        t = k / inside_rings
        loops.append(ring(-t * 0.06 * TAU, 0.93 - 0.03 * t, 0.0, 1.0, lambda th, ph: 0.5))
    faces = []
    for a, b in zip(loops, loops[1:]):
        for i in range(segments):
            quad = (a[i], a[i + 1], b[i + 1], b[i])
            face = bm.faces.new([q[0] for q in quad])
            for loop, q in zip(face.loops, quad):
                loop[uv].uv = q[1]
            faces.append(face)
    # (the apex, and the far end of the inside, are closed)
    for end, flip in ((loops[0], True), (loops[-1], False)):
        middle = Vector((0, 0, 0))
        for q in end[:-1]:
            middle += q[0].co
        middle /= segments
        pole = bm.verts.new(middle)
        for i in range(segments):
            vs = [end[i][0], end[i + 1][0], pole]
            if flip:
                vs.reverse()
            face = bm.faces.new(vs)
            for loop in face.loops:
                loop[uv].uv = end[0][1]
            faces.append(face)
        colours[pole] = end[0][2]
    for loop in loops:
        for v, _, colour in loop:
            colours[v] = colour
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def lip_ring(count):
    """Points round the lip of the mouth, in the shell's own space."""
    return [shell_point(0.0, TAU * k / count) for k in range(count)]


def shell_place():
    basis = shell_basis()
    ring = lip_ring(64)
    middle = sum(ring, Vector((0, 0, 0))) / len(ring)
    # (the mouth's middle where MOUTH_AT says)
    shift = MOUTH_AT - basis @ middle
    return lambda p: basis @ p + shift


# --- The body ---

ZT, ZH = -4.35, 3.6
HEAD_ROUND = 2.7


def width_at(z):
    return keyed([(-4.35, 0.05), (-3.9, 0.36), (-3.2, 0.72), (-2.2, 1.05), (-1.0, 1.2), (0.6, 1.22), (1.8, 1.08),
                  (2.6, 0.95), (3.6, 0.9)], z)


def height_at(z):
    return keyed([(-4.35, 0.05), (-3.9, 0.22), (-3.2, 0.45), (-2.3, 0.72), (-1.4, 1.0), (-0.3, 1.6), (0.3, 2.15), (0.75, 2.45),
                  (1.2, 2.05), (1.7, 1.45), (2.3, 1.15), (2.85, 1.12), (3.6, 1.0)], z)


def section(z, a):
    """A point round the foot at `z` (`a` the angle round it, 0 at its left side, rising over the top),
    and how far down the fringe it is."""
    w, h = width_at(z), height_at(z)
    c, s = math.cos(a), math.sin(a)
    cy = min(h * 0.3, 0.36)
    x = w * math.copysign(abs(c) ** (2.0 / 2.4), c)
    if s >= 0.0:
        # (its sides slope in from the skirt to a rounded back)
        x = w * c * lerp(1.0, 0.84, s)
        y = cy + (h - cy) * s
    else:
        # (flat beneath, the sole, with rounded edges)
        y = cy * (1.0 - abs(s) ** (2.0 / 6.0))
    y = max(y, 0.0)
    # The skirt stands a little proud low down, just above the sole.
    x *= 1.0 + 0.06 * (1.0 - smooth(0.0, 0.35, y))
    # The keel down the top of the tail.
    if z < -1.8 and s > 0.0:
        y += 0.09 * smooth(-1.8, -3.0, z) * math.exp(-(x / 0.22) ** 2)
    fringe = smooth(0.42, 0.05, y)
    # The head rounds off in front to the mouth, low down (the sole runs on under it).
    if z > HEAD_ROUND:
        u = min((z - HEAD_ROUND) / (ZH - HEAD_ROUND), 1.0)
        dome = math.sqrt(max(1.0 - u * u, 0.0))
        middle = 0.24
        x *= lerp(0.04, 1.0, dome)
        y = middle + (y - middle) * lerp(0.04, 1.0, dome ** 0.7)
        y = max(y, 0.0)
    return V(x, y, z), fringe


def body_mesh(bm, uv, colours):
    stations = 30 if LOW else 96
    segments = 14 if LOW else 44
    loops = []
    # (evenly along the foot, and closer together round the front of the head, where it rounds off)
    zs = [lerp(ZT + 0.02, HEAD_ROUND, k / stations) for k in range(stations)]
    cap = 4 if LOW else 12
    zs += [HEAD_ROUND + (ZH - 0.01 - HEAD_ROUND) * math.sin(math.pi * 0.5 * k / cap) for k in range(cap + 1)]
    for z in zs:
        loop = []
        around = 0.0
        last = None
        for i in range(segments + 1):
            a = -math.pi * 0.5 + TAU * i / segments
            p, fringe = section(z, a)
            if last is not None:
                around += (p - last).length
            last = p
            v = bm.verts.new(to_blender(p))
            sole = 1.0 if p.y < 0.02 else 0.0
            # The mouth: a dark slit under the front of the head.
            mouth = math.exp(-((z - 3.45) / 0.07) ** 2) * math.exp(-((p.y - 0.3) / 0.05) ** 2) * math.exp(-(p.x / 0.24) ** 2)
            under_head = smooth(2.2, 3.2, z) * smooth(0.6, 0.2, p.y)
            pale = max(sole * 0.8, under_head * 0.5, fringe * 0.35)
            open_ = 1.0 - 0.6 * mouth - 0.3 * math.exp(-((p.y - 0.3) / 0.05) ** 2)
            colours[v] = (open_, fringe, pale, 0.5 if mouth > 0.5 else 0.0)
            loop.append((v, (z, around)))
        loops.append(loop)
    faces = []
    for a, b in zip(loops, loops[1:]):
        for i in range(segments):
            quad = (a[i], a[i + 1], b[i + 1], b[i])
            face = bm.faces.new([q[0] for q in quad])
            for loop, q in zip(face.loops, quad):
                loop[uv].uv = q[1]
            faces.append(face)
    for end, z in ((loops[0], ZT), (loops[-1], ZH)):
        p, _ = section(z, math.pi * 0.5)
        pole = bm.verts.new(to_blender(V(0.0, 0.24 if z > 0 else 0.03, z + (0.01 if z > 0 else -0.01))))
        colours[pole] = (1.0, 0.0, 0.3, 0.0)
        for i in range(segments):
            face = bm.faces.new([end[i][0], end[i + 1][0], pole])
            for loop in face.loops:
                loop[uv].uv = (z, 0.0)
            faces.append(face)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def strand(bm, uv, colours, points, radii, colour, segments, cap_colour=None):
    """A round-ended tube along `points` (Godot space). Gives its rings' vertices, by point."""
    rings = []
    for i, p in enumerate(points):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        u = ahead.cross(V(0, 1, 0) if abs(ahead.y) < 0.9 else V(1, 0, 0)).normalized()
        v = ahead.cross(u)
        rings.append((p, u * radii[i], v * radii[i]))
    # (domed ends)
    first = (points[0] - points[1]).normalized()
    last = (points[-1] - points[-2]).normalized()

    def dome(r, axis, radius, steps):
        out = []
        for k in range(1, steps + 1):
            ang = math.pi * 0.5 * k / (steps + 1)
            out.append((r[0] + axis * radius * math.sin(ang), r[1] * math.cos(ang), r[2] * math.cos(ang)))
        return out

    rings = dome(rings[0], first, radii[0], 2)[::-1] + rings + dome(rings[-1], last, radii[-1], 3)
    loops = []
    made = []
    for n, (centre, u, v) in enumerate(rings):
        loop = []
        for i in range(segments + 1):
            ang = TAU * i / segments
            p = centre + u * math.cos(ang) + v * math.sin(ang)
            vert = bm.verts.new(to_blender(p))
            colours[vert] = colour(n / (len(rings) - 1), p) if callable(colour) else colour
            loop.append((vert, (n * 0.1, i / segments)))
        loops.append(loop)
        made.append(loop)
    faces = []
    for a, b in zip(loops, loops[1:]):
        for i in range(segments):
            quad = (a[i], a[i + 1], b[i + 1], b[i])
            face = bm.faces.new([q[0] for q in quad])
            for loop, q in zip(face.loops, quad):
                loop[uv].uv = q[1]
            faces.append(face)
    for end in (loops[0], loops[-1]):
        middle = Vector((0, 0, 0))
        for q in end[:-1]:
            middle += q[0].co
        middle /= segments
        pole = bm.verts.new(middle)
        colours[pole] = colours[end[0][0]]
        for i in range(segments):
            face = bm.faces.new([end[i][0], end[i + 1][0], pole])
            faces.append(face)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def curve(base, ahead, bend, length, count):
    """Points along a gently bending line from `base`."""
    out = []
    for k in range(count):
        t = k / (count - 1)
        out.append(base + ahead * (length * t) + bend * (length * t * t))
    return out


# Where the stalks and feelers are rooted, and how they go (the left; the right is mirrored).
EYE_ROOT = V(0.36, 1.08, 2.78)
EYE_AHEAD = V(0.30, 0.78, 0.55).normalized()
EYE_BEND = V(0.06, -0.10, 0.12)
EYE_LENGTH = 2.1
FEEL_ROOT = V(0.40, 0.55, 3.28)
FEEL_AHEAD = V(0.55, -0.32, 0.78).normalized()
FEEL_LENGTH = 0.62


def mirrored(p, side):
    return V(p.x * side, p.y, p.z)


def tentacles(bm, uv, colours):
    """The eye stalks and the feelers. Gives {bone: [vertices and how far along each is]} for weighing."""
    along = {}
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        seg = 6 if LOW else 14
        count = 5 if LOW else 12
        points = curve(mirrored(EYE_ROOT, side), mirrored(EYE_AHEAD, side), mirrored(EYE_BEND, side), EYE_LENGTH, count)
        radii = [lerp(0.15, 0.065, (k / (count - 1)) ** 0.7) for k in range(count)]
        radii[-1] = 0.1
        radii[-2] = 0.085
        colour = lambda t, p: (lerp(0.75, 1.0, t), 0.0, 0.15, 0.0)
        before = len(bm.verts)
        strand(bm, uv, colours, points, radii, colour, seg)
        bm.verts.ensure_lookup_table()
        along["eye" + suffix] = (points, bm.verts[before:])
        # The eye: a black bead on the tip's outer face.
        tip = points[-1]
        ahead = (points[-1] - points[-2]).normalized()
        out = mirrored(V(1, 0, 0), side)
        eye_at = tip + ahead * 0.06 + (out - ahead * out.dot(ahead)).normalized() * 0.07 + V(0, 0.03, 0)
        before = len(bm.verts)
        strand(bm, uv, colours, [eye_at - ahead * 0.02, eye_at + ahead * 0.02], [0.065, 0.065], (0.1, 0.0, 0.0, 1.0), 6 if LOW else 10)
        bm.verts.ensure_lookup_table()
        along["eyeball" + suffix] = (points, bm.verts[before:])
        # The feeler.
        fcount = 4 if LOW else 7
        points = curve(mirrored(FEEL_ROOT, side), mirrored(FEEL_AHEAD, side), V(0, -0.06, 0.04), FEEL_LENGTH, fcount)
        radii = [lerp(0.15, 0.075, k / (fcount - 1)) for k in range(fcount)]
        radii[-1] = 0.09
        before = len(bm.verts)
        strand(bm, uv, colours, points, radii, lambda t, p: (lerp(0.8, 1.0, t), 0.0, 0.25, 0.0), 5 if LOW else 10)
        bm.verts.ensure_lookup_table()
        along["feel" + suffix] = (points, bm.verts[before:])
    return along


def mouth_lip_frame():
    """The mouth of the shell in the snail's space: its middle, the way it faces, and its lip (48 points round it)."""
    place = shell_place()
    ring = [place(p) for p in lip_ring(48)]
    middle = sum(ring, Vector((0, 0, 0))) / len(ring)
    normal = Vector((0, 0, 0))
    for a, b in zip(ring, ring[1:] + ring[:1]):
        normal += (a - middle).cross(b - middle)
    normal.normalize()
    # (it faces the way the shell grows: forward)
    if normal.z < 0.0:
        normal = -normal
    return middle, normal, ring


def mantle(bm, uv, colours):
    """The mantle filling the mouth of the shell inside its collar: a low dome of skin
    (the body goes in under it, into the shell)."""
    middle, facing, ring = mouth_lip_frame()
    count = 16 if LOW else len(ring)
    steps = 2 if LOW else 5
    rims = []
    for k in range(count):
        lip = ring[k * len(ring) // count]
        rims.append(middle + (lip - middle) * 0.9 - facing * 0.35)
    loops = []
    for n in range(steps):
        t = n / steps
        bulge = math.sqrt(max(1.0 - (1.0 - t) ** 2, 0.0)) if n else 0.0
        loop = []
        for p in rims:
            q = middle + (p - middle) * (1.0 - t) - facing * 0.35 + facing * (0.3 * bulge)
            v = bm.verts.new(to_blender(q))
            colours[v] = (lerp(0.6, 0.9, t), 0.0, 0.0, 0.0)
            loop.append(v)
        loops.append(loop)
    pole = bm.verts.new(to_blender(middle - facing * 0.05))
    colours[pole] = (0.9, 0.0, 0.0, 0.0)
    faces = []
    for a, b in zip(loops, loops[1:]):
        for k in range(count):
            faces.append(bm.faces.new([a[k], a[(k + 1) % count], b[(k + 1) % count], b[k]]))
    for k in range(count):
        faces.append(bm.faces.new([loops[-1][k], loops[-1][(k + 1) % count], pole]))
    for face in faces:
        for loop in face.loops:
            p = from_blender(loop.vert.co)
            loop[uv].uv = (p.x + p.z, p.y)
    # (it faces out of the mouth)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    if faces[-1].normal.dot(to_blender(facing)) < 0.0:
        for face in faces:
            face.normal_flip()


def collar(bm, uv, colours):
    """The mantle's thick collar in the mouth of the shell, and the breathing pore in it, on the right."""
    middle, facing, ring = mouth_lip_frame()
    ring_count = len(ring) if not LOW else 16
    tube = 6 if LOW else 12
    points = []
    pore_at = None
    best = -9.0
    for k in range(ring_count):
        lip = ring[k * len(ring) // ring_count]
        p = middle + (lip - middle) * 0.86 - facing * 0.04
        points.append(p)
        # (the pore: on the right of the collar, high)
        score = -p.x + p.y * 0.5
        if score > best:
            best = score
            pore_at = p
    loops = []
    for k, p in enumerate(points):
        ahead = (points[(k + 1) % ring_count] - points[k - 1]).normalized()
        out = (p - middle).normalized()
        out = (out - ahead * out.dot(ahead)).normalized()
        side = ahead.cross(out)
        loop = []
        for i in range(tube + 1):
            ang = TAU * i / tube
            q = p + out * (0.14 * math.cos(ang)) + side * (0.2 * math.sin(ang))
            v = bm.verts.new(to_blender(q))
            colours[v] = (0.9, 0.0, 0.45, 0.0)
            loop.append(v)
        loops.append(loop)
    faces = []
    for k in range(ring_count):
        a, b = loops[k], loops[(k + 1) % ring_count]
        for i in range(tube):
            face = bm.faces.new([a[i], a[i + 1], b[i + 1], b[i]])
            for n, loop in enumerate(face.loops):
                loop[uv].uv = ((k + (n in (2, 3))) * 6.5 / ring_count, (i + (n in (1, 2))) * 0.9 / tube)
            faces.append(face)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    # The pore: a dark round hole on the collar's outside.
    out = (pore_at - middle).normalized()
    pore_centre = pore_at + out * 0.14 + facing * 0.06
    before = len(bm.verts)
    strand(bm, uv, colours, [pore_centre - out * 0.04, pore_centre + out * 0.04], [0.12, 0.12], (0.25, 0.0, 0.0, 0.5), 6 if LOW else 12)
    bm.verts.ensure_lookup_table()
    return middle, pore_centre, bm.verts[before:]


# --- Bones and weights ---

FOOT_BONES = 10
FOOT_FROM, FOOT_TO = -4.0, 2.2
HEAD = V(0.0, 0.55, 2.85)


def foot_z(i):
    return lerp(FOOT_FROM, FOOT_TO, i / (FOOT_BONES - 1))


def bones(along, shell_at, pore_at):
    made = [("foot_%d" % i, V(0.0, 0.0, foot_z(i))) for i in range(FOOT_BONES)]
    made.append(("head", HEAD))
    for suffix in ("_l", "_r"):
        points = along["eye" + suffix][0]
        for k in range(4):
            made.append(("eye%s_%d" % (suffix, k), points[round(k * (len(points) - 1) / 3)]))
        points = along["feel" + suffix][0]
        made.append(("feel%s_0" % suffix, points[0]))
        made.append(("feel%s_1" % suffix, points[-1]))
    made.append(("shell", shell_at))
    made.append(("pore", pore_at))
    return made


def foot_weights(p):
    """The foot bones (and the head's) for a point of the body."""
    z = p.z
    out = {}
    head = smooth(2.05, 2.75, z)
    f = (min(max(z, FOOT_FROM), FOOT_TO) - FOOT_FROM) / (FOOT_TO - FOOT_FROM) * (FOOT_BONES - 1)
    i = min(int(f), FOOT_BONES - 2)
    t = f - i
    out["foot_%d" % i] = (1.0 - t) * (1.0 - head)
    out["foot_%d" % (i + 1)] = out.get("foot_%d" % (i + 1), 0.0) + t * (1.0 - head)
    if head > 0.0:
        out["head"] = head
    # What rises into the shell's mouth goes with the shell.
    inside = smooth(1.05, 1.5, p.y) * smooth(-2.4, -1.6, z) * smooth(1.75, 1.2, z)
    if inside > 0.0:
        out = {k: v * (1.0 - inside) for k, v in out.items()}
        out["shell"] = inside
    return out


def chain_weights(points, names, p):
    """Weights along a chain of bones at `points`' quarter marks, for a point near it."""
    best, best_t = 1e9, 0.0
    n = len(points) - 1
    for k in range(n):
        a, b = points[k], points[k + 1]
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        d = (a + ab * t - p).length
        if d < best:
            best, best_t = d, (k + t) / n
    f = best_t * (len(names) - 1)
    i = min(int(f), len(names) - 2)
    t = f - i
    return {names[i]: 1.0 - t, names[i + 1]: t}


# --- Putting it together ---

def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


MATERIALS = [("skin", (0.32, 0.29, 0.26)), ("shell", (0.45, 0.40, 0.33))]


def make_armature(listed):
    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for name, at in listed:
        bone = data.edit_bones.new(name)
        bone.head = to_blender(at)
        bone.tail = to_blender(at + V(0, 0.08, 0))
        bone.roll = 0.0
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def export():
    name = "snail" + ("_lo" if LOW else "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    colours = {}
    part = {}

    first = len(bm.verts)
    skin_faces = body_mesh(bm, uv, colours)
    bm.verts.ensure_lookup_table()
    for v in bm.verts[first:]:
        part[v] = "body"
    along = tentacles(bm, uv, colours)
    mantle(bm, uv, colours)
    middle, pore_centre, pore_verts = collar(bm, uv, colours)
    bm.verts.ensure_lookup_table()
    for v in bm.verts[first:]:
        part.setdefault(v, "collar")
    for v in pore_verts:
        part[v] = "pore"
    for key, (points, verts) in along.items():
        for v in verts:
            part[v] = key
    skin_count = len(bm.faces)
    shell_first = len(bm.verts)
    place = shell_place()
    shell_mesh(bm, uv, colours, place)
    bm.verts.ensure_lookup_table()
    for v in bm.verts[shell_first:]:
        part[v] = "shell"
    bm.faces.ensure_lookup_table()
    for k, face in enumerate(bm.faces):
        face.material_index = 0 if k < skin_count else 1
        face.smooth = True
    # (the shell's middle, for its bone)
    shell_at = place(V(0.0, -T * R0 * 0.55, 0.0))
    if not LOW:
        low = min((from_blender(v.co) for v in bm.verts[shell_first:]), key=lambda p: p.y)
        high = max((from_blender(v.co) for v in bm.verts[shell_first:]), key=lambda p: p.y)
        print("SHELL lowest (%.2f, %.2f, %.2f) highest %.2f; mouth %s faces %s" % (low.x, low.y, low.z, high.y, tuple(round(c, 2) for c in mouth_lip_frame()[0]), tuple(round(c, 2) for c in mouth_lip_frame()[1])))

    listed = bones(along, shell_at, pore_centre)
    armature = make_armature(listed)
    mesh = bpy.data.meshes.new(name)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    for label, srgb in MATERIALS:
        made = bpy.data.materials.new(label)
        made.use_nodes = True
        colour = tuple(linear(c) for c in srgb) + (1.0,)
        bsdf = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Roughness"].default_value = 1.0
        made.diffuse_color = colour
        mesh.materials.append(made)
    groups = {bone.name: body.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
    deform = bm.verts.layers.deform.verify()
    layer = bm.verts.layers.float_color.new("Color")
    eye_names = {s: ["eye%s_%d" % (s, k) for k in range(4)] for s in ("_l", "_r")}
    for v in bm.verts:
        p = from_blender(v.co)
        what = part.get(v, "body")
        if what == "body":
            weights = foot_weights(p)
        elif what in ("collar", "shell"):
            weights = {"shell": 1.0}
        elif what == "pore":
            weights = {"pore": 1.0}
        elif what.startswith("eyeball"):
            weights = {"eye%s_3" % what[-2:]: 1.0}
        elif what.startswith("eye"):
            weights = chain_weights(along[what][0], eye_names[what[-2:]], p)
            # (its root is part of the head)
            root = smooth(0.25, 0.0, (p - along[what][0][0]).length)
            if root > 0.0:
                weights = {k: w * (1.0 - root) for k, w in weights.items()}
                weights["head"] = weights.get("head", 0.0) + root
        else:
            suffix = what[-2:]
            weights = chain_weights(along[what][0], ["feel%s_0" % suffix, "feel%s_1" % suffix], p)
        for bone, weight in weights.items():
            if weight > 0.001:
                v[deform][groups[bone]] = weight
        r, g, b, a = colours.get(v, (1.0, 0.0, 0.0, 0.0))
        v[layer] = (r, g, b, a)
    bm.to_mesh(mesh)
    bm.free()
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
    print("BUILT %s verts=%d tris=%d bones=%d" % (name, len(mesh.vertices), sum(len(p.vertices) - 2 for p in mesh.polygons), len(listed)))
    if PREVIEW:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(PREVIEW, name + ".blend"))
        if not LOW:
            render(PREVIEW, name)


def render(folder, name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 900, 700
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (view, direction to the camera in Blender space, what it looks at, how much it frames, colours)
    views = [("left", (1, 0, 0), (0.0, 0.0, 1.6), 9.5, "MATERIAL"), ("right", (-1, 0, 0), (0.0, 0.0, 1.6), 9.5, "MATERIAL"),
             ("quarter", (0.7, -0.7, 0.35), (0.0, 0.0, 1.6), 9.5, "MATERIAL"), ("front", (0.0, -1, 0.1), (0.0, 0.0, 1.8), 6.0, "MATERIAL"),
             ("top", (0.05, 0.0, 1), (0.0, 0.0, 1.0), 9.5, "MATERIAL"), ("back", (-0.5, 0.8, 0.4), (0.0, 0.0, 1.6), 9.5, "MATERIAL"),
             ("head", (0.6, -0.7, 0.25), (0.0, -3.0, 1.6), 4.0, "VERTEX"), ("mouth_left", (1, -0.5, 0.3), (0.0, -0.9, 1.4), 3.5, "VERTEX"), ("mouth_right", (-1, -0.6, 0.3), (0.0, -0.9, 1.4), 3.5, "VERTEX"), ("shade", (0.8, -0.5, 0.2), (0.0, 0.0, 1.6), 9.5, "VERTEX")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 20.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for low in (False, True):
        LOW = low
        export()
