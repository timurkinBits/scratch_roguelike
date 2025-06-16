extends Enemy
class_name SkirmisherEnemy

var movement_used: int = 0
var has_attacked_this_turn: bool = false

var color: Color = Color.DARK_CYAN

func initialize_special_enemy() -> void:
	# Увеличиваем скорость и уменьшаем здоровье для баланса
	speed = randi_range(4, 6)  # Высокая скорость
	heal_points = max(1, heal_points - 1)  # Меньше здоровья
	hp = heal_points
	
	modulate = color

func take_turn() -> void:
	if is_dead:
		return
	
	if not is_instance_valid(player):
		return
	
	# Сбрасываем счетчики хода
	movement_used = 0
	has_attacked_this_turn = false
	
	# Проверяем дистанцию до игрока
	var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
	
	# Если уже рядом с игроком - атакуем и отступаем
	if distance_to_player == 1:
		await attack_and_retreat()
		return
	
	# Стандартное поведение - двигаемся к игроку
	await move_towards_player()

func attack_and_retreat() -> void:
	# Сначала атакуем
	await attack_player()
	has_attacked_this_turn = true
	movement_used = 0  # После атаки можем двигаться
	
	# Затем пытаемся отступить
	await retreat_from_player()
	
func retreat_from_player() -> void:
	if not is_instance_valid(player) or movement_used >= speed:
		return
	
	var retreat_positions = find_retreat_positions()
	if retreat_positions.is_empty():
		return
	
	# Выбираем лучшую позицию для отступления
	var best_position = choose_best_retreat_position(retreat_positions)
	if best_position == get_tile_position():
		return
	
	# Строим путь к позиции отступления
	var path = find_path_to_position(best_position)
	await move_along_path(path, true)  # true = это отступление
	
func find_retreat_positions() -> Array:
	var retreat_positions = []
	var current_pos = get_tile_position()
	var player_pos = player.get_tile_position()
	var remaining_moves = speed - movement_used
	
	# Ищем позиции в радиусе оставшихся очков движения
	for distance in range(1, remaining_moves + 1):
		for x in range(-distance, distance + 1):
			for y in range(-distance, distance + 1):
				if abs(x) + abs(y) != distance:  # Только на нужной дистанции
					continue
				
				var candidate_pos = current_pos + Vector2(x, y)
				
				# Проверяем, можем ли переместиться на эту позицию
				if not can_move_to_tile(candidate_pos):
					continue
				
				# Проверяем, что позиция дальше от игрока
				var distance_from_player = calculate_path_length(candidate_pos, player_pos)
				var current_distance_from_player = calculate_path_length(current_pos, player_pos)
				
				if distance_from_player > current_distance_from_player:
					retreat_positions.append(candidate_pos)
	
	return retreat_positions
	
func choose_best_retreat_position(positions: Array) -> Vector2:
	if positions.is_empty():
		return get_tile_position()
	
	var best_position = positions[0]
	var best_score = evaluate_retreat_position(best_position)
	
	for pos in positions:
		var score = evaluate_retreat_position(pos)
		if score > best_score:
			best_score = score
			best_position = pos
	
	return best_position
	
func evaluate_retreat_position(pos: Vector2) -> float:
	var player_pos = player.get_tile_position()
	var current_pos = get_tile_position()
	
	# Базовый счет - дистанция от игрока
	var distance_from_player = calculate_path_length(pos, player_pos)
	var score = float(distance_from_player)
	
	# Бонус за увеличение дистанции от текущей позиции
	var current_distance = calculate_path_length(current_pos, player_pos)
	if distance_from_player > current_distance:
		score += 2.0
	
	# Штраф за близость к стенам (предпочитаем открытые пространства)
	var wall_penalty = 0
	for direction in DIRECTION_VECTORS.values():
		if not can_move_to_tile(pos + direction):
			wall_penalty += 0.5
	score -= wall_penalty
	
	return score

func move_towards_player() -> void:
	var path = find_path_to_player()
	await move_along_path(path, false)  # false = это не отступление
	
func move_along_path(path: Array, is_retreating: bool = false) -> void:
	if path.size() <= 1:
		return
	
	var remaining_moves = speed - movement_used
	var steps = min(remaining_moves, path.size() - 1)
	
	for i in range(steps):
		if not is_instance_valid(player):
			return
		
		var next_tile = path[i + 1]
		var direction_vector = next_tile - get_tile_position()
		current_direction = get_direction_from_vector(direction_vector)
		update_visual()
		
		var target_pos = get_world_position_from_tile(next_tile)
		await animate_movement(target_pos)
		movement_used += 1
		
		if not is_instance_valid(player):
			return
		
		# Если не отступаем и дошли до игрока - атакуем
		if not is_retreating and not has_attacked_this_turn:
			var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
			if distance_to_player == 1:
				await attack_player()
				has_attacked_this_turn = true
				
				# После атаки пытаемся отступить, если есть движение
				if movement_used < speed:
					await retreat_from_player()
				return
				
func find_path_to_position(target_pos: Vector2) -> Array:
	var start = get_tile_position()
	
	if start == target_pos:
		return [start]
	
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: calculate_path_length(start, target_pos)}
	
	while not open_set.is_empty():
		var current = get_lowest_f_score(open_set, f_score)
		if current == target_pos:
			var path = reconstruct_path(came_from, current)
			return path
		
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
	
	return [start]
