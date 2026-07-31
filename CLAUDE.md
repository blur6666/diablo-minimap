# CLAUDE.md

## Repo

- This repo **is** the mod root: `manifest.json`, `mod_main.gd`, `extensions/`, `scenes/` sit at top level, no `mods-unpacked/` wrapper.
- Mod `blur6-diablo_minimap`, for **Pathogenic** (Godot 4.7, Steam app `3808690`).
- Everything else lives in `../pathogenic-files/` — not a git repo, never committed:
  - `Pathogenic/` — the game decompile; has `mods-unpacked/` junctioned to this repo. Read-only reference — never edit its `.gd`/`.tscn`.
  - `Godot_v4.7-stable_mono_win64/` — engine (see Environment)
  - `deploy_mod.ps1` — build/install script, and its output zip
  - `other_mods/` — community mods, third-party reference only
- **Only `pathogenic-files/Pathogenic/` is authoritative about the game.** Anything else under `pathogenic-files/` is leftover, stale or unverified — don't read it as reference, don't cite it, don't test against it. If something there looks needed, say so instead of using it. The engine, `deploy_mod.ps1` and `other_mods/` above are the exceptions, and they are tools/reference, not game truth.

## Environment

- **Godot 4.7, not 4.7.1.** Mixing versions produces misleading failures.
- `../pathogenic-files/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64.exe` — use the `..._console.exe` sibling to capture output.
- **The `godot` MCP server may or may not be connected.** Check whether its tools are in your toolset — absent is normal, not an error. Use it when present for interactive inspection and one-off runs. Use the CLI below for anything scripted or reproducible: the log-grep recipes assume it, and it's the only path an unsupervised session has.
- Use **context7** for engine / GDScript / library API questions.
- godot MCP quirk (`@coding-solo/godot-mcp`): it *does* read `GODOT_PATH`, but validates it (`existsSync`, then `<path> --version`) and **silently** drops to a hardcoded list headed by `C:\Program Files\Godot\Godot.exe` — indistinguishable from "env ignored". Give it an **absolute** path (validation runs against the *server's* cwd and Node's `normalize()` doesn't absolutize). It memoizes at startup, so config edits do nothing until Claude Code restarts.
- `.mcp.json` is committed → keep it free of secrets and machine-specific paths. `${CONTEXT7_API_KEY}` / `${GODOT_PATH}` are defined in gitignored `.claude/settings.local.json`.

## Commands

All run from this repo's root, hence the `../`.

```bash
GODOT="../pathogenic-files/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"

# headless run, bounded frames, captured (output is ANSI-coloured)
"$GODOT" --headless --path ../pathogenic-files/Pathogenic --quit-after 300 > run.log 2>&1
sed 's/\x1b\[[0-9;]*m//g' run.log | grep -aE "SCRIPT ERROR|blur6-diablo_minimap"

# syntax-check one script against the project
"$GODOT" --headless --path ../pathogenic-files/Pathogenic --check-only --script "res://mods-unpacked/blur6-diablo_minimap/mod_main.gd"

# build zip, and copy into <game>/mods unless -NoCopy; paths anchored on $PSScriptRoot
powershell -NoProfile -ExecutionPolicy Bypass -File ../pathogenic-files/deploy_mod.ps1 [-NoCopy]
```

- Healthy run logs `SUCCESS ModLoader: res://mods-unpacked/blur6-diablo_minimap loaded.`, then `Installing script extension:` for `scn/signal_bus.gd` and `scn/ui/options_menu.gd`, then `INFO blur6-diablo_minimap:…`. None of those → check the junction before suspecting mod code.
- **`--check-only` doesn't register autoloads**, so every script touching `G`/`SignalBus`/`SaveManager`/`ModLoaderLog` reports `Compile Error: Identifier not found` — vanilla files included. Only `Parse Error` and analyzer errors are meaningful.

## GDScript traps (the compiler flags neither)

- **`set_anchor(side, value, keep_offset)` reads backwards.** `keep_offset = true` leaves offsets alone, so the control *moves*. `false` rewrites offsets to hold it still. (The `anchor_left = …` setters behave like `false`.)
- **Don't name a static method `reload()`** on a script called through a `preload`ed const. `MyScript.reload()` resolves to the built-in `Script.reload()`, which reloads the script and resets every `static var` to its initializer instead of calling your method.

## Mod architecture — ModLoader 7.0.1

At `../pathogenic-files/Pathogenic/addons/mod_loader/`, wired as autoloads #1 and #2.

- **Discovery**: `res://mods-unpacked/<namespace>-<name>/` (editor only, disabled in shipped builds), `<game>/mods/*.zip`, Steam Workshop. Folder name **must** equal `"%s-%s" % [namespace, name]` from `manifest.json`.
- **Testing junction** — the mod is authored here and junctioned into the decompile, so `Pathogenic/` stays clean. Points at this repo's root, since the repo root is the mod root:
  ```powershell
  New-Item -ItemType Junction `
    -Path   '<dev_dir>\pathogenic-files\Pathogenic-release\mods-unpacked\blur6-diablo_minimap' `
    -Target '<dev_dir>\blur6-diablo_minimap'
  ```
  A dangling junction is **silent**: ModLoader finds no mod and the game runs vanilla.
- **Lifecycle**: `mod_main.gd` (`extends Node`) is instantiated then `add_child`ed, so `_init()` runs **before the game's own autoloads exist**. Anything touching `G`/`SignalBus`/`SaveManager` must wait for `_ready()`, usually plus one `call_deferred()`. Install script extensions in `_init()` — ModLoader applies them at the end of autoload #2's `_init()`, i.e. before `SignalBus` (#3), `SaveManager` (#5) and `G` (#6) exist, which is what makes extending those autoloads viable.
- **Script extensions** live at `<mod>/extensions/<vanilla path under res://>`; first line is `extends "res://<vanilla path>"` — by path, never by `class_name`.
- **Extending a script that a cached scene uses? Also call `ModLoaderMod.refresh_scene("res://path/to.tscn")`.** A `PackedScene` already in the resource cache holds the *old* GDScript object, so instances keep running vanilla. This fails **completely silently** — mod loads, logs success, does nothing. `refresh_scene` reloads with `CACHE_MODE_REPLACE`, rewriting the cached resource in place.
- **Avoid extending `class_name` scripts** — ModLoader documents this as hazardous (`addons/mod_loader/api/mod.gd`). Drive such nodes externally through their `G` handle.
- **Never extend `scn/globals.gd`.** Re-parsing it triggers a `preload` cycle back through `G`, leaving it half-loaded and segfaulting on the next `G` call. Keep mod settings on a mod-owned script and hook `SignalBus.profile_changed` instead (emitted by `profile_manager.gd` right after `G.reload_settings_from_save()`).
- **Hooks** — the sanctioned way to intercept a `class_name` script, which extensions can't safely target:
  ```gdscript
  # preferred: one Callable per method, no hook file
  ModLoaderMod.add_hook(_force_open, "res://scn/environ/secret_path/brain_gate.gd", "_on_room_finished")

  func _force_open(chain: ModLoaderHookChain) -> void:
      var gate = chain.reference_object   # the instance, i.e. self
      chain.execute_next()                # run vanilla, then post-process
      if not gate.solved: gate.restore_open()

  # many methods at once: an `extends Object` script whose func names mirror the vanilla ones
  ModLoaderMod.install_script_hooks("res://scn/player/player.gd", mod_dir.path_join("hooks/player.gd"))
  ```
  `ModLoaderHookChain` gives `reference_object`, `execute_next([args])` and `execute_next_async([args])` for coroutines. Returning **without** calling `execute_next` cancels the vanilla body; calling it first and then acting wraps it.
  Costly in the editor, free at runtime: they need a generated `mod-hooks.zip` plus a restart, and in-editor testing needs `mod_tool`'s `hook_gen`, which **rewrites the vanilla `.gd` files in place** — keep a clean copy of `Pathogenic/` first. Prefer driving a node through its `G` handle when that suffices (this mod never touches `Minimap` directly); reach for hooks when you actually need to intercept a call.

## Game conventions

- **Settings flow**: `SignalBus` signal → cached var on `G` → `SaveManager` persistence. `G` (`scn/globals.gd`) caches each setting in **two** places — `@onready var x = SaveManager.read_setting(key, default)` *and* `reload_settings_from_save()` (profile switch). Mirror both when adding one.
- `SaveManager.save_setting`/`read_setting` write per-profile `save.json`, backed by untyped Dictionaries, so mod-invented keys work with no engine-side change. `save_local_setting` is the device-local ConfigFile variant, for graphics/physics quality that must not sync across machines.
- `scn/signal_bus.gd`, `scn/globals.gd` and `scn/ui/options_menu.gd` have **no `class_name`** → safe extension targets.
- `options_menu.tscn` has hand-rolled tabs and no reusable row component — mirror the existing injection. It is instanced **twice** (main and pause menu), so inject per instance in `_ready()`, never once globally; runtime-added nodes aren't scene-unique, so `%Name` won't find them.
- Slider idiom is a dual save: `value_changed` applies and persists live, `drag_ended` re-saves once.