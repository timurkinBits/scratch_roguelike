extends Node
class_name SlotManager

signal slots_updated

const SLOT_OFFSET := 37
const SLOT_HEIGHT_INCREMENT := 30

var parent_block: Block
var slots: Array[CommandSlot] = []
var slot_offset_start := Vector2(28, 32)
var original_slot_commands: Array = []

func _init(block: Block, start_offset: Vector2) -> void:
	parent_block = block
	slot_offset_start = start_offset

func initialize_slots(count: int = 1) -> void:
	# Remove excess slots
	while slots.size() > count:
		var slot = slots.pop_back()
		if is_instance_valid(slot):
			slot.queue_free()
	
	# Create new slots if needed
	while slots.size() < count:
		create_slot()
	
	update_slots()

func create_slot() -> CommandSlot:
	var slot = preload("res://scenes/command_slot.tscn").instantiate() as CommandSlot
	parent_block.add_child(slot)
	slot.block = parent_block
	slots.append(slot)
	return slot

func get_total_height() -> float:
	var height = slot_offset_start.y
	for slot in slots:
		if not is_instance_valid(slot):
			continue
		height += SLOT_OFFSET if not (slot.command is Block) else slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
	return height

func update_all_slot_positions() -> void:
	var current_y = slot_offset_start.y
	for slot in slots:
		if not is_instance_valid(slot):
			continue
		slot.position = Vector2(slot_offset_start.x, current_y)
		var increment = SLOT_OFFSET
		if is_instance_valid(slot.command):
			slot.command.global_position = parent_block.to_global(slot.position)
			if slot.command is Command:
				slot.command.slot = slot
			elif slot.command is Block:
				slot.command.parent_slot = slot
				slot.command.update_command_positions(slot.command.z_index)
				increment = slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
		current_y += increment

func update_slots() -> void:
	shift_commands_up()
	adjust_slot_count()
	update_all_slot_positions()
	emit_signal("slots_updated")

func shift_commands_up() -> void:
	# Collect valid commands
	var valid_items = []
	for slot in slots:
		if is_instance_valid(slot) and is_instance_valid(slot.command):
			valid_items.append(slot.command)
	
	# Clear all slots
	for slot in slots:
		if is_instance_valid(slot):
			slot.command = null
	
	# Fill slots with commands from top
	for i in min(valid_items.size(), slots.size()):
		slots[i].command = valid_items[i]
		if valid_items[i] is Command:
			valid_items[i].slot = slots[i]
		elif valid_items[i] is Block:
			valid_items[i].parent_slot = slots[i]
	
	update_all_slot_positions()

func adjust_slot_count() -> void:
	# Create at least one slot if none exist
	if slots.is_empty():
		create_slot()
		return
	
	# Determine max slots based on block type
	var max_slots
	if parent_block.type == Block.BlockType.CONDITION:
		max_slots = parent_block.CONDITION_SLOTS.get(parent_block.text, 3)
	elif parent_block.type == Block.BlockType.ABILITY:
		max_slots = parent_block.ABILITY_SLOTS.get(parent_block.text, 3)
	elif parent_block.type == Block.BlockType.LOOP:
		max_slots = 3
	else:
		max_slots = 3
	
	# Count occupied slots
	var command_count = 0
	for slot in slots:
		if is_instance_valid(slot) and is_instance_valid(slot.command):
			command_count += 1
	
	# Target slot count: commands + 1 empty slot (up to max allowed)
	var target_count = min(command_count + 1, max_slots)
	
	# Remove empty slots at the end
	while slots.size() > target_count and is_instance_valid(slots.back()) and not slots.back().command:
		slots.pop_back().queue_free()
	
	# Add slots if needed
	while slots.size() < target_count:
		create_slot()

func prepare_for_insertion(target_slot: CommandSlot) -> void:
	if not target_slot in slots:
		return
	
	# Store original commands
	original_slot_commands = []
	for slot in slots:
		original_slot_commands.append(slot.command)
	
	var hover_index = slots.find(target_slot)
	
	# Determine max slots based on block type
	var max_slots
	if parent_block.type == Block.BlockType.CONDITION:
		max_slots = parent_block.CONDITION_SLOTS.get(parent_block.text, 3)
	elif parent_block.type == Block.BlockType.ABILITY:
		max_slots = parent_block.ABILITY_SLOTS.get(parent_block.text, 3)
	elif parent_block.type == Block.BlockType.LOOP:
		max_slots = 3
	else:
		max_slots = 3
	
	# Create new empty slot if last slot is occupied and not exceeding max limit
	if slots.size() < max_slots and slots.back().command:
		create_slot()
	
	# Shift commands down from insertion point
	for i in range(slots.size() - 1, hover_index, -1):
		slots[i].command = slots[i - 1].command
	
	# Clear the insertion slot
	slots[hover_index].command = null
	
	update_all_slot_positions()

func cancel_insertion() -> void:
	if original_slot_commands.is_empty():
		return
	
	# Restore original slot commands
	for i in min(slots.size(), original_slot_commands.size()):
		slots[i].command = original_slot_commands[i]
	
	# Remove extra slots
	while slots.size() > original_slot_commands.size():
		var slot = slots.pop_back()
		if is_instance_valid(slot):
			slot.queue_free()
	
	original_slot_commands = []
	update_slots()

func update_command_positions(base_z_index: int) -> void:
	for slot in slots:
		if not is_instance_valid(slot) or not is_instance_valid(slot.command):
			continue
		
		slot.command.global_position = parent_block.to_global(slot.position)
		slot.command.visible = true
		slot.command.z_index = base_z_index - 1
		
		if slot.command is Block:
			slot.command.update_command_positions(base_z_index - 1)
