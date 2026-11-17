# Elaris — Assessment and Development Plan

Date: 2026-11-16. Covers commit `9f6e24c` (main, in sync with origin), Godot 4.5.

When this was written, `CLAUDE.md`, `ROADMAP.md` and `PROGRESS.md` said the Phase
2–8 systems were "built, integrated and validated". They were built. Most were not
integrated, and the validation could not see the problems below. Those files have since
been rewritten to match this document.

**Progress since:** Phases 0 and 1 were implemented the same day. Sections 3 to 5
describe the game as it was at `9f6e24c`; `CHANGELOG.md` lists what each phase
changed and `PROGRESS.md` lists what was deliberately left for later. Two Phase 1
items moved to Phase 2, where the code they touch is rebuilt: the input map and the
rest of the `world.gd` split.

---

## 1. Bottom line

Elaris today is a working combat prototype with a large amount of unreachable code
around it.

- **What a player can actually do:** walk around a three-room dungeon, get pulled into
  turn-based fights with three enemies, hit them with one of three attack buttons, pick
  up loot, gain XP, drag armour onto a character sheet, save and load.
- **What exists but a player cannot use:** spells, crafting, quests, the world map,
  companions, character creation and dialogue. Every panel built in the June session
  renders off-screen (section 3). Behind the panels, most of those systems are either
  unreachable from play or change numbers nothing reads (section 4).
- **What does not exist at all:** a main menu, a new-game flow, a game-over, a town,
  an NPC, a shop, a boss, ranged attacks, enemy abilities, art, audio.

The June build-out produced breadth without depth. Fourteen managers were written in a
day against a contract and checked only by a headless boot, which proves the scripts
parse and nothing more. The managers themselves are mostly sound; the game around them
was never connected, and nobody looked at the screen.

The plan in section 7 reverses the approach: make the existing work visible, rebuild
four load-bearing models that the rest depends on, then grow one complete playable loop
before widening.

---

## 2. How this was assessed

1. Read the core loop in full: `world.gd`, `grid_character.gd`, `enemy.gd`,
   `dungeon_generator.gd`, `room_library.gd`, HUD scripts, `game_manager.gd`,
   `ui_manager.gd`.
2. Four parallel code audits of the other systems (items/crafting, combat rules/magic,
   story/companions, progression/save), each tracing whether a feature is reachable
   from play and whether its result is consumed.
3. Ran the game in a real 1920×1080 window with a driver script that opened every
   panel, played one fight, and saved screenshots.
4. Two headless probes that called the live managers to confirm the audit claims that
   matter most.

Findings marked **(run)** were confirmed against the running game. The rest come from
reading both sides of the call. Not covered: playing by hand with mouse and keyboard,
performance beyond a spot check, and anything about how the game *feels*.

The driver and probe scripts are throwaway files outside the repo. Phase 0 turns them
into a permanent check.

---

## 3. What the game looks like when run

**(run)** throughout.

- **Exploration.** Flat grey floor, brown walls, the Godot icon as the player. The map
  is 200×200 tiles holding three rooms joined by five-wide corridors. The minimap is
  one pixel per tile and almost entirely black.
- **HUD.** The combat log sits top-left. The turn banner and the initiative bar are
  meant to be centred at the top; both pile into the top-left corner over the log, and
  the initiative bar is partly off-screen. The bottom bar has no background. Messages
  such as "Out of range", "Inventory full" and "You are incapacitated" are never shown:
  33 places emit `ui_notification` and the only listener is an empty function
  (`ui/crafting_panel.gd:383`).
- **Panels.** Spellbook, crafting, quest log, world map, companions and character
  creation each appear as a fragment in the top-left corner with most of their content
  clipped. The dialogue panel is completely invisible while pausing the game, so
  pressing Y looks like a freeze until ESC.
  Cause: each panel calls `set_anchors_preset()` in `_ready()`, which changes anchors
  but keeps the current rectangle, and that rectangle is 0×0. The two older screens
  (character sheet, save menu) use `set_anchors_and_offsets_preset()` and are fine.
  The same mistake explains the HUD.
- **Character sheet (I).** Works. Items show as a single letter with no name or icon.
  Title reads "Character Name"; speed reads "6 ft" (it is six tiles).
- **A fight.** The starting kit is in the bag, not equipped, so the fighter starts at
  AC 11 with 12 HP. One bandit took the driver's fighter from 12 HP to 1.
- **Death.** The player node is freed. No screen, no reload: the save loader refuses to
  run without a player (`save_manager.gd:119`), so the game must be relaunched.

Measured in the probe:

| Situation | Hit chance | Damage per swing |
|---|---|---|
| Enemy → player, kit not equipped (AC 11) | 41% | 2.0 |
| Enemy → player, kit equipped (AC 17) | 11% | 0.7 |
| Player light / medium / heavy → enemy (AC 10) | 51% each | 2.4 / 3.5 / 4.7 |

So the first fight is close to a coin flip against one enemy and lethal against three,
until the player finds the character sheet; after that enemies barely land a hit. Heavy
attack is strictly better than the other two, so the three buttons are not a choice.

---

## 4. System status

"Reachable" means a player can get to it through the interface. "Effective" means its
result changes something the game reads.

| System | Data / logic | Reachable | Effective | Main gap |
|---|---|---|---|---|
| Movement, pathfinding | Solid | Yes | Yes | A* is hand-rolled; a 146-tile path took 58 ms **(run)** |
| Turn order, initiative | Works | Yes | Mostly | Player can attack or cast during enemy turns; a combatant dying on its own turn skips the next one |
| Attack maths (d20, advantage, crits) | Correct 5e | Yes | Yes | Only ever adjacent melee |
| Player attacks | Three hard-coded dice | Yes | Yes | Equipped weapon is ignored (`grid_character.gd:738-779`) |
| Ranged attacks | None | No | — | Fighter starts with a crossbow that cannot be fired |
| Cover, line of sight, damage types, resistances | Written | No | No | Cover is skipped at distance 1 and every attack is at distance 1; `apply_damage` drops the type |
| Enemies | Four names | Yes | — | All four share one stat block, one 1d6 attack and one behaviour; only HP differs. No boss ever spawns |
| Status effects (17) | Coherent | Via spells only | On enemies | Enemies never apply any; durations only tick in combat |
| Armour / AC | Works | Yes | Yes | Not 5e: every slot adds, DEX uncapped. A craftable bronze set reaches AC 24 against enemy +3 to hit |
| Inventory, gold, loot drops | Works | Yes | Yes | 25-slot cap is display only; overweight pickups destroy the loot |
| Durability, repair, enchanting, item quality, magic bonus | Written | No | No | Never decremented, never read, or read from the wrong object |
| Shops, selling | None | No | — | Gold has no sink except crafting |
| Crafting (115 recipes) | Works | Panel off-screen | 24 recipes | Player level always reads as 1 **(run)**; 68 recipes can never be learned |
| Spells (82) | 45 resolve sensibly | Panel off-screen; fighter has none | Partly | Only 21 obtainable; never granted on level-up; AoE always hits the caster; no ally targeting |
| Classes | Maths correct | Via hidden panel | Casters only | Class features are strings nothing reads. Fighter and Rogue differ by hit die and kit |
| Races | Bonuses apply | Via hidden panel | Partly | Darkvision, Lucky, Relentless Endurance, resistances unread |
| Levelling | Correct 5e XP, HP | Yes | Yes | No level-up notice, no XP display, ASI points cannot be spent |
| Character creation | Works | Hotkey N, any time | Too much | Not a start-of-game flow. Mid-fight it heals, resets level and adds another kit |
| Dialogue (6 trees) | Works | 1 of 6 | Yes | Only the Reeve has an entry point (hotkey Y) |
| Quests (8) | Works | 1 of 8 | No | Main chain dies at step two: the NPC cannot be opened. Step three needs a "boss" that never spawns |
| Factions (3) | Works | No | No | Nothing reads reputation |
| World events, crisis | Fire silently | No | Barely | Crisis phases change nothing in the world |
| Zones (9), world map | Defined | No | No | Travel button permanently disabled; zone tier only adds enemy HP |
| Companions (4) | Most alive part | Debug button | Partly | Cannot be hurt, targeted, controlled, healed or levelled; gifting crashes **(run)** |
| Save / load | Managers round-trip | Yes | Partly | The dungeon is not saved. Load after a restart drops the player into the void of a different map |
| Rests | Long rest works | Hotkey | Yes | Free and unlimited; short rest does nothing |
| Menus, game over, settings | None | — | — | Game boots straight into a fight-ready dungeon |
| Art, audio | None | — | — | Four flat tiles, one icon, no sound |

Content counts: 263 items (85 weapons, 90 armour, 36 aliases, 13 accessories, 12
consumables, 7 misc, 20 materials), 82 spells, 115 recipes, 17 status effects, 8
quests, 6 dialogues totalling 843 words, 4 companions, 6 world events, 1 crisis.

---

## 5. Confirmed defects

Ordered by how much they block play. Line numbers are at commit `9f6e24c`.

### Blockers

1. All June panels and the top HUD render at the origin with a 0×0 root (section 3).
   **(run)**
2. No notification renderer; all system feedback is console-only.
3. Death is terminal and blocks loading (`grid_character.gd:1169`,
   `save_manager.gd:119`).
4. Load after restart places the player at saved coordinates in a newly generated
   dungeon (`save_manager.gd:207-215`); on a non-floor tile neither WASD nor
   click-to-move can leave.
5. Main quest cannot progress past its first objective; no quest in the game is
   completable (`zone_1_quests.gd:46-47`, `:103-104`, `world.gd:268`).
6. Starting kit is not equipped, which decides the first fight (section 3). **(run)**

### Crashes and data loss

7. `companion_manager.gd:255` — `get("item_id", "")` on a Resource; gifting throws a
   script error every time. **(run)**
8. `crafting_manager.gd:328` — `Engine.has_singleton("GameManager")` is false for
   autoloads, so crafting never sees the player; every recipe above level 1 is
   permanently uncraftable. **(run)**
9. `ground_item.gd:114-145` — pickup frees the drop even when the bag refused it.
   Same pattern in `crafting_manager.gd:188` (inputs spent, product lost) and for
   quest, dialogue and event rewards.
10. `character_screen.gd:655` — right-clicking a scroll deletes it without casting.
11. `companion_panel.gd:405` — a dismissed companion can never rejoin. **(run)**
12. `crafting_panel.gd:368` — the X button hides the panel but leaves the game paused.
13. `world.gd:178-183` — character creation swaps the stats object; equipment keyed to
    the old one is orphaned, and old and new both save under the id "player".

### Rules that are wrong

14. Encumbrance subtracts feet (−10/−20) from a speed stored in tiles (6), so any
    encumbrance means zero movement **(run)**; and it applies disadvantage to every
    roller in the game, enemies included (`combat_manager.gd:101`, `:345`).
15. Player can attack or cast during enemy turns: the only gate is
    `has_attacked_this_turn` (`grid_character.gd:262-305`, `:755-774`, `:858`).
    Pressing SPACE during enemy turns also burns a turn off every effect on the player.
16. Area spells always include the caster if in radius (`spell_manager.gd:373-377`);
    Burning Hands and Thunderwave always hit the wizard. They also ignore walls.
17. Spells are granted once, when the known list is empty (`spell_manager.gd:68`). A
    level-3 wizard has second-level slots and no second-level spells.
18. Self-buffs expire at the caster's own turn end, so Shield lasts zero enemy turns.
19. `wizard.tres` — save proficiency is WIS only (should be INT and WIS) **(run)**;
    slot table is off from level 11.
20. Wizards are handed Eldritch Blast; the cleric's third cantrip is the no-op Light,
    because cantrips are picked alphabetically. **(run)** for the wizard list.
21. Combat starts on straight-line distance, through walls
    (`world.gd:548-581`).
22. Dialogue rewards repeat on every visit; talk objectives complete when any dialogue
    closes, including by ESC.
23. Companion gift preferences test the wrong enum numbers
    (`companion_manager.gd:327-338`).
24. Loading in the same session leaves stale equipment bonuses, spent slots, status
    effects and concentration in place; no manager has a reset.

### Dangling references

`trinket_lucky_coin`, four `recruit_*` dialogue ids, enemy type `boss`, `notice_board`,
`bread` as a pickup objective (bread only comes from crafting). Nothing validates ids
at load, which is how these survived.

### Dead code

`scripts/test_inventory_setup.gd` (calls functions that do not exist),
`scripts/cameracontroller.gd`, `scripts/dungeon_test_controller.gd`, and about a dozen
unused manager functions and never-emitted signals.

---

## 6. Structural problems

These are the things patching will not fix. Each one blocks several features at once.

1. **No combatant model.** Player, enemy and companion are three unrelated scripts.
   "Hostile" is hard-coded as `world.enemies` versus the single player in the AI, the
   spell system, opportunity attacks and the initiative bar. This is why companions
   cannot be hurt, healed, targeted or controlled, and why enemy casters, summons and
   real party combat are impossible. The design calls for a party of four, so this is
   foundational, not optional.

2. **No action model.** A turn is one boolean. There is no action, bonus action,
   reaction, per-rest resource, or authority for whose turn it is. Extra Attack,
   Action Surge, Cunning Action, Channel Divinity, Shield and Counterspell cannot be
   expressed. The three-button attack is also a different design from the one-die-per-
   weapon item model; wiring weapons in means redesigning the input, not swapping a
   lookup.

3. **No damage or feature pipeline.** Two separate attack resolvers (weapons and
   spells), damage type discarded, and no hooks for on-hit, on-damage or on-zero-HP.
   Sneak attack, resistances, Relentless Endurance and magic weapon effects have
   nowhere to attach. Class features and racial traits are bare strings.

4. **Armour is a flat sum.** Thirteen slots each add AC with no DEX cap. Numbers cannot
   be tuned out of that; the model has to become 5e's (body armour sets the base,
   capped DEX, shield, small bonuses elsewhere).

5. **No game-state layer.** `World._ready()` is the new game. Loading merges into live
   singletons that have no reset. The dungeon has no seed. Enemies, loot and fog live
   in local variables nothing can save. Menu, new game, continue and game over all
   need this.

6. **No world outside the dungeon.** No NPC node, interact action, town, shop or
   location. Every zone is a hostile dungeon biome. Quests have no giver, no turn-in
   and no way to spawn their own targets. Dialogue, quests, factions, crafting
   stations, companions and rests all need somewhere to be reached from.

7. **Enemies are a four-row table.** Colour and base HP. No stat blocks, attacks,
   abilities, behaviours or encounter composition.

8. **`world.gd` is the whole game.** 917 lines: scene setup, combat loop, spawning,
   rewards, hotkeys, panel registration, companion management and load handling.

9. **UI built entirely in code.** This was a rule for the parallel agents, not a good
   idea. It is why the layout bug went unseen, why every button restyles itself by
   hand, and why nothing can be adjusted in the editor. There is no Theme, no stretch
   mode (the window does not scale), and no input map (keys are hard-coded, so no
   rebinding).

10. **Content is GDScript dictionaries with no validation.** At the design's 75 quests
    this is roughly 7,000 lines of hand-written literals, with every cross-reference a
    string checked only when used.

11. **Deprecated engine pieces.** The dungeon uses the `TileMap` node, deprecated since
    Godot 4.3 in favour of `TileMapLayer`. Pathfinding should move to the built-in
    `AStarGrid2D`.

### What is worth keeping

- The autoload + EventBus architecture.
- `CharacterStats` maths: modifiers, hit-die HP, proficiency, XP table.
- `CombatManager` roll logic and the `CombatGrid` helpers (line of sight, cover,
  flanking).
- `StatusEffectManager` lifecycle.
- Spell data schema and the slot / concentration core of `SpellManager`.
- Item and material generation, loot tables (numbers need rebalancing).
- Dialogue, quest and faction managers as a base for a richer model.
- `SaveManager` structure and the primitives-only save discipline.
- Combat log, save menu, floating damage text.
- The Zone 1 writing: Brackenford, Dawnwatch, Mournstead, the Hollow Throne. It is
  short but the voices are distinct.

---

## 7. The plan

### Principles

1. **Done means seen.** A feature counts when a player can reach it through normal
   play, I have watched it work in the running game, and you have played it.
2. **Depth before breadth.** One class, one dungeon and one town working properly
   before four of each.
3. **Rebuild the load-bearing models first:** combatant, action, armour, game state.
   Content added before that is content to redo.
4. **Content is validated at load.** Unknown ids fail the smoke test.
5. **No more headless-only validation.** Every commit runs the smoke test and the
   screenshot tour.

### Phase 0 — Truthful baseline (small)

Make what exists visible and stop it crashing. No design decisions needed.

- Fix the anchor bug across the seven panels and the HUD; set a stretch mode so the
  window scales; add a toast renderer for `ui_notification`.
- Fix defects 7–12, 14, 19, 20, 23; auto-equip the starting kit; fix the dangling ids.
- Move debug keys (R regenerate, N re-create, Y talk-anywhere, debug recruit) behind a
  debug flag.
- Delete the dead code.
- Add `tools/`: a smoke test (boot, scripted fight, assertions) and a screenshot tour,
  with one command to run both.
- Rewrite `CLAUDE.md`, `ROADMAP.md`, `PROGRESS.md` to match reality; revise the
  contracts doc (drop the agent ownership matrix and the code-only UI rule).

Exit: every existing panel is readable and usable; no known script-error path; the
checks run from one command and pass.

### Phase 1 — Game shell and state (medium)

- Main menu (new game, continue, load, settings, quit), pause menu, game-over screen.
- Character creation as the real start of a new game, with skill choice and a proper
  ability-score method.
- `reset()` on every manager; load becomes reset-then-apply.
- Seeded dungeon generation; saves include seed, enemy state, ground loot, explored
  map and companion HP. Autosave on entering and leaving a dungeon. Save migrations
  per version. No saving mid-combat.
- Input map with rebindable actions; settings for volume and display.
- Split `world.gd` into game state, dungeon scene and combat controller.
- Placeholder art in place for everything that already exists: floor, wall and door
  per biome, the player, the four enemies, item icons, the loot marker. Asset manifest
  and the first art checklist (section 8).

Exit: launch → menu → new game → create a character → play → save → quit → continue
restores the same dungeon, position and enemies. Dying leads to a screen with a way
back.

### Phase 2 — Combat core (large)

The heart of the game, and the phase everything after depends on.

- One combatant base for player, party members and enemies, with a team. Initiative,
  targeting, AI and spells all work on combatants.
- Turn resources: movement, action, bonus action, reaction. One authority for whose
  turn it is.
- Action bar replacing the three attack buttons: Attack (equipped weapon, melee or
  ranged), Cast, Use Item, Dash, Disengage, Dodge, End Turn, plus class features.
- Weapons wired in properly: dice, finesse, versatile, two-handed, ranged with range
  and line of sight, proficiency, damage type.
- One damage pipeline with types, resistance and vulnerability, and hooks that
  features, traits, effects and magic items attach to.
- 5e armour class; armour data reworked to match.
- Durability wear on weapons, armour and shields through the damage pipeline, with
  damaged and broken states, tooltips and a HUD warning (section 8).
- Data-driven bestiary: stat block, attacks, abilities, behaviour, XP, loot. First
  set: goblin (ranged, nimble), skeleton (bow, weak to bludgeoning), bandit, wolf
  (pack tactics, knockdown), and one boss.
- Behaviours: rusher, archer, caster, pack. They drive any combatant regardless of
  team, which is what makes the AI-companion option cheap. Enemies perceive by line of
  sight, choose among party members, and do something when not in combat.
- Encounters built per room against a difficulty budget instead of three random spawns.
- Combat readability: movement range, valid targets, hit chance before committing,
  status icons, a working turn-order bar, faster enemy turns.
- `AStarGrid2D` and `TileMapLayer`.
- A headless combat simulator that plays hundreds of fights with a simple policy, so
  balance is measured instead of guessed.

Exit: a level-1 character of each class fights a mixed melee-and-ranged group using
the full action bar with correct 5e maths; enemies target party members; the simulator
shows level 1–3 encounters landing in an agreed win-rate band.

### Phase 3 — Dungeons worth exploring (medium to large)

- Generator v2 on a seed: 8–15 rooms of varied size, narrow corridors, doors, room
  roles (entrance, fight, treasure, shrine, boss, exit).
- Things in rooms: chests, traps with saves, difficult terrain, objects that give
  cover.
- Vision: what the party can see is what is drawn; the minimap follows.
- A goal per run (kill the boss, fetch the item, reach the bottom) and a way out.
- Quest-driven spawns, so a quest can put a named enemy in a specific place.

Exit: a run has a start, a reason to explore, a boss and an exit; the same seed gives
the same dungeon.

### Phase 4 — Town, world map, economy (medium to large)

This is what makes the story systems reachable.

- A town screen for Brackenford: reeve, tavern, market, smithy, apothecary, shrine,
  notice board, gate.
- A world map of locations to travel between, replacing the regenerate key.
- NPC registry; dialogue started by visiting an NPC; persistent dialogue flags.
- Quest model v2: giver and turn-in, stages in order, spawned targets, collect by
  possession with hand-in, fail conditions.
- Shops with buy and sell; rest costs; recipes found or bought; crafting stations at
  their buildings.
- Repair: the smith for gold, repair kits for the field, the forge for crafters.
- Faction reputation affecting prices and which quests are offered.

Exit: the main quest chain is completable start to finish by normal play; gold has
sources and sinks; no system is reachable only by hotkey.

**Milestone 1 — First playable.** Phases 0–4. Menu to character to town to dungeon and
back, with fights that use real rules. The first build worth handing to someone else.

### Phase 5 — Class, magic and item depth, levels 1–5 (large)

- The four classes play differently by level 3: Fighter (fighting style, Second Wind,
  Action Surge, Extra Attack), Rogue (Sneak Attack, Cunning Action, Expertise), Wizard
  (spellbook, Arcane Recovery), Cleric (domain, Channel Divinity, healing).
- Level-up screen with choices; XP visible.
- About 35 spells for levels 0–3 implemented fully: shapes, ally targeting, reactions,
  concentration shown on the HUD. The rest hidden until done properly.
- Item quality and magic bonuses that work; magic items with real effects; consumables
  that do what they say; inventory screen rebuilt with icons, tooltips and comparison.
- Companions as full party members: recruited through dialogue, controlled by the
  player with a per-companion AI toggle, levelling, equipped, with relationship
  affecting something.

### Phase 6 — Presentation (large, mostly asset-bound)

- Own art replacing the placeholders, worked through the art checklist: one biome, the
  town, the party and the first bestiary; item icons; dialogue portraits; spell
  effects.
- A UI Theme; panels rebuilt as scenes.
- Music for town, exploration and combat; sound effects.
- First-run guidance.

Phases 5 and 6 can interleave. Art can start as soon as its direction is decided.

**Milestone 2 — Vertical slice.** One to two hours of play that represents the finished
game: what a store page would be built from.

### Phase 7 — Zone 1 content

Content pipeline first (a text format you can write quests and dialogue in, with a
validator), then the three towns, main quest, faction lines, side quests, bestiary,
bosses, and a crisis that changes the world.

### Phase 8 — Early Access preparation

Export builds, performance, accessibility, localisation hooks, store page.

---

## 8. Decisions

Made by Ákos on 2026-11-16.

| # | Question | Decision |
|---|---|---|
| 1 | Combat input | Weapon-based action bar. The light / medium / heavy buttons go |
| 2 | Party in combat | The player controls each member on their turn, with an option to hand companions to AI |
| 3 | Towns | Town screen plus a world map of locations |
| 4 | Durability and repair | Keep. It is a core mechanic. Design settled 2026-11-17 from Ákos's homebrew system (below): notches per material, wear marks by the length of fights, critical hits and natural 1s taking notches, hardness, debuffs and buffs, repair by kit or smith, ageing. The numbers are tuned in the Phase 2 simulator |
| 5 | Level range | 1–5 for now, with expansion planned (below). Nothing may hard-code 5 |
| 6 | Art | Own art eventually, drawn at 32×32. Until then the Dungeon Crawl Stone Soup CC0 tiles as placeholders, wired so own art drops in by replacing files (below) |
| 7 | Names and lore | Deferred. The code's names stay until decided: Brackenford / Dawnwatch / Mournstead and Merchants' Guild / Order of the Dawn / Gravewardens. The design doc says Ironhold / Silverwood / Blackstone Keep and Royal Guard / Thieves Guild / Order of Light, and refers to a campaign setting that is not written down in the repo |
| 8 | Multiplayer | Shelved for now. Every system assumes one local player |

### Durability

Status: design settled with Ákos on 2026-11-17. It is his homebrew tabletop system
(`PROGRESS.md` says where the source document is), streamlined in discussion because
he found it "quite unbalanced" as it ran at the table. Numbers marked as dials are set
by the Phase 2 combat simulator, not by argument.

#### What it is for

His requirements, which outrank any single rule below:

- Gear should matter, "and it should matter what it's made of".
- Wear shows inside a fight, with special attention to critical hits.
- It adds no chore. The player's one upkeep action is repair. States are "a debuff
  and buff system, not to give players another thing to do".
- A state never has anything to do with wear marks. It may interact with notches.

#### Notches

- Everything wielded or worn as armour has notches: weapons, shields, body armour,
  helmets, and the shoulder, back, wrist, hands, waist, legs and feet slots. He
  overruled the first sketch, which left those seven out ("absolutely disagree").
  Accessories (neck, rings, trinkets) do not wear for now; he said he could be
  convinced of that.
- The count comes from the material: the durability score in his tables divided by
  about 8. Copper 2, bronze 3, steel 4, Damascus steel 5, mythril 6, adamantite 8.
- Masterforged adds one notch. Each plus of magic adds one.
- Every second lost notch costs -1: to hit for a weapon, AC for body armour and
  helmets. The first lost notch is free, the second costs, and so on. Never below
  the wearer's unarmoured AC. (He found -1 for every notch too harsh, for armour
  and weapons alike. Steel chain mail goes 16, 16, 15, 15, then broken at 10.)
- Shields and light armour keep their full bonus until the last notch goes. He
  confirmed this for light armour: leather gives only +1 AC and one notch would
  wipe it out.
- Medium and heavy armour always give at least +1 until they break, because hide
  and a chain shirt have small bonuses. Whatever bonus is left goes when the last
  notch goes.
- At zero notches the piece is broken: no bonus, and a weapon cannot attack. It is
  never destroyed.

#### Steady wear: marks

- Every piece used in a fight gains wear marks by the length of the fight: one mark
  for every two rounds, rounded up (1-2 rounds one mark, 3-4 two, 5-6 three).
- A weapon counts as used if it attacked; armour or a shield if it was attacked.
  Spares in the pack get none.
- When a piece's marks reach its limit it loses a notch and the marks start again.
- The limit is the piece's hardness times a factor. The factor is a dial. At 1
  (steel 5 marks) a steel sword loses a notch about every two fights and is broken
  within one run; about 3 fits the target below better.
- Marks are a plain counter. Nothing but the length of fights moves them.

#### Sudden wear: blows

| Event | Loss |
|---|---|
| A critical hit against you | 1 notch from your shield. Without a shield: two times in three from your body armour, one time in three from another worn armour piece picked at random. 2 notches from a two-handed or bludgeoning weapon |
| Your natural 1 on an attack | 1 notch from your weapon |
| Your critical hit on an armoured enemy | 1 notch from its shield or armour |
| Sunder, acid, rust | Notches directly |

#### Hardness

- Every material has a hardness: the break threshold number from his tables (copper
  3, bronze 4, steel 5, Damascus steel 6, adamantite 10), rescaled so metal, wood,
  leather and cloth share one scale. As written, some leathers and cloths come out
  harder than steel.
- Hardness sets the marks limit (above).
- When two pieces meet, compare them. This applies to a critical hit (the weapon
  against the shield or armour it lands on), a sunder, and a natural 1 (your weapon
  against the armour or hide of what you swung at).

| Comparison | Result |
|---|---|
| Striker harder by 2 or more | One extra notch |
| Within 1 either way | The normal notch |
| Struck piece harder by 2 or more | No notch, one mark instead |

- Acid and rust ignore hardness. They go by material traits (mythril rustproof,
  tantalum acid-resistant).
- Creatures have a hardness for natural weapons and for hide, set in the bestiary.

#### The seven secondary armour slots

Shoulder, back, wrist, hands, waist, legs and feet. Agreed 2026-11-17.

- They give no armour class. Body armour and shield set it, as in 5e.
- In a fight they take one critical hit in three for a wearer without a shield
  (the blows table). The share is a dial. It was chosen so the body armour still
  takes most critical hits and a shield stays the better protection. Spreading
  critical hits evenly over all worn armour was rejected: a notch on a secondary
  piece costs nothing until the piece breaks and the first lost notch is free
  everywhere, so it protected body armour too much.
- From Phase 3 they are the wearer's protection from the elements, using his
  weather rule: three layers (base clothing; an insulated layer of fur, wool or a
  cloak; waterproofing such as an oiled cloak or waxed boots). A place needs so
  many layers, and an underdressed character makes Constitution saves against
  exposure, then exhaustion. A broken piece stops counting.
- From Phase 4 they can matter socially. Not designed.
- Known gap: until Phase 3 a broken secondary piece costs nothing.
- Upkeep: a character has about eleven wearing pieces instead of four. These slots
  use a slower marks factor, and kits and the smith get a repair-all action.
  (Assumed; he was told and did not object.)

#### Magic and craftsmanship

- More notches, as above. +2 and +3 gear wears like everything else.
- Magic gear also has a chance to ignore a lost notch. He confirmed both together
  and wants the chance low. Starting values: +1 5%, +2 10%, +3 15% (dials).
- The chance works against blows only. A notch lost through wear marks is never
  resisted, so marks stay fully predictable. (Confirmed by him.)

#### Debuffs

- A debuff arrives only together with a lost notch, so there is always something to
  repair. Repairing the piece clears its debuffs. No debuff has its own cure, timer
  or supply.
- Each is one penalty, decided by what took the notch.

| Debuff | Applies to | Cause | Penalty |
|---|---|---|---|
| Cracked | Any piece | Two or more notches lost in one blow | Breaks on the next critical hit against it, or the next natural 1 with it |
| Breached | Armour | A piercing critical hit | Enemies score critical hits on 19-20 against the wearer |
| Dented | Armour, shields | A bludgeoning critical hit | One tile less movement |
| Torn | Leather, cloth | A slashing critical hit | Hits on the wearer deal +1 damage |
| Chipped | Weapons | A natural 1 | -1 damage |

- Scorched, brittle and corroded follow the same pattern when fire, cold and acid
  damage arrive (Phase 5 and the bestiary).
- A lost notch with no debuff still carries a name for its cause (dulled, dented,
  torn) as flavour only.

#### Buffs

- Hard earned, tracked by the game from what the piece has lived through, and
  permanent. Only a reforge erases them. They need no upkeep.
- First set, from his own list:

| Buff | Applies to | Earned by | Bonus |
|---|---|---|---|
| Battle-Honed | Weapons | Many kills without ever breaking | +1 to hit |
| Blood-Forged | Weapons | Many kills of one kind of creature | +1 damage against that kind |
| Mage-Touched | Weapons | Kills of spellcasters | +1 damage against them |
| Dragon-Hardened | Armour | Surviving a breath weapon | +1 AC against fire and cold |

- How many kills count as "many" is a dial.

#### Repair

- A field kit restores one notch on one piece, out of combat. It is paid for in
  kits and in scrap salvaged from loot, not gold.
- The scrap must be the same kind as the piece (metal, wood, leather or cloth) and
  at least as hard. Steel scrap patches bronze; copper cannot patch adamantite. The
  kit picks suitable scrap by itself. (Confirmed by him.)
- The smith restores everything for gold: a set fraction of the item's value. The
  numbers belong to Phase 4, with the shops.
- Any repair of a piece clears its debuffs.
- Looted gear arrives worn.
- His concern, which the rules above answer in three ways: a system like this can
  "eat all the gold all the time". Hardness means good gear barely wears against
  lesser enemies; field repair costs scrap, not gold; and ageing carries part of the
  long-term cost, so ordinary repair can stay cheap.

#### Ageing

- Every piece has an age counter, separate from its notches. It rises by one for
  each notch repaired, wherever and whenever the repair happens.
- Every so many points the piece loses one maximum notch. Better materials take more
  points. (A dial.)
- A reforge clears the age, but the piece comes back as a new item without its
  history: its buffs are gone.
- He saw the appeal of weapons being retired and worried players would find it
  frustrating. Watch for that in play.

#### Materials

- His material lists replace the game's ladder of 20. They are added in stages, zone
  by zone, not all at once.
- Stage one, agreed 2026-11-17, for levels 1 to 5:
  - Metal: copper, wrought iron, bronze, steel, silver, Damascus steel.
  - Wood: pine, oak, ash, maple, hickory, ironwood.
  - Leather: pigskin, deerskin, cowhide, boiled leather, wolfhide, bearhide.
  - Cloth: burlap, roughspun wool, cotton, wool, fine linen, silk.
  Mythril, adamantite and the other top materials stay defined but do not drop in
  the first zone.
- A material sets the notch count, hardness, price, weight and a trait. In his
  system it does not change the damage die or the armour class; the game's current
  materials add +1 to +3 to both. He confirmed those bonuses go: materials "should
  absolutely stop adding any stats. materials are for the durability and hardness
  rules not gameplay changes." Whether that also rules out material traits (silver
  against undead, mythril at half weight) has been asked and not yet answered.

#### How it is shown

- A bar cut into segments. Each segment is a notch; the fill inside the current
  segment is the wear marks.
- Debuffs and buffs appear on the item's tooltip and on the character sheet.

#### Target and dials

- Target for one dungeon run, confirmed by him: cheap gear breaks unless repaired or
  swapped, steel comes home damaged, the best gear comes home merely worn.
- Dials for the simulator: the marks factor; the divisor of 8; the hardness gap of
  2; the extra notch for two-handed and bludgeoning weapons; the magic resist
  chances; kills needed for each buff; age points per lost maximum notch; what a kit
  restores; the smith's fraction.

#### Still to confirm or decide

None of these blocks the Phase 2 hooks.

- Material traits: kept, or out along with the stat bonuses. He deferred it ("we
  can talk about traits later").
- Resting rules. A separate discussion; it includes whether anything clears marks.
- Climate for places, which the secondary slots protect against (Phase 3), and
  what worn gear does socially (Phase 4). Neither is designed.

#### How this was arrived at

Three shapes were considered: upkeep across an expedition, erosion inside a fight, and
ablative armour as in Battle Brothers. Ákos chose erosion. Armour stays 5e: it makes
the wearer harder to hit and absorbs nothing. The option tables and my first sketch are
in this file's history before 2026-11-17.

Ideas he turned down, so they do not come back:

- A per-material break threshold, and a penalty range over the last 25% of
  durability. He chose a cost per lost notch.
- A d6 roll per piece for long fights. Wear marks replaced it, because a short fight
  with no critical hit should still cost something.
- Counting every swing. It is a points system under another name.
- States that key off marks, change marks or change hardness.
- States with their own cures (oil, a fire, a forge only) and states prepared at camp
  (honed, oiled, fitted). They gave the player another thing to do.

### Level expansion

- Levels 6–20 have 5e tables. Class data already carries slot tables to 20 (the
  wizard's needs correcting from level 11).
- Levels 21–40 have no 5e source and would need designed tables. `CharacterStats`
  already extrapolates the XP curve to 40. Decide when Zone 1 content approaches 20.
- Rule until then: class features, spells, bestiary and encounter budgets are data
  keyed by level, so raising the cap means adding rows, not changing code.

### Placeholder art

- **Chosen set:** the Dungeon Crawl Stone Soup tiles, 32×32, CC0. Downloaded
  2026-11-16 into `art_source/dcss-tiles/` (4,357 PNGs, 11 MB), with provenance in
  `art_source/CREDITS.md`. The folder is hidden from Godot by a `.gdignore`; only
  tiles the game uses get copied into `assets/`.
- **Licence, checked at the source:** the Crawl project says most, not all, of its
  tiles are CC0. This copy is the project's own cleared export (`crawl/tiles`, release
  `Nov-2015`), which leaves out about 1,300 tiles of unclear ownership. Do not top it
  up from the game repository or other mirrors without checking the exclusion list.
- **Coverage, checked:** goblin, hobgoblin, human, wolf, skeletons, wight, ghoul, lich
  and orcs among 772 monsters; crypt, cave, grass, stone and brick floor and wall
  themes; doors, traps, altars, stairs, trees; 673 item sprites; spell icons and
  effects. No sprite is named "bandit"; the human tiles stand in.
- **Layered characters:** 819 player sprites come as layers (body, legs, armour, each
  hand, head, cloak). Compositing them shows a character's equipped gear on the map.
- **Static sprites.** Movement and attacks are already tweened, which is enough for
  tile tactics.
- **Sound and UI stand-ins:** still to choose. Licence text gets checked for every
  pack at download and recorded in the credits file.
- **Swappable by design:** an `assets/` tree and a manifest mapping content ids (enemy,
  item, tile role, spell) to sprite files, with a fallback for anything missing. From
  the content registries I generate an art checklist: every sprite the game needs,
  with size and file name. Own art is then produced against that list and dropped in.
- **Grid size is 32×32**, for the placeholders and for own art. The game moves from
  16-pixel to 32-pixel tiles in Phase 1.

Other mismatches between design doc and code, for when they matter: faction reputation
scale (−100..100 in code, up to 5000 in the doc); equipment slots (13 plus rings and
trinkets in code, 11 in the doc); the doc's world name, lore and zones 4–9 are still
placeholders.

One note for a commercial release: D&D 5e rules are usable through the SRD under
CC-BY-4.0 with attribution, which covers the classes, spells and monsters used so far.
Content outside the SRD is not covered.

---

## 9. Working method

- One branch per phase, small commits, smoke test and screenshot tour before each.
- I report what I ran and what I saw, with screenshots for anything visual.
- You play each phase's exit build for ten minutes; feel and fun are your call.
- Story, names and lore come from you; I implement and keep them consistent.
- The real constraints on pace are your playtest time, the decisions above, and art
  and audio. Code volume is not the bottleneck.
