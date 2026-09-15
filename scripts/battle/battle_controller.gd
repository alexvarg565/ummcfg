class_name BattleController
extends Node2D


enum InputMode {
	NORMAL,
	ATTACK_TARGETING
}


const PLAYER_MOVE_STEP_DURATION: float = 0.10

const ENEMY_START_DELAY: float = 0.35
const ENEMY_MOVE_STEP_DURATION: float = 0.14
const ENEMY_POST_MOVE_DELAY: float = 0.10
const ENEMY_ATTACK_DELAY: float = 0.40


const OBJECTIVE_TARGET_PRIORITY_BONUS: int = 2

const INVALID_TARGET_CELL: Vector2i = Vector2i(
	-999,
	-999
)


# ==================================================
# SYSTEM REFERENCES
# ==================================================

@onready var grid_controller: GridController = \
	$Systems/GridController

@onready var initiative_controller: InitiativeController = \
	$Systems/InitiativeController

@onready var turn_controller: TurnController = \
	$Systems/TurnController

@onready var displacement_system: DisplacementSystem = \
	$Systems/DisplacementSystem


# ==================================================
# BATTLEFIELD REFERENCES
# ==================================================

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

@onready var objective_structure: ObjectiveStructure = \
	$Battlefield/ObjectiveLayer/Generator


# ==================================================
# UI REFERENCES
# ==================================================

@onready var battle_hud: BattleHUD = \
	$BattleHUD


# ==================================================
# UNIT COLLECTIONS
# ==================================================

var all_units: Array[Unit] = []
var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []


# ==================================================
# PLAYER INPUT STATE
# ==================================================

var selected_unit: Unit = null

var valid_move_cells: Array[Vector2i] = []
var valid_attack_cells: Array[Vector2i] = []

var input_mode: InputMode = InputMode.NORMAL

var is_player_movement_animating: bool = false


# ==================================================
# ENEMY PLANS
# ==================================================

var enemy_intents: Dictionary = {}


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	print("Battle initialized.")
	print("Contract: Defend the Settlement Generator")

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

	battle_hud.result_continue_requested.connect(
		_on_result_continue_requested
	)

	battle_hud.result_restart_requested.connect(
		_on_result_restart_requested
	)

	_collect_units()
	_register_unit_signals()

	_place_units()
	_place_objective()
	_register_objective_signals()
	_setup_objective_hud()

	_start_turn_system()


# ==================================================
# UNIT COLLECTION / SETUP
# ==================================================

func _collect_units() -> void:
	all_units.clear()
	player_units.clear()
	enemy_units.clear()

	for child: Node in unit_layer.get_children():
		var unit: Unit = \
			child as Unit

		if unit == null:
			continue

		all_units.append(
			unit
		)

		if unit.is_player_unit():
			player_units.append(
				unit
			)

		elif unit.is_enemy_unit():
			enemy_units.append(
				unit
			)


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


func _register_objective_signals() -> void:
	if objective_structure == null:
		return

	if not objective_structure.destroyed.is_connected(
		_on_objective_destroyed
	):
		objective_structure.destroyed.connect(
			_on_objective_destroyed
		)

	if not objective_structure.health_changed.is_connected(
		_on_objective_health_changed
	):
		objective_structure.health_changed.connect(
			_on_objective_health_changed
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


func _place_objective() -> void:
	if objective_structure == null:
		push_error(
			"Objective structure reference is missing."
		)

		return

	var objective_cell: Vector2i = \
		Vector2i(
			3,
			3
		)

	objective_structure.set_grid_position(
		objective_cell
	)

	var registered: bool = \
		grid_controller.register_static_blocker(
			objective_structure,
			objective_cell
		)

	if not registered:
		push_error(
			"Could not place objective structure at %s."
			% objective_cell
		)


# ==================================================
# OBJECTIVE HUD
# ==================================================

func _setup_objective_hud() -> void:
	if objective_structure == null:
		return

	battle_hud.show_objective(
		"DEFEND THE GENERATOR",
		objective_structure.display_name,
		objective_structure.current_health,
		objective_structure.max_health
	)


# ==================================================
# TURN SYSTEM START
# ==================================================

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
	if not turn_controller.battle_running:
		return

	if is_player_movement_animating:
		return

	if event.is_action_pressed(
		"ui_cancel"
	):
		if input_mode == InputMode.ATTACK_TARGETING:

			_exit_attack_mode()

			get_viewport().set_input_as_handled()

			return

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
	if not turn_controller.battle_running:
		return

	if is_player_movement_animating:
		return

	_try_enter_attack_mode()


func _on_hud_end_turn_requested() -> void:
	if not turn_controller.battle_running:
		return

	if is_player_movement_animating:
		return

	_try_end_player_activation()


# ==================================================
# RESULTS
# ==================================================

func _on_result_restart_requested() -> void:
	get_tree().reload_current_scene()


func _on_result_continue_requested() -> void:
	RunManager.complete_contract()


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
# ENEMY PLAN CREATION
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

	var target_cell: Vector2i = \
		_find_best_enemy_target_cell(
			enemy
		)

	if target_cell == INVALID_TARGET_CELL:
		return null

	var intent: EnemyIntent = \
		EnemyIntent.new(
			enemy,
			target_cell,
			enemy.weapon
		)

	var destination: Vector2i = \
		_choose_enemy_plan_destination(
			enemy,
			intent
		)

	if destination == enemy.grid_position:
		return intent

	var path: Array[Vector2i] = \
		grid_controller.get_shortest_path(
			enemy.grid_position,
			destination
		)

	intent.set_movement_path(
		path
	)

	return intent


# ==================================================
# ENEMY TARGET SELECTION
# ==================================================

func _find_best_enemy_target_cell(
	enemy: Unit
) -> Vector2i:
	var best_cell: Vector2i = \
		INVALID_TARGET_CELL

	var best_score: int = 999999

	for candidate: Unit in player_units:

		if candidate == null:
			continue

		if not candidate.is_alive:
			continue

		var score: int = \
			_get_grid_distance(
				enemy.grid_position,
				candidate.grid_position
			)

		if score < best_score:

			best_score = score

			best_cell = \
				candidate.grid_position

	if (
		objective_structure != null
		and not objective_structure.is_destroyed
	):

		var objective_distance: int = \
			_get_grid_distance(
				enemy.grid_position,
				objective_structure.grid_position
			)

		var objective_score: int = \
			objective_distance \
			- OBJECTIVE_TARGET_PRIORITY_BONUS

		if objective_score <= best_score:

			best_score = objective_score

			best_cell = \
				objective_structure.grid_position

	return best_cell


func _choose_enemy_plan_destination(
	enemy: Unit,
	intent: EnemyIntent
) -> Vector2i:
	if enemy.weapon == null:
		return enemy.grid_position

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
			best_move_distance = \
				move_distance
			best_cell = cell

			continue

		if (
			score == best_score
			and move_distance < best_move_distance
		):

			best_move_distance = \
				move_distance
			best_cell = cell

	return best_cell


# ==================================================
# ENEMY PLAN VISUALIZATION
# ==================================================

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
		intent = \
			enemy_intents[enemy] as EnemyIntent

	if intent == null:

		turn_controller.end_current_activation()

		return

	var moved: bool = \
		await _execute_planned_enemy_movement(
			enemy,
			intent
		)

	_adjust_intent_for_actual_firing_position(
		enemy,
		intent
	)

	_refresh_intent_highlights()

	if moved:

		await get_tree().create_timer(
			ENEMY_POST_MOVE_DELAY
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
# COMMITTED ENEMY MOVEMENT
# ==================================================

func _execute_planned_enemy_movement(
	enemy: Unit,
	intent: EnemyIntent
) -> bool:
	if enemy == null:
		return false

	if intent == null:
		return false

	if not enemy.is_alive:
		return false

	if intent.movement_path.is_empty():
		return false

	var moved: bool = false

	for planned_cell: Vector2i in \
		intent.movement_path:

		if not grid_controller.is_inside_grid(
			planned_cell
		):
			break

		if grid_controller.is_occupied(
			planned_cell
		):
			break

		var old_visual_position: Vector2 = \
			enemy.position

		var step_successful: bool = \
			grid_controller.move_unit(
				enemy,
				planned_cell
			)

		if not step_successful:
			break

		moved = true

		var destination_position: Vector2 = \
			enemy.position

		enemy.position = \
			old_visual_position

		await _animate_enemy_move_step(
			enemy,
			destination_position
		)

		if not turn_controller.battle_running:
			return moved

		if not enemy.is_alive:
			return moved

		_refresh_intent_highlights()

	if moved:
		enemy.mark_moved()

	return moved


func _animate_enemy_move_step(
	enemy: Unit,
	destination_position: Vector2
) -> void:
	if enemy == null:
		return

	var tween: Tween = \
		create_tween()

	tween.tween_property(
		enemy,
		"position",
		destination_position,
		ENEMY_MOVE_STEP_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished


func _adjust_intent_for_actual_firing_position(
	enemy: Unit,
	intent: EnemyIntent
) -> void:
	if enemy == null:
		return

	if intent == null:
		return

	if intent.movement_path.is_empty():
		return

	var planned_destination: Vector2i = \
		intent.get_move_destination()

	var actual_destination: Vector2i = \
		enemy.grid_position

	var firing_position_difference: Vector2i = \
		actual_destination \
		- planned_destination

	if firing_position_difference == Vector2i.ZERO:
		return

	intent.target_cell += \
		firing_position_difference


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

	var unit_target: Unit = \
		grid_controller.get_unit_at(
			intent.target_cell
		)

	if unit_target != null:

		var unit_damage: int = \
			_roll_weapon_damage(
				intent.weapon
			)

		var unit_target_cell: Vector2i = \
			unit_target.grid_position

		unit_target.take_damage(
			unit_damage
		)

		combat_feedback.show_damage(
			unit_target_cell,
			unit_damage
		)

		_apply_weapon_displacement(
			intent.actor,
			unit_target,
			intent.weapon
		)

		return

	var blocker: Node2D = \
		grid_controller.get_static_blocker_at(
			intent.target_cell
		)

	var objective_target: ObjectiveStructure = \
		blocker as ObjectiveStructure

	if (
		objective_target != null
		and not objective_target.is_destroyed
	):

		var objective_damage: int = \
			_roll_weapon_damage(
				intent.weapon
			)

		objective_target.take_damage(
			objective_damage
		)

		combat_feedback.show_damage(
			intent.target_cell,
			objective_damage
		)

		return

	combat_feedback.show_miss(
		intent.target_cell
	)


# ==================================================
# PLAYER SELECTION / MOVEMENT
# ==================================================

func _on_cell_selected(
	cell: Vector2i
) -> void:
	if not turn_controller.battle_running:
		return

	if is_player_movement_animating:
		return

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

		await _move_selected_unit(
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


# ==================================================
# ANIMATED PLAYER MOVEMENT
# ==================================================

func _move_selected_unit(
	target_cell: Vector2i
) -> void:
	if selected_unit == null:
		return

	if not selected_unit.can_move():
		return

	if is_player_movement_animating:
		return

	var moving_unit: Unit = \
		selected_unit

	var movement_path: Array[Vector2i] = \
		grid_controller.get_shortest_path(
			moving_unit.grid_position,
			target_cell
		)

	if movement_path.is_empty():
		return

	is_player_movement_animating = true

	movement_highlights.clear()

	valid_move_cells.clear()

	for path_cell: Vector2i in \
		movement_path:

		if not grid_controller.is_inside_grid(
			path_cell
		):
			break

		if grid_controller.is_occupied(
			path_cell
		):
			break

		var old_visual_position: Vector2 = \
			moving_unit.position

		var step_successful: bool = \
			grid_controller.move_unit(
				moving_unit,
				path_cell
			)

		if not step_successful:
			break

		var destination_position: Vector2 = \
			moving_unit.position

		moving_unit.position = \
			old_visual_position

		await _animate_player_move_step(
			moving_unit,
			destination_position
		)

	moving_unit.mark_moved()

	is_player_movement_animating = false

	battle_hud.refresh_unit(
		moving_unit
	)

	battle_hud.refresh_player_controls(
		moving_unit
	)

	_refresh_movement_highlights()


func _animate_player_move_step(
	unit: Unit,
	destination_position: Vector2
) -> void:
	if unit == null:
		return

	var tween: Tween = \
		create_tween()

	tween.tween_property(
		unit,
		"position",
		destination_position,
		PLAYER_MOVE_STEP_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)

	await tween.finished


# ==================================================
# PLAYER ATTACK
# ==================================================

func _try_enter_attack_mode() -> void:
	if not turn_controller.battle_running:
		return

	if is_player_movement_animating:
		return

	var active_unit: Unit = \
		turn_controller.active_unit

	if active_unit == null:
		return

	if not active_unit.is_player_unit():
		return

	if input_mode == InputMode.ATTACK_TARGETING:

		_exit_attack_mode()

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

	var weapon: WeaponDefinition = \
		attacker.weapon

	var damage: int = \
		_roll_weapon_damage(
			weapon
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

	_apply_weapon_displacement(
		attacker,
		target,
		weapon
	)

	attacker.mark_acted()

	battle_hud.refresh_unit(
		attacker
	)

	battle_hud.refresh_player_controls(
		attacker
	)

	_exit_attack_mode()


func _roll_weapon_damage(
	weapon: WeaponDefinition
) -> int:
	var total: int = \
		weapon.damage_bonus

	for _roll_index: int in range(
		weapon.damage_dice
	):

		total += randi_range(
			1,
			weapon.damage_sides
		)

	return total


func _exit_attack_mode() -> void:
	input_mode = \
		InputMode.NORMAL

	valid_attack_cells.clear()

	attack_highlights.clear()

	_refresh_movement_highlights()


# ==================================================
# WEAPON EFFECTS / DISPLACEMENT
# ==================================================

func _apply_weapon_displacement(
	attacker: Unit,
	target: Unit,
	weapon: WeaponDefinition
) -> void:
	if attacker == null:
		return

	if target == null:
		return

	if weapon == null:
		return

	if not target.is_alive:
		return

	if weapon.push_distance <= 0:
		return

	var old_cell: Vector2i = \
		target.grid_position

	var pushed: bool = \
		displacement_system.try_push(
			attacker,
			target,
			weapon.push_distance
		)

	if not pushed:
		return

	var new_cell: Vector2i = \
		target.grid_position

	var displacement: Vector2i = \
		new_cell - old_cell

	if (
		target.is_enemy_unit()
		and enemy_intents.has(target)
	):

		var intent: EnemyIntent = \
			enemy_intents[target] as EnemyIntent

		if intent != null:

			intent.translate_plan(
				displacement
			)

	_refresh_intent_highlights()


# ==================================================
# OBJECTIVE EVENTS
# ==================================================

func _on_objective_health_changed(
	structure: ObjectiveStructure,
	current_health: int,
	max_health: int
) -> void:
	battle_hud.update_objective_health(
		current_health,
		max_health
	)

	print(
		"%s HP: %d/%d"
		% [
			structure.display_name,
			current_health,
			max_health
		]
	)


func _on_objective_destroyed(
	structure: ObjectiveStructure
) -> void:
	grid_controller.unregister_static_blocker(
		structure.grid_position
	)

	print(
		"%s DESTROYED"
		% structure.display_name
	)

	_end_battle(
		false,
		"Generator Destroyed"
	)


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


# ==================================================
# BATTLE END
# ==================================================

func _check_battle_end() -> void:
	if (
		objective_structure != null
		and objective_structure.is_destroyed
	):

		_end_battle(
			false,
			"Generator Destroyed"
		)

		return

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

		_end_battle(
			false,
			"All Player Mechs Destroyed"
		)

	elif not enemy_alive:

		_end_battle(
			true,
			"Generator Survived\nReward: +%d Salvage"
			% RunManager.get_current_salvage_reward()
		)


func _end_battle(
	player_won: bool,
	reason: String = ""
) -> void:
	if not turn_controller.battle_running:
		return

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

	battle_hud.show_battle_result(
		player_won,
		reason
	)

	if player_won:

		print(
			"CONTRACT COMPLETE"
		)

	else:

		print(
			"CONTRACT FAILED"
		)

	if not reason.is_empty():

		print(
			reason
		)


# ==================================================
# TURN END
# ==================================================

func _try_end_player_activation() -> void:
	if not turn_controller.battle_running:
		return

	if is_player_movement_animating:
		return

	var active_unit: Unit = \
		turn_controller.active_unit

	if active_unit == null:
		return

	if not active_unit.is_player_unit():
		return

	_clear_selection_state()

	turn_controller.end_current_activation()


# ==================================================
# SELECTION CLEANUP
# ==================================================

func _clear_selection_state() -> void:
	if selected_unit != null:

		selected_unit.deselect()

	selected_unit = null

	valid_move_cells.clear()

	valid_attack_cells.clear()

	movement_highlights.clear()

	attack_highlights.clear()

	input_mode = \
		InputMode.NORMAL


# ==================================================
# COMBAT HELPERS
# ==================================================

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

		return (
			distance
			- weapon.max_range
		)

	return (
		weapon.min_range
		- distance
	)


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
		absi(
			a.x - b.x
		)
		+ absi(
			a.y - b.y
		)
	)
