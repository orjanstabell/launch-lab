class_name BirdTypes
extends RefCounted
## The projectiles you can pick, and what Activate (Space, mid-air) does for each.
## (The code calls every projectile a "bird", and the ids below are the ones
## level files have always used; what you see are the names and the marks.)
##   "none":   nothing, a pure projectile
##   "change": uses the On Activate column (new g, speed, angle, mass);
##             a "preset" fills that column in for you when you pick the bird
##   "split":  splits into pieces (settings in PhysicsParams.split)
##   "rocket": fires a rocket along its heading (settings in PhysicsParams.rocket)
##   "egg":    the Dropper throws its ballast straight down and recoils up (PhysicsParams.egg)
## "action": the big button's name for the ability ("Split", ...).
## "hidden": not offered in the picker (the ballast is only ever a piece).
## "mark" is what shows its job (see BirdArt.draw_bird); every one collides as a circle.

const TYPES := {
	"red": {
		"name": "Plain", "color": Color(0.1, 0.66, 0.6), "radius": 0.3, "ability": "none",
		"about": "No ability. Just x(t) and y(t).",
	},
	"yellow": {
		"name": "Booster", "color": Color(1.0, 0.8, 0.12), "radius": 0.3, "ability": "change", "action": "Boost", "mark": "chevrons",
		"preset": {"v0": 30.0},
		"about": "One push mid-air: 30 m/s, same direction. (Preset; tweak it.)",
	},
	"blue": {
		"name": "Splitter", "color": Color(0.93, 0.38, 0.6), "radius": 0.22, "ability": "split", "action": "Split", "mark": "seam",
		"about": "Comes apart. Its center of mass keeps the old arc.",
	},
	"matilda": {
		"name": "Dropper", "color": Color(0.96, 0.96, 0.93), "radius": 0.32, "ability": "egg", "action": "Drop", "mark": "ballast",
		"about": "Drops ballast straight down; the recoil kicks it up: Δv = (m_ballast/m)·u.",
	},
	"egg": {
		"name": "Ballast", "color": Color(0.38, 0.41, 0.48), "radius": 0.16, "ability": "none", "mark": "weight", "hidden": true,
		"about": "The Dropper's ballast.",
	},
	"rocket": {
		"name": "Rocket", "color": Color(0.95, 0.5, 0.15), "radius": 0.3, "ability": "rocket", "action": "Fire rocket", "mark": "rocket",
		"about": "Throws mass backwards to go forwards: F = v_e·ṁ, Δv = v_e·ln(m₀/m₁).",
	},
	"custom": {
		"name": "Custom", "color": Color(0.62, 0.38, 0.85), "radius": 0.3, "ability": "change", "action": "Activate", "mark": "dials",
		"about": "Your own ability: tick what changes in the On Activate column.",
	},
}
