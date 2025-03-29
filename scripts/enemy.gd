extends AbstractCharacter
class_name Enemy

var player: Node2D

@export var speed: int = 1  # Скорость врага
@export var damage: int = 1 # Урон врага
@export var heal_points: int = 3

@onready var ui_stats: EnemyStats = $'../../UI/EnemyStats'
@onready var selected_rect: ColorRect = $SelectedRect
@onready var command_executor = $"../../Table/CommandExecutor"

var is_selected: bool = false
var is_turn_in_progress: bool = false

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	add_to_group("characters")
	hp = heal_points
	selected_rect.visible = false
	player = get_parent().get_node("Player")
	if not player:
		push_error("Player not found!")

# Остановка движения врага
func stop_movement() -> void:
	# Останавливаем любое текущее движение
	is_turn_in_progress = false
	set_process(false)
	set_physics_process(false)

# Логика хода врага
func take_turn() -> void:
	if should_skip_action():
		return
	
	if not is_instance_valid(player) or not command_executor.is_player_alive:
		return  # Ничего не делаем, если игрок мертв
	
	is_turn_in_progress = true
	
	var path = find_path_to_player()
	
	if path.size() > 1:
		var steps = min(speed, path.size() - 1)
		for i in range(steps):
			# Проверяем, жив ли игрок перед каждым шагом
			if not is_instance_valid(player) or not command_executor.is_player_alive:
				is_turn_in_progress = false
				return
				
			var next_tile = path[i + 1]
			var direction_vector = next_tile - get_tile_position()
			current_direction = get_direction_from_vector(direction_vector)
			var target_pos = get_world_position_from_tile(next_tile)
			await animate_movement(target_pos)
			
			# Проверяем еще раз после анимации движения
			if not is_instance_valid(player) or not command_executor.is_player_alive:
				is_turn_in_progress = false
				return
			
			# Проверяем, можем ли атаковать игрока после шага
			var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
			if distance_to_player == 1:
				await attack_player()
				is_turn_in_progress = false
				return
	else:
		# Проверяем, жив ли игрок перед атакой
		if not is_instance_valid(player) or not command_executor.is_player_alive:
			is_turn_in_progress = false
			return
			
		var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
		if distance_to_player == 1:
			await attack_player()
	
	is_turn_in_progress = false

# Поиск пути к ближайшей клетке рядом с игроком
func find_path_to_player() -> Array:
	if not is_instance_valid(player) or not command_executor.is_player_alive:
		return [get_tile_position()]  # Возвращаем текущую позицию, если игрок мертв
		
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
	if is_dead or not is_instance_valid(player) or not command_executor.is_player_alive:
		return
	
	# Определяем направление к игроку
	current_direction = get_direction_from_vector(player.get_tile_position() - get_tile_position())
	
	# Выполняем анимацию атаки
	await animate_attack()
	
	# Проверяем, жив ли игрок перед нанесением урона
	if is_instance_valid(player) and command_executor.is_player_alive:
		player.take_damage(damage)
	
func take_damage(damage_amount: int):
	hp -= damage_amount
	
	# Instead of directly calling sub_hp, just update the UI if this enemy is selected
	if is_selected:
		ui_stats.reset_hp(hp)  # Reset with current hp
	
	super.take_damage(damage_amount)
	
func dead():
	ui_stats.change_stats(self, false)
	super.dead()

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# First check if this enemy is already selected
			if is_selected:
				# If already selected, deselect it
				is_selected = false
				selected_rect.visible = false
				ui_stats.change_stats(self, false)
			else:
				# If not selected, deselect all other enemies first
				for enemy in get_tree().get_nodes_in_group('enemies'):
					if enemy != self and enemy.is_selected:  # Only deselect other enemies
						enemy.is_selected = false
						enemy.selected_rect.visible = false
						
				# Then select this enemy
				is_selected = true
				selected_rect.visible = true
				ui_stats.change_stats(self, true)
