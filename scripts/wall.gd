extends Node2D

var tilemap: TileMapLayer

func _ready() -> void:
	add_to_group("barrier")
	
	tilemap = get_parent().get_node("TileMapLayer")
	var tile_pos = get_tile_position()
	position = get_world_position_from_tile(tile_pos)
	
func get_tile_position() -> Vector2:
	var local_pos = position / tilemap.scale
	return tilemap.local_to_map(local_pos)
	
func get_world_position_from_tile(tile_pos: Vector2) -> Vector2:
	var local_center = tilemap.map_to_local(tile_pos)
	return local_center * tilemap.scale
