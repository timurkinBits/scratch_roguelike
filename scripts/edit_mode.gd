extends Node2D

const SAVE_FILE_PATH = "res://wall_layouts.save"

var room: Node2D
var player: Node
var tile_map: TileMapLayer
var wall_scene: PackedScene
var allow_layout_editing: bool = false

@onready var edit_label: Label = $"../../UI/edit_label"
@onready var layout_label: Label = $"../../UI/layout_label"

var saved_layouts: Array = []
var edit_mode: bool = false
var selected_layout_index: int = -1

func init(parent_room: Node2D, player_node: Node, tilemap: TileMapLayer, wall_packed_scene: PackedScene, editing_allowed: bool) -> void:
	room = parent_room
	player = player_node
	tile_map = tilemap
	wall_scene = wall_packed_scene
	allow_layout_editing = editing_allowed
	
	load_saved_layouts()
	
	if saved_layouts.is_empty():
		save_current_layout()
	
	edit_label.visible = allow_layout_editing
	layout_label.visible = false

func _input(event: InputEvent) -> void:
	if not allow_layout_editing:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and edit_mode:
		place_wall_at_mouse(get_global_mouse_position())
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_E:
				toggle_edit_mode()
			KEY_S:
				if edit_mode:
					save_current_layout()
			KEY_C:
				if edit_mode:
					room.clear_walls()
			KEY_D:
				if edit_mode:
					delete_current_layout()
			KEY_RIGHT:
				if edit_mode:
					cycle_layout(1)
			KEY_LEFT:
				if edit_mode:
					cycle_layout(-1)

func update_layout_label() -> void:
	if layout_label:
		var current_index = selected_layout_index + 1 if selected_layout_index >= 0 else 0
		layout_label.text = "Пресет: " + str(current_index) + "/" + str(saved_layouts.size())

func toggle_edit_mode() -> void:
	edit_mode = !edit_mode
	layout_label.visible = edit_mode
	
	if edit_label:
		edit_label.text = "Режим редактирования " + ("включен" if edit_mode else "выключен") + " (нажмите E для переключения)"
		if edit_mode:
			edit_label.text += "\nS-сохранить, C-очистить, D-удалить, стрелки-листать"

func cycle_layout(direction: int) -> void:
	if saved_layouts.is_empty():
		return
		
	selected_layout_index = posmod(selected_layout_index + direction, saved_layouts.size())
	apply_layout_by_index(selected_layout_index)
	update_layout_label()

func delete_current_layout() -> void:
	if selected_layout_index < 0 or selected_layout_index >= saved_layouts.size():
		return
	
	saved_layouts.remove_at(selected_layout_index)
	save_layouts_to_file()
	
	if saved_layouts.is_empty():
		selected_layout_index = -1
		room.clear_walls()
	else:
		selected_layout_index = min(selected_layout_index, saved_layouts.size() - 1)
		apply_layout_by_index(selected_layout_index)
	
	update_layout_label()

func apply_layout_by_index(index: int) -> void:
	room.clear_walls()
	
	if index < 0 or index >= saved_layouts.size():
		return
		
	var selected_layout = saved_layouts[index]
	
	if selected_layout is Array:
		for wall_data in selected_layout:
			if wall_data is Dictionary and wall_data.has("x") and wall_data.has("y"):
				room.spawn_wall_at_position(Vector2(wall_data.x, wall_data.y))

func place_wall_at_mouse(mouse_position: Vector2) -> void:
	var local_pos = tile_map.to_local(mouse_position)
	var tile_pos = tile_map.local_to_map(local_pos)
	
	# Проверка наличия стены и удаление если есть
	var walls = room.get_tree().get_nodes_in_group('barrier')
	for wall in walls:
		if wall.get_tile_position() == Vector2(tile_pos):
			wall.queue_free()
			return
	
	# Проверка валидности позиции
	if not is_valid_wall_position(tile_pos):
		return
	
	room.spawn_wall_at_position(tile_pos)

func is_valid_wall_position(tile_pos: Vector2) -> bool:
	# Проверка, не находится ли позиция на игроке
	if tile_pos == player.get_tile_position():
		return false
		
	# Проверка близости к дверям
	for door_pos in room.DOOR_POSITIONS.values():
		if room.calculate_path_length(tile_pos, door_pos) < 2:
			return false
	
	# Проверка границ карты
	if not tile_map.get_used_rect().has_point(tile_pos):
		return false
	
	return true

func load_saved_layouts() -> void:
	saved_layouts.clear()
	
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify([]))
		return
	
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		return
		
	var json_text := file.get_as_text()
	var json_result = JSON.parse_string(json_text)
	if json_result is Array:
		saved_layouts = json_result

func save_layouts_to_file() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_layouts))

func save_current_layout() -> void:
	var walls_positions: Array = []
	for wall in room.get_tree().get_nodes_in_group('barrier'):
		var pos: Vector2 = wall.get_tile_position()
		walls_positions.append({"x": pos.x, "y": pos.y})
	
	if walls_positions.is_empty():
		return
	
	if layout_exists_in_saved(walls_positions):
		return
		
	saved_layouts.append(walls_positions)
	selected_layout_index = saved_layouts.size() - 1
	
	save_layouts_to_file()
	update_layout_label()

func layout_exists_in_saved(layout: Array) -> bool:
	var layout_str := JSON.stringify(layout)
	
	for saved_layout in saved_layouts:
		if JSON.stringify(saved_layout) == layout_str:
			return true
	
	return false

func apply_random_layout() -> void:
	if saved_layouts.is_empty():
		return
		
	var random_index := randi() % saved_layouts.size()
	selected_layout_index = random_index
	apply_layout_by_index(random_index)
	update_layout_label()

func check_and_apply_layout() -> void:
	if saved_layouts.is_empty():
		save_current_layout()
	else:
		apply_random_layout()
