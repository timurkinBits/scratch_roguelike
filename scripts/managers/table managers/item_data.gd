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

const ITEMS = {
	ItemType.ABILITY_PLUS_ATTACK: {
		"icon": "res://sprites/attack.png",
		"color": Color.CRIMSON,
		"description": "Команды атаки получают способность: +1 очко",
		"cost": 3,
		"weight": 3.0,
		"block_text": "+1 атака",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_MOVE: {
		"icon": "res://sprites/move.png",
		"color": Color.DODGER_BLUE,
		"description": "Команды перемещения получают способность: +1 очко",
		"cost": 2,
		"weight": 3.0,
		"block_text": "+1 движ.",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_HEAL: {
		"icon": "res://sprites/heal.png",
		"color": Color.LIME_GREEN,
		"description": "Команды лечения получают способность: +1 очко",
		"cost": 5,
		"weight": 2.0,
		"block_text": "+1 леч.",
		"slot_count": 1
	},
	ItemType.ABILITY_PLUS_DEFENSE: {
		"icon": "res://sprites/defense.png",
		"color": Color.CADET_BLUE,
		"description": "Команды защиты получают способность: +1 очко",
		"cost": 3,
		"weight": 2.5,
		"block_text": "+1 защита",
		"slot_count": 1
	},
	ItemType.LOOP_2_TIMES: {
		"icon": "res://sprites/loop2.png",
		"color": Color.CORAL,
		"description": "После выполнения команд в блоке, выполнение начинается ещё раз",
		"cost": 6,
		"weight": 2.0,
		"block_text": "Повторить 2 раз",
		"slot_count": 2
	},
	ItemType.LOOP_3_TIMES: {
		"icon": "res://sprites/loop3.png",
		"color": Color.CHOCOLATE,
		"description": "После выполнения команд в блоке, выполнение начинается ещё 2 раза",
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

# Получить цвет предмета
func get_item_color(item_type: int) -> Color:
	if item_type in ITEMS:
		return ITEMS[item_type]["color"]
	return Color.WHITE

# Получить текст блока для предмета
func get_block_text(item_type: int) -> String:
	if item_type in ITEMS and "block_text" in ITEMS[item_type]:
		return ITEMS[item_type]["block_text"]
	return ""

# Получить количество слотов для блока по его типу и тексту
func get_slot_count(text: String) -> int:
	if text == "начало хода":
		return 10
		
	if text in TEXT_TO_ITEM_TYPE:
		var item_type = TEXT_TO_ITEM_TYPE[text]
		if item_type in ITEMS:
			return ITEMS[item_type]['slot_count']
	return 0
			
func get_slot_count_by_item_type(item_type: int) -> int:
	if item_type in ITEMS and "slot_count" in ITEMS[item_type]:
		return ITEMS[item_type]["slot_count"]
	return 1  # По умолчанию 1 слот
