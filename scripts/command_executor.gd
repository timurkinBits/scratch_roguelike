extends Node

@onready var button: Button = $"../../UI/Button"
@onready var player: Player = $"../../Room/Player"
@onready var table: Table = $".."
@onready var hp_bar: UI = $"../../UI"

@export var ui_node: UI
@export var room: Node2D
@onready var defeat_label: Label = ui_node.get_node('DefeatLabel')

var outline_panels: Array[Node] = []

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)
	if player:
		player.tree_exited.connect(_on_player_dead)
	Global.reset_remaining_points()

func _on_button_pressed() -> void:
	if !is_instance_valid(player):
		return
	# Отключаем взаимодействие во время хода
	_disable_interactions()
	table.is_turn_in_progress = true  # Устанавливаем флаг начала хода
	
	# Process turn phases
	if !await _process_turn_phase("начало хода"): return
	if !await _process_generic_conditions(): return
	if !await _clear_main_commands(): return
	
	# Enemy turn
	if !await _process_enemy_turns(): return
	
	if !await _process_generic_conditions(): return
	if !await _clear_all(): return
	
	# Reset for next turn
	await _prepare_next_turn()

func _disable_interactions() -> void:
	button.disabled = true
	for command in get_tree().get_nodes_in_group("commands"):
		command.change_settings(false)

func _process_turn_phase(trigger_time: String) -> bool:
	await check_and_execute_conditions(trigger_time)
	return is_instance_valid(player)

func _process_generic_conditions() -> bool:
	await check_and_execute_conditions("")
	return is_instance_valid(player)

func _process_enemy_turns() -> bool:
	for enemy in get_tree().get_nodes_in_group('enemies'):
		if enemy:
			await enemy.take_turn()
			if !is_instance_valid(player):
				return false
	return true

func _clear_main_commands() -> bool:
	await clear_main_commands()
	return is_instance_valid(player)

func _clear_all() -> bool:
	await clear_all()
	return is_instance_valid(player)

func _prepare_next_turn() -> void:
	if !is_instance_valid(player):
		return
	await get_tree().create_timer(0.2).timeout
	ui_node.reset_defense()
	table.is_turn_in_progress = false  # Сбрасываем флаг окончания хода
	button.disabled = false
	
	# Show doors if no enemies
	if get_tree().get_nodes_in_group('enemies').is_empty():
		for door in get_tree().get_nodes_in_group('level_door'):
			door.visible = true

func check_and_execute_conditions(trigger_time: String) -> bool:
	# Get condition blocks
	var condition_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return block.type == Block.BlockType.CONDITION)
	
	for block in condition_blocks:
		# Match time-based triggers exactly, or check non-time conditions when trigger_time is empty
		if (trigger_time != "" and block.text == trigger_time) or \
		   (trigger_time == "" and block.text != "начало хода" and check_condition(block.text)):
			await execute_block(block)
			if !is_instance_valid(player):
				return false
				
	return true

func clear_main_commands() -> void:
	if !is_inside_tree():
		return
	
	var commands_to_free = get_tree().get_nodes_in_group("commands").filter(
		func(command): 
			return is_instance_valid(command) and command.slot and command.slot.block and \
				   command.slot.block.type != Block.BlockType.CONDITION)
	
	# Clear collected commands and nullify their slots
	for command in commands_to_free:
		command.slot.command = null
		
	await clear_commands(commands_to_free)
	
	# Update slots in non-condition blocks
	for block in get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and block.type != Block.BlockType.CONDITION
	):
		block.update_slots()

func check_condition(condition: String) -> bool:
	match condition:
		"начало хода":
			return true
		"здоровье < 50%":
			return is_instance_valid(player) and player.hp < 5
		_:
			return false

func _on_player_dead() -> void:
	await end_game_player_dead()

func end_game_player_dead() -> void:
	for panel in outline_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	outline_panels.clear()
	await clear_all()
	
	if button:
		button.disabled = true
	room.visible = false
	defeat_label.visible = true
	if is_inside_tree():
		await get_tree().create_timer(2).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func execute_block(block: Block) -> void:
	if !is_instance_valid(player) or !is_instance_valid(block):
		return
		
	var outline = create_outline_panel(block)
	var iterations = max(1, block.loop_count) if block.type == Block.BlockType.LOOP else 1
	
	# Set ability properties
	if block.type == Block.BlockType.ABILITY:
		_apply_ability_properties(block)

	# Process iterations
	for i in iterations:
		if !is_instance_valid(player):
			break
			
		# Process slots
		for slot in block.slots:
			if !is_instance_valid(player) or !is_instance_valid(slot.command):
				break
				
			if slot.command is Block:
				await execute_block(slot.command)
			elif slot.command is Command:
				await execute_command(slot.command)
		
		# Add delay between iterations
		if i < iterations - 1 and is_instance_valid(player):
			await get_tree().create_timer(0.2).timeout
			
	# Clean up outline
	if is_instance_valid(outline):
		outline_panels.erase(outline)
		outline.queue_free()

func _apply_ability_properties(block: Block) -> void:
	for slot in block.slots:
		if slot.command is Command:
			slot.command.additional_properties = block.text

func create_outline_panel(node: Node2D) -> Panel:
	if !is_instance_valid(node) or !node.has_node("Texture"):
		return null
		
	var texture = node.get_node("Texture")
	var panel = Panel.new()
	panel.size = texture.size + Vector2(4, 4)
	panel.position = Vector2(-2, -2)
	
	var style = StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 10
	
	node.add_child(panel)
	outline_panels.append(panel)
	
	return panel

func execute_command(command: Command) -> void:
	if !is_instance_valid(player) or !is_instance_valid(command):
		return
		
	var outline = create_outline_panel(command)
	
	# Apply command modifiers
	_apply_command_modifiers(command)
	
	# Execute command based on type
	match command.type:
		Command.TypeCommand.MOVE: await player.move(command.value)
		Command.TypeCommand.TURN: 
			# Определяем направление поворота по значению угла
			var direction = "right" if command.value == 90 else "left" if command.value == -90 else "around"
			await player.turn(direction)
		Command.TypeCommand.ATTACK: await player.attack(command.value)
		Command.TypeCommand.USE: await player.use()  # Добавлена обработка команды USE
		Command.TypeCommand.HEAL: await player.add_hp(command.value)
		Command.TypeCommand.DEFENSE: await player.add_defense(command.value)
	
	# Clean up outline
	if is_instance_valid(outline):
		outline_panels.erase(outline)
		outline.queue_free()

func _apply_command_modifiers(command: Command) -> void:
	if command.additional_properties == '+1 урон' and command.type == Command.TypeCommand.ATTACK:
		command.value += 1
	elif command.additional_properties == '+1 перемещение' and command.type == Command.TypeCommand.MOVE:
		command.value += 1

func collect_commands(block: Block, commands: Array[Node]) -> void:
	if !is_instance_valid(block):
		return
		
	for slot in block.slots:
		if !is_instance_valid(slot.command):
			continue
			
		if slot.command is Block:
			collect_commands(slot.command, commands)
			slot.command.update_slots()
		elif slot.command is Command:
			commands.append(slot.command)
			slot.command = null

func clear_commands(commands_to_free: Array[Node]) -> void:
	if commands_to_free.is_empty():
		return
		
	# Fade out animation
	var tween = create_tween().set_parallel(true)
	for command in commands_to_free:
		if is_instance_valid(command) and command.has_node("Texture"):
			tween.tween_property(command.get_node("Texture"), "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# Free commands
	for command in commands_to_free:
		if is_instance_valid(command):
			command.queue_free()

func clear_all() -> void:
	if !is_inside_tree():
		return
		
	var blocks = get_tree().get_nodes_in_group("blocks")
	var commands_to_free: Array[Node] = []
	
	# First collect commands from blocks
	for block in blocks:
		if is_instance_valid(block):
			collect_commands(block, commands_to_free)
	
	# Then collect all remaining commands on the table (not in slots)
	var all_commands = get_tree().get_nodes_in_group("commands")
	for command in all_commands:
		if is_instance_valid(command) and not command.is_menu_command and not commands_to_free.has(command):
			commands_to_free.append(command)
	
	await clear_commands(commands_to_free)
	
	for block in blocks:
		if is_instance_valid(block):
			block.update_slots()
