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
	var item_name = ItemData.get_item_description(type)
	show_info_message('Добавлено: ' + item_name, 0.8)
	
	# Remove the item and its linked info
	queue_free()

# Helper function to display messages in info panel
func show_info_message(message: String, duration: float) -> void:
	info.text = message
	await get_tree().create_timer(duration).timeout
	info.text = ''

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

func _on_area_2d_mouse_entered() -> void:
	info.get_node("ColorRect").visible = true
	info.text = ItemData.get_item_description(type) + \
	"\nЦена: " + str(ItemData.get_item_cost(type))
	if type not in [ItemData.ItemType.LOOP_BLOCK, ItemData.ItemType.CONDITION_BLOCK, ItemData.ItemType.ABILITY_BLOCK]:
		info.text += "\nСлотов: " + str(ItemData.get_slot_count(ItemData.get_block_type(type), 
	ItemData.get_ability_name_for_item_type(type)))


func _on_area_2d_mouse_exited() -> void:
	info.get_node("ColorRect").visible = false
	info.text = ""
