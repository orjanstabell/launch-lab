class_name Kinematics
extends RefCounted
## Projectile motion without air resistance. Pure functions, no nodes.
## Units: meters and seconds, with the y axis pointing UP (as in a physics book).
##
##   x(t)  = x₀ + v₀·cos(θ)·t
##   y(t)  = y₀ + v₀·sin(θ)·t − ½·g·t²
##   vx(t) = v₀·cos(θ)
##   vy(t) = v₀·sin(θ) − g·t
##
## Everything is computed straight from t (no step-by-step simulation),
## so the result is exact and never drifts.


## The launch velocity split into its x and y parts: (v₀·cos θ, v₀·sin θ).
static func initial_velocity(p: LaunchParams) -> Vector2:
	var theta := deg_to_rad(p.theta_deg)
	return Vector2(cos(theta), sin(theta)) * p.v0


static func position(p: LaunchParams, t: float) -> Vector2:
	var v := initial_velocity(p)
	var x := p.x0 + v.x * t
	var y := p.y0 + v.y * t - 0.5 * p.g * t * t
	return Vector2(x, y) + p.thrust_dir * rocket_distance(p, t)


static func velocity(p: LaunchParams, t: float) -> Vector2:
	var v := initial_velocity(p)
	return Vector2(v.x, v.y - p.g * t) + p.thrust_dir * rocket_speed(p, t)


# --- Rockets ---
# While burning, the mass drops: m(t) = m₀ − ṁ·t. The rocket equation (momentum
# of bird + exhaust is conserved) gives the extra speed along the thrust:
#   Δv(t) = v_e·ln(m₀ / m(t))
# and integrating that gives the extra distance:
#   s(t) = (v_e/ṁ)·(m(t)·ln(m(t)/m₀) + m₀ − m(t))
# After burnout the extra speed stays, so the bird is an ordinary projectile
# again. All exact, from t, like the rest of this file.

## The mass at time t (it only changes while a rocket burns).
static func mass_at(p: LaunchParams, t: float) -> float:
	if not p.is_rocket():
		return p.m
	return p.m - p.burn_rate * clampf(t, 0.0, p.burn_time)


## Speed added by the rocket so far (along thrust_dir).
static func rocket_speed(p: LaunchParams, t: float) -> float:
	if not p.is_rocket():
		return 0.0
	return p.exhaust_speed * log(p.m / mass_at(p, t))


## Distance added by the rocket so far (along thrust_dir).
static func rocket_distance(p: LaunchParams, t: float) -> float:
	if not p.is_rocket():
		return 0.0
	var burning := minf(maxf(t, 0.0), p.burn_time)
	var m := p.m - p.burn_rate * burning
	var during := p.exhaust_speed / p.burn_rate * (m * log(m / p.m) + p.m - m)
	return during + rocket_speed(p, t) * maxf(t - p.burn_time, 0.0)


## A rocket segment after burnout: an ordinary projectile from that moment.
static func after_burn(p: LaunchParams) -> LaunchParams:
	var at := position(p, p.burn_time)
	var v := velocity(p, p.burn_time)
	var next := LaunchParams.new()
	next.x0 = at.x
	next.y0 = at.y
	next.v0 = v.length()
	next.theta_deg = rad_to_deg(atan2(v.y, v.x))
	next.g = p.g
	next.m = mass_at(p, p.burn_time)
	return next


## Time until the bird is back at ground level (y = 0). INF if it never comes down.
## Solves y₀ + vy·t − ½·g·t² = 0 and takes the positive root.
static func time_of_flight(p: LaunchParams) -> float:
	if p.is_rocket():
		return _rocket_time_of_flight(p)
	var vy := initial_velocity(p).y
	if p.g > 0.0:
		return (vy + sqrt(vy * vy + 2.0 * p.g * p.y0)) / p.g
	# No gravity: a straight line. It only comes down if it's already heading down.
	if vy < 0.0:
		return maxf(0.0, -p.y0 / vy)
	if p.y0 <= 0.0 and vy == 0.0:
		return 0.0
	return INF


## Time until the highest point, where vy = 0.
static func time_to_apex(p: LaunchParams) -> float:
	if p.is_rocket():
		return _rocket_time_to_apex(p)
	var vy := initial_velocity(p).y
	if vy <= 0.0:
		return 0.0   # already moving flat or down: the start is the highest point
	if p.g <= 0.0:
		return INF   # nothing slows it down, it rises forever
	return vy / p.g


static func apex_height(p: LaunchParams) -> float:
	var t := time_to_apex(p)
	if is_inf(t):
		return INF
	return position(p, t).y


## Horizontal distance from the slingshot to where the bird lands at y = 0.
static func horizontal_range(p: LaunchParams) -> float:
	var t := time_of_flight(p)
	if is_inf(t):
		return INF
	return position(p, t).x - p.x0


# --- Solving for a target ---
# Which launch hits the point (X, Y)? Put x = X into the path and solve y = Y.
# With t = X / (v₀·cos θ) and the drop D = y₀ − Y:
#   0 = D + X·tan θ − g·X² / (2·v₀²·cos²θ)
# Lock two of v₀, θ, g and this gives the third. (The slingshot is at x = 0.)


## The launch speed that hits `target` (meters). NAN if no speed can.
static func solve_speed(theta_deg: float, g: float, y0: float, target: Vector2) -> float:
	var theta := deg_to_rad(theta_deg)
	var drop := y0 - target.y
	var lift := drop + target.x * tan(theta)   # must be > 0: aimed above the target
	if target.x <= 0.0 or cos(theta) <= 0.0 or lift <= 0.0 or g <= 0.0:
		return NAN
	return sqrt(g * target.x * target.x / (2.0 * pow(cos(theta), 2) * lift))


## The gravity that makes a launch hit `target`. NAN if no (positive) gravity can.
static func solve_gravity(v0: float, theta_deg: float, y0: float, target: Vector2) -> float:
	var theta := deg_to_rad(theta_deg)
	var lift := (y0 - target.y) + target.x * tan(theta)
	if target.x <= 0.0 or lift <= 0.0:
		return NAN
	return 2.0 * v0 * v0 * pow(cos(theta), 2) * lift / (target.x * target.x)


## The launch angles (degrees) that hit `target`: usually two, a low arc and a
## high arc, or none if the target is out of reach. Low arc first.
## With u = tan θ and a = g·X²/(2·v₀²), the equation becomes a·u² − X·u + (a − D) = 0.
static func solve_angles(v0: float, g: float, y0: float, target: Vector2) -> Array[float]:
	var result: Array[float] = []
	if target.x <= 0.0 or v0 <= 0.0 or g <= 0.0:
		return result
	var a := g * target.x * target.x / (2.0 * v0 * v0)
	var drop := y0 - target.y
	var discriminant := target.x * target.x - 4.0 * a * (a - drop)
	if discriminant < 0.0:
		return result   # out of reach at this speed
	for root_sign in [-1.0, 1.0]:   # −: the low arc, +: the high arc
		result.append(rad_to_deg(atan((target.x + root_sign * sqrt(discriminant)) / (2.0 * a))))
	return result


## When, and how close, the path passes `point`: returns Vector2(t, distance).
## Searched from launch until it lands (or 30 s): first every 0.02 s, then
## finely around the closest of those.
static func closest_approach(p: LaunchParams, point: Vector2) -> Vector2:
	var end_time := minf(time_of_flight(p), 30.0)
	var best := _closest_between(p, point, 0.0, end_time, 0.02)
	return _closest_between(p, point, maxf(best.x - 0.02, 0.0), minf(best.x + 0.02, end_time), 0.0002)


static func _closest_between(p: LaunchParams, point: Vector2, from: float, to: float, step: float) -> Vector2:
	var best := Vector2(from, position(p, from).distance_to(point))
	for i in range(1, int((to - from) / step) + 1):
		var t := from + i * step
		var distance := position(p, t).distance_to(point)
		if distance < best.y:
			best = Vector2(t, distance)
	var at_end := position(p, to).distance_to(point)
	return Vector2(to, at_end) if at_end < best.y else best


## The launch (speed, angle) whose path passes through BOTH points `a` and `b`.
## Returns Vector2(v₀, θ in degrees), or Vector2(NAN, NAN) if no launch can.
## With u = tan θ and k = g / (2·v₀²·cos²θ), the path is y = y₀ + x·u − k·x²,
## which is linear in u and k: two points give two equations, two unknowns.
static func solve_two_points(y0: float, a: Vector2, b: Vector2, g: float) -> Vector2:
	var det := a.x * b.x * (a.x - b.x)
	if is_zero_approx(det) or g <= 0.0:
		return Vector2(NAN, NAN)
	var u := (a.x * a.x * (b.y - y0) - b.x * b.x * (a.y - y0)) / det
	var k := (a.x * (b.y - y0) - b.x * (a.y - y0)) / det
	if k <= 0.0:
		return Vector2(NAN, NAN)   # would need the path to curve upwards
	return Vector2(sqrt(g * (1.0 + u * u) / (2.0 * k)), rad_to_deg(atan(u)))



## A rocket segment lands either during the burn (found by stepping through it,
## then narrowing down) or after it (the ordinary formula from burnout).
static func _rocket_time_of_flight(p: LaunchParams) -> float:
	var step := 0.002
	var previous := 0.0
	for i in range(1, int(p.burn_time / step) + 2):
		var t := minf(i * step, p.burn_time)
		if position(p, t).y <= 0.0 and t > 0.0:
			for j in 30:   # bisect between the last step above ground and this one
				var middle := (previous + t) / 2.0
				if position(p, middle).y > 0.0:
					previous = middle
				else:
					t = middle
			return t
		previous = t
	return p.burn_time + time_of_flight(after_burn(p))


## The highest point of a rocket segment: during the burn (stepped through) or
## after it (the ordinary apex from burnout), whichever is higher.
static func _rocket_time_to_apex(p: LaunchParams) -> float:
	var best_t := 0.0
	var best_y := p.y0
	for i in range(1, int(p.burn_time / 0.01) + 1):
		var y := position(p, i * 0.01).y
		if y > best_y:
			best_y = y
			best_t = i * 0.01
	var after := after_burn(p)
	var after_apex := time_to_apex(after)
	if not is_inf(after_apex) and position(after, after_apex).y > best_y:
		return p.burn_time + after_apex
	return INF if is_inf(after_apex) else best_t
