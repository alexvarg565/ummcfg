class_name BattleController
extends Node2D


enum InputMode {
	NORMAL,
	ATTACK_TARGETING
}


const ENEMY_START_DELAY: float = 0.35
const ENEMY_MOVE_DELAY: float = 0.30
const ENEMY_ATTACK_DELAY: float = 0.40


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

@onready var combat_feedback: CombatFeedback = \
	$Battlefield/EffectLayer/CombatFeedback

@onready var unit_layer: Node2D = \
	$Battlefield/UnitLayer

@onready var battle_hud: BattleHUD = \
	$BattleHUD


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

	battle_hud.attack_requested.connect(
		_on_hud_attack_requested
	)

	battle_hud.end_turn_requested.connect(
		_on_hud_end_turn_requested
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


func _register_unit_signals() -> void:
	for unit: Unit in all_units:
		if not unit.died.is_connected(
			_on_unit_died
		):
			unit.died.connect(
				_on_unit_died
			)

		if not unit.health_changed.is_connected(
			_on_unit_health_changed
		):
			unit.health_changed.connect(
				_on_unit_health_changed
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
		if not spawn_positions.has(
			unit.name
		):
			continue

		var spawn_cell: Vector2i = \
			spawn_positions[unit.name]

		grid_controller.register_unit(
			unit,
			spawn_cell
		)


func _start_turn_system() -> void:
	var initiative_order: Array[Unit] = \
		initiative_controller.build_order(
			all_units
		)

	battle_hud.refresh_initiative(
		initiative_order,
		null
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


func _on_hud_attack_requested() -> void:
	_try_enter_attack_mode()


func _on_hud_end_turn_requested() -> void:
	_try_end_player_activation()


# ==================================================
# ROUND / INITIATIVE
# ==================================================

func _on_round_started(
	round_number: int
) -> void:
	battle_hud.set_round(
		round_number
	)

	battle_hud.refresh_initiative(
		turn_controller.turn_order,
		turn_controller.active_unit
	)

	_plan_enemy_intents()


func _on_active_unit_changed(
	unit: Unit
) -> void:
	_clear_selection_state()

	battle_hud.show_unit(
		unit
	)

	battle_hud.refresh_initiative(
		turn_controller.turn_order,
		unit
	)

	_refresh_turn_indicators()

	if unit.is_player_unit():
		battle_hud.refresh_player_controls(
			unit
		)

		return

	battle_hud.set_player_controls_enabled(
		false
	)

	_execute_enemy_turn(
		unit
	)


func _refresh_turn_indicators() -> void:
	for unit: Unit in all_units:
		if unit == null:
			continue

		unit.clear_turn_indicators()

	var active_unit: Unit = \
		turn_controller.active_unit

	if (
		active_unit != null
		and active_unit.is_alive
	):
		active_unit.set_active_indicator(
			true
		)

	var next_unit: Unit = \
		turn_controller.get_next_living_unit()

	if (
		next_unit != null
		and next_unit != active_unit
	):
		next_unit.set_next_indicator(
			true
		)


# ==================================================
# ENEMY INTENT
# ==================================================

func _plan_enemy_intents() -> void:
	enemy_intents.clear()
	intent_highlights.clear()

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
			continue

		enemy_intents[enemy] = intent

	_refresh_intent_highlights()


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


func _refresh_intent_highlights() -> void:
	var visible_intents: Array[EnemyIntent] = []

	for intent_value: Variant in \
		enemy_intents.values():

		var intent: EnemyIntent = \
			intent_value as EnemyIntent

		if intent == null:
			continue

		if intent.actor == null:
			continue

		if not intent.actor.is_alive:
			continue

		visible_intents.append(
			intent
		)

	intent_highlights.show_intents(
		visible_intents
	)


# ==================================================
# ENEMY TURN
# ==================================================

func _execute_enemy_turn(
	enemy: Unit
) -> void:
	if not enemy.is_alive:
		turn_controller.end_current_activation()
		return

	await get_tree().create_timer(
		ENEMY_START_DELAY
	).timeout

	if not turn_controller.battle_running:
		return

	if not enemy.is_alive:
		turn_controller.end_current_activation()
		return

	var intent: EnemyIntent = null

	if enemy_intents.has(
		enemy
	):
		intent = enemy_intents[enemy]

	if intent == null:
		var starting_cell: Vector2i = \
			enemy.grid_position

		_move_enemy_without_intent(
			enemy
		)

		if enemy.grid_position != starting_cell:
			await get_tree().create_timer(
				ENEMY_MOVE_DELAY
			).timeout

		if not turn_controller.battle_running:
			return

		turn_controller.end_current_activation()
		return

	var starting_cell: Vector2i = \
		enemy.grid_position

	_move_enemy_for_intent(
		enemy,
		intent
	)

	_refresh_intent_highlights()

	if enemy.grid_position != starting_cell:
		await get_tree().create_timer(
			ENEMY_MOVE_DELAY
		).timeout

		if not turn_controller.battle_running:
			return

	if not enemy.is_alive:
		turn_controller.end_current_activation()
		return

	if _can_execute_enemy_attack(
		intent
	):
		_execute_enemy_attack(
			intent
		)

	else:
		combat_feedback.show_miss(
			intent.target_cell
		)

	await get_tree().create_timer(
		ENEMY_ATTACK_DELAY
	).timeout

	if not turn_controller.battle_running:
		return

	enemy_intents.erase(
		enemy
	)

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

	if _is_target_in_weapon_range(
		enemy.weapon,
		enemy.grid_position,
		intent.target_cell
	):
		return

	var destination: Vector2i = \
		_choose_enemy_move_cell(
			enemy,
			intent
		)

	if destination == enemy.grid_position:
		return

	var moved: bool = \
		grid_controller.move_unit(
			enemy,
			destination
		)

	if moved:
		enemy.mark_moved()


func _choose_enemy_move_cell(
	enemy: Unit,
	intent: EnemyIntent
) -> Vector2i:
	var reachable_cells: Array[Vector2i] = \
		grid_controller.get_reachable_cells(
			enemy.grid_position,
			enemy.movement_range
		)

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

	if (
		distance >= weapon.min_range
		and distance <= weapon.max_range
	):
		return 0

	if distance > weapon.max_range:
		return distance - weapon.max_range

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
	intent.actor.mark_acted()

	var target: Unit = \
		grid_controller.get_unit_at(
			intent.target_cell
		)

	if target == null:
		combat_feedback.show_miss(
			intent.target_cell
		)

		return

	var damage: int = \
		_roll_weapon_damage(
			intent.weapon
		)

	var target_cell: Vector2i = \
		target.grid_position

	target.take_damage(
		damage
	)

	combat_feedback.show_damage(
		target_cell,
		damage
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
		return

	if not unit.is_player_unit():
		return

	if not turn_controller.is_units_turn(
		unit
	):
		return

	_select_unit(
		unit
	)


func _select_unit(
	unit: Unit
) -> void:
	selected_unit = unit
	selected_unit.select()

	_refresh_movement_highlights()

	battle_hud.show_unit(
		selected_unit
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
		return

	var moved: bool = \
		grid_controller.move_unit(
			selected_unit,
			target_cell
		)

	if not moved:
		return

	selected_unit.mark_moved()

	_refresh_movement_highlights()

	battle_hud.refresh_unit(
		selected_unit
	)


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
		return

	if active_unit.weapon == null:
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


func _try_attack_cell(
	cell: Vector2i
) -> void:
	if selected_unit == null:
		return

	if cell not in valid_attack_cells:
		return

	var target: Unit = \
		grid_controller.get_unit_at(
			cell
		)

	if target == null:
		return

	if target.team == \
		selected_unit.team:
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

	var target_cell: Vector2i = \
		target.grid_position

	target.take_damage(
		damage
	)

	combat_feedback.show_damage(
		target_cell,
		damage
	)

	attacker.mark_acted()

	battle_hud.refresh_unit(
		attacker
	)

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
# HEALTH / DEATH
# ==================================================

func _on_unit_health_changed(
	unit: Unit,
	_current_health: int,
	_max_health: int
) -> void:
	if turn_controller.active_unit == unit:
		battle_hud.refresh_unit(
			unit
		)


func _on_unit_died(
	unit: Unit
) -> void:
	if selected_unit == unit:
		_clear_selection_state()

	grid_controller.unregister_unit(
		unit
	)

	if enemy_intents.has(
		unit
	):
		enemy_intents.erase(
			unit
		)

	unit.visible = false

	_refresh_intent_highlights()
	_refresh_turn_indicators()

	battle_hud.refresh_initiative(
		turn_controller.turn_order,
		turn_controller.active_unit
	)

	_check_battle_end()


func _check_battle_end() -> void:
	var player_alive: bool = false
	var enemy_alive: bool = false

	for unit: Unit in player_units:
		if unit.is_alive:
			player_alive = true
			break

	for unit: Unit in enemy_units:
		if unit.is_alive:
			enemy_alive = true
			break

	if not player_alive:
		_end_battle(false)

	elif not enemy_alive:
		_end_battle(true)


func _end_battle(
	player_won: bool
) -> void:
	turn_controller.stop_battle()

	_clear_selection_state()

	for unit: Unit in all_units:
		unit.clear_turn_indicators()

	enemy_intents.clear()
	intent_highlights.clear()

	battle_hud.set_player_controls_enabled(
		false
	)

	battle_hud.clear_unit()

	battle_hud.refresh_initiative(
		turn_controller.turn_order,
		null
	)

	print(
		"VICTORY"
		if player_won
		else "DEFEAT"
	)


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
