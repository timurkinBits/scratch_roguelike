extends Node2D
class_name EditMode

# Пути к файлам для разных типов комнат
const BASE_SAVE_PATH = "res://layouts"
const SAVE_FILE_EXTENSION = ".save"

enum PlacementType {
	NONE,
	WALL,
	DOOR,
	INFO
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

# Словарь для хранения макетов комнат по типам
var room_layouts: Dictionary = {}
var current_room_type: int = 0
var edit_mode: bool = false
var selected_layout_index: int = -1
var degree: int = 0

# Создаем имена для файлов и отображаемые имена типов комнат
var room_type_file_names = {
	0: "normal_enemies",
	1: "elite_enemies",
	2: "shop",
	3: "challenge"
}

var room_type_display_names = {
	0: "Обычные враги",
	1: "Элитные враги",
	2: "Магазин",
	3: "Испытание"
}

func init(parent_room: Node2D, player_node: Node, tilemap: TileMapLayer, wall_packed_scene: PackedScene, door_packed_scene: PackedScene, editing_allowed: bool) -> void:
	room = parent_room
	player = player_node
	tile_map = tilemap
	wall_scene = wall_packed_scene
	door_scene = door_packed_scene
	allow_layout_editing = editing_allowed
	
	# Загружаем макеты комнат всех типов
	load_all_layouts()
	
	# Если для какого-то типа комнат нет макетов, сохраняем текущий
	for room_type in room_type_file_names.keys():
		if room_layouts.get(room_type, []).is_empty():
			save_current_layout(room_type)
	
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
			KEY_R:
				if edit_mode:
					degree += 90
					if degree == 360:
						degree = 0
			KEY_S:
				if edit_mode:
					save_current_layout(current_room_type)
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
			# Добавляем клавиши для переключения типов комнат
			KEY_1:
				if edit_mode:
					current_room_type = 0
					update_layout_label()
					apply_layout_by_index(0, current_room_type)
					@warning_ignore("narrowing_conversion")
					cycle_layout(-INF)
			KEY_2:
				if edit_mode:
					current_room_type = 1
					update_layout_label()
					apply_layout_by_index(0, current_room_type)
					@warning_ignore("narrowing_conversion")
					cycle_layout(-INF)
			KEY_3:
				if edit_mode:
					current_room_type = 2
					update_layout_label()
					apply_layout_by_index(0, current_room_type)
					@warning_ignore("narrowing_conversion")
					cycle_layout(-INF)
			KEY_4:
				if edit_mode:
					current_room_type = 3
					update_layout_label()
					apply_layout_by_index(0, current_room_type)
					@warning_ignore("narrowing_conversion")
					cycle_layout(-INF)

func update_layout_label() -> void:
	var layouts = room_layouts.get(current_room_type, [])
	var current_index = selected_layout_index + 1 if selected_layout_index >= 0 else 0
	var type_name = room_type_display_names.get(current_room_type, "Неизвестный")
	layout_label.text = type_name + " (пресет: " + str(current_index) + "/" + str(layouts.size()) + ")"

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
			edit_label.text += "\nS-сохранить, C-очистить, D-удалить, Стрелки-листать\n1-4: типы комнат"

func set_placement_type(type: int) -> void:
	current_placement_type = type

func cycle_layout(direction: int) -> void:
	var layouts = room_layouts.get(current_room_type, [])
	if layouts.is_empty():
		return
		
	selected_layout_index = posmod(selected_layout_index + direction, layouts.size())
	apply_layout_by_index(selected_layout_index, current_room_type)
	update_layout_label()

func delete_current_layout() -> void:
	var layouts = room_layouts.get(current_room_type, [])
	if selected_layout_index < 0 or selected_layout_index >= layouts.size():
		return
	
	layouts.remove_at(selected_layout_index)
	room_layouts[current_room_type] = layouts
	save_layouts_to_file(current_room_type)
	
	if layouts.is_empty():
		selected_layout_index = -1
		room.clear_walls()
	else:
		selected_layout_index = min(selected_layout_index, layouts.size() - 1)
		apply_layout_by_index(selected_layout_index, current_room_type)
	
	update_layout_label()

func apply_layout_by_index(index: int, room_type: int) -> void:
	room.clear_walls()
	
	var layouts = room_layouts.get(room_type, [])
	if index < 0 or index >= layouts.size():
		return
		
	var selected_layout = layouts[index]
	if not selected_layout is Array:
		return
	
	# Словарь для отслеживания занятых позиций и их типов
	var position_map: Dictionary = {}
	
	# Сначала собираем все объекты, чтобы выявить конфликты
	for object_data in selected_layout:
		if object_data is Dictionary and object_data.has("x") and object_data.has("y"):
			var position_obj = Vector2(object_data.x, object_data.y)
			var type = object_data.get("t", PlacementType.WALL)
			var degree_obj = object_data.get("d", 0)
			
			# Если позиция уже занята, даём приоритет дверям
			if position_map.has(position_obj):
				if position_map[position_obj].t == PlacementType.DOOR:
					continue  # Дверь уже есть, пропускаем стену
				elif type == PlacementType.DOOR:
					position_map[position_obj] = {"t": type, "d": degree_obj}  # Заменяем стену дверью
			else:
				position_map[position_obj] = {"t": type, "d": degree_obj}
	
	# Теперь размещаем объекты из отфильтрованного набора
	for pos in position_map.keys():
		var data = position_map[pos]
		room.spawn_object_at_position(data.t, pos, data.d)

func place_object_at_mouse(mouse_position: Vector2) -> void:
	var local_pos = tile_map.to_local(mouse_position)
	var tile_pos = tile_map.local_to_map(local_pos)
	# Проверка валидности позиции
	if not is_valid_object_position(tile_pos, current_placement_type):
		return
	# Проверка наличия объекта и удаление если есть
	var objects = get_tree().get_nodes_in_group('objects')
	for obj in objects:
		if obj.get_tile_position() == Vector2(tile_pos):
			obj.queue_free()
			return
	
	# Размещаем новый объект в зависимости от выбранного типа
	room.spawn_object_at_position(current_placement_type, tile_pos, degree)

func is_valid_object_position(tile_pos: Vector2, object_type: int) -> bool:
	match object_type:
		PlacementType.WALL:
			# Проверка близости к дверям
			for door_pos in room.DOOR_POSITIONS.values():
				if room.calculate_path_length(tile_pos, door_pos) < 2:
					return false
	
	# Проверка границ карты
	if not tile_map.get_used_rect().has_point(tile_pos):
		return false
	
	return true

func get_save_file_path(room_type: int) -> String:
	var file_name = room_type_file_names.get(room_type, "default")
	return BASE_SAVE_PATH + "_" + file_name + SAVE_FILE_EXTENSION

func load_all_layouts() -> void:
	room_layouts.clear()
	
	# Загружаем макеты для каждого типа комнат
	for room_type in room_type_file_names.keys():
		room_layouts[room_type] = load_layouts_from_file(room_type)

func load_layouts_from_file(room_type: int) -> Array:
	var layouts = []
	var file_path = get_save_file_path(room_type)
	
	if not FileAccess.file_exists(file_path):
		var file_write := FileAccess.open(file_path, FileAccess.WRITE)
		if file_write:
			file_write.store_string(JSON.stringify([]))
		return layouts
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return layouts
		
	var json_text := file.get_as_text()
	var json_result = JSON.parse_string(json_text)
	if json_result is Array:
		layouts = json_result
	
	return layouts

func save_layouts_to_file(room_type: int) -> void:
	var file_path = get_save_file_path(room_type)
	var layouts = room_layouts.get(room_type, [])
	
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(layouts))

func save_current_layout(room_type: int) -> void:
	var objects_data: Array = []
	
	# Сохраняем стены
	for wall in room.get_tree().get_nodes_in_group('barrier'):
		var pos: Vector2 = wall.get_tile_position()
		objects_data.append({"x": pos.x, "y": pos.y, "t": PlacementType.WALL})
	
	# Сохраняем двери с углом поворота
	for door in room.get_tree().get_nodes_in_group('doors'):
		var pos: Vector2 = door.get_tile_position()
		var door_data = {"x": pos.x, "y": pos.y, "t": PlacementType.DOOR, "d": door.degree}
		objects_data.append(door_data)
		
	for info in room.get_tree().get_nodes_in_group('info'):
		var pos: Vector2 = info.get_tile_position()
		objects_data.append({"x": pos.x, "y": pos.y, "t": PlacementType.INFO})
	
	if objects_data.is_empty():
		return
	
	# Получаем список макетов для текущего типа комнат
	var layouts = room_layouts.get(room_type, [])
	
	if layout_exists_in_saved(objects_data, layouts):
		return
		
	layouts.append(objects_data)
	room_layouts[room_type] = layouts
	selected_layout_index = layouts.size() - 1
	
	save_layouts_to_file(room_type)
	update_layout_label()

func layout_exists_in_saved(layout: Array, layouts: Array) -> bool:
	var layout_str := JSON.stringify(layout)
	
	for saved_layout in layouts:
		if JSON.stringify(saved_layout) == layout_str:
			return true
	
	return false

func apply_random_layout_for_type(room_type: int) -> void:
	var layouts = room_layouts.get(room_type, [])
	if layouts.is_empty():
		return
		
	var random_index = randi() % layouts.size()
	selected_layout_index = random_index
	apply_layout_by_index(random_index, room_type)
	update_layout_label()

func check_and_apply_layout() -> void:
	# Получаем тип комнаты из родительского узла
	var room_type = room.type
	
	# Если для этого типа комнат ещё нет макетов, сохраняем текущий
	if room_layouts.get(room_type, []).is_empty():
		save_current_layout(room_type)
	
	# Применяем случайный макет для данного типа комнаты
	apply_random_layout_for_type(room_type)

func _on_door_button_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			set_placement_type(PlacementType.DOOR)

func _on_wall_button_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			set_placement_type(PlacementType.WALL)

func _on_info_button_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			set_placement_type(PlacementType.INFO)
