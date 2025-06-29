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
	# Проверяем все условия блокировки
	if is_menu_card:
		print("Блокировка: карта меню")
		return
	
	if not is_instance_valid(table):
		print("Блокировка: стол недоступен")
		return
		
	if table.is_turn_in_progress:
		print("Блокировка: ход в процессе")
		return
	
	if is_being_dragged:
		print("Блокировка: уже перетаскивается")
		return
	
	# Принудительно поднимаем карту наверх перед началом перетаскивания
	bring_to_front()
		
	is_being_dragged = true
	z_index = Z_INDEX_DRAGGING
	drag_offset = global_position - get_global_mouse_position()
	
	# ИСПРАВЛЕНИЕ: Корректная очистка связей при извлечении из слота
	if slot and is_instance_valid(slot):
		original_slot = slot
		var parent_block = slot.block
		
		# Очищаем связи
		slot.command = null
		slot = null
		
		# Для блоков также очищаем parent_slot
		if self is Block:
			self.parent_slot = null
			# Уведомляем блок о том, что он был извлечен
			call_deferred("on_extracted_from_slot")
		
		# Немедленно обновляем родительский блок
		if is_instance_valid(parent_block):
			parent_block.force_update_slots()
	
	reset_hover_state()
	drag_started.emit()
	
	if self is Block:
		bring_nested_commands_to_front()
		
func force_unlock_drag() -> void:
	"""Принудительно разблокирует перетаскивание после завершения хода"""
	if is_being_dragged:
		finish_drag()
	
	# Сбрасываем все возможные блокировки
	is_being_dragged = false
	reset_hover_state()
	
	# Обеспечиваем корректный z-индекс
	if z_index == Z_INDEX_DRAGGING:
		z_index = next_z_index
		next_z_index += 1

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
	
	# ИСПРАВЛЕНИЕ: Более надежная отмена подготовки к вставке
	if not card_placed:
		if affected_block and is_instance_valid(affected_block):
			affected_block.slot_manager.cancel_insertion()
		
		# Если карта не была размещена и у нас был исходный слот,
		# проверяем, нужно ли обновить исходный родительский блок
		if original_slot and is_instance_valid(original_slot) and is_instance_valid(original_slot.block):
			original_slot.block.force_update_slots()
	
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
	# Отменяем подготовку к вставке если она была начата
	if affected_block and is_instance_valid(affected_block):
		# Проверяем, была ли карта успешно размещена
		var card_was_placed = (slot != null and is_instance_valid(slot))
		if not card_was_placed:
			affected_block.slot_manager.cancel_insertion()
			# Дополнительно обновляем блок после отмены
			affected_block.call_deferred("force_update_slots")
	
	# Очищаем все состояния
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
	
	# Для блоков устанавливаем parent_slot
	if self is Block:
		self.parent_slot = target_slot
	
	# Устанавливаем позицию относительно блока
	position = Vector2.ZERO
	
	# Обновляем слоты блока
	if is_instance_valid(target_slot.block):
		target_slot.block.slot_manager.finalize_insertion()
		target_slot.block.force_update_slots()
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

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not is_being_dragged:
			# Проверяем, является ли эта карта самой верхней в точке клика
			if is_topmost_card_at_position():
				if not is_drag_blocked():
					call_deferred("start_drag")
		elif is_being_dragged:
			finish_drag()

# ИСПРАВЛЕНИЕ 4: Кардинально улучшенная функция проверки самой верхней карты
func is_topmost_card_at_position() -> bool:
	var mouse_pos = get_global_mouse_position()
	var cards_under_mouse = []
	
	# Собираем все карты под курсором с их z-индексами
	for card in get_tree().get_nodes_in_group('cards'):
		if card == self or card.is_menu_card:
			continue
		if not is_instance_valid(card):
			continue
			
		# Проверяем, находится ли мышь над картой
		var card_rect = Rect2(card.global_position, card.get_size() * card.scale)
		if card_rect.has_point(mouse_pos):
			cards_under_mouse.append({
				"card": card,
				"z_index": card.z_index,
				"nesting_level": get_nesting_level(card)
			})
	
	# Если под мышью нет других карт, эта карта самая верхняя
	if cards_under_mouse.is_empty():
		return true
	
	# Сортируем карты по z-индексу, затем по уровню вложенности
	cards_under_mouse.sort_custom(func(a, b): 
		if a.z_index != b.z_index:
			return a.z_index > b.z_index
		return a.nesting_level > b.nesting_level
	)
	
	# Проверяем, является ли наша карта самой верхней
	var our_z = z_index
	var our_nesting = get_nesting_level(self)
	var top_card = cards_under_mouse[0]
	
	if our_z > top_card.z_index:
		return true
	elif our_z == top_card.z_index:
		return our_nesting >= top_card.nesting_level
	
	return false

# Новая функция для определения уровня вложенности карты
func get_nesting_level(card: Card) -> int:
	var level = 0
	var current_slot = null
	
	if card is Block and card.parent_slot:
		current_slot = card.parent_slot
	elif card is Command and card.slot:
		current_slot = card.slot
	
	while current_slot and is_instance_valid(current_slot):
		level += 1
		var parent_block = current_slot.block
		if not is_instance_valid(parent_block):
			break
			
		if parent_block.parent_slot:
			current_slot = parent_block.parent_slot
		else:
			break
	
	return level

# ИСПРАВЛЕНИЕ 5: Функция для принудительного восстановления состояния
func force_reset_drag_state() -> void:
	"""Принудительно сбрасывает состояние перетаскивания в случае ошибок"""
	if is_being_dragged:
		is_being_dragged = false
		z_index = next_z_index
		next_z_index += 1
		reset_hover_state()

func is_drag_blocked() -> bool:
	"""Проверяет, заблокировано ли перетаскивание с подробной диагностикой"""
	if is_menu_card:
		return true
	
	if not is_instance_valid(table):
		return true
		
	if table.is_turn_in_progress:
		return true
		
	if is_being_dragged:
		return true
	
	return false

# Функция для принудительного поднятия карты наверх (может быть полезна)
func bring_to_front() -> void:
	z_index = next_z_index
	next_z_index += 1

# НОВАЯ ФУНКЦИЯ: Поднимает все вложенные команды вместе с блоком
func bring_nested_commands_to_front() -> void:
	"""Поднимает все вложенные команды на передний план вместе с блоком"""
	if not self is Block:
		return
	
	var slot_manager = self.get("slot_manager")
	if not slot_manager:
		return
	
	for slot in slot_manager.slots:
		if not is_instance_valid(slot) or not is_instance_valid(slot.command):
			continue
		
		# Устанавливаем высокий z-индекс для вложенных команд
		slot.command.z_index = Z_INDEX_DRAGGING - 1
		
		# Рекурсивно поднимаем вложенные блоки
		if slot.command is Block:
			slot.command.bring_nested_commands_to_front()
