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
| 4 | Durability and repair | Keep. It is a core mechanic. Direction set 2026-11-17: shape B (erosion), with special attention to critical hits, scaled by material rarity and magic level. The actual rules will be based on the system Ákos designed for his homebrew D&D campaign, which he will bring. The sketch below is provisional |
| 5 | Level range | 1–5 for now, with expansion planned (below). Nothing may hard-code 5 |
| 6 | Art | Own art eventually, drawn at 32×32. Until then the Dungeon Crawl Stone Soup CC0 tiles as placeholders, wired so own art drops in by replacing files (below) |
| 7 | Names and lore | Deferred. The code's names stay until decided: Brackenford / Dawnwatch / Mournstead and Merchants' Guild / Order of the Dawn / Gravewardens. The design doc says Ironhold / Silverwood / Blackstone Keep and Royal Guard / Thieves Guild / Order of Light, and refers to a campaign setting that is not written down in the repo |
| 8 | Multiplayer | Shelved for now. Every system assumes one local player |

### Durability

Status: direction set 2026-11-17, rules not final. Ákos chose shape B with special
attention to critical hits, depending on material rarity and magic level. He has a
durability system he designed for his homebrew D&D campaign and the game's rules will
be based on that; he will supply it. It includes **passive degradation based on combat
length**, which the sketch below does not have.

Until his system is in this document, nothing below is settled. Phase 2 builds the
damage pipeline with the hooks durability needs and leaves the rules themselves for
his input.

#### What Ákos has specified so far

These are his and are fixed points for whatever the final rules become:

- Erosion (shape B), with special attention to critical hits: they cause extra
  durability loss or a special effect.
- Passive degradation as well, based on how long a fight lasts.
- How many notches a piece has depends on more than rarity. A magic item has more
  than a plain one (+1 more than +0, and so on), and an item of a better material
  has more than one of a poorer material, material by material rather than by
  rarity band.
- The rest comes from the system he designed for his homebrew D&D campaign.

Added later on 2026-11-17, after he supplied that system (`PROGRESS.md` says where
it is and which parts have been read). He called it "quite unbalanced" as it ran at
the table and wants it streamlined, keeping the feeling: gear should matter, and it
should matter what it is made of.

- Pace is shape B's: gear wears visibly inside a fight.
- Durability is counted in notches, as in the sketch below, but the count comes
  from his material tables, material by material.
- Effect of wear is the sketch's: each lost notch costs at once. The per-material
  break threshold goes. (He first replaced it with a penalty range over the last
  25% of durability for every piece, then preferred the sketch's version the same
  day.)
- Magic and craftsmanship work as in the sketch (a chance to resist a loss). +2 and
  +3 gear wears too and may also get more notches. Whether he means both together
  is to be confirmed.
- Repair is the sketch's: a kit in the field, the smith for everything, loot
  arrives worn.
- Materials are his lists. The count rises heavily from today's 20.
- The twelve named damage states and their separate repair methods get simplified.
  How far is open.
- Open: what makes gear lose durability, including his combat-length rule.
- Open: ageing. He sees the appeal of weapons being retired but expects players to
  find it frustrating.
- Resting rules are needed, as a separate discussion.

#### Provisional sketch (to be replaced by the homebrew system)

Written before Ákos mentioned his own system. Keep what fits it; drop the rest.

**Notches.** Weapons, shields, body armour and helmets have a small number of
condition notches. Nothing else wears. Notches replace the unused 20-to-150 point
durability value.

| Material tier | Notches |
|---|---|
| Common | 3 |
| Uncommon | 4 |
| Rare | 5 |
| Epic | 6 |
| Legendary | 7 |

Each level of craftsmanship quality adds one notch.
(Superseded by Ákos's input above: the count must also rise with the magic bonus, and
with the material itself rather than only its rarity tier. The sketch gave magic a
chance to resist a loss instead of extra notches.)

**What wears gear: the extremes of the die.** Ordinary hits and misses never wear
anything. Wear comes from natural 20s, natural 1s, and attacks aimed at gear.
(Superseded: the homebrew system also wears gear passively, by how long a fight lasts.)

- **You are critically hit:** your shield loses a notch if you carry one, otherwise
  your body armour does. Shields exist to take that blow.
- **You roll a natural 1 on an attack:** your weapon loses a notch.
- **You critically hit an armoured enemy:** its shield or armour loses a notch, and
  its AC drops for everyone attacking it after you.
- **Gear-targeting attacks:** a Sunder action, and creatures whose attacks corrode
  (rust, acid), strip notches directly.

**Material, quality and magic decide how bad it is.**

- **Heavier blow.** A critical hit from a two-handed or bludgeoning weapon strips two
  notches instead of one.
- **Tier advantage.** If the attacking weapon's material tier is above the tier of the
  piece it damages, it strips one extra notch. A fine blade shears cheap armour.
- **Ward.** Magic gear resists: +1 ignores a lost notch 25% of the time, +2 50%, +3 75%.
- More notches for better material and better craftsmanship, as in the table.

**What a lost notch costs.**

- Body armour and helmets: −1 AC per lost notch, never below the wearer's unarmoured AC.
- Weapons: −1 to hit per lost notch.
- Shields: full bonus until the last notch goes. They are a buffer, not a slope.
- At zero notches the piece is **broken**: no bonus, a weapon cannot attack. It is
  never destroyed and can always be repaired.

**Repair.**

- A repair kit restores one notch on one piece, out of combat.
- The smith restores everything for gold; the cost per notch rises with material tier.
- Looted gear arrives with notches already missing.

**Dials to tune by play.** Notch counts per tier; whether ordinary hits should ever
wear gear; the extra notches for heavy weapons and tier advantage; ward percentages;
kit strength and smith prices; whether helmets wear at all.

**Special effects to try once the base works.**

- *Shield sacrifice:* when critically hit, choose to let the shield take two notches
  and turn the critical hit into a normal one.
- *Crit effects by damage type:* slashing rends armour (the standard notch),
  bludgeoning dents it harder or staggers, piercing finds the gap and bleeds instead
  of damaging gear.
- *Material properties:* adamantine armour that critical hits cannot notch, silver
  that notches easily, and similar.
- *Scars:* a piece that has been broken and repaired loses a notch for good.

#### Background: the options considered

Before Phase 1 the field existed on every item instance and material tiers set its
maximum (20 to 150), but nothing ever wore and repair had no caller.

**The underlying tension.** The two games the pitch names treat armour in opposite
ways. In 5e, armour makes you harder to hit and absorbs nothing; the rules have no
durability. In Battle Brothers, armour is a second health bar that is destroyed hit by
hit, and that is where its durability system gets its weight. "Durability is core"
means something different depending on which of those the game follows.

**Three shapes it could take.**

| | A. Upkeep | B. Erosion | C. Ablative |
|---|---|---|---|
| Armour does | Harder to hit (5e) | Harder to hit (5e) | Absorbs damage (Battle Brothers) |
| Wear moves | Slowly, over an expedition | Fast, inside a single fight | Every hit |
| Effect of wear | Nothing until a threshold, then a small penalty, then broken | Each lost notch is −1 AC or −1 to hit, immediately | Armour points gone means hits reach HP |
| What the player does | Budgets for repairs, carries a spare, decides when to turn back | Reads the fight: shields splinter, long fights get dangerous, patches up between fights | Chooses weapons by armour damage, protects armour as a resource |
| 5e maths and SRD monsters | Unchanged | Unchanged in form; AC drifts during a fight | Replaced; every stat block needs converting |
| Risk | Can feel like a chore bar | More to track per fight | No longer "real 5e" |

B has a precedent inside 5e itself: the SRD's rust monster and oozes give metal weapons
and armour a cumulative −1 per corrosion until destroyed. B generalises that rule to
ordinary combat.

**Sub-questions that settle the design.**

1. **Timescale.** Should gear visibly degrade within one fight, or across a whole
   expedition? This is the main dial; it decides between A and B.
2. **Armour's job.** Harder to hit, or absorbs damage? (C is the only shape that
   breaks with 5e.)
3. **What triggers wear.** Steady and predictable (every hit removes points), or
   dice-driven events (a critical hit splits the shield, a natural 1 chips the blade,
   an attack that only missed because of the armour dents it)?
4. **Permanence.** Can an item be lost for good? Is everything fully repairable, or
   does repeated breaking leave a permanent scar that lowers its maximum?
5. **Player verbs.** Passive wear only, or also actions and enemies that target gear:
   sundering a shield, acid, rust?
6. **Magic and named items.** Exempt, slower, or the same as everything else?
7. **Field repair.** Kits and camp, or town only? Does a tool proficiency matter?
8. **Which slots.** Weapon, shield and body armour only, or all thirteen?

**Outcome:** shape B. Pending the homebrew system, the sketch above answers the
sub-questions as: wear inside a fight (1); armour makes you harder to hit (2); dice-driven
triggers, critical hits above all (3); nothing destroyed, scars held back as a later
option (4); sundering and corroding enemies are in (5); magic gear wears more slowly
(6); kits in the field, the smith in town (7); weapon, shield, body armour and
helmet (8).

**These hold whatever the tuning:**

- Wear runs through the Phase 2 damage pipeline, so it covers the whole party and can
  be modified by materials, features and enchantments.
- Repair lives with the smith, the forge and field kits (Phase 4). Looted gear arrives
  worn. Material tier drives how much wear a piece can take and what repair costs.
- State is readable at a glance: on tooltips, on the character sheet, and as a warning
  before something fails.

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
