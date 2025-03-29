extends Node

@onready var button: Button = $"../../UI/Button"
@onready var player: Player = $"../../Room/Player"
@onready var hp_bar: UI = $"../../UI"

@export var ui_node: UI
@export var room: Node2D
@onready var win_label: Label = ui_node.get_node('Labels/WinLabel')
@onready var defeat_label: Label = ui_node.get_node('Labels/DefeatLabel')

var is_player_alive: bool = true
var outline_panels: Array[Node] = []
var current_block: Block = null
var game_finished: bool = false

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)
	if player:
		player.tree_exited.connect(_on_player_dead)
	# Сбрасываем доступные очки при запуске
	Global.reset_remaining_points()

func _on_button_pressed() -> void:
	if not is_player_alive or not is_instance_valid(player) or not is_inside_tree() or game_finished:
		return
		
	# Сразу после нажатия
	button.disabled = true
	for command in get_tree().get_nodes_in_group("commands"):
		command.change_settings(false)
		
	# Выполнение команд
	for block in get_tree().get_nodes_in_group("blocks"):
		if block.type == Block.BlockType.CONDITION and block.text == "начало хода":
			await execute_block(block)
			
			# Проверяем состояние игрока после выполнения блока
			if not is_player_alive or not is_instance_valid(player):
				await end_game_player_dead()
				return
			
	await clear_all()
	
	# Если игрок умер во время выполнения своих команд, заканчиваем игру
	if not is_player_alive or not is_instance_valid(player):
		await end_game_player_dead()
		return
	
	# Ход врага
	for enemy in get_tree().get_nodes_in_group('enemies'):
		if enemy and not game_finished:
			await enemy.take_turn()
			
			# Проверяем состояние игрока после хода каждого врага
			if not is_player_alive or not is_instance_valid(player):
				await end_game_player_dead()
				return
	
	# Если после всех ходов игрок остался жив
	if is_player_alive and not game_finished:
		await get_tree().create_timer(0.2).timeout
		
		# После хода врага
		Global.reset_remaining_points()
		ui_node.reset_defense()
		button.disabled = false
		
		# Проверяем условие победы
		if !get_tree().get_nodes_in_group('enemies').size():
			game_finished = true
			room.visible = false
			win_label.visible = true

func _on_player_dead() -> void:
	if not is_player_alive:
		return
	is_player_alive = false
	await end_game_player_dead()

# Функция завершения игры после смерти игрока
func end_game_player_dead() -> void:
	if game_finished:
		return
		
	game_finished = true
	
	# Остановка всех текущих процессов
	for panel in outline_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	outline_panels.clear()
	await clear_all()
	
	# Отключение кнопки
	if button:
		button.disabled = true
	
	# Остановка всех врагов
	if is_inside_tree():
		for enemy in get_tree().get_nodes_in_group('enemies'):
			if enemy:
				enemy.stop_movement()
	
	# Отображение экрана поражения
	room.visible = false
	defeat_label.visible = true

func execute_block(block: Block) -> void:
	if game_finished or not is_player_alive or not is_instance_valid(block):
		return
	current_block = block
	var outline = create_outline_panel(block)
	var iterations = max(1, block.loop_count) if block.type == Block.BlockType.LOOP else 1
	if block.type == Block.BlockType.ABILITY:
		for slot in block.slots:
			if slot.command is Command:
				slot.command.additional_properties = block.text
	for i in iterations:
		# Прерываем выполнение блока, если игра завершена
		if game_finished or not is_player_alive:
			break
		for slot in block.slots:
			# Прерываем выполнение слота, если игра завершена
			if game_finished or not is_player_alive:
				break
			if not is_instance_valid(slot.command):
				continue
			if slot.command is Block:
				await execute_block(slot.command)
			elif slot.command is Command:
				await execute_command(slot.command)
		if i < iterations - 1 and not game_finished and is_player_alive:
			await get_tree().create_timer(0.2).timeout
	if is_instance_valid(outline):
		outline_panels.erase(outline)
		outline.queue_free()
	current_block = null

func create_outline_panel(node: Node2D) -> Panel:
	if not is_instance_valid(node) or not node.has_node("Texture"):
		return null
	var panel = Panel.new()
	var texture = node.get_node("Texture")
	panel.size = texture.size + Vector2(4, 4)
	panel.position = Vector2(-2, -2)
	var style = StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	style.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 10
	node.add_child(panel)
	outline_panels.append(panel)
	return panel

# Выполнение команды с обводкой текущей выполняемой команды
func execute_command(command: Command) -> void:
	if game_finished or not is_player_alive or not is_instance_valid(command) or not is_instance_valid(player):
		return
	var outline = create_outline_panel(command)
	if command.additional_properties == '+1 урон' and command.type == Command.TypeCommand.ATTACK:
		command.value += 1
	if command.additional_properties == '+1 перемещение' and command.type == Command.TypeCommand.MOVE:
		command.value += 1
	match command.type:
		Command.TypeCommand.MOVE: await player.move(command.value)
		Command.TypeCommand.TURN_LEFT: await player.turn("left")
		Command.TypeCommand.TURN_RIGHT: await player.turn("right")
		Command.TypeCommand.TURN_AROUND: await player.turn("around")
		Command.TypeCommand.ATTACK: await player.attack(command.value)
		Command.TypeCommand.HEAL: await player.add_hp(command.value)
		Command.TypeCommand.DEFENSE: await player.add_defense(command.value)
	
	# Проверяем, жив ли игрок после выполнения команды
	if not is_player_alive or not is_instance_valid(player):
		if is_instance_valid(outline):
			outline_panels.erase(outline)
			outline.queue_free()
		return
	
	if is_instance_valid(outline):
		outline_panels.erase(outline)
		outline.queue_free()

# создание массива команд с возможностью рекурсивного обхода вложенных блоков с командами
func collect_commands(block: Block, commands: Array[Node]) -> void:
	if not is_instance_valid(block):
		return
	for slot in block.slots:
		if not is_instance_valid(slot.command):
			continue
		if slot.command is Block:
			collect_commands(slot.command, commands)
			slot.command.update_slots()
		elif slot.command is Command:
			commands.append(slot.command)
			slot.command = null

func clear_all() -> void:
	if not is_inside_tree():
		return
	var blocks = get_tree().get_nodes_in_group("blocks")
	var commands_to_free: Array[Node] = []
	for block in blocks:
		if is_instance_valid(block):
			collect_commands(block, commands_to_free)
	if commands_to_free.size() > 0:
		var tween = create_tween().set_parallel(true)
		for command in commands_to_free:
			if is_instance_valid(command) and command.has_node("Texture"):
				tween.tween_property(command.get_node("Texture"), "modulate:a", 0.0, 0.3)
		await tween.finished
	for command in commands_to_free:
		if is_instance_valid(command):
			command.queue_free()
	for block in blocks:
		if is_instance_valid(block):
			block.update_slots()
	
	# Сбрасываем очки после очистки всех команд
	Global.reset_remaining_points()
