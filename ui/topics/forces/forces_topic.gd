class_name ForcesTopic
extends Topic
## Forces and momentum, in one tab because they're one story: the force on the
## bird (Newton's 2nd law, a = F/m) changes its momentum p = m·v by Δp = F·Δt.
## Then what happens to momentum when the blue bird splits, the Dropper throws her
## egg, the rocket burns, and the bird hits something.


func _init():
	super()
	title = "Forces & momentum"
	add_content(ForcesLabel.new())
	add_content(MomentumLabel.new())
	add_details(ForcesLabel.new(true))
	add_details(MomentumLabel.new(true))
	add_overlay(ForceOverlay.new(), "F and a arrows", true, "On the ball: gravity F = m·g, and the acceleration a = F/m (plus the rocket's thrust)")
	add_overlay(MomentumOverlay.new(), "p arrows + center of mass", true, "p = m·v on the ball, its pieces and the cans; after a split, the pieces' center of mass")
	add_overlay(PigOverlay.new("forces"), "Cans", true, "On each can: gravity, and the contact force from whatever touches it.\nResting, the contact force is the normal force: m·g up, so they cancel.\nA hit's biggest push stays on screen for a moment. Arrow lengths grow with log(F), so a hit fits too.")
	add_overlay(ImpactOverlay.new(), "Last hit", true, "The last collision: the push each body got (impulse J = Δp) and the average force J/Δt")
	add_overlay(ExhaustOverlay.new(), "Rocket exhaust", true, "Velocity arrows on some of the rocket's exhaust puffs (from the ground)", "rocket")
