extends Node

signal points_changed
signal coins_changed

var points: Dictionary = {
	Command.TypeCommand.MOVE: 10,
	Command.TypeCommand.ATTACK: 30,
	Command.TypeCommand.HEAL: 3,
	Command.TypeCommand.DEFENSE: 3
}

var coins: int = 999

var remaining_move_points: int
var remaining_attack_points: int
var remaining_heal_points: int
var remaining_defense_points: int

# Новая система: каждый блок - отдельный экземпляр с уникальным ID
var purchased_blocks: Array[Dictionary] = []  # [{ id: String, type: int, text: String, used: bool }]
var next_block_id: int = 0

# Track purchased abilities, conditions, and loops for backwards compatibility
var purchased_abilities: Dictionary = {}
var purchased_conditions: Dictionary = {}
var purchased_loops: Dictionary = {}

func _ready() -> void:
	for item_type in ItemData.ItemType.values():
		var ability_name = ItemData.get_ability_name(item_type)
		if ability_name != "":
			purchased_abilities[ability_name] = false
		
		var condition_name = ItemData.get_condition_name(item_type)
		if condition_name != "":
			purchased_conditions[condition_name] = false
		
		var loop_name = ItemData.get_loop_name(item_type)
		if loop_name != "":
			purchased_loops[loop_name] = false
	
	reset_remaining_points()

func reset_remaining_points() -> void:
	remaining_move_points = points[Command.TypeCommand.MOVE]
	remaining_attack_points = points[Command.TypeCommand.ATTACK]
	remaining_heal_points = points[Command.TypeCommand.HEAL]
	remaining_defense_points = points[Command.TypeCommand.DEFENSE]
	points_changed.emit()

func get_remaining_points(command_type) -> int:
	match command_type:
		Command.TypeCommand.MOVE: return remaining_move_points
		Command.TypeCommand.ATTACK: return remaining_attack_points
		Command.TypeCommand.HEAL: return remaining_heal_points
		Command.TypeCommand.DEFENSE: return remaining_defense_points
		Command.TypeCommand.USE: return 999
		Command.TypeCommand.TURN: return 999
		_: return 0

# Генерируем уникальный ID для нового блока
func generate_block_id() -> String:
	var id = "block_" + str(next_block_id)
	next_block_id += 1
	return id

# Проверяем, можно ли использовать любой блок данного типа и текста
func can_use_block(block_type: int, block_text: String = "") -> bool:
	if block_text == "":
		# Если текст не указан, проверяем любой блок данного типа
		for block in purchased_blocks:
			if block.type == block_type and not block.used:
				return true
		return false
	
	# Ищем любой неиспользованный блок с данным типом и текстом
	for block in purchased_blocks:
		if block.type == block_type and block.text == block_text and not block.used:
			return true
	return false

# Найти первый доступный блок по типу и тексту
func find_available_block(block_type: int, block_text: String) -> Dictionary:
	for block in purchased_blocks:
		if block.type == block_type and block.text == block_text and not block.used:
			return block
	return {}

func use_points(command_type, value) -> void:
	if command_type == Command.TypeCommand.USE or command_type == Command.TypeCommand.TURN:
		return
		
	match command_type:
		Command.TypeCommand.MOVE: remaining_move_points -= value
		Command.TypeCommand.ATTACK: remaining_attack_points -= value
		Command.TypeCommand.HEAL: remaining_heal_points -= value
		Command.TypeCommand.DEFENSE: remaining_defense_points -= value
	
	remaining_move_points = max(0, remaining_move_points)
	remaining_attack_points = max(0, remaining_attack_points)
	remaining_heal_points = max(0, remaining_heal_points)
	remaining_defense_points = max(0, remaining_defense_points)
	points_changed.emit()

func release_points(command_type, value) -> void:
	if command_type == Command.TypeCommand.USE or command_type == Command.TypeCommand.TURN:
		return
		
	match command_type:
		Command.TypeCommand.MOVE: 
			remaining_move_points = min(points[Command.TypeCommand.MOVE], remaining_move_points + value)
		Command.TypeCommand.ATTACK: 
			remaining_attack_points = min(points[Command.TypeCommand.ATTACK], remaining_attack_points + value)
		Command.TypeCommand.HEAL: 
			remaining_heal_points = min(points[Command.TypeCommand.HEAL], remaining_heal_points + value)
		Command.TypeCommand.DEFENSE: 
			remaining_defense_points = min(points[Command.TypeCommand.DEFENSE], remaining_defense_points + value)
	
	points_changed.emit()

# Использовать блок по его уникальному ID
func use_block(block_id: String) -> bool:
	for block in purchased_blocks:
		if block.id == block_id and not block.used:
			block.used = true
			points_changed.emit()
			return true
	return false

# Вернуть использование блока по ID
func release_block(block_id: String) -> void:
	for block in purchased_blocks:
		if block.id == block_id and block.used:
			block.used = false
			points_changed.emit()
			return

# Получить количество доступных блоков данного типа и текста
func get_available_block_count(block_type: int, block_text: String) -> int:
	var count = 0
	for block in purchased_blocks:
		if block.type == block_type and block.text == block_text and not block.used:
			count += 1
	return count

# Сбросить использования всех блоков
func reset_all_blocks() -> void:
	for block in purchased_blocks:
		block.used = false
	points_changed.emit()

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit()
	
func get_coins() -> int:
	return coins
	
func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_changed.emit()
		return true
	return false

# Покупка блока - каждый блок создается как отдельный экземпляр
func purchase_block(block_type: int, block_text: String, count: int = 1) -> void:
	for i in range(count):
		var new_block = {
			"id": generate_block_id(),
			"type": block_type,
			"text": block_text,
			"used": false
		}
		purchased_blocks.append(new_block)
	
	# Обновляем старые словари для обратной совместимости
	if block_type == ItemData.BlockType.ABILITY:
		purchased_abilities[block_text] = true
	elif block_type == ItemData.BlockType.CONDITION:
		purchased_conditions[block_text] = true
	elif block_type == ItemData.BlockType.LOOP:
		purchased_loops[block_text] = true
	
	points_changed.emit()

func purchase_ability(ability_name: String, count: int = 1) -> void:
	purchase_block(ItemData.BlockType.ABILITY, ability_name, count)

func purchase_condition(condition_name: String, count: int = 1) -> void:
	purchase_block(ItemData.BlockType.CONDITION, condition_name, count)
		
func purchase_loop(loop_name: String, count: int = 1) -> void:
	purchase_block(ItemData.BlockType.LOOP, loop_name, count)

func is_ability_purchased(ability_name: String) -> bool:
	return ability_name in purchased_abilities and purchased_abilities[ability_name]

func is_condition_purchased(condition_name: String) -> bool:
	return condition_name in purchased_conditions and purchased_conditions[condition_name]

func is_loop_purchased(loop_name: String) -> bool:
	return loop_name in purchased_loops and purchased_loops[loop_name]

func purchase_item(item_type: int, count: int = 1) -> void:
	var ability_name = ItemData.get_ability_name(item_type)
	var condition_name = ItemData.get_condition_name(item_type)
	var loop_name = ItemData.get_loop_name(item_type)
	
	if ability_name != "":
		purchase_ability(ability_name, count)
	elif condition_name != "":
		purchase_condition(condition_name, count)
	elif loop_name != "":
		purchase_loop(loop_name, count)

# Получить все купленные блоки для меню (каждый блок отдельно)
func get_all_purchased_blocks() -> Array:
	var blocks = []
	for block in purchased_blocks:
		blocks.append({
			"id": block.id,
			"type": block.type,
			"text": block.text,
			"used": block.used
		})
	return blocks
