extends Control
class_name EnemyStats

@onready var heal_points: Control = $heal_points
@onready var speed_label: Label = $SpeedLabel
@onready var damage_label: Label = $DamageLabel
@export var hp_scene: PackedScene

var current_hp_nodes = []

func _ready() -> void:
	heal_points.visible = false
	
# Устанавливает начальное количество HP, создавая нужное количество HP-сцен
func reset_hp(count: int):
	# Сначала очищаем все существующие HP-ноды
	for node in current_hp_nodes:
		if is_instance_valid(node):
			node.queue_free()
	
	current_hp_nodes.clear()
	
	# Сбрасываем позицию контейнера
	heal_points.position = Vector2.ZERO
	
	# Создаем новые HP-ноды в нужном количестве
	for i in range(count):
		var hp_instance = hp_scene.instantiate()
		heal_points.add_child(hp_instance)
		# Устанавливаем позицию каждого индикатора HP относительно предыдущего
		hp_instance.position.x = i * 32  # вместо изменения позиции контейнера
		current_hp_nodes.append(hp_instance)

# Уменьшает здоровье, удаляя указанное количество HP-нод справа
func sub_hp(remaining_to_remove: int):
	# Удаляем HP-ноды справа налево
	while remaining_to_remove > 0 and not current_hp_nodes.is_empty():
		var node_to_remove = current_hp_nodes.pop_back()  # Берем последний элемент (самый правый)
		if is_instance_valid(node_to_remove):
			node_to_remove.queue_free()
		remaining_to_remove -= 1
		
# Показывает статистику врага (здоровье)
func change_stats(enemy: Enemy, is_selected: bool):
	if is_selected:
		heal_points.visible = true
		reset_hp(enemy.hp)
		speed_label.text = "Скорость: " + str(enemy.speed)
		damage_label.text = "Урон: " + str(enemy.damage)
	else:
		heal_points.visible = false
		speed_label.text = ''
		damage_label.text = ''
