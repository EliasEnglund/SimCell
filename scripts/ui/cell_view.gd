extends Control
class_name CellView

var simulation
var _pulse := 0.0

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10292d"))
	var center := size * 0.5
	var molecule_count := 0.0
	if simulation != null:
		for id in simulation.molecule_amounts.keys():
			molecule_count += float(simulation.molecule_amounts[id])
	var radius := minf(size.x, size.y) * (0.22 + clampf(molecule_count / 1200.0, 0.0, 0.08))
	_draw_cell(center, radius)
	_draw_particles(center, radius)

func _draw_cell(center: Vector2, radius: float) -> void:
	var rx := radius * 1.45
	var ry := radius * 0.86
	_draw_filled_ellipse(center, Vector2(rx, ry), Color(0.12, 0.34, 0.38, 0.58))
	for ring in 3:
		_draw_ellipse_outline(center, Vector2(rx + ring * 7.0, ry + ring * 5.0), Color("76f4ff").darkened(ring * 0.18), 2.0)
	for i in 18:
		var angle := float(i) / 18.0 * TAU + sin(_pulse * 0.6) * 0.05
		var p := center + Vector2(cos(angle) * rx, sin(angle) * ry)
		draw_circle(p, 4.0, Color("9de6e1"))
	draw_circle(center + Vector2(rx * 0.22, -ry * 0.08), ry * 0.24, Color(0.65, 0.75, 0.78, 0.18))

func _draw_particles(center: Vector2, radius: float) -> void:
	for i in 80:
		var phase := _pulse * (0.35 + fposmod(i, 7) * 0.02) + i * 1.9
		var p := center + Vector2(cos(phase) * radius * fposmod(i * 0.17, 1.1), sin(phase * 1.34) * radius * fposmod(i * 0.13, 0.72))
		var color := Color("8ff0a4") if i % 4 != 0 else Color("e95058")
		draw_circle(p, 2.5 + fposmod(i, 3), Color(color.r, color.g, color.b, 0.62))

func _draw_filled_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = []
	for i in 128:
		var angle := float(i) / 128.0 * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _draw_ellipse_outline(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var previous := center + Vector2(radii.x, 0)
	for i in range(1, 129):
		var angle := float(i) / 128.0 * TAU
		var next := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		draw_line(previous, next, color, width, true)
		previous = next
