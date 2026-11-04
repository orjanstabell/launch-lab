class_name Block
extends RigidBody2D
## A wooden block. Fully simulated by Godot physics.

const DENSITY := 2.0   # kg per m² (the world is 2D, so mass comes from area)

var size_m: Vector2


func _init(size: Vector2 = Vector2.ONE):
	size_m = size


func _ready():
	var shape := RectangleShape2D.new()
	shape.size = size_m * Units.PIXELS_PER_METER
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	mass = DENSITY * size_m.x * size_m.y
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.05
	collision_layer = Layers.BLOCKS
	collision_mask = Layers.GROUND | Layers.BLOCKS | Layers.BIRD


func _draw():
	var size_px := size_m * Units.PIXELS_PER_METER
	var rect := Rect2(-size_px / 2, size_px)
	draw_rect(rect, Color(0.72, 0.5, 0.28))
	draw_rect(rect, Color(0.42, 0.27, 0.12), false, 3.0)
