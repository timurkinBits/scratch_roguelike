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
var command_scene = preload('res://scenes/Command.tscn')

func _process(delta: float) -> void:
	if not dragged_card:
		return
	var mouse_pos = get_global_mouse_position()
	var table_canvas_rect = table_texture.get_global_rect()
	var canvas_to_world = get_viewport().canvas_transform.inverse()
	var table_top_left_world = canvas_to_world * table_canvas_rect.position
	var table_bottom_right_world = canvas_to_world * (table_canvas_rect.position + table_canvas_rect.size)
	var table_global_rect_world = Rect2(table_top_left_world, table_bottom_right_world - table_top_left_world)
	
	enforce_table_boundaries(dragged_card, mouse_pos + drag_offset, table_global_rect_world)
	if dragged_card is Block:
		dragged_card.update_command_positions(Z_INDEX_DRAGGING)
	
	update_hovered_slot()
	if hovered_slot:
		hover_timer += delta
		if hover_timer >= HOVER_THRESHOLD and not has_shifted_commands:
			affected_block = hovered_slot.block
			affected_block.prepare_for_insertion(hovered_slot)
			has_shifted_commands = true
	else:
		if has_shifted_commands and affected_block:
			affected_block.cancel_insertion()
			has_shifted_commands = false
		hover_timer = 0.0

# Обрабатывает ввод мыши для начала и завершения перетаскивания
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_drag()
		else:
			finish_drag()

func enforce_table_boundaries(card: Node2D, target_position: Vector2, table_rect: Rect2) -> void:
	var size = get_card_size(card)
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
func get_card_size(card: Node2D) -> Vector2:
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
			hovered_slot.block.update_slots()
			
			# После добавления в слот проверяем границы для всего блока
			check_parent_block_boundaries(hovered_slot.block, table_global_rect)
		else:
			# Если не помещается, оставляем на текущей позиции с проверкой границ
			enforce_table_boundaries(dragged_card, dragged_card.global_position, table_global_rect)
	dragged_card.z_index = 1
	
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
	var card_size = get_card_size(card)
	
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
