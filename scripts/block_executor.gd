extends Node
class_name BlockExecutor

## Visual execution indicators
var outline_panels: Array[Node] = []

@onready var player: Player = $"../../../Room/Player"
@onready var command_executor: CommandExecutor = $"../CommandExecutor"

func clear_start_turn_commands_preserve_blocks(start_turn_block: Block) -> void:
	if not is_instance_valid(start_turn_block) or \
	   start_turn_block.type != ItemData.BlockType.CONDITION or \
	   start_turn_block.text != "начало хода":
		return
	
	# Шаг 1: Собираем команды для удаления
	var commands_to_remove = []
	for slot in start_turn_block.slot_manager.slots:
		if is_instance_valid(slot) and is_instance_valid(slot.command) and slot.command is Command:
			commands_to_remove.append(slot.command)
	
	# Шаг 2: Удаляем команды с анимацией
	if not commands_to_remove.is_empty():
		var tween = create_tween().set_parallel(true)
		for command in commands_to_remove:
			if is_instance_valid(command) and command.has_node("Texture"):
				tween.tween_property(command.get_node("Texture"), "modulate:a", 0.0, 0.3)
		await tween.finished
		
		for command in commands_to_remove:
			if is_instance_valid(command):
				command.slot.command = null
				command.queue_free()
	
	# Шаг 3: Обновляем слоты с сохранением блоков
	start_turn_block.slot_manager.update_slots()
	
	
## Check and execute condition blocks
func check_and_execute_conditions(trigger_time: String) -> bool:
	var condition_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and block.type == ItemData.BlockType.CONDITION)
	
	for block in condition_blocks:
		if not is_instance_valid(block):
			continue
		var should_execute = trigger_time != "" if block.text == trigger_time else \
		block.text != "начало хода" and check_condition(block.text)
		
		if should_execute:
			await execute_block(block)
			if !is_instance_valid(player):
				return false
	
	return true

## Check if a condition is met
func check_condition(condition: String) -> bool:
	match condition:
		"начало хода":
			return true
		"здоровье < 50%":
			return is_instance_valid(player) and player.hp < 5
		_:
			return false

## Execute a block of commands
func execute_block(block: Block) -> void:
	if !is_instance_valid(player) or !is_instance_valid(block):
		return
	
	# Create visual execution indicator
	var outline = create_outline_panel(block)
	
	# Determine iterations (for loops)
	var iterations = max(1, block.loop_count) if (block.type == ItemData.BlockType.LOOP) else 1
	
	# Apply ability properties
	if block.type == ItemData.BlockType.ABILITY:
		_apply_ability_properties(block)
	
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
				await command_executor.execute_command(slot.command)
		
		# Delay between loop iterations
		if i < iterations - 1 and is_instance_valid(player):
			await get_tree().create_timer(0.2).timeout
	
	# Remove indicator
	remove_outline(outline)

## Apply ability properties to commands
func _apply_ability_properties(block: Block) -> void:
	for slot in block.slot_manager.slots:
		if slot.command is Command:
			slot.command.additional_properties = block.text

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

func clear_main_commands() -> void:
	if not is_inside_tree():
		return
	
	var start_turn_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and \
					  block.type == ItemData.BlockType.CONDITION and \
					  block.text == "начало хода")
	
	for block in start_turn_blocks:
		await clear_start_turn_commands_preserve_blocks(block)

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

## Clear commands with animation
func clear_commands(commands_to_free: Array) -> void:
	if commands_to_free.is_empty():
		return
	
	# Fade-out animation
	var tween = create_tween().set_parallel(true)
	for command in commands_to_free:
		if is_instance_valid(command) and command.has_node("Texture"):
			tween.tween_property(command.get_node("Texture"), "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# Free commands
	for command in commands_to_free:
		if is_instance_valid(command):
			if command.slot:
				command.slot.command = null
			command.queue_free()

func clear_all() -> void:
	
	# Обрабатываем блоки "начало хода"
	if is_inside_tree():
		var start_turn_blocks = get_tree().get_nodes_in_group("blocks").filter(
			func(block): return is_instance_valid(block) and \
						  block.type == ItemData.BlockType.CONDITION and \
						  block.text == "начало хода")
		for block in start_turn_blocks:
			await clear_start_turn_commands_preserve_blocks(block)
	
	# Собираем команды для удаления из остальных блоков
	var commands_to_free = []
	var blocks_to_update = []
	if is_inside_tree():
		for block in get_tree().get_nodes_in_group("blocks"):
			if !is_instance_valid(block) or block.type == ItemData.BlockType.CONDITION:
				continue
			for slot in block.slot_manager.slots:
				if !is_instance_valid(slot) or !is_instance_valid(slot.command):
					continue
				if slot.command is Command:
					commands_to_free.append(slot.command)
					slot.command = null
					if !blocks_to_update.has(block):
						blocks_to_update.append(block)
				elif slot.command is Block:
					_collect_commands_from_block(slot.command, commands_to_free, blocks_to_update)
	
	# Удаляем команды с анимацией
	await clear_commands(commands_to_free)
	
	# Обновляем слоты затронутых блоков
	for block in blocks_to_update:
		if is_instance_valid(block):
			block.slot_manager.shift_commands_up()
			block.slot_manager.adjust_slot_count()
			block.slot_manager.update_all_slot_positions()
	
	# Обновляем иерархию блоков
	update_root_blocks()

func _collect_commands_from_block(block: Block, commands: Array, blocks_to_update: Array) -> void:
	if !is_instance_valid(block) or block.type == ItemData.BlockType.CONDITION:
		return
	
	var had_commands = false
	
	for slot in block.slot_manager.slots:
		if !is_instance_valid(slot) or !is_instance_valid(slot.command):
			continue
			
		if slot.command is Command:
			# Собираем только команды, но не блоки
			commands.append(slot.command)
			slot.command = null
			had_commands = true
		elif slot.command is Block:
			# Для блока рекурсивно вызываем эту функцию,
			# но не изменяем связь с текущим слотом
			_collect_commands_from_block(slot.command, commands, blocks_to_update)
	
	if had_commands and !blocks_to_update.has(block):
		blocks_to_update.append(block)
