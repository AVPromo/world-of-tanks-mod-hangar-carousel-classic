# Release Template (Hangar Carousel Classic)

Dieses Template ist fuer schnelle, konsistente Releases gedacht.

## 1) Version vorbereiten

Version an allen Stellen angleichen:

- `res/scripts/client/gui/mods/mod_hangar_carousel_classic.py` (`MOD_VERSION`)
- `meta.xml` (`<version>`)
- `tools/build.ps1` (`$version`)
- `README.md` (Version, Release-Link, Package-Link, Beispielpfade)
- `docs/TECHNICAL_DETAILS.md` (Beispiel-Packagepfade)

Schnellcheck auf alte Werte:

```powershell
rg -n "1\.0\.2|1\.0\.3s|2\.3\.1\.0" README.md meta.xml docs res config tools
```

## 2) Build + Verify

```powershell
Set-Location "e:/Dokumente (E)/VSCode Workspace Projects/mod_hangar_carousel_classic"
python -m py_compile ./res/scripts/client/gui/mods/mod_hangar_carousel_classic.py
./tools/build.ps1
```

Erwartung:

- `dist/mod_hangar_carousel_classic_<VERSION>.wotmod` existiert
- Build-Skript validiert Paket ohne Fehler

## 3) Optional lokal installieren

```powershell
./tools/install.ps1 -GameRoot "G:/Games/World_of_Tanks_EU" -PackagePath "./dist/mod_hangar_carousel_classic_<VERSION>.wotmod"
```

## 4) Git Sync

```powershell
git add README.md docs/TECHNICAL_DETAILS.md meta.xml res/scripts/client/gui/mods/mod_hangar_carousel_classic.py config/default.json res/gui/gameface/mods/hcc/hangar_carousel_classic/hangar_carousel_classic.css res/gui/gameface/mods/hcc/hangar_carousel_classic/hangar_carousel_classic.js res/gui/gameface/mods/hcc/hangar_carousel_classic/hangar_carousel_classic.tooltip.js tools/build.ps1 tools/patch-native-carousel.ps1 tools/patch-native-tooltip.ps1
git commit -m "Release <VERSION>"
git push origin master
git tag -a v<VERSION> -m "v<VERSION>"
git push origin v<VERSION>
```

## 5) GitHub Release

Wenn `gh` im PATH fehlt, den absoluten Pfad nutzen:

```powershell
& "C:/Program Files/GitHub CLI/gh.exe" auth status
& "C:/Program Files/GitHub CLI/gh.exe" release create v<VERSION> ./dist/mod_hangar_carousel_classic_<VERSION>.wotmod --title "v<VERSION>" --notes-file ./docs/RELEASE_NOTES_<VERSION>.md
```

## 6) Release Notes Vorlage

Datei: `docs/RELEASE_NOTES_<VERSION>.md`

```markdown
- Fix settings persistence for sorting criteria, nation order, and type order.
- Stabilize card stats pipeline: average damage (dossier), MoE percent (+ level), alpha fallback chain.
- Improve sorting robustness for MoE percent values and high-vehicle refresh scenarios.
- Clarify mastery labels: M1/M2/M3 and ASS for level 4.
- Keep winrate rendering neutral (no color striping).
- Harden native controls against Gameface SVG/use issues.
- Improve card text readability (outline/shadow/weight).
- Sync docs and metadata to this version.
```

## 7) Final Check

- Release URL oeffnen und Asset-Name pruefen
- README-Links pruefen (Tag + Download)
- `git status --short` sollte leer sein
