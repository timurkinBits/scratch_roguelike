extends Node2D

signal room_changed(direction: String)

@export var enemy_scene: PackedScene
@export var max_enemies: int = 3
@export var min_enemies: int = 1
@export var min_distance_from_player: int = 5
@export var wall_scene: PackedScene
@export var door_scene: PackedScene
@export var allow_layout_editing: bool = false

const DOOR_POSITIONS = {
	"up": Vector2(7, 0),
	"down": Vector2(7, 10),
	"left": Vector2(2, 5),
	"right": Vector2(12, 5)
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
@onready var doors: Control = $Doors

func _ready() -> void:
	doors.visible = false
	init_edit_mode()
	spawn_enemies()

func init_edit_mode() -> void:
	edit_mode_manager.init(self, player, tile_map, wall_scene, door_scene, allow_layout_editing)
	edit_mode_manager.apply_random_layout()

func apply_random_layout() -> void:
	clear_walls()
	edit_mode_manager.apply_random_layout()

func clear_walls() -> void:
	for wall in get_tree().get_nodes_in_group('objects'):
		wall.queue_free()

func clear_room() -> void:
	clear_enemies()
	clear_walls()

func teleport_player_to_door(door_direction: String) -> void:
	var target_tile = DOOR_POSITIONS[door_direction]
	var world_position = player.get_world_position_from_tile(target_tile)
	
	player.position = world_position
	player.current_direction = OPPOSITE_DIRECTIONS[door_direction]
	player.update_visual()

func transition_to_new_room(direction: String) -> void:
	clear_room()
	teleport_player_to_door(OPPOSITE_DIRECTIONS[direction])
	doors.visible = false
	Global.reset_remaining_points()
	edit_mode_manager.check_and_apply_layout()
	spawn_enemies()
	room_changed.emit(direction)

# Обобщенный обработчик событий дверей
func _on_door_input_event(direction: String, _viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		transition_to_new_room(direction)

# Обработчики для каждого направления
func _on_right_door_input_event(viewport, event, shape_idx) -> void:
	_on_door_input_event("right", viewport, event, shape_idx)

func _on_left_door_input_event(viewport, event, shape_idx) -> void:
	_on_door_input_event("left", viewport, event, shape_idx)

func _on_down_door_input_event(viewport, event, shape_idx) -> void:
	_on_door_input_event("down", viewport, event, shape_idx)
			
func _on_up_door_input_event(viewport, event, shape_idx) -> void:
	_on_door_input_event("up", viewport, event, shape_idx)

func spawn_enemies() -> void:
	clear_enemies()
	
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

func clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()

func get_available_spawn_positions() -> Array:
	var available_positions: Array = []
	var tilemap_rect = tile_map.get_used_rect()
	var player_tile_position = player.get_tile_position()
	
	# Получаем позиции всех препятствий
	var barrier_positions = []
	for barrier in get_tree().get_nodes_in_group("barrier"):
		barrier_positions.append(barrier.get_tile_position())
	
	# Проверяем каждую плитку на карте
	for x in range(tilemap_rect.position.x, tilemap_rect.position.x + tilemap_rect.size.x):
		for y in range(tilemap_rect.position.y, tilemap_rect.position.y + tilemap_rect.size.y):
			var current_tile = Vector2(x, y)
			
			# Пропускаем плитки слишком близкие к игроку
			if calculate_path_length(current_tile, player_tile_position) < min_distance_from_player:
				continue
			
			# Пропускаем плитки с препятствиями
			if current_tile in barrier_positions:
				continue
			
			available_positions.append(current_tile)
	
	return available_positions

func calculate_path_length(from_tile: Vector2, to_tile: Vector2) -> int:
	return int(abs(from_tile.x - to_tile.x) + abs(from_tile.y - to_tile.y))

func spawn_wall_at_position(tile_position: Vector2) -> void:
	if wall_scene:
		var wall_instance = wall_scene.instantiate()
		add_child(wall_instance)  # Убедитесь, что объект добавляется в сцену
		wall_instance.position = wall_instance.get_world_position_from_tile(tile_position)

func spawn_door_at_position(tile_position: Vector2, rotation_degree: int) -> void:
	if door_scene:
		var door_instance = door_scene.instantiate()
		add_child(door_instance)
		door_instance.position = door_instance.get_world_position_from_tile(tile_position)
		door_instance.set_rotation_degree(rotation_degree)  # Устанавливаем угол поворота
		#door_instance.visible = false
