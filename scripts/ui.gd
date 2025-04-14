extends Control
class_name UI

var max_hp := 100.0
var current_health := max_hp
var current_defense := 0
var is_dead := false


@export var player: Player
@export var max_scores: Control
@export var player_bars: Control
@onready var health_bar: ColorRect = player_bars.get_node('hp_bar/HealthRect')
@onready var defense_bar: ColorRect = player_bars.get_node('defense_bar/DefenseRect')
@onready var coin_label: Label = player_bars.get_node('CoinLabel')
@onready var move_label: Label = max_scores.get_node('MoveLabel')
@onready var attack_label: Label = max_scores.get_node('AttackLabel')
@onready var heal_label: Label = max_scores.get_node('HealLabel')
@onready var defense_label: Label = max_scores.get_node('DefenseLabel')

# New block count labels
@onready var condition_label: Label = max_scores.get_node('ConditionLabel')
@onready var loop_label: Label = max_scores.get_node('LoopLabel')
@onready var ability_label: Label = max_scores.get_node('AbilityLabel')


func _ready():
	if not player:
		print("Player not found in HPbar!")
	update_health_bar()
	
	# Connect to the Global points_changed signal
	Global.connect("points_changed", update_all_counters)
	
	# Connect to the coins_changed signal
	Global.connect("coins_changed", update_coin_display)
	
	update_all_counters()
	update_coin_display()

func update_all_counters():
	# Update command points
	move_label.text = str(Global.get_remaining_points(Command.TypeCommand.MOVE))
	attack_label.text = str(Global.get_remaining_points(Command.TypeCommand.ATTACK))
	defense_label.text = str(Global.get_remaining_points(Command.TypeCommand.DEFENSE))
	heal_label.text = str(Global.get_remaining_points(Command.TypeCommand.HEAL))
	
	# Update block counts
	condition_label.text = str(Global.get_remaining_blocks(ItemData.BlockType.CONDITION))
	loop_label.text = str(Global.get_remaining_blocks(ItemData.BlockType.LOOP))
	ability_label.text = str(Global.get_remaining_blocks(ItemData.BlockType.ABILITY))

func update_coin_display():
	# Update coin counter in UI
	coin_label.text = str(Global.get_coins())

func change_scores(type: Command.TypeCommand) -> void:
	var remaining = Global.get_remaining_points(type)
	match type:
		Command.TypeCommand.MOVE:
			move_label.text = str(remaining)
		Command.TypeCommand.ATTACK:
			attack_label.text = str(remaining)
		Command.TypeCommand.DEFENSE:
			defense_label.text = str(remaining)
		Command.TypeCommand.HEAL:
			heal_label.text = str(remaining)

func update_health_bar():
	if is_instance_valid(health_bar) and is_instance_valid(defense_bar):
		health_bar.scale.x = current_health / max_hp
		defense_bar.scale.x = current_defense / max_hp

func add_defense(value: float):
	if is_dead:
		return
	current_defense = clamp(current_defense + value * 10, 0, max_hp)
	update_health_bar()
	await get_tree().create_timer(0.5).timeout

func hp_change(value: float):
	if is_dead:
		return
	
	var previous_health = current_health
	
	var raw_value = value * 10
	if raw_value > 0:
		# Лечение: применяем сразу к здоровью
		current_health = clamp(current_health + raw_value, 0, max_hp)
	else:
		# Урон: сначала уменьшаем защиту
		var damage_amount = abs(raw_value)
		var defense_used = min(current_defense, damage_amount)
		current_defense -= defense_used
		damage_amount -= defense_used
		
		# Применяем оставшийся урон к здоровью
		if damage_amount > 0:
			current_health = clamp(current_health - damage_amount, 0, max_hp)
	
	update_health_bar()
	
	# Проверяем смерть только если персонаж ещё не умер
	if not is_dead and previous_health > 0 and current_health <= 0:
		death()
	
	await get_tree().create_timer(0.5).timeout

func death():
	if is_dead or not is_instance_valid(player):
		return
	is_dead = true
	player.dead()
	
func reset_defense():
	current_defense = 0
	update_health_bar()

func reset_health():
	if is_instance_valid(health_bar):
		current_health = max_hp
		is_dead = false
		update_health_bar()
