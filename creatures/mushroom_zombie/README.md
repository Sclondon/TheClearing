# Mushroom zombie

One of the boys, taken over by a fungus, for Godot 4.7 (GL Compatibility): ashen, blotched, his clothes faded and
filthy; caps crowded out of a knot of fruiting body over his crown, shelves out of a temple and the back of his
skull, clumps out of both shoulders, shelves down his spine, and pale mycelium spreading over him in patches,
threads and mats. He is walked, not walking: hung from his upper back like a puppet, head lolled, arms dead, in fits
and jerks, knees lifted high as if on strings. He listens (stops dead, head snapped round to a sound), lunges (arms
thrown out, pitching forward, hands clawing shut), clings, and rises out of the ground. He clicks: a dry crackle,
made in code. Only the look, motion and sound; Warren's `MazeMushroomZombie` is the thinking (blind, by sound).

## Use

```gdscript
var zombie := MushroomZombie.new()
add_child(zombie)
# each frame, from your own body:
zombie.global_position = body_position
zombie.rotation.y = facing_yaw      # 0 faces +Z
zombie.velocity = body_velocity
zombie.clicking = 0.3               # 0..1
zombie.frenzy = 0.0                 # 0..1: worked harder (hunting)
zombie.aim = sound_position         # INF: nothing
# when you like:
zombie.listen()                     # MushroomZombieRig.Act.LISTEN
zombie.lunge()                      # `closing`; grab_hits(point) while stage() is CLOSE; held = true to cling
zombie.rise()                       # up out of the ground (RISE_TIME); `stood`
```

## Needs

GameCommon's `godot/character-controller` (`MushroomZombieRig` extends `CharacterRig`; he has the boy's bones) and
`godot/mushrooms` (MushroomLook shades him; his growths glow faintly at night). Global class names:
`MushroomZombie`, `MushroomZombieRig`.

## Model

`tools/build_mushroom_zombie.py` builds `models/mushroom_zombie.glb` and `_lo` in Blender 4.3 from the boy's own
shapes (the game's `tools/build_boy.py` and `build_character.py`) and the mushrooms' growths.glb, as ONE mesh of ONE
material: his colours and mycelium painted into vertex colours, the growths held by the head and chest bones:

    blender --background --python creatures/mushroom_zombie/tools/build_mushroom_zombie.py

So he costs 3 draws in sight, shadow included (the dressed boy costs about 16). 34k triangles (`_lo`: 6k). His rig
runs none of the boy's own posing, only its own.

## Try it

`example.gd` on a Node3D: he rises, shambles, listens to a post, lurches at it, lunges and takes it.
