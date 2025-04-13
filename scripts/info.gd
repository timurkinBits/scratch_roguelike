extends ObjectRoom
class_name Info

@onready var info: Label = $Label
@onready var key_edit: LineEdit = $LineEdit

var key: int = 0
var linked_item: Item  # Прямая ссылка на связанный предмет

func _ready() -> void:
	super._ready()
	add_to_group('info')
	key_edit.visible = false
	key_edit.text = ""
	call_deferred("find_and_link_item")  # Найти и связаться с предметом после того, как сцена полностью загрузится

# Поиск и связывание с предметом по ключу
func find_and_link_item() -> void:
	if key > 0 and !linked_item:
		for item in get_tree().get_nodes_in_group('items'):
			if item.key == key:
				link_with_item(item)
				break

# Установка связи с предметом
func link_with_item(item: Item) -> void:
	if !linked_item:  # Проверка что связь устанавливается только один раз
		linked_item = item
		item.link_with_info(self)  # Обратная связь

func _on_area_2d_mouse_entered() -> void:
	info.get_node("ColorRect").visible = true
	if linked_item:
		info.text = ItemData.get_item_description(linked_item.type) + \
		"\nЦена: " + str(ItemData.get_item_cost(linked_item.type))
		if linked_item.type not in [ItemData.ItemType.LOOP_BLOCK, ItemData.ItemType.CONDITION_BLOCK, ItemData.ItemType.ABILITY_BLOCK]:
			info.text += "\nСлотов: " + str(ItemData.get_slot_count(ItemData.get_block_type(linked_item.type), 
		ItemData.get_ability_name_for_item_type(linked_item.type)))
	elif key > 0:
		for item in get_tree().get_nodes_in_group('items'):
			if item.key == key:
				info.text = "Предмет #" + str(key) + " (не связан)"
				return
		info.text = "Предмет #" + str(key) + " (не найден)"
	else:
		info.text = 'Информация'

func _on_area_2d_mouse_exited() -> void:
	info.get_node("ColorRect").visible = false
	info.text = ""

func _on_line_edit_text_submitted(_new_text: String) -> void:
	key = key_edit.text.to_int()
	key_edit.visible = false
	var edit_mode = get_tree().get_first_node_in_group("edit_mode")
	if edit_mode:
		edit_mode.is_editing_key = false
	
	# После изменения ключа пытаемся найти и привязаться к предмету
	linked_item = null  # Сбрасываем текущую связь
	find_and_link_item()  # Ищем предмет по новому ключу
