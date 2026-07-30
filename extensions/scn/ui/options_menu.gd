extends "res://scn/ui/options_menu.gd"

## Injects the map size / map opacity / Diablo style rows into the UI tab.
##
## The rows are built in code rather than shipped as a scene so that no vanilla
## .tscn has to be overridden. They clone the CameraZoomMargin structure exactly
## (MarginContainer > HBoxContainer > Label + HSlider, plus a button_sfx child)
## so they look and sound native. Node references are kept on the instance:
## nodes added at runtime are not registered as scene-unique, so % won't find them.
##
## Labels are literal English rather than translation keys: the mod ships no
## translations, and tr() passes unknown strings through unchanged, so a key
## would just render as "label_map_size" in every locale.

const LOG_NAME := "blur6-map_options:OptionsMenu"

const MapSettings := preload("res://mods-unpacked/blur6-map_options/scenes/map_settings.gd")
const BUTTON_SFX := preload("res://scn/ui/button_sfx.tscn")
const MENU_TOOLTIP := preload("res://scn/ui/menu_tooltip.tscn")

const MAP_SIZE_MIN := 0.5
const MAP_SIZE_MAX := 2.5
const MAP_OPACITY_MIN := 0.1
const MAP_OPACITY_MAX := 1.0

var map_size_slider: HSlider
var map_opacity_slider: HSlider
var diablo_map_button: CheckButton


func _ready() -> void:
	super._ready()
	_build_map_options()


func show_options():
	super.show_options()
	if is_instance_valid(map_size_slider):
		map_size_slider.set_value_no_signal(MapSettings.size_scale)
	if is_instance_valid(map_opacity_slider):
		map_opacity_slider.set_value_no_signal(MapSettings.opacity)
	if is_instance_valid(diablo_map_button):
		diablo_map_button.set_pressed_no_signal(MapSettings.diablo)


func _build_map_options() -> void:
	var tab := get_node_or_null("TabContent/button_ui")
	if tab == null:
		ModLoaderLog.error("TabContent/button_ui not found - map options not added", LOG_NAME)
		return

	# Either this menu or the map controller can be the first thing to touch the
	# settings, so whichever gets there first triggers the read from the save.
	MapSettings.ensure_loaded()

	var size_row := _make_slider_row(
		"MapSizeMargin", "Map Size", "MapSizeSlider",
		MAP_SIZE_MIN, MAP_SIZE_MAX, 0.05, MapSettings.size_scale
	)
	map_size_slider = size_row.get_node("HBoxContainer/MapSizeSlider")
	map_size_slider.value_changed.connect(_on_map_size_slider_value_changed)
	map_size_slider.drag_ended.connect(_on_map_size_slider_drag_ended)

	var opacity_row := _make_slider_row(
		"MapOpacityMargin", "Map Opacity", "MapOpacitySlider",
		MAP_OPACITY_MIN, MAP_OPACITY_MAX, 0.01, MapSettings.opacity
	)
	map_opacity_slider = opacity_row.get_node("HBoxContainer/MapOpacitySlider")
	map_opacity_slider.value_changed.connect(_on_map_opacity_slider_value_changed)
	map_opacity_slider.drag_ended.connect(_on_map_opacity_slider_drag_ended)

	diablo_map_button = CheckButton.new()
	diablo_map_button.name = "DiabloMap"
	diablo_map_button.text = "Diablo Style Map"
	diablo_map_button.set_pressed_no_signal(MapSettings.diablo)
	diablo_map_button.toggled.connect(_on_diablo_map_toggled)
	var tooltip := MENU_TOOLTIP.instantiate()
	tooltip.text = "Moves the map to the centre of the screen as a translucent overlay, Diablo-style. Size and opacity still apply."
	# Vanilla's tooltip layout: anchors preset 6 (centre-right), all offsets 0.
	# set_anchor(..., false) instead of the property setters, which would rewrite
	# the offsets to keep the node where it currently is.
	tooltip.set_anchor(SIDE_LEFT, 1.0, false)
	tooltip.set_anchor(SIDE_RIGHT, 1.0, false)
	tooltip.set_anchor(SIDE_TOP, 0.5, false)
	tooltip.set_anchor(SIDE_BOTTOM, 0.5, false)
	tooltip.offset_left = 0.0
	tooltip.offset_right = 0.0
	tooltip.offset_top = 0.0
	tooltip.offset_bottom = 0.0
	tooltip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tooltip.grow_vertical = Control.GROW_DIRECTION_BOTH
	diablo_map_button.add_child(tooltip)
	diablo_map_button.add_child(BUTTON_SFX.instantiate())

	# Group them with the existing minimap toggle rather than dumping them at
	# the bottom of the tab.
	var after := %PlayerMinimapVisible.get_index() if %PlayerMinimapVisible.get_parent() == tab \
		else tab.get_child_count() - 1
	for row: Control in [size_row, opacity_row, diablo_map_button]:
		tab.add_child(row)
		after += 1
		tab.move_child(row, after)

	_add_hover_highlight([map_size_slider, map_opacity_slider])


func _make_slider_row(row_name: String, label_key: String, slider_name: String,
		min_value: float, max_value: float, step: float, value: float) -> MarginContainer:
	var row := MarginContainer.new()
	row.name = row_name
	row.add_theme_constant_override("margin_left", 15)
	row.add_theme_constant_override("margin_right", 15)

	var box := HBoxContainer.new()
	box.name = "HBoxContainer"
	box.add_theme_constant_override("separation", 15)
	row.add_child(box)

	var label := Label.new()
	label.name = "Label"
	label.text = label_key
	box.add_child(label)

	var slider := HSlider.new()
	slider.name = slider_name
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.set_value_no_signal(value)
	box.add_child(slider)
	slider.add_child(BUTTON_SFX.instantiate())

	return row


## Same treatment _ready() gives the vanilla sliders, so the new rows highlight
## on hover / focus like their neighbours.
func _add_hover_highlight(sliders: Array) -> void:
	var hover_style := get_theme_stylebox("hover", "Button")
	for s: Control in sliders:
		var row: Control = s.get_parent().get_parent()
		var hovered := [false]
		row.draw.connect(func():
			if hovered[0]:
				row.draw_style_box(hover_style, Rect2(Vector2.ZERO, row.size))
		)
		var show_hover := func(): hovered[0] = true; row.queue_redraw()
		var hide_hover := func(): hovered[0] = false; row.queue_redraw()
		row.mouse_entered.connect(show_hover)
		row.mouse_exited.connect(hide_hover)
		s.mouse_entered.connect(show_hover)
		s.mouse_exited.connect(hide_hover)
		s.focus_entered.connect(show_hover)
		s.focus_exited.connect(hide_hover)


# Vanilla's slider idiom is a dual save: value_changed applies and persists live,
# drag_ended re-saves once at the end of the drag.
func _on_map_size_slider_value_changed(value: float) -> void:
	MapSettings.set_size_scale(value)


func _on_map_size_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		MapSettings.resave_size_scale()


func _on_map_opacity_slider_value_changed(value: float) -> void:
	MapSettings.set_opacity(value)


func _on_map_opacity_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		MapSettings.resave_opacity()


func _on_diablo_map_toggled(toggled_on: bool) -> void:
	MapSettings.set_diablo(toggled_on)
