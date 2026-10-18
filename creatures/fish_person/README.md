# Fish person

A deep one, out of Innsmouth: a man gone over to the sea. Taller than a man and stooped, a hump of a back, wet
grey-green skin in scales (paler on the belly and throat, mottled darker on the back), a bulbous fish's head on a
neck that is hardly a neck: a low brow sloping back from the snout, round glassy eyes set wide on mounds at the
sides, two slits for a nose, a lipless downturned mouth right across the front with an underbite and needle teeth
in both jaws (a few lower fangs stand outside the upper lip), three gill slits down each side of the neck under
flaps that flare, a ragged fin from the crown of the head down the spine and along the back of each forearm, long
arms with webbed, long-fingered, clawed hands, and long flat feet with four webbed toes.

It lurks in black water up to its eyes, rises out of it, shambles, lopes bent double, croaks (a gurgling, rattling
croak that strains up into a screech) and lunges, grabbing with both hands. It is only the look, the motion and the
croak. It does no thinking: your game moves it and tells it when to act. Made for Warren, 2026-10-18 (its
`MazeFishPerson` is the thinking that drives it there).

## Needs

GameCommon's `godot/character-controller` (the rig, `FishPersonRig`, extends `CharacterRig`, and uses its `Toon`,
`Dust` and `Settings`). Global class names: `FishPerson`, `FishPersonRig`, `FishPool`.

## Use

```gdscript
var fish := FishPerson.new()
fish.scale = Vector3.ONE * 1.5          # modelled about 1.42 units tall
add_child(fish)
fish.put(spawn_point, spawn_yaw, true)  # true: down in the water

# every frame, from your own body (a CharacterBody3D, a path follower...):
fish.global_position = body_position
fish.rotation.y = facing_yaw            # 0 faces +Z
fish.velocity = body_velocity           # its feet step to this (fast, it lopes)
fish.awake = true                       # false: it squats, still
fish.winded = 0.0                       # 0..1: how hard it breathes (after a lope)
fish.aim = target + Vector3.UP          # looks at it, and reaches for it when near (INF: nothing)

fish.emerge()                           # up out of the water (RISE_TIME); `risen` when it is up
fish.submerge()                         # back down (SINK_TIME); `sank` when it is under
fish.croak()                            # `croaked` fires at the height of it: call the others then
fish.grab()                             # `closing` fires as the hands clamp; test grab_hits(point) while stage() is CLOSE
fish.held = true                        # it has them: it drags them to its mouth
```

- `doing()` (`FishPersonRig.Act.NONE`, `CROAK`, `GRAB`), `stage()` (`FishPersonRig.Stage`: SWELL, CROAKING,
  SUBSIDE, WIND, LUNGE, CLOSE, HOLD, LET_GO), `busy()`, `FishPerson.act_length(act)`, `moving_in_water()`, `sunk`
  (0 up, 1 down to its eyes).
- `grab_hits(point, radius := 0.25)`: whether a point is inside its clamping hands (in front of it, out to the end
  of its lunge, within its height). `mouth()` and `eyes()`: where they are, for line-of-sight tests.
- Exports: `low_poly` (or `Settings.low_poly`), `sound`, `volume_db`, `sound_range`. Also `reaching` (0..1, how far
  its arms come up for `aim`) and `grounded`.
- `pool`: give it a `FishPool` and it stirs the water as it rises, sinks, breathes down there and wades.

### FishPool

A pool of still black water lying on the ground with a ragged rim of wet mud, rings spreading over it from wherever
it is `stir`red, the sky showing dimly at a low angle. One draw. It hides nothing itself: anything let down into it
goes down into the ground, which hides it (so the ground must be drawn, opaque, under it).

```gdscript
var pool := FishPool.new()
pool.radius = 1.8
add_child(pool)
pool.global_position = on_the_ground
fish.pool = pool
```

## How it moves

Lurking it squats on its heels, knees wide, hands down between its feet, head up; `sunk` lets the whole of it down
into the ground until only its crown, eyes and fin are out. Rising, it comes up head first, slowly and then all at
once. About, it stands stooped and swaying, hands hanging loose before its knees; its head turns in sudden jerks and
holds, as a fish's eye does, or tracks `aim`. It shambles flat-footed: the webbed toes flop as each foot lifts and
the foot slaps down flat (a spatter of wet grit), a lurch forward onto each step, one leg dragging, the head
nodding. Driven fast it lopes: longer, lifted strides, bent right over, arms swinging low and clawing, mouth open
and gills pumping. It breathes all the time: a gulp of the mouth, then the gills flare as it shuts, slow at rest,
fast when `winded`. The croak: drawn up, mouth shut and gills clamped; then head thrust up and out, mouth at its
widest, gills flared and quivering, arms flung out low behind it, juddering with each pulse. The grab: hands drawn
back and mouth opening, then thrown forward with both arms straight and fingers spread, then clamped.

## Sound

`FishPerson.croak_sound()` makes the croak in code (nothing to load): a wet gulp and a gurgle of bubbles; a slow,
creaking voice down in a swollen throat (glottal pulses at a frog's pitch, every other one weak so that it rattles,
through the resonances of a wet "oo"), in pulses; straining up into a hoarse screech that breaks (the throat going to
"ee", hissing); dying back into a rattle and bubbles. 2.2 s.

## Model

`tools/build_fish_person.py` builds `models/fish_person.glb` and `fish_person_lo.glb` in Blender 4.3 on the boy's
bone names, plus `jaw` and `gill0`..`gill2` each side (so any rig for the boy can move it, and FishPersonRig moves
the rest):

    blender --background --python creatures/fish_person/tools/build_fish_person.py [-- <folder for preview renders>]

(Run from a game's root: it needs the character controller's `tools/build_character.py`.) The head is lofted from
slices, the cranium's floor and the jaw's top meeting flat on the mouth line so the jaw can drop away; the trunk,
neck and arms are one fused surface. It is all one skin material, its regions told apart by the vertex colour (r how
far a point lies in a hollow, g how pale, b what it is: scaled skin, smooth skin, fin and web, tooth or claw), and
its rest position rides along as its texture coordinates (UV x, z; UV2 x: y) so that `FishPersonRig`'s shader lays
scales over it that stay put as it moves (scales in rows like roof tiles, triplanar, fading out where they would be
too small to see), with mottling, a hard wet gleam broken up by the scales and a sheen along its edges. Its eyes,
the dark of its mouth and gills, its teeth and claws are coloured by the same shader from the vertex colour, so it
is one material and one surface; about 58k triangles (`fish_person_lo`: 10k). In Warren one in sight costs
about 4 draw calls, shadows and the spatter of its feet included, and its pool one more.

## Try it

`example.gd` on a Node3D: one on a flat floor going round a loop (under the water, rise, croak, shamble at a post,
lope, lunge and grab it, shamble back, sink).
