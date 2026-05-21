# Local Engine Modding And Packaging

## Zip Mods

Drop zip mods into `content/` or `mods/` next to `LocalEngine.exe`.

Supported layouts:

```text
content/bradarPack.zip
  characters/bf.json
  images/characters/BOYFRIEND.png
  songs/tutorial/Inst.ogg
```

```text
content/bradarPack.zip
  bradarPack/
    characters/bf.json
    images/characters/BOYFRIEND.png
    songs/tutorial/Inst.ogg
```

```text
content/bradarPack.zip
  assets/shared/characters/bf.json
  assets/shared/images/characters/BOYFRIEND.png
  assets/songs/tutorial/Inst.ogg
```

```text
content/bradarPack.zip
  content/bradarPack/characters/bf.json
  content/bradarPack/songs/tutorial/Inst.ogg
```

The engine scans zip files automatically. You do not have to add them to `modsList.txt`.

Audio lookup checks `.opus`, `.ogg`, then `.mp3`. Songs inside zip can use:

```text
songs/song-name/Inst.ogg
songs/song-name/Voices.ogg
assets/songs/song-name/Inst.ogg
assets/songs/song-name/Voices.ogg
```

## Asset Zip Packs

Zip files under `assets/` are treated as asset packs. This is useful when you want to keep original assets packed:

```text
assets/base-assets.zip
  shared/images/menuDesat.png
  songs/tutorial/Inst.ogg
```

or:

```text
assets/base-assets.zip
  assets/shared/images/menuDesat.png
  assets/songs/tutorial/Inst.ogg
```

## Chart Compatibility

Supported chart loaders:

- Psych Engine legacy charts: `data/song/song.json`
- Psych Engine 1.x style charts with `chartVersion`
- Codename-style charts with `strumLines`
- Codename-style locations: `songs/song/charts/normal.json`, `songs/song/charts/hard.json`

For Codename charts, optional metadata can be placed at:

```text
songs/song/meta.json
data/song/meta.json
```

## Built-In Code Editor

Open `Editors > Code Editor` in-game. It can browse `.lua` and `.hx` scripts from loose mods and zip mods.

Zip files are read-only by design. If you save a script opened from zip, the editor writes an editable override to:

```text
content/mod-name/path/from/zip.lua
```

That lets you test changes immediately without repacking the zip.

## Startup State

You can choose the first in-game screen with `engine.json` or `startup.json` in `content/`, the game root, a loose mod folder, or the root of a zip mod:

```json
{
  "firstState": "code-editor"
}
```

Built-in values: `title`, `main-menu`, `freeplay`, `story`, `mods`, `editors`, `chart-editor`, `character-editor`, `code-editor`.

## Minimal Windows Package

Run from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File tools/package-windows.ps1 -Configuration release
```

The package is created in:

```text
dist/LocalEngine-windows
```

Native OpenFL/HaxeFlixel builds cannot be a true single `.exe` in every case because native DLL/NDLL libraries and external mod files may be required. The script copies the smallest practical runtime folder: executable, native libraries, manifests, and external `content`/`mods` folders.
