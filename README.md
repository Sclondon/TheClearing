# The Clearing

A maze game for the Scareathon arcade, after *The Maze Runner* and *Labyrinth*. You and up to three friends
wake in a wide grassy clearing walled in by a maze that was not built for people: grey stone walls 34 m
high, damp and mossy, ivy hanging from them. Find the way out. The maze goes round the clearing in rings, each
walled off from the next but for one gate; a pale light stands up past the gate out of the last ring.

This is the start: the clearing, the first ring, rooms for playing together, and a maze made fresh each
round. Apophis, packs of mummies and a Griever hunt the passages; the walls do not move, and there is no night.
Every player is Inside's boy:
no face, a plain shirt (its colour by seat, the first red) and dark trousers.

What the game is meant to be (pillars, art direction, the maze's rules, enemies, playing together) is in
[DESIGN.md](DESIGN.md); this file is how it is built and run.

Godot 4.7, GL Compatibility, landscape first (it also fills a portrait window). Web build in `build/`, served at
https://sclondon.github.io/TheClearing/build/.

## Playing

- **Move:** a thumb on the left half of the screen (touch), WASD or arrows, or a gamepad stick.
- **Look:** drag on the right half, the mouse, or the right stick. **Jump:** the jump button, Space, or A.
- **Cut** a vine strung across a hall (walk it like a tightrope from the buttress at its end): the hand button, E or F.
  It falls into two vines hanging from the walls; if you were on it, you keep hold of yours.
- Everything else the boy from *Outside* can do works too (sprint, duck, slide, climb a ledge, kick off a wall).
  The walls themselves are far too tall to climb, but there are ways up: ivy up the terraces, vines, rope bridges.
- **PLAY ALONE**, or **MAKE A ROOM** and give friends its four-letter code to **JOIN A ROOM**. The room's
  maker starts the game. When everyone is out, the room's maker picks the next maze.
- A run's score, sent to the arcade, is 10000 less the seconds it took you to get out.

## Laying out mazes by hand

Open `res://maze_editor.tscn`. Its root is a `MazeLayout`: set **Maze Seed** and **Rings** in the Inspector and
press **Generate**. The maze is laid out as pieces (`MazePiece`) in folders: Walls, Piers, Terraces, Ivy, Vines,
Bridges, Trees and the Beacon, each shown as it will be. Move, turn, resize (a box's **Size**, or scale it), copy or
delete any of them; a bridge's far end is its child **End**. Save the scene as `res://mazes/<name>.tscn` and rounds
play it: layouts in `res://mazes/` are played in name order (round 1 the first), round and round; with none there,
every maze is generated. **Playable** off leaves one out. **Game Light** off shows it in the editor's plain light.

Walls count where they stand: which lines between cells have a wall is read from the wall and pier pieces when the
maze is played, so taking one away opens the way there (for the players, the things that hunt them and the way out),
and one put down on a line (every 14 m, half a cell off the middle) closes it. The rings, gates and clearing come
from the seed. Generate again replaces everything in the layout.

## How it works

- `scripts/maze.gd` (`Maze`): the plan. Square cells 14 m across. `Maze.CLEARING` cells across the clearing (41),
  then each ring as its `MazeStyle` (`scripts/maze_style.gd`) says: depth, hall width (it carves over blocks of
  cells), wall thickness, a rampart of solid cells round its inside and how high that wall is, straightness,
  branching, loops, entrances, and
  what is on its walls (see DESIGN.md). `rings` of them are built (1 for now) and the grid runs to the outside of
  the last. Each ring is grown from its first way in (into the first, a gate in the middle of each side of the
  clearing; into each later one, the gate out of the ring inside it), and its gate out put on its outside as far
  round the walls from its ways in as there is. The gate out of the last ring is the exit. The same seed always
  gives the same maze: `Maze.seed_for(room code, round)`.
- `scripts/maze_layout.gd` (`MazeLayout`) and `scripts/maze_piece.gd` (`MazePiece`): a maze as pieces, generated
  or laid out by hand (above). `MazeBuilder.build(plan)` lays out a generated maze and realizes it; `realize(layout)`
  builds any layout. `scripts/mazes.gd` (`Mazes`) finds the ones in res://mazes/; `scripts/maze_light.gd`
  (`MazeLight`) is the sky, mist and sun, for the game and the editor alike.
- `scripts/maze_builder.gd` (`MazeBuilder`): the walls inside a ring 34 m high and 3.2 thick, the walls between
  rings as high as the outer ring's style says (the clearing's 92 m, the rest 46) and 4.2 thick, each with a footing and a cornice, and square piers standing above them where walls
  meet; built of real blocks (each a chamfered slab a little proud or sunk, with joints between) out to 110 m
  and plain boxes beyond, in squares of 70 m so that what is off screen is not drawn, with plain boxes for shadows;
  a box for each piece to bump into. The next ring's outside wall stands
  unbroken beyond the last ring built, with open ground up to it. The ground, and over the clearing its gentle
  hills (`ClearingStyle`: a mesh and a heightmap to walk on, `MazeBuilder.hills`); stands of pines in the clearing
  (none in its middle, dense woods in one corner)
  and a few past the last ring (GameCommon's pine-tree); real grass over the clearing (GameCommon's
  grass: knee-high blades that the wind moves and the players push aside); the light past the exit.
- `scripts/maze_features.gd` (`MazeFeatures`): the ways up, chosen from the seed. Terraces of stone against the walls
  like steps for something huge (a lower one 6.5 m up and 3 m deep, often an upper one at 13 m set back above
  it), with climbable ivy up their faces (`scripts/ivy_climb.gd`, `IvyClimb`, a `Ladder`) and sometimes on up to the
  wall top, where he can walk to the next pier; vines to swing on (`scripts/vine.gd`, `Vine`, a `Rope`, its end
  2.6 m up so it takes a jump); and rope bridges (`scripts/rope_bridge.gd`, `RopeBridge`: a chain of points that
  sags, dips under anyone in the group `bridge_weights` and sways, its planks moving bodies) between terraces
  across a hall and between wall tops.
- `scenes/wall_gallery.tscn` (`scripts/wall_gallery.gd`, made by `tools/make_wall_gallery.gd`): a room of every
  wall style and look side by side, each signed; play it to walk among them.
- `scripts/wall.gd` (`Wall`, scene `scenes/wall.tscn`): a wall in a style (Basic: a plain box; Cornice, Pilasters,
  Stepped: decorated; `Wall.style_boxes`), width, height and depth in the
  Inspector, in one of several concretes (photographed, from Poly Haven, CC0: `textures/polyhaven/CREDITS.md`; or
  made by `tools/make_wall_textures.gd`), the repeats hidden by a shader that shifts the texture about and lays
  broad tone and rain stains over it. The maze's walls are drawn with it (`Wall.material_for`), Basic unless a
  wall piece is given a style (`MazePiece.style`): cast concrete inside
  the rings, precast slabs between them.
- `scripts/maze_stone.gd` (`MazeStone`): the ground shader (and the old stone wall shader, no longer used). The stone is Outside's `Sandstone`
  shader at a giant's scale (blocks 5 m long), made grey and damp: dark streaks run down from the joints, the
  foot of every wall is soaked and mossy, and ivy hangs in curtains from the top. Lit in hard bands like the figures.
- `scripts/world.gd` (`World`): one round. Sky, fog and sun; the maze; this player (`player.tscn`, Outside's boy
  from GameCommon) with `FollowCamera` (orbit, `indoors` so it stays out of the walls) and `TouchControls`;
  a `RemotePlayer` for each friend. Each copy sends where its own player is 12 times a second.
- `scripts/enemies/`: what hunts the maze. `Apophis` (Outside's great snake) and six kinds of `Mummy` (Outside's,
  with their rigs and models in `models/enemies/`) on a shared `MazeEnemy`, finding their way with `MazeNav` on the maze
  plan and placed from the seed by `MazeEnemies`; and the `Griever` (`griever*.gd`): a lump of wet meat on eight
  procedural robotic spider legs that plant on walls and ground, with a stinger. Then the newer kinds, each a thin
  `MazeEnemy` driving a creature from `creatures/` (installed from GameCommon): `MazeGhoul`, `Centipede`,
  `MazeSpider`, `Abomination`, `MazeSlimeWall`, `Bats`, `MazeBaboon`, `MazeDog`, `MazeDeer` (the watching herd),
  `MazeElk` (the territorial bull), `Alien`. How many of each a ring
  has is its `MazeStyle` ("What hunts it"); `World` asks `MazeEnemies` for the first ring's (`populate`, then
  `add_hunters`) and puts in a Griever; alone or as the host they are run there and their state goes to guests ten
  times a second (K_ENEMIES), where copies follow it. Caught, a player is put back in the clearing; out, nobody is
  hunted.
- `creatures/`: GameCommon's creatures, look and motion only (see each one's README): `ghoul`, `centipede`,
  `giant_spider`, `abomination`, `slime_wall`, `bats`, `baboon`, `dog`, `deer`, `elk`, `alien`. Change them here, then `kit.sh pull`
  them back to GameCommon (`godot/<name>`, with `_` as `-`). Their models are built in Blender by their `tools/` scripts.
- `scripts/wildlife.gd` (`Wildlife`): the animals that hunt nobody: herds of ordinary deer and elk grazing in the
  clearing's meadow (ClearingStyle, "Wildlife") and in the halls (MazeStyle, "Wildlife"), running off when someone
  comes near. Lightweight (not MazeEnemies, not sent over the network): each copy runs its own from the round's seed.
- `scripts/remote_player.gd` (`RemotePlayer`): a friend, a `Figure` on the boy's rig chasing their news.
- `scripts/looks.gd` (`Looks`): every player is the same boy, as Inside has him (no face, a basin cut, no cap,
  shirt, dark trousers and boots). Only the shirt's colour differs, by seat.
- `scripts/voice.gd` (`Voice`): proximity voice in rooms (web only), WebRTC signalled through the room.
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
"$G" --headless --path . -s res://tests/strand_test.gd    # a strung vine: walked as a tightrope, cut into two vines
"$G" --headless --path . -s res://tests/hunt_test.gd      # enemies in a round; caught, back to the clearing
"$G" --headless --path . -s res://tests/layout_test.gd    # a layout changed by hand, saved, loaded and played
"$G" --editor --path . res://tests/editor_check.tscn       # (after layout_test) what the editor shows, saved to user://editor_view.png
"$G" --headless --path . -s res://tests/enemy_test.gd     # Apophis and the mummies on their own
"$G" --headless --path . -s res://tests/griever_test.gd   # the Griever on its own
# each newer kind on its own (always with --audio-driver Dummy: some make sounds)
for t in ghoul centipede spider abomination slime_wall bats baboon dog deer wildlife alien; do
  "$G" --headless --audio-driver Dummy --path . -s res://tests/${t}_test.gd; done
# pictures of each: tools/<kind>_shots.gd (windowed, 1280x720)
"$G" --headless --path . -s res://tests/dev_test.gd -- --dev   # the dev tools (and the clearing wall's height)
"$G" --path . --resolution 1280x720 -s res://tools/climb_shots.gd -- <folder>   # pictures of the ways up
"$G" --headless --path . -s res://tools/bake_preview.gd -- [seed] [rings]   # a maze to look round in the editor: preview/maze_preview.scn
"$G" --path . --resolution 900x900 -s res://tools/head_sheet.gd -- <file.png>    # every head shape
"$G" --path . --resolution 900x900 -s res://tools/legs_sheet.gd -- <file.png>    # every trouser cut and boot
node tools/dev_relay.mjs <scareathon-v3/server> 3111      # local rooms (needs server/node_modules)
sh tools/coop_test.sh                                     # two copies in one room against it
"$G" --path . --resolution 1280x720 -s res://tools/shots.gd -- <folder>   # pictures to look at
"$G" --path . --resolution 1280x720 -s res://tools/clearing_shots.gd -- <folder> [seed]   # the clearing: hills, woods
"$G" --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/deer_shots.gd -- <folder> [studio|strips|maze|clearing|all]   # deer and elk, gallop strips, the herd, wildlife
"$G" --headless --path . --export-release "Web" build/index.html
```

Flags (command line `-- --name=value` or the page's `?name=value`): `server=<url>` for another rooms server.
`dev` turns on the dev tools (on anyway when the game is run from the Godot editor): everyone starts in front of a
gate of the clearing (`start=middle` for the middle), and a DEV button under the clock opens god mode: put mummies
(of a chosen kind, alone or in a pack), the snake or a Griever into the maze ahead, freeze or clear everything that
hunts, be uncatchable, go to a gate, the middle or the exit. Keys: ` the panel, G god, M a mummy, N the snake, B a
Griever. What it puts in is only in your copy, so use it playing alone; no score is sent with it on
(`scripts/dev_tools.gd`, `DevTools`).

## Not done yet

Rings past the first; enemies knowing about the ways up (terraces, bridges); ears;
walls that move, doors that shut at night, a map, sound and music, names, and reconnecting mid-round past the
server's 90 seconds.
