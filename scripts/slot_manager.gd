extends Node
class_name SlotManager

signal slots_updated

const SLOT_OFFSET := 37
const SLOT_HEIGHT_INCREMENT := 30
const MAX_LOOP_SLOTS := 3

var parent_block: Block
var slots: Array[CommandSlot] = []
var slot_offset_start := Vector2(28, 32)
var original_slot_commands: Array = []

func _init(block: Block, start_offset: Vector2) -> void:
	parent_block = block
	slot_offset_start = start_offset

func initialize_slots(count: int = 1) -> void:
	if slots.is_empty():
		var slot_count = min(count, MAX_LOOP_SLOTS) if parent_block.type == Block.BlockType.LOOP else 1
		for _i in slot_count:
			create_slot()
	update_slots()

func create_slot() -> CommandSlot:
	if parent_block.type == Block.BlockType.LOOP and slots.size() >= MAX_LOOP_SLOTS:
		return slots.back()
	
	var slot = preload("res://scenes/command_slot.tscn").instantiate() as CommandSlot
	parent_block.add_child(slot)
	slot.block = parent_block
	slots.append(slot)
	return slot

func get_total_height() -> float:
	var height = slot_offset_start.y
	for slot in slots:
		height += SLOT_OFFSET if not (slot.command is Block) else slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
	return height

func update_all_slot_positions() -> void:
	var current_y = slot_offset_start.y
	for slot in slots:
		if not is_instance_valid(slot):
			continue
		slot.position = Vector2(slot_offset_start.x, current_y)
		var increment = SLOT_OFFSET
		if slot.command and is_instance_valid(slot.command):
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
	var valid_items = slots.filter(func(s): return s.command and is_instance_valid(s.command)).map(func(s): return s.command)
	for slot in slots:
		if is_instance_valid(slot):
			slot.command = null
	for i in min(valid_items.size(), slots.size()):
		slots[i].command = valid_items[i]
		if valid_items[i] is Command:
			valid_items[i].slot = slots[i]
		elif valid_items[i] is Block:
			valid_items[i].parent_slot = slots[i]
	update_all_slot_positions()

func adjust_slot_count() -> void:
	if slots.is_empty():
		create_slot()
		return
	var command_count = slots.filter(func(s): return s.command and is_instance_valid(s.command)).size()
	var target_count = min(command_count + 1, MAX_LOOP_SLOTS if parent_block.type == Block.BlockType.LOOP else INF)
	while slots.size() > target_count and not slots.back().command and is_instance_valid(slots.back()):
		slots.pop_back().queue_free()
	while slots.size() < target_count:
		create_slot()

func prepare_for_insertion(target_slot: CommandSlot) -> void:
	if not target_slot in slots:
		return
	original_slot_commands = slots.map(func(s): return s.command)
	var hover_index = slots.find(target_slot)
	if slots.back().command:
		create_slot()
	for i in range(slots.size() - 1, hover_index, -1):
		slots[i].command = slots[i - 1].command
	slots[hover_index].command = null
	update_all_slot_positions()

func cancel_insertion() -> void:
	if original_slot_commands.is_empty():
		return
	for i in slots.size():
		slots[i].command = original_slot_commands[i] if i < original_slot_commands.size() else null
	original_slot_commands = []
	update_slots()

func update_command_positions(base_z_index: int) -> void:
	for slot in slots:
		if slot.command and is_instance_valid(slot.command):
			slot.command.global_position = parent_block.to_global(slot.position)
			slot.command.visible = true
			slot.command.z_index = base_z_index - 1
			if slot.command is Block:
				slot.command.update_command_positions(base_z_index - 1)

func get_slot_at_index(index: int) -> CommandSlot:
	return slots[index] if index >= 0 and index < slots.size() else null
