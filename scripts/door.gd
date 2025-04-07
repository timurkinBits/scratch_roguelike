extends Node2D

@onready var tilemap: TileMapLayer = get_tree().get_first_node_in_group("TileMap")
@onready var closed_sprite: Sprite2D = $ClosedSprite
@onready var opened_sprite: Sprite2D = $OpenedSprite

var is_opened: bool = false
var degree: int = 0

func _ready() -> void:
	add_to_group('doors')
	add_to_group('objects')
	
	toggle_door(is_opened)
	
	position = get_world_position_from_tile(get_tile_position())
	
func toggle_door(is_door_opened: bool) -> void:
	is_opened = is_door_opened
	opened_sprite.visible = is_door_opened
	closed_sprite.visible = !is_door_opened
	
	if is_opened:
		remove_from_group('barrier')
	else:
		add_to_group('barrier')
	
func get_tile_position() -> Vector2:
	return tilemap.local_to_map(position / tilemap.scale)
	
func get_world_position_from_tile(tile_pos: Vector2) -> Vector2:
	return tilemap.map_to_local(tile_pos) * tilemap.scale

# Упрощенный метод установки поворота
func set_rotation_degree(rot_degree: int) -> void:
	degree = rot_degree
	rotation_degrees = rot_degree
