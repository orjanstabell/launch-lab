extends Node2D
## Builds the whole game from code: world, level, UI.
##
## All world objects live under `world`, a Node2D placed at the slingshot's foot.
## So inside `world`, pixel (0, 0) is the physics origin (x = 0 m, y = 0 m), and
## Units.to_px() turns meters into positions directly.
##
## Screen layout (like a city builder's bottom bar): the sky is kept free, and
## all the panels sit in a dock "under the ground", in three columns:
##   the tabs (physics first, then the activities) and the shown tab's panel |
##   the launch values and the bird |
##   the big button (whatever Space does now), time and view, collisions, hiding values.
## Formulas and explanations only float over the sky when you switch them on
## (Formulas button, or D); H shows the keys. The look is in ui/ui_theme.gd.
##
## Pausing: this node and the UI keep running while paused (so keys and buttons
## still work), but `world` is set to pause, which freezes the bird and physics.
##
## Topics (Motion, Forces, ...) each bring a panel in the dock and overlays in
## the world. Only one is shown at a time; switch with the tabs or number keys.
##
## The level (blocks and cans) is built from level_data, a plain Dictionary (see
## Level). The Levels tab loads, saves and edits it; editing goes through `editor`.
## The game opens on an empty range.
##
## Lecture cues (LevelPresets.cues()) are levels that ask one question. PageDown
## (a presenter clicker's key) walks through them: load the cue with the future
## hidden, fly it, show its reveal line, next cue. PageUp asks the same cue again.

const ORIGIN_PX := Vector2(160, 690)   # where x = 0 m, y = 0 m appears on screen (at zoom 1 / Fit)
const SCREEN_SIZE := Vector2(1920, 1080)
const SCREEN_CENTER := SCREEN_SIZE / 2
const DOCK_HEIGHT := 340.0   # the panel strip at the bottom, under the ground
const ZOOMED_FOCUS_ON_SCREEN := Vector2(900, 380)   # where the bird sits when zoomed in
const SKY_MARGIN := 40.0   # Fit keeps this much space around the arc
const MIN_FIT_ZOOM := 0.3
const LEVEL_RIGHT_M := 28.0   # Fit always keeps the level in view
const CAMERA_EASE := 6.0   # how quickly the camera eases to its target (higher = faster)
const GRAB_RADIUS_PX := 70.0   # how close (on screen) to the waiting bird a click must be to grab it
const FIT_ZOOM_IN_MARGIN := 1.15   # Fit only zooms back in once there's this much more room (no jitter)
const ACTION_ZOOM := 3.0
const ACTION_SLOW := 0.12   # time scale during the action cam
const ACTION_AFTER_HIT_MS := 1500   # real milliseconds to keep watching after the hit
const ACTION_MAX_MS := 6000
const MAX_DRAG_M := 2.0   # the furthest you can pull the bird back
const CUE_KEY_GAP_MS := 250   # a second cue key this soon is a clicker's double press: ignored
const CUE_REVEAL_AFTER_ABILITY := 1.5   # seconds a cue's scripted ability is watched before the reveal

enum CueStage { ASKED, FLOWN, REVEALED }

var world: Node2D
var level: Node2D   # blocks and pig, rebuilt on reset
var slingshot: Slingshot
var trails: Node2D   # this shot's trail(s): one per bird, more after a blue bird split
var birds: Node2D   # this shot's bird(s)
var topics: Array[Topic] = [MotionTopic.new(), ForcesTopic.new(), EnergyTopic.new(), PracticeTopic.new(), LevelsTopic.new(), EditorTopic.new()]
var level_data: Dictionary = LevelPresets.open_range()
var shots := 0   # launches since the level was set up
var shot_marks: ShotMarks   # the miss as a tape measure; where a cue's ability will fire
var cue_index := -1   # which lecture cue is loaded (−1: none)
var cue_stage := CueStage.ASKED
var cue_big: Label   # the cue's question, then its reveal line: centered, over the sky
var cue_small: Label   # the cue's answer options, under the question
var _cue_reveal_at := INF   # flight time at which a flying cue shows its reveal (INF: when it lands)
var _cue_key_ms := -CUE_KEY_GAP_MS
var _miss_checked: Bird   # the shot whose miss has been measured
var editor: LevelEditor
var level_title: Label   # the level's name, over the sky...
var banner: Label   # ...and its task, under the name
var main_button: Button   # Launch, or the flying bird's ability: whatever Space does right now
var _main_button_color := Color.TRANSPARENT   # what it's painted now (sliders refresh it many times a second)
var help: Control   # the keys and the mouse, over the sky (H)
var hint: Label   # how to start, until the first launch
var launched_once := false
var topic_buttons: Array[Button] = []
var current_topic := 0
var show_details := false   # formulas/explanations floating over the sky
var details_button: Button
var bird: Bird
var message: Label
var camera: Camera2D
var follow_zoom := 0.0   # 0 = Fit mode; 2 or 3 = zoomed in, following the bird
var view_zoom := 1.0   # the camera's actual zoom, eased toward the target
var dragging := false   # pulling the waiting bird back with the mouse
var fit_target := 1.0   # the zoom Fit is easing toward
var action_cam_enabled := false
var action := {}   # while the action cam runs: {"bird", "pig", "running_ms", "last_tick", "hit_seen"}
var action_overlay: ActionCamOverlay
var sim_controls: SimControls


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	_build_ui()
	_build_level()
	for topic in topics:
		if topic is LevelsTopic:
			topic.levels_panel.setup(self)
		elif topic is EditorTopic:
			topic.editor_panel.setup(self)
	show_topic(0)
	PhysicsParams.values_changed.connect(_apply_gravity_to_world)
	PhysicsParams.flight_changed.connect(_apply_gravity_to_world)
	PhysicsParams.launch_requested.connect(launch)
	PhysicsParams.reset_requested.connect(reset_level)
	PhysicsParams.bird_near_pig.connect(_on_bird_near_pig)
	PhysicsParams.announced.connect(func(text): message.text = text)
	PhysicsParams.values_changed.connect(_refresh_main_button)
	PhysicsParams.flight_changed.connect(_refresh_main_button)
	PhysicsParams.flight_changed.connect(_measure_miss)
	_apply_gravity_to_world()
	_refresh_main_button()


func _process(delta: float):
	# The slingshot shows a waiting bird unless one is currently flying.
	slingshot.loaded = not PhysicsParams.is_flying()
	hint.visible = not launched_once and PhysicsParams.manual_launch_allowed and not editor.active and message.text == "" and not is_cue()
	_update_cue()
	_update_action_cam()
	_update_camera(delta)


func _unhandled_input(event: InputEvent):
	# A click in the world ends typing in a number box (which applies the value),
	# so Space and the other keys work as shortcuts again.
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
	# Editing the level: the mouse belongs to the editor.
	if editor.active and event is InputEventMouse:
		editor.handle_input(event, _event_meters(event))
		return
	# Right-click in the world: move the solve-mode target there.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		PhysicsParams.set_target(_event_meters(event))
		return
	# Drag the waiting bird back to aim; let go to launch.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _can_grab(_event_meters(event)):
			dragging = true
			_update_drag(_event_meters(event))
		elif not event.pressed and dragging:
			dragging = false
			var pulled: float = slingshot.drag_offset.length()
			slingshot.drag_offset = Vector2.ZERO
			if pulled > 0.15:   # a tiny tug is just a click, not a launch
				player_launch()
		return
	if event is InputEventMouseMotion and dragging:
		_update_drag(_event_meters(event))
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			space_action()
		KEY_ENTER, KEY_KP_ENTER:
			PhysicsParams.activate()
		KEY_R:
			if is_cue() and PhysicsParams.show_level:
				load_level(level_data)   # the cue as it was asked: its values, and the future hidden again
			else:
				reset_level()
		KEY_PAGEDOWN, KEY_RIGHT:
			cue_key(true)
		KEY_PAGEUP, KEY_LEFT:
			cue_key(false)
		KEY_D:
			set_show_details(not show_details)
		KEY_H, KEY_F1:
			help.visible = not help.visible
		KEY_F11:   # fullscreen, e.g. on a projector (and back)
			set_fullscreen(not is_fullscreen())
		KEY_ESCAPE:
			if help.visible:
				help.visible = false
			elif is_fullscreen():
				set_fullscreen(false)
		var key when key >= KEY_1 and key < KEY_1 + topics.size():
			show_topic(key - KEY_1)


## Where a mouse event happened, in world meters (through the camera's zoom and position).
func _event_meters(event: InputEventMouse) -> Vector2:
	var global := get_viewport().get_canvas_transform().affine_inverse() * event.position
	return Units.to_m(world.to_local(global))


## Can the waiting bird be grabbed right now (a click near it)?
func _can_grab(click: Vector2) -> bool:
	if not PhysicsParams.manual_launch_allowed or PhysicsParams.inputs_locked or PhysicsParams.is_flying() or editor.active:
		return false
	var bird_at: Vector2 = Vector2(0, PhysicsParams.values["y0"]) + slingshot.pulled_back()
	return click.distance_to(bird_at) < GRAB_RADIUS_PX / (Units.PIXELS_PER_METER * view_zoom)


## Pulling back sets the launch: the angle points away from the pull (pull the
## bird up to aim down), and the pull distance sets Δx (spring mode) or v₀
## (speed mode: a full pull = 40 m/s).
func _update_drag(mouse: Vector2):
	var launch_point := Vector2(0, PhysicsParams.values["y0"])
	var pull := (launch_point - mouse).limit_length(MAX_DRAG_M)
	# From a launch point on the ground, aiming down would just roll the bird along
	# the ground, so only a raised launch point can aim below horizontal.
	var lowest_angle := -90.0 if PhysicsParams.values["y0"] >= 0.5 else 0.0
	PhysicsParams.set_value("theta", clampf(rad_to_deg(atan2(pull.y, pull.x)), lowest_angle, 90.0))
	if PhysicsParams.launch_mode == "spring":
		PhysicsParams.set_spring_value("pull", pull.length())
	else:
		PhysicsParams.set_value("v0", remap(pull.length(), 0.0, MAX_DRAG_M, 1.0, 40.0))
	slingshot.drag_offset = -pull   # the bird sits behind the launch point, where you pulled it


## Space, or the big button. Use the ability mid-air
## if the flying bird still has one, otherwise launch the next bird. (So a bird
## that's used its ability and is still far off-screen never blocks the next launch.)
func space_action():
	if PhysicsParams.can_activate():
		PhysicsParams.activate()
	else:
		player_launch()


## Launching by hand (Space, the big button, dragging). A practice problem can
## switch this off, so the answer can't just be found by trying.
func player_launch():
	if PhysicsParams.manual_launch_allowed and not editor.active:
		launch()


## The big button says what Space would do right now, in the colour of the bird it's for.
func _refresh_main_button():
	var ability := PhysicsParams.can_activate()
	var type: String = PhysicsParams.bird.type if ability else PhysicsParams.bird_type
	var info: Dictionary = BirdTypes.TYPES[type]
	main_button.text = "%s (Space)" % (info.get("action", "Activate") if ability else "Launch")
	main_button.disabled = not ability and not (PhysicsParams.manual_launch_allowed and not editor.active)
	if info["color"] != _main_button_color:
		_main_button_color = info["color"]
		UiTheme.paint(main_button, _main_button_color)


func launch():
	launched_once = true
	shots += 1
	message.text = ""   # (the last shot's result)
	_clear_shot()
	var trail := Trail.new()
	trails.add_child(trail)
	bird = Bird.new()
	bird.setup(PhysicsParams.values, PhysicsParams.bird_type, trail)
	birds.add_child(bird)
	if is_cue() and PhysicsParams.show_level and cue_stage == CueStage.ASKED:
		_fly_cue()


# --- Lecture cues ---

## Is the loaded level a lecture cue (a level that asks a question)?
func is_cue() -> bool:
	return level_data.has("question")


## PageDown / PageUp (and the arrow keys: some clickers send those).
## Forward does the cue's next step: fly it, reveal it, load the next cue.
## Back asks the same cue again, or goes to the one before if it hasn't flown yet.
func cue_key(forward: bool):
	var now := Time.get_ticks_msec()
	if editor.active or now - _cue_key_ms < CUE_KEY_GAP_MS:
		return
	_cue_key_ms = now
	if not PhysicsParams.show_level:   # a practice problem is open: leave it first, so it puts its settings back
		show_topic(0)
	var cues := LevelPresets.cues()
	if not forward:
		if cue_index < 0:
			return
		if cue_stage != CueStage.ASKED:
			load_level(cues[cue_index])
		else:
			load_level(cues[cue_index - 1] if cue_index > 0 else LevelPresets.open_range())
		return
	if PhysicsParams.is_flying() and get_tree().paused:   # it stopped itself at the top: carry on
		get_tree().paused = false
	elif PhysicsParams.is_flying() and cue_stage != CueStage.REVEALED:
		pass   # never wipe a shot the class is watching
	elif cue_index >= 0 and cue_stage == CueStage.ASKED:
		player_launch()
	elif cue_index >= 0 and cue_stage == CueStage.FLOWN:
		_reveal_cue()
	else:
		load_level(cues[cue_index + 1] if cue_index + 1 < cues.size() else LevelPresets.open_range())


## The flight time at which the cue's ability fires by itself (INF: it doesn't).
func _cue_ability_time() -> float:
	var at: Variant = level_data.get("activate_at")
	if at is String and at == "apex":
		return Kinematics.time_to_apex(PhysicsParams.launch_params())
	return float(at) if at is float or at is int else INF


## The cue's shot has just been launched: script its ability and its stop.
func _fly_cue():
	cue_stage = CueStage.FLOWN
	bird.activate_at = _cue_ability_time()
	_cue_reveal_at = bird.activate_at + CUE_REVEAL_AFTER_ABILITY
	if level_data.get("stop_at_apex", false) == true:
		bird.pause_at = Kinematics.time_to_apex(PhysicsParams.launch_params())
		bird.auto_stopped.connect(_reveal_cue)
	update_banner()


## A flown cue reveals itself when its shot ends (or a moment after its ability
## fired), unless it waits for PageDown.
func _update_cue():
	if cue_stage != CueStage.FLOWN or not is_cue() or level_data.get("reveal_on_key", false) == true:
		return
	if not is_instance_valid(bird) or bird.state != Bird.State.FLYING or bird.flight_time >= _cue_reveal_at:
		_reveal_cue()


## Show the cue's reveal line and everything that was hidden (the dotted
## prediction then lies on the path the shot really took).
func _reveal_cue():
	if cue_stage == CueStage.REVEALED:
		return
	cue_stage = CueStage.REVEALED
	Reveal.show_all()
	update_banner()


## The ring that shows where a cue's ability will fire.
func _mark_cue_ability():
	var at := _cue_ability_time()
	if is_cue() and PhysicsParams.show_level and not is_inf(at):
		shot_marks.show_ring(Units.to_px(Kinematics.position(PhysicsParams.launch_params(), at)), level_data.get("mark", "here"))


# --- The miss, in meters ---

## When a shot comes down on the ground with cans still standing, measure how
## close its path came to the nearest one: that distance is the number to beat.
## (Not after hitting a block: the tower may still fall. Not for a split: a piece may still hit.)
func _measure_miss():
	if not is_instance_valid(bird) or bird == _miss_checked or bird.state != Bird.State.PHYSICS:
		return
	_miss_checked = bird
	if not PhysicsParams.show_level or editor.active or not bird.pieces.is_empty() or PhysicsParams.collision.get("bird") == bird:
		return
	var nearest := {}
	for can: Pig in get_tree().get_nodes_in_group("pigs"):
		var closest := Kinematics.closest_approach(bird.segment, Units.to_m(can.position))   # (time, distance)
		if nearest.is_empty() or closest.y < nearest["distance"]:
			nearest = {"can": can, "time": minf(closest.x, bird.t), "distance": closest.y}
	if nearest.is_empty():
		return
	var can: Pig = nearest["can"]
	var passed := Kinematics.position(bird.segment, nearest["time"])
	var target := Units.to_m(can.position)
	var how := "passed above" if passed.y > target.y else "passed below"
	if nearest["time"] >= bird.t - 0.02:   # it was closest when it came down
		how = "landed short of" if passed.x < target.x else "landed beyond"
	var distance := "%s m" % String.num(nearest["distance"], 1)
	message.text = "Missed by %s: %s the %s." % [distance, how, "big dummy" if can.big else "dummy"]
	shot_marks.show_miss(Units.to_px(passed), can.position, distance)


func show_topic(index: int):
	current_topic = index
	for i in topics.size():
		topics[i].set_shown(i == index, show_details)
		topic_buttons[i].set_pressed_no_signal(i == index)


func set_show_details(on: bool):
	show_details = on
	details_button.set_pressed_no_signal(on)
	show_topic(current_topic)


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func set_fullscreen(on: bool):
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func reset_level():
	get_tree().paused = false   # a fresh start runs (slow motion stays as it is)
	shots = 0
	cue_stage = CueStage.ASKED
	_clear_shot()
	if is_instance_valid(level):
		level.queue_free()
	_build_level()
	update_banner()


## Load a level: its objects, its settings (launch values, bird, hidden
## values...) and its topic. Shows its name and task over the sky. The view
## starts fresh too (normal speed, Fit, no action cam, no formulas), so a level
## looks the same whatever was on screen before it.
func load_level(data: Dictionary):
	level_data = data.duplicate(true)
	editor.data = level_data
	cue_index = LevelPresets.cues().map(func(cue): return cue["name"]).find(level_data.get("name", "")) if is_cue() else -1
	Level.apply_settings(level_data)
	sim_controls.reset_view()
	set_show_details(false)
	reset_level()
	show_topic(clampi(level_data.get("topic", 0), 0, topics.size() - 1))
	update_banner()
	_mark_cue_ability()


func update_banner():
	var task: String = level_data.get("description", "")
	if not PhysicsParams.show_level:   # practice problems use an empty world: no level task
		task = ""
	banner.text = task
	level_title.text = level_data.get("name", "") if task != "" else ""
	# A cue asks its question big, in the middle. Once it flies, the question
	# moves up to the right (out of the arc's way), and the reveal takes the middle.
	var cue := is_cue() and PhysicsParams.show_level
	var asked := cue_stage == CueStage.ASKED
	cue_big.text = ""
	cue_small.text = ""
	if cue:
		var question: String = level_data["question"]
		var options: String = level_data.get("options", "")
		cue_big.text = question if asked else ""
		cue_small.text = options if asked else ""
		level_title.text = "" if asked else question
		banner.text = "" if asked else options
		if cue_stage == CueStage.REVEALED:
			cue_big.text = String(level_data.get("reveal", "")).replace("{g}", String.num(PhysicsParams.values["g"], 2))
	cue_big.visible = cue_big.text != ""
	cue_small.visible = cue_small.text != ""


## Start or stop editing the level. Stopping rebuilds it with live physics.
func set_editing(on: bool):
	editor.active = on
	reset_level()
	_refresh_main_button()


## Removes the last shot's bird(s) and trail(s) (and ends the action cam).
func _clear_shot():
	_end_action_cam()
	shot_marks.clear()
	for node in birds.get_children() + trails.get_children():
		node.set_physics_process(false)   # freed at the end of this frame; stop it touching the trails now
		node.queue_free()


## Godot's own physics (blocks, the pig, the bird after a hit) uses the same g as the formulas.
func _apply_gravity_to_world():
	var g_px := PhysicsParams.world_gravity() * Units.PIXELS_PER_METER
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, g_px)


# --- Camera ---

func set_zoom(zoom_level: float):
	follow_zoom = 0.0 if zoom_level == 1.0 else zoom_level


# --- Action cam ---

func _on_bird_near_pig(near_bird: Bird, pig: Pig):
	if not action_cam_enabled or not action.is_empty() or near_bird != bird:
		return
	action = {"bird": near_bird, "pig": pig, "pig_at": pig.position, "running_ms": 0, "last_tick": Time.get_ticks_msec(), "hit_seen": -1}
	Engine.time_scale = ACTION_SLOW
	for topic in topics:   # the topic's own arrows would clutter the close-up
		for overlay in topic.overlays:
			overlay.visible = false
	action_overlay.bird = near_bird
	action_overlay.pig = pig
	action_overlay.visible = true


## Ends the action cam a moment (real time) after the hit, or if nothing happens.
## Paused, the close-up waits for you: only real time while running counts.
func _update_action_cam():
	if action.is_empty():
		return
	var tick := Time.get_ticks_msec()
	if not get_tree().paused:
		action["running_ms"] += tick - action["last_tick"]
	action["last_tick"] = tick
	var now: int = action["running_ms"]
	if is_instance_valid(action["pig"]):
		action["pig_at"] = action["pig"].position
	if action["hit_seen"] < 0 and (not is_instance_valid(action["bird"]) or action["bird"].state != Bird.State.FLYING):
		action["hit_seen"] = now
	var done_after_hit: bool = action["hit_seen"] >= 0 and now - action["hit_seen"] > ACTION_AFTER_HIT_MS
	if done_after_hit or now > ACTION_MAX_MS:
		_end_action_cam()


func _end_action_cam():
	if action.is_empty():
		return
	Engine.time_scale = sim_controls.speed()   # the slow motion the button shows, even if S was pressed mid-action
	action = {}
	action_overlay.visible = false
	show_topic(current_topic)   # brings the topic's overlays back


## view: "" (off), "forces", "velocities" or "momentum". Can change mid-action.
func set_action_cam(view: String):
	action_cam_enabled = view != ""
	action_overlay.view = view
	if not action_cam_enabled:
		_end_action_cam()


func _update_camera(delta: float):
	if dragging:
		return   # hold still while aiming, or the view would move under the mouse
	# Fit zooms out as soon as the arc needs it, but only zooms back in once there's
	# clearly more room, so small changes don't make the view pump in and out.
	var needed := _fit_zoom()
	if needed < fit_target or needed > fit_target * FIT_ZOOM_IN_MARGIN:
		fit_target = needed
	var target_zoom := follow_zoom if follow_zoom > 0.0 else fit_target
	if not action.is_empty():
		target_zoom = ACTION_ZOOM
	var ease_amount := 1.0 - exp(-CAMERA_EASE * delta)
	view_zoom = lerpf(view_zoom, target_zoom, ease_amount)
	camera.zoom = Vector2(view_zoom, view_zoom)

	# Fit: keep the slingshot's foot at ORIGIN_PX on screen, whatever the zoom.
	# Zoomed in: put the bird (or the slingshot) at ZOOMED_FOCUS_ON_SCREEN.
	var focus := Vector2.ZERO
	var focus_on_screen := ORIGIN_PX
	if not action.is_empty():   # between the bird and the pig
		var bird_at: Vector2 = action["bird"].position if is_instance_valid(action["bird"]) else action["pig_at"]
		focus = (bird_at + action["pig_at"]) / 2.0
		focus_on_screen = ZOOMED_FOCUS_ON_SCREEN
	elif follow_zoom > 0.0:
		focus = bird.position if is_instance_valid(bird) else Units.to_px(Vector2(0, PhysicsParams.values["y0"]))
		focus_on_screen = ZOOMED_FOCUS_ON_SCREEN
	# A world point W appears on screen at (W − camera)·zoom + SCREEN_CENTER; solve for camera.
	var target := world.position + focus + (SCREEN_CENTER - focus_on_screen) / view_zoom
	camera.position = camera.position.lerp(target, ease_amount) if follow_zoom > 0.0 or not action.is_empty() else target


## The largest zoom (at most 1) that keeps the whole predicted arc, and the
## level, inside the sky between the left edge, the right edge and the top.
func _fit_zoom() -> float:
	var extent := Vector2(LEVEL_RIGHT_M, 6.0)   # meters that must fit: right of and above the origin
	var paths: Array[LaunchParams] = []
	if is_instance_valid(bird):
		paths.append_array(bird.segment_history)
		for piece in bird.pieces:
			if is_instance_valid(piece):
				paths.append(piece.segment)
	else:
		paths.append(PhysicsParams.launch_params())
	for p in paths:
		# A path that never comes down (g = 0, e.g. after a yellow-bird tap) would
		# need an endless view: skip it, the bird's own position covers it below.
		var landing := p.x0 + Kinematics.horizontal_range(p)
		var top := Kinematics.apex_height(p)
		if not is_inf(landing):
			extent.x = maxf(extent.x, landing)
		if not is_inf(top):
			extent.y = maxf(extent.y, top)
	if is_instance_valid(bird):
		var at := Units.to_m(bird.position)
		extent = Vector2(maxf(extent.x, at.x + 3.0), maxf(extent.y, at.y + 2.0))

	var room := Vector2(SCREEN_SIZE.x - ORIGIN_PX.x, ORIGIN_PX.y) - Vector2(SKY_MARGIN, SKY_MARGIN)
	var needed := extent * Units.PIXELS_PER_METER
	return clampf(minf(room.x / needed.x, room.y / needed.y), MIN_FIT_ZOOM, 1.0)


# --- Building the scene ---

func _build_world():
	world = Node2D.new()
	world.position = ORIGIN_PX
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	var ground := Ground.new()
	ground.process_mode = Node.PROCESS_MODE_ALWAYS   # redraws its rulers when the zoom changes
	world.add_child(ground)

	# Trails go below the preview dots, so you can see both.
	trails = Node2D.new()
	trails.process_mode = Node.PROCESS_MODE_ALWAYS   # redraw on zoom changes while paused
	world.add_child(trails)
	var preview := TrajectoryPreview.new()
	preview.process_mode = Node.PROCESS_MODE_ALWAYS   # keep redrawing while paused
	world.add_child(preview)

	slingshot = Slingshot.new()
	world.add_child(slingshot)
	birds = Node2D.new()   # the level gets placed just before this, so birds draw over blocks
	world.add_child(birds)
	shot_marks = ShotMarks.new()
	shot_marks.process_mode = Node.PROCESS_MODE_ALWAYS
	world.add_child(shot_marks)
	action_overlay = ActionCamOverlay.new()
	action_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	action_overlay.visible = false
	world.add_child(action_overlay)
	editor = LevelEditor.new()
	editor.process_mode = Node.PROCESS_MODE_ALWAYS
	editor.data = level_data
	editor.changed.connect(reset_level)
	world.add_child(editor)

	# The UI lives on a CanvasLayer, so zooming only affects the world.
	camera = Camera2D.new()
	camera.position = SCREEN_CENTER
	add_child(camera)


## Build the blocks and cans from level_data.
func _build_level():
	level = Node2D.new()
	world.add_child(level)
	world.move_child(level, slingshot.get_index() + 1)   # keep the topic overlays on top
	message.text = ""
	if not PhysicsParams.show_level:
		return   # practice problems use an empty world, so nothing blocks the shot
	for block_data in level_data["blocks"]:
		var block := Block.new(Vector2(block_data["w"], block_data["h"]))
		block.position = Units.to_px(Vector2(block_data["x"], block_data["y"]))
		block.freeze = editor.active   # frozen while editing, so pieces stay where they're put
		level.add_child(block)
	for pig_data in level_data["pigs"]:
		var pig := Pig.new(pig_data.get("big", false), pig_data.get("mass", 0.0))
		pig.position = Units.to_px(Vector2(pig_data["x"], pig_data["y"]))
		pig.freeze = editor.active
		pig.died.connect(_on_pig_died.bind(pig.big))
		pig.dented.connect(func(): message.text = "Hard hat cracked.  One more hit.")
		level.add_child(pig)


func _on_pig_died(big: bool):
	var left := get_tree().get_nodes_in_group("pigs").size()   # (a knocked-out can leaves the group)
	shot_marks.clear()   # (a shot that landed short can still roll into one)
	if left <= 0:
		message.text = "All down in %d shot%s.  R to reset." % [shots, "" if shots == 1 else "s"]
	else:
		message.text = "%s down.  %d to go." % ["Big dummy" if big else "Dummy", left]


func _build_ui():
	# Topic overlays go in the world last, so they draw on top of everything else there.
	for topic in topics:
		for overlay in topic.overlays:
			world.add_child(overlay)

	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	layer.add_child(root)

	# The dock: a strip under the ground with three columns.
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", UiTheme.dock())
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -DOCK_HEIGHT
	root.add_child(dock)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	dock.add_child(columns)

	# Column 1: the tabs, with the shown tab's panel under them. The physics tabs
	# come first; a divider, then the activities (Practice, Levels, Editor).
	var topic_column := VBoxContainer.new()
	topic_column.add_theme_constant_override("separation", 6)
	columns.add_child(topic_column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	topic_column.add_child(tabs)
	var tab_group := ButtonGroup.new()
	for i in topics.size():
		if topics[i] is PracticeTopic:
			tabs.add_child(VSeparator.new())
		var button := _make_toggle(topics[i].title, "%s (key %d)" % [topics[i].title, i + 1])
		button.add_theme_font_size_override("font_size", 16)
		button.button_group = tab_group
		button.pressed.connect(show_topic.bind(i))
		tabs.add_child(button)
		topic_buttons.append(button)
		topic_column.add_child(topics[i].panel)

	# Column 2: launch values and the bird.
	columns.add_child(ParamPanel.new())

	# Column 3: the big button, then time and view, then the world's settings.
	var control_column := VBoxContainer.new()
	control_column.add_theme_constant_override("separation", 6)
	control_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # the room that's left: the hide summary needs it
	columns.add_child(control_column)
	main_button = Button.new()
	main_button.custom_minimum_size = Vector2(0, 50)
	main_button.focus_mode = Control.FOCUS_NONE   # (Space is its key)
	main_button.tooltip_text = "Launch; in the air, use the ability (Space)"
	main_button.add_theme_font_override("font", UiTheme.bold())
	main_button.add_theme_font_size_override("font_size", 22)
	main_button.pressed.connect(space_action)
	control_column.add_child(main_button)
	sim_controls = SimControls.new()
	sim_controls.zoom_changed.connect(set_zoom)
	sim_controls.action_cam_changed.connect(set_action_cam)
	control_column.add_child(sim_controls)
	details_button = sim_controls.details_button
	details_button.toggled.connect(set_show_details)
	var world_panel := PanelContainer.new()
	control_column.add_child(world_panel)
	var world_rows := VBoxContainer.new()
	world_rows.add_theme_constant_override("separation", 6)
	world_panel.add_child(world_rows)
	world_rows.add_child(ElasticityRow.new())
	var hide_row := HBoxContainer.new()
	hide_row.add_theme_constant_override("separation", 10)
	world_rows.add_child(hide_row)
	var hide_panel := HidePanel.new()
	hide_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hide_row.add_child(hide_panel)
	var help_button := Button.new()
	help_button.text = "Help (H)"
	help_button.tooltip_text = "The keys and the mouse (H)"
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.custom_minimum_size = Vector2(0, 34)
	help_button.pressed.connect(func(): help.visible = not help.visible)
	hide_row.add_child(help_button)

	# Over the middle of the sky, from the top: a cue's question and options (or
	# its reveal), then the message (hits, misses, practice verdicts), then the hint.
	var sky_box := VBoxContainer.new()
	sky_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sky_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sky_box.offset_top = 96   # under the level's name and task (top right), which a long task can stretch
	sky_box.add_theme_constant_override("separation", 2)
	sky_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky_box)
	cue_big = _sky_label(52, 10)   # big enough for the back row
	cue_big.add_theme_font_override("font", UiTheme.bold())
	cue_small = _sky_label(34, 8)
	message = _sky_label(40, 8)
	hint = _sky_label(22, 6)
	hint.text = "Drag to aim  ·  Space to launch  ·  PageDown: lecture cues  ·  H for help"
	for label in [cue_big, cue_small, message, hint]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sky_box.add_child(label)

	# The level's name and task, top right: the name big, so the goal reads first.
	var banner_box := VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	banner_box.offset_right = -20
	banner_box.offset_top = 12
	banner_box.add_theme_constant_override("separation", 0)
	root.add_child(banner_box)
	level_title = _sky_label(30, 7)
	level_title.add_theme_font_override("font", UiTheme.bold())
	level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	banner_box.add_child(level_title)
	banner = _sky_label(21, 6)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	banner_box.add_child(banner)
	update_banner()
	# Formulas/explanations, only when switched on: under the name, so the slingshot's side of the sky stays clear.
	for topic in topics:
		topic.details.size_flags_horizontal = Control.SIZE_SHRINK_END
		banner_box.add_child(topic.details)

	help = _make_help()
	root.add_child(help)


func _make_toggle(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 34)
	button.focus_mode = Control.FOCUS_NONE
	return button


## White text with a dark outline, readable on the sky (and on the arrows under it).
func _sky_label(font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", outline)
	return label


## The keys and the mouse, shown over the sky with H (or the Help button):
## the one place that doesn't need hovering, so the class can see it too.
func _make_help() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 100   # under the level's name and task
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Keys and mouse"
	title.add_theme_font_override("font", UiTheme.bold())
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for row in [
		["Drag", "aim and pull back; let go to launch"],
		["Space", "launch; in the air, use the ability"],
		["R", "reset the level"],
		["PageDown  /  PageUp", "lecture cues: next step  /  ask again (a clicker's keys; ← → work too)"],
		["P  /  F", "pause  /  one physics step while paused"],
		["S", "slow motion: 1×, 0.5×, 0.25×, 0.1×"],
		["Z", "zoom: fit the arc, or follow the ball at 2× / 3×"],
		["C", "action cam near a dummy: forces, velocities, momentum, off"],
		["D", "formulas and explanations over the sky"],
		["1 – %d" % topics.size(), "tabs"],
		["Right-click", "move the target for Solve (Motion tab)"],
		["F11  /  Esc", "fullscreen on / off"],
		["H", "show / hide this"],
	]:
		var key := Label.new()
		key.text = row[0]
		key.add_theme_font_override("font", UiTheme.bold())
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(key)
		var what := Label.new()
		what.text = row[1]
		grid.add_child(what)
	var dock_guide := Label.new()
	dock_guide.text = "The dock:  left, what the tab shows  ·  middle, the launch and the ball  ·  right, run and view.\nHover over any control for more; D shows the formulas behind what's on screen."
	dock_guide.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	dock_guide.add_theme_font_size_override("font_size", 16)
	box.add_child(dock_guide)
	return panel
