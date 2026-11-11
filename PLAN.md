# Physics Slingshot — Project Plan

A slingshot game built as a **physics learning tool** (it began as an Angry Birds–style prototype; since 2026-11-12 it has its own look and names, see the end of this log). You edit the parameters in the ball's
motion formula, stage the changes, and they only take effect when you press **Activate**.

## Decisions so far

- **Engine:** Godot `4.7.2.stable.mono.official` (binary: `~/.local/bin/godot`)
- **Language:** GDScript. The mono build runs GDScript fine, and skipping C# means no dotnet build step.
- **Renderer:** GL Compatibility, 1920×1080 (same as `suika/`)
- **Scope v1:** pure kinematics. It doesn't need polish: use simple shapes, or sprites from `~/gamedev/kenney`.
- **Later:** energy (kinetic, potential, spring), then drag and collisions.
- **Workflow:** Claude Code in VS Code, Godot editor open alongside for play-testing (F5).
  Claude checks errors with `godot --headless --path . --quit-after 120`; the user checks game feel.
- **Effort:** high for Phase 1 (core architecture and physics), medium for later phases.

## Core idea: the formula must be the truth

The bird is **not** a `RigidBody2D` while in flight. Its position comes straight from the formulas shown on
screen, so what you read is exactly what runs:

```
x(t) = x₀ + v₀·cos(θ)·t
y(t) = y₀ + v₀·sin(θ)·t − ½·g·t²
vx(t) = v₀·cos(θ)
vy(t) = v₀·sin(θ) − g·t
```

- Compute it analytically from `t` rather than with an Euler step, so it's exact and has no drift.
- Units: use **meters** internally with a fixed `PIXELS_PER_METER` (e.g. 50), so `g = 9.81` means something real.
- Godot's y-axis points down, so flip y only at the render step.
- When the bird hits something, switch it to a `RigidBody2D` (or hand its velocity over to one), so blocks and pigs
  can still use Godot physics for the destruction.

## Launch parameters + Activate ability

| Parameter | Symbol | Default | Range |
|---|---|---|---|
| Gravity | `g` | 9.81 m/s² | 0 – 30 |
| Launch speed | `v₀` | 15 m/s | 1 – 40 |
| Launch angle | `θ` | 45° | 0 – 90 |
| Launch height | `y₀` | 0 m | 0 – 10 |
| Mass | `m` | 1 kg | 0.1 – 10 (no effect on pure kinematics; that's a lesson in itself, and it matters later for energy) |

- **Launch column**: the values the next bird starts with. Edits apply straight away, no extra button.
- **On Activate column** (set up *before* launch): a modular "yellow bird ability". Tick which of `g`, `v₀`, `θ`, `m`
  it changes and set the new values; press **Space** mid-air to use it. The bird starts a **new formula segment**
  from where it is: new `v₀` = new speed in the same direction, new `θ` = new direction at the same speed (−90°…90°,
  so dives work), `v₀` = 0 = stop and drop; unticked values carry on unchanged. `y₀` is launch-only.
- In flight, a yellow dotted path shows where the ability would send the bird right now, so you can time it.
- **Bird types** (`scenes/bird_types.gd`) decide what Activate does, picked in the panel:
  - **Red**: no ability. **Yellow**: a *preset* for the On Activate column (speed boost: `v₀` = 30 m/s, same
    direction); picking it fills the column in, and you can still tweak it. **Custom**: the free-form column.
  - **Blue**: splits into 2–5 pieces fanned ±spread around the heading, each with m/n. **Conserve momentum** (on by
    default) speeds the pieces up to `v' = n·v / Σcos(αᵢ)` so total p is unchanged; off = the real game (v' = v,
    momentum lost). With p conserved, the pieces' center of mass stays exactly on the unsplit arc (tested to 1e-6 m),
    and KE goes *up* (the split adds energy, like an explosion). Splits once; the extra pieces are new `Bird`s.
  - Abilities have unlimited uses for change-birds; could become one use per flight later.
  *(Changed 2026-10-16: "stage then Activate" → "edit mid-air then Activate" → pre-set ability → bird presets.)*
- **Lock / solve mode** (Phase 2): lock one value and pick a target (e.g. distance to the pig). The tool solves
  for the unknown, e.g. `v₀ = sqrt(g·R / sin(2θ))` when the bird lands at its launch height.
- Store all of this in **one autoload** (`PhysicsParams.gd`): launch values, ability values + which are ticked,
  the current bird, and the signals `values_changed` / `flight_changed`. Everything else reads from it.

## Screen layout

Inspired by city builders' bottom bars: the **sky stays free**. All panels sit in a dock "under the ground" (bottom
340 px): topic tabs + the topic's compact live numbers | parameters + bird | sim controls + hide values. Key hints live
in tooltips. **Formulas** (button or D) floats the full formulas/explanations over the sky only when wanted (off by
default). Camera **Fit** (default) zooms out just enough to keep the whole predicted arc and the level on screen;
2×/3× follow the bird. Topic text uses fixed-width live numbers and grow-only panels, so nothing jitters.

## Topics: one idea on screen at a time

The screen's teaching content is split into **topics**, switched with tabs on the left (or number keys 1, 2, ...).
Each topic owns a panel on the left plus overlays drawn on the bird, each with its own on/off checkbox. The
trajectory, trail, parameter panel and sim controls are always visible.

- **1 Motion**: live readouts (formulas in the Formulas panel), solve mode, velocity arrows, angle arcs,
  apex & landing markers, the solve target
- **2 Forces**: gravity F = m·g, Newton's 2nd law a = F/m, "mass cancels"; F and a arrows side by side
- **3 Momentum**: p = m·v, Δp = F·Δt; blue bird split before/after (p, KE, conserved or % lost); arrows on the bird,
  each piece and moving pigs; center of mass vs. the unsplit bird
- **4 Energy**: KE/PE/E live, energy-vs-time graph, energy bar on the bird, spring energy, energy lost in hits
- **5 Practice**: random problems to solve yourself (see below)
- **6 Levels**: pick and play a level (★ built in, plus your saved ones); Load, Delete, Import
- **7 Editor**: edit the loaded level (editing is on while the tab is open): pieces, name, task, opening tab,
  big pig mass; Save, Save copy, Export, New
- To add a topic: a script that extends `Topic` + one entry in `main.gd`'s `topics` list

## Hiding values (work it out yourself)

A collapsible **Hide values** panel has a toggle per symbol (`g v₀ θ y₀ m t x y vx vy |v| F a`) plus **Predictions**
(the dotted path and the landing/flight-time/apex numbers). Hidden numbers show as `?` everywhere. All displays format
numbers through the `Reveal` autoload, listing what each number is made from, so hiding `g` also hides `½·g` in `y(t)`.
**Randomize hidden** gives hidden launch values random numbers, e.g. "find g by measuring the arc against the rulers".

## Zoom

**Z** / the Zoom button cycles 1×, 2×, 3×; the camera follows the bird. Overlays (arrows, labels, arcs) grow by
√zoom while the world grows by zoom, so they get clearer but stay on screen (`DrawUtil.size_factor`).

## Structure

```
physics-slingshot/
├── project.godot
├── autoload/
│   ├── physics_params.gd     # launch values, spring, bird type, ability, split, target, current bird, signals
│   └── reveal.gd             # hide values: every displayed number goes through Reveal.num()/live()
├── physics/                  # no nodes: pure, testable
│   ├── kinematics.gd         # position/velocity(t), apex, range, flight time, solvers, closest approach
│   ├── launch_params.gd      # one formula segment's numbers
│   ├── units.gd, layers.gd
├── scenes/
│   ├── main.tscn / main.gd   # builds world, level (from level_data), dock UI and topics from code
│   ├── bird.gd, bird_types.gd, slingshot.gd, block.gd, pig.gd, ground.gd, level_editor.gd
├── levels/                   # level.gd (data + capture/apply), level_presets.gd, level_store.gd (JSON files)
├── practice/                 # problem.gd (base), problem_types.gd (registry), problems/*.gd (one per kind)
├── ui/
│   ├── param_panel.gd, sim_controls.gd, hide_panel.gd, trail.gd, trajectory_preview.gd, draw_util.gd
│   └── topics/               # topic.gd, live_label.gd + motion/ forces/ momentum/ energy/ practice/ levels/
└── tests/test_kinematics.gd
```

Keep `kinematics.gd` free of nodes (static functions only), so it's easy to test and to extend later with energy.

## Practice tab (problems to solve yourself)

Tab **4 Practice**: pick a kind of problem (or **Random**: any topic / per topic), press **New problem**: random,
always-solvable values, rounded to nice numbers. The scene is set up for it (an empty world with the pigs to hit),
the parameter panel is locked, and whatever would give the answer away is hidden. Everything is put back when the
problem ends or you leave the tab.
- **Predict** problems: type a number, **Check** → the shot flies with your answer shown in the world, then ✓ / ✗
  plus what happened ("It landed 2.1 m beyond your flag"). See "Every answer is simulated" below.
- **Control** problems: type launch value(s), **Try it** → the bird flies once and is judged (hit / missed by X m).
- **Show solution** (only when asked): the answer, worked steps in the Formulas panel, the correct path in green.
- One small script per kind in `practice/problems/` (extends `practice/problem.gd`), listed in `practice/problem_types.gd`.
- Kinds so far: hit the target (v₀ / θ), hit with the top at H (v₀ + θ), **two pigs one bird** (v₀ + θ), **yellow bird:
  when to tap (g → 0)**, top as high as the range (θ = atan 4, any planet), predict range / apex / time, same range
  other angle, mystery planet (measure g), gravity's pull on planets, acceleration from F and m, blue split speed,
  split-in-two angle, momentum at the top. Inspired by the user's FYS100 problem sheets (ideas, not copies).
- Later: energy problems (Phase 3), difficulty levels, a score/streak, class levels that bundle a fixed set.

## Order of work (recommended, 2026-10-16)

1. ✅ Practice tab (above)
2. ✅ Phase 3: energy, spring slingshot, collisions (Energy topic + energy/spring problems), 2026-10-16
3. ✅ Phase 3½: sandbox + saved, named levels, 2026-10-16
4. Next ideas: see "Possible next steps" at the bottom

## Phases

### Phase 1 — playable kinematics prototype ✅ (built 2026-10-16)
1. Project setup, autoload, `kinematics.gd`
2. Ground, a slingshot point, and a bird that launches from the **current** params when you press Space or a Launch button
3. Parameter panel with pending/current values and Activate/Reset
4. Trajectory preview (predicted path) plus a trail of the actual path, so you can compare them
5. A few blocks and one pig (Godot physics) so there's something to hit
6. Formula readout showing live numbers, e.g. `y(t) = 0 + 10.6·t − 4.9·t²`

**Done when:** you can change `g` to 3, see it highlighted as pending, press Activate, watch the preview update,
then launch and see the bird follow that exact arc.

### Phase 2 — learning aids
- ✅ Velocity vector arrows (vx, vy, v) plus the gravity force F = m·g, drawn on the bird (while paused, or toggle with V)
- ✅ Slow motion (1× / 0.5× / 0.25× / 0.1×) and pause / step-frame
- ✅ Live readouts: t, x, y, vx, vy
- ✅ Angle arcs (toggle with A): θ of each segment, the bird's current direction, the ability's θ
- ✅ Hide values per symbol + Randomize hidden; zoom on the bird
- ✅ Bird types (red, yellow preset, blue split, custom) and the Momentum topic
- ✅ Markers at the apex and landing point with computed values
- ✅ Solve mode: pick the unknown (v₀, θ or g), the rest stay locked; hits the target point (right-click to move it,
  defaults to the pig on its tower). θ gives a low and a high arc. Solvers in `kinematics.gd`, tested.
- ✅ **Quiz me** (student answers first): the unknown and the predicted path are hidden; type an answer and press
  Try it: the level resets and the bird flies once with that value. Feedback is only ✓ Hit! / ✗ Missed by X m
  (+ "passed above/below the target", or "right path, but something was in the way"), with an attempt count.
  The correct value, % off and the correct path appear **only when Show answer is pressed**. Either θ arc counts.
  Good base for class levels later (a level could start in quiz mode, maybe limit attempts or disable Show answer).
- ✅ Dock layout, Formulas toggle, Fit camera
- **Phase 2 done (2026-10-16).**

### Phase 3 — energy, spring slingshot, collisions ✅ (built 2026-10-16, except where noted)
Done: **4 Energy** topic (KE/PE/E live, E-vs-time graph in the dock, stacked energy bar on the bird with the
launch-energy line; E constant in flight, tested to 1e-5 J). **Spring launch** toggle (k, Δx; v₀ = Δx·√(k/m), mass
matters; Hooke's law + spring force arrow in Forces; ½kΔx² → ½mv₀² in Energy; Reveal/Randomize cover k and Δx).
**Drag to aim**: grab the waiting bird, pull back (angle + Δx, or v₀ in speed mode), let go to launch. **Collision
snapshot**: bird hits a pig/block → p and KE of both just before and just after (once the push registers); the
Momentum topic says honestly whether Σp was conserved or an outside push (plank/ground) changed it (a clean g = 0
sideways hit keeps Σp to 0.3%). **6 energy/spring practice problems**.
Not done: spring efficiency factor / simulated release (release is instant and lossless); pig death by impact
energy (kept the Δp rule, which works and matches "impulse").

Original notes:
- `KE = ½·m·v²`, `PE = m·g·h`, `E = KE + PE` (should stay constant in flight, which is a great check)
- Live energy bar or graph over time, as the **Energy topic** (see Topics above); blue split shows the KE jump
- **Spring slingshot** (launch mode toggle: "set v₀ directly" or "spring"):
  - Parameters `k` (spring constant, N/m) and pull distance `x` (m); `v₀` becomes an *output*:
    `½·k·x² = ½·m·v₀²` → `v₀ = x·√(k/m)`. Drag back on the slingshot to set `x` and `θ`.
  - Big lesson: **mass finally matters**: same pull, heavier bird → slower launch, shorter arc. A nice contrast
    with "mass cancels" in flight (Forces topic).
  - Forces topic during the pull/release: `F = −k·x` (Hooke's law), arrow shrinking as the band relaxes.
    Optionally simulate the release itself (`a = −k·x/m`, very short), or treat it as instant energy transfer.
  - Energy topic: elastic PE `½·k·x²` → KE at release; optional efficiency factor (real bands lose energy).
  - Hide/Randomize works with `k` too: "find the spring constant from the range".
- **Collisions with vectors on both objects** (user request): when the bird hits a pig (or block), show arrows on
  *both* (p, and later KE). A collision snapshot freezes the moment: p and KE of each just before and just after,
  Σp before vs. after (conserved up to the time the contact lasts; ground/friction are outside forces), and the KE
  lost to deformation/heat (inelastic). Needs velocities from the frame before contact (keep a short history).
  Live momentum arrows on pigs already exist in the Momentum topic.
- Problem ideas for Practice (inspired by the user's FYS100 sheets): max height from energy (½mv² = mgh, also
  straight up vs. at an angle); spring pushes two masses apart (momentum + elastic energy); spring slingshot:
  find k from the range, or the pull x for a target; pogo-stick style energy bookkeeping (KE, PE_grav, PE_spring
  at the top, the bottom, the equilibrium point); elastic collision of two pucks/birds at ±θ.
- Impact energy decides whether a pig dies (instead of the current rule: Δp = m·Δv > 2.5 kg·m/s in one physics
  step, measured from the pig's own velocity, since Godot 2D's reported contact impulses proved unreliable)

### Phase 3½ — sandbox and levels ✅ (built 2026-10-16)
Done: **6 Levels** tab. Levels are plain Dictionaries / JSON (`levels/level.gd`): name, task text, blocks, pigs,
launch values, launch mode + spring, bird + ability + split settings, hidden values (+ randomize), solve target,
which tab it opens on. Saved in `user://levels/` (`levels/level_store.gd`): Load, New, Save (renames a loaded saved
level), Copy, Delete, Export…/Import… (.json anywhere, e.g. to hand out to a class). The task shows as a banner over
the sky. **Sandbox editing**: pick box / big box / post / plank / wall / pig, click to place (drops onto whatever is
below, snapped to 0.1 m), drag to move, right-click to delete; pieces are frozen while editing. **8 presets**
(`levels/level_presets.gd`): Tower, Moon gravity, Same range two angles, Find the hidden g, High arc only, Three
pigs one blue bird, Spring heavy bird, Yellow bird straight shot. Each one was checked by planning a shot with the
solvers and flying it in the real level until every pig went down. Pig counter: "Pig down! 2 to go" / "All pigs down!".
Not done: rotating pieces, a separate main menu (the Levels tab covers it), levels that bundle practice problems,
attempt limits / scores for class use.

Original notes:
- **Sandbox mode / level editor**: place, move, rotate and delete blocks (choose size/material) and pigs; move the
  slingshot; set the level's `g`; maybe targets/markers ("land here") for exercises. Simple: click a palette item,
  click to place, drag to move, right-click to delete, snap to a 0.5 m grid.
- **Save, name and load levels** so they can be prepared ahead of time, e.g. for a class:
  - Each level has a **name** and an optional **description / task text** shown to the student when it loads
    ("Hit the pig using g = 3. What angle works?").
  - Saved as small JSON files in `user://levels/` (one file per level, file name from the level name); a level
    list to open, rename, duplicate and delete them.
  - **Export / import** a level file, so a teacher can hand a set of levels to students.
  - A level stores everything needed to reproduce the exercise: blocks, pigs, slingshot position, launch values,
    bird type and ability settings, hidden values (and whether they're randomized), the target, and which
    topic/overlays are shown.
- **Preset levels**, each built around one concept, loaded from the same format: e.g. "Moon gravity", "Same range,
  two angles", "Find the hidden g", "Thread the gap", "Split to hit three pigs" (blue bird), "Spring: heavy vs light".
  A level can also preset hidden values, the bird type and which topic is shown.
- Main menu / level select: Sandbox, Levels.

### Phase 4 — later ideas
- Air drag (`F = −½·ρ·C_d·A·v²`, numerical integration, compared with the no-drag arc)
- Restitution and friction on bounces
- Graphs: x(t), y(t), v(t)
- More bird types (heavy, light; ✅ red/yellow/blue/custom done)

## Notes for Claude

- Check `suika/` and `tower-defense/` for the user's existing GDScript conventions.
- Prefer building nodes from code over hand-writing large `.tscn` files.
- After each change, run headless and fix any script errors before handing over.
- Keep it simple and readable: the user is learning from this code too.


## Added 2026-10-17 (after play-testing feedback)

- Slingshot: launch angle −90°…90° (pull the bird up to aim down); the camera holds still while you drag; Fit
  zooms out at once but only back in when there's clearly room (no pumping); grab radius is fixed on screen.
- **Big pig** (3 kg default, mass set per level in the Editor): survives one hit (bandage), then dies. Pigs fade
  out instead of vanishing. A pig hit counts the pig's own Δp (ignoring what gravity alone or the ground alone
  does, so heavy pigs aren't "killed" by resting or falling) and, by Newton's 3rd law, the bird's Δp in the hit
  (catches squashing against the ground).
- **Impact overlay** (Forces + Momentum, "Last hit"): the hit frozen in place: impulse J = Δp on bird and pig,
  average force J/Δt, whether they were equal and opposite, measured elasticity and KE kept.
- **Elasticity e** (Momentum tab, saved with levels): the bird's bounce; pigs/ground have none, so a bird hit has
  exactly e. Measured e in the snapshot. Equal-mass head-on tests match theory: e = 1 keeps 100% KE, 0.5 → 62%, 0 → 50%.
- **Action cam** (sim controls, C cycles off / forces / velocities / momentum): each bird has a 2.5 m proximity
  sensor (Area2D); when it nears a pig the camera zooms in between them at 0.12× speed. Forces view: gravity and
  live contact force F = m·Δv/Δt − m·g on both (log-scale arrows, peak kept); velocities view; momentum view with
  Σp. A resting pig shows the normal force = m·g.
- **Rocket bird**: Activate fires along the heading: thrust F = v_e·ṁ, mass drops, Δv = v_e·ln(m₀/m₁). Exact closed
  form in Kinematics (rocket_speed / rocket_distance / after_burn), so the formula is still the truth. Fuel, v_e,
  burn rate in the panel; thrust arrow (Forces), rocket equation (Momentum). **Exhaust puffs** (30/s) with velocity
  arrows on every third (Momentum, "Rocket exhaust"); live check: bird + exhaust Σp ≈ the bird without a rocket.
  3 rocket practice problems. Yellow bird is drawn as a triangle.
- UI: Levels split into Levels (play) and Editor (build) tabs; compact tab names; narrower widgets so the dock
  fits; equal topic panel widths.
- Tests: `tests/run_all.sh` runs tests/test_kinematics.gd + every scenario in `tests/scenarios/` headless.

## Added 2026-10-17 (later)

- Birds redrawn in the style of the classic ones (user's reference images): red (unibrow, spots), yellow (upright
  triangle), blue (big eyes, cheeks), rocket (orange, with a real rocket strapped on: flame from the nozzle), custom.
- Space uses the ability only if the flying bird still has one, otherwise launches the next bird (a rocket bird
  far off-screen no longer blocks launching). Dragging from a ground-level launch point can't aim below horizontal.
- **Matilda** (white egg bird): throws an egg straight down; momentum conserved, so she recoils up by (m_egg/m)·u
  and the egg gets (m_bird/m)·u downwards; the pair's center of mass stays on the old arc. Egg mass and throw speed
  in the panel; the yellow preview shows where the egg would go (it keeps her forward speed). Shares the split code
  (Bird._break_up). Matches the wiki apart from the egg exploding (left out for now; could come with a Bomb bird).
  Practice problem "Matilda: the kick", preset level "Egg drop", scenario test tests/scenarios/matilda.gd.
- Other birds researched (not built): Terence (heavy: mass lesson), Silver (loop: circular motion a = v²/r),
  Hal (boomerang: constant sideways acceleration), Bomb (explosion: radial impulses), Bubbles (inflate).

## Added 2026-10-17: every answer is simulated

Play-testing: "I couldn't really see how my answer affected the sim." Now almost every problem flies on Check, and
your number becomes something you can see next to what really happens:
- **Flag / height line** at your answer: where it lands, highest point, energy: how high, heavy vs light.
- **Clock + dot**: time in the air (a running t on the bird; a dot on the path at your time).
- **Ghost birds** (see-through, keeping pace with the real bird, slow motion and pause included): the path your g /
  k / v₀ / force / acceleration / Matilda kick / rocket Δv / rocket fuel gives. A right answer's ghost flies exactly
  with the real bird; a wrong one parts ways. Other angle and heavy vs light: the first shot flies as a ghost.
- **Arrows** (yours yellow, real blue): speed at a height (where it crosses, going up and coming down), momentum at
  the top, weight / acceleration at the start of the drop test.
- **Splits use your number**: the blue bird splits at the top of its arc with your v' or α; the pieces' center of
  mass ✛ stays with the "no split" ghost only if momentum is conserved.
- Only "rocket acceleration at start and end" is still check-only.
- Framework: `Problem.ghosts()`, `Problem.outcome()`, marker types point/arrow/clock with "at" times,
  `show_com`; answers with a "key" set launch values for predict problems too (split_speed, split_spread);
  launch keys rocket_* / split_* / egg_*. `PracticePanel.sim_time` drives the overlay. Test:
  tests/scenarios/simulate_answers.gd (every predict kind, right and wrong answer).

## Added 2026-10-17: play-test fixes

- Pause freezes the rocket exhaust too; resetting the level (R) unpauses.
- Pigs get arrows: Forces → gravity + contact force (resting: the normal force, m·g up; a hit's peak push stays
  on screen for a second), Motion → velocity. Knocked-out pigs keep their arrows while they fade (group
  "all_pigs"), also in the action cam. Exhaust velocity arrows in Motion and Forces as well as Momentum.
- Tooltips on every button, checkbox and launch row (a test checks for missing ones). Overlay checkboxes wrap.
- Test: tests/scenarios/pause_and_overlays.gd.

## Added 2026-11-04: review before showing it in a lecture

- **README.md** for a teacher: running it, controls, lecture demo ideas, what the model simplifies, a code tour.
- Fixed: the Energy graph only recorded while its tab was open (empty after switching mid-flight); switching to
  Forces while paused showed resting pigs with gravity but no normal force; the Energy panel's LAST HIT section
  never appeared (wrong key); Solve for g at θ = 90° claimed g ≈ 0 worked; hidden fuel/mass/KE still showed in
  the Momentum text; a rounding error showed as "-0.00".
- The dock never leaves the screen any more (it did on the Practice tab, and on Forces with the spring or rocket):
  practice picker trimmed with "…", long dock lines split, and dock labels end in "…" instead of growing. Test:
  `tests/scenarios/dock_fits.gd` (every tab, bird, practice problem and level).
- Level files from Import… are checked: broken pieces and unknown settings are skipped instead of crashing.
- A 40 m/s bird vanished mid-air at x ≈ 77 m (birds were removed past 4000 px); now only past the ends of the
  ground. The dotted path runs to the end of the ground and draws the way down from very high arcs too.
- Clicking in the world ends typing in a number box (the value is applied and Space launches again).
- F11 fullscreen (Esc leaves it). The monospace font falls back to Consolas / Menlo on Windows / macOS. Own icon.
- Zero GDScript warnings in the editor (also with every warning treated as an error).
- Open question (settled 2026-11-12, see below): the "Yellow bird: when to tap" problem and the "Yellow bird:
  straight shot" level fly the purple Custom bird with g → 0, while the Yellow bird itself is the speed boost.

## Changed 2026-11-05: UI/UX redesign of the dock

- **Forces and Momentum are one tab, "Forces & momentum"** (they're one story: F changes p by Δp = F·Δt).
  The dock shows F, a and p together plus that link; each overlay exists once ("Last hit" was in both tabs
  with separate checkboxes). Tabs are now 1 Motion, 2 Forces & momentum, 3 Energy | 4 Practice, 5 Levels,
  6 Editor (a divider between the physics tabs and the activities); this supersedes the Topics list above.
  Level files are version 2; `Level.migrate()` moves a version 1 file's opening tab (tested).
- **One big button** in the right-hand column does what Space does right now (Launch / Boost / Split /
  Fire rocket / Drop egg), in the bird's colour; the Launch and Activate buttons are gone.
- **Less on screen**: Hide values is one button that opens the grid (the dock lists what's hidden); the
  On activate column only appears for the yellow and custom birds; "Rocket exhaust" only for the rocket.
  Elasticity moved next to the simulation controls (it changes the world in every tab). Formulas (D) is a
  sim button instead of looking like an 8th tab.
- **Help without hovering**: keys printed on the buttons ("Pause (P)"), H / Help shows every key and the
  mouse over the sky, and a first-launch hint ("Drag the bird to aim · Space to launch · H for help").
- **Look** (`ui/ui_theme.gd`): a calm, flat, dark instrument panel; anything selected or on is lit (light
  fill, dark text) instead of yellow, which now only means "ability"; text contrast ≥ 7:1 for projectors;
  bird buttons get a colour dot; visible empty checkboxes; Delete sits apart from Load, in red.
- World: pig force arrows use the action cam's log scale (the big pig's gravity arrow no longer ends under
  the dock); the split's "center of mass" / "unsplit bird" labels moved behind the marker; the level's
  name is big and its task under it.

## Changed 2026-11-12: own look, lecture cues, the miss in meters

From a design council (five roles, three rounds). In the code a ball is still a *bird* and a can a *pig*, and
the ids in level files are unchanged, so old files load; only what's on screen changed.

- **Own look and names** (`scenes/bird_types.gd`, `bird_art.gd`, `pig.gd`): Plain, Booster, Splitter, Dropper
  (drops Ballast), Rocket, Custom. Every ball is one round body with eyes at the front and a mark for its job
  (chevrons, a seam, ballast slung underneath, a rocket, dials); new colours. Targets are cans seen end-on (they
  roll, a stripe shows the spin); the big one is a drum that dents on the first hit. A knocked-out can crumples flat.
  All on-screen text and the README follow. This also settles the 2026-11-04 open question: the "Yellow bird"
  problem and level are now "Gravity off: when to tap" / "Gravity off: straight shot".
- **Every level load starts from the same state** (`Level.apply_settings`, `main.load_level`): settings a level
  doesn't mention get their defaults (before, "Egg drop" then "Tower" flew the egg bird at 17 m/s, 50°), and the
  view resets (speed 1×, Fit, no action cam, no formulas). Tested in `levels_and_editor.gd`.
- **The game opens on an empty range** (`LevelPresets.open_range()`), not on the tower. The Levels tab lists it first.
- **Lecture cues** (`LevelPresets.cues()`, `main.cue_key`): six levels that each ask one question. PageDown / PageUp
  (a presenter clicker's keys; ← → too) walk through them: asked big with lettered options and the prediction
  hidden → PageDown flies it → the reveal line (starting with the right letter) and everything hidden appear when
  the shot ends → PageDown loads the next. A cue is a level with optional keys `question`, `options`, `reveal`,
  `stop_at_apex`, `activate_at` (seconds or "apex"), `mark`, `reveal_on_key`; no format version change.
  Cues: mass and the arc · speed at the top (freezes itself at the apex) · two angles, one range · gravity off
  (Newton's first law) · split and center of mass · unknown planet (the reveal waits for PageDown).
  PageDown is ignored while a shot is in the air, and a second press within 250 ms is ignored.
- **Strobe trail** (`ui/trail.gd`, `Bird._fly`): a dot every 0.1 s of formula flight, on the same ticks as the
  white prediction dots. **Auto-stop**: `Bird.pause_at` pauses on the exact moment (only that much of the step is flown).
- **The miss, in meters** (`main._measure_miss`, `ui/shot_marks.gd`): a shot that comes down on the ground with
  cans standing gets "Missed by 1.8 m: landed short of the can." and a tape measure in the world from the path's
  closest point to that can. Not after hitting a block (the tower may still fall) and not for a split. The last
  can going down reports "All down in N shots."
- **Practice verdict** (`practice_panel.gd`): "✗ 9 % high · landed 2.1 m short of your flag" / "✓ Correct on
  call 2"; "Not quite", "try again" and the separate too-high/too-low hint are gone.
- Test: `tests/scenarios/cues.gd` (cues, strobe, auto-stop, miss).

## Possible next steps (not started)

- Class mode: a level that opens straight into a practice problem; limit attempts or hide Show solution; a score.
- Levels that bundle a set of practice problems (a "problem sheet" a teacher can hand out).
- Rotating level pieces; more materials (light/heavy blocks, glass that breaks).
- Air drag (Phase 4), restitution/bounces, x(t)/y(t)/v(t) graphs, more bird types.
- Spring efficiency (real bands lose energy) and a simulated release instead of an instant one.
