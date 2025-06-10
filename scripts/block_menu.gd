extends Node2D

@onready var table_node: Table = $".."

const MAX_SLOTS = 8
var block_slots: Array[Dictionary] = []  # [{ block: Block, block_id: String }]

func _ready() -> void:
	add_to_group("block_menu")
	
	block_slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		block_slots[i] = {}
	
	Global.connect("points_changed", refresh_menu)
	if Global.has_signal("turn_state_changed"):
		Global.connect("turn_state_changed", update_availability)
	
	call_deferred("refresh_menu")

func refresh_menu() -> void:
	if not is_inside_tree():
		return
	
	# Очищаем текущие блоки
	clear_menu()
	
	# Получаем все купленные блоки (каждый экземпляр отдельно)
	var purchased_blocks = Global.get_all_purchased_blocks()
	
	# Добавляем каждый блок в отдельный слот
	var slot_index = 0
	for block_data in purchased_blocks:
		if slot_index >= MAX_SLOTS:
			break
		
		create_block_in_slot(block_data.id, block_data.type, block_data.text, slot_index)
		slot_index += 1
	
	update_availability()

func clear_menu() -> void:
	for i in range(block_slots.size()):
		if not block_slots[i].is_empty() and block_slots[i].has("block") and is_instance_valid(block_slots[i].block):
			block_slots[i].block.queue_free()
		block_slots[i] = {}

func create_block_in_slot(block_id: String, block_type: int, block_text: String, slot_index: int) -> void:
	if not is_inside_tree():
		return
	
	var block_scene = load("res://scenes/Block.tscn")
	var block = block_scene.instantiate()
	
	block.type = block_type
	block.text = block_text
	block.is_menu_card = true
	
	if block_type == ItemData.BlockType.LOOP:
		var parts = block_text.split(" ")
		if parts.size() > 1:
			block.loop_count = int(parts[1])
	
	add_child(block)
	
	# Сохраняем блок с его уникальным ID
	block_slots[slot_index] = {
		"block": block,
		"block_id": block_id
	}
	
	block.position = Vector2(0, slot_index * 30)
	
	# Сразу устанавливаем доступность и подключаем события
	set_block_availability(block, block_id)
	connect_block_input(block, slot_index)

func set_block_availability(block: Block, block_id: String) -> void:
	if not is_instance_valid(block):
		return
	
	# Проверяем доступность конкретного блока по его ID
	var is_available = can_use_block(block_id)
	block.modulate.a = 1.0 if is_available else 0.3
	
	var area = block.get_node("Area2D")
	if area:
		area.input_pickable = is_available

func can_use_block(block_id: String) -> bool:
	# Проверяем, не использован ли блок с данным ID
	var purchased_blocks = Global.get_all_purchased_blocks()
	for block_data in purchased_blocks:
		if block_data.id == block_id:
			return not block_data.used
	return false

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
	
	if slot_index < 0 or slot_index >= block_slots.size() or block_slots[slot_index].is_empty():
		return
	
	var slot_data = block_slots[slot_index]
	var block = slot_data.block
	var block_id = slot_data.block_id
	
	if block == null or not is_instance_valid(block):
		return
	
	if not can_use_block(block_id):
		return
	
	# ИСПРАВЛЕНИЕ: Передаем block_id в create_block_copy
	table_node.create_block_copy(block.type, block.text, block.loop_count, block_id)
	
	# Используем конкретный блок по его ID
	if not Global.use_block(block_id):
		return
	
	# Обновляем только этот конкретный блок
	update_single_block_availability(slot_index)

func update_availability() -> void:
	if not is_inside_tree():
		return
	
	for i in range(block_slots.size()):
		update_single_block_availability(i)

func update_single_block_availability(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= block_slots.size() or block_slots[slot_index].is_empty():
		return
	
	var slot_data = block_slots[slot_index]
	var block = slot_data.block
	var block_id = slot_data.block_id
	
	if block == null or not is_instance_valid(block):
		return
	
	# Каждый блок проверяет только свою доступность по своему ID
	var can_use = can_use_block(block_id)
	
	block.modulate.a = 1.0 if can_use else 0.3
	
	var area = block.get_node("Area2D")
	if area:
		area.input_pickable = can_use
