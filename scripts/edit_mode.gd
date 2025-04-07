extends Node2D

const SAVE_FILE_PATH = "res://layouts.save"

enum PlacementType {
	NONE,
	WALL,
	DOOR
}

var room: Node2D
var player: Node
var tile_map: TileMapLayer
var wall_scene: PackedScene
var door_scene: PackedScene
var allow_layout_editing: bool = false
var current_placement_type: int = PlacementType.WALL
var degree: int = 0

var saved_layouts: Array = []
var edit_mode: bool = false
var selected_layout_index: int = -1

@onready var edit_label: Label = $edit_label
@onready var layout_label: Label = $layout_label
@onready var table_node: Table = $"../../Table"
@onready var ui_node: UI = $"../../UI"
@onready var object_menu: Node2D = $"ObjectMenu"

func init(parent_room: Node2D, player_node: Node, tilemap: TileMapLayer, 
		wall_packed_scene: PackedScene, door_packed_scene: PackedScene, editing_allowed: bool) -> void:
	room = parent_room
	player = player_node
	tile_map = tilemap
	wall_scene = wall_packed_scene
	door_scene = door_packed_scene
	allow_layout_editing = editing_allowed
	
	load_saved_layouts()
	
	if saved_layouts.is_empty():
		save_current_layout()
	
	edit_label.visible = allow_layout_editing
	layout_label.visible = false
	object_menu.visible = edit_mode

func _input(event: InputEvent) -> void:
	if not allow_layout_editing:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and edit_mode:
		place_object_at_mouse(get_global_mouse_position())
	elif event is InputEventKey and event.pressed:
		handle_key_input(event.keycode)

func handle_key_input(keycode: int) -> void:
	if not edit_mode and keycode != KEY_E:
		return
		
	match keycode:
		KEY_E: toggle_edit_mode()
		KEY_R: degree = (degree + 90) % 360
		KEY_S: save_current_layout()
		KEY_C: room.clear_walls()
		KEY_D: delete_current_layout()
		KEY_RIGHT: cycle_layout(1)
		KEY_LEFT: cycle_layout(-1)
		KEY_1: set_placement_type(PlacementType.WALL)
		KEY_2: set_placement_type(PlacementType.DOOR)

func update_layout_label() -> void:
	if layout_label:
		var current_index = selected_layout_index + 1 if selected_layout_index >= 0 else 0
		layout_label.text = "Пресет: %d/%d" % [current_index, saved_layouts.size()]

func toggle_edit_mode() -> void:
	edit_mode = !edit_mode
	
	# Update visibility
	layout_label.visible = edit_mode
	table_node.visible = !edit_mode
	ui_node.visible = !edit_mode
	object_menu.visible = edit_mode
	
	# Hide/show enemies
	for enemy in get_tree().get_nodes_in_group('enemies'):
		enemy.visible = !edit_mode
	
	# Update edit label
	if edit_label:
		var status = "включен" if edit_mode else "выключен"
		edit_label.text = "Режим редактирования %s (нажмите E для переключения)" % status
		if edit_mode:
			edit_label.text += "\nS-сохранить, C-очистить, D-удалить, Стрелки-листать"

func set_placement_type(type: int) -> void:
	current_placement_type = type

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
		
	var layout = saved_layouts[index]
	
	if layout is Array:
		for object_data in layout:
			if not _is_valid_object_data(object_data):
				continue
				
			var position = Vector2(object_data.x, object_data.y)
			var type = object_data.get("type", PlacementType.WALL)
			
			match type:
				PlacementType.WALL:
					room.spawn_wall_at_position(position)
				PlacementType.DOOR:
					var door_degree = object_data.get("degree", 0)
					room.spawn_door_at_position(position, door_degree)

func _is_valid_object_data(data: Variant) -> bool:
	return data is Dictionary and data.has("x") and data.has("y")

func place_object_at_mouse(mouse_position: Vector2) -> void:
	var tile_pos = tile_map.local_to_map(tile_map.to_local(mouse_position))
	
	# Проверяем, существует ли объект в этой позиции
	for obj in get_tree().get_nodes_in_group('objects'):
		if obj.get_tile_position() == Vector2(tile_pos):
			obj.queue_free()
			return
	
	# Проверяем, валидна ли позиция
	if not is_valid_object_position(tile_pos, current_placement_type):
		return
	
	# Размещаем новый объект
	match current_placement_type:
		PlacementType.WALL:
			room.spawn_wall_at_position(tile_pos)
		PlacementType.DOOR:
			room.spawn_door_at_position(tile_pos, degree)

func is_valid_object_position(tile_pos: Vector2, object_type: int) -> bool:
	# Check if position is within tile map bounds
	if not tile_map.get_used_rect().has_point(tile_pos):
		return false
	
	# Check if position is already occupied by non-barrier, non-door object
	for obj in get_tree().get_nodes_in_group('objects'):
		if tile_pos == obj.get_tile_position() and !obj.is_in_group('barrier') and !obj.is_in_group('doors'):
			return false
	
	# Проверки для стен
	if object_type == PlacementType.WALL:
		# Check proximity to doors
		for door_pos in room.DOOR_POSITIONS.values():
			if room.calculate_path_length(tile_pos, door_pos) < 2:
				return false
	
	return true

func load_saved_layouts() -> void:
	saved_layouts.clear()
	
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		_initialize_empty_save_file()
		return
	
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		var json_result = JSON.parse_string(json_text)
		if json_result is Array:
			saved_layouts = json_result

func _initialize_empty_save_file() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify([]))

func save_layouts_to_file() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_layouts))

func save_current_layout() -> void:
	var objects_data: Array = []
	
	# Сохраняем стены (исключая двери)
	for wall in get_tree().get_nodes_in_group('barrier'):
		if not wall.is_in_group('doors'):
			var pos = wall.get_tile_position()
			objects_data.append({"x": pos.x, "y": pos.y, "type": PlacementType.WALL})
	
	# Сохраняем двери с градусом поворота
	for door in get_tree().get_nodes_in_group('doors'):
		var pos = door.get_tile_position()
		objects_data.append({
			"x": pos.x, 
			"y": pos.y, 
			"type": PlacementType.DOOR,
			"degree": door.degree
		})
	
	if objects_data.is_empty() or layout_exists_in_saved(objects_data):
		return
		
	saved_layouts.append(objects_data)
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

# Обработчики событий UI кнопок
func _on_door_button_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_placement_type(PlacementType.DOOR)

func _on_wall_button_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_placement_type(PlacementType.WALL)
