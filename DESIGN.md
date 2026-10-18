# The Clearing: design

What the game is meant to be, and the decisions that shape it. The README says how it is built and run; this says
what it is for. Where the two disagree about the game (not the code), this one wins. Keep it current: when a
decision changes, change it here.

## The idea

You wake in a wide grassy clearing walled in on every side by a maze that was not built for people. Up to four
friends wake with you. Find the way out.

After *The Maze Runner* (the Glade, the walls, the Grievers, the sprint) and *Labyrinth* (a maze with rules of its
own), seen and lit like *Inside*. A secret cart in the Scareathon arcade (code **MAZE**), played on phones first.

## Pillars

1. **Built for something bigger.** The maze dwarfs you. Walls are huge, high, thick and damp; gaps through them are
   slots you squeeze through; the clearing is vast. Scale is the main feeling.
2. **Quiet dread, not combat.** You cannot fight what hunts the maze. You run, hide, climb and get out. Being caught
   costs you ground (back to the clearing), not the game.
3. **Together, close by.** Friends in a room run the same maze, hear each other only when near, and lose each other
   round corners.
4. **Every maze new, every maze fair.** Mazes are generated from rules, a fresh one each round, the same for everyone
   in a room. Rules, not hand edits, are how the maze changes (hand layouts are possible, but the rules come first).
5. **Phones first.** It must run smoothly in a phone browser, in portrait, with touch.

## Look and feel (the art direction)

- **The boy.** Every player is Inside's boy, the same character for everyone (no random looks): no face, a mask-like
  head with a chin, a plain basin-cut of hair low over the brow, a plain shirt, tapered dark trousers with some shape
  to the legs (never tubes), short angular boots. The only difference between players is the shirt colour, by seat:
  Inside's deep red first, then faded blue, mustard, dull green. Every head and hair option made along the way is
  kept (CharacterStudio, and the head/hair sheets) for comparison.
- **Animation.** Readable, exaggerated poses; a full-tilt sprint after Dylan O'Brien's in *The Maze Runner*; jump,
  slide, roll and trip with believable hands and ankles. Reference: `videoplayback.mp4`.
- **Light.** Inside's: overcast, misty, nearly colourless but for the red shirt; soft light from above, soft
  shadows. Mist thick enough to lose the far walls, but not so thick the maze is grey mush (lighter on the title and
  in the editor).
- **Walls.** Brutalist concrete: cast concrete inside the rings, precast slabs between them; photographed textures
  without visible tiling, rain stains running down from ledges. Plain boxes by default (no crowning or footing);
  decorated styles are for particular places. Solid, never planes.
- **Ground.** Damp dirt and mud in the halls (cracked dry patches, stones, wet mud, moss along the wall feet,
  puddles that reflect the walls), at the quality of Outside's sand. Real 3D grass in the clearing that bends round
  you and stands back up, never mown.
- **Life on the walls.** Vines hang from the wall tops (climbable ropes); ivy where there are ways up.

## The maze

### Shape

Square rings round the clearing, middle out, each walled off from the next but for its gates. Only the first ring
is built so far; the others are planned. The way out of the last ring is the exit, marked by a pale light standing
up past it.

The plan is a grid of 14 m cells. Walls stand on the lines between cells. Every ring has its own **style**
(`MazeStyle`), which is where the rules live, and which can be changed per ring in the editor (`MazeLayout.styles`).

### The clearing

- 41 cells across: about 574 m. Open grass, stands of pines round its edge and dense woods in one corner (chosen by
  the seed), but no trees within 95 m of the middle. The middle is level (70 m out); past it very gentle hills, up to
  4 m, level again near the walls. All set by `ClearingStyle` (`scripts/clearing_style.gd`, `MazeLayout.clearing_style`).
- Its wall is a special case, far thicker than the grid: about 54 m of solid stone (the first ring's `rampart`), 92
  m high (`inner_height`), twice the other walls between rings. Nothing grows or stands on it.
- Four gates, one in the middle of each side, each a slot about 2 m wide (about three of him) running the whole way
  through that wall. Every gate leads on into the maze: none is a dead end.

### Ring styles

| | Avenues (ring 1) | Warren (ring 2, planned) | Tangle (ring 3, planned) |
| --- | --- | --- | --- |
| Depth | 6 cells, inside 3 of rampart (9 in all) | 4 cells | 4 cells |
| Halls | 2 cells wide (about 16 m between walls) | 1 cell | 1 cell |
| Walls | 12 m thick, 34 m high | 3.2 m thick | 3.2 m thick |
| Passages | go on straight half the time; no extra branching; no loops | winding, forking | branching often, many loops |
| On the walls | climbable ivy up a tenth of the faces (a third to two-thirds of the way up, never to the top), vines hanging from some of it, leafy vines strung across an eighth of the halls | terraces, ivy, vines, rope bridges | as Warren |

What a style can set: depth (cells), hall width (cells), wall thickness, rampart (extra cells of solid wall round
its inside), how high the wall round its inside is, how often passages go straight, how often they branch, how many loops, narrow entrances (a passage of
some length from each gate) and doorways (a slot through a gatehouse), and the share of walls with terraces, upper
terraces, rope bridges, ivy to the top, vines on terraces, wall-top bridges and wall-top vines.

Because walls are thick, any opening one cell long through a wall is itself a slot (cell minus wall thickness):
that is how the gates become slots.

### Ways up

Terraces of stone against the walls (steps for a giant: 6.5 m and 13 m), ivy to climb their faces and sometimes on
to the wall top, vines to catch with a jump and swing on, rope bridges across halls and between wall tops. Which a
ring has is its style's choice. The wall tops are a second level you can travel along.

## Players

- Move, look, jump, and everything Outside's boy can do: sprint (its own button), duck, slide, roll, climb a ledge,
  kick off a wall, climb ivy, swing on ropes, cross bridges.
- Controls: left thumb moves, right half drags the camera; keyboard/mouse and gamepad too. The camera follows behind
  when you run away from it, and never circles you when you run sideways.

## What hunts the maze

- **Apophis**, Outside's great snake.
- **Mummies**, six kinds from Outside, in packs.
- **The Griever**: a gelatinous lump of wet meat on eight robotic, procedurally animated spider legs that plant on
  walls and floor, with a stinger. It sees, hunts, winds up, strikes.
- None enters the clearing. Caught, a player is put back in the clearing. Once out, nobody is hunted.
- With friends, the room's maker runs them; everyone else sees copies.

## Playing together

- Alone, or a room for up to four: make a room, share its four-letter code, the maker starts. The maze comes from
  the room code and the round, so nothing about it is sent.
- **Proximity voice** (web): talk with the MIC button (or V), off until you turn it on. Full volume within 4 m,
  silent by 30 m, heard from where the speaker is, muffled through walls. Peer to peer (WebRTC), set up through the
  room.
- A round ends when everyone is out; the maker calls the next maze.
- Score (sent to the arcade): 10000 less the seconds it took to get out.

## Performance rules

- Target phones in a browser (GL Compatibility, WebGL). The web .pck must stay well under GitHub's 100 MB limit
  (textures capped at 1024).
- Anything simulated per object (vines, rope bridges) must rest when still and nobody is near; never simulate
  thousands of things every frame.
- Anything numerous and spread out (grass squares, trees) is updated only near the camera and only when it changes.
- Check the first seconds too: no settling or warm-up work that runs for everything at once.

## Not decided or not done

- Rings 2 and 3 (styles exist; not built or played yet), and what changes between rings beyond the style.
- Moving walls, doors that shut at night, a day/night cycle.
- A map, sound and music, player names.
- Enemies using the ways up (terraces, bridges, wall tops).
- Reconnecting mid-round past the server's 90 seconds; a relay (TURN) server for voice behind strict networks.
- Whether the score should reward helping friends out.
