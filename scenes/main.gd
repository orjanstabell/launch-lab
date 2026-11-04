extends Node2D
## Builds the whole game from code: world, level, UI.
##
## All world objects live under `world`, a Node2D placed at the slingshot's foot.
## So inside `world`, pixel (0, 0) is the physics origin (x = 0 m, y = 0 m), and
## Units.to_px() turns meters into positions directly.
##
## Screen layout (like a city builder's bottom bar): the sky is kept free, and
## all the panels sit in a dock "under the ground". Formulas and explanations
## only float over the sky when you switch them on (Formulas button, or D).
##
## Pausing: this node and the UI keep running while paused (so keys and buttons
## still work), but `world` is set to pause, which freezes the bird and physics.
##
## Topics (Motion, Forces, ...) each bring a panel in the dock and overlays in
## the world. Only one is shown at a time; switch with the tabs or number keys.
##
## The level (blocks and pigs) is built from level_data, a plain Dictionary (see
## Level). The Levels tab loads, saves and edits it; editing goes through `editor`.

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

var world: Node2D
var level: Node2D   # blocks and pig, rebuilt on reset
var slingshot: Slingshot
var trails: Node2D   # this shot's trail(s): one per bird, more after a blue bird split
var birds: Node2D   # this shot's bird(s)
var topics: Array[Topic] = [MotionTopic.new(), ForcesTopic.new(), MomentumTopic.new(), EnergyTopic.new(), PracticeTopic.new(), LevelsTopic.new(), EditorTopic.new()]
var level_data: Dictionary = LevelPresets.tower()
var editor: LevelEditor
var banner: Label   # the level's name and task, over the sky
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
var action := {}   # while the action cam runs: {"bird", "pig", "saved_scale", "started", "hit_seen"}
var action_overlay: ActionCamOverlay


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
	PhysicsParams.details_requested.connect(set_show_details.bind(true))
	PhysicsParams.bird_near_pig.connect(_on_bird_near_pig)
	PhysicsParams.announced.connect(func(text): message.text = text)
	_apply_gravity_to_world()


func _process(delta: float):
	# The slingshot shows a waiting bird unless one is currently flying.
	slingshot.loaded = not PhysicsParams.is_flying()
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
			# Like tapping in Angry Birds: use the ability mid-air if the flying bird
			# still has one, otherwise launch the next bird. (So a bird that's used its
			# ability and is still far off-screen never blocks the next launch.)
			if PhysicsParams.can_activate():
				PhysicsParams.activate()
			else:
				player_launch()
		KEY_ENTER, KEY_KP_ENTER:
			PhysicsParams.activate()
		KEY_R:
			reset_level()
		KEY_D:
			set_show_details(not show_details)
		KEY_F11:   # fullscreen, e.g. on a projector (and back)
			set_fullscreen(not is_fullscreen())
		KEY_ESCAPE:
			if is_fullscreen():
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


## Space or the Launch button. A practice problem can switch this off, so the
## answer can't just be found by trying.
func player_launch():
	if PhysicsParams.manual_launch_allowed and not editor.active:
		launch()


func launch():
	_clear_shot()
	var trail := Trail.new()
	trails.add_child(trail)
	bird = Bird.new()
	bird.setup(PhysicsParams.values, PhysicsParams.bird_type, trail)
	birds.add_child(bird)


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
	_clear_shot()
	if is_instance_valid(level):
		level.queue_free()
	_build_level()
	update_banner()


## Load a level: its objects, its settings (launch values, bird, hidden
## values...) and its topic. Shows its name and task over the sky.
func load_level(data: Dictionary):
	level_data = data.duplicate(true)
	editor.data = level_data
	Level.apply_settings(level_data)
	reset_level()
	show_topic(clampi(level_data.get("topic", 0), 0, topics.size() - 1))
	update_banner()


func update_banner():
	if not PhysicsParams.show_level:   # practice problems use an empty world: no level task
		banner.text = ""
		return
	var task: String = level_data.get("description", "")
	banner.text = "%s\n%s" % [level_data.get("name", ""), task] if task != "" else ""


## Start or stop editing the level. Stopping rebuilds it with live physics.
func set_editing(on: bool):
	editor.active = on
	reset_level()


## Removes the last shot's bird(s) and trail(s) (and ends the action cam).
func _clear_shot():
	_end_action_cam()
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
	action = {"bird": near_bird, "pig": pig, "pig_at": pig.position, "saved_scale": Engine.time_scale, "started": Time.get_ticks_msec(), "hit_seen": -1}
	Engine.time_scale = ACTION_SLOW
	for topic in topics:   # the topic's own arrows would clutter the close-up
		for overlay in topic.overlays:
			overlay.visible = false
	action_overlay.bird = near_bird
	action_overlay.pig = pig
	action_overlay.visible = true


## Ends the action cam a moment (real time) after the hit, or if nothing happens.
func _update_action_cam():
	if action.is_empty():
		return
	var now := Time.get_ticks_msec()
	if is_instance_valid(action["pig"]):
		action["pig_at"] = action["pig"].position
	if action["hit_seen"] < 0 and (not is_instance_valid(action["bird"]) or action["bird"].state != Bird.State.FLYING):
		action["hit_seen"] = now
	var done_after_hit: bool = action["hit_seen"] >= 0 and now - action["hit_seen"] > ACTION_AFTER_HIT_MS
	if done_after_hit or now - action["started"] > ACTION_MAX_MS:
		_end_action_cam()


func _end_action_cam():
	if action.is_empty():
		return
	Engine.time_scale = action["saved_scale"]
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


## Build the blocks and pigs from level_data. (The default level is a small
## tower with the pig on top; the default shot falls a little short of it.)
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
		pig.died.connect(_on_pig_died)
		level.add_child(pig)


func _on_pig_died():
	var left := get_tree().get_nodes_in_group("pigs").size()   # (a defeated pig leaves the group)
	message.text = "All pigs down!  Press R to play again." if left <= 0 else "Pig down!  %d to go." % left


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
	root.theme = _make_theme()
	layer.add_child(root)

	# Formulas/explanations: float over the top-left of the sky, only when switched on.
	for topic in topics:
		topic.details.position = Vector2(20, 20)
		root.add_child(topic.details)

	# The dock: a strip under the ground with three columns.
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", _make_dock_style())
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -DOCK_HEIGHT
	root.add_child(dock)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	dock.add_child(columns)

	# Column 1: topic tabs (+ the Formulas toggle), with the topic's compact panel.
	var topic_column := VBoxContainer.new()
	topic_column.add_theme_constant_override("separation", 6)
	columns.add_child(topic_column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	topic_column.add_child(tabs)
	var tab_group := ButtonGroup.new()
	for i in topics.size():
		var button := _make_toggle(topics[i].title, "%s (key %d)" % [topics[i].title, i + 1])
		button.add_theme_font_size_override("font_size", 16)
		button.button_group = tab_group
		button.pressed.connect(show_topic.bind(i))
		tabs.add_child(button)
		topic_buttons.append(button)
		topic_column.add_child(topics[i].panel)
	details_button = _make_toggle("Formulas", "Show the formulas and explanations over the sky (D)")
	details_button.add_theme_font_size_override("font_size", 16)
	details_button.toggled.connect(set_show_details)
	tabs.add_child(details_button)

	# Column 2: parameters and bird.
	var param_panel := ParamPanel.new()
	param_panel.launch_requested.connect(player_launch)
	columns.add_child(param_panel)

	# Column 3: simulation controls and hiding values.
	var control_column := VBoxContainer.new()
	control_column.add_theme_constant_override("separation", 6)
	columns.add_child(control_column)
	var sim_controls := SimControls.new()
	sim_controls.zoom_changed.connect(set_zoom)
	sim_controls.action_cam_changed.connect(set_action_cam)
	control_column.add_child(sim_controls)
	control_column.add_child(HidePanel.new())

	message = Label.new()
	message.add_theme_font_size_override("font_size", 40)
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.add_theme_constant_override("outline_size", 8)
	message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message.position.y = 30
	root.add_child(message)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	banner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	banner.offset_right = -20
	banner.offset_top = 16
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner.add_theme_constant_override("outline_size", 6)
	root.add_child(banner)
	update_banner()


func _make_toggle(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.2))
	return button


func _make_theme() -> Theme:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)

	# Not every computer (and no browser) has a font with ✓, ✗, ★… to borrow from.
	ThemeDB.fallback_font.fallbacks = [LiveLabel.MONO_FONT]
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	return theme


## Dark earth, so the dock reads as "under the ground".
func _make_dock_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.14, 0.09)
	style.border_color = Color(0.13, 0.09, 0.05)
	style.border_width_top = 4
	style.set_content_margin_all(10)
	return style
