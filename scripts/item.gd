extends ObjectRoom
class_name Item

@onready var icon: Sprite2D = $Sprite2D
@onready var info: Label = $Label

var type: int  # Использует ItemData.ItemType

func _ready() -> void:
	super._ready()
	add_to_group('items')
	add_to_group('barrier')
	
	# Проверяем, находимся ли мы в комнате испытаний
	var room = get_parent()
	if room.type == room.RoomType.CHALLENGE:
		generate_challenge_reward()
	else:
		generate_random_type()
	
	# Устанавливаем иконку после определения типа
	icon.texture = load(ItemData.get_item_icon(type))

# Генерация особой награды за испытание
func generate_challenge_reward() -> void:
	# Получаем случайную награду из списка наград за испытания
	var challenge_rewards = ItemData.get_challenge_rewards()
	if challenge_rewards.is_empty():
		generate_random_type()  # Если список наград пуст, используем обычную генерацию
		return
	
	# Выбираем случайную награду
	challenge_rewards.shuffle()
	type = challenge_rewards[0]  # Берем первый элемент из перемешанного списка

# Выбор случайного типа на основе весов вероятности
func generate_random_type() -> void:
	# Получаем доступные типы предметов с их весами
	var available_weights = get_available_item_weights()
	
	# Рассчитываем общий вес
	var total_weight = 0.0
	for weight in available_weights.values():
		total_weight += weight
	
	# Если нет доступных весов, используем резервную логику
	if total_weight <= 0:
		type = get_fallback_type()
		return
	
	# Выбираем случайный тип на основе весов
	var rand_value = randf() * total_weight
	var current_sum = 0.0
	
	for item_type in available_weights.keys():
		current_sum += available_weights[item_type]
		if rand_value <= current_sum:
			type = item_type
			return
	
	# Резервный выбор первого доступного типа
	if !available_weights.is_empty():
		type = available_weights.keys()[0]

# Получить доступные типы предметов с их весами
func get_available_item_weights() -> Dictionary:
	var available_weights = {}
	
	# Проходим только по конкретным предметам (не абстрактным блокам)
	var concrete_items = [
		ItemData.ItemType.ABILITY_PLUS_ATTACK,
		ItemData.ItemType.ABILITY_PLUS_MOVE,
		ItemData.ItemType.ABILITY_PLUS_HEAL,
		ItemData.ItemType.ABILITY_PLUS_DEFENSE,
		ItemData.ItemType.LOOP_2_TIMES,
		ItemData.ItemType.LOOP_3_TIMES,
		ItemData.ItemType.CONDITION_BELOW_HALF_HP
	]
	
	for item_type in concrete_items:
		if should_include_item_type(item_type):
			available_weights[item_type] = ItemData.get_item_weight(item_type)
	
	return available_weights

# Определить, следует ли включить тип предмета
func should_include_item_type(item_type: int) -> bool:
	# Получаем текст блока для данного типа предмета
	var block_text = ItemData.get_ability_name_for_item_type(item_type)
	if block_text == "":
		return false
	
	# Получаем тип блока
	var block_type = ItemData.get_block_type(item_type)
	if block_type == -1:
		return false
	
	# Всегда разрешаем покупку блоков для получения дополнительных использований
	# В новой системе каждый блок - отдельный экземпляр
	return true

# Получить резервный тип предмета
func get_fallback_type() -> int:
	# Возвращаем самый базовый предмет
	return ItemData.ItemType.ABILITY_PLUS_MOVE

func use():
	# Проверяем, хватает ли денег
	var cost = ItemData.get_item_cost(type)
	if Global.get_coins() < cost:
		show_info_message('Не хватает денег!', 0.6)
		return
	
	# Покупаем предмет
	Global.spend_coins(cost)
	
	# Обрабатываем покупку
	process_purchase()
	
	# Показываем сообщение и удаляем предмет
	var item_name = ItemData.get_item_description(type)
	show_info_message('Добавлено: ' + item_name, 0.8)
	
	# Удаляем предмет
	queue_free()

# Вспомогательная функция для отображения сообщений
func show_info_message(message: String, duration: float) -> void:
	info.text = message
	await get_tree().create_timer(duration).timeout
	info.text = ''

# Обработка покупки в зависимости от типа предмета
func process_purchase() -> void:
	var block_text = ItemData.get_ability_name_for_item_type(type)
	var block_type = ItemData.get_block_type(type)
	
	if block_text != "" and block_type != -1:
		# Покупаем конкретный блок с одним использованием
		# В новой системе каждый purchase_block создает отдельный экземпляр
		Global.purchase_block(block_type, block_text, 1)
		
		# Обновляем старые словари для совместимости
		match block_type:
			ItemData.BlockType.ABILITY:
				Global.purchased_abilities[block_text] = true
			ItemData.BlockType.CONDITION:
				Global.purchased_conditions[block_text] = true
			ItemData.BlockType.LOOP:
				Global.purchased_loops[block_text] = true

func _on_area_2d_mouse_entered() -> void:
	info.get_node("ColorRect").visible = true
	info.text = ItemData.get_item_description(type)
	
	# Показываем информацию о слотах для конкретного блока
	var block_text = ItemData.get_ability_name_for_item_type(type)
	var block_type = ItemData.get_block_type(type)
	
	if block_text != "" and block_type != -1:
		var slot_count = ItemData.get_slot_count(block_type, block_text)
		info.text += "\nСлотов: " + str(slot_count)
		
		# Показываем текущее количество доступных блоков (неиспользованных)
		var available_count = Global.get_available_block_count(block_type, block_text)
		if available_count > 0:
			info.text += "\nДоступно: " + str(available_count)
	
	info.text += "\nЦена: " + str(ItemData.get_item_cost(type))

func _on_area_2d_mouse_exited() -> void:
	info.get_node("ColorRect").visible = false
	info.text = ""
