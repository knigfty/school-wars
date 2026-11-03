# Medieval Wars — Current Game Mechanics

Checked against current gameplay code on **3 November 2026**. This document describes the `/v2` Medieval rules. Shared mechanics appear first; each race's stats, exceptions, progression and AI appear only in its race section. Times are battle seconds at 1× speed unless stated otherwise.

## Contents

1. [Match, map and clock](#1-match-map-and-clock)
2. [Controls and movement](#2-controls-and-movement)
3. [Shared combat and progression rules](#3-shared-combat-and-progression-rules)
4. [Territory, healing and recruitment](#4-territory-healing-and-recruitment)
5. [Shared AI and difficulty](#5-shared-ai-and-difficulty)
6. [Humans](#6-humans)
7. [Orcs](#7-orcs)
8. [Elves](#8-elves)
9. [Demons](#9-demons)
10. [Interface](#10-interface)
11. [Implementation and verification](#11-implementation-and-verification)

## 1. Match, map and clock

- Four races start with three warriors and one corner base each. Race-to-corner assignments are shuffled using the match RNG.
- The board has **16 × 16 tiles**, each containing **4 × 4 movement cells**: **64 × 64 cells** overall. Warriors occupy cells; special-tile ownership belongs to whole tiles.
- Ordinary matches make **26 neutral-objective placement attempts**. Existing special tiles and their four side-adjacent tiles reject placements, so fewer objectives may be created. Accepted objectives are approximately two-thirds spades and one-third hearts.
- Spectator maps target **4–7 sets of four rotationally matching neutral objectives**, with matching positions/types relative to each corner and the same non-adjacency checks. Spectator mode controls all armies with AI and disables troop selection/orders.
- Eliminate all opponents to win. A player's elimination ends an ordinary match in defeat; spectator matches continue until one race remains. Bases have no building HP, and territory ownership alone does not win.
- Ordinary dead units remain in population counts and occupy cells until death cleanup. They cannot act, be targeted as living enemies, or contest capture.

The simulation runs at **18 ticks/second**. The speed button cycles **1× → 2× → 4× → 8× → 1×**, resetting on each new match. It accelerates all simulation timers together, without changing stats or relative speeds. Pause, help and quit dialogs freeze simulation; application focus loss opens pause during a running match. Frame backlog is limited after interruptions, so these timings are not wall-clock guarantees under heavy load.

Unless specified otherwise, cell distances are **Manhattan distance**: `abs(dx) + abs(dy)`. Squad-awareness radii and several strategic scores instead use straight-line distance.

## 2. Controls and movement

| Action | Control |
| --- | --- |
| Select a friendly warrior/group | Left-click or drag a selection box with no existing selection |
| Assign a tile / focus an enemy | Left-click while warriors are selected; issuing the order clears selection |
| Select all living friendly warriors | A |
| Clear selection | Space; Escape also clears selection before opening pause |
| Pause / resume a resumable dialog | Escape |
| Pan | Right-drag or Space + left-drag |
| Zoom | Mouse wheel, centred on the pointer |
| Reposition camera | Click or drag the minimap |

A tile order chooses a destination cell inside the tile, not a rigid formation. Movement uses four directions. An unobstructed baseline step takes **six ticks**, approximately **three cells/second**; speed multipliers change progress per tick. Fractional progress carries across consecutive steps.

Each moving warrior reserves its next occupied cell before its sprite reaches it. Living units and uncleared bodies block cells. Squads can share routes and destinations and coincidentally form large crowds: there is no strategic repulsion or destination-spacing penalty.

**Current pursuit uses ordinary individual movement.** It does not reserve coordinated attack slots or run the old breadth-first focus-position search. Units may wait/retry around congestion; choosing a common victim does not guarantee that everyone can reach it. Explicit focus follows a victim rather than a fixed tile, and target death clears that focus.

Routing searches still exist for returning to an assigned tile, certain retreat/regroup journeys and blocked retreat detours. A trapped returning defender can fight an adjacent enemy to open a route. These searches do not restore coordinated pursuit or allow occupied cells to overlap.

## 3. Shared combat and progression rules

### Attacks and accuracy

Each swing damages **one victim**. Extended reach does not grant cleave, splash, armour penetration or extra attack speed. There is no armour or critical-hit calculation.

All warriors have a nominal **15-tick repeating attack cycle**: two two-tick wind-up portions and eleven ticks of recovery, giving **1.2 attempts/second**. Initial setup, lost contact, hit reactions, movement and retargeting affect practical attack cadence.

| Attack | Victim condition | Hit chance for a valid attempt |
| --- | --- | ---: |
| One-cell melee | Stationary, directly in front | 90% |
| One-cell melee | Walking | Normally cannot connect; the race exception is in its section |
| Reach above one cell | Stationary, within Manhattan reach | 80% |
| Reach above one cell | Walking; attacker swings/sec greater than victim movement multiplier | 70% |
| Reach above one cell | Walking; the two displayed values equal | 50% |
| Reach above one cell | Walking; attacker swings/sec lower | 30% |

This intentionally compares **1.2 swings/second** with the target's **movement multiplier**, not cells/second. Reach is checked against reserved cell coordinates. Walking victims finish their reserved movement step after nonlethal hits; stationary victims receive a hit reaction. Extended reach is classified by the attacker's unlocked reach even when the victim is adjacent.

### Kills, assists and replacement

Successful damage records the contributor's ID, unit lifetime and tick on the victim. A qualifying damaging assist is within **54 ticks (three seconds), inclusive**, and requires the same contributor to still be alive. Repeated hits refresh that contributor's record but do not give multiple rewards for one death. A contributor can qualify even when a different race lands the final blow. Reward eligibility and amounts are defined in the race sections.

Maximum-HP rewards do **not** immediately heal. Ordinary recruits start at their race's full starting HP and reset progression, orders, assist history and personal cooldowns. Units retain earned bonuses only for their lifetime, except for the separate conversion inheritance described in its race section.

## 4. Territory, healing and recruitment

### Clearing, capture and defence

These tile-order rules apply to AI armies and the player's automatically acting warriors:

1. Clear enemies on the assigned tile, normally selecting a weak victim and sharing valid defence targets. Extended-reach units can fire into the assigned tile before entering when a victim is already in reach.
2. Once clear, stand for **one second**, then sit. An enemy returning to the tile resets clearing. Firing from outside does not capture.
3. Only seated allies generate progress. **Any living enemy on the tile contests capture**, including walkers. Friendly units do not contest one another; bodies do not contest.
4. Progress pauses when warriors leave or enemies contest. Each race retains its own partial progress until capture completes; completion changes ownership and resets everyone's progress on that tile.
5. After capture, hold and defend the assigned tile until a new order or a higher-priority AI response replaces it.

The standard capture target is **300 seated-unit ticks**. For `n` seated warriors, full capture takes `ceil(300 / n) / 18` seconds, excluding travel, clearing and standing. The race-specific replacement for this formula is in its section.

One-cell guards on an **owned** objective detect enemies within one cell of its side border. They may pursue into one directly side-adjacent tile, then return when the victim dies or leaves the allowed area. Diagonal tiles are outside this leash. Ordinary ground is not owned and does not receive this owned-objective border trigger.

Extended-reach guards detect enemies from their own cell using their own reach. They stay on their assigned tile while guarding, rather than crossing its border to extend range. Enemies inside the assigned tile take priority. Explicit focus and AI retaliation are separate orders and can override ordinary guard leashes; player guards retain their command/defence restrictions.

### Bases

An original home base is capturable only after its **original race is eliminated and its population has cleared**. Driving its defenders away is insufficient. Once conquered, it can be recaptured while its current owner is alive.

Each currently owned enemy base adds **six regular-unit capacity** and a spawning location. Losing it removes both benefits without deleting existing units. An invaded owned base normally prompts local AI defence after the spawn-standing animation, including during strategic opening delays; protected responses can override that job.

### Healing

The default healing rate is **0.1 HP per seated tick (1.8 HP/second)** on an owned heart or base, capped at maximum HP. Spades and ordinary ground do not heal. Race-specific rates, restrictions and exclusions appear only in the race sections.

Healing is not directly blocked by the capture-contest check. Fighting or movement stops seated healing, so local combat often interrupts it indirectly.

### Recruitment and capacity

Every active race has **one shared recruitment meter**, producing at most one regular recruit when ready. Default threshold: **1,500**. Default gain: **2 + owned spades per tick**. Racial overrides are in the relevant sections.

From an empty meter with fixed ownership:

`cycle seconds = ceil(threshold / gain per tick) / 18`

The default zero-spade cycle is **750 ticks, about 41.67 seconds**. Ownership changes affect the current gain without erasing existing progress. Difficulty provides no extra spawning multiplier.

Default regular capacity is **12 + 6 × currently owned enemy bases**. Racial additions/exemptions are documented separately. Losing capacity leaves existing warriors alive; ordinary recruitment waits until regular population is below the new cap.

A recruit also needs a free cell in an owned base. Successful spawns rotate through owned bases in stable area order, skipping full bases. Every base shares the same timer. If capacity or space blocks spawning, the meter holds one ready cycle; failed attempts do not consume it or bank additional recruits.

## 5. Shared AI and difficulty

### Reactions and retaliation

**Every AI race, on every difficulty, responds to valid attack attempts, including misses.** The victim and living same-race allies within **eight Manhattan cells** of it pursue the attacker. A lethal opening attack can still recruit surviving allies. This does not grant player-controlled units the enemy strategic planner.

Responses can pursue beyond tile leashes and from beyond the defender's own reach. Further attack attempts by that attacker, including attacks on other opponents, refresh responses already tracking it. New attacks can redirect responders. Attacker death/lifetime replacement or **three seconds without another attempt** ends the response; saved jobs can then resume. Occupancy and ordinary movement still constrain pursuit.

**Shared retreat exception:** retreating Humans, Orcs and Elves ignore ranged attackers (reach above one) and do not join nearby allies' ranged responses while escaping. Non-retreating allies can cover them. Melee attacks still activate retaliation. Individual recovery-entry and timer interactions are specified in each race section.

### Strategic scheduling

| Shared planner rule | Easy | Normal | Expert |
| --- | --- | --- | --- |
| Ordinary strategic organisation | Individual decisions | Squads, for races using them | Race-specific squads, for races using them |
| Squad planning interval | None | 36 ticks / 2 seconds | 18 ticks / 1 second |
| Squad opening delay | Not applicable | 400 ticks / 22.22 seconds | None |
| Squad combat awareness | Not applicable | Straight-line radius 16 cells from available members' centre; Demon territorial exception below | Same |

The individual scheduler considers **one unit-list entry per tick**. Its default eligibility requires a seated unit with at least **400 seated idle ticks**; the individual race override is in its section. Objectives use Manhattan tile distance plus random variation below four. When no objective qualifies, it can select an enemy.

The individual planner also uses a rough leader score: population plus owned spades, with a race-specific adjustment below. A score exceeding **40%** of the total marks a leader. Non-leading AI tends to choose that leader's territory/units; eligible abandoned bases bypass the territory filter. This is a preference, not an alliance.

For races using Normal squads, recruits join nearby groups up to four; a lone fifth recruit can receive a member from a larger group. Groups can act before full. A member farther than **12 straight-line cells** from its group's centre can cause a rally order. Expert rebuilds race groups on planning passes; sizes/priorities are in the race sections.

Squad objective searches can cover the whole map despite local combat awareness. If no capturable objective and no local enemy remain, squads can advance toward a distant opponent. Units busy with retaliation, recovery, interception, tile clearing/capture, base defence or returning are protected from ordinary squad reassignment. These are availability rules, not one universal priority list for every controller.

## 6. Humans

### Stats, capture and growth

**Starting HP 20 · punch 4 · reach 1 · movement 1×.** Default recruitment, capacity and seated healing apply.

Human capture replaces the standard formula:

| Seated Humans | Full capture from zero |
| ---: | ---: |
| 1 | 12 seconds |
| 2 | 9 seconds |
| 3 | 6 seconds |
| 4 | 4 seconds |
| 5 | 2 seconds |
| 6+ | 1 second |

Killing blows repeat **+2 maximum HP → +2 permanent punch → +2 reach**, without a fixed tier cap. For `K` lifetime kills:

- Maximum HP: `20 + 2 × floor((K + 2) / 3)`.
- Permanent punch: `4 + 2 × floor((K + 1) / 3)`.
- Reach: `1 + 2 × floor(K / 3)` cells.

Assists give no Human upgrade. Fighting on an owned special tile activates **+1 temporary punch**. Once active, owned-territory presence refreshes it; it lasts three seconds after leaving. It does not change permanent punch, movement or attack speed.

### AI: individual orders and regrouping

On every difficulty, Humans use basic individual capture/attack orders. Their proximity-interception controller, numerical engagement restriction, squad objectives, squad healing and conquest waves are **removed**. Shared tile defence and retaliation remain.

Easy/Normal apply a **global 400-tick opening delay** to individual strategic orders. Expert removes that opening delay. Humans do not need the default 400 seated-idle ticks between individual orders; they still must be seated, available and selected by the rotating individual scheduler. Wounds alone do not switch ordinary objective selection to healing.

Below **50% individual current/max HP**, an AI Human begins regrouping toward the nearest living Human by Manhattan cell distance. It refreshes the ally choice about once per second, or immediately when an existing target dies/changes lifetime. The destination follows that ally's current tile.

Regrouping ends when a completed movement step leaves the Human on a tile containing another living Human, or **20 seconds after regrouping begins**. A **20-second cooldown** starts then. A lone survivor waits out the deadline. Full healing is not required, and already sharing an ally's tile can complete regrouping immediately.

Entering regrouping replaces an existing response; subsequent melee retaliation can interrupt travel. Its 20-second deadline still runs during that interruption. Player-controlled Humans are not automatically regrouped. Active AI regrouping displays **`Retreat!`**.

## 7. Orcs

### Stats, recruitment and capacity

**Starting HP 10 · punch 2 · reach 1 · movement 1×.** Default seated healing applies. Ordinary kills do not grant permanent stat growth.

Recruitment threshold is **750**, twice the default rate at equal boost counts. Only spades boost Orc recruitment; hearts do not. Regular capacity is:

`12 + floor((owned spades + owned hearts) / 2) + 6 × owned enemy bases`

Converted Orcs are excluded from regular capacity. They remain valid survivors for elimination and appear separately as `(+N)`. The individual planner halves the Orc leader score before comparing leadership shares.

### Shared-target damage and conversion

An Orc gains **+1 punch for each lower-ID Orc** currently fighting the same victim with valid melee contact. Ordinary engaged attackers therefore deal **2, 3, 4, 5** punch in ID order: totals **5 / 9 / 14** for two / three / four successful attacks. Nearby or approaching allies do not count. Converted Orcs participate, but their final damage is capped at **10**.

An Orc killing blow rolls conversion using successful Orc hits on that victim in the preceding **five seconds, inclusive**, including the killing blow. Each unexpired hit adds **25 percentage points**, capped at 100%; repeated hits from one Orc count separately. Misses do not count, later hits do not refresh older stacks, and a non-Orc final blow cannot convert.

A converted victim creates a fresh Orc at the victim's cell, outside regular capacity and without consuming the recruitment meter. It inherits **maximum HP capped at 30**, starts at that full HP, and inherits **permanent punch capped at 10**. Reach resets to one. Temporary bonuses, prior race progression, selection and orders are not inherited. Conversion removes the former unit from its old race immediately; the killer displays **`ORCS RISE!`**.

### AI: groups and fleeing

Easy uses individual orders; wounded individuals can seek owned healing tiles. Normal uses the shared up-to-four squad system, favouring targets by `distance + 0.4 × enemy HP` and giving spade objectives a six-cell scoring preference. Expert groups contain up to **six**, with the same local target preference but no Normal objective-type discount.

Normal/Expert squads compare all living enemies and same-race allies within the **16-cell straight-line squad radius**. If enemies outnumber allies, eligible members flee individually. This is distinct from retained ranged-response threat assessment code; the latter is not a normal attack trigger under current retaliation priority (see implementation notes).

Fleeing lasts **ten seconds** with **1.3× movement** and **`Flee!`** overhead:

1. First five seconds: head toward the interior of the quadrant containing the fewest living enemies; ties favour the nearer quadrant centre.
2. Next five seconds: seek a capturable objective in that quadrant, preferring fewer occupants, then shorter Manhattan cell distance. Captured/ineligible objectives can be replaced. Without a candidate, keep the relocation destination.

Expiry ends the speed bonus and leaves the new tile assignment instead of resuming the old chase. Reuse is blocked until the Orc sits at the selected capture destination during phase two, or sits after the flee phase has ended; that event starts a **ten-second cooldown**. It cannot begin another flee while cooldown is pending/active. Melee retaliation suspends the itinerary; releasing that response extends the flee expiry by the response duration. Ranged fire uses the shared retreat exception.

## 8. Elves

### Stats, participation and healing

**Starting HP 25 · punch 3 · reach 1 · movement 1×.** Default recruitment/capacity apply. No owned-tile punch bonus.

Each qualifying death grants a living contributing Elf **+1 maximum HP**, once whether it killed or assisted. On Expert, AI Elves receive **+2**; player Elves still receive +1. All Elves in spectator mode are AI. These rewards do not instantly heal.

Reach depends on maximum HP above the starting 25:

| Maximum HP | Reach |
| ---: | ---: |
| 25–26 | 1 |
| 27–28 | 2 |
| 29–31 | 3 |
| 32–34 | 4 |
| 35–38 | 5 |
| 39–42 | 6 |

After five reach, each further four maximum HP adds one cell indefinitely. Growth does not raise punch or attack speed.

Elves can hit **walking enemies even at one-cell reach**; valid one-cell hits use 90% accuracy. At longer reach they use the shared ranged accuracy formula.

Owned hearts heal **0.2 HP/tick (3.6 HP/second)**; owned bases retain the default rate. Both require sitting and **three seconds without attack activity**. A valid in-range enemy fighting the Elf refreshes that timer even without a successful hit. Combat never heals.

### AI: interception, recovery and squads

On all difficulties, available AI Elves check every tick for the nearest enemy within their current Manhattan reach, including walkers and while travelling. They release interception when that target leaves reach or becomes invalid. Recovery suppresses fresh proximity interception.

Below **30% HP**, a ready AI Elf starts recovery. A threatened tile guard can also choose retreat with 50% probability when eligible; otherwise it holds its fight choice for three seconds. A valid destination is required to begin.

Recovery chooses the **nearest owned heart/base**, measured to the nearest cell in that tile. It does not scan enemy occupancy/support: an occupied healing tile can still be selected. The goal is retained rather than continually comparing distances; stopping on any owned healing tile counts as arrival. Losing goal ownership selects the nearest remaining eligible tile; no replacement means waiting until a destination appears or the travel limit expires.

Travel uses **0.7× movement** and **`Fallback!`** overhead. Arrival on an owned healing tile after a reserved step completes, or a **20-second travel timeout**, starts a **30-second cooldown**. Arrival at the deadline takes precedence over timeout when no retaliation response is active. After arrival, travel slowdown ends and recovery remains committed until full HP; it can defend locally and shared retaliation can interrupt. Timeout releases recovery without requiring full HP. Leaving or losing the occupied healing tile starts a new travel phase while recovery remains active.

**Retaliation timing detail:** while a melee response remains active, the current departure timestamp can still reach the 20-second timeout. If the response ends first, the shared response-release code shifts that timestamp forward by the response's elapsed duration. Thus interrupted travel can take longer than 20 battle seconds overall; the limit is not an unconditional wall-clock deadline. Player Elves are not automatically retreated.

Easy uses individual objectives outside these reactions. Normal uses shared squads, nearest local enemies and a six-cell objective-score preference for hearts. Expert has up to **four melee core members**; ranged supporters join the nearest group even if full. Available Expert guards prioritise an enemy fighting an ally at **20% HP or less** when within ten Manhattan cells of that ally, then capture, then ordinary local attacks. Combat candidates still originate in the 16-cell squad-awareness scan.

## 9. Demons

### Stats, progression and economy

**Starting HP 15 · punch 5 · reach 1 · movement 1×.** Default capacity applies.

Killing blows grant **+1 permanent punch** on Easy/Normal, **+2** on Expert, and restore up to **two current HP**. A qualifying damaging assist independently has a **50% chance of +1 punch** and never heals. A killer receives one killing reward, not an additional assist reward. Expert bonuses apply equally to player and AI Demons. Ordinary progression does not increase maximum HP, reach or attack speed.

Demons **cannot heal on hearts**; seated owned-base healing retains the default rate. Owned hearts instead boost recruitment exactly like spades: `gain per tick = 2 + owned spades + owned hearts`. Hearts do not add capacity or spawning locations.

| Permanent punch | Easy/Normal movement |
| ---: | ---: |
| 5–7 | 1× |
| 8–11 | 1.2× |
| 12–17 | 1.3× |
| 18+ | 1.4× |

Expert replaces those tiers with `1 + 0.05 × floor(bonus punch / 2)`, where bonus punch is permanent punch above five. Thus 7–8 punch gives 1.05×, 9–10 gives 1.10×, continuing without that tier cap.

### AI: pursuit and territorial defence

Every difficulty checks for enemies within **three Manhattan cells** each tick. Once intercepted, the victim can be pursued without a distance leash until invalid/dead; nearby hostile melee blockers are attacked before resuming the recorded pursuit. Shared retaliation can redirect that job.

Easy treats wounded Demons as available for offensive objectives instead of seeking healing. Normal groups use the shared up-to-four system. They favour weak victims and estimate hostile support within eight straight-line cells of each candidate, rejecting danger above **1.1×** group power. The strength estimate is `HP × permanent punch × (1 + 0.15 × (reach − 1))`.

Expert groups contain up to **four**. They prioritise enemies on owned objectives within territorial awareness, then capture objectives, then ordinary local group attacks. On **all difficulties**, Demon territorial awareness is **16 straight-line cells** while three rival races remain, **32** with two, and **64** with one. Eliminations use active-race state, not temporary population changes. This expands detection and response to enemies on Demon-owned objectives; ordinary squad combat awareness remains 16 cells and nearby interception remains three Manhattan cells. Easy uses individual pursuit for territorial responses. Once acquired, the existing persistent pursuit applies. Expert does not use Normal's support-strength rejection calculation.

AI Demons do not initiate healing retreats. The old casualty-based ranged-response flee branch is retained code, not a normal live response under current universal retaliation ordering.

## 10. Interface

Every victory, defeat and spectator result displays a four-row table of race, survival time (`Xm YYs`), cumulative kills and cumulative deaths. Time uses simulation ticks from match start to recorded elimination; surviving armies use the final tick. Lethal defeats count immediately, totals survive replacement recruits, and a new match resets all statistics. Final standings put the winner first, followed by reverse elimination order; equal-tick eliminations retain their recorded sequence. Early player defeat can leave several armies alive: those survivors are provisionally sorted by living units, then kills, then faction order, above eliminated armies. The result screen labels these provisional standings. The exit button reads **Return to menu**.

- The top bar reports regular population/capacity. Fallen units can remain counted until cleanup. Race-specific extra population is defined in that race's section.
- The bottom-left spawning box shows the shared meter, capacity-full/base-blocked state and an estimate based on current boosts. Spectator mode identifies itself instead of reporting one selected army's meter.
- One selected warrior shows current/max HP and base-plus-gain punch, reach, movement and attack rate. Active temporary damage bonuses are included; several selected warriors show a count instead of aggregate stats.
- Clearing selection retains the last character-info snapshot for **five interface seconds**, then hides it. This UI timer can run while battle simulation is paused. A new match/menu resets it.
- Health-bar length reflects maximum HP; green fill reflects current HP. Selection adds a white `!`. Reward popups last **30 simulation ticks** and replace the previous popup on that warrior. Race-specific retreat text is listed in its race section.
- The minimap shows living units, base ownership and the camera rectangle; it also moves the camera. Sound playback is limited to events inside the camera view.

## 11. Implementation and verification

The playable entry scene is `Scenes/Classic/classic_game.tscn`. `/` selects original School Wars; `/v2` and `/v2/` select Medieval rules through the browser pathname. Original-mode mechanics are outside this document. The project targets **Godot 4.3 / Godot 4.x**, with the existing threadless Web export and compatibility renderer. No manual scene wiring is required for these rules.

| Source | Authority |
| --- | --- |
| [classic_rules.gd](Scripts/Classic/classic_rules.gd) | Clock, board, starting stats, base constants |
| [classic_simulation.gd](Scripts/Classic/classic_simulation.gd) | Combat, movement, ownership, capture, healing, recruitment, progression and elimination |
| [medieval_human_ai.gd](Scripts/Classic/medieval_human_ai.gd) | Individual regroup lifecycle |
| [medieval_orc_flee.gd](Scripts/Classic/medieval_orc_flee.gd) | Two-phase flee and reuse cooldown |
| [medieval_elf_recovery.gd](Scripts/Classic/medieval_elf_recovery.gd) | Healing-tile selection, recovery and travel timeout |
| [medieval_proximity_ai.gd](Scripts/Classic/medieval_proximity_ai.gd) | Tick-level interception |
| [medieval_retaliation.gd](Scripts/Classic/medieval_retaliation.gd) | Attack-attempt responses, ally assistance and suspended jobs |
| [medieval_squad_ai.gd](Scripts/Classic/medieval_squad_ai.gd) | Available squad membership, target and objective choices |
| [classic_game.gd](Scripts/Classic/classic_game.gd), [classic_board.gd](Scripts/Classic/classic_board.gd), [character_info_panel.gd](Scripts/Classic/character_info_panel.gd) | Mode selection, input, display, speed and pause |

**Retained-code distinction:** `medieval_ranged_response.gd` still contains older hit-triggered group/chase/retreat routines and direct tests. Normal AI attack processing registers universal retaliation first; its guards then prevent creating those legacy groups. Their existence is not evidence that old group casualty rolls or hit-triggered flee decisions normally activate in a running match. Active shared-target squad orders and tile defence remain, even though coordinated pursuit routing was removed.

Facts were checked against the source above. Mechanics and match-results regression suites cover these rules; document links and contents anchors were also validated. Run the relevant `Testing/run_*tests.gd` scripts with Godot headless for executable checks. Web export/browser CI is defined in [.github/workflows/deploy-pages.yml](.github/workflows/deploy-pages.yml).
