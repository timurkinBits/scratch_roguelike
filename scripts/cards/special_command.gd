extends Command
class_name SpecialCommand

var special_id: String = ""
var has_value: bool = true
var special_type: int = -1

func _ready() -> void:
	super._ready()
	add_to_group("special_commands")

func get_special_id() -> String:
	return special_id

func get_command_type() -> int:
	return Command.TypeCommand.NONE

# ИЗМЕНЕНО: Получить текущее максимальное значение (может быть уменьшено)
func get_max_value() -> int:
	if special_type != -1:
		# Используем текущий максимум вместо изначального
		return Global.get_current_max_special_points(special_id)
	return 1

# Обработка событий мыши
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click()
		else:
			super._on_area_2d_input_event(viewport, event, shape_idx)
	else:
		super._on_area_2d_input_event(viewport, event, shape_idx)

func _handle_right_click() -> void:
	if not is_menu_card and not table.is_turn_in_progress:
		# Освобождаем очки если есть
		if special_id != "" and has_value and value > 0:
			Global.release_special_points(special_id, value)
		
		# Освобождаем команду
		if special_id != "":
			if has_value:
				Global.release_special_command(special_id)
			else:
				Global.consume_special_command(special_id)
		
		queue_free()

# Обновление внешнего вида
func update_appearance() -> void:
	if not sprite or not text_label or not num_label:
		return
	
	if special_type != -1:
		var special_data = ItemData.get_special_command_data(special_type)
		if special_data.is_empty():
			_set_unknown_appearance()
			return
		
		# Проверяем доступность для меню
		var is_available = true
		if is_menu_card:
			is_available = (Global.can_use_special_command(special_id) and 
						   not Global.is_special_command_consumed(special_id))
			if has_value:
				# ИЗМЕНЕНО: Проверяем текущий максимум
				is_available = is_available and Global.get_current_max_special_points(special_id) > 0
		
		# Устанавливаем текстуру
		if ResourceLoader.exists(special_data.icon):
			sprite.texture = load(special_data.icon)
		
		# Устанавливаем цвет
		if special_data.has("color"):
			if is_available or not is_menu_card:
				sprite.modulate = special_data.color
			else:
				sprite.modulate = special_data.color * Color(0.5, 0.5, 0.5, 0.7)
		
		# Устанавливаем текст
		text_label.text = special_data.name
		text_label.modulate = Color.WHITE if (is_available or not is_menu_card) else Color.GRAY
		
		# ИЗМЕНЕНО: Показываем текущий максимум для меню карт
		if has_value and special_data.has_value:
			if is_menu_card:
				# Показываем текущий максимум в меню
				var current_max = Global.get_current_max_special_points(special_id)
				if current_max > 0:
					num_label.text = str(current_max)
					num_label.visible = true
					num_label.modulate = Color.WHITE if is_available else Color.GRAY
				else:
					num_label.visible = false
			else:
				num_label.text = str(value)
				num_label.visible = true
				num_label.modulate = Color.WHITE
		else:
			num_label.visible = false
	else:
		_set_unknown_appearance()

func _set_unknown_appearance() -> void:
	sprite.texture = null
	sprite.modulate = Color.GRAY
	text_label.text = "НЕИЗВЕСТНО"
	text_label.modulate = Color.WHITE
	num_label.visible = false

# Обработка кнопок
func _on_up_pressed() -> void:
	if not has_value:
		return
	
	var max_value = get_max_value()
	var remaining_points = Global.get_remaining_special_points(special_id)
	var max_available = remaining_points + value
	
	var new_value = min(value + 1, max_available, max_value)
	if new_value > value:
		set_number(new_value)
	
	_update_special_buttons()

func _on_down_pressed() -> void:
	if not has_value:
		return
	
	if value > 0:
		set_number(value - 1)
	
	_update_special_buttons()

func _update_special_buttons() -> void:
	if not has_value or not is_settings:
		up_button.visible = false
		down_button.visible = false
		return
	
	var max_value = get_max_value()
	var remaining_points = Global.get_remaining_special_points(special_id)
	var max_available = remaining_points + value
	
	up_button.disabled = (value >= max_available) or (value >= max_value)
	down_button.disabled = (value <= 0)

# Установка значения
func set_number(new_value: int) -> void:
	if not has_value:
		return
	
	# Освобождаем текущие очки
	if not is_menu_card and value > 0:
		Global.release_special_points(special_id, value)
	
	# Вычисляем новое значение
	var remaining_points = Global.get_remaining_special_points(special_id)
	var max_value = get_max_value()
	value = clamp(new_value, 0, min(remaining_points, max_value))
	
	# Тратим новые очки
	if not is_menu_card and value > 0:
		Global.use_special_points(special_id, value)
	
	# Обновляем отображение
	if value > 0:
		num_label.text = str(value)
		num_label.visible = true
	else:
		num_label.visible = false
	
	if is_settings:
		_update_special_buttons()

# Обработка клика по числу
func _on_num_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not has_value:
		return
	
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and 
		event.pressed and not is_menu_card and not table.is_turn_in_progress):
		is_settings = not is_settings
		change_settings(is_settings)
		_update_special_buttons()

func change_settings(settings: bool) -> void:
	if not has_value:
		up_button.visible = false
		down_button.visible = false
		return
	
	up_button.visible = settings
	down_button.visible = settings
	
	if settings:
		_update_special_buttons()

# Обработка левого клика
func _handle_left_click() -> void:
	if is_menu_card:
		# Проверяем доступность
		if (not Global.can_use_special_command(special_id) or 
			Global.is_special_command_consumed(special_id)):
			return
		
		# ИЗМЕНЕНО: Проверяем текущий максимум для команд со значениями
		if has_value:
			var current_max = Global.get_current_max_special_points(special_id)
			if current_max <= 0:
				return
		
		# Проверяем наличие очков для команд со значениями
		if has_value and not Global.has_available_special_points(special_id):
			return
	else:
		if not has_value:
			is_settings = false
		change_settings(is_settings)
