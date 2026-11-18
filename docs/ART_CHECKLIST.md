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
| Item icons | 69 | 69 | 0 | 0 |
| **Total** | **142** | **142** | **0** | **0** |

Items in the database: 283, of which 283 have an icon.

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
| `assets/icons/items/dagger.png` | 32x32 | 6 items: `adamantine_dagger`, `bronze_dagger`, `dagger`, `iron_dagger`, `mithril_dagger`, `steel_dagger` | `item/weapon/dagger.png` | stand-in |
| `assets/icons/items/shortsword.png` | 32x32 | 6 items: `adamantine_shortsword`, `bronze_shortsword`, `iron_shortsword`, `mithril_shortsword`, `shortsword`, `steel_shortsword` | `item/weapon/short_sword1.png` | stand-in |
| `assets/icons/items/longsword.png` | 32x32 | 6 items: `adamantine_longsword`, `bronze_longsword`, `iron_longsword`, `longsword`, `mithril_longsword`, `steel_longsword` | `item/weapon/long_sword1.png` | stand-in |
| `assets/icons/items/greatsword.png` | 32x32 | 6 items: `adamantine_greatsword`, `bronze_greatsword`, `greatsword`, `iron_greatsword`, `mithril_greatsword`, `steel_greatsword` | `item/weapon/greatsword1.png` | stand-in |
| `assets/icons/items/handaxe.png` | 32x32 | 6 items: `adamantine_handaxe`, `bronze_handaxe`, `handaxe`, `iron_handaxe`, `mithril_handaxe`, `steel_handaxe` | `item/weapon/hand_axe1.png` | stand-in |
| `assets/icons/items/battleaxe.png` | 32x32 | 6 items: `adamantine_battleaxe`, `battleaxe`, `bronze_battleaxe`, `iron_battleaxe`, `mithril_battleaxe`, `steel_battleaxe` | `UNUSED/weapons/battle_axe4.png` | stand-in |
| `assets/icons/items/greataxe.png` | 32x32 | 6 items: `adamantine_greataxe`, `bronze_greataxe`, `greataxe`, `iron_greataxe`, `mithril_greataxe`, `steel_greataxe` | `UNUSED/weapons/executioner_axe4.png` | stand-in |
| `assets/icons/items/mace.png` | 32x32 | 6 items: `adamantine_mace`, `bronze_mace`, `iron_mace`, `mace`, `mithril_mace`, `steel_mace` | `item/weapon/mace1.png` | stand-in |
| `assets/icons/items/warhammer.png` | 32x32 | 6 items: `adamantine_warhammer`, `bronze_warhammer`, `iron_warhammer`, `mithril_warhammer`, `steel_warhammer`, `warhammer` | `UNUSED/weapons/hammer1.png` | stand-in |
| `assets/icons/items/spear.png` | 32x32 | 6 items: `adamantine_spear`, `bronze_spear`, `iron_spear`, `mithril_spear`, `spear`, `steel_spear` | `item/weapon/spear1.png` | stand-in |
| `assets/icons/items/rapier.png` | 32x32 | 6 items: `adamantine_rapier`, `bronze_rapier`, `iron_rapier`, `mithril_rapier`, `rapier`, `steel_rapier` | `item/weapon/rapier1.png` | stand-in |
| `assets/icons/items/quarterstaff.png` | 32x32 | 6 items: `ash_quarterstaff`, `ebony_quarterstaff`, `oak_quarterstaff`, `quarterstaff`, `starwood_quarterstaff`, `yew_quarterstaff` | `item/weapon/quarterstaff.png` | stand-in |
| `assets/icons/items/club.png` | 32x32 | 6 items: `ash_club`, `club`, `ebony_club`, `oak_club`, `starwood_club`, `yew_club` | `item/weapon/club.png` | stand-in |
| `assets/icons/items/shortbow.png` | 32x32 | 6 items: `ash_shortbow`, `ebony_shortbow`, `oak_shortbow`, `shortbow`, `starwood_shortbow`, `yew_shortbow` | `item/weapon/ranged/shortbow1.png` | stand-in |
| `assets/icons/items/longbow.png` | 32x32 | 6 items: `ash_longbow`, `ebony_longbow`, `longbow`, `oak_longbow`, `starwood_longbow`, `yew_longbow` | `item/weapon/ranged/longbow1.png` | stand-in |
| `assets/icons/items/light_crossbow.png` | 32x32 | 6 items: `ash_light_crossbow`, `ebony_light_crossbow`, `light_crossbow`, `oak_light_crossbow`, `starwood_light_crossbow`, `yew_light_crossbow` | `item/weapon/ranged/hand_crossbow.png` | stand-in |
| `assets/icons/items/heavy_crossbow.png` | 32x32 | 6 items: `ash_heavy_crossbow`, `ebony_heavy_crossbow`, `heavy_crossbow`, `oak_heavy_crossbow`, `starwood_heavy_crossbow`, `yew_heavy_crossbow` | `item/weapon/ranged/arbalest1.png` | stand-in |
| `assets/icons/items/helmet.png` | 32x32 | 6 items: `adamantine_helmet`, `bronze_helmet`, `helmet`, `iron_helmet`, `mithril_helmet`, `steel_helmet` | `item/armour/headgear/helmet1.png` | stand-in |
| `assets/icons/items/chestplate.png` | 32x32 | 6 items: `adamantine_chestplate`, `bronze_chestplate`, `chestplate`, `iron_chestplate`, `mithril_chestplate`, `steel_chestplate` | `item/armour/plate1.png` | stand-in |
| `assets/icons/items/chain_mail.png` | 32x32 | 6 items: `adamantine_chain_mail`, `bronze_chain_mail`, `chain_mail`, `iron_chain_mail`, `mithril_chain_mail`, `steel_chain_mail` | `item/armour/scale_mail1.png` | stand-in |
| `assets/icons/items/scale_mail.png` | 32x32 | 6 items: `adamantine_scale_mail`, `bronze_scale_mail`, `iron_scale_mail`, `mithril_scale_mail`, `scale_mail`, `steel_scale_mail` | `item/armour/scale_mail2.png` | stand-in |
| `assets/icons/items/gauntlets.png` | 32x32 | 6 items: `adamantine_gauntlets`, `bronze_gauntlets`, `gauntlets`, `iron_gauntlets`, `mithril_gauntlets`, `steel_gauntlets` | `UNUSED/armour/gauntlet1.png` | stand-in |
| `assets/icons/items/greaves.png` | 32x32 | 6 items: `adamantine_greaves`, `bronze_greaves`, `greaves`, `iron_greaves`, `mithril_greaves`, `steel_greaves` | `player/legs/leg_armour01.png` | stand-in |
| `assets/icons/items/plate_boots.png` | 32x32 | 6 items: `adamantine_plate_boots`, `bronze_plate_boots`, `iron_plate_boots`, `mithril_plate_boots`, `plate_boots`, `steel_plate_boots` | `UNUSED/armour/boots_iron2.png` | stand-in |
| `assets/icons/items/shield.png` | 32x32 | 6 items: `adamantine_shield`, `bronze_shield`, `iron_shield`, `mithril_shield`, `shield`, `steel_shield` | `UNUSED/armour/shield2.png` | stand-in |
| `assets/icons/items/leather_cap.png` | 32x32 | 6 items: `dragon_leather_leather_cap`, `hide_leather_cap`, `leather_cap`, `leather_leather_cap`, `scaled_leather_leather_cap`, `wyvern_leather_leather_cap` | `UNUSED/armour/cap1.png` | stand-in |
| `assets/icons/items/jerkin.png` | 32x32 | 7 items: `dragon_leather_jerkin`, `hide_jerkin`, `jerkin`, `leather_armor`, `leather_jerkin`, `scaled_leather_jerkin`, `wyvern_leather_jerkin` | `item/armour/leather_armour1.png` | stand-in |
| `assets/icons/items/gloves.png` | 32x32 | 6 items: `dragon_leather_gloves`, `gloves`, `hide_gloves`, `leather_gloves`, `scaled_leather_gloves`, `wyvern_leather_gloves` | `item/armour/glove1.png` | stand-in |
| `assets/icons/items/leggings.png` | 32x32 | 6 items: `dragon_leather_leggings`, `hide_leggings`, `leather_leggings`, `leggings`, `scaled_leather_leggings`, `wyvern_leather_leggings` | `player/legs/pants_brown.png` | stand-in |
| `assets/icons/items/boots.png` | 32x32 | 6 items: `boots`, `dragon_leather_boots`, `hide_boots`, `leather_boots`, `scaled_leather_boots`, `wyvern_leather_boots` | `item/armour/boots1_brown.png` | stand-in |
| `assets/icons/items/hood.png` | 32x32 | 6 items: `celestial_cloth_hood`, `cotton_hood`, `hood`, `linen_hood`, `silk_hood`, `spidersilk_hood` | `item/armour/headgear/hat1.png` | stand-in |
| `assets/icons/items/robe.png` | 32x32 | 6 items: `celestial_cloth_robe`, `cotton_robe`, `linen_robe`, `robe`, `silk_robe`, `spidersilk_robe` | `item/armour/robe1.png` | stand-in |
| `assets/icons/items/wraps.png` | 32x32 | 6 items: `celestial_cloth_wraps`, `cotton_wraps`, `linen_wraps`, `silk_wraps`, `spidersilk_wraps`, `wraps` | `item/armour/artefact/urand_fencer.png` | stand-in |
| `assets/icons/items/pants.png` | 32x32 | 6 items: `celestial_cloth_pants`, `cotton_pants`, `linen_pants`, `pants`, `silk_pants`, `spidersilk_pants` | `player/legs/pants_l_white.png` | stand-in |
| `assets/icons/items/slippers.png` | 32x32 | 6 items: `celestial_cloth_slippers`, `cotton_slippers`, `linen_slippers`, `silk_slippers`, `slippers`, `spidersilk_slippers` | `item/armour/boots3_stripe.png` | stand-in |
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
| `assets/icons/items/material_metal.png` | 32x32 | 5 items: `material_adamantine`, `material_bronze`, `material_iron`, `material_mithril`, `material_steel` | `item/misc/misc_stone.png` | stand-in |
| `assets/icons/items/material_wood.png` | 32x32 | 5 items: `material_ash`, `material_ebony`, `material_oak`, `material_starwood`, `material_yew` | `item/weapon/giant_club.png` | stand-in |
| `assets/icons/items/material_leather.png` | 32x32 | 5 items: `material_dragon_leather`, `material_hide`, `material_leather`, `material_scaled_leather`, `material_wyvern_leather` | `item/armour/animal_skin1.png` | stand-in |
| `assets/icons/items/material_cloth.png` | 32x32 | 5 items: `material_celestial_cloth`, `material_cotton`, `material_linen`, `material_silk`, `material_spidersilk` | `item/armour/artefact/urand_starlight.png` | stand-in |
| `assets/icons/items/scroll.png` | 32x32 | 10 items: `scroll_bless`, `scroll_cure_wounds`, `scroll_fire_bolt`, `scroll_fireball`, `scroll_hold_person`, `scroll_ice_storm`, `scroll_lightning_bolt`, `scroll_magic_missile`, `scroll_misty_step`, `scroll_scorching_ray` | `item/scroll/scroll.png` | stand-in |
| `assets/icons/items/wand.png` | 32x32 | 10 items: `wand_bless`, `wand_cure_wounds`, `wand_fire_bolt`, `wand_fireball`, `wand_hold_person`, `wand_ice_storm`, `wand_lightning_bolt`, `wand_magic_missile`, `wand_misty_step`, `wand_scorching_ray` | `item/wand/gem_silver.png` | stand-in |

## Not on this list

Nothing in the game asks for these yet, so there is no file to draw: spell icons,
status-effect icons, attack and spell effects, portraits, UI frames and buttons, a
sprite per item lying on the floor, and equipment shown on the character. HP bars,
the path preview, the grid and the minimap are drawn by code.
