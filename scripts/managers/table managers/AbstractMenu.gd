extends Node2D
class_name AbstractMenu

@onready var table_node: Table = $".."

var slots: Array = []
var max_slots: int = 1

# Абстрактные методы - переопределить в наследниках
func get_purchased_items() -> Array:
	assert(false, "Переопределить get_purchased_items()")
	return []

func can_use_item(item_id: String) -> bool:
	assert(false, "Переопределить can_use_item()")
	return false

func create_item_in_slot(item_data: Dictionary, slot_index: int) -> Node:
	assert(false, "Переопределить create_item_in_slot()")
	return null

func create_item_copy_on_table(item_data: Dictionary) -> void:
	assert(false, "Переопределить create_item_copy_on_table()")

func reset_all_items() -> void:
	assert(false, "Переопределить reset_all_items()")

# Настройки меню
func get_inventory_signal() -> String:
	return ""

func get_availability_signal() -> String:
	return ""

func get_slot_spacing() -> float:
	return 70.0

func _ready() -> void:
	slots.resize(max_slots)
	_connect_signals()
	call_deferred("refresh_menu")

# Подключение сигналов обновления
func _connect_signals() -> void:
	var inventory_sig = get_inventory_signal()
	var availability_sig = get_availability_signal()
	
	if inventory_sig != "" and Global.has_signal(inventory_sig):
		Global.connect(inventory_sig, refresh_menu)
	
	if availability_sig != "" and Global.has_signal(availability_sig):
		Global.connect(availability_sig, update_availability)

# Полное обновление меню
func refresh_menu() -> void:
	if not is_inside_tree():
		return
	
	_clear_slots()
	var items = get_purchased_items()
	
	for i in range(min(items.size(), max_slots)):
		var item = create_item_in_slot(items[i], i)
		if item:
			_setup_slot(item, items[i], i)

# Очистка всех слотов
func _clear_slots() -> void:
	for item in slots:
		if is_instance_valid(item):
			item.queue_free()
	slots.fill(null)

# Настройка элемента в слоте
func _setup_slot(item: Node, item_data: Dictionary, slot_index: int) -> void:
	add_child(item)
	slots[slot_index] = item
	item.position = Vector2(0, slot_index * get_slot_spacing())
	
	# Подключение клика
	var area = item.get_node("Area2D")
	if area:
		area.input_event.connect(_on_item_click.bind(item_data.id, item))
	
	_update_item_state(item, item_data.id)

# Обработка клика по элементу
func _on_item_click(viewport: Node, event: InputEvent, shape_idx: int, item_id: String, item: Node) -> void:
	if not _is_left_click(event) or not can_use_item(item_id):
		return
	
	var item_data = _find_item_by_id(item_id)
	if not item_data.is_empty():
		create_item_copy_on_table(item_data)

# Проверка левого клика мыши
func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

# Обновление доступности всех элементов
func update_availability() -> void:
	if not is_inside_tree():
		return
	
	var items = get_purchased_items()
	for i in range(min(slots.size(), items.size())):
		var item = slots[i]
		if is_instance_valid(item):
			_update_item_state(item, items[i].id)

# Обновление состояния элемента
func _update_item_state(item: Node, item_id: String) -> void:
	var is_available = can_use_item(item_id)
	item.modulate.a = 1.0 if is_available else 0.3
	
	var area = item.get_node("Area2D")
	if area:
		area.input_pickable = is_available

# Сброс и обновление всех элементов
func reset_all_items_and_update() -> void:
	reset_all_items()
	call_deferred("update_availability")

# Поиск элемента по ID
func _find_item_by_id(item_id: String) -> Dictionary:
	for item_data in get_purchased_items():
		if item_data.get("id", "") == item_id:
			return item_data
	return {}
