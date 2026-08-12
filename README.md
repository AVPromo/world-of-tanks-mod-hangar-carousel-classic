# Hangar Carousel Classic (World of Tanks Mod)

Classic-style hangar carousel for World of Tanks 2.x with native Gameface integration, advanced sorting, and card stats overlays.

## Quick Facts

- Version: 1.0.4
- Latest release: [v1.0.4](https://github.com/ticzz/world-of-tanks-mod-hangar-carousel-classic/releases/tag/v1.0.4)
- Full release notes: [GitHub Releases](https://github.com/ticzz/world-of-tanks-mod-hangar-carousel-classic/releases)
- Mod ID: hangar.carousel.classic
- Runtime: WoT embedded Python 2.7
- Tested game version: 2.3.1.2

## Key Features

- Carousel rows: manual 1-4 and auto mode.
- Vehicle card stats: battles, win rate, average damage, alpha damage, mastery, marks on gun.
- Filters: bonus, favorite, elite, premium, non-elite, not ready, marks incomplete, crew not maxed.
- Advanced hierarchical sorting with optional reverse per criterion.
- Nation/type priority layers for deterministic grouping.

## Install

1. Install the matching `net.openwg.gameface_*.wotmod` from the [OpenWG Gameface releases](https://gitlab.com/openwg/wot.gameface/-/releases) into your client mods folder.
2. Download the latest package from [Releases](https://github.com/ticzz/world-of-tanks-mod-hangar-carousel-classic/releases).
3. Place the `.wotmod` into your client mods folder, for example:
   `G:/Games/World_of_Tanks_EU/mods/2.3.1.2/`
4. Start the game and configure via ModsSettingsAPI.

`net.openwg.gameface` is required for the carousel UI injection. ModsSettingsAPI is optional and only provides the in-game settings menu.

### Complete Package

The release asset `hangar_carousel_classic_1.0.4_full.zip` contains the carousel mod, `net.openwg.gameface`, and ModsSettingsAPI under `mods/2.3.1.2/`. Extract it directly into the World of Tanks installation folder.

## Build Locally

```powershell
./tools/build.ps1
./tools/validate.ps1 -PackagePath ./dist/mod_hangar_carousel_classic_1.0.4.wotmod
./tools/install.ps1 -GameRoot G:/Games/World_of_Tanks_EU -PackagePath ./dist/mod_hangar_carousel_classic_1.0.4.wotmod
```

## Documentation

- Detailed feature/config/build docs: [docs/TECHNICAL_DETAILS.md](docs/TECHNICAL_DETAILS.md)
- Security summary: [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)
- Security audit: [SECURITY_AUDIT_REPORT.md](SECURITY_AUDIT_REPORT.md)

## Quick Links

- Releases overview: [GitHub Releases](https://github.com/ticzz/world-of-tanks-mod-hangar-carousel-classic/releases)
- Latest package (v1.0.4): [mod_hangar_carousel_classic_1.0.4.wotmod](https://github.com/ticzz/world-of-tanks-mod-hangar-carousel-classic/releases/download/v1.0.4/mod_hangar_carousel_classic_1.0.4.wotmod)
- Full technical docs: [docs/TECHNICAL_DETAILS.md](docs/TECHNICAL_DETAILS.md)
- Main mod source: [res/scripts/client/gui/mods/mod_hangar_carousel_classic.py](res/scripts/client/gui/mods/mod_hangar_carousel_classic.py)
- Frontend assets: [res/gui/gameface/mods/hcc/hangar_carousel_classic](res/gui/gameface/mods/hcc/hangar_carousel_classic)
- Build script: [tools/build.ps1](tools/build.ps1)
- Validate script: [tools/validate.ps1](tools/validate.ps1)
- Install script: [tools/install.ps1](tools/install.ps1)
- Default config: [config/default.json](config/default.json)
- Package metadata: [meta.xml](meta.xml)

## Changelog Policy

- README contains only short release highlights.
- Full per-release details are published on [GitHub Releases](https://github.com/ticzz/world-of-tanks-mod-hangar-carousel-classic/releases).

## Credits

- Original concept: [RCooLeR / WoT-Hangar-carousel-plus](https://github.com/RCooLeR/WoT-Hangar-carousel-plus)

## Disclaimer

This is a third-party mod for World of Tanks. Use at your own responsibility and keep backups of your config and installed mods.
