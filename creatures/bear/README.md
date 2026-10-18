# Screaming bear

A huge bear that something has got into and changed, in the spirit of the mutated bear of the film *Annihilation*
(its own design, not the film's). Starved to the bone and wrong: legs far too long for it, so that it stands high and
gaunt; a deep, narrow ribcage with the ribs standing out, the belly pinched up to nothing, hip bones and the knobs
of the spine poking through, a bony hump; a long thin neck carrying the head low. Half its face is skull: on its
right the skin has gone from the muzzle and the cheek and round the eye, and the bone shows, the eye in it clouded
white; it has no lips, so its teeth show all along both jaws in dark wet gums. Patchy fur sloughing away to pale,
blotched, veined skin, raw at the edges; bare ribs on its right flank; loose flaps of skin; long claws; bloody
slaver; steaming breath. Toon-shaded (hard light bands). The model stands a metre at the shoulder; scaled 2.4 it
stands far over a man and rears to twice his height. Everything it does is animated in code on its own skeleton:
no clips. Made for Warren. The component has no thinking.

Its horror is its voice: it cries out with the voice of the last thing it killed ("help!", "help... me",
"no, no, no!", a scream, sobbing), always the same cries the same way, as a recording would be. The voices are
made in code (formant synthesis: a glottal pulse through the resonances of a mouth), nobody's real voice.

## Using it

```gdscript
var bear := Bear.new()
bear.scale = Vector3.ONE * 2.4
add_child(bear)
# each frame: move it (position, rotation.y; it faces +Z) and it prowls, trots or gallops to match (and skids, slowing hard)
bear.sniffing = true          # head up, nose working
bear.lowered = true           # gathered to spring: the wind-up of a charge, and the charge
bear.rearing = true           # up on its hind legs
bear.mauling = true           # head down over something in front of it, tearing
bear.look_at_point = target   # INF for nothing
bear.voice = 2                # whose voice (BearVoice: 0..5 people, 6 an animal's shriek)
bear.call_out()               # one of its stolen calls (or call_out(BearVoice.SOB), ...)
bear.scream()                 # its scream, jaws agape
bear.swipe(1.0)               # a foreleg raked across (`swiped` as the claws come through)
if bear.claws_reach(their_chest): ...
bear.huff(); bear.pop_jaw(); bear.sniff(); bear.growl()
```

- **Gaits**: a slow, heavy four-beat prowl (the head low and swinging, the shoulder blades rolling), a trot, and a
  rotary gallop for the charge (after the boar's rig). Speed is measured from how it is moved, or set `velocity`
  with `measure_velocity = false`. Now and then a twitch of the head or a shoulder, too quick for an animal.
- **Signals**: `called(which)`, `screamed`, `swiped`, `huffed`, `footfall(at, weight)`.
- **Its voice** (`BearVoice`): `CALL_HELP`, `CALL_HELP_ME`, `CALL_NO`, `SCREAM`, `SOB`, in seven voices (a man, a
  woman, a boy, an old man, another woman, a young man, an animal). Each is made once and kept. Setting `voice`
  (and adding a Bear) puts that voice's cries in hand to be made a little at a time (about 1.5 ms a frame,
  `BearVoice.work`), so making them never holds a frame up; `call_out(which, true)` calls only once the cry is
  ready. `BearVoice.cry(which, voice)` makes one at once. Its voice carries far (`voice_range`, 140 m); its other
  sounds (huff, jaw pop, sniff, growl, footfalls, the rake of its claws) less (`sound_range`). Run tests with
  `--audio-driver Dummy`.
- **Exports**: `low_poly` (the demade model, no fur shells), `fur_shells`, `coat_tint`, `bare` (how much fur has
  sloughed), `eyeshine`, `measure_velocity`, `voice`, `sound`, `volume_db`, `voice_range`, `sound_range`, `steam`.
- **Cost**: 4 draws with 2 shells (2 surfaces: coat, parts), plus its puffs of breath; 2 with `low_poly`. The model
  is about 52k triangles, or 4k low.

## Files

- `bear.gd` (`Bear`): what a game drives; its sounds and breath.
- `bear_voice.gd` (`BearVoice`): its stolen voice, made in code.
- `bear_rig.gd` (`BearRig`): poses the skeleton every frame.
- `bear_look.gd` (`BearLook`): two shaders. A ragged coat in lank clumps with shells that tatter its outline, and
  where the vertex colours say, bare skin (blotched, veined, raw at the edge) and bare bone (ivory, pitted, cracked);
  vertex-coloured parts (teeth, gums, eyes, one clouded, claws, bare ribs, flaps of skin, slaver).
- `models/bear.glb` and `bear_lo.glb`: built by `tools/build_bear.py` in Blender 4.3, which uses
  `tools/build_character.py` from `godot/character-controller`. Run it from the game's root:
  `blender --background --python creatures/bear/tools/build_bear.py [-- <folder for pictures>]`
- `example.gd`: put it on a Node3D in an empty scene. A bear goes through every move.

Needs nothing else at run time (no textures, no other components).
