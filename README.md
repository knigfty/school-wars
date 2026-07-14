# School Wars

School Wars is a browser-first Godot 4 RTS prototype. Four colored student teams fight for territory on a floating, isometric diamond platform using mouse-driven squad control, stationary capture, close-contact combat, and territory-scaled reinforcements.

Play the current GitHub Pages build at [knigfty.github.io/school-wars](https://knigfty.github.io/school-wars/).

## Match rules

| Team | Starting point | Special trait |
| --- | --- | --- |
| Purple | North | Strong Attack: deals 40% more damage |
| Green | East | Fast Spawn: receives reinforcements 35% faster |
| Black | South | All-Rounder: 10% spawn, damage, and health bonuses plus 3 maximum health per takedown |
| Yellow | West | Takedown Growth: involved students gain 12 maximum health when an enemy is defeated |

- Each team begins with two students inside its colored base diamond.
- Twelve neutral white territory diamonds are placed randomly inside the arena each match.
- A student captures a tile by remaining stationary on it for 2.5 seconds. Moving students do not advance capture, and competing teams on the same tile pause capture.
- A captured tile changes to the capturing student's team color. Opponents can recapture it with the same stationary rule.
- Every team receives reinforcements only inside its own base.
- The base reinforcement interval is 14 seconds. Territory and team traits accelerate it according to `14 / ((1 + 0.35 × owned tiles) × team spawn multiplier)`, with a minimum interval of 3 seconds and a maximum of 30 students per team.
- Students collide only with other students and the invisible four-edge circumference, so they cannot leave the floating diamond.
- Enemy students automatically fight when they collide. Attacks use a per-student cooldown, team-adjusted damage, and visible health bars.
- A selected squad can pursue a specific enemy. Students who contributed damage receive their team's takedown benefit when that enemy is defeated.

## Controls

- **Select students:** left-click one student, or hold and drag the left mouse button around a group.
- **Direct selected students:** after selecting, left-click empty ground. The command system assigns formation slots so the group does not target one identical point.
- **Capture a square:** with students selected, left-click a territory diamond. The squad is ordered to the square's center and captures after stopping there.
- **Attack an enemy:** with students selected, left-click an enemy student. The squad pursues that target and attacks at contact range.
- **Pan the map:** hold and drag the right mouse button. Screen-edge panning and optional IJKL camera panning are also available.
- **Zoom:** use the mouse wheel. Maximum zoom-out fits the whole platform, including its visible depth.

Students never read keyboard movement input. There is no WASD or eight-direction control of an individual student.

## Run in Godot

1. Install Godot 4.3 or later and the matching Web export templates.
2. Open this folder in Godot.
3. Press **F5** to run the project.

The project uses the GL Compatibility renderer and a threadless Web preset for broad browser and static-hosting support.

## Run in a browser on localhost

With Godot installed, run:

```bash
./Tools/run_web.sh
```

On Windows, double-click `Tools/run_web.bat`, or run:

```powershell
python Tools/run_web.py
```

The launcher finds Godot, exports the project, verifies the HTML, JavaScript, WebAssembly, and PCK output, starts `http://localhost:8060`, and opens the browser. Set `GODOT_BIN` or pass `--godot` if Godot is not on `PATH`.

To run without installing Godot, download the `school-wars-web` artifact from a successful GitHub Actions run, extract it, and double-click its included `run_localhost.bat`. That package requires Python 3 but not Godot.

## Automatic deployment

`.github/workflows/deploy-pages.yml` performs a Godot Web export whenever `main` changes. It publishes the browser build to GitHub Pages and uploads the same output as a downloadable `school-wars-web` artifact. The repository's Pages source must remain set to **GitHub Actions**.

## Technical architecture

- `TeamDefinition` resources are the source of truth for team identity, color, trait labels, spawn rate, damage, starting health, and takedown growth.
- `StudentController` is a command-driven `CharacterBody2D` motor and combatant. It owns health, contact detection, target pursuit, attack cadence, damage contribution, takedown rewards, and combat feedback without reading player input.
- `SelectableComponent` exposes selection state. `UnitSelectionController` owns click and marquee selection in screen coordinates.
- `StudentMoveOrderComponent` drives a selected student toward a world destination. `UnitCommandController` distributes formation movement, territory-center, and explicit enemy-target orders.
- `RTSCameraController` owns right-drag and edge panning, pointer-centered wheel zoom, smoothing, and viewport-aware constraints.
- `FourSquareArena` renders the gray four-tip platform with directional top-edge lighting, asymmetric side faces, a deep lower rim, and a floating shadow. Four rotated invisible collision shapes form its circumference.
- `TerritoryField` uses a randomized seed to place neutral tiles within the diamond while enforcing tile spacing and base clearance.
- `TerritoryTile` is a monitoring `Area2D`. It filters overlapping bodies to stationary students, resolves team contention, records capture progress, and emits ownership changes.
- `TeamSpawnPoint` draws and validates each colored base diamond and provides only base-contained spawn slots.
- `TeamReinforcementSpawner` counts owned territories and live students per team, calculates the current interval, and instantiates new students at the matching team's base.
- `TeamStatusLabel` displays each team's territory count, current reinforcement interval, and trait.

## Automated checks

With a Godot executable on `PATH`, run:

```bash
godot --headless --path . --script res://Testing/run_movement_tests.gd
godot --headless --path . --script res://Testing/run_camera_tests.gd
godot --headless --path . --script res://Testing/run_selection_tests.gd
godot --headless --path . --script res://Testing/run_move_order_tests.gd
godot --headless --path . --script res://Testing/run_collision_tests.gd
godot --headless --path . --script res://Testing/run_map_tests.gd
godot --headless --path . --script res://Testing/run_territory_tests.gd
godot --headless --path . --script res://Testing/run_reinforcement_tests.gd
godot --headless --path . --script res://Testing/run_combat_tests.gd
```

Some installations name the executable `godot4`.

## Current scope

This prototype implements navigation, selection, constrained camera control, territory capture, combat, health, team traits, and reinforcement economy. Strategic AI orders, win conditions, sound, full sprite animation, and the reference title/team-selection screen remain future work.
