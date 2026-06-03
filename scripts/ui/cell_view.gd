extends Control
class_name CellView

var simulation

const BASE_CELL_RADIUS := 170.0
const WORLD_BOUNDS := Rect2(Vector2(-2600.0, -2100.0), Vector2(5200.0, 4200.0))

var cell_position := Vector2.ZERO
var cell_angle := -0.18
var camera_position := Vector2.ZERO
var zoom := 1.0
var _elapsed := 0.0
var _swim_power := 0.0
var _environment: Array[Dictionary] = []
var _particles: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_environment()
	_build_particles()

func _process(delta: float) -> void:
	_elapsed += delta
	_update_cell(delta)
	camera_position = camera_position.lerp(cell_position, clampf(delta * 5.5, 0.0, 1.0))
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_zoom_at(event.factor)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.09)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.09)

func _update_cell(delta: float) -> void:
	var turn := 0.0
	if Input.is_key_pressed(KEY_A):
		turn -= 1.0
	if Input.is_key_pressed(KEY_D):
		turn += 1.0
	var throttle := 0.0
	if Input.is_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S):
		throttle -= 0.45
	cell_angle += turn * delta * 2.2
	var forward := Vector2.RIGHT.rotated(cell_angle)
	var speed := 285.0 if throttle > 0.0 else 135.0
	cell_position += forward * throttle * speed * delta
	cell_position.x = clampf(cell_position.x, WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x)
	cell_position.y = clampf(cell_position.y, WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y)
	_swim_power = lerpf(_swim_power, clampf(absf(throttle) + absf(turn) * 0.7, 0.0, 1.0), clampf(delta * 6.0, 0.0, 1.0))

func _zoom_at(factor: float) -> void:
	var min_screen_radius := minf(size.x, size.y) * 0.05
	var max_screen_radius := minf(size.x, size.y) * 0.50
	var min_zoom := min_screen_radius / BASE_CELL_RADIUS
	var max_zoom := max_screen_radius / BASE_CELL_RADIUS
	zoom = clampf(zoom * factor, min_zoom, max_zoom)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07181c"), true)
	_draw_medium()
	_draw_environment()
	_draw_cell()
	_draw_controls_hint()

func _draw_medium() -> void:
	var center := size * 0.5
	draw_circle(center + Vector2(80, -40), maxf(size.x, size.y) * 0.58, Color(0.12, 0.28, 0.31, 0.32))
	draw_circle(center + Vector2(-220, 130), maxf(size.x, size.y) * 0.42, Color(0.18, 0.42, 0.44, 0.16))
	for particle in _particles:
		var base: Vector2 = particle.get("pos", Vector2.ZERO)
		var speed := float(particle.get("speed", 1.0))
		var phase := float(particle.get("phase", 0.0))
		var drift_amount := float(particle.get("drift", 12.0))
		var drift := Vector2(sin(_elapsed * speed + phase), cos(_elapsed * speed * 0.7 + phase)) * drift_amount
		var screen: Vector2 = _world_to_screen(base + drift)
		if not Rect2(Vector2(-40, -40), size + Vector2(80, 80)).has_point(screen):
			continue
		var radius := float(particle.get("radius", 2.0)) * zoom
		var color: Color = particle.get("color", Color("8fcfd3"))
		draw_circle(screen, maxf(0.8, radius), Color(color.r, color.g, color.b, 0.20))

func _draw_environment() -> void:
	for item in _environment:
		var pos: Vector2 = _world_to_screen(item.get("pos", Vector2.ZERO))
		var margin := 220.0 * zoom
		if not Rect2(Vector2(-margin, -margin), size + Vector2(margin * 2.0, margin * 2.0)).has_point(pos):
			continue
		match str(item.get("type", "")):
			"bacteria":
				_draw_bacterium(pos, float(item.get("angle", 0.0)), float(item.get("scale", 1.0)), item.get("color", Color("8ea6a1")))
			"hostile":
				_draw_bacterium(pos, float(item.get("angle", 0.0)), float(item.get("scale", 1.0)), Color("e95058"))
			"sugar":
				_draw_deposit(pos, float(item.get("scale", 1.0)), Color("ffe064"), 8)
			"sulfur":
				_draw_crystals(pos, float(item.get("scale", 1.0)), Color("d8ed67"))
			"nitrogen":
				_draw_deposit(pos, float(item.get("scale", 1.0)), Color("56a8ff"), 5)
			"virus":
				_draw_virus(pos, float(item.get("scale", 1.0)))

func _draw_cell() -> void:
	var pos := _world_to_screen(cell_position)
	var radius := BASE_CELL_RADIUS * zoom
	var forward := Vector2.RIGHT.rotated(cell_angle)
	var back := -forward
	var normal := Vector2(-forward.y, forward.x)
	_draw_flagellum(pos + back * radius * 0.84, back, normal, radius)
	draw_circle(pos, radius * 0.58, Color(0.15, 1.0, 1.0, 0.08))
	_draw_bacterium(pos, cell_angle, zoom * 1.08, Color("48d9f0"), true)
	var triangle := PackedVector2Array([
		pos + forward * radius * 0.88,
		pos + back * radius * 0.18 + normal * radius * 0.24,
		pos + back * radius * 0.18 - normal * radius * 0.24
	])
	draw_polyline(triangle, Color("76f4ff"), 2.2, true)

func _draw_flagellum(anchor: Vector2, dir: Vector2, normal: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	var anim := _elapsed * (7.0 + _swim_power * 8.0)
	for i in 36:
		var t := float(i) / 35.0
		var wave := sin(t * TAU * 2.4 + anim) * radius * 0.12 * (0.25 + t) * (0.25 + _swim_power)
		points.append(anchor + dir * radius * 1.65 * t + normal * wave)
	draw_polyline(points, Color(0.0, 0.0, 0.0, 0.75), maxf(2.0, radius * 0.055), true)
	draw_polyline(points, Color("76f4ff"), maxf(1.0, radius * 0.028), true)

func _draw_bacterium(pos: Vector2, angle: float, scale_value: float, color: Color, player := false) -> void:
	var rx := 90.0 * scale_value * zoom
	var ry := 34.0 * scale_value * zoom
	if player:
		rx = BASE_CELL_RADIUS * 0.74 * zoom
		ry = BASE_CELL_RADIUS * 0.30 * zoom
	var points := PackedVector2Array()
	for i in 72:
		var a := float(i) / 72.0 * TAU
		points.append(pos + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	draw_colored_polygon(points, Color("02070b"))
	var inner := PackedVector2Array()
	for i in 72:
		var a := float(i) / 72.0 * TAU
		inner.append(pos + Vector2(cos(a) * rx * 0.90, sin(a) * ry * 0.84).rotated(angle))
	draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.72))
	draw_arc(pos, maxf(rx, ry) * 0.42, angle - 0.9, angle + 0.9, 18, Color(1, 1, 1, 0.24), maxf(1.0, 3.0 * zoom), true)
	if player:
		draw_string(ThemeDB.fallback_font, pos + Vector2(-30.0, ry + 24.0), "CELL-1", HORIZONTAL_ALIGNMENT_LEFT, -1, maxf(10.0, 14.0 * zoom), Color("f4fbff"))

func _draw_deposit(pos: Vector2, scale_value: float, color: Color, count: int) -> void:
	for i in count:
		var angle := float(i) / float(count) * TAU + _elapsed * 0.04
		var offset := Vector2(cos(angle), sin(angle)) * (14.0 + fposmod(i * 11.0, 36.0)) * zoom * scale_value
		var r := (8.0 + fposmod(i * 5.0, 8.0)) * zoom * scale_value
		draw_circle(pos + offset, r + 3.0 * zoom, Color("02070b"))
		draw_circle(pos + offset, r, Color(color.r, color.g, color.b, 0.82))

func _draw_crystals(pos: Vector2, scale_value: float, color: Color) -> void:
	for i in 7:
		var angle := float(i) * 0.9
		var center := pos + Vector2(cos(angle), sin(angle)) * (24.0 + i * 3.0) * zoom * scale_value
		var r := (18.0 + fposmod(i * 7.0, 14.0)) * zoom * scale_value
		var poly := PackedVector2Array()
		for p in 6:
			var a := float(p) / 6.0 * TAU + angle
			poly.append(center + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(poly, Color("02070b"))
		draw_colored_polygon(poly, Color(color.r, color.g, color.b, 0.72))

func _draw_virus(pos: Vector2, scale_value: float) -> void:
	var r := 16.0 * zoom * scale_value
	for i in 8:
		var dir := Vector2.RIGHT.rotated(float(i) / 8.0 * TAU)
		draw_line(pos + dir * r * 0.6, pos + dir * r * 1.35, Color("93a9ad"), maxf(1.0, 2.0 * zoom), true)
	draw_circle(pos, r + 3.0 * zoom, Color("02070b"))
	draw_circle(pos, r, Color(0.46, 0.60, 0.62, 0.65))

func _draw_controls_hint() -> void:
	var panel := Rect2(Vector2(18, size.y - 112), Vector2(238, 88))
	draw_rect(panel, Color(0.04, 0.10, 0.13, 0.72), true)
	draw_rect(panel, Color("76f4ff"), false, 1.2)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(14, 24), "W/S swim forward/back", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(14, 46), "A/D rotate", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(14, 68), "Mouse wheel / pinch zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))

func _world_to_screen(world: Vector2) -> Vector2:
	return (world - camera_position) * zoom + size * 0.5

func _build_environment() -> void:
	_environment = [
		{"type": "sugar", "pos": Vector2(520, -220), "scale": 1.3},
		{"type": "sulfur", "pos": Vector2(980, 420), "scale": 1.2},
		{"type": "nitrogen", "pos": Vector2(-840, 680), "scale": 1.1},
		{"type": "bacteria", "pos": Vector2(-720, -520), "angle": 0.4, "scale": 0.80, "color": Color("97b4aa")},
		{"type": "bacteria", "pos": Vector2(1260, -620), "angle": -0.2, "scale": 0.95, "color": Color("92aaa2")},
		{"type": "hostile", "pos": Vector2(-1180, 160), "angle": -0.6, "scale": 0.72},
		{"type": "hostile", "pos": Vector2(380, 760), "angle": 0.8, "scale": 0.62},
		{"type": "virus", "pos": Vector2(840, -860), "scale": 0.9},
		{"type": "virus", "pos": Vector2(-1480, -820), "scale": 0.75},
		{"type": "virus", "pos": Vector2(1540, 760), "scale": 0.85}
	]

func _build_particles() -> void:
	_particles = []
	for i in 220:
		var seed := float(abs(("particle:%d" % i).hash() % 10000)) / 10000.0
		var seed_b := float(abs(("particle-b:%d" % i).hash() % 10000)) / 10000.0
		_particles.append({
			"pos": Vector2(lerpf(WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x, seed), lerpf(WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y, seed_b)),
			"phase": seed * TAU * 4.0,
			"speed": 0.25 + seed_b * 0.6,
			"drift": 10.0 + seed * 34.0,
			"radius": 1.2 + seed_b * 3.2,
			"color": Color("8fcfd3") if i % 5 != 0 else Color("d8ed67")
		})
