extends RefCounted

## The mod's three settings, held as static vars instead of on `G`.
##
## The plan originally put these on `G` via a script extension, mirroring how
## every vanilla setting is cached. That turns out to be unsafe in this game:
## installing an extension makes ModLoader re-parse `res://scn/globals.gd`, and
## re-parsing it resolves its `preload()` of `level_config_liver.tres` /
## `level_config_brain.tres`, whose `script_class = "LevelConfig"` pulls in
## `level_config.gd`, which itself references `G` — a cycle. `globals.gd` then
## reloads into a broken state and the first `G.final_boss_level()` call
## segfaults the game. Verified by A/B run: the mod is clean without the
## globals extension and crashes with it, on an otherwise error-free project.
##
## Persistence still goes through SaveManager under unprefixed keys, so the
## values live in the same per-profile save.json subdict as the vanilla settings.

const KEY_SIZE := "map_size_scale"
const KEY_OPACITY := "map_opacity"
const KEY_DIABLO := "diablo_map"

const DEFAULT_SIZE := 1.0
## Vanilla minimap modulate.a.
const DEFAULT_OPACITY := 0.75
const DEFAULT_DIABLO := false

static var size_scale := DEFAULT_SIZE
static var opacity := DEFAULT_OPACITY
static var diablo := DEFAULT_DIABLO

static var _loaded := false


## Reads from the save on first use. Both the options menu and the map
## controller call this before touching the values, since either can run first.
static func ensure_loaded() -> void:
	if not _loaded:
		reload_from_save()


## Re-reads every key. Called on SignalBus.profile_changed, which ProfileManager
## emits right after G.reload_settings_from_save() — the same moment the vanilla
## settings are refreshed for the newly active profile.
##
## NOT named reload(): this script is a GDScript resource, so `MapSettings.reload()`
## resolves to the built-in Script.reload(), which reloads the script and resets
## every static var here to its initializer. That silently wiped the settings back
## to defaults on every profile switch.
static func reload_from_save() -> void:
	_loaded = true
	size_scale = SaveManager.read_setting(KEY_SIZE, DEFAULT_SIZE)
	opacity = SaveManager.read_setting(KEY_OPACITY, DEFAULT_OPACITY)
	diablo = SaveManager.read_setting(KEY_DIABLO, DEFAULT_DIABLO)


static func set_size_scale(value: float) -> void:
	size_scale = value
	SaveManager.save_setting(KEY_SIZE, value)
	SignalBus.map_display_changed.emit()


static func set_opacity(value: float) -> void:
	opacity = value
	SaveManager.save_setting(KEY_OPACITY, value)
	SignalBus.map_display_changed.emit()


static func set_diablo(value: bool) -> void:
	diablo = value
	SaveManager.save_setting(KEY_DIABLO, value)
	SignalBus.map_display_changed.emit()


## Re-save without re-emitting, for the sliders' drag_ended pass.
static func resave_size_scale() -> void:
	SaveManager.save_setting(KEY_SIZE, size_scale)


static func resave_opacity() -> void:
	SaveManager.save_setting(KEY_OPACITY, opacity)
