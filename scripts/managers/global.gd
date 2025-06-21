extends Node

signal points_changed
signal coins_changed
signal inventory_changed  # Для покупки новых блоков
signal block_availability_changed  # Для изменения доступности блоков
signal special_command_availability_changed

enum RoomType {
	NORMAL,
	ELITE,
	SHOP,
	CHALLENGE
}

var points: Dictionary = {
	Command.TypeCommand.MOVE: 10,
	Command.TypeCommand.ATTACK: 30,
	Command.TypeCommand.HEAL: 3,
	Command.TypeCommand.DEFENSE: 3
}

var coins: int = 999
var remaining_points: Dictionary = {}
var max_slots_for_blocks: int = 8
var max_slots_for_commands: int = 1

# Block system - теперь работает только с текстом блоков
var purchased_blocks: Array[Dictionary] = []
var next_block_id: int = 0

# Special commands system - с системой очков
var purchased_special_commands: Array[Dictionary] = []
var next_special_command_id: int = 0
var special_command_points: Dictionary = {}  # Очки для особых команд по ID
var remaining_special_points: Dictionary = {}  # Оставшиеся очки для особых команд

func _ready() -> void:
	reset_remaining_points()
	reset_all_blocks()

# Points management
func reset_remaining_points() -> void:
	remaining_points = points.duplicate()
	# Также сбрасываем очки особых команд
	reset_special_command_points()
	points_changed.emit()

func get_remaining_points(command_type) -> int:
	if command_type in [Command.TypeCommand.USE, Command.TypeCommand.TURN]:
		return 999
	return remaining_points.get(command_type, 0)

func use_points(command_type, value) -> void:
	if command_type in [Command.TypeCommand.USE, Command.TypeCommand.TURN]:
		return
	
	if command_type in remaining_points:
		remaining_points[command_type] = max(0, remaining_points[command_type] - value)
		points_changed.emit()

func release_points(command_type, value) -> void:
	if command_type in [Command.TypeCommand.USE, Command.TypeCommand.TURN]:
		return
	
	if command_type in remaining_points:
		remaining_points[command_type] = min(points[command_type], remaining_points[command_type] + value)
		points_changed.emit()

# === SPECIAL COMMAND POINTS MANAGEMENT ===

func reset_special_command_points() -> void:
	remaining_special_points.clear()
	for command_data in purchased_special_commands:
		var command_id = command_data.id
		if special_command_points.has(command_id):
			remaining_special_points[command_id] = special_command_points[command_id]

func get_remaining_special_points(command_id: String) -> int:
	return remaining_special_points.get(command_id, 0)

# ИСПРАВЛЕНО: Метод use_special_points теперь вызывает сигнал доступности
func use_special_points(command_id: String, value: int) -> void:
	if command_id in remaining_special_points:
		remaining_special_points[command_id] = max(0, remaining_special_points[command_id] - value)
		points_changed.emit()
		special_command_availability_changed.emit()  # ДОБАВЛЕНО

# ИСПРАВЛЕНО: Метод release_special_points теперь вызывает сигнал доступности
func release_special_points(command_id: String, value: int) -> void:
	if command_id in remaining_special_points and command_id in special_command_points:
		var max_points = special_command_points[command_id]
		remaining_special_points[command_id] = min(max_points, remaining_special_points[command_id] + value)
		points_changed.emit()
		special_command_availability_changed.emit()  # ДОБАВЛЕНО

# Coins management
func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit()

func get_coins() -> int:
	return coins

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_changed.emit()
		return true
	return false

# Block management - упрощенная система без типов
func generate_block_id() -> String:
	var id = "block_" + str(next_block_id)
	next_block_id += 1
	return id

func purchase_block(block_text: String, count: int = 1) -> void:
	for i in range(count):
		var new_block = {
			"id": generate_block_id(),
			"text": block_text,
			"used": false
		}
		purchased_blocks.append(new_block)
	
	points_changed.emit()
	inventory_changed.emit()  # Только при покупке

func can_use_block_by_id(block_id: String) -> bool:
	for block in purchased_blocks:
		if block.id == block_id:
			return not block.used
	return false

func use_block(block_id: String) -> bool:
	for block in purchased_blocks:
		if block.id == block_id and not block.used:
			block.used = true
			points_changed.emit()
			block_availability_changed.emit()  # Отдельный сигнал для доступности
			return true
	return false

func release_block(block_id: String) -> void:
	for block in purchased_blocks:
		if block.id == block_id and block.used:
			block.used = false
			points_changed.emit()
			block_availability_changed.emit()  # Отдельный сигнал для доступности
			return

func reset_all_blocks() -> void:
	for block in purchased_blocks:
		block.used = false
	points_changed.emit()
	block_availability_changed.emit()  # Отдельный сигнал для доступности

func get_all_purchased_blocks() -> Array:
	return purchased_blocks.duplicate()

# Проверка доступности блока по тексту
func can_use_block(block_text: String) -> bool:
	for block in purchased_blocks:
		if block.text == block_text and not block.used:
			return true
	return false

# Поиск доступного блока по тексту
func find_available_block(block_text: String) -> Dictionary:
	for block in purchased_blocks:
		if block.text == block_text and not block.used:
			return block
	return {}

# === SPECIAL COMMANDS MANAGEMENT - С СИСТЕМОЙ ОЧКОВ ===

func generate_special_command_id() -> String:
	var id = "special_cmd_" + str(next_special_command_id)
	next_special_command_id += 1
	return id

func purchase_special_command(special_type: int, count: int = 1) -> void:
	var special_data = ItemData.get_special_command_data(special_type)
	if special_data.is_empty():
		return
	
	for i in range(count):
		var command_id = generate_special_command_id()
		var new_command = {
			"id": command_id,
			"type": special_type,
			"name": special_data.name,
			"used": false,
			"consumed": false  # Для команд без значений - отслеживает потребление
		}
		purchased_special_commands.append(new_command)
		
		# Устанавливаем очки для особой команды
		if special_data.has_value:
			# Для команд со значениями - очки равны максимальному значению
			var max_value = special_data.get("max_value", 1)
			special_command_points[command_id] = max_value
			remaining_special_points[command_id] = max_value
		else:
			# Для команд без значений - 1 очко (одноразовые)
			special_command_points[command_id] = 1
			remaining_special_points[command_id] = 1
	
	special_command_availability_changed.emit()

# ИСПРАВЛЕНО: Улучшенная проверка доступности особых команд
func can_use_special_command(command_id: String) -> bool:
	for command in purchased_special_commands:
		if command.id == command_id:
			var basic_available = not command.used and not command.get("consumed", false)
			
			# Для команд со значениями дополнительно проверяем очки
			if basic_available and command.has("type"):
				var special_data = ItemData.get_special_command_data(command.type)
				if not special_data.is_empty() and special_data.has_value:
					# Команда доступна только если есть хотя бы 1 очко
					return has_available_special_points(command_id)
			
			return basic_available
	return false

func use_special_command(command_id: String) -> bool:
	for command in purchased_special_commands:
		if command.id == command_id and not command.used and not command.get("consumed", false):
			command.used = true
			special_command_availability_changed.emit()
			return true
	return false

# Потребление особой команды без значений (удаляет навсегда до сброса комнаты)
func consume_special_command(command_id: String) -> void:
	for command_data in purchased_special_commands:
		if command_data.id == command_id:
			command_data.consumed = true
			command_data.used = false  # Освобождаем used, но остается consumed
			special_command_availability_changed.emit()
			return

func release_special_command(command_id: String) -> void:
	for command_data in purchased_special_commands:
		if command_data.id == command_id:
			# Освобождаем used, но не consumed (consumed команды остаются недоступными)
			command_data.used = false
			special_command_availability_changed.emit()
			return

# ИСПРАВЛЕНО: В методе reset_special_commands() также сбрасываем очки:
func reset_special_commands() -> void:
	for command in purchased_special_commands:
		command.used = false
		command.consumed = false  # Сбрасываем и потребление
	# Сбрасываем очки особых команд
	reset_special_command_points()
	special_command_availability_changed.emit()

# ИСПРАВЛЕНО: Новый метод для проверки, есть ли доступные очки
func has_available_special_points(command_id: String) -> bool:
	return get_remaining_special_points(command_id) > 0

# Проверка, потреблена ли команда
func is_special_command_consumed(command_id: String) -> bool:
	for command in purchased_special_commands:
		if command.id == command_id:
			return command.get("consumed", false)
	return false

func get_all_purchased_special_commands() -> Array:
	return purchased_special_commands.duplicate()

func get_special_command_data(command_id: String) -> Dictionary:
	for command in purchased_special_commands:
		if command.id == command_id:
			# Дополняем данные из ItemData
			var result = command.duplicate()
			if command.has("type") and command.type is int and command.type in ItemData.SpecialCommandType.values():
				var item_data = ItemData.get_special_command_data(command.type)
				if not item_data.is_empty():
					result["icon"] = item_data.icon
					result["color"] = item_data.color
					result["description"] = item_data.description
					result["cost"] = item_data.cost
					result["has_value"] = item_data.has_value
			return result
	return {}

# Проверка, можно ли использовать особую команду с определенным значением
func can_use_special_command_with_value(command_id: String, value: int) -> bool:
	var remaining = get_remaining_special_points(command_id)
	return remaining >= value
