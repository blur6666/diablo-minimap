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

## Peek: while a map control is being used from the *pause* menu, the pause
## veil (CanvasLayer/Blur's lod + CanvasLayer/Darken's own colour) is faded out
## so the map behind it is sharp and undimmed and the change can actually be
## judged. Darken's `color` is faded rather than its `modulate`, because the
## black backdrop panel behind the menu text is a child of Darken and inherits
## modulate — fading colour leaves that panel, and the menu's readability,
## alone.
const PEEK_FADE_IN := 0.12
const PEEK_FADE_OUT := 0.25
## Keyboard/gamepad slider nudges emit value_changed with no drag_started /
## drag_ended pair, so those hold the peek open for a moment instead. Kept
## short: it only has to bridge the gap between successive key repeats.
const PEEK_HOLD := 0.5
## pause_menu.tscn's "enter" animation ends here; only used if the live instance
## shader parameter cannot be read back.
const PEEK_BLUR_LOD := 4.5

var map_size_slider: HSlider
var map_opacity_slider: HSlider
var diablo_map_button: CheckButton

var _peek_blur: ColorRect
var _peek_darken: ColorRect
var _peek_lod := PEEK_BLUR_LOD
var _peek_darken_alpha := 1.0
var _peek_captured := false
var _peek_active := false
var _peek_tween: Tween
var _peek_dragging := false
## Bumped whenever the peek state changes, so a pending hold timer that has been
## superseded knows to do nothing.
var _peek_hold_id := 0


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


func hide_options():
	super.hide_options()
	# Leaving the tab mid-peek (Back, or the pause menu closing) must not strand
	# the veil faded out.
	_peek_dragging = false
	_peek_end()


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
	map_size_slider.drag_started.connect(_on_map_slider_drag_started)
	map_size_slider.drag_ended.connect(_on_map_size_slider_drag_ended)

	var opacity_row := _make_slider_row(
		"MapOpacityMargin", "Map Opacity", "MapOpacitySlider",
		MAP_OPACITY_MIN, MAP_OPACITY_MAX, 0.01, MapSettings.opacity
	)
	map_opacity_slider = opacity_row.get_node("HBoxContainer/MapOpacitySlider")
	map_opacity_slider.value_changed.connect(_on_map_opacity_slider_value_changed)
	map_opacity_slider.drag_started.connect(_on_map_slider_drag_started)
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
	_peek_on_value_changed()


func _on_map_size_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		MapSettings.resave_size_scale()
	_on_map_slider_drag_ended()


func _on_map_opacity_slider_value_changed(value: float) -> void:
	MapSettings.set_opacity(value)
	_peek_on_value_changed()


func _on_map_opacity_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		MapSettings.resave_opacity()
	_on_map_slider_drag_ended()


func _on_diablo_map_toggled(toggled_on: bool) -> void:
	MapSettings.set_diablo(toggled_on)
	# Same reason as the sliders: the toggle relocates and re-tints the map, and
	# there is nothing to see through a blurred veil.
	_peek_on_value_changed()


func _on_map_slider_drag_started() -> void:
	_peek_dragging = true
	_peek_begin()


func _on_map_slider_drag_ended() -> void:
	_peek_dragging = false
	_peek_end()


## Keyboard / gamepad changes never emit the drag pair, so they open the peek
## themselves and let it close on a timer.
func _peek_on_value_changed() -> void:
	if _peek_dragging:
		return
	_peek_begin()
	_peek_end(PEEK_HOLD)


## The options menu is instanced in the main menu as well, where there is no
## pause veil (and no map) — this only resolves inside the pause menu instance.
## Resolved lazily because pause_menu.gd assigns G.pause_menu in its own _ready,
## which runs after this node's.
func _peek_bind() -> bool:
	if is_instance_valid(_peek_blur) and is_instance_valid(_peek_darken):
		return true
	var pause_menu: Node = G.pause_menu
	if not is_instance_valid(pause_menu) or not pause_menu.is_ancestor_of(self):
		return false
	_peek_blur = pause_menu.get_node_or_null("CanvasLayer/Blur") as ColorRect
	_peek_darken = pause_menu.get_node_or_null("CanvasLayer/Darken") as ColorRect
	if _peek_blur == null or _peek_darken == null:
		ModLoaderLog.warning("Pause veil nodes not found - map preview peek disabled", LOG_NAME)
		return false
	var anim := pause_menu.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim:
		anim.animation_started.connect(_on_pause_animation_started)
	return true


func _peek_begin() -> void:
	if not _peek_bind():
		return
	_peek_hold_id += 1
	if not _peek_active:
		# Capture only when the veil is at rest, so a peek started while the
		# previous one is still fading back does not record a mid-fade value.
		if not _peek_captured:
			var lod: Variant = _peek_blur.get_instance_shader_parameter("lod")
			_peek_lod = float(lod) if lod != null else PEEK_BLUR_LOD
			_peek_darken_alpha = _peek_darken.color.a
			_peek_captured = true
		_peek_active = true
	_peek_tween_veil(0.0, 0.0, PEEK_FADE_IN)


func _peek_end(hold := 0.0) -> void:
	if not _peek_active:
		return
	if hold > 0.0:
		_peek_hold_id += 1
		var id := _peek_hold_id
		# process_always so it still ticks with the tree paused, ignore_time_scale
		# so the resume slow-motion ramp does not stretch it.
		var timer := get_tree().create_timer(hold, true, false, true)
		timer.timeout.connect(func() -> void:
			if id == _peek_hold_id:
				_peek_end()
		)
		return
	_peek_active = false
	_peek_tween_veil(_peek_lod, _peek_darken_alpha, PEEK_FADE_OUT)


func _peek_tween_veil(lod: float, darken_alpha: float, duration: float) -> void:
	if not is_instance_valid(_peek_blur) or not is_instance_valid(_peek_darken):
		return
	if _peek_tween:
		_peek_tween.kill()
	var from: Variant = _peek_blur.get_instance_shader_parameter("lod")
	# Ignore the pause time scale the same way every other pause-menu tween does.
	_peek_tween = create_tween().set_parallel().set_ignore_time_scale(true)
	_peek_tween.tween_method(_set_peek_lod, float(from) if from != null else lod, lod, duration)
	_peek_tween.tween_property(_peek_darken, "color:a", darken_alpha, duration)


func _set_peek_lod(value: float) -> void:
	if is_instance_valid(_peek_blur):
		_peek_blur.set_instance_shader_parameter("lod", value)


## pause() and resume() drive the blur lod from the pause menu's own
## AnimationPlayer. Once that is playing it owns the property, so drop the peek
## rather than fight it — but Darken's `color` is not on any track, so that one
## still has to be put back by hand.
func _on_pause_animation_started(_anim_name: StringName) -> void:
	if _peek_tween:
		_peek_tween.kill()
		_peek_tween = null
	_peek_hold_id += 1
	_peek_active = false
	_peek_dragging = false
	if _peek_captured and is_instance_valid(_peek_darken):
		_peek_darken.color.a = _peek_darken_alpha
