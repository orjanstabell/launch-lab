class_name LiveLabel
extends Label
## Base for the topics' text, which is rebuilt every frame.
## Subclasses override _build_lines() and return the lines to show. Each topic
## makes two: a compact one for the dock (details = false) and a long one with
## the formulas and explanations (details = true).
##
## Keeping it calm on screen:
##   - a monospace font, plus Reveal.live() for changing numbers, so numbers
##     keep the same width as they change
##   - it only grows, never shrinks: when a line gets shorter or disappears, the
##     panel keeps its size instead of jumping around
##   - the text is only replaced when it actually changed (no relayout otherwise),
##     and nothing is rebuilt while the label is hidden
##   - in the dock it never gets wider than the panel: a line that's too long
##     ends in "…" instead of pushing the other columns off the screen

var details := false


func _init(show_details := false):
	details = show_details
	var mono := SystemFont.new()
	# Consolas (Windows) and Menlo (macOS) are always installed there, so the
	# numbers stay aligned on a lecture-room PC too.
	mono.font_names = PackedStringArray(["JetBrainsMono Nerd Font", "Consolas", "Menlo", "Liberation Mono", "DejaVu Sans Mono", "monospace"])
	add_theme_font_override("font", mono)
	add_theme_font_size_override("font_size", 17)
	if not details:
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _process(_delta: float):
	if not is_visible_in_tree():
		return
	var new_text := "\n".join(_build_lines())
	if new_text == text:
		return
	text = new_text
	custom_minimum_size = custom_minimum_size.max(get_minimum_size())


## Override this: the lines of text to show right now (check `details`).
func _build_lines() -> Array:
	return []
