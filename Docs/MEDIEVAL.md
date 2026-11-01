# Medieval Wars variant

School Wars stays at `/`. Its animated Extras button opens `/v2`. The `/v2` and `/v2/` routes serve the same Godot Web export and choose the medieval skin from the browser pathname. A return button opens School Wars. The shared simulation uses an opt-in medieval rules flag.

Teams map in order: Black -> Humans, Green -> Orcs, Yellow -> Elves, Purple -> Demons. Colours, base stats, map and movement are shared. Medieval balance differences are listed below. Original School Wars assets and attribution remain in the classic version. No GAMEDESIGN title is displayed on the medieval menu.

Assets: `Assets/Medieval/menu.jpg` and `Assets/Medieval/students.png`. The atlas keeps the 640x960 layout, 20 columns x 20 rows, with 32x48 cells. The same atlas supplies portraits and all in-game animations. The Extras pulse respects the browser reduced-motion preference. No Godot scene wiring is required; export with the existing Web preset.

Artwork was generated with the built-in image generation tool. Background prompt: wide illustrated dark fantasy medieval warfare; castle battlements, armies, human warrior, green orcs, golden elves and violet demons, dusk and embers, central negative space, no text or logos. Atlas edit prompt: preserve the original 400 animation slots and foot anchors; replace the four 100-frame colour groups with dark-armoured humans, green orcs, golden elves and purple horned demons; transparent background, retain walk/sit/punch/death poses and original directions. The generated atlas was normalized to the existing cell dimensions and palette-compressed for browser loading.

Validation: Godot import and complete Classic tests, plus medieval shell checks for title, race order, sprite binding and starting each race with the unchanged simulation.

## HD sprite and recruitment HUD update

The active medieval atlas is `Assets/Medieval/students_hd.webp`, 1280x1920 with 64x96 frames (twice the original width and height). A higher-detail image-generation redraw was normalized into the existing 400 slots; transparent death blink frames are preserved. Both portraits and board rendering derive source frame size from the texture dimensions while keeping world-space character size, hitboxes and animation timing unchanged. Medieval rendering uses linear sampling; classic sprites remain unchanged.

The bottom-right HUD shows the exact requested mouse tips, with the recruitment progress bar above and minimap above that. The progress bar reads actual per-team recruitment progress/threshold; owned recruitment tiles and the Green/Orc threshold naturally affect fill speed. Capacity-full and blocked-base labels explain why a recruitment cycle may not produce a unit. No recruitment rules have changed.

HD art prompt: clearer high-resolution remaster of the original medieval atlas, preserving all 400 slots, poses, directions and race colour blocks; improve armor edges, faces, elf ears, orc tusks and demon horns; transparent background. Built-in image generation was used, followed by atlas normalization and WebP encoding.

## Animation and compact HUD repair

Six empty live medieval atlas frames (19,79,119,179,219,319) were replaced with the adjacent valid pose in the same directional sequence. Death-blink frames remain intentionally blank. Both variants use cached filter-clipped atlas textures to prevent sampling neighbouring frames. Regression checks cover all 368 live-state frames.

The spawning panel is now 225x48, bottom-left (75% of the previous width and height), labelled Spawning. Battlefield control tips are hidden and appear first in the concise bulleted help dialog. The minimap is restored to bottom-right.

## Registered races.png replacement

The active atlas is now `Assets/Medieval/races.png`; `students_hd.webp` is removed. Image generation used the original Classic/students.png as the pose reference. Tools/register_race_atlas.py isolates the dominant connected character in each generated frame and fits it to approximately 99% of the classic frame's visible width and height, at 2x resolution. All output is contained within the original scaled per-frame bounds, centred horizontally and aligned to the original foot anchor. Original blank frames remain transparent. Tests check visible frames, bounds, foot anchors and clipped sampling. Generation remains an artistic reinterpretation of poses, not exact pixel tracing.

## Directional races2.png redraw

The active medieval atlas is `Assets/Medieval/races2.png`, a 1280x1920 transparent PNG with 64x96 cells. `races.png` remains available as the previous artwork. Both menu portraits and battlefield characters use the new texture through `ClassicGame.MEDIEVAL_STUDENTS`; no scene setup is required. Classic artwork and classic simulation behavior remain unchanged.

Each race occupies 100 row-major cells: bottom-right at offsets 0-23, bottom-left at 25-48, top-left at 50-73, and top-right at 75-98. Offsets 24, 49, 74 and 99 are transparent and are also used by the death blink. In each direction, one-based poses 1-10 are walking, 11-13 standing, 14-16 sitting on the ground for idle/capture, 17-20 punching, and 21-24 hit/recoil/fall/dead. Back-facing directions show the back of the head and armor. The hit reactions retain the original turns and leans.

The built-in image generation tool redrew one race at a time from the original classic poses, rearranged into an 8-column, 12-row reference (three rows per direction). The accepted sheets are packed with `Tools/pack_races2_atlas.py HUMAN ORC ELF DEMON OUTPUT`; this fails on missing poses instead of borrowing frames. It retains the original scaled bounding envelope, horizontal centre and bottom anchor at approximately 99% visible width/height. Registration checks all 384 visible poses and 16 blank cells. These checks establish layout and anchors; pose fidelity still requires visual review.

Generation prompt: redraw the supplied 96-pose template as sharp hand-painted HD medieval sprites; exactly 8 columns by 12 rows; rows 1-3 bottom-right, 4-6 bottom-left, 7-9 top-left, 10-12 top-right. Match each original skeleton, head angle and limb placement. Within each three-row group: eight walking poses; then two walking, three standing and three ground-sitting poses; then four punch poses and four hit-to-death poses. Show the back for both top-facing directions. Transparent background, no labels, weapons, shields, wings or ground shadows. Race designs: dark steel human with red-brown hair; green orc with tusks and leather/iron armor; golden elf with pointed ears and blond hair; violet demon with small horns and purple armor. Do not change grid, facing or action order.

## Medieval balance rules

The game passes its medieval flag through ClassicBoard into ClassicSimulation before setup. Classic remains the default; no Godot scene setup is required.

- Human capture uses the fixed table below, based on seated humans on the same tile. This replaces the earlier 20% capture bonus.
- Orc recruitment threshold is 750 instead of classic Green's 500; other races remain at 1500. At equal spade ownership, orcs recruit twice as fast.
- Orc capacity increases by one per two owned spades or hearts combined, rounded down. Losing either lowers capacity without removing existing units. Converted orcs are counted separately as (+N) in the top bar and never consume regular recruitment capacity.
- Against one target, the first engaged orc (stable unit-ID order) deals base damage, and each additional engaged orc deals +1 on successful punches. Two deal 5 combined; three deal 8. Support requires a living orc fighting that same enemy in melee contact; misses retain the existing combat rules.
- Elves gain +1 maximum HP per killing blow or recent damaging assist, without instantly healing. Humans have the kill milestones below.
- Demons gain +1 permanent punch damage per killing blow or recent damaging assist, stacking for that unit's lifetime. Respawning resets all progression.
- Elves heal 0.2 HP per seated tick on owned hearts (3.6 HP/sec). Their base healing and all other races' healing remain 0.1 per tick.

The recruitment HUD uses the variant's actual threshold; medieval help describes these rules. Run Godot headless with --script res://Testing/run_medieval_tests.gd for balance and variant-wiring regression checks.

## Fixed human capture and conquered bases

| Seated humans on one tile | Full capture time |
| --- | --- |
| 1 | 12 seconds |
| 2 | 9 seconds |
| 3 | 6 seconds |
| 4 | 4 seconds |
| 5 | 2 seconds |
| 6 or more | 1 second |

These times apply to spades, hearts and eligible bases from zero progress. Only seated units contribute. Partial progress remains when units leave; changing the seated count changes the rate for the remaining progress. All medieval capture is evaluated once per tick from a snapshot of seated units. Other races retain 300 total seated ticks (16.7 seconds for one unit).

An original home base becomes capturable after its original race is eliminated and its last unit finishes death cleanup. Once conquered, it can be recaptured by another team while its current owner is alive. Ownership changes colour and healing allegiance. Each owned enemy base adds six capacity; losing it removes that capacity without deleting existing warriors. Capturing bases does not change the team spawn interval. Spades and racial spawn rates still apply.

Medieval teams use one shared recruitment timer. Successful spawns rotate through all currently owned bases in stable map order: A, B, A, B for two bases, or A, B, C, A for three. Full bases are skipped so another owned base with free space can spawn. If every base is full, the team holds its ready timer until space opens. Only successful scheduled spawns advance the rotation. Ownership changes immediately update available locations. Existing player defeat and last-team-standing victory conditions remain unchanged; there is no post-victory capture phase. Classic capture, bases and recruitment remain unchanged.

The recruitment HUD checks space at the next base in the rotation and displays the next spawn cycle. No manual Godot setup is required. Testing/run_medieval_capture_tests.gd checks all human timing tiers on all capturable tile types, other-race timing, changing squad sizes, elimination protection, base ownership and recruitment, dynamic spade bonuses, blocked bases, shared capacity, and classic base protection.

## Race progression and recent-damage assists

| Race | Trigger | Bonus |
| --- | --- | --- |
| Human | First killing blow | +2 maximum HP, once |
| Human | Second killing blow | +2 punch, once |
| Human | Third killing blow | Total attack reach becomes 3 grid cells |
| Human | Fourth killing blow | Each successful swing also hits one enemy adjacent to the main victim, within human reach |
| Orc | Each killing blow | 25/50/75/100% conversion for 1/2/3/4+ distinct orcs landing hits in the previous three seconds |
| Elf | Kill or damage in the last 3 seconds before death | +1 maximum HP per enemy death |
| Elf | 28 / 32 / 36 maximum HP | +1 / +2 / +3 reach, for total reach of 2 / 3 / 4 cells |
| Demon | Kill or damage in the last 3 seconds before death | +1 punch per enemy death |
| Demon | 8 / 12 / 18 permanent punch damage | +20% / +30% / +40% movement speed |

Human milestones are cumulative and stop after four kills. Elf range and demon speed use the highest unlocked tier rather than adding tiers together. Max-HP bonuses do not instantly heal. All bonuses belong to individual units and reset on new spawns or conversions.

Successful damage records the simulation tick and attacker's lifetime on the victim. Qualifying living elves and demons each receive one reward at death; repeated hits refresh the timestamp, and the killing blow does not give duplicate assist credit. The three-second window is inclusive (54 simulation ticks). Misses grant no credit. Lifetime checks prevent a respawned unit from inheriting the previous occupant's assists. Assists do not count toward kill totals or human milestones.

Range is Manhattan distance in movement grid cells, not the larger capture tiles. Ranged pursuit, focus-position pathfinding, priority attacks and retaliation use the same per-unit reach. Melee defenders close the gap against ranged attackers. The existing rule that moving targets cannot be punched remains. Demon movement accumulates fractional progress across consecutive walk steps so +30% and +40% remain distinct at 18 Hz, with rendering using that same progress.

Orc conversion replaces the dead enemy with a fresh full-health orc of the killer's team, with a new unit ID and no inherited stats, selection, or targeting orders. The death cell is transferred immediately without an overlapping corpse. Conversions do not consume regular recruitment capacity. Regular recruitment respects its own count and cap; converted survivors still prevent elimination. Conversion status resets on an ordinary respawn. Converting a team's last unit triggers elimination and unlocks its bases.

Testing/run_medieval_progression_tests.gd covers exact milestone boundaries, assist expiration and duplicate prevention, dead/reused contributors, real ranged damage and pursuit, sustained movement speed, deterministic conversion rolls and death-cell occupancy, elimination and fresh-spawn resets. Classic rules remain unchanged.


## Floating reward text

Medieval units display the event they actually earned for 30 ticks (about 1.7 seconds): humans show "+2 HP", "+2 PUNCH", and "+3 RANGE" at their first three kill milestones and "+1 TARGET" at their fourth; successful orc conversions show "ORCS RISE!" above the killer; elves show their previous maximum HP followed by " + 1 HP", and demons show their previous total punch (base plus earned bonus) followed by " + 1 PUNCH" for rewarded kills or assists. For example, "30 + 1 HP" means maximum HP increased from 30 to 31; "30 + 1 PUNCH" means punch increased from 30 to 31. Kills after the fourth human milestone and failed orc conversion rolls do not trigger another notification. A new reward replaces the current message and restarts its timer. Fresh spawns clear messages. Labels are centred above medieval units, and classic keeps its existing "Level up!" notification.


## Difficulty and coordinated opponents

The title menu defaults to **Easy**. The selection applies to every opposing
race and persists when returning to race selection or replaying a match.

- **Easy:** original individual AI.
- **Normal:** persistent squads of 2–4 where population allows, with strategic
  decisions every two seconds. It shares Easy's 400-tick opening wait (about
  22.2 seconds); this wait applies only at match start, not to reinforcements.
- **Expert:** squad decisions every second, no opening wait, and local enemy awareness. Enemy recruitment runs at 1.5 times the Normal rate (two-thirds the interval); the player, Easy, Normal and Classic spawn rates remain unchanged.

Squads share capture destinations and focus targets. Separated members rally
before advancing; recruits fill squads, and a group of five splits into 3/2.
Single surviving warriors can still act until another recruit is available.
Humans capture together and choose their next objective once ownership changes.
Elves below 20% HP seek an owned heart or base and normally recover to 80% HP.
All medieval elves, including player units, heal only while sitting on an owned
heart/base after three seconds without being attacked. Active in-range attacks
block healing even when a punch misses. When threatened, Normal elves randomly
choose to fight back or seek another healing spot. Expert elves use the same random threatened-healing choice as Normal. Decisions commit for three seconds to limit oscillation;
arrival under attack triggers a new decision. Retreat does not grant immunity.
Orcs focus a shared victim; when locally outnumbered they can flee for at most
ten seconds, once per unit every thirty seconds measured from flee start.
Cooldown orcs keep fighting even when squadmates flee. They flee toward the nearest active enemy-owned base. Demons favour low-HP
prey and compare their squad's health, damage and reach against nearby defenders
before selecting an attack. Orcs value spades; elves value hearts.

`Scripts/Classic/medieval_squad_ai.gd` owns planning. The simulation enables it only
for Medieval Normal/Expert with AI enabled. Player orders and Classic rules remain
unchanged. Unit reuse resets retreat flags and reassigns squad membership.
Run `Testing/run_squad_ai_tests.gd` for race decisions, recovery, difficulty gates,
respawn membership and seeded simulation occupancy checks.

Human fourth-level attacks snapshot at most one secondary enemy before applying primary damage. Both victims take the normal full punch damage on the same successful swing, with ordinary retaliation, kill rewards and assist credit. The extra victim must be stationary, adjacent to the main victim (Manhattan distance one), and within the human's attack range. A missed swing hits neither victim; unlocking level four takes effect on the next swing.

### Expert race strategy

Expert retains no opening wait and 50% faster enemy recruitment. Enemy unit awareness is local (16 cells, the same as Normal); there is no global army/stat evaluation or demon race campaign. Known tile ownership and base locations still guide movement.

Humans fill squads to four and prioritize nearby unoccupied capture objectives. Orcs fill squads to six and focus one nearby enemy. Outnumbered orcs in Normal and Expert flee toward an enemy-owned base for up to ten seconds, retaining the thirty-second per-unit cooldown.

Elves use Normal's healing and combat rules with four core members per group; ranged elves may join beyond that limit. They prioritize nearby attackers fighting allies below 20% HP, then capture tiles. Group destinations are spaced apart with a three-tile separation preference, except when responding to the same threatened ally.

Demons form groups of four and aggressively focus nearby enemies on their owned tiles, regardless of the strength comparison or their own remaining HP. Once those threats are gone, demons below 30% HP seek an owned heart/base and recover to 80% before returning. Healthy members resume capture orders. Defending owned land takes priority over healing whenever a nearby invasion is detected.
