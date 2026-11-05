class_name PracticePanel
extends VBoxContainer
## The Practice tab: pick a kind of problem (or "Random" for a surprise kind),
## get a random one, and answer it.
## While a problem is open it sets up the scene (an empty world with the pigs to
## hit), locks the parameter panel, and hides whatever would give the answer
## away. Everything goes back to how it was when the problem ends or you leave
## the tab. The worked solution only appears when you ask for it.

signal changed   # a new problem, an answer checked, or the solution shown

const HINT_COLOR := Color(1, 1, 1, 0.6)

var problem: Problem = null
var given: Array[float] = []   # the answers last checked or tried
var solution_shown := false
var attempts := 0

var _picker: OptionButton
var _question: Label
var _answer_row: HBoxContainer
var _answer_labels: Array[Label] = []
var _answer_spins: Array[SpinBox] = []
var _check_button: Button
var _solution_button: Button
var _feedback: Label
var _samples: Array[Problem] = []   # one of each kind, for their titles and topics
var _saved := {}   # what to put back when the problem ends
var _watching := {}   # a shot in the air: {"bird", "until", "judge"}
var _ghost_end := 0.0   # when the last ghost has landed (seconds into the shot)
## Seconds since the last shot was launched. The ghosts and timed markers in the
## overlay follow it, so they keep pace with the bird (and slow motion and pause).
var sim_time := 0.0


func _ready():
	add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_picker = OptionButton.new()
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.custom_minimum_size.x = 380
	_picker.fit_to_longest_item = false   # the longest titles would push the dock off screen
	_picker.clip_text = true
	_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_picker.tooltip_text = "The kind of problem. \"Random\" picks a kind for you (from any topic, or one topic)."
	# Item metadata: a String = "random kind from this topic" ("" = any topic),
	# an int = that kind (index into ProblemTypes.ALL).
	var topics := []
	for script in ProblemTypes.ALL:
		var sample: Problem = script.new()
		_samples.append(sample)
		if sample.topic not in topics:
			topics.append(sample.topic)
	_add_choice("Random: any topic", "")
	for topic in topics:
		_add_choice("Random: %s" % topic, topic)
	_picker.add_separator()
	for i in _samples.size():
		_add_choice("%s · %s" % [_samples[i].topic, _samples[i].title], i)
	row.add_child(_picker)
	_add_button(row, "New problem", new_problem, "A new random problem of this kind")
	_add_button(row, "End", end_problem, "Stop: put everything back the way it was")

	_question = Label.new()
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.custom_minimum_size = Vector2(600, 44)
	_question.add_theme_font_size_override("font_size", 16)
	add_child(_question)

	_answer_row = HBoxContainer.new()
	_answer_row.add_theme_constant_override("separation", 8)
	add_child(_answer_row)
	for i in 2:
		var label := Label.new()
		_answer_row.add_child(label)
		_answer_labels.append(label)
		var spin := SpinBox.new()
		spin.custom_minimum_size.x = 125
		var line_edit := spin.get_line_edit()
		line_edit.text_submitted.connect(func(_text): line_edit.release_focus())
		_answer_row.add_child(spin)
		_answer_spins.append(spin)
	_check_button = _add_button(_answer_row, "Check", check, "Check your answer")
	_solution_button = _add_button(_answer_row, "Show solution", show_solution, "Show the answer, the worked steps (over the sky), and the correct path")

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # two answers + "try again" can be long
	add_child(_feedback)

	visibility_changed.connect(func(): if not is_visible_in_tree(): end_problem())
	_show_idle()


func _process(_delta: float):
	if not _watching.is_empty():
		_check_shot()


func _physics_process(delta: float):
	if _watching.is_empty() or get_tree().paused:
		return
	var bird = _watching["bird"]   # (untyped: it may have been freed, e.g. flown off screen)
	if is_instance_valid(bird) and bird.state == Bird.State.FLYING:
		sim_time = bird.flight_time
	else:
		sim_time += delta   # the bird is down, but a ghost may still be flying


# --- Starting and ending ---

func _add_choice(text: String, metadata: Variant):
	_picker.add_item(text)
	_picker.set_item_metadata(_picker.item_count - 1, metadata)


## The kind of problem to make: the one picked, or a random one for "Random".
func _pick_kind() -> int:
	var choice: Variant = _picker.get_selected_metadata()
	if choice is int:
		return choice
	var matching := []
	for i in _samples.size():
		if choice == "" or _samples[i].topic == choice:
			matching.append(i)
	return matching[randi() % matching.size()]


func new_problem():
	end_problem()
	var script: GDScript = ProblemTypes.ALL[_pick_kind()]
	for try in 100:
		problem = script.new()
		problem.rng.randomize()
		if problem.generate():
			break

	_saved = Level.capture({}, 0)   # the same settings a saved level keeps
	# The launch mode first: in spring mode, setting m recomputes v₀ from the spring.
	PhysicsParams.set_launch_mode(problem.launch.get("mode", "speed"))
	for key in problem.launch:
		_apply(key, problem.launch[key])
	PhysicsParams.set_launch_mode(problem.launch.get("mode", "speed"))
	PhysicsParams.set_bird_type(problem.bird_type)
	for key in PhysicsParams.ability_on:
		PhysicsParams.set_ability_on(key, problem.ability.has(key))
	for key in problem.ability:
		PhysicsParams.set_ability_value(key, problem.ability[key])
	for key in problem.hidden_keys:
		Reveal.set_hidden(key, true)
	PhysicsParams.show_level = false
	PhysicsParams.set_inputs_locked(true, problem.demo_shot)
	PhysicsParams.request_reset()
	PhysicsParams.announce("")
	if problem.demo_shot:
		PhysicsParams.request_launch()

	attempts = 0
	given = []
	sim_time = 0.0
	solution_shown = false
	_question.text = problem.question()
	if not (_picker.get_selected_metadata() is int):   # a random kind: say which one it is
		_question.text = "[%s · %s]  %s" % [problem.topic, problem.title, _question.text]
	_answer_row.visible = true
	for i in 2:
		var shown := i < problem.answers.size()
		_answer_labels[i].visible = shown
		_answer_spins[i].visible = shown
		if shown:
			var answer: Dictionary = problem.answers[i]
			_answer_labels[i].text = answer["label"]
			_answer_spins[i].min_value = answer["min"]
			_answer_spins[i].max_value = answer["max"]
			_answer_spins[i].step = answer["step"]
			_answer_spins[i].suffix = answer["unit"]
			_answer_spins[i].value = answer["min"]
	var is_control := problem.kind == "control"
	_check_button.text = "Try it" if is_control else "Check"
	_check_button.tooltip_text = "Launch once with your answer" if is_control else "Check your answer"
	_feedback.text = "Work it out, type your answer and press %s." % _check_button.text
	changed.emit()


func end_problem():
	if problem == null:
		return
	problem = null
	_watching = {}
	Level.apply_settings(_saved)
	PhysicsParams.set_egg_back_speed(-1.0)   # practice-only, so levels don't keep it
	PhysicsParams.show_level = true
	PhysicsParams.set_inputs_locked(false)
	PhysicsParams.request_reset()
	PhysicsParams.announce("")
	_show_idle()
	changed.emit()


func _show_idle():
	_question.text = "Pick a kind of problem and press New problem."
	_answer_row.visible = false
	_feedback.text = ""


# --- Answering ---

func check():
	if problem == null or not _watching.is_empty():
		return
	given = []
	for i in problem.answers.size():
		given.append(_answer_spins[i].value)
	attempts += 1
	if problem.kind == "predict" and not problem.flies:
		_announce_prediction()
	else:
		# Fly once with the answers, then judge (control) or say how the
		# prediction did (predict).
		_launch(given, true)
		_feedback.text = "Attempt %d: flying..." % attempts
	changed.emit()


## Launch the shot for these answers: answers with a "key" set that value, and
## predict problems add fly_changes(). `judge`: give the verdict when it's done.
func _launch(answers_given: Array[float], judge: bool):
	var changes := {}
	for i in problem.answers.size():
		if problem.answers[i].has("key"):
			changes[problem.answers[i]["key"]] = answers_given[i]
	if problem.kind == "predict":
		changes.merge(problem.fly_changes(answers_given), true)
	for key in changes:
		_apply(key, changes[key])
	PhysicsParams.announce("")
	PhysicsParams.request_reset()
	PhysicsParams.request_launch()
	var bird: Bird = PhysicsParams.bird
	bird.activate_at = problem.tap_time(answers_given)
	sim_time = 0.0
	_ghost_end = 0.0
	if not given.is_empty():
		for part in problem.ghosts(given):
			_ghost_end = maxf(_ghost_end, part["start"] + ghost_duration(part))
	# Control shots are judged once they're past the pigs; predict shots when they land.
	var until := problem.watch_time(answers_given) if problem.kind == "control" else INF
	_watching = {"bird": bird, "until": until, "judge": judge}


## How long a ghost part flies (at most 12 s, so a ghost that never lands doesn't stall the check).
static func ghost_duration(part: Dictionary) -> float:
	return minf(minf(part["until"], Kinematics.time_of_flight(part["params"])), 12.0)


## Wait until the bird has passed the pigs or landed (and the ghosts have too), then judge.
func _check_shot():
	var bird = _watching["bird"]   # (untyped: it may have been freed, e.g. flown off screen)
	if is_instance_valid(bird) and bird.state == Bird.State.FLYING and bird.flight_time < _watching["until"] + 0.05:
		return
	if sim_time < _ghost_end:
		return
	var judge: bool = _watching["judge"]
	_watching = {}
	if not judge:
		return
	if problem.kind == "predict":
		_announce_prediction()
		return
	var result := problem.judge(given)
	PhysicsParams.announce(result["message"])
	_feedback.text = "%s · attempt %d%s" % [_your_answers(), attempts, "" if result["ok"] else " · try again"]


func _announce_prediction():
	var ok := problem.is_correct(given)
	var what_happened := problem.outcome(given)
	var hint := ""
	if not ok and given.size() == 1:
		hint = " · too %s" % ("high" if given[0] > problem.correct[0] else "low")
	PhysicsParams.announce("%s%s" % ["✓ Correct!" if ok else "✗ Not quite", "  ·  " + what_happened if what_happened != "" else ""])
	_feedback.text = "%s%s · attempt %d%s" % [_your_answers(), hint, attempts, "" if ok else " · try again"]


## Set one launch value: the scene's values, or the spring's, the egg's
## ("egg_mass", "egg_back"...), the rocket's ("rocket_fuel"...) or the split's ("split_speed"...).
func _apply(key: String, value: Variant):
	if key == "mode":
		return
	elif key == "egg_back":
		PhysicsParams.set_egg_back_speed(value)
	elif key in PhysicsParams.SPRING_DEFINITIONS:
		PhysicsParams.set_spring_value(key, value)
	elif key.begins_with("egg_"):
		PhysicsParams.set_egg_value(key.trim_prefix("egg_"), value)
	elif key.begins_with("rocket_"):
		PhysicsParams.set_rocket_value(key.trim_prefix("rocket_"), value)
	elif key.begins_with("split_"):
		var setting := key.trim_prefix("split_")
		PhysicsParams.set_split(setting, int(value) if setting == "pieces" else value)
	else:
		PhysicsParams.set_value(key, value)


## Only when asked: the answer, the worked steps (in the floating details panel)
## and the correct path in the world.
func show_solution():
	if problem == null:
		return
	solution_shown = true
	var parts := []
	if problem.answers.size() == 1 and problem.correct.size() > 1:
		var options := []
		for value in problem.correct:
			options.append(Problem.n(value))
		parts.append("%s = %s %s" % [problem.answers[0]["label"], " or ".join(options), problem.answers[0]["unit"]])
	else:
		for i in problem.answers.size():
			parts.append("%s = %s %s" % [problem.answers[i]["label"], Problem.n(problem.correct[i]), problem.answers[i]["unit"]])
	_feedback.text = "Answer: " + ", ".join(parts)
	PhysicsParams.request_details()
	if problem.kind == "predict" and problem.flies and _watching.is_empty():
		_launch(problem.correct, false)
	changed.emit()


func _your_answers() -> String:
	var parts := []
	for i in given.size():
		parts.append("%s = %s %s" % [problem.answers[i]["label"], Problem.n(given[i]), problem.answers[i]["unit"]])
	return "You: " + ", ".join(parts)


func _add_button(parent: Container, text: String, on_pressed: Callable, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(80, 32)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
