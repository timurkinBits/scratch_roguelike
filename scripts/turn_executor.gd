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
	await block_executor.check_and_execute_conditions(trigger_time)
	return is_instance_valid(player)

## Обработка общих условий
func _process_generic_conditions() -> bool:
	await block_executor.check_and_execute_conditions("")
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

## Обработка смерти игрока
func _on_player_dead() -> void:
	await end_game_player_dead()

## Завершение игры при смерти игрока
func end_game_player_dead() -> void:
	block_executor.clear_outlines()
	
	await block_executor.clear_all()
	
	# Отключаем кнопку и показываем экран поражения
	if button:
		button.disabled = true
	room.visible = false
	defeat_label.visible = true
	
	# Возвращаемся в меню через 2 секунды
	if is_inside_tree():
		await get_tree().create_timer(2).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
