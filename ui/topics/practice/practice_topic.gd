class_name PracticeTopic
extends Topic
## Practice problems: pick a kind, get a random one, work it out yourself.


func _init():
	super()
	title = "Practice"
	var practice := PracticePanel.new()
	add_content(practice)
	add_details(PracticeDetailsLabel.new(practice))
	var overlay := PracticeOverlay.new()
	overlay.practice = practice
	add_overlay(overlay, "Dummies & markers", true, "The problem's dummies, your answer (flags, lines, arrows), ghost balls and the solution path")
