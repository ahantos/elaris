# Art sources and licences

Everything under `art_source/` is source material, not game assets. The empty
`.gdignore` file keeps Godot from importing it. Tiles the game actually uses are copied
into `assets/` (Phase 1), and each one stays traceable to an entry here.

## dcss-tiles — placeholder art

- **What:** Dungeon Crawl Stone Soup tiles, 32×32, 4,357 PNGs: dungeon (1,107), monsters
  (772), layered player sprites (819), items (673), GUI and spell icons (275), misc
  (231), effects (198), unused (282).
- **Source:** https://github.com/crawl/tiles — folder `releases/Nov-2015`, repository
  commit `a6ea1655db5c044829d9eea19a232fa6fcac87b0` (2020-09-05). Downloaded 2026-11-16.
- **Licence:** CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/). No
  attribution required; given here as a courtesy.
- **Why this package and not the game's own repository:** the Crawl project states that
  most, not all, of its tiles are CC0, and that older pieces have unclear ownership.
  The `crawl/tiles` repository is the project's own export of the cleared tiles. Roughly
  1,300 tiles with unclear licensing are listed in `TILES_UNDER_UNKNOWN_LICENSE.md` and
  are excluded from the release. Do not top this folder up from the game repository or
  from other mirrors without checking that list.
- **Artists:** listed in `dcss-tiles/ARTISTS.md`. The upstream description of the
  licensing effort is in `dcss-tiles/UPSTREAM_README.md`.

The tiles are stand-ins. Own art replaces them file by file through the asset manifest.
