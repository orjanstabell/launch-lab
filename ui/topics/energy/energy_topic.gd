class_name EnergyTopic
extends Topic
## Energy: kinetic, potential and their total, which stays the same in flight.


func _init():
	super()
	title = "Energy"
	add_content(EnergyLabel.new())
	add_content(EnergyGraph.new())
	add_details(EnergyLabel.new(true))
	add_overlay(EnergyOverlay.new(), "Energy bar on the ball", true, "Kinetic and potential energy as a bar next to the ball: the total stays the same in flight")
