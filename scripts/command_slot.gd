extends Node2D
class_name CommandSlot

var command: Node2D = null
@onready var block: Block = get_parent() as Block
@onready var table: Node2D = find_parent("Table") as Node2D

func _ready() -> void:
	if has_node("Area2D"):
		var area = $Area2D
		area.collision_layer = 3
		area.collision_mask = 3
	update_visibility()

func _process(_delta: float) -> void:
	update_visibility()

func update_visibility() -> void:
	if block.is_menu_command:
		visible = false
	else:
		# Check if any card is being dragged
		var any_card_dragged = false
		for card in get_tree().get_nodes_in_group("cards"):
			if card is Card and card.is_being_dragged:
				any_card_dragged = true
				break
		
		visible = any_card_dragged and command == null

func add_command(new_command: Node2D) -> void:
	if command != null or not is_instance_valid(new_command):
		return
		
	command = new_command
	if command is Card:
		command.slot = self
		
	if command is Command:
		command.block = block
	elif command is Block:
		command.parent_slot = self
	
	# Обновляем позицию команды явно при добавлении
	command.global_position = global_position
	command.visible = true
	command.z_index = block.z_index + 1
	block.update_slots()

func clear_command() -> void:
	# Save a reference to the command being cleared
	var old_command = command
	command = null
	
	# Update the block structure
	if block and is_instance_valid(block):
		block.update_slots()
		
		# If this was a nested block, update the parent hierarchy
		if old_command is Block and block.parent_slot and is_instance_valid(block.parent_slot):
			var parent_block = block.parent_slot.block
			if parent_block and is_instance_valid(parent_block):
				parent_block.call_deferred("update_slots")
