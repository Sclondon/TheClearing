"""Builds the men's parts the flesh mounds grow out of (with the character
controller's boy, who is not made here), and
exports them for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/flesh_mound/tools/build_parts.py [-- <preview folder>]

Writes creatures/flesh_mound/models/parts.glb and parts_lo.glb, each holding
seven parts, every one its own armature and skinned mesh:

- arm_r, arm_l: a man's arm from the shoulder (and a stub past it, to sink
  into flesh) to the fingertips: biceps, a bony elbow, a forearm that flattens
  to the wrist, the knob of the ulna, a palm with the ball of the thumb, four
  fingers each in three joints with swollen knuckles and nails, a thumb.
- long_r, long_l: the same, stretched gaunt: an upper arm and forearm twice as
  long and thin, bigger bony knuckles, longer fingers (the mound's grabbers).
- leg_r, leg_l: from the hip (and a stub) to the toes: a thigh, a kneecap, a
  calf, the knobs of the ankle, a heel, a foot with an arch and the ball of the
  foot, five toes (the big one the biggest) with nails.
- torso: a wasted body from the hips to the crown: a pelvis, a sunken belly,
  ribs showing, a ridge of vertebrae and the shoulder blades on its back,
  collarbones, shoulders, a neck, and a head with a face but no mouth (a brow,
  a nose, cheekbones, a chin, dark sockets with the eyes shut, ears).

Each part is made of simple shapes (lofted tubes with oval sections, and
ovals) fused into one skin by a voxel remesh and brought down to a budget of
triangles; the fingers, toes and nails are added after it as they are (a
remesh would fill the gaps between them). Arms and legs are made fatter than
a living man's (`girth`: bloated, and so they read from far off). Fewer
in parts_lo. Everything is in Godot's axes and metres here
(Y up), turned to Blender's only as it is made:

- arms lie along +Y from the shoulder at the origin, the palm facing +Z, the
  thumb on +X for the right arm (-X for the left);
- legs lie along +Y from the hip at the origin, the kneecap and toes to +Z,
  the sole facing +Y (the big toe on +X for the right);
- the torso stands on +Y from its pelvis at the origin, facing +Z.

Bones (each part's own): arms upper, fore, hand, thumb_1..3, index_1..3,
middle_1..3, ring_1..3, pinky_1..3; legs thigh, shin, foot, toes; the torso
pelvis, chest, head. Each vertex is weighted to its nearest bone and blended
with that bone's parent or child near a joint, never with a bone further off
(so fingers do not pull each other).

Vertex colours (the shader's masks): R a nail, G how bruised it is (finger and
toe ends, knuckles, knees, elbows, heels: livid purple in Godot), B a dark
hollow (the eye sockets, between the toes).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None


def to_b(v):
    """Godot (Y up) to Blender (Z up)."""
    return Vector((v.x, -v.z, v.y))


LOW = [False]


def V(x, y, z):
    return Vector((x, y, z))


class Part:
    """A part being made: shapes into one bmesh, bones, and features for the masks."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        # Shapes fused by the remesh (bm), and shapes added after it as they are (loose:
        # fingers, toes and nails, whose gaps a remesh would fill).
        self.loose = bmesh.new()
        self.target = self.bm
        self.low = LOW[0]
        # How much fatter than a living man its round parts are made (bloated).
        self.girth = 1.0
        # name -> (head, tail, parent, radius)
        self.bones = {}
        self.order = []
        # masks: (centre, radius, channel, strength)
        self.spots = []

    def bone(self, name, head, tail, parent, radius):
        self.bones[name] = (head.copy(), tail.copy(), parent, radius)
        self.order.append(name)

    def spot(self, at, radius, channel, strength=1.0):
        self.spots.append((at.copy(), radius, channel, strength))

    def oval(self, at, ax, ay, az, segments=14, rings=10):
        """An oval at `at`, its half-axes the vectors ax, ay, az."""
        ax, az = ax * self.girth, az * self.girth
        verts = []
        for i in range(rings + 1):
            v = math.pi * i / rings
            row = []
            for j in range(segments):
                u = 2.0 * math.pi * j / segments
                p = at + ax * (math.sin(v) * math.cos(u)) + ay * math.cos(v) + az * (math.sin(v) * math.sin(u))
                row.append(self.target.verts.new(to_b(p)))
            verts.append(row)
        for i in range(rings):
            for j in range(segments):
                a, b = verts[i][j], verts[i][(j + 1) % segments]
                c, d = verts[i + 1][(j + 1) % segments], verts[i + 1][j]
                if i == 0:
                    if a != d:
                        self._face([a, c, d])
                elif i == rings - 1:
                    self._face([a, b, d])
                else:
                    self._face([a, b, c, d])

    def ball(self, at, r, squash=Vector((1, 1, 1))):
        self.oval(at, V(r * squash.x, 0, 0), V(0, r * squash.y, 0), V(0, 0, r * squash.z))

    def _face(self, verts):
        try:
            self.target.faces.new(verts)
        except ValueError:
            pass

    def loft(self, rings, front=V(0, 0, 1), sides=14, caps=True):
        """A tube through `rings`, each (centre, rx, rz): rx across (side), rz
        towards `front`, which is kept square to the tube as it bends."""
        loops = []
        count = len(rings)
        for i, (c, rx, rz) in enumerate(rings):
            ahead = rings[min(i + 1, count - 1)][0] - rings[max(i - 1, 0)][0]
            t = ahead.normalized()
            f = (front - t * front.dot(t))
            if f.length < 1e-4:
                f = t.orthogonal()
            f.normalize()
            s = t.cross(f).normalized()
            rx, rz = rx * self.girth, rz * self.girth
            loop = []
            for k in range(sides):
                a = 2.0 * math.pi * k / sides
                p = c + s * (math.cos(a) * rx) + f * (math.sin(a) * rz)
                loop.append(self.target.verts.new(to_b(p)))
            loops.append((loop, t))
        for i in range(count - 1):
            a, b = loops[i][0], loops[i + 1][0]
            for k in range(sides):
                self._face([a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]])
        if caps:
            for end, sign in ((0, -1.0), (count - 1, 1.0)):
                loop, t = loops[end]
                c, rx, rz = rings[end]
                tip = self.target.verts.new(to_b(c + t * sign * min(rx, rz) * 0.6))
                for k in range(sides):
                    self._face([loop[k], loop[(k + 1) % sides], tip])

    def chain(self, points, radii, front=V(0, 0, 1), flat=1.0, sides=12):
        """A loft along points with round-ish sections (rz = r * flat)."""
        self.loft([(p, r, r * flat) for p, r in zip(points, radii)], front, sides)

    # --- making it ---

    def finish(self, voxel, budget):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(mesh)
        self.bm.free()
        body = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(body)
        bpy.context.view_layer.objects.active = body
        for o in bpy.context.selected_objects:
            o.select_set(False)
        body.select_set(True)
        remesh = body.modifiers.new("Remesh", "REMESH")
        remesh.mode = "VOXEL"
        remesh.voxel_size = voxel
        remesh.adaptivity = 0.0
        bpy.ops.object.modifier_apply(modifier=remesh.name)
        smooth = body.modifiers.new("Smooth", "SMOOTH")
        smooth.factor = 0.5
        smooth.iterations = 2
        bpy.ops.object.modifier_apply(modifier=smooth.name)
        faces = len(body.data.polygons) * 2
        if faces > budget:
            decimate = body.modifiers.new("Decimate", "DECIMATE")
            decimate.ratio = budget / faces
            bpy.ops.object.modifier_apply(modifier=decimate.name)
        if len(self.loose.verts) > 0:
            bmesh.ops.recalc_face_normals(self.loose, faces=self.loose.faces[:])
            extra = bpy.data.meshes.new(self.name + "_loose")
            self.loose.to_mesh(extra)
            joined = bmesh.new()
            joined.from_mesh(body.data)
            joined.from_mesh(extra)
            joined.to_mesh(body.data)
            joined.free()
        self.loose.free()
        tri = body.modifiers.new("Tri", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=tri.name)
        for poly in body.data.polygons:
            poly.use_smooth = True
        self._weights(body)
        self._masks(body)
        data = bpy.data.armatures.new(self.name + "_rig")
        rig = bpy.data.objects.new(self.name + "_rig", data)
        bpy.context.collection.objects.link(rig)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        made = {}
        for name in self.order:
            head, tail, parent, _r = self.bones[name]
            eb = data.edit_bones.new(name)
            eb.head = to_b(head)
            eb.tail = to_b(tail)
            if parent:
                eb.parent = made[parent]
                eb.use_connect = False
            made[name] = eb
        bpy.ops.object.mode_set(mode="OBJECT")
        body.parent = rig
        body.modifiers.new("Armature", "ARMATURE").object = rig
        print("BUILT %s verts=%d tris=%d" % (self.name, len(body.data.vertices), len(body.data.polygons)))
        return body, rig

    def _weights(self, body):
        groups = {name: body.vertex_groups.new(name=name) for name in self.order}
        children = {name: [] for name in self.order}
        for name in self.order:
            parent = self.bones[name][2]
            if parent:
                children[parent].append(name)
        segs = {name: (to_b(h), to_b(t), r) for name, (h, t, _p, r) in self.bones.items()}

        def far(p, name):
            a, b, r = segs[name]
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
            return (p - (a + ab * t)).length / r

        for v in body.data.vertices:
            p = v.co
            best = min(self.order, key=lambda n: far(p, n))
            near = [best] + children[best] + ([self.bones[best][2]] if self.bones[best][2] else [])
            scores = [(n, far(p, n)) for n in near]
            raw = [(n, 1.0 / max(e, 0.05) ** 6) for n, e in scores]
            total = sum(w for _n, w in raw)
            kept = [(n, w / total) for n, w in raw if w / total > 0.04]
            kept.sort(key=lambda x: -x[1])
            kept = kept[:3]
            total = sum(w for _n, w in kept)
            for n, w in kept:
                groups[n].add([v.index], w / total, "REPLACE")

    def _masks(self, body):
        mesh = body.data
        colours = mesh.color_attributes.new("Col", "BYTE_COLOR", "POINT")
        spots = [(to_b(at), r, ch, s) for at, r, ch, s in self.spots]
        for v in mesh.vertices:
            c = [0.0, 0.0, 0.0]
            for at, r, ch, s in spots:
                d = (v.co - at).length / r
                if d < 1.0:
                    k = 1.0 - d
                    c[ch] = max(c[ch], min(1.0, s * (k * k * (3.0 - 2.0 * k)) * 1.6))
            colours.data[v.index].color = (c[0], c[1], c[2], 1.0)
        mesh.color_attributes.active_color = colours
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")


# --- An arm ---

def arm(name, side, long=False):
    p = Part(name)
    p.girth = 1.3
    U = 0.60 if long else 0.30
    F = 0.52 if long else 0.26
    thin = 0.78 if long else 1.0
    W = U + F
    # Upper arm: the deltoid's end, the biceps in front, narrowing to the elbow.
    p.loft([(V(0, -0.14 if not long else -0.5, 0), 0.05 * thin, 0.05 * thin),
            (V(0, 0.0, 0), 0.057 * thin, 0.056 * thin),
            (V(0, U * 0.3, 0.004), 0.05 * thin, 0.053 * thin),
            (V(0, U * 0.62, 0.006), 0.045 * thin, 0.048 * thin),
            (V(0, U * 0.92, 0.0), 0.04 * thin, 0.037 * thin),
            (V(0, U + 0.01, -0.004), 0.041 * thin, 0.036 * thin)])
    # The elbow: the point of the ulna behind, and its knobs either side.
    p.ball(V(0, U, -0.03 * thin), 0.017 * (1.25 if long else 1.0))
    p.ball(V(side * 0.03 * thin, U - 0.005, -0.006), 0.012)
    p.ball(V(-side * 0.032 * thin, U - 0.005, -0.008), 0.014)
    p.spot(V(0, U, -0.04 * thin), 0.05, 1, 0.7)
    # Forearm: full near the elbow, flattening to the wrist.
    p.loft([(V(0, U - 0.03, -0.004), 0.038 * thin, 0.034 * thin),
            (V(0, U + F * 0.2, 0.004), 0.044 * thin, 0.036 * thin),
            (V(0, U + F * 0.5, 0.002), 0.037 * thin, 0.029 * thin),
            (V(0, U + F * 0.85, 0.0), 0.031, 0.02),
            (V(0, W, 0.0), 0.029, 0.018)])
    # The knob of the ulna, on the little finger's side, at the back.
    p.ball(V(-side * 0.026, W - 0.012, -0.008), 0.009)
    p.bone("upper", V(0, 0, 0), V(0, U, 0), None, 0.05 * thin)
    p.bone("fore", V(0, U, 0), V(0, W, 0), "upper", 0.04 * thin)
    # The palm: wider and flatter to the knuckles; the balls of the thumb and the little finger.
    p.girth = 1.12
    P = 0.095 * (1.08 if long else 1.0)
    p.loft([(V(0, W - 0.01, 0), 0.03, 0.018), (V(side * 0.002, W + P * 0.35, 0.001), 0.038, 0.016),
            (V(side * 0.0, W + P * 0.75, 0.0), 0.043, 0.0135), (V(0, W + P - 0.004, -0.001), 0.041, 0.0115),
            (V(0, W + P + 0.003, -0.001), 0.034, 0.008)])
    p.oval(V(side * 0.021, W + 0.03, 0.009), V(0.017, 0, 0), V(0, 0.027, 0), V(0, 0, 0.012))
    p.oval(V(-side * 0.026, W + 0.05, 0.006), V(0.012, 0, 0), V(0, 0.03, 0), V(0, 0, 0.0095))
    p.bone("hand", V(0, W, 0), V(0, W + P, 0), "fore", 0.03)
    # Fingers: x of the knuckle, how far up, lengths of the three bones, radius, splay.
    fingers = [("index", side * 0.0335, 0.0, (0.044, 0.026, 0.021), 0.0087, side * 0.13),
               ("middle", side * 0.0115, 0.004, (0.048, 0.03, 0.023), 0.009, side * 0.035),
               ("ring", -side * 0.0105, 0.0, (0.045, 0.028, 0.022), 0.0083, -side * 0.08),
               ("pinky", -side * 0.0315, -0.009, (0.035, 0.021, 0.019), 0.0072, -side * 0.2)]
    stretch = 1.22 if long else 1.0
    for fname, x, up, lengths, r, splay in fingers:
        base = V(x, W + P + up - 0.006, -0.001)
        d = V(-math.sin(splay), math.cos(splay), 0.0)
        _digit(p, fname, base, d, [l * stretch for l in lengths], r * (0.92 if long else 1.0), V(0, 0, -1), "hand", knobby=1.35 if long else 1.0)
        # The knuckle on the back of the hand.
        p.ball(base + V(0, -0.004, -0.006), r * (1.0 if long else 0.85))
        p.spot(base + V(0, 0, -0.012), 0.016, 1, 0.45)
    # The thumb: from the wrist's side, out and forward over the palm.
    tb = V(side * 0.024, W + 0.012, 0.006)
    td = V(side * 0.62, 0.72, 0.31).normalized()
    nail = (V(side * 1.0, 0, -0.5) - td * V(side * 1.0, 0, -0.5).dot(td)).normalized()
    _digit(p, "thumb", tb, td, [0.046, 0.033 * stretch, 0.028 * stretch], 0.0125, nail, "hand", first_thick=1.25, knobby=1.3 if long else 1.0)
    return p


def _digit(p, name, base, d, lengths, r, nail_side, parent, first_thick=1.0, knobby=1.0):
    """A finger (or thumb, or toe): three bones from `base` along `d`, the nail on `nail_side`."""
    joints = [base]
    for l in lengths:
        joints.append(joints[-1] + d * l)
    # (the joints a little swollen, the bones between a little narrower; the tip rounded)
    rings = []
    profile = [(0.0, 1.0 * first_thick), (0.5, 0.95 * first_thick), (1.0, 1.0 * knobby), (1.5, 0.87), (2.0, 0.93 * knobby),
               (2.45, 0.86), (2.8, 0.74), (2.95, 0.5)]
    for t, k in profile:
        i = min(int(t), 2)
        f = t - i
        c = joints[i].lerp(joints[i + 1], f)
        rr = r * k * (1.0 - 0.12 * (t / 3.0))
        rings.append((c, rr, rr * 0.86))
    p.target = p.loose
    p.loft(rings, front=-nail_side, sides=6 if p.low else 10)
    names = ["%s_%d" % (name, i + 1) for i in range(3)]
    for i in range(3):
        p.bone(names[i], joints[i], joints[i + 1], parent if i == 0 else names[i - 1], r)
    # The nail: a thin flat oval on the last bone.
    tip = joints[3]
    at = tip - d * lengths[2] * 0.4 + nail_side * r * 0.62
    side = d.cross(nail_side).normalized()
    if not p.low:
        p.oval(at, side * r * 0.7, d * lengths[2] * 0.36, nail_side * r * 0.2, 8, 4)
    p.target = p.bm
    p.spot(at + nail_side * r * 0.2, r * 1.0, 0, 1.0)
    # The end of it bruised dark.
    p.spot(tip, lengths[2] * 1.6, 1, 0.8)


# --- A leg ---

def leg(name, side):
    p = Part(name)
    p.girth = 1.22
    H, S = 0.44, 0.42
    A = H + S
    p.loft([(V(0, -0.16, 0), 0.075, 0.075), (V(0, 0.0, 0.0), 0.085, 0.08), (V(0, 0.12, 0.008), 0.078, 0.078),
            (V(0, 0.28, 0.006), 0.064, 0.064), (V(0, H - 0.04, 0.0), 0.05, 0.048), (V(0, H + 0.01, 0.0), 0.047, 0.045)])
    # The kneecap, and the knee bruised.
    p.oval(V(0, H - 0.005, 0.036), V(0.025, 0, 0), V(0, 0.03, 0), V(0, 0, 0.016))
    p.spot(V(0, H, 0.05), 0.06, 1, 0.6)
    # The shin: the calf full behind, thin to the ankle.
    p.loft([(V(0, H, 0.0), 0.048, 0.046), (V(0, H + 0.1, -0.012), 0.05, 0.054), (V(0, H + 0.2, -0.008), 0.043, 0.044),
            (V(0, H + 0.32, -0.002), 0.033, 0.031), (V(0, A - 0.02, 0.0), 0.029, 0.029)])
    # The knobs of the ankle.
    p.ball(V(side * 0.027, A - 0.008, -0.004), 0.013)
    p.ball(V(-side * 0.024, A + 0.004, -0.01), 0.012)
    p.bone("thigh", V(0, 0, 0), V(0, H, 0), None, 0.07)
    p.bone("shin", V(0, H, 0), V(0, A, 0), "thigh", 0.045)
    # The heel, and the foot to the ball, its top sloping down to the toes (the sole is +Y).
    p.girth = 1.08
    p.oval(V(0, A + 0.045, -0.032), V(0.031, 0, 0), V(0, 0.034, 0), V(0, 0, 0.04))
    p.spot(V(0, A + 0.075, -0.05), 0.05, 1, 0.5)
    sole = A + 0.075
    p.loft([(V(0, A + 0.03, -0.015), 0.03, 0.04), (V(side * 0.003, A + 0.042, 0.045), 0.036, 0.03),
            (V(side * 0.006, sole - 0.024, 0.1), 0.043, 0.025), (V(side * 0.006, sole - 0.02, 0.145), 0.046, 0.019)],
           front=V(0, -1, 0))
    p.bone("foot", V(0, A, 0), V(0, sole - 0.02, 0.145), "shin", 0.035)
    # Toes: x, length, radius; along +Z, curling a little down to the ground.
    toes = [(side * 0.029, 0.05, 0.0135), (side * 0.006, 0.038, 0.0092), (-side * 0.012, 0.034, 0.0087),
            (-side * 0.0275, 0.03, 0.0082), (-side * 0.041, 0.025, 0.0077)]
    for i, (x, l, r) in enumerate(toes):
        base = V(x, sole - 0.016, 0.15 - abs(x) * 0.45 - (0.0 if i == 0 else 0.005 * i))
        d = V(0, 0.18, 1).normalized()
        tip = base + d * l
        rings = [(base - d * 0.01, r * 1.1, r), (base.lerp(tip, 0.35), r * 0.95, r * 0.85), (base.lerp(tip, 0.6), r * 1.0, r * 0.9), (base.lerp(tip, 0.85), r * 0.95, r * 0.82),
                 (tip, r * 0.6, r * 0.5)]
        p.target = p.loose
        p.loft(rings, front=V(0, -1, 0), sides=6 if p.low else 9)
        nail = base.lerp(tip, 0.72) + V(0, -r * 0.6, 0)
        if not p.low:
            p.oval(nail, V(r * 0.7, 0, 0), V(0, r * 0.18, 0), V(0, 0, l * 0.28), 8, 4)
        p.target = p.bm
        p.spot(nail + V(0, -r * 0.2, 0), r * 0.95, 0, 1.0)
        p.spot(tip, l * 0.9, 1, 0.7)
        if i > 0:
            p.spot(base + V(side * 0.01, 0, l * 0.3), 0.008, 2, 0.6)
    p.bone("toes", V(0, sole - 0.02, 0.145), V(0, sole - 0.015, 0.185), "foot", 0.02)
    return p


# --- A body ---

# The trunk's sections up it: (height, half width, half depth, how far forward its middle is).
TRUNK = [(-0.06, 0.12, 0.08, -0.01), (0.0, 0.15, 0.095, 0.0), (0.08, 0.145, 0.09, 0.005), (0.17, 0.118, 0.072, 0.0),
         (0.25, 0.128, 0.082, -0.004), (0.33, 0.142, 0.094, -0.004), (0.42, 0.148, 0.097, -0.006),
         (0.49, 0.15, 0.088, -0.01), (0.54, 0.138, 0.072, -0.014), (0.575, 0.09, 0.055, -0.012), (0.6, 0.05, 0.045, -0.01)]


def _trunk_at(y):
    """The trunk's section at a height: (half width, half depth, middle z)."""
    for (y0, w0, d0, z0), (y1, w1, d1, z1) in zip(TRUNK, TRUNK[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return w0 + (w1 - w0) * t, d0 + (d1 - d0) * t, z0 + (z1 - z0) * t
    return TRUNK[-1][1], TRUNK[-1][2], TRUNK[-1][3]


def torso(name):
    p = Part(name)
    # The trunk, wasted: wide hips, a waist sunk in under the ribs, a deep chest.
    p.loft([(V(0, y, z), w, d) for y, w, d, z in TRUNK], sides=20)
    # Ribs pressing out round its sides under the skin, sloping down to the front.
    for i in range(7):
        y = 0.27 + i * 0.034
        for side in (1.0, -1.0):
            pts, rad = [], []
            for k in range(10):
                a = -math.pi * 0.42 + (k / 9.0) * math.pi * 0.8
                yy = y - 0.055 * (k / 9.0)
                w, d, z = _trunk_at(yy)
                # (just under the surface: they show as ridges)
                pts.append(V(side * math.cos(a) * (w - 0.004), yy, z + math.sin(a) * (d - 0.004)))
                rad.append(0.0075 * (1.0 - 0.3 * k / 9.0))
            p.chain(pts, rad, front=V(side, 0, 0), sides=8)
    # The spine down its back, and the shoulder blades.
    for i in range(16):
        y = 0.0 + i * 0.035
        w, d, z = _trunk_at(y)
        p.ball(V(0, y, z - d + 0.004), 0.011)
    for side in (1.0, -1.0):
        w, d, z = _trunk_at(0.44)
        p.oval(V(side * 0.075, 0.44, z - d + 0.006), V(0.046, 0.0, 0.01 * side), V(0.01 * side, 0.058, 0.0), V(0, 0, 0.01))
        # Shallow pectorals, the collarbones, the shoulders' caps.
        p.oval(V(side * 0.065, 0.445, z + d - 0.016), V(0.06, 0, 0), V(0, 0.04, 0), V(0, 0, 0.014))
        p.chain([V(side * 0.018, 0.545, 0.05), V(side * 0.09, 0.553, 0.04), V(side * 0.16, 0.548, 0.0)], [0.009, 0.0085, 0.01], sides=8)
        p.oval(V(side * 0.155, 0.5, -0.005), V(0.042, 0, 0), V(0, 0.05, 0), V(0, 0, 0.044))
        # The points of the hips.
        p.ball(V(side * 0.115, 0.075, 0.05), 0.016)
    # Neck, leaning forward a little; the head on it.
    p.chain([V(0, 0.54, -0.01), V(0, 0.6, 0.0), V(0, 0.66, 0.01)], [0.05, 0.044, 0.042], sides=12)
    h = V(0, 0.75, 0.0)
    p.oval(h + V(0, 0.005, -0.012), V(0.072, 0, 0), V(0, 0.09, 0), V(0, 0, 0.092))
    # The face, no mouth: a jaw and chin, a low brow, a nose, cheekbones, shut eyes, ears.
    p.oval(h + V(0, -0.058, 0.028), V(0.054, 0, 0), V(0, 0.05, 0), V(0, 0, 0.055))
    p.ball(h + V(0, -0.093, 0.06), 0.017)
    p.oval(h + V(0, 0.026, 0.06), V(0.05, 0, 0), V(0, 0.011, 0), V(0, 0, 0.014))
    p.oval(h + V(0, -0.018, 0.077), V(0.0095, 0, 0), V(0, 0.024, -0.006), V(0, 0.004, 0.014))
    p.oval(h + V(0, -0.036, 0.083), V(0.014, 0, 0), V(0, 0.008, 0), V(0, 0, 0.01))
    for side in (1.0, -1.0):
        p.ball(h + V(side * 0.04, -0.024, 0.05), 0.014)
        p.oval(h + V(side * 0.073, -0.005, -0.008), V(0.01, 0, 0), V(0, 0.028, 0), V(0, 0, 0.018))
        # Sockets, eyes shut and sunk: dark, the lids just proud.
        p.spot(h + V(side * 0.029, 0.004, 0.08), 0.022, 2, 0.9)
    p.spot(h + V(0, -0.055, 0.085), 0.03, 1, 0.35)
    p.bone("pelvis", V(0, -0.05, 0), V(0, 0.2, 0), None, 0.13)
    p.bone("chest", V(0, 0.2, 0), V(0, 0.55, 0), "pelvis", 0.13)
    p.bone("head", V(0, 0.58, 0.01), V(0, 0.84, 0.0), "chest", 0.06)
    return p



def build(low, folder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    LOW[0] = low
    budget = {"arm": 2000, "long": 2200, "leg": 1500, "torso": 3600} if not low else {"arm": 450, "long": 500, "leg": 420, "torso": 1500}
    made = []
    for name, side in (("arm_r", 1.0), ("arm_l", -1.0)):
        made.append(arm(name, side).finish(0.002, budget["arm"]))
    for name, side in (("long_r", 1.0), ("long_l", -1.0)):
        made.append(arm(name, side, True).finish(0.002, budget["long"]))
    for name, side in (("leg_r", 1.0), ("leg_l", -1.0)):
        made.append(leg(name, side).finish(0.0025, budget["leg"]))
    made.append(torso("torso").finish(0.0025, budget["torso"]))
    os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
    path = os.path.join(FOLDER, "models", "parts%s.glb" % ("_lo" if low else ""))
    options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=True,
                   export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    print("EXPORTED", path)
    if folder and not low:
        previews(made, folder)


def previews(made, folder):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = os.environ.get("PART_COLOUR", "SINGLE")
    scene.display.shading.single_color = (0.62, 0.58, 0.56)
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 700, 700
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 60
    scene.collection.objects.link(camera)
    scene.camera = camera
    views = {
        "arm_r": [("hand_palm", V(0, 0.68, 0), V(0.0, 0.1, 1.0), 0.3), ("hand_back", V(0, 0.68, 0), V(0.2, 0.1, -1.0), 0.3), ("hand_side", V(0, 0.66, 0), V(1.0, 0.1, 0.3), 0.36),
                  ("whole", V(0, 0.35, 0), V(1.0, 0.0, 0.6), 1.2)],
        "long_r": [("whole", V(0, 0.65, 0), V(1.0, 0.0, 0.6), 1.9), ("hand", V(0, 1.2, 0), V(0.4, 0.1, 1.0), 0.4)],
        "leg_r": [("foot", V(0, 0.92, 0.05), V(0.9, -0.3, 0.6), 0.45), ("whole", V(0, 0.45, 0), V(1.0, 0.0, 0.4), 1.4)],
        "torso": [("front", V(0, 0.4, 0), V(0.0, 0.1, 1.0), 1.3), ("back", V(0, 0.4, 0), V(0.4, 0.2, -1.0), 1.3),
                  ("face", V(0, 0.76, 0.02), V(0.5, 0.1, 1.0), 0.45)],
    }
    for body, rig in made:
        for o in bpy.data.objects:
            if o.type == "MESH":
                o.hide_render = o != body
        for view, at, direction, far in views.get(body.name, []):
            offset = to_b(direction.normalized()) * far
            target = to_b(at)
            camera.location = target + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(folder, "%s_%s.png" % (body.name, view))
            bpy.ops.render.render(write_still=True)
        # Bent, to see that the weights hold: fingers curled, elbow and knee bent.
        if body.name in ("arm_r", "leg_r", "long_r"):
            for bone in rig.pose.bones:
                bone.rotation_mode = "XYZ"
                if bone.name.split("_")[0] in ("index", "middle", "ring", "pinky"):
                    bone.rotation_euler = (1.1, 0, 0)
                elif bone.name in ("fore", "shin"):
                    bone.rotation_euler = (1.2 if bone.name == "fore" else -1.3, 0, 0)
                elif bone.name == "foot":
                    bone.rotation_euler = (0.5, 0, 0)
            bpy.context.view_layer.update()
            for view, at, direction, far in views.get(body.name, []):
                offset = to_b(direction.normalized()) * far
                camera.location = to_b(at) + offset
                camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
                scene.render.filepath = os.path.join(folder, "%s_%s_bent.png" % (body.name, view))
                bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build(False, PREVIEW_DIR)
    build(True, None)
