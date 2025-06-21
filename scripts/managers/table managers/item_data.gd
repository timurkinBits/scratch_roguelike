extends Node

# Константы для типов предметов (блоки)
enum BlockType {
	ABILITY_PLUS_ATTACK,
	ABILITY_PLUS_MOVE,
	ABILITY_PLUS_HEAL,
	ABILITY_PLUS_DEFENSE,
	LOOP_2_TIMES,
	LOOP_3_TIMES
}

# Константы для типов специальных команд (отдельные от обычных команд)
enum SpecialCommandType {
}

const BLOCKS = {
	BlockType.ABILITY_PLUS_ATTACK: {
		"icon": "res://sprites/attack.png",
		"color": Color.CRIMSON,
		"description": "Команды атаки получают способность: +1 очко",
		"cost": 3,
		"weight": 3.0,
		"block_text": "+1 атака",
		"slot_count": 1
	},
	BlockType.ABILITY_PLUS_MOVE: {
		"icon": "res://sprites/move.png",
		"color": Color.DODGER_BLUE,
		"description": "Команды перемещения получают способность: +1 очко",
		"cost": 2,
		"weight": 3.0,
		"block_text": "+1 движ.",
		"slot_count": 1
	},
	BlockType.ABILITY_PLUS_HEAL: {
		"icon": "res://sprites/heal.png",
		"color": Color.LIME_GREEN,
		"description": "Команды лечения получают способность: +1 очко",
		"cost": 5,
		"weight": 2.0,
		"block_text": "+1 леч.",
		"slot_count": 1
	},
	BlockType.ABILITY_PLUS_DEFENSE: {
		"icon": "res://sprites/defense.png",
		"color": Color.CADET_BLUE,
		"description": "Команды защиты получают способность: +1 очко",
		"cost": 3,
		"weight": 2.5,
		"block_text": "+1 защита",
		"slot_count": 1
	},
	BlockType.LOOP_2_TIMES: {
		"icon": "res://sprites/loop2.png",
		"color": Color.CORAL,
		"description": "После выполнения команд в блоке, выполнение начинается ещё раз",
		"cost": 6,
		"weight": 2.0,
		"block_text": "Повторить 2 раз",
		"slot_count": 2
	},
	BlockType.LOOP_3_TIMES: {
		"icon": "res://sprites/loop3.png",
		"color": Color.CHOCOLATE,
		"description": "После выполнения команд в блоке, выполнение начинается ещё 2 раза",
		"cost": 8,
		"weight": 1.0,
		"block_text": "Повторить 3 раз",
		"slot_count": 2
	}
}

# Данные специальных команд
const SPECIAL_COMMANDS = {
	
}

const SHOP_WEIGHTS = {
	"blocks": 5.0,           # Общий вес для блоков
	"special_commands": 10  # Общий вес для особых команд
}


const TEXT_TO_BLOCK_TYPE = {
	"Повторить 2 раз": BlockType.LOOP_2_TIMES,
	"Повторить 3 раз": BlockType.LOOP_3_TIMES,
	"+1 атака": BlockType.ABILITY_PLUS_ATTACK,
	"+1 движ.": BlockType.ABILITY_PLUS_MOVE,
	"+1 леч.": BlockType.ABILITY_PLUS_HEAL,
	"+1 защита": BlockType.ABILITY_PLUS_DEFENSE
}

# Получить стоимость предмета
func get_item_cost(item_type: int) -> int:
	if item_type in BLOCKS:
		return BLOCKS[item_type]["cost"]
	return 0

# Получить вес предмета для вероятности выпадения
func get_item_weight(item_type: int) -> float:
	if item_type in BLOCKS:
		return BLOCKS[item_type]["weight"]
	return 0.0

# Получить описание предмета
func get_item_description(item_type: int) -> String:
	if item_type in BLOCKS:
		return BLOCKS[item_type]["description"]
	return ""

# Получить иконку предмета
func get_item_icon(item_type: int) -> String:
	if item_type in BLOCKS:
		return BLOCKS[item_type]["icon"]
	return ""

# Получить цвет предмета
func get_item_color(item_type: int) -> Color:
	if item_type in BLOCKS:
		return BLOCKS[item_type]["color"]
	return Color.WHITE

# Получить текст блока для предмета
func get_block_text(item_type: int) -> String:
	if item_type in BLOCKS and "block_text" in BLOCKS[item_type]:
		return BLOCKS[item_type]["block_text"]
	return ""

# Получить количество слотов для блока по его тексту
func get_slot_count(text: String) -> int:
	if text == "начало хода":
		return 10
		
	if text in TEXT_TO_BLOCK_TYPE:
		var item_type = TEXT_TO_BLOCK_TYPE[text]
		if item_type in BLOCKS:
			return BLOCKS[item_type]['slot_count']
	return 0
			
func get_slot_count_by_item_type(item_type: int) -> int:
	if item_type in BLOCKS and "slot_count" in BLOCKS[item_type]:
		return BLOCKS[item_type]["slot_count"]
	return 1  # По умолчанию 1 слот

# === МЕТОДЫ ДЛЯ СПЕЦИАЛЬНЫХ КОМАНД ===

# Получить данные специальной команды
func get_special_command_data(special_type: int) -> Dictionary:
	if special_type in SPECIAL_COMMANDS:
		return SPECIAL_COMMANDS[special_type]
	return {}

# Получить название специальной команды
func get_special_command_name(special_type: int) -> String:
	if special_type in SPECIAL_COMMANDS:
		return SPECIAL_COMMANDS[special_type]["name"]
	return ""

# Получить иконку специальной команды
func get_special_command_icon(special_type: int) -> String:
	if special_type in SPECIAL_COMMANDS:
		return SPECIAL_COMMANDS[special_type]["icon"]
	return ""

# Получить цвет специальной команды
func get_special_command_color(special_type: int) -> Color:
	if special_type in SPECIAL_COMMANDS:
		return SPECIAL_COMMANDS[special_type]["color"]
	return Color.WHITE

# Получить описание специальной команды
func get_special_command_description(special_type: int) -> String:
	if special_type in SPECIAL_COMMANDS:
		return SPECIAL_COMMANDS[special_type]["description"]
	return ""

# Получить стоимость специальной команды
func get_special_command_cost(special_type: int) -> int:
	if special_type in SPECIAL_COMMANDS:
		return SPECIAL_COMMANDS[special_type]["cost"]
	return 0

# Получить вес специальной команды для вероятности выпадения
func get_special_command_weight(special_type: int) -> float:
	if special_type in SPECIAL_COMMANDS:
		return SPECIAL_COMMANDS[special_type]["weight"]
	return 0.0

# Проверить, имеет ли специальная команда изменяемое значение
func special_command_has_value(special_type: int) -> bool:
	if special_type in SPECIAL_COMMANDS:
		return SPECIAL_COMMANDS[special_type]["has_value"]
	return false

# Получить скорректированный вес блока для магазина
func get_block_shop_weight(item_type: int) -> float:
	var base_weight = get_item_weight(item_type)
	return base_weight * SHOP_WEIGHTS.blocks

# Вес особой команды
func get_special_command_shop_weight(special_type: int) -> float:
	return get_special_command_weight(special_type) * SHOP_WEIGHTS.special_commands
