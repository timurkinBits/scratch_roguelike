extends Node

# Константы для типов предметов
enum ItemType {
	# Убираем абстрактные блоки из генерации, но оставляем для совместимости
	LOOP_BLOCK,
	CONDITION_BLOCK,
	ABILITY_BLOCK,
	# Конкретные предметы
	ABILITY_PLUS_ATTACK,
	ABILITY_PLUS_MOVE,
	ABILITY_PLUS_HEAL,
	ABILITY_PLUS_DEFENSE,
	LOOP_2_TIMES,
	LOOP_3_TIMES,
	CONDITION_BELOW_HALF_HP
}

# Константы для типов блоков
enum BlockType {
	NONE,
	CONDITION,
	LOOP,
	ABILITY
}

# Данные предметов
const ITEMS = {
	# Абстрактные блоки (не генерируются в магазине, но могут быть наградами за испытания)
	ItemType.LOOP_BLOCK: {
		"icon": "res://sprites/loop.png",
		"description": "Блок цикл",
		"cost": 8,
		"weight": 0.0,  # Вес 0 = не генерируется в обычном магазине
		"block_type": BlockType.LOOP,
		"slot_count": 1
	},
	ItemType.CONDITION_BLOCK: {
		"icon": "res://sprites/condition.png",
		"description": "Блок условие",
		"cost": 8,
		"weight": 0.0,  # Вес 0 = не генерируется в обычном магазине
		"block_type": BlockType.CONDITION,
		"slot_count": 1
	},
	ItemType.ABILITY_BLOCK: {
		"icon": "res://sprites/ability.png",
		"description": "Блок навык",
		"cost": 8,
		"weight": 0.0,  # Вес 0 = не генерируется в обычном магазине
		"block_type": BlockType.ABILITY,
		"slot_count": 1
	},
	# Конкретные предметы
	ItemType.ABILITY_PLUS_ATTACK: {
		"icon": "res://sprites/attack.png",
		"description": "Навык +1 атака",
		"cost": 3,
		"weight": 3.0,
		"block_type": BlockType.ABILITY,
		"ability_name": "+1 атака",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_MOVE: {
		"icon": "res://sprites/move.png",
		"description": "Навык +1 перемещение",
		"cost": 2,
		"weight": 3.0,
		"block_type": BlockType.ABILITY,
		"ability_name": "+1 движ.",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_HEAL: {
		"icon": "res://sprites/heal.png",
		"description": "Навык +1 лечение",
		"cost": 5,
		"weight": 2.0,
		"block_type": BlockType.ABILITY,
		"ability_name": "+1 леч.",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_DEFENSE: {
		"icon": "res://sprites/defense.png",
		"description": "Навык +1 защита",
		"cost": 3,
		"weight": 2.5,
		"block_type": BlockType.ABILITY,
		"ability_name": "+1 защита",
		"slot_count": 1
	},
	ItemType.LOOP_2_TIMES: {
		"icon": "res://sprites/loop2.png",
		"description": "Цикл на 2 повторения",
		"cost": 6,
		"weight": 2.0,
		"block_type": BlockType.LOOP,
		"loop_name": "Повторить 2 раз",
		"slot_count": 2
	},
	ItemType.LOOP_3_TIMES: {
		"icon": "res://sprites/loop3.png",
		"description": "Цикл на 3 повторения",
		"cost": 8,
		"weight": 1.0,
		"block_type": BlockType.LOOP,
		"loop_name": "Повторить 3 раз",
		"slot_count": 2
	},
	ItemType.CONDITION_BELOW_HALF_HP: {
		"icon": "res://sprites/below_half_hp.png",
		"description": "Условие здоровье < 50%",
		"cost": 3,
		"weight": 3.0,
		"block_type": BlockType.CONDITION,
		"condition_name": "здоровье < 50%",
		"slot_count": 3
	}
}

const TEXT_TO_ITEM_TYPE = {
	"Повторить 2 раз": ItemType.LOOP_2_TIMES,
	"Повторить 3 раз": ItemType.LOOP_3_TIMES,
	"+1 атака": ItemType.ABILITY_PLUS_ATTACK,
	"+1 движ.": ItemType.ABILITY_PLUS_MOVE,
	"+1 леч.": ItemType.ABILITY_PLUS_HEAL,
	"+1 защита": ItemType.ABILITY_PLUS_DEFENSE,
	"здоровье < 50%": ItemType.CONDITION_BELOW_HALF_HP
}

# Цвета и префиксы для блоков
const BLOCK_CONFIGS = {
	BlockType.CONDITION: {
		"prefix": "Если ",
		"color": Color.YELLOW,
		"icon": "res://sprites/condition.png"
	},
	BlockType.LOOP: {
		"prefix": "Повторить ",
		"color": Color.CHOCOLATE,
		"icon": "res://sprites/loop.png"
	},
	BlockType.ABILITY: {
		"prefix": "Улучшить ",
		"color": Color.TURQUOISE,
		"icon": "res://sprites/ability.png"
	},
	BlockType.NONE: {
		"prefix": "none ",
		"color": Color.WHITE,
		"icon": ""
	}
}

# Награды за испытания (могут включать абстрактные блоки)
const CHALLENGE_REWARDS = [
	ItemType.ABILITY_PLUS_ATTACK,
	ItemType.ABILITY_PLUS_MOVE,
	ItemType.ABILITY_PLUS_HEAL,
	ItemType.ABILITY_PLUS_DEFENSE,
	ItemType.LOOP_2_TIMES,
	ItemType.LOOP_3_TIMES,
	ItemType.CONDITION_BELOW_HALF_HP,
	# Абстрактные блоки как особые награды
	ItemType.LOOP_BLOCK,
	ItemType.CONDITION_BLOCK,
	ItemType.ABILITY_BLOCK
]

# Получить список наград за испытания
func get_challenge_rewards() -> Array:
	return CHALLENGE_REWARDS.duplicate()

# Получить информацию о предмете
func get_item_info(item_type: int) -> Dictionary:
	if item_type in ITEMS:
		return ITEMS[item_type]
	return {}

# Получить стоимость предмета
func get_item_cost(item_type: int) -> int:
	if item_type in ITEMS:
		return ITEMS[item_type]["cost"]
	return 0

# Получить вес предмета для вероятности выпадения
func get_item_weight(item_type: int) -> float:
	if item_type in ITEMS:
		return ITEMS[item_type]["weight"]
	return 0.0

# Получить описание предмета
func get_item_description(item_type: int) -> String:
	if item_type in ITEMS:
		return ITEMS[item_type]["description"]
	return ""

# Получить иконку предмета
func get_item_icon(item_type: int) -> String:
	if item_type in ITEMS:
		return ITEMS[item_type]["icon"]
	return ""

# Получить тип блока для предмета-блока
func get_block_type(item_type: int) -> int:
	if item_type in ITEMS and "block_type" in ITEMS[item_type]:
		return ITEMS[item_type]["block_type"]
	return -1

# Получить название способности для предмета-способности
func get_ability_name(item_type: int) -> String:
	if item_type in ITEMS and "ability_name" in ITEMS[item_type]:
		return ITEMS[item_type]["ability_name"]
	return ""

# Получить название условия для предмета-условия
func get_condition_name(item_type: int) -> String:
	if item_type in ITEMS and "condition_name" in ITEMS[item_type]:
		return ITEMS[item_type]["condition_name"]
	return ""

# Получить название цикла для предмета-цикла
func get_loop_name(item_type: int) -> String:
	if item_type in ITEMS and "loop_name" in ITEMS[item_type]:
		return ITEMS[item_type]["loop_name"]
	return ""

# Получить количество слотов для блока по его типу и тексту
func get_slot_count(block_type: int, text: String) -> int:
	if text == "начало хода":
		return 10
		
	if text in TEXT_TO_ITEM_TYPE:
		var item_type = TEXT_TO_ITEM_TYPE[text]
		if item_type in ITEMS:
			return ITEMS[item_type]['slot_count']
	
	# Если текст не найден, возвращаем значение по умолчанию для типа блока
	match block_type:
		BlockType.CONDITION:
			return ITEMS[ItemType.CONDITION_BLOCK]['slot_count']
		BlockType.LOOP:
			return ITEMS[ItemType.LOOP_BLOCK]['slot_count']
		BlockType.ABILITY:
			return ITEMS[ItemType.ABILITY_BLOCK]['slot_count']
		_:
			return 2

# Получить конфигурацию блока
func get_block_config(block_type: int) -> Dictionary:
	if block_type in BLOCK_CONFIGS:
		return BLOCK_CONFIGS[block_type]
	return {}

# Получить название предмета по типу элемента (для поиска соответствия)
func get_ability_name_for_item_type(item_type: int) -> String:
	match item_type:
		ItemType.ABILITY_PLUS_ATTACK:
			return "+1 атака"
		ItemType.ABILITY_PLUS_MOVE:
			return "+1 движ."
		ItemType.ABILITY_PLUS_HEAL:
			return "+1 леч."
		ItemType.ABILITY_PLUS_DEFENSE:
			return "+1 защита"
		ItemType.CONDITION_BELOW_HALF_HP:
			return "здоровье < 50%"
		ItemType.LOOP_2_TIMES:
			return "Повторить 2 раз"
		ItemType.LOOP_3_TIMES:
			return "Повторить 3 раз"
		# Для абстрактных блоков возвращаем общие названия
		ItemType.LOOP_BLOCK:
			return "цикл"
		ItemType.CONDITION_BLOCK:
			return "условие"
		ItemType.ABILITY_BLOCK:
			return "навык"
		_:
			return ""
