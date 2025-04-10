extends Node2D
class_name Coin

@onready var tilemap: TileMapLayer = get_tree().get_first_node_in_group("TileMap")

func _ready() -> void:
	add_to_group('coins')  # Add to coins group for easy finding
	
	var tile_pos = get_tile_position()
	position = get_world_position_from_tile(tile_pos)
	
func pickup():
	Global.add_coins(1)  # Add one coin to global counter
	queue_free()  # Remove the coin from the scene
	
func get_tile_position() -> Vector2:
	var local_pos = position / tilemap.scale
	return tilemap.local_to_map(local_pos)
	
func get_world_position_from_tile(tile_pos: Vector2) -> Vector2:
	var local_center = tilemap.map_to_local(tile_pos)
	return local_center * tilemap.scale - Vector2(0, 1)
