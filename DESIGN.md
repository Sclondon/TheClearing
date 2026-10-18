# The Clearing: design

What the game is meant to be, and the decisions that shape it. The README says how it is built and run; this says
what it is for. Where the two disagree about the game (not the code), this one wins. Keep it current: when a
decision changes, change it here.

## The idea

You wake in a wide grassy clearing walled in on every side by a maze that was not built for people. Up to four
friends wake with you. Find the way out.

After *The Maze Runner* (the Glade, the walls, the Grievers, the sprint) and *Labyrinth* (a maze with rules of its
own), seen and lit like *Inside*. A secret cart in the Scareathon arcade (code **MAZE**), played in landscape.

## Pillars

1. **Built for something bigger.** The maze dwarfs you. Walls are huge, high, thick and damp; gaps through them are
   slots you squeeze through; the clearing is vast. Scale is the main feeling.
2. **Quiet dread, not combat.** You cannot fight what hunts the maze. You run, hide, climb and get out. Being caught
   costs you ground (back to the clearing), not the game.
3. **Together, close by.** Friends in a room run the same maze, hear each other only when near, and lose each other
   round corners.
4. **Every maze new, every maze fair.** Mazes are generated from rules, a fresh one each round, the same for everyone
   in a room. Rules, not hand edits, are how the maze changes (hand layouts are possible, but the rules come first).
5. **Landscape first.** Laid out, played and checked in landscape (1280x720), with mouse and keyboard, a gamepad,
   or touch on a phone held sideways. It must still run smoothly in a phone browser, and still fit a portrait window.

## Look and feel (the art direction)

- **The boy.** Every player is Inside's boy, the same character for everyone (no random looks): no face, a mask-like
  head with a chin, a plain basin-cut of hair low over the brow, a plain shirt, tapered dark trousers with some shape
  to the legs (never tubes), short angular boots. The only difference between players is the shirt colour, by seat:
  Inside's deep red first, then faded blue, mustard, dull green. Every head and hair option made along the way is
  kept (CharacterStudio, and the head/hair sheets) for comparison. The runners (below) are the same boy too, in
  greyer shirts no player has: grey, brown, off-white, a dark charcoal-brown.
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
- Something different before each entrance (`ClearingStyle.entrances`): dense woods round one, grass up to his chest
  round another, a marsh in front of another, nothing at all near the last.
- The marsh (`scripts/marsh.gd`, the marsh settings of `ClearingStyle`): not a pond but a wide, ragged bog, about
  190 m along the wall and 125 m out, beginning a few metres from the wall's foot. Many shallow, irregular pools and
  channels of standing water between hummocks and tussocks of wet ground, black mud at the water's edge, broad open
  meres in some parts and flats of tussocks in others, and a few deep dark pools he has to swim. The water is one
  sheet at one level that the ground stands up through: the shape is all the ground's, from the seed. Sedges grow all
  over it, up out of the shallow water too (thinner there and in open gaps, so the eye catches water at his height;
  darker and yellower than the field's grass; none in the
  deep pools), with reeds and bulrushes in clumps along the pools' edges (rounded heads of brown velvet; some gone to
  seed, some broken, some leant over) and lily pads and a scum of duckweed on the
  open water. All of it bends round whoever pushes through. Wading slows him (the deeper, the slower), he splashes
  going in and leaves rings. A lane in from the gate has nothing deep and nothing standing in it: the way in is wet
  but open.
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
| On the walls | climbable ivy up a tenth of the faces (a third to two-thirds of the way up, never to the top), vines hanging from some of it, vines strung across an eighth of the halls (walked as tightropes from a buttress with ivy up it; the act button cuts one into two hanging vines) | terraces, ivy, vines, rope bridges | as Warren |

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
- Added 2026-10-18 at the user's request ("models and animations specifically, and then as reusable components"):
  each is a GameCommon creature (look and motion, `creatures/<name>/`) driven by a thin `MazeEnemy` here.
  - **Ghoul** (after Zelda's ReDeads, from our mummies, no wraps): raw red, bare, a blank mask face. A statue in a
    dead end until it sees someone; its wrenching shriek freezes anyone facing it for about 2 s; it rushes (faster
    than a walk) and hug-grabs. Turn away or run at once and it is easy to get past.
  - **Giant centipede**: rests coiled, hunts faster than a run (a sprint escapes), up the wall feet round corners,
    rears as a warning and pounces with its claws.
  - **Giant spider**: waits head down high on a wall, drops on a thread, charges in dashes, rears, lunges. Loses
    a sprinter. Climbs back up to wait.
  - **Meat abomination** ("MEAT BEAST" on the dev panel): slow, never lets go, nearly fills a hall; lashes tendrils
    from a few metres after a visible wind-up; touching it catches.
  - **Flesh mounds** (added 2026-10-18: "hands and legs sticking out of it ... like it's absorbed a bunch of people", no
    mouth; "the torsos should use the character torsos, with mask faces ... less bloody, more like the skin grew together,
    maybe pussy"; "different size abominations that can grow and merge together or by absorbing people"): people grown
    together, one creature in sizes by how many bodies are in it. Pallid waxy skin flowing from body to body, puckered
    scar-dark seams, stretch marks, veins, boils of pus; the boys' blank mask faces; men's arms, long gaunt arms and legs.
    - **Amalgam** (3 or 4): boys fused at the hips in a wheel of limbs. Shambles a little slower than a run; where its
      quarry is in a straight line down a hall it rears with its limbs splayed (0.6 s, the warning) and cartwheels at them
      at 5.1 m/s, faster than a run, slower than a sprint, for about 3 s, then is spent and lurches slowly. A sprint, a
      side turning or a climb gets away. Rolling into you catches.
    - **Mound** (5 to 10): fills more of a hall the bigger it is, crawls slower (no faster than a walk). Hauls itself on
      its hands, on the walls where they are near; grabs with the hands at its front after a wind-up (arms drawn up,
      hands splayed and shaking). A closing hand or walking into it catches.
    - **Growing**: whom it catches it absorbs (their body is seen dragged in; the player still goes back to the clearing)
      and it gains a body; two that meet merge, the smaller flowing into the bigger. An amalgam that grows past 4 becomes
      a mound. Capped at 10 bodies (phones). The first ring has two amalgams and a mound of 7 or 8.
  - **Slime wall**: see-through jelly full of skeletons that fills a hall wall to wall, below walking pace;
    touching it catches (you are drawn in and tumble among the bones). Find another way round.
  - **Bats**: a colony roosts on a wall; running or sprinting near wakes it. They catch nobody: they mob the
    player and call every hunter within 45 m to them. Duck or stand still and they lose interest.
  - **Demon baboons**: troops of a mandrill alpha and baboons. They bark, flank (some go where you are heading),
    burst faster than a run and tire; a sprint escapes. Leap-grab.
  - **Feral dogs**: packs that follow players' scent trails nose-down out of sight, bay and gallop on sight
    (between a run and a sprint), lunge-bite. Climbing breaks the trail.
  - **Aliens**: twos and threes that walk calmly and blink ahead of you when unwatched (a shimmering column
    warns first; looking at it stops it), then raise a hand and catch you in a pale light.
  - **Beetles** (after Outside's scarabs): a swarm of several hundred glossy black beetles with an oily sheen
    (ground beetles and dor beetles) waits in cracks at the foot of a wall, in a dead end or along a hall. When
    someone comes down the hall they pour out and flood along the floor after them, lapping up the wall feet, a
    little faster than a run and slower than a sprint. Those that reach you run up your legs; enough of them for
    a moment and you are caught. Sprint away, or get up onto a terrace, the ivy or a vine (they climb no higher
    than about a metre up a wall); when they get no nearer for a few seconds they stream home into the cracks.
  - **Fish people** (deep ones, out of Innsmouth; the user asked 2026-10-18 for "a fish person enemy that uses the
    character controller as a base"): tall, stooped, grey-green and scaled, a fish's head with glassy eyes and needle
    teeth, gills, a fin down the back, webbed hands and feet. Each lies in a black pool of its own in a hall, sunk to
    its eyes: a puddle with two eyes in it, if you look. Down there it hears only what is close or loud: walk softly
    past along the far wall and it stays down; run near it, or step in its pool, and it rises and croaks, and its
    croak brings up every other fish person within about 40 m. It shambles below a walk, but lopes faster than a run
    in short bursts when it sees you near, then stands gulping for breath; a sprint or a corner loses it. It lunges
    and grabs with both hands. It cannot stay out of the water: after half a minute, or once it has lost you, it goes
    back to its pool and sinks.
  - **Angel** (a "biblically accurate" one, after Ezekiel's ophanim and Isaiah's seraphim): three great wheels of
    pale gold one within another, turning slowly, their rims full of real eyes that blink out of step, round a
    burning white-gold heart half hidden by six wings. Huge (7 m across), silent, floating over the halls; the one
    warm bright thing in the mist, lighting the walls round it. It drifts slowly and everyone passes under it, but
    its eyes look every way, so there is no creeping past behind it. Being SEEN is the danger: while you stand in its
    sight in the open its gaze builds on you over about four seconds (quicker near it), and everyone can see and hear
    it build: every eye turns on you, the wheels stop, the wings before its face part, a cone of pale light reaches
    down and pools at your feet, and a choir swells and rises. If it reaches the full you are drawn up into the light
    and taken. Break its sight (a corner, a slot, onto the ivy) and the gaze falls away. One in the first ring.
  - **Giant toad** (added at the user's request, "a frog enemy"): a huge warty toad, taller than the boy's chest,
    squatting wet and still in a dead end, throat pulsing. Seen, it croaks (its throat a great bubble), turns on you
    slowly and comes in great arcing leaps (slower than a run, on the whole). Near and facing you, it winds up for
    about a second where you can see it (the throat swells, the mouth gapes), aims at your chest and holds that aim
    for the last third of a second, and shoots a sticky tongue several metres. Step aside, duck under it, or be out of
    reach; it misses, gulps and sits a moment.
  - **Frog swarm**: dozens of small frogs (fist- to cat-sized) in a muddy pool in a dead end, a few sitting about its
    edge. Come near and they pour out at you in hopping waves, leaping over each other, croaking in chorus. Those that
    reach you leap on and cling, and the more there are the slower you go; enough of them for long enough and you are
    caught. Outrun them, shake them off by running and jumping, or get up onto something (a terrace, the ivy): they
    cannot hop that high, give up and go home.
  - **Harpies** (the user: "lets add a harpie type enemy"): a starved woman's head and trunk (ribs, hollow eyes, a
    too-wide lipless mouth, lank wet hair over the face) on great ragged grey-black wings, with a bird's lower body
    and scaly raptor legs. Each perches high on a wall (the ledge, or the top), hunched, wings mantled, watching the
    hall below. Seeing someone out in the open it screeches (the first warning), takes off over the walls and
    circles high over them; then a falling cry (the second warning), a stoop over the end of a long straight hall,
    and a dive down it, talons first, at chest height. It flies over the walls, so it can come from anywhere, but
    it needs a straight run of hall, wider than its wings, under open sky: under a bridge or a platform, or in a
    slot, you cannot be dived at, and staying hidden long enough sends it home. Its line is set the last half second: duck, slide or roll and
    the talons pass over; step aside and they pass by; stand or run straight and you are snatched. Two dives, then
    it climbs back to its perch and lands.
  - **Giant boar** (after the boar gods of *Princess Mononoke*): a wild boar far over the boy's head at the
    shoulder, black bristle with a crest down its hump, great chipped tusks (one broken), mud-caked, scarred, old
    arrows in its hide, steaming breath. It roots in the mud of a dead end or a wide hall. Poor eyes, a great nose:
    it smells anyone near, much further upwind of it than downwind, so creep past downwind. Noticing you it snorts,
    stamps and paws, its hackles rise and it lowers its head (about two seconds, seen and heard), then charges in a
    straight line, far faster than a sprint and barely able to turn. Step aside (a side passage, a slot, a way up)
    and it thunders past and skids, or slams into the wall and stands stunned a few seconds, then forgets you a
    while. In its way, you are tossed and caught. It cannot reach anyone up a wall.
  - **Chickens** (added at the user's request, "lets also add chickens"): flocks of scruffy feral hens and a rooster
    foraging in the halls, pecking and scratching at the mud, heads bobbing with the chicken head-lock; filthy and
    molting, a rooster crowing in the fog, and a little comic relief. Like the bats they catch nobody: run or
    sprint near them, or walk upright close by, and they explode in a squawking, flapping panic (some flying, feathers
    everywhere), and the racket calls every hunter within 40 m. Creep past crouched. Run into one and the rooster
    flies into a rage (after Zelda's cuccos): the flock mobs you, leaping and beating round your head, pecking,
    slowing you, calling the hunters all the while, until you get away.
  - **Gargoyles** ("and a Gargoyle enemy"): a carved-stone grotesque, alive, bat-winged, of the walls' own weathered
    concrete. It crouches as a statue on a ledge over a hall (a terrace's edge, a wall top low enough to be seen, or
    a stone corbel jutting from the wall), and cannot be told from a carving. Pass beneath it and it stirs (a faint
    ember in its cracks and eyes, its head grinding round to follow you, dust trickling off it), then drops in a long
    glide onto where you were going, its shadow darkening where it will land: keep moving, or turn aside, and it
    misses. A miss turns it to stone where it lands for a few seconds: the time to get away. Then it hunts in heavy
    bounds a little slower than a run, slow to turn (a turn down a side passage gains ground), and from a few metres
    in front of you winds up (wings raised, a snarl) and leaps. Lost, it beats its way back up to its ledge.
  - **The herd** (added 2026-10-18, "lets add deer and elk as well"): white-tailed deer standing in a hall, real at
    first glance. When they see you every head comes up and turns to you, and they freeze, staring, too long, eyes
    giving back the light. Look away and they are a little closer when you look back (they never come within 12 m).
    Come near (9 m) or run at them and one snorts and stamps, the tails go up white, they stot off on stiff legs and
    break into a stampede down the passages away from you; if the only way out is past you, it comes straight back
    down the hall at you, and a deer that runs into you knocks you down (caught). The alarm and the stotting are the
    warning, nearly two seconds: stand aside. One in a herd of four or more is wrong: legs a little too long, a head
    that turns round further than a neck should; now and then it stands up on its hind legs and takes a step towards
    you; it never runs with the others, and stays watching you as they go.
  - **The bull elk**: taller at the shoulder than the boy, holding a stretch of halls as his own. On his ground and
    in his sight, he faces you and bugles (an eerie rising scream, steam pouring from his mouth: the first time
    only), paws the ground and lowers his antlers, then charges faster than anyone can run. For an instant he can
    still swing at you; then his line is set and he can hardly turn. Step aside into a side passage or behind a
    buttress, climb, or leave his ground; standing in his line, you are caught. He runs on past, stands blowing,
    turns slowly and comes again.
  - **Tiny imps** (added 2026-10-18, "add tiny imps and imp swarm"): knee-high devils, sooty red-brown, pot-bellied,
    bat-eared, needle-toothed. Gangs of three or four perch head down on a wall face like gargoyles, chittering. They
    pester rather than kill: noticing you, they cackle, scurry down the wall and scuttle after you (faster than a run,
    slower than a sprint), leap on and cling (back, thigh, shoulder). Each one on you holds you back, and its cackle
    tells every hunter nearby where you are (they fetch bigger things). Three on at once for a moment bring you down.
    A jump or two shakes them off; a roll, slide or dive throws them all off; thrown off, one tumbles and throws a
    tantrum before it comes again. They give up when they lose you and climb back to their perch.
  - **Imp swarm**: a crack at the foot of a wall. Come near (or run near) and it chitters for a second, then dozens of
    imps pour out as a tide along the floor and up and along the walls. Those that reach you run up you and cling,
    slowing you; ten on you for a second and you are down. A roll throws them off; a sprint outruns them; getting up
    onto anything (a terrace, ivy, a vine) or out of reach and they give up and stream home, and rest before coming
    out again.
- **The colossus** (added 2026-10-18: "and a colossus", then "even bigger, crawl over the top of the maze, and
  try to use just 1 fingertip to crush you", and "more lanky and spindly"): what the maze might have been built
  for. A gaunt giant 260 m tall if it stood, after *Shadow of the Colossus* (and *Attack on Titan*'s giants over the
  wall): impossibly long thin arms and legs, knobbly joints, a narrow ribcage and hunched spine, a small stone mask
  of a head on a long neck with pale eyes, sparse slabs of weathered stone with moss, grass, vines and glowing
  runes, tatters of dark fur, long bony fingers. One crawls over each ring wide enough (the Avenues and the
  Galleries) like a spider, on the wall tops, never in the halls: its hands and feet come down only on wall tops of
  its ring, its elbows and knees bent high above, its body slung low over the maze, the halls in its shadow; dust
  and stones rain into the halls where a hand comes down. Its upper body is lost in the mist. It never crosses the
  clearing.
  - It hunts with one finger. Whoever it sees out in the open, it stops, bends its head down to peer between the
    walls, and holds its long index finger over them (its shadow growing on the ground, following slowly), then
    presses it down, grinds, lifts and tries again where they ran, four times at most; under the fingertip is
    caught. The finger cannot get into a slot, right up to the foot of a wall, or under a ledge. Lose it and it
    gives up and crawls on.
  - It sees from above whoever is out in the open in front of it; not in a slot, flat against a wall, under a
    ledge or bridge, or behind a wall from where its eyes are. Standing still halves how far it sees. Running hard
    near one of its hands or feet makes it stop and peer about.
  - Now and then, crawling beside the clearing's wall, it rears up, leans its hands on the top and looks over: from
    the clearing, a gaunt figure over the wall with two pale eyes. It cannot reach in.
  - Its limbs as ways up (riding it over the walls) are not done: see below.
  - **Coyotes** (added 2026-10-18 at the user's request, "there should be a coyote, and coyote skinwalker as well"):
    real coyotes, lean and rangy, grizzled grey-tan with a cream throat and belly, big upright ears, yellow eyes, a
    bushy black-tipped tail carried low. Packs of three to five trot about the halls, sniff, stand and stare. Mostly
    skittish: seeing someone they shadow them at a distance (about 15 m), stopping to stare whenever they look round;
    now and then the pack breaks into its yip-howl chorus. Come close or run at one and it gallops off and slinks back.
    One alone, or a pair, never does more. Only a pack of three or more round someone **alone** (nobody else within
    12 m) grows bold over about seven seconds: they circle, closing in low and snarling, a yip as the warning, and
    after a couple of seconds of it the one behind you darts in and snaps. Turn on one and it backs off; run at one and
    the pack loses its nerve; running gets away (they close in slower than a run); a friend coming near ends it.
    After a snap the pack scatters and is not bold again for a while. Tame coyotes live in the clearing too
    (ClearingStyle "Wildlife"): they stare, yip and run off, and are never bold.
  - **Skinwalker** (the internet-horror figure, kept to horror fiction): something wearing a coyote's skin, hidden
    in one of the packs as one of them. Look closely: it is bigger, its joints bend the wrong ways, its eyes shine too
    much, it never joins the chorus, and when the coyotes run from you it does not: it stares. From round a corner it
    calls out to you, a voice made in code (a "hey?", a "hel-lo", a coyote's yip turned human; never anyone's real
    voice). Look straight at it from close, or walk up to it, and it stops pretending: it freezes, turns its head to
    you and rises (the warning, nearly two seconds) onto long gaunt legs, the hide hanging down its back, the coyote's
    head a mask over a pale human face; its pack scatters. Then it runs you down on all fours in bursts: down flat and
    a jerk of the head (the wind-up), a burst far faster than a sprint, then it stops dead, twitching. Bursts need a
    straight line to you; out of its sight it crawls after you slower than a run. Turn corners, get up high (it cannot
    climb: it stands under you and gives up) or get into the clearing (it will not follow). Lost, it goes back to its
    pack. The first ring has two coyote packs and one skinwalker hidden in one of them.
  - **Tripod** (the user: "a giant 3 legged tripod enemy like from war of the worlds"; then "the tripod legs should
    be more fluid, noodly"): a Martian fighting-machine far taller than the walls. A low cowl of weathered bronze
    plate some 60 m up, half lost in the mist, a pale eye glowing in the dark under its brow; three long, whippy legs
    of segmented metal that coil up as they lift, swing high over the walls and uncoil to plant in the halls with a
    boom that shakes the ground; cable tentacles and a clawed grasper hanging under it; a heat ray on a jointed arm;
    red weed trailing off it. It does not chase: it patrols round its ring in great slow strides (slower than a
    walk), its searchlight crossing the wall tops and sweeping slowly down one hall after another. Lit in the open
    for half a second, you are found: its horn sounds, a deep, distorted "ULLA" heard across the maze (the warning),
    its light stays on you and its hood turns to you. Near under it, its grasper uncoils high over you and comes down
    slowly; get away or out of its sight and it draws back, stay and its claws lift you away. Further off, its arm
    swings round and the emitter charges (about two and a half seconds: it glows brighter and its hum rises); then
    the ray comes down the hall at you from well up it and burns along it through where you stood, drifting after
    you only slowly. Step out of its line, into a side passage or a slot, under a ledge or behind a buttress, and it
    burns past, leaving a black scorch with a glowing seam and steam rising off it. The walls cut its light and its
    ray as they do its sight: against the near wall, under a ledge, in the ivy, you are hidden. One in a ring at
    most (it is huge); the first ring has one.
- How many of each a ring has is its style's rule (MazeStyle, "What hunts it"); the first ring has some of every
  kind. The dev panel puts any of them in ahead of you.
- None enters the clearing. Caught, a player is put back in the clearing. Once out, nobody is hunted.
- With friends, the room's maker runs them; everyone else sees copies.

## Who else is in the maze

Added 2026-10-18 at the user's request ("npc runners"): other boys in the maze, after the Gladers' Runners, run by
the computer. They are the same boy as the players, on the same controller and rig, in muted shirts no player has, so
they read as others but plainly the same kind of person. Each knows his own section (ring) and stays in it.

- **They run it.** They jog its halls from place to place, down the middle of the wide ones, and now and then climb
  some ivy to look about and come down again.
- **They are hunted.** Everything that hunts the maze hunts them as it would a player. They see it coming and sprint
  (as fast as a player's sprint, near enough) to where it cannot get first: the clearing best, or up ivy they will
  reach before it. Caught, a runner is struck down and is back in the clearing, sitting, as a caught player is; then
  he jogs out to his section again.
- **They draw hunters away.** Sprinting, a runner is loud: anything hunting that sees him near turns after him if he
  is nearer than what it was after, so one sprinting past pulls the pack off you. And one who sees a player hunted
  near him waves both arms over his head (no voice: gestures only) and the hunter takes after him instead; not
  often (half a minute between).
- **They lead.** Come up to one (a few metres, in sight) and he stops, faces you and beckons, then runs (not
  sprints, so you can keep up) for the gate out of his section; fall behind and he stops and
  beckons again; lose him and he gives up. At the gate he stands aside and points through it, and goes back to his
  running. He leads one section at a time, never all the way out: the next section's runners know theirs. Then he
  will not lead again for a while.
- **How many**: a ring's style says (MazeStyle, "Who else is in it"); two in each for now. Few, since each poses a whole
  boy, and none is posed when far from the camera.
- With friends, the room's maker runs them; everyone else sees copies driven by the same inputs, so they climb,
  sprint and gesture alike.
## Wildlife

Not everything that lives here hunts (added 2026-10-18: "there should be non hostile regular deer and elk"). Herds of
ordinary white-tailed deer (a buck, does, spotted fawns) and of elk (a bull, cows, calves) graze out in the clearing's
meadow, towards its corners and the edges of the woods (never the middle where everyone wakes, nor the ways to the
gates), and a few stand in the halls. They graze and wander, lift their heads to watch you come, flick their ears
and tails, and run off when you come near (deer stotting a few bounds with their white tails up, then away at a
gallop; elk trotting, then galloping), and settle to graze where they stop; a bull bugles now and then far off. They
catch nobody and are nothing to be afraid of, which makes the ones that are wrong worse. How many: ClearingStyle and
MazeStyle, "Wildlife". Each machine runs its own copy from the round's seed, frightened by the same players, so they
agree.
## Wildlife

Not everything in the clearing and the maze is a threat. Added 2026-10-18 at the user's request ("there should be
non hostile regular deer and elk and chicken as well. Some should be in the clearing"):

- **Tame chickens**: ordinary farmyard hens and a rooster that forage, cluck and crow. Run through them and they
  scatter a few steps, squawking, and settle; walk near and they edge away. They never call the hunters and never mob.
  The clearing has a couple of flocks (ClearingStyle, "Wildlife"), the first pecking at the edge of the woods, all well
  away from the middle and the paths to the gates; a ring can have some in its halls too (MazeStyle, "Wildlife", none
  by default). Placed from the round's seed, so everyone in a room sees the same flocks.

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
- Climbing the colossus: its limbs, fur and stone as ways up, riding it over the walls (the ivy's `Ladder` would
  have to move with a bone, and the character controller does not carry a climber on a moving body).
- Reconnecting mid-round past the server's 90 seconds; a relay (TURN) server for voice behind strict networks.
- Whether the score should reward helping friends out.
