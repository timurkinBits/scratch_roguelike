extends AbstractMenu

# ИСПРАВЛЕНО: Подключаемся к сигналу изменения очков
func _ready() -> void:
	add_to_group("special_command_menu")
	max_slots = Global.max_slots_for_commands
	super._ready()
	
	# Подключаемся к сигналу покупки новых команд
	Global.inventory_changed.connect(_on_inventory_changed)
	# ИСПРАВЛЕНО: Подключаемся к сигналу изменения очков
	Global.points_changed.connect(_on_points_changed)

# Обработчик покупки новых особых команд
func _on_inventory_changed() -> void:
	refresh_menu()

# ИСПРАВЛЕНО: Обработчик изменения очков
func _on_points_changed() -> void:
	update_all_availability()

# Переопределяем абстрактные методы для работы с особыми командами

func get_purchased_items() -> Array:
	return Global.get_all_purchased_special_commands()

# ИСПРАВЛЕНО: Переопределяем can_use_item с учетом очков
func can_use_item(item_id: String) -> bool:
	var basic_availability = Global.can_use_special_command(item_id) and not Global.is_special_command_consumed(item_id)
	
	# Для команд со значениями также проверяем наличие очков
	var command_data = Global.get_special_command_data(item_id)
	if not command_data.is_empty() and command_data.has("type"):
		var special_data = ItemData.get_special_command_data(command_data.type)
		if not special_data.is_empty() and special_data.has_value:
			return basic_availability and Global.has_available_special_points(item_id)
	
	return basic_availability

func use_item(item_id: String) -> bool:
	return Global.use_special_command(item_id)

func reset_all_items() -> void:
	Global.reset_special_commands()

func create_item_in_slot(item_data: Dictionary, slot_index: int) -> Node:
	var command_scene = load("res://scenes/Command.tscn")
	var command = command_scene.instantiate()
	
	# Заменяем скрипт на SpecialCommand
	var special_script = preload("res://scripts/cards/special_command.gd")
	command.set_script(special_script)
	
	# ИСПРАВЛЕНО: Устанавливаем специальный тип вместо обычного
	command.special_id = item_data.id
	command.special_type = item_data.type  # Тип особой команды из ItemData
	command.type = Command.TypeCommand.NONE if Command.TypeCommand.has("NONE") else -1  # Нейтральный тип
	command.is_menu_card = true
	
	# Проверяем, есть ли у команды изменяемое значение
	var special_data = ItemData.get_special_command_data(item_data.type)
	if not special_data.is_empty():
		command.has_value = special_data.has_value
	else:
		command.has_value = true  # По умолчанию
	
	# ИСПРАВЛЕНО: Устанавливаем начальное значение 0 для команд со значениями
	if command.has_value:
		command.value = 0
	else:
		command.value = 1  # Для команд без значений оставляем 1
	
	# Обновляем внешний вид после добавления в дерево сцены
	command.call_deferred("update_appearance")
	
	return command

func create_item_copy_on_table(item_data: Dictionary) -> void:
	table_node.create_special_command_copy(item_data)

# Правильные имена сигналов
func get_inventory_changed_signal() -> String:
	return "special_command_availability_changed"

func get_availability_changed_signal() -> String:
	return "special_command_availability_changed"

func get_slot_vertical_spacing() -> float:
	return 80.0

# ИСПРАВЛЕНО: Обновляем доступность всех команд
func update_all_availability() -> void:
	super.update_all_availability()

# Публичные методы для совместимости с существующим кодом
func refresh_menu() -> void:
	super.refresh_menu()

func reset_all_special_commands() -> void:
	reset_all_items_and_update()
