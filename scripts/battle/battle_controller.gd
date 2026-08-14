class_name BattleController
extends Node2D


@onready var grid_controller: GridController = $Systems/GridController
@onready var grid_cursor: GridCursor = $Battlefield/GridCursor
@onready var test_mech: Unit = $Battlefield/UnitLayer/TestMech

var selected_unit: Unit = null


func _ready() -> void:
	print("Battle initialized.")

	grid_cursor.cell_selected.connect(_on_cell_selected)

	var placed := grid_controller.register_unit(
		test_mech,
		Vector2i(2, 3)
	)

	if placed:
		print(
			"Placed ",
			test_mech.display_name,
			" at ",
			test_mech.grid_position
		)
	else:
		push_error("Failed to place test mech.")


func _on_cell_selected(cell: Vector2i) -> void:
	var unit := grid_controller.get_unit_at(cell)

	if unit == null:
		_clear_selected_unit()
		print("No unit at ", cell)
		return

	_select_unit(unit)


func _select_unit(unit: Unit) -> void:
	if selected_unit == unit:
		return

	if selected_unit != null:
		selected_unit.deselect()

	selected_unit = unit
	selected_unit.select()

	print(
		"Selected ",
		selected_unit.display_name,
		" at ",
		selected_unit.grid_position
	)


func _clear_selected_unit() -> void:
	if selected_unit == null:
		return

	selected_unit.deselect()
	selected_unit = null

	print("Selection cleared.")
