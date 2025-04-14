extends Node2D
class_name Table

# Константы
const HOVER_THRESHOLD: float = 0.5
const Z_INDEX_DRAGGING: int = 100

# Базовые переменные для перетаскивания
var dragged_card: Node2D = null
var hovered_slot: CommandSlot = null
var drag_offset := Vector2.ZERO
var original_slot: CommandSlot = null
var affected_block: Block = null
var hover_timer: float = 0.0
var has_shifted_commands: bool = false
var is_turn_in_progress: bool = false

# Предзагрузка ресурсов
@onready var table_texture: ColorRect = $Texture
var command_scene = preload('res://scenes/Command.tscn')
var block_scene = preload('res://scenes/Block.tscn')

# Основной игровой цикл
func _process(delta: float) -> void:
	if is_turn_in_progress or not dragged_card:
		return
		
	var mouse_pos = get_global_mouse_position()
	var table_rect = get_table_rect()
	
	enforce_table_boundaries(dragged_card, mouse_pos + drag_offset, table_rect)
	if dragged_card is Block:
		dragged_card.update_command_positions(Z_INDEX_DRAGGING)
	
	handle_hover_logic(delta)

# Обработка логики наведения на слот при перетаскивании
func handle_hover_logic(delta: float) -> void:
	update_hovered_slot()
	
	if hovered_slot:
		# Проверка для предотвращения вставки для блоков условий
		var is_condition_block = dragged_card is Block and dragged_card.type == ItemData.BlockType.CONDITION
		
		if not is_condition_block:
			hover_timer += delta
			if hover_timer >= HOVER_THRESHOLD and not has_shifted_commands:
				affected_block = hovered_slot.block
				affected_block.prepare_for_insertion(hovered_slot)
				has_shifted_commands = true
	elif has_shifted_commands and affected_block:
		affected_block.cancel_insertion()
		has_shifted_commands = false
		hover_timer = 0.0
	else:
		hover_timer = 0.0

# Обработка событий ввода
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	
	if event.pressed and not is_turn_in_progress:
		start_drag()
	elif not event.pressed:
		finish_drag()

# Границы стола
func get_table_rect() -> Rect2:
	var table_canvas_rect = table_texture.get_global_rect()
	var canvas_to_world = get_viewport().canvas_transform.inverse()
	var table_top_left_world = canvas_to_world * table_canvas_rect.position
	var table_bottom_right_world = canvas_to_world * (table_canvas_rect.position + table_canvas_rect.size)
	return Rect2(table_top_left_world, table_bottom_right_world - table_top_left_world)

# Ограничение перемещения карты границами стола
func enforce_table_boundaries(card: Node2D, target_position: Vector2, table_rect: Rect2) -> void:
	var size = get_card_size(card)
	card.global_position = target_position.clamp(
		table_rect.position,
		table_rect.position + table_rect.size - size
	)

# Получение размера карты
func get_card_size(card: Node2D) -> Vector2:
	if card is Block:
		return card.get_full_size() * card.scale
	
	var texture_node = card.get_node("Texture")
	return texture_node.size * card.scale if texture_node else Vector2.ZERO

# Поиск карты под указателем мыши
func raycast_for_card() -> Node2D:
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = 3
	var hits = get_world_2d().direct_space_state.intersect_point(query)
	
	for hit in hits:
		var obj = hit["collider"].get_parent()
		if obj is CommandSlot and is_instance_valid(obj.command):
			return obj.command
		if obj is Command and not obj.is_menu_command:
			return obj
		if obj is Block and not obj.is_menu_command:
			if hit["shape"] != 0:
				return obj
			# Пропускаем, если shape_idx == 0
	return null

# Поиск слота, в котором находится карта
func find_card_slot(card: Node2D) -> CommandSlot:
	if not is_instance_valid(card):
		return null
	
	for block in get_tree().get_nodes_in_group("blocks"):
		if not is_instance_valid(block):
			continue
			
		for slot in block.slot_manager.slots:
			if slot.command == card:
				return slot
	return null

# Начало перетаскивания
func start_drag() -> void:
	var card = raycast_for_card()
	if not card:
		return
	
	card.z_index = Z_INDEX_DRAGGING
	drag_offset = card.global_position - get_global_mouse_position()
	dragged_card = card
	
	original_slot = find_card_slot(card)
	if original_slot:
		original_slot.clear_command()

# Завершение перетаскивания
func finish_drag() -> void:
	if not dragged_card:
		return
		
	var table_rect = get_table_rect()
	
	if is_turn_in_progress:
		enforce_table_boundaries(dragged_card, dragged_card.global_position, table_rect)
	elif hovered_slot and is_instance_valid(hovered_slot):
		var invalid_placement = dragged_card is Block and is_condition_block_in_block(dragged_card, hovered_slot)
		
		if would_fit_in_boundaries(dragged_card, hovered_slot, table_rect) and not invalid_placement:
			place_card_in_slot(hovered_slot)
		else:
			enforce_table_boundaries(dragged_card, dragged_card.global_position, table_rect)
	else:
		enforce_table_boundaries(dragged_card, dragged_card.global_position, table_rect)
	
	if dragged_card:
		dragged_card.z_index = 3
	
	reset_drag_state()

# Сброс состояния перетаскивания
func reset_drag_state() -> void:
	dragged_card = null
	affected_block = null
	hover_timer = 0.0
	original_slot = null
	has_shifted_commands = false

# Размещение карты в слоте
func place_card_in_slot(slot: CommandSlot) -> void:
	slot.add_command(dragged_card)
	dragged_card.position = Vector2.ZERO
	slot.block.update_slots()
	
	check_parent_block_boundaries(slot.block, get_table_rect())

# Проверка и коррекция границ для родительского блока
func check_parent_block_boundaries(block: Block, table_rect: Rect2) -> void:
	if not is_instance_valid(block):
		return
	
	var full_size = block.get_full_size() * block.get_global_transform().get_scale()
	var current_position = block.global_position
	
	var new_position = current_position.clamp(
		table_rect.position,
		table_rect.position + table_rect.size - full_size
	)
	
	if new_position != current_position and block.parent_slot == null:
		block.global_position = new_position
		block.slot_manager.update_all_slot_positions()
		
		for slot in block.slot_manager.slots:
			if slot.command and is_instance_valid(slot.command):
				slot.command.global_position = block.to_global(slot.position)
	
	if block.parent_slot and block.parent_slot.block:
		check_parent_block_boundaries(block.parent_slot.block, table_rect)

# Проверка, поместится ли карта в границы
func would_fit_in_boundaries(card: Node2D, slot: CommandSlot, table_rect: Rect2) -> bool:
	if not is_instance_valid(slot) or not is_instance_valid(slot.block):
		return false
	
	var card_size = get_card_size(card)
	var slot_global_pos = slot.global_position
	
	return (
		slot_global_pos.x >= table_rect.position.x and
		slot_global_pos.y >= table_rect.position.y and
		slot_global_pos.x + card_size.x <= table_rect.position.x + table_rect.size.x and
		slot_global_pos.y + card_size.y <= table_rect.position.y + table_rect.size.y
	)

# Проверка, является ли перетаскиваемая карта блоком условия внутри другого блока
func is_condition_block_in_block(dragged_block: Block, target_slot: CommandSlot) -> bool:
	return dragged_block.type == ItemData.BlockType.CONDITION and target_slot and target_slot.block != null

# Обновление текущего наведенного слота
func update_hovered_slot() -> void:
	hovered_slot = null
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = 3
	var hits = get_world_2d().direct_space_state.intersect_point(query)
	
	for hit in hits:
		var obj = hit["collider"].get_parent()
		if obj is CommandSlot and obj != dragged_card:
			hovered_slot = obj
			break

# Создание копии команды
func create_command_copy(type: int) -> void:
	var remaining_points = Global.get_remaining_points(type)
	if remaining_points <= 0:
		return
		
	var new_command = command_scene.instantiate()
	new_command.type = type
	table_texture.add_child(new_command)
	new_command.update_appearance()
	
	new_command.set_number(1)
	new_command.position = Vector2(8, 8)

# Создание копии блока
func create_block_copy(type: int) -> void:
	if is_turn_in_progress:
		return
		
	var new_block = block_scene.instantiate() as Block
	new_block.type = type
	new_block.is_menu_command = false
	
	# Установка значений по умолчанию в зависимости от типа
	match type:
		ItemData.BlockType.CONDITION:
			new_block.text = Block.available_conditions[0]
		ItemData.BlockType.LOOP:
			new_block.loop_count = Block.available_loops[0]
		ItemData.BlockType.ABILITY:
			new_block.text = Block.available_abilities[0]
			
	table_texture.add_child(new_block)
	new_block.update_appearance()
	
	# Блок инициализируется после добавления в дерево сцены
	new_block.button_color.visible = true
	new_block.position = Vector2(8, 8)
	new_block.scale = Vector2(0.9, 0.9)

# Общий метод создания карты
func create_card(kind, type: int) -> void:
	if kind == Command:
		create_command_copy(type)
	else:
		create_block_copy(type)
