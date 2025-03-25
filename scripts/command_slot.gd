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

func _process(_delta: float) -> void:
	visible = table.dragged_card != null and command == null
	if command and is_instance_valid(command):
		command.global_position = global_position

func add_command(new_command: Node2D) -> void:
	if command != null or not is_instance_valid(new_command):
		return
	if new_command is Block:
		if new_command.parent_slot:
			new_command.parent_slot.clear_command()
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
	if command is Block:
		command.parent_slot = null
	command = null
	block.update_slots()
