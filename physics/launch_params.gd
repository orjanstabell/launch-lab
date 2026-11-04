class_name LaunchParams
extends RefCounted
## A frozen copy of the numbers one launch uses.
## Units: meters, seconds, kilograms. The angle is in degrees.

var x0 := 0.0   # the slingshot is always at x = 0
var y0 := 0.0
var v0 := 15.0
var theta_deg := 45.0
var g := 9.81
var m := 1.0

# A rocket segment (rocket bird): for t < burn_time it burns fuel at burn_rate
# kg/s, pushing along thrust_dir with exhaust speed exhaust_speed. m is the mass
# at the start of the segment (bird + fuel). burn_time = 0: not a rocket.
var thrust_dir := Vector2.ZERO
var exhaust_speed := 0.0
var burn_rate := 0.0
var burn_time := 0.0


func is_rocket() -> bool:
	return burn_time > 0.0


static func from_dict(values: Dictionary) -> LaunchParams:
	var p := LaunchParams.new()
	p.y0 = values["y0"]
	p.v0 = values["v0"]
	p.theta_deg = values["theta"]
	p.g = values["g"]
	p.m = values["m"]
	return p
