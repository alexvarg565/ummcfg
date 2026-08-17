class_name IntentHighlights
extends Node2D


const INTENT_COLOR := Color(1.0, 0.45, 0.1, 0.45)

var highlighted_cells: Array[Vector2i] = []


func show_cells(cells: Array[Vector2i]) -> void:
	highlighted_cells = cells.duplicate()
	queue_redraw()


func clear() -> void:
	highlighted_cells.clear()
	queue_redraw()


func _draw() -> void:
	for cell: Vector2i in highlighted_cells:
		var draw_position := Vector2(
			cell.x * GridController.TILE_SIZE,
			cell.y * GridController.TILE_SIZE
		)

		draw_rect(
			Rect2(
				draw_position,
				Vector2(
					GridController.TILE_SIZE,
					GridController.TILE_SIZE
				)
			),
			INTENT_COLOR,
			true
		)
