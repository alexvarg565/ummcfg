class_name BattleController
extends Node2D


@onready var grid_controller: GridController = \
	$Systems/GridController

@onready var grid_cursor: GridCursor = \
	$Battlefield/GridCursor

@onready var movement_highlights: MovementHighlights = \
	$Battlefield/MovementHighlights

@onready var test_mech: Unit = \
	$Battlefield/UnitLayer/TestMech

@onready var blocker: Unit = \
	$Battlefield/UnitLayer/Blocker


var selected_unit: Unit = null
var valid_move_cells: Array[Vector2i] = []


func _ready() -> void:
	print("Battle initialized.")

	grid_cursor.cell_selected.connect(_on_cell_selected)

	_place_test_units()


func _place_test_units() -> void:
	test_mech.team = Unit.Team.PLAYER
	blocker.team = Unit.Team.ENEMY

	var mech_placed: bool = grid_controller.register_unit(
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
		push_error("Failed to place test mech.")

	var blocker_placed: bool = grid_controller.register_unit(
		blocker,
		Vector2i(3, 3)
	)

	if blocker_placed:
		print(
			"Placed ",
			blocker.display_name,
			" at ",
			blocker.grid_position
		)
	else:
		push_error("Failed to place blocker.")


func _on_cell_selected(cell: Vector2i) -> void:
	if (
		selected_unit != null
		and cell in valid_move_cells
	):
		_move_selected_unit(cell)
		return

	var unit: Unit = grid_controller.get_unit_at(cell)

	if unit == null:
		_clear_selected_unit()
		print("No unit at ", cell)
		return

	if not unit.is_player_unit():
		_clear_selected_unit()
		print("Cannot select enemy unit.")
		return

	_select_unit(unit)


func _select_unit(unit: Unit) -> void:
	if (
		selected_unit != null
		and selected_unit != unit
	):
		selected_unit.deselect()

	selected_unit = unit
	selected_unit.select()

	valid_move_cells = grid_controller.get_reachable_cells(
		selected_unit.grid_position,
		selected_unit.movement_range
	)

	movement_highlights.show_cells(
		valid_move_cells
	)

	print(
		"Selected ",
		selected_unit.display_name,
		" at ",
		selected_unit.grid_position
	)


func _move_selected_unit(target_cell: Vector2i) -> void:
	if selected_unit == null:
		return

	var moved: bool = grid_controller.move_unit(
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

	print(
		"Moved ",
		selected_unit.display_name,
		" to ",
		target_cell
	)

	_clear_selected_unit()


func _clear_selected_unit() -> void:
	if selected_unit != null:
		selected_unit.deselect()

	selected_unit = null
	valid_move_cells.clear()

	movement_highlights.clear()

	print("Selection cleared.")
