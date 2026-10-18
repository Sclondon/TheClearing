# Psychic child

A small, thin child of six or so, in one plain washed-out hospital smock (a round neck, short loose sleeves, tied at
the back), barefoot, her head shaved to a grey stubble, a blank mask for a face. She never walks: she drifts a hand's
breadth off the ground, her legs dangling with the toes pointed, humming to herself, while a few small things
(pebbles, dead leaves, motes of dust) go slowly round her in the air. She can take hold of a thing with her mind: her
right arm held out at it, shaking, her left hand at her temple, the air round it warping, her nose bleeding. Frightened,
she curls up in the air with her hands to her head while the air round her warps, the things round her race and rise,
a high ringing comes up and her nose bleeds; then it all goes out of her at once, a burst that flings everything near
away. After it she sits on the ground hugging her knees, still. Uncanny and sad more than monstrous.

It is only the look, the motion and the sounds. She does no thinking: your game moves her and says how she feels.
Made for Warren (its `MazePsychicChild` is the thinking that drives her there: she hunts nobody, watches over whoever
is calm near her, and bursts when she is frightened).

## Needs

GameCommon's `godot/character-controller` (her rig, `PsychicChildRig`, extends `CharacterRig`, and uses its `Toon`,
`Dust` and `Settings`). Global class names: `PsychicChild`, `PsychicChildRig`. Works in GL Compatibility (web, phones).

## Use

```gdscript
var child := PsychicChild.new()        # modelled a little under a metre tall: use her at scale 1
add_child(child)
child.put(spawn_point, spawn_yaw)

# every frame, from your own body (a CharacterBody3D, a path follower...):
child.global_position = body_position  # where her feet would be on the ground (she floats over it)
child.rotation.y = facing_yaw          # 0 faces +Z
child.velocity = body_velocity         # her legs trail behind as she drifts
child.aim = player_head                # what she looks at (INF: nothing)
child.distress = 0.4                   # 0 calm .. 1 about to burst: all the warning comes from this
child.drained = true                   # sitting on the ground, hugging her knees
child.humming = true                   # her tune (it breaks off as she is frightened)
child.reaching = true                  # holding something with her mind...
child.reach_at = hostile_middle        # ...there: her arm out at it, the air warped round it

child.thud(point)                      # a puff of dust where something is slammed down
child.burst()                          # `bursting` fires as it goes out (BURST_PEAK s): fling things then
child.far = true                       # not posed or heard
```

- `busy()` (in a burst), `head()` (for a line-of-sight test).
- Exports: `low_poly` (or `Settings.low_poly`), `sound`, `volume_db`, `sound_range`, `pose_rate` (poses a second, 0
  every frame: fewer when she is far off).

## How it moves

All procedural on the boy's bone names (`PsychicChildRig` poses every joint itself and never runs CharacterRig's
own walk, so she is cheap). Drifting: she bobs slowly, legs hanging all but straight with the toes pointed and curled
under, paddling out of step as if in water and trailing behind her; arms hanging a little behind, as if drawn along;
her head tilted over, swaying with her humming, turning to what she looks at. Distress curls her up in the air:
shoulders up, hands to her head, elbows before her face, head bowed and shaking, knees drawn up, rising, all of it
trembling harder as it builds. The burst throws her open (arms out wide, fingers splayed, head back, back arched, legs
straight, up in the air), then she sags and sinks to sit. Reaching: right arm out straight at the thing, hand open and
stiff, shaking; left hand at her temple.

## The things round her, the warp, the nosebleed

- Nine pebbles, six specks of dust and six dead leaves go round her (two MultiMeshes, no shadows: two draws). Frightened
  they go faster, higher and closer; the burst shoots them out (they fall and lie where they land) and they gather
  again, slowly, once she is calm.
- The warp is the screen behind drawn again through slow ripples (a camera-facing quad with `hint_screen_texture`):
  round her as her distress builds, round whatever she holds, and a ring going out with the burst. Each is drawn only
  while it shows. It undoes the scene's tonemap where the scene is tonemapped as it is drawn (it reads the
  environment: filmic, its white and exposure; nothing to undo with glow or adjustments on, when the tonemap is a pass
  of its own), so where nothing bends it cannot be seen.
- The nosebleed is an object of its own on the head (`psychic_child_blood`): two trickles that run down from her nose as
  far as she has bled (a shader cut along each), shown only while there is any.

## Sound

All made in code (nothing to load): her humming (a soft nasal "mmm", read from a one-cycle table, with breath in it,
carrying a slow little air in A minor that goes round; it wavers and goes flat as she is unsettled, and breaks off),
the ringing (a thin high tone with a second just off it beating slowly, rising with her distress), and the burst (a
dry crack, a deep soft boom falling away, and grit scattering). The humming is made the first time she hums, not
before.

## Model

`tools/build_psychic_child.py` builds `models/psychic_child.glb` and `psychic_child_lo.glb` in Blender 4.3 on the
mummy's and the boy's bone names, with the character controller's `tools/build_character.py`:

    blender --background --python creatures/psychic_child/tools/build_psychic_child.py [-- <folder for preview renders>]

One material for all of her but the blood: each part's colour is baked into the model as its vertex colour, and how
much dirt is in each point (her soles, the hem, folds of the smock) as its alpha; `PsychicChildRig` shades it with
Toon's shader, darkening the dirt in one soft step. About 24k triangles (`_lo`: 3k); one draw and its shadow, two more
for the things round her.

## Try it

`example.gd` on a Node3D: one on a flat floor going round a loop (drift to a post and watch it, lift a block with her
mind and slam it down, be frightened, burst, sit drained, drift back).
