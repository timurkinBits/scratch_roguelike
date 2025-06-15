extends AbstractCharacter
class_name Enemy

var player: Node2D

var speed: int = randi_range(2, 5)
var damage: int = randi_range(2, 5)
var heal_points: int = randi_range(3, 6)

# Новые свойства для специальных способностей
var has_special_ability: bool = false
var ability_cooldown: int = 0
var max_ability_cooldown: int = 3
var ability_name: String = ""

@onready var ui_stats: EnemyStats = $'../../UI/EnemyStats'
@onready var command_executor = $"../../Table/TurnExecutor"
@onready var sprite = $Sprite

var hp_bar_offset: Vector2 = Vector2(0, -40)
var coin_scene = preload("res://scenes/Coin.tscn")

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	hp = heal_points
	player = get_parent().get_node("Player")
	sprite.animation = get_enemy_type() + "_idle"
	initialize_special_enemy()
	update_visual()

# Виртуальная функция для инициализации специальных врагов
func initialize_special_enemy() -> void:
	pass

func get_enemy_type() -> String:
	if damage <= 3:
		return "weak_enemy"
	elif damage == 4:
		return "medium_enemy"
	else:
		return "strong_enemy"

# Модифицированная логика хода врага с учетом способностей
func take_turn() -> void:
	if is_dead:
		return
	
	if not is_instance_valid(player):
		return
	
	# Уменьшаем кулдаун способности
	if ability_cooldown > 0:
		ability_cooldown -= 1
	
	# Проверяем, можем ли использовать способность
	if can_use_special_ability():
		await use_special_ability()
		return
	
	# Обычное поведение
	var path = find_path_to_player()
	
	if path.size() > 1:
		var steps = min(speed, path.size() - 1)
		for i in range(steps):
			if not is_instance_valid(player):
				return
				
			var next_tile = path[i + 1]
			var direction_vector = next_tile - get_tile_position()
			current_direction = get_direction_from_vector(direction_vector)
			update_visual()
			
			var target_pos = get_world_position_from_tile(next_tile)
			await animate_movement(target_pos)
			
			if not is_instance_valid(player):
				return
			
			var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
			if distance_to_player == 1:
				await attack_player()
				return
	else:
		if not is_instance_valid(player):
			return
			
		var distance_to_player = calculate_path_length(get_tile_position(), player.get_tile_position())
		if distance_to_player == 1:
			await attack_player()

# Виртуальные функции для способностей (переопределяются в наследниках)
func can_use_special_ability() -> bool:
	return has_special_ability and ability_cooldown <= 0

func use_special_ability() -> void:
	# Базовая реализация - ничего не делает
	pass
			
func update_visual() -> void:
	var animation_prefix = get_enemy_type() + "_"

	sprite.visible = true

	if is_moving:
		sprite.play(animation_prefix + "walk")
	else:
		sprite.play(animation_prefix + "idle")

	if current_direction == "left":
		sprite.flip_h = true
	else:
		sprite.flip_h = false
		
func animate_movement(target_pos: Vector2) -> void:
	is_moving = true
	update_visual()
	
	create_tween().tween_property(
		self, 
		"position", 
		target_pos, 
		0.3
	).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.3).timeout
	
	is_moving = false
	update_visual()

func find_path_to_player() -> Array:
	if not is_instance_valid(player):
		return [get_tile_position()]
		
	var start = get_tile_position()
	var player_pos = player.get_tile_position()
	
	var distance_to_player = calculate_path_length(start, player_pos)
	if distance_to_player <= 1:
		return [start]
	
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

func get_lowest_f_score(open_set: Array, f_score: Dictionary) -> Vector2:
	var lowest = open_set[0]
	for node in open_set:
		if f_score[node] < f_score[lowest]:
			lowest = node
	return lowest

func get_neighbors(tile: Vector2) -> Array:
	var neighbors = []
	for dir in DIRECTION_VECTORS.values():
		var neighbor = tile + dir
		if can_move_to_tile(neighbor):
			neighbors.append(neighbor)
	return neighbors

func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path

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

func attack_player() -> void:
	if is_dead or not is_instance_valid(player):
		return
	
	current_direction = get_direction_from_vector(player.get_tile_position() - get_tile_position())
	update_visual()
	
	await animate_attack()
	
	if is_instance_valid(player):
		player.take_damage(damage)
	
func take_damage(damage_amount: int):
	hp -= damage_amount
	super.take_damage(damage_amount)
	
func spawn_coin() -> void:
	var coin_instance = coin_scene.instantiate()
	get_parent().add_child(coin_instance)
	coin_instance.position = position
	
	var room = get_parent()
	var is_elite = room.type == room.RoomType.ELITE
		
	var coin_type = Coin.get_random_coin_type(is_elite)
	coin_instance.set_type(coin_type)
	
func dead():
	spawn_coin()
	ui_stats.change_stats(self, false)
	super.dead()

func _on_area_2d_mouse_entered() -> void:
	ui_stats.change_stats(self, true)

func _on_area_2d_mouse_exited() -> void:
	ui_stats.change_stats(self, false)
	
func calculate_path_length(from_tile: Vector2, to_tile: Vector2) -> int:
	return int(abs(from_tile.x - to_tile.x) + abs(from_tile.y - to_tile.y))
