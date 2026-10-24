class_name BattlefieldObstacle
extends Node2D

# Each obstacle occupies exactly one grid cell.
# These are indestructible terrain objects, not units or objectives.
enum ObstacleType {
	ROCK,
	SCRAP,
	BUILDING
}

@export var obstacle_type: ObstacleType = ObstacleType.ROCK

var grid_position: Vector2i = Vector2i.ZERO


func configure(cell: Vector2i, kind: ObstacleType) -> void:
	grid_position = cell
	obstacle_type = kind
	position = Vector2(cell * GridController.TILE_SIZE)
	queue_redraw()


func _draw() -> void:
	match obstacle_type:
		ObstacleType.ROCK:
			_draw_rock()
		ObstacleType.SCRAP:
			_draw_scrap()
		ObstacleType.BUILDING:
			_draw_building()


# Temporary 32 x 32 pixel-style art, easy to replace with a Sprite2D.
func _draw_rock() -> void:
	draw_rect(Rect2(7, 7, 18, 22), Color("#353d45"))
	draw_rect(Rect2(4, 12, 24, 13), Color("#596773"))
	draw_rect(Rect2(9, 7, 14, 6), Color("#84929a"))
	draw_rect(Rect2(5, 21, 21, 5), Color("#45505c"))
	draw_rect(Rect2(10, 13, 5, 3), Color("#a4afb4"))


func _draw_scrap() -> void:
	draw_rect(Rect2(5, 19, 23, 9), Color("#493b37"))
	draw_rect(Rect2(3, 15, 17, 8), Color("#936b46"))
	draw_rect(Rect2(11, 9, 17, 9), Color("#617781"))
	draw_rect(Rect2(16, 5, 5, 18), Color("#9ba8a7"))
	draw_rect(Rect2(6, 18, 5, 3), Color("#d4a15c"))
	draw_rect(Rect2(22, 20, 4, 5), Color("#b8704b"))


func _draw_building() -> void:
	draw_rect(Rect2(4, 10, 24, 19), Color("#353c4a"))
	draw_rect(Rect2(6, 5, 20, 7), Color("#667783"))
	draw_rect(Rect2(3, 10, 26, 4), Color("#929fa2"))
	draw_rect(Rect2(8, 16, 7, 8), Color("#273747"))
	draw_rect(Rect2(19, 16, 6, 8), Color("#273747"))
	draw_rect(Rect2(11, 17, 3, 3), Color("#c1a56c"))
	draw_rect(Rect2(22, 17, 2, 3), Color("#c1a56c"))
