extends Node2D
class_name Table

const HOVER_THRESHOLD: float = 0.5
const Z_INDEX_DRAGGING: int = 100

var dragged_card: Node2D = null
var hovered_slot: CommandSlot = null
var drag_offset := Vector2.ZERO  # Смещение между курсором и позицией объекта
var original_slot: CommandSlot = null
var affected_block: Block = null
var hover_timer: float = 0.0
var original_positions: Dictionary = {}
var has_shifted_commands: bool = false

@onready var table_texture: ColorRect = $Texture
# Загружаем сцену Command (скорректируйте путь)
var command_scene = preload('res://scenes/Command.tscn')

func _process(delta: float) -> void:
	if not dragged_card:
		return
	var mouse_pos = get_global_mouse_position()
	
	# Получаем глобальный прямоугольник стола в координатах холста
	var table_canvas_rect = table_texture.get_global_rect()
	
	# Преобразуем его в мировые координаты
	var canvas_to_world = get_viewport().canvas_transform.inverse()
	var table_top_left_world = canvas_to_world * table_canvas_rect.position
	var table_bottom_right_world = canvas_to_world * (table_canvas_rect.position + table_canvas_rect.size)
	var table_global_rect_world = Rect2(table_top_left_world, table_bottom_right_world - table_top_left_world)
	
	# Применяем границы в мировых координатах
	enforce_table_boundaries(dragged_card, mouse_pos + drag_offset, table_global_rect_world)
	
	if dragged_card is Block:
		update_block_cards(table_global_rect_world)
	
	update_hovered_slot()
	if hovered_slot:
		hover_timer += delta
		if hover_timer >= HOVER_THRESHOLD:
			shift_commands_down()
	else:
		hover_timer = max(0.0, hover_timer - delta)
		if affected_block:
			restore_positions()

# Обрабатывает ввод мыши для начала и завершения перетаскивания
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_drag()
		else:
			finish_drag()

func enforce_table_boundaries(card: Node2D, target_position: Vector2, table_rect: Rect2) -> void:
	var size = get_card_size_with_scale(card)
	var new_position = target_position
	
	if new_position.x < table_rect.position.x:
		new_position.x = table_rect.position.x
	elif new_position.x + size.x > table_rect.position.x + table_rect.size.x:
		new_position.x = table_rect.position.x + table_rect.size.x - size.x
	
	if new_position.y < table_rect.position.y:
		new_position.y = table_rect.position.y
	elif new_position.y + size.y > table_rect.position.y + table_rect.size.y:
		new_position.y = table_rect.position.y + table_rect.size.y - size.y
	
	card.global_position = new_position

# Получает размер карты с учетом масштаба
func get_card_size_with_scale(card: Node2D) -> Vector2:
	var size = Vector2.ZERO
	if card is Block:
		size = card.get_full_size() * card.scale
	else:
		var texture_node = card.get_node("Texture")
		if texture_node:
			size = texture_node.size * card.scale
	return size

# Находит карту под курсором мыши с помощью физического запроса
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
		if (obj is Command and not obj.is_menu_command) or (obj is Block):  # Измененная строка
			return obj
	return null

# Находит слот, содержащий указанную карту
func find_card_slot(card: Node2D) -> CommandSlot:
	if not is_instance_valid(card):
		return null
	for block in get_tree().get_nodes_in_group("blocks"):
		if is_instance_valid(block):
			for slot in block.slots:
				if slot.command == card:
					return slot
	return null

# Получает максимальный z-индекс среди всех блоков и команд
func get_highest_z_index() -> int:
	var max_z_index = 1
	for block in get_tree().get_nodes_in_group("blocks"):
		if is_instance_valid(block) and block != dragged_card:
			max_z_index = max(max_z_index, block.z_index + 1)
	for command in get_tree().get_nodes_in_group("commands"):
		if is_instance_valid(command) and command != dragged_card:
			max_z_index = max(max_z_index, command.z_index + 1)
	return max_z_index

# Начинает операцию перетаскивания карты под курсором
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

# Завершает перетаскивание и размещает карту в слоте, если возможно
func finish_drag() -> void:
	if not dragged_card:
		return
	var new_z_index = get_highest_z_index()
	
	# Получаем границы стола
	var table_global_rect = Rect2(
		table_texture.global_position,
		table_texture.size * table_texture.get_global_transform().get_scale()
	)
	
	if hovered_slot and is_instance_valid(hovered_slot):
		# Проверяем, поместится ли блок в слот без выхода за границы стола
		if would_fit_in_boundaries(dragged_card, hovered_slot, table_global_rect):
			hovered_slot.add_command(dragged_card)
			dragged_card.position = Vector2.ZERO
			dragged_card.z_index = new_z_index
			hovered_slot.block.update_slots()
			
			# После добавления в слот проверяем границы для всего блока
			check_parent_block_boundaries(hovered_slot.block, table_global_rect)
		else:
			# Если не помещается, оставляем на текущей позиции с проверкой границ
			enforce_table_boundaries(dragged_card, dragged_card.global_position, table_global_rect)
	elif affected_block:
		restore_positions()
		dragged_card.z_index = new_z_index
	else:
		dragged_card.z_index = new_z_index
	
	dragged_card = null
	affected_block = null
	hover_timer = 0.0
	original_slot = null
	has_shifted_commands = false

func check_parent_block_boundaries(block: Block, table_rect: Rect2) -> void:
	if not is_instance_valid(block):
		return
	
	# Вычисляем общий размер блока со всеми вложенными элементами
	var full_size = block.get_full_size() * block.get_global_transform().get_scale()
	var current_position = block.global_position
	
	# Проверяем, не выходит ли блок за границы стола
	var needs_adjustment = false
	var new_position = current_position
	
	if current_position.x < table_rect.position.x:
		new_position.x = table_rect.position.x
		needs_adjustment = true
	elif current_position.x + full_size.x > table_rect.position.x + table_rect.size.x:
		new_position.x = table_rect.position.x + table_rect.size.x - full_size.x
		needs_adjustment = true
	
	if current_position.y < table_rect.position.y:
		new_position.y = table_rect.position.y
		needs_adjustment = true
	elif current_position.y + full_size.y > table_rect.position.y + table_rect.size.y:
		new_position.y = table_rect.position.y + table_rect.size.y - full_size.y
		needs_adjustment = true
	
	# Если требуется корректировка и блок не в слоте
	if needs_adjustment and block.parent_slot == null:
		block.global_position = new_position
		block.update_all_slot_positions()
		
		# Обновляем позиции команд внутри блока
		for slot in block.slots:
			if slot.command and is_instance_valid(slot.command):
				slot.command.global_position = block.to_global(slot.position)
	
	# Проверяем родительский блок, если он существует
	if block.parent_slot and block.parent_slot.block:
		check_parent_block_boundaries(block.parent_slot.block, table_rect)

# Проверяет, поместится ли элемент в слот без выхода за границы стола
func would_fit_in_boundaries(card: Node2D, slot: CommandSlot, table_rect: Rect2) -> bool:
	if not is_instance_valid(slot) or not is_instance_valid(slot.block):
		return false
	
	# Получаем размер карты с учетом масштаба
	var card_size = get_card_size_with_scale(card)
	
	# Получаем позицию слота в глобальных координатах
	var slot_global_pos = slot.global_position
	
	# Проверяем, не выходит ли за границы
	return (
		slot_global_pos.x >= table_rect.position.x and
		slot_global_pos.y >= table_rect.position.y and
		slot_global_pos.x + card_size.x <= table_rect.position.x + table_rect.size.x and
		slot_global_pos.y + card_size.y <= table_rect.position.y + table_rect.size.y
	)

# Обновляет слот под курсором мыши
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

# Сдвигает команды вниз в блоке, освобождая место для перетаскиваемой карты
func shift_commands_down() -> void:
	if not hovered_slot or not is_instance_valid(hovered_slot.block) or has_shifted_commands:
		return
	
	# Получаем границы стола
	var table_global_rect = Rect2(
		table_texture.global_position,
		table_texture.size * table_texture.get_global_transform().get_scale()
	)
	
	# Проверяем, поместится ли карта в слот без выхода за границы
	if not would_fit_in_boundaries(dragged_card, hovered_slot, table_global_rect):
		return
	
	affected_block = hovered_slot.block
	var block_slots = affected_block.slots
	var hover_index = block_slots.find(hovered_slot)
	
	if original_positions.is_empty():
		for i in range(hover_index, block_slots.size()):
			if block_slots[i].command:
				original_positions[block_slots[i].command] = block_slots[i].command.global_position
	
	if block_slots.back().command:
		affected_block.create_slot()
		block_slots = affected_block.slots  # Обновляем список слотов
	
	for i in range(block_slots.size() - 1, hover_index, -1):
		block_slots[i].command = block_slots[i - 1].command
	
	block_slots[hover_index].command = null
	affected_block.update_all_slot_positions()
	
	for slot in block_slots:
		if slot.command:
			slot.command.global_position = slot.global_position
	
	hover_timer = 0.0
	has_shifted_commands = true
	
	# Проверяем, не выходит ли блок за границы после сдвига команд
	check_parent_block_boundaries(affected_block, table_global_rect)

# Восстанавливает команды на их исходные позиции при отмене перетаскивания
func restore_positions() -> void:
	if original_positions.is_empty() or not affected_block:
		return
	var block_slots = affected_block.slots
	for slot in block_slots:
		slot.command = null
	for command in original_positions:
		if is_instance_valid(command):
			for slot in block_slots:
				if slot.global_position == original_positions[command]:
					slot.command = command
					break
	original_positions.clear()
	affected_block.update_slots()
	affected_block = null

# Обновляет позиции команд внутри перетаскиваемого блока
func update_block_cards(table_rect: Rect2) -> void:
	if not dragged_card is Block:
		return
		
	for slot in dragged_card.slots:
		if slot.command and is_instance_valid(slot.command):
			# Вычисляем глобальную позицию слота
			var slot_global_pos = dragged_card.to_global(slot.position)
			
			# Обновляем позицию команды в слоте
			slot.command.global_position = slot_global_pos
			slot.command.visible = true
			slot.command.z_index = Z_INDEX_DRAGGING - 1
			
			# Проверяем, не выходит ли команда за границы стола
			var command_size = get_card_size_with_scale(slot.command)
			
			# Проверяем правую и нижнюю границы
			var right_edge = slot_global_pos.x + command_size.x
			var bottom_edge = slot_global_pos.y + command_size.y
			
			# Если команда выходит за границы, корректируем позицию родительского блока
			if right_edge > table_rect.position.x + table_rect.size.x:
				var offset = right_edge - (table_rect.position.x + table_rect.size.x)
				dragged_card.global_position.x -= offset
			
			if bottom_edge > table_rect.position.y + table_rect.size.y:
				var offset = bottom_edge - (table_rect.position.y + table_rect.size.y)
				dragged_card.global_position.y -= offset
			
			# Если команда выходит за левую или верхнюю границу, тоже корректируем
			if slot_global_pos.x < table_rect.position.x:
				var offset = table_rect.position.x - slot_global_pos.x
				dragged_card.global_position.x += offset
			
			if slot_global_pos.y < table_rect.position.y:
				var offset = table_rect.position.y - slot_global_pos.y
				dragged_card.global_position.y += offset
			
			# После корректировки родительского блока обновляем позиции всех команд
			for update_slot in dragged_card.slots:
				if update_slot.command and is_instance_valid(update_slot.command):
					update_slot.command.global_position = dragged_card.to_global(update_slot.position)
					
					# Рекурсивно обновляем позиции для вложенных блоков
					if update_slot.command is Block:
						update_nested_block_positions(update_slot.command, table_rect)

# Рекурсивно обновляет позиции вложенных блоков
func update_nested_block_positions(block: Block, table_rect: Rect2) -> void:
	if not is_instance_valid(block):
		return
	
	# Обновляем позиции слотов для вложенного блока
	block.update_all_slot_positions()
	
	# Проверяем каждый слот на наличие команд
	for slot in block.slots:
		if slot.command and is_instance_valid(slot.command):
			# Устанавливаем позицию команды
			slot.command.global_position = block.to_global(slot.position)
			
			# Если команда - блок, рекурсивно обновляем и для него
			if slot.command is Block:
				update_nested_block_positions(slot.command, table_rect)

func create_command(type: int) -> void:
	var remaining_points = Global.get_remaining_points(type)
	
	if remaining_points <= 0:
		return
		
	var new_command = command_scene.instantiate()
	new_command.type = type
	table_texture.add_child(new_command)
	new_command.update_appearance()
	
	new_command.set_number(1)
	new_command.position = Vector2(8, 8)
	new_command.add_to_group("commands")
