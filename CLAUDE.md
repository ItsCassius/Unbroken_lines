# Unbroken_lines

A Godot project for a realistic-feeling racing game. Living status doc — keep
"Current state" and "Open work" up to date as the project progresses, not
just at the start. See `design_principles.md` for general Godot/game
architecture and process defaults.

## Current state

Foundation only — the seams exist, no real gameplay systems built on top of
them yet. Repo has:

- `.gitignore` (standard Godot 4 ignores)
- `LICENSE` — PolyForm Noncommercial 1.0.0 (open for anyone to use/modify/
  contribute for noncommercial purposes; commercial use is prohibited
  outright — chosen specifically so this can be open to contribution without
  risk of someone else monetizing it)
- `project.godot` — minimal, targets Godot 4.3, registers the `RaceManager`
  autoload. No `.tscn` scenes yet — see "Smoke test — verified" below.
- `tests/smoke/vertical_slice_smoke_test.gd` — headless integration smoke
  test, builds its scene in code, confirmed passing (see below).
- `scripts/core/` — the foundation, **not a claimable unit, owner-maintained**:
  - `race_manager.gd` — `RaceManager` autoload. Owns the
    `COUNTDOWN → RACING → FINISHED` state machine (§1) and the signals
    every other system hooks into: `checkpoint_passed`, `race_finished`,
    `state_changed`. Illegal transitions (e.g. a checkpoint reported before
    the race has started) are rejected, not silently accepted.
  - `drivable.gd` — the `Drivable` contract (§1a): a `RigidBody3D` base with
    `apply_input(steer, throttle, brake)` and a `crashed` signal. The
    vehicle-physics unit extends this; nothing else should reach into a
    car's internals.
  - `checkpoint.gd` — generic `Area3D` checkpoint trigger wired to
    `RaceManager`, so the track unit doesn't have to invent that wiring.
  - `dev_smoke_test_car.gd` — **temporary**, extends `Drivable` with crude
    forces and raw keyboard input, to be deleted once the real
    vehicle-physics and input units land. Proves the seam works; not
    production code.
- `scripts/{vehicle,track,camera,input,ui,audio,ai_opponents,save}/` —
  empty, genuinely claimable unit directories (see table below).
- `assets/{models,textures,audio}/` — empty, for non-code contributions
  (art/audio assets need no script access at all).
- This doc and `design_principles.md`

### Claimable work units — vertical slice

Scoped so each unit only touches its own path and talks to the rest only
through `RaceManager` signals or the `Drivable` contract above — see
design_principles.md §1a for why that's what makes non-overlapping claims
possible at all.

| Unit | Path | Talks to |
|---|---|---|
| Vehicle physics | `scripts/vehicle/*.gd` | extends `Drivable` only |
| Track/level | `scripts/track/*.gd` + track scenes | calls `RaceManager.report_checkpoint`/`finish_race` via `checkpoint.gd`, emits `surface_changed` (§3) |
| Camera feel | `scripts/camera/*.gd` | reads a `Drivable`'s public transform/speed only |
| Input mapping | `scripts/input/*.gd` | feeds a `Drivable.apply_input()`, nothing else |
| HUD/UI | `scripts/ui/*.gd` | `RaceManager` signals only |
| Menus | `scripts/ui/menus/*.gd` | mostly standalone |
| Audio | `scripts/audio/*.gd` | same shared signals as camera |
| Car/track art | `assets/**` | a scale/spec doc, no script access |

`scripts/ai_opponents/` and `scripts/save/` are intentionally deferred past
the vertical slice — single-player time-trial is the smaller slice to prove
the feel on first.

### Smoke test — verified ✅

`tests/smoke/vertical_slice_smoke_test.gd` builds the ground/car/checkpoint
entirely in code (no `.tscn` needed) and drives the placeholder car
straight ahead, asserting `RaceManager.race_finished` fires. **Run and
passing as of 2026-08-30** on Godot 4.3, confirming the
`RaceManager`/`Drivable`/`checkpoint.gd` seam genuinely works end to end
before any real unit builds on top of it.

Run it headless, no editor GUI or display required:

```sh
# One-time per fresh clone/engine version — builds the class_name cache
# (.godot/ is gitignored, so this is needed again after every fresh clone):
godot --headless --editor --quit-after 1

# The actual smoke test:
godot --headless --path . -s res://tests/smoke/vertical_slice_smoke_test.gd
```

Two non-obvious things this depends on, discovered getting it working on a
headless server with no Godot previously installed:

- A `-s` entrypoint script compiles *before* autoloads are registered as
  global identifiers, so it can't reference `RaceManager` by bare name —
  it fetches it via `get_root().get_node("RaceManager")` at runtime
  instead. Any future headless/CLI-run script needs the same workaround;
  scripts loaded normally at runtime (like `checkpoint.gd`) don't have this
  problem and can reference `RaceManager` directly.
- `class_name`-based types (`Drivable`) are invisible until the editor
  import step above has run at least once — without it you get "Could not
  find base class" errors that look like a real code bug but aren't.

A manual, in-editor version of the same check (useful once there's
something worth actually watching move) is: new 3D scene, a flat
`StaticBody3D` ground, a `RigidBody3D` with `dev_smoke_test_car.gd`
attached, an `Area3D` checkpoint with `checkpoint.gd` attached
(`is_finish_line = true`), call `RaceManager.start_race()` on scene
`_ready()`, then run with F6 — arrow keys should move the car.

## Publishing to VibeOasis (vibeoasis.io)

Intent: put this project up on vibeoasis.io. It's **not** a game-hosting or
showcase site — it's a coordination layer for pointing coding agents (or
other contributors) at a GitHub repo. Code and PRs stay entirely on GitHub;
VibeOasis only stores coordination state (who's working on what, what's been
merged). Key mechanics, since they shape how this repo should be structured:

- **Publishing requires a linked GitHub account** — ownership is verified via
  GitHub, so the repo needs to be reachable there (it already is:
  `github.com/ItsCassius/Unbroken_lines`). The publish form needs: repo URL,
  title, a **pitch** (what the project is, what state it's in, what you're
  stuck on — this should basically mirror "Current state"/"Open work" below),
  a license, and optionally type/genre/language tags and an image URL (any
  externally-hosted screenshot/logo link).
- **Work is broken into "work units"** on the project page after publishing —
  each one scoped to a set of file-path globs (e.g. `scripts/vehicle/*.gd`).
  A path needs "a real starting point" — a bare `*` isn't allowed, and a
  claim whose paths could touch an already-claimed unit's paths gets
  refused. **This is why the directory-per-system layout and
  interface/singleton discipline in `design_principles.md` §1a matter here
  specifically** — units can only be carved out cleanly (vehicle physics vs.
  AI opponents vs. UI vs. save system, etc.) if those systems don't bleed
  into each other's files.
- **Claims are 24-hour leases** — an agent that goes quiet loses the claim
  and it reopens automatically. No action needed on this repo's side for
  that.
- **Nothing merges automatically.** Contributors (human or agent) open
  regular GitHub PRs against declared paths; the project owner reviews and
  merges (or doesn't) same as any other PR, then manually marks the work
  unit "merged" on VibeOasis to record it. Keep PRs scoped tightly to a
  unit's declared paths so they're actually reviewable in isolation.
- **Agent tokens** are minted per-account under VibeOasis account settings
  and shown once — that's a VibeOasis account concern, not something this
  repo needs to store or configure.

### Before publishing, worth having in place

- ~~A license file~~ — done, see above.
- ~~At least a minimal `project.godot` + directory skeleton~~ — done. The
  foundation (`scripts/core/`) is real code now too; the 8 vertical-slice
  units above are genuinely claimable as soon as the smoke test confirms
  the seam works.
- A screenshot or logo once there's anything visual worth showing — not
  required to publish, but "worth doing" per VibeOasis's own guidance since
  it's what makes the project recognizable in the feed.

## Open work

- [x] Verify the RaceManager/Drivable/checkpoint seam actually works —
      done, see "Smoke test — verified" above.
- [ ] Publish the 8 vertical-slice work units listed above (or start
      claiming/building them directly) now that the foundation is real and
      confirmed working.
- [ ] Write the actual VibeOasis pitch text — it should mirror this file's
      "Current state" and open blockers, and can now honestly say the
      foundation is tested and working, not just present.
