extends Node
class_name BlockExecutor

## Visual execution indicators
var outline_panels: Array[Node] = []

@onready var player: Player = $"../../../Room/Player"
@onready var command_executor: CommandExecutor = $"../CommandExecutor"

## Check and execute condition blocks
func check_and_execute_conditions(trigger_time: String) -> bool:
	# Get all condition blocks
	var condition_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and block.type == Block.BlockType.CONDITION)
	
	for block in condition_blocks:
		# Check if condition should execute
		var should_execute = trigger_time != "" if block.text == trigger_time else \
		block.text != "начало хода" and check_condition(block.text)
		
		if should_execute:
			await execute_block(block)
			if !is_instance_valid(player):
				return false
	
	return true

## Check if a condition is met
func check_condition(condition: String) -> bool:
	match condition:
		"начало хода":
			return true
		"здоровье < 50%":
			return is_instance_valid(player) and player.hp < 5
		_:
			return false

## Execute a block of commands
func execute_block(block: Block) -> void:
	if !is_instance_valid(player) or !is_instance_valid(block):
		return
	
	# Create visual execution indicator
	var outline = create_outline_panel(block)
	
	# Determine iterations (for loops)
	var iterations = max(1, block.loop_count) if (block.type == Block.BlockType.LOOP) else 1
	
	# Apply ability properties
	if block.type == Block.BlockType.ABILITY:
		_apply_ability_properties(block)
	
	# Execute iterations
	for i in iterations:
		if !is_instance_valid(player):
			break
		
		# Execute all commands in slots
		for slot in block.slot_manager.slots:
			if !is_instance_valid(player) or !is_instance_valid(slot.command):
				break
			
			if slot.command is Block:
				await execute_block(slot.command)
			elif slot.command is Command:
				await command_executor.execute_command(slot.command)
		
		# Delay between loop iterations
		if i < iterations - 1 and is_instance_valid(player):
			await get_tree().create_timer(0.2).timeout
	
	# Remove indicator
	remove_outline(outline)

## Apply ability properties to commands
func _apply_ability_properties(block: Block) -> void:
	for slot in block.slot_manager.slots:
		if slot.command is Command:
			slot.command.additional_properties = block.text

## Create visual execution indicator
func create_outline_panel(node: Node2D) -> Panel:
	if !is_instance_valid(node) or !node.has_node("Texture"):
		return null
	
	var texture = node.get_node("Texture")
	var panel = Panel.new()
	panel.size = texture.size + Vector2(4, 4)
	panel.position = Vector2(-2, -2)
	
	# Set panel style
	var style = StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 10
	
	node.add_child(panel)
	outline_panels.append(panel)
	
	return panel

## Remove a visual indicator
func remove_outline(outline: Panel) -> void:
	if is_instance_valid(outline):
		outline_panels.erase(outline)
		outline.queue_free()

## Clear all visual indicators
func clear_outlines() -> void:
	for panel in outline_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	outline_panels.clear()

## Clear main commands (excluding conditional blocks except "начало хода")
func clear_main_commands() -> void:
	if !is_inside_tree():
		return
	
	# Collect commands to remove and affected blocks
	var commands_to_free = []
	var affected_blocks = {}
	
	# Get commands to free
	for command in get_tree().get_nodes_in_group("commands"):
		if !is_instance_valid(command) or !command.slot or !command.slot.block:
			continue
			
		var block = command.slot.block
		if block.type != Block.BlockType.CONDITION || block.text == "начало хода":
			commands_to_free.append(command)
			affected_blocks[block] = true
	
	# Remove commands
	await clear_commands(commands_to_free)
	
	# Update affected blocks
	for block in affected_blocks.keys():
		if is_instance_valid(block):
			block.slot_manager.shift_commands_up()
			block.update_slots()
	
	# Update all root blocks for consistency
	update_root_blocks()

## Update all root blocks
func update_root_blocks() -> void:
	var root_blocks = get_tree().get_nodes_in_group("blocks").filter(
		func(block): return is_instance_valid(block) and !block.parent_slot)
	
	for block in root_blocks:
		update_block_recursive(block)

## Update block recursively
func update_block_recursive(block: Block) -> void:
	if !is_instance_valid(block):
		return
	
	# Force update slots
	block.slot_manager.shift_commands_up()
	block.slot_manager.update_slots()
	
	# Update all child blocks
	for slot in block.slot_manager.slots:
		if is_instance_valid(slot.command) and slot.command is Block:
			update_block_recursive(slot.command)
	
	# Update positions of all commands
	block.update_command_positions(block.z_index)

## Clear commands with animation
func clear_commands(commands_to_free: Array) -> void:
	if commands_to_free.is_empty():
		return
	
	# Fade-out animation
	var tween = create_tween().set_parallel(true)
	for command in commands_to_free:
		if is_instance_valid(command) and command.has_node("Texture"):
			tween.tween_property(command.get_node("Texture"), "modulate:a", 0.0, 0.3)
	await tween.finished
	
	# Free commands
	for command in commands_to_free:
		if is_instance_valid(command):
			if command.slot:
				command.slot.command = null
			command.queue_free()

## Clear all commands (except in condition blocks other than "начало хода")
func clear_all() -> void:
	if !is_inside_tree():
		return
	
	var commands_to_free = []
	var affected_blocks = []
	
	# Process all blocks
	var all_blocks = get_tree().get_nodes_in_group("blocks")
	for block in all_blocks:
		if !is_instance_valid(block):
			continue
			
		# Skip condition blocks except "начало хода"
		if block.type == Block.BlockType.CONDITION and block.text != "начало хода":
			continue
			
		# Process this block
		for slot in block.slot_manager.slots:
			if !is_instance_valid(slot) or !is_instance_valid(slot.command):
				continue
				
			if slot.command is Command:
				commands_to_free.append(slot.command)
				slot.command = null
				if !affected_blocks.has(block):
					affected_blocks.append(block)
					
			elif slot.command is Block and (block.type != Block.BlockType.CONDITION or block.text == "начало хода"):
				# Recursively handle nested blocks
				_collect_commands_from_block(slot.command, commands_to_free, affected_blocks)
	
	await clear_commands(commands_to_free)
	
	# Update block hierarchy
	update_root_blocks()

## Recursively collect commands from a block
func _collect_commands_from_block(block: Block, commands: Array, affected_blocks: Array) -> void:
	if !is_instance_valid(block):
		return
		
	if !affected_blocks.has(block):
		affected_blocks.append(block)
		
	for slot in block.slot_manager.slots:
		if !is_instance_valid(slot) or !is_instance_valid(slot.command):
			continue
			
		if slot.command is Command:
			commands.append(slot.command)
			slot.command = null
		elif slot.command is Block:
			_collect_commands_from_block(slot.command, commands, affected_blocks)
