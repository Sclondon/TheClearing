# Crows and ravens (Godot 4.7)

A flock of corvids: a murder of American crows, a pair of common ravens (and, with `godot/blue-jay`, a family of
blue jays): how they look and how they go about, and nothing about what they mean in a game. Made 2026-10-18 for The
Clearing, where crows are the maze's watchers (`scripts/enemies/crows.gd` there: they follow you along the wall tops
and erupt cawing at a runner, which calls the hunters), ravens are omens (`scripts/wildlife/ravens.gd`) and jays and
a few crows live in the clearing's pines (`scripts/wildlife/birds.gd`). No scenes and no textures:
`creatures/crow/corvid_flock.gd` (`class_name CorvidFlock`), `corvid_body.gd` (`CorvidBody`: the meshes and
material), `corvid.gdshader`, `corvid_voice.gd` (`CorvidVoice`), and the models `models/crow.glb`, `raven.glb` (and
`_lo` twins), built in Blender 4.3 by `tools/build_corvids.py` (which builds the blue jay too, into
`creatures/blue_jay/models/`):

```
blender --background --python creatures/crow/tools/build_corvids.py [-- <folder for pictures> [crow,raven,blue_jay]]
```

## The birds

One builder, one anatomy, three kinds (all three are corvids): a core of dark down from the rump to the forehead;
contour feathers over it in overlapping rows, each a small curved vane with a raised shaft, laid back along the body;
scapulars; small feathers flowing back over the head; nasal bristles lying forward over the base of the bill; twelve
tail feathers with their coverts; feathered tibiae, scaled black tarsi, three toes forward and the strong hind toe,
hooked nails; a deep bill with the culmen arched to the tip, the lower mandible (which opens) and the inside of the
mouth; eyes with a glint. Each wing is in three pieces by the bone that carries it (arm, forearm, hand): ten primaries
(the outer ones emarginated, so the spread tip parts into fingers), alula and primary coverts on the hand; ten
secondaries, rows of greater, median and lesser coverts on the forearm; tertials at the elbow; a core along the
leading edge. Each wing is modelled twice: folded on the flank and spread level.

- **Crow** (`Kind.CROW`): 0.45 m from bill to tail, about 0.9 m across the wings. Black with a blue-violet gloss (a rim
  of light and a sheen where light glances off), the flight feathers worn browner; rounded tail.
- **Raven** (`Kind.RAVEN`): a third bigger, the heavy bill, a steeper forehead, a shaggy throat of lanceolate hackles
  (`fluff` stands them out), a long wedge-shaped tail, more fingered wings.
- **Blue jay** (`Kind.BLUE_JAY`, the model in `godot/blue-jay`): see that component.

About 12500 triangles a bird (`low_poly` or far off, about 3800). Lit in flat cel bands; the body's feathers shade as
one form (their normals bent out from the body), so the light falls in one clean band.

## What they do

- **Sitting** (`set_perches(points, faces)`: where they may sit and the way a bird there faces; each takes one): mostly
  side on, looking about (the head snapped from pose to pose, cocked to look with one eye), preening, fluffing and
  shaking out, shuffling a step along, turning about; calling: a crow bows forward on each caw, tail flicked, bill wide
  (2 to 4 caws); a raven fluffs its throat and croaks, or knocks (the bill clapped). `grip` curls the toes (0.6 for
  branches, little for a flat ledge).
- **New perches** (`set_perches` again): they move over in short flights, one after another; with `gather` those left
  at the ends come in to the middle (crows leapfrogging along a wall after someone).
- **The ground** (`ground_share` above 0): that share come down to forage round `home` within `roam`: a crow walks
  with its swagger (the body rolling, the head thrust forward each step), sometimes hops; they peck and look about,
  and fly back up. `startle(from)` sends those on the ground (and any sitting within `near`) up to perches.
- **Flight**: a crouch and a spring with a downstroke; flapping (a crow rows steadily with a glide now and then, a raven
  flaps slow and deep and soars); banking into turns; landing with a flare (wings up and forward, tail fanned down,
  legs reaching), then the wings fold. The wingbeat, after slow-motion film of crows: on the downstroke the wing is
  straight and spread, swept a little forward, the leading edge down, the primaries fanned into fingers and bent up by
  the load; on the upstroke elbow and wrist flex so the wing folds half shut at the wrist and is drawn up and back,
  the hand trailing and the primaries closed edge on; at the top it flicks open. They fly curves (up off the perch,
  over, down onto the next), so they need no collisions: give them perches they can reach in the open.
- **Erupting** (`erupt(over, seconds)`): they all burst off one after another in a moment, calling hard, and wheel
  round `over` (`move_circle` moves it; they follow), then come down to the perches nearest. `circle_over(point,
  seconds)` the same without the alarm.
- **Watching** (`watch(point)`): every head turns to it; a body that would have to turn too far turns on its perch.
- `send_ahead(i, perch)` flies one bird to a perch; `call_now(i)` makes one call.

## Sounds and phones

- `CorvidVoice.new(flock)`, added as a child of the flock, plays the calls (signal `called(at, Call)`) and a clatter
  of wings on take-off (`took_off`), all made in code the first time one is made (no sound files): the crow's caw
  (nasal, harsh, falling) and its harsher alarm caw; the raven's deep gurgling croak and its hollow knocking; the
  jay's calls (see `godot/blue-jay`).
- `low_poly = true` (before it goes in) always draws the low-detail bird; otherwise it switches to it past
  `far_detail` metres from the camera. Out of `view_range`, with none in the air, a flock does no work and is not drawn.

## Putting it in a game

```gdscript
var crows := CorvidFlock.new()
crows.kind = CorvidBody.Kind.CROW
crows.count = 9
crows.flock_seed = 5
crows.home = Vector3(0, 0, 1.5)        # where some forage (with ground_share)
add_child(crows)
crows.set_perches(points, faces, false) # PackedVector3Arrays: where they sit, which way they face
crows.settle()
crows.add_child(CorvidVoice.new(crows))
# ... later
crows.erupt(over_here, 8.0)
```

`example.gd` is the smallest level: a murder on a wall (some on the ground), erupting and wheeling now and then, and
a raven on a post.

## What a game talks to

`set_perches(points, faces, move, gather)`, `settle()`, `erupt(over, seconds)`, `circle_over(point, seconds)`,
`move_circle(point)`, `watch(point)`, `scold(point)` (jays), `startle(from, near)`, `send_ahead(i, perch)`,
`call_now(i)`; `centre()`, `bird_position(i)`, `act_of(i)` (`Act`), `perch_of(i)`, `flying()`, `perched()`,
`circling()`; signals `called`, `took_off`, `landed`, `erupted`, `flapped`. Tuning: `count`, `size`, `restless`,
`ground_share`, `roam`, `flight_speed`, `walk_speed`, `circle_radius`, `circle_height`, `call_every`, `grip`,
`far_detail`, `view_range`. Optional `ground_height` and `keep_in` callables for uneven ground. For pictures,
`frozen = true` and `pose_bird(i, at, yaw, {fold, beat, strength, pitch, flare, tail_lift, tail_fan, bank, crest, grip,
reach, crouch, beak, fluff, head, turn, walk, step, hop, tuck})`.

## Limits

- No collisions: flights are curves between points, so perches must be reachable in the open (a wall top from a wall
  top is fine; through a roof is not).
- At most 16 birds a flock (the shader's arrays). One kind per flock.
- Blending from the spread wing to the folded one is a straight blend of positions, quick (a tenth of a second), so a
  wing does not fold through the motions of a real fold.
- Classes: `CorvidFlock`, `CorvidBody`, `CorvidVoice`.
