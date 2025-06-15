extends Node
class_name CommandExecutor

@onready var player: Player = $"../../../Room/Player"
@onready var block_executor: BlockExecutor = $"../BlockExecutor"

## Выполнение отдельной команды
func execute_command(command: Command) -> void:
	if !is_instance_valid(player) or !is_instance_valid(command):
		return
	
	# Создаем визуальный индикатор выполнения
	var outline = block_executor.create_outline_panel(command)
	
	# Применяем модификаторы команд
	_apply_command_modifiers(command)
	
	# Выполняем команду в зависимости от типа
	match command.type:
		Command.TypeCommand.MOVE:
			await player.move(command.value)
		Command.TypeCommand.TURN:
			var direction = "right" if command.value == 90 else "left" if command.value == -90 else "around"
			await player.turn(direction)
		Command.TypeCommand.ATTACK:
			await player.attack(command.value)
		Command.TypeCommand.USE:
			await player.use()
		Command.TypeCommand.HEAL:
			await player.add_hp(command.value)
		Command.TypeCommand.DEFENSE:
			await player.add_defense(command.value)
	
	# Очищаем индикатор
	block_executor.remove_outline(outline)

## Применение модификаторов к команде
func _apply_command_modifiers(command: Command) -> void:
	match command.additional_properties:
		'+1 движ.':
			if command.type == Command.TypeCommand.MOVE:
				command.value += 1
		'+1 атака':
			if command.type == Command.TypeCommand.ATTACK:
				command.value += 1
		'+1 защита':
			if command.type == Command.TypeCommand.DEFENSE:
				command.value += 1
		'+1 леч.':
			if command.type == Command.TypeCommand.HEAL:
				command.value += 1
