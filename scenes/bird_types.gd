class_name BirdTypes
extends RefCounted
## The projectiles you can pick, and what Activate (Space, mid-air) does for each.
## (The code calls every projectile a "bird", and the ids below are the ones
## level files have always used; what you see are the names and BirdArt's pictures.)
##   "none":   nothing, a pure projectile
##   "change": uses the On Activate column (new g, speed, angle, mass);
##             a "preset" fills that column in for you when you pick the bird
##   "split":  splits into pieces (settings in PhysicsParams.split)
##   "rocket": fires a rocket along its heading (settings in PhysicsParams.rocket)
##   "egg":    the Recoil cannon fires its cannonball straight down and is kicked up (PhysicsParams.egg)
## "action": the big button's name for the ability ("Split", ...).
## "hidden": not offered in the picker (the ballast is only ever a piece).
## "color": its trail and the big button. Every one collides as a circle.

const TYPES := {
	"red": {
		"name": "Plain", "color": Color(0.84, 0.16, 0.18), "radius": 0.3, "ability": "none",
		"about": "No ability. Just x(t) and y(t).",
	},
	"yellow": {
		"name": "Booster", "color": Color(1.0, 0.74, 0.12), "radius": 0.3, "ability": "change", "action": "Boost",
		"preset": {"v0": 30.0},
		"about": "One push mid-air: 30 m/s, same direction. (Preset; tweak it.)",
	},
	"blue": {
		"name": "Splitter", "color": Color(0.95, 0.35, 0.65), "radius": 0.22, "ability": "split", "action": "Split",
		"about": "A firework shell: bursts into stars. Their center of mass keeps the old arc.",
	},
	"matilda": {
		"name": "Recoil", "color": Color(0.3, 0.6, 0.32), "radius": 0.32, "ability": "egg", "action": "Fire",
		"about": "A little cannon: fires its cannonball straight down and is kicked up: Δv = (m_b/m)·u.",
	},
	"egg": {
		"name": "Cannonball", "color": Color(0.3, 0.31, 0.36), "radius": 0.16, "ability": "none", "hidden": true,
		"about": "The Recoil cannon's cannonball.",
	},
	"rocket": {
		"name": "Rocket", "color": Color(0.2, 0.55, 0.95), "radius": 0.3, "ability": "rocket", "action": "Fire rocket",
		"about": "Throws mass backwards to go forwards: F = v_e·ṁ, Δv = v_e·ln(m₀/m₁).",
	},
	"custom": {
		"name": "Custom", "color": Color(0.1, 0.66, 0.6), "radius": 0.3, "ability": "change", "action": "Activate",
		"about": "Your own ability: tick what changes in the On Activate column.",
	},
}
