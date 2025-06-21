extends Node
class_name SlotManager

signal slots_updated

const SLOT_OFFSET := 37
const SLOT_HEIGHT_INCREMENT := 30

var parent_block: Block
var slots: Array[CommandSlot] = []
var slot_offset_start := Vector2(28, 32)
var original_slot_commands: Array = []
var insertion_prepared := false
var insertion_slot: CommandSlot = null

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
			# ИСПРАВЛЕНИЕ 1: Более безопасное обновление связей
			if slot.command is Command:
				if slot.command.slot != slot:
					slot.command.slot = slot
			elif slot.command is Block:
				if slot.command.parent_slot != slot:
					slot.command.parent_slot = slot
				slot.command.update_command_positions(slot.command.z_index)
				increment = slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
		current_y += increment

func update_slots() -> void:
	if not is_instance_valid(parent_block):
		print("Warning: parent_block is not valid in SlotManager.update_slots()")
		return
	
	shift_commands_up()
	adjust_slot_count()
	update_all_slot_positions()
	
	# Проверяем и восстанавливаем связи только если это необходимо
	if is_inside_tree():
		var table = get_tree().get_first_node_in_group('table')
		# ИСПРАВЛЕНИЕ: Восстанавливаем связи всегда, не только во время хода
		if table:
			call_deferred("restore_command_links")
	
	call_deferred("emit_slots_updated_signal")

func emit_slots_updated_signal() -> void:
	emit_signal("slots_updated")

# ИСПРАВЛЕНИЕ 4: Улучшенная функция восстановления связей
func restore_command_links() -> void:
	"""Восстанавливает связи между командами и слотами"""
	for block in get_tree().get_nodes_in_group("blocks"):
		if not is_instance_valid(block):
			continue
			
		if is_instance_valid(block.parent_slot):
			# Проверяем, что связь не нарушена
			if block.parent_slot.command != block:
				block.parent_slot.command = block
			
			# Обновляем позиции команд
			if block.has_method('update_command_positions'):
				block.update_command_positions(block.z_index)

func shift_commands_up() -> void:
	# Collect valid commands
	var valid_items = []
	for slot in slots:
		if is_instance_valid(slot) and is_instance_valid(slot.command):
			valid_items.append(slot.command)
	
	# Clear all slots first
	for slot in slots:
		if is_instance_valid(slot):
			slot.command = null
	
	# Fill slots with commands from top
	for i in min(valid_items.size(), slots.size()):
		if is_instance_valid(slots[i]):
			slots[i].command = valid_items[i]
			# Устанавливаем обратные связи
			if valid_items[i] is Command:
				valid_items[i].slot = slots[i]
			elif valid_items[i] is Block:
				valid_items[i].parent_slot = slots[i]

func adjust_slot_count() -> void:
	# Create at least one slot if none exist
	if slots.is_empty():
		create_slot()
		return
	
	# Determine max slots based on block text
	var max_slots = _get_max_slots_for_block(parent_block.text)
	
	# Count occupied slots
	var command_count = 0
	for slot in slots:
		if is_instance_valid(slot) and is_instance_valid(slot.command):
			command_count += 1
	
	# Target slot count: commands + 1 empty slot (up to max allowed)
	var target_count = min(command_count + 1, max_slots)
	
	# Remove empty slots at the end if we have too many
	while slots.size() > target_count:
		var last_slot = slots.back()
		if is_instance_valid(last_slot) and not is_instance_valid(last_slot.command):
			slots.pop_back()
			last_slot.queue_free()
		else:
			break
	
	# Add slots if needed
	while slots.size() < target_count:
		create_slot()

func _get_max_slots_for_block(block_text: String) -> int:
	# Определяем максимальное количество слотов по тексту блока
	if block_text == "начало хода":
		return 10
	elif block_text == "Повторить 2 раз" or block_text == "Повторить 3 раз":
		return 2
	elif block_text in ItemData.TEXT_TO_ITEM_TYPE:
		# Для блоков навыков из ItemData
		var item_type = ItemData.TEXT_TO_ITEM_TYPE[block_text]
		return ItemData.get_slot_count_by_item_type(item_type)
	else:
		# Для остальных блоков навыков
		return 1

# ИСПРАВЛЕНИЕ 5: Улучшенная подготовка к вставке
func prepare_for_insertion(target_slot: CommandSlot) -> void:
	if not target_slot in slots or insertion_prepared:
		return
	
	# ИСПРАВЛЕНИЕ 6: Проверяем валидность всех объектов
	if not is_instance_valid(target_slot) or not is_instance_valid(parent_block):
		print("Warning: Invalid objects in prepare_for_insertion")
		return
	
	# Store original commands state
	original_slot_commands.clear()
	for slot in slots:
		original_slot_commands.append(slot.command)
	
	insertion_prepared = true
	insertion_slot = target_slot
	var hover_index = slots.find(target_slot)
	
	# Determine max slots based on block text
	var max_slots = _get_max_slots_for_block(parent_block.text)
	
	# Create new empty slot if last slot is occupied and not exceeding max limit
	if slots.size() < max_slots and slots.back().command:
		create_slot()
	
	# Shift commands down from insertion point
	for i in range(slots.size() - 1, hover_index, -1):
		if i > 0 and i < slots.size():
			slots[i].command = slots[i - 1].command
			# Обновляем обратные связи
			if is_instance_valid(slots[i].command):
				if slots[i].command is Command:
					slots[i].command.slot = slots[i]
				elif slots[i].command is Block:
					slots[i].command.parent_slot = slots[i]
	
	# Clear the insertion slot
	if hover_index >= 0 and hover_index < slots.size():
		slots[hover_index].command = null
	
	update_all_slot_positions()

func finalize_insertion() -> void:
	# Завершаем процесс вставки - очищаем сохраненное состояние
	if insertion_prepared:
		original_slot_commands.clear()
		insertion_prepared = false
		insertion_slot = null

# ИСПРАВЛЕНИЕ 7: Улучшенная отмена вставки
func cancel_insertion() -> void:
	if not insertion_prepared or original_slot_commands.is_empty():
		return
	
	# ИСПРАВЛЕНИЕ 8: Дополнительные проверки валидности
	if not is_instance_valid(parent_block):
		print("Warning: parent_block is not valid in cancel_insertion")
		original_slot_commands.clear()
		insertion_prepared = false
		insertion_slot = null
		return
	
	# Restore original slot commands
	var restore_size = min(slots.size(), original_slot_commands.size())
	
	# Remove extra slots that were created during preparation
	while slots.size() > original_slot_commands.size():
		var slot = slots.pop_back()
		if is_instance_valid(slot):
			slot.queue_free()
	
	# Restore commands to their original positions
	for i in restore_size:
		if i < slots.size():
			slots[i].command = original_slot_commands[i]
			# Восстанавливаем обратные связи
			if is_instance_valid(slots[i].command):
				if slots[i].command is Command:
					slots[i].command.slot = slots[i]
				elif slots[i].command is Block:
					slots[i].command.parent_slot = slots[i]
	
	# Clear state
	original_slot_commands.clear()
	insertion_prepared = false
	insertion_slot = null
	
	update_all_slot_positions()

func update_command_positions(base_z_index: int) -> void:
	for slot in slots:
		if not is_instance_valid(slot) or not is_instance_valid(slot.command):
			continue
		
		slot.command.global_position = parent_block.to_global(slot.position)
		slot.command.visible = true
		
		# Устанавливаем z-индекс для вложенных команд относительно родительского блока
		# но сохраняем их собственную иерархию z-индексов
		if slot.command.z_index < Card.Z_INDEX_DRAGGING:
			slot.command.z_index = base_z_index - 1
		
		if slot.command is Block:
			slot.command.update_command_positions(slot.command.z_index)
