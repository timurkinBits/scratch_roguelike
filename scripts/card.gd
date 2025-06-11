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

func _ready() -> void:
	add_to_group('cards')
	table = find_parent("Table")
	
func get_size() -> Vector2:
	return Vector2.ZERO  # Override in subclasses

func start_drag() -> void:
	if is_menu_card or table.is_turn_in_progress:
		return
		
	is_being_dragged = true
	z_index = Z_INDEX_DRAGGING
	drag_offset = global_position - get_global_mouse_position()
	
	if original_slot:
		original_slot.clear_command()
	
	reset_hover_state()
	drag_started.emit()

func finish_drag() -> void:
	if not is_being_dragged:
		return
		
	is_being_dragged = false
	z_index = Z_INDEX_NORMAL
	
	handle_card_placement()
	reset_hover_state()
	drag_finished.emit()

func handle_card_placement() -> void:
	var table_rect = table.get_table_rect()
	
	if table.is_turn_in_progress:
		enforce_table_boundaries(global_position, table_rect)
	elif hovered_slot and is_instance_valid(hovered_slot):
		var invalid_placement = self is Block and is_condition_block_in_block(hovered_slot)
		
		if would_fit_in_boundaries(hovered_slot, table_rect) and not invalid_placement:
			place_card_in_slot(hovered_slot)
		else:
			enforce_table_boundaries(global_position, table_rect)
	else:
		enforce_table_boundaries(global_position, table_rect)

func reset_hover_state() -> void:
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

func place_card_in_slot(slot: CommandSlot) -> void:
	slot.add_command(self)
	position = Vector2.ZERO
	slot.block.update_slots()
	
	check_parent_block_boundaries(slot.block, table.get_table_rect())

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
		
		for slot in block.slot_manager.slots:
			if slot.command and is_instance_valid(slot.command):
				slot.command.global_position = block.to_global(slot.position)
	
	if block.parent_slot and block.parent_slot.block:
		check_parent_block_boundaries(block.parent_slot.block, table_rect)

func would_fit_in_boundaries(slot: CommandSlot, table_rect: Rect2) -> bool:
	if not is_instance_valid(slot) or not is_instance_valid(slot.block):
		return false
	
	var card_size = get_size() * scale
	var slot_global_pos = slot.global_position
	
	return (
		slot_global_pos.x >= table_rect.position.x and
		slot_global_pos.y >= table_rect.position.y and
		slot_global_pos.x + card_size.x <= table_rect.position.x + table_rect.size.x and
		slot_global_pos.y + card_size.y <= table_rect.position.y + table_rect.size.y
	)

func is_condition_block_in_block(target_slot: CommandSlot) -> bool:
	return self is Block and self.type == ItemData.BlockType.CONDITION and target_slot and target_slot.block != null

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
		var is_condition_block = self is Block and self.type == ItemData.BlockType.CONDITION
		
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

func _process(delta: float) -> void:
	if is_being_dragged and not table.is_turn_in_progress:
		update_drag_position(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and is_being_dragged:
			finish_drag()

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_drag()
		elif is_being_dragged:
			finish_drag()
