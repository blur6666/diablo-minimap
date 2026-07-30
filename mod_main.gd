extends Node


const MOD_DIR := "blur6-diablo_minimap"
const LOG_NAME := "blur6-diablo_minimap:Main"

var mod_dir_path := ""
var extensions_dir_path := ""

var map_controller: Node = null


func _init() -> void:
	ModLoaderLog.info("Init", LOG_NAME)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
	install_script_extensions()


func install_script_extensions() -> void:
	extensions_dir_path = mod_dir_path.path_join("extensions")

	# signal_bus must be extended before its autoload instantiates; ModLoader
	# applies extensions from its own _init (autoload #2) and SignalBus is #3,
	# so this is safe.
	#
	# globals.gd is deliberately NOT extended — doing so makes ModLoader re-parse
	# it, which trips a preload cycle through level_config.gd and segfaults the
	# game. The three settings live on scenes/map_settings.gd instead.
	ModLoaderMod.install_script_extension(extensions_dir_path.path_join("scn/signal_bus.gd"))
	ModLoaderMod.install_script_extension(extensions_dir_path.path_join("scn/ui/options_menu.gd"))

	# options_menu.tscn is already in the resource cache by the time the extension
	# is installed, and a cached PackedScene holds a reference to the *old* script
	# object — so every instance built from it (main menu and pause menu alike)
	# silently runs vanilla options_menu.gd and the rows never appear. refresh_scene
	# reloads it with CACHE_MODE_REPLACE, rewriting the cached resource in place so
	# existing holders pick up the extended script.
	ModLoaderMod.refresh_scene("res://scn/ui/options_menu.tscn")


func _ready() -> void:
	ModLoaderLog.info("Ready", LOG_NAME)
	# The controller touches G / SignalBus, which do not exist while mods are
	# being initialized — defer past autoload setup.
	_add_map_controller.call_deferred()


func _add_map_controller() -> void:
	var MapControllerScript = load(mod_dir_path.path_join("scenes/map_controller.gd"))
	map_controller = MapControllerScript.new()
	map_controller.name = "MapController"
	add_child(map_controller)
	ModLoaderLog.info("Map controller added", LOG_NAME)
