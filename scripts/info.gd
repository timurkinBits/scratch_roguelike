extends ObjectRoom
class_name Info


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



func _on_line_edit_text_submitted(_new_text: String) -> void:
	key = key_edit.text.to_int()
	key_edit.visible = false
	var edit_mode = get_tree().get_first_node_in_group("edit_mode")
	if edit_mode:
		edit_mode.is_editing_key = false
	
	# После изменения ключа пытаемся найти и привязаться к предмету
	linked_item = null  # Сбрасываем текущую связь
	find_and_link_item()  # Ищем предмет по новому ключу
