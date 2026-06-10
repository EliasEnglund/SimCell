extends Control
class_name CellView

var simulation
var view_mode := "exploration"

const BASE_CELL_RADIUS := 170.0
const WORLD_BOUNDS := Rect2(Vector2(-2600.0, -2100.0), Vector2(5200.0, 4200.0))

var cell_position := Vector2.ZERO
var cell_angle := -0.18
var desired_angle := -0.18
var propulsion_energy := 0.0
var cell_velocity := Vector2.ZERO
var camera_position := Vector2.ZERO
var zoom := 1.0
var _elapsed := 0.0
var _swim_power := 0.0
var _environment: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _wake_points: Array[Dictionary] = []
var _interior_particles: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_environment()
	_build_clouds()
	_build_particles()
	_build_interior_particles()

func _process(delta: float) -> void:
	_elapsed += delta
	if view_mode == "exploration":
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
	var turn_input := 0.0
	if Input.is_key_pressed(KEY_A):
		turn_input -= 1.0
	if Input.is_key_pressed(KEY_D):
		turn_input += 1.0
	if Input.is_key_pressed(KEY_W):
		propulsion_energy = clampf(propulsion_energy + delta * 0.72, 0.0, 1.0)
	if Input.is_key_pressed(KEY_S):
		propulsion_energy = clampf(propulsion_energy - delta * 0.95, 0.0, 1.0)
	desired_angle += turn_input * delta * 1.25
	var steering_error := wrapf(desired_angle - cell_angle, -PI, PI)
	cell_angle += steering_error * clampf(delta * 1.45, 0.0, 1.0)
	var forward := Vector2.RIGHT.rotated(cell_angle)
	var drift := Vector2.RIGHT.rotated(cell_angle + PI * 0.5) * sin(_elapsed * 0.74 + cell_position.x * 0.002) * (26.0 + propulsion_energy * 34.0)
	var desired_velocity := forward * (80.0 + propulsion_energy * 330.0) * propulsion_energy + drift
	cell_velocity = cell_velocity.lerp(desired_velocity, clampf(delta * 1.15, 0.0, 1.0))
	cell_position += cell_velocity * delta
	cell_position.x = clampf(cell_position.x, WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x)
	cell_position.y = clampf(cell_position.y, WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y)
	_swim_power = lerpf(_swim_power, clampf(propulsion_energy + absf(turn_input) * 0.42, 0.0, 1.0), clampf(delta * 4.4, 0.0, 1.0))
	_update_wake(delta, forward)

func _zoom_at(factor: float) -> void:
	var min_screen_radius := minf(size.x, size.y) * 0.05
	var max_screen_radius := minf(size.x, size.y) * 0.50
	var min_zoom := min_screen_radius / BASE_CELL_RADIUS
	var max_zoom := max_screen_radius / BASE_CELL_RADIUS
	zoom = clampf(zoom * factor, min_zoom, max_zoom)
	queue_redraw()

func _draw() -> void:
	if view_mode == "overview":
		_draw_cell_overview()
		return
	var closeup := _closeup_amount()
	var travel_alpha := 1.0 - closeup
	draw_rect(Rect2(Vector2.ZERO, size), Color("07181c"), true)
	_draw_medium(1.0 - closeup * 0.34)
	_draw_environment(travel_alpha)
	_draw_cell_wake(1.0 - closeup * 0.55)
	_draw_cell(closeup)
	_draw_cell_interior(closeup)
	_draw_controls_hint()

func _draw_cell_overview() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07181c"), true)
	_draw_medium(0.72)
	var center := size * 0.5 + Vector2(0, 18)
	var radius := minf(size.x, size.y) * 0.31
	_draw_nearby_context(center, radius)
	_draw_overview_cell(center, radius)
	_draw_status_panel(Rect2(Vector2(24, 24), Vector2(304, 238)))
	_draw_cell_inventory_panel(Rect2(Vector2(size.x - 344, 24), Vector2(320, 288)))
	_draw_cell_progression_panel(Rect2(Vector2(24, size.y - 178), Vector2(size.x - 48, 136)))

func _draw_nearby_context(center: Vector2, radius: float) -> void:
	var sugar_pos := center + Vector2(radius * 1.34, -radius * 0.58)
	var bacteria_pos := center + Vector2(-radius * 1.18, radius * 0.12)
	draw_circle(sugar_pos, radius * 0.46, Color(0.92, 0.76, 0.22, 0.08))
	_draw_deposit(sugar_pos, 1.05, Color("ffe064"), 9, 0.88)
	draw_string(ThemeDB.fallback_font, sugar_pos + Vector2(-58, radius * 0.42), "Sugar deposit nearby", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.92, 0.70, 0.82))
	_draw_bacterium(bacteria_pos, -0.18, 0.90, Color("8aa59d"), false, 0.86)
	draw_string(ThemeDB.fallback_font, bacteria_pos + Vector2(-54, radius * 0.34), "Neighbor cell", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.78, 0.90, 0.88, 0.82))

func _draw_overview_cell(center: Vector2, radius: float) -> void:
	draw_circle(center, radius * 1.20, Color(0.24, 0.72, 0.78, 0.055))
	draw_circle(center, radius * 1.02, Color(0.02, 0.05, 0.06, 0.94))
	draw_circle(center, radius * 0.96, Color(0.95, 0.58, 0.36, 0.38))
	draw_circle(center, radius * 0.82, Color(0.17, 0.34, 0.31, 0.82))
	draw_arc(center, radius * 0.99, 0, TAU, 128, Color("76f4ff"), 3.0, true)
	draw_arc(center, radius * 0.88, 0, TAU, 128, Color(0.55, 1.0, 0.74, 0.38), 2.0, true)
	_draw_overview_transporters(center, radius)
	_draw_overview_internal_molecules(center, radius)
	_draw_overview_flagellum(center, radius)

func _draw_overview_transporters(center: Vector2, radius: float) -> void:
	var transporters: Array = simulation.transporter_list() if simulation != null else []
	var total_count := 0
	for item in transporters:
		total_count += int(item.get("count", 0))
	var visual_count := clampi(maxi(total_count, 1), 1, 34)
	for i in visual_count:
		var angle := -PI * 0.92 + float(i) / maxf(1.0, float(visual_count - 1)) * PI * 1.84
		var dir := Vector2.RIGHT.rotated(angle)
		var normal := dir
		var base := center + dir * radius * 0.94
		var protein_color := Color("66e083") if i % 3 != 1 else Color("68c8ff")
		draw_line(base - normal * radius * 0.11, base + normal * radius * 0.12, Color(0.0, 0.03, 0.04, 0.82), maxf(5.0, radius * 0.035), true)
		draw_line(base - normal * radius * 0.10, base + normal * radius * 0.11, protein_color, maxf(2.5, radius * 0.018), true)
		draw_circle(base + normal * radius * 0.13, maxf(3.0, radius * 0.022), protein_color.lightened(0.16))

func _draw_overview_internal_molecules(center: Vector2, radius: float) -> void:
	var ids: Array[String] = []
	if simulation != null:
		ids = simulation.present_molecule_ids()
	var colors: Array[Color] = [Color("64d878"), Color("54c8d8"), Color("d8c75a"), Color("b878d8"), Color("d86c64")]
	var count := clampi(ids.size() * 8 + 12, 16, 80)
	for i in count:
		var seed := float(abs(("overview-molecule:%d" % i).hash() % 10000)) / 10000.0
		var seed_b := float(abs(("overview-molecule-b:%d" % i).hash() % 10000)) / 10000.0
		var angle := seed * TAU + _elapsed * (0.08 + seed_b * 0.08)
		var distance := sqrt(seed_b) * radius * 0.66
		var pos := center + Vector2(cos(angle), sin(angle)) * distance + Vector2(sin(_elapsed + seed * 8.0), cos(_elapsed * 0.7 + seed_b * 7.0)) * 4.0
		var color: Color = colors[i % colors.size()]
		draw_circle(pos, 6.0, Color(0, 0, 0, 0.34))
		draw_circle(pos, 4.4, Color(color.r, color.g, color.b, 0.64))
		draw_circle(pos + Vector2(-1.2, -1.4), 1.2, Color(1, 1, 1, 0.30))

func _draw_overview_flagellum(center: Vector2, radius: float) -> void:
	var anchor := center + Vector2(-radius * 0.92, radius * 0.10)
	var dir := Vector2.LEFT.rotated(0.18)
	var normal := Vector2(-dir.y, dir.x)
	var points := PackedVector2Array()
	for i in 34:
		var t := float(i) / 33.0
		var wave := sin(t * TAU * 2.0 + _elapsed * 2.0) * radius * 0.055 * t
		points.append(anchor + dir * radius * 0.92 * t + normal * wave)
	draw_polyline(points, Color(0, 0, 0, 0.72), 8.0, true)
	draw_polyline(points, Color("76f4ff"), 3.0, true)

func _draw_status_panel(rect: Rect2) -> void:
	_draw_glass_panel(rect, "CELL HEALTH")
	_draw_meter(rect.position + Vector2(18, 56), rect.size.x - 36, "Integrity", 0.98, Color("72e58e"))
	_draw_meter(rect.position + Vector2(18, 100), rect.size.x - 36, "Energy", _resource_fraction("ATP", 120.0), Color("ffe064"))
	_draw_meter(rect.position + Vector2(18, 144), rect.size.x - 36, "Redox NADH", _resource_fraction("NADH", 18.0), Color("5ca8ff"))
	_draw_meter(rect.position + Vector2(18, 188), rect.size.x - 36, "Protein stock", _resource_fraction("Amino Acids", 60.0), Color("8cff6a"))

func _draw_cell_inventory_panel(rect: Rect2) -> void:
	_draw_glass_panel(rect, "CELL CONTENTS")
	var transporter_count := 0
	var enzyme_count := 0
	var molecules := 0
	if simulation != null:
		for item in simulation.transporter_list():
			transporter_count += int(item.get("count", 0))
		for count in simulation.active_enzymes.values():
			enzyme_count += int(count)
		molecules = simulation.present_molecule_ids().size()
	var rows := [
		["Molecule pools", molecules, Color("64d878")],
		["Transporters", transporter_count, Color("76f4ff")],
		["Active enzymes", enzyme_count, Color("d47cff")],
		["Flagellum", 1, Color("ffe064")]
	]
	for i in rows.size():
		var y := rect.position.y + 58.0 + i * 48.0
		var color: Color = rows[i][2]
		draw_circle(Vector2(rect.position.x + 26, y - 5), 7.0, color)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 44, y), str(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dbeff2"))
		draw_string(ThemeDB.fallback_font, Vector2(rect.end.x - 72, y), str(rows[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, 54, 15, color.lightened(0.15))

func _draw_cell_progression_panel(rect: Rect2) -> void:
	_draw_glass_panel(rect, "VISUAL PROGRESSION")
	var text := "Early cells have sparse membranes and few molecule pools. As transporters, enzymes, and movement structures are built, the cell becomes visibly busier."
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(18, 58), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36, 15, Color(0.82, 0.94, 0.93, 0.88))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(18, 92), "Nearby deposits and cells appear enlarged around the cell when exploration places you close to them.", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36, 14, Color(0.62, 0.95, 1.0, 0.78))

func _draw_glass_panel(rect: Rect2, title: String) -> void:
	draw_rect(rect, Color(0.03, 0.09, 0.12, 0.74), true)
	draw_rect(rect, Color(0.44, 0.95, 1.0, 0.52), false, 1.4)
	draw_line(rect.position + Vector2(12, 38), rect.position + Vector2(rect.size.x - 12, 38), Color(0.44, 0.95, 1.0, 0.22), 1.0, true)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, 27), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("76f4ff"))

func _draw_meter(pos: Vector2, width: float, label: String, value: float, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))
	var bar := Rect2(pos + Vector2(0, 10), Vector2(width, 12))
	draw_rect(bar, Color(0.02, 0.06, 0.08, 0.88), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y)), color, true)
	draw_rect(bar, Color(0.70, 0.95, 1.0, 0.35), false, 1.0)

func _resource_fraction(resource_id: String, target: float) -> float:
	if simulation == null:
		return 0.0
	return clampf(float(simulation.resources.get(resource_id, 0.0)) / target, 0.0, 1.0)

func _draw_medium(alpha: float) -> void:
	var center := size * 0.5
	draw_circle(center + Vector2(80, -40), maxf(size.x, size.y) * 0.58, Color(0.11, 0.32, 0.36, 0.34 * alpha))
	draw_circle(center + Vector2(-220, 130), maxf(size.x, size.y) * 0.42, Color(0.22, 0.50, 0.48, 0.17 * alpha))
	draw_circle(center + Vector2(size.x * 0.18, size.y * 0.10), maxf(size.x, size.y) * 0.30, Color(0.09, 0.49, 0.54, 0.13 * alpha))
	_draw_clouds(alpha)
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
		var flicker := 0.74 + sin(_elapsed * speed * 1.8 + phase) * 0.26
		draw_circle(screen, maxf(0.8, radius), Color(color.r, color.g, color.b, 0.18 * flicker * alpha))
		if radius > 2.2:
			draw_circle(screen, maxf(0.5, radius * 0.35), Color(1, 1, 1, 0.10 * flicker * alpha))

func _draw_clouds(alpha: float) -> void:
	for cloud in _clouds:
		var base: Vector2 = cloud.get("pos", Vector2.ZERO)
		var phase := float(cloud.get("phase", 0.0))
		var drift := Vector2(cos(_elapsed * 0.06 + phase), sin(_elapsed * 0.05 + phase * 1.7)) * 85.0
		var screen := _world_to_screen(base + drift)
		var radius := float(cloud.get("radius", 200.0)) * zoom
		if not Rect2(Vector2(-radius, -radius), size + Vector2(radius * 2.0, radius * 2.0)).has_point(screen):
			continue
		var color: Color = cloud.get("color", Color("356a70"))
		draw_circle(screen, radius, Color(color.r, color.g, color.b, 0.045 * alpha))
		draw_circle(screen + Vector2(radius * 0.24, -radius * 0.12), radius * 0.55, Color(0.5, 0.95, 0.95, 0.030 * alpha))

func _draw_environment(alpha: float) -> void:
	if alpha <= 0.02:
		return
	for item in _environment:
		var pos: Vector2 = _world_to_screen(item.get("pos", Vector2.ZERO))
		var margin := 220.0 * zoom
		if not Rect2(Vector2(-margin, -margin), size + Vector2(margin * 2.0, margin * 2.0)).has_point(pos):
			continue
		match str(item.get("type", "")):
			"bacteria":
				_draw_bacterium(pos, float(item.get("angle", 0.0)), float(item.get("scale", 1.0)), item.get("color", Color("8ea6a1")), false, alpha)
			"hostile":
				_draw_bacterium(pos, float(item.get("angle", 0.0)), float(item.get("scale", 1.0)), Color("e95058"), false, alpha)
			"sugar":
				_draw_deposit(pos, float(item.get("scale", 1.0)), Color("ffe064"), 8, alpha)
			"sulfur":
				_draw_crystals(pos, float(item.get("scale", 1.0)), Color("d8ed67"), alpha)
			"nitrogen":
				_draw_deposit(pos, float(item.get("scale", 1.0)), Color("56a8ff"), 5, alpha)
			"virus":
				_draw_virus(pos, float(item.get("scale", 1.0)), alpha)

func _draw_cell(closeup: float) -> void:
	var pos := _world_to_screen(cell_position)
	var radius := BASE_CELL_RADIUS * zoom
	var forward := Vector2.RIGHT.rotated(cell_angle)
	var back := -forward
	var normal := Vector2(-forward.y, forward.x)
	_draw_flagellum(pos + back * radius * 0.84, back, normal, radius, 1.0 - closeup * 0.25)
	draw_circle(pos, radius * (0.82 + closeup * 0.35), Color(0.12, 0.95, 1.0, 0.06 + closeup * 0.08))
	draw_circle(pos, radius * 0.58, Color(0.15, 1.0, 1.0, 0.10))
	_draw_bacterium(pos, cell_angle, zoom * 1.08, Color("48d9f0"), true, 1.0)
	var triangle := PackedVector2Array([
		pos + forward * radius * 0.88,
		pos + back * radius * 0.18 + normal * radius * 0.24,
		pos + back * radius * 0.18 - normal * radius * 0.24
	])
	draw_polyline(triangle, Color(0.46, 0.96, 1.0, 1.0 - closeup * 0.72), 2.2, true)

func _draw_cell_wake(alpha: float) -> void:
	if alpha <= 0.02:
		return
	for point in _wake_points:
		var age := float(point.get("age", 0.0))
		var fade := clampf(1.0 - age / 1.45, 0.0, 1.0)
		var pos: Vector2 = _world_to_screen(point.get("pos", Vector2.ZERO))
		var angle := float(point.get("angle", 0.0))
		var power := float(point.get("power", 0.0))
		var forward := Vector2.RIGHT.rotated(angle)
		var normal := Vector2(-forward.y, forward.x)
		var radius := BASE_CELL_RADIUS * zoom * (0.36 + age * 0.20)
		var wash := PackedVector2Array([
			pos - forward * radius * 0.70,
			pos + normal * radius * (0.42 + power * 0.22),
			pos + forward * radius * 0.85,
			pos - normal * radius * (0.42 + power * 0.22)
		])
		draw_colored_polygon(wash, Color(0.20, 1.0, 1.0, 0.035 * fade * alpha))
		draw_polyline(wash, Color(0.42, 1.0, 0.88, 0.12 * fade * alpha), maxf(1.0, 2.0 * zoom), true)

func _draw_cell_interior(alpha: float) -> void:
	if alpha <= 0.02:
		return
	var pos := _world_to_screen(cell_position)
	var radius := BASE_CELL_RADIUS * zoom
	var forward := Vector2.RIGHT.rotated(cell_angle)
	var normal := Vector2(-forward.y, forward.x)
	var rx := radius * 0.78
	var ry := radius * 0.34
	draw_circle(pos, radius * 0.72, Color(0.06, 0.34, 0.36, 0.18 * alpha))
	_draw_internal_streams(pos, forward, normal, rx, ry, alpha)
	for particle in _interior_particles:
		var local: Vector2 = particle.get("local", Vector2.ZERO)
		var orbit := float(particle.get("orbit", 0.0))
		var speed := float(particle.get("speed", 0.4))
		var phase := float(particle.get("phase", 0.0))
		var wiggle := Vector2(cos(_elapsed * speed + phase), sin(_elapsed * speed * 1.3 + phase)) * orbit
		var screen := pos + forward * (local.x + wiggle.x) * rx + normal * (local.y + wiggle.y) * ry
		var depth := clampf(1.0 - absf(local.y + wiggle.y) * 0.55, 0.42, 1.0)
		var color: Color = particle.get("color", Color("8cff6a"))
		var particle_radius := float(particle.get("radius", 5.0)) * zoom * (0.72 + depth * 0.28)
		draw_circle(screen, particle_radius + 3.0 * zoom, Color(0, 0, 0, 0.30 * alpha))
		draw_circle(screen, particle_radius, Color(color.r, color.g, color.b, alpha * (0.34 + depth * 0.40)))
		draw_circle(screen + Vector2(-particle_radius * 0.22, -particle_radius * 0.25), maxf(1.0, particle_radius * 0.22), Color(1, 1, 1, 0.24 * alpha))
	_draw_internal_label(alpha)

func _draw_internal_streams(pos: Vector2, forward: Vector2, normal: Vector2, rx: float, ry: float, alpha: float) -> void:
	for lane in 4:
		var y := -0.48 + float(lane) * 0.32
		var points := PackedVector2Array()
		for i in 28:
			var t := float(i) / 27.0
			var x := -0.74 + t * 1.48
			var wave := sin(t * TAU * 1.6 + _elapsed * (0.7 + lane * 0.11)) * 0.08
			points.append(pos + forward * x * rx + normal * (y + wave) * ry)
		draw_polyline(points, Color(0.48, 1.0, 0.82, 0.11 * alpha), maxf(1.0, 2.4 * zoom), true)

func _draw_internal_label(alpha: float) -> void:
	var panel := Rect2(Vector2(size.x - 246.0, size.y - 126.0), Vector2(222.0, 82.0))
	draw_rect(panel, Color(0.03, 0.09, 0.11, 0.72 * alpha), true)
	draw_rect(panel, Color(0.46, 0.96, 1.0, 0.55 * alpha), false, 1.2)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 24), "Cytoplasm close-up", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.90, 1.0, 1.0, alpha))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 48), "Internal metabolites active", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 1.0, 0.82, alpha))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 68), "Zoom out for travel", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.94, 0.96, alpha * 0.9))

func _draw_flagellum(anchor: Vector2, dir: Vector2, normal: Vector2, radius: float, alpha: float) -> void:
	var points := PackedVector2Array()
	var anim := _elapsed * (7.0 + _swim_power * 8.0)
	for i in 36:
		var t := float(i) / 35.0
		var wave := sin(t * TAU * 2.4 + anim) * radius * 0.12 * (0.25 + t) * (0.25 + _swim_power)
		points.append(anchor + dir * radius * 1.65 * t + normal * wave)
	draw_polyline(points, Color(0.0, 0.0, 0.0, 0.75 * alpha), maxf(2.0, radius * 0.065), true)
	draw_polyline(points, Color(0.1, 1.0, 1.0, (0.15 + _swim_power * 0.12) * alpha), maxf(2.0, radius * 0.085), true)
	draw_polyline(points, Color(0.46, 0.96, 1.0, alpha), maxf(1.0, radius * 0.028), true)

func _draw_bacterium(pos: Vector2, angle: float, scale_value: float, color: Color, player := false, alpha := 1.0) -> void:
	var rx := 90.0 * scale_value * zoom
	var ry := 34.0 * scale_value * zoom
	if player:
		rx = BASE_CELL_RADIUS * 0.74 * zoom
		ry = BASE_CELL_RADIUS * 0.30 * zoom
	var points := PackedVector2Array()
	for i in 72:
		var a := float(i) / 72.0 * TAU
		points.append(pos + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	draw_colored_polygon(points, Color(0.01, 0.03, 0.05, 0.95 * alpha))
	var inner := PackedVector2Array()
	for i in 72:
		var a := float(i) / 72.0 * TAU
		inner.append(pos + Vector2(cos(a) * rx * 0.90, sin(a) * ry * 0.84).rotated(angle))
	draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.72 * alpha))
	if player:
		var membrane := PackedVector2Array()
		for i in 72:
			var a := float(i) / 72.0 * TAU
			membrane.append(pos + Vector2(cos(a) * rx * 0.97, sin(a) * ry * 0.91).rotated(angle))
		draw_polyline(membrane, Color(0.66, 1.0, 0.92, 0.42 * alpha), maxf(1.0, 4.0 * zoom), true)
		for i in 9:
			var t := (float(i) / 8.0 - 0.5) * 1.65
			var organelle_center := pos + Vector2(t * rx * 0.48, sin(_elapsed * 0.9 + i) * ry * 0.18).rotated(angle)
			var organelle_radius := (5.0 + fposmod(i * 3.0, 7.0)) * zoom
			draw_circle(organelle_center, organelle_radius + 1.6 * zoom, Color(0, 0, 0, 0.28 * alpha))
			draw_circle(organelle_center, organelle_radius, Color(0.72, 1.0, 0.88, 0.26 * alpha))
		for i in 14:
			var a := float(i) / 14.0 * TAU + _elapsed * 0.25
			var rim_pos := pos + Vector2(cos(a) * rx * 0.82, sin(a) * ry * 0.72).rotated(angle)
			draw_circle(rim_pos, maxf(1.2, 2.6 * zoom), Color(0.90, 1.0, 1.0, 0.24 * alpha))
	draw_arc(pos, maxf(rx, ry) * 0.42, angle - 0.9, angle + 0.9, 18, Color(1, 1, 1, 0.24 * alpha), maxf(1.0, 3.0 * zoom), true)
	if player:
		draw_string(ThemeDB.fallback_font, pos + Vector2(-30.0, ry + 24.0), "CELL-1", HORIZONTAL_ALIGNMENT_LEFT, -1, maxf(10.0, 14.0 * zoom), Color(0.96, 0.98, 1.0, alpha))

func _draw_deposit(pos: Vector2, scale_value: float, color: Color, count: int, alpha := 1.0) -> void:
	for i in count:
		var angle := float(i) / float(count) * TAU + _elapsed * 0.04
		var offset := Vector2(cos(angle), sin(angle)) * (14.0 + fposmod(i * 11.0, 36.0)) * zoom * scale_value
		var r := (8.0 + fposmod(i * 5.0, 8.0)) * zoom * scale_value
		draw_circle(pos + offset, r + 12.0 * zoom, Color(color.r, color.g, color.b, 0.07 * alpha))
		draw_circle(pos + offset, r + 3.0 * zoom, Color(0.01, 0.03, 0.05, alpha))
		draw_circle(pos + offset, r, Color(color.r, color.g, color.b, 0.82 * alpha))
		draw_circle(pos + offset + Vector2(-r * 0.24, -r * 0.26), maxf(1.0, r * 0.20), Color(1, 1, 1, 0.22 * alpha))

func _draw_crystals(pos: Vector2, scale_value: float, color: Color, alpha := 1.0) -> void:
	for i in 7:
		var angle := float(i) * 0.9
		var center := pos + Vector2(cos(angle), sin(angle)) * (24.0 + i * 3.0) * zoom * scale_value
		var r := (18.0 + fposmod(i * 7.0, 14.0)) * zoom * scale_value
		var poly := PackedVector2Array()
		for p in 6:
			var a := float(p) / 6.0 * TAU + angle
			poly.append(center + Vector2(cos(a), sin(a)) * r)
		draw_circle(center, r * 1.45, Color(color.r, color.g, color.b, 0.06 * alpha))
		draw_colored_polygon(poly, Color(0.01, 0.03, 0.05, alpha))
		draw_colored_polygon(poly, Color(color.r, color.g, color.b, 0.72 * alpha))

func _draw_virus(pos: Vector2, scale_value: float, alpha := 1.0) -> void:
	var r := 16.0 * zoom * scale_value
	for i in 8:
		var dir := Vector2.RIGHT.rotated(float(i) / 8.0 * TAU)
		draw_line(pos + dir * r * 0.6, pos + dir * r * 1.35, Color(0.58, 0.66, 0.68, alpha), maxf(1.0, 2.0 * zoom), true)
	draw_circle(pos, r + 3.0 * zoom, Color(0.01, 0.03, 0.05, alpha))
	draw_circle(pos, r, Color(0.46, 0.60, 0.62, 0.65 * alpha))

func _draw_controls_hint() -> void:
	var panel := Rect2(Vector2(18, size.y - 112), Vector2(238, 88))
	draw_rect(panel, Color(0.04, 0.10, 0.13, 0.72), true)
	draw_rect(panel, Color("76f4ff"), false, 1.2)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(14, 24), "W/S swim forward/back", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(14, 46), "A/D rotate", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(14, 68), "Mouse wheel / pinch zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))

func _world_to_screen(world: Vector2) -> Vector2:
	return (world - camera_position) * zoom + size * 0.5

func _closeup_amount() -> float:
	return smoothstep(1.35, 2.15, zoom)

func _update_wake(delta: float, forward: Vector2) -> void:
	for i in range(_wake_points.size() - 1, -1, -1):
		var point := _wake_points[i]
		point["age"] = float(point.get("age", 0.0)) + delta
		if float(point["age"]) > 1.45:
			_wake_points.remove_at(i)
		else:
			_wake_points[i] = point
	if _swim_power < 0.08:
		return
	var wake_position := cell_position - forward * BASE_CELL_RADIUS * 0.64
	var should_add := _wake_points.is_empty()
	if not should_add:
		var latest: Vector2 = _wake_points[_wake_points.size() - 1].get("pos", Vector2.ZERO)
		should_add = latest.distance_to(wake_position) > 18.0
	if should_add:
		_wake_points.append({"pos": wake_position, "angle": cell_angle, "age": 0.0, "power": _swim_power})
		if _wake_points.size() > 34:
			_wake_points.remove_at(0)

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

func _build_clouds() -> void:
	_clouds = []
	for i in 18:
		var seed := float(abs(("cloud:%d" % i).hash() % 10000)) / 10000.0
		var seed_b := float(abs(("cloud-b:%d" % i).hash() % 10000)) / 10000.0
		_clouds.append({
			"pos": Vector2(lerpf(WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x, seed), lerpf(WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y, seed_b)),
			"phase": seed * TAU,
			"radius": 180.0 + seed_b * 360.0,
			"color": Color("2f7379") if i % 3 != 0 else Color("6e8f7f")
		})

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

func _build_interior_particles() -> void:
	_interior_particles = []
	var colors := [Color("8cff6a"), Color("5ca8ff"), Color("f0df6a"), Color("d47cff"), Color("76f4ff")]
	for i in 44:
		var seed := float(abs(("inside:%d" % i).hash() % 10000)) / 10000.0
		var seed_b := float(abs(("inside-b:%d" % i).hash() % 10000)) / 10000.0
		var x := lerpf(-0.72, 0.72, seed)
		var max_y := sqrt(maxf(0.0, 1.0 - pow(x / 0.82, 2.0))) * 0.72
		var y := lerpf(-max_y, max_y, seed_b)
		_interior_particles.append({
			"local": Vector2(x, y),
			"phase": seed * TAU * 3.0,
			"speed": 0.25 + seed_b * 0.55,
			"orbit": 0.018 + seed * 0.045,
			"radius": 2.6 + seed_b * 4.8,
			"color": colors[i % colors.size()]
		})
