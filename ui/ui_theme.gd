class_name UiTheme
extends RefCounted
## How the dock looks: a calm, flat instrument panel under the ground, so the
## colour stays in the world (the birds, the arrows, the sky).
## One rule for state: anything selected or switched on is lit (a light fill with
## dark text), so colour never has to say "on". Yellow is kept for the ability
## (its dotted path and its values); a bird's own colour marks the bird.
## Text contrast is 7:1 or more, for a projector at the back of a lecture hall.

const BG := Color("1b1916")   # the dock: deep soil under the grass
const SURFACE := Color("25221e")   # panels
const RAISED := Color("312d28")   # buttons
const HOVER := Color("3d3832")
const INSET := Color("161411")   # number boxes, lists, slider tracks
const LINE := Color("4a433b")   # borders
const TEXT := Color("f3eee6")   # 13:1 on SURFACE
const TEXT_DIM := Color("b9b0a3")   # 7:1 on SURFACE
const LIT := Color("f3eee6")   # selected / switched on
const LIT_HOVER := Color("ddd5c9")
const LIT_TEXT := Color("1b1916")


static func make() -> Theme:
	# Not every computer (and no browser) has a font with ✓, ✗, ★… to borrow from.
	ThemeDB.fallback_font.fallbacks = [LiveLabel.MONO_FONT]
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", _box(SURFACE, LINE, 8, 12, 12))

	theme.set_stylebox("normal", "Button", _box(RAISED, LINE, 6, 9, 4))
	theme.set_stylebox("hover", "Button", _box(HOVER, LINE, 6, 9, 4))
	theme.set_stylebox("pressed", "Button", _box(LIT, LIT, 6, 9, 4))
	theme.set_stylebox("hover_pressed", "Button", _box(LIT_HOVER, LIT_HOVER, 6, 9, 4))
	theme.set_stylebox("disabled", "Button", _box(Color(RAISED, 0.45), Color(LINE, 0.45), 6, 9, 4))
	theme.set_stylebox("focus", "Button", _focus_ring())
	_set_font_colors(theme, "Button", LIT_TEXT)
	# A checkbox is just its box and text: without these it would borrow the Button look.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(2)
		theme.set_stylebox(state, "CheckBox", empty)
	theme.set_stylebox("focus", "CheckBox", _focus_ring())
	_set_font_colors(theme, "CheckBox", TEXT)
	# The default empty box is dark on dark: draw an outline you can see from the back row.
	var box_size: Vector2 = ThemeDB.get_default_theme().get_icon("checked", "CheckBox").get_size()
	theme.set_icon("unchecked", "CheckBox", _outline_square(box_size, TEXT_DIM))
	theme.set_icon("unchecked_disabled", "CheckBox", _outline_square(box_size, Color(TEXT_DIM, 0.4)))

	theme.set_stylebox("normal", "LineEdit", _box(INSET, LINE, 4, 6, 3))
	theme.set_stylebox("focus", "LineEdit", _focus_ring())   # drawn over "normal"
	theme.set_stylebox("read_only", "LineEdit", _box(INSET, Color(LINE, 0.5), 4, 6, 3))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_uneditable_color", "LineEdit", TEXT_DIM)
	theme.set_color("font_placeholder_color", "LineEdit", Color(TEXT_DIM, 0.7))
	theme.set_color("caret_color", "LineEdit", TEXT)
	theme.set_color("selection_color", "LineEdit", Color(TEXT, 0.25))

	theme.set_stylebox("slider", "HSlider", _track(LINE))
	theme.set_stylebox("grabber_area", "HSlider", _track(TEXT_DIM))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _track(TEXT))

	theme.set_stylebox("panel", "ItemList", _box(INSET, LINE, 6, 6, 6))
	for state in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		theme.set_stylebox(state, "ItemList", _box(LIT, LIT, 4, 4, 2))
	theme.set_stylebox("hovered", "ItemList", _box(HOVER, HOVER, 4, 4, 2))
	for state in ["focus", "cursor", "cursor_unfocused"]:
		theme.set_stylebox(state, "ItemList", StyleBoxEmpty.new())
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_hovered_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", LIT_TEXT)
	theme.set_color("font_hovered_selected_color", "ItemList", LIT_TEXT)
	theme.set_color("guide_color", "ItemList", Color(LINE, 0.6))

	theme.set_stylebox("panel", "PopupMenu", _box(SURFACE, LINE, 6, 6, 6))
	theme.set_stylebox("hover", "PopupMenu", _box(HOVER, HOVER, 4, 6, 2))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_color("font_disabled_color", "PopupMenu", Color(TEXT, 0.35))

	theme.set_stylebox("panel", "TooltipPanel", _box(RAISED, LINE, 6, 10, 6))
	theme.set_color("font_color", "TooltipLabel", TEXT)

	var line := StyleBoxLine.new()
	line.vertical = true
	line.color = LINE
	theme.set_stylebox("separator", "VSeparator", line)
	return theme


## Dark earth, so the dock reads as "under the ground".
static func dock() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = Color("0e0c0a")
	style.border_width_top = 4
	style.set_content_margin_all(10)
	return style


## The default font, heavier: for headings and the big button.
static func bold() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.7
	return font


## A small heading over a group of controls.
static func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_override("font", bold())
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", TEXT_DIM)
	return label


## Fills a button with `color` (a bird's), with whichever text colour reads best on it.
static func paint(button: Button, color: Color):
	var text := LIT_TEXT if _contrast(color, LIT_TEXT) >= _contrast(color, Color.WHITE) else Color.WHITE
	button.add_theme_stylebox_override("normal", _box(color, color.darkened(0.25), 8, 16, 6))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.15), color.darkened(0.25), 8, 16, 6))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.15), color.darkened(0.35), 8, 16, 6))
	button.add_theme_stylebox_override("hover_pressed", _box(color.darkened(0.15), color.darkened(0.35), 8, 16, 6))
	button.add_theme_stylebox_override("disabled", _box(Color(color, 0.3), Color(color, 0.3), 8, 16, 6))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text)
	button.add_theme_color_override("font_disabled_color", Color(TEXT, 0.5))


## WCAG contrast ratio between two colours (1 to 21).
static func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var linear := c.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


static func _set_font_colors(theme: Theme, type: String, pressed: Color):
	theme.set_color("font_color", type, TEXT)
	theme.set_color("font_hover_color", type, TEXT)
	theme.set_color("font_focus_color", type, TEXT)
	theme.set_color("font_pressed_color", type, pressed)
	theme.set_color("font_hover_pressed_color", type, pressed)
	theme.set_color("font_disabled_color", type, Color(TEXT, 0.35))


static func _box(bg: Color, border: Color, radius: int, margin_x: float, margin_y: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


## Thin, rounded: a slider's track (the filled part uses it too).
static func _track(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


## An empty checkbox: a rounded square outline, 2 px.
static func _outline_square(size: Vector2, color: Color) -> ImageTexture:
	var image := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	var half := size / 2.0 - Vector2(1.5, 1.5)   # a little inside the edge, so it lines up with "checked"
	for y in int(size.y):
		for x in int(size.x):
			# Distance to a rounded square's outline (corner radius 3).
			var q := (Vector2(x + 0.5, y + 0.5) - size / 2.0).abs() - half + Vector2(3, 3)
			var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 3.0
			image.set_pixel(x, y, Color(color, clampf(1.5 - absf(outside + 1.0), 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## Shown around whatever has the keyboard focus (typing in a number box, mostly).
static func _focus_ring() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = TEXT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_expand_margin_all(2)
	return style
