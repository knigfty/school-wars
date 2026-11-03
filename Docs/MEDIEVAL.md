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
- Demons gain +1 permanent punch damage per killing blow, with a 50% chance of +1 for a recent damaging assist, stacking for that unit's lifetime. Respawning resets all progression.
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
| Human | Kills 1/4/7/... | +2 maximum HP each time |
| Human | Kills 2/5/8/... | +2 permanent punch each time |
| Human | Kills 3/6/9/... | +2 attack reach each time |
| Orc | Each killing blow | 25/50/75/100% conversion for 1/2/3/4+ successful hit stacks in the previous five seconds, including repeated hits by one orc |
| Elf | Kill or damage in the last 3 seconds before death | +1 maximum HP per enemy death |
| Elf | Bonus maximum HP above the starting 25 | +1 reach per 2 HP until 3 cells, per 3 additional HP until 5 cells, then per 4 additional HP forever |
| Demon | Killing blow / qualifying damage assist in the last 3 seconds | Guaranteed kill punch (+2 Expert, +1 otherwise); 50% chance of +1 assist punch |
| Demon | 8 / 12 / 18 permanent punch damage | +20% / +30% / +40% movement speed |

Human upgrades repeat a three-kill cycle indefinitely. Elf range uses 2/3/4-HP steps at the 3/5-cell boundaries; demon speed follows the selected difficulty's rules. Max-HP bonuses do not instantly heal. All bonuses belong to individual units and reset on new spawns or conversions.

Successful damage records the simulation tick and attacker's lifetime on the victim. Qualifying living elves receive one reward at death; qualifying demon assistants roll independently for a 50% chance of one punch reward; repeated hits refresh the timestamp, and the killing blow does not give duplicate assist credit. The three-second window is inclusive (54 simulation ticks). Misses grant no credit. Lifetime checks prevent a respawned unit from inheriting the previous occupant's assists. Assists do not count toward kill totals or human milestones.

Range is Manhattan distance in movement grid cells, not the larger capture tiles. Ranged pursuit, focus-position pathfinding, priority attacks and retaliation use the same per-unit reach. Melee defenders close the gap against ranged attackers. Moving targets can be hit by ranged attacks and by elves at any reach; other one-cell melee attacks cannot hit walkers. Demon movement accumulates fractional progress across consecutive walk steps so +30% and +40% remain distinct at 18 Hz, with rendering using that same progress.

Orc conversion creates a new orc with the victim's maximum HP and permanent punch, at full inherited HP, with one-cell reach and a new unit ID. Temporary human territorial punch and a snapshot of the victim's group bonus are not inherited. The converted unit participates in current orc group damage normally. Other race traits, selection and targeting orders are not inherited. The death cell is transferred immediately without an overlapping corpse. Conversions do not consume regular recruitment capacity. Regular recruitment respects its own count and cap; converted survivors still prevent elimination. Conversion status resets on an ordinary respawn. Converting a team's last unit triggers elimination and unlocks its bases.

Testing/run_medieval_progression_tests.gd covers exact milestone boundaries, assist expiration and duplicate prevention, dead/reused contributors, real ranged damage and pursuit, sustained movement speed, deterministic conversion rolls and death-cell occupancy, elimination and fresh-spawn resets. Classic rules remain unchanged.


## Floating reward text

Medieval units display the event they actually earned for 30 ticks (about 1.7 seconds): humans repeat "+2 HP", "+2 PUNCH", and "+2 RANGE" on successive kills; successful orc conversions show "ORCS RISE!" above the killer; elves show their previous maximum HP followed by " + 1 HP", and demons show their previous total punch (base plus earned bonus) followed by " + 1 PUNCH" for rewarded kills or assists. For example, "30 + 1 HP" means maximum HP increased from 30 to 31; "30 + 1 PUNCH" means punch increased from 30 to 31. Every human kill triggers its cycle reward; failed orc conversion rolls do not trigger a notification. A new reward replaces the current message and restarts its timer. Fresh spawns clear messages. Labels are centred above medieval units, and classic keeps its existing "Level up!" notification.


## Difficulty and coordinated opponents

The title menu defaults to **Easy**. The selection applies to every opposing
race and persists when returning to race selection or replaying a match.

- **Easy:** original individual AI.
- **Normal:** persistent squads of 2–4 where population allows, with strategic
  decisions every two seconds. It shares Easy's 400-tick opening wait (about
  22.2 seconds); this wait applies only at match start, not to reinforcements.
- **Expert:** squad decisions every second, no opening wait, and local enemy awareness. All difficulties use the same race-specific recruitment rates.

Squads share capture destinations and focus targets. Separated members rally
before advancing; recruits fill squads, and a group of five splits into 3/2.
Single surviving warriors can still act until another recruit is available.
Humans capture together and choose their next objective once ownership changes.
AI elves below 30% HP seek the nearest uncontested owned heart/base without a distance limit and recover fully. Retreat movement is 30% slower; the thirty-second cooldown starts on arrival. All medieval elves, including player units, heal only while sitting on an owned heart/base after three seconds without being attacked. Active in-range attacks block healing even when a punch misses. Healing AI elves retaliate in place without healing during combat. Threatened tile defenders may choose fight or healing retreat if cooldown allows; fighting holds for three seconds before reconsideration. Retreat does not grant immunity.
Orcs focus a shared victim; when locally outnumbered they can flee for at most
ten seconds, with a ten-second cooldown beginning only when the orc reaches a tile and sits.
Cooldown orcs keep fighting even when squadmates flee. They flee toward the nearest active enemy-owned base. Demons favour low-HP
prey and compare their squad's health, damage and reach against nearby defenders
before selecting an attack. Orcs value spades; elves value hearts.

`Scripts/Classic/medieval_squad_ai.gd` owns planning. The simulation enables it only
for Medieval Normal/Expert with AI enabled. Player orders and Classic rules remain
unchanged. Unit reuse resets retreat flags and reassigns squad membership.
Run `Testing/run_squad_ai_tests.gd` for race decisions, recovery, difficulty gates,
respawn membership and seeded simulation occupancy checks.

Human attacks hit one target per swing; the former fourth-kill cleave upgrade has been removed.

### Expert race strategy

Expert retains no opening wait and uses Normal recruitment rates. Enemy unit awareness is local (16 cells, the same as Normal); there is no global army/stat evaluation or demon race campaign. Known tile ownership and base locations still guide movement.

Humans fill squads to four and prioritize nearby unoccupied capture objectives. Orcs fill squads to six and focus one nearby enemy. Outnumbered orcs in Normal and Expert flee toward an enemy-owned base for up to ten seconds, using the ten-second per-unit cooldown that starts only after reaching a tile and sitting.

Expert elves form four core members per group; ranged elves may join beyond that limit. They prioritize: (1) shared all-difficulty healing recovery below 30% HP, (2) protect allies at or below 20% HP within ten movement cells by targeting their attackers, (3) capture enemy/neutral tiles, (4) fight nearby enemies as a group. Recovery has no distance limit, uses uncontested owned hearts/bases, and starts its thirty-second cooldown on arrival. Elves remain committed until 100% HP. Group destinations have no separation preference; coincident squads can share objectives and march together.

Expert demons form groups of four and prioritize defending owned tiles within ten movement cells, then capture, then group attacks. Enemy demons never retreat to heal on any difficulty. Demons (player and enemy) cannot heal on hearts, but can heal while seated on owned bases. Each demon killing blow heals two HP; damaging assists never heal. Killers do not also receive assist healing. Healing is capped at maximum HP and existing punch rewards remain unchanged.

Healing destination selection uses Manhattan movement-cell distance to the nearest cell on a healing tile. Elf recovery uses the same unlimited-distance rules on every difficulty.

On all Medieval difficulties, humans gain +1 punch while fighting on an owned spade, heart or base. The temporary bonus remains for three seconds after leaving owned territory, then expires. It stacks with permanent punch upgrades and is reset on normal respawn or conversion.

On all Medieval difficulties, player and enemy units execute assigned tile orders through a shared controller: clear same-tile enemies together, stand for one clear second, then sit to capture. Capture remains paused while contested. Captured tiles are held until another command; enemy strategic planners can issue new commands. Enemies one movement cell from an owned tile border trigger shared defence. Pursuit is confined to the defending tile and its four directly adjacent tiles. Target death or leaving that zone forces a return to the original tile. This assigned-tile defence replaces the previous eight-second retaliation allowance for these units. Explicit attack orders remain available.

The in-game question-mark help shows shared Medieval rules plus only the active match difficulty's AI and bonuses. `Scripts/Classic/medieval_help.gd` owns the text and per-selection menu hover tooltips. Changing the selector updates its tooltip; in-match help reads the simulation difficulty. Classic help remains unchanged.

Human AI on every difficulty now uses the shared full-map capture and conquest controller described below; the older Expert-only five-tile scout and mission casualty rules are superseded.

Expert enemy elves gain +2 maximum HP per kill or damaging assist; player elves and other difficulties receive +1. Expert demons gain +2 punch per kill and a 50% chance of +1 per damaging assist, for both player and enemy teams. Reward popups display the actual +1 or +2 increment; the same assist timing and one-credit-per-death rules apply.

Across all Medieval difficulties, enemy AI units in an owned base containing living opponents are locked to local base defence. New recruits finish their brief spawn-standing animation, then attack without waiting for strategic opening delays. Capture, healing, flee, retaliation pursuit outside the base, and squad orders are suppressed until the tile is clear. This applies to original and captured owned bases; player-controlled units keep their existing command rules. Losing base ownership also releases the lock.

All Medieval difficulties require uncontested capture: any living opposing unit on the tile pauses capture for all teams regardless of its movement/combat state. Only sitting units add progress; fighting and moving units never do. Friendly groups still capture together. Partial progress is preserved while contested and resumes when seated capturers remain alone with their allies. Corpses do not contest tiles.

Expert demon adjustment: both player and enemy demons gain +2 permanent punch on a killing blow and a 50% chance of +1 on a valid damaging assist within three seconds. Their movement multiplier is `1 + 0.05 * floor(bonus_punch / 2)`: total punch 5/6 gives base speed, 7/8 gives +5%, 9/10 gives +10%, 11/12 gives +15%, continuing without a tier cap. Easy/Normal retain +1 punch per kill and a 50% chance of +1 per qualifying assist and their existing 8/12/18 total-punch speed tiers. Combat healing and Expert enemy elf rewards are unchanged.

Expert human missions with no capturable objective inside their five-tile observation range issue local scouting orders instead of idling. Scouting destinations stay inside that range, remember visited locations and spread groups apart; newly observed capture targets still become committed missions. Expert enemy-human tile movement uses obstacle-aware routes, including backward detours around friendly base congestion. Base defence, retaliation returns and existing player orders keep their priority.

Current all-difficulty scaling: elf reach costs 2 bonus HP per cell up to reach 3, then 3 additional HP per cell up to reach 5, then 4 additional HP per cell forever; human reach is `1 + 2 * floor(kills / 3)`. Human cycles continue indefinitely. Converted orcs preserve only maximum HP and permanent punch; for example a twenty-max-HP, ten-punch victim becomes a full-health twenty-HP, ten-punch orc with reach one. Attack-position searches are bounded to the map even with very large reach.

`Testing/run_tile_defence_tests.gd` covers the shared tile lifecycle on every difficulty for player and enemy units, including target focus, the one-second standing boundary, seated capture, border detection and forced return.

All difficulties: elves gain no territorial punch bonus. Demon assist punch is rolled independently per qualifying living assistant with a 50% chance; failed rolls display no reward popup. Killing-blow punch rewards remain guaranteed.

### Interrupted return movement

Returning guards retry their route after an interrupted walk leaves them standing or seated outside their assigned tile. Ranged units finish returning before reacquiring enemies on that tile. The adjacent-tile defence leash remains in force for ordinary nearby returns; units beginning farther away (such as ranged capture approaches) can route back into that area. Regression coverage advances eight simulation steps per frame across all difficulties and races and checks completed movement and occupancy.


### Unified Elf retreat (all difficulties)

AI elves begin recovery below 30% current/maximum HP, or may choose recovery with a 50% roll when defending a threatened tile. A fight choice holds for three seconds before reconsideration. Retreat requires the cooldown to be ready and a safe destination: the nearest owned heart/base containing no living enemies, measured to the nearest tile cell with no distance limit. A committed retreat remains active if its goal is lost or contested, searches for another safe destination, and moves at 70% normal speed. It does not cancel just because HP rises en route. The 30-second cooldown starts on arrival, not departure. At the healing spot, normal speed returns but recovery remains committed until full HP. Elves retaliate against attackers in reach without leaving their healing spot; fighting never heals, and seated healing resumes only after the existing three-second safe interval. Explicit player control remains unchanged.

Orc group damage counts earlier engaged, in-contact teammates on the same victim in stable unit-ID order. Four regular attackers deal 2/3/4/5 punch (14 total if each connects once). Converted orcs both contribute and receive these bonuses, on top of inherited permanent punch, subject to their final punch cap of 10.


### Tick-level enemy interception (all difficulties)

AI elves interrupt travel to attack any enemy in their current attack reach, including moving targets at one-cell reach. They complete a reserved walking step before firing. During healing recovery, they do not initiate proximity attacks and only retaliate under the existing healing rules. AI demons detect enemies within three Manhattan movement cells and maintain their chosen pursuit until target death (or their own death), including beyond the detection radius. AI humans detect within max(3, attack reach) movement cells, route only inside the tile where the encounter began, and return there to regroup after the target dies or becomes unreachable from that tile. Strategic planners cannot overwrite these engagements. New unit lifetimes cannot inherit old commitments. Player commands retain their existing control.

Orc flee cooldown is ten seconds, starting only after reaching a tile and sitting. A pending cooldown blocks another flee before that settling event; the existing two-part ten-second itinerary is preserved.


Elf retreat travel is limited to fifteen battle seconds from departure. Changing or losing a destination does not reset this deadline. Arrival at the exact deadline enters healing; already seated recovery can continue to full HP without a travel timeout. An unsuccessful retreat releases the fallback state, restores normal movement, and uses the existing three-second fight hold before another retreat attempt; it does not spend the arrival-only cooldown. A new travel phase after losing an occupied healing spot receives its own fifteen-second deadline.

A demon pursuing a distant enemy now attacks adjacent hostile blockers, including retreating elves in waiting states, instead of idling beside them. Its original target and lifetime remain recorded, and pursuit resumes after the blocker is removed.


### Symmetric spectator maps

Spectator-only generation samples four to seven neutral objectives in one quadrant and repeats every position and kind at 0°, 90°, 180°, and 270° around the map centre. Each corner base therefore has identical distances to the same objective types. Totals remain randomized in complete groups of four: sixteen to twenty-eight neutral tiles plus four bases. Non-adjacency remains enforced across the quadrant seams and beside bases. The same match seed reproduces the layout and randomized race-to-corner assignment. Player-controlled generation remains unchanged. `Testing/run_symmetric_map_tests.gd` checks symmetry, objective-distance profiles, spacing, ownership, variation, replay determinism, and player-map golden snapshots.


### Shared Human campaign (all difficulties)

Human strategic AI now uses one full-map controller on Easy, Normal, and Expert. Groups fill to four while already in the field; partial squads deploy immediately and later recruits follow their existing squad. Normal capture picks the quadrant with the fewest living enemies, breaking ties by nearest quadrant and then nearest objective. Larger hostile groups are avoided: enemies within three movement cells of the target are compared with nearby Human support within eight cells, or the full army during conquest.

At ten living Humans, all rally at the original base. Once every living Human is within fifteen movement cells of its nearest tile cell, the wave attacks the enemy race minimizing living count multiplied by combined current HP. Elimination leads to capture of that race's original base. Falling to three survivors or fewer before elimination triggers committed return to the Human base and a reset to normal on arrival. Capturing the conquered base also completes and resets the campaign. The shared controller supersedes the older Expert-only five-tile scout/casualty mission strategy, while preserving player commands and Easy/Normal's ordinary opening capture delay. Conquest takes precedence over local Human interception. `Testing/run_human_strategy_tests.gd` covers the transitions and actual combat-to-base-capture flow.


Human squads no longer wait for four recruits before moving out. Each partial squad captures normally; new recruits join and follow that squad until it has four members. Existing groups and their leaders remain stable rather than being repacked after casualties.

A group begins shared healing retreat when its summed current HP is strictly below half its summed maximum HP. Every living member receives one shared destination. The priority is an uncontested owned or historically Human-captured heart; otherwise the nearest empty heart (capturing it first if necessary); otherwise the Human base. An enemy entering the selected heart causes the whole squad to reroute. Recovery remains committed until all surviving members have reached the healing destination and regained full HP. New recruits joining that group follow its healing order. Healing squads do not initiate proximity combat and do not count as available combat support. The existing conquest rally/target rules remain; conquest casualty retreat to base takes precedence when only three attackers survive.

All AI races on every difficulty allow coincidental large formations: friendly squads can share destinations and travel side by side without strategic repulsion or separation penalties. Squad membership, racial behavior, retreat commitments and distinct occupied movement cells remain in force; groups are not forced to split apart merely for being close.


### Universal retaliation takes priority

All AI races on every difficulty retaliate against incoming attack attempts, including missed swings/shots. The victim and same-race allies within eight Manhattan movement cells pursue the attacker from any range. This response supersedes tile defence leashes, numerical attack avoidance, healing, flee and conquest orders. Every continuing attack refreshes that attacker's shared response; it ends on attacker death or after three battle seconds without an attack attempt. New attacks can redirect responders to a new attacker. Lethal opening attacks still alert surviving allies.

Strategic/recovery controllers cannot overwrite active retaliation. Recovery flags and the original objective are preserved; suspended Elf retreat travel deadlines and Orc flee itinerary time are paused while fighting, then resume afterward. Unit-lifetime checks prevent recycled attacker or responder slots from inheriting a stale pursuit. Reserved walking steps complete before combat changes state. Earlier race-specific reactive flee/in-place healing descriptions are superseded by this universal attack response; unprovoked proximity detection keeps its existing rules.


Ranged-fire retreat exception (all difficulties): Humans, Orcs and Elves with an active retreat/flee flag do not initiate retaliation or join an ally's response against a ranged attacker (attack reach greater than one). They keep their current safety destination and existing retreat movement/timers. Non-retreating allies may still respond to cover them. Melee attacks retain ordinary retaliation, as do ranged attacks outside retreat; Demons retain their existing response. This exception takes precedence over the universal retaliation rule above.


## Simplified Medieval AI — current rules (supersedes earlier strategy notes)

- Medieval units of every race use ordinary individual pursuit. Coordinated attack-slot reservations and breadth-first focus pursuit are disabled in Medieval; classic routing remains unchanged. Explicit focus commands, group target orders, range, occupancy, retaliation and tile defence still work.
- Human proximity interception, numerical permission-to-engage checks, squad objective planning, group healing and army conquest waves are removed on all difficulties. Humans use the existing individual capture/attack orders instead; Expert retains immediate strategic availability, Easy/Normal retain the global opening delay.
- Each AI Human below 50% individual HP regroups toward its nearest living Human ally. The ally is reselected at most once per second unless it dies or changes lifetime. Reaching a tile containing another living Human ends regrouping; otherwise it ends after 20 simulation seconds, including when no ally survives. A 20-second cooldown starts on completion or timeout. Regrouping does not require healing. Player-controlled Humans remain under player orders.
- Elf retreat selects the nearest owned heart or base by Manhattan distance to the tile edge, without enemy occupancy/support scans. Only ownership loss changes the selected healing tile. Selection is O(number of areas), replacing nested area-by-unit scans. Arrival or 20 simulation seconds of travel starts the 30-second cooldown. Arrival keeps full-healing recovery; timeout releases travel. Existing low-HP/threat triggers, healing/combat restrictions and retreat speed remain.
- Retreating Humans/Orcs/Elves retain the existing exception to ranged retaliation; melee attackers still trigger retaliation. Simulation time, not frame rate, controls deadlines at every game speed.

Validation: Godot 4.3 headless regression suites, including Human regroup lifecycle, Elf nearest-tile/arrival/timeout cooldowns, all-race individual pursuit, classic compatibility, retaliation and tile defence. No scene wiring or manual Godot setup is required.
