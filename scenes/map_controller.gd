extends Node

## Drives the vanilla Minimap from the outside.
##
## minimap.gd declares `class_name Minimap`, and ModLoader documents script
## extensions on class_name scripts as hazardous, so nothing is extended here:
## every property this needs (the rect, modulate, %SubViewport, %Camera2D, the
## `expanded` flag and the writable default_size / default_alpha / default_zoom
## vars that shrink() converges to) is reachable through G.minimap.
##
## Layout formula — shrink() always drives offset_left -> -default_size.x and
## offset_bottom -> default_size.y, so choosing anchors such that the resting
## state equals the wanted rect makes the vanilla tween land correctly with no
## interception. For target rect (x, y, S) in a viewport of (vw, vh):
##
##     anchor_left = anchor_right  = (x + S.x) / vw    offset_left = -S.x  offset_right  = 0
##     anchor_top  = anchor_bottom = y / vh            offset_top  = 0     offset_bottom = S.y
##
## Docked (x = vw - S.x, y = 0) reproduces the vanilla .tscn anchors exactly.

const LOG_NAME := "blur6-map_options:MapController"
const MapSettings := preload("map_settings.gd")
## Mirrors Minimap.anim_len.
const ANIM_LEN := 0.5
## Extra dimming on top of the opacity slider while the map sits over gameplay.
const DIABLO_ALPHA_MULT := 0.6
## The map never covers more than this fraction of the shorter viewport axis.
const MAX_VIEWPORT_FRACTION := 0.9
## Vanilla's in-room minimap zoom (minimap.gd hardcodes this literal).
const IN_ROOM_ZOOM := Vector2.ONE * 0.03
## Vanilla's per-frame zoom lerp weight.
const ZOOM_LERP := 0.05

var minimap: Control
var minimap_id: int = 0

var base_size := Vector2(500, 500)
var base_zoom := Vector2(0.01, 0.01)

## Scale actually used after the viewport clamp.
var effective_scale := 1.0
## Anchor pair (horizontal, vertical) for the resting rect in the current mode.
var rest_anchor := Vector2(1.0, 0.0)

var was_expanded := false
## While > 0 the vanilla shrink tween owns %Camera2D.zoom; we only track it.
var zoom_lock := 0.0
var zoom_state := Vector2(0.01, 0.01)
var anchor_tween: Tween


func _ready() -> void:
	# Runs after the minimap's own _physics_process, so our zoom write is the
	# last one of the frame and vanilla's lerp never fights it.
	process_physics_priority = 100
	# The size slider lives in the pause menu, and apply() only resizes the rect
	# — the matching zoom is driven from _physics_process. Without this the tree
	# is paused while the slider moves, the zoom never follows, and the preview
	# shows a bigger window onto the world instead of a bigger map. The minimap's
	# own _physics_process stays paused, so there is still nothing to fight.
	process_mode = Node.PROCESS_MODE_ALWAYS
	MapSettings.ensure_loaded()
	SignalBus.map_display_changed.connect(apply)
	get_tree().root.size_changed.connect(apply)
	# ProfileManager emits this right after refreshing the vanilla settings for
	# the newly active profile, so it stands in for the reload_settings_from_save
	# override the plan wanted on G.
	SignalBus.profile_changed.connect(_on_profile_changed)


func _on_profile_changed() -> void:
	MapSettings.reload_from_save()
	apply()


func _physics_process(delta: float) -> void:
	if not _bind():
		return

	var expanded: bool = minimap.expanded
	if expanded != was_expanded:
		was_expanded = expanded
		if expanded:
			# expand() is tweening the offsets to fullscreen; walk the anchors
			# back to the docked set so the tween lands on the whole viewport.
			_tween_anchors(Vector2(1.0, 0.0))
		else:
			_tween_anchors(rest_anchor)
			zoom_lock = ANIM_LEN

	if zoom_lock > 0.0:
		zoom_lock -= delta

	var camera := _cam()
	if camera == null:
		return

	# While expanded — and for the length of the shrink tween afterwards —
	# default_zoom must already hold the scaled value, because shrink() reads it
	# when it builds its tween and vanilla's own lerp targets it too. Once the
	# map is at rest it goes back to the unscaled value so a later expand()
	# gives the vanilla fullscreen zoom (default_zoom * 1.8) regardless of the
	# size slider.
	var owns_zoom := not expanded and zoom_lock <= 0.0
	minimap.default_zoom = base_zoom if owns_zoom else base_zoom * effective_scale

	if not owns_zoom:
		zoom_state = camera.zoom
		return

	# Same lerp as vanilla, but toward the magnified target: growing the rect by
	# k and the zoom by k keeps the drawn world extent identical.
	var target: Vector2 = (IN_ROOM_ZOOM if G.current_room else base_zoom) * effective_scale
	zoom_state = zoom_state.lerp(target, ZOOM_LERP)
	camera.zoom = zoom_state


## Picks up a freshly spawned Minimap (a new one is created per level load).
func _bind() -> bool:
	var current: Control = G.minimap if is_instance_valid(G.minimap) else null
	if current == null:
		minimap = null
		minimap_id = 0
		return false
	if current.get_instance_id() == minimap_id:
		return minimap.is_inside_tree()

	minimap = current
	minimap_id = current.get_instance_id()
	# The scene's root is a TextureRect carrying the 400x400 square_mask, and
	# TextureRect's default EXPAND_KEEP_SIZE turns the texture's size into a hard
	# minimum that custom_minimum_size cannot go under. Every map below 400px was
	# therefore clamped to 400: docked, the size simply stopped responding below
	# 0.8x; centred, the anchor kept tracking the requested size while the width
	# stayed pinned, so the panel slid sideways instead of shrinking. The mask is
	# drawn with STRETCH_SCALE regardless, so dropping the texture out of the
	# minimum-size calculation changes nothing about how it renders.
	var texture_rect := current as TextureRect
	if texture_rect:
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	else:
		ModLoaderLog.warning("Minimap root is not a TextureRect - sizes below 400px may clamp", LOG_NAME)
	base_size = current.default_size
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		base_size = Vector2(500, 500)
	base_zoom = current.default_zoom
	zoom_state = base_zoom
	was_expanded = current.expanded
	zoom_lock = 0.0
	ModLoaderLog.info("Bound minimap (base size %s, base zoom %s)" % [base_size, base_zoom], LOG_NAME)
	apply()
	return minimap.is_inside_tree()


func apply() -> void:
	if not is_instance_valid(minimap) or not minimap.is_inside_tree():
		return

	var vp := minimap.get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var k := maxf(MapSettings.size_scale, 0.05)
	var s := base_size * k
	# Clamp uniformly so the map never swallows the screen.
	var limit := minf(vp.x, vp.y) * MAX_VIEWPORT_FRACTION
	var longest := maxf(s.x, s.y)
	if longest > limit:
		k *= limit / longest
		s = base_size * k
	effective_scale = k

	var pos := Vector2(vp.x - s.x, 0.0)
	if MapSettings.diablo:
		pos = (vp - s) / 2.0
	var alpha := clampf(MapSettings.opacity, 0.0, 1.0)
	if MapSettings.diablo:
		alpha *= DIABLO_ALPHA_MULT

	rest_anchor = Vector2((pos.x + s.x) / vp.x, pos.y / vp.y)

	# The vars shrink() converges to, so the M-key map always returns here.
	minimap.default_size = s
	minimap.default_alpha = alpha
	# Keeps the control's minimum size in step with the requested rect. The
	# texture-derived floor that used to override this is disabled in _bind().
	minimap.custom_minimum_size = s

	if minimap.expanded:
		# expand()/shrink() own the rect right now; the values above are enough
		# for the shrink tween to land in the right place.
		return

	if anchor_tween and anchor_tween.is_running():
		anchor_tween.kill()
	_set_anchors(rest_anchor)
	minimap.offset_left = -s.x
	minimap.offset_right = 0.0
	minimap.offset_top = 0.0
	minimap.offset_bottom = s.y
	minimap.modulate.a = alpha

	# SubViewportContainer has stretch off, so the viewport must match the rect
	# or the render crops / letterboxes.
	var sub_viewport := _sub_viewport()
	if sub_viewport:
		sub_viewport.size = Vector2i(roundi(s.x), roundi(s.y))


func _tween_anchors(to: Vector2) -> void:
	if not is_instance_valid(minimap):
		return
	if anchor_tween:
		anchor_tween.kill()
	var from := Vector2(minimap.anchor_left, minimap.anchor_top)
	anchor_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	anchor_tween.tween_method(_set_anchors, from, to, ANIM_LEN)


## keep_offset = true means "leave the offset values alone", so moving an anchor
## actually moves the control. With false, Godot rewrites the offsets to hold the
## control still — which silently corrupts the expand transition: vanilla
## expand() only tweens offset_left and offset_bottom, so a compensated
## offset_top / offset_right survives and the fullscreen map lands cropped.
func _set_anchors(a: Vector2) -> void:
	if not is_instance_valid(minimap):
		return
	minimap.set_anchor(SIDE_LEFT, a.x, true)
	minimap.set_anchor(SIDE_RIGHT, a.x, true)
	minimap.set_anchor(SIDE_TOP, a.y, true)
	minimap.set_anchor(SIDE_BOTTOM, a.y, true)


func _sub_viewport() -> SubViewport:
	var n := minimap.get_node_or_null("%SubViewport")
	if n == null:
		n = minimap.get_node_or_null("SubViewportContainer/SubViewport")
	return n as SubViewport


func _cam() -> Camera2D:
	var n := minimap.get_node_or_null("%Camera2D")
	if n == null:
		n = minimap.get_node_or_null("SubViewportContainer/SubViewport/Camera2D")
	return n as Camera2D
