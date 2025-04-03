extends Control
class_name EnemyStats

@onready var heal_points: Control = $heal_points
@export var hp_scene: PackedScene

var current_hp_nodes = []
var tracked_enemy: Enemy = null  # Переменная для отслеживания текущего врага
var total_width: float = 0.0    # Общая ширина полосы здоровья

func _ready() -> void:
	heal_points.visible = false

func reset_hp(count: int):
	# Очищаем существующие HP-ноды
	for node in current_hp_nodes:
		if is_instance_valid(node):
			node.queue_free()
	current_hp_nodes.clear()
	
	# Сбрасываем позицию контейнера
	heal_points.position = Vector2.ZERO
	
	# Создаем новые HP-ноды
	for i in range(count):
		var hp_instance = hp_scene.instantiate()
		heal_points.add_child(hp_instance)
		hp_instance.position.x = i * 13  # Позиция каждого индикатора
		current_hp_nodes.append(hp_instance)
	
	# Вычисляем общую ширину полосы здоровья
	if count > 0:
		var last_hp = current_hp_nodes[-1]
		total_width = last_hp.position.x + last_hp.size.x
	else:
		total_width = 0.0

func sub_hp(remaining_to_remove: int):
	while remaining_to_remove > 0 and not current_hp_nodes.is_empty():
		var node_to_remove = current_hp_nodes.pop_back()
		if is_instance_valid(node_to_remove):
			node_to_remove.queue_free()
		remaining_to_remove -= 1
	# Пересчитываем ширину после удаления
	if current_hp_nodes.size() > 0:
		var last_hp = current_hp_nodes[-1]
		total_width = last_hp.position.x + last_hp.size.x
	else:
		total_width = 0.0

func change_stats(enemy: Enemy, is_selected: bool):
	if is_selected:
		tracked_enemy = enemy   # Начинаем отслеживать врага
		heal_points.visible = true
		reset_hp(enemy.hp)
	else:
		if tracked_enemy == enemy:  # Добавьте эту проверку
			tracked_enemy = null
			heal_points.visible = false

func _process(_delta: float) -> void:
	if tracked_enemy != null and is_instance_valid(tracked_enemy):
		# Позиционируем полосу над врагом с центрированием
		var enemy_pos = tracked_enemy.global_position + tracked_enemy.hp_bar_offset + Vector2(2, 0)
		global_position = enemy_pos - Vector2(total_width / 2, 0)
