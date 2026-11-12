class_name MotionTopic
extends Topic
## Kinematics: where the bird is and how fast it moves.
## The formulas, solve mode, plus velocity arrows, angle arcs, apex/landing
## markers and the target on the bird's path.


func _init():
	super()
	title = "Motion"
	add_content(FormulaLabel.new())
	add_content(SolvePanel.new())
	add_details(FormulaLabel.new(true))
	add_overlay(VelocityOverlay.new(), "Velocity arrows", true, "The ball's velocity v, split into vx and vy")
	add_overlay(AngleOverlay.new(), "Angles", false, "The launch angle θ and the angle of the velocity right now")
	add_overlay(MarkersOverlay.new(), "Apex & landing", true, "Where the arc tops out and where it lands")
	add_overlay(TargetOverlay.new(), "Target", true, "The target for Solve mode (right-click in the world to move it)")
	add_overlay(PigOverlay.new("velocity"), "Dummies", true, "Each dummy's velocity, while it moves")
	add_overlay(ExhaustOverlay.new(), "Rocket exhaust", true, "Velocity arrows on some of the rocket's exhaust puffs (from the ground)", "rocket")
