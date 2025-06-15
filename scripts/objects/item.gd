extends ObjectRoom
class_name Item

@onready var icon: Sprite2D = $Sprite2D
@onready var info: Label = $Label
@onready var background: ColorRect = $Label/BackGround

var type: int  # Использует ItemData.ItemType

func _ready() -> void:
	super._ready()
	add_to_group('items')
	add_to_group('barrier')
	
	# Проверяем, находимся ли мы в комнате испытаний
	generate_random_type()
	
	# Устанавливаем иконку после определения типа
	icon.texture = load(ItemData.get_item_icon(type))

# Выбор случайного типа на основе весов вероятности
func generate_random_type() -> void:
	# Получаем доступные типы предметов с их весами
	var available_weights = get_available_item_weights()
	
	# Рассчитываем общий вес
	var total_weight = 0.0
	for weight in available_weights.values():
		total_weight += weight
	
	# Выбираем случайный тип на основе весов
	var rand_value = randf() * total_weight
	var current_sum = 0.0
	
	for item_type in available_weights.keys():
		current_sum += available_weights[item_type]
		if rand_value <= current_sum:
			type = item_type
			return

# Получить доступные типы предметов с их весами
func get_available_item_weights() -> Dictionary:
	var available_weights = {}
	
	for item_type in ItemData.ITEMS:
		available_weights[item_type] = ItemData.get_item_weight(item_type)
	
	return available_weights

func use():
	if Global.get_all_purchased_blocks().size() >= Global.max_slots:
		show_info_message('Не хватает места!', 0.6)
		return
	
	var cost = ItemData.get_item_cost(type)
	if Global.get_coins() < cost:
		show_info_message('Не хватает денег!', 0.6)
		return
	
	# Покупаем предмет
	Global.spend_coins(cost)
	
	# Обрабатываем покупку - добавляем блок в инвентарь
	process_purchase()
	
	# Показываем сообщение
	var item_name = ItemData.get_item_description(type)
	show_info_message('Добавлено: ' + item_name, 0.8)
	
	# Удаляем предмет
	queue_free()

# Вспомогательная функция для отображения сообщений
func show_info_message(message: String, duration: float) -> void:
	info.text = message
	await get_tree().create_timer(duration).timeout
	info.text = ''

# Обработка покупки - добавление блока в инвентарь через Global
func process_purchase() -> void:
	var block_text = ItemData.get_block_text(type)
	
	if block_text != "":
		# Добавляем блок в глобальный инвентарь (Global.purchased_blocks)
		Global.purchase_block(block_text, 1)
		
		# Создаем блок на столе
		var table = get_tree().get_first_node_in_group("table")
		if table:
			table.create_purchased_block(block_text)

# Функция для обновления размера фона в зависимости от текста
func update_background_size() -> void:
	# Ждем один кадр, чтобы Label успел обновить свой размер
	await get_tree().process_frame
	
	# Добавляем отступы (padding) для фона
	var padding = Vector2(16, 12)  # горизонтальный и вертикальный отступ
	
	# Устанавливаем автоматический размер для Label
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Получаем реальный размер Label после обновления
	await get_tree().process_frame
	var label_size = info.get_rect().size
	
	# Устанавливаем размер фона с учетом отступов
	background.size = label_size + padding
	
	# Позиционируем фон так, чтобы он был центрирован относительно Label
	background.position = -padding / 2

func _on_area_2d_mouse_entered() -> void:
	background.visible = true
	info.text = ItemData.get_item_description(type)
	
	var block_text = ItemData.get_block_text(type)
	if block_text != "":
		var slot_count = ItemData.get_slot_count_by_item_type(type)
		info.text += "\nСлотов: " + str(slot_count)
	
	info.text += "\nЦена: " + str(ItemData.get_item_cost(type))
	
	# Обновляем размер фона после установки текста
	update_background_size()

func _on_area_2d_mouse_exited() -> void:
	background.visible = false
	info.text = ""
