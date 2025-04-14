extends Node2D

@onready var list: Array[Node] = get_children()
@onready var table_node: Table = $".."

func _ready() -> void:
	for item in list:
		setup_menu_item(item)
	
	Global.connect("points_changed", update_command_appearances)
	update_command_appearances()

func setup_menu_item(item) -> void:
	if item is Command:
		#item.is_menu_command = true
		item.menu_card_clicked.connect(_on_menu_command_clicked)
	elif item is Block:
		#item.is_menu_command = true
		var area = item.get_node("Area2D")
		area.input_pickable = true
		area.input_event.connect(func(_viewport, event, _shape_idx):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_menu_block_clicked(item.type)
		)

func _on_menu_command_clicked(type: int) -> void:
	var remaining_points = Global.get_remaining_points(type)
	if remaining_points > 0 and !table_node.is_turn_in_progress:
		table_node.create_command_copy(type)
	
	update_command_appearances()

func _on_menu_block_clicked(type: int) -> void:
	# Check if blocks are available before creating
	if !table_node.is_turn_in_progress and Global.get_remaining_blocks(type) > 0:
		table_node.create_block_copy(type)
		# Use the block limit
		Global.use_block(type)
	
func update_command_appearances() -> void:
	if not is_inside_tree():
		return
		
	# Update all command buttons
	for command in get_tree().get_nodes_in_group("commands"):
		command.update_buttons_state()
		
	# Update menu items visibility
	for item in list:
		if item is Command:
			var remaining = Global.get_remaining_points(item.type)
			var is_available = remaining > 0
			
			item.modulate.a = 1.0 if is_available else 0.3
			item.get_node("Area2D").input_pickable = is_available
		elif item is Block:
			var remaining = Global.get_remaining_blocks(item.type)
			var is_available = remaining > 0
			
			item.modulate.a = 1.0 if is_available else 0.3
			item.get_node("Area2D").input_pickable = is_available
