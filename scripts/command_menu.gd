extends Node2D

@onready var command_list: Array[Node] = get_children()
@onready var table_node: Table = $".."

func _ready() -> void:
	for command in command_list:
		if command is Command:
			command.is_menu_command = true  # Confirm this is a menu command
			command.menu_command_clicked.connect(_on_menu_command_clicked)
	
	# Add signals to update visual state when points change
	Global.connect("points_changed", _on_points_changed)
	update_command_appearances()

func _on_menu_command_clicked(type: int) -> void:
	# Strict check for remaining points
	var remaining_points = Global.get_remaining_points(type)
	if remaining_points > 0:
		table_node.create_command(type)  # Create a command copy on the table
	
	# Update appearances after attempting to create a command
	update_command_appearances()
	
func _on_points_changed() -> void:
	update_command_appearances()
		
func update_command_appearances() -> void:
	if is_inside_tree():
		for command in get_tree().get_nodes_in_group("commands"):
			command.update_buttons_state()
	for command in command_list:
		if command is Command:
			var remaining = Global.get_remaining_points(command.type)
			# Make commands with no remaining points appear disabled
			if remaining <= 0:
				command.modulate.a = 0.3  # Semi-transparent
				# Optional: disable interactive elements
				command.get_node("Area2D").input_pickable = false
			else:
				command.modulate.a = 1.0  # Fully opaque
				command.get_node("Area2D").input_pickable = true
