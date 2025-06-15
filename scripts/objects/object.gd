extends Node2D
class_name ObjectRoom

@onready var tilemap: TileMapLayer = get_tree().get_first_node_in_group("TileMap")

func _ready() -> void:
	add_to_group('objects')
	position = get_world_position_from_tile(get_tile_position())

func get_tile_position() -> Vector2:
	return tilemap.local_to_map(position / tilemap.scale)
	
func get_world_position_from_tile(tile_pos: Vector2) -> Vector2:
	return tilemap.map_to_local(tile_pos) * tilemap.scale
