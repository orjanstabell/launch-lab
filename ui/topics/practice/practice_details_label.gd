class_name PracticeDetailsLabel
extends LiveLabel
## The floating details panel for Practice: the question in full, and the worked
## solution once it's asked for.

const WRAP_AT := 70   # characters per line

var practice: PracticePanel


func _init(panel: PracticePanel):
	super(true)
	practice = panel
	# A new problem can be much shorter than the last: let the panel shrink again.
	practice.changed.connect(func(): custom_minimum_size = Vector2.ZERO)


func _build_lines() -> Array:
	var problem := practice.problem
	if problem == null:
		return ["PRACTICE", "Pick a kind of problem in the dock and press New problem."]
	var lines := ["%s: %s" % [problem.topic.to_upper(), problem.title], ""]
	for paragraph in problem.question().split("\n"):
		lines.append_array(_wrap(paragraph))
	lines.append("")
	if practice.solution_shown:
		lines.append("SOLUTION")
		for step in problem.solution_steps():
			lines.append_array(_wrap(step))
	else:
		lines.append("(Press Show solution in the dock for the worked steps.)")
	return lines


## Break a long line at spaces so the panel doesn't get too wide.
func _wrap(text: String) -> Array:
	var lines := []
	var line := ""
	for word in text.split(" "):
		if line.length() + word.length() + 1 > WRAP_AT and line != "":
			lines.append(line)
			line = "    " + word
		else:
			line = word if line == "" else line + " " + word
	lines.append(line)
	return lines
