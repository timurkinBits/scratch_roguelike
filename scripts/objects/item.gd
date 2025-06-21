extends ObjectRoom
class_name Item

@onready var icon: Sprite2D = $Sprite2D
@onready var info: Label = $Label
@onready var background: ColorRect = $Label/BackGround

var type: int  # Использует ItemData.ItemType или ItemData.SpecialCommandType
var is_special_command: bool = false  # Флаг для различения обычных блоков и особых команд

func _ready() -> void:
	super._ready()
	add_to_group('items')
	add_to_group('barrier')
	
	# Генерируем случайный тип (блок или особая команда)
	generate_random_type()
	
	# Устанавливаем иконку после определения типа
	if is_special_command:
		icon.texture = load(ItemData.get_special_command_icon(type))
	else:
		icon.texture = load(ItemData.get_item_icon(type))

# Выбор случайного типа на основе весов вероятности (блоки + особые команды)
func generate_random_type() -> void:
	# Получаем доступные типы предметов и особых команд с их весами
	var available_weights = get_all_available_weights()
	
	# Рассчитываем общий вес
	var total_weight = 0.0
	for weight in available_weights.values():
		total_weight += weight
	
	# Выбираем случайный тип на основе весов
	var rand_value = randf() * total_weight
	var current_sum = 0.0
	
	for item_info in available_weights.keys():
		current_sum += available_weights[item_info]
		if rand_value <= current_sum:
			type = item_info.type
			is_special_command = item_info.is_special
			return

# Получить все доступные типы (блоки + особые команды) с их весами для магазина
func get_all_available_weights() -> Dictionary:
	var available_weights = {}
	
	# Добавляем обычные блоки с весами для магазина
	for item_type in ItemData.BLOCKS:
		var item_info = {"type": item_type, "is_special": false}
		available_weights[item_info] = ItemData.get_block_shop_weight(item_type)
	
	# Добавляем особые команды с финальными весами для магазина
	for item_type in ItemData.SPECIAL_COMMANDS:
		var item_info = {"type": item_type, "is_special": true}
		available_weights[item_info] = ItemData.get_special_command_shop_weight(item_type)
	
	return available_weights

func use():
	# Проверяем ограничения по слотам
	if is_special_command:
		if Global.get_all_purchased_special_commands().size() >= Global.max_slots_for_commands:
			show_info_message('Не хватает места для особой команды!', 0.6)
			return
	else:
		if Global.get_all_purchased_blocks().size() >= Global.max_slots_for_blocks:
			show_info_message('Не хватает места для блока!', 0.6)
			return
	
	# Получаем стоимость
	var cost = get_item_cost()
	if Global.get_coins() < cost:
		show_info_message('Не хватает денег!', 0.6)
		return
	
	# Покупаем предмет
	Global.spend_coins(cost)
	
	# Обрабатываем покупку
	process_purchase()
	
	# Показываем сообщение
	var item_name = get_item_name()
	show_info_message('Добавлено: ' + item_name, 0.8)
	
	# Удаляем предмет
	queue_free()

# Получить стоимость предмета
func get_item_cost() -> int:
	if is_special_command:
		return ItemData.get_special_command_cost(type)
	else:
		return ItemData.get_item_cost(type)

# Получить название предмета
func get_item_name() -> String:
	if is_special_command:
		return ItemData.get_special_command_name(type)
	else:
		return ItemData.get_item_description(type)

# Получить описание предмета
func get_item_description() -> String:
	if is_special_command:
		return ItemData.get_special_command_description(type)
	else:
		return ItemData.get_item_description(type)

# Вспомогательная функция для отображения сообщений
func show_info_message(message: String, duration: float) -> void:
	info.text = message
	await get_tree().create_timer(duration).timeout
	info.text = ''

# Обработка покупки
func process_purchase() -> void:
	if is_special_command:
		# Покупаем особую команду
		Global.purchase_special_command(type, 1)
		
		# Уведомляем меню особых команд об обновлении
		var special_menu = get_tree().get_first_node_in_group("special_command_menu")
		if special_menu:
			special_menu.refresh_menu()
	else:
		# Покупаем обычный блок
		var block_text = ItemData.get_block_text(type)
		if block_text != "":
			# Добавляем блок в глобальный инвентарь
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
	info.text = get_item_description()
	
	if is_special_command:
		# Информация для особой команды
		var special_data = ItemData.get_special_command_data(type)
		if special_data.has_value:
			info.text += "\nМаксимальное значение: " + str(special_data.max_value)
	else:
		# Информация для обычного блока
		var block_text = ItemData.get_block_text(type)
		if block_text != "":
			var slot_count = ItemData.get_slot_count_by_item_type(type)
			info.text += "\nСлотов: " + str(slot_count)
	
	info.text += "\nЦена: " + str(get_item_cost())
	
	# Обновляем размер фона после установки текста
	update_background_size()

func _on_area_2d_mouse_exited() -> void:
	background.visible = false
	info.text = ""
