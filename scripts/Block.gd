extends Node2D
class_name Block

enum BlockType { NONE, CONDITION, LOOP, ABILITY }

@export_category("Block Settings")
@export var type: BlockType
@export var text: String
@export var loop_count: int = 2
@export var slot_offset_start := Vector2(28, 32)

const MAX_TEXT_LENGTH := 14
const SLOT_OFFSET := 37
const SLOT_HEIGHT_INCREMENT := 30
const MAX_LOOP_SLOTS := 3

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

var slots: Array[CommandSlot] = []
var parent_slot: CommandSlot = null
var config: Dictionary
var original_slot_commands: Array = []
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
	update_appearance()
	initialize_slots()
	buttons[0].visible = false  # Скрываем кнопку "Up"
	buttons[1].visible = false  # Скрываем кнопку "Down"
	button_color.visible = false

func initialize_slots() -> void:
	if slots.is_empty():
		var slot_count = min(loop_count, MAX_LOOP_SLOTS) if type == BlockType.LOOP else 1
		for _i in range(slot_count):
			create_slot()
	update_slots()

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

func create_slot() -> CommandSlot:
	if type == BlockType.LOOP and slots.size() >= MAX_LOOP_SLOTS:
		return slots.back()
		
	var slot = preload("res://scenes/command_slot.tscn").instantiate() as CommandSlot
	add_child(slot)
	slot.block = self
	slots.append(slot)
	return slot

func get_total_height() -> float:
	var height = slot_offset_start.y
	
	for slot in slots:
		var slot_height = SLOT_OFFSET
		if slot.command and slot.command is Block:
			slot_height = slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
		height += slot_height
		
	return height

func update_all_slot_positions() -> void:
	var current_y = slot_offset_start.y
	
	for slot in slots:
		if not is_instance_valid(slot):
			continue
			
		slot.position = Vector2(slot_offset_start.x, current_y)
		var increment = SLOT_OFFSET
		
		if slot.command and is_instance_valid(slot.command):
			# Ensure command is properly positioned
			slot.command.global_position = to_global(slot.position)
			
			# Update command references
			if slot.command is Command:
				slot.command.slot = slot
			elif slot.command is Block:
				slot.command.parent_slot = slot
				
			# Calculate space needed
			if slot.command is Block:
				increment = slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
				
		current_y += increment

func update_texture_sizes() -> void:
	var total_height = get_total_height()
	texture_down.position.y = total_height
	texture_left.size.y = total_height
	
	recreate_collision_shapes(total_height)
	
	if parent_slot and is_instance_valid(parent_slot) and parent_slot.block:
		parent_slot.block.update_slots()

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

func update_slots() -> void:
	shift_commands_up()
	adjust_slot_count()
	update_all_slot_positions()
	update_texture_sizes()

func shift_commands_up() -> void:
	# Create a new array to hold valid slots
	var valid_slots: Array[CommandSlot] = []
	
	# First pass: collect valid slots with valid commands
	for slot in slots:
		if is_instance_valid(slot):
			if slot.command and is_instance_valid(slot.command):
				valid_slots.append(slot)
			else:
				# Explicitly clear command reference
				slot.command = null
	
	# Second pass: shift commands up to fill gaps
	for i in range(valid_slots.size()):
		if i < slots.size():
			slots[i].command = valid_slots[i].command
			# Make sure the command references the correct slot
			if slots[i].command is Command:
				slots[i].command.slot = slots[i]
			elif slots[i].command is Block:
				slots[i].command.parent_slot = slots[i]
		
	# Clear remaining slots
	for i in range(valid_slots.size(), slots.size()):
		if i < slots.size():
			slots[i].command = null
	
	# Make sure all commands have correct positions
	update_all_slot_positions()

func adjust_slot_count() -> void:
	if slots.is_empty():
		create_slot()
		return
	
	# Count commands
	var command_count = slots.filter(func(s): 
		return s.command != null and is_instance_valid(s.command)
	).size()
	
	# Calculate target slots 
	var target_count = command_count + 1  # One empty slot
	if type == BlockType.LOOP:
		target_count = min(target_count, MAX_LOOP_SLOTS)
	
	# Remove excess empty slots
	while slots.size() > target_count:
		var last_slot = slots.back()
		if not last_slot.command and is_instance_valid(last_slot):
			slots.pop_back()
			last_slot.queue_free()
		else:
			break
	
	# Add slots if needed
	while slots.size() < target_count:
		create_slot()

func get_full_size() -> Vector2:
	var base_size = Vector2(
		max(texture_up.size.x, texture_down.size.x),
		texture_down.position.y + texture_down.size.y
	)
	
	for slot in slots:
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
	if slots.is_empty() or target_slot not in slots:
		return
		
	# Save original state
	original_slot_commands = []
	for slot in slots:
		original_slot_commands.append(slot.command)
	
	var hover_index = slots.find(target_slot)
	
	# Create new slot if needed
	if slots.back().command:
		create_slot()
	
	# Shift commands down
	for i in range(slots.size() - 1, hover_index, -1):
		slots[i].command = slots[i - 1].command
	
	# Clear target slot
	slots[hover_index].command = null
	update_all_slot_positions()
	
	# Update visual positions
	for slot in slots:
		if slot.command and is_instance_valid(slot.command):
			slot.command.global_position = to_global(slot.position)
			
func cancel_insertion() -> void:
	if original_slot_commands.is_empty():
		return
		
	# Restore original state
	for i in range(min(slots.size(), original_slot_commands.size())):
		slots[i].command = original_slot_commands[i]
	
	for i in range(original_slot_commands.size(), slots.size()):
		slots[i].command = null
		
	original_slot_commands = []
	update_slots()
	
func update_command_positions(base_z_index: int) -> void:
	for slot in slots:
		if slot.command and is_instance_valid(slot.command):
			slot.command.global_position = to_global(slot.position)
			slot.command.visible = true
			slot.command.z_index = base_z_index - 1
			
			if slot.command is Block:
				slot.command.update_command_positions(base_z_index - 1)

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
		initialize_slots()

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
					# Let _exit_tree handle the cleanup and parent updates
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
	buttons[0].visible = settings  # Показываем/скрываем "Up"
	buttons[1].visible = settings  # Показываем/скрываем "Down"
			
func _exit_tree() -> void:
	# Store parent reference
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
	navigate_options(1)  # -1 означает переход к предыдущему элементу

func _on_down_pressed() -> void:
	navigate_options(-1)   # 1 означает переход к следующему элементу
