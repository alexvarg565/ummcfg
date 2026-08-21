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

@onready var unit_layer: Node2D = \
	$Battlefield/UnitLayer


var all_units: Array[Unit] = []
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []

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

	_collect_units()
	_register_unit_signals()
	_place_units()
	_start_turn_system()


# ==================================================
# UNIT COLLECTION / SETUP
# ==================================================

func _collect_units() -> void:
	all_units.clear()
	player_units.clear()
	enemy_units.clear()

	for child: Node in unit_layer.get_children():
		var unit: Unit = child as Unit

		if unit == null:
			continue

		all_units.append(unit)

		if unit.is_player_unit():
			player_units.append(unit)
		elif unit.is_enemy_unit():
			enemy_units.append(unit)

	print(
		"Collected ",
		all_units.size(),
		" units."
	)

	print(
		"Players: ",
		player_units.size(),
		" | Enemies: ",
		enemy_units.size()
	)


func _register_unit_signals() -> void:
	for unit: Unit in all_units:
		if not unit.died.is_connected(
			_on_unit_died
		):
			unit.died.connect(
				_on_unit_died
			)


func _place_units() -> void:
	var spawn_positions: Dictionary = {
		"MechA": Vector2i(1, 2),
		"MechB": Vector2i(1, 4),
		"MechC": Vector2i(1, 6),
		"GruntA": Vector2i(6, 2),
		"Elite": Vector2i(6, 4),
		"GruntB": Vector2i(6, 6)
	}

	for unit: Unit in all_units:
		if not spawn_positions.has(unit.name):
			push_warning(
				"No spawn position found for ",
				unit.name
			)

			continue

		var spawn_cell: Vector2i = \
			spawn_positions[unit.name]

		var placed: bool = \
			grid_controller.register_unit(
				unit,
				spawn_cell
			)

		if placed:
			print(
				"Placed ",
				unit.display_name,
				" at ",
				unit.grid_position
			)
		else:
			push_error(
				"Failed to place ",
				unit.display_name
			)


func _start_turn_system() -> void:
	var initiative_order: Array[Unit] = \
		initiative_controller.build_order(
			all_units
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


# ==================================================
# INPUT
# ==================================================

func _unhandled_input(
	event: InputEvent
) -> void:
	if event.is_action_pressed(
		"attack"
	):
		_try_enter_attack_mode()

		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(
		"end_turn"
	):
		_try_end_player_activation()

		get_viewport().set_input_as_handled()


# ==================================================
# ROUND / INITIATIVE
# ==================================================

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

		return

	print(
		"Enemy activation: ",
		unit.display_name
	)

	_execute_enemy_turn(
		unit
	)


# ==================================================
# ENEMY INTENT PLANNING
# ==================================================

func _plan_enemy_intents() -> void:
	enemy_intents.clear()
	intent_highlights.clear()

	var intent_cells: Array[Vector2i] = []

	for enemy: Unit in enemy_units:
		if enemy == null:
			continue

		if not enemy.is_alive:
			continue

		var intent: EnemyIntent = \
			_create_enemy_intent(
				enemy
			)

		if intent == null:
			print(
				enemy.display_name,
				" has no valid intent."
			)

			continue

		enemy_intents[enemy] = intent

		intent_cells.append(
			intent.target_cell
		)

		print(
			enemy.display_name,
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
		_find_closest_living_player(
			enemy
		)

	if target == null:
		return null

	return EnemyIntent.new(
		enemy,
		target.grid_position,
		enemy.weapon
	)


func _find_closest_living_player(
	enemy: Unit
) -> Unit:
	var best_target: Unit = null
	var best_distance: int = 999999

	for candidate: Unit in player_units:
		if candidate == null:
			continue

		if not candidate.is_alive:
			continue

		var distance: int = \
			_get_grid_distance(
				enemy.grid_position,
				candidate.grid_position
			)

		if distance < best_distance:
			best_distance = distance
			best_target = candidate

	return best_target


# ==================================================
# ENEMY TURN
# ==================================================

func _execute_enemy_turn(
	enemy: Unit
) -> void:
	if not enemy.is_alive:
		turn_controller.end_current_activation()
		return

	var intent: EnemyIntent = null

	if enemy_intents.has(enemy):
		intent = enemy_intents[enemy]

	if intent == null:
		print(
			enemy.display_name,
			" has no committed attack."
		)

		_move_enemy_without_intent(enemy)

		turn_controller.end_current_activation()
		return

	# Movement is chosen NOW, when the enemy's turn begins.
	_move_enemy_for_intent(
		enemy,
		intent
	)

	# The attack itself remains committed.
	if _can_execute_enemy_attack(
		intent
	):
		_execute_enemy_attack(
			intent
		)
	else:
		print(
			enemy.display_name,
			"'s committed attack failed."
		)

	enemy_intents.erase(enemy)

	_refresh_intent_highlights()

	turn_controller.end_current_activation()


# ==================================================
# ENEMY MOVEMENT
# ==================================================

func _move_enemy_for_intent(
	enemy: Unit,
	intent: EnemyIntent
) -> void:
	if enemy.weapon == null:
		return

	# If the enemy can already attack the committed
	# tile, staying still is currently preferred.
	if _is_target_in_weapon_range(
		enemy.weapon,
		enemy.grid_position,
		intent.target_cell
	):
		print(
			enemy.display_name,
			" is already in range."
		)

		return

	var destination: Vector2i = \
		_choose_enemy_move_cell(
			enemy,
			intent
		)

	if destination == enemy.grid_position:
		print(
			enemy.display_name,
			" cannot improve its position."
		)

		return

	var moved: bool = \
		grid_controller.move_unit(
			enemy,
			destination
		)

	if not moved:
		print(
			enemy.display_name,
			" could not move to ",
			destination
		)

		return

	enemy.mark_moved()

	print(
		enemy.display_name,
		" moves to ",
		destination
	)


func _choose_enemy_move_cell(
	enemy: Unit,
	intent: EnemyIntent
) -> Vector2i:
	var reachable_cells: Array[Vector2i] = \
		grid_controller.get_reachable_cells(
			enemy.grid_position,
			enemy.movement_range
		)

	# Staying where it is must also be considered
	# a legal movement choice.
	var best_cell: Vector2i = \
		enemy.grid_position

	var best_score: int = \
		_get_attack_position_score(
			enemy.weapon,
			best_cell,
			intent.target_cell
		)

	var best_move_distance: int = 0

	for cell: Vector2i in reachable_cells:
		var score: int = \
			_get_attack_position_score(
				enemy.weapon,
				cell,
				intent.target_cell
			)

		var move_distance: int = \
			_get_grid_distance(
				enemy.grid_position,
				cell
			)

		if score < best_score:
			best_score = score
			best_move_distance = move_distance
			best_cell = cell
			continue

		if (
			score == best_score
			and move_distance < best_move_distance
		):
			best_move_distance = move_distance
			best_cell = cell

	return best_cell


func _get_attack_position_score(
	weapon: WeaponDefinition,
	origin: Vector2i,
	target: Vector2i
) -> int:
	var distance: int = \
		_get_grid_distance(
			origin,
			target
		)

	# Perfect position.
	if (
		distance >= weapon.min_range
		and distance <= weapon.max_range
	):
		return 0

	# Too far away.
	if distance > weapon.max_range:
		return distance - weapon.max_range

	# Too close.
	return weapon.min_range - distance


func _move_enemy_without_intent(
	enemy: Unit
) -> void:
	var target: Unit = \
		_find_closest_living_player(
			enemy
		)

	if target == null:
		return

	var reachable_cells: Array[Vector2i] = \
		grid_controller.get_reachable_cells(
			enemy.grid_position,
			enemy.movement_range
		)

	var best_cell: Vector2i = \
		enemy.grid_position

	var best_distance: int = \
		_get_grid_distance(
			best_cell,
			target.grid_position
		)

	for cell: Vector2i in reachable_cells:
		var distance: int = \
			_get_grid_distance(
				cell,
				target.grid_position
			)

		if distance < best_distance:
			best_distance = distance
			best_cell = cell

	if best_cell == enemy.grid_position:
		return

	var moved: bool = \
		grid_controller.move_unit(
			enemy,
			best_cell
		)

	if moved:
		enemy.mark_moved()

		print(
			enemy.display_name,
			" advances to ",
			best_cell
		)


# ==================================================
# ENEMY ATTACK
# ==================================================

func _can_execute_enemy_attack(
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

	return _is_target_in_weapon_range(
		intent.weapon,
		intent.actor.grid_position,
		intent.target_cell
	)


func _execute_enemy_attack(
	intent: EnemyIntent
) -> void:
	# The primary action is consumed even if
	# the committed tile is now empty.
	intent.actor.mark_acted()

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

	var damage: int = \
		_roll_weapon_damage(
			intent.weapon
		)

	if target.team == intent.actor.team:
		print(
			intent.actor.display_name,
			" hits an allied unit!"
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

	target.take_damage(
		damage
	)


func _refresh_intent_highlights() -> void:
	var cells: Array[Vector2i] = []

	for intent_value: Variant in \
		enemy_intents.values():

		var intent: EnemyIntent = \
			intent_value as EnemyIntent

		if intent == null:
			continue

		cells.append(
			intent.target_cell
		)

	intent_highlights.show_cells(
		cells
	)


# ==================================================
# PLAYER SELECTION / MOVEMENT
# ==================================================

func _on_cell_selected(
	cell: Vector2i
) -> void:
	var active_unit: Unit = \
		turn_controller.active_unit

	if active_unit == null:
		return

	if not active_unit.is_player_unit():
		return

	if input_mode == \
		InputMode.ATTACK_TARGETING:

		_try_attack_cell(
			cell
		)

		return

	if (
		selected_unit != null
		and cell in valid_move_cells
	):
		_move_selected_unit(
			cell
		)

		return

	var unit: Unit = \
		grid_controller.get_unit_at(
			cell
		)

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

	_select_unit(
		unit
	)


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


# ==================================================
# PLAYER ATTACK
# ==================================================

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
		grid_controller.get_unit_at(
			cell
		)

	if target == null:
		print(
			"No target at ",
			cell
		)

		return

	if target.team == \
		selected_unit.team:

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

	target.take_damage(
		damage
	)

	attacker.mark_acted()

	_exit_attack_mode()


func _roll_weapon_damage(
	weapon: WeaponDefinition
) -> int:
	var total: int = \
		weapon.damage_bonus

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


# ==================================================
# UNIT DEATH / BATTLE END
# ==================================================

func _on_unit_died(
	unit: Unit
) -> void:
	print(
		"Removing ",
		unit.display_name,
		" from battlefield."
	)

	if selected_unit == unit:
		_clear_selection_state()

	grid_controller.unregister_unit(
		unit
	)

	if enemy_intents.has(unit):
		enemy_intents.erase(
			unit
		)

	_refresh_intent_highlights()

	unit.visible = false

	_check_battle_end()


func _check_battle_end() -> void:
	var player_alive: bool = false
	var enemy_alive: bool = false

	for unit: Unit in player_units:
		if (
			unit != null
			and unit.is_alive
		):
			player_alive = true
			break

	for unit: Unit in enemy_units:
		if (
			unit != null
			and unit.is_alive
		):
			enemy_alive = true
			break

	if not player_alive:
		_end_battle(false)
		return

	if not enemy_alive:
		_end_battle(true)


func _end_battle(
	player_won: bool
) -> void:
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


# ==================================================
# TURN END
# ==================================================

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


# ==================================================
# HELPERS
# ==================================================

func _is_target_in_weapon_range(
	weapon: WeaponDefinition,
	origin: Vector2i,
	target: Vector2i
) -> bool:
	var distance: int = \
		_get_grid_distance(
			origin,
			target
		)

	return (
		distance >= weapon.min_range
		and distance <= weapon.max_range
	)


func _get_grid_distance(
	a: Vector2i,
	b: Vector2i
) -> int:
	return (
		absi(a.x - b.x)
		+ absi(a.y - b.y)
	)
