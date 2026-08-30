# Dev Directions — general principles for Godot/game projects

Living document. These are patterns worth starting with as defaults on any
new game project rather than rediscovering them. Add to this file whenever
the project surfaces a pattern that would've been useful to know on day one
— including patterns this first pass doesn't have real-world grounding for
yet.

## 1. Architecture & code quality (non-negotiable defaults)

- **Strict layering.** Domain/game logic (physics tuning, lap/scoring rules,
  AI decision logic, race-state transitions) must not know about the
  engine's node/scene-tree machinery. The `Node`/`_process`/
  `_physics_process` glue is the only layer allowed to know Godot's `Node`
  API exists — the actual rules should be readable as plain functions/classes
  over plain data.
  - **Corollary — this is what buys portability and testability.** Domain
    logic with zero engine imports can be driven headlessly in a unit test
    without booting the scene tree, and reused if the presentation layer
    ever changes shape. Decide up front whether that's actually needed —
    don't design for a hypothetical port — but if it is, get it right early;
    retrofitting it after engine types leak into game logic is expensive.
- **Prefer plain data structures and explicit interfaces over engine
  magic.** A contributor — human or agent — should be able to read the
  domain layer and understand the *rules* without knowing Godot.
- **Illegal states unrepresentable.** Model state so invalid combinations
  can't happen, not just "shouldn't happen." Use a discriminated union/enum
  for finite state (a race's `countdown → racing → finished` state; a
  vehicle's `grounded → airborne → wrecked` state) instead of a scatter of
  booleans/nullable fields that can contradict each other. Transitions
  return an explicit result (including a rejection case) rather than
  throwing or silently no-op'ing.
- **Functional where it clarifies, not dogmatically.** Pure functions for
  anything that's "given this data, compute that data" — lap-time math,
  scoring, steering-curve evaluation, tire-grip formulas — kept separate
  from the stateful node that calls them. This is what makes that logic
  unit-testable with no scene tree needed.
- **Composition over big "god" files.** A new car, a new track hazard, a new
  AI behavior should be additive — small modules at clear boundaries, not
  one giant vehicle/gamestate script that grows to know everything. See
  §1a — this also determines how cleanly work can be split into
  independent, non-overlapping chunks for outside contribution.
- **Detect conflicts, don't auto-resolve them.** When two systems both try
  to own the same piece of state, or a concurrent edit/merge conflicts,
  surface it clearly rather than silently letting one side win.
- **Single source of truth for live/mutable state.** One autoload/singleton
  owns any state that persists across scenes (race state, player
  progression, input-remap config); everything else reads through it rather
  than independently tracking the same thing. See §1a.
- **Confirm before anything destructive or hard-to-reverse**; give a cheap
  undo for anything that's just a misclick. Don't conflate "are you sure you
  want to delete your save" with "you clicked the wrong menu button."

## 1a. Game-engine specifics (Godot) — and why they matter for open contribution

Module boundaries aren't just good hygiene here — they're what makes it
possible to hand off a piece of work (to a teammate, or an agent claiming a
scoped set of files on a platform like VibeOasis) without it silently
depending on files outside that scope. A claim on `scripts/ai_opponents/*.gd`
needs to be completable without also touching `scripts/vehicle/*.gd` — that's
only true if the seam between those two systems is a real interface, not
incidental coupling.

- **Autoload singletons are the mechanism for "single source of truth."**
  Global, cross-scene state (race/session manager, input-remap config, save
  data, audio bus state) belongs in a small number of well-named autoloads
  — not duplicated into per-scene state that has to stay in sync by
  convention. Keep each autoload single-purpose; a `GameState` autoload that
  slowly accumulates every unrelated global is the same "god file" problem
  as a bloated script.
- **Interfaces are contracts, even without a formal `interface` keyword.**
  GDScript doesn't have one, so the contract has to be enforced by
  convention + `class_name` + documented method/signal names. E.g. every
  drivable thing implements `apply_input(steer, throttle, brake)` and emits
  a `crashed` signal; anything reading vehicle state calls that contract,
  never a specific car script's internals. Write the contract down next to
  the base class/interface script, not just in a comment on one
  implementation.
- **Signals over tight coupling.** Prefer a node emitting a signal
  (`race_finished`, `checkpoint_passed`) that other systems subscribe to,
  over one system reaching into another's internals or holding a direct
  reference it pokes every frame. This is what lets the UI/HUD, the
  save/progression system, and the AI opponents each live in their own
  claimable path without importing each other.
  - **Disconnect what you connect.** A signal connected from a node that
    gets freed (`queue_free()`'d) without disconnecting first is a common
    source of "callable on a freed object" errors and silent leaks. Prefer
    connections scoped to the emitting/receiving node's own lifetime
    (`CONNECT_ONE_SHOT` where appropriate, or explicit `disconnect` in
    `_exit_tree`) over long-lived cross-scene connections that outlive one
    side.
- **Resources for data, scripts for behavior.** Track configs, car
  stats/tuning curves, AI difficulty presets belong in `.tres` `Resource`
  files, not hardcoded inside behavior scripts. This splits "balance
  tuning" work (edit a Resource) from "logic" work (edit a script) into
  genuinely separate, non-overlapping claims, and lets tuning be iterated
  without touching code at all.
- **Composition over deep scene/script inheritance.** A 6-level inheritance
  chain for vehicle types means a change to the base class blows up every
  subclass at once. Prefer small components (a script per concern — engine
  model, tire model, input adapter) composed onto a node, over one script
  inheriting through several base classes.
- **Directory-per-system layout, chosen up front.** `scripts/vehicle/`,
  `scripts/ai_opponents/`, `scripts/track/`, `scripts/ui/`,
  `scripts/save/`, etc. — decided before the codebase grows organically —
  keeps future work scoped to meaningful paths instead of accidentally
  spanning unrelated systems.

## 2. Simulation vs. presentation

Racing-game feel and fairness both hinge on keeping "what actually happened"
separate from "what got drawn."

- **Physics runs on a fixed timestep, always.** Use `_physics_process`
  (Godot's fixed-rate callback) for anything that affects race outcome —
  vehicle motion, collision, lap/checkpoint detection — never
  `_process`(variable-rate) for these. Frame-rate-dependent physics means
  the game plays differently on a 60Hz vs. 144Hz display, and any recorded
  input/output (ghost replays, ranked times) becomes meaningless across
  machines.
- **Camera and visual smoothing live in `_process`, decoupled from the
  physics tick.** Interpolate the camera/visual transform between physics
  frames (Godot's physics interpolation, or manual lerp against the last two
  physics states) rather than snapping it to a fixed-timestep position —
  this is what avoids visible judder on high-refresh displays without
  touching simulation accuracy.
- **Decide determinism requirements early, not after a ghost-replay or
  leaderboard feature is half-built.** If ghost cars, replays, or
  competitive lap times are a goal, physics needs to be reproducible from a
  recorded input stream (same inputs → same outcome) — which constrains
  things like RNG usage (seed and record it, never call an unseeded random
  source inside the sim step) and float determinism across platforms. If
  that's not a goal, don't pay the cost of enforcing it — but write down
  which case this project is in, since it changes how replays/leaderboards
  get built later.

## 3. Sense of speed & tactile feedback

The target for this project is arcade realism in service of *felt* speed —
not sim-racing accuracy for its own sake. Grade every idea below against
that: does it make speed feel dangerous and physical, or is it just more
simulation detail nobody will notice. Most racing games undersell speed by
being too clean and too forgiving (wide roads, uniform asphalt, a rigidly
car-mounted camera) — the fixes below are mostly about removing that
smoothing, not adding effects on top of it.

- **Real-world road scale.** Narrow lanes, barriers close to the track edge,
  roadside objects (posts, walls, trees) sized and spaced like the real
  world, not gamified-wide. Track width should be data on the track
  Resource (§1a) that varies per segment, not a global constant — real roads
  narrow at technical sections and widen on straights, and that rhythm is
  itself part of the feel.
- **Road surface as data, not one material.** Per-segment surface type
  (fresh asphalt, patched/cracked asphalt, cobblestone, curb, gravel, wet)
  driven along the track spline, each with its own grip coefficient,
  suspension response, audio, and VFX. Single source of truth per §1a
  (Resource) with a `surface_changed` signal for anything reacting to it
  (audio, haptics, camera shake) to subscribe to — rather than every system
  independently re-deriving "what's under the car right now" (§1's
  conflict/duplication principle).
- **Physically simulated suspension, not a faked visual.** Real per-wheel
  suspension travel, compression/rebound, driven by actual wheel-ground
  contact and weight transfer is what makes body roll, dive-under-braking,
  and squat-under-acceleration read as real instead of a scripted lean.
  Keep this in the simulation layer (§2), and drive camera/visual bounce off
  the *actual* simulated chassis state — never a separate cosmetic fudge
  that can visibly disagree with what the car is doing underneath it.
- **Camera as a body in the car, not a rigid mount.** Model it as a
  lightweight spring-damper (or similarly lagged) system attached to the
  chassis, rather than parented 1:1 to the car's transform — a driver's head
  has its own inertia and slightly lags/overshoots chassis motion, which is
  what actually reads as "you're a body being thrown around" instead of
  "the camera is welded to the hood." Keep this feel-lag layer distinct
  from, and downstream of, the physics-interpolation smoothing in §2 — one
  fixes judder, the other is a deliberate feel choice.
- **FOV that widens with speed.** A well-worn but effective trick
  (Burnout/NFS/Forza Horizon-style) — increasing camera FOV as speed rises
  visually stretches the road and creates a tunneling effect. Tunable as a
  speed→FOV curve (Resource, §1a), not a hardcoded formula, so it can be
  tuned by feel rather than recompiled.
- **Foreground detail density near the road edge matters more than the
  speed number does.** Posts, barriers, and close trackside objects
  streaking past via motion parallax read as "fast" far more viscerally
  than a HUD readout — this is as much a track-authoring/dressing concern
  as a rendering one; leave room for it when laying out track edges.
- **Steering pull and self-aligning torque should come out of the tire/
  surface physics, not be scripted separately.** Pull under braking on a
  cambered or split-mu (mixed-grip, e.g. half-dry/half-wet) surface should
  be a natural output of a per-wheel slip/friction model reacting to real
  per-wheel surface data — not a hand-tuned "add torque when X" special
  case. This is also the value a force-feedback wheel peripheral would want
  to read from directly, if one is ever supported.
- **Off-line surfaces (dirt, gravel, standing water) should destabilize the
  car through the same grip model as the racing line**, not a separate
  "off-track penalty" hack — running wide should feel like reduced grip,
  never an invisible rule.
- **Audio and haptics driven off the same underlying physics values as
  everything else** (per-wheel slip, surface type, suspension compression,
  RPM) — engine note, road/tire noise, and controller rumble should all read
  off shared signals/state (§1a) rather than each independently
  re-simulating "what's happening to the car." This is also what keeps them
  from drifting out of sync with each other as the physics model evolves.
- **Be deliberate about stylized speed cues** (motion blur, speed lines,
  chromatic streaking) — valid tools for perceived speed, but they read as
  an artificial filter instead of physical speed when overused. Treat them
  as tunable, separately toggleable effects layered on top of the physical
  simulation above, never a substitute for it.

## 4. Input & controls

- **Read raw analog input, then apply a response curve — don't ship the raw
  value straight to the physics.** Steering/throttle from a controller stick
  or trigger needs a deadzone and (usually) a non-linear response curve
  tuned for feel; treat the curve itself as tunable data (see §1a Resources),
  not a hardcoded constant buried in the input-handling script.
- **Define control bindings as data (an `InputMap`-driven config), not
  hardcoded key/button checks scattered through gameplay scripts.** This is
  what makes remapping possible later without touching gameplay code, and
  keeps "which button does what" answerable from one place.
- **Support keyboard, controller, and (if relevant) wheel/pedals as
  first-class input sources from the start of input-handling work, even if
  only one is wired up initially** — retrofitting device abstraction after
  gameplay code assumes one input shape is disruptive. One `Drivable`-facing
  `apply_input(steer, throttle, brake)` call (§1a) fed by any device is the
  right shape.
- **Buffer input intentionally where it affects feel** (e.g. a brief grace
  window on a late brake/handbrake input around a tight corner) — but make
  the buffer window itself a tunable value, not a magic number picked once
  and forgotten.
- **Remapping and accessibility are cheap to build in from day one, expensive
  to retrofit** — once gameplay code reads `Input.is_action_pressed("steer_left")`
  against a data-driven action map instead of a raw key/button, remapping
  and colorblind-safe HUD palettes/assist toggles are additive UI work, not
  an architecture change.

## 5. Performance & allocation discipline

- **Avoid per-frame allocations in `_process`/`_physics_process`.** GDScript
  is garbage-collected; allocating new arrays/dictionaries/objects every
  physics tick (e.g. rebuilding a nearby-opponents list from scratch each
  frame) causes GC churn that shows up as stutter, especially with many
  vehicles/particles on screen. Reuse buffers, or pool objects that are
  created/destroyed frequently (impact particles, tire-smoke effects,
  transient AI queries).
- **Object pooling for anything spawned/freed at high frequency** — VFX,
  audio one-shots, transient collision shapes. `instantiate()`/`queue_free()`
  churn on a hot path is a common, fixable source of frame drops.
- **Profile before optimizing.** Godot's built-in profiler (and the
  physics/rendering frame-time breakdown) tells you where time actually
  goes; don't hand-optimize a guessed hot path — verify it's actually hot
  first.
- **Keep collision layers/masks intentional and documented.** An
  undocumented collision-layer scheme is a frequent source of "why did that
  hit register" bugs once more than a couple of layers exist (vehicle body,
  wheel raycasts, track surface, checkpoints, VFX-only triggers) — write
  down what each bit means, once, somewhere central (e.g. as constants in
  the relevant autoload).

## 6. Persistence & save data

- **Save-file format changes go through a forward-only version bump, never
  a silent format change.** Editing what a save file looks like without
  bumping a version field is fine only as an explicitly-flagged emergency
  measure during early prototyping — replace it with a real versioned
  migration before real player saves exist.
- **Write a round-trip test that loads a save from every prior format
  version through the current loader and asserts it upgrades cleanly** —
  the save-file equivalent of a database migration test. This is what
  actually proves old saves don't break on update, rather than trusting the
  migration code by inspection.
- **A save-format change and the code that depends on it ship together,
  same commit** — a version bump landing without the feature that needs it
  (or vice versa) means the code and the save schema silently disagree.
- **Separate "settings" (device bindings, graphics options, volume) from
  "progression" (unlocks, best times, campaign state) as distinct save
  blobs.** They change at different rates and have different stakes if
  corrupted — losing settings is an annoyance, losing progression is a much
  bigger deal — and keeping them separate means a settings-format change
  never risks progression data.

## 7. Asset & version-control hygiene

- **Set up Git LFS before binary assets accumulate, not after.** A racing
  game's meshes, textures, and audio are exactly the asset types that bloat
  a plain git repo and make history slow/huge to clone; track them via LFS
  (`.gitattributes` patterns for `*.png`, `*.wav`, `*.ogg`, `*.glb`/`.fbx`,
  etc.) from the point the first real asset lands, since converting
  existing history to LFS later is disruptive.
- **Never commit `.godot/` or `.import/`** — already covered by this
  project's `.gitignore`; these are regenerated caches, not source.
- **Treat `.tscn`/`.tres` as source, and expect merge conflicts in them.**
  They're text formats and diffable, but two people/agents editing the same
  scene concurrently will produce a real conflict — keep scenes scoped
  narrowly per system (per §1a) specifically to reduce how often two
  contributors touch the same `.tscn` at once.
- **`project.godot` and `export_presets.cfg` changes are easy to
  under-review** — a stray edit to global input maps or autoload
  registration in `project.godot` affects everything; call these out
  explicitly in PR descriptions rather than letting them ride along
  silently in an unrelated diff.

## 8. Anticipate organizational structure early

Grouping/folder concepts for a primary content type (tracks, cars, levels)
tend to arrive after the base content pipeline is built, and retrofitting
them is disruptive once real content exists. Worth planning for from the
start even if the tooling/UI is deferred:

- A `campaign`/`series` grouping field on a track or event, `null`/unset =
  ungrouped. Cheap to add early, expensive to retrofit once real content and
  UI exist.
- Start flat (no nested groupings) unless something already demonstrably
  needs a tree — don't build the general case speculatively.
- Don't offer two competing ways to do the same assignment (e.g. a
  campaign picker in a track-config Resource *and* a separate ordering file
  that can drift out of sync with it) — pick one mechanism.
- Settle the top-level content directory layout (`tracks/`, `vehicles/`,
  `levels/`) before content accumulates unsorted — see §1a/§7, same
  underlying reasoning.

## 9. Background execution / async & long-running work

- **Anything that must keep running independent of a single frame**
  (pathfinding, procedural generation, asset streaming) needs a real
  off-main-thread mechanism — a `Thread`, `call_deferred`, or Godot's async
  resource loading (`ResourceLoader.load_threaded_request`) — never a long
  synchronous call inside `_process`/`_physics_process` that blocks a frame.
- Structure it as: one thread/system owns the live state and the one thing
  that ticks it; callers only enqueue work or read status, they don't do the
  ticking themselves inline.
- Two-phase is a reasonable default: Phase 1 = the simplest async mechanism
  that covers the common case (a loading screen while a track streams in).
  Phase 2 = the rarer edge case (streaming a track *during* a race without a
  hitch) — genuinely more complex, fine to defer explicitly rather than
  build speculatively.
- **Throttle anything that would otherwise fire every frame** — autosave,
  telemetry, network state sync — bucket by a coarse interval instead.

## 10. Canonical value vs. display formatting

Store and compute in one canonical unit/format internally; convert only at
the display edge, never write a converted value back. Speed stored
internally as m/s (whatever the physics engine natively uses), converted to
mph/kph only at the HUD; lap/race time stored as a raw float in seconds,
formatted to `MM:SS.mmm` only at display. This prevents drift on repeated
edit/save cycles and means a units/format preference change (imperial vs.
metric HUD toggle) never requires touching stored data.

## 11. Sentinel values and defaults — document them explicitly

If a field uses a magic value to mean "not set" — a `-1` best-lap-time
meaning "no time set yet" vs. an actual `0.0`, or an empty vs. `null`
save-slot name — write down where that sentinel is checked and why, right
next to the field. Easy to reintroduce incorrectly if the convention isn't
written down somewhere obvious.

## 12. Testing strategy

- **Domain/game logic gets rigorous unit test coverage** — it's pure logic,
  cheap to test, and the highest-value place to catch regressions (lap
  timing math, scoring, steering/tire-model formulas, AI decision rules).
  [GUT](https://github.com/bitwes/Gut) is the default choice for this on
  Godot unless something specific rules it out.
- **Save persistence gets round-trip tests against real save data**, not
  hand-inspection — see §6.
- **Frame-rate-dependent physics and other genuinely
  environment-dependent behavior is not meaningfully unit-testable.** Say
  so explicitly rather than pretending a passing test suite proves it;
  verify manually, or via a fixed-timestep replay/regression harness if the
  project builds one (worth doing once §2's determinism question is
  answered "yes").
- **Don't build automated playtesting/gameplay-feel tests speculatively** —
  feel and balance need an actual human playtesting, not an assertion.
  Revisit automated coverage once there's a specific high-risk flow (save
  corruption, a scoring/leaderboard exploit) that justifies the cost.
- When a bug is root-caused, capture *why* in the regression test or nearby
  comment, not just the assertion.
- **Seed/demo content for manual review goes through the real loading path,
  not a hand-crafted save file or hardcoded test scene state** — same
  reasoning as round-trip testing above. Prefix any such test-only content
  unambiguously (`test-`) so it's trivially filterable.

## 13. Export & build pipeline

- **Version-control `export_presets.cfg` deliberately, not by accident.**
  It defines what platforms build and how; treat changes to it with the
  same scrutiny as a build-pipeline/CI config change, not as incidental
  churn.
- **Tag or version each exported build** (a build number or git short-SHA
  baked into a debug HUD/about screen) so a bug report against a built
  executable can be traced back to the exact commit — invaluable once
  builds start circulating for playtesting outside the dev machine.
- **Keep platform-specific export artifacts out of git** — exported
  binaries/packages are build output, not source; distribute them via
  itch.io/GitHub Releases/etc., not by committing them to the repo.

## 14. Process / how these docs get used

- Keep the project's own `CLAUDE.md` as a living status document, not a
  one-time brief — update "what's actually built," open findings, and
  what's explicitly deferred (and why) as you go. This matters more, not
  less, once outside contributors — including agents claiming scoped work
  off a platform like VibeOasis — are reading it cold to decide what to pick
  up; a stale "current state" section actively misleads a claim.
- When descoping something, write down *why* and what the fallback/upgrade
  path would be if the simpler version turns out to be insufficient.
- Distinguish "well-specified, low-ambiguity work that's safe to do
  autonomously" from "open-ended, visually/UX-subjective work that needs
  someone actually present to react to direction" (new gameplay feel, a new
  interaction pattern) — and only proceed autonomously on the former. This
  distinction is also exactly what determines whether a piece of work is
  safe to publish as an open, agent-claimable work unit versus something
  that needs the project owner directly.

## 15. Third-party API keys & secrets

Applies once/if the project has any third-party keys — a cloud leaderboard,
analytics, a backend for online features. Skip entirely for a purely
local/offline build with none of the above.

- **Never commit a real secret, ever, even briefly.** `.gitignore` the file
  that holds it before the first key goes in, not after. If one lands in
  git history anyway, treat it as compromised and rotate it immediately.
- **"The client can't keep a secret" applies to a compiled game binary too**
  — it can be decompiled/inspected same as a web bundle can be
  view-sourced. For keys that grant write access, spend real money, or gate
  paid features, keep them server-side only and put a backend endpoint in
  front of the third-party API. For keys the provider designs to be public,
  embedding is the intended usage — restrict scope instead.
- **Local secrets: gitignored `.env`/local config, not a hardcoded literal
  in source.** Commit a `.env.example` (or equivalent) with placeholders so
  a new contributor knows what's needed without ever seeing a real value.
- **Different keys per environment** — dev/staging keys for local dev and
  CI, production keys only in the deploy environment's secret store.
- **Restrict every key at the provider console to the narrowest scope that
  still works.** Set a usage/budget alert on anything metered.
- **Document which secrets a project needs in its `CLAUDE.md`, not the
  secrets themselves.**
