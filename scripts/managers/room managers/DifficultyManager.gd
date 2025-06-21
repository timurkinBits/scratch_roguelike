extends Node

signal difficulty_changed(new_level: int)

# Текущий уровень сложности
var current_level: int = 1

# Настройки масштабирования для каждого уровня сложности
@export_group("Enemy Scaling")
@export var hp_scaling_per_level: float = 0.15  # +15% ХП за уровень
@export var damage_scaling_per_level: float = 0.15  # +15% урона за уровень
@export var speed_scaling_per_level: float = 0.1   # +10% скорости за уровень

@export_group("Spawn Scaling")
@export var max_enemies_increase_per_level: int = 1  # +1 макс враг каждые N уровней
@export var max_enemies_increase_threshold: int = 3  # Каждые 3 уровня
@export var special_enemy_chance_per_level: float = 2.0  # +2% шанса за уровень
@export var advanced_enemy_chance_per_level: float = 1.5  # +1.5% шанса на продвинутых врагов за уровень

@export_group("Room Rewards")
@export var normal_room_difficulty_gain: int = 1
@export var elite_room_difficulty_gain: int = 2
@export var challenge_room_difficulty_gain: int = 0

# Максимальные значения для ограничения роста
@export_group("Scaling Limits")
@export var max_special_enemy_chance: int = 80
@export var max_advanced_enemy_chance: int = 60
@export var max_difficulty_level: int = 50

# Увеличение сложности после прохождения комнаты
func increase_difficulty_for_room(room_type: Global.RoomType) -> void:
	var difficulty_gain = 0
	
	match room_type:
		Global.RoomType.NORMAL:
			difficulty_gain = normal_room_difficulty_gain
		Global.RoomType.ELITE:
			difficulty_gain = elite_room_difficulty_gain
		Global.RoomType.CHALLENGE:
			difficulty_gain = 0
		Global.RoomType.SHOP:
			difficulty_gain = 0  # Магазин не повышает сложность
	
	if difficulty_gain > 0:
		increase_difficulty(difficulty_gain)

# Увеличение сложности на указанное количество уровней
func increase_difficulty(levels: int) -> void:
	var old_level = current_level
	current_level = min(current_level + levels, max_difficulty_level)
	
	if current_level != old_level:
		difficulty_changed.emit(current_level)

# ИСПРАВЛЕНО: Получение масштабированного ХП для врага
func get_scaled_hp(base_hp: int) -> int:
	if current_level <= 1:
		return base_hp
	
	var scaling_factor = 1.0 + (hp_scaling_per_level * (current_level - 1))
	var scaled_hp = int(base_hp * scaling_factor)
	return max(base_hp, scaled_hp)  # Гарантируем что ХП не уменьшится

# ИСПРАВЛЕНО: Получение масштабированного урона для врага
func get_scaled_damage(base_damage: int) -> int:
	if current_level <= 1:
		return base_damage
	
	var scaling_factor = 1.0 + (damage_scaling_per_level * (current_level - 1))
	var scaled_damage = int(base_damage * scaling_factor)
	return max(base_damage, scaled_damage)  # Гарантируем что урон не уменьшится

# ИСПРАВЛЕНО: Получение масштабированной скорости для врага
func get_scaled_speed(base_speed: int) -> int:
	if current_level <= 1:
		return base_speed
	
	var scaling_factor = 1.0 + (speed_scaling_per_level * (current_level - 1))
	var scaled_speed = int(base_speed * scaling_factor)
	return max(base_speed, scaled_speed)  # Гарантируем что скорость не уменьшится

# ИСПРАВЛЕНО: Получение максимального количества врагов с учетом сложности
func get_scaled_max_enemies(base_max_enemies: int) -> int:
	if current_level <= 1:
		return base_max_enemies
	
	# Увеличиваем каждые max_enemies_increase_threshold уровней
	var additional_enemies = ((current_level - 1) / max_enemies_increase_threshold) * max_enemies_increase_per_level
	var scaled_max = base_max_enemies + additional_enemies
	
	return scaled_max

# Получение шанса замены на специального врага с учетом сложности
func get_scaled_special_enemy_chance(base_chance: int) -> int:
	if current_level <= 1:
		return base_chance
	
	var additional_chance = (current_level - 1) * special_enemy_chance_per_level
	return min(base_chance + int(additional_chance), max_special_enemy_chance)

# Получение шанса появления продвинутого врага с учетом сложности
func get_scaled_advanced_enemy_chance(base_chance: int) -> int:
	if current_level <= 1:
		return base_chance
	
	var additional_chance = (current_level - 1) * advanced_enemy_chance_per_level
	return min(base_chance + int(additional_chance), max_advanced_enemy_chance)

# Проверка, должен ли появиться продвинутый враг
func should_spawn_advanced_enemy(base_chance: int = 0) -> bool:
	var scaled_chance = get_scaled_advanced_enemy_chance(base_chance)
	return randi() % 100 < scaled_chance

# Получение текущего уровня сложности
func get_current_difficulty() -> int:
	return current_level

# Установка уровня сложности (для тестирования или сохранения)
func set_difficulty(level: int) -> void:
	var old_level = current_level
	current_level = clamp(level, 1, max_difficulty_level)
	
	if current_level != old_level:
		difficulty_changed.emit(current_level)

# Сброс сложности (для новой игры)
func reset_difficulty() -> void:
	set_difficulty(1)

# ИСПРАВЛЕНО: Получение информации о текущих модификаторах сложности
func get_difficulty_info() -> Dictionary:
	return {
		"level": current_level,
		"hp_multiplier": 1.0 + (hp_scaling_per_level * max(0, current_level - 1)),
		"damage_multiplier": 1.0 + (damage_scaling_per_level * max(0, current_level - 1)),
		"speed_multiplier": 1.0 + (speed_scaling_per_level * max(0, current_level - 1)),
		"special_enemy_bonus": int(max(0, current_level - 1) * special_enemy_chance_per_level),
		"advanced_enemy_bonus": int(max(0, current_level - 1) * advanced_enemy_chance_per_level),
		"max_enemies_bonus": ((max(0, current_level - 1)) / max_enemies_increase_threshold) * max_enemies_increase_per_level
	}

# ИСПРАВЛЕНО: Получение описания текущей сложности для UI
func get_difficulty_description() -> String:
	var info = get_difficulty_info()
	var desc = "=== DIFFICULTY LEVEL: %d ===\n" % current_level
	desc += "Enemy HP: +%d%% (x%.2f)\n" % [int((info.hp_multiplier - 1.0) * 100), info.hp_multiplier]
	desc += "Enemy Damage: +%d%% (x%.2f)\n" % [int((info.damage_multiplier - 1.0) * 100), info.damage_multiplier]
	desc += "Enemy Speed: +%d%% (x%.2f)\n" % [int((info.speed_multiplier - 1.0) * 100), info.speed_multiplier]
	desc += "Special Enemy Chance: +%d%%\n" % info.special_enemy_bonus
	desc += "Advanced Enemy Chance: +%d%%\n" % info.advanced_enemy_bonus
	desc += "Max Enemies Bonus: +%d\n" % info.max_enemies_bonus
	desc += "=========================="
	return desc

# Сохранение/загрузка сложности
func get_save_data() -> Dictionary:
	return {
		"current_level": current_level
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("current_level"):
		set_difficulty(data.current_level)
