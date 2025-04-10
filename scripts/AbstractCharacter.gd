extends ObjectRoom
class_name AbstractCharacter

# Общие свойства
var is_dead: bool = false
var current_direction: String = "up"
var hp: int = 1  # Базовое здоровье
var is_moving: bool = false  # Общее свойство для отслеживания движения

# Векторы направлений
const DIRECTION_VECTORS := {
	"up": Vector2.UP,
	"down": Vector2.DOWN,
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT
}

func _ready() -> void:
	super._ready()
	remove_from_group('objects')
	add_to_group("barrier")

# Проверка, может ли персонаж переместиться на указанную клетку
func can_move_to_tile(next_tile: Vector2) -> bool:
	if not tilemap.get_used_rect().has_point(next_tile):
		return false
	
	for barrier in get_tree().get_nodes_in_group("barrier"):
		if barrier.get_tile_position() == next_tile:
			return false
	
	return true

# Обработка смерти
func dead() -> void:
	if is_dead:
		return
	is_dead = true
	play_death_animation()

# Анимация смерти (может быть переопределена)
func play_death_animation() -> void:
	var death_tween = create_tween()
	death_tween.tween_property(self, "modulate", Color(1, 0, 0, 1), 0.2)
	death_tween.tween_property(self, "modulate", Color(1, 0, 0, 0), 0.3)
	death_tween.parallel().tween_property(self, "scale", Vector2(0.1, 0.1), 0.5)
	death_tween.parallel().tween_property(self, "rotation_degrees", 180, 0.5)
	await death_tween.finished
	queue_free()

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
	var tween = create_tween()
	tween.tween_property(self, "position", position + DIRECTION_VECTORS[current_direction] * 15 * tilemap.scale.x, 0.1)
	tween.tween_property(self, "position", position, 0.1)
	await tween.finished
