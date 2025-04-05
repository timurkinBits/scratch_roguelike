extends Node2D

@onready var tilemap: TileMapLayer = get_tree().get_first_node_in_group("TileMap")
@onready var closed_sprite: Sprite2D = $ClosedSprite
@onready var opened_sprite: Sprite2D = $OpenedSprite

var is_opened: bool = false

func _ready() -> void:
	add_to_group('doors')
	add_to_group('objects')
	
	toggle_door(is_opened)
	
	var tile_pos = get_tile_position()
	position = get_world_position_from_tile(tile_pos)
	
func toggle_door(is_door_opened: bool):
	is_opened = is_door_opened
	opened_sprite.visible = is_door_opened
	closed_sprite.visible = !is_door_opened
	
func get_tile_position() -> Vector2:
	var local_pos = position / tilemap.scale
	return tilemap.local_to_map(local_pos)
	
func get_world_position_from_tile(tile_pos: Vector2) -> Vector2:
	var local_center = tilemap.map_to_local(tile_pos)
	return local_center * tilemap.scale
