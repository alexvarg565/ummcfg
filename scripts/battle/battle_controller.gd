class_name BattleController
extends Node2D


enum InputMode {
	NORMAL,
	ATTACK_TARGETING
}


@onready var grid_controller: GridController = \
	$Systems/GridController

@onready var initiative_controller: InitiativeController = \
	$Systems/InitiativeController

@onready var turn_controller: TurnController = \
	$Systems/TurnController

@onready var grid_cursor: GridCursor = \
	$Battlefield/GridCursor

@onready var movement_highlights: MovementHighlights = \
	$Battlefield/MovementHighlights

@onready var attack_highlights: AttackHighlights = \
	$Battlefield/AttackHighlights

@onready var intent_highlights: IntentHighlights = \
	$Battlefield/IntentHighlights

@onready var test_mech: Unit = \
	$Battlefield/UnitLayer/TestMech

@onready var blocker: Unit = \
	$Battlefield/UnitLayer/Blocker


var selected_unit: Unit = null

var valid_move_cells: Array[Vector2i] = []
var valid_attack_cells: Array[Vector2i] = []

var enemy_intents: Dictionary = {}

var input_mode: InputMode = InputMode.NORMAL


func _ready() -> void:
	print("Battle initialized.")

	grid_cursor.cell_selected.connect(
		_on_cell_selected
	)

	turn_controller.round_started.connect(
		_on_round_started
	)

	turn_controller.active_unit_changed.connect(
		_on_active_unit_changed
	)

	_register_unit_signals()

	_place_test_units()
	_start_turn_system()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_try_enter_attack_mode()

		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("end_turn"):
		_try_end_player_activation()

		get_viewport().set_input_as_handled()


func _register_unit_signals() -> void:
	test_mech.died.connect(
		_on_unit_died
	)

	blocker.died.connect(
		_on_unit_died
	)


func _place_test_units() -> void:
	test_mech.team = Unit.Team.PLAYER
	test_mech.initiative = 15

	blocker.team = Unit.Team.ENEMY
	blocker.initiative = 10

	var mech_placed: bool = \
		grid_controller.register_unit(
			test_mech,
			Vector2i(2, 3)
		)

	if mech_placed:
		print(
			"Placed ",
			test_mech.display_name,
			" at ",
			test_mech.grid_position
		)
	else:
		push_error(
			"Failed to place test mech."
		)

	var enemy_placed: bool = \
		grid_controller.register_unit(
			blocker,
			Vector2i(3, 3)
		)

	if enemy_placed:
		print(
			"Placed ",
			blocker.display_name,
			" at ",
			blocker.grid_position
		)
	else:
		push_error(
			"Failed to place enemy."
		)


func _start_turn_system() -> void:
	var units: Array[Unit] = [
		test_mech,
		blocker
	]

	var initiative_order: Array[Unit] = \
		initiative_controller.build_order(
			units
		)

	print("")
	print("Initiative Order:")

	for unit: Unit in initiative_order:
		print(
			unit.initiative,
			" - ",
			unit.display_name
		)

	turn_controller.start_battle(
		initiative_order
	)


# --------------------------------------------------
# ROUND / INITIATIVE
# --------------------------------------------------

func _on_round_started(
	round_number: int
) -> void:
	print(
		"Starting round ",
		round_number
	)

	_plan_enemy_intents()


func _on_active_unit_changed(
	unit: Unit
) -> void:
	_clear_selection_state()

	if unit.is_player_unit():
		print(
			"Player activation: ",
			unit.display_name
		)
	else:
		print(
			"Enemy activation: ",
			unit.display_name
		)

		_execute_enemy_intent(unit)


# --------------------------------------------------
# ENEMY INTENT
# --------------------------------------------------

func _plan_enemy_intents() -> void:
	enemy_intents.clear()
	intent_highlights.clear()

	var intent_cells: Array[Vector2i] = []

	for unit: Unit in turn_controller.turn_order:
		if unit == null:
			continue

		if not unit.is_alive:
			continue

		if not unit.is_enemy_unit():
			continue

		var intent: EnemyIntent = \
			_create_enemy_intent(unit)

		if intent == null:
			print(
				unit.display_name,
				" has no valid intent."
			)

			continue

		enemy_intents[unit] = intent
		intent_cells.append(
			intent.target_cell
		)

		print(
			unit.display_name,
			" intends to attack ",
			intent.target_cell
		)

	intent_highlights.show_cells(
		intent_cells
	)


func _create_enemy_intent(
	enemy: Unit
) -> EnemyIntent:
	if enemy.weapon == null:
		return null

	var target: Unit = \
		_find_enemy_target(enemy)

	if target == null:
		return null

	return EnemyIntent.new(
		enemy,
		target.grid_position,
		enemy.weapon
	)


func _find_enemy_target(
	enemy: Unit
) -> Unit:
	var best_target: Unit = null
	var best_distance: int = 999999

	for candidate: Unit in turn_controller.turn_order:
		if candidate == null:
			continue

		if not candidate.is_alive:
			continue

		if candidate.team == enemy.team:
			continue

		var distance: int = \
			_get_grid_distance(
				enemy.grid_position,
				candidate.grid_position
			)

		if distance < enemy.weapon.min_range:
			continue

		if distance > enemy.weapon.max_range:
			continue

		if distance < best_distance:
			best_distance = distance
			best_target = candidate

	return best_target


func _execute_enemy_intent(
	enemy: Unit
) -> void:
	if not enemy_intents.has(enemy):
		print(
			enemy.display_name,
			" has no committed action."
		)

		turn_controller.end_current_activation()
		return

	var intent: EnemyIntent = \
		enemy_intents[enemy]

	enemy_intents.erase(enemy)

	_refresh_intent_highlights()

	if not _is_enemy_intent_still_valid(
		intent
	):
		print(
			enemy.display_name,
			"'s committed attack failed."
		)

		turn_controller.end_current_activation()
		return

	_execute_enemy_attack(intent)

	turn_controller.end_current_activation()


func _is_enemy_intent_still_valid(
	intent: EnemyIntent
) -> bool:
	if intent.actor == null:
		return false

	if not intent.actor.is_alive:
		return false

	if intent.weapon == null:
		return false

	if not grid_controller.is_inside_grid(
		intent.target_cell
	):
		return false

	var distance: int = \
		_get_grid_distance(
			intent.actor.grid_position,
			intent.target_cell
		)

	if distance < intent.weapon.min_range:
		return false

	if distance > intent.weapon.max_range:
		return false

	return true


func _execute_enemy_attack(
	intent: EnemyIntent
) -> void:
	var target: Unit = \
		grid_controller.get_unit_at(
			intent.target_cell
		)

	if target == null:
		print(
			intent.actor.display_name,
			" fires ",
			intent.weapon.display_name,
			" at ",
			intent.target_cell,
			", but the tile is empty."
		)

		return

	if target.team == intent.actor.team:
		print(
			intent.actor.display_name,
			" fires at ",
			intent.target_cell,
			" and hits an allied unit!"
		)

	var damage: int = \
		_roll_weapon_damage(
			intent.weapon
		)

	print(
		intent.actor.display_name,
		" attacks ",
		target.display_name,
		" at ",
		intent.target_cell,
		" for ",
		damage,
		" damage."
	)

	target.take_damage(damage)

	intent.actor.mark_acted()


func _refresh_intent_highlights() -> void:
	var cells: Array[Vector2i] = []

	for intent_value: Variant in enemy_intents.values():
		var intent: EnemyIntent = \
			intent_value as EnemyIntent

		if intent == null:
			continue

		cells.append(
			intent.target_cell
		)

	intent_highlights.show_cells(cells)


# --------------------------------------------------
# PLAYER SELECTION / MOVEMENT
# --------------------------------------------------

func _on_cell_selected(
	cell: Vector2i
) -> void:
	var active_unit: Unit = \
		turn_controller.active_unit

	if active_unit == null:
		return

	if not active_unit.is_player_unit():
		return

	if input_mode == InputMode.ATTACK_TARGETING:
		_try_attack_cell(cell)
		return

	if (
		selected_unit != null
		and cell in valid_move_cells
	):
		_move_selected_unit(cell)
		return

	var unit: Unit = \
		grid_controller.get_unit_at(cell)

	if unit == null:
		_clear_selection_state()

		print(
			"No unit at ",
			cell
		)

		return

	if not unit.is_player_unit():
		_clear_selection_state()

		print(
			"Cannot select enemy unit."
		)

		return

	if not turn_controller.is_units_turn(
		unit
	):
		_clear_selection_state()

		print(
			"It is not ",
			unit.display_name,
			"'s turn."
		)

		return

	_select_unit(unit)


func _select_unit(
	unit: Unit
) -> void:
	if (
		selected_unit != null
		and selected_unit != unit
	):
		selected_unit.deselect()

	selected_unit = unit
	selected_unit.select()

	_refresh_movement_highlights()

	print(
		"Selected ",
		selected_unit.display_name,
		" at ",
		selected_unit.grid_position
	)


func _refresh_movement_highlights() -> void:
	valid_move_cells.clear()
	movement_highlights.clear()

	if selected_unit == null:
		return

	if not selected_unit.can_move():
		return

	valid_move_cells = \
		grid_controller.get_reachable_cells(
			selected_unit.grid_position,
			selected_unit.movement_range
		)

	movement_highlights.show_cells(
		valid_move_cells
	)


func _move_selected_unit(
	target_cell: Vector2i
) -> void:
	if selected_unit == null:
		return

	if not selected_unit.can_move():
		print(
			selected_unit.display_name,
			" has already moved."
		)

		return

	var moved: bool = \
		grid_controller.move_unit(
			selected_unit,
			target_cell
		)

	if not moved:
		print(
			"Failed to move ",
			selected_unit.display_name,
			" to ",
			target_cell
		)

		return

	selected_unit.mark_moved()

	print(
		"Moved ",
		selected_unit.display_name,
		" to ",
		target_cell
	)

	_refresh_movement_highlights()


# --------------------------------------------------
# PLAYER ATTACK
# --------------------------------------------------

func _try_enter_attack_mode() -> void:
	var active_unit: Unit = \
		turn_controller.active_unit

	if active_unit == null:
		return

	if not active_unit.is_player_unit():
		return

	if not active_unit.can_act():
		print(
			active_unit.display_name,
			" has already acted."
		)

		return

	if active_unit.weapon == null:
		print(
			active_unit.display_name,
			" has no weapon."
		)

		return

	selected_unit = active_unit
	selected_unit.select()

	input_mode = \
		InputMode.ATTACK_TARGETING

	movement_highlights.clear()
	valid_move_cells.clear()

	valid_attack_cells = \
		grid_controller.get_cells_in_range(
			active_unit.grid_position,
			active_unit.weapon.min_range,
			active_unit.weapon.max_range
		)

	attack_highlights.show_cells(
		valid_attack_cells
	)

	print(
		"Attack mode: ",
		active_unit.weapon.display_name
	)


func _try_attack_cell(
	cell: Vector2i
) -> void:
	if selected_unit == null:
		_exit_attack_mode()
		return

	if cell not in valid_attack_cells:
		print(
			"Target is outside weapon range."
		)

		return

	var target: Unit = \
		grid_controller.get_unit_at(cell)

	if target == null:
		print(
			"No target at ",
			cell
		)

		return

	if target.team == selected_unit.team:
		print(
			"Cannot attack friendly unit."
		)

		return

	_execute_basic_attack(
		selected_unit,
		target
	)


func _execute_basic_attack(
	attacker: Unit,
	target: Unit
) -> void:
	if attacker.weapon == null:
		return

	var damage: int = \
		_roll_weapon_damage(
			attacker.weapon
		)

	print(
		attacker.display_name,
		" attacks ",
		target.display_name,
		" with ",
		attacker.weapon.display_name,
		" for ",
		damage,
		" damage."
	)

	target.take_damage(damage)

	attacker.mark_acted()

	_exit_attack_mode()


func _roll_weapon_damage(
	weapon: WeaponDefinition
) -> int:
	var total: int = weapon.damage_bonus

	for roll_index: int in range(
		weapon.damage_dice
	):
		total += randi_range(
			1,
			weapon.damage_sides
		)

	return total


func _exit_attack_mode() -> void:
	input_mode = InputMode.NORMAL

	valid_attack_cells.clear()
	attack_highlights.clear()

	_refresh_movement_highlights()


# --------------------------------------------------
# UNIT DEATH
# --------------------------------------------------

func _on_unit_died(unit: Unit) -> void:
	print(
		"Removing ",
		unit.display_name,
		" from battlefield."
	)

	if selected_unit == unit:
		_clear_selection_state()

	grid_controller.unregister_unit(unit)

	if enemy_intents.has(unit):
		enemy_intents.erase(unit)

	_refresh_intent_highlights()

	unit.visible = false

	_check_battle_end()

# --------------------------------------------------
# TURN END
# --------------------------------------------------

func _try_end_player_activation() -> void:
	var active_unit: Unit = \
		turn_controller.active_unit

	if active_unit == null:
		return

	if not active_unit.is_player_unit():
		return

	print(
		"Ending activation for ",
		active_unit.display_name
	)

	_clear_selection_state()

	turn_controller.end_current_activation()


func _clear_selection_state() -> void:
	if selected_unit != null:
		selected_unit.deselect()

	selected_unit = null

	valid_move_cells.clear()
	valid_attack_cells.clear()

	movement_highlights.clear()
	attack_highlights.clear()

	input_mode = InputMode.NORMAL


func _get_grid_distance(
	a: Vector2i,
	b: Vector2i
) -> int:
	return (
		absi(a.x - b.x)
		+ absi(a.y - b.y)
	)

func _check_battle_end() -> void:
	var player_alive: bool = false
	var enemy_alive: bool = false

	for unit: Unit in turn_controller.turn_order:
		if unit == null:
			continue

		if not unit.is_alive:
			continue

		if unit.is_player_unit():
			player_alive = true
		elif unit.is_enemy_unit():
			enemy_alive = true

	if not player_alive:
		_end_battle(false)
		return

	if not enemy_alive:
		_end_battle(true)

func _end_battle(player_won: bool) -> void:
	turn_controller.stop_battle()

	_clear_selection_state()

	enemy_intents.clear()
	intent_highlights.clear()

	print("")
	print("====================")

	if player_won:
		print("VICTORY")
	else:
		print("DEFEAT")

	print("====================")
