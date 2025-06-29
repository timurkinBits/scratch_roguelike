extends AbstractMenu

func _ready() -> void:
	add_to_group("special_command_menu")
	max_slots = Global.max_slots_for_commands
	super._ready()

# Переопределение абстрактных методов

func get_purchased_items() -> Array:
	return Global.get_all_purchased_special_commands()

func can_use_item(item_id: String) -> bool:
	# Проверка базовых условий
	if not Global.can_use_special_command(item_id) or Global.is_special_command_consumed(item_id):
		return false
	
	# Проверка очков для команд со значениями
	var command_data = Global.get_special_command_data(item_id)
	if command_data.has("type"):
		var special_data = ItemData.get_special_command_data(command_data.type)
		if not special_data.is_empty() and special_data.has_value:
			return Global.has_available_special_points(item_id)
	
	return true

func create_item_in_slot(item_data: Dictionary, slot_index: int) -> Node:
	# Создание команды
	var command_scene = load("res://scenes/Command.tscn")
	var command = command_scene.instantiate()
	
	# Настройка как особая команда
	var special_script = preload("res://scripts/cards/special_command.gd")
	command.set_script(special_script)
	
	command.special_id = item_data.id
	command.special_type = item_data.type
	command.type = Command.TypeCommand.get("NONE", -1)
	command.is_menu_card = true
	
	# Настройка значений
	var special_data = ItemData.get_special_command_data(item_data.type)
	command.has_value = special_data.get("has_value", true) if not special_data.is_empty() else true
	command.value = 0 if command.has_value else 1
	
	command.call_deferred("update_appearance")
	return command

func create_item_copy_on_table(item_data: Dictionary) -> void:
	table_node.create_special_command_copy(item_data)

func reset_all_items() -> void:
	Global.reset_special_commands()

# Настройка сигналов и расстояния

func get_inventory_signal() -> String:
	return "special_command_availability_changed"

func get_availability_signal() -> String:
	return "special_command_availability_changed"

func get_slot_spacing() -> float:
	return 80.0
