# Unbroken_lines

A Godot project for a realistic-feeling racing game. Living status doc — keep
"Current state" and "Open work" up to date as the project progresses, not
just at the start. See `design_principles.md` for general Godot/game
architecture and process defaults.

## Current state

Bare skeleton, no gameplay yet. Repo has:

- `.gitignore` (standard Godot 4 ignores)
- `LICENSE` — PolyForm Noncommercial 1.0.0 (open for anyone to use/modify/
  contribute for noncommercial purposes; commercial use is prohibited
  outright — chosen specifically so this can be open to contribution without
  risk of someone else monetizing it)
- `project.godot` — minimal, targets Godot 4.3, no scenes or gameplay code
  yet
- `scripts/{vehicle,track,ai_opponents,ui,save}/` — empty directory
  skeleton (per §1a/§8) so the first VibeOasis work units have real,
  non-overlapping paths to claim from day one
- This doc and `design_principles.md`

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
- ~~At least a minimal `project.godot` + directory skeleton~~ — done, see
  above. Still just empty folders — no actual scenes/gameplay code, so
  there isn't yet a meaningful work unit to publish.
- A screenshot or logo once there's anything visual worth showing — not
  required to publish, but "worth doing" per VibeOasis's own guidance since
  it's what makes the project recognizable in the feed.

## Open work

- [ ] Build out enough of a real vertical slice (one drivable car, one
      test track, a fixed-timestep physics loop per §2) that there's
      something concrete to demo in the VibeOasis pitch — right now the
      skeleton is directories, not gameplay.
- [ ] Decide initial work units to publish once there's real code/scenes to
      carve claims out of.
- [ ] Write the actual VibeOasis pitch text once the above exists — it
      should mirror this file's "Current state" and open blockers.
