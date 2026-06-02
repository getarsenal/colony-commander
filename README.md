# Colony Commander

A faithful recreation of *Anthill: Tactical Trail Defense* (Image & Form, 2011) —
a pheromone-trail RTS / tower-defense hybrid. Built in **Godot 4.x** (GDScript),
per the project handoff.

> **Step 1 — trail-flow prototype** (handoff §4, §9): the make-or-break ant
> streaming. Proven first, on its own.
>
> **Step 2 — combat + carcass + harvest loop** (handoff §5): enemies assault the
> hill; Soldiers/Spitters fight along your trails; slain bugs drop carcasses that
> Workers haul home for food, which grows the colony. Built *on top of* the
> Step-1 streaming — fighting/harvesting happen wherever a trail's tip meets the action.
>
> **Step 3 — level flow + UI** (handoff §7, *now in*): a 6-wave level with a prep
> countdown and a **Call Wave** button (summon early), **Victory** on surviving
> all waves and **Defeat** if the hill falls (with Restart). Plus an Anthill-style
> HUD: hill-health bar, food counter, `Wave X / 6` with next-wave preview, and
> **speed (1×/2×) / pause** controls. Upgrade trees & biomes (§8+) are still ahead.

---

## Play on your phone (the target platform)

Colony Commander targets **mobile**, so the prototype ships with **on-screen
touch controls** and an automated **web (HTML5) build** you can open in a phone
browser — no app install.

- **Live URL:** once GitHub Pages is enabled for this repo, every push to `main`
  auto-deploys to **https://getarsenal.github.io/colony-commander/** via the
  `.github/workflows/deploy-web.yml` workflow.
- **Controls on touch:** a button bar at the bottom selects the caste
  (Worker / Soldier / Spitter) and toggles **Erase** / **Clear**. **Drag**
  anywhere to draw a trail (it always anchors at the hill); in Erase mode, tap a
  trail to remove it. The keyboard shortcuts below still work on desktop.
- The web build is exported with **thread support off** so it runs on GitHub
  Pages without cross-origin-isolation (COOP/COEP) headers.

> First deploy only: if Pages isn't enabled yet, the workflow tries to enable it
> automatically; if org policy blocks that, flip it on once under
> **Settings → Pages → Build and deployment → GitHub Actions**, then re-run the
> workflow.

---

## First time with Godot? Start here

1. **Install Godot 4.x** (the standard build, *not* the .NET/C# build — this
   project is pure GDScript). Download from <https://godotengine.org/download>.
   It's a single executable, no installer required.
2. **Open the project:** launch Godot → *Import* → navigate to this
   `colony-commander/` folder → select **`project.godot`** → *Import & Edit*.
3. **Run it:** press **F5** (or the ▶ "Play" button, top-right). The main scene
   (`scenes/Main.tscn`) launches in a 1280×720 window.
4. First launch will spend a second importing assets/icon — normal.

That's it. The whole scene is built from code at startup, so you don't need to
wire anything in the editor.

---

## Controls

| Input | Action |
|-------|--------|
| **1 / 2 / 3** | Select caste: **Worker** (blue, harvests) / **Soldier** (yellow, melee) / **Spitter** (red, ranged) |
| **Left-drag** | Draw a trail. It always anchors at the anthill, then routes to where you drag. |
| **E** | Toggle **erase mode** |
| **Right-click** | Erase the nearest trail (works in any mode) |
| **C** | Clear all trails |

Draw a few trails radiating out from the hill, switch castes, and watch the
colour-coded streams flow out, "work" at the tip, and stream back home. Erase a
busy trail mid-flow and watch the ants reroute home instead of freezing.

**Step 2 in play:** bugs crawl in from the edges toward your hill (its HP ring
shrinks if they bite it). Draw a **Soldier** or **Spitter** trail *into* the
swarm to hold a line — slain bugs leave **carcasses**. Then draw a **Worker**
trail onto those kills: workers grab the carcasses, haul them home, and bank
**food**, which raises your population cap.

**Level flow & HUD (Step 3):** the top bar shows hill health, food, and
`Wave X / 6` with the next wave's size and countdown. Tap **Call Wave** to
summon the next wave early, **1× / 2×** to fast-forward, and **Pause** to stop
the clock (the caste panel still works while paused). Survive all six waves to
**win**; if the hill's health hits zero it's **Defeat** — hit **Restart Level**
to try again.

---

## What to evaluate (the feel checklist — handoff §4)

This is the part *you* have to judge by running it — I can't see it from the
build environment. Ask yourself:

- [ ] **Streaming, not marching.** Does the column read as a living stream
  (staggered spawns + lateral sway), or a rigid conga line?
- [ ] **Congestion.** Do ants queue/bunch at the destination and behind each
  other, instead of overlapping perfectly?
- [ ] **Graceful redraw.** Erase a trail with ants on it — do they walk home
  smoothly (never freeze, never teleport)?
- [ ] **Performance.** Draw several long trails to push 300+ ants. Does the FPS
  counter (top-left) hold at/near 60?

If the streaming doesn't feel alive, that's the thing to iterate on **before**
building combat/harvest. All the feel knobs are constants at the top of
`sim/ant.gd` (`MIN_GAP`, `WIGGLE_AMP`, `WIGGLE_FREQ`, `WORK_TIME`) and
`sim/trail.gd` (`spawn_interval`) and `sim/colony.gd` (`POOL_SIZE`,
`DEFAULT_POP_CAP`).

---

## File map (matches handoff §4)

```
project.godot          # Godot project manifest
export_presets.cfg     # Web (HTML5) export preset — threads off for GitHub Pages
icon.svg               # app/window icon
scenes/Main.tscn       # trivial root scene -> main.gd builds everything
scenes/main.gd         # wires the slice, camera, hill-HP bar; routes HUD actions
scenes/terrain.gd      # static lush jungle floor + anthill mound (drawn once)
sim/ant_types.gd       # the 4 castes: colours, speeds, names (class AntTypes)
sim/ant.gd             # lightweight follower: progress, state, sway, spacing
sim/trail.gd           # Curve2D wrapper: draw, sample, spawn metering, erase
sim/colony.gd          # ant POOL, population cap, spawn budget, food stub
sim/trail_drawer.gd    # input -> Curve2D, caste colour coding, erase/redraw
sim/enemy.gd           # attacking bug: advances on the hill, fights ants (pooled)
sim/carcass.gd         # harvestable food dropped by a slain enemy (pooled)
sim/projectile.gd      # Spitter acid glob (pooled)
sim/wave_director.gd   # spawns enemy waves; owns enemy/carcass/projectile pools
fx/fx_layer.gd         # juice: puffs, floating "+food" popups, screen shake
fx/fx_bit.gd           # one throwaway puff/label flourish
ui/touch_controls.gd   # bottom caste / erase / clear panel for mobile + web
ui/caste_button.gd     # one tactile, icon-drawn control-panel button
ui/hud.gd              # HUD: Call-Wave / speed / pause buttons + win-lose overlay
ui/hud_topbar.gd       # top status bar: hill health, food, wave progress
.github/workflows/     # deploy-web.yml: export HTML5 + publish to GitHub Pages
data/                  # (empty — level/enemy/balance data lands in later steps)
assets/                # (empty — placeholder art/audio lands in step 2+)
```

## How the streaming works (quick tour)

- Ants are **not** pathfound. Each `Ant` tracks one float `dist` (pixels along
  its trail's baked `Curve2D`) plus a state machine
  (`OUTBOUND → WORKING → RETURNING`, or `FREE_RETURN` when its trail is erased).
- The `Colony` pre-builds a **pool** of ant nodes once and reuses them forever —
  never instantiate/free per spawn — to hit the 300+ @ 60fps target.
- **Streaming** = metered spawns (`Trail.spawn_interval`) + per-ant speed
  variation + a per-ant sine sway phase.
- **Congestion** = each ant clamps its `dist` behind the ant ahead
  (`MIN_GAP`), so columns naturally queue and bunch at the tip.
- **Graceful redraw** = erasing a trail calls `Ant.on_trail_removed()` on every
  ant on it, switching them to walk straight home.

---

## Moving this into its own repo

Colony Commander is a completely different game from the FIREBASE project that
currently shares this repository, so it belongs in its **own repo**. A Godot
project is just this folder of files — to relocate it:

1. Create the new empty GitHub repo (e.g. `getarsenal/colony-commander`).
2. Copy **the contents of this `colony-commander/` folder** into the new repo's
   **root** (so `project.godot` sits at the repo root).
3. Commit & push. The `.gitignore` here already excludes Godot's `.godot/`
   cache.

(Or, once the new repo is added to this session's scope, I can push it there
directly — just say the word.)

---

## Next steps (handoff build order)

2. Combat + carcass + **harvest loop** with a full juice pass (the beloved
   feature — §5).
3. Wave director + one full campaign level (vertical slice — §7).
4. Upgrade trees + food economy tuning (§8).
5+. Remaining campaign content, biomes, endless mode, audio/art polish.
