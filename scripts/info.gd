extends ObjectRoom

@onready var info: Label = $Label
@onready var key_edit: LineEdit = $LineEdit

var key: int = 0

func _ready() -> void:
	super._ready()
	add_to_group('info')
	key_edit.visible = false
	key_edit.text = ""

func _on_area_2d_mouse_entered() -> void:
	# Ensure key is treated as an integer consistently
	if key > 0:
		var matching_items = get_tree().get_nodes_in_group('items')
		for item in matching_items:
			if item.key == key:
				info.text = "Предмет #" + str(key)
				return
	# If no match found or key == 0
	info.text = 'Информация'

func _on_area_2d_mouse_exited() -> void:
	info.text = ""

func _on_line_edit_text_submitted(_new_text: String) -> void:
	key = key_edit.text.to_int()
	key_edit.visible = false
	var edit_mode = get_tree().get_first_node_in_group("edit_mode")
	if edit_mode:
		edit_mode.is_editing_key = false
		
