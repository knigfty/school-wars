# School Wars

School Wars is a browser-first Godot 4 RTS prototype. Choose a school color from the launch menu, then fight three autonomous teams for territory on a floating isometric platform using mouse-driven squad control, stationary capture, close-contact combat, and territory-scaled reinforcements.

Play the current GitHub Pages build at [knigfty.github.io/school-wars](https://knigfty.github.io/school-wars/).

## Match rules

| Team | Starting point | Special trait |
| --- | --- | --- |
| Purple | North | 60 HP, 15 damage per second, 15-second base spawn, 10-unit cap |
| Green | East | 30 HP, 5 damage per second, 10-second base spawn, 15-unit cap |
| Black | South | 70 HP, 10 damage per second, 12-second base spawn, 12-unit cap, +10 HP per kill/assist |
| Yellow | West | 100 HP, 6 damage per second, 15-second base spawn, 10-unit cap, +20 HP per kill/assist |

- Each team begins with two students inside its colored base diamond.
- The three non-player colors use trait-specific strategies: Green favors expansion and defense, Purple hunts nearby enemies, Yellow prioritizes weakened enemies for takedowns, and Black balances expansion with nearby fights. AI squads can split between chasing a retreating enemy and holding captured territory.
- Twelve neutral white territory diamonds are placed randomly inside the arena each match.
- One student captures a tile by remaining stationary on it for 5 seconds. Every additional stationary ally on the same tile reduces the required time by 1 second, down to a 1-second floor. Moving students do not advance capture, and competing teams on the same tile pause capture.
- A captured tile changes to the capturing student's team color. Opponents can recapture it with the same stationary rule.
- Every team receives reinforcements only inside its own base.
- Purple and Yellow start with a 15-second reinforcement interval and cap at 10 students. Green starts at 10 seconds and caps at 15 students. Black starts at 12 seconds and caps at 12 students. Every captured non-base square subtracts exactly 1 second from that team's interval, with a 1-second safety floor.
- Students collide only with other students and the invisible four-edge circumference, so they cannot leave the floating diamond.
- Enemy students automatically fight one opposing student at a time when they collide. Damage is applied once per second at each team's listed rate and health bars remain visible.
- A selected squad can pursue a specific enemy. Students who contributed damage receive their team's takedown benefit when that enemy is defeated.
- A new movement order overrides combat and remains the student's priority until the destination is reached or the route is blocked. Units steer directly, separate from nearby teammates, and slow smoothly on arrival. Explicit attack orders still cancel movement and begin pursuit.
- A team is permanently eliminated as soon as its last student is killed, regardless of how many squares it owns. Its spawning stops and a four-second `<Color> has been eliminated` announcement appears. The player wins only after all three opponents are eliminated and loses immediately when their own team is eliminated.
- Victory and Defeat screens stop the finished simulation and provide a return button to start again from the color-selection menu.

## Controls

- **Choose a team:** select Black, Green, Yellow, or Purple from the launch menu. Only the chosen color is player-selectable during that match.
- **Select students:** left-click one student, or hold and drag the left mouse button around a group.
- **Direct selected students:** after selecting, left-click empty ground. Students steer smoothly toward individual formation slots so the group does not target one identical point.
- **Capture a square:** with students selected, left-click a territory diamond. The squad is ordered to the square's center and captures after stopping there.
- **Attack an enemy:** with students selected, left-click an enemy student. The squad pursues that target and attacks at contact range.
- **Pan the map:** hold and drag the right mouse button. Screen-edge panning and optional IJKL camera panning are also available.
- **Zoom:** use the mouse wheel. Maximum zoom-out fits the whole platform, including its visible depth.
- **Show controls:** click the round **?** button in the top-right to show the readable how-to-play panel; click it again to hide the panel.

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

- `GameFlowController` owns the menu → match → result → menu lifecycle. Matches are instantiated only after color selection and are disposed before returning to the menu.
- `GameMenu` draws the responsive reference-inspired title treatment, uniformed student portraits, four team cards, concise trait tooltips, and an animated team-color hover glow while real Button controls provide input.
- `HelpToggleButton` keeps the readable in-match instructions hidden until the player requests them from the round question-mark button.
- `TeamDefinition` resources are the source of truth for team identity, color, exact base spawn interval, unit cap, starting health, damage per second, and takedown growth.
- `StudentController` is a command-driven `CharacterBody2D` motor and combatant. It owns health, contact detection, target pursuit, attack cadence, damage contribution, takedown rewards, and combat feedback without reading player input.
- `SelectableComponent` exposes selection state. `UnitSelectionController` owns click and marquee selection in screen coordinates.
- `StudentMoveOrderComponent` provides direct steering, smooth arrival, and blocked-route cancellation. `StudentController` adds light teammate separation, while `UnitCommandController` distributes formation movement, territory-center, and explicit enemy-target orders.
- `RTSCameraController` owns right-drag and edge panning, pointer-centered wheel zoom, smoothing, and viewport-aware constraints.
- `FourSquareArena` renders the gray four-tip platform with directional top-edge lighting, a raised north bevel, asymmetric side faces, a deep lower rim, and a floating shadow. Four rotated invisible collision shapes form its circumference.
- `TerritoryField` uses a randomized seed to place neutral tiles within the diamond while enforcing tile spacing and base clearance.
- `TerritoryTile` is a monitoring `Area2D`. It filters overlapping bodies to stationary students, resolves team contention, counts allied capturers, applies the 5-to-1-second timing curve, records capture progress, and emits ownership changes.
- `TeamSpawnPoint` draws and validates each colored base diamond and provides only base-contained spawn slots.
- `TeamReinforcementSpawner` counts owned territories and live students per team, subtracts one second per tile from the team's base interval, enforces its individual unit cap, and instantiates new students at the matching base.
- `TeamStatusLabel` displays only each team's live unit count in a compact single-line bar.
- `TeamAIController` periodically applies four trait-specific strategies, reserves defenders on owned tiles, and selects a team-dependent fraction of free units to chase enemies while leaving the player's units untouched.
- `MatchManager` permanently disables zero-unit teams, ends immediately on player elimination, and awards victory only after all three opponents are eliminated. Territory control affects reinforcements but never ends the match.

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
godot --headless --path . --script res://Testing/run_menu_tests.gd
godot --headless --path . --script res://Testing/run_match_tests.gd
```

Some installations name the executable `godot4`.

## Current scope

This prototype implements the complete menu-to-result loop, player-team selection, opponent territory AI, navigation, constrained camera control, capture, combat, health, team traits, elimination results, and reinforcement economy. Sound, advanced tactical AI, and full frame-by-frame sprite animation remain future work.
