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

# Убираем старую систему лимитов по типам
# Теперь каждый блок - отдельная единица с собственным количеством использований
var purchased_blocks: Dictionary = {}  # "block_key": { uses: int, max_uses: int }

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

# Создаем уникальный ключ для блока
func get_block_key(block_type: int, block_text: String) -> String:
	return str(block_type) + "_" + block_text

# Проверяем, можно ли использовать конкретный блок
func can_use_block(block_type: int, block_text: String = "") -> bool:
	# Если передан только тип (для обратной совместимости), проверяем любой блок этого типа
	if block_text == "":
		for key in purchased_blocks:
			var parts = key.split("_", false, 1)
			if parts.size() >= 2 and int(parts[0]) == block_type:
				if purchased_blocks[key].uses > 0:
					return true
		return false
	
	var block_key = get_block_key(block_type, block_text)
	if block_key in purchased_blocks:
		return purchased_blocks[block_key].uses > 0
	return false

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

# Использовать конкретный блок
func use_block(block_type: int, block_text: String) -> bool:
	var block_key = get_block_key(block_type, block_text)
	if block_key in purchased_blocks and purchased_blocks[block_key].uses > 0:
		purchased_blocks[block_key].uses -= 1
		points_changed.emit()
		return true
	return false

# Вернуть использование конкретного блока
func release_block(block_type: int, block_text: String) -> void:
	var block_key = get_block_key(block_type, block_text)
	if block_key in purchased_blocks:
		purchased_blocks[block_key].uses = min(purchased_blocks[block_key].max_uses, purchased_blocks[block_key].uses + 1)
		points_changed.emit()

# Получить количество использований конкретного блока
func get_block_uses(block_type: int, block_text: String) -> int:
	var block_key = get_block_key(block_type, block_text)
	if block_key in purchased_blocks:
		return purchased_blocks[block_key].uses
	return 0

# Сбросить использования всех блоков
func reset_all_blocks() -> void:
	for key in purchased_blocks:
		purchased_blocks[key].uses = purchased_blocks[key].max_uses
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

# Покупка блока - каждый блок независим
func purchase_block(block_type: int, block_text: String, uses: int = 1) -> void:
	var block_key = get_block_key(block_type, block_text)
	
	if block_key in purchased_blocks:
		# Если блок уже есть, увеличиваем его максимальное использование
		purchased_blocks[block_key].max_uses += uses
		purchased_blocks[block_key].uses += uses
	else:
		# Создаем новый блок
		purchased_blocks[block_key] = {
			"uses": uses,
			"max_uses": uses
		}
	
	# Обновляем старые словари для обратной совместимости
	if block_type == ItemData.BlockType.ABILITY:
		purchased_abilities[block_text] = true
	elif block_type == ItemData.BlockType.CONDITION:
		purchased_conditions[block_text] = true
	elif block_type == ItemData.BlockType.LOOP:
		purchased_loops[block_text] = true
	
	points_changed.emit()

func purchase_ability(ability_name: String, uses: int = 1) -> void:
	purchase_block(ItemData.BlockType.ABILITY, ability_name, uses)

func purchase_condition(condition_name: String, uses: int = 1) -> void:
	purchase_block(ItemData.BlockType.CONDITION, condition_name, uses)
		
func purchase_loop(loop_name: String, uses: int = 1) -> void:
	purchase_block(ItemData.BlockType.LOOP, loop_name, uses)

func is_ability_purchased(ability_name: String) -> bool:
	return ability_name in purchased_abilities and purchased_abilities[ability_name]

func is_condition_purchased(condition_name: String) -> bool:
	return condition_name in purchased_conditions and purchased_conditions[condition_name]

func is_loop_purchased(loop_name: String) -> bool:
	return loop_name in purchased_loops and purchased_loops[loop_name]

func purchase_item(item_type: int, uses: int = 1) -> void:
	var ability_name = ItemData.get_ability_name(item_type)
	var condition_name = ItemData.get_condition_name(item_type)
	var loop_name = ItemData.get_loop_name(item_type)
	
	if ability_name != "":
		purchase_ability(ability_name, uses)
	elif condition_name != "":
		purchase_condition(condition_name, uses)
	elif loop_name != "":
		purchase_loop(loop_name, uses)

# Получить все купленные блоки для меню
func get_all_purchased_blocks() -> Array:
	var blocks = []
	for key in purchased_blocks:
		var parts = key.split("_", false, 1)
		if parts.size() >= 2:
			var block_type = int(parts[0])
			var block_text = parts[1]
			blocks.append({
				"type": block_type,
				"text": block_text,
				"uses": purchased_blocks[key].uses,
				"max_uses": purchased_blocks[key].max_uses
			})
	return blocks
