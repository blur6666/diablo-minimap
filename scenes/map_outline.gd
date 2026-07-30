extends Node

## Traces every room and hall floor with a map-only outline, so the layout reads
## as walls rather than as flat blobs.
##
## This sidesteps the problem that blocks recolouring the floors themselves: the
## minimap shares World2D with the main viewport, so a node drawn in both cannot
## be restyled for one of them. Room and hall MaskPoly polygons are
## BACKGROUND_MASK | MINIMAP - they also feed the background mask - so tinting
## them would bleed into the world render.
##
## An outline has no such problem, because it is a *new* node: a Line2D whose
## visibility_layer is MINIMAP alone exists only on the map, and touches nothing
## vanilla draws elsewhere.
##
## Parenting it under the MaskPoly is what keeps it honest about discovery.
## Godot propagates `visible` to children but not `visibility_layer`, so the
## outline shows exactly when its floor shows and never reveals a room the
## player has not found.

const LOG_NAME := "blur6-diablo_minimap:MapOutline"
const MapSettings := preload("map_settings.gd")

const OUTLINE_NAME := "DiabloMapOutline"
## World units. The map draws at roughly 0.01-0.03 zoom, so this lands at about
## 2-5 px of outline depending on whether the map is docked, expanded or in-room.
const OUTLINE_WIDTH := 150.0
## Brighter than the 0.5 grey the floors are set to, so the edge reads as a wall.
## The map's own modulate still applies the opacity setting on top of this.
const OUTLINE_COLOR := Color(0.82, 0.88, 1.0, 0.95)
## Drawn above the floor fill, below the icons.
const OUTLINE_Z := 1


func _ready() -> void:
	MapSettings.ensure_loaded()
	SignalBus.level_ready.connect(_rescan)
	# Secret paths and shops can put geometry on the map after the level is
	# already running, so re-sweep as rooms are found rather than only at load.
	if SignalBus.has_signal("room_entered_first_time"):
		SignalBus.room_entered_first_time.connect(_on_room_entered)
	SignalBus.map_display_changed.connect(_apply_visibility)


func _on_room_entered(_room) -> void:
	_rescan()


func _rescan() -> void:
	var root: Node = G.level_generator if is_instance_valid(G.level_generator) else null
	if root == null:
		return
	var made := 0
	for poly in _find_map_polys(root):
		if _ensure_outline(poly):
			made += 1
	if made > 0:
		ModLoaderLog.info("Outlined %d map polygons" % made, LOG_NAME)


## Every Polygon2D that the minimap actually draws. Selected by layer rather than
## by node name so a room type that names its polygon differently is still caught.
func _find_map_polys(node: Node, out: Array = []) -> Array:
	var poly := node as Polygon2D
	if poly and (poly.visibility_layer & G.VisibilityLayers.MINIMAP) != 0:
		out.append(poly)
	for child in node.get_children():
		_find_map_polys(child, out)
	return out


## Returns true when it created one, false when the outline already existed.
func _ensure_outline(poly: Polygon2D) -> bool:
	var existing := poly.get_node_or_null(OUTLINE_NAME) as Line2D
	var points := poly.polygon
	if points.size() < 3:
		return false

	if existing:
		existing.visible = MapSettings.outline
		return false

	var line := Line2D.new()
	line.name = OUTLINE_NAME
	# Closed loop: Line2D does not join its ends on its own.
	var loop := PackedVector2Array(points)
	loop.append(points[0])
	line.points = loop
	# Polygon2D.offset shifts its points; the child has to match or the outline
	# sits beside the shape it is meant to trace.
	line.position = poly.offset
	line.width = OUTLINE_WIDTH
	line.default_color = OUTLINE_COLOR
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = OUTLINE_Z
	# MINIMAP alone - this is the whole point, it must not draw in the world.
	line.visibility_layer = G.VisibilityLayers.MINIMAP
	line.visible = MapSettings.outline
	# The floors are made unshaded so world lighting cannot darken the map; the
	# outline needs the same treatment or it dims as the player moves. Utils
	# exposes this as a static function, the same call room.gd makes on the floor.
	Utils.make_unshaded(line)
	poly.add_child(line)
	return true


func _apply_visibility() -> void:
	var root: Node = G.level_generator if is_instance_valid(G.level_generator) else null
	if root == null:
		return
	for poly in _find_map_polys(root):
		var line := poly.get_node_or_null(OUTLINE_NAME) as Line2D
		if line:
			line.visible = MapSettings.outline
