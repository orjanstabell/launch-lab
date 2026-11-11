# Physics Slingshot

A slingshot game for demonstrating and learning mechanics: launch a ball at a row
of cans. The ball's flight is not simulated by a physics engine: every frame its position is computed straight
from the textbook formulas shown on screen,

```
x(t) = x₀ + v₀·cos(θ)·t        y(t) = y₀ + v₀·sin(θ)·t − ½·g·t²
```

so what the students read is exactly what runs. Change `g`, `v₀`, `θ`, `y₀` or `m`,
and the predicted path, the live numbers and the arrows on the ball change with it.

It covers projectile motion, forces and Newton's 2nd law, momentum (explosions,
recoil, the rocket equation, collisions), and energy (KE, PE, a spring
slingshot), plus 27 kinds of practice problems with worked solutions and 9
built-in levels.

## Running it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build is
   enough; the project uses no C#).
2. In Godot: **Import**, pick `project.godot`, then press **F5**.
   From a terminal: `godot --path .` in this folder.
3. Press **F11** for fullscreen on a projector (**Esc** to leave it). The game
   is laid out for 1920×1080 and scales to any window.

## The web version

This copy of the project also runs in a browser. The ready-built game is in
`docs/` (`index.html` plus the engine, about 40 MB; browsers cache it after the
first visit).

- **Play it online:** <https://orjanstabell.github.io/launch-lab/>
- **Try it locally:** `python3 -m http.server -d docs 8000`, then open
  <http://localhost:8000>. Opening `index.html` directly from disk won't work.
- **Publish it on GitHub Pages:** push this repo to GitHub, then go to
  Settings → Pages and choose this branch with the `/docs` folder.
- **Rebuild it after a change:** export with the **standard** (non-.NET) Godot
  4.7, because .NET builds can't export to the web. In the editor, use
  Project → Export → Web → Export Project, or run this in a terminal:
  `godot --headless --export-release Web docs/index.html`. Thread support is
  off, so plain hosts like GitHub Pages work without special headers.

Differences from the desktop version:

- **Import…** and **Export…** use the browser's own upload and download
  windows.
- Saved levels stay in that browser, on that computer.
- The monospace font is bundled (`fonts/`, OFL licence), because a web page
  can't use the computer's installed fonts.
- Browsers only allow fullscreen after a click, so click the game once before
  pressing F11, or use the browser's own fullscreen.

## Controls

| Key / mouse | What it does |
|---|---|
| **Space** | Launch; mid-air, use the ability (boost, split, rocket, drop ballast, ...) |
| Drag the waiting ball | Aim and pull back; let go to launch |
| **PageDown** / **PageUp** | Lecture cues: next step / ask the same cue again (a presenter clicker's keys; ← → work too) |
| **R** | Reset the level |
| **P** / **F** | Pause / step one physics frame while paused |
| **S** | Slow motion: 1×, 0.5×, 0.25×, 0.1× |
| **Z** | Zoom: fit the whole arc, or follow the ball at 2× / 3× |
| **C** | Action cam: zoom in and slow down when a ball nears a can (cycles forces, velocities, momentum, off) |
| **D** | Show the formulas and explanations over the sky |
| **1**–**6** | Tabs: Motion, Forces & momentum, Energy, then Practice, Levels, Editor |
| **H** / **F1** | The keys and the mouse, over the sky (or the *Help* button) |
| Right-click | Move the target for solve mode |
| **F11** / **Esc** | Fullscreen on / off |

The big button in the right-hand column always does what **Space** would do
right now (*Launch*, *Split*, *Fire rocket*, ...), in the colour of that ball. The
other buttons show their key, e.g. *Pause (P)*, so the class can see what you
pressed. Every button and setting also has a tooltip.

## The balls and the cans

Every ball is a round body with eyes at the front; the mark on it says what it
does when you press **Space** mid-air.

| Ball | Mark | What it shows |
|---|---|---|
| **Plain** | none | A pure projectile: just x(t) and y(t). |
| **Booster** | chevrons | One push mid-air: a new speed, same direction (a new formula segment). |
| **Splitter** | a seam | Comes apart; momentum is conserved, so its center of mass keeps the old arc. |
| **Dropper** | ballast underneath | Drops its ballast straight down; the recoil kicks it up. |
| **Rocket** | a rocket on its back | The rocket equation: throws mass backwards to go forwards. |
| **Custom** | dials | Your own ability: pick what changes (g, speed, angle, mass). |

The targets are **cans**, seen end-on, so they roll (the stripe shows the spin). The
big one is a **drum**: the first hit dents it, the second knocks it out.

A shot that comes down without hitting leaves a tape measure from where its path came
closest to the nearest can, with the distance in big figures ("Missed by 1.8 m:
landed short of the can"). That distance is the number to beat; when the last can
goes, the message counts the shots. Every flight also leaves a dot every 0.1 s on its
trail, like a strobe photo: equal gaps sideways, growing gaps downwards.

## Lecture cues

The game opens on an empty range. **PageDown** (what a presenter clicker sends) walks
through six built-in questions, so a lecture needs no setup and no mouse:

1. the cue loads with its question and answer options big over the sky, and the
   predicted path hidden: the class votes by show of hands;
2. **PageDown** flies it (abilities fire by themselves; the *top of the arc* cue freezes
   itself there, and **PageDown** carries on);
3. when the shot is over, the answer appears as one line, starting with its letter, and
   the dotted prediction is drawn over the path the shot really took;
4. **PageDown** again loads the next cue. **PageUp** (or **R**) asks the same cue again.

| Cue | Question | What the class sees |
|---|---|---|
| Mass and the arc | 1 kg hits the can. Same launch, 5 kg? | The same arc; the force arrow is 5× as long. |
| Speed at the top | How fast is it at the top? | Frozen at the apex: only the vertical arrow is gone. |
| Two angles, one range | 30° hits the can. Does 60°? | It does: less speed across, more time in the air. |
| Gravity off | Gravity switches off here. Then what? | A straight line, with evenly spaced strobe dots. |
| Split and center of mass | It splits at the top. Where does the center go? | The center of mass stays on the old arc. |
| Unknown planet | Watch it land: which g? | g is hidden; **PageDown** reveals it after the class has worked it out. |

Every level load, cue or not, starts from the same state: default launch values unless
the level sets them, normal speed, Fit zoom, no action cam, no formulas. So a demo looks
the same whatever was on screen before it. The cues are also in the **Levels** tab (▶).

## Ideas for a lecture

Each takes a minute or two. Pause (**P**) mid-flight whenever you want to discuss
the numbers.

| Idea | How to show it |
|---|---|
| The formula is the truth | **Motion**, press **D**. Launch, pause, and check `t`, `x`, `y` against `x(t)` and `y(t)` with the numbers filled in. |
| Mass cancels | **Forces & momentum**. Raise `m` from 1 to 5 kg: the force arrow grows, the acceleration stays `g`, the path doesn't move. |
| Two angles, one range | Level **Same range, two angles**, or **Solve for θ** in **Motion** (tick *high arc*). |
| Energy is conserved | **Energy**. Launch: KE turns into PE and back, the total line stays flat until the crash. |
| Explosions conserve momentum | **Splitter**, **Forces & momentum**. Split mid-air: the pieces' center of mass stays on the old arc. Untick *Conserve momentum* to see what happens to it if the pieces just keep their speed. |
| The rocket equation | **Rocket**, **Forces & momentum**, press **D**: Δv = v_e·ln(m₀/m₁), and ball + exhaust together keep the momentum the ball alone would have had. |
| Recoil | **Dropper**, **Forces & momentum**: throwing the ballast down kicks it up by (m_ballast/m)·u. |
| Newton's 3rd law in a collision | Action cam (**C**) on *forces*, or the *Last hit* arrows: the pushes on ball and can are equal and opposite. |
| Mass matters at launch | Press *Spring launch*: v₀ = Δx·√(k/m), so a heavier ball leaves the same spring slower. |
| Measure g on another planet | *Hide values…* → `g` (right-hand column), press *Randomize*, then measure the range against the rulers. Or Practice → *Mystery planet*. |
| Let the class predict | **Practice**: pick a problem, let the students vote, then *Check* flies the shot with their answer next to what really happens. The verdict is a measurement ("✗ 9 % high · landed 2.1 m short of your flag") and says which call it was. |

## Hiding values

*Hide values…* (right-hand column) opens a toggle per quantity; next to the
button, the dock lists what is hidden. A hidden quantity shows as `?` everywhere,
including numbers that would give it away: hiding `g` also hides `½·g` in
`y(t)`. *Predictions* hides the dotted path and the landing point, so students
can guess first. *Randomize* gives hidden launch values random numbers.

## Levels and sharing

The **Levels** tab plays the built-in levels (★) and your own. *Random* builds a new level from small stable pieces (towers, pillars, walls, a pit), always with a clear shot to every can. The **Editor**
tab builds the loaded level: click to place a piece, drag to move it,
right-click to delete it. *Save* also stores the current settings (launch
values, ball, hidden values, opening tab), so a saved level reproduces the
exercise. *Export…* writes a `.json` file you can hand out; students load it
with *Import…*.

## What is simplified

The flight is exact for the model below. The model is a simplification:

- No air resistance.
- The spring slingshot releases instantly and loses no energy.
- Collisions, blocks and cans use Godot's rigid-body physics (60 steps per
  second). A ball follows the formulas until its first contact, then the engine
  takes over. Forces in a hit are measured as Δp/Δt over one physics step, so
  peak values depend on the step size.
- The world is 2D: a block's mass comes from its area (2 kg per m²).
- A can is knocked out when it gets an impulse above 2.5 kg·m/s in one step
  (4 kg·m/s for the drum, which survives one hit).
- A rocket pushes along the direction it was moving when it fired, and can burn
  at most 90% of the ball's mass.
- 1 m on screen is 50 pixels at normal zoom; the rulers show metres.

## How the code is organised

Everything is GDScript, and the scene is built from code (`scenes/main.gd`).

```
physics/kinematics.gd     the formulas: position/velocity at time t, range, apex,
                          time of flight, solvers, the rocket equation. Pure functions.
autoload/physics_params.gd  the values you edit, and the ball that's flying
autoload/reveal.gd        hiding values: every number on screen is formatted here
scenes/bird.gd            follows kinematics.gd while flying; abilities; the hand-over
                          to the physics engine on the first hit
scenes/bird_art.gd        how every ball looks (also drawn on the slingshot)
scenes/pig.gd             the cans and the drum
ui/shot_marks.gd          the miss as a tape measure; where a cue's ability will fire
ui/ui_theme.gd            how the dock looks: colours, buttons, the lit "on" state
ui/topics/                one folder per tab topic: its dock panel, formulas and overlays
practice/problems/        one file per kind of practice problem
levels/                   level format, built-in levels and lecture cues, saving and loading
tests/                    headless tests (see below)
```

To add a practice problem: write a script that extends `practice/problem.gd` and
list it in `practice/problem_types.gd`. To add a tab: extend `ui/topics/topic.gd`
and add it to the `topics` list in `scenes/main.gd`.

## Tests

```
tests/run_all.sh        # or: GODOT=/path/to/godot tests/run_all.sh -v
```

Runs every test headless (bash, so Linux or macOS): the formulas against
hand-worked answers, every practice problem (generated, answered right and wrong,
flown), every level (winnable, stable), energy and momentum bookkeeping, and the
screen layout (the panels fit at 1920×1080 in every tab).

---

Everything on screen is drawn in code; no outside assets are used. In the code, a
ball is still called a *bird* and a can a *pig* (the ids in level files are the
ones they have always had, so old level files keep loading). `PLAN.md` is the
development log.
