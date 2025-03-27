extends AbstractCharacter
class_name Enemy

var player: Node2D

@export var speed: int = 1  # Скорость врага
@export var damage: int = 1 # Урон врага
@export var heal_points: int = 3

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	add_to_group("characters")
	hp = heal_points
	player = get_parent().get_node("Player")
	if not player:
		push_error("Player not found!")

# Логика хода врага
func take_turn() -> void:
	if should_skip_action():
		return
	
	var path = find_path_to_player()
	
	if path.size() > 1:
		var steps = min(speed, path.size() - 1)
		for i in range(steps):
			var next_tile = path[i + 1]
			var direction_vector = next_tile - get_tile_position()
			current_direction = get_direction_from_vector(direction_vector)
			var target_pos = get_world_position_from_tile(next_tile)
			await animate_movement(target_pos)
			
			# Проверяем, можем ли атаковать игрока после шага
			var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
			if distance_to_player == 1:
				await attack_player()
				return
	else:
		var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
		if distance_to_player == 1:
			await attack_player()

# Поиск пути к ближайшей клетке рядом с игроком
func find_path_to_player() -> Array:
	var start = get_tile_position()
	var player_pos = player.get_tile_position()
	
	# Если уже рядом с игроком, остаемся на месте
	var distance_to_player = calculate_path_length(start, player_pos)
	if distance_to_player <= 1:
		return [start]
	
	# Находим ближайшую доступную клетку рядом с игроком
	var goal = get_closest_reachable_tile(player_pos)
	if goal == start:
		return [start]
	
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: calculate_path_length(start, goal)}
	
	while not open_set.is_empty():
		var current = get_lowest_f_score(open_set, f_score)
		if current == goal:
			var path = reconstruct_path(came_from, current)
			return path
		
		open_set.erase(current)
		var neighbors = get_neighbors(current)
		for neighbor in neighbors:
			var tentative_g_score = g_score[current] + 1
			if not g_score.has(neighbor) or tentative_g_score < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + calculate_path_length(neighbor, goal)
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	return [start]

# Нахождение ближайшей доступной клетки рядом с игроком
func get_closest_reachable_tile(player_pos: Vector2) -> Vector2:
	var directions = DIRECTION_VECTORS.values()
	var closest_tile = player_pos
	var min_distance = INF
	
	for dir in directions:
		var candidate = player_pos + dir
		if can_move_to_tile(candidate):
			var distance = calculate_path_length(get_tile_position(), candidate)
			if distance < min_distance:
				min_distance = distance
				closest_tile = candidate
	
	return closest_tile

# Выбор узла с минимальной F-стоимостью
func get_lowest_f_score(open_set: Array, f_score: Dictionary) -> Vector2:
	var lowest = open_set[0]
	for node in open_set:
		if f_score[node] < f_score[lowest]:
			lowest = node
	return lowest

# Получение соседних клеток
func get_neighbors(tile: Vector2) -> Array:
	var neighbors = []
	for dir in DIRECTION_VECTORS.values():
		var neighbor = tile + dir
		if can_move_to_tile(neighbor):
			neighbors.append(neighbor)
	return neighbors

# Восстановление пути
func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path

# Определение направления по вектору
func get_direction_from_vector(vector: Vector2) -> String:
	if vector.x > 0:
		return "right"
	elif vector.x < 0:
		return "left"
	elif vector.y > 0:
		return "down"
	elif vector.y < 0:
		return "up"
	return current_direction

# Атака игрока
func attack_player() -> void:
	if is_dead or not player or not is_instance_valid(player):
		return
	
	# Определяем направление к игроку
	current_direction = get_direction_from_vector(player.get_tile_position() - get_tile_position())
	
	# Выполняем анимацию атаки
	await animate_attack()
	player.take_damage(damage)
