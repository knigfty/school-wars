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

### Special tiles

| Tile | Main benefit | Important restriction |
| --- | --- | --- |
| Spade | Speeds up the owner's reinforcement cycle | Does not heal or directly increase punch |
| Heart | Heals eligible seated friendly warriors | Does not directly speed spawning |
| Base | Produces reinforcements and heals seated friendly warriors | An original home base is protected from capture until its original race is eliminated |
| Ordinary ground | Space for movement, formations, and fighting | Has no capture reward or ownership benefit |

The map makes **26 attempts** to place neutral special tiles. An attempt is rejected if the chosen tile is already occupied by a special tile or has a special tile immediately beside it in one of the four tile directions. Consequently, there can be fewer than 26 neutral objectives. Accepted neutral objectives have approximately a **two-thirds chance of being a spade** and a **one-third chance of being a heart**. The layout and mix vary between matches.

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

The battle advances in **18 rules steps per second**, approximately **0.0556 seconds per step**. Combat, capture, spawning, movement, and racial cooldowns use that battle clock. The visuals can animate more frequently, but a higher display frame rate does not grant faster attacks or reinforcements.

Pausing freezes the battle. Opening help, a pause dialog, or the quit dialog pauses it too. Losing application focus also brings up the pause dialog. Long frame interruptions are limited so returning to a suspended tab does not suddenly simulate an entire absence at once. Under severe performance problems, real-world timings can therefore stretch; the battle rules still advance in their usual order.

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

Warriors assigned to a tile first clear enemies inside that tile. They coordinate around a shared victim, normally preferring the weakest enemy by current HP. An existing valid shared target helps keep the group focused rather than independently scattering across enemies.

Before the tile belongs to the warriors' race, they do not chase its defenders outside it. Removing the last enemy starts a **one-second standing period**. If another enemy enters, clearing resumes and that clear period is reset. Once the tile remains clear, the warriors sit.

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

Once the guarded tile is owned by the defenders' race, an enemy within **one movement cell of the tile's border** can trigger a coordinated defence. This is a side-adjacency test; a diagonally touching outside cell can be two steps from the nearest cell inside and will not meet the one-cell test.

Defenders may pursue a chosen threat into one **directly side-adjacent large tile**. They cannot chase it into a diagonal tile or a second tile beyond that. Killing the victim or having it leave the allowed area ends the pursuit, and defenders return to their assigned tile. If completely surrounded on the return, a warrior can fight a nearby enemy to try to free a route rather than remain helplessly trapped.

Ordinary ground does not become owned territory. A ground order can hold and clear that location, but it does not create the owned-objective border-defence benefit.

An explicit new order can change the assignment. Enemy planners can likewise issue fresh orders to available units; the leash restricts an existing automatic defence, rather than forbidding future strategic movement.

### Base capture

An original home base cannot be captured while its original race remains active. Merely driving its defenders away does not unlock it. After that original race has been eliminated, another race can capture it using the usual uncontested sitting rules.

Once conquered, a base can be taken again while its new owner is still alive. Its protection does not reset around each new owner. Every enemy base you currently own adds **six regular-unit capacity** and becomes another reinforcement location. Losing it removes that capacity bonus and spawn location immediately.

Enemy warriors inside an invaded owned base prioritise intruders after their short initial standing animation. This local defence can happen during Easy or Normal's opening strategic delay. The opening delay is not immunity from counterattacks.

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

> 2 + number of currently owned spades.

Its target is **1,500 for Humans, Elves, and Demons**, and **750 for Orcs**. Consequently, medieval orcs spawn twice as fast as the other races when both sides own the same number of spades.

Starting from an empty meter with ownership unchanged:

> Cycle seconds = ceiling(target ÷ (2 + owned spades)) ÷ 18.

| Owned spades | Human / Elf / Demon cycle | Orc cycle |
| ---: | ---: | ---: |
| 0 | 41.67 seconds | 20.83 seconds |
| 1 | 27.78 seconds | 13.89 seconds |
| 2 | 20.83 seconds | 10.44 seconds |
| 4 | 13.89 seconds | 6.94 seconds |
| 6 | 10.44 seconds | 5.22 seconds |

These are full-cycle timings under steady conditions, not necessarily the time remaining on a partially filled meter. Capturing or losing a spade changes the rate of the current cycle. It does not erase that cycle's existing progress. A spade's reinforcement benefit persists without a garrison as long as ownership remains yours.

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

When several orcs are actively engaged on the same victim, the first eligible attacker supplies the baseline and each additional qualifying attacker receives **+1 punch for its own hits**. The extra point is not multiplied by the total number of orcs.

For ordinary two-punch orcs, a fully engaged group has this nominal damage distribution:

| Engaged orcs on the victim | Punch values across the attackers | Sum if every listed attack connects once |
| ---: | --- | ---: |
| 1 | 2 | 2 |
| 2 | 2, 3 | 5 |
| 3 | 2, 3, 3 | 8 |
| 4 | 2, 3, 3, 3 | 11 |

The last column is not DPS; misses and attack timing still apply. Being nearby, walking toward the victim, or merely belonging to the same squad is insufficient. An earlier qualifying orc must actually be fighting that target with valid contact. Inherited permanent punch on converted orcs changes their baseline, but the group addition remains one point.

### Conversion chance

Conversion is checked **only when an orc lands the killing blow**. The chance depends on how many distinct orcs successfully damaged that particular victim in the preceding three battle seconds, including the killer's final hit:

| Distinct recent orc damage contributors | Conversion chance |
| ---: | ---: |
| 1 | 25% |
| 2 | 50% |
| 3 | 75% |
| 4 or more | 100% |

Multiple hits from one orc still count as one contributor. Misses do not qualify. The three-second boundary is inclusive. A recent contributing orc does not have to still be alive for its recorded hit to count toward the conversion roll; this differs from receiving an individual living-assistant reward.

Conversion is rolled once on death. It does not accumulate a meter across several different victims, and a non-orc final blow cannot convert the victim merely because orcs assisted.

### What a converted orc inherits

The defeated warrior becomes a new orc at the victim's cell. The recruit:

- Inherits the victim's **maximum HP**, and starts fully healed to that maximum.
- Inherits the victim's **permanent punch**, including earned punch bonuses.
- Starts with **one-cell reach**, regardless of the victim's former reach.
- Does not retain the former race's progression, special speed scaling, focus orders, or selection.
- Does not inherit temporary human territorial punch or orc group damage.
- Does not use a regular capacity slot or consume the reinforcement meter.

For example, a human with 26 maximum HP and ten permanent punch becomes a **26/26 HP, ten-punch orc** if converted. A formerly long-range elf becomes a one-cell melee orc even if it retains a very large maximum HP value.

Converted orcs can take normal orc orders, receive orc group damage, and contribute to later conversions. Their population is shown separately as `(+N)`. A converted survivor can keep the orc race alive even after every regular orc has fallen. The successful-conversion popup is `ORCS RISE!`.

## 11. Elves

Elves begin with the highest HP and turn damaging participation into durability and reach.

### Kill and assist growth

A living elf receives **+1 maximum HP** when a victim it successfully damaged within the last three seconds dies. The killing blow also qualifies; it does not grant an additional second assist reward. Several hits on that victim still produce just one reward for that death.

In Expert, **enemy AI elves gain +2 maximum HP** for each qualifying kill or assist. Player elves remain at +1. This is an explicit difficulty asymmetry.

The reward does not instantly heal. A wounded veteran's maximum can rise while its current HP stays unchanged.

### Reach from bonus HP

Every complete three HP above the original 25 maximum grants one extra cell of reach:

> Reach = 1 + floor((maximum HP − 25) ÷ 3).

| Maximum HP | Bonus HP | Reach |
| ---: | ---: | ---: |
| 25–27 | 0–2 | 1 cell |
| 28–30 | 3–5 | 2 cells |
| 31–33 | 6–8 | 3 cells |
| 34–36 | 9–11 | 4 cells |
| 40–42 | 15–17 | 6 cells |

There is no fixed reach-tier cap. The field's finite size still limits the useful distance. Bonus HP does not increase punch, movement speed, or attack speed.

Because assists count, several elves can all grow from the same victim. A basic player elf needs three qualifying deaths to unlock its first extra cell. An Expert enemy elf needs two, reaching 29 maximum HP.

### Healing identity

Owned hearts heal elves twice as quickly as the general healing rate. Bases retain the ordinary rate. Both require sitting and the three-second unattacked window. A heart is therefore an especially valuable recovery point for an experienced elf, but retreating under continuing attack can prevent healing from starting.

An elf's popup shows the old maximum followed by the gain: `30 + 1 HP` means its maximum has just risen from 30 to 31. Expert enemy rewards can show `+ 2 HP` instead.

## 12. Demons

Demons begin with the strongest punch and convert combat participation into more damage, combat healing, and movement speed.

### Punch growth and combat healing

| Event | Easy / Normal punch reward | Expert punch reward | Healing |
| --- | ---: | ---: | ---: |
| Demon lands the killing blow | +1 | +2 | Restore 3 current HP |
| Demon provided a qualifying damaging assist | +1 | +1 | Restore 1 current HP |

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

Movement upgrades do not speed up the attack cycle. Demons remain one-cell attackers. They cannot heal from hearts, but can heal while seated on an owned base and through the combat rewards above. Enemy demons do not choose healing retreats.

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

The player's warriors carry out their orders and the shared automatic defence rules. They do not receive the enemy strategic squad planner. Choosing Expert therefore does not make your own army autonomously select all the same missions as Expert enemies.

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

A warrior busy clearing or capturing its assigned objective, responding to a base invasion, returning from a defence, or carrying out another protected local response is not freely reassigned by every strategic planning pass. A held friendly tile can later be given a new mission. Consequently, a listed strategic priority is a choice among **available** units, not a guarantee that every wounded or nearby unit instantly abandons its current battle.

### Easy: individual objective choices

Easy considers one potential individual decision per battle step, rotating through the population. A warrior must be seated and have built up at least **400 seated idle steps**, about 22.22 seconds, before it qualifies for an individual strategic order. Travel, standing, fighting, and which warrior is being considered can make its departure later. This is not a global promise that every enemy moves at the same instant.

Healthy warriors look for capturable objectives. Wounded non-demons instead look for owned healing tiles. Demons are treated as ready to continue offensive activity even when wounded. Objective preference combines four-direction tile distance with a small random variation. If no suitable objective is found, the warrior can choose an enemy target.

Easy also tracks a rough leader: active population plus owned spades, with the orc value halved. A race qualifies as a leader when its value exceeds 40% of the combined total; if several qualify, the current selection follows the game's race-check order. Other Easy enemies tend to concentrate choices against that leader. This is a targeting preference, not a formal alliance: they can still fight one another locally, and eligible abandoned bases have an exception to the objective filter.

Easy has no strategic squad coordination or Normal/Expert orc flee cooldown. Shared tile-clearing focus and border defence still work, so “individual AI” does not mean four enemies assigned to one tile will ignore a shared intruder.

### Normal: coordinated small groups

After the opening delay, Normal builds same-race groups of up to four, fills nearby groups with recruits, and avoids leaving a fifth unit alone where a larger group can split into three and two. Groups are not required to wait until full before acting.

Groups make a fresh strategic decision every two seconds. Their usual attack awareness is 16 cells around the group centre. Widely separated members can receive a rally order before advancing; a member more than 12 cells from the centre can trigger this regrouping. This is a loose squad system, not rigid formation movement.

- **Humans** advance and fight as a group, then seek capturable objectives when no local target is selected.
- **Orcs** favour a shared victim based on distance and current HP. When nearby enemies outnumber nearby allies, eligible orcs flee toward a nearby active enemy-owned base for up to ten seconds. That unusual destination is an escape-direction rule, not a healing trip. Each warrior can start this behaviour once every 30 seconds.
- **Elves** begin healing recovery below 20% HP and stop treating themselves as retreating at 80% HP or higher. There is no ten-cell limit or 45-second recovery-start cooldown in Normal. When threatened during healing behaviour, they can randomly choose to fight back or relocate; choosing to fight can hold them in place for three seconds before reconsideration.
- **Demons** favour weak nearby victims, while comparing their group's combat strength against nearby defenders. Their estimate combines current HP, permanent punch, and extra reach. They can reject a locally dangerous attack instead of blindly focusing the nearest enemy. They never retreat specifically to heal.

When seeking objectives, Normal orcs favour spades and Normal elves favour hearts. Normal's strategic objective search is not restricted to the 16-cell combat-awareness radius. If no capturable objectives remain and no local victim is available, a group can advance toward a more distant opponent. Awareness radius should therefore not be read as universal fog of war.

### Expert Humans: committed missions

Enemy humans organise missions of up to four warriors, with later recruits able to fill incomplete groups. They look for capturable objectives within **five large-tile steps** of the group's current tile position. Nearby objectives with no enemies are heavily preferred, but an occupied objective remains a possible choice.

After choosing a goal, they commit to it instead of replacing it every second with whichever tile is now marginally closer. Enemies on that goal can become a shared focus target; the mission's target check reaches 20 movement cells from the group centre. On capture, the mission can end and its survivors become available for another assignment.

If no objective is in the local five-tile search area, the group scouts toward locations three to five tiles away. It prefers less-visited directions, spreads away from other human scouts, and penalises enemy-occupied destinations. This lets it discover more useful objectives instead of indefinitely waiting at home.

Losing at least half of the original goal-setting mission group creates **one 50% retreat chance** for that mission when the survivors' cooldowns allow it. A successful retreat sends surviving eligible members toward their nearest owned heart or base. There is no ten-cell healing limit. Each retreating warrior receives a **45-second cooldown**, and recovery continues until full HP. The cooldown prevents a fresh retreat start; it does not force an ongoing recovery to end after 45 seconds.

This is casualty-triggered group recovery, not a generic “human retreats below 20% HP” rule. Reinforcements joining the mission do not redefine which original members count as the mission's initial force.

### Expert Orcs: larger focus groups

Enemy orcs form groups of up to **six**. They keep the shared-target preference and the locally outnumbered escape behaviour: up to ten seconds of fleeing, with a 30-second personal cooldown. The surrounding ally-versus-enemy count uses the group's 16-cell awareness area.

Six group members do not create six adjacent melee slots. Only warriors actually landing recent damage increase conversion probability; the ordinary four-slot melee geometry still matters.

### Expert Elves: recovery, protection, spacing

Enemy elves form groups of up to **four core warriors**. Elves whose reach has grown beyond one cell can join a full group as ranged support, so the total headcount can exceed four.

Among available units, their strategic ordering is recovery, protection of badly wounded allies, capture, then ordinary group attacks. An enemy actively fighting an elf at 20% HP or lower receives high protection priority when an available guard is within **ten four-direction movement cells** of the wounded ally. Only nearby eligible responders are sent.

An elf at **20% HP or less** can start a healing retreat if an owned heart or base lies within **ten four-direction cells of its nearest cell** and the elf's cooldown is ready. Distance is measured to the edge of the healing tile, not its centre. Starting recovery applies a **45-second cooldown**. Recovery continues to **100% HP**. No qualifying healing point means no retreat starts and no cooldown is spent. Losing the healing destination can cause a search for another nearby one or end recovery if none is available.

Groups penalise capture destinations close to other elf groups or already chosen elf destinations. This spreads pressure and reduces unnecessary clustering; it does not create permanent lanes or guaranteed spacing.

Enemy elves also receive the Expert +2 maximum-HP participation reward described earlier. Player elves do not.

### Expert Demons: defend, expand, attack

Enemy demons form groups of up to **four**. They strongly prioritise enemies occupying demon-owned objectives when an available responder is within **ten four-direction movement cells** of the intruder. These checks also sit within the normal local enemy-awareness scan.

After urgent defence, they prefer capturable objectives, then ordinary local group attacks when no objective is selected. Their target scoring also favours lower-HP victims. Expert demon planning is not the same strength-rejection calculation used by Normal demons.

Demons never choose healing retreats. Their survival tools are successful combat, kills and assists, and any ordinary base healing obtained while seated. Expert's +2 killing-blow punch and continuing movement formula apply equally to player and enemy demons.

## 15. Reading the interface

### Population display

A display such as `Orcs 8 (+3)/14` means eight regular orcs, three converted orcs, and a regular capacity of 14. The converted population does not fill the 14 regular slots. Brief death sequences can keep a fallen warrior in a displayed population until it clears.

### Spawning box

The bottom-left box reports the next reinforcement cycle, full capacity, or a blocked base. The progress bar belongs to the shared race-wide meter. Its countdown is an estimate based on current spade ownership; capture or loss of a spade can change it partway through the cycle.

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

Four orcs surround an elf. If only two successfully damaged it in the final three seconds, an orc killing blow has **50%**, not 100%, conversion chance. Four distinct successful recent orc contributors raise it to 100%. A human stealing the final blow prevents the conversion roll altogether.

### An elf grows without securing the final hit

Three player elves each successfully damage one enemy, and all remain alive. A different warrior kills that enemy within three seconds of all three elves' hits. Each elf gains one maximum HP. None needs the final blow, and none gains an extra reward for having landed several hits.

If the victim had 1 HP remaining, one tiny successful contribution still qualifies; assist credit has no minimum damage-share percentage.

### A demon's Expert progress

An Expert demon begins at five punch. One killing blow grants +2 punch and restores up to three current HP, taking it to seven punch and **+5% movement**. A qualifying assist afterward adds one punch and up to one HP, taking it to eight punch. It still has +5% movement because only complete pairs of bonus punch count. Another assist brings it to nine punch and +10% movement.

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
- **Focus and participation:** concentrating damage removes a victim quickly, but melee access is limited. Orcs benefit from several distinct recent contributors; elves and demons benefit from qualifying assists. Reach growth lets veterans participate from additional cells.
- **Commitment and distraction:** tile orders provide a bounded clear-capture-defend job. Focus orders pursue a chosen warrior. A defender can be drawn into the adjacent tile, but cannot be automatically dragged across the entire battlefield by that same guard assignment.
- **Probability and positioning:** hit chance creates uncertainty, while occupied cells, valid contact, retreat paths, and available attack positions determine how many useful hit attempts happen at all.
- **Race-specific territory value:** human groups exploit capture breakpoints; orcs turn hearts and spades into capacity; elves recover especially well on hearts; demons rely on bases and combat healing instead of heart regeneration.

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
