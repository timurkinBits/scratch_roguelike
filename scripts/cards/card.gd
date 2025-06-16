extends Node2D
class_name Card

# Signals
signal drag_started
signal drag_finished

# Drag properties
var is_being_dragged := false
var drag_offset := Vector2.ZERO
var original_slot: CommandSlot = null
var is_menu_card := false
var slot: CommandSlot = null
var hovered_slot: CommandSlot = null
var hover_timer := 0.0
var has_shifted_commands := false
var affected_block: Block = null

# Constants
const Z_INDEX_NORMAL := 3
const Z_INDEX_DRAGGING := 100
const HOVER_THRESHOLD := 0.5

var table: Node2D = null
# Добавляем статический счетчик для уникальных z-индексов
static var next_z_index := Z_INDEX_NORMAL

func _ready() -> void:
	add_to_group('cards')
	table = find_parent("Table")
	# Устанавливаем начальный z-индекс
	z_index = next_z_index
	next_z_index += 1
	
func get_size() -> Vector2:
	return Vector2.ZERO  # Override in subclasses

func start_drag() -> void:
	if is_menu_card or table.is_turn_in_progress:
		return
		
	is_being_dragged = true
	# Устанавливаем максимальный z-индекс для перетаскиваемой карты
	z_index = Z_INDEX_DRAGGING
	drag_offset = global_position - get_global_mouse_position()
	
	# Сохраняем ссылку на исходный слот для правильного обновления
	if slot and is_instance_valid(slot):
		original_slot = slot
		var parent_block = slot.block
		# Очищаем слот
		slot.command = null
		slot = null
		# Обновляем слоты блока сразу после извлечения
		if is_instance_valid(parent_block):
			parent_block.slot_manager.update_slots()
	
	reset_hover_state()
	drag_started.emit()

func finish_drag() -> void:
	if not is_being_dragged:
		return
		
	is_being_dragged = false
	# После завершения перетаскивания присваиваем новый уникальный z-индекс
	# который будет выше всех остальных неперетаскиваемых карт
	z_index = next_z_index
	next_z_index += 1
	
	# ВАЖНО: не сбрасываем hover состояние до размещения карты
	handle_card_placement()
	# Сбрасываем hover состояние только после размещения
	reset_hover_state()
	drag_finished.emit()

func handle_card_placement() -> void:
	var table_rect = table.get_table_rect()
	var card_placed = false
	
	if table.is_turn_in_progress:
		enforce_table_boundaries(global_position, table_rect)
	elif hovered_slot and is_instance_valid(hovered_slot):
		# Проверяем, можем ли мы разместить карту в этом слоте
		if can_place_in_slot(hovered_slot, table_rect):
			place_card_in_slot(hovered_slot)
			card_placed = true
		else:
			enforce_table_boundaries(global_position, table_rect)
	else:
		enforce_table_boundaries(global_position, table_rect)
	
	# Если карта не была размещена в слот, отменяем подготовку к вставке
	if not card_placed and affected_block and is_instance_valid(affected_block):
		affected_block.slot_manager.cancel_insertion()
	
	# Очищаем ссылку на исходный слот после завершения размещения
	original_slot = null

func can_place_in_slot(target_slot: CommandSlot, table_rect: Rect2) -> bool:
	if not is_instance_valid(target_slot) or not is_instance_valid(target_slot.block):
		return false
	
	# Если слот уже занят, проверяем, подготовлен ли он для вставки
	if target_slot.command != null and not has_shifted_commands:
		return false
	
	# Проверяем границы стола
	return would_fit_in_boundaries(target_slot, table_rect)

func reset_hover_state() -> void:
	# Сбрасываем состояние hover только если карта не была размещена
	if affected_block and is_instance_valid(affected_block):
		# Проверяем, была ли карта успешно размещена
		var card_was_placed = (slot != null and is_instance_valid(slot))
		if not card_was_placed:
			affected_block.slot_manager.cancel_insertion()
	
	affected_block = null
	hover_timer = 0.0
	has_shifted_commands = false
	hovered_slot = null

func enforce_table_boundaries(target_position: Vector2, table_rect: Rect2) -> void:
	var size = get_size() * scale
	global_position = target_position.clamp(
		table_rect.position,
		table_rect.position + table_rect.size - size
	)

func place_card_in_slot(target_slot: CommandSlot) -> void:
	if not is_instance_valid(target_slot):
		return
	
	# Устанавливаем связи
	target_slot.command = self
	slot = target_slot
	
	# Устанавливаем позицию относительно блока
	position = Vector2.ZERO
	
	# Обновляем слоты блока
	if is_instance_valid(target_slot.block):
		target_slot.block.slot_manager.finalize_insertion()
		target_slot.block.slot_manager.update_slots()
		check_parent_block_boundaries(target_slot.block, table.get_table_rect())

func check_parent_block_boundaries(block: Block, table_rect: Rect2) -> void:
	if not is_instance_valid(block):
		return
	
	var full_size = block.get_size() * block.get_global_transform().get_scale()
	var current_position = block.global_position
	
	var new_position = current_position.clamp(
		table_rect.position,
		table_rect.position + table_rect.size - full_size
	)
	
	if new_position != current_position and block.parent_slot == null:
		block.global_position = new_position
		block.slot_manager.update_all_slot_positions()
		
		for slot_item in block.slot_manager.slots:
			if slot_item.command and is_instance_valid(slot_item.command):
				slot_item.command.global_position = block.to_global(slot_item.position)
	
	if block.parent_slot and block.parent_slot.block:
		check_parent_block_boundaries(block.parent_slot.block, table_rect)

func would_fit_in_boundaries(target_slot: CommandSlot, table_rect: Rect2) -> bool:
	if not is_instance_valid(target_slot) or not is_instance_valid(target_slot.block):
		return false
	
	var card_size = get_size() * scale
	var slot_global_pos = target_slot.global_position
	
	return (
		slot_global_pos.x >= table_rect.position.x and
		slot_global_pos.y >= table_rect.position.y and
		slot_global_pos.x + card_size.x <= table_rect.position.x + table_rect.size.x and
		slot_global_pos.y + card_size.y <= table_rect.position.y + table_rect.size.y
	)

func update_hovered_slot() -> void:
	hovered_slot = null
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collision_mask = 3
	var hits = table.get_world_2d().direct_space_state.intersect_point(query)
	
	for hit in hits:
		var obj = hit["collider"].get_parent()
		if obj is CommandSlot and obj != self:
			hovered_slot = obj
			break

func update_drag_position(delta: float) -> void:
	if is_being_dragged:
		var mouse_pos = get_global_mouse_position()
		var table_rect = table.get_table_rect()
		var new_pos = mouse_pos + drag_offset
		
		global_position = new_pos.clamp(
			table_rect.position,
			table_rect.position + table_rect.size - get_size() * scale
		)
		
		handle_hover_logic(delta)
		
		if self is Block:
			update_command_positions(Z_INDEX_DRAGGING)

func update_command_positions(z_index):
	pass  # Override in Block class

func handle_hover_logic(delta: float) -> void:
	update_hovered_slot()
	
	if hovered_slot:
		hover_timer += delta
		if hover_timer >= HOVER_THRESHOLD and not has_shifted_commands:
			affected_block = hovered_slot.block
			if is_instance_valid(affected_block):
				affected_block.slot_manager.prepare_for_insertion(hovered_slot)
				has_shifted_commands = true
	elif has_shifted_commands and affected_block:
		if is_instance_valid(affected_block):
			affected_block.slot_manager.cancel_insertion()
		affected_block = null
		has_shifted_commands = false
		hover_timer = 0.0
	else:
		hover_timer = 0.0

func _process(delta: float) -> void:
	if is_being_dragged and not table.is_turn_in_progress:
		update_drag_position(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and is_being_dragged:
			finish_drag()

# Обновленная функция для обработки событий мыши с учетом z-индекса
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Проверяем, является ли эта карта самой верхней в точке клика
			if is_topmost_card_at_position():
				start_drag()
		elif is_being_dragged:
			finish_drag()

# Новая функция для проверки, является ли карта самой верхней в точке клика
func is_topmost_card_at_position() -> bool:
	var mouse_pos = get_global_mouse_position()
	var cards_at_position = []
	
	# Собираем все карты под курсором
	for card in get_tree().get_nodes_in_group('cards'):
		if card == self:
			continue
		if card.is_menu_card:
			continue
		if not is_instance_valid(card):
			continue
			
		# Проверяем, находится ли мышь над картой
		var card_rect = Rect2(card.global_position, card.get_size() * card.scale)
		if card_rect.has_point(mouse_pos):
			cards_at_position.append(card)
	
	# Проверяем наш z-индекс против всех других карт в этой позиции
	for card in cards_at_position:
		if card.z_index > self.z_index:
			return false
	
	return true

# Функция для принудительного поднятия карты наверх (может быть полезна)
func bring_to_front() -> void:
	z_index = next_z_index
	next_z_index += 1
