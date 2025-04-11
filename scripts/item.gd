extends ObjectRoom
class_name Item

@onready var key_edit: LineEdit = $LineEdit

var key: int = 0

func _ready() -> void:
	super._ready()
	add_to_group('items')
	key_edit.visible = false
	key_edit.text = ""

func use():
	#Global.spend_coins()
	queue_free()

func _on_line_edit_text_submitted(_new_text: String) -> void:
	key = key_edit.text.to_int()
	key_edit.visible = false
	var edit_mode = get_tree().get_first_node_in_group("edit_mode")
	if edit_mode:
		edit_mode.is_editing_key = false
		
