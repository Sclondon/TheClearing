# The Clearing

A maze game for the Scareathon arcade, after *The Maze Runner* and *Labyrinth*. You and up to three friends
wake in a grassy clearing in the middle of a huge stone maze, ivy hanging from its walls, and find the way out.
A pale light stands up past the one way out, seen over the walls when you look up.

This is the start: the clearing, rooms for playing together, and a maze made fresh each round. Nothing hunts you
yet, the walls do not move, and there is no night.

Godot 4.7, GL Compatibility, portrait first (it also fills a landscape window). Web build in `build/`, served at
https://sclondon.github.io/TheClearing/build/.

## Playing

- **Move:** a thumb on the left half of the screen (touch), WASD or arrows, or a gamepad stick.
- **Look:** drag on the right half, the mouse, or the right stick. **Jump:** the jump button, Space, or A.
- Everything else the boy from *Outside* can do works too (sprint, duck, slide, climb a ledge, kick off a wall).
  The maze walls are too tall to climb.
- **PLAY ALONE**, or **MAKE A ROOM** and give friends its four-letter code to **JOIN A ROOM**. The room's
  maker starts the game. When everyone is out, the room's maker picks the next maze.
- A run's score, sent to the arcade, is 10000 less the seconds it took you to get out.

## How it works

- `scripts/maze.gd` (`Maze`): the plan. A 25 x 25 grid of 4 m cells, a 5 x 5 clearing open in the middle with
  a gap in each side, passages carved by a depth-first walk from behind each gap, 6% more walls knocked through
  for loops, and the exit put on the outer edge as far round the walls from the clearing as there is. The same
  seed always gives the same maze: `Maze.seed_for(room code, round)`.
- `scripts/maze_builder.gd` (`MazeBuilder`): walls 8 m high as one mesh, with a box for each straight run to bump
  into; the ground; pines from GameCommon round the clearing and outside; the light past the exit.
- `scripts/maze_stone.gd` (`MazeStone`): the wall and ground shaders. The stone is Outside's `Sandstone`
  shader, made grey with ivy curtains added; lit in hard bands like the figures.
- `scripts/world.gd` (`World`): one round. Sky, fog and sun; the maze; this player (`player.tscn`, Outside's boy
  from GameCommon) with `FollowCamera` (orbit, `indoors` so it stays out of the walls) and `TouchControls`;
  a `RemotePlayer` for each friend. Each copy sends where its own player is 12 times a second.
- `scripts/remote_player.gd` (`RemotePlayer`): a friend, a `Figure` on the boy's rig chasing their news.
- `scripts/looks.gd` (`Looks`): each player is one of Outside's made-up people (`CharacterLook.random`), known
  by a seed that goes round the room as the server's "hero" word (`p123456`).
- `scripts/net.gd` (autoload `Net`): the rooms connection, copied from October Valley. Server side:
  `server/routes/theClearing.js` in scareathon-v3 at `/the-clearing/ws`, which reuses
  `server/eightBitEvilV2/rooms.js` (four seats, four-letter codes, the maker hosts, seats held through
  a dropped connection). A guest can only talk to the host, so the host passes guests' news on.
- `scripts/main.gd`: the title (over a maze seen from above), joining by code (an on-screen letter pad, so no
  phone keyboard), the lobby, the HUD, round over, and the score sent to the arcade.
- From GameCommon (`C:\Projects\GameCommon`): `godot/character-controller` (player.tscn, `scripts/player.gd`,
  `character_rig.gd`, `character_look.gd`, `follow_camera.gd`, `touch_controls.gd`, `toon.gd`, `figure.gd`,
  models/boy*.glb and the rest listed in its FILES.txt) and `godot/pine-tree`. Copies: change them here if need
  be, and pull good changes back with `sh /c/Projects/GameCommon/kit.sh pull`.

## Commands

Godot is `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe` (`$G` below).

```
"$G" --headless --path . --import                         # after adding a class_name script or a model
"$G" --headless --path . -s res://tests/maze_test.gd      # the maze plan
"$G" --headless --path . -s res://tests/smoke_test.gd     # alone: walk, walls, out, next maze, touch
node tools/dev_relay.mjs <scareathon-v3/server> 3111      # local rooms (needs server/node_modules)
sh tools/coop_test.sh                                     # two copies in one room against it
"$G" --path . --resolution 720x1280 -s res://tools/shots.gd -- <folder>   # pictures to look at
"$G" --headless --path . --export-release "Web" build/index.html
```

Flags (command line `-- --name=value` or the page's `?name=value`): `server=<url>` for another rooms server.

## Not done yet

Things that hunt you in the maze, walls that move, doors that shut at night, a map, sound and music, names,
reconnecting mid-round past the server's 90 seconds, and a preview film for the arcade.
