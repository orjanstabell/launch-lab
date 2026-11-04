class_name EditorTopic
extends Topic
## The level editor (sandbox): build the level that's loaded, name it, save it.

var editor_panel := EditorPanel.new()


func _init():
	super()
	title = "Editor"
	add_content(editor_panel)
