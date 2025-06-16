extends Enemy
class_name TeleporterEnemy

# Настройки телепортации
var teleport_range: int = 4

# Цвета для телепортера
var color: Color = Color(0.4, 0.7, 1.0, 1.0)  # Синеватый
var teleport_out_color: Color = Color(0.8, 0.4, 1.0, 0.3)  # Фиолетовый полупрозрачный
var teleport_in_color: Color = Color(0.2, 0.8, 1.0, 1.2)   # Яркий голубой
var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)

func initialize_special_enemy() -> void:
	has_special_ability = true
	ability_name = "Телепортация"
	max_ability_cooldown = 4
	ability_cooldown = 4
	
	# Немного увеличиваем статистики для компенсации
	damage += 1
	speed = max(speed - 3, 1)  # Уменьшаем скорость, так как может телепортироваться
	
	# Устанавливаем цвет телепортера
	modulate = color

func can_use_special_ability() -> bool:
	if not super.can_use_special_ability():
		return false
	
	# Используем телепортацию, если игрок далеко или заблокирован
	var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
	var path_to_player = find_path_to_player()
	
	# Телепортируемся если игрок далеко или путь слишком длинный
	return distance_to_player > 3 or path_to_player.size() > 4

func use_special_ability() -> void:
	ability_cooldown = max_ability_cooldown
	await teleport_to_player()

func teleport_to_player() -> void:
	if not is_instance_valid(player):
		return
	
	var player_pos = player.get_tile_position()
	var teleport_positions = get_teleport_positions_near_player(player_pos)
	
	if teleport_positions.is_empty():
		return  # Нет доступных позиций для телепортации
	
	# Выбираем случайную позицию рядом с игроком
	var teleport_pos = teleport_positions[randi() % teleport_positions.size()]
	
	# Эффект исчезновения
	await play_teleport_out_effect()
	
	# Телепортируемся
	var world_pos = get_world_position_from_tile(teleport_pos)
	position = world_pos
	
	# Обновляем направление к игроку
	current_direction = get_direction_from_vector(player_pos - teleport_pos)
	
	# Эффект появления
	await play_teleport_in_effect()
	
	update_visual()

func get_teleport_positions_near_player(player_pos: Vector2) -> Array:
	var positions = []
	var directions = DIRECTION_VECTORS.values()
	
	# Проверяем клетки вокруг игрока
	for dir in directions:
		var candidate_pos = player_pos + dir
		if can_move_to_tile(candidate_pos):
			positions.append(candidate_pos)
	
	# Если нет места рядом с игроком, ищем в радиусе телепортации
	if positions.is_empty():
		for x in range(-teleport_range, teleport_range + 1):
			for y in range(-teleport_range, teleport_range + 1):
				if x == 0 and y == 0:
					continue
				
				var candidate_pos = player_pos + Vector2(x, y)
				var distance = calculate_path_length(player_pos, candidate_pos)
				
				if distance <= teleport_range and can_move_to_tile(candidate_pos):
					positions.append(candidate_pos)
	
	return positions

func play_teleport_out_effect() -> void:
	# Сложная анимация исчезновения
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 1. Мерцание перед исчезновением
	for i in range(4):
		tween.tween_property(self, "modulate", teleport_out_color, 0.08)
		tween.tween_property(self, "modulate", color, 0.08)
	
	# 2. Вращение и уменьшение
	tween.tween_property(self, "rotation_degrees", 720, 0.6)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.5)
	
	# 3. Постепенное исчезновение
	tween.tween_property(self, "modulate", teleport_out_color, 0.4)
	
	# 4. Волновой эффект
	for wave in range(3):
		var wave_scale = 1.0 + wave * 0.3
		tween.tween_property(self, "scale", Vector2(wave_scale, wave_scale), 0.1)
		tween.tween_property(self, "scale", Vector2(wave_scale * 0.8, wave_scale * 0.8), 0.1)
	
	await tween.finished

func play_teleport_in_effect() -> void:
	# Эффектная анимация появления
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Начальное состояние - невидимый и маленький
	modulate = Color(0, 0, 0, 0)
	scale = Vector2(0.1, 0.1)
	rotation_degrees = 0
	
	# 1. Быстрое появление с яркой вспышкой
	tween.tween_property(self, "modulate", teleport_in_color, 0.2)
	tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.15)
	
	# 2. Стабилизация размера
	tween.tween_property(self, "scale", Vector2(2, 2), 0.3)
	
	# 3. Вращение материализации
	tween.tween_property(self, "rotation_degrees", -360, 0.4)
	
	# 4. Возврат к нормальному цвету
	tween.tween_property(self, "modulate", color, 0.4)
	
	# 5. Импульсные волны после появления
	await tween.finished

func take_damage(damage_amount: int):
	super.take_damage(damage_amount)
	
	# Эффект получения урона для телепортера
	if not is_dead:
		var damage_tween = create_tween()
		damage_tween.set_parallel(true)
		
		# Мерцание при получении урона
		damage_tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		damage_tween.tween_property(self, "modulate", color, 0.2)
		
		# Легкое дрожание
		var original_pos = position
		damage_tween.tween_property(self, "position", original_pos + Vector2(3, 0), 0.05)
		damage_tween.tween_property(self, "position", original_pos + Vector2(-3, 0), 0.05)
		damage_tween.tween_property(self, "position", original_pos, 0.05)

func update_visual() -> void:
	super.update_visual()
	
	# Постоянное легкое свечение для телепортера
	if not is_moving and not is_dead:
		# Создаем циклическое мерцание
		var glow_tween = create_tween()
		glow_tween.set_loops()
		glow_tween.tween_property(self, "modulate", color * 1.2, 1.0)
		glow_tween.tween_property(self, "modulate", color * 0.8, 1.0)

#func get_enemy_type() -> String:
	## Переопределяем для уникального внешнего вида
	#return "teleporter_enemy"

func dead():
	super.dead()
