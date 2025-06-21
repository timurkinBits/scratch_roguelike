extends Enemy
class_name BerserkerEnemy

# Настройки ярости
var is_enraged: bool = false
var rage_duration: int = 0
var max_rage_duration: int = 3
var rage_damage_bonus: int = 3
var rage_speed_bonus: int = 2
var original_damage: int
var original_speed: int

# Цвета для берсерка
var color: Color = Color(0.8, 0.3, 0.3, 1.0)  # Темно-красный
var rage_color: Color = Color(1.5, 0.2, 0.2, 1.0)      # Ярко-красный
var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)

func initialize_special_enemy() -> void:
	has_special_ability = true
	max_ability_cooldown = 6
	ability_cooldown = 0
	
	# Сохраняем оригинальные значения
	original_damage = damage
	original_speed = speed
	
	# Базовые характеристики чуть слабее, чтобы компенсировать ярость
	damage = max(damage - 3, 1)
	
	# Увеличиваем HP для танковости
	heal_points += 2
	hp += 2
	
	# Устанавливаем цвет берсерка
	modulate = color

func can_use_special_ability() -> bool:
	if not super.can_use_special_ability():
		return false
	
	# Используем ярость при низком HP
	var low_health = hp <= heal_points * 0.5
	
	return low_health

func use_special_ability() -> void:
	reset_ability_cooldown()
	await activate_rage()

func activate_rage() -> void:
	is_enraged = true
	rage_duration = max_rage_duration
	
	# Применяем бонусы ярости
	damage = original_damage + rage_damage_bonus
	speed = original_speed + rage_speed_bonus
	
	# Эффект активации ярости с встроенными анимациями
	await play_rage_activation_effect()

func take_turn() -> void:
	# Проверяем состояние ярости в начале хода
	if is_enraged:
		rage_duration -= 1
		if rage_duration <= 0:
			deactivate_rage()
	
	# Обычная логика хода
	await super.take_turn()

func deactivate_rage() -> void:
	if not is_enraged:
		return
		
	is_enraged = false
	
	# Возвращаем оригинальные характеристики
	damage = original_damage
	speed = original_speed
	
	# Эффект окончания ярости
	play_rage_deactivation_effect()

func play_rage_activation_effect() -> void:
	# Создаем комплексную анимацию активации ярости
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 1. Быстрое мигание красным
	for i in range(3):
		tween.tween_property(self, "modulate", rage_color, 0.1)
		tween.tween_property(self, "modulate", color, 0.1)
	
	# 2. Увеличение размера с "взрывом"
	var original_scale = scale
	tween.tween_property(self, "scale", original_scale * 1.3, 0.2)
	tween.tween_property(self, "scale", original_scale * 1.1, 0.3)
	
	# 3. Вращение с затуханием
	tween.tween_property(self, "rotation_degrees", 15, 0.1)
	tween.tween_property(self, "rotation_degrees", -15, 0.1)
	tween.tween_property(self, "rotation_degrees", 10, 0.1)
	tween.tween_property(self, "rotation_degrees", 0, 0.2)
	
	# 4. Дрожание
	var original_pos = position
	for i in range(6):
		var shake_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		tween.tween_property(self, "position", original_pos + shake_offset, 0.05)
	tween.tween_property(self, "position", original_pos, 0.1)
	
	# 5. Финальная вспышка
	tween.tween_property(self, "modulate", Color(2.0, 0.5, 0.5, 1.2), 0.1)
	tween.tween_property(self, "modulate", rage_color, 0.2)
	
	await tween.finished

func play_rage_deactivation_effect() -> void:
	# Плавное окончание ярости
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Постепенное затухание цвета и размера
	tween.tween_property(self, "modulate", color, 1.0)
	tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.8)
	
	# Легкое дрожание при истощении
	var original_pos = position
	for i in range(3):
		var shake_offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		tween.tween_property(self, "position", original_pos + shake_offset, 0.2)
	tween.tween_property(self, "position", original_pos, 0.2)

func take_damage(damage_amount: int):
	super.take_damage(damage_amount)
	
	# Эффект получения урона для берсерка
	if not is_dead:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		if is_enraged:
			tween.tween_property(self, "modulate", rage_color, 0.2)
		else:
			tween.tween_property(self, "modulate", color, 0.2)
	
	# Берсерк может впасть в ярость при получении урона
	if not is_enraged and hp <= heal_points * 0.3 and is_ability_ready():
		# Немедленная активация ярости при критическом HP
		ability_cooldown = 0

func update_visual() -> void:
	super.update_visual()
	
	# Дополнительные визуальные эффекты во время ярости
	if is_enraged:
		# Красноватый оттенок и немного больший размер
		if modulate != rage_color:
			modulate = rage_color
			
		# Постоянное легкое дрожание в ярости
		if not is_moving:
			var shake_tween = create_tween()
			shake_tween.set_loops()
			var base_pos = position
			shake_tween.tween_property(self, "position", base_pos + Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.1)
			shake_tween.tween_property(self, "position", base_pos, 0.1)
	else:
		# Обычный вид берсерка
		if modulate != color:
			modulate = color

#func get_enemy_type() -> String:
	## Переопределяем для уникального внешнего вида
	#if is_enraged:
		#return "berserker_enemy_enraged"
	#return "berserker_enemy"

func dead():
	# При смерти снимаем эффекты ярости и играем анимацию смерти
	if is_enraged:
		deactivate_rage()

	super.dead()
