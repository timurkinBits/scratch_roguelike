extends Node
class_name TurnExecutor

## Основные узлы сцены
@onready var button: Button = $"../../UI/Button"
@onready var player: Player = $"../../Room/Player"
@onready var table: Table = $".."
@onready var hp_bar: UI = $"../../UI"
@export var ui_node: UI
@export var room: Node2D
@onready var defeat_label: Label = ui_node.get_node('DefeatLabel')

## Исполнители команд и блоков
@onready var block_executor: BlockExecutor = $BlockExecutor
@onready var command_executor: CommandExecutor = $CommandExecutor

## Инициализация
func _ready() -> void:
	# Подключение сигналов
	if button:
		button.pressed.connect(_on_button_pressed)
	if player:
		player.tree_exited.connect(_on_player_dead)

## Обработка нажатия на кнопку "Выполнить"
func _on_button_pressed() -> void:
	if !is_instance_valid(player):
		return
	
	# Отключаем взаимодействие и устанавливаем флаг начала хода
	_turn_interactions(false)
	for command in get_tree().get_nodes_in_group("commands"):
		command.change_settings(false)
	table.is_turn_in_progress = true
	
	# Выполняем все фазы хода
	await _execute_turn_phases()

## Выполнение всех фаз хода
func _execute_turn_phases() -> void:
	# Фаза 1: Выполнение блоков "начало хода"
	if !await _execute_start_turn(): return
	
	# Фаза 2: Очистка основных команд
	if !await _clear_main_commands(): return
	
	# Фаза 3: Ход врагов
	if !await _process_enemy_turns(): return
	
	# Фаза 4: Очистка всех команд
	if !await _clear_all(): return
	
	# Фаза 5: Подготовка к следующему ходу
	await _prepare_next_turn()

## Отключение всех интерактивных элементов
func _turn_interactions(turn: bool) -> void:
	button.disabled = !turn
	
	# Отключаем команды и блоки
	if turn:
		table.modulate = Color(table.modulate, 1)
	else:
		table.modulate = Color(table.modulate, 0.5)

## Выполнение блоков "начало хода"
func _execute_start_turn() -> bool:
	await block_executor.execute_start_turn_blocks()
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
	await block_executor.clear_main_commands()
	return is_instance_valid(player)

## Очистка всех команд
func _clear_all() -> bool:
	await block_executor.clear_all()
	# Возвращаем особые команды после очистки всех команд
	await _reset_special_commands()
	return is_instance_valid(player)

## Сброс особых команд и возврат их в слоты (НЕ сбрасывает очки!)
func _reset_special_commands() -> void:
	# Освобождаем все особые команды на столе
	if is_inside_tree():
		for command in get_tree().get_nodes_in_group("special_commands"):
			if is_instance_valid(command) and not command.is_menu_card:
				# Для одноразовых команд - потребляем при завершении хода
				if command.special_id != "" and not command.has_value:
					Global.consume_special_command(command.special_id)
				# Для команд с очками - просто освобождаем
				elif command.special_id != "" and command.has_value:
					Global.release_special_command(command.special_id)
				
				# Удаляем команду со стола
				command.queue_free()
	
	# Ждем один кадр чтобы команды удалились
	await get_tree().process_frame
	
	# НЕ сбрасываем очки особых команд здесь!
	# Очки сбрасываются только при переходе в новую комнату

## Подготовка к следующему ходу
func _prepare_next_turn() -> void:
	if !is_instance_valid(player):
		return
	
	# Небольшая задержка для плавности
	await get_tree().process_frame
	
	ui_node.reset_defense()
	table.is_turn_in_progress = false
	_turn_interactions(true)
	
	# Показываем двери, если врагов не осталось
	if get_tree().get_nodes_in_group('enemies').is_empty():
		for exit_door in room.doors:
			exit_door.get_node('button').visible = true
		# Генерируем типы комнат только если комната очищена от врагов
		room.random_types_rooms()

## Обработка смерти игрока
func _on_player_dead() -> void:
	await end_game_player_dead()

## Завершение игры при смерти игрока
func end_game_player_dead() -> void:
	block_executor.clear_outlines()
	
	await block_executor.clear_all()
	
	# При смерти игрока полностью сбрасываем особые команды
	await _reset_special_commands_on_death()
	
	# Отключаем кнопку и показываем экран поражения
	_turn_interactions(false)
	room.visible = false
	defeat_label.visible = true
	
	# Возвращаемся в меню через 2 секунды
	if is_inside_tree():
		await get_tree().create_timer(2).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		Global.coins = 0

## Полный сброс особых команд при смерти игрока
func _reset_special_commands_on_death() -> void:
	# Освобождаем все особые команды на столе
	if is_inside_tree():
		for command in get_tree().get_nodes_in_group("special_commands"):
			if is_instance_valid(command) and not command.is_menu_card:
				# Освобождаем команду в Global
				if command.special_id != "":
					Global.release_special_command(command.special_id)
				# Удаляем команду со стола
				command.queue_free()
	
	# Ждем один кадр чтобы команды удалились
		await get_tree().process_frame
	
	# Полностью сбрасываем все особые команды (включая очки)
	Global.reset_special_commands()
