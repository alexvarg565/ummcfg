class_name GridCursor
extends Node2D


signal cell_selected(cell: Vector2i)

const CURSOR_COLOR := Color(1.0, 0.85, 0.25, 1.0)
const CURSOR_WIDTH: float = 2.0

var grid_position: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_update_world_position()


func _unhandled_input(event: InputEvent) -> void:
	# Convert mouse world coordinates to battlefield-local grid cells.
	# The parent stays stationary while this cursor moves, so do not use
	# the cursor's own to_local() transform for the conversion.
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = \
			event as InputEventMouseButton

		if (
			mouse_button.button_index == MOUSE_BUTTON_LEFT
			and mouse_button.pressed
		):
			var battlefield: Node2D = get_parent() as Node2D
			if battlefield == null:
				return

			var battlefield_position: Vector2 = \
				battlefield.to_local(get_global_mouse_position())

			var clicked_cell: Vector2i = Vector2i(
				floori(battlefield_position.x / GridController.TILE_SIZE),
				floori(battlefield_position.y / GridController.TILE_SIZE)
			)

			if _is_inside_grid(clicked_cell):
				grid_position = clicked_cell
				_update_world_position()
				cell_selected.emit(clicked_cell)
				get_viewport().set_input_as_handled()

		return

	var direction := Vector2i.ZERO

	if event.is_action_pressed("cursor_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("cursor_down"):
		direction = Vector2i.DOWN
	elif event.is_action_pressed("cursor_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("cursor_right"):
		direction = Vector2i.RIGHT
	elif event.is_action_pressed("select"):
		cell_selected.emit(grid_position)
		get_viewport().set_input_as_handled()
		return

	if direction != Vector2i.ZERO:
		_move_cursor(direction)
		get_viewport().set_input_as_handled()


func _move_cursor(direction: Vector2i) -> void:
	var target_position: Vector2i = grid_position + direction

	if not _is_inside_grid(target_position):
		return

	grid_position = target_position
	_update_world_position()


func _is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < GridController.GRID_WIDTH
		and cell.y >= 0
		and cell.y < GridController.GRID_HEIGHT
	)


func _update_world_position() -> void:
	position = Vector2(
		grid_position.x * GridController.TILE_SIZE,
		grid_position.y * GridController.TILE_SIZE
	)


func _draw() -> void:
	var tile_size: int = GridController.TILE_SIZE

	var rect := Rect2(
		Vector2.ONE,
		Vector2(tile_size - 2, tile_size - 2)
	)

	draw_rect(
		rect,
		CURSOR_COLOR,
		false,
		CURSOR_WIDTH
	)
