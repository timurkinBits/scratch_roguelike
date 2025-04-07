extends Node2D

@onready var command_list: Array[Node] = get_children()
@onready var table_node: Table = $".."

func _ready() -> void:
	for command in command_list:
		setup_menu_item(command)
	
	Global.connect("points_changed", update_command_appearances)
	update_command_appearances()

func setup_menu_item(command) -> void:
	if command is Command:
		command.is_menu_command = true
		command.menu_command_clicked.connect(_on_menu_command_clicked)
	elif command is Block:
		command.is_menu_command = true
		var area = command.get_node("Area2D")
		area.input_pickable = true
		area.input_event.connect(func(_viewport, event, _shape_idx):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_menu_block_clicked(command.type)
		)

func _on_menu_command_clicked(type: int) -> void:
	var remaining_points = Global.get_remaining_points(type)
	if remaining_points > 0 and !table_node.is_turn_in_progress:
		table_node.create_command_copy(type)
	
	update_command_appearances()

func _on_menu_block_clicked(type: int) -> void:
	if !table_node.is_turn_in_progress:
		table_node.create_block_copy(type)
	
func update_command_appearances() -> void:
	if not is_inside_tree():
		return
		
	# Update all command buttons
	for command in get_tree().get_nodes_in_group("commands"):
		command.update_buttons_state()
		
	# Update menu items visibility
	for command in command_list:
		if command is Command:
			var remaining = Global.get_remaining_points(command.type)
			var is_available = remaining > 0
			
			command.modulate.a = 1.0 if is_available else 0.3
			command.get_node("Area2D").input_pickable = is_available
