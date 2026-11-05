class_name BirdTypes
extends RefCounted
## The birds you can pick, and what Activate (Space, mid-air) does for each:
##   "none":   nothing, a pure projectile
##   "change": uses the On Activate column (new g, speed, angle, mass);
##             a "preset" fills that column in for you when you pick the bird
##   "split":  splits into pieces (settings in PhysicsParams.split)
##   "rocket": fires a rocket along its heading (settings in PhysicsParams.rocket)
##   "egg":    Matilda throws an egg straight down and recoils up (PhysicsParams.egg)
## "action": the big button's name for the ability ("Split", ...).
## "hidden": not offered in the bird picker (the egg is only ever a piece).
## "shape" and "style" are only how it's drawn (see BirdArt.draw_bird); every bird
## collides as a circle.

const TYPES := {
	"red": {
		"name": "Red", "color": Color(0.84, 0.0, 0.18), "radius": 0.3, "ability": "none",
		"style": {"brow": true, "spots": true},
		"about": "No ability: a pure projectile.",
	},
	"yellow": {
		"name": "Yellow", "color": Color(1.0, 0.82, 0.1), "radius": 0.3, "ability": "change", "action": "Boost", "shape": "triangle",
		"preset": {"v0": 30.0},
		"about": "Speed boost: same direction, but 30 m/s. (Preset; you can tweak it.)",
	},
	"blue": {
		"name": "Blue", "color": Color(0.39, 0.67, 0.79), "radius": 0.22, "ability": "split", "action": "Split",
		"style": {"cheeks": true, "eyes": 1.25},
		"about": "Splits into pieces. See the Forces & momentum tab.",
	},
	"matilda": {
		"name": "Matilda", "color": Color(0.97, 0.97, 0.95), "radius": 0.32, "ability": "egg", "action": "Drop egg", "shape": "matilda",
		"about": "Drops an egg straight down; the recoil kicks her up: Δv = (m_egg/m)·u.",
	},
	"egg": {
		"name": "Egg", "color": Color(0.98, 0.97, 0.92), "radius": 0.16, "ability": "none", "shape": "egg", "hidden": true,
		"about": "Matilda's egg.",
	},
	"rocket": {
		"name": "Rocket", "color": Color(0.95, 0.5, 0.15), "radius": 0.3, "ability": "rocket", "action": "Fire rocket",
		"style": {"brow": true, "rocket": true},
		"about": "Fires a rocket along its heading: thrust F = v_e·ṁ, Δv = v_e·ln(m₀/m₁).",
	},
	"custom": {
		"name": "Custom", "color": Color(0.62, 0.38, 0.85), "radius": 0.3, "ability": "change", "action": "Activate",
		"style": {"brow": true},
		"about": "Your own ability: tick what changes in the On Activate column.",
	},
}
