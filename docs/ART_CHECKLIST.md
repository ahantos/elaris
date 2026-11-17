# Art checklist

Every piece of art the game loads right now: where the file is, how big it is, what
it is used for, and which Dungeon Crawl Stone Soup tile (CC0, see
`art_source/CREDITS.md`) is standing in for it. Draw against this list.

**Generated file, do not edit by hand.** It is written by `tools/art_checklist.gd` from
`data/art/art_manifest.gd` and the item database. Regenerate it after changing the
manifest, adding items, or replacing files (run from the project folder):

```
"%GODOT_EXE%" --headless --path . --script res://tools/art_checklist.gd
```

## Replacing a piece of art

1. Save your PNG over the file in the first column, same name, same folder.
2. Open the project in Godot once, or run `tools\run_checks.bat`, so the file is imported.

That is all; no code changes. Map tiles must be exactly 32x32. Sprites and icons are
32x32 too, but a larger square image is scaled down to fit. Use a transparent
background wherever the floor should show through. Textures are drawn unfiltered
(nearest neighbour), so pixels stay sharp.

To add art for something new (an enemy type, an item, a tile variant, a biome), add a
row to the matching table in `data/art/art_manifest.gd`; the comments there say where
the file goes. Anything without art is drawn as a magenta and black checker, and the
smoke test names it.

The **Status** column compares each file with its stand-in: `stand-in` means it is still
the placeholder, `own art` means the file has been replaced (or never had a placeholder),
`MISSING` means the manifest lists a file that is not there.

## Summary

| Group | Files | Still stand-ins | Own art | Missing |
|---|---|---|---|---|
| Map tiles | 59 | 59 | 0 | 0 |
| Enemies | 4 | 4 | 0 | 0 |
| Player | 4 | 4 | 0 | 0 |
| Companions | 4 | 4 | 0 | 0 |
| Loot on the floor | 2 | 2 | 0 | 0 |
| Item icons | 74 | 74 | 0 | 0 |
| **Total** | **147** | **147** | **0** | **0** |

Items in the database: 448, of which 448 have an icon.

## Map tiles

Opaque for floors. Walls, doors and decorations are drawn over a floor tile, so they may be transparent around the edges. The percentage is how many cells of that role show the variant.

| File | Size | Used for | Stand-in (under `art_source/dcss-tiles/`) | Status |
|---|---|---|---|---|
| `assets/tiles/house/floor_1.png` | 32x32 | house biome, floor (variant 1 of 4, about 25% of cells) | `dngn/floor/sandstone_floor0.png` | stand-in |
| `assets/tiles/house/floor_2.png` | 32x32 | house biome, floor (variant 2 of 4, about 25% of cells) | `dngn/floor/sandstone_floor1.png` | stand-in |
| `assets/tiles/house/floor_3.png` | 32x32 | house biome, floor (variant 3 of 4, about 25% of cells) | `dngn/floor/sandstone_floor2.png` | stand-in |
| `assets/tiles/house/floor_4.png` | 32x32 | house biome, floor (variant 4 of 4, about 25% of cells) | `dngn/floor/sandstone_floor3.png` | stand-in |
| `assets/tiles/house/wall_1.png` | 32x32 | house biome, wall (variant 1 of 4, about 25% of cells) | `dngn/wall/brick_brown0.png` | stand-in |
| `assets/tiles/house/wall_2.png` | 32x32 | house biome, wall (variant 2 of 4, about 25% of cells) | `dngn/wall/brick_brown1.png` | stand-in |
| `assets/tiles/house/wall_3.png` | 32x32 | house biome, wall (variant 3 of 4, about 25% of cells) | `dngn/wall/brick_brown2.png` | stand-in |
| `assets/tiles/house/wall_4.png` | 32x32 | house biome, wall (variant 4 of 4, about 25% of cells) | `dngn/wall/brick_brown3.png` | stand-in |
| `assets/tiles/house/door_1.png` | 32x32 | house biome, door | `dngn/doors/closed_door.png` | stand-in |
| `assets/tiles/house/decoration_1.png` | 32x32 | house biome, decoration | `dngn/blue_fountain.png` | stand-in |
| `assets/tiles/cave/floor_1.png` | 32x32 | cave biome, floor (variant 1 of 4, about 25% of cells) | `dngn/floor/pebble_brown0.png` | stand-in |
| `assets/tiles/cave/floor_2.png` | 32x32 | cave biome, floor (variant 2 of 4, about 25% of cells) | `dngn/floor/pebble_brown1.png` | stand-in |
| `assets/tiles/cave/floor_3.png` | 32x32 | cave biome, floor (variant 3 of 4, about 25% of cells) | `dngn/floor/pebble_brown2.png` | stand-in |
| `assets/tiles/cave/floor_4.png` | 32x32 | cave biome, floor (variant 4 of 4, about 25% of cells) | `dngn/floor/pebble_brown3.png` | stand-in |
| `assets/tiles/cave/wall_1.png` | 32x32 | cave biome, wall (variant 1 of 4, about 25% of cells) | `dngn/wall/lair0.png` | stand-in |
| `assets/tiles/cave/wall_2.png` | 32x32 | cave biome, wall (variant 2 of 4, about 25% of cells) | `dngn/wall/lair1.png` | stand-in |
| `assets/tiles/cave/wall_3.png` | 32x32 | cave biome, wall (variant 3 of 4, about 25% of cells) | `dngn/wall/lair2.png` | stand-in |
| `assets/tiles/cave/wall_4.png` | 32x32 | cave biome, wall (variant 4 of 4, about 25% of cells) | `dngn/wall/lair3.png` | stand-in |
| `assets/tiles/cave/door_1.png` | 32x32 | cave biome, door | `dngn/doors/open_door.png` | stand-in |
| `assets/tiles/cave/decoration_1.png` | 32x32 | cave biome, decoration (variant 1 of 3, about 50% of cells) | `dngn/wall/crystal_wall_lightcyan.png` | stand-in |
| `assets/tiles/cave/decoration_2.png` | 32x32 | cave biome, decoration (variant 2 of 3, about 25% of cells) | `dngn/wall/crystal_wall_lightblue.png` | stand-in |
| `assets/tiles/cave/decoration_3.png` | 32x32 | cave biome, decoration (variant 3 of 3, about 25% of cells) | `dngn/wall/crystal_wall_lightmagenta.png` | stand-in |
| `assets/tiles/dungeon/floor_1.png` | 32x32 | dungeon biome, floor (variant 1 of 4, about 25% of cells) | `dngn/floor/rect_gray0.png` | stand-in |
| `assets/tiles/dungeon/floor_2.png` | 32x32 | dungeon biome, floor (variant 2 of 4, about 25% of cells) | `dngn/floor/rect_gray1.png` | stand-in |
| `assets/tiles/dungeon/floor_3.png` | 32x32 | dungeon biome, floor (variant 3 of 4, about 25% of cells) | `dngn/floor/rect_gray2.png` | stand-in |
| `assets/tiles/dungeon/floor_4.png` | 32x32 | dungeon biome, floor (variant 4 of 4, about 25% of cells) | `dngn/floor/rect_gray3.png` | stand-in |
| `assets/tiles/dungeon/wall_1.png` | 32x32 | dungeon biome, wall (variant 1 of 4, about 25% of cells) | `dngn/wall/brick_gray0.png` | stand-in |
| `assets/tiles/dungeon/wall_2.png` | 32x32 | dungeon biome, wall (variant 2 of 4, about 25% of cells) | `dngn/wall/brick_gray1.png` | stand-in |
| `assets/tiles/dungeon/wall_3.png` | 32x32 | dungeon biome, wall (variant 3 of 4, about 25% of cells) | `dngn/wall/brick_gray2.png` | stand-in |
| `assets/tiles/dungeon/wall_4.png` | 32x32 | dungeon biome, wall (variant 4 of 4, about 25% of cells) | `dngn/wall/brick_gray3.png` | stand-in |
| `assets/tiles/dungeon/door_1.png` | 32x32 | dungeon biome, door | `dngn/doors/gate_closed_middle.png` | stand-in |
| `assets/tiles/dungeon/decoration_1.png` | 32x32 | dungeon biome, decoration | `dngn/floor/pedestal_full.png` | stand-in |
| `assets/tiles/crypt/floor_1.png` | 32x32 | crypt biome, floor (variant 1 of 4, about 25% of cells) | `dngn/floor/green_bones01.png` | stand-in |
| `assets/tiles/crypt/floor_2.png` | 32x32 | crypt biome, floor (variant 2 of 4, about 25% of cells) | `dngn/floor/green_bones02.png` | stand-in |
| `assets/tiles/crypt/floor_3.png` | 32x32 | crypt biome, floor (variant 3 of 4, about 25% of cells) | `dngn/floor/green_bones03.png` | stand-in |
| `assets/tiles/crypt/floor_4.png` | 32x32 | crypt biome, floor (variant 4 of 4, about 25% of cells) | `dngn/floor/green_bones04.png` | stand-in |
| `assets/tiles/crypt/wall_1.png` | 32x32 | crypt biome, wall (variant 1 of 6, about 22% of cells) | `dngn/wall/catacombs0.png` | stand-in |
| `assets/tiles/crypt/wall_2.png` | 32x32 | crypt biome, wall (variant 2 of 6, about 22% of cells) | `dngn/wall/catacombs1.png` | stand-in |
| `assets/tiles/crypt/wall_3.png` | 32x32 | crypt biome, wall (variant 3 of 6, about 22% of cells) | `dngn/wall/catacombs2.png` | stand-in |
| `assets/tiles/crypt/wall_4.png` | 32x32 | crypt biome, wall (variant 4 of 6, about 22% of cells) | `dngn/wall/catacombs3.png` | stand-in |
| `assets/tiles/crypt/wall_5.png` | 32x32 | crypt biome, wall (variant 5 of 6, about 6% of cells) | `dngn/wall/catacombs14.png` | stand-in |
| `assets/tiles/crypt/wall_6.png` | 32x32 | crypt biome, wall (variant 6 of 6, about 6% of cells) | `dngn/wall/catacombs15.png` | stand-in |
| `assets/tiles/crypt/door_1.png` | 32x32 | crypt biome, door | `dngn/doors/runed_door.png` | stand-in |
| `assets/tiles/crypt/decoration_1.png` | 32x32 | crypt biome, decoration | `dngn/vaults/sarcophagus_sealed.png` | stand-in |
| `assets/tiles/forest/floor_1.png` | 32x32 | forest biome, floor (variant 1 of 6, about 30% of cells) | `dngn/floor/grass/grass0.png` | stand-in |
| `assets/tiles/forest/floor_2.png` | 32x32 | forest biome, floor (variant 2 of 6, about 30% of cells) | `dngn/floor/grass/grass1.png` | stand-in |
| `assets/tiles/forest/floor_3.png` | 32x32 | forest biome, floor (variant 3 of 6, about 30% of cells) | `dngn/floor/grass/grass2.png` | stand-in |
| `assets/tiles/forest/floor_4.png` | 32x32 | forest biome, floor (variant 4 of 6, about 4% of cells) | `dngn/floor/grass/grass_flowers_blue1.png` | stand-in |
| `assets/tiles/forest/floor_5.png` | 32x32 | forest biome, floor (variant 5 of 6, about 4% of cells) | `dngn/floor/grass/grass_flowers_red1.png` | stand-in |
| `assets/tiles/forest/floor_6.png` | 32x32 | forest biome, floor (variant 6 of 6, about 4% of cells) | `dngn/floor/grass/grass_flowers_yellow1.png` | stand-in |
| `assets/tiles/forest/wall_1.png` | 32x32 | forest biome, wall (variant 1 of 5, about 27% of cells) | `dngn/trees/mangrove1.png` | stand-in |
| `assets/tiles/forest/wall_2.png` | 32x32 | forest biome, wall (variant 2 of 5, about 27% of cells) | `dngn/trees/mangrove2.png` | stand-in |
| `assets/tiles/forest/wall_3.png` | 32x32 | forest biome, wall (variant 3 of 5, about 27% of cells) | `dngn/trees/mangrove3.png` | stand-in |
| `assets/tiles/forest/wall_4.png` | 32x32 | forest biome, wall (variant 4 of 5, about 9% of cells) | `dngn/trees/tree1_yellow.png` | stand-in |
| `assets/tiles/forest/wall_5.png` | 32x32 | forest biome, wall (variant 5 of 5, about 9% of cells) | `dngn/trees/tree2_yellow.png` | stand-in |
| `assets/tiles/forest/door_1.png` | 32x32 | forest biome, door | `dngn/floor/grass/grass0-dirt-mix1.png` | stand-in |
| `assets/tiles/forest/decoration_1.png` | 32x32 | forest biome, decoration (variant 1 of 3, about 33% of cells) | `mon/fungi_plants/bush2.png` | stand-in |
| `assets/tiles/forest/decoration_2.png` | 32x32 | forest biome, decoration (variant 2 of 3, about 33% of cells) | `mon/fungi_plants/bush3.png` | stand-in |
| `assets/tiles/forest/decoration_3.png` | 32x32 | forest biome, decoration (variant 3 of 3, about 33% of cells) | `mon/fungi_plants/bush4.png` | stand-in |

## Enemies

Drawn at one tile. Transparent background.

| File | Size | Used for | Stand-in (under `art_source/dcss-tiles/`) | Status |
|---|---|---|---|---|
| `assets/sprites/enemies/goblin.png` | 32x32 | enemy type 'goblin' | `mon/goblin.png` | stand-in |
| `assets/sprites/enemies/skeleton.png` | 32x32 | enemy type 'skeleton' | `mon/undead/skeletons/skeleton_humanoid_small.png` | stand-in |
| `assets/sprites/enemies/bandit.png` | 32x32 | enemy type 'bandit' | `mon/human.png` | stand-in |
| `assets/sprites/enemies/wolf.png` | 32x32 | enemy type 'wolf' | `mon/animals/wolf.png` | stand-in |

## Player

One sprite per class; the sprite follows the character's class.

| File | Size | Used for | Stand-in (under `art_source/dcss-tiles/`) | Status |
|---|---|---|---|---|
| `assets/sprites/player/fighter.png` | 32x32 | the player as a fighter (also before a class is chosen) | `mon/unique/terence.png` | stand-in |
| `assets/sprites/player/wizard.png` | 32x32 | the player as a wizard | `mon/unique/jessica.png` | stand-in |
| `assets/sprites/player/cleric.png` | 32x32 | the player as a cleric | `mon/unique/edmund.png` | stand-in |
| `assets/sprites/player/rogue.png` | 32x32 | the player as a rogue | `mon/unique/maurice.png` | stand-in |

## Companions

A companion without a sprite of its own is drawn with the player sprite of its class.

| File | Size | Used for | Stand-in (under `art_source/dcss-tiles/`) | Status |
|---|---|---|---|---|
| `assets/sprites/companions/kaelen.png` | 32x32 | companion 'kaelen' | `mon/vault_guard.png` | stand-in |
| `assets/sprites/companions/lyra.png` | 32x32 | companion 'lyra' | `mon/deep_elf_conjurer.png` | stand-in |
| `assets/sprites/companions/brom.png` | 32x32 | companion 'brom' | `mon/dwarf.png` | stand-in |
| `assets/sprites/companions/whisper.png` | 32x32 | companion 'whisper' | `mon/halfling.png` | stand-in |

## Loot on the floor

| File | Size | Used for | Stand-in (under `art_source/dcss-tiles/`) | Status |
|---|---|---|---|---|
| `assets/sprites/loot/loot_bag.png` | 32x32 | loot on the floor that holds items | `item/armour/animal_skin1.png` | stand-in |
| `assets/sprites/loot/loot_gold.png` | 32x32 | loot on the floor that is gold only | `item/gold/10.png` | stand-in |

## Item icons

Shown in the character sheet at twice their size. Material variants share the icon of their base type.

| File | Size | Used for | Stand-in (under `art_source/dcss-tiles/`) | Status |
|---|---|---|---|---|
| `assets/icons/items/dagger.png` | 32x32 | 9 items: `adamantite_dagger`, `bronze_dagger`, `copper_dagger`, `dagger`, `damascus_steel_dagger`, `mythril_dagger`, `silver_dagger`, `steel_dagger`, `wrought_iron_dagger` | `item/weapon/dagger.png` | stand-in |
| `assets/icons/items/shortsword.png` | 32x32 | 9 items: `adamantite_shortsword`, `bronze_shortsword`, `copper_shortsword`, `damascus_steel_shortsword`, `mythril_shortsword`, `shortsword`, `silver_shortsword`, `steel_shortsword`, `wrought_iron_shortsword` | `item/weapon/short_sword1.png` | stand-in |
| `assets/icons/items/longsword.png` | 32x32 | 9 items: `adamantite_longsword`, `bronze_longsword`, `copper_longsword`, `damascus_steel_longsword`, `longsword`, `mythril_longsword`, `silver_longsword`, `steel_longsword`, `wrought_iron_longsword` | `item/weapon/long_sword1.png` | stand-in |
| `assets/icons/items/greatsword.png` | 32x32 | 9 items: `adamantite_greatsword`, `bronze_greatsword`, `copper_greatsword`, `damascus_steel_greatsword`, `greatsword`, `mythril_greatsword`, `silver_greatsword`, `steel_greatsword`, `wrought_iron_greatsword` | `item/weapon/greatsword1.png` | stand-in |
| `assets/icons/items/handaxe.png` | 32x32 | 9 items: `adamantite_handaxe`, `bronze_handaxe`, `copper_handaxe`, `damascus_steel_handaxe`, `handaxe`, `mythril_handaxe`, `silver_handaxe`, `steel_handaxe`, `wrought_iron_handaxe` | `item/weapon/hand_axe1.png` | stand-in |
| `assets/icons/items/battleaxe.png` | 32x32 | 9 items: `adamantite_battleaxe`, `battleaxe`, `bronze_battleaxe`, `copper_battleaxe`, `damascus_steel_battleaxe`, `mythril_battleaxe`, `silver_battleaxe`, `steel_battleaxe`, `wrought_iron_battleaxe` | `UNUSED/weapons/battle_axe4.png` | stand-in |
| `assets/icons/items/greataxe.png` | 32x32 | 9 items: `adamantite_greataxe`, `bronze_greataxe`, `copper_greataxe`, `damascus_steel_greataxe`, `greataxe`, `mythril_greataxe`, `silver_greataxe`, `steel_greataxe`, `wrought_iron_greataxe` | `UNUSED/weapons/executioner_axe4.png` | stand-in |
| `assets/icons/items/mace.png` | 32x32 | 9 items: `adamantite_mace`, `bronze_mace`, `copper_mace`, `damascus_steel_mace`, `mace`, `mythril_mace`, `silver_mace`, `steel_mace`, `wrought_iron_mace` | `item/weapon/mace1.png` | stand-in |
| `assets/icons/items/warhammer.png` | 32x32 | 9 items: `adamantite_warhammer`, `bronze_warhammer`, `copper_warhammer`, `damascus_steel_warhammer`, `mythril_warhammer`, `silver_warhammer`, `steel_warhammer`, `warhammer`, `wrought_iron_warhammer` | `UNUSED/weapons/hammer1.png` | stand-in |
| `assets/icons/items/spear.png` | 32x32 | 9 items: `adamantite_spear`, `bronze_spear`, `copper_spear`, `damascus_steel_spear`, `mythril_spear`, `silver_spear`, `spear`, `steel_spear`, `wrought_iron_spear` | `item/weapon/spear1.png` | stand-in |
| `assets/icons/items/rapier.png` | 32x32 | 9 items: `adamantite_rapier`, `bronze_rapier`, `copper_rapier`, `damascus_steel_rapier`, `mythril_rapier`, `rapier`, `silver_rapier`, `steel_rapier`, `wrought_iron_rapier` | `item/weapon/rapier1.png` | stand-in |
| `assets/icons/items/quarterstaff.png` | 32x32 | 10 items: `ash_quarterstaff`, `ebony_quarterstaff`, `hickory_quarterstaff`, `ironwood_quarterstaff`, `maple_quarterstaff`, `oak_quarterstaff`, `pine_quarterstaff`, `quarterstaff`, `starwood_quarterstaff`, `yew_quarterstaff` | `item/weapon/quarterstaff.png` | stand-in |
| `assets/icons/items/club.png` | 32x32 | 10 items: `ash_club`, `club`, `ebony_club`, `hickory_club`, `ironwood_club`, `maple_club`, `oak_club`, `pine_club`, `starwood_club`, `yew_club` | `item/weapon/club.png` | stand-in |
| `assets/icons/items/shortbow.png` | 32x32 | 10 items: `ash_shortbow`, `ebony_shortbow`, `hickory_shortbow`, `ironwood_shortbow`, `maple_shortbow`, `oak_shortbow`, `pine_shortbow`, `shortbow`, `starwood_shortbow`, `yew_shortbow` | `item/weapon/ranged/shortbow1.png` | stand-in |
| `assets/icons/items/longbow.png` | 32x32 | 10 items: `ash_longbow`, `ebony_longbow`, `hickory_longbow`, `ironwood_longbow`, `longbow`, `maple_longbow`, `oak_longbow`, `pine_longbow`, `starwood_longbow`, `yew_longbow` | `item/weapon/ranged/longbow1.png` | stand-in |
| `assets/icons/items/light_crossbow.png` | 32x32 | 10 items: `ash_light_crossbow`, `ebony_light_crossbow`, `hickory_light_crossbow`, `ironwood_light_crossbow`, `light_crossbow`, `maple_light_crossbow`, `oak_light_crossbow`, `pine_light_crossbow`, `starwood_light_crossbow`, `yew_light_crossbow` | `item/weapon/ranged/hand_crossbow.png` | stand-in |
| `assets/icons/items/heavy_crossbow.png` | 32x32 | 10 items: `ash_heavy_crossbow`, `ebony_heavy_crossbow`, `heavy_crossbow`, `hickory_heavy_crossbow`, `ironwood_heavy_crossbow`, `maple_heavy_crossbow`, `oak_heavy_crossbow`, `pine_heavy_crossbow`, `starwood_heavy_crossbow`, `yew_heavy_crossbow` | `item/weapon/ranged/arbalest1.png` | stand-in |
| `assets/icons/items/helmet.png` | 32x32 | 9 items: `adamantite_helmet`, `bronze_helmet`, `copper_helmet`, `damascus_steel_helmet`, `helmet`, `mythril_helmet`, `silver_helmet`, `steel_helmet`, `wrought_iron_helmet` | `item/armour/headgear/helmet1.png` | stand-in |
| `assets/icons/items/chestplate.png` | 32x32 | 9 items: `adamantite_chestplate`, `bronze_chestplate`, `chestplate`, `copper_chestplate`, `damascus_steel_chestplate`, `mythril_chestplate`, `silver_chestplate`, `steel_chestplate`, `wrought_iron_chestplate` | `item/armour/plate1.png` | stand-in |
| `assets/icons/items/chain_mail.png` | 32x32 | 9 items: `adamantite_chain_mail`, `bronze_chain_mail`, `chain_mail`, `copper_chain_mail`, `damascus_steel_chain_mail`, `mythril_chain_mail`, `silver_chain_mail`, `steel_chain_mail`, `wrought_iron_chain_mail` | `item/armour/scale_mail1.png` | stand-in |
| `assets/icons/items/scale_mail.png` | 32x32 | 9 items: `adamantite_scale_mail`, `bronze_scale_mail`, `copper_scale_mail`, `damascus_steel_scale_mail`, `mythril_scale_mail`, `scale_mail`, `silver_scale_mail`, `steel_scale_mail`, `wrought_iron_scale_mail` | `item/armour/scale_mail2.png` | stand-in |
| `assets/icons/items/gauntlets.png` | 32x32 | 9 items: `adamantite_gauntlets`, `bronze_gauntlets`, `copper_gauntlets`, `damascus_steel_gauntlets`, `gauntlets`, `mythril_gauntlets`, `silver_gauntlets`, `steel_gauntlets`, `wrought_iron_gauntlets` | `UNUSED/armour/gauntlet1.png` | stand-in |
| `assets/icons/items/greaves.png` | 32x32 | 9 items: `adamantite_greaves`, `bronze_greaves`, `copper_greaves`, `damascus_steel_greaves`, `greaves`, `mythril_greaves`, `silver_greaves`, `steel_greaves`, `wrought_iron_greaves` | `player/legs/leg_armour01.png` | stand-in |
| `assets/icons/items/plate_boots.png` | 32x32 | 9 items: `adamantite_plate_boots`, `bronze_plate_boots`, `copper_plate_boots`, `damascus_steel_plate_boots`, `mythril_plate_boots`, `plate_boots`, `silver_plate_boots`, `steel_plate_boots`, `wrought_iron_plate_boots` | `UNUSED/armour/boots_iron2.png` | stand-in |
| `assets/icons/items/shield.png` | 32x32 | 9 items: `adamantite_shield`, `bronze_shield`, `copper_shield`, `damascus_steel_shield`, `mythril_shield`, `shield`, `silver_shield`, `steel_shield`, `wrought_iron_shield` | `UNUSED/armour/shield2.png` | stand-in |
| `assets/icons/items/leather_cap.png` | 32x32 | 10 items: `bearhide_leather_cap`, `boiled_leather_leather_cap`, `cowhide_leather_cap`, `deerskin_leather_cap`, `dragon_leather_leather_cap`, `leather_cap`, `pigskin_leather_cap`, `scaled_leather_leather_cap`, `wolfhide_leather_cap`, `wyvern_leather_leather_cap` | `UNUSED/armour/cap1.png` | stand-in |
| `assets/icons/items/jerkin.png` | 32x32 | 11 items: `bearhide_jerkin`, `boiled_leather_jerkin`, `cowhide_jerkin`, `deerskin_jerkin`, `dragon_leather_jerkin`, `jerkin`, `leather_armor`, `pigskin_jerkin`, `scaled_leather_jerkin`, `wolfhide_jerkin`, `wyvern_leather_jerkin` | `item/armour/leather_armour1.png` | stand-in |
| `assets/icons/items/gloves.png` | 32x32 | 10 items: `bearhide_gloves`, `boiled_leather_gloves`, `cowhide_gloves`, `deerskin_gloves`, `dragon_leather_gloves`, `gloves`, `pigskin_gloves`, `scaled_leather_gloves`, `wolfhide_gloves`, `wyvern_leather_gloves` | `item/armour/glove1.png` | stand-in |
| `assets/icons/items/leggings.png` | 32x32 | 10 items: `bearhide_leggings`, `boiled_leather_leggings`, `cowhide_leggings`, `deerskin_leggings`, `dragon_leather_leggings`, `leggings`, `pigskin_leggings`, `scaled_leather_leggings`, `wolfhide_leggings`, `wyvern_leather_leggings` | `player/legs/pants_brown.png` | stand-in |
| `assets/icons/items/boots.png` | 32x32 | 10 items: `bearhide_boots`, `boiled_leather_boots`, `boots`, `cowhide_boots`, `deerskin_boots`, `dragon_leather_boots`, `pigskin_boots`, `scaled_leather_boots`, `wolfhide_boots`, `wyvern_leather_boots` | `item/armour/boots1_brown.png` | stand-in |
| `assets/icons/items/hood.png` | 32x32 | 9 items: `burlap_hood`, `celestial_cloth_hood`, `cotton_hood`, `fine_linen_hood`, `hood`, `roughspun_wool_hood`, `silk_hood`, `spidersilk_hood`, `wool_hood` | `item/armour/headgear/hat1.png` | stand-in |
| `assets/icons/items/robe.png` | 32x32 | 9 items: `burlap_robe`, `celestial_cloth_robe`, `cotton_robe`, `fine_linen_robe`, `robe`, `roughspun_wool_robe`, `silk_robe`, `spidersilk_robe`, `wool_robe` | `item/armour/robe1.png` | stand-in |
| `assets/icons/items/wraps.png` | 32x32 | 9 items: `burlap_wraps`, `celestial_cloth_wraps`, `cotton_wraps`, `fine_linen_wraps`, `roughspun_wool_wraps`, `silk_wraps`, `spidersilk_wraps`, `wool_wraps`, `wraps` | `item/armour/artefact/urand_fencer.png` | stand-in |
| `assets/icons/items/pants.png` | 32x32 | 9 items: `burlap_pants`, `celestial_cloth_pants`, `cotton_pants`, `fine_linen_pants`, `pants`, `roughspun_wool_pants`, `silk_pants`, `spidersilk_pants`, `wool_pants` | `player/legs/pants_l_white.png` | stand-in |
| `assets/icons/items/slippers.png` | 32x32 | 9 items: `burlap_slippers`, `celestial_cloth_slippers`, `cotton_slippers`, `fine_linen_slippers`, `roughspun_wool_slippers`, `silk_slippers`, `slippers`, `spidersilk_slippers`, `wool_slippers` | `item/armour/boots3_stripe.png` | stand-in |
| `assets/icons/items/ring_protection.png` | 32x32 | `ring_protection` | `item/ring/artefact/urand_shadows.png` | stand-in |
| `assets/icons/items/ring_strength.png` | 32x32 | `ring_strength` | `item/ring/ruby.png` | stand-in |
| `assets/icons/items/ring_dexterity.png` | 32x32 | `ring_dexterity` | `item/ring/tourmaline.png` | stand-in |
| `assets/icons/items/ring_wisdom.png` | 32x32 | `ring_wisdom` | `item/ring/artefact/urand_octoring.png` | stand-in |
| `assets/icons/items/amulet_health.png` | 32x32 | `amulet_health` | `item/amulet/crystal_red.png` | stand-in |
| `assets/icons/items/amulet_charisma.png` | 32x32 | `amulet_charisma` | `item/amulet/cameo_blue.png` | stand-in |
| `assets/icons/items/cloak_protection.png` | 32x32 | `cloak_protection` | `item/armour/cloak3.png` | stand-in |
| `assets/icons/items/cloak_stealth.png` | 32x32 | `cloak_stealth` | `item/armour/cloak2.png` | stand-in |
| `assets/icons/items/belt.png` | 32x32 | 2 items: `belt_constitution`, `belt_strength` | `item/weapon/ranged/sling2.png` | stand-in |
| `assets/icons/items/trinket_luck.png` | 32x32 | `trinket_luck` | `item/misc/runes/rune_elven.png` | stand-in |
| `assets/icons/items/trinket_arcane.png` | 32x32 | `trinket_arcane` | `item/misc/misc_crystal.png` | stand-in |
| `assets/icons/items/holy_symbol.png` | 32x32 | `holy_symbol` | `item/amulet/celtic_yellow.png` | stand-in |
| `assets/icons/items/potion_healing_minor.png` | 32x32 | `potion_healing_minor` | `item/potion/puce.png` | stand-in |
| `assets/icons/items/potion_healing.png` | 32x32 | `potion_healing` | `item/potion/ruby.png` | stand-in |
| `assets/icons/items/potion_healing_greater.png` | 32x32 | `potion_healing_greater` | `item/potion/magenta.png` | stand-in |
| `assets/icons/items/antidote.png` | 32x32 | `antidote` | `item/potion/bubbly.png` | stand-in |
| `assets/icons/items/elixir_strength.png` | 32x32 | `elixir_strength` | `item/potion/orange.png` | stand-in |
| `assets/icons/items/elixir_agility.png` | 32x32 | `elixir_agility` | `item/potion/cyan.png` | stand-in |
| `assets/icons/items/elixir_resist_fire.png` | 32x32 | `elixir_resist_fire` | `item/potion/brilliant_blue.png` | stand-in |
| `assets/icons/items/elixir_mana.png` | 32x32 | `elixir_mana` | `item/potion/effervescent.png` | stand-in |
| `assets/icons/items/elixir_fortitude.png` | 32x32 | `elixir_fortitude` | `item/potion/yellow.png` | stand-in |
| `assets/icons/items/bread.png` | 32x32 | `bread` | `item/food/bread_ration.png` | stand-in |
| `assets/icons/items/cooked_meat.png` | 32x32 | `cooked_meat` | `item/food/chunk.png` | stand-in |
| `assets/icons/items/hearty_stew.png` | 32x32 | `hearty_stew` | `item/food/meat_ration.png` | stand-in |
| `assets/icons/items/pack.png` | 32x32 | 4 items: `burglar_pack`, `explorer_pack`, `priest_pack`, `scholar_pack` | `item/armour/artefact/urand_ratskin_cloak.png` | stand-in |
| `assets/icons/items/component_pouch.png` | 32x32 | `component_pouch` | `item/weapon/ranged/sling1.png` | stand-in |
| `assets/icons/items/spellbook.png` | 32x32 | `spellbook` | `item/book/dark_blue.png` | stand-in |
| `assets/icons/items/thieves_tools.png` | 32x32 | `thieves_tools` | `item/weapon/ranged/needle-c.png` | stand-in |
| `assets/icons/items/material_metal.png` | 32x32 | 8 items: `material_adamantite`, `material_bronze`, `material_copper`, `material_damascus_steel`, `material_mythril`, `material_silver`, `material_steel`, `material_wrought_iron` | `item/misc/misc_stone.png` | stand-in |
| `assets/icons/items/material_wood.png` | 32x32 | 9 items: `material_ash`, `material_ebony`, `material_hickory`, `material_ironwood`, `material_maple`, `material_oak`, `material_pine`, `material_starwood`, `material_yew` | `item/weapon/giant_club.png` | stand-in |
| `assets/icons/items/material_leather.png` | 32x32 | 9 items: `material_bearhide`, `material_boiled_leather`, `material_cowhide`, `material_deerskin`, `material_dragon_leather`, `material_pigskin`, `material_scaled_leather`, `material_wolfhide`, `material_wyvern_leather` | `item/armour/animal_skin1.png` | stand-in |
| `assets/icons/items/material_cloth.png` | 32x32 | 8 items: `material_burlap`, `material_celestial_cloth`, `material_cotton`, `material_fine_linen`, `material_roughspun_wool`, `material_silk`, `material_spidersilk`, `material_wool` | `item/armour/artefact/urand_starlight.png` | stand-in |
| `assets/icons/items/repair_kit.png` | 32x32 | `repair_kit` | `item/misc/misc_box.png` | stand-in |
| `assets/icons/items/scrap_metal.png` | 32x32 | 8 items: `scrap_adamantite`, `scrap_bronze`, `scrap_copper`, `scrap_damascus_steel`, `scrap_mythril`, `scrap_silver`, `scrap_steel`, `scrap_wrought_iron` | `item/misc/misc_stone_inert.png` | stand-in |
| `assets/icons/items/scrap_wood.png` | 32x32 | 9 items: `scrap_ash`, `scrap_ebony`, `scrap_hickory`, `scrap_ironwood`, `scrap_maple`, `scrap_oak`, `scrap_pine`, `scrap_starwood`, `scrap_yew` | `item/weapon/giant_club2.png` | stand-in |
| `assets/icons/items/scrap_leather.png` | 32x32 | 9 items: `scrap_bearhide`, `scrap_boiled_leather`, `scrap_cowhide`, `scrap_deerskin`, `scrap_dragon_leather`, `scrap_pigskin`, `scrap_scaled_leather`, `scrap_wolfhide`, `scrap_wyvern_leather` | `item/armour/animal_skin2.png` | stand-in |
| `assets/icons/items/scrap_cloth.png` | 32x32 | 8 items: `scrap_burlap`, `scrap_celestial_cloth`, `scrap_cotton`, `scrap_fine_linen`, `scrap_roughspun_wool`, `scrap_silk`, `scrap_spidersilk`, `scrap_wool` | `item/armour/robe2.png` | stand-in |
| `assets/icons/items/scroll.png` | 32x32 | 10 items: `scroll_bless`, `scroll_cure_wounds`, `scroll_fire_bolt`, `scroll_fireball`, `scroll_hold_person`, `scroll_ice_storm`, `scroll_lightning_bolt`, `scroll_magic_missile`, `scroll_misty_step`, `scroll_scorching_ray` | `item/scroll/scroll.png` | stand-in |
| `assets/icons/items/wand.png` | 32x32 | 10 items: `wand_bless`, `wand_cure_wounds`, `wand_fire_bolt`, `wand_fireball`, `wand_hold_person`, `wand_ice_storm`, `wand_lightning_bolt`, `wand_magic_missile`, `wand_misty_step`, `wand_scorching_ray` | `item/wand/gem_silver.png` | stand-in |

## Not on this list

Nothing in the game asks for these yet, so there is no file to draw: spell icons,
status-effect icons, attack and spell effects, portraits, UI frames and buttons, a
sprite per item lying on the floor, and equipment shown on the character. HP bars,
the path preview, the grid and the minimap are drawn by code.
