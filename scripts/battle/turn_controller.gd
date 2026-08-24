class_name TurnController
extends Node


signal round_started(round_number: int)
signal round_finished(round_number: int)

signal active_unit_changed(unit: Unit)
signal activation_finished(unit: Unit)


var turn_order: Array[Unit] = []
var active_unit: Unit = null

var round_number: int = 0
var current_index: int = -1

var battle_running: bool = false


func start_battle(
	order: Array[Unit]
) -> void:
	turn_order = order

	if turn_order.is_empty():
		push_error(
			"Cannot start battle without units."
		)
		return

	battle_running = true

	_start_round()


func stop_battle() -> void:
	battle_running = false

	if active_unit != null:
		active_unit.end_activation()

	active_unit = null


func _start_round() -> void:
	if not battle_running:
		return

	round_number += 1
	current_index = -1

	round_started.emit(
		round_number
	)

	print("")
	print(
		"=== ROUND ",
		round_number,
		" ==="
	)

	_advance_turn()


func _advance_turn() -> void:
	if not battle_running:
		return

	current_index += 1

	if current_index >= turn_order.size():
		_finish_round()
		return

	var candidate: Unit = \
		turn_order[current_index]

	if candidate == null:
		_advance_turn()
		return

	if not candidate.is_alive:
		_advance_turn()
		return

	active_unit = candidate
	active_unit.begin_activation()

	print(
		"Active unit: ",
		active_unit.display_name,
		" | Initiative: ",
		active_unit.initiative
	)

	active_unit_changed.emit(
		active_unit
	)


func end_current_activation() -> void:
	if not battle_running:
		return

	if active_unit == null:
		return

	var finished_unit: Unit = \
		active_unit

	finished_unit.end_activation()

	activation_finished.emit(
		finished_unit
	)

	active_unit = null

	_advance_turn()


func _finish_round() -> void:
	if not battle_running:
		return

	print(
		"=== END ROUND ",
		round_number,
		" ==="
	)

	round_finished.emit(
		round_number
	)

	_start_round()


func is_units_turn(
	unit: Unit
) -> bool:
	return (
		battle_running
		and unit != null
		and unit == active_unit
	)


func get_next_living_unit() -> Unit:
	if turn_order.is_empty():
		return null

	if current_index < 0:
		return null

	# Search everything after the active unit.
	# This automatically wraps into the next round.
	for offset: int in range(
		1,
		turn_order.size()
	):
		var index: int = (
			current_index + offset
		) % turn_order.size()

		var candidate: Unit = \
			turn_order[index]

		if candidate == null:
			continue

		if not candidate.is_alive:
			continue

		return candidate

	return null
