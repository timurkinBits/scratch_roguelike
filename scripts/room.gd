# Изменения в room.gd
extends Node2D

signal room_changed(direction: String)

enum RoomType {
	NORMAL,
	ELITE,
	SHOP,
	CHALLENGE
}

@export var enemy_scene: PackedScene
@export var wall_scene: PackedScene
@export var door_scene: PackedScene
@export var info_scene: PackedScene
@export var item_scene: PackedScene
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
	RoomType.NORMAL: "res://sprites/normal.png",
	RoomType.ELITE: "res://sprites/elite.png",
	RoomType.SHOP: "res://sprites/shop.png",
	RoomType.CHALLENGE: "res://sprites/challenge.png"
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

var teleporter_enemy_script = preload("res://scripts/TeleporterEnemy.gd")
var berserker_enemy_script = preload("res://scripts/BerserkerEnemy.gd")

@export_group("Special Enemy Spawn Chances")
@export_range(0, 100) var special_enemy_chance: int = 15  # Общий шанс замены врага на особого
@export_range(0, 100) var teleporter_weight: int = 50     # Вес телепортера среди особых врагов
@export_range(0, 100) var berserker_weight: int = 50      # Вес берсерка среди особых врагов

var type: RoomType = RoomType.NORMAL
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
	clear_objects()
	edit_mode_manager.check_and_apply_layout()

func clear_objects() -> void:
	for wall in get_tree().get_nodes_in_group('objects'):
		wall.queue_free()

func clear_room() -> void:
	clear_enemies()
	clear_objects()

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

# Функция для определения типа комнаты с учетом весов и предотвращения повторений определенных типов
func get_weighted_room_type() -> int:
	# Создаем копии оригинальных шансов, которые будем модифицировать
	var current_normal_chance = normal_room_chance
	var current_elite_chance = elite_room_chance
	var current_shop_chance = shop_room_chance
	var current_challenge_chance = challenge_room_chance
	
	# Предотвращаем повторение текущего типа комнаты (кроме обычной комнаты)
	match type:
		RoomType.ELITE:
			current_elite_chance = 0  # Исключаем элитную комнату из следующего выбора
		RoomType.SHOP:
			current_shop_chance = 0   # Исключаем магазин из следующего выбора
		RoomType.CHALLENGE:
			current_challenge_chance = 0  # Исключаем испытание из следующего выбора
		# Обычные комнаты могут повторяться, поэтому для RoomType.NORMAL ничего не меняем
	
	# Создаем общий пул шансов с учетом модификаций
	var total_chance = current_normal_chance + current_elite_chance + current_shop_chance + current_challenge_chance
	
	# Если общий шанс равен 0, устанавливаем обычную комнату по умолчанию
	if total_chance == 0:
		return RoomType.NORMAL
	
	# Выберем случайное число в диапазоне общего шанса
	var roll = randi() % total_chance
	
	# Определяем, какому типу комнаты соответствует выпавшее число
	var current_sum = 0
	
	# Обычная комната
	current_sum += current_normal_chance
	if roll < current_sum:
		return RoomType.NORMAL
	
	# Элитная комната
	current_sum += current_elite_chance
	if roll < current_sum:
		return RoomType.ELITE
	
	# Магазин
	current_sum += current_shop_chance
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
		RoomType.NORMAL:
			min_enemies = 1
			max_enemies = 3
		RoomType.ELITE:
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
		# Всегда создаем базового врага
		var enemy_instance = enemy_scene.instantiate()
		
		# Определяем, будет ли это особый враг
		if should_spawn_special_enemy():
			convert_to_special_enemy(enemy_instance)
		
		add_child(enemy_instance)
		
		var world_position = tile_map.map_to_local(available_positions[i]) * tile_map.scale
		enemy_instance.position = world_position
		enemy_instance.scale = Vector2(1.604, 1.604)
	
	# Бонусы для элитных комнат применяются ко всем врагам
	if type == RoomType.ELITE:
		for enemy in get_tree().get_nodes_in_group('enemies'):
			enemy.hp += 2
			enemy.damage += 2
			enemy.heal_points += 2
			
func should_spawn_special_enemy() -> bool:
	# Базовый шанс
	var base_chance = special_enemy_chance
	
	# Увеличиваем шанс в элитных комнатах
	if type == RoomType.ELITE:
		base_chance += 15
	
	# Увеличиваем шанс в комнатах испытаний
	if type == RoomType.CHALLENGE:
		base_chance += 25
	
	# Ограничиваем максимальный шанс
	base_chance = min(base_chance, 75)
	print(randi() % 100 < base_chance)
	return randi() % 100 < base_chance
	
func convert_to_special_enemy(enemy_instance: Node) -> void:
	var total_weight = teleporter_weight + berserker_weight
	
	if total_weight == 0:
		print("Веса особых врагов не заданы, остается обычный враг")
		return
	
	var roll = randi() % total_weight
	
	if roll < teleporter_weight:
		# Превращаем в телепортера
		enemy_instance.set_script(teleporter_enemy_script)
		print("Враг превращен в Телепортера!")
	else:
		# Превращаем в берсерка
		enemy_instance.set_script(berserker_enemy_script)
		print("Враг превращен в Берсерка!")

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

func spawn_object_at_position(type_obj: EditMode.PlacementType, tile_position: Vector2i, rotation_degree: int = 0) -> void:
	match type_obj:
		EditMode.PlacementType.WALL:
			spawn_object(wall_scene, tile_position, rotation_degree)
		EditMode.PlacementType.DOOR:
			spawn_object(door_scene, tile_position, rotation_degree)
		EditMode.PlacementType.ITEM:
			spawn_object(item_scene, tile_position, rotation_degree)

# В room.gd
func spawn_object(scene: PackedScene, tile_position: Vector2i, rotation_degree: int = 0) -> void:
	if scene:
		var instance = scene.instantiate()
		add_child(instance)
		# Важно: преобразуем tile_position в целые числа
		var pos = Vector2i(int(tile_position.x), int(tile_position.y))
		instance.position = instance.get_world_position_from_tile(pos)
		if instance.has_method('set_rotation_degree'):
			instance.set_rotation_degree(rotation_degree)
