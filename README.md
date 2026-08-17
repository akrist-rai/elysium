# Hack The Plot

A top-down 2D RPG in **Odin + Raylib**, built in the shape of *Disco
Elysium*: 2d6 white and red skill checks with every modifier shown, 24 skills
that interrupt you as internal voices, passive checks you only hear when you
pass them, a Thought Cabinet, and Health/Morale instead of hit points.

It is set inside the world of [`../hacktheplot`](../hacktheplot) — the Next.js
CTF platform this repository already contained. That platform's own mechanics
are the case: the harmonic scoring curve is the motive, the audio-hint-with-
synced-transcript feature is the murder weapon, and the transaction wrapped
around `flagSubmit` is what froze the scoreboard.

> You wake on the floor of Server Room B at three in the morning. The TechHunt
> scoreboard has been frozen since 02:14. One contestant is face down on a desk
> and has not moved. The final flag was submitted eleven minutes ago by an
> account that was never registered. You have until dawn, and you cannot
> produce your own name on demand.

---

## Running it

### Linux

```bash
./tools/setup_odin.sh   # one time: fetches Odin, shims clang
./run.sh                # debug build and play
./run.sh --test         # headless logic + content checks, no window
./build.sh              # optimised build to build/hacktheplot
```

`setup_odin.sh` installs Odin to `~/.local/odin` and symlinks a bare `clang`
(Odin invokes `clang` to link; Ubuntu ships only versioned binaries). Fonts are
copied from the system DejaVu install by `tools/prepare_assets.sh`, which
`run.sh` and `build.sh` both call.

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup_odin.ps1
powershell -ExecutionPolicy Bypass -File run.ps1
powershell -ExecutionPolicy Bypass -File run.ps1 --test
powershell -ExecutionPolicy Bypass -File build.ps1
```

The build scripts pass `-linker:radlink` to use the linker Odin ships with, so
a full Visual Studio install is **not** required. Drop that flag if you have
the VS Build Tools and would rather use the system linker.

There is no font step on Windows — `assets/fonts/` is vendored in the
repository, and if a font file is ever missing the game falls back to raylib's
built-in one rather than failing.

> **Honesty note:** the Odin source is verified portable — `odin check` passes
> clean against `windows_amd64` and `darwin_arm64`, and there is not a single
> `ODIN_OS` guard, absolute path, or platform-specific call in `src/`. The
> PowerShell scripts, however, were written on Linux and have **not** been
> executed on a Windows machine. If they misbehave it will be in the setup
> plumbing, not the game.

### Platform support

| | Game code | Toolchain scripts |
|---|---|---|
| Linux x64 | built and played | tested |
| Windows x64 | `odin check` clean | written, untested |
| macOS arm64 | `odin check` clean | not written — use the Odin macOS release and the two `odin build` lines from `build.sh` |

**No system raylib is required on any platform.** The Odin distribution vendors
it: `vendor/raylib/linux/libraylib.so` on Linux, `windows/raylib.lib` linked
statically on Windows (so there is no DLL to ship next to the `.exe`), and
`macos/libraylib.a` on macOS.

The painterly shader targets GLSL `#version 330`, which is raylib's default
OpenGL 3.3 backend on all three platforms.

## Controls

| | |
|---|---|
| `W` `A` `S` `D`, arrows | walk. The camera follows you and leads where you are going |
| `E` | look at, or speak to, whatever you are standing next to |
| Scroll | zoom (world) / scroll the log (dialogue) |
| `1`–`9`, click | choose a dialogue option |
| `Space` | skip the typewriter, or continue |
| `Enter` | commit a check, then live with it |
| `Esc` | back out of a check *before* you roll; close a screen |
| `Tab` `C` `T` `J` `I` | skills, thoughts, journal, pockets |
| `F5` | hot-reload all content without losing the run |
| `F6` | toggle the painterly shader (useful for seeing what it does) |
| `F2` | save |

---

## The systems

**Skill checks** are the centre of it. Roll 2d6, add the skill, add every
situational modifier, compare to a target on the difficulty ladder (Trivial 6 →
Impossible 22). Snake eyes always fails and double six always succeeds, so
nothing is ever certain in either direction — `check_odds` enumerates all 36
outcomes exactly rather than approximating, and the number you are shown is the
number the dice are actually playing to.

Modifiers are carried as a *list with reasons*, never a bare integer, because
the popup itemises them. That is the whole point: you see `Interfacing 3`,
`+2 you found the badge`, `-1 researching The Harmonic Curve`, the target, and
the exact percentage, all before you commit.

**White checks** reopen the moment anything in your favour changes — a level, a
thought, an item, a fact you dug up. **Red checks** resolve once, permanently,
and every red check has an authored failure branch. Failing the case's climax
does not end the game; it changes who gets to say the thing.

**Passive checks** roll silently when you enter a node. Pass, and the skill
speaks in its own colour. Fail, and you never learn what you missed. They are
cached per node so two lines from the same voice never contradict each other.

**Thoughts** cost you something while you are working them out and pay once
you have adopted them. **Health and Morale** are separate ways to lose: one is
your body quitting, the other is you deciding you are not the person who solves
this.

## Content is data

All of the writing lives in `content/` and reloads with `F5` while the game is
running. Nothing about the story is compiled in.

`content/scenes/*.plot` — dialogue graphs:

```
:: the_body
SAY   Narrator | She is folded forward over the desk, the way people sleep in airports.
VOICE Half Light 9 | A body. It is a body. Leave the room, leave the building.
VOICE Empathy 11 | Nineteen hours. That is not a collapse, that is somebody letting go.
OPT   - | Check whether she is breathing. | body_breathing
OPT   Half Light 10 | Back away from the desk. | body_backaway | MORALE:-1

:: whiteboard_hand
CHECK Visual Calculus WHITE 10 +1:read_notebook | Compare it to the notebook. | hand_yes | hand_no
```

- `SAY <speaker> | <text>` — someone in the room says it
- `VOICE <Skill> <difficulty> | <text>` — a passive check; heard only on success
- `OPT <gate> | <text> | <target> [| effects]` — gate is `-`, or `<Skill> <n>`,
  or `IF:flag` / `NOT:flag` / `ITEM:id` / `THOUGHT:id` / `ONCE`, or a mix
- `CHECK <Skill> <WHITE|RED> <n> [+N:flag …] | <text> | <pass> | <fail> [| effects]`
- `SET` / `CLEAR` / `DO` — node-entry effects; `GOTO`; `END`
- Effects: `SET:` `CLEAR:` `HEALTH:` `MORALE:` `XP:` `ITEM:` `TAKEITEM:`
  `THOUGHT:` `TASK:` `TASKDONE:` `TASKFAIL:`

`content/world.defs` — thoughts, items and tasks in the same line-oriented
style. Skill names are matched case-insensitively with spaces, underscores and
slashes interchangeable, so `Esprit de Corps`, `Esprit_De_Corps` and
`esprit de corps` all resolve.

## Verifying it

`./run.sh --test` runs everything that does not need a GPU and is the fastest
way to know the game is not broken:

- the 2d6 distribution against hand-computed fractions, criticals in both
  directions, monotonicity in the bonus, and 40,000 live rolls against the
  stated odds
- white/red availability rules
- every `.plot` and `.defs` file parses, every jump target resolves, every
  effect names a thought/item/task that exists, no node dead-ends
- every orb in the room opens a node that exists; the whole graph is walked
- the case is completable: the accusation stays hidden until the evidence is
  in, the climax is a red check fed by seven pieces of evidence, and gathering
  them moves it from 8% to 97%
- hot reload preserves thought progress and world flags

There is also `--screenshot`, which drives the game through a fixed sequence and
captures each screen, so the visuals can be checked without a human present.

## Layout

```
src/
  stats.odin     24 skills, 4 attributes, Health/Morale
  check.odin     2d6 resolution, exact odds, modifier assembly
  dialogue.odin  graph runtime, conditions, effects, passives
  script.odin    .plot parser and validator
  defs.odin      .defs parser for thoughts/items/tasks
  tilemap.odin   the .map parser: one character per tile
  scene.odin     hangs lights, floor marks, people and interactables on the grid
  world.odin     WASD movement, collision, proximity interaction
  camera.odin    the follow camera
  nav.odin       A*, used by the one NPC who wanders
  render.odin painterly.odin    top-down passes + post pass
  ui_*.odin      dialogue panel, check popup, contextual prompts, sheets
  headless.odin  the --test harness
assets/shaders/painterly.fs     brush wobble, bloom, grade, grain
content/                        all of the writing, and the floor plan
```

The look is entirely procedural — there are no art assets for the world at all.
The room is drawn in three passes: the floor, then everything standing on it
sorted by where its base meets the ground, then a light map multiplied over the
top. Every light in the building comes from something you can see: a tube in the
ceiling, the face of a rack, a screen nobody switched off. Over that sits one
fragment shader that displaces sampling by fbm noise so edges wobble, blooms the
monitors, grades shadows cold and highlights sodium, and lays grain on top.

Two rules the renderer is built around, both learned the hard way:

- **Framing is defined in tiles, not pixels.** The camera derives its scale from
  the window height, so the same amount of room is on screen on a 900px laptop
  panel and a 1662px HiDPI one. A fixed pixels-per-tile just means a sharper
  display gets a smaller character.
- **Nothing that varies per tile may be a hard step.** Floor wear is sampled at
  tile *corners* and drawn as a gradient, so neighbours share their values
  exactly. A per-tile constant is invisible on its own, but the painterly pass
  preserves edges by design and will faithfully turn every one of those steps
  into a crisp line — which reads as graph paper.

## The floor plan is content too

`content/map.txt` is the building, one character per tile, and it reloads with
F5 along with the writing — you can rearrange the room without losing your run.

```
;   #  wall            X  doorway         @  player spawn
;   .  server floor    ,  corridor        :  office carpet
;   *  floor, with a fluorescent tube in the ceiling above it
;   R  server rack     D  desk            d  low workbench
;   c  chair           B  crates          =  shelving        ~  cable spool
;   P  printer         W  whiteboard      S  wall display    N  notice board
;   e  exit sign
```

`--test` treats it exactly like the writing: it has to parse, the spawn has to
be somewhere you can stand, every room has to be reachable on foot from where
you wake up, and every single interactable has to have somewhere to stand next
to it. A case whose evidence is behind a wall is as broken as one that jumps to
a node that does not exist.

## What is not in this pass

One location, one case. No second district, no day cycle across multiple days,
no full DE thought catalogue. Each of those is content or an additive system
against the existing engine rather than a rewrite.
