extends Enemy
class_name HealerEnemy

# Настройки лекаря
var heal_range: int = 1
var color: Color = Color(0.3, 0.8, 0.3, 1.0)  # Зеленый цвет
var healing_color: Color = Color(0.5, 1.0, 0.5, 1.0)  # Ярко-зеленый
var min_distance_from_player: int = 3  # Минимальное расстояние от игрока

func initialize_special_enemy() -> void:
	has_special_ability = true
	max_ability_cooldown = 2
	ability_cooldown = 0
	
	# Лекарь не может атаковать
	damage = 0
	
	# Увеличиваем здоровье и скорость для выживаемости
	heal_points += 3
	hp += 3
	speed += 2
	
	# Устанавливаем зеленый цвет
	modulate = color

func can_use_special_ability() -> bool:
	if not super.can_use_special_ability():
		return false
	
	# Проверяем, есть ли раненые союзники в радиусе лечения
	var wounded_allies = get_wounded_allies_in_range()
	return wounded_allies.size() > 0

func use_special_ability() -> void:
	reset_ability_cooldown()
	await heal_nearby_allies()

func get_wounded_allies_in_range() -> Array:
	var wounded_allies = []
	var my_pos = get_tile_position()
	
	# Ищем всех врагов (союзников лекаря)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead:
			continue
			
		var ally_pos = enemy.get_tile_position()
		var distance = calculate_path_length(my_pos, ally_pos)
		
		# Проверяем, находится ли союзник в радиусе лечения и ранен ли он
		if distance <= heal_range and enemy.hp < enemy.heal_points * 0.5:
			wounded_allies.append(enemy)
	
	return wounded_allies

func heal_nearby_allies() -> void:
	var wounded_allies = get_wounded_allies_in_range()
	
	if wounded_allies.size() == 0:
		return
	
	# Играем анимацию лечения
	await play_healing_animation()
	
	# Лечим всех раненых союзников в радиусе
	for ally in wounded_allies:
		if is_instance_valid(ally) and not ally.is_dead:
			ally.hp = ally.heal_points  # Полное восстановление здоровья
			play_ally_heal_effect(ally)

func play_healing_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Пульсирующий зеленый свет
	for i in range(3):
		tween.tween_property(self, "modulate", healing_color, 0.3)
		tween.tween_property(self, "modulate", color, 0.3)
	
	# Увеличение размера с "волной лечения"
	var original_scale = scale
	tween.tween_property(self, "scale", original_scale * 1.4, 0.4)
	tween.tween_property(self, "scale", original_scale, 0.5)
	
	# Легкое свечение
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.2)
	tween.tween_property(self, "modulate", color, 0.6)
	
	await tween.finished

func play_ally_heal_effect(ally: Node2D) -> void:
	if not is_instance_valid(ally):
		return
		
	# Эффект лечения на союзнике
	var heal_tween = create_tween()
	heal_tween.set_parallel(true)
	
	# Зеленое свечение на союзнике
	var original_modulate = ally.modulate
	heal_tween.tween_property(ally, "modulate", Color(0.5, 1.2, 0.5, 1.0), 0.3)
	heal_tween.tween_property(ally, "modulate", original_modulate, 0.5)
	
	# Небольшое увеличение размера
	var original_scale = ally.scale
	heal_tween.tween_property(ally, "scale", original_scale * 1.1, 0.2)
	heal_tween.tween_property(ally, "scale", original_scale, 0.3)

# Переопределяем стандартное поведение
func execute_standard_behavior() -> void:
	# Сначала проверяем, можем ли мы использовать способность лечения
	if can_use_special_ability():
		await use_special_ability()
		return
	
	# Основная стратегия: избегать игрока и приближаться к раненым союзникам
	var target_position = find_optimal_position()
	
	if target_position != get_tile_position():
		await move_towards_position(target_position)
	else:
		# Если не можем двигаться, просто ждем
		await get_tree().create_timer(0.3).timeout

func find_optimal_position() -> Vector2:
	var current_pos = get_tile_position()
	var best_position = current_pos
	var best_score = evaluate_position(current_pos)
	
	# Получаем все возможные позиции в радиусе движения
	var possible_moves = get_possible_moves()
	
	for pos in possible_moves:
		var score = evaluate_position(pos)
		if score > best_score:
			best_score = score
			best_position = pos
	
	return best_position

func get_possible_moves() -> Array:
	var moves = []
	var current_pos = get_tile_position()
	
	# Проверяем все позиции в радиусе скорости
	for x in range(-speed, speed + 1):
		for y in range(-speed, speed + 1):
			if abs(x) + abs(y) > speed or (x == 0 and y == 0):
				continue  # Манхэттенское расстояние больше скорости или текущая позиция
				
			var new_pos = current_pos + Vector2(x, y)
			if can_move_to_tile(new_pos):
				moves.append(new_pos)
	
	return moves

func evaluate_position(pos: Vector2) -> float:
	var score = 0.0
	
	# Штраф за близость к игроку
	if is_instance_valid(player):
		var distance_to_player = calculate_path_length(pos, player.get_tile_position())
		if distance_to_player < min_distance_from_player:
			score -= (min_distance_from_player - distance_to_player)  # Большой штраф
	
	# Бонус за близость к раненым союзникам
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead:
			continue
			
		var ally_pos = enemy.get_tile_position()
		var distance_to_ally = calculate_path_length(pos, ally_pos)
		
		# Если союзник ранен, даем бонус за близость
		if enemy.hp < enemy.heal_points * 0.5:
			if distance_to_ally <= heal_range:
				score += 35.0  # Большой бонус за возможность лечения
			else:
				score += max(0, 5.0 - distance_to_ally)  # Бонус за приближение к раненому
	
	return score

func move_towards_position(target_pos: Vector2) -> void:
	var path = find_path_to_position(target_pos)
	
	if path.size() > 1:
		var steps = min(speed, path.size() - 1)
		for i in range(steps):
			var next_tile = path[i + 1]
			var direction_vector = next_tile - get_tile_position()
			current_direction = get_direction_from_vector(direction_vector)
			update_visual()
			
			var target_world_pos = get_world_position_from_tile(next_tile)
			await animate_movement(target_world_pos)

func find_path_to_position(target_pos: Vector2) -> Array:
	var start = get_tile_position()
	
	if start == target_pos:
		return [start]
	
	# Используем A* для поиска пути
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: calculate_path_length(start, target_pos)}
	
	while not open_set.is_empty():
		var current = get_lowest_f_score(open_set, f_score)
		if current == target_pos:
			return reconstruct_path(came_from, current)
		
		open_set.erase(current)
		var neighbors = get_neighbors(current)
		for neighbor in neighbors:
			var tentative_g_score = g_score[current] + 1
			if not g_score.has(neighbor) or tentative_g_score < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + calculate_path_length(neighbor, target_pos)
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	# Если путь не найден, возвращаем текущую позицию
	return [start]

# Лекарь не может атаковать
func attack_player() -> void:
	# Вместо атаки пытаемся отойти от игрока
	var retreat_pos = find_retreat_position()
	if retreat_pos != get_tile_position():
		await move_towards_position(retreat_pos)

func find_retreat_position() -> Vector2:
	if not is_instance_valid(player):
		return get_tile_position()
	
	var current_pos = get_tile_position()
	var player_pos = player.get_tile_position()
	var best_pos = current_pos
	var max_distance = calculate_path_length(current_pos, player_pos)
	
	# Ищем позицию, максимально удаленную от игрока
	var possible_moves = get_possible_moves()
	for pos in possible_moves:
		var distance = calculate_path_length(pos, player_pos)
		if distance > max_distance:
			max_distance = distance
			best_pos = pos
	
	return best_pos

func update_visual() -> void:
	super.update_visual()
	
	# Дополнительные визуальные эффекты
	if modulate != color:
		modulate = color

func take_damage(damage_amount: int):
	super.take_damage(damage_amount)
	
	# Эффект получения урона
	if not is_dead:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(self, "modulate", color, 0.2)

#func get_enemy_type() -> String:
	#return "healer_enemy"
 
