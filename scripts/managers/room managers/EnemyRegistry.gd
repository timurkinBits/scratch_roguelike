extends Node

# Структура для хранения информации о типе врага
class EnemyType:
	var script_path: String
	var weight: int
	var allowed_room_types: Array[Global.RoomType] = []
	var spawn_condition: Callable
	var min_difficulty_level: int = 1  # Минимальный уровень сложности для появления
	var is_advanced: bool = false  # Является ли продвинутым врагом
	var advanced_weight_bonus: int = 0  # Дополнительный вес для продвинутых врагов
	
	func _init(p_script_path: String, p_weight: int = 50, p_allowed_room_types: Array[Global.RoomType] = [], p_spawn_condition: Callable = Callable(), p_min_difficulty_level: int = 1, p_is_advanced: bool = false, p_advanced_weight_bonus: int = 0):
		script_path = p_script_path
		weight = p_weight
		allowed_room_types = p_allowed_room_types
		spawn_condition = p_spawn_condition
		min_difficulty_level = p_min_difficulty_level
		is_advanced = p_is_advanced
		advanced_weight_bonus = p_advanced_weight_bonus

# Реестр всех специальных врагов
var special_enemies: Dictionary = {}

# Настройки шансов замены для разных типов комнат (базовые значения)
var base_replacement_chances: Dictionary = {
	Global.RoomType.NORMAL: 15,
	Global.RoomType.ELITE: 30,
	Global.RoomType.CHALLENGE: 0,
	Global.RoomType.SHOP: 0
}

func _ready():
	register_enemies()

# Регистрация стандартных врагов с учетом сложности
func register_enemies():
	# Базовые специальные враги (доступны с начала)
	register_enemy("teleporter", EnemyType.new(
		"res://scripts/objects/characters/enemies/TeleporterEnemy.gd",
		60,
		[],
		Callable(),
		1,  # Доступен с 1 уровня
		false
	))
	
	register_enemy("berserker", EnemyType.new(
		"res://scripts/objects/characters/enemies/BerserkerEnemy.gd", 
		40,
		[],
		Callable(),
		1,  # Доступен с 1 уровня
		false
	))
	
	register_enemy("skirmisher", EnemyType.new(
		'res://scripts/objects/characters/enemies/SkirmisherEnemy.gd',
		70,
		[],
		Callable(),
		2,  # Доступен с 2 уровня
		false
	))
	
	# Хилер - базовый, но требует условие (только 1 на комнату)
	register_enemy("healer", EnemyType.new(
		"res://scripts/objects/characters/enemies/HealerEnemy.gd",
		40,
		[],
		healer_spawn_condition,
		3,  # Доступен с 3 уровня
		false
	))
	
	## Продвинутые враги (появляются на высоких уровнях сложности)
	#register_enemy("elite_teleporter", EnemyType.new(
		#"res://scripts/objects/characters/enemies/EliteTeleporterEnemy.gd",
		#30,
		#[],
		#Callable(),
		#5,  # Доступен с 5 уровня
		#true,  # Продвинутый враг
		#20  # Получает +20 к весу при высокой сложности
	#))
	
	#register_enemy("necromancer", EnemyType.new(
		#"res://scripts/objects/characters/enemies/NecromancerEnemy.gd",
		#25,
		#[],
		#Callable(),
		#7,  # Доступен с 7 уровня
		#true,  # Продвинутый враг
		#25  # Получает +25 к весу при высокой сложности
	#))
	
	#register_enemy("shadow_assassin", EnemyType.new(
		#"res://scripts/objects/characters/enemies/ShadowAssassinEnemy.gd",
		#35,
		#[],
		#Callable(),
		#6,  # Доступен с 6 уровня
		#true,  # Продвинутый враг
		#15  # Получает +15 к весу при высокой сложности
	#))

# Условие спавна для хилера - теперь с ограничением 1 на комнату
func healer_spawn_condition(room_context: Dictionary) -> bool:
	var total_enemies = room_context.get("total_enemies", 1)
	var current_spawn_index = room_context.get("current_spawn_index", 0)
	
	# Проверяем количество врагов и индекс спавна
	var can_spawn_by_count = total_enemies >= 2 and current_spawn_index > 0
	
	# Проверяем, не был ли уже заспавнен хилер в этой комнате
	var spawned_healers = room_context.get("spawned_healers", 0)
	var healer_not_spawned_yet = spawned_healers == 0
	
	return can_spawn_by_count and healer_not_spawned_yet

# Регистрация нового типа врага
func register_enemy(id: String, enemy_type: EnemyType):
	special_enemies[id] = enemy_type

# Получение случайного скрипта специального врага для конкретного типа комнаты с учетом сложности
func get_random_special_enemy_script(room_type: Global.RoomType, room_context: Dictionary = {}) -> String:
	var available_enemies = get_available_enemies_for_room(room_type, room_context)
	
	if available_enemies.is_empty():
		return ""
	
	var total_weight = calculate_total_weight(available_enemies)
	
	if total_weight == 0:
		return ""
	
	var roll = randi() % total_weight
	var current_weight = 0
	
	for enemy_id in available_enemies.keys():
		var enemy_data = available_enemies[enemy_id]
		var effective_weight = get_effective_weight(enemy_data)
		current_weight += effective_weight
		if roll < current_weight:
			# Обновляем счетчик хилеров, если выбран хилер
			if enemy_id == "healer":
				_update_healer_count_in_context(room_context)
			return enemy_data.script_path
	
	# Fallback - возвращаем первого доступного
	var first_enemy_id = available_enemies.keys()[0]
	if first_enemy_id == "healer":
		_update_healer_count_in_context(room_context)
	return available_enemies[first_enemy_id].script_path

# Обновление счетчика хилеров в контексте комнаты
func _update_healer_count_in_context(room_context: Dictionary):
	var current_count = room_context.get("spawned_healers", 0)
	room_context["spawned_healers"] = current_count + 1

# Расчет эффективного веса врага с учетом сложности
func get_effective_weight(enemy_data: EnemyType) -> int:
	var base_weight = enemy_data.weight
	
	# Для продвинутых врагов добавляем бонус веса в зависимости от сложности
	if enemy_data.is_advanced:
		var difficulty_level = DifficultyManager.get_current_difficulty()
		var difficulty_factor = max(0, difficulty_level - enemy_data.min_difficulty_level)
		base_weight += enemy_data.advanced_weight_bonus * (difficulty_factor / 3)  # Каждые 3 уровня увеличиваем бонус
	
	return base_weight

# Расчет общего веса всех доступных врагов
func calculate_total_weight(available_enemies: Dictionary) -> int:
	var total_weight = 0
	for enemy_data in available_enemies.values():
		total_weight += get_effective_weight(enemy_data)
	return total_weight

# Получение врагов, доступных для данного типа комнаты с учетом условий спавна и сложности
func get_available_enemies_for_room(room_type: Global.RoomType, room_context: Dictionary = {}) -> Dictionary:
	var available = {}
	var current_difficulty = DifficultyManager.get_current_difficulty()
	
	for enemy_id in special_enemies.keys():
		var enemy_data = special_enemies[enemy_id]
		
		# Проверяем минимальный уровень сложности
		if current_difficulty < enemy_data.min_difficulty_level:
			continue
		
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
		
		# Для продвинутых врагов дополнительная проверка шанса
		if enemy_data.is_advanced:
			if not DifficultyManager.should_spawn_advanced_enemy(10):  # Базовый шанс 10%
				continue
		
		available[enemy_id] = enemy_data
	
	return available

# Проверка, должен ли обычный враг быть заменен на специального с учетом сложности
func should_replace_with_special_enemy(room_type: Global.RoomType, room_context: Dictionary = {}) -> bool:
	var base_chance = get_base_replacement_chance(room_type)
	var scaled_chance = DifficultyManager.get_scaled_special_enemy_chance(base_chance)
	var has_available_enemies = not get_available_enemies_for_room(room_type, room_context).is_empty()
	
	return randi() % 100 < scaled_chance and has_available_enemies

# Получение базового шанса замены для типа комнаты
func get_base_replacement_chance(room_type: Global.RoomType) -> int:
	return base_replacement_chances.get(room_type, 15)

# Установка базового шанса замены для типа комнаты
func set_replacement_chance(room_type: Global.RoomType, chance: int):
	base_replacement_chances[room_type] = clamp(chance, 0, 100)

# Получение текущего шанса замены с учетом сложности
func get_current_replacement_chance(room_type: Global.RoomType) -> int:
	var base_chance = get_base_replacement_chance(room_type)
	return DifficultyManager.get_scaled_special_enemy_chance(base_chance)

# Получение всех настроек шансов замены
func get_all_replacement_chances() -> Dictionary:
	var current_chances = {}
	for room_type in base_replacement_chances.keys():
		current_chances[room_type] = get_current_replacement_chance(room_type)
	return current_chances

# Получение всех зарегистрированных врагов с фильтрацией по уровню сложности
func get_available_special_enemies_for_difficulty(difficulty_level: int = -1) -> Dictionary:
	if difficulty_level == -1:
		difficulty_level = DifficultyManager.get_current_difficulty()
	
	var available = {}
	for enemy_id in special_enemies.keys():
		var enemy_data = special_enemies[enemy_id]
		if difficulty_level >= enemy_data.min_difficulty_level:
			available[enemy_id] = enemy_data
	
	return available

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

# Проверка доступности врага в комнате с учетом условий и сложности
func is_enemy_available_in_room(enemy_id: String, room_type: Global.RoomType, room_context: Dictionary = {}) -> bool:
	if not has_enemy(enemy_id):
		return false
	
	var enemy_data = special_enemies[enemy_id]
	var current_difficulty = DifficultyManager.get_current_difficulty()
	
	# Проверяем минимальный уровень сложности
	if current_difficulty < enemy_data.min_difficulty_level:
		return false
	
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
		if not enemy_data.spawn_condition.call(room_context):
			return false
	
	# Для продвинутых врагов дополнительная проверка шанса
	if enemy_data.is_advanced:
		return DifficultyManager.should_spawn_advanced_enemy(10)
	
	return true

# Получение статистики врагов по сложности
func get_enemy_difficulty_stats() -> Dictionary:
	var stats = {
		"total_enemies": special_enemies.size(),
		"available_at_current_difficulty": 0,
		"advanced_enemies": 0,
		"by_difficulty_level": {}
	}
	
	var current_difficulty = DifficultyManager.get_current_difficulty()
	
	for enemy_data in special_enemies.values():
		# Подсчет доступных на текущем уровне
		if current_difficulty >= enemy_data.min_difficulty_level:
			stats.available_at_current_difficulty += 1
		
		# Подсчет продвинутых
		if enemy_data.is_advanced:
			stats.advanced_enemies += 1
		
		# Группировка по уровням сложности
		var min_level = enemy_data.min_difficulty_level
		if not stats.by_difficulty_level.has(min_level):
			stats.by_difficulty_level[min_level] = 0
		stats.by_difficulty_level[min_level] += 1
	
	return stats

# Сброс счетчиков для новой комнаты (вызывайте при входе в новую комнату)
func reset_room_context() -> Dictionary:
	return {
		"spawned_healers": 0,
		"current_spawn_index": 0,
		"total_enemies": 0
	}
