# Classic revamp

The default scene is `Scenes/Classic/classic_game.tscn`. This is a Godot 4.3+ reimplementation of the supplied `schwar.swf`, based on its recovered ActionScript and bitmap timelines. It does not embed Flash or require Ruffle. The original menu title and GAMEDESIGN attribution are retained.

## Recovered rules

The source movie is 640×400 at 18 frames per second. `ClassicSimulation` advances in fixed 18 Hz steps regardless of display refresh rate. The 960×600 viewport preserves its 8:5 aspect ratio.

| Rule | Classic behavior | SWF source |
| --- | --- | --- |
| Board | 16×16 isometric tiles, 64×64 occupied subcells; four shuffled corner bases | `DefineSprite_862/frame_1` |
| Starting army | Three students per school; 48 pooled slots, 12 per school | `frame_2`, `pmax = 48` |
| Neutral tiles | 26 randomized placement attempts, skipping occupied positions and orthogonal neighbors; roughly two thirds fist, one third heart | `frame_1` |
| Capture | Seated students each contribute one progress point per tick; 300 points captures a tile | `frame_3`, `sitting()` |
| Partial capture | Each school retains its own progress while absent; changing ownership resets the other schools' progress | `sitting()` |
| Bases | Permanent ownership, recruit only here, heal seated friendly students | `frame_2`, `sitting()` |
| Fist tiles | Each owned fist adds one recruitment progress per tick; no healing | `check_add_people()` |
| Heart tiles | Seated friendly students heal 0.1 HP per tick, up to maximum health; no recruitment bonus | `sitting()` |
| Reinforcements | Two base progress per tick plus one per owned fist; threshold 1,500, or 500 for Green; spawn only when threshold is exceeded | `check_add_people()` |
| Movement | Reserve one subcell per student; four isometric directions, six ticks per step; wait or stop when blocked | `start_turn()`, `set_dir()`, `walking()` |
| Combat | Adjacent enemies, directional punch animation, 50% miss chance, hit interruption, death animation | `fighting()` |
| Level-up | Killer gets +1 maximum HP, with no immediate healing; applies to every colour | `start_levelup()` |
| Elimination | Last death animation completes → school eliminated permanently; no territory-based victory | `dying()`, `on_annihilated()` |
| Opponents | Idle students seek nearby enemies; after 400 seated idle ticks seek enemy territory or friendly healing; leading-school targeting above 40% strength | `frame_3`, `frame_4` |

| School | Starting HP | Successful punch | Recruitment threshold | Base-only interval |
| --- | ---: | ---: | ---: | ---: |
| Black | 20 | 4 | 1,500 | ~41.67 s |
| Green | 10 | 2 | 500 | ~13.89 s |
| Yellow | 25 | 3 | 1,500 | ~41.67 s |
| Purple | 15 | 5 | 1,500 | ~41.67 s |

The intervals above are nominal threshold/rate values. The source uses a strict `>` comparison. A full or blocked base can delay an actual spawn. One seated student takes 300/18 ≈ 16.67 seconds to capture, plus its initial standing delay; three seated students contribute three points per tick. This replaces the prototype's unrelated five-to-one-second capture curve and subtract-one-second spawn formula.

## Controls and interface

- Choose Black, Green, Yellow, or Purple.
- Click a friendly student or drag a rectangle around a squad. With a selection, press the left mouse button on a tile to move or on an enemy to focus attacks. A red arrow identifies the hovered enemy and briefly confirms the attack order. Explicit focus remains the preferred order until the enemy dies or another player order replaces it. When it is outside melee reach, students can temporarily fight adjacent attackers and resume focus afterward. As in Flash, issuing the order clears the selection; students choose random destination subcells within that tile.
- Space + left-drag pans like the original. Right-drag is an additional option. Click or drag the minimap to relocate the view.
- Wheel zoom and **A** to select all are convenience additions. **Esc** cancels selection, then opens pause; **Esc** also resumes.
- Help, pause, sound toggle, quit confirmation, and replay use native Godot controls. Help and browser focus loss pause the simulation. Time spent in a suspended browser tab is never replayed as a burst of simulation steps.

The interface is refreshed rather than a pixel-perfect menu replica. The seedable Godot random generator cannot reproduce Flash's unseeded random sequence. Animation timing and greedy grid navigation follow the recovered state machine; they are not a byte-for-byte ActionScript runtime emulation. Watch/spectator mode is not included in this increment.

## Modules and compatibility

| File | Responsibility |
| --- | --- |
| `Scripts/Classic/classic_rules.gd` | Recovered constants, team identity, isometric coordinate conversion |
| `Scripts/Classic/classic_student.gd` | Pooled unit state and rendered movement position |
| `Scripts/Classic/classic_simulation.gd` | Seeded map generation, occupancy, AI, capture, healing, recruitment, combat, elimination |
| `Scripts/Classic/classic_board.gd` | Atlas rendering, depth order, mouse commands, view, fixed clock, audio pool |
| `Scripts/Classic/classic_minimap.gd` | Live army dots, viewport rectangle, minimap drag |
| `Scripts/Classic/classic_game.gd` | Menu → match → pause/help/result → replay/menu lifecycle |
| `Assets/Classic/` | Original atlas art, menu crop, six original sound cues and import settings |
| `Testing/run_classic_tests.gd` | Source-rule checks, seeded stress runs, occupancy invariants, shell lifecycle |
| `Tools/smoke_classic_web.cjs` | Chromium checks against the exported HTML5 game |

The legacy `Scenes/main.tscn`, `Scenes/movement_test.tscn`, public classes, resources, and all eleven legacy test suites remain available. They retain their existing prototype rules. Keeping Classic isolated avoids silently changing those APIs or mixing two incompatible economies. `project.godot` switches only the default entry point and viewport aspect ratio.

No manual scene wiring, autoloads, addons, or resource assignments are required. Install matching Web export templates for HTML5, then use the existing launch tools. The renderer remains GL Compatibility and the Web preset remains threadless. Pull requests test and export without deploying Pages. Merging to `main` uses the existing Pages deployment.

For Vercel, `vercel.json` selects the static `export/web` output. `Tools/build_vercel.sh` downloads checksum-pinned Godot 4.3 tools, imports the project, and exports the native Web build. It needs no API keys, Node dependencies, or manual Godot installation. The hosting configuration sets same-origin isolation headers and explicit WebAssembly/PCK content types. A deployment can target the revamp branch for playtesting before merging.

## Asset provenance and reproducibility

Source: user-supplied `schwar.swf`, SHA-256 `5994d74c67d46a96ab1f6f74926fada050b06df07d2dffd3b9fc5ff605e70e8a`.

The images and sounds are recovered original game assets, not newly licensed artwork. No change of ownership or license is asserted. The unmodified source SWF is preserved at `Reference/schwar.swf`, excluded from Godot imports by `Reference/.gdignore`. Decompiler binaries are not added to this repository.

Extraction used JPEXS Free Flash Decompiler 26.4.0:

```sh
java -jar ffdec.jar -cli -export sprite reference schwar.swf
java -jar ffdec.jar -cli -format sound:wav -export sound reference/wav schwar.swf
java -jar ffdec.jar -cli -swf2xml schwar.swf reference/schwar.xml
```

`DefineSprite_775` has 400 32×48 frames (four colours × four directions × 25 patterns). `students.png` packs them in 20 columns. The wrapper in symbol 786 places each frame at (-16, -34) relative to the student's foot position. `DefineSprite_812_mcMapPatOrg` supplies 15 96×48 tile frames, packed in five columns. No interpolation or generative reconstruction is applied.

For the menu crop, remove the `PlaceObject2Tag` referencing character 825 (the runtime fade overlay) from sprite 845 in the XML, convert that temporary XML back to SWF, and export sprite 845. Frame 7's rectangle (5,15)–(645,280) supplies the title art. The four black placeholder buttons below the title are replaced with live team-coloured Godot buttons. Sounds 1–6 map to move, select, punch, message, death, cancel. `Tools/pack_classic_assets.py` reproduces the atlases and sound copies from these exports.

## Validation and next increment

Run `godot --headless --path . --script res://Testing/run_classic_tests.gd`. The test suite verifies source constants, placement rules, capture, healing, recruitment, kill rewards, elimination, deterministic replay, and 18,000 total ticks across three seeded AI runs. All eleven legacy suites should still pass. The Actions workflow also exports Web and runs `Tools/smoke_classic_web.cjs`; screenshots are uploaded as `classic-browser-checks`.

Next: side-by-side playtesting against the supplied SWF, focusing on idle/attack cadence, death animation timing, and congested squad routing before adding another major system.

## Mechanics follow-up

Moving defenders remember an adjacent attacker while finishing their current step, matching Flash. Player commands issue on mouse-down; their mouse-up does not begin a second selection. Existing Godot immediate recovery when a combat target dies is retained deliberately.

Box selection retains the Godot six-screen-pixel click/drag threshold and existing forgiving selection margins. This avoids treating hand jitter as a drag. Flash uses exact pointer equality for clicks and asymmetric world-space margins. With a squad selected, pressing left mouse issues its order, including when followed by dragging; cancel with Esc before drawing another selection box. Space-left-drag and right-drag still pan without issuing orders.

Focused attacks are a deliberate stronger player-control rule: clicked enemies remain the priority while within melee reach. Students outside that range may defend against adjacent attackers without losing the original focus order. Normal uncommanded retaliation still follows Flash. Navigation remains the original greedy grid movement, so congestion can delay reaching a target; focus does not guarantee immediate contact or bypass occupied cells.

## Selection, pursuit, and Green capacity

Space clears selection; the separate cancel-selection button is removed. Space-drag still pans. When a target dies, pursuing units continue toward its final grid cell, subject to normal occupancy and routing. Green capacity is 12 + floor(currently owned non-base tiles / 2), counting both spades and hearts. Recruitment timing is unchanged. Territory loss reduces capacity but does not kill surplus units; spawning resumes below the current cap. The shared unit pool grows as necessary and AI scans every slot. The HUD shows population/capacity.
