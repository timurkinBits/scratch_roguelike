extends Node2D
class_name AbstractMenu

@onready var table_node: Table = $".."

var slots: Array = []
var max_slots: int = 1

# Абстрактные методы, которые должны быть переопределены в наследниках
func get_purchased_items() -> Array:
	assert(false, "get_purchased_items() должен быть переопределен в наследнике")
	return []

func can_use_item(item_id: String) -> bool:
	assert(false, "can_use_item() должен быть переопределен в наследнике")
	return false

func use_item(item_id: String) -> bool:
	assert(false, "use_item() должен быть переопределен в наследнике")
	return false

func reset_all_items() -> void:
	assert(false, "reset_all_items() должен быть переопределен в наследнике")

func create_item_in_slot(item_data: Dictionary, slot_index: int) -> Node:
	assert(false, "create_item_in_slot() должен быть переопределен в наследнике")
	return null

func create_item_copy_on_table(item_data: Dictionary) -> void:
	assert(false, "create_item_copy_on_table() должен быть переопределен в наследнике")

func get_inventory_changed_signal() -> String:
	assert(false, "get_inventory_changed_signal() должен быть переопределен в наследнике")
	return ""

func get_availability_changed_signal() -> String:
	assert(false, "get_availability_changed_signal() должен быть переопределен в наследнике")
	return ""

func get_slot_vertical_spacing() -> float:
	return 70.0  # Может быть переопределен в наследниках

# Общая инициализация
func _ready() -> void:
	slots.resize(max_slots)
	
	# ИСПРАВЛЕНО: Проверяем существование сигналов перед подключением
	var inventory_signal = get_inventory_changed_signal()
	var availability_signal = get_availability_changed_signal()
	
	if inventory_signal != "" and Global.has_signal(inventory_signal):
		if not Global.is_connected(inventory_signal, refresh_menu):
			Global.connect(inventory_signal, refresh_menu)
	
	if availability_signal != "" and Global.has_signal(availability_signal):
		if not Global.is_connected(availability_signal, update_all_availability):
			Global.connect(availability_signal, update_all_availability)
	
	call_deferred("refresh_menu")

# ИСПРАВЛЕНО: Более надежное обновление меню
func refresh_menu() -> void:
	if not is_inside_tree():
		return
	
	var purchased_items = get_purchased_items()
	
	# Всегда пересоздаем меню для консистентности
	clear_menu()
	
	for i in range(min(purchased_items.size(), max_slots)):
		var item_data = purchased_items[i]
		var item = create_item_in_slot(item_data, i)
		if item:
			setup_item_in_slot(item, item_data, i)

# Очистка меню
func clear_menu() -> void:
	for item in slots:
		if is_instance_valid(item):
			item.queue_free()
	slots.fill(null)

# Настройка элемента в слоте
func setup_item_in_slot(item: Node, item_data: Dictionary, slot_index: int) -> void:
	add_child(item)
	slots[slot_index] = item
	item.position = Vector2(0, slot_index * get_slot_vertical_spacing())
	
	# Подключаем обработчик клика
	var area = item.get_node("Area2D")
	if area:
		# ИСПРАВЛЕНО: Проверяем существование сигнала перед подключением
		if not area.is_connected("input_event", _on_item_clicked):
			area.input_event.connect(_on_item_clicked.bind(item_data.id, item))
	
	# Устанавливаем начальное состояние доступности
	update_item_availability(item, item_data.id)

# Обработчик клика по элементу
func _on_item_clicked(viewport: Node, event: InputEvent, shape_idx: int, item_id: String, item: Node) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	if not can_use_item(item_id):
		return
	
	# Получаем данные элемента
	var item_data = find_item_data_by_id(item_id)
	if item_data.is_empty():
		return
	
	# Создаем копию на столе
	create_item_copy_on_table(item_data)

# ИСПРАВЛЕНО: Более надежное обновление доступности
func update_all_availability() -> void:
	if not is_inside_tree():
		return
	
	var purchased_items = get_purchased_items()
	
	for i in range(min(slots.size(), purchased_items.size())):
		var item = slots[i]
		if not is_instance_valid(item):
			continue
		
		var item_data = purchased_items[i]
		update_item_availability(item, item_data.id)

# Обновление доступности конкретного элемента
func update_item_availability(item: Node, item_id: String) -> void:
	if not is_instance_valid(item):
		return
		
	var is_available = can_use_item(item_id)
	
	# Обновляем визуальное состояние
	item.modulate.a = 1.0 if is_available else 0.3
	
	var area = item.get_node("Area2D")
	if area:
		area.input_pickable = is_available

# Сброс использования всех элементов (для начала нового хода)
func reset_all_items_and_update() -> void:
	reset_all_items()
	# ИСПРАВЛЕНО: Добавляем задержку перед обновлением
	call_deferred("update_all_availability")

# Поиск данных элемента по ID
func find_item_data_by_id(item_id: String) -> Dictionary:
	var purchased_items = get_purchased_items()
	for item_data in purchased_items:
		if item_data.get("id", "") == item_id:
			return item_data
	return {}
