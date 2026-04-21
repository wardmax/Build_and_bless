extends Control

var _t = 0.0 # Time remaining for hit indicator
var cross_hair_length = 8
var cross_hair_thickness = 1

# Call this when an enemy is hit
func register_hit():
	_t = 0.15 # 0.15 seconds duration

func _draw():
	var center = get_viewport_rect().size / 2.0
	var color = Color.WHITE
	
	# Draw Indicator (Red 'X') if timer is active
	if _t > 0.0:
		color = Color(1, 0.2, 0) # Red
		draw_line(center + Vector2(-4,-4), center + Vector2(4,4), color, 2)
		draw_line(center + Vector2(4,-4), center + Vector2(-4,4), color, 2)
		
	# Draw Crosshair
	draw_line(center + Vector2(-cross_hair_length,0), center + Vector2(cross_hair_length,0), color, cross_hair_thickness)
	draw_line(center + Vector2(0,-cross_hair_length), center + Vector2(0,cross_hair_length), color, cross_hair_thickness)

func _process(delta):
	if _t > 0.0:
		_t -= delta
	queue_redraw()
