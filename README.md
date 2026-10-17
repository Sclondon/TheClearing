# The Clearing

A maze game for the Scareathon arcade, after *The Maze Runner* and *Labyrinth*. You and up to three friends
wake in a wide grassy clearing walled in by a maze that was not built for people: grey stone walls 34 m
high, damp and mossy, ivy hanging from them. Find the way out. The maze goes round the clearing in rings, each
walled off from the next but for one gate; a pale light stands up past the gate out of the last ring.

This is the start: the clearing, the first ring, rooms for playing together, and a maze made fresh each
round. Nothing hunts you yet, the walls do not move, and there is no night. Every player is Inside's boy:
no face, a plain shirt (its colour by seat, the first red) and dark trousers.

Godot 4.7, GL Compatibility, portrait first (it also fills a landscape window). Web build in `build/`, served at
https://sclondon.github.io/TheClearing/build/.

## Playing

- **Move:** a thumb on the left half of the screen (touch), WASD or arrows, or a gamepad stick.
- **Look:** drag on the right half, the mouse, or the right stick. **Jump:** the jump button, Space, or A.
- Everything else the boy from *Outside* can do works too (sprint, duck, slide, climb a ledge, kick off a wall).
  The walls themselves are far too tall to climb, but there are ways up: ivy up the terraces, vines, rope bridges.
- **PLAY ALONE**, or **MAKE A ROOM** and give friends its four-letter code to **JOIN A ROOM**. The room's
  maker starts the game. When everyone is out, the room's maker picks the next maze.
- A run's score, sent to the arcade, is 10000 less the seconds it took you to get out.

## How it works

- `scripts/maze.gd` (`Maze`): the plan. Square cells 14 m across (halls about 10 m wide). `Maze.RINGS` gives the clearing (7 cells
  across, 98 m, open) and the ring round it after ring, middle out; `rings` of them are built (1 for now) and
  the grid runs to the outside of the last. Each ring is carved on its own by a depth-first walk from its way in
  (into the first, a gate in the middle of each side of the clearing; into each later one, the gate out of the
  ring inside it), with 6% more walls knocked through for loops, and its gate out put on its outside as far
  round the walls from its way in as there is. The gate out of the last ring is the exit. The same seed always
  gives the same maze: `Maze.seed_for(room code, round)`.
- `scripts/maze_builder.gd` (`MazeBuilder`): the walls inside a ring 34 m high and 3.2 thick, the walls between
  rings 46 m and 4.2 thick, each with a footing and a cornice, and square piers standing above them where walls
  meet; built of real blocks (each a chamfered slab a little proud or sunk, with joints between) out to 110 m
  and plain boxes beyond, in squares of 70 m so that what is off screen is not drawn, with plain boxes for shadows;
  a box for each piece to bump into. The next ring's outside wall stands
  unbroken beyond the last ring built, with open ground up to it. The ground; stands of pines in the clearing
  and a few past the last ring (GameCommon's pine-tree); real grass over the clearing (GameCommon's
  grass: knee-high blades that the wind moves and the players push aside); the light past the exit.
- `scripts/maze_features.gd` (`MazeFeatures`): the ways up, chosen from the seed. Terraces of stone against the walls
  like steps for something huge (a lower one 6.5 m up and 3 m deep, often an upper one at 13 m set back above
  it), with climbable ivy up their faces (`scripts/ivy_climb.gd`, `IvyClimb`, a `Ladder`) and sometimes on up to the
  wall top, where he can walk to the next pier; vines to swing on (`scripts/vine.gd`, `Vine`, a `Rope`, its end
  2.6 m up so it takes a jump); and rope bridges (`scripts/rope_bridge.gd`, `RopeBridge`: a chain of points that
  sags, dips under anyone in the group `bridge_weights` and sways, its planks moving bodies) between terraces
  across a hall and between wall tops.
- `scripts/maze_stone.gd` (`MazeStone`): the wall and ground shaders. The stone is Outside's `Sandstone`
  shader at a giant's scale (blocks 5 m long), made grey and damp: dark streaks run down from the joints, the
  foot of every wall is soaked and mossy, and ivy hangs in curtains from the top. Lit in hard bands like the figures.
- `scripts/world.gd` (`World`): one round. Sky, fog and sun; the maze; this player (`player.tscn`, Outside's boy
  from GameCommon) with `FollowCamera` (orbit, `indoors` so it stays out of the walls) and `TouchControls`;
  a `RemotePlayer` for each friend. Each copy sends where its own player is 12 times a second.
- `scripts/remote_player.gd` (`RemotePlayer`): a friend, a `Figure` on the boy's rig chasing their news.
- `scripts/looks.gd` (`Looks`): each player is the boy as Inside has him (no face, cropped hair, no cap, shirt,
  dark trousers and boots). The shirt's colour goes by seat; skin and hair by a seed that goes round the room as
  the server's "hero" word (`p123456`).
- `scripts/net.gd` (autoload `Net`): the rooms connection, copied from October Valley. Server side:
  `server/routes/theClearing.js` in scareathon-v3 at `/the-clearing/ws`, which reuses
  `server/eightBitEvilV2/rooms.js` (four seats, four-letter codes, the maker hosts, seats held through
  a dropped connection). A guest can only talk to the host, so the host passes guests' news on.
- `scripts/main.gd`: the title (over a maze seen from above), joining by code (an on-screen letter pad, so no
  phone keyboard), the lobby, the HUD, round over, and the score sent to the arcade.
- From GameCommon (`C:\Projects\GameCommon`): `godot/character-controller` (player.tscn, `scripts/player.gd`,
  `character_rig.gd`, `character_look.gd`, `follow_camera.gd`, `touch_controls.gd`, `toon.gd`, `figure.gd`,
  models/boy*.glb and the rest listed in its FILES.txt), `godot/pine-tree` and `godot/grass`. Copies: change them here if need
  be, and pull good changes back with `sh /c/Projects/GameCommon/kit.sh pull`.

## Commands

Godot is `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe` (`$G` below).

```
"$G" --headless --path . --import                         # after adding a class_name script or a model
"$G" --headless --path . -s res://tests/maze_test.gd      # the maze plan
"$G" --headless --path . -s res://tests/smoke_test.gd     # alone: walk, walls, out, next maze, touch
"$G" --headless --path . -s res://tests/climb_test.gd     # ivy onto a terrace, a vine, a rope bridge
"$G" --path . --resolution 720x1280 -s res://tools/climb_shots.gd -- <folder>   # pictures of the ways up
"$G" --headless --path . -s res://tools/bake_preview.gd -- [seed] [rings]   # a maze to look round in the editor: preview/maze_preview.scn
"$G" --path . --resolution 900x900 -s res://tools/head_sheet.gd -- <file.png>    # every head shape
"$G" --path . --resolution 900x900 -s res://tools/legs_sheet.gd -- <file.png>    # every trouser cut and boot
node tools/dev_relay.mjs <scareathon-v3/server> 3111      # local rooms (needs server/node_modules)
sh tools/coop_test.sh                                     # two copies in one room against it
"$G" --path . --resolution 720x1280 -s res://tools/shots.gd -- <folder>   # pictures to look at
"$G" --headless --path . --export-release "Web" build/index.html
```

Flags (command line `-- --name=value` or the page's `?name=value`): `server=<url>` for another rooms server.

## Not done yet

Rings past the first; things that hunt you (Outside's snake and mummies, and a Griever-like thing of meat on
metal legs, are being made);
walls that move, doors that shut at night, a map, sound and music, names, and reconnecting mid-round past the
server's 90 seconds.
