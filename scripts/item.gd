extends ObjectRoom
class_name Item

enum ItemType{
	LOOP_BLOCK,
	CONDITION_BLOCK,
	ABILITY_BLOCK,
	ABILITY_PLUS_ATTACK,
	ABILITY_PLUS_MOVE,
	ABILITY_PLUS_HEAL,
	ABILITY_PLUS_DEFENSE,
	LOOP_2_TIMES,
	LOOP_3_TIMES,
	CONDITION_BELOW_HALF_HP
}

const ITEM_INFO: Dictionary = {
	ItemType.LOOP_BLOCK: "Блок цикл",
	ItemType.CONDITION_BLOCK: "Блок условие",
	ItemType.ABILITY_BLOCK: "Блок навык",
	ItemType.ABILITY_PLUS_ATTACK: "Навык +1 атака",
	ItemType.ABILITY_PLUS_MOVE: "Навык +1 перемещение",
	ItemType.ABILITY_PLUS_HEAL: "Навык +1 лечение",
	ItemType.ABILITY_PLUS_DEFENSE: "Навык +1 защита",
	ItemType.LOOP_3_TIMES: "Цикл на 3 повторения",
	ItemType.LOOP_2_TIMES: "Цикл на 2 повторения",
	ItemType.CONDITION_BELOW_HALF_HP: "Условие здоровье < 50%"
}

const ITEM_COST: Dictionary = {
	ItemType.LOOP_BLOCK: 8,
	ItemType.CONDITION_BLOCK: 8,
	ItemType.ABILITY_BLOCK: 8,
	ItemType.ABILITY_PLUS_ATTACK: 3,
	ItemType.ABILITY_PLUS_MOVE: 2,
	ItemType.ABILITY_PLUS_HEAL: 5,
	ItemType.ABILITY_PLUS_DEFENSE: 3,
	ItemType.LOOP_2_TIMES: 6,
	ItemType.LOOP_3_TIMES: 8,
	ItemType.CONDITION_BELOW_HALF_HP: 3
}
# Настройки вероятностей для каждого типа
# Сумма всех весов определяет общую вероятность
const ITEM_WEIGHT: Dictionary = {
	ItemType.LOOP_BLOCK: 0.5,
	ItemType.CONDITION_BLOCK: 0.5,
	ItemType.ABILITY_BLOCK: 0.5,
	ItemType.ABILITY_PLUS_ATTACK: 3.0,
	ItemType.ABILITY_PLUS_MOVE: 3.0,
	ItemType.ABILITY_PLUS_HEAL: 2.0,
	ItemType.ABILITY_PLUS_DEFENSE: 2.5,
	ItemType.LOOP_2_TIMES: 2.0,
	ItemType.LOOP_3_TIMES: 1.0,
	ItemType.CONDITION_BELOW_HALF_HP: 3.0
}

@onready var key_edit: LineEdit = $LineEdit

var key: int = 0
var linked_info: Info  # Прямая ссылка на связанную информацию
var type: ItemType

func _ready() -> void:
	super._ready()
	add_to_group('items')
	add_to_group('barrier')
	key_edit.visible = false
	key_edit.text = ""
	generate_random_type()
	call_deferred("find_and_link_info")  # Вызываем после загрузки сцены

# Выбор случайного типа на основе весов вероятности
func generate_random_type() -> void:
	# Создадим копию весов, чтобы работать с ней
	var available_weights = {}
	
	# Check if any abilities are unpurchased and available
	var unpurchased_abilities_exist = false
	for ability in Global.purchased_abilities:
		if !Global.purchased_abilities[ability]:
			unpurchased_abilities_exist = true
			break
	
	# Check if at least one ability has been purchased
	var any_ability_purchased = false
	for ability in Global.purchased_abilities:
		if Global.purchased_abilities[ability]:
			any_ability_purchased = true
			break
	
	# Check if at least one condition has been purchased
	var any_condition_purchased = false
	for condition in Global.purchased_conditions:
		if Global.purchased_conditions[condition]:
			any_condition_purchased = true
			break
	
	# Check if at least one loop has been purchased
	var any_loop_purchased = false
	for loop in Global.purchased_loops:
		if Global.purchased_loops[loop]:
			any_loop_purchased = true
			break
			
	# Check which conditions are unpurchased
	var unpurchased_conditions_exist = false
	for condition in Global.purchased_conditions:
		if !Global.purchased_conditions[condition]:
			unpurchased_conditions_exist = true
			break
			
	# Check which loops are unpurchased
	var unpurchased_loops_exist = false
	for loop in Global.purchased_loops:
		if !Global.purchased_loops[loop]:
			unpurchased_loops_exist = true
			break
	
	# Добавляем только те типы, которые еще не куплены (для способностей)
	for item_type in ITEM_WEIGHT:
		var include_item = true
		
		# For block types, only include if at least one of that category is purchased
		if item_type == ItemType.ABILITY_BLOCK:
			# Only include ability block if there are unpurchased abilities AND at least one ability is already purchased
			if !unpurchased_abilities_exist or !any_ability_purchased:
				include_item = false
		elif item_type == ItemType.CONDITION_BLOCK:
			# Only include condition block if there are unpurchased conditions AND at least one condition is already purchased
			if !unpurchased_conditions_exist or !any_condition_purchased:
				include_item = false
		elif item_type == ItemType.LOOP_BLOCK:
			# Only include loop block if there are unpurchased loops AND at least one loop is already purchased
			if !unpurchased_loops_exist or !any_loop_purchased:
				include_item = false
		
		# Проверка для способностей - пропускаем, если способность уже куплена
		elif item_type in [ItemType.ABILITY_PLUS_ATTACK, ItemType.ABILITY_PLUS_MOVE, 
						ItemType.ABILITY_PLUS_HEAL, ItemType.ABILITY_PLUS_DEFENSE]:
			var ability_name = Global.get_ability_name_for_item_type(item_type)
			if Global.is_ability_purchased(ability_name):
				include_item = false
		
		# Check for condition types
		elif item_type == ItemType.CONDITION_BELOW_HALF_HP:
			var condition_name = Global.get_ability_name_for_item_type(item_type)
			if Global.is_condition_purchased(condition_name):
				include_item = false
				
		# Check for loop types
		elif item_type in [ItemType.LOOP_2_TIMES, ItemType.LOOP_3_TIMES]:
			var loop_name = Global.get_ability_name_for_item_type(item_type)
			if Global.is_loop_purchased(loop_name):
				include_item = false
		
		# Добавляем тип в доступные, если он прошел проверку
		if include_item:
			available_weights[item_type] = ITEM_WEIGHT[item_type]
	
	# Проверка, что есть хотя бы один тип с положительным весом
	var total_weight = 0.0
	for weight in available_weights.values():
		total_weight += weight
	
	# Если нет валидных весов, используем специальное поведение
	if total_weight <= 0:
		# Если у нас нет доступных блоков, предлагаем базовые возможности
		var basic_types = []
		
		# Определяем доступные базовые типы:
		# - Если нет купленных способностей, добавляем первую способность
		if !any_ability_purchased and unpurchased_abilities_exist:
			# Find the first unpurchased ability
			for item_type in [ItemType.ABILITY_PLUS_MOVE, ItemType.ABILITY_PLUS_ATTACK, 
							ItemType.ABILITY_PLUS_HEAL, ItemType.ABILITY_PLUS_DEFENSE]:
				var ability_name = Global.get_ability_name_for_item_type(item_type)
				if !Global.is_ability_purchased(ability_name):
					basic_types.append(item_type)
					break
		
		# - Если нет купленных условий, добавляем первое условие
		if !any_condition_purchased and unpurchased_conditions_exist:
			basic_types.append(ItemType.CONDITION_BELOW_HALF_HP)
		
		# - Если нет купленных циклов, добавляем первый цикл
		if !any_loop_purchased and unpurchased_loops_exist:
			basic_types.append(ItemType.LOOP_2_TIMES)
		
		if basic_types.is_empty():
			# Если все уже куплено, или нет ничего доступного, не добавляем ничего (используем первый тип)
			type = ItemType.LOOP_2_TIMES  # Fallback option
		else:
			type = basic_types[randi() % basic_types.size()]
		return
	
	# Генерация случайного числа в диапазоне от 0 до суммы весов
	var rand_value = randf() * total_weight
	var current_sum = 0.0
	
	# Выбор типа на основе случайного значения и весов
	for item_type in available_weights.keys():
		current_sum += available_weights[item_type]
		if rand_value <= current_sum:
			type = item_type
			return  # Важно - выходим из функции сразу после установки типа
	
	# Если по какой-то причине тип не был установлен, выбираем первый доступный
	if !available_weights.is_empty():
		type = available_weights.keys()[0]

# Поиск и связывание с информацией по ключу
func find_and_link_info() -> void:
	if key > 0 and !linked_info:
		for info_node in get_tree().get_nodes_in_group('info'):
			if info_node.key == key:
				link_with_info(info_node)
				break

# Установка связи с информацией
func link_with_info(info_node) -> void:
	if !linked_info:  # Проверка что связь устанавливается только один раз
		linked_info = info_node
		# Если информация еще не связана с нами, устанавливаем связь
		if info_node.linked_item != self:
			info_node.link_with_item(self)

func use():
	# Check if player has enough coins
	var cost = ITEM_COST[type]
	if Global.get_coins() < cost:
		linked_info.info.text = 'Не хватает денег!'
		await get_tree().create_timer(0.6).timeout
		linked_info.info.text = ''
		return
	
	# Process the purchase
	Global.spend_coins(cost)
	
	# Handle special purchases for abilities, conditions, and loops
	match type:
		ItemType.ABILITY_PLUS_ATTACK, ItemType.ABILITY_PLUS_MOVE, \
		ItemType.ABILITY_PLUS_HEAL, ItemType.ABILITY_PLUS_DEFENSE:
			var ability_name = Global.get_ability_name_for_item_type(type)
			Global.purchase_ability(ability_name)
			
		ItemType.CONDITION_BELOW_HALF_HP:
			var condition_name = Global.get_ability_name_for_item_type(type)
			Global.purchase_condition(condition_name)
			
		ItemType.LOOP_3_TIMES:
			var loop_name = Global.get_ability_name_for_item_type(type)
			Global.purchase_loop(loop_name)
			
		ItemType.LOOP_2_TIMES:
			var loop_name = Global.get_ability_name_for_item_type(type)
			Global.purchase_loop(loop_name)
			
		_:
			# For block types, increase the block limit
			var block_type = convert_item_type_to_block_type(type)
			if block_type != -1:
				Global.increase_block_limit(block_type)
	
	# Show feedback
	if linked_info:
		var item_name = ITEM_INFO[type]
		linked_info.info.text = 'Добавлено: ' + item_name
		await get_tree().create_timer(0.8).timeout
		linked_info.info.text = ''
	
	# Remove the item and its linked info
	if linked_info:
		linked_info.queue_free()
	
	queue_free()

# Helper function to convert Item.ItemType to Block.BlockType
func convert_item_type_to_block_type(item_type) -> int:
	match item_type:
		ItemType.LOOP_BLOCK:
			return Block.BlockType.LOOP
		ItemType.CONDITION_BLOCK:
			return Block.BlockType.CONDITION
		ItemType.ABILITY_BLOCK:
			return Block.BlockType.ABILITY
		_:
			return -1  # Invalid type

func _on_line_edit_text_submitted(_new_text: String) -> void:
	key = key_edit.text.to_int()
	key_edit.visible = false
	get_tree().get_first_node_in_group("edit_mode").is_editing_key = false
	
	find_and_link_info()  # Ищем информацию по новому ключу
