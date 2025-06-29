extends Node

# Сигналы
signal points_changed
signal coins_changed
signal inventory_changed
signal block_availability_changed
signal special_command_availability_changed

enum RoomType { NORMAL, ELITE, SHOP, CHALLENGE }

# Очки команд
var points: Dictionary = {
	Command.TypeCommand.MOVE: 10,
	Command.TypeCommand.ATTACK: 30,
	Command.TypeCommand.HEAL: 3,
	Command.TypeCommand.DEFENSE: 3
}
var remaining_points: Dictionary = {}

# Монеты и ограничения
var coins: int = 999
var max_slots_for_blocks: int = 8
var max_slots_for_commands: int = 1

# Система блоков
var purchased_blocks: Array[Dictionary] = []
var next_block_id: int = 0

# Система особых команд
var purchased_special_commands: Array[Dictionary] = []
var next_special_command_id: int = 0
var special_command_points: Dictionary = {}
var remaining_special_points: Dictionary = {}
# НОВОЕ: Текущие максимальные значения команд (могут уменьшаться)
var current_max_special_points: Dictionary = {}
# НОВОЕ: Изначальные максимальные значения (для восстановления в новой комнате)
var original_max_special_points: Dictionary = {}

func _ready() -> void:
	reset_remaining_points()
	reset_all_blocks()

# === УПРАВЛЕНИЕ ОЧКАМИ ===

func reset_remaining_points() -> void:
	remaining_points = points.duplicate()
	_reset_special_points()
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

# === ОЧКИ ОСОБЫХ КОМАНД ===

func _reset_special_points() -> void:
	remaining_special_points.clear()
	for cmd in purchased_special_commands:
		if current_max_special_points.has(cmd.id):
			remaining_special_points[cmd.id] = current_max_special_points[cmd.id]

func get_remaining_special_points(command_id: String) -> int:
	return remaining_special_points.get(command_id, 0)

# НОВОЕ: Получить текущий максимум очков команды
func get_current_max_special_points(command_id: String) -> int:
	return current_max_special_points.get(command_id, 0)

func use_special_points(command_id: String, value: int) -> void:
	if command_id in remaining_special_points:
		remaining_special_points[command_id] = max(0, remaining_special_points[command_id] - value)
		points_changed.emit()
		special_command_availability_changed.emit()

func release_special_points(command_id: String, value: int) -> void:
	if command_id in remaining_special_points and command_id in current_max_special_points:
		var max_points = current_max_special_points[command_id]
		remaining_special_points[command_id] = min(max_points, remaining_special_points[command_id] + value)
		points_changed.emit()
		special_command_availability_changed.emit()

# НОВОЕ: Уменьшить максимальное значение команды (при использовании)
func deplete_special_command_max(command_id: String, used_value: int) -> void:
	if command_id in current_max_special_points:
		current_max_special_points[command_id] = max(0, current_max_special_points[command_id] - used_value)
		# Если текущие очки больше нового максимума, уменьшаем их
		if command_id in remaining_special_points:
			remaining_special_points[command_id] = min(remaining_special_points[command_id], current_max_special_points[command_id])
		special_command_availability_changed.emit()

# НОВОЕ: Восстановить максимальные значения всех команд (при входе в новую комнату)
func restore_special_commands_for_new_room() -> void:
	for cmd in purchased_special_commands:
		var command_id = cmd.id
		if original_max_special_points.has(command_id):
			current_max_special_points[command_id] = original_max_special_points[command_id]
			remaining_special_points[command_id] = original_max_special_points[command_id]
	
	# Сбрасываем статус использования и потребления
	reset_special_commands()
	special_command_availability_changed.emit()

# === УПРАВЛЕНИЕ МОНЕТАМИ ===

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

# === СИСТЕМА БЛОКОВ ===

func _generate_block_id() -> String:
	var id = "block_" + str(next_block_id)
	next_block_id += 1
	return id

func purchase_block(block_text: String, count: int = 1) -> void:
	for i in range(count):
		purchased_blocks.append({
			"id": _generate_block_id(),
			"text": block_text,
			"used": false
		})
	points_changed.emit()
	inventory_changed.emit()

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
			block_availability_changed.emit()
			return true
	return false

func release_block(block_id: String) -> void:
	for block in purchased_blocks:
		if block.id == block_id and block.used:
			block.used = false
			points_changed.emit()
			block_availability_changed.emit()
			return

func reset_all_blocks() -> void:
	for block in purchased_blocks:
		block.used = false
	points_changed.emit()
	block_availability_changed.emit()

func get_all_purchased_blocks() -> Array:
	return purchased_blocks.duplicate()

# Поиск блока по тексту
func can_use_block(block_text: String) -> bool:
	for block in purchased_blocks:
		if block.text == block_text and not block.used:
			return true
	return false

func find_available_block(block_text: String) -> Dictionary:
	for block in purchased_blocks:
		if block.text == block_text and not block.used:
			return block
	return {}

# === СИСТЕМА ОСОБЫХ КОМАНД ===

func _generate_special_command_id() -> String:
	var id = "special_cmd_" + str(next_special_command_id)
	next_special_command_id += 1
	return id

func purchase_special_command(special_type: int, count: int = 1) -> void:
	var special_data = ItemData.get_special_command_data(special_type)
	if special_data.is_empty():
		return
	
	for i in range(count):
		var command_id = _generate_special_command_id()
		purchased_special_commands.append({
			"id": command_id,
			"type": special_type,
			"name": special_data.name,
			"used": false,
			"consumed": false
		})
		
		# Установка очков команды
		var max_value = special_data.get("max_value", 1) if special_data.has_value else 1
		special_command_points[command_id] = max_value
		remaining_special_points[command_id] = max_value
		# НОВОЕ: Сохраняем изначальный и текущий максимум
		original_max_special_points[command_id] = max_value
		current_max_special_points[command_id] = max_value
	
	special_command_availability_changed.emit()

func can_use_special_command(command_id: String) -> bool:
	for cmd in purchased_special_commands:
		if cmd.id == command_id:
			var available = not cmd.used and not cmd.consumed
			# ИЗМЕНЕНО: Проверка текущего максимума вместо изначального
			if available and cmd.has("type"):
				var data = ItemData.get_special_command_data(cmd.type)
				if not data.is_empty():
					if data.has_value:
						# Команда доступна только если у неё есть текущий максимум > 0
						return current_max_special_points.get(command_id, 0) > 0
					else:
						# Одноразовая команда доступна если не использована
						return true
			return available
	return false

func use_special_command(command_id: String) -> bool:
	for cmd in purchased_special_commands:
		if cmd.id == command_id and not cmd.used and not cmd.consumed:
			cmd.used = true
			special_command_availability_changed.emit()
			return true
	return false

func consume_special_command(command_id: String) -> void:
	for cmd in purchased_special_commands:
		if cmd.id == command_id:
			cmd.consumed = true
			cmd.used = false
			special_command_availability_changed.emit()
			return

func release_special_command(command_id: String) -> void:
	for cmd in purchased_special_commands:
		if cmd.id == command_id:
			cmd.used = false
			special_command_availability_changed.emit()
			return

func reset_special_commands() -> void:
	for cmd in purchased_special_commands:
		cmd.used = false
		cmd.consumed = false
	_reset_special_points()
	special_command_availability_changed.emit()

func has_available_special_points(command_id: String) -> bool:
	return get_remaining_special_points(command_id) > 0

func is_special_command_consumed(command_id: String) -> bool:
	for cmd in purchased_special_commands:
		if cmd.id == command_id:
			return cmd.get("consumed", false)
	return false

func get_all_purchased_special_commands() -> Array:
	return purchased_special_commands.duplicate()

func get_special_command_data(command_id: String) -> Dictionary:
	for cmd in purchased_special_commands:
		if cmd.id == command_id:
			var result = cmd.duplicate()
			if cmd.has("type") and cmd.type is int:
				var item_data = ItemData.get_special_command_data(cmd.type)
				if not item_data.is_empty():
					result.merge(item_data)
			return result
	return {}

func can_use_special_command_with_value(command_id: String, value: int) -> bool:
	return get_remaining_special_points(command_id) >= value
