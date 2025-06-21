extends Node2D
class_name Table

# Базовые переменные
var is_turn_in_progress: bool = false

# Предзагрузка ресурсов
@onready var table_texture: ColorRect = $Texture
var command_scene = preload('res://scenes/Command.tscn')
var block_scene = preload('res://scenes/Block.tscn')

func _ready() -> void:
	add_to_group("table")

# Границы стола
func get_table_rect() -> Rect2:
	var table_canvas_rect = table_texture.get_global_rect()
	var canvas_to_world = get_viewport().canvas_transform.inverse()
	var table_top_left_world = canvas_to_world * table_canvas_rect.position
	var table_bottom_right_world = canvas_to_world * (table_canvas_rect.position + table_canvas_rect.size)
	return Rect2(table_top_left_world, table_bottom_right_world - table_top_left_world)

# Создание копии команды
func create_command_copy(type: int) -> void:
	var remaining_points = Global.get_remaining_points(type)
	if remaining_points <= 0:
		return
		
	var new_command = command_scene.instantiate()
	new_command.type = type
	table_texture.add_child(new_command)
	new_command.update_appearance()
	
	new_command.set_number(1)
	new_command.position = Vector2(8, 8)

# ДОБАВЛЕН: Исправленное создание копии специальной команды
func create_special_command_copy(command_data: Dictionary) -> void:
	if is_turn_in_progress:
		return
	
	# Проверяем доступность команды
	if not Global.can_use_special_command(command_data.id):
		return
	
	# Создаем специальную команду
	var new_command = command_scene.instantiate()
	
	# Заменяем скрипт на SpecialCommand
	var special_script = preload("res://scripts/cards/special_command.gd")
	new_command.set_script(special_script)
	
	# ИСПРАВЛЕНО: Устанавливаем правильные типы
	new_command.special_id = command_data.id
	new_command.special_type = command_data.type  # Тип особой команды из ItemData
	new_command.type = Command.TypeCommand.NONE if Command.TypeCommand.has("NONE") else -1  # Нейтральный тип
	new_command.is_menu_card = false
	
	# Проверяем настройки из ItemData
	var special_data = ItemData.get_special_command_data(command_data.type)
	if not special_data.is_empty():
		new_command.has_value = special_data.has_value
	else:
		new_command.has_value = true  # По умолчанию
	
	table_texture.add_child(new_command)
	
	# Позиционируем команду
	position_new_command(new_command)
	
	# Отмечаем команду как использованную
	Global.use_special_command(command_data.id)
	
	# Обновляем внешний вид после добавления в дерево
	new_command.call_deferred("update_appearance")

# Позиционирование новой команды на столе
func position_new_command(command: Node) -> void:
	var table_rect = table_texture.get_rect()
	var command_size = Vector2(80, 60)  # Примерный размер команды
	var margin = 20
	
	var x = margin
	var y = margin
	var row_height = command_size.y + margin
	
	# Проверяем пересечения с существующими командами
	var existing_commands = get_all_commands()
	var placed = false
	
	while not placed and y < table_rect.size.y - command_size.y:
		while x < table_rect.size.x - command_size.x:
			var test_rect = Rect2(Vector2(x, y), command_size)
			var intersects = false
			
			for existing_command in existing_commands:
				if existing_command == command or not is_instance_valid(existing_command):
					continue
				var existing_rect = Rect2(existing_command.position, command_size)
				if test_rect.intersects(existing_rect):
					intersects = true
					break
			
			if not intersects:
				command.position = Vector2(x, y)
				placed = true
				break
			
			x += command_size.x + margin
		
		if not placed:
			x = margin
			y += row_height
	
	# Если не удалось найти место, ставим в углу
	if not placed:
		command.position = Vector2(8, 8)

# Получить все команды на столе
func get_all_commands() -> Array:
	var commands = []
	for child in table_texture.get_children():
		if child.has_method("get_class") and child.get_class() == "Command":
			commands.append(child)
		elif child.get_script() and child.get_script().get_global_name() == "SpecialCommand":
			commands.append(child)
	return commands

# Создание блока с использованием ID из инвентаря
func create_block_copy(block_text: String, block_id: String = "") -> void:
	if is_turn_in_progress:
		return
	
	# Если ID указан, проверяем доступность блока в инвентаре
	if block_id != "":
		if not Global.can_use_block_by_id(block_id):
			return
	else:
		# Если ID не указан, ищем доступный блок по тексту
		var available_block = Global.find_available_block(block_text)
		if available_block.is_empty():
			return
		block_id = available_block.id
	
	# Создаем блок
	var new_block = block_scene.instantiate() as Block
	new_block.is_menu_card = false
	new_block.text = block_text
	new_block.block_id = block_id
	
	table_texture.add_child(new_block)
	new_block.update_appearance()
	
	# Позиционируем блок
	position_new_block(new_block)
	
	# Отмечаем блок как использованный в инвентаре
	Global.use_block(block_id)

# Позиционирование нового блока на столе
func position_new_block(block: Block) -> void:
	var table_rect = table_texture.get_rect()
	var block_size = Vector2(100, 60)  # Примерный размер блока
	var margin = 20
	
	var x = margin
	var y = margin
	var row_height = block_size.y + margin
	
	# Проверяем пересечения с существующими блоками
	var existing_blocks = get_all_blocks()
	var placed = false
	
	while not placed and y < table_rect.size.y - block_size.y:
		while x < table_rect.size.x - block_size.x:
			var test_rect = Rect2(Vector2(x, y), block_size)
			var intersects = false
			
			for existing_block in existing_blocks:
				if existing_block == block or not is_instance_valid(existing_block):
					continue
				var existing_rect = Rect2(existing_block.position, block_size)
				if test_rect.intersects(existing_rect):
					intersects = true
					break
			
			if not intersects:
				block.position = Vector2(x, y)
				placed = true
				break
			
			x += block_size.x + margin
		
		if not placed:
			x = margin
			y += row_height
	
	# Если не удалось найти место, ставим в углу
	if not placed:
		block.position = Vector2(8, 8)

# Получить все блоки на столе
func get_all_blocks() -> Array[Block]:
	var blocks: Array[Block] = []
	for child in table_texture.get_children():
		if child is Block:
			blocks.append(child)
	return blocks

# Получить блоки определенного типа
func get_blocks_by_text(text: String) -> Array[Block]:
	var matching_blocks: Array[Block] = []
	for block in get_all_blocks():
		if block.text == text:
			matching_blocks.append(block)
	return matching_blocks

# Очистить все блоки кроме "начало хода"
func clear_non_essential_blocks() -> void:
	for child in table_texture.get_children():
		if child is Block and child.text != "начало хода":
			# Освобождаем блок в инвентаре перед удалением
			if child.block_id != "":
				Global.release_block(child.block_id)
			child.queue_free()

# Получить количество блоков определенного типа
func count_blocks_by_text(text: String) -> int:
	return get_blocks_by_text(text).size()

# Создание блока напрямую из покупки (для Item.gd)
func create_purchased_block(block_text: String) -> void:
	# Находим доступный блок в инвентаре
	var available_block = Global.find_available_block(block_text)
	if not available_block.is_empty():
		create_block_copy(block_text, available_block.id)
