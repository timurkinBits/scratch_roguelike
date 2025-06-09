extends Node2D

@onready var table_node: Table = $".."

const MAX_SLOTS = 8
var block_slots: Array[Block] = []
var refresh_pending: bool = false

func _ready() -> void:
	add_to_group("block_menu")
	
	block_slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		block_slots[i] = null
	
	Global.connect("points_changed", refresh_menu)
	if Global.has_signal("turn_state_changed"):
		Global.connect("turn_state_changed", update_availability)
	
	call_deferred("initial_refresh")

func initial_refresh() -> void:
	refresh_menu()

func refresh_menu() -> void:
	if not is_inside_tree() or refresh_pending:
		return
	
	refresh_pending = true
	
	# Очищаем текущие блоки
	clear_menu()
	
	# Получаем все купленные блоки
	var purchased_blocks = Global.get_all_purchased_blocks()
	
	# Добавляем каждый блок в отдельный слот
	var slot_index = 0
	for block_data in purchased_blocks:
		if slot_index >= MAX_SLOTS:
			break
		
		create_block_in_slot(block_data.type, block_data.text, slot_index)
		slot_index += 1
	
	update_availability()
	refresh_pending = false

func clear_menu() -> void:
	for i in range(block_slots.size()):
		if block_slots[i] != null and is_instance_valid(block_slots[i]):
			block_slots[i].queue_free()
		block_slots[i] = null

func create_block_in_slot(block_type: int, block_text: String, slot_index: int) -> void:
	if not is_inside_tree():
		return
	
	var block_scene = load("res://scenes/Block.tscn")
	var block = block_scene.instantiate()
	
	block.type = block_type
	block.text = block_text
	block.is_menu_command = true
	block.scale = Vector2(0.45, 0.45)
	
	if block_type == ItemData.BlockType.LOOP:
		var parts = block_text.split(" ")
		if parts.size() > 1:
			block.loop_count = int(parts[1])
	
	add_child(block)
	block_slots[slot_index] = block
	block.position = Vector2(slot_index * 90, 0)
	
	# Сразу устанавливаем доступность и подключаем события
	set_block_availability(block, block_type, block_text)
	connect_block_input(block, slot_index)

func set_block_availability(block: Block, block_type: int, block_text: String) -> void:
	if not is_instance_valid(block):
		return
	
	var is_available = can_use_block(block_type, block_text)
	block.modulate.a = 1.0 if is_available else 0.3
	
	var area = block.get_node("Area2D")
	if area:
		area.input_pickable = is_available

func connect_block_input(block: Block, slot_index: int) -> void:
	if not is_instance_valid(block):
		return
	
	var area = block.get_node("Area2D")
	if area:
		area.input_pickable = true
		if area.input_event.is_connected(_on_block_clicked):
			area.input_event.disconnect(_on_block_clicked)
		area.input_event.connect(_on_block_clicked.bind(slot_index))

func _on_block_clicked(viewport: Node, event: InputEvent, shape_idx: int, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	var block = block_slots[slot_index]
	if block == null or not is_instance_valid(block):
		return
	
	if not can_use_block(block.type, block.text):
		return
	
	table_node.create_block_copy(block.type, block.text, block.loop_count)
	
	# Используем конкретный блок
	if not Global.use_block(block.type, block.text):
		return
	
	# Обновляем только этот конкретный блок
	update_single_block_availability(slot_index)

func can_use_block(block_type: int, block_text: String) -> bool:
	return Global.can_use_block(block_type, block_text)

func update_availability() -> void:
	if not is_inside_tree():
		return
	
	for i in range(block_slots.size()):
		update_single_block_availability(i)

func update_single_block_availability(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= block_slots.size():
		return
		
	var block = block_slots[slot_index]
	if block == null or not is_instance_valid(block):
		return
	
	# Каждый блок проверяет только свою доступность
	var can_use = can_use_block(block.type, block.text)
	
	block.modulate.a = 1.0 if can_use else 0.3
	
	var area = block.get_node("Area2D")
	if area:
		area.input_pickable = can_use

func return_block_to_slot(block_type: int, block_text: String) -> bool:
	Global.release_block(block_type, block_text)
	update_availability()
	return true
