class_name ForcesTopic
extends Topic
## Forces and Newton's 2nd law: the force on the bird, and the acceleration it causes.


func _init():
	super()
	title = "Forces"
	add_content(ForcesLabel.new())
	add_details(ForcesLabel.new(true))
	add_overlay(ForceOverlay.new(), "Force and acceleration arrows", true, "On the bird: gravity F = m·g, and the acceleration a = F/m (plus the rocket's thrust)")
	add_overlay(PigOverlay.new("forces"), "Pigs", true, "On each pig: gravity, and the contact force from whatever touches it.\nResting, the contact force is the normal force: m·g up, so they cancel.\nA hit's biggest push stays on screen for a moment.")
	add_overlay(ImpactOverlay.new(), "Last hit", true, "The last collision: the push each body got (impulse J = Δp) and the average force J/Δt")
	add_overlay(ExhaustOverlay.new(), "Rocket exhaust", true, "Velocity arrows on some of the rocket's exhaust puffs (from the ground)")
