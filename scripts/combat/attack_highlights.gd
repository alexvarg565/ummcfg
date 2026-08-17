class_name AttackHighlights
extends Node2D


const HIGHLIGHT_COLOR := Color(1.0, 0.2, 0.2, 0.35)

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
			HIGHLIGHT_COLOR,
			true
		)
