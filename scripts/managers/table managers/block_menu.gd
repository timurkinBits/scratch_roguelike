extends Node2D

@onready var table_node: Table = $".."

var block_slots: Array[Block] = []

func _ready() -> void:
	add_to_group("block_menu")
	block_slots.resize(Global.max_slots)
	
	# Подключаем правильные сигналы
	Global.connect("inventory_changed", refresh_menu)  # Только для покупки новых блоков
	Global.connect("block_availability_changed", update_all_availability)  # Для изменения доступности
	call_deferred("refresh_menu")

func refresh_menu() -> void:
	if not is_inside_tree():
		return
	
	clear_menu()
	
	var purchased_blocks = Global.get_all_purchased_blocks()
	for i in range(min(purchased_blocks.size(), Global.max_slots)):
		var block_data = purchased_blocks[i]
		create_block_in_slot(block_data, i)

func clear_menu() -> void:
	for block in block_slots:
		if is_instance_valid(block):
			block.queue_free()
	block_slots.fill(null)

func create_block_in_slot(block_data: Dictionary, slot_index: int) -> void:
	var block_scene = load("res://scenes/Block.tscn")
	var block = block_scene.instantiate()
	
	block.text = block_data.text
	block.block_id = block_data.id
	block.is_menu_card = true
	
	add_child(block)
	block_slots[slot_index] = block
	block.position = Vector2(0, slot_index * 30)
	
	# Сразу устанавливаем правильную доступность при создании
	var is_available = Global.can_use_block_by_id(block_data.id)
	block.modulate.a = 1.0 if is_available else 0.3
	
	var area = block.get_node("Area2D")
	if area:
		area.input_pickable = is_available
		area.input_event.connect(_on_block_clicked.bind(block_data.id, block))

func _on_block_clicked(viewport: Node, event: InputEvent, shape_idx: int, block_id: String, block: Block) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	if not Global.can_use_block_by_id(block_id):
		return
	
	# Create copy on table
	table_node.create_block_copy(block.text, block_id)
	
	# ИСПРАВЛЕНИЕ 1: НЕ обновляем визуальное состояние сразу после создания копии
	# Состояние должно обновляться только через сигнал block_availability_changed
	# который срабатывает когда блок действительно используется или освобождается

# Обновить доступность всех блоков в меню
func update_all_availability() -> void:
	if not is_inside_tree():
		return
	
	var inventory_blocks = Global.get_all_purchased_blocks()
	
	for i in range(min(block_slots.size(), inventory_blocks.size())):
		var block = block_slots[i]
		if not is_instance_valid(block):
			continue
		
		var block_data = inventory_blocks[i]
		var is_available = Global.can_use_block_by_id(block_data.id)
		
		# Update visual state
		block.modulate.a = 1.0 if is_available else 0.3
		
		var area = block.get_node("Area2D")
		if area:
			area.input_pickable = is_available

# ИСПРАВЛЕНИЕ 2: Новый метод для сброса использования блоков в начале хода
func reset_all_blocks_for_new_turn() -> void:
	"""Сбрасывает использование всех блоков в начале нового хода"""
	Global.reset_all_blocks()
	update_all_availability()

# Устаревший метод - оставляем для совместимости
func reset_all_blocks() -> void:
	reset_all_blocks_for_new_turn()
