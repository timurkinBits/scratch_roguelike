extends Node2D
class_name Table

# Базовые переменные
var is_turn_in_progress: bool = false

# Предзагрузка ресурсов
@onready var table_texture: ColorRect = $Texture
var command_scene = preload('res://scenes/Command.tscn')
var block_scene = preload('res://scenes/Block.tscn')

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

# Создание копии блока
func create_block_copy(type: int) -> void:
	if is_turn_in_progress:
		return
		
	var new_block = block_scene.instantiate() as Block
	new_block.type = type
	new_block.is_menu_command = false
	
	# Установка значений по умолчанию в зависимости от типа
	match type:
		ItemData.BlockType.CONDITION:
			new_block.text = Block.available_conditions[0]
		ItemData.BlockType.LOOP:
			new_block.loop_count = Block.available_loops[0]
		ItemData.BlockType.ABILITY:
			new_block.text = Block.available_abilities[0]
			
	table_texture.add_child(new_block)
	new_block.update_appearance()
	
	# Блок инициализируется после добавления в дерево сцены
	new_block.button_color.visible = true
	new_block.position = Vector2(8, 8)
	new_block.scale = Vector2(0.9, 0.9)

# Общий метод создания карты
func create_card(kind, type: int) -> void:
	if kind == Command:
		create_command_copy(type)
	else:
		create_block_copy(type)
