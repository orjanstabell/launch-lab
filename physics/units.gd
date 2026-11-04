class_name Units
extends RefCounted
## Converts between physics units (meters, y up) and screen pixels (y down).
## Physics code works in meters; only drawing and Godot nodes use pixels.

const PIXELS_PER_METER := 50.0


## Works for positions and velocities alike.
static func to_px(meters: Vector2) -> Vector2:
	return Vector2(meters.x, -meters.y) * PIXELS_PER_METER


static func to_m(pixels: Vector2) -> Vector2:
	return Vector2(pixels.x, -pixels.y) / PIXELS_PER_METER
