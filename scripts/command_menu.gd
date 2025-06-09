# В command_menu.gd
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
		command.menu_card_clicked.connect(_on_menu_command_clicked)

func _on_menu_command_clicked(type: int) -> void:
	# USE и TURN команды всегда доступны (бесконечные)
	if type == Command.TypeCommand.USE or type == Command.TypeCommand.TURN:
		if !table_node.is_turn_in_progress:
			table_node.create_command_copy(type)
	else:
		# Для остальных команд проверяем очки
		var remaining_points = Global.get_remaining_points(type)
		if remaining_points > 0 and !table_node.is_turn_in_progress:
			table_node.create_command_copy(type)
	
	update_command_appearances()

func update_command_appearances() -> void:
	if not is_inside_tree():
		return
		
	# Update all command buttons
	for command in get_tree().get_nodes_in_group("commands"):
		command.update_buttons_state()
		
	# Update menu items visibility
	for command in command_list:
		if command is Command:
			var is_available = false
			
			# USE и TURN команды всегда доступны
			if command.type == Command.TypeCommand.USE or command.type == Command.TypeCommand.TURN:
				is_available = true
			else:
				# Для остальных команд проверяем очки
				var remaining = Global.get_remaining_points(command.type)
				is_available = remaining > 0
			
			command.modulate.a = 1.0 if is_available else 0.3
			command.get_node("Area2D").input_pickable = is_available
