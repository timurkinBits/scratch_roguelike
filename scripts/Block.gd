extends Node2D
class_name Block

enum BlockType { NONE, CONDITION, LOOP, ABILITY }

@export_category("Block Settings")
@export var type: BlockType
@export var text: String
@export var loop_count: int = 2
@export var slot_offset_start := Vector2(28, 32)

const MAX_TEXT_LENGTH := 14

@onready var label: Label = $Label
@onready var texture: Control = $Texture
@onready var area: Area2D = $Area2D
@onready var icon: Sprite2D = $Icon
@onready var texture_up = $Texture/TextureUp
@onready var texture_down = $Texture/TextureDown
@onready var texture_left = $Texture/TextureLeft
@onready var buttons = [$'Buttons/Up', $'Buttons/Down']
@onready var table = $'../..'
@onready var button_color: ColorRect = $'Buttons/ColorRect'

var slot_manager: SlotManager
var parent_slot: CommandSlot = null
var config: Dictionary
var is_menu_command: bool = false
var is_settings: bool = false

const AVAILABLE_CONDITIONS = [
	"здоровье < 50%",
]

const AVAILABLE_ABILITIES = [
	"+1 урон",
	"+1 движ.",
	"+1 защита",
]

var block_configs = {
	BlockType.CONDITION: {
		"prefix": "Если ",
		"color": Color.YELLOW,
		"icon": "res://sprites/fb13.png"
	},
	BlockType.LOOP: {
		"prefix": "Повторить ",
		"color": Color.CHOCOLATE,
		"icon": "res://sprites/fb666.png"
	},
	BlockType.ABILITY: {
		"prefix": "Улучшить ",
		"color": Color.TURQUOISE,
		"icon": "res://sprites/fb12.png"
	},
	BlockType.NONE: {
		"prefix": "none ",
		"color": Color.WHITE,
		"icon": ""
	}
}

func _ready() -> void:
	add_to_group("blocks")
	config = block_configs[type]
	slot_manager = SlotManager.new(self, slot_offset_start)
	add_child(slot_manager)
	slot_manager.connect("slots_updated", _on_slots_updated)
	
	update_appearance()
	slot_manager.initialize_slots(loop_count if type == BlockType.LOOP else 1)
	
	buttons[0].visible = false
	buttons[1].visible = false
	button_color.visible = false

func update_appearance() -> void:
	texture.modulate = config["color"]
	icon.texture = load(config["icon"]) if config["icon"] else null
	label.text = get_display_text()

func get_display_text() -> String:
	if type == BlockType.LOOP:
		return config["prefix"] + str(loop_count) + " раз"
	return config["prefix"] + truncate_text(text)

func truncate_text(input_text: String) -> String:
	return input_text.substr(0, MAX_TEXT_LENGTH) if input_text.length() > MAX_TEXT_LENGTH else input_text

func get_total_height() -> float:
	return slot_manager.get_total_height()

func update_slots() -> void:
	slot_manager.update_slots()

func _on_slots_updated() -> void:
	update_texture_sizes()
	
	if parent_slot and is_instance_valid(parent_slot) and parent_slot.block:
		parent_slot.block.update_slots()

func update_texture_sizes() -> void:
	var total_height = get_total_height()
	texture_down.position.y = total_height
	texture_left.size.y = total_height
	
	recreate_collision_shapes(total_height)

func recreate_collision_shapes(total_height: float) -> void:
	for child in area.get_children():
		if !child.name == "CollisionUpProperty":
			child.queue_free()
			
	var size_up = texture_up.size.x / 1.78
	create_collision_rectangle("CollisionUp", Vector2(size_up, texture_up.size.y), 
		Vector2(size_up / 2, texture_up.size.y / 2))
	
	create_collision_rectangle("CollisionDown", texture_down.size,
		Vector2(texture_down.size.x / 2, total_height + texture_down.size.y / 2))
	
	create_collision_rectangle("CollisionLeft", 
		Vector2(texture_left.size.x, total_height - texture_up.size.y),
		Vector2(texture_left.size.x / 2, texture_up.size.y + (total_height - texture_up.size.y) / 2))

func create_collision_rectangle(name_collision: String, size: Vector2, position_collision: Vector2) -> void:
	var collision = CollisionShape2D.new()
	collision.name = name_collision
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_collision
	area.add_child(collision)

func get_full_size() -> Vector2:
	var base_size = Vector2(
		max(texture_up.size.x, texture_down.size.x),
		texture_down.position.y + texture_down.size.y
	)
	
	for slot in slot_manager.slots:
		if not is_instance_valid(slot) or not slot.command:
			continue
		
		var command_size = Vector2.ZERO
		var slot_pos = slot.position
		
		if slot.command is Block:
			command_size = slot.command.get_full_size() * slot.command.scale
		else:
			var texture_node = slot.command.get_node("Texture")
			if texture_node:
				command_size = texture_node.size * slot.command.scale
		
		var command_right = slot_pos.x + command_size.x
		var command_bottom = slot_pos.y + command_size.y
		
		base_size.x = max(base_size.x, command_right)
		base_size.y = max(base_size.y, command_bottom)
	
	return base_size

func prepare_for_insertion(target_slot: CommandSlot) -> void:
	slot_manager.prepare_for_insertion(target_slot)
	
func cancel_insertion() -> void:
	slot_manager.cancel_insertion()
	
func update_command_positions(base_z_index: int) -> void:
	slot_manager.update_command_positions(base_z_index)

func set_condition(new_condition: String) -> void:
	if type == BlockType.CONDITION and new_condition in AVAILABLE_CONDITIONS:
		text = new_condition
		update_appearance()

func set_ability(new_ability: String) -> void:
	if type == BlockType.ABILITY and new_ability in AVAILABLE_ABILITIES:
		text = new_ability
		update_appearance()

func change_loop_count(amount: int) -> void:
	if type == BlockType.LOOP:
		loop_count = clamp(loop_count + amount, 2, 2)
		update_appearance()
		slot_manager.initialize_slots(loop_count)

func navigate_options(direction: int) -> void:
	match type:
		BlockType.CONDITION:
			_navigate_conditions(direction)
		BlockType.LOOP:
			change_loop_count(direction)
		BlockType.ABILITY:
			_navigate_abilities(direction)

func _navigate_conditions(direction: int) -> void:
	if AVAILABLE_CONDITIONS.is_empty():
		return
		
	var current_index = AVAILABLE_CONDITIONS.find(text)
	if current_index == -1:
		current_index = 0
	else:
		current_index = (current_index + direction) % AVAILABLE_CONDITIONS.size()
		if current_index < 0:
			current_index = AVAILABLE_CONDITIONS.size() - 1
			
	set_condition(AVAILABLE_CONDITIONS[current_index])

func _navigate_abilities(direction: int) -> void:
	if AVAILABLE_ABILITIES.is_empty():
		return
		
	var current_index = AVAILABLE_ABILITIES.find(text)
	if current_index == -1:
		current_index = 0
	else:
		current_index = (current_index + direction) % AVAILABLE_ABILITIES.size()
		if current_index < 0:
			current_index = AVAILABLE_ABILITIES.size() - 1
			
	set_ability(AVAILABLE_ABILITIES[current_index])

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if shape_idx != 0:
			if event.button_index == MOUSE_BUTTON_RIGHT and !is_menu_command and event.pressed \
				and text != 'начало хода' and not table.is_turn_in_progress:
					queue_free()
			else:
				is_settings = false
				change_settings(is_settings)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and !is_menu_command and event.pressed \
				and text != 'начало хода' and not table.is_turn_in_progress:
					is_settings = !is_settings
					change_settings(is_settings)

func change_settings(settings: bool) -> void:
	buttons[0].visible = settings
	buttons[1].visible = settings

func _exit_tree() -> void:
	var parent = null
	if parent_slot and is_instance_valid(parent_slot):
		parent = parent_slot.block
		parent_slot.command = null
	
	# Update parent after this node is removed
	if parent and is_instance_valid(parent):
		# Use call_deferred to ensure this happens after current operations complete
		parent.call_deferred("update_slots")
	
	Global.release_block(type)

func _on_up_pressed() -> void:
	navigate_options(1)  # 1 означает переход к следующему элементу

func _on_down_pressed() -> void:
	navigate_options(-1)  # -1 означает переход к предыдущему элементу
