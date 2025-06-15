extends Node2D

@onready var table_node: Table = $".."

const MAX_SLOTS = 8
var block_slots: Array[Block] = []

func _ready() -> void:
	add_to_group("block_menu")
	block_slots.resize(MAX_SLOTS)
	
	# Подключаем правильные сигналы
	Global.connect("inventory_changed", force_refresh)  # Только для покупки новых блоков
	Global.connect("block_availability_changed", update_all_availability)  # Для изменения доступности
	call_deferred("refresh_menu")

func refresh_menu() -> void:
	if not is_inside_tree():
		return
	
	clear_menu()
	
	var purchased_blocks = Global.get_all_purchased_blocks()
	for i in range(min(purchased_blocks.size(), MAX_SLOTS)):
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
	
	# Connect click event with proper parameters
	var area = block.get_node("Area2D")
	if area:
		area.input_event.connect(_on_block_clicked.bind(block_data.id, block))

func _on_block_clicked(viewport: Node, event: InputEvent, shape_idx: int, block_id: String, block: Block) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	if not Global.can_use_block_by_id(block_id):
		return
	
	# Create copy on table
	table_node.create_block_copy(block.text, block_id)
	
	# Сразу обновляем визуальное состояние блока в меню
	var is_available = Global.can_use_block_by_id(block_id)
	block.modulate.a = 1.0 if is_available else 0.3
	
	var area = block.get_node("Area2D")
	if area:
		area.input_pickable = is_available

func update_block_availability(block_id: String) -> void:
	# Find the block in slots and update its availability
	var inventory_blocks = Global.get_all_purchased_blocks()
	
	for i in range(block_slots.size()):
		var block = block_slots[i]
		if not is_instance_valid(block) or i >= inventory_blocks.size():
			continue
		
		var block_data = inventory_blocks[i]
		if block_data.id == block_id:
			var is_available = Global.can_use_block_by_id(block_id)
			
			block.modulate.a = 1.0 if is_available else 0.3
			
			var area = block.get_node("Area2D")
			if area:
				area.input_pickable = is_available
			break

# Получить блок в меню по ID
func get_menu_block_by_id(block_id: String) -> Block:
	var inventory_blocks = Global.get_all_purchased_blocks()
	
	for i in range(block_slots.size()):
		var block = block_slots[i]
		if not is_instance_valid(block) or i >= inventory_blocks.size():
			continue
		
		var block_data = inventory_blocks[i]
		if block_data.id == block_id:
			return block
	
	return null

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

# Получить количество доступных блоков в меню
func get_available_blocks_count() -> int:
	var count = 0
	var inventory_blocks = Global.get_all_purchased_blocks()
	
	for block_data in inventory_blocks:
		if Global.can_use_block_by_id(block_data.id):
			count += 1
	
	return count

# Получить количество использованных блоков в меню
func get_used_blocks_count() -> int:
	var count = 0
	var inventory_blocks = Global.get_all_purchased_blocks()
	
	for block_data in inventory_blocks:
		if not Global.can_use_block_by_id(block_data.id):
			count += 1
	
	return count

# Сбросить использование всех блоков (для начала нового хода)
func reset_all_blocks() -> void:
	Global.reset_all_blocks()
	# Не пересоздаем меню, только обновляем доступность
	update_all_availability()

# Проверить, есть ли блоки определенного типа в меню
func has_blocks_with_text(text: String) -> bool:
	var inventory_blocks = Global.get_all_purchased_blocks()
	
	for block_data in inventory_blocks:
		if block_data.text == text:
			return true
	
	return false

# Получить все блоки с определенным текстом
func get_blocks_with_text(text: String) -> Array:
	var matching_blocks = []
	var inventory_blocks = Global.get_all_purchased_blocks()
	
	for block_data in inventory_blocks:
		if block_data.text == text:
			matching_blocks.append(block_data)
	
	return matching_blocks

# Добавляем функцию для принудительного обновления меню при покупке
func force_refresh() -> void:
	refresh_menu()
