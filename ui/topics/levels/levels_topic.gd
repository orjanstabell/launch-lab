class_name LevelsTopic
extends Topic
## Levels: pick a level (built in, or one you saved in the Editor tab) and play it.

var levels_panel := LevelsPanel.new()


func _init():
	super()
	title = "Levels"
	add_content(levels_panel)
