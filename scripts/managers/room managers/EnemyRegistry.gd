extends Node

# Структура для хранения информации о типе врага
class EnemyType:
	var script_path: String
	var weight: int
	var allowed_room_types: Array[Global.RoomType] = []
	
	func _init(p_script_path: String, p_weight: int = 50, p_allowed_room_types: Array[Global.RoomType] = []):
		script_path = p_script_path
		weight = p_weight
		allowed_room_types = p_allowed_room_types

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
	
	register_enemy("healer", EnemyType.new(
		"res://scripts/objects/characters/enemies/HealerEnemy.gd",
		40,
		[]
	))

# Регистрация нового типа врага
func register_enemy(id: String, enemy_type: EnemyType):
	special_enemies[id] = enemy_type

# Получение случайного скрипта специального врага для конкретного типа комнаты
func get_random_special_enemy_script(room_type: Global.RoomType) -> String:
	var available_enemies = get_available_enemies_for_room(room_type)
	
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

# Получение врагов, доступных для данного типа комнаты
func get_available_enemies_for_room(room_type: Global.RoomType) -> Dictionary:
	var available = {}
	
	for enemy_id in special_enemies.keys():
		var enemy_data = special_enemies[enemy_id]
		
		# Если массив разрешенных комнат пустой - враг доступен везде
		if enemy_data.allowed_room_types.is_empty():
			available[enemy_id] = enemy_data
		# Иначе проверяем, есть ли текущий тип комнаты в разрешенных
		elif room_type in enemy_data.allowed_room_types:
			available[enemy_id] = enemy_data
	
	return available

# Проверка, должен ли обычный враг быть заменен на специального
func should_replace_with_special_enemy(room_type: Global.RoomType) -> bool:
	var chance = get_replacement_chance(room_type)
	return randi() % 100 < chance

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

# Проверка доступности врага в комнате
func is_enemy_available_in_room(enemy_id: String, room_type: Global.RoomType) -> bool:
	if not has_enemy(enemy_id):
		return false
	
	var enemy_data = special_enemies[enemy_id]
	
	# Если нет ограничений - доступен везде
	if enemy_data.allowed_room_types.is_empty():
		return true
	
	# Проверяем наличие типа комнаты в разрешенных
	return room_type in enemy_data.allowed_room_types
