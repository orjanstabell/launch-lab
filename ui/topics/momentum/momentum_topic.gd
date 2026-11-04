class_name MomentumTopic
extends Topic
## Momentum p = m·v, and what happens to it when the blue bird splits.


func _init():
	super()
	title = "Momentum"
	add_content(MomentumLabel.new())
	add_content(ElasticityRow.new())
	add_details(MomentumLabel.new(true))
	add_overlay(MomentumOverlay.new(), "Momentum arrows + center of mass", true, "p = m·v on the bird, its pieces and the pigs; after a split, the pieces' center of mass")
	add_overlay(ImpactOverlay.new(), "Last hit", true, "The last collision: the push each body got (impulse J = Δp) and the average force J/Δt")
	add_overlay(ExhaustOverlay.new(), "Rocket exhaust", true, "Velocity arrows on some of the rocket's exhaust puffs (from the ground)")
