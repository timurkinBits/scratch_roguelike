extends Node2D

const SAVE_FILE_PATH = "res://wall_layouts.save"

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

@onready var edit_label: Label = $edit_label
@onready var layout_label: Label = $layout_label
@onready var table_node: Table = $"../../Table"
@onready var ui_node: UI = $"../../UI"
@onready var object_menu: Node2D = $"ObjectMenu"

var saved_layouts: Array = []
var edit_mode: bool = false
var selected_layout_index: int = -1

func init(parent_room: Node2D, player_node: Node, tilemap: TileMapLayer, wall_packed_scene: PackedScene, door_packed_scene: PackedScene, editing_allowed: bool) -> void:
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
		# Размещаем объект в зависимости от текущего типа
		place_object_at_mouse(get_global_mouse_position())
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
			KEY_1:
				if edit_mode:
					set_placement_type(PlacementType.WALL)
			KEY_2:
				if edit_mode:
					set_placement_type(PlacementType.DOOR)

func update_layout_label() -> void:
	if layout_label:
		var current_index = selected_layout_index + 1 if selected_layout_index >= 0 else 0
		layout_label.text = "Пресет: " + str(current_index) + "/" + str(saved_layouts.size())

func toggle_edit_mode() -> void:
	edit_mode = !edit_mode
	layout_label.visible = edit_mode
	table_node.visible = !edit_mode
	ui_node.visible = !edit_mode
	object_menu.visible = edit_mode
	for enemy in get_tree().get_nodes_in_group('enemies'):
		enemy.visible = !edit_mode
	if edit_label:
		edit_label.text = "Режим редактирования " + ("включен" if edit_mode else "выключен") + " (нажмите E для переключения)"
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
		
	var selected_layout = saved_layouts[index]
	
	if selected_layout is Array:
		for object_data in selected_layout:
			if object_data is Dictionary and object_data.has("x") and object_data.has("y"):
				var position = Vector2(object_data.x, object_data.y)
				var type = object_data.get("type", PlacementType.WALL)
				
				if type == PlacementType.WALL:
					room.spawn_wall_at_position(position)
				elif type == PlacementType.DOOR:
					room.spawn_door_at_position(position)

func place_object_at_mouse(mouse_position: Vector2) -> void:
	var local_pos = tile_map.to_local(mouse_position)
	var tile_pos = tile_map.local_to_map(local_pos)
	
	# Проверка валидности позиции
	if not is_valid_object_position(tile_pos, current_placement_type):
		return
		
	# Проверка наличия объекта и удаление если есть
	var objects = room.get_tree().get_nodes_in_group('objects')
	for obj in objects:
		if obj.get_tile_position() == Vector2(tile_pos):
			obj.queue_free()
			return
	
	# Размещаем новый объект в зависимости от выбранного типа
	match current_placement_type:
		PlacementType.WALL:
			room.spawn_wall_at_position(tile_pos)
		PlacementType.DOOR:
			room.spawn_door_at_position(tile_pos)

func is_valid_object_position(tile_pos: Vector2, object_type: int) -> bool:
	# Проверка, не находится ли позиция на игроке
	for obj in get_tree().get_nodes_in_group('objects'):
		if tile_pos == obj.get_tile_position() and !obj.is_in_group('barrier') and !obj.is_in_group('doors'):
			return false
	
	# Дополнительные проверки в зависимости от типа объекта
	match object_type:
		PlacementType.WALL:
			# Проверка близости к дверям
			for door_pos in room.DOOR_POSITIONS.values():
				if room.calculate_path_length(tile_pos, door_pos) < 2:
					return false
		
		PlacementType.DOOR:
			# Возможно, дополнительные проверки для дверей
			pass
	
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
	var objects_data: Array = []
	
	# Сохраняем стены
	for wall in room.get_tree().get_nodes_in_group('barrier'):
		if !wall.is_in_group('edit_mode_button'):
			var pos: Vector2 = wall.get_tile_position()
			objects_data.append({"x": pos.x, "y": pos.y, "type": PlacementType.WALL})
	
	# Сохраняем двери
	for door in room.get_tree().get_nodes_in_group('doors'):
		if !door.is_in_group('edit_mode_button'):
			var pos: Vector2 = door.get_tile_position()
			objects_data.append({"x": pos.x, "y": pos.y, "type": PlacementType.DOOR})
	
	if objects_data.is_empty():
		return
	
	if layout_exists_in_saved(objects_data):
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

func _on_door_button_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			set_placement_type(PlacementType.DOOR)

func _on_wall_button_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			set_placement_type(PlacementType.WALL)
