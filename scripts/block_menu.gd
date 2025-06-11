extends Node2D

@onready var table_node: Table = $".."

const MAX_SLOTS = 8
var block_slots: Array[Block] = []

func _ready() -> void:
	add_to_group("block_menu")
	block_slots.resize(MAX_SLOTS)
	
	Global.connect("points_changed", refresh_menu)
	call_deferred("refresh_menu")

func refresh_menu() -> void:
	if not is_inside_tree():
		return
	
	clear_menu()
	
	var purchased_blocks = Global.get_all_purchased_blocks()
	for i in range(min(purchased_blocks.size(), MAX_SLOTS)):
		var block_data = purchased_blocks[i]
		create_block_in_slot(block_data, i)
	
	update_availability()

func clear_menu() -> void:
	for block in block_slots:
		if is_instance_valid(block):
			block.queue_free()
	block_slots.fill(null)

func create_block_in_slot(block_data: Dictionary, slot_index: int) -> void:
	var block_scene = load("res://scenes/Block.tscn")
	var block = block_scene.instantiate()
	
	block.type = block_data.type
	block.text = block_data.text
	block.is_menu_card = true
	
	# Setup loop count if it's a loop block
	if block_data.type == ItemData.BlockType.LOOP:
		var parts = block_data.text.split(" ")
		if parts.size() > 1:
			block.loop_count = int(parts[1])
	
	add_child(block)
	block_slots[slot_index] = block
	block.position = Vector2(0, slot_index * 30)
	
	# Connect click event
	var area = block.get_node("Area2D")
	if area:
		area.input_event.connect(_on_block_clicked.bind(block_data.id, block))

func _on_block_clicked(viewport: Node, event: InputEvent, shape_idx: int, block_id: String, block: Block) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	
	if not Global.can_use_block_by_id(block_id):
		return
	
	# Create copy on table
	table_node.create_block_copy(block.type, block.text, block.loop_count, block_id)
	
	# Mark block as used
	Global.use_block(block_id)
	update_availability()

func update_availability() -> void:
	if not is_inside_tree():
		return
	
	var purchased_blocks = Global.get_all_purchased_blocks()
	
	for i in range(block_slots.size()):
		var block = block_slots[i]
		if not is_instance_valid(block) or i >= purchased_blocks.size():
			continue
		
		var block_data = purchased_blocks[i]
		var is_available = not block_data.used
		
		block.modulate.a = 1.0 if is_available else 0.3
		
		var area = block.get_node("Area2D")
		if area:
			area.input_pickable = is_available
