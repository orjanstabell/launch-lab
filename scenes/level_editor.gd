class_name LevelEditor
extends Node2D
## Sandbox editing of the level data (main.level_data):
##   click: place the chosen piece   drag: move a piece   right-click: delete a piece
## A piece drops onto whatever is below the cursor (a block's top, or the
## ground), so stacks line up exactly. While editing, the level's bodies are
## frozen; they come alive when you stop editing.

signal changed   # the level data was edited: main rebuilds the level

## Piece name -> size in meters (a pig is a circle of radius 0.4).
const PIECES := {
	"box": Vector2(0.6, 0.6),
	"big box": Vector2(1.0, 1.0),
	"post": Vector2(0.3, 1.6),
	"plank": Vector2(2.8, 0.3),
	"wall": Vector2(0.4, 3.0),
	"pig": Vector2(0.8, 0.8),
	"big pig": Vector2(1.2, 1.2),
}
const SNAP_M := 0.1   # horizontal snapping
const GHOST_COLOR := Color(1, 1, 1, 0.35)
const HOVER_COLOR := Color(1.0, 0.85, 0.2)

var active := false:
	set(value):
		active = value
		_dragging = {}
		queue_redraw()
var piece := "box"
var data: Dictionary   # the level being edited (main.level_data)

var _mouse := Vector2.INF   # meters
var _dragging := {}   # {"list": "blocks"/"pigs", "index": i} while moving a piece


## Called by main with each mouse event in edit mode (and its position in meters).
func handle_input(event: InputEvent, at: Vector2):
	_mouse = at
	if event is InputEventMouseMotion:
		if not _dragging.is_empty():
			_move(_dragging, at)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _piece_at(at)
		if hit.is_empty():
			_place(at)
		else:
			_dragging = hit
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = {}
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var hit := _piece_at(at)
		if not hit.is_empty():
			data[hit["list"]].remove_at(hit["index"])
			changed.emit()
	queue_redraw()


func _place(at: Vector2):
	var size: Vector2 = PIECES[piece]
	var center := _drop(size, at, {})
	if piece.ends_with("pig"):
		Level.add_pig(data, center, piece == "big pig")
	else:
		Level.add_block(data, size, center)
	changed.emit()


func _move(item: Dictionary, at: Vector2):
	var entry: Dictionary = data[item["list"]][item["index"]]
	var size := _size_of(item)
	var center := _drop(size, at, item)
	entry["x"] = center.x
	entry["y"] = center.y
	changed.emit()


## Where a piece of `size` ends up if let go at `at`: snapped sideways, and
## resting on the highest block top below the cursor (or the ground).
func _drop(size: Vector2, at: Vector2, ignore: Dictionary) -> Vector2:
	var x := snappedf(at.x, SNAP_M)
	var support := 0.0
	for i in data["blocks"].size():
		if ignore.get("list") == "blocks" and ignore.get("index") == i:
			continue
		var block: Dictionary = data["blocks"][i]
		var top: float = block["y"] + block["h"] / 2.0
		var overlaps: bool = absf(block["x"] - x) < (block["w"] + size.x) / 2.0 - 0.01
		if overlaps and top <= at.y + size.y / 2.0:
			support = maxf(support, top)
	return Vector2(x, support + size.y / 2.0)


## The piece under `at`: {"list", "index"}, or {} if none. Pigs first (they're on top).
func _piece_at(at: Vector2) -> Dictionary:
	for i in range(data["pigs"].size() - 1, -1, -1):
		var pig: Dictionary = data["pigs"][i]
		if at.distance_to(Vector2(pig["x"], pig["y"])) < (Pig.BIG_RADIUS_M if pig.get("big", false) else Pig.RADIUS_M):
			return {"list": "pigs", "index": i}
	for i in range(data["blocks"].size() - 1, -1, -1):
		var block: Dictionary = data["blocks"][i]
		if Rect2(block["x"] - block["w"] / 2.0, block["y"] - block["h"] / 2.0, block["w"], block["h"]).has_point(at):
			return {"list": "blocks", "index": i}
	return {}


func _size_of(item: Dictionary) -> Vector2:
	if item["list"] == "pigs":
		return PIECES["big pig" if data["pigs"][item["index"]].get("big", false) else "pig"]
	var block: Dictionary = data["blocks"][item["index"]]
	return Vector2(block["w"], block["h"])


func _draw():
	if not active:
		return
	var k := DrawUtil.size_factor(self)
	# A light 1 m grid.
	for x in range(-2, 61):
		draw_line(Units.to_px(Vector2(x, 0)), Units.to_px(Vector2(x, 20)), Color(1, 1, 1, 0.07), 1.0 * k)
	for y in range(0, 21):
		draw_line(Units.to_px(Vector2(-2, y)), Units.to_px(Vector2(60, y)), Color(1, 1, 1, 0.07), 1.0 * k)
	if _mouse == Vector2.INF:
		return

	var hover := _dragging if not _dragging.is_empty() else _piece_at(_mouse)
	if not hover.is_empty():
		var entry: Dictionary = data[hover["list"]][hover["index"]]
		var size := _size_of(hover)
		_outline(Vector2(entry["x"], entry["y"]), size, hover["list"] == "pigs", HOVER_COLOR, k)
		DrawUtil.label(self, Units.to_px(Vector2(entry["x"], entry["y"] + size.y / 2.0)), Vector2(-60, -10), "drag to move · right-click to delete", HOVER_COLOR)
	else:
		var size: Vector2 = PIECES[piece]
		_outline(_drop(size, _mouse, {}), size, piece.ends_with("pig"), GHOST_COLOR, k)


func _outline(center: Vector2, size: Vector2, is_round: bool, color: Color, k: float):
	if is_round:
		draw_arc(Units.to_px(center), size.x / 2.0 * Units.PIXELS_PER_METER, 0.0, TAU, 24, color, 3.0 * k, true)
	else:
		var top_left := Units.to_px(center + Vector2(-size.x, size.y) / 2.0)
		draw_rect(Rect2(top_left, size * Units.PIXELS_PER_METER), color, false, 3.0 * k)
