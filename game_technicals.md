# Medieval Wars — The Mechanics Compendium

*A detailed guide for players who want to understand the numbers, decisions, and battlefield behaviour behind the game.*

This guide describes the current **Medieval Wars** rules, available through the medieval version of the game (`/v2`). The original School Wars mode has different rules; a comparison appears at the end. The values below describe the game as implemented, including small timing and targeting details that the short in-game help cannot explain.

**Rules checked: 2 November 2026.** These are current mechanics, not a roadmap or a list of planned features.

## Contents

1. [The match and battlefield](#1-the-match-and-battlefield)
2. [Reading distances and time](#2-reading-distances-and-time)
3. [Starting stats](#3-starting-stats)
4. [Orders, selection, and movement](#4-orders-selection-and-movement)
5. [Combat, accuracy, and attack speed](#5-combat-accuracy-and-attack-speed)
6. [Clearing, capturing, and defending tiles](#6-clearing-capturing-and-defending-tiles)
7. [Healing and recovery](#7-healing-and-recovery)
8. [Reinforcements and capacity](#8-reinforcements-and-capacity)
9. [Humans](#9-humans)
10. [Orcs](#10-orcs)
11. [Elves](#11-elves)
12. [Demons](#12-demons)
13. [Kills, assists, death, and replacement recruits](#13-kills-assists-death-and-replacement-recruits)
14. [Difficulty and enemy decision-making](#14-difficulty-and-enemy-decision-making)
15. [Reading the interface](#15-reading-the-interface)
16. [Worked battlefield examples](#16-worked-battlefield-examples)
17. [How the systems fit together](#17-how-the-systems-fit-together)
18. [Original School Wars differences](#18-original-school-wars-differences)

## 1. The match and battlefield

Four rival races fight simultaneously: Humans, Orcs, Elves, and Demons. You choose one race and command its warriors against the other three. There are no resource purchases, building queues, equipment loadouts, or manual unit upgrades in the current rules. Reinforcements arrive automatically, territory changes their strategic value, and individual survivors grow through combat.

Each race starts with **three warriors**, **12 regular-unit capacity**, and one home base. The four home bases occupy the four corners of the battlefield. Race-to-corner assignments are shuffled for each new match.

The battlefield contains **16 × 16 large tiles**. Each large tile contains **4 × 4 movement cells**, making the entire field **64 × 64 movement cells**. Warriors occupy individual movement cells; territory ownership belongs to the large tiles.

### Spectator mode and fast-forward

The **Spectator mode** button sits immediately to the right of the difficulty selector. Clicking it launches a fresh match at the chosen difficulty with **all four races controlled by AI** and no player-owned race. The observer cannot select or command troops; right-drag, Space-drag, wheel zoom, and the minimap still control the camera. The view starts centred and zoomed out to show the battlefield.

The observer's match continues through the first and second race eliminations and ends when one race remains. Its result names the victorious army, rather than announcing a player victory or defeat. **Play again** starts another spectator match at the selected difficulty. Choosing a race from the menu returns to an ordinary player match. In Expert spectator matches, all elves count as enemy AI for the +2 maximum-HP participation reward; there is no player elf faction receiving the smaller reward.

The top-right **fast-forward icon and multiplier** control battle speed in both spectator and ordinary Medieval matches:

> **1x → 2x → 4x → 8x → 1x** with successive clicks.

Every new match and replay begins at **1x**. The multiplier accelerates the whole battle clock: walking, attacks, capture, healing, reinforcements, opening delays, and AI cooldowns all advance together. For example, ten battle seconds take approximately five real seconds at 2x or 1.25 real seconds at 8x when the device can keep up. It does not change unit stats, relative movement bonuses, hit-chance formulas, or how many rules steps make one attack. Camera and menu interaction stay at normal speed, and pause freezes the battle at every multiplier. On slower devices, high-speed playback can be limited by available processing time.

The spectator HUD shows all four populations without highlighting a player faction. Its spawning box identifies spectator mode instead of showing one race's recruitment meter. Unit information remains tied to player selections in ordinary play.

### Special tiles

| Tile | Main benefit | Important restriction |
| --- | --- | --- |
| Spade | Speeds up the owner's reinforcement cycle | Does not heal or directly increase punch |
| Heart | Heals eligible seated friendly warriors; speeds demon spawning | Only demons receive its spawning boost; demons cannot heal on it |
| Base | Produces reinforcements and heals seated friendly warriors | An original home base is protected from capture until its original race is eliminated |
| Ordinary ground | Space for movement, formations, and fighting | Has no capture reward or ownership benefit |

In player-controlled matches, the map makes **26 attempts** to place neutral special tiles. An attempt is rejected if the chosen tile is already occupied by a special tile or has a special tile immediately beside it in one of the four tile directions. Consequently, there can be fewer than 26 neutral objectives. Accepted neutral objectives have approximately a **two-thirds chance of being a spade** and a **one-third chance of being a heart**. The layout and mix vary between matches.

Spectator maps instead generate **4–7 neutral objectives in one quadrant**, then repeat each position and tile kind at 0°, 90°, 180°, and 270° around the map centre. Each quadrant has the same spade/heart layout relative to its corner base. This produces **16–28 neutral objectives, plus four bases (20–32 total tiles)**, in complete groups of four. The count, locations, and kind mix vary by match seed; replaying the same seed reproduces them. The existing non-adjacency rule applies across quadrant seams and around bases. Race-to-corner assignment remains randomized. Player-controlled layouts retain their original generator.

### Winning and elimination

Victory comes from eliminating all three rival armies. Owning the most tiles, filling capacity, or taking the largest share of the map does not independently win the match. Your own race being eliminated ends your match in defeat even if multiple enemy races remain.

A base is not a destructible building with its own HP. Killing the army is what eliminates a race. The brief death sequence matters here: ordinary fallen warriors finish that sequence before they disappear from the race's population count. A successful orc conversion removes the defeated warrior from its former race immediately.

## 2. Reading distances and time

### Cells versus tiles

A **cell** is one warrior-sized step. A **tile** is a 4 × 4 group of those cells. A defence trigger one cell outside a tile is much closer than a pursuit limit one whole tile away.

Most attack and nearby-healing limits use **four-direction distance**, also called Manhattan distance:

> Distance = horizontal cell difference + vertical cell difference.

A warrior one cell horizontally and one cell vertically away is **two cells away**, even if its sprite looks diagonally adjacent. Basic one-cell melee reaches the four side-adjacent cells. Range two adds cells whose combined horizontal and vertical separation is two.

Enemy squad awareness generally uses a **straight-line radius of 16 movement cells around the squad's centre**. Some racial response and healing limits use four-direction distance instead. The relevant distinction is stated where it matters below.

### The battle clock

At **1x**, the battle advances in **18 rules steps per second**, approximately **0.0556 seconds per step**. Combat, capture, spawning, movement, and racial cooldowns use that battle clock. The visuals can animate more frequently, but a higher display frame rate does not grant faster attacks or reinforcements.

The fast-forward control multiplies that battle clock by two, four, or eight as described above. Pausing freezes the battle. Opening help, a pause dialog, or the quit dialog pauses it too. Losing application focus also brings up the pause dialog. Long frame interruptions are limited so returning to a suspended tab does not suddenly simulate an entire absence at once. Under severe performance problems, real-world timings can therefore stretch; the battle rules still advance in their usual order.

The character-info box's five-second dismissal is an interface timer. It can expire while a pause dialog is open even though battle cooldowns are frozen.

## 3. Starting stats

| Race | Starting/current maximum HP | Base punch | Base reach | Base movement | Nominal swing attempts |
| --- | ---: | ---: | ---: | ---: | ---: |
| Humans | 20 | 4 | 1 cell | 1× | 1.2 per second |
| Orcs | 10 | 2 | 1 cell | 1× | 1.2 per second |
| Elves | 25 | 3 | 1 cell | 1× | 1.2 per second |
| Demons | 15 | 5 | 1 cell | 1× | 1.2 per second |

**Punch** is the HP removed by one successful hit, before considering whether the victim has fewer HP remaining. There is no separate armour reduction, critical-hit multiplier, or race-versus-race damage chart in the current combat rules.

**Maximum HP** and **current HP** are separate. Raising maximum HP normally creates more room to heal; it does not immediately fill that room. A human at 5/20 HP who earns +2 maximum HP becomes **5/22**, not 7/22.

All races start with the same basic walking and attack cadence. Their differences come from starting HP and punch, reinforcement rules, progression, capture, healing, and enemy behaviour.

## 4. Orders, selection, and movement

### The command rhythm

With no current selection, left-click one friendly warrior or drag a box around several. With warriors selected, the next battlefield left-click issues an order:

- Click ground or an objective to assign that large tile.
- Click an enemy to focus that particular enemy.
- The order clears the selection after it is issued.

This means a click while a selection is active is a command, rather than an ordinary switch-selection gesture. Clear the selection first when you want to choose a different warrior without issuing an order. **Space** clears selection. **A** selects all living friendly warriors, including converted orcs. **Escape** clears a current selection before opening the pause dialog; it also resumes an open resumable dialog.

Right-drag or Space-drag pans the camera. The mouse wheel zooms around the pointer. Clicking or dragging the minimap moves the camera. Camera movement and zoom do not change reach, awareness, or combat speed.

### Avoiding stalled retreats and idle endgames

A retreat keeps its destination until it reaches it or valid recovery rules replace it. If a direct route is blocked, retreating warriors can search for a route around occupied cells, including taking a first step away from the destination. A warrior that becomes seated short of its retreat destination retries its travel order instead of remaining permanently excluded from other AI decisions. Occupied cells and combat restrictions still apply; this is a path correction, not teleportation or temporary immunity.

When Expert non-human squads have no capturable objectives and cannot see a local enemy, they now advance toward a surviving opponent's tile. This follows the ordinary AI's endgame advance policy and prevents two distant armies from waiting indefinitely outside one another's awareness. Combat target acquisition still uses the usual local rules; living survivors are not deleted or awarded to an army automatically.

### Where a move order sends warriors

A ground order specifies a large tile, rather than an exact formation or exact cell. Each warrior chooses a destination cell within it. They do not preserve the shape of the selection box or line up in a player-defined formation.

Warriors move in the four cell directions. One ordinary step takes **six battle steps**, giving an unobstructed baseline of **three movement cells per second**. Demon bonuses multiply that walking progress. Fractional progress is retained between consecutive steps, so a 5% or 15% speed bonus remains meaningful over a journey rather than disappearing through rounding.

Cells have occupancy: warriors cannot simply stack on top of one another. A moving warrior reserves its next cell before its sprite finishes crossing to it. This is why visually overlapping sprites do not always mean that a cell is available. Bodies also remain obstacles until their ordinary death sequence ends.

Ordinary movement chooses available steps toward the destination and can pause or retry when blocked. It is not a promise of a perfect shortest route through every crowd. Focus attacks search for reachable attack positions, and returning defenders search for a route home. Expert enemy human travel also uses routing that can detour around crowded base cells. Traffic and body blocking are therefore real tactical effects.

### Focus orders

A focus order follows a particular victim rather than committing to a fixed tile. Allies try to claim separate reachable attack positions around that victim. When the four basic melee positions are full, extra attackers close toward the target and wait for an opening instead of all occupying the same position. More than four allies can contribute if some have extended reach.

A warrior can defend itself locally while its focus target is unavailable, then return to the focus order. A reachable focus target takes priority over switching to a different attacker when it can be attacked: stationary for melee, or stationary or moving for extended reach. When the focused enemy dies, the focus ends and the warrior adopts its current tile as its new guarded position.

An explicit focus order can pursue farther than the automatic tile-defence limit. The one-adjacent-tile leash belongs to **guarding a tile**, not to every attack command.

## 5. Combat, accuracy, and attack speed

### Contact and hit chance

An attack needs a valid living enemy in reach. Basic melee also needs the victim in the cell directly in front of the attacker. Extended-reach humans and elves can connect anywhere within their allowed four-direction reach, without that single-front-cell restriction.

**Ranged attacks can hit moving targets.** In these rules, an attacker with more than one cell of unlocked reach is treated as ranged, including when its victim is adjacent. A one-cell attacker uses melee rules. Stationary includes standing, sitting, waiting, and fighting; moving means actively walking between cells.

| Attack type | Target condition | Hit chance per valid attempt |
| --- | --- | ---: |
| Ranged | Stationary | **80%** |
| Ranged | Moving; attack speed greater than target movement multiplier | **70%** |
| Ranged | Moving; attack speed equal to target movement multiplier | **50%** |
| Ranged | Moving; attack speed lower than target movement multiplier | **30%** |
| Melee | Stationary and in valid front-cell contact | **90%** |
| Melee | Moving | Cannot connect |

For moving-target accuracy, compare the displayed **attacker swings per second** directly with the displayed **target movement multiplier**. This is an intentional game rule, not a conversion to cells travelled per second. With the current attack speed of 1.2, a target walking at 1× gives 70% accuracy, at 1.2× gives 50%, and at 1.4× gives 30%. The target's current racial and difficulty-dependent speed gains count. The comparison and target state are evaluated when the hit attempt resolves, rather than locked in at the start of the wind-up.

Moving out of reach still prevents a hit. Extended reach uses the target's reserved movement cell for its range check, even while the sprite is crossing toward that cell. A nonlethal ranged hit does not cancel or restart that reserved walking step. The target can finish it before responding according to its orders and defence rules.

Punch is the damage on a successful hit, not the average damage of every animation. There is no accumulating accuracy bonus for repeated misses.

### The attack cycle

An uninterrupted repeating swing cycle takes **15 battle steps**, or about **0.833 seconds**:

| Part of repeating cycle | Duration |
| --- | ---: |
| First wind-up portion | 2 steps |
| Second wind-up portion, ending in the hit check | 2 steps |
| Recovery before the next wind-up | 11 steps |

That is the source of the interface's **1.2 attacks per second**. It is a nominal attempt rate. Starting a fight includes an initial setup, and movement, lost contact, incoming hits, and target changes can alter the practical cadence.

For a stationary, uninterrupted attacker whose swings remain valid:

> Expected damage per second ≈ punch × 1.2 × applicable hit chance.

Against a stationary target, basic melee averages punch × 1.08: a basic human therefore averages about **4.32 HP per second**, and a basic demon about **5.4 HP per second**. Extended-reach attacks against stationary targets average punch × 0.96. Against moving targets, the ranged multipliers are punch × 0.84, × 0.60, or × 0.36 for the 70%, 50%, and 30% cases respectively. These are probability averages, not guaranteed damage schedules. A short duel can diverge sharply because of misses.

Receiving a successful hit while stationary also puts the victim into a short hit reaction/recovery state. A walking victim keeps its current movement step instead. Multiple attackers can disrupt an enemy's own attack rhythm, so a crowded fight is not fully described by multiplying duel damage figures.

### One victim per swing

Every successful normal swing damages one target. Humans gain reach, but do not gain cleave or splash damage. A warrior with a very large range can reach more possible victims, but still chooses and strikes one at a time.

## 6. Clearing, capturing, and defending tiles

The following tile-order policy applies to **every race, every difficulty, and the player's own automatically acting warriors**.

### Arrival and clearing

Warriors assigned to a tile first clear enemies inside that tile. Warriors with increased reach scan the destination while approaching: if a victim on that tile is already within their reach, they stop and attack from that distance without first entering. A reachable victim takes priority over an unreachable weaker victim, and shared targeting only overrides a ranged choice when the shared victim is reachable. Melee units continue closing in. Firing from outside does not produce capture progress; when the enemies are gone, the ranged warriors resume travelling to the ordered tile, then clear, sit, and capture normally. They coordinate around a shared victim, normally preferring the weakest enemy by current HP. An existing valid shared target helps keep the group focused rather than independently scattering across enemies.

Before the tile belongs to the warriors' race, the tile-clearing order targets enemies on that tile rather than chasing them elsewhere. Ranged units may fire into it from outside as described above. Removing the last enemy starts a **one-second standing period**. If another enemy enters, clearing resumes and that clear period is reset. Once the tile remains clear, the warriors sit.

Only sitting warriors generate capture progress. Walking, standing, fighting, or merely being selected does not capture anything.

### Contested capture

Any living enemy anywhere inside the same large tile blocks capture for everyone. The opponent can be walking, standing, sitting, or fighting; it does not have to be sitting to contest. Allies do not block one another. A dead body does not contest, although it may still occupy a cell temporarily.

Capture progress is tracked separately for each race on each objective. Leaving or becoming contested pauses progress; it does not automatically drain it. A race can return later and resume its own unfinished progress. When someone completes the capture, ownership changes and **all races' accumulated progress on that tile resets**.

An enemy-owned tile remains that owner's tile while an opponent is only partway through taking it. There is no separate neutralisation stage before a second capture stage.

### Capture times from zero progress

These times measure **uncontested sitting time**, after travel, combat, and the normal one-second clear period.

| Seated warriors of the capturing race | Humans | Orcs, Elves, or Demons |
| ---: | ---: | ---: |
| 1 | 12 seconds | About 16.67 seconds |
| 2 | 9 seconds | About 8.33 seconds |
| 3 | 6 seconds | About 5.56 seconds |
| 4 | 4 seconds | About 4.17 seconds |
| 5 | 2 seconds | About 3.33 seconds |
| 6 | 1 second | About 2.78 seconds |
| 7 or more | 1 second | About 16.67 ÷ seated count seconds |

For non-humans, the exact progress target is 300, with each seated warrior adding one per battle step. Completion rounds up to a whole step: **ceiling(300 ÷ seated count) ÷ 18 seconds**. Human group sizes use the fixed times in the table; their best time stops improving at six seated warriors.

Human capture is deliberately nonlinear. Two humans are not twice as fast as one, and two non-humans actually capture slightly faster than two humans. Large human groups gain particularly strong capture speed.

### Holding and border defence

After capture, the group holds its assigned tile. An opponent inside it is dealt with before an opponent outside it.

For **one-cell melee defenders**, once the guarded tile is owned by their race, an enemy within **one movement cell of the tile's border** can trigger a coordinated defence. This is a side-adjacency test; a diagonally touching outside cell can be two steps from the nearest cell inside and will not meet the one-cell test.

**Melee defenders** may pursue a chosen threat into one **directly side-adjacent large tile**. They cannot chase it into a diagonal tile or a second tile beyond that. Killing the victim or having it leave the allowed area ends the pursuit, and defenders return to their assigned tile. If completely surrounded on the return, a warrior can fight a nearby enemy to try to free a route rather than remain helplessly trapped.

**Increased-range defenders** use their own attack reach as their detection distance, measured from their current cell. An enemy does not have to be one cell from the tile border, or even in a directly adjacent tile, to be fired upon. These defenders remain on their assigned tile while guarding: they do not step outside it to extend their range or chase an enemy that leaves reach. They may reposition inside the tile to fight an intruder. Targets inside the defended tile still take priority over outside threats.

Ordinary ground does not become owned territory. A ground order can hold and clear that location, but it does not create the owned-objective melee border-defence benefit. Increased-range warriors holding ordinary ground can still fire at enemies within their own reach.

Idle or seated defenders respond to incoming damage under these guard restrictions. Even melee defenders holding ordinary ground can return a hit from a directly reachable adjacent enemy while staying in place. A player ranged defender that can reach its attacker returns fire and holds its tile. Player melee defenders can retaliate within their ordinary permitted defence area; an attacker beyond their reach and leash cannot be countered by extending those limits.

Enemy defenders and idle tile occupants make a racial response decision when a successful ranged hit lands, **even when their own reach could hit the shooter**. These decisions apply on **Easy, Normal, and Expert**. A miss does not trigger a decision. A lethal opening hit still records the original group and prompts its survivors.

| Enemy race | Initial response | Later response |
| --- | --- | --- |
| Humans | Detect enemies within max(3 cells, attack reach) every tick | Pursue only within the encounter tile, then return and regroup; ranged hits do not create unlimited chases |
| Orcs | Each orc individually pursues | Can flee if outnumbered by nearby attacking enemies or at 20% HP or less, only when its flee cooldown is ready |
| Elves | Each threatened defender chooses fight or healing retreat with equal probability | Retreat requires a ready cooldown and safe owned heart/base; fight decisions hold three seconds |
| Demons | The tile's defenders pursue together | At least half of the original group lost: one shared 50% flee / 50% continue-fighting roll |

A response group is formed from the same race's living defenders or idle occupants of the threatened tile at the start of that response. Moving defenders assigned to that tile can participate; unrelated units travelling through it on another order do not. Later recruits do not change the original strength or casualty threshold. Repeated hits on a committed group do not reroll its choice. Converted orcs use the same individual response rules as regular orcs.

Demon and orc counter-pursuit has **no tile-distance leash**; human proximity interception remains confined to its encounter tile. Normal strategic planners do not replace a response group's commitment with unrelated capture orders or human casualty-retreat rolls. The response ends when its pursued attacker dies; surviving units then hold their current tile and become available again. An explicit replacement order can also release a unit. Existing active retreat states are not cancelled by a new hit.

Human ranged-fire responses use the local interception rules rather than shared unlimited pursuit/retreat groups; the shared Human conquest controller handles army rally and casualty retreat. Elf retreat decisions use the shared healing recovery lifecycle and arrival-based cooldown, including when triggered by a defensive threat. Demon flee survivors also share a relocation destination. Relocation ends once the surviving group reaches its destination. A lost healing destination is replaced rather than leaving the group waiting forever for healing on hostile ground.

Orcs scan **two large tiles in four-direction tile distance** around their current tile, including the boundary. They count nearby allied orcs against nearby enemies actively fighting or pursuing orcs. Nearby enemies not attacking orcs do not inflate that count. More attackers than allies triggers fleeing; an equal count does not. Low HP independently permits fleeing at **20% current HP or less**. The existing **ten-second flee window**, **ten-second cooldown starting only after reaching a tile and sitting**, and **+30% movement** apply. During cooldown they must continue attacking even if wounded or outnumbered. Fleeing now follows the two-phase itinerary below; at expiry the old pursuit is cleared and the new tile assignment remains available to continue. Each orc makes this decision separately, and the scan is refreshed as the fight moves.

**The two halves of orc fleeing:** the field is split into four 8 × 8 large-tile quadrants. At flee start, count living enemies in each quadrant and select the least populated one; a fully empty quadrant wins over any occupied one. Equal enemy counts favour the nearer quadrant centre, then a consistent quadrant order. The first **five battle seconds** send the orc toward that quadrant's interior. The second **five battle seconds** choose a capturable spade, heart, or eligible base in that same quadrant. An objective with no living enemies is preferred over an occupied one; otherwise fewer enemies, then shorter distance, decide. A completed or no-longer-eligible objective can be replaced with another eligible target in the same quadrant while the window remains active. If no capture objective exists there, the orc holds its safe relocation position instead of chasing an enemy base.

The two-phase split uses battle time, so fast-forward accelerates both halves together. Finding a distant quadrant does not teleport the orc there: the second phase starts at the halfway point even if it is still travelling. Capture still requires arrival, clearing, the standing interval, and sitting; five seconds does not guarantee a completed capture. At the end of the ten-second window the speed boost and `Flee!` label end, the old counter-pursuit is discarded, and the selected tile remains its new order. The ten-second reuse cooldown starts only after the orc reaches a tile and sits; until that event, a pending cooldown prevents restarting flee. The same itinerary is used by ordinary squad fleeing and individual responses to ranged fire.

Elves below 30% HP seek the nearest uncontested owned heart/base on every difficulty with no distance limit. Travel is 30% slower, cooldown is thirty seconds from arrival, and recovery continues to full HP. They retaliate at the healing spot without healing during combat.

Demon casualties are measured against the response's **original recorded members**, counting deaths and conversions as losses. Losing two of four, three of five, or one of two reaches the half-loss threshold. The casualty roll is made once per response; choosing to fight does not create a new 50% chance on every later hit or death. The survivors flee or continue pursuing together. This is a ranged-response exception to demons' usual refusal to retreat for healing; it does not grant heart healing or create an ordinary low-HP demon retreat.

An explicit new order can change the assignment. Enemy planners can likewise issue fresh orders to available units; the leash restricts an existing automatic defence, rather than forbidding future strategic movement.

### Base capture

An original home base cannot be captured while its original race remains active. Merely driving its defenders away does not unlock it. After that original race has been eliminated, another race can capture it using the usual uncontested sitting rules.

Once conquered, a base can be taken again while its new owner is still alive. Its protection does not reset around each new owner. Every enemy base you currently own adds **six regular-unit capacity** and becomes another reinforcement location. Losing it removes that capacity bonus and spawn location immediately.

Enemy warriors inside an invaded owned base normally prioritise intruders after their short initial standing animation. A racial ranged-fire response can release that base assignment for shared pursuit or retreat. This local defence can happen during Easy or Normal's opening strategic delay. The opening delay is not immunity from counterattacks.

## 7. Healing and recovery

Healing is automatic while an eligible warrior sits on an **owned heart or owned base**. There is no active heal button or spendable healing resource. Spades and ordinary ground do not heal.

| Race | Owned heart | Owned base | Extra condition |
| --- | ---: | ---: | --- |
| Humans | 1.8 HP/second | 1.8 HP/second | Must be sitting |
| Orcs | 1.8 HP/second | 1.8 HP/second | Must be sitting |
| Elves | 3.6 HP/second | 1.8 HP/second | Must be sitting and unattacked for three seconds |
| Demons | No healing | 1.8 HP/second | Must be sitting; also gain separate combat healing |

Healing is continuous in small battle-step increments, so current HP may contain fractions. It is capped at maximum HP.

The elf delay is stricter than “no successful damage for three seconds.” An enemy actively fighting the elf from within its attack reach refreshes the attacked timer, even when individual swings miss. Escaping a damaging hit but remaining under valid attack does not let the elf quietly regenerate.

Healing eligibility does not itself use the capture-contest test. However, tile defence normally gets seated defenders up to fight intruders, which stops their seated healing in practice. Enemy retreat thresholds are AI decisions; they do not change the underlying healing rates available to player-controlled warriors.

## 8. Reinforcements and capacity

### Automatic spawning

Each race has one shared reinforcement meter. It advances continuously while the race is active, including while its army is fighting elsewhere. Each completed cycle tries to create **one regular warrior**.

The meter's progress per battle step is:

> Humans, Orcs, Elves: 2 + currently owned spades.
>
> Demons: 2 + currently owned spades + currently owned hearts.

Its target is **1,500 for Humans, Elves, and Demons**, and **750 for Orcs**. Consequently, medieval orcs spawn twice as fast as the other races when both sides have the same number of spawning-boost objectives. Demon hearts count toward that comparison.

Starting from an empty meter with ownership unchanged:

> Cycle seconds = ceiling(target ÷ (2 + spawning-boost objectives)) ÷ 18.

For demons, a heart counts exactly like one spade for this formula. For the other races, only spades count.

| Spawning-boost objectives | Human / Elf / Demon cycle | Orc cycle |
| ---: | ---: | ---: |
| 0 | 41.67 seconds | 20.83 seconds |
| 1 | 27.78 seconds | 13.89 seconds |
| 2 | 20.83 seconds | 10.44 seconds |
| 4 | 13.89 seconds | 6.94 seconds |
| 6 | 10.44 seconds | 5.22 seconds |

These are full-cycle timings under steady conditions, not necessarily the time remaining on a partially filled meter. Capturing or losing a spade changes the rate of the current cycle; capturing or losing a heart does the same for demons. It does not erase that cycle's existing progress. A spade's reinforcement benefit persists without a garrison as long as ownership remains yours.

Difficulty does not shorten the meter or provide a hidden reinforcement-rate multiplier.

### Capacity formula

For Humans, Elves, and Demons:

> Regular capacity = 12 + 6 × currently owned enemy bases.

For Orcs:

> Regular capacity = 12 + floor((owned spades + owned hearts) ÷ 2) + 6 × currently owned enemy bases.

Only non-base objectives count toward the orc tile-pair bonus. A heart can increase orc capacity even though it does not speed the reinforcement meter. Bases have their separate +6 bonus.

Capacity can fall below your existing population when territory is lost. Existing warriors are not deleted; regular recruitment waits until population falls below the new cap. Converted orcs sit outside regular capacity altogether.

### Full capacity and blocked bases

A regular recruit needs both an available capacity slot and a free movement cell in an owned base. The base has 16 cells. Friendly warriors, enemies, and uncleared ordinary bodies can obstruct them.

When spawning is prevented, the meter stops at ready rather than repeatedly consuming failed cycles. Once the blocker is removed, a ready meter can create a recruit on the next eligible battle step. There is no bank of several completed cycles: the game holds one ready reinforcement.

With several owned bases, successful spawns rotate between them in a consistent turn order. A full base is skipped when another owned base has a free cell. Extra bases therefore improve capacity, deployment options, and resilience to a blocked base; they do not each receive an independent spawning timer.

## 9. Humans

Humans combine repeatable personal growth, large-group capture speed, and a temporary owned-territory damage bonus.

### Repeating kill progression

Only the warrior landing the killing blow advances the human kill cycle:

| Lifetime killing blows | New reward | Maximum HP afterward | Permanent punch afterward | Reach afterward |
| ---: | --- | ---: | ---: | ---: |
| 0 | Starting stats | 20 | 4 | 1 |
| 1 | +2 maximum HP | 22 | 4 | 1 |
| 2 | +2 punch | 22 | 6 | 1 |
| 3 | +2 reach | 22 | 6 | 3 |
| 4 | +2 maximum HP | 24 | 6 | 3 |
| 5 | +2 punch | 24 | 8 | 3 |
| 6 | +2 reach | 24 | 8 | 5 |
| 9 | Third reach reward | 26 | 10 | 7 |

The sequence continues without a fixed upgrade-tier cap. For **K** lifetime kills:

- Maximum HP = **20 + 2 × floor((K + 2) ÷ 3)**.
- Permanent punch = **4 + 2 × floor((K + 1) ÷ 3)**.
- Reach = **1 + 2 × floor(K ÷ 3)** movement cells.

These rewards do not raise movement or attack speed. HP rewards raise the maximum without an instant heal. There is no human assist reward and no multi-target cleave.

### Territorial punch

Fighting on any owned special tile grants **+1 temporary punch**. It lasts **three battle seconds after leaving owned territory**. Once active, being on owned territory keeps the grace window refreshed. It is one point of damage, not a multiplier, and it does not permanently add to the kill-earned punch stat.

For example, a two-kill human has six permanent punch, deals seven with the territorial bonus, and returns to six after the grace period expires away from owned tiles.

The human event messages are `+2 HP`, `+2 PUNCH`, and `+2 RANGE`, matching the reward actually granted.

## 10. Orcs

Orcs begin with low individual durability and punch but compensate through faster reinforcements, territorial capacity, shared-target damage, and conversion.

### Shared-target punch

When several orcs are actively engaged on the same victim, each attacker gains **+1 punch per earlier eligible attacker**, using stable unit-ID order. Their group bonuses are +0, +1, +2, +3.

For ordinary two-punch orcs, a fully engaged group has this nominal damage distribution:

| Engaged orcs on the victim | Punch values across the attackers | Sum if every listed attack connects once |
| ---: | --- | ---: |
| 1 | 2 | 2 |
| 2 | 2, 3 | 5 |
| 3 | 2, 3, 4 | 9 |
| 4 | 2, 3, 4, 5 | 14 |

The last column is not DPS; misses and attack timing still apply. Being nearby, walking toward the victim, or merely belonging to the same squad is insufficient. An earlier qualifying orc must actually be fighting that target with valid contact. Inherited permanent punch on converted orcs changes their baseline, and the group addition follows its position among the engaged attackers. Converted orcs can both activate and receive this group bonus like regular orcs. Their final punch is capped at ten, so a converted warrior already at ten gains no extra damage beyond that cap.

### Conversion chance

Conversion is checked **only when an orc lands the killing blow**. The chance depends on how many successful orc hit stacks remain on that particular victim from the preceding five battle seconds, including the killer's final hit:

| Unexpired successful orc hit stacks | Conversion chance |
| ---: | ---: |
| 1 | 25% |
| 2 | 50% |
| 3 | 75% |
| 4 or more | 100% |

Each successful damaging attack adds a separate +25 percentage-point stack, even from the same orc. Each stack expires independently five seconds after its own hit; later hits do not refresh older stacks. Misses do not qualify. The five-second boundary is inclusive. A contributing orc does not have to still be alive for its unexpired hits to count toward the conversion roll; this differs from receiving an individual living-assistant reward.

Conversion is rolled once on death. It does not accumulate a meter across several different victims, and a non-orc final blow cannot convert the victim merely because orcs assisted.

### What a converted orc inherits

The defeated warrior becomes a new orc at the victim's cell. The recruit:

- Inherits the victim's **maximum HP, capped at 30**, and starts fully healed to that capped maximum.
- Inherits the victim's **permanent punch, capped at ten**, including earned punch bonuses. Orc group damage applies afterward, but final punch remains capped at ten for converted orcs.
- Starts with **one-cell reach**, regardless of the victim's former reach.
- Does not retain the former race's progression, special speed scaling, focus orders, or selection.
- Does not inherit temporary human territorial punch or snapshot the victim's temporary group bonus. As an orc, it receives and contributes to current orc group damage normally.
- Does not use a regular capacity slot or consume the reinforcement meter.

For example, a human with 26 maximum HP and ten permanent punch becomes a **26/26 HP, ten-punch orc** if converted. A victim with 60 maximum HP and 20 permanent punch instead becomes a **30/30 HP, ten-punch orc**. A formerly long-range elf becomes a one-cell melee orc; its inherited maximum HP is also limited to 30.

Converted orcs can take normal orc orders, receive orc group damage, and contribute to later conversions. Their population is shown separately as `(+N)`. A converted survivor can keep the orc race alive even after every regular orc has fallen. The successful-conversion popup is `ORCS RISE!`.

## 11. Elves

Elves begin with the highest HP and turn damaging participation into durability and reach.

### Kill and assist growth

A living elf receives **+1 maximum HP** when a victim it successfully damaged within the last three seconds dies. The killing blow also qualifies; it does not grant an additional second assist reward. Several hits on that victim still produce just one reward for that death.

In Expert, **enemy AI elves gain +2 maximum HP** for each qualifying kill or assist. Player elves remain at +1. This is an explicit difficulty asymmetry.

The reward does not instantly heal. A wounded veteran's maximum can rise while its current HP stays unchanged.

### Reach from bonus HP

Elf reach uses progressively larger HP steps above the original 25 maximum:

- First two extra cells: +1 reach per 2 bonus HP, reaching 3 cells at 29 maximum HP.
- Next two extra cells: +1 reach per 3 additional HP, reaching 5 cells at 35 maximum HP.
- Thereafter: +1 reach per 4 additional HP forever.

| Maximum HP | Reach |
| ---: | ---: |
| 25–26 | 1 cell |
| 27–28 | 2 cells |
| 29–31 | 3 cells |
| 32–34 | 4 cells |
| 35–38 | 5 cells |
| 39–42 | 6 cells |
| 43–46 | 7 cells |

There is no fixed reach-tier cap. The field's finite size still limits useful distance. Owned tiles no longer grant elves a punch bonus. Bonus HP does not increase punch, movement speed, or attack speed.

Because assists count, several elves can all grow from the same victim. A basic player elf needs two qualifying deaths to unlock its first extra cell. An Expert enemy elf needs one, reaching 27 maximum HP.

### Healing identity

Owned hearts heal elves twice as quickly as the general healing rate. Bases retain the ordinary rate. Both require sitting and the three-second unattacked window. A heart is therefore an especially valuable recovery point for an experienced elf, but retreating under continuing attack can prevent healing from starting.

An elf's popup shows the old maximum followed by the gain: `30 + 1 HP` means its maximum has just risen from 30 to 31. Expert enemy rewards can show `+ 2 HP` instead.

## 12. Demons

Demons begin with the strongest punch and convert combat participation into more damage, combat healing, and movement speed.

### Punch growth and combat healing

| Event | Easy / Normal punch reward | Expert punch reward | Healing |
| --- | ---: | ---: | ---: |
| Demon lands the killing blow | +1 | +2 | Restore 2 current HP |
| Demon provided a qualifying damaging assist | 50% chance of +1 | 50% chance of +1 | None |

Expert's demon rewards apply to **both the player's demons and enemy demons**. A killer receives its killing reward once; it does not additionally collect assist punch or assist healing for the same death. Healing cannot exceed maximum HP.

Ordinary demon progression raises punch rather than maximum HP. There is no fixed punch-tier cap.

### Movement on Easy and Normal

Movement depends on total permanent punch:

| Permanent punch | Movement multiplier | Unobstructed walking rate |
| ---: | ---: | ---: |
| 5–7 | 1× | 3 cells/second |
| 8–11 | 1.2× | 3.6 cells/second |
| 12–17 | 1.3× | 3.9 cells/second |
| 18 or more | 1.4× | 4.2 cells/second |

These are thresholds, not additions stacked together. Reaching 18 punch gives +40% total movement, not +20% +30% +40%.

### Movement on Expert

Expert replaces those thresholds with continuing scaling:

> Movement multiplier = 1 + 0.05 × floor(bonus punch ÷ 2).

Bonus punch means permanent punch above the starting five.

| Total permanent punch | Bonus punch | Expert movement bonus |
| ---: | ---: | ---: |
| 5–6 | 0–1 | 0% |
| 7–8 | 2–3 | +5% |
| 9–10 | 4–5 | +10% |
| 11–12 | 6–7 | +15% |
| 15–16 | 10–11 | +25% |
| 25–26 | 20–21 | +50% |

The formula continues beyond the table. Expert is not simply the Easy/Normal speed table plus another bonus: the curve is different, including smaller early bonuses and no old +40% tier ceiling.

Movement upgrades do not speed up the attack cycle. Demons remain one-cell attackers. They cannot heal from hearts, but can heal while seated on an owned base and through the combat rewards above. Each owned heart instead accelerates their team's reinforcement meter exactly like a spade, on every difficulty and for player and enemy demons. A demon heart does not add capacity or become a spawn location; it boosts the shared timer while owned, even without a seated garrison. Enemy demons do not choose healing retreats.

A demon popup such as `8 + 1 PUNCH` reports the old permanent punch followed by the gain: the warrior now has nine punch. An Expert killing blow can display a gain of two.

## 13. Kills, assists, death, and replacement recruits

### What qualifies as an assist?

A qualifying assistant must have successfully damaged the eventual victim within **three battle seconds**, including a hit exactly three seconds earlier. Merely targeting, surrounding, chasing, or missing the victim is insufficient.

For elf and demon rewards, the contributor must still be alive and must be the same living warrior that made the hit. A newly recruited replacement does not inherit credit from a predecessor. Each contributor receives at most one participation reward from that death, regardless of hit count. Humans only receive their own killing-blow progression; ordinary orcs have no separate permanent kill-stat reward.

Participation rewards do not require the victim's killer to belong to the contributor's race. In a three-way battle, a living elf or demon that recently damaged a victim can receive its appropriate assist reward when another race finishes that victim. Orc conversion still specifically requires an orc final blow.

### Death and replacement

At zero HP, a warrior stops acting and is no longer a living target or capture contestant. Its normal death sequence lasts about **1.6 battle seconds** before the body and population entry clear. During that brief interval it can still occupy its cell and count against regular capacity. This explains momentary differences between visibly living troops, the population display, and whether a replacement can spawn.

Regular reinforcements are fresh warriors with full starting HP and starting race stats. They do not inherit the fallen warrior's kills, reach, punch growth, damage-assist history, or personal AI cooldowns. Surviving veterans retain their own gains for their lifetime. Successful conversion is a distinct inheritance event, not ordinary replacement spawning.

The final elimination check happens as warriors finish disappearing, or immediately when conversion removes a victim from its former race. A ready reinforcement may replace an earlier casualty while other population remains, but the game does not revive a race after it has been declared eliminated.

## 14. Difficulty and enemy decision-making

Difficulty primarily changes how enemy armies organise and choose orders. Local combat, manual commands, capture contention, and the shared tile-defence leash still apply across difficulties.

The player's warriors carry out their orders and the shared automatic defence rules. The new racial ranged-fire response choices are enemy-only. They do not receive the enemy strategic squad planner. Choosing Expert therefore does not make your own army autonomously select all the same missions as Expert enemies.

| Feature | Easy | Normal | Expert |
| --- | --- | --- | --- |
| Strategic opening | Individual idle delay of at least about 22 seconds | About 22.22 seconds before squad planning starts | No strategic opening delay |
| Strategic organisation | Individual decisions | Groups usually 2–4 | Race-specific groups |
| Squad decision interval | No common squad interval | Every 2 battle seconds | Every 1 battle second |
| General squad enemy-awareness radius | Individual rules instead | 16 cells from group centre | Usually 16 cells from group centre |
| Racial spawn rates | Standard medieval rates | Same | Same |
| Tile clearing and defence | Shared rules | Shared rules | Shared rules |

“Immediate” Expert planning does not mean every starting warrior teleports into action on the first step. Initial standing animations, movement, and higher-priority local jobs still take time.

### Local jobs take priority

A warrior busy clearing or capturing its assigned objective, responding to a base invasion, returning from a defence, or carrying out another protected local response is not freely reassigned by every strategic planning pass. The racial ranged-fire responses described earlier can deliberately replace a defensive tile/base job and then keep their own commitment against ordinary strategic reassignment. A held friendly tile can later be given a new mission. Consequently, a listed strategic priority is a choice among **available** units, not a guarantee that every wounded or nearby unit instantly abandons its current battle.

### Easy: individual objective choices

Easy considers one potential individual decision per battle step, rotating through the population. A warrior must be seated and have built up at least **400 seated idle steps**, about 22.22 seconds, before it qualifies for an individual strategic order. Travel, standing, fighting, and which warrior is being considered can make its departure later. This is not a global promise that every enemy moves at the same instant.

Healthy warriors look for capturable objectives. Wounded non-demons instead look for owned healing tiles. Demons are treated as ready to continue offensive activity even when wounded. Objective preference combines four-direction tile distance with a small random variation. If no suitable objective is found, the warrior can choose an enemy target.

Easy also tracks a rough leader: active population plus owned spades, with the orc value halved. A race qualifies as a leader when its value exceeds 40% of the combined total; if several qualify, the current selection follows the game's race-check order. Other Easy enemies tend to concentrate choices against that leader. This is a targeting preference, not a formal alliance: they can still fight one another locally, and eligible abandoned bases have an exception to the objective filter.

Easy has no ordinary strategic squad coordination. The racial ranged-fire response groups and orc flee cooldown described above still apply. Shared tile-clearing focus and border defence still work, so “individual AI” does not mean four enemies assigned to one tile will ignore a shared intruder.

### Normal: coordinated small groups

After the opening delay, Normal builds same-race groups of up to four, fills nearby groups with recruits, and avoids leaving a fifth unit alone where a larger group can split into three and two. Groups are not required to wait until full before acting.

Groups make a fresh strategic decision every two seconds. Their usual attack awareness is 16 cells around the group centre. Widely separated members can receive a rally order before advancing; a member more than 12 cells from the centre can trigger this regrouping. This is a loose squad system, not rigid formation movement.

- **Humans** use the shared full-map capture and conquest strategy described below.
- **Orcs** favour a shared victim based on distance and current HP. When nearby enemies outnumber nearby allies, eligible orcs use the two-phase ten-second flee itinerary: relocate toward the least-enemy quadrant, then seek a capture target within it. Each warrior waits for a ten-second cooldown that starts only after reaching a tile and sitting.
- **Elves** use the shared recovery rules on every difficulty: below 30% HP, nearest safe owned heart/base at any distance, 30% slower travel, thirty-second cooldown from arrival, full HP before resuming normal orders. Threatened tile defenders can choose fight or retreat; a fight choice holds for three seconds.
- **Demons** favour weak nearby victims, while comparing their group's combat strength against nearby defenders. Their estimate combines current HP, permanent punch, and extra reach. They can reject a locally dangerous attack instead of blindly focusing the nearest enemy. They never retreat specifically to heal.

When seeking objectives, Normal orcs favour spades and Normal elves favour hearts. Normal's strategic objective search is not restricted to the 16-cell combat-awareness radius. If no capturable objectives remain and no local victim is available, a group can advance toward a more distant opponent. Awareness radius should therefore not be read as universal fog of war.

### Human strategy on all difficulties

Humans use full-map awareness on Easy, Normal, and Expert. Their ordinary capture groups contain four warriors when available; partial squads deploy immediately and later recruits join them until they reach four. An initial army below four can still capture. Squad membership remains stable across casualties; later recruits fill vacancies without pulling field squads back to base. Capture destinations are ranked first by total enemy population in their quadrant, then by distance to that quadrant, then distance to the objective. Quadrants without an eligible objective are skipped. Humans do not initiate combat against a larger enemy group: a hostile group consists of living enemies within three movement cells of the prospective target; ordinary support counts nearby Humans within eight movement cells. Conquest uses the whole living Human army. Existing Easy/Normal opening delays are retained for ordinary strategic capture.

At **ten living Humans**, the army enters **conquest rally**. Every current Human, including new recruits, is sent toward its original base. The wave releases only when every living Human is within **fifteen Manhattan movement cells of the nearest cell of the base tile**. It then chooses the enemy race with the lowest `living unit count × combined current HP`, ignoring eliminated races. All Humans share a focus target from that race. The chosen race remains committed until elimination, rather than being switched when relative strength changes.

After the race is eliminated, the army captures its original base and returns to normal strategy. If the attacking army instead falls to **three living Humans or fewer** before elimination, survivors commit to returning to the Human base; arrival resets conquest to normal. Local interception and older Expert mission planning cannot overwrite conquest rally, attack, capture, or retreat orders. Player-controlled Humans keep their existing command behavior.

### Expert Orcs: larger focus groups

Enemy orcs form groups of up to **six**. They keep the shared-target preference and the locally outnumbered escape behaviour: up to ten seconds of fleeing, with a ten-second personal cooldown starting only after reaching a tile and sitting. The surrounding ally-versus-enemy count uses the group's 16-cell awareness area.

Six group members do not create six adjacent melee slots. Only warriors actually landing recent damage increase conversion probability; the ordinary four-slot melee geometry still matters.

### Expert Elves: recovery, protection, shared destinations

Enemy elves form groups of up to **four core warriors**. Elves whose reach has grown beyond one cell can join a full group as ranged support, so the total headcount can exceed four.

Among available units, their strategic ordering is recovery, protection of badly wounded allies, capture, then ordinary group attacks. An enemy actively fighting an elf at 20% HP or lower receives high protection priority when an available guard is within **ten four-direction movement cells** of the wounded ally. Only nearby eligible responders are sent.

AI elves on every difficulty begin recovery **below 30% HP** and choose the nearest owned heart/base with no living enemies. There is no distance limit. Retreat travel runs at **70% movement speed** and remains committed until reaching a safe healing tile, rerouting if the goal is lost or contested. The **30-second cooldown starts on arrival**. Recovery continues until **100% HP**. At the healing spot, elves retaliate in place against attackers in reach; fighting and incoming attacks block healing. A threatened tile defender may choose fight or retreat with equal probability, subject to cooldown and a safe goal. Choosing fight holds that choice for three seconds before reconsideration. Player commands remain unchanged.

Groups do not penalise capture destinations near other squads or destinations already selected by another squad. Multiple groups may independently choose the same objective and travel together.

Enemy elves also receive the Expert +2 maximum-HP participation reward described earlier. Player elves do not.

### Expert Demons: defend, expand, attack

Enemy demons form groups of up to **four**. They strongly prioritise enemies occupying demon-owned objectives when an available responder is within **ten four-direction movement cells** of the intruder. These checks also sit within the normal local enemy-awareness scan.

After urgent defence, they prefer capturable objectives, then ordinary local group attacks when no objective is selected. Their target scoring also favours lower-HP victims. Expert demon planning is not the same strength-rejection calculation used by Normal demons.

Demons never choose healing retreats. Their survival tools are successful combat, kills and assists, and any ordinary base healing obtained while seated. Expert's +2 killing-blow punch and continuing movement formula apply equally to player and enemy demons.

## 15. Reading the interface

### Population display

A display such as `Orcs 8 (+3)/14` means eight regular orcs, three converted orcs, and a regular capacity of 14. The converted population does not fill the 14 regular slots. Brief death sequences can keep a fallen warrior in a displayed population until it clears.

### Spawning box

The bottom-left box reports the next reinforcement cycle, full capacity, or a blocked base. The progress bar belongs to the shared race-wide meter. Its countdown is an estimate based on current spawning-boost objectives; capture or loss of a spade, or a heart for demons, can change it partway through the cycle.

### Character-info box

Selecting one friendly warrior displays its current details in the bottom-centre panel, styled like the spawning box:

| Field | How to read it |
| --- | --- |
| `HP: 5/22` | Five current HP out of 22 maximum HP |
| `PUNCH: 4 + 3` | Four base punch plus three currently displayed bonus punch |
| `RANGE: 1 + 2` | One base cell plus two gained cells, for three total |
| `MOVEMENT SPEED: 1 + 0.2×` | Base movement multiplier one plus 0.2, for 1.2× walking speed |
| `ATTACK SPEED: 1.2 + 0/s` | Base 1.2 attempts per second with no earned attack-speed gain |

Punch includes currently active human territorial or orc shared-target bonuses where applicable. Thus its displayed gain is not necessarily all permanent progression. Converted orcs use the normal orc base of two in the display, with the inherited difference shown as gained punch. Current HP may be shown with decimals because healing uses fractional increments.

Information refreshes while the warrior remains selected. Selecting several shows **`Number of units: <count>`**, rather than summed or averaged stats. Clearing selection retains the last displayed snapshot for five seconds and then hides it. Giving an order also clears selection, so it begins that same dismissal period. A new selection replaces the old snapshot immediately. Death removes a warrior from the live selection; a new match or returning to the menu clears the panel.

On narrow layouts the panel can sit above spawning so the text remains readable. The panel is informational and does not change stats or issue orders.

### Retreat indicators

Enemy humans show **`Retreat!`** while their retreat mode is active. Enemy orcs show **`Flee!`** throughout their active flee window, and enemy elves show **`Fallback!`** while retreating. These labels persist with the state rather than fading like reward popups, and sit above those popups so a new reward does not hide the retreat indication. They clear when the mode ends or the warrior dies, and do not appear on the player's units.

Enemy orcs receive **+30% movement speed (1.3×)** only while actively fleeing and before their flee window expires. The boost stops at the window boundary or when fleeing is cancelled. It applies to converted enemy orcs too. Ranged accuracy uses that boosted speed: the current 1.2 attacks/second is slower than a fleeing orc's 1.3× movement, giving a 30% ranged hit chance. These display and speed rules apply on every difficulty whenever the relevant retreat state is active; they do not introduce new retreat triggers into difficulties that lack that behaviour.

### Health bars, popups, and minimap

A warrior's green HP portion is drawn over its red maximum-HP background. The bar's absolute length reflects maximum HP, so a grown veteran can have a wider bar than a new recruit. A white `!` marks a selected living warrior.

Reward messages show specific gains instead of a generic level-up message. They remain for about **1.67 battle seconds**; a new event replaces the previous event for that warrior. Elf HP and demon punch popups show the value **before** the displayed addition.

The minimap shows living warriors and, in Medieval Wars, base ownership. Its outlined rectangle indicates the current camera view. It is a navigation tool, not a second set of different combat rules. Battle sound cues are limited to events within the current camera view; an unheard off-screen hit can still resolve normally.

## 16. Worked battlefield examples

### A four-human capture party

Four humans reach a neutral spade occupied by two enemies. They focus intruders inside the objective, without following a retreating defender outside the uncaptured tile. Once it is clear, they stand for one second, then sit.

Four seated humans need four uncontested capture seconds from zero progress. Ignoring the journey and fight, the normal clear-and-capture portion is therefore about **five seconds**. If a living opponent enters after two capture seconds, progress pauses. Removing it and completing the next clear period lets the remaining progress continue.

After capture, all four hold the tile. A threat one movement cell outside its side border can trigger defence, with pursuit limited to the tile and a directly adjacent tile. The spade improves human reinforcement speed even while the defenders are briefly outside it.

### A recently wounded human earns maximum HP

A human at 5/20 HP lands its first killing blow. It becomes **5/22 HP**, retains four permanent punch, and displays `+2 HP`. Sitting on an owned heart would recover the missing 17 HP in about **9.44 seconds of uninterrupted healing**, apart from arrival and sitting delays. The second kill grants punch; the third grants reach.

### Four orcs do not guarantee conversion just by arriving

Four orcs surround an elf. If only two successful hits occurred in the final five seconds, including the killing blow, the conversion chance is **50%**. Four unexpired hit stacks raise it to 100%, even if one orc landed all four attacks. A human stealing the final blow prevents the conversion roll altogether.

### An elf grows without securing the final hit

Three player elves each successfully damage one enemy, and all remain alive. A different warrior kills that enemy within three seconds of all three elves' hits. Each elf gains one maximum HP. None needs the final blow, and none gains an extra reward for having landed several hits.

If the victim had 1 HP remaining, one tiny successful contribution still qualifies; assist credit has no minimum damage-share percentage.

### A demon's Expert progress

An Expert demon begins at five punch. One killing blow grants +2 punch and restores up to two current HP, taking it to seven punch and **+5% movement**. A qualifying assist afterward has a 50% chance to add one punch and never heals; a successful roll takes it to eight punch. It still has +5% movement because only complete pairs of bonus punch count. Another successful assist roll brings it to nine punch and +10% movement.

Its swing-attempt rate remains 1.2 per second throughout.

### Losing land while over capacity

An orc army owns four spades, two hearts, and one conquered base. Its regular capacity is:

> 12 + floor(6 ÷ 2) + 6 = **21**.

With four spades, a fresh orc reinforcement cycle takes about 6.94 seconds. If it has 21 regular orcs and five converted orcs, the display can read `21 (+5)/21`.

Losing the conquered base lowers regular capacity to 15. None of the 26 existing orcs is deleted. Regular spawning waits until regular population falls below 15. New conversions remain possible above that limit.

## 17. How the systems fit together

The rules create several connected pressures:

- **Territory and army growth:** spades shorten the replacement cycle; hearts preserve experienced survivors; conquered bases add capacity and deployment locations. A valuable objective can therefore matter even when no warrior remains sitting on it.
- **Quality and replacement:** regular recruits return at starting strength, while surviving humans, elves, and demons accumulate lifetime advantages. Reinforcement volume and veteran preservation solve different problems.
- **Focus and participation:** concentrating damage removes a victim quickly, but melee access is limited. Orcs benefit from repeated successful hit stacks; elves and demons benefit from qualifying assists. Reach growth lets veterans participate from additional cells.
- **Commitment and distraction:** tile orders provide a bounded clear-capture-defend job. Focus orders pursue a chosen warrior. A melee guard can be drawn into the adjacent tile; a ranged guard fires while staying on its own tile. An enemy choosing a distinct counter-pursuit order after taking ranged damage can chase without that guard leash.
- **Probability and positioning:** hit chance creates uncertainty, while occupied cells, valid contact, retreat paths, and available attack positions determine how many useful hit attempts happen at all.
- **Race-specific territory value:** human groups exploit capture breakpoints; orcs turn hearts and spades into capacity; elves recover especially well on hearts; demons rely on bases and combat healing instead of heart regeneration, while using hearts as additional spawning accelerators.

These are practical consequences of the current rules, rather than promises about a single optimal strategy. Random hits, a different map, three-way intervention, or a crowded base can change which choice pays off.

## 18. Original School Wars differences

The original School Wars mode remains a separate playable ruleset. The medieval race names and progression should not be assumed to apply there.

| Mechanic | Medieval Wars | Original School Wars |
| --- | --- | --- |
| Factions | Humans, Orcs, Elves, Demons | Black, Green, Yellow, Purple |
| Starting HP and punch | The four race baselines listed above | Same four starting HP and punch baselines by faction order |
| Green / Orc recruitment | Orc target 750; twice the other races' speed | Green target 500; three times the other factions' speed |
| Kill progression | Race-specific kills and assists | Killer gains +1 maximum HP; no instant heal |
| Range growth | Human kills and elf bonus maximum HP | Basic one-cell combat |
| Accuracy | Ranged: 80% stationary, 70%/50%/30% moving by speed comparison; melee: 90% stationary | Original 50% hit chance; walking victims cannot be hit |
| Conversion | Orc final-blow mechanic | None |
| Capture | Human group breakpoints; living enemies contest | Seated progress at the original 300-step target; opposing presence does not use the medieval global contest rule |
| Base capture and expansion | Eliminated races' bases can be conquered, adding capacity and spawn locations | Bases are not capturable |
| Healing | Race-specific restrictions and bonuses | Seated friendly heart/base healing at 1.8 HP/second |
| Strategic difficulties | Easy, Normal, Expert | Original individual enemy decision system |
| Automatic tile defence | Shared medieval clear-capture-defend policy | Original engagement behaviour |
| Character-info panel | Available | Not added to the original mode |

Both modes share the four-corner battlefield concept, automatic reinforcements, cell occupancy, the basic attack-cycle rhythm, camera controls, and elimination as the match objective. When comparing advice or old screenshots, first check which mode the player was using.

Return movement recovery: an interrupted return resumes routing from a stationary state instead of remaining excluded from the planner indefinitely. Ranged units do not reacquire destination-tile enemies until their return completes. Returns starting outside the adjacent-tile defence area can route inward; ordinary guard returns retain their existing leash. This uses simulation ticks at every playback speed.


Enemy interception runs every simulation tick on every difficulty. Elves acquire moving and stationary enemies within their reach even during travel; a reserved step finishes before attacking. At one-cell reach, elves are the exception to the ordinary melee restriction on moving targets. Healing recovery suppresses initiation but permits retaliation without healing during combat. Demons acquire within three Manhattan movement cells and pursue their chosen enemy until either side dies, regardless of subsequent distance. Humans acquire within max(3, current attack reach), cannot route outside their encounter tile, and return there to regroup when combat ends. Their strategic squads resume after regrouping. Detection includes walkers, so passing enemies do not wait for a strategic decision interval. Player-controlled orders are unchanged.


Elf retreat travel is limited to fifteen battle seconds from departure. Changing or losing a destination does not reset this deadline. Arrival at the exact deadline enters healing; already seated recovery can continue to full HP without a travel timeout. An unsuccessful retreat releases the fallback state, restores normal movement, and uses the existing three-second fight hold before another retreat attempt; it does not spend the arrival-only cooldown. A new travel phase after losing an occupied healing spot receives its own fifteen-second deadline.

A demon pursuing a distant enemy now attacks adjacent hostile blockers, including retreating elves in waiting states, instead of idling beside them. Its original target and lifetime remain recorded, and pursuit resumes after the blocker is removed.


Human squads no longer wait for four recruits before moving out. Each partial squad captures normally; new recruits join and follow that squad until it has four members. Existing groups and their leaders remain stable rather than being repacked after casualties.

A group begins shared healing retreat when its summed current HP is strictly below half its summed maximum HP. Every living member receives one shared destination. The priority is an uncontested owned or historically Human-captured heart; otherwise the nearest empty heart (capturing it first if necessary); otherwise the Human base. An enemy entering the selected heart causes the whole squad to reroute. Recovery remains committed until all surviving members have reached the healing destination and regained full HP. New recruits joining that group follow its healing order. Healing squads do not initiate proximity combat and do not count as available combat support. The existing conquest rally/target rules remain; conquest casualty retreat to base takes precedence when only three attackers survive.

All AI races on every difficulty allow coincidental large formations: friendly squads can share destinations and travel side by side without strategic repulsion or separation penalties. Squad membership, racial behavior, retreat commitments and distinct occupied movement cells remain in force; groups are not forced to split apart merely for being close.


### Universal retaliation takes priority

All AI races on every difficulty retaliate against incoming attack attempts, including missed swings/shots. The victim and same-race allies within eight Manhattan movement cells pursue the attacker from any range. This response supersedes tile defence leashes, numerical attack avoidance, healing, flee and conquest orders. Every continuing attack refreshes that attacker's shared response; it ends on attacker death or after three battle seconds without an attack attempt. New attacks can redirect responders to a new attacker. Lethal opening attacks still alert surviving allies.

Strategic/recovery controllers cannot overwrite active retaliation. Recovery flags and the original objective are preserved; suspended Elf retreat travel deadlines and Orc flee itinerary time are paused while fighting, then resume afterward. Unit-lifetime checks prevent recycled attacker or responder slots from inheriting a stale pursuit. Reserved walking steps complete before combat changes state. Earlier race-specific reactive flee/in-place healing descriptions are superseded by this universal attack response; unprovoked proximity detection keeps its existing rules.


Ranged-fire retreat exception (all difficulties): Humans, Orcs and Elves with an active retreat/flee flag do not initiate retaliation or join an ally's response against a ranged attacker (attack reach greater than one). They keep their current safety destination and existing retreat movement/timers. Non-retreating allies may still respond to cover them. Melee attacks retain ordinary retaliation, as do ranged attacks outside retreat; Demons retain their existing response. This exception takes precedence over the universal retaliation rule above.
