extends Node

## Основные узлы сцены
@onready var button: Button = $"../../UI/Button"
@onready var player: Player = $"../../Room/Player"
@onready var table: Table = $".."
@onready var hp_bar: UI = $"../../UI"
@export var ui_node: UI
@export var room: Node2D
@onready var defeat_label: Label = ui_node.get_node('DefeatLabel')

## Массив визуальных индикаторов выполнения
var outline_panels: Array[Node] = []

## Инициализация
func _ready() -> void:
	# Подключение сигналов
	if button:
		button.pressed.connect(_on_button_pressed)
	if player:
		player.tree_exited.connect(_on_player_dead)
	
	# Сброс счетчиков
	Global.reset_remaining_points()
	Global.reset_remaining_blocks()

## Обработка нажатия на кнопку "Выполнить"
func _on_button_pressed() -> void:
	if !is_instance_valid(player):
		return
	
	# Отключаем взаимодействие и устанавливаем флаг начала хода
	_disable_interactions()
	table.is_turn_in_progress = true
	
	# Выполняем все фазы хода
	await _execute_turn_phases()

## Выполнение всех фаз хода
func _execute_turn_phases() -> void:
	# Фаза 1: Выполнение начальных условий
	if !await _process_turn_phase("начало хода"): return
	
	# Фаза 2: Проверка общих условий
	if !await _process_generic_conditions(): return
	
	# Фаза 3: Выполнение основных команд
	if !await _clear_main_commands(): return
	
	# Фаза 4: Ход врагов
	if !await _process_enemy_turns(): return
	
	# Фаза 5: Финальная проверка условий
	if !await _process_generic_conditions(): return
	
	# Фаза 6: Очистка всех команд
	if !await _clear_all(): return
	
	# Фаза 7: Подготовка к следующему ходу
	await _prepare_next_turn()

## Отключение всех интерактивных элементов
func _disable_interactions() -> void:
	button.disabled = true
	
	# Отключаем команды и блоки
	for command in get_tree().get_nodes_in_group("commands"):
		command.change_settings(false)
	for block in get_tree().get_nodes_in_group("blocks"):
		block.change_settings(false)

## Обработка фазы хода с определенным триггером
func _process_turn_phase(trigger_time: String) -> bool:
	await check_and_execute_conditions(trigger_time)
	return is_instance_valid(player)

## Обработка общих условий
func _process_generic_conditions() -> bool:
	await check_and_execute_conditions("")
	return is_instance_valid(player)

## Обработка ходов всех врагов
func _process_enemy_turns() -> bool:
	for enemy in get_tree().get_nodes_in_group('enemies'):
		if is_instance_valid(enemy):
			await enemy.take_turn()
			if !is_instance_valid(player):
				return false
	return true

## Очистка основных команд
func _clear_main_commands() -> bool:
	await clear_main_commands()
	return is_instance_valid(player)

## Очистка всех команд
func _clear_all() -> bool:
	await clear_all()
	return is_instance_valid(player)

## Подготовка к следующему ходу
func _prepare_next_turn() -> void:
	if !is_instance_valid(player):
		return
	
	# Небольшая задержка для плавности
	await get_tree().create_timer(0.2).timeout
	
	# Сброс защиты и флага хода
	ui_node.reset_defense()
	table.is_turn_in_progress = false
	button.disabled = false
	
	# Показываем двери, если врагов не осталось
	if get_tree().get_nodes_in_group('enemies').is_empty():
		room.doors.visible = true

## Проверка и выполнение блоков условий
func check_and_execute_conditions(trigger_time: String) -> bool:
	# Получаем все блоки условий
	var condition_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and block.type == Block.BlockType.CONDITION)
	
	for block in condition_blocks:
		# Проверяем соответствие триггеру или условию
		var should_execute = false
		
		if trigger_time != "":
			# Явный триггер времени
			should_execute = block.text == trigger_time
		else:
			# Триггер условия
			should_execute = block.text != "начало хода" and check_condition(block.text)
		
		if should_execute:
			await execute_block(block)
			if !is_instance_valid(player):
				return false
	
	return true

## Очистка основных команд (не затрагивая условные блоки кроме "начало хода")
func clear_main_commands() -> void:
	if !is_inside_tree():
		return
	
	# Собираем команды для удаления
	var commands_to_free = get_tree().get_nodes_in_group("commands").filter(
		func(command): 
			if !is_instance_valid(command) or !command.slot or !command.slot.block:
				return false
			
			var block = command.slot.block
			
			# Очищаем команды из обычных блоков и из блока "начало хода"
			return block.type != Block.BlockType.CONDITION || block.text == "начало хода"
	)
	
	# Создаем словарь для отслеживания затронутых блоков
	var affected_blocks = {}
	
	# Отсоединяем команды от слотов и запоминаем затронутые блоки
	for command in commands_to_free:
		if command.slot and command.slot.block:
			affected_blocks[command.slot.block] = true
	
	# Удаляем команды
	await clear_commands(commands_to_free)
	
	# Обновляем затронутые блоки
	for block in affected_blocks.keys():
		if is_instance_valid(block):
			block.slot_manager.shift_commands_up()
			block.update_slots()
	
	# Обновляем все корневые блоки для гарантии согласованности
	var root_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and !block.parent_slot
	)
	
	for block in root_blocks:
		update_block_recursive(block)
		
func _update_block_recursive(block: Block) -> void:
	if !is_instance_valid(block):
		return
	
	# Принудительно обновляем слоты
	block.slot_manager.shift_commands_up()
	block.slot_manager.update_slots()
	
	# Обновляем все дочерние блоки
	for slot in block.slot_manager.slots:
		if slot.command and slot.command is Block:
			_update_block_recursive(slot.command)
	
	# Обновляем позиции всех команд
	var z_index_base = block.z_index
	block.update_command_positions(z_index_base)
		
func _update_block_hierarchy(block: Block) -> void:
	if !is_instance_valid(block):
		return
	
	block.slot_manager.shift_commands_up()
	block.slot_manager.update_slots()
	
	# Рекурсивно обновляем все вложенные блоки
	for slot in block.slot_manager.slots:
		if slot.command and slot.command is Block:
			_update_block_hierarchy(slot.command)
			
	# Обновляем позиции всех команд в блоке
	block.update_command_positions(block.z_index)

## Проверка выполнения условия
func check_condition(condition: String) -> bool:
	match condition:
		"начало хода":
			return true
		"здоровье < 50%":
			return is_instance_valid(player) and player.hp < 5
		_:
			return false

## Обработка смерти игрока
func _on_player_dead() -> void:
	await end_game_player_dead()

## Завершение игры при смерти игрока
func end_game_player_dead() -> void:
	# Очищаем все панели-индикаторы
	for panel in outline_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	outline_panels.clear()
	
	await clear_all()
	
	# Отключаем кнопку и показываем экран поражения
	if button:
		button.disabled = true
	room.visible = false
	defeat_label.visible = true
	
	# Возвращаемся в меню через 2 секунды
	if is_inside_tree():
		await get_tree().create_timer(2).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

## Выполнение блока команд
func execute_block(block: Block) -> void:
	if !is_instance_valid(player) or !is_instance_valid(block):
		return
	
	# Создаем визуальный индикатор выполнения
	var outline = create_outline_panel(block)
	
	# Определяем количество итераций (для циклов)
	var iterations = 1
	if block.type == Block.BlockType.LOOP:
		iterations = max(1, block.loop_count)
	
	# Применяем свойства улучшения для блоков способностей
	if block.type == Block.BlockType.ABILITY:
		_apply_ability_properties(block)
	
	# Выполняем итерации
	for i in iterations:
		if !is_instance_valid(player):
			break
		
		# Выполняем все команды в слотах
		for slot in block.slot_manager.slots:
			if !is_instance_valid(player) or !is_instance_valid(slot.command):
				break
			
			if slot.command is Block:
				await execute_block(slot.command)
			elif slot.command is Command:
				await execute_command(slot.command)
		
		# Задержка между итерациями цикла
		if i < iterations - 1 and is_instance_valid(player):
			await get_tree().create_timer(0.2).timeout
	
	# Очищаем индикатор
	if is_instance_valid(outline):
		outline_panels.erase(outline)
		outline.queue_free()

## Применение свойств улучшения к командам
func _apply_ability_properties(block: Block) -> void:
	for slot in block.slot_manager.slots:
		if slot.command is Command:
			slot.command.additional_properties = block.text

## Создание визуального индикатора выполнения
func create_outline_panel(node: Node2D) -> Panel:
	if !is_instance_valid(node) or !node.has_node("Texture"):
		return null
	
	var texture = node.get_node("Texture")
	var panel = Panel.new()
	panel.size = texture.size + Vector2(4, 4)
	panel.position = Vector2(-2, -2)
	
	# Настройка стиля панели
	var style = StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 10
	
	node.add_child(panel)
	outline_panels.append(panel)
	
	return panel

## Выполнение отдельной команды
func execute_command(command: Command) -> void:
	if !is_instance_valid(player) or !is_instance_valid(command):
		return
	
	# Создаем визуальный индикатор выполнения
	var outline = create_outline_panel(command)
	
	# Применяем модификаторы команд
	_apply_command_modifiers(command)
	
	# Выполняем команду в зависимости от типа
	match command.type:
		Command.TypeCommand.MOVE:
			await player.move(command.value)
		Command.TypeCommand.TURN:
			var direction = "right" if command.value == 90 else "left" if command.value == -90 else "around"
			await player.turn(direction)
		Command.TypeCommand.ATTACK:
			await player.attack(command.value)
		Command.TypeCommand.USE:
			await player.use()
		Command.TypeCommand.HEAL:
			await player.add_hp(command.value)
		Command.TypeCommand.DEFENSE:
			await player.add_defense(command.value)
	
	# Очищаем индикатор
	if is_instance_valid(outline):
		outline_panels.erase(outline)
		outline.queue_free()

## Применение модификаторов к команде
func _apply_command_modifiers(command: Command) -> void:
	match [command.additional_properties, command.type]:
		['+1 урон', Command.TypeCommand.ATTACK]:
			command.value += 1
		['+1 движ.', Command.TypeCommand.MOVE]:
			command.value += 1
		['+1 защита', Command.TypeCommand.DEFENSE]:
			command.value += 1

func collect_commands(block: Block, commands: Array[Node]) -> void:
	if !is_instance_valid(block):
		return
	
	# Массив для хранения индексов, с которых были удалены команды
	var removed_indices = []
	
	for i in range(block.slot_manager.slots.size()):
		var slot = block.slot_manager.slots[i]
		if !is_instance_valid(slot) or !slot.command:
			continue
		
		if slot.command is Block:
			if block.type == Block.BlockType.CONDITION and block.text != "начало хода":
				# Пропускаем блоки в условиях (кроме "начало хода")
				continue
			
			# Рекурсивно собираем команды из вложенных блоков
			collect_commands(slot.command, commands)
		elif slot.command is Command:
			# Пропускаем команды в блоках условий (кроме "начало хода")
			if block.type == Block.BlockType.CONDITION and block.text != "начало хода":
				continue
			
			# Добавляем команду на удаление
			commands.append(slot.command)
			# Отсоединяем от слота
			slot.command = null
			removed_indices.append(i)
	
	# Если были удалены команды, вызываем shift_commands_up()
	if !removed_indices.is_empty():
		block.slot_manager.shift_commands_up()

## Очистка команд с анимацией
func clear_commands(commands_to_free: Array[Node]) -> void:
	if commands_to_free.is_empty():
		return
	
	# Анимация исчезновения
	var tween = create_tween().set_parallel(true)
	for command in commands_to_free:
		if is_instance_valid(command) and command.has_node("Texture"):
			tween.tween_property(command.get_node("Texture"), "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# Удаление команд
	for command in commands_to_free:
		if is_instance_valid(command):
			command.queue_free()

## Очистка всех команд (кроме команд в блоках условий, не "начало хода")
func clear_all() -> void:
	if !is_inside_tree():
		return
	
	var commands_to_free: Array[Node] = []
	var affected_blocks = []
	
	# Получаем все корневые блоки
	var root_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and (!block.parent_slot or !block.parent_slot.block)
	)
	
	# Собираем команды для удаления от корневых блоков
	for block in root_blocks:
		if block.type != Block.BlockType.CONDITION or block.text == "начало хода":
			_collect_commands_recursive(block, commands_to_free, affected_blocks)
	
	# Собираем все оставшиеся команды на столе
	var all_commands = get_tree().get_nodes_in_group("commands")
	for command in all_commands:
		if is_instance_valid(command) and not command.is_menu_command and not commands_to_free.has(command):
			# Проверяем, не находится ли команда в сохраняемом блоке условий
			var in_preserved_condition = false
			if command.slot and command.slot.block and command.slot.block.type == Block.BlockType.CONDITION:
				in_preserved_condition = command.slot.block.text != "начало хода"
			
			if !in_preserved_condition:
				commands_to_free.append(command)
				if command.slot and command.slot.block and not affected_blocks.has(command.slot.block):
					affected_blocks.append(command.slot.block)
	
	await clear_commands(commands_to_free)
	
	# Обновляем иерархию блоков, начиная с корневых
	for block in root_blocks:
		_update_block_hierarchy(block)
		
func _collect_commands_recursive(block: Block, commands: Array[Node], affected_blocks: Array) -> void:
	if !is_instance_valid(block):
		return
	
	if not affected_blocks.has(block):
		affected_blocks.append(block)
	
	for slot in block.slot_manager.slots:
		if !is_instance_valid(slot.command):
			continue
		
		if slot.command is Block:
			if block.type != Block.BlockType.CONDITION or block.text == "начало хода":
				_collect_commands_recursive(slot.command, commands, affected_blocks)
		elif slot.command is Command:
			# Пропускаем команды в блоках условий (кроме "начало хода")
			if block.type == Block.BlockType.CONDITION and block.text != "начало хода":
				continue
			
			commands.append(slot.command)
			slot.command = null
			
func update_block_recursive(block: Block) -> void:
	if !is_instance_valid(block):
		return
	
	block.slot_manager.update_slots()
	
	# Обновляем все дочерние блоки
	for slot in block.slot_manager.slots:
		if slot.command and slot.command is Block:
			update_block_recursive(slot.command)
