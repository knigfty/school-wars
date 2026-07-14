# School Wars — RTS Selection, Orders, and Camera

This project establishes a browser-safe Godot 4.x foundation with multi-unit selection, left-click movement orders, a floating four-square arena, and a constrained RTS camera.

## Run the project

1. Open this folder in Godot 4.3 or later.
2. Press **F6** to run the current selection test scene, or **F5** to run the project.
3. Select a student with a left click, or select multiple students by holding the left mouse button and dragging a box around them.
4. With students selected, left-click empty ground to direct them there.
5. Pan the camera with **IJKL**, the screen edges, or right-mouse dragging. Zoom with the mouse wheel.

The camera begins at the Purple southeast spawn so selectable students are visible immediately. The renderer is set to **GL Compatibility**, which is the appropriate baseline for Godot Web exports.

## Architecture

- `Resources/Unit/student_stats.gd` defines reusable unit tuning data. The default `.tres` resource owns all current numbers; the controller does not hardcode them.
- `Scripts/Characters/student_controller.gd` is a command-driven movement motor. It never reads player input; future AI or player orders can drive it through `set_move_intent()`.
- `Scripts/Characters/selectable_component.gd` gives a unit selection state and a screen-space selection position without coupling it to global UI logic.
- `Scripts/Characters/student_move_order_component.gd` converts a world destination into movement intent and stops the student within a configurable arrival radius.
- `Scripts/UI/unit_selection_controller.gd` owns left-click, drag-marquee selection, and empty-ground order requests through camera pan and zoom.
- `Scripts/Commands/unit_command_controller.gd` distributes group movement orders into centered formation slots.
- `Scripts/Camera/rts_camera_controller.gd` owns right-drag panning, cursor-centered zoom, smoothing, and viewport-aware map constraints. It has no dependency on units or map gameplay.
- `Scripts/Maps/movement_test_arena.gd` draws four equal square quadrants as a floating platform, adds a visible platform depth and shadow, and labels its North, South, East, and West sides. The camera exposes a small controlled margin of sky around the map.
- `Scripts/Maps/team_spawn_point.gd` defines reusable color-coded spawn markers. Black, Green, Yellow, and Purple occupy the four map corners.
- `Characters/student.tscn` composes the movement motor, selectable component, placeholder visuals, and default stats. Students collide with one another and the invisible map circumference.
- `Scenes/Camera/rts_camera.tscn` provides a reusable configured camera component.
- `Scenes/movement_test.tscn` composes the four spawn corners, eight test students, four invisible perimeter walls, selection UI, command system, and camera. There are no internal wall bodies or visible fences.

## Automated check

With a Godot executable on your `PATH`, run:

```bash
godot --headless --path . --script res://Testing/run_movement_tests.gd
godot --headless --path . --script res://Testing/run_camera_tests.gd
godot --headless --path . --script res://Testing/run_selection_tests.gd
godot --headless --path . --script res://Testing/run_move_order_tests.gd
godot --headless --path . --script res://Testing/run_collision_tests.gd
godot --headless --path . --script res://Testing/run_map_tests.gd
```

Some installations name the executable `godot4`; use that name if needed.

## Run in a browser on localhost

Install Godot 4 and its matching Web export templates, then use one command:

```bash
./Tools/run_web.sh
```

On Windows, double-click `Tools/run_web.bat` or run:

```powershell
python Tools/run_web.py
```

The launcher finds Godot, exports the project, validates the generated HTML, JavaScript, WebAssembly, and PCK files, starts `http://localhost:8060`, and opens the browser automatically. If Godot is not on `PATH`, set `GODOT_BIN` or pass `--godot /path/to/godot`.

The included server supplies WebAssembly MIME and cross-origin isolation headers. The current preset disables threads for broader browser and hosting compatibility.

## Automatic GitHub Pages deployment

`.github/workflows/deploy-pages.yml` builds the Godot Web export in GitHub Actions whenever `main` changes, uploads a downloadable `school-wars-web` artifact, and deploys the same build to GitHub Pages. Godot is downloaded only inside the cloud runner, so players and contributors do not need Godot to run the compiled build.

One repository setting is required: open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**. GitHub Pages for a private repository requires a GitHub plan that supports private Pages sites; otherwise change the repository visibility to public.

To run without Godot after a successful workflow:

1. Open the workflow run in the repository's **Actions** tab.
2. Download and extract the `school-wars-web` artifact.
3. Double-click `run_localhost.bat` inside the extracted folder.

This standalone package requires Python 3 but does not require Godot.

## Scope boundary

Combat, health runtime state, AI, territories, menus, and match rules are intentionally not implemented in this increment. They remain separate roadmap features.
