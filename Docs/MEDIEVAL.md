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
- Orc capacity increases by one per two owned spades, rounded down. Hearts do not count. Losing spades lowers capacity without removing existing units.
- Against one target, the first engaged orc (stable unit-ID order) deals base damage, and each additional engaged orc deals +1 on successful punches. Two deal 5 combined; three deal 8. Support requires a living orc fighting that same enemy in melee contact; misses retain the existing combat rules.
- Only elves gain +1 maximum HP per killing blow, without instantly healing. Other medieval races gain no HP from kills.
- Demons gain +1 permanent punch damage per killing blow, stacking for that unit's lifetime. Respawning resets kill bonuses.
- Elves heal 0.2 HP per seated tick on owned hearts (3.6 HP/sec). Their base healing and all other races' healing remain 0.1 per tick.

The recruitment HUD uses the variant's actual threshold; medieval help describes these rules. Run Godot headless with --script res://Testing/run_medieval_tests.gd for balance and variant-wiring regression checks.

## Fixed human capture and conquered bases

| Seated humans on one tile | Full capture time |
| --- | --- |
| 1 | 12 seconds |
| 2 | 7 seconds |
| 3 | 4 seconds |
| 4 | 3 seconds |
| 5 | 2 seconds |
| 6 or more | 1 second |

These times apply to spades, hearts and eligible bases from zero progress. Only seated units contribute. Partial progress remains when units leave; changing the seated count changes the rate for the remaining progress. All medieval capture is evaluated once per tick from a snapshot of seated units. Other races retain 300 total seated ticks (16.7 seconds for one unit).

A medieval base becomes capturable only after its current owning team is eliminated and its last unit finishes death cleanup. Changing ownership changes the base's colour in the existing board and minimap renderers. Captured bases heal their new owner's seated units and each independently recruits that owner's race, using the same race threshold and current spade bonus as the home base. Each new base starts with an empty spawn meter; spade ownership changes immediately affect every owned base's rate. Multiple bases share the existing team population cap, and a blocked base does not block other bases. Captured bases add no population capacity.

Protection follows the current owner: a captured base can be conquered again after its new owner is eliminated. AI teams can pursue eligible bases. Existing player defeat and last-team-standing victory conditions remain unchanged; there is no post-victory capture phase. Classic capture, bases and recruitment remain unchanged.

The recruitment HUD checks space across every owned base and displays the next spawn cycle. No manual Godot setup is required. Testing/run_medieval_capture_tests.gd checks all human timing tiers on all capturable tile types, other-race timing, changing squad sizes, elimination protection, base ownership and recruitment, dynamic spade bonuses, blocked bases, shared capacity, and classic base protection.
