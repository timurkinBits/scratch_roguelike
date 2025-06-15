extends Node

# Константы для типов предметов (теперь только блоки без типизации)
enum ItemType {
	ABILITY_PLUS_ATTACK,
	ABILITY_PLUS_MOVE,
	ABILITY_PLUS_HEAL,
	ABILITY_PLUS_DEFENSE,
	LOOP_2_TIMES,
	LOOP_3_TIMES
}

# Данные предметов (все теперь просто блоки)
const ITEMS = {
	ItemType.ABILITY_PLUS_ATTACK: {
		"icon": "res://sprites/attack.png",
		"description": "Навык +1 атака",
		"cost": 3,
		"weight": 3.0,
		"block_text": "+1 атака",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_MOVE: {
		"icon": "res://sprites/move.png",
		"description": "Навык +1 перемещение",
		"cost": 2,
		"weight": 3.0,
		"block_text": "+1 движ.",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_HEAL: {
		"icon": "res://sprites/heal.png",
		"description": "Навык +1 лечение",
		"cost": 5,
		"weight": 2.0,
		"block_text": "+1 леч.",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_DEFENSE: {
		"icon": "res://sprites/defense.png",
		"description": "Навык +1 защита",
		"cost": 3,
		"weight": 2.5,
		"block_text": "+1 защита",
		"slot_count": 1
	},
	ItemType.LOOP_2_TIMES: {
		"icon": "res://sprites/loop2.png",
		"description": "Цикл на 2 повторения",
		"cost": 6,
		"weight": 2.0,
		"block_text": "Повторить 2 раз",
		"slot_count": 2
	},
	ItemType.LOOP_3_TIMES: {
		"icon": "res://sprites/loop3.png",
		"description": "Цикл на 3 повторения",
		"cost": 8,
		"weight": 1.0,
		"block_text": "Повторить 3 раз",
		"slot_count": 2
	}
}

const TEXT_TO_ITEM_TYPE = {
	"Повторить 2 раз": ItemType.LOOP_2_TIMES,
	"Повторить 3 раз": ItemType.LOOP_3_TIMES,
	"+1 атака": ItemType.ABILITY_PLUS_ATTACK,
	"+1 движ.": ItemType.ABILITY_PLUS_MOVE,
	"+1 леч.": ItemType.ABILITY_PLUS_HEAL,
	"+1 защита": ItemType.ABILITY_PLUS_DEFENSE
}

# Награды за испытания
const CHALLENGE_REWARDS = [
	ItemType.ABILITY_PLUS_ATTACK,
	ItemType.ABILITY_PLUS_MOVE,
	ItemType.ABILITY_PLUS_HEAL,
	ItemType.ABILITY_PLUS_DEFENSE,
	ItemType.LOOP_2_TIMES,
	ItemType.LOOP_3_TIMES
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

# Получить текст блока для предмета
func get_block_text(item_type: int) -> String:
	if item_type in ITEMS and "block_text" in ITEMS[item_type]:
		return ITEMS[item_type]["block_text"]
	return ""

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
	return 0

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
		ItemType.LOOP_2_TIMES:
			return "Повторить 2 раз"
		ItemType.LOOP_3_TIMES:
			return "Повторить 3 раз" 
		_:
			return ""
			
func get_slot_count_by_item_type(item_type: int) -> int:
	if item_type in ITEMS and "slot_count" in ITEMS[item_type]:
		return ITEMS[item_type]["slot_count"]
	return 1  # По умолчанию 1 слот
