# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo is **one mod**: `blur6-diablo_minimap`, for **Pathogenic**, a Godot 4 game shipped on
Steam (app id `3808690`). The repo root *is* the mod root — `manifest.json`, `mod_main.gd`,
`extensions/` and `scenes/` sit directly here, with no `mods-unpacked/` wrapper.

Everything that is *not* the mod lives in a sibling directory, `../pathogenic-files/`, which is
**not** a git repo and is never committed. That is where the game, the toolchain and the
generated references live:

```
proj/dev/
├── blur6-diablo_minimap/        <- THIS REPO (the mod itself)
└── pathogenic-files/            <- untracked support directory
    ├── Godot_v4.7-stable_mono_win64/   the engine (see Environment)
    ├── Pathogenic-release/             GDRE decompile used for testing  <- the one to use
    ├── Pathogenic-modding/             decompile of the Steam "modding" branch
    ├── Pathogenic-prerelease/          decompile of the prerelease branch
    ├── GDRE_tools-v2.6.3-windows/      the decompiler itself
    ├── scripts/                        gd_api_index.py, main.py, gen_addon_docs.py
    ├── other_mods/                     community mods read as reference
    ├── deploy_mod.ps1                  builds the zip and installs it into the game
    ├── api_index.json, addons_map.json generated / hand-pinned data
    └── blur6-diablo_minimap.zip        build output of deploy_mod.ps1
```

**Use `Pathogenic-release/`.** The three decompiles are of different Steam branches and are
otherwise near-identical — all three have the GDExtension DLLs correctly placed (see below).
What makes `Pathogenic-release/` the working one is that it alone has `mods-unpacked/` with the
junction to this repo, and it is where `Modding_API_Index.md` is generated. Testing against
either of the others would silently run vanilla, since neither has a `mods-unpacked/` at all.
The decompiles are read-only reference — do not edit their `.gd`/`.tscn` files.

`Modding_API_Index.md` is generated into `Pathogenic-release/`. `Modding_Documentation.md` is
*not* currently generated — only `main.py` produces it, and it has not been run against this
layout.

## Environment

**Godot 4.7 — not 4.7.1.** The project requires it and mixing versions produces misleading
failures. The engine lives inside the support directory, so paths are relative to this repo:

```
../pathogenic-files/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64.exe
../pathogenic-files/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe   # use this one for captured output
```

The `godot` MCP server in `.mcp.json` points `GODOT_PATH` at the first of these. Its env has
historically not taken effect (falling back to `C:\Program Files\Godot\Godot.exe` and failing),
so prefer invoking the exe directly.

`.mcp.json` is committed and must stay free of secrets: the Context7 key is referenced as
`${CONTEXT7_API_KEY}` and its real value lives in `.claude/settings.local.json`, which is
gitignored.

### GDExtension DLLs (the decompile's main trap)

GDRE recovers no native binaries. Without them, the four `.gdextension` files
(`addons/sentry/sentry.gdextension`, `addons/godotsteam/godotsteam.gdextension`,
`addons/gde_gozen/gozen.gdextension`, `addons/limboai/bin/limboai.gdextension`) fail to load,
which makes vanilla scripts that reference their classes (notably `scn/globals.gd` → `SentrySDK`)
**unparseable**, producing hundreds of misleading `SCRIPT ERROR: Parse Error` lines and a
segfault. Copying the DLLs to the *project root* — the exported-game layout — does **not**
fix an editor run; Godot resolves the `res://` paths written inside each `.gdextension`, and a
debug/editor run picks the `windows.debug.x86_64` entry. The release DLLs work in the debug
slots. **All three decompiles already have this done** — it is only a trap on a fresh GDRE
export. Required layout, relative to the decompile root:

```
addons/sentry/bin/windows/x86_64/libsentry.windows.{debug,release}.x86_64.dll
addons/limboai/bin/liblimboai.windows.{editor,template_release}.x86_64.dll
addons/godotsteam/win64/libgodotsteam.windows.template_{debug,release}.x86_64.dll
addons/godotsteam/win64/steam_api64.dll
addons/gde_gozen/bin/libgozen.windows.template_{debug,release}.x86_64.dll
```

Sources: the Steam install at `C:\Program Files (x86)\Steam\steamapps\common\Pathogenic\`
(its "modding" branch ships them loose next to the exe).

## Commands

All commands below are run **from this repo's root**, which is why every path starts `../`.

Run the project headless for a bounded number of frames and capture everything:

```bash
GODOT="../pathogenic-files/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"
"$GODOT" --headless --path ../pathogenic-files/Pathogenic-release --quit-after 300 > run.log 2>&1
sed 's/\x1b\[[0-9;]*m//g' run.log | grep -aE "SCRIPT ERROR|blur6-diablo_minimap"   # output is ANSI-coloured
```

A healthy run logs `SUCCESS ModLoader: res://mods-unpacked/blur6-diablo_minimap loaded.`, then
`Installing script extension:` for `scn/signal_bus.gd` and `scn/ui/options_menu.gd`, then the
mod's own `INFO blur6-diablo_minimap:…` lines. If none of those appear, the junction is the
first thing to check (see Testing below).

Syntax-check a single script against the project:

```bash
"$GODOT" --headless --path ../pathogenic-files/Pathogenic-release --check-only --script "res://mods-unpacked/blur6-diablo_minimap/mod_main.gd"
```

Build the zip and install it into the shipped game. The script anchors its own paths on
`$PSScriptRoot`, so the zip always lands in `../pathogenic-files/` no matter where it is invoked:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File ../pathogenic-files/deploy_mod.ps1          # build + copy into <game>/mods
powershell -NoProfile -ExecutionPolicy Bypass -File ../pathogenic-files/deploy_mod.ps1 -NoCopy  # build only
```

`deploy_mod.ps1` reads the mod straight from this repo (`..\<ModId>` relative to itself,
overridable with `-ModSrc`) and skips the working tree's local junk — `.git`, `.godot`, `.claude`,
`.vscode`, `.c7_cache`, `tmp`, and the repo-level `CLAUDE.md` / `.gitignore` / `.mcp.json`.
Without that filter the 1.3 GB `.godot/` cache would end up in the archive.

Two GDScript traps that cost real debugging time here, neither of which the compiler flags:

- **`set_anchor(side, value, keep_offset)` reads backwards.** `keep_offset = true` leaves the
  offset values alone, so moving an anchor moves the control. `false` *rewrites the offsets* to
  hold the control still. (The property setters `anchor_left = …` behave like `false`.)
- **Don't name a static method `reload()` on a script you call through a `preload`ed const.**
  `MyScript.reload()` resolves to the built-in `Script.reload()`, which reloads the script and
  resets every `static var` to its initializer, instead of calling your method.

Caveat: `--check-only` does not register autoloads, so **every** script touching `G`,
`SignalBus`, `SaveManager` or `ModLoaderLog` reports `Compile Error: Identifier not found: …`,
vanilla files included. Only `Parse Error` and analyzer errors are meaningful. Also note
GDScript does not statically reject unknown members on a typed base, so property typos on
`Control`/`Node`-typed vars surface only at runtime.

Regenerate the reference docs. These live in the support directory, not this repo — run them
with `../pathogenic-files/` as the working directory, since they write their output relative to
the cwd. Stdlib-only Python; the two LLM ones need Ollama running locally:

```bash
cd ../pathogenic-files
python scripts/gd_api_index.py --project Pathogenic-release   # → Modding_API_Index.md + api_index.json, no LLM, seconds
python scripts/main.py --project Pathogenic-release           # → Modding_Documentation.md, per-file LLM summaries, resumable via gd_progress.md
python scripts/gen_addon_docs.py --dry-run                    # inventory addons; --github to document. Always dry-run first
```

`--project` defaults to `.`, so it must be passed explicitly here. `gen_addon_docs.py` guesses
upstream GitHub repos heuristically; corrections are pinned in `addons_map.json`.

## Mod architecture

Godot **ModLoader 7.0.1** (`../pathogenic-files/Pathogenic-release/addons/mod_loader/`), wired as
autoloads #1 and #2.

- **Discovery**: `res://mods-unpacked/<namespace>-<name>/` (editor only — disabled in shipped
  builds), `<game>/mods/*.zip`, and Steam Workshop. The folder name **must** equal
  `"%s-%s" % [namespace, name]` from `manifest.json`.
- **Testing**: the mod is authored in its own repo and junctioned into the decompile, so
  `Pathogenic-release/` stays clean. The junction points at this repo's root, because the repo
  root is the mod root:
  ```powershell
  New-Item -ItemType Junction `
    -Path   '<dev_dir>\pathogenic-files\Pathogenic-release\mods-unpacked\blur6-diablo_minimap' `
    -Target '<dev_dir>\blur6-diablo_minimap'
  ```
  A dangling junction is silent: ModLoader simply finds no mod and the game runs vanilla. If a
  headless run shows no `blur6-diablo_minimap` lines at all, verify the link resolves before
  suspecting the mod code. (`mklink /J` does the same thing from `cmd`, but Git Bash mangles
  its `/J` switch, so the PowerShell form above is the one to use here.)
- **Lifecycle**: `mod_main.gd` (`extends Node`) is instantiated then `add_child`ed, so `_init()`
  runs **before the game's own autoloads exist**. Anything touching `G`/`SignalBus`/`SaveManager`
  must wait for `_ready()`, and usually one more `call_deferred()`. Install script extensions in
  `_init()`; ModLoader applies them at the end of its own `_init()` (autoload #2), i.e. before
  `SignalBus` (#3), `SaveManager` (#5) and `G` (#6) are instantiated — which is what makes
  extending those autoloads viable.
- **Script extensions** live at `<mod>/extensions/<vanilla path under res://>` and their first
  line is `extends "res://<vanilla path>"` — by path, never by `class_name`.
- **Extending a script that a cached scene uses? You must also call
  `ModLoaderMod.refresh_scene("res://path/to.tscn")`.** A `PackedScene` already in the resource
  cache holds a reference to the *old* GDScript object, so instances keep running the vanilla
  script. This fails completely silently — the mod loads, logs success, and simply does
  nothing. `refresh_scene` reloads with `CACHE_MODE_REPLACE`, rewriting the cached resource in
  place so existing holders pick it up.
- **Zip layout**: mods are mounted with `ProjectSettings.load_resource_pack`, so zip entries map
  directly onto `res://`. The archive must contain `mods-unpacked/<namespace>-<name>/…`, with
  forward-slash separators. Windows PowerShell's `Compress-Archive` writes backslashes — build
  entry names explicitly instead. Drop the zip in `<game>/mods/`.
- **Avoid extending `class_name` scripts.** ModLoader documents this as hazardous
  (`addons/mod_loader/api/mod.gd`). Drive such nodes externally through their `G` handle instead.
- **Never extend `scn/globals.gd`.** Installing an extension makes ModLoader re-parse it, which
  resolves its `preload()` of `level_config_liver.tres` / `level_config_brain.tres` →
  `level_config.gd` → which references `G`. That cycle leaves `globals.gd` half-reloaded and the
  next `G.final_boss_level()` segfaults the game. Symptom: `Could not preload resource file`
  plus `Invalid call. Nonexistent function … in base 'Node (globals.gd)'`. Keep mod settings on
  a mod-owned script and hook `SignalBus.profile_changed` (emitted by `profile_manager.gd`
  right after `G.reload_settings_from_save()`) instead of overriding that method.
- **Hooks** are the sanctioned way to intercept a `class_name` script, which script extensions
  cannot safely target. Two APIs, both used in the wild:

  ```gdscript
  # 1. add_hook — one Callable per method. No hook file. Prefer this.
  ModLoaderMod.add_hook(_force_open, "res://scn/environ/secret_path/brain_gate.gd", "_on_room_finished")

  func _force_open(chain: ModLoaderHookChain) -> void:
      var gate = chain.reference_object       # the instance, i.e. self
      chain.execute_next()                    # run vanilla, then post-process
      if not gate.solved: gate.restore_open()

  # 2. install_script_hooks — a whole `extends Object` script whose function
  #    names mirror the vanilla methods. Worth it only for many methods at once.
  ModLoaderMod.install_script_hooks("res://scn/player/player.gd", mod_dir.path_join("hooks/player.gd"))
  ```

  `ModLoaderHookChain` gives `reference_object` (the instance), `execute_next([args])`, and
  `execute_next_async([args])` for coroutines. Returning **without** calling `execute_next`
  cancels the vanilla body; calling it first and then acting wraps it.

  Costly in the editor, not at runtime: they need a generated `mod-hooks.zip` plus a restart, and
  in-editor testing requires `mod_tool`'s `hook_gen`, which **rewrites the vanilla `.gd` files in
  place** — so keep a clean copy of `Pathogenic-release/` before running it (the two unused
  decompiles next to it are not spares; they differ by branch). That editor friction is the
  only real objection; `kon-playable_enemies` ships hooks on seven vanilla scripts, so they are
  fine for release. Prefer driving a node externally through its `G` handle when that suffices
  (see `blur6-diablo_minimap`, which never touches `Minimap` directly), and reach for hooks when
  you actually need to intercept a call.
- **`config_schema` in `manifest.json`** is ModLoader's built-in settings system: a JSON-Schema
  object of `properties` with `type` / `default` / `enum` / `description`, which ModLoader turns
  into a per-mod config file without any UI work
  (`DevToolsMaster-HotkeyCheats` is a worked example). It is *not* per-profile and does not appear
  in the game's own options menu, so for a settings-heavy UI mod, injecting rows into
  `options_menu.gd` and persisting through `SaveManager` is still the better fit — that is what
  `blur6-diablo_minimap` does. Use `config_schema` for non-UI knobs.
- Also worth setting in the manifest: `compatible_game_version` (e.g. `["1.0.20"]`), which the
  community mods pin and this repo's mod currently leaves empty.
- **Translations need no files.** Register them at runtime from a plain Dictionary in `_init()`;
  no CSV, no `.translation` import step:

  ```gdscript
  for locale in TRANSLATIONS:                     # {"en": "...", "de": "...", ...}
      var t := Translation.new()
      t.locale = locale
      t.add_message(KEY, TRANSLATIONS[locale])
      TranslationServer.add_translation(t)
  ```

  Then set `button.text = KEY` — `Control` auto-translation resolves it and re-resolves when the
  player changes language. The game ships en, de, fr, es, pt_BR, it, ru, zh_CN, ko, ja, cs, fi, tr
  (see `options_menu.gd`'s `languages`); "en" covers anything unlisted.
  (`Spurrito-numeric_overcharge_labels` is a worked example.) If you skip this, `tr()` passes an
  unknown key through unchanged, so a *key* would render literally in every locale — which is why
  untranslated mods should use plain English strings rather than keys.

## Game conventions worth knowing

- **Settings flow**: `SignalBus` signal → cached var on `G` → `SaveManager` persistence.
  `G` (`scn/globals.gd`) caches each setting via `@onready var x = SaveManager.read_setting(key, default)`
  **and** re-reads it in `reload_settings_from_save()` (profile switch) — both spots must be
  mirrored when adding one.
- `SaveManager.save_setting`/`read_setting` write per-profile `save.json`, backed by untyped
  Dictionaries, so mod-invented keys work with no engine-side change.
  `save_local_setting` is the device-local ConfigFile variant, used for graphics/physics quality
  that must not sync across machines.
- `scn/signal_bus.gd`, `scn/globals.gd` and `scn/ui/options_menu.gd` have **no `class_name`**,
  so they are safe extension targets.
- `options_menu.tscn` uses hand-rolled tabs (a `PButton` strip plus a `TabContent` panel whose
  `VBoxContainer` children are shown by index). There is no reusable option-row component; rows
  are hand-built and each interactive control carries a `button_sfx.tscn` child. The scene is
  instanced **twice** (main menu and pause menu), so injection must happen per instance in
  `_ready()`, not once globally. Nodes added at runtime are not scene-unique, so `%Name` will not
  find them — keep explicit references.
- Slider idiom is a dual save: `value_changed` applies and persists live, `drag_ended` re-saves once.
