extends Node

# Структура для хранения информации о типе врага
class EnemyType:
	var script_path: String
	var weight: int
	var allowed_room_types: Array[Global.RoomType] = []
	var spawn_condition: Callable  # Новое поле для условия спавна
	
	func _init(p_script_path: String, p_weight: int = 50, p_allowed_room_types: Array[Global.RoomType] = [], p_spawn_condition: Callable = Callable()):
		script_path = p_script_path
		weight = p_weight
		allowed_room_types = p_allowed_room_types
		spawn_condition = p_spawn_condition

# Реестр всех специальных врагов
var special_enemies: Dictionary = {}

# Настройки шансов замены для разных типов комнат
var replacement_chances: Dictionary = {
	Global.RoomType.NORMAL: 15,
	Global.RoomType.ELITE: 30,
	Global.RoomType.CHALLENGE: 0,
	Global.RoomType.SHOP: 0
}

func _ready():
	register_enemies()

# Регистрация стандартных врагов
func register_enemies():
	register_enemy("teleporter", EnemyType.new(
		"res://scripts/objects/characters/enemies/TeleporterEnemy.gd",
		60,
		[]
	))
	
	register_enemy("berserker", EnemyType.new(
		"res://scripts/objects/characters/enemies/BerserkerEnemy.gd", 
		40,
		[]
	))
	
	register_enemy("skirmisher", EnemyType.new(
		'res://scripts/objects/characters/enemies/SkirmisherEnemy.gd',
		70,
		[]
	))
	
	# Хилер может появиться только если в комнате будет хотя бы 2 врага
	register_enemy("healer", EnemyType.new(
		"res://scripts/objects/characters/enemies/HealerEnemy.gd",
		40,
		[],
		healer_spawn_condition
	))

# Условие спавна для хилера
func healer_spawn_condition(room_context: Dictionary) -> bool:
	var total_enemies = room_context.get("total_enemies", 1)
	var current_spawn_index = room_context.get("current_spawn_index", 0)
	
	var can_spawn_by_count = total_enemies >= 2 and current_spawn_index > 0
	
	return can_spawn_by_count

# Регистрация нового типа врага
func register_enemy(id: String, enemy_type: EnemyType):
	special_enemies[id] = enemy_type

# Получение случайного скрипта специального врага для конкретного типа комнаты
func get_random_special_enemy_script(room_type: Global.RoomType, room_context: Dictionary = {}) -> String:
	var available_enemies = get_available_enemies_for_room(room_type, room_context)
	
	if available_enemies.is_empty():
		return ""
	
	var total_weight = 0
	for enemy_data in available_enemies.values():
		total_weight += enemy_data.weight
	
	if total_weight == 0:
		return ""
	
	var roll = randi() % total_weight
	var current_weight = 0
	
	for enemy_data in available_enemies.values():
		current_weight += enemy_data.weight
		if roll < current_weight:
			return enemy_data.script_path
	
	# Fallback - возвращаем первого доступного
	return available_enemies.values()[0].script_path

# Получение врагов, доступных для данного типа комнаты с учетом условий спавна
func get_available_enemies_for_room(room_type: Global.RoomType, room_context: Dictionary = {}) -> Dictionary:
	var available = {}
	
	for enemy_id in special_enemies.keys():
		var enemy_data = special_enemies[enemy_id]
		
		# Проверяем разрешенные типы комнат
		var room_type_allowed = false
		if enemy_data.allowed_room_types.is_empty():
			room_type_allowed = true
		elif room_type in enemy_data.allowed_room_types:
			room_type_allowed = true
		
		if not room_type_allowed:
			continue
		
		# Проверяем условие спавна
		if enemy_data.spawn_condition.is_valid():
			if not enemy_data.spawn_condition.call(room_context):
				continue
		
		available[enemy_id] = enemy_data
	
	return available

# Проверка, должен ли обычный враг быть заменен на специального
func should_replace_with_special_enemy(room_type: Global.RoomType, room_context: Dictionary = {}) -> bool:
	var chance = get_replacement_chance(room_type)
	var has_available_enemies = not get_available_enemies_for_room(room_type, room_context).is_empty()
	return randi() % 100 < chance and has_available_enemies

# Получение шанса замены для типа комнаты
func get_replacement_chance(room_type: Global.RoomType) -> int:
	return replacement_chances.get(room_type, 15)

# Установка шанса замены для типа комнаты
func set_replacement_chance(room_type: Global.RoomType, chance: int):
	replacement_chances[room_type] = clamp(chance, 0, 100)

# Получение всех настроек шансов замены
func get_all_replacement_chances() -> Dictionary:
	return replacement_chances.duplicate()

# Получение всех зарегистрированных врагов
func get_all_special_enemies() -> Dictionary:
	return special_enemies.duplicate()

# Проверка, зарегистрирован ли враг
func has_enemy(id: String) -> bool:
	return special_enemies.has(id)

# Удаление врага из реестра (для модов или динамического контента)
func unregister_enemy(id: String):
	special_enemies.erase(id)

# Получение информации о враге по ID
func get_enemy_info(id: String) -> EnemyType:
	return special_enemies.get(id, null)

# Проверка доступности врага в комнате с учетом условий
func is_enemy_available_in_room(enemy_id: String, room_type: Global.RoomType, room_context: Dictionary = {}) -> bool:
	if not has_enemy(enemy_id):
		return false
	
	var enemy_data = special_enemies[enemy_id]
	
	# Проверяем разрешенные типы комнат
	var room_type_allowed = false
	if enemy_data.allowed_room_types.is_empty():
		room_type_allowed = true
	elif room_type in enemy_data.allowed_room_types:
		room_type_allowed = true
	
	if not room_type_allowed:
		return false
	
	# Проверяем условие спавна
	if enemy_data.spawn_condition.is_valid():
		return enemy_data.spawn_condition.call(room_context)
	
	return true
