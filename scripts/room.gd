extends Node2D

# Сигнал, который будет вызываться при переходе в новую комнату
signal room_changed(direction: String)

@export var enemy_scene: PackedScene
@export var max_enemies: int = 5
@export var min_enemies: int = 3
@export var min_distance_from_player: int = 5
@export var wall_scene: PackedScene  # Добавляем сцену стены для создания
@export var allow_layout_editing: bool = false  # Флаг разрешения редактирования расположения стен

# Определяем константы для дверей
const DOOR_POSITIONS = {
	"up": Vector2(7, 0),
	"down": Vector2(7, 10),
	"left": Vector2(2, 5),
	"right": Vector2(12, 5)
}

# Словарь с противоположными направлениями
const OPPOSITE_DIRECTIONS = {
	"up": "down",
	"down": "up",
	"left": "right",
	"right": "left"
}

# Расстояние отступа от двери (в единицах мира)
const DOOR_OFFSET = 45

# Путь к файлу сохранения
const SAVE_FILE_PATH = "res://wall_layouts.save"

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var player: Player = $Player
@onready var edit_label: Label = $"../UI/edit_label"
@onready var layout_label: Label = $"../UI/layout_label"

# Массив для хранения всех сохраненных расположений стен
var saved_layouts: Array = []
# Флаг режима редактирования
var edit_mode: bool = false
# Индекс выбранного расположения для управления удалением
var selected_layout_index: int = -1

func _ready() -> void:
	# Скрываем двери при запуске
	toggle_doors(false)
	# Загружаем сохраненные расположения стен
	load_saved_layouts()
	# Если нет сохраненных расположений, создаем базовое пустое и сохраняем его
	if saved_layouts.size() == 0:
		save_current_layout()
	else:
		# Применяем случайное сохраненное расположение
		apply_random_layout()
	# Спавним врагов
	spawn_enemies()
	
	# Настраиваем режим редактирования, если он разрешен
	if !allow_layout_editing:
		edit_label.visible = false
	layout_label.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if allow_layout_editing and edit_mode:
			var mouse_pos = get_global_mouse_position()
			place_wall_at_mouse(mouse_pos)
	elif event is InputEventKey and event.pressed and allow_layout_editing:
		if event.keycode == KEY_E:  # Переключить режим редактирования
			toggle_edit_mode()
		if edit_mode:
			if event.keycode == KEY_S:  # Сохранить текущее расположение
				save_current_layout()
				print("Расположение стен сохранено!")
			elif event.keycode == KEY_C:  # Очистить все стены
				clear_walls()
				print("Все стены удалены!")
			elif event.keycode == KEY_D:  # Удалить текущее расположение
				delete_current_layout()
			elif event.keycode == KEY_RIGHT:  # Перейти к следующему расположению
				cycle_to_next_layout()
			elif event.keycode == KEY_LEFT:  # Перейти к предыдущему расположению
				cycle_to_previous_layout()

# Обновление метки с информацией о текущем расположении
func update_layout_label() -> void:
	if layout_label:
		var current_index = selected_layout_index + 1 if selected_layout_index >= 0 else 0
		layout_label.text = "Пресет: " + str(current_index) + "/" + str(saved_layouts.size())

# Переключение режима редактирования
func toggle_edit_mode() -> void:
	edit_mode = !edit_mode
	if edit_mode:
		layout_label.visible = true
	else:
		layout_label.visible = false
	if edit_label:
		edit_label.text = "Режим редактирования " + ("включен" if edit_mode else "выключен") + " (нажмите E для переключения)"
		if edit_mode:
			edit_label.text += "\nS-сохранить, C-очистить, D-удалить, стрелки-листать"
	print("Режим редактирования " + ("включен" if edit_mode else "выключен"))

# Перейти к следующему расположению
func cycle_to_next_layout() -> void:
	if saved_layouts.size() == 0:
		return
		
	selected_layout_index = (selected_layout_index + 1) % saved_layouts.size()
	apply_layout_by_index(selected_layout_index)
	update_layout_label()
	print("Выбрано расположение #" + str(selected_layout_index + 1))

# Перейти к предыдущему расположению
func cycle_to_previous_layout() -> void:
	if saved_layouts.size() == 0:
		return
		
	selected_layout_index = (selected_layout_index - 1) if selected_layout_index > 0 else saved_layouts.size() - 1
	apply_layout_by_index(selected_layout_index)
	update_layout_label()
	print("Выбрано расположение #" + str(selected_layout_index + 1))

# Удаление текущего расположения
func delete_current_layout() -> void:
	if selected_layout_index >= 0 and selected_layout_index < saved_layouts.size():
		saved_layouts.remove_at(selected_layout_index)
		
		# Сохраняем обновленный список расположений
		save_layouts_to_file()
		
		# Корректируем индекс текущего расположения
		if saved_layouts.size() > 0:
			selected_layout_index = min(selected_layout_index, saved_layouts.size() - 1)
			apply_layout_by_index(selected_layout_index)
		else:
			selected_layout_index = -1
			clear_walls()
		
		update_layout_label()
		print("Расположение удалено. Осталось: " + str(saved_layouts.size()))
	else:
		print("Нет выбранного расположения для удаления!")

# Применение расположения по индексу
func apply_layout_by_index(index: int) -> void:
	if index >= 0 and index < saved_layouts.size():
		clear_walls()
		var selected_layout = saved_layouts[index]
		
		if selected_layout is Array:
			# Создаем стены на указанных позициях
			for wall_data in selected_layout:
				if wall_data is Dictionary and wall_data.has("x") and wall_data.has("y"):
					var wall_position := Vector2(wall_data.x, wall_data.y)
					spawn_wall_at_position(wall_position)
	else:
		clear_walls()

# Размещение стены под курсором мыши
func place_wall_at_mouse(mouse_position: Vector2) -> void:
	# Преобразуем координаты мыши с учетом масштаба и позиции тайлмапа
	var local_pos = tile_map.to_local(mouse_position)
	var tile_pos = tile_map.local_to_map(local_pos)
	
	# Проверяем, нет ли уже стены на этой позиции
	var walls = get_tree().get_nodes_in_group('barrier')
	for wall in walls:
		if wall.get_tile_position() == Vector2(tile_pos):
			wall.queue_free()  # Удаляем существующую стену
			print("Стена удалена на позиции: ", tile_pos)
			return
	
	# Проверяем, не пытаемся ли мы разместить стену на игроке или возле двери
	var player_tile_pos = player.get_tile_position()
	if Vector2(tile_pos) == player_tile_pos:
		print("Нельзя разместить стену на игроке!")
		return
		
	# Проверяем близость к дверям
	for door_pos in DOOR_POSITIONS.values():
		if calculate_path_length(tile_pos, door_pos) < 2:
			print("Нельзя разместить стену рядом с дверью!")
			return
	
	if not tile_map.get_used_rect().has_point(tile_pos):
		return
	
	# Создаем новую стену
	spawn_wall_at_position(tile_pos)
	print("Стена размещена на позиции: ", tile_pos)

# Загрузка всех сохраненных расположений стен
func load_saved_layouts() -> void:
	saved_layouts = []  # Сбрасываем массив перед загрузкой
	
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var json_text := file.get_as_text()
			var json_result = JSON.parse_string(json_text)
			if json_result != null and json_result is Array:
				saved_layouts = json_result
				print("Загружено " + str(saved_layouts.size()) + " сохраненных расположений стен")
			else:
				printerr("Ошибка при парсинге JSON файла!")
	else:
		# Создаем пустой файл для будущих сохранений
		var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify([]))
			print("Создан новый файл сохранений")

# Сохранение данных в файл
func save_layouts_to_file() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_layouts))
		print("Данные сохранены в файл")

# Сохранение нового расположения стен
func save_current_layout() -> void:
	var walls_positions: Array = []
	for wall in get_tree().get_nodes_in_group('barrier'):
		var pos: Vector2 = wall.get_tile_position()
		walls_positions.append({"x": pos.x, "y": pos.y})
	
	# Проверяем, не пустое ли расположение
	if walls_positions.size() == 0:
		print("Нет стен для сохранения!")
		return
	
	# Проверяем, существует ли уже такое расположение
	if !layout_exists_in_saved(walls_positions):
		saved_layouts.append(walls_positions)
		selected_layout_index = saved_layouts.size() - 1
		
		# Сохраняем все расположения в файл
		save_layouts_to_file()
		update_layout_label()
		print("Новое расположение сохранено. Всего сохранений: " + str(saved_layouts.size()))
	else:
		print("Такое расположение уже существует в сохранениях!")

# Проверка, существует ли уже такое расположение стен
func layout_exists_in_saved(layout: Array) -> bool:
	# Создаем строковое представление для сравнения
	var layout_str := JSON.stringify(layout)
	
	for saved_layout in saved_layouts:
		var saved_layout_str := JSON.stringify(saved_layout)
		if layout_str == saved_layout_str:
			return true
	
	return false

# Применение случайного расположения стен из сохраненных
func apply_random_layout() -> void:
	# Очищаем текущие стены
	clear_walls()
	
	# Выбираем случайное расположение
	if saved_layouts.size() > 0:
		var random_index := randi() % saved_layouts.size()
		selected_layout_index = random_index
		var selected_layout = saved_layouts[random_index]
		
		if selected_layout is Array:
			# Создаем стены на указанных позициях
			for wall_data in selected_layout:
				if wall_data is Dictionary and wall_data.has("x") and wall_data.has("y"):
					var wall_position := Vector2(wall_data.x, wall_data.y)
					spawn_wall_at_position(wall_position)
			
			print("Применено расположение стен #" + str(random_index + 1))
		else:
			printerr("Неверный формат сохраненного расположения!")
	else:
		print("Нет сохраненных расположений стен!")
	
	update_layout_label()

# Очистка существующих стен
func clear_walls() -> void:
	var walls = get_tree().get_nodes_in_group('barrier')
	for wall in walls:
		wall.queue_free()

# Создание стены на указанной позиции
func spawn_wall_at_position(tile_position: Vector2) -> void:
	if wall_scene:
		var wall_instance = wall_scene.instantiate()
		add_child(wall_instance)
		
		# Устанавливаем позицию стены через её метод
		wall_instance.position = wall_instance.get_world_position_from_tile(tile_position)

# Получение всех доступных позиций для размещения стен
func get_available_wall_positions() -> Array:
	var available_positions: Array = []
	var tilemap_rect = tile_map.get_used_rect()
	var player_tile_position = player.get_tile_position()
	
	# Перебираем все клетки тайлмапа
	for x in range(tilemap_rect.position.x + 1, tilemap_rect.position.x + tilemap_rect.size.x - 1):
		for y in range(tilemap_rect.position.y + 1, tilemap_rect.position.y + tilemap_rect.size.y - 1):
			var current_tile = Vector2(x, y)
			
			# Проверяем, не слишком ли близко к игроку
			var distance_to_player = calculate_path_length(current_tile, player_tile_position)
			
			# Проверяем, не находится ли позиция возле двери
			var is_near_door = false
			for door_pos in DOOR_POSITIONS.values():
				if calculate_path_length(current_tile, door_pos) < 2:
					is_near_door = true
					break
			
			# Добавляем клетку, если она подходит
			if distance_to_player >= 2 and not is_near_door:
				available_positions.append(current_tile)
	
	return available_positions

# Функция скрытия всех дверей
func toggle_doors(is_visible: bool) -> void:
	for door in get_tree().get_nodes_in_group('doors'):
		door.visible = is_visible

# Функция очистки всех объектов комнаты кроме игрока и дверей
func clear_room() -> void:
	# Очищаем врагов
	clear_existing_enemies()
	# Стены будут заменяться другим расположением
	clear_walls()

# Функция телепортации игрока к определенной двери
func teleport_player_to_door(door_direction: String) -> void:
	var target_position = DOOR_POSITIONS[door_direction]
	
	# Получаем целевую позицию в клетках с учетом смещения
	var target_tile = target_position
	
	# Используем метод из AbstractCharacter для получения точной позиции в мировых координатах
	var world_position = player.get_world_position_from_tile(target_tile)
	
	# Устанавливаем позицию игрока точно по центру клетки
	player.position = world_position
	
	# Обновляем направление игрока, чтобы он смотрел от двери
	player.current_direction = OPPOSITE_DIRECTIONS[door_direction]
	player.update_visual()

# Основная функция перехода в новую комнату
func transition_to_new_room(direction: String) -> void:
	clear_room()
	teleport_player_to_door(OPPOSITE_DIRECTIONS[direction])
	toggle_doors(false)
	if saved_layouts.size() == 0:
		save_current_layout()
	else:
		apply_random_layout()
	spawn_enemies()
	emit_signal("room_changed", direction)

# Обработчики событий нажатия на двери
func _on_right_door_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			transition_to_new_room("right")

func _on_left_door_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			transition_to_new_room("left")

func _on_down_door_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			transition_to_new_room("down")
			
func _on_up_door_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			transition_to_new_room("up")

# Основная функция создания врагов
func spawn_enemies() -> void:
	# Очищаем существующих врагов, если необходимо
	clear_existing_enemies()
	
	# Определяем количество врагов для создания
	var enemy_count = randi_range(min_enemies, max_enemies)
	
	# Получаем все доступные позиции для спавна
	var available_positions = get_available_spawn_positions()
	
	# Перемешиваем позиции для случайности
	available_positions.shuffle()
	
	# Ограничиваем количество врагов количеством доступных позиций
	enemy_count = min(enemy_count, available_positions.size())
	
	# Создаем врагов на выбранных позициях
	for i in range(enemy_count):
		if i < available_positions.size():
			var enemy_instance = enemy_scene.instantiate()
			
			add_child(enemy_instance)
			
			# Устанавливаем позицию врага
			var world_position = tile_map.map_to_local(available_positions[i]) * tile_map.scale
			enemy_instance.position = world_position
			enemy_instance.scale = Vector2(1.604, 1.604)

# Очистка существующих врагов
func clear_existing_enemies() -> void:
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in existing_enemies:
		enemy.queue_free()

# Получение всех доступных позиций для спавна
func get_available_spawn_positions() -> Array:
	var available_positions: Array = []
	var tilemap_rect = tile_map.get_used_rect()
	var player_tile_position = player.get_tile_position()
	
	# Получаем все стены и препятствия
	var barriers = get_tree().get_nodes_in_group("barrier")
	var barrier_positions = []
	for barrier in barriers:
		barrier_positions.append(barrier.get_tile_position())
	
	# Перебираем все клетки тайлмапа
	for x in range(tilemap_rect.position.x, tilemap_rect.position.x + tilemap_rect.size.x):
		for y in range(tilemap_rect.position.y, tilemap_rect.position.y + tilemap_rect.size.y):
			var current_tile = Vector2(x, y)
			
			# Проверяем расстояние до игрока
			var distance_to_player = calculate_path_length(current_tile, player_tile_position)
			
			# Проверяем, находится ли клетка на стене
			var is_wall = false
			for barrier_pos in barrier_positions:
				if current_tile == barrier_pos:
					is_wall = true
					break
			
			# Добавляем клетку, если она подходит
			if distance_to_player >= min_distance_from_player and not is_wall:
				available_positions.append(current_tile)
	
	return available_positions

# Расчет манхэттенского расстояния между клетками
func calculate_path_length(from_tile: Vector2, to_tile: Vector2) -> int:
	return int(abs(from_tile.x - to_tile.x) + abs(from_tile.y - to_tile.y))
