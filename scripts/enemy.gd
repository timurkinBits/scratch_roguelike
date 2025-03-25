extends AbstractCharacter
class_name Enemy

var player: Node2D

@export var speed: int = 1
@export var damage: int = 1
var stuck_counter: int = 0

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	add_to_group("characters")
	hp = 3
	player = get_parent().get_node("Player")
	if not player:
		push_error("Player not found!")

# Логика хода врага
func take_turn() -> void:
	if should_skip_action():
		return
	
	var enemy_tile = get_tile_position()
	var player_tile = player.get_tile_position()
	
	# Атака, если игрок рядом
	if calculate_path_length(enemy_tile, player_tile) == 1 and !is_dead:
		current_direction = get_direction_to_player()
		await attack_player()
		return
	
	# Движение к игроку
	var remaining_steps = speed
	
	while remaining_steps > 0:
		enemy_tile = get_tile_position()
		player_tile = player.get_tile_position()
		
		# Проверка, достигнут ли игрок
		if calculate_path_length(enemy_tile, player_tile) == 1:
			break
		
		# Определяем оптимальное направление движения
		current_direction = get_optimal_direction(enemy_tile, player_tile)
		var direction_vector = DIRECTION_VECTORS[current_direction]
		var next_tile = enemy_tile + direction_vector
		
		# Проверяем возможность движения
		if not can_move_to_tile(next_tile):
			current_direction = find_path_around_obstacle(enemy_tile, player_tile)
			if current_direction == "":
				stuck_counter += 1
				if stuck_counter >= 3:
					current_direction = get_random_direction()
					stuck_counter = 0
			
			direction_vector = DIRECTION_VECTORS[current_direction]
			next_tile = enemy_tile + direction_vector
			
			# Последняя проверка возможности движения
			if not can_move_to_tile(next_tile):
				break
		
		# Выполняем движение
		var target_pos = get_world_position_from_tile(next_tile)
		await animate_movement(target_pos)
		
		remaining_steps -= 1
	
	# Атака, если добрались до игрока
	if calculate_path_length(get_tile_position(), player.get_tile_position()) == 1 and !is_dead:
		current_direction = get_direction_to_player()
		await attack_player()
		
func get_random_direction() -> String:
	var directions = ["up", "down", "left", "right"]
	directions.shuffle()
	for dir in directions:
		if can_move_to_tile(get_tile_position() + DIRECTION_VECTORS[dir]):
			return dir
	return ""
	
func is_tile_walkable(tile_pos: Vector2) -> bool:
	# Проверяем, находится ли тайл в пределах карты
	if not tilemap.get_used_rect().has_point(tile_pos):
		return false
	# Проверяем наличие барьеров
	var barrier_group = get_tree().get_nodes_in_group("barrier")
	for barrier in barrier_group:
		if barrier.get_tile_position() == tile_pos:
			return false
	# Проверяем наличие других персонажей
	var all_characters = get_tree().get_nodes_in_group("characters")
	for character in all_characters:
		if character != self and is_instance_valid(character):
			if character.get_tile_position() == tile_pos:
				return false
	return true

# Атака игрока
func attack_player() -> void:
	if is_dead:
		return
	await animate_attack()
	if player and player.has_method("take_damage"):
		player.take_damage(damage)

# Направление к игроку
func get_direction_to_player() -> String:
	if not player:
		return ""
	
	var enemy_tile = get_tile_position()
	var player_tile = player.get_tile_position()
	
	var dx = player_tile.x - enemy_tile.x
	var dy = player_tile.y - enemy_tile.y
	
	if abs(dx) > abs(dy):
		return "right" if dx > 0 else "left"
	else:
		return "down" if dy > 0 else "up"

# Оптимальное направление движения
func get_optimal_direction(enemy_tile: Vector2, player_tile: Vector2) -> String:
	var dx = player_tile.x - enemy_tile.x
	var dy = player_tile.y - enemy_tile.y
	
	if abs(dx) >= abs(dy) and dx != 0:
		return "right" if dx > 0 else "left"
	elif dy != 0:
		return "down" if dy > 0 else "up"
	return "up"

# Альтернативное направление
func find_alternate_direction(enemy_tile: Vector2, player_tile: Vector2) -> String:
	var alternate_direction = find_advanced_path(enemy_tile, player_tile)
	
	# Если расширенный поиск не нашел путь, используем старую логику
	if alternate_direction == "":
		var directions = ["up", "down", "left", "right"]
		var best_direction = ""
		var best_distance = INF
		
		for dir in directions:
			var dir_vector = DIRECTION_VECTORS[dir]
			var next_tile = enemy_tile + dir_vector
			
			if can_move_to_tile(next_tile):
				var new_distance = calculate_path_length(next_tile, player_tile)
				if new_distance < best_distance:
					best_distance = new_distance
					best_direction = dir
		
		return best_direction
	
	return alternate_direction
	
func find_advanced_path(enemy_tile: Vector2, player_tile: Vector2) -> String:
	var directions = ["up", "down", "left", "right"]
	var potential_paths = []
	
	# Проверяем каждое возможное направление
	for dir in directions:
		var initial_dir_vector = DIRECTION_VECTORS[dir]
		var next_tile = enemy_tile + initial_dir_vector
		
		# Если первый шаг возможен
		if can_move_to_tile(next_tile):
			# Пробуем сделать второй шаг в сторону
			var perpendicular_dirs = []
			match dir:
				"up", "down":
					perpendicular_dirs = ["left", "right"]
				"left", "right":
					perpendicular_dirs = ["up", "down"]
			
			for perp_dir in perpendicular_dirs:
				var perp_vector = DIRECTION_VECTORS[perp_dir]
				var path_tile = next_tile + perp_vector
				
				# Проверяем, можно ли пройти боковым шагом
				if can_move_to_tile(path_tile):
					var path_length = calculate_path_length(path_tile, player_tile)
					potential_paths.append({
						"direction": dir,
						"length": path_length
					})
	
	# Сортируем потенциальные пути по близости к игроку
	if potential_paths:
		potential_paths.sort_custom(func(a, b): return a["length"] < b["length"])
		return potential_paths[0]["direction"]
	
	return ""
	
func find_path_around_obstacle(enemy_tile: Vector2, player_tile: Vector2) -> String:
	var directions = ["up", "down", "left", "right"]
	var best_direction = ""
	var best_score = -INF
	
	# Проверяем все возможные направления
	for dir in directions:
		var dir_vector = DIRECTION_VECTORS[dir]
		var next_tile = enemy_tile + dir_vector
		
		# Проверяем, можно ли двигаться в этом направлении
		if can_move_to_tile(next_tile):
			var score = 0
			
			# Основной критерий: приближение к игроку
			var distance_to_player = calculate_path_length(next_tile, player_tile)
			score += 100 - distance_to_player
			
			# Штраф за препятствие впереди (через одну клетку)
			var ahead_tile = next_tile + dir_vector
			if not can_move_to_tile(ahead_tile):
				score -= 20  # Уменьшаем приоритет, если впереди тупик
			
			# Бонус за возможность двигаться в стороны (обход)
			var perpendicular_dirs = []
			match dir:
				"up", "down":
					perpendicular_dirs = ["left", "right"]
				"left", "right":
					perpendicular_dirs = ["up", "down"]
			
			for perp_dir in perpendicular_dirs:
				var perp_vector = DIRECTION_VECTORS[perp_dir]
				var side_tile = next_tile + perp_vector
				if can_move_to_tile(side_tile):
					score += 10  # Бонус за открытый путь в сторону
			
			# Выбираем направление с лучшим score
			if score > best_score:
				best_score = score
				best_direction = dir
	
	return best_direction
