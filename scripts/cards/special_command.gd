extends Command
class_name SpecialCommand

# Уникальный ID особой команды
var special_id: String = ""
var has_value: bool = true
var special_type: int = -1  # Тип особой команды из ItemData

func _ready() -> void:
	super._ready()
	add_to_group("special_commands")

# Добавляем метод для получения special_id (для совместимости)
func get_special_id() -> String:
	return special_id

# Переопределяем метод получения типа для особых команд
func get_command_type() -> int:
	# Особые команды всегда возвращают NONE, чтобы не конфликтовать с обычными
	return Command.TypeCommand.NONE if Command.TypeCommand.has("NONE") else -1

# Получить максимальное значение для данной особой команды
func get_max_value() -> int:
	if special_type != -1:
		var special_data = ItemData.get_special_command_data(special_type)
		if not special_data.is_empty() and special_data.has("max_value"):
			return special_data.max_value
	return 1  # По умолчанию максимум 1

# Переопределяем метод обработки правого клика
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click()
		else:
			# Передаем другие события родительскому классу
			super._on_area_2d_input_event(viewport, event, shape_idx)
	else:
		super._on_area_2d_input_event(viewport, event, shape_idx)

func _handle_right_click() -> void:
	if not is_menu_card and not table.is_turn_in_progress:
		# Для особых команд с очками - освобождаем очки только если value > 0
		if special_id != "" and has_value and value > 0:
			Global.release_special_points(special_id, value)
		
		# Освобождаем саму команду
		if special_id != "":
			if has_value:
				Global.release_special_command(special_id)
			else:
				Global.consume_special_command(special_id)
		
		queue_free()

# Переопределяем обновление внешнего вида для особых команд
func update_appearance() -> void:
	# Проверяем что все узлы существуют перед вызовом родительского метода
	if not sprite or not text_label or not num_label:
		return
	
	# Для особых команд используем данные из ItemData
	if special_type != -1:
		var special_data = ItemData.get_special_command_data(special_type)
		if not special_data.is_empty():
			# Устанавливаем текстуру
			if ResourceLoader.exists(special_data.icon):
				sprite.texture = load(special_data.icon)
			
			# ИСПРАВЛЕНО: Проверяем доступность команды только для команд в меню
			var is_available = true
			if is_menu_card:
				is_available = Global.can_use_special_command(special_id) and not Global.is_special_command_consumed(special_id)
				# Для команд со значениями также проверяем наличие очков
				if has_value:
					is_available = is_available and Global.has_available_special_points(special_id)
			
			# Устанавливаем цвет с учетом доступности
			if special_data.has("color"):
				if is_available or not is_menu_card:
					# Команды на столе всегда имеют нормальный цвет
					sprite.modulate = special_data.color
				else:
					# Делаем недоступные команды в меню серыми и прозрачными
					sprite.modulate = special_data.color * Color(0.5, 0.5, 0.5, 0.7)
			
			# Устанавливаем текст
			if text_label:
				text_label.text = special_data.name
				if is_menu_card:
					text_label.modulate = Color.WHITE if is_available else Color.GRAY
				else:
					text_label.modulate = Color.WHITE
			
			# Устанавливаем значение, если есть
			if has_value and special_data.has_value and num_label:
				# ИСПРАВЛЕНО: для меню карт не показываем значение
				if is_menu_card:
					num_label.visible = false
				else:
					num_label.text = str(value)
					num_label.visible = true
					num_label.modulate = Color.WHITE
			elif num_label:
				num_label.visible = false
			
			return
	
	# Если не удалось определить тип - делаем нейтральной
	if sprite:
		sprite.texture = null
		sprite.modulate = Color.GRAY
	if text_label:
		text_label.text = "НЕИЗВЕСТНО"
		text_label.modulate = Color.WHITE
	if num_label:
		num_label.visible = false

# Переопределяем логику кнопок для особых команд с учетом очков
func _on_up_pressed() -> void:
	if !has_value:
		return
	
	var max_value = get_max_value()
	var remaining_points = Global.get_remaining_special_points(special_id)
	var max_available = remaining_points + value  # Текущие очки + уже потраченные на эту команду
	
	var new_value = min(value + 1, max_available, max_value)
	if new_value > value:
		set_number(new_value)
	
	_update_special_buttons()

func _on_down_pressed() -> void:
	if !has_value:
		return
	
	if value > 0:  # ИСПРАВЛЕНО: теперь можно уменьшить до 0
		set_number(value - 1)
	
	_update_special_buttons()

# Обновление состояния кнопок для особых команд
func _update_special_buttons() -> void:
	if !has_value:
		up_button.visible = false
		down_button.visible = false
		return
	
	if not is_settings:
		return
	
	var max_value = get_max_value()
	var remaining_points = Global.get_remaining_special_points(special_id)
	var max_available = remaining_points + value
	
	up_button.disabled = (value >= max_available) or (value >= max_value)
	down_button.disabled = (value <= 0)  # ИСПРАВЛЕНО: можно уменьшить до 0

# ИСПРАВЛЕНО: Установка значения с учетом системы очков (как у обычных команд)
func set_number(new_value: int) -> void:
	if !has_value:
		return
	
	# Освобождаем текущие очки (если они были потрачены)
	if not is_menu_card and value > 0:
		Global.release_special_points(special_id, value)
	
	# Вычисляем доступные очки
	var remaining_points = Global.get_remaining_special_points(special_id)
	var max_value = get_max_value()
	
	# ИСПРАВЛЕНО: устанавливаем значение от 0 до максимума
	value = clamp(new_value, 0, min(remaining_points, max_value))
	
	# Тратим новые очки (только если значение больше 0)
	if not is_menu_card and value > 0:
		Global.use_special_points(special_id, value)
	
	# Обновляем отображение
	if num_label:
		if value > 0:
			num_label.text = str(value)
			num_label.visible = true
		else:
			num_label.visible = false
	
	if is_settings:
		_update_special_buttons()

# Переопределяем логику настроек
func _on_num_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if !has_value:
		return
	
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and 
		event.pressed and not is_menu_card and not table.is_turn_in_progress):
		is_settings = not is_settings
		change_settings(is_settings)
		_update_special_buttons()

func change_settings(settings: bool) -> void:
	if !has_value:
		up_button.visible = false
		down_button.visible = false
		return
	
	up_button.visible = settings
	down_button.visible = settings
	
	if settings:
		_update_special_buttons()

# ИСПРАВЛЕНО: Переопределяем обработку левого клика с проверкой доступности
func _handle_left_click() -> void:
	if is_menu_card:
		# Проверяем доступность команды
		if not Global.can_use_special_command(special_id) or Global.is_special_command_consumed(special_id):
			# Команда недоступна - ничего не делаем
			return
		
		# Для команд со значениями проверяем наличие очков
		if has_value and not Global.has_available_special_points(special_id):
			# Нет доступных очков - ничего не делаем
			return
		
		# Для особых команд в меню нужно использовать специальную логику
		# (здесь может быть логика создания особой команды)
		pass
	else:
		# Для команд без значений просто отключаем настройки
		if !has_value:
			is_settings = false
		change_settings(is_settings)

func _exit_tree() -> void:
	super._exit_tree()
