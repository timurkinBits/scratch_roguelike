extends AbstractCharacter
class_name Player

var defense: int = 0

@onready var hp_bar = $"../../UI"
@onready var command_executor = $"../../Table/TurnExecutor"
@onready var sprites = {
		"right": $SpriteRight,
		"left": $SpriteLeft,
		"up": $SpriteUp,
		"down": $SpriteDown
	}

func _ready() -> void:
	hp = 10
	
	super._ready()
	update_visual()

func move(value: int) -> void:
	if is_dead:
		return
	
	var current_tile = get_tile_position()
	
	for _i in value:
		var direction_vector = DIRECTION_VECTORS[current_direction]
		var next_tile = current_tile + direction_vector
		
		if not can_move_to_tile(next_tile):
			break
		
		var target_pos = get_world_position_from_tile(next_tile)
		await animate_movement(target_pos)
		current_tile = next_tile
		
# Анимация движения
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

# Изменяет значения здоровья у игрока
func take_damage(damage_amount: int) -> void:
	hp_bar.hp_change(-damage_amount)
	hp = ceil(hp_bar.current_health / 10)
	
	super.take_damage(damage_amount)
	
func add_defense(defense_amount: int):
	await hp_bar.add_defense(defense_amount)
	defense = ceil(hp_bar.current_defense / 10)

func add_hp(heal_amount: int):
	await hp_bar.hp_change(heal_amount)
	hp = ceil(hp_bar.current_health / 10)
	
# Переопределение анимации смерти
func play_death_animation() -> void:
	if sprites is Array:
		for sprite_key in sprites:
			if sprites[sprite_key]:
				sprites[sprite_key].stop()
	super.play_death_animation()

# Обновление видимости и анимации спрайтов
func update_visual() -> void:
	for sprite in sprites.keys():
		if sprites[sprite]:
			sprites[sprite].visible = false
	
	if current_direction in sprites and sprites[current_direction]:
		sprites[current_direction].visible = true
		
		if is_moving:
			sprites[current_direction].play("walk")
		else:
			sprites[current_direction].play("idle")
			
# Поворот игрока
func turn(turn_type: String) -> void:
	if is_dead:
		return
	
	var new_direction = current_direction
	
	match turn_type:
		"left":
			match current_direction:
				"up":    new_direction = "left"
				"down":  new_direction = "right"
				"left":  new_direction = "down"
				"right": new_direction = "up"
		"right":
			match current_direction:
				"up":    new_direction = "right"
				"down":  new_direction = "left"
				"left":  new_direction = "up"
				"right": new_direction = "down"
		"around":
			match current_direction:
				"up":    new_direction = "down"
				"down":  new_direction = "up"
				"left":  new_direction = "right"
				"right": new_direction = "left"
	
	if new_direction != current_direction:
		current_direction = new_direction
		update_visual()
	await get_tree().create_timer(0.3).timeout

# Атака игрока
func attack(damage_value: int) -> void:
	if is_dead:
		return
	
	await animate_attack()
	
	# Получение целевой клетки для атаки
	var player_tile = get_tile_position()
	var attack_tile = player_tile + DIRECTION_VECTORS[current_direction]
	
	# Поиск врагов
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.get_tile_position() == attack_tile:
			enemy.take_damage(damage_value)
			break
	
	await get_tree().create_timer(0.55).timeout

# Использовать предмет или объект
func use() -> void:
	if is_dead:
		return
	
	# Получаем клетку перед игроком
	var player_tile = get_tile_position()
	var interact_tile = player_tile + DIRECTION_VECTORS[current_direction]
	
	for object in get_tree().get_nodes_in_group("objects"):
		if is_instance_valid(object) and object.get_tile_position() == interact_tile:
			if object.has_method('use'):
				object.use()
				break
	
	# Анимация использования
	var animation_tween = create_tween()
	animation_tween.tween_property(self, "scale", Vector2(2.8, 2.8), 0.1)
	animation_tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.1)
	await animation_tween.finished
	
	await get_tree().create_timer(0.2).timeout
