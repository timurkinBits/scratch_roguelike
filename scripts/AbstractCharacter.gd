extends Node2D
class_name AbstractCharacter

# Общие свойства
var is_dead: bool = false
var current_direction: String = "up"
var tilemap: TileMapLayer
var hp: int = 1  # Базовое здоровье
var is_moving: bool = false  # Общее свойство для отслеживания движения

# Векторы направлений
const DIRECTION_VECTORS := {
	"up": Vector2.UP,
	"down": Vector2.DOWN,
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT
}

# Словарь для хранения спрайтов направлений (будет заполняться в дочерних классах)
var sprites

func _ready() -> void:
	tilemap = get_parent().get_node("TileMapLayer")
	if not tilemap:
		push_error("TileMapLayer not found!")
		return
	
	# Выравнивание начальной позиции по центру ближайшей клетки
	var tile_pos = get_tile_position()
	position = get_world_position_from_tile(tile_pos)
	update_visual()  # Инициализация визуального представления

# Проверка, может ли персонаж переместиться на указанную клетку
func can_move_to_tile(next_tile: Vector2) -> bool:
	# Проверка границ тайлмапа
	if not tilemap.get_used_rect().has_point(next_tile):
		return false
	
	# Проверка барьеров
	var barrier_group = get_tree().get_nodes_in_group("barrier")
	for barrier in barrier_group:
		if barrier.get_tile_position() == next_tile:
			return false
	
	# Проверка других персонажей
	var all_characters = get_tree().get_nodes_in_group("characters")
	for character in all_characters:
		if character != self and is_instance_valid(character):
			if character.get_tile_position() == next_tile:
				# Если это враг и текущий персонаж тоже враг, то блокируем движение
				if (character is Enemy and self is Enemy):
					return false
				# Для игрока блокируем движение на любого персонажа
				if self is Player:
					return false
	
	return true

# Проверка, можно ли выполнить действие
func should_skip_action() -> bool:
	return is_dead || !is_instance_valid(self) || !is_inside_tree()

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

# Обработка смерти
func dead() -> void:
	if should_skip_action():
		return
	is_dead = true
	play_death_animation()

# Анимация смерти (может быть переопределена)
func play_death_animation() -> void:
	if sprites is Array:
		for sprite_key in sprites:
			if sprites[sprite_key]:
				sprites[sprite_key].stop()
			
	var death_tween = create_tween()
	death_tween.tween_property(self, "modulate", Color(1, 0, 0, 1), 0.2)
	death_tween.tween_property(self, "modulate", Color(1, 0, 0, 0), 0.3)
	death_tween.parallel().tween_property(self, "scale", Vector2(0.1, 0.1), 0.5)
	death_tween.parallel().tween_property(self, "rotation_degrees", 180, 0.5)
	await death_tween.finished
	queue_free()
	remove_from_group('characters')
	remove_from_group('enemies')

# Получение урона
func take_damage(_damage_amount: int) -> void:
	if is_dead:
		return
	
	var hit_tween = create_tween()
	hit_tween.tween_property(self, "modulate", Color(1, 0.5, 0.5), 0.1)
	hit_tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

	if hp <= 0:
		dead()

# Анимация атаки
func animate_attack() -> void:
	var original_pos = position
	var attack_pos = position + DIRECTION_VECTORS[current_direction] * 15 * tilemap.scale.x
	var tween = create_tween()
	tween.tween_property(self, "position", attack_pos, 0.1)
	tween.tween_property(self, "position", original_pos, 0.1)
	await tween.finished

# Преобразование координат
func get_tile_position() -> Vector2:
	var local_pos = position / tilemap.scale
	return tilemap.local_to_map(local_pos)

func get_world_position_from_tile(tile_pos: Vector2) -> Vector2:
	var local_center = tilemap.map_to_local(tile_pos)
	return local_center * tilemap.scale

# Расчет расстояния Манхэттена между тайлами
func calculate_path_length(from_tile: Vector2, to_tile: Vector2) -> int:
	return int(abs(from_tile.x - to_tile.x) + abs(from_tile.y - to_tile.y))
