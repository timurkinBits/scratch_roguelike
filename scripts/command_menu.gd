extends Node2D

@onready var command_list: Array[Node] = get_children()
@onready var table_node: Table = $".."

func _ready() -> void:
	for command in command_list:
		if command is Command:
			command.is_menu_command = true
			command.menu_command_clicked.connect(_on_menu_command_clicked)
		elif command is Block:
			command.is_menu_command = true  # Добавьте эту строку
			command.get_node("Area2D").input_pickable = true
			var area = command.get_node("Area2D")
			area.input_event.connect(func(_viewport, event, _shape_idx):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					_on_menu_block_clicked(command.type)
			)
	
	Global.connect("points_changed", _on_points_changed)
	update_command_appearances()

func _on_menu_command_clicked(type: int) -> void:
	var remaining_points = Global.get_remaining_points(type)
	if remaining_points > 0 and !table_node.is_turn_in_progress:
		# Instead of directly creating a card, call the new method that creates a copy
		table_node.create_command_copy(type)
	
	update_command_appearances()

func _on_menu_block_clicked(type: int) -> void:
	if !table_node.is_turn_in_progress:
		# Заменяем вызов create_card на create_block_copy
		table_node.create_block_copy(type)
	
func _on_points_changed() -> void:
	update_command_appearances()
		
func update_command_appearances() -> void:
	if is_inside_tree():
		for command in get_tree().get_nodes_in_group("commands"):
			command.update_buttons_state()
	for command in command_list:
		if command is Command:
			var remaining = Global.get_remaining_points(command.type)
			if remaining <= 0:
				command.modulate.a = 0.3
				command.get_node("Area2D").input_pickable = false
			else:
				command.modulate.a = 1.0
				command.get_node("Area2D").input_pickable = true
