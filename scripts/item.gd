extends ObjectRoom
class_name Item

@onready var key_edit: LineEdit = $LineEdit

var key: int = 0
var linked_info: Info  # Прямая ссылка на связанную информацию
var type: int  # Использует ItemData.ItemType

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
	# Check purchase status for different categories
	var purchase_status = {
		"ability": {
			"any_purchased": has_any_purchased(Global.purchased_abilities),
			"unpurchased_exist": has_unpurchased(Global.purchased_abilities)
		},
		"condition": {
			"any_purchased": has_any_purchased(Global.purchased_conditions),
			"unpurchased_exist": has_unpurchased(Global.purchased_conditions)
		},
		"loop": {
			"any_purchased": has_any_purchased(Global.purchased_loops),
			"unpurchased_exist": has_unpurchased(Global.purchased_loops)
		}
	}
	
	# Get available item types with their weights
	var available_weights = get_available_item_weights(purchase_status)
	
	# Calculate total weight
	var total_weight = 0.0
	for weight in available_weights.values():
		total_weight += weight
	
	# If no valid weights, use fallback logic
	if total_weight <= 0:
		type = get_fallback_type(purchase_status)
		return
	
	# Select random type based on weights
	var rand_value = randf() * total_weight
	var current_sum = 0.0
	
	for item_type in available_weights.keys():
		current_sum += available_weights[item_type]
		if rand_value <= current_sum:
			type = item_type
			return
	
	# Fallback to first available type if nothing was selected
	if !available_weights.is_empty():
		type = available_weights.keys()[0]

# Helper function to check if any items in category are purchased
func has_any_purchased(category_dict: Dictionary) -> bool:
	for item in category_dict:
		if category_dict[item]:
			return true
	return false

# Helper function to check if any items in category are unpurchased
func has_unpurchased(category_dict: Dictionary) -> bool:
	for item in category_dict:
		if !category_dict[item]:
			return true
	return false

# Get available item types with their weights
func get_available_item_weights(purchase_status: Dictionary) -> Dictionary:
	var available_weights = {}
	
	for item_type in ItemData.ItemType.values():
		if should_include_item_type(item_type, purchase_status):
			available_weights[item_type] = ItemData.get_item_weight(item_type)
	
	return available_weights

# Determine if an item type should be included based on purchase status
func should_include_item_type(item_type: int, purchase_status: Dictionary) -> bool:
	# Block types - include only if at least one item of that category is purchased
	if item_type == ItemData.ItemType.ABILITY_BLOCK:
		return purchase_status.ability.any_purchased
	elif item_type == ItemData.ItemType.CONDITION_BLOCK:
		return purchase_status.condition.any_purchased
	elif item_type == ItemData.ItemType.LOOP_BLOCK:
		return purchase_status.loop.any_purchased
	
	# Ability types - include only if not already purchased
	elif item_type in [ItemData.ItemType.ABILITY_PLUS_ATTACK, ItemData.ItemType.ABILITY_PLUS_MOVE, 
					ItemData.ItemType.ABILITY_PLUS_HEAL, ItemData.ItemType.ABILITY_PLUS_DEFENSE]:
		var ability_name = ItemData.get_ability_name_for_item_type(item_type)
		return !Global.is_ability_purchased(ability_name)
	
	# Condition type
	elif item_type == ItemData.ItemType.CONDITION_BELOW_HALF_HP:
		var condition_name = ItemData.get_ability_name_for_item_type(item_type)
		return !Global.is_condition_purchased(condition_name)
	
	# Loop types
	elif item_type in [ItemData.ItemType.LOOP_2_TIMES, ItemData.ItemType.LOOP_3_TIMES]:
		var loop_name = ItemData.get_ability_name_for_item_type(item_type)
		return !Global.is_loop_purchased(loop_name)
	
	# Default - include
	return true

# Get fallback item type when no weights are available
func get_fallback_type(purchase_status: Dictionary) -> int:
	var basic_types = []
	
	# If no abilities purchased, add the first unpurchased ability
	if !purchase_status.ability.any_purchased and purchase_status.ability.unpurchased_exist:
		for item_type in [ItemData.ItemType.ABILITY_PLUS_MOVE, ItemData.ItemType.ABILITY_PLUS_ATTACK, 
						ItemData.ItemType.ABILITY_PLUS_HEAL, ItemData.ItemType.ABILITY_PLUS_DEFENSE]:
			var ability_name = ItemData.get_ability_name_for_item_type(item_type)
			if !Global.is_ability_purchased(ability_name):
				basic_types.append(item_type)
				break
	
	# If no conditions purchased, add the first condition
	if !purchase_status.condition.any_purchased and purchase_status.condition.unpurchased_exist:
		basic_types.append(ItemData.ItemType.CONDITION_BELOW_HALF_HP)
	
	# If no loops purchased, add the first loop
	if !purchase_status.loop.any_purchased and purchase_status.loop.unpurchased_exist:
		basic_types.append(ItemData.ItemType.LOOP_2_TIMES)
	
	if basic_types.is_empty():
		return ItemData.ItemType.LOOP_2_TIMES  # Fallback option
	else:
		return basic_types[randi() % basic_types.size()]

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
	var cost = ItemData.get_item_cost(type)
	if Global.get_coins() < cost:
		show_info_message('Не хватает денег!', 0.6)
		return
	
	# Process the purchase
	Global.spend_coins(cost)
	
	# Process the purchase based on item type
	process_purchase()
	
	# Show feedback and remove item
	if linked_info:
		var item_name = ItemData.get_item_description(type)
		show_info_message('Добавлено: ' + item_name, 0.8)
	
	# Remove the item and its linked info
	cleanup_and_remove()

# Helper function to display messages in info panel
func show_info_message(message: String, duration: float) -> void:
	if linked_info:
		linked_info.info.text = message
		await get_tree().create_timer(duration).timeout
		linked_info.info.text = ''

# Process the purchase based on item type
func process_purchase() -> void:
	match type:
		ItemData.ItemType.ABILITY_PLUS_ATTACK, ItemData.ItemType.ABILITY_PLUS_MOVE, \
		ItemData.ItemType.ABILITY_PLUS_HEAL, ItemData.ItemType.ABILITY_PLUS_DEFENSE:
			var ability_name = ItemData.get_ability_name_for_item_type(type)
			Global.purchase_ability(ability_name)
			
		ItemData.ItemType.CONDITION_BELOW_HALF_HP:
			var condition_name = ItemData.get_ability_name_for_item_type(type)
			Global.purchase_condition(condition_name)
			
		ItemData.ItemType.LOOP_3_TIMES, ItemData.ItemType.LOOP_2_TIMES:
			var loop_name = ItemData.get_ability_name_for_item_type(type)
			Global.purchase_loop(loop_name)
			
		_:
			# For block types, increase the block limit
			var block_type = ItemData.get_block_type(type)
			if block_type != -1:
				Global.increase_block_limit(block_type)

# Remove the item and its linked info
func cleanup_and_remove() -> void:
	if linked_info:
		linked_info.queue_free()
	queue_free()

func _on_line_edit_text_submitted(_new_text: String) -> void:
	key = key_edit.text.to_int()
	key_edit.visible = false
	get_tree().get_first_node_in_group("edit_mode").is_editing_key = false
	
	find_and_link_info()  # Ищем информацию по новому ключу
