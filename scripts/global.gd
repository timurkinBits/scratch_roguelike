extends Node

signal points_changed
signal coins_changed
signal inventory_changed  # Для покупки новых блоков
signal block_availability_changed  # Для изменения доступности блоков

var points: Dictionary = {
	Command.TypeCommand.MOVE: 10,
	Command.TypeCommand.ATTACK: 30,
	Command.TypeCommand.HEAL: 3,
	Command.TypeCommand.DEFENSE: 3
}

var coins: int = 0
var remaining_points: Dictionary = {}

# Block system - теперь работает только с текстом блоков
var purchased_blocks: Array[Dictionary] = []
var next_block_id: int = 0

func _ready() -> void:
	reset_remaining_points()
	reset_all_blocks()

# Points management
func reset_remaining_points() -> void:
	remaining_points = points.duplicate()
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

# Получить количество доступных блоков определенного типа
func get_available_block_count(block_text: String) -> int:
	var count = 0
	for block in purchased_blocks:
		if block.text == block_text and not block.used:
			count += 1
	return count

# Получить общее количество блоков определенного типа (включая использованные)
func get_total_block_count(block_text: String) -> int:
	var count = 0
	for block in purchased_blocks:
		if block.text == block_text:
			count += 1
	return count

# Compatibility functions for ItemData integration
func purchase_item(item_type: int, count: int = 1) -> void:
	var block_text = ItemData.get_block_text(item_type)
	if block_text != "":
		purchase_block(block_text, count)
