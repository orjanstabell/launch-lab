# Physics Slingshot

An Angry Birds–style slingshot game for learning mechanics. The bird's flight is
not simulated by a physics engine: every frame its position is computed straight
from the textbook formulas shown on screen,

```
x(t) = x₀ + v₀·cos(θ)·t        y(t) = y₀ + v₀·sin(θ)·t − ½·g·t²
```

so what the students read is exactly what runs. Change `g`, `v₀`, `θ`, `y₀` or `m`,
and the predicted path, the live numbers and the arrows on the bird change with it.

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

## Controls

| Key / mouse | What it does |
|---|---|
| **Space** | Launch a bird; mid-air, use its ability (split, rocket, egg, ...) |
| Drag the waiting bird | Aim and pull back; let go to launch |
| **R** | Reset the level |
| **P** / **F** | Pause / step one physics frame while paused |
| **S** | Slow motion: 1×, 0.5×, 0.25×, 0.1× |
| **Z** | Zoom: fit the whole arc, or follow the bird at 2× / 3× |
| **C** | Action cam: zoom in and slow down when a bird nears a pig (cycles forces, velocities, momentum, off) |
| **D** | Show the formulas and explanations over the sky |
| **1**–**7** | Tabs: Motion, Forces, Momentum, Energy, Practice, Levels, Editor |
| Right-click | Move the target for solve mode |
| **F11** / **Esc** | Fullscreen on / off |

Every button and setting has a tooltip.

## Ideas for a lecture

Each takes a minute or two. Pause (**P**) mid-flight whenever you want to discuss
the numbers.

| Idea | How to show it |
|---|---|
| The formula is the truth | **Motion**, press **D**. Launch, pause, and check `t`, `x`, `y` against `x(t)` and `y(t)` with the numbers filled in. |
| Mass cancels | **Forces**. Raise `m` from 1 to 5 kg: the force arrow grows, the acceleration stays `g`, the path doesn't move. |
| Two angles, one range | Level **Same range, two angles**, or **Solve for θ** in **Motion** (tick *high arc*). |
| Energy is conserved | **Energy**. Launch: KE turns into PE and back, the total line stays flat until the crash. |
| Explosions conserve momentum | **Blue** bird, **Momentum**. Split mid-air: the pieces' centre of mass stays on the old arc. Untick *Conserve momentum* to see what the real game does instead. |
| The rocket equation | **Rocket** bird, **Momentum**, press **D**: Δv = v_e·ln(m₀/m₁), and bird + exhaust together keep the momentum the bird alone would have had. |
| Recoil | **Matilda**, **Momentum**: throwing the egg down kicks her up by (m_egg/m)·u. |
| Newton's 3rd law in a collision | Action cam (**C**) on *forces*, or the *Last hit* arrows: the pushes on bird and pig are equal and opposite. |
| Mass matters at launch | Press *Spring launch*: v₀ = Δx·√(k/m), so a heavier bird leaves the same spring slower. |
| Measure g on another planet | Hide `g` (right-hand panel), press *Randomize*, then measure the range against the rulers. Or Practice → *Mystery planet*. |
| Let the class predict | **Practice**: pick a problem, let the students vote, then *Check* flies the shot with their answer next to what really happens. |

## Hiding values

The *Hide values* panel hides any quantity everywhere it appears (shown as `?`),
including numbers that would give it away: hiding `g` also hides `½·g` in
`y(t)`. *Predictions* hides the dotted path and the landing point, so students
can guess first. *Randomize* gives hidden launch values random numbers.

## Levels and sharing

The **Levels** tab plays the built-in levels (★) and your own. The **Editor**
tab builds the loaded level: click to place a piece, drag to move it,
right-click to delete it. *Save* also stores the current settings (launch
values, bird, hidden values, opening tab), so a saved level reproduces the
exercise. *Export…* writes a `.json` file you can hand out; students load it
with *Import…*.

## What is simplified

The flight is exact for the model below. The model is a simplification:

- No air resistance.
- The spring slingshot releases instantly and loses no energy.
- Collisions, blocks and pigs use Godot's rigid-body physics (60 steps per
  second). A bird follows the formulas until its first contact, then the engine
  takes over. Forces in a hit are measured as Δp/Δt over one physics step, so
  peak values depend on the step size.
- The world is 2D: a block's mass comes from its area (2 kg per m²).
- A pig is knocked out when it gets an impulse above 2.5 kg·m/s in one step
  (4 kg·m/s for the big pig, which survives one hit).
- A rocket pushes along the direction it was moving when it fired, and can burn
  at most 90% of the bird's mass.
- 1 m on screen is 50 pixels at normal zoom; the rulers show metres.

## How the code is organised

Everything is GDScript, and the scene is built from code (`scenes/main.gd`).

```
physics/kinematics.gd     the formulas: position/velocity at time t, range, apex,
                          time of flight, solvers, the rocket equation. Pure functions.
autoload/physics_params.gd  the values you edit, and the bird that's flying
autoload/reveal.gd        hiding values: every number on screen is formatted here
scenes/bird.gd            follows kinematics.gd while flying; abilities; the hand-over
                          to the physics engine on the first hit
scenes/bird_art.gd        how every bird looks (also drawn on the slingshot)
ui/topics/                one folder per tab: its dock panel, formulas and overlays
practice/problems/        one file per kind of practice problem
levels/                   level format, built-in levels, saving and loading
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

Inspired by Angry Birds (Rovio). The birds are drawn in code in that style; no
game assets are used. `PLAN.md` is the development log.
