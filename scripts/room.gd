# Изменения в room.gd
extends Node2D

signal room_changed(direction: String)

enum RoomType {
	NORMAL_ENEMIES,
	ELITE_ENEMIES,
	SHOP,
	CHALLENGE
}

@export var enemy_scene: PackedScene
@export var wall_scene: PackedScene
@export var door_scene: PackedScene
@export var info_scene: PackedScene
@export var allow_layout_editing: bool = false

# Добавляем настройки шансов для каждого типа комнаты
@export_group("Room Spawn Chances")
@export_range(0, 100) var normal_room_chance: int = 60
@export_range(0, 100) var shop_room_chance: int = 20
@export_range(0, 100) var elite_room_chance: int = 10
@export_range(0, 100) var challenge_room_chance: int = 10

const DOOR_POSITIONS = {
	"up": Vector2(7, 0),
	"down": Vector2(7, 10),
	"left": Vector2(2, 5),
	"right": Vector2(12, 5)
}

const DOOR_ICONS = {
	RoomType.NORMAL_ENEMIES: "res://sprites/fb727.png",
	RoomType.ELITE_ENEMIES: "res://sprites/fb729.png",
	RoomType.SHOP: "res://sprites/fb136.png",
	RoomType.CHALLENGE: "res://sprites/fb71.png"
}

const OPPOSITE_DIRECTIONS = {
	"up": "down",
	"down": "up",
	"left": "right",
	"right": "left"
}

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var player: Player = $Player
@onready var edit_mode_manager = $EditModeManager
@onready var exit_doors: Node2D = $ExitDoors

@onready var doors = exit_doors.get_children()

var type: RoomType = RoomType.NORMAL_ENEMIES
var max_enemies: int = 3
var min_enemies: int = 1
var min_distance_from_player: int = 5
var door_types_generated: bool = false  # Флаг для отслеживания, были ли сгенерированы типы комнат

func _ready() -> void:
	for exit_door in doors:
		exit_door.get_node('button').visible = false
	init_edit_mode()
	spawn_enemies()

func init_edit_mode() -> void:
	edit_mode_manager.init(self, player, tile_map, wall_scene, door_scene, allow_layout_editing)
	apply_layout_for_current_type()

func apply_layout_for_current_type() -> void:
	clear_walls()
	edit_mode_manager.check_and_apply_layout()

func clear_walls() -> void:
	for wall in get_tree().get_nodes_in_group('objects'):
		wall.queue_free()

func clear_room() -> void:
	clear_enemies()
	clear_walls()

# Измененная функция для рандомной генерации типов комнат с учетом весов
func random_types_rooms() -> void:
	# Проверяем, были ли уже сгенерированы типы комнат
	if door_types_generated:
		return
	
	# Устанавливаем флаг, что типы комнат сгенерированы
	door_types_generated = true
	
	# Генерируем тип для каждой двери с учетом шансов
	for door in doors:
		# Используем настраиваемые шансы для определения типа комнаты
		var room_type = get_weighted_room_type()
		door.type = RoomType.keys()[room_type]
		door.get_node('button').texture = load(DOOR_ICONS[room_type])

# Функция для определения типа комнаты с учетом весов
func get_weighted_room_type() -> int:
	# Создаем общий пул шансов
	var total_chance = normal_room_chance + elite_room_chance + shop_room_chance + challenge_room_chance
	
	# Если общий шанс равен 0, устанавливаем равномерное распределение
	if total_chance == 0:
		return randi() % RoomType.size()
	
	# Выберем случайное число в диапазоне общего шанса
	var roll = randi() % total_chance
	
	# Определяем, какому типу комнаты соответствует выпавшее число
	var current_sum = 0
	
	# Обычная комната
	current_sum += normal_room_chance
	if roll < current_sum:
		return RoomType.NORMAL_ENEMIES
	
	# Элитная комната
	current_sum += elite_room_chance
	if roll < current_sum:
		return RoomType.ELITE_ENEMIES
	
	# Магазин
	current_sum += shop_room_chance
	if roll < current_sum:
		return RoomType.SHOP
	
	# Комната испытаний
	return RoomType.CHALLENGE

func teleport_player_to_door(door_direction: String) -> void:
	var target_tile = DOOR_POSITIONS[door_direction]
	var world_position = player.get_world_position_from_tile(target_tile)
	
	player.position = world_position
	player.current_direction = OPPOSITE_DIRECTIONS[door_direction]
	player.update_visual()

func transition_to_new_room(direction: String, door_type = null) -> void:
	clear_room()
	teleport_player_to_door(OPPOSITE_DIRECTIONS[direction])
	
	if door_type != null:
		if typeof(door_type) == TYPE_STRING:
			type = RoomType[door_type]
		else:
			type = door_type
	
	for exit_door in doors:
		exit_door.get_node('button').visible = false
	
	Global.reset_remaining_points()
	
	# Сбрасываем флаг генерации типов комнат при переходе в новую комнату
	door_types_generated = false
	
	# Применяем макет, соответствующий текущему типу комнаты
	apply_layout_for_current_type()
	
	apply_room_type_settings()
	spawn_enemies()
	room_changed.emit(direction)

func apply_room_type_settings() -> void:
	match type:
		RoomType.NORMAL_ENEMIES:
			min_enemies = 1
			max_enemies = 3
		RoomType.ELITE_ENEMIES:
			min_enemies = 2
			max_enemies = 4
		RoomType.SHOP:
			pass
		RoomType.CHALLENGE:
			min_enemies = 0
			max_enemies = 0

func _on_right_door_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		transition_to_new_room('right', $ExitDoors/RightDoor.type)

func _on_left_door_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		transition_to_new_room('left', $ExitDoors/LeftDoor.type)

func _on_down_door_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		transition_to_new_room('down', $ExitDoors/DownDoor.type)
			
func _on_up_door_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		transition_to_new_room('up', $ExitDoors/UpDoor.type)

func spawn_enemies() -> void:
	clear_enemies()
	
	if type == RoomType.SHOP:
		return
	
	var available_positions = get_available_spawn_positions()
	if available_positions.is_empty():
		return
	
	available_positions.shuffle()
	var enemy_count = min(randi_range(min_enemies, max_enemies), available_positions.size())
	
	for i in range(enemy_count):
		var enemy_instance = enemy_scene.instantiate()
		add_child(enemy_instance)
		
		var world_position = tile_map.map_to_local(available_positions[i]) * tile_map.scale
		enemy_instance.position = world_position
		enemy_instance.scale = Vector2(1.604, 1.604)
	
	if type == RoomType.ELITE_ENEMIES:
		for enemy in get_tree().get_nodes_in_group('enemies'):
			enemy.hp += 2
			enemy.damage += 2

func clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()

func get_available_spawn_positions() -> Array:
	var available_positions: Array = []
	var tilemap_rect = tile_map.get_used_rect()
	var player_tile_position = player.get_tile_position()
	
	var barrier_positions = []
	for barrier in get_tree().get_nodes_in_group("barrier"):
		barrier_positions.append(barrier.get_tile_position())
	
	for x in range(tilemap_rect.position.x, tilemap_rect.position.x + tilemap_rect.size.x):
		for y in range(tilemap_rect.position.y, tilemap_rect.position.y + tilemap_rect.size.y):
			var current_tile = Vector2(x, y)
			
			if calculate_path_length(current_tile, player_tile_position) < min_distance_from_player:
				continue
			
			if current_tile in barrier_positions:
				continue
			
			available_positions.append(current_tile)
	
	return available_positions

func calculate_path_length(from_tile: Vector2, to_tile: Vector2) -> int:
	return int(abs(from_tile.x - to_tile.x) + abs(from_tile.y - to_tile.y))

func spawn_object_at_position(type_obj: EditMode.PlacementType, tile_position: Vector2, rotation_degree: int = 0):
	match type_obj:
		EditMode.PlacementType.WALL:
			spawn_object(wall_scene, tile_position, rotation_degree)
		EditMode.PlacementType.DOOR:
			spawn_object(door_scene, tile_position, rotation_degree)
		EditMode.PlacementType.INFO:
			spawn_object(info_scene, tile_position, rotation_degree)

func spawn_object(scene: PackedScene, tile_position: Vector2, rotation_degree: int = 0):
	if scene:
		var instance = scene.instantiate()
		add_child(instance)
		instance.position = instance.get_world_position_from_tile(tile_position)
		if instance.has_method('set_rotation_degree'):
			instance.set_rotation_degree(rotation_degree)
