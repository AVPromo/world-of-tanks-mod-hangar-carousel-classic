# Hangar Carousel Classic (World of Tanks Mod)

Classic-style hangar carousel mod for World of Tanks 2.x with native Gameface integration, custom card statistics, and advanced hierarchical sorting.

This project extends the original Hangar Carousel Plus idea from RCooLeR:
https://github.com/RCooLeR/WoT-Hangar-carousel-plus

The main difference is modern WoT 2.x compatibility plus much finer sorting control: multi-level hierarchy, optional reverse order per criterion, and explicit nation/type priority layers.

## Current Status

- Version: 1.0.0
- Mod ID: hangar.carousel.classic
- Python runtime: WoT embedded Python 2.7
- Security/quality: see [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md) and [SECURITY_AUDIT_REPORT.md](SECURITY_AUDIT_REPORT.md)

## What This Mod Does

- Restores and extends classic hangar carousel behavior.
- Adds configurable carousel row handling (1-4 rows and auto mode).
- Adds card statistics overlays (battles, win rate, damage, mastery, marks on gun).
- Integrates with native Gameface model properties and patched native bundles.
- Provides a hierarchical sorting schema that is XVM-compatible by design, but does not require XVM.
- Adds several practical filter toggles in the Hangar UI.

## Why It Is an Improved Version

Compared to the original carousel-plus approach, this project adds:

- Hierarchical sorting criteria list instead of single-mode only sorting.
- Per-criterion reverse mode using a minus prefix.
- Nation priority ordering and vehicle type priority ordering.
- Runtime and configuration migration logic (legacy format to schemaVersion 5).
- Expanded compatibility/safety patches for modern WoT client behavior.
- Build-time validation gates for Python bytecode, native bundle hooks, and required assets.

## Feature Overview

### 1) Carousel Rows

- Manual rows: 1, 2, 3, 4
- Auto mode: the mod tracks and preserves client-resolved row count behavior where applicable.

### 2) Card Statistics

Configurable card fields:

- battles
- winRate
- averageDamage
- mastery
- marksOnGun

Minimum battles threshold is configurable.

### 3) Filters

Supported filter IDs:

- bonus
- favorite
- elite
- premium
- non_elite
- not_ready
- marks_incomplete
- crew_not_maxed

### 4) Advanced Hierarchical Sorting (Main Upgrade)

Sorting is configured via an ordered list of criteria. The order in the list is the hierarchy:

- First entry = primary key
- Second entry = secondary key
- Third entry = tertiary key
- and so on

Each criterion can be ascending or descending:

- ascending: criterion name, e.g. battles
- descending: prefix with -, e.g. -battles

Supported criteria:

- nation
- type
- level / -level
- maxBattleTier / -maxBattleTier
- premium / -premium
- battles / -battles
- winRate / -winRate
- markOfMastery / -markOfMastery
- damageRating / -damageRating
- marksOnGun / -marksOnGun
- battlePassPoints / -battlePassPoints
- lastPlayed / -lastPlayed

### 5) Nation and Type Priority Layers

You can define custom priority order independent from numeric sorting:

- nations_order: ordered nation tokens, for example ussr, germany, usa, china, france, uk, japan, czech, poland, sweden, italy
- types_order: ordered type tokens, for example lightTank, mediumTank, heavyTank, AT-SPG, SPG

Unknown/unmapped entries are sorted last.

## Practical Sorting Examples

Use these examples inside sorting.sorting_criteria:

1. nation, type, level
- Classic hierarchy by nation -> type -> tier ascending

2. nation, type, -level
- Nation/type groups with highest tier first inside each type group

3. -winRate, -battles, level
- Performance-first ranking, tie-break by battles, then tier

4. premium, nation, type, -damageRating
- Premium-first layout, then grouped by nation/type, then strongest damage first

5. -lastPlayed
- Recently played tanks first

6. nation, type, -markOfMastery, -marksOnGun
- Group by nation/type, then skill/progression ordering within group

## Configuration

Default configuration is in [config/default.json](config/default.json).

Runtime/user config path used by the mod:

- %APPDATA%/Wargaming.net/WorldOfTanks/mods/mod_hangar_carousel_classic/config.json

Runtime state path:

- %APPDATA%/Wargaming.net/WorldOfTanks/mods/mod_hangar_carousel_classic/runtime.json

Legacy fallback paths are read when present, then migrated.

## Filter Synchronization Update

The client-side filter override issue has been addressed in the native carousel patch flow.

What was changed:

- HCC filtered vehicle IDs are now re-applied after native list rebuilds.
- Re-application is done against both vehicle ID and inventory ID mappings.
- This prevents native refresh passes from silently reintroducing vehicles that HCC filtering already excluded.

Scope:

- Only filtering synchronization behavior was adjusted.
- Sorting logic and sorting criteria behavior were intentionally left unchanged.

## Build and Validation

Project scripts:

- [tools/build.ps1](tools/build.ps1)
- [tools/install.ps1](tools/install.ps1)
- [tools/validate.ps1](tools/validate.ps1)
- [tools/package_wotmod.py](tools/package_wotmod.py)

Recommended workflow if you want to build and verify the mod yourself:

1. Open PowerShell and switch to the repository folder.
2. Run the build script. It compiles the Python 2.7 mod, stages the Gameface assets, patches the native bundles, and creates the final `.wotmod` file in `dist/`.

```powershell
./tools/build.ps1
```

3. Validate the package. This checks that the archive contains the required assets, that the bytecode is Python 2.7 compatible, and that the native bundle markers are present.

```powershell
./tools/validate.ps1 -PackagePath ./dist/mod_hangar_carousel_classic_1.0.0.wotmod
```

4. Install the package into your World of Tanks client. Replace `G:/Games/World_of_Tanks_EU` with your own game folder if needed.

```powershell
./tools/install.ps1 -GameRoot G:/Games/World_of_Tanks_EU -PackagePath ./dist/mod_hangar_carousel_classic_1.0.0.wotmod
```

Notes:

- If you do not trust the prebuilt `.wotmod`, run the build locally and install the package from `dist/`.
- Build enforces Python 2.7 bytecode compatibility.
- Packaging keeps entries uncompressed as required for .wotmod compatibility.
- Validation checks required assets and native patch markers.

## Installation Notes

- Requires World of Tanks client with Gameface support.
- If net.openwg.gameface is missing, injection is skipped and features fail closed.
- Existing installed versions are backed up by installer scripts before replacement.

## Repository Structure

- [res/scripts/client/gui/mods/mod_hangar_carousel_classic.py](res/scripts/client/gui/mods/mod_hangar_carousel_classic.py)
  Core Python 2.7 mod logic, integration hooks, sorting/filter/state handling.
- [res/gui/gameface/mods/hcc/hangar_carousel_classic](res/gui/gameface/mods/hcc/hangar_carousel_classic)
  JS/CSS UI integration assets.
- [config/default.json](config/default.json)
  Default user-facing configuration values.
- [meta.xml](meta.xml)
  Package metadata.
- [tools](tools)
  Build/install/validate toolchain.

## Compatibility and Safety

- Defensive error handling around game services access.
- Hot-reload cleanup for callbacks/providers/models.
- Dossier fetch rate limiting to reduce UI-blocking risk in large garages.
- Legacy config migration path to current schema.

## Credits

- Original concept and inspiration: [RCooLeR / WoT-Hangar-carousel-plus](https://github.com/RCooLeR/WoT-Hangar-carousel-plus)
- This repository: a modernized hangar carousel workflow for WoT 2.x with native Gameface integration and extended sorting control

## Disclaimer

This is a third-party mod for World of Tanks. Use at your own responsibility and always keep backups of your configuration and installed mods.
