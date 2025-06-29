extends Node
class_name BlockExecutor

## Visual execution indicators
var outline_panels: Array[Node] = []

@onready var player: Player = $"../../../Room/Player"
@onready var command_executor: CommandExecutor = $"../CommandExecutor"

## Execute start turn blocks
func execute_start_turn_blocks() -> bool:
	var start_turn_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and block.text == "начало хода")
	
	for block in start_turn_blocks:
		if not is_instance_valid(block):
			continue
		await execute_block(block)
		if !is_instance_valid(player):
			return false
	
	return true

## Execute a block of commands
func execute_block(block: Block) -> void:
	if !is_instance_valid(player) or !is_instance_valid(block):
		return
	
	# Create visual execution indicator
	var outline = create_outline_panel(block)
	
	# Determine iterations and properties based on block text
	var iterations = 1
	var additional_properties = ""
	
	if block._is_loop_block():
		if block.text == "Повторить 2 раз":
			iterations = 2
		elif block.text == "Повторить 3 раз":
			iterations = 3
		else:
			iterations = max(1, block.loop_count)
	elif not block._is_start_turn_block():
		# Это навык - применяем свойства к командам
		additional_properties = block.text
	
	# Execute iterations
	for i in iterations:
		if !is_instance_valid(player):
			break
		
		# Execute all commands in slots
		for slot in block.slot_manager.slots:
			if !is_instance_valid(player) or !is_instance_valid(slot.command):
				break
			
			if slot.command is Block:
				await execute_block(slot.command)
			elif slot.command is Command:
				# Apply ability properties if this is an ability block
				if additional_properties != "":
					slot.command.additional_properties = additional_properties
				await command_executor.execute_command(slot.command)
		
		# Delay between loop iterations
		if i < iterations - 1 and is_instance_valid(player):
			await get_tree().create_timer(0.2).timeout
	
	# Remove indicator
	remove_outline(outline)

## Create visual execution indicator
func create_outline_panel(node: Node2D) -> Panel:
	if !is_instance_valid(node) or !node.has_node("Texture"):
		return null
	
	var texture = node.get_node("Texture")
	var panel = Panel.new()
	panel.size = texture.size + Vector2(4, 4)
	panel.position = Vector2(-2, -2)
	
	# Set panel style
	var style = StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 10
	
	node.add_child(panel)
	outline_panels.append(panel)
	
	return panel

## Remove a visual indicator
func remove_outline(outline: Panel) -> void:
	if is_instance_valid(outline):
		outline_panels.erase(outline)
		outline.queue_free()

## Clear all visual indicators
func clear_outlines() -> void:
	for panel in outline_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	outline_panels.clear()



## НОВЫЙ ЕДИНЫЙ МЕТОД: Полная очистка всех элементов с возвратом в меню
func clear_all_elements() -> void:
	if not is_inside_tree():
		return
	
	var elements_to_clear = []
	var blocks_to_update = []
	
	# Проходим по всем блокам
	for block in get_tree().get_nodes_in_group("blocks"):
		if not is_instance_valid(block):
			continue
		
		var block_had_content = false
		
		# Собираем все элементы из слотов блока
		for slot in block.slot_manager.slots:
			if is_instance_valid(slot) and is_instance_valid(slot.command):
				var element = slot.command
				var release_method = ""
				
				if element is SpecialCommand:
					# Определяем метод освобождения для команды
					if element.special_id.is_empty():
						release_method = "release_points"
					else:
						release_method = "release_special_command"
				elif element is Block:
					# Сначала рекурсивно собираем элементы из вложенного блока
					_collect_elements_from_block_recursive(element, elements_to_clear)
					# Сам блок тоже освобождаем
					release_method = "release_block"
				
				elements_to_clear.append({
					"element": element,
					"slot": slot,
					"release_method": release_method
				})
				block_had_content = true
		
		if block_had_content and not blocks_to_update.has(block):
			blocks_to_update.append(block)
	
	# Очищаем все собранные элементы
	await _clear_elements_with_animation(elements_to_clear)
	
	# Обновляем все затронутые блоки
	for block in blocks_to_update:
		if is_instance_valid(block):
			block.slot_manager.shift_commands_up()
			block.slot_manager.adjust_slot_count()
			block.slot_manager.update_all_slot_positions()
	
	# Обновляем иерархию блоков
	update_root_blocks()

## Рекурсивный сбор элементов из блока
func _collect_elements_from_block_recursive(block: Block, elements_array: Array) -> void:
	if not is_instance_valid(block):
		return
	
	for slot in block.slot_manager.slots:
		if is_instance_valid(slot) and is_instance_valid(slot.command):
			var element = slot.command
			var release_method = ""
			
			if element is SpecialCommand:
				if element.special_id.is_empty():
					release_method = "release_points"
				else:
					release_method = "release_special_command"
			elif element is Block:
				# Рекурсивно обрабатываем вложенный блок
				_collect_elements_from_block_recursive(element, elements_array)
				release_method = "release_block"
			
			elements_array.append({
				"element": element,
				"slot": slot,
				"release_method": release_method
			})

## Единый метод для очистки элементов с анимацией и освобождением ресурсов
func _clear_elements_with_animation(elements_to_clear: Array) -> void:
	if elements_to_clear.is_empty():
		return
	
	# Анимация исчезновения
	var tween = create_tween().set_parallel(true)
	for element_data in elements_to_clear:
		var element = element_data.element
		if is_instance_valid(element) and element.has_node("Texture"):
			tween.tween_property(element.get_node("Texture"), "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# Освобождение ресурсов и удаление элементов
	for element_data in elements_to_clear:
		var element = element_data.element
		var slot = element_data.slot
		var release_method = element_data.release_method
		
		if not is_instance_valid(element):
			continue
		
		# Освобождаем ресурсы в Global в зависимости от типа элемента
		match release_method:
			"release_points":
				if element is Command:
					Global.release_points(element.type_command, element.value)
			"release_special_command":
				if element is Command and not element.special_id.is_empty():
					if element.has_value:
						Global.release_special_points(element.special_id, element.value)
					Global.release_special_command(element.special_id)
			"release_block":
				if element is Block and not element.block_id.is_empty():
					Global.release_block(element.block_id)
		
		# Очищаем слот и удаляем элемент
		if is_instance_valid(slot):
			slot.command = null
		element.queue_free()

## Update all root blocks
func update_root_blocks() -> void:
	if is_inside_tree():
		var root_blocks = get_tree().get_nodes_in_group("blocks").filter(
			func(block): return is_instance_valid(block) and !block.parent_slot)
		
		for block in root_blocks:
			update_block_recursive(block)

## Update block recursively
func update_block_recursive(block: Block) -> void:
	if !is_instance_valid(block):
		return
	
	# Восстанавливаем связь с родительским слотом, если она есть
	if block.parent_slot and is_instance_valid(block.parent_slot):
		block.parent_slot.command = block
	
	block.slot_manager.shift_commands_up()
	block.slot_manager.update_slots()
	
	for slot in block.slot_manager.slots:
		if is_instance_valid(slot.command) and slot.command is Block:
			update_block_recursive(slot.command)
	
	block.update_command_positions(block.z_index)

func clear_all() -> void:
	await clear_all_elements()
	Global.reset_all_blocks()
	Global.reset_special_commands()
