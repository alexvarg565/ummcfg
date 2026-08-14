class_name GridOverlay
extends Node2D


const GRID_COLOR := Color(0.55, 0.65, 0.50, 1.0)
const BACKGROUND_COLOR := Color(0.12, 0.14, 0.12, 1.0)


func _draw() -> void:
	var board_size := Vector2(
		GridController.GRID_WIDTH * GridController.TILE_SIZE,
		GridController.GRID_HEIGHT * GridController.TILE_SIZE
	)

	draw_rect(
		Rect2(Vector2.ZERO, board_size),
		BACKGROUND_COLOR,
		true
	)

	for x in range(GridController.GRID_WIDTH + 1):
		var x_position := float(x * GridController.TILE_SIZE)

		draw_line(
			Vector2(x_position, 0),
			Vector2(x_position, board_size.y),
			GRID_COLOR,
			1.0
		)

	for y in range(GridController.GRID_HEIGHT + 1):
		var y_position := float(y * GridController.TILE_SIZE)

		draw_line(
			Vector2(0, y_position),
			Vector2(board_size.x, y_position),
			GRID_COLOR,
			1.0
		)
