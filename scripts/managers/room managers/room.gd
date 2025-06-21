extends Node2D

signal room_changed(direction: String)

@export var enemy_scene: PackedScene
@export var wall_scene: PackedScene
@export var door_scene: PackedScene
@export var info_scene: PackedScene
@export var item_scene: PackedScene
@export var allow_layout_editing: bool = false

# Настройки шансов для каждого типа комнаты
@export_group("Room Spawn Chances")
@export_range(0, 100) var normal_room_chance: int = 50
@export_range(0, 100) var shop_room_chance: int = 30
@export_range(0, 100) var elite_room_chance: int = 10
@export_range(0, 100) var challenge_room_chance: int = 10

# Настройки шансов замены обычных врагов на специальных
@export_group("Special Enemy Replacement Chances")
@export_range(0, 100) var normal_room_special_chance: int = 25
@export_range(0, 100) var elite_room_special_chance: int = 45
@export_range(0, 100) var challenge_room_special_chance: int = 0
@export_range(0, 100) var shop_room_special_chance: int = 0

const DOOR_POSITIONS = {
	"up": Vector2(7, 0),
	"down": Vector2(7, 10),
	"left": Vector2(2, 5),
	"right": Vector2(12, 5)
}

const DOOR_ICONS = {
	Global.RoomType.NORMAL: "res://sprites/normal.png",
	Global.RoomType.ELITE: "res://sprites/elite.png",
	Global.RoomType.SHOP: "res://sprites/shop.png",
	Global.RoomType.CHALLENGE: "res://sprites/challenge.png"
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

var type: Global.RoomType = Global.RoomType.NORMAL
var max_enemies: int = 3
var min_enemies: int = 1
var min_distance_from_player: int = 5
var door_types_generated: bool = false

func _ready() -> void:
	for exit_door in doors:
		exit_door.get_node('button').visible = false
	
	# Обновляем настройки шансов замены в реестре
	update_registry_replacement_chances()
	
	init_edit_mode()
	spawn_enemies()
	
func update_registry_replacement_chances() -> void:
	EnemyRegistry.set_replacement_chance(Global.RoomType.NORMAL, normal_room_special_chance)
	EnemyRegistry.set_replacement_chance(Global.RoomType.ELITE, elite_room_special_chance)
	EnemyRegistry.set_replacement_chance(Global.RoomType.CHALLENGE, challenge_room_special_chance)
	EnemyRegistry.set_replacement_chance(Global.RoomType.SHOP, shop_room_special_chance)

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

# Генерация типов комнат с учетом весов
func random_types_rooms() -> void:
	if door_types_generated:
		return
	
	door_types_generated = true
	
	for door in doors:
		var room_type = get_weighted_room_type()
		door.type = Global.RoomType.keys()[room_type]
		door.get_node('button').texture = load(DOOR_ICONS[room_type])

func get_weighted_room_type() -> int:
	var current_normal_chance = normal_room_chance
	var current_elite_chance = elite_room_chance
	var current_shop_chance = shop_room_chance
	var current_challenge_chance = challenge_room_chance
	
	# Предотвращаем повторение текущего типа комнаты (кроме обычной)
	match type:
		Global.RoomType.ELITE:
			current_elite_chance = 0
		Global.RoomType.SHOP:
			current_shop_chance = 0
		Global.RoomType.CHALLENGE:
			current_challenge_chance = 0
	
	var total_chance = current_normal_chance + current_elite_chance + current_shop_chance + current_challenge_chance
	
	if total_chance == 0:
		return Global.RoomType.NORMAL
	
	var roll = randi() % total_chance
	var current_sum = 0
	
	current_sum += current_normal_chance
	if roll < current_sum:
		return Global.RoomType.NORMAL
	
	current_sum += current_elite_chance
	if roll < current_sum:
		return Global.RoomType.ELITE
	
	current_sum += current_shop_chance
	if roll < current_sum:
		return Global.RoomType.SHOP
	
	return Global.RoomType.CHALLENGE

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
			type = Global.RoomType[door_type]
		else:
			type = door_type
	
	for exit_door in doors:
		exit_door.get_node('button').visible = false
	
	Global.reset_remaining_points()
	Global.reset_special_commands()
	door_types_generated = false
	
	# Обновляем настройки шансов замены при смене комнаты
	update_registry_replacement_chances()
	
	apply_layout_for_current_type()
	apply_room_type_settings()
	spawn_enemies()
	room_changed.emit(direction)
	
	DifficultyManager.increase_difficulty_for_room(type)

func apply_room_type_settings() -> void:
	match type:
		Global.RoomType.NORMAL:
			min_enemies = 1
			max_enemies = 3
		Global.RoomType.ELITE:
			min_enemies = 2
			max_enemies = 4
		Global.RoomType.SHOP:
			pass
		Global.RoomType.CHALLENGE:
			min_enemies = 0
			max_enemies = 0

# Обработчики дверей
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
	
	if type == Global.RoomType.SHOP:
		return
	
	var available_positions = get_available_spawn_positions()
	if available_positions.is_empty():
		return
	
	available_positions.shuffle()
	
	# ИСПРАВЛЕНО: Используем масштабированные значения для определения количества врагов
	var scaled_max_enemies = DifficultyManager.get_scaled_max_enemies(max_enemies)
	var scaled_min_enemies = min(min_enemies, scaled_max_enemies)  # Убеждаемся что min не больше max
	
	var enemy_count = min(randi_range(scaled_min_enemies, scaled_max_enemies), available_positions.size())
	
	# Создаем контекст для условий спавна
	var room_context = {
		"total_enemies": enemy_count,
		"room_type": type,
		"available_positions": available_positions.size()
	}
	
	var special_enemy_count = 0  # Для отладки
	
	for i in range(enemy_count):
		var enemy_instance = enemy_scene.instantiate()
		
		# Обновляем контекст для текущего врага
		room_context["current_spawn_index"] = i
		
		# ИСПРАВЛЕНО: Проверяем замену на специального врага с отладкой
		var should_replace = EnemyRegistry.should_replace_with_special_enemy(type, room_context)
		
		if should_replace:
			var special_script_path = EnemyRegistry.get_random_special_enemy_script(type, room_context)
			if special_script_path != "":
				var special_script = load(special_script_path)
				if special_script:
					enemy_instance.set_script(special_script)
					special_enemy_count += 1
		
		add_child(enemy_instance)
		
		# ВАЖНО: Применяем масштабирование сложности после добавления в сцену
		apply_difficulty_scaling_to_enemy(enemy_instance)
		
		var world_position = tile_map.map_to_local(available_positions[i]) * tile_map.scale
		enemy_instance.position = world_position
		enemy_instance.scale = Vector2(1.604, 1.604)
	
	# Бонусы для элитных комнат применяются ПОСЛЕ масштабирования сложности
	if type == Global.RoomType.ELITE:
		apply_elite_bonuses()

# ИСПРАВЛЕНО: Функция для применения масштабирования сложности к врагу
func apply_difficulty_scaling_to_enemy(enemy: Enemy) -> void:
	# Сохраняем базовые значения если они еще не сохранены
	if not enemy.has_meta("base_hp"):
		enemy.set_meta("base_hp", enemy.heal_points)
	if not enemy.has_meta("base_damage"):
		enemy.set_meta("base_damage", enemy.damage)  
	if not enemy.has_meta("base_speed"):
		enemy.set_meta("base_speed", enemy.speed)
	
	# Применяем масштабирование на основе базовых значений
	var base_hp = enemy.get_meta("base_hp")
	var base_damage = enemy.get_meta("base_damage")
	var base_speed = enemy.get_meta("base_speed")
	
	var old_hp = enemy.heal_points
	var old_damage = enemy.damage
	var old_speed = enemy.speed
	
	enemy.heal_points = DifficultyManager.get_scaled_hp(base_hp)
	enemy.hp = enemy.heal_points  # Устанавливаем текущие ХП
	enemy.damage = DifficultyManager.get_scaled_damage(base_damage)
	enemy.speed = DifficultyManager.get_scaled_speed(base_speed)

func apply_elite_bonuses() -> void:
	for enemy in get_tree().get_nodes_in_group('enemies'):
		# Элитные бонусы применяются поверх масштабирования сложности
		var old_hp = enemy.hp
		var old_damage = enemy.damage
		
		enemy.hp += 2
		enemy.damage += 2
		enemy.heal_points += 2

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

func spawn_object(scene: PackedScene, tile_position: Vector2i, rotation_degree: int = 0) -> void:
	if scene:
		var instance = scene.instantiate()
		add_child(instance)
		var pos = Vector2i(int(tile_position.x), int(tile_position.y))
		instance.position = instance.get_world_position_from_tile(pos)
		if instance.has_method('set_rotation_degree'):
			instance.set_rotation_degree(rotation_degree)
