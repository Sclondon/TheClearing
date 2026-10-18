"""Builds the giant ants (creatures/giant_ant/) and exports them for Godot.

Run from the game's root:
    blender --background --python creatures/giant_ant/tools/build_ants.py [-- <folder for pictures>]
then, so that Godot takes up the new models:
    godot --headless --path . --import

Writes creatures/giant_ant/models/ants.glb and the demade ants_lo.glb. Each holds three objects, all at their real
size in metres, facing the game's +Z, standing on the ground (y = 0) with the middle of the thorax over the origin:

    worker   a big formicine worker, after the carpenter ants (Camponotus), 1.2 m from its jaws to the tip of its
             gaster: the size of a dog. A heart-shaped head held a little down, wider behind, with big oval compound
             eyes on its sides, toothed triangular jaws closed in front of it, and elbowed feelers (a long scape up
             and out from between the eyes, then a whip of eleven beads running forward and down, thickening to its
             tip). A narrow humped thorax (pronotum, mesonotum, a groove, the propodeum falling steeply behind), one
             upright scale for a waist (the petiole), and a big oval gaster of four overlapping plates. Six long legs
             from under the thorax, each coxa, femur, tibia (with its spur) and five beads of tarsus with a claw.
    soldier  a major: the same body, a head nearly twice as big, with heavy jaws.
    load     what a forager carries home in its jaws: a lump of meat with a splinter of bone in it.

The game draws a colony of them as one MultiMesh (AntLook) and moves their parts in a shader (`ant.gdshader`), which
is told what each point belongs to by the mesh's UV map:

    U  how far along its part a point is (a leg: 0 at the hip, 1 at the foot; a feeler: 0 at its socket, 1 at its
       tip; a jaw: 0 at its hinge, 1 at its point; the gaster: 0 at the waist, 1 at its tip; the rest 0)
    V  which part it is (in Godot, after glTF has turned V over; here it is written 1 - part):
        0 head and thorax, 1-3 left legs fore to hind, 4-6 right legs fore to hind, 7 left feeler, 8 right feeler,
        9 left jaw, 10 right jaw, 11 gaster, 12 eyes, 13 the load

The colours are the game's (the shader's, by part); the materials here are only for the pictures. Keep the worker to
about 1800 triangles and the low one to about 600: a colony is some thirty of them.

Everything is written in the game's own directions (x to its left, y up, z the way it faces) and turned to Blender's as
it is made.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
OUT = os.path.join(COMPONENT, "models")
PREVIEW = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

LOW = False

BODY, LEG_L, LEG_R, FEELER_L, FEELER_R, JAW_L, JAW_R, GASTER, EYES, LOAD = 0, 1, 4, 7, 8, 9, 10, 11, 12, 13
# (for the pictures only)
TONES = {BODY: (0.07, 0.055, 0.045), GASTER: (0.06, 0.05, 0.042), EYES: (0.02, 0.02, 0.025), LOAD: (0.45, 0.33, 0.3)}
LIMB_TONE = (0.13, 0.1, 0.08)


def V(x, y, z):
    return Vector((x, y, z))


def to_blender(p):
    return Vector((p.x, -p.z, p.y))


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


class Shape:
    """Faces, each with the U of every corner and the part it belongs to."""

    def __init__(self):
        self.faces = []

    def face(self, corners, us, part):
        self.faces.append((corners, us, part))

    def loft(self, rings, us, part, start_tip=None, end_tip=None, start_u=None, end_u=None):
        """Joins rings of points (each the same count, round in the same sense) with quads, and closes either end
        in a point (`start_tip`, `end_tip`) when given. `us` is the U of each ring."""
        sides = len(rings[0])
        for r in range(len(rings) - 1):
            a, b = rings[r], rings[r + 1]
            for k in range(sides):
                n = (k + 1) % sides
                self.face([a[k], a[n], b[n], b[k]], [us[r], us[r], us[r + 1], us[r + 1]], part)
        if start_tip is not None:
            first = rings[0]
            u = us[0] if start_u is None else start_u
            for k in range(sides):
                n = (k + 1) % sides
                self.face([start_tip, first[n], first[k]], [u, us[0], us[0]], part)
        if end_tip is not None:
            last = rings[-1]
            u = us[-1] if end_u is None else end_u
            for k in range(sides):
                n = (k + 1) % sides
                self.face([last[k], last[n], end_tip], [us[-1], us[-1], u], part)


def frames(points, hint=V(0.0, 1.0, 0.0)):
    """A frame (side, up) at each point of a path, carried along it so that it does not twist."""
    out = []
    side = None
    for i, p in enumerate(points):
        ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        if side is None:
            side = ahead.cross(hint)
            if side.length < 1e-4:
                side = ahead.cross(V(1.0, 0.0, 0.0))
            side.normalize()
        else:
            side = (side - ahead * side.dot(ahead)).normalized()
        up = side.cross(ahead).normalized()
        out.append((side, up))
    return out


def tube(shape, points, radii, us, part, sides, hint=V(0.0, 1.0, 0.0), tip_start=False, tip_end=True):
    """A tube along `points`, each ring an ellipse (rx across, ry up) about the path, closed at the ends."""
    fr = frames(points, hint)
    rings = []
    for p, (side, up), r in zip(points, fr, radii):
        rx, ry = r if isinstance(r, tuple) else (r, r)
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            ring.append(p + side * math.cos(a) * rx + up * math.sin(a) * ry)
        rings.append(ring)
    start = points[0] - (points[1] - points[0]).normalized() * (radii[0][0] if isinstance(radii[0], tuple) else radii[0]) * 0.6 if tip_start else None
    end_r = radii[-1][0] if isinstance(radii[-1], tuple) else radii[-1]
    end = points[-1] + (points[-1] - points[-2]).normalized() * end_r * 0.7 if tip_end else None
    shape.loft(rings, us, part, start, end)


def body_loft(shape, stations, part, sides, u_of=None, warp=None):
    """A body part lofted along z: stations of (z, centre y, half width, half height), rings round the long axis,
    closed at both ends in points. `warp(p)` may move each point after."""
    rings = []
    us = []
    for z, y, rx, ry in stations:
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            p = V(math.cos(a) * rx, y + math.sin(a) * ry, z)
            ring.append(warp(p) if warp else p)
        rings.append(ring)
        us.append(u_of(z) if u_of else 0.0)
    z0, y0 = stations[0][0], stations[0][1]
    z1, y1 = stations[-1][0], stations[-1][1]
    first = V(0.0, y0, z0 + (0.006 if z0 > z1 else -0.006))
    last = V(0.0, y1, z1 + (0.006 if z1 > z0 else -0.006))
    # (rings run from z0 to z1; the end points close them)
    shape.loft(rings, us, part, warp(first) if warp else first, warp(last) if warp else last)


def ellipsoid(shape, centre, radii, part, rings, sides, turn=None, u=0.0):
    rx, ry, rz = radii
    made = []
    for i in range(1, rings):
        t = math.pi * i / rings
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            p = V(math.cos(a) * math.sin(t) * rx, math.sin(a) * math.sin(t) * ry, -math.cos(t) * rz)
            ring.append(centre + (turn @ p if turn else p))
        made.append(ring)
    back = centre + (turn @ V(0.0, 0.0, -rz) if turn else V(0.0, 0.0, -rz))
    front = centre + (turn @ V(0.0, 0.0, rz) if turn else V(0.0, 0.0, rz))
    shape.loft(made, [u] * len(made), part, back, front)


# --- The ant ---

SIDES = 10


def head(shape, big):
    """The head: heart-shaped from above (wide behind, with a notch at the back of the crown), flattened, held a
    little down. `big` scales a soldier's about its back (where it meets the neck)."""
    sides = 7 if LOW else 12
    back = V(0.0, 0.25, 0.33)
    length = 0.26 * big
    tilt = Matrix.Rotation(math.radians(22.0), 3, "X")

    def warp(p):
        q = V(p.x, p.y - 0.25, p.z - 0.33)
        # (the notch at the back of the crown, and the face a little hollowed between the eyes)
        t = q.z / length
        notch = 0.018 * big * math.exp(-(q.x / (0.05 * big)) ** 2) * smooth(1.0 - t * 4.0) * (1.0 if q.y > 0.0 else 0.0)
        q.y -= notch
        q = tilt @ q
        return back + q + V(0.0, 0.0, 0.0)

    stations = []
    count = 6 if LOW else 10
    for i in range(count + 1):
        t = i / count
        # (half width: widest a third of the way from the back, narrowing to the jaws; half height lower in front)
        width = (0.115 * (1.0 - 0.18 * (t - 0.32) ** 2 / 0.46 - 0.35 * smooth((t - 0.45) / 0.55))) * big
        width *= math.sin(math.pi * min(max(t * 0.92 + 0.04, 0.0), 1.0)) ** 0.28
        height = (0.075 - 0.02 * t) * (1.0 + (big - 1.0) * 0.7)
        height *= math.sin(math.pi * min(max(t * 0.92 + 0.04, 0.0), 1.0)) ** 0.35
        stations.append((t * length, 0.0, max(width, 0.006), max(height, 0.005)))
    stations = [(0.33 + z, 0.25 + y, rx, ry) for z, y, rx, ry in stations]

    def warp_world(p):
        return warp(p)

    body_loft(shape, stations, BODY, sides, warp=warp_world)
    # The eyes: big ovals bulging from the sides, a little forward of the middle.
    for side in (1.0, -1.0):
        at = warp(V(side * 0.098 * big, 0.268, 0.33 + length * 0.52))
        ellipsoid(shape, at, (0.034 * big ** 0.6, 0.042 * big ** 0.6, 0.056 * big ** 0.6), EYES,
                  3 if LOW else 5, 5 if LOW else 8, Matrix.Rotation(side * math.radians(8.0), 3, "Y") @ tilt)
    return warp, length


def feelers(shape, warp, length, big):
    sides = 4 if LOW else 5
    for side, part in ((1.0, FEELER_L), (-1.0, FEELER_R)):
        socket = warp(V(side * 0.035 * big, 0.278, 0.33 + length * 0.78))
        elbow = socket + V(side * 0.12, 0.17, 0.075)
        # The scape: a long straight stalk, thickening a little to the elbow.
        scape = [socket, socket.lerp(elbow, 0.5), elbow] if not LOW else [socket, elbow]
        tube(shape, scape, [0.011, 0.012, 0.015] if not LOW else [0.011, 0.015], [0.0, 0.15, 0.3] if not LOW else [0.0, 0.3], part, sides, tip_start=True, tip_end=False)
        # The whip: eleven beads forward and down, out a little, thickening to a club.
        beads = 11 if not LOW else 5
        tip = elbow + V(side * 0.08, -0.05, 0.25)
        bend = elbow + V(side * 0.06, 0.02, 0.12)
        points = []
        for i in range(beads + 1):
            t = i / beads
            a = elbow.lerp(bend, t)
            b = bend.lerp(tip, t)
            points.append(a.lerp(b, t))
        radii = []
        for i in range(len(points)):
            t = i / (len(points) - 1)
            r = 0.010 + 0.007 * smooth((t - 0.6) / 0.4)
            # (each bead a little waisted where it joins the next)
            radii.append(r * (0.82 if (i % 2 == 0 and 0 < i < len(points) - 1 and not LOW) else 1.0))
        tube(shape, points, radii, [0.3 + 0.7 * i / (len(points) - 1) for i in range(len(points))], part, sides, tip_start=False)


def jaws(shape, warp, length, big):
    """Triangular blades meeting in front of the face, teeth on their inner edges."""
    heavy = 1.0 + (big - 1.0) * 1.4
    for side, part in ((1.0, JAW_L), (-1.0, JAW_R)):
        hinge = warp(V(side * 0.06 * big, 0.232, 0.33 + length * 0.94))
        # (outer edge sweeps forward and in; the cutting edge runs back along the inside)
        outer = [hinge, hinge + V(side * 0.006, -0.008, 0.05 * heavy), hinge + V(-side * 0.02 * heavy, -0.014, 0.095 * heavy),
                 hinge + V(-side * 0.058 * big, -0.016, 0.112 * heavy)]
        rings = []
        us = []
        teeth = 5
        for i, p in enumerate(outer):
            t = i / (len(outer) - 1)
            width = (0.03 * (1.0 - t) + 0.006) * heavy
            depth = (0.012 * (1.0 - 0.6 * t)) * heavy
            inward = V(-side, 0.0, -0.35).normalized()
            ring = [p + V(0.0, depth, 0.0), p + inward * width + V(0.0, depth * 0.4, 0.0),
                    p + inward * width * (1.0 + (0.18 if i % 2 == 1 else 0.0)) - V(0.0, depth * 0.4, 0.0), p - V(0.0, depth, 0.0)]
            if side < 0:
                ring.reverse()
            rings.append(ring)
            us.append(t)
        shape.loft(rings, us, part, None, outer[-1] + V(-side * 0.012, -0.002, 0.004) * heavy)
        # (the base closed off where it goes into the head)
        shape.face(list(reversed(rings[0])), [0.0] * 4, part)


def thorax(shape):
    sides = 7 if LOW else SIDES
    # (z, middle height, half width, half height): the pronotum's hump, the mesonotum, the groove, the propodeum
    stations = [(0.335, 0.246, 0.030, 0.028), (0.318, 0.252, 0.055, 0.05), (0.29, 0.258, 0.072, 0.068),
                (0.25, 0.262, 0.078, 0.074), (0.21, 0.258, 0.074, 0.07), (0.17, 0.246, 0.062, 0.062),
                (0.13, 0.24, 0.056, 0.058), (0.09, 0.232, 0.052, 0.052), (0.055, 0.222, 0.046, 0.04),
                (0.03, 0.222, 0.05, 0.048), (0.0, 0.226, 0.054, 0.054), (-0.03, 0.222, 0.05, 0.05),
                (-0.055, 0.214, 0.036, 0.034), (-0.068, 0.21, 0.018, 0.018)]
    if LOW:
        stations = stations[::2] + [stations[-1]]
    body_loft(shape, stations, BODY, sides)
    # The neck, from the front of the pronotum into the back of the head
    tube(shape, [V(0.0, 0.248, 0.33), V(0.0, 0.25, 0.36)], [0.032, 0.03], [0.0, 0.0], BODY, 6, tip_start=True, tip_end=True)


def waist(shape):
    sides = 6 if LOW else 8
    tube(shape, [V(0.0, 0.212, -0.06), V(0.0, 0.214, -0.1), V(0.0, 0.218, -0.14)], [0.02, 0.022, 0.024], [0.0] * 3, BODY, sides, tip_start=True)
    # The scale: an upright plate, thick at its foot, rounded at the top
    ellipsoid(shape, V(0.0, 0.252, -0.102), (0.042, 0.062, 0.02), BODY, 4 if LOW else 6, sides, Matrix.Rotation(math.radians(-12.0), 3, "X"))


def gaster(shape):
    sides = 8 if LOW else 11
    front, back = -0.13, -0.6
    stations = []
    count = 7 if LOW else 13
    for i in range(count + 1):
        t = i / count
        z = front + (back - front) * t
        s = math.sin(math.pi * min(max(t * 0.96 + 0.02, 0.0), 1.0)) ** 0.62
        # (the plates overlap: each a little fuller at its back edge)
        plates = 0.0 if LOW else 0.035 * (((t * 4.3) % 1.0) ** 3) * smooth(t * 8.0) * smooth((1.0 - t) * 5.0)
        rx = 0.15 * s * (1.0 + plates) * (1.0 - 0.15 * t)
        ry = 0.13 * s * (1.0 + plates)
        # (it hangs a little: its middle lower than the waist, its tip curving down)
        y = 0.225 + 0.02 * math.sin(math.pi * t) - 0.05 * t ** 2.2
        stations.append((z, y, max(rx, 0.006), max(ry, 0.006)))
    body_loft(shape, stations, GASTER, sides, u_of=lambda z: (z - front) / (back - front))


# Each leg: coxa root, coxa end, knee, end of the tibia, foot; on the left (the right is its mirror).
LEGS = [
    [V(0.04, 0.2, 0.25), V(0.075, 0.135, 0.285), V(0.2, 0.3, 0.39), V(0.31, 0.07, 0.47), V(0.345, 0.0, 0.56)],
    [V(0.045, 0.185, 0.12), V(0.085, 0.13, 0.115), V(0.27, 0.32, 0.14), V(0.43, 0.065, 0.12), V(0.5, 0.0, 0.1)],
    [V(0.045, 0.19, 0.005), V(0.085, 0.13, -0.015), V(0.27, 0.33, -0.13), V(0.41, 0.07, -0.32), V(0.47, 0.0, -0.43)],
]
LEG_U = [0.0, 0.1, 0.45, 0.85, 1.0]


def legs(shape):
    sides = 4 if LOW else 6
    for side, first in ((1.0, LEG_L), (-1.0, LEG_R)):
        for k, joints in enumerate(LEGS):
            j = [V(p.x * side, p.y, p.z) for p in joints]
            part = first + k
            hint = V(0.0, 0.0, 1.0)
            # coxa
            tube(shape, [j[0], j[1]], [0.034, 0.03], [LEG_U[0], LEG_U[1]], part, sides, hint, tip_start=True, tip_end=False)
            # femur: thick at its root, a little bowed
            mid = j[1].lerp(j[2], 0.5) + V(0.0, 0.015, 0.0)
            pts = [j[1], j[1].lerp(mid, 0.5), mid, mid.lerp(j[2], 0.5), j[2]]
            us = [LEG_U[1] + (LEG_U[2] - LEG_U[1]) * t / 4.0 for t in range(5)]
            tube(shape, pts if not LOW else [j[1], mid, j[2]], [0.028, 0.03, 0.026, 0.022, 0.02] if not LOW else [0.028, 0.026, 0.02],
                 us if not LOW else [us[0], us[2], us[4]], part, sides, hint, tip_start=False, tip_end=False)
            # tibia, with a spur at its end
            pts = [j[2], j[2].lerp(j[3], 0.5), j[3]]
            tube(shape, pts, [0.019, 0.016, 0.015], [LEG_U[2], (LEG_U[2] + LEG_U[3]) * 0.5, LEG_U[3]], part, sides, hint, tip_start=False, tip_end=False)
            if not LOW:
                spur = [j[3], j[3] + (j[4] - j[3]).normalized() * 0.03 + V(-side * 0.01, -0.005, -0.01)]
                tube(shape, spur, [0.006, 0.002], [LEG_U[3], LEG_U[3]], part, 4, hint, tip_start=False)
            # tarsus: five beads, then a claw
            beads = 5 if not LOW else 2
            pts = []
            radii = []
            for b in range(beads + 1):
                t = b / beads
                pts.append(j[3].lerp(j[4], t) + V(0.0, 0.02 * math.sin(math.pi * t), 0.0))
                radii.append((0.011 - 0.004 * t) * (0.72 if b % 2 == 1 and b < beads else 1.0))
            tube(shape, pts, radii, [LEG_U[3] + (LEG_U[4] - LEG_U[3]) * b / beads for b in range(beads + 1)], part, max(sides - 1, 4), hint, tip_start=False)


def load(shape):
    """A lump of meat with a splinter of bone, held in the jaws."""
    sides = 6 if LOW else 9
    centre = V(0.0, 0.17, 0.72)

    def warp(p):
        q = p - centre
        bump = 1.0 + 0.18 * math.sin(q.x * 70.0 + 1.0) * math.sin(q.z * 55.0) + 0.1 * math.sin(q.y * 90.0)
        return centre + q * bump

    stations = []
    for i in range(7):
        t = i / 6
        s = math.sin(math.pi * min(max(t, 0.02), 0.98)) ** 0.7
        stations.append((centre.z - 0.075 + 0.15 * t, centre.y - 0.01 * t, 0.085 * s, 0.06 * s))
    body_loft(shape, stations, LOAD, sides, warp=warp)
    tube(shape, [centre + V(0.02, 0.02, 0.0), centre + V(0.13, 0.05, 0.03)], [0.014, 0.011], [0.0, 0.0], LOAD, 5)


def ant(big):
    shape = Shape()
    warp, length = head(shape, big)
    feelers(shape, warp, length, big)
    jaws(shape, warp, length, big)
    thorax(shape)
    waist(shape)
    gaster(shape)
    legs(shape)
    return shape


def carried():
    shape = Shape()
    load(shape)
    return shape


# --- Putting it together ---

def material_of(label, colour):
    material = bpy.data.materials.new(label)
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = colour + (1.0,)
    bsdf.inputs["Roughness"].default_value = 0.6
    material.diffuse_color = colour + (1.0,)
    return material


def mesh_of(name, shape, materials):
    points = []
    found = {}
    faces = []
    uvs = []
    tones = []
    for corners, us, part in shape.faces:
        face = []
        for corner, u in zip(corners, us):
            key = (round(corner.x, 5), round(corner.y, 5), round(corner.z, 5), part)
            if key not in found:
                found[key] = len(points)
                points.append(to_blender(corner))
            face.append(found[key])
            # (glTF turns V over: Godot reads 1 - v)
            uvs.append((u, 1.0 - part))
        # (a face that has folded onto itself is left out)
        if len(set(face)) < len(face):
            uvs = uvs[:len(uvs) - len(face)]
            continue
        faces.append(face)
        tones.append(part)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name="parts")
    for k, uv in enumerate(uvs):
        layer.data[k].uv = uv
    labels = ["body", "limb", "eyes", "load"]
    for label in labels:
        mesh.materials.append(materials[label])
    for k, part in enumerate(tones):
        mesh.polygons[k].material_index = 0 if part in (BODY, GASTER) else (2 if part == EYES else (3 if part == LOAD else 1))
        mesh.polygons[k].use_smooth = True
    return mesh


def build():
    global LOW
    counts = {}
    for low in (False, True):
        LOW = low
        bpy.ops.wm.read_factory_settings(use_empty=True)
        materials = {"body": material_of("ant_body", TONES[BODY]), "limb": material_of("ant_limb", LIMB_TONE),
                     "eyes": material_of("ant_eyes", TONES[EYES]), "load": material_of("ant_load", TONES[LOAD])}
        for name, shape, x in (("worker", ant(1.0), 0.0), ("soldier", ant(1.7), 1.6), ("load", carried(), 0.0)):
            made = bpy.data.objects.new(name, mesh_of(name, shape, materials))
            bpy.context.collection.objects.link(made)
            made.location = to_blender(V(x, 0.0, 0.0))
            made.data.calc_loop_triangles()
            counts[name + ("_lo" if low else "")] = len(made.data.loop_triangles)
        os.makedirs(OUT, exist_ok=True)
        # (each object at the origin in the file: the game puts them where they go)
        for obj in bpy.data.objects:
            shown_at = obj.location.copy()
            obj.location = (0.0, 0.0, 0.0)
            obj["shown_at"] = list(shown_at)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "ants%s.glb" % ("_lo" if low else "")), export_format="GLB",
                                  export_yup=True, export_animations=False)
        if PREVIEW and not low:
            for obj in bpy.data.objects:
                obj.location = Vector(obj["shown_at"])
            render(PREVIEW)
    print("BUILT ants: " + ", ".join("%s %d" % (k, v) for k, v in counts.items()))


def render(folder):
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1000, 700
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.55, 0.57, 0.6)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (view, direction to the camera in Blender space, what it looks at, how much it frames)
    views = [("side", (1, 0, 0.05), (0.0, 0.0, 0.25), 1.5), ("top", (0.0, 0.0, 1), (0.8, 0.0, 0.0), 3.2),
             ("quarter", (0.8, -0.8, 0.45), (0.0, 0.0, 0.2), 1.6), ("front", (0.1, -1, 0.25), (0.0, -0.4, 0.3), 1.0),
             ("soldier", (0.8, -0.8, 0.45), (1.6, 0.0, 0.2), 1.7), ("head", (0.6, -0.8, 0.5), (0.0, -0.5, 0.28), 0.6)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 5.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "ants_%s.png" % view)
        bpy.ops.render.render(write_still=True)


build()
