extends Node2D
class_name CommandSlot

var command: Node2D = null
@onready var block: Block = get_parent() as Block
@onready var table: Node2D = get_tree().get_root().get_node("Main/Table") as Node2D

func _ready() -> void:
	if has_node("Area2D"):
		var area = $Area2D
		area.collision_layer = 3
		area.collision_mask = 3
	update_visibility()

func _process(_delta: float) -> void:
	update_visibility()
	if command and is_instance_valid(command):
		command.global_position = global_position

func update_visibility() -> void:
	if block.is_menu_command:
		visible = false
	else:
		visible = table.dragged_card != null and command == null

func add_command(new_command: Node2D) -> void:
	if command != null or not is_instance_valid(new_command):
		return
	if new_command is Block:
		new_command.parent_slot = self
		
	command = new_command
	if command is Command:
		command.slot = self
		command.block = block
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
