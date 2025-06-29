extends Node2D

@onready var table_node: Table = $".."

var block_slots: Array[Block] = []
const SLOT_HEIGHT = 30

func _ready() -> void:
	add_to_group("block_menu")
	block_slots.resize(Global.max_slots_for_blocks)
	
	# Подключение сигналов
	Global.connect("inventory_changed", refresh_menu)
	Global.connect("block_availability_changed", update_availability)
	call_deferred("refresh_menu")

# Полное обновление меню
func refresh_menu() -> void:
	if not is_inside_tree():
		return
	
	_clear_slots()
	var purchased_blocks = Global.get_all_purchased_blocks()
	
	for i in range(min(purchased_blocks.size(), Global.max_slots_for_blocks)):
		_create_block_slot(purchased_blocks[i], i)

# Очистка всех слотов
func _clear_slots() -> void:
	for block in block_slots:
		if is_instance_valid(block):
			block.queue_free()
	block_slots.fill(null)

# Создание блока в слоте
func _create_block_slot(block_data: Dictionary, slot_index: int) -> void:
	var block_scene = load("res://scenes/Block.tscn")
	var block = block_scene.instantiate()
	
	# Настройка блока
	block.text = block_data.text
	block.block_id = block_data.id
	block.is_menu_card = true
	block.position = Vector2(0, slot_index * SLOT_HEIGHT)
	
	add_child(block)
	block_slots[slot_index] = block
	
	_setup_block_interaction(block, block_data.id)

# Настройка взаимодействия с блоком
func _setup_block_interaction(block: Block, block_id: String) -> void:
	_update_block_state(block, block_id)
	
	var area = block.get_node("Area2D")
	if area:
		area.input_event.connect(_on_block_click.bind(block_id, block))

# Обработка клика по блоку
func _on_block_click(viewport: Node, event: InputEvent, shape_idx: int, block_id: String, block: Block) -> void:
	if not _is_left_click(event) or not Global.can_use_block_by_id(block_id):
		return
	
	table_node.create_block_copy(block.text, block_id)

# Проверка левого клика
func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

# Обновление доступности всех блоков
func update_availability() -> void:
	if not is_inside_tree():
		return
	
	await get_tree().process_frame
	var inventory_blocks = Global.get_all_purchased_blocks()
	
	for i in range(min(block_slots.size(), inventory_blocks.size())):
		var block = block_slots[i]
		if is_instance_valid(block):
			_update_block_state(block, inventory_blocks[i].id)

# Обновление состояния блока
func _update_block_state(block: Block, block_id: String) -> void:
	var is_available = Global.can_use_block_by_id(block_id)
	block.modulate.a = 1.0 if is_available else 0.3
	
	var area = block.get_node("Area2D")
	if area:
		area.input_pickable = is_available

# Сброс всех блоков
func reset_all_blocks() -> void:
	Global.reset_all_blocks()
	call_deferred("update_availability")
