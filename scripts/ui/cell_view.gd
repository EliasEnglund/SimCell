extends Control
class_name CellView

const Catalog := preload("res://scripts/core/data_catalog.gd")

var simulation
var _pulse := 0.0

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	var rect := get_rect()
	var center := rect.size * 0.5
	var radius: float = minf(rect.size.x, rect.size.y) * 0.32
	_draw_background(rect.size)
	_draw_cell(center, radius)
	_draw_molecules(center, radius)
	_draw_environment(center, radius)

func _draw_background(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("061217"))
	for i in 42:
		var x := fposmod(i * 97.37 + _pulse * 8.0, size.x)
		var y := fposmod(i * 47.19 + sin(_pulse + i) * 16.0, size.y)
		var color := Color(0.25, 0.86, 0.78, 0.14)
		draw_circle(Vector2(x, y), 1.5 + fposmod(i, 4), color)

func _draw_cell(center: Vector2, radius: float) -> void:
	var size_scale := 1.0
	if simulation != null:
		size_scale = clampf(simulation.cell_size, 0.85, 1.38)
	var rx := radius * 1.45 * size_scale
	var ry := radius * 0.82 * size_scale
	var membrane_color := Color("54d7c3")
	var fill := Color(0.10, 0.38, 0.40, 0.44)
	draw_filled_ellipse(center, Vector2(rx, ry), fill)
	for ring in 4:
		var offset := ring * 5.0
		draw_arc(center, rx + offset, 0.0, TAU, 128, membrane_color.darkened(ring * 0.13), 2.0)
		draw_arc(center, ry + offset, 0.0, TAU, 128, Color(0.25, 0.95, 0.86, 0.10), 1.0)
	for i in 14:
		var angle := float(i) / 14.0 * TAU + sin(_pulse * 0.7) * 0.05
		var p := center + Vector2(cos(angle) * rx, sin(angle) * ry)
		draw_circle(p, 4.0, Color("8ff0a4"))
		draw_line(p - Vector2(0, 9), p + Vector2(0, 9), Color(0.85, 1.0, 0.95, 0.45), 2.0)
	draw_circle(center + Vector2(rx * 0.25, -ry * 0.1), ry * 0.22, Color(0.74, 0.60, 1.0, 0.16))

func _draw_molecules(center: Vector2, radius: float) -> void:
	var molecules: Dictionary = Catalog.molecules()
	var keys: Array = molecules.keys()
	for i in keys.size():
		var id: String = keys[i]
		var amount := 0.0
		if simulation != null:
			amount = float(simulation.resources.get(id, 0.0))
		if amount <= 0.05:
			continue
		var count: int = clampi(int(ceil(amount / 3.0)), 1, 10)
		for j in count:
			var phase := _pulse * (0.35 + i * 0.03) + j * 1.9 + i
			var p := center + Vector2(cos(phase) * radius * (0.12 + 0.055 * j), sin(phase * 1.3) * radius * (0.08 + 0.044 * j))
			var color: Color = molecules[id].get("color", Color.WHITE)
			draw_circle(p, 2.5 + minf(3.0, amount * 0.04), _with_alpha(color, 0.76))

func _draw_environment(center: Vector2, radius: float) -> void:
	if simulation == null:
		return
	var pressure: float = maxf(simulation.starvation, maxf(simulation.toxicity, simulation.hostility))
	var threat_color: Color = _with_alpha(Color("ff6c66"), 0.16 + pressure * 0.28)
	for i in 5:
		var angle := float(i) / 5.0 * TAU + _pulse * 0.08
		var p := center + Vector2(cos(angle) * radius * 2.05, sin(angle) * radius * 1.15)
		draw_circle(p, 18.0 + sin(_pulse + i) * 2.0, threat_color)
		draw_arc(p, 25.0, 0.0, TAU, 24, _with_alpha(Color("ff6c66"), 0.35), 2.0)

func draw_filled_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = []
	for i in 96:
		var angle := float(i) / 96.0 * TAU
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
