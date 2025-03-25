extends AbstractCharacter
class_name Player

# Direction-specific sprites
@onready var sprites: Dictionary = {
	"right": $SpriteRight,
	"left": $SpriteLeft,
	"up": $SpriteUp,
	"down": $SpriteDown
}

# Movement tracking
var is_moving: bool = false

# Health bar reference
@onready var hp_bar = $"../../UI"

func _ready() -> void:
	hp = 10  # Player-specific starting health
	add_to_group("characters")  # Добавление в группу персонажей
	super._ready()
	update_visual()

# Переопределение метода move для обновления визуала
func move(value: int) -> void:
	if should_skip_action():
		return
	
	is_moving = true
	update_visual()
	
	await super.move(value)
	
	is_moving = false
	update_visual()

# Обновление видимости и анимации спрайтов
func update_visual() -> void:
	for sprite in sprites.keys():
		sprites[sprite].visible = false
	
	sprites[current_direction].visible = true
	
	if is_moving:
		sprites[current_direction].play("walk")
	else:
		sprites[current_direction].play("idle")

# Изменяет значения здоровья у игрока с анимацией получения урона
func take_damage(damage_amount: int) -> void:
	if is_dead:
		return
	
	hp_bar.hp_change(-damage_amount)
	hp = hp_bar.current_health / 10.0
	
	var hit_tween = create_tween()
	hit_tween.tween_property(self, "modulate", Color(1, 0.5, 0.5), 0.1)
	hit_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

# Переопределение анимации смерти
func play_death_animation() -> void:
	for sprite_key in sprites:
		sprites[sprite_key].stop()
	super.play_death_animation()

# Поворот игрока
func turn(turn_type: String) -> void:
	if should_skip_action():
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
	if should_skip_action():
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
	
	await get_tree().create_timer(0.3).timeout
