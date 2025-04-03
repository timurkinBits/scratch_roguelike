extends Node2D

# Сигнал, который будет вызываться при переходе в новую комнату
signal room_changed(direction: String)

@export var enemy_scene: PackedScene
@export var max_enemies: int = 5
@export var min_enemies: int = 3
@export var min_distance_from_player: int = 5

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

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var player: Player = $Player

# Флаг для предотвращения множественных переходов
var is_transitioning: bool = false

func _ready() -> void:
	# Скрываем двери при запуске
	hide_doors()
	# Спавним врагов
	spawn_enemies()
	
	
func save_barriers():
	var walls: Array
	for wall in get_tree().get_nodes_in_group('barrier'):
		walls.append(wall.get_tile_position())
	
	# Преобразуем Vector2 в словари для сериализации
	var save_data := []
	for pos in walls:
		save_data.append({"x": pos.x, "y": pos.y})
	
	# Сохраняем данные в JSON-файл
	var save_path := "user://barriers.save"
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	
	if file:
		file.store_string(JSON.stringify(save_data))
	else:
		push_error("Failed to save barriers to %s" % save_path)

# Функция скрытия всех дверей
func hide_doors() -> void:
	for door in get_tree().get_nodes_in_group('doors'):
		door.visible = false

# Функция отображения всех дверей
func show_doors() -> void:
	for door in get_tree().get_nodes_in_group('doors'):
		door.visible = true

# Функция очистки всех объектов комнаты кроме игрока и дверей
func clear_room() -> void:
	# Очищаем врагов
	clear_existing_enemies()
	save_barriers()
	# Очищаем другие объекты (например, предметы, сундуки и т.д.)
	# Если есть группы других объектов, их можно добавить сюда
	var objects = get_tree().get_nodes_in_group('objects')
	for object in objects:
		if object != player and not object.is_in_group('doors'):
			object.queue_free()

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
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Шаг 1: Очистка текущей комнаты
	clear_room()
	
	# Шаг 2: Телепортация игрока к противоположной двери
	var opposite_direction = OPPOSITE_DIRECTIONS[direction]
	teleport_player_to_door(opposite_direction)
	
	# Шаг 3: Скрываем двери
	hide_doors()
	
	# Шаг 4: Генерация новой комнаты (враги, объекты и т.д.)
	spawn_enemies()
	
	# Шаг 5: Отправляем сигнал о смене комнаты (для других систем)
	emit_signal("room_changed", direction)
	
	# Сбрасываем флаг перехода
	is_transitioning = false

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
	var available_positions = []
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
			var is_wall = current_tile in barrier_positions
			
			# Добавляем клетку, если она подходит
			if distance_to_player >= min_distance_from_player and not is_wall:
				available_positions.append(current_tile)
	
	return available_positions

# Расчет манхэттенского расстояния между клетками
func calculate_path_length(from_tile: Vector2, to_tile: Vector2) -> int:
	return int(abs(from_tile.x - to_tile.x) + abs(from_tile.y - to_tile.y))
