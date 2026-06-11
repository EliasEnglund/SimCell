extends Control
class_name CellView

var simulation
var view_mode := "exploration"

const BASE_CELL_RADIUS := 170.0
const EXPLORATION_ZOOM := 0.62
const WORLD_BOUNDS := Rect2(Vector2(-2600.0, -2100.0), Vector2(5200.0, 4200.0))
const MAP_PATH := "res://data/exploration_map.json"

var cell_position := Vector2.ZERO
var cell_angle := -0.18
var desired_angle := -0.18
var propulsion_energy := 0.0
var cell_velocity := Vector2.ZERO
var camera_position := Vector2.ZERO
var zoom := EXPLORATION_ZOOM
var _elapsed := 0.0
var _swim_power := 0.0
var _environment: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _wake_points: Array[Dictionary] = []
var _background_texture: Texture2D
var _particle_overlay_texture: Texture2D
var _object_texture: Texture2D
var _player_cell_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background_texture = _load_texture("res://assets/art_lab/exploration/exploration-background.png")
	_particle_overlay_texture = _load_texture("res://assets/art_lab/exploration/parallax-particles-alpha.png")
	_object_texture = _load_texture("res://assets/art_lab/exploration/exploration-objects-alpha.png")
	_player_cell_texture = _load_texture("res://assets/art_lab/exploration/player-cell-idle-alpha.png")
	_build_environment()
	_build_clouds()
	_build_particles()

func _process(delta: float) -> void:
	_elapsed += delta
	if view_mode == "exploration":
		_update_cell(delta)
		camera_position = camera_position.lerp(cell_position, clampf(delta * 5.5, 0.0, 1.0))
	queue_redraw()

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

func _draw() -> void:
	if view_mode == "overview":
		_draw_cell_overview()
		return
	_draw_exploration_background()
	_draw_exploration_medium(0.42)
	_draw_parallax_particle_overlay(0.20)
	_draw_environment(1.0)
	_draw_cell_wake(1.0)
	_draw_cell()
	_draw_parallax_particle_overlay(0.12, true)
	_draw_propulsion_widget()

func _draw_cell_overview() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07181c"), true)
	_draw_status_background()
	var center := size * 0.5 + Vector2(22, 0)
	var radius := minf(size.x, size.y) * 0.36
	_draw_overview_cell(center, radius)
	_draw_status_overlay(center, radius)

func _draw_status_background() -> void:
	var top := Color("0a252d")
	var bottom := Color("13313a")
	for i in 28:
		var t := float(i) / 27.0
		var band := Rect2(Vector2(0, size.y * t), Vector2(size.x, size.y / 27.0 + 1.0))
		draw_rect(band, top.lerp(bottom, t), true)
	for i in 140:
		var seed := float(abs(("cell-status-speck:%d" % i).hash() % 10000)) / 10000.0
		var seed_b := float(abs(("cell-status-speck-b:%d" % i).hash() % 10000)) / 10000.0
		var pos := Vector2(lerpf(22.0, size.x - 22.0, seed), lerpf(22.0, size.y - 22.0, seed_b))
		var drift := Vector2(sin(_elapsed * 0.09 + seed * 18.0), cos(_elapsed * 0.07 + seed_b * 16.0)) * 5.0
		draw_circle(pos + drift, 1.0 + seed * 2.2, Color(0.72, 1.0, 0.92, 0.035 + seed_b * 0.045))

func _draw_overview_cell(center: Vector2, radius: float) -> void:
	draw_circle(center, radius * 1.07, Color(0.0, 0.02, 0.025, 0.84))
	draw_circle(center, radius * 0.99, Color(0.60, 0.39, 0.24, 0.62))
	draw_circle(center, radius * 0.92, Color(0.12, 0.28, 0.29, 0.94))
	draw_circle(center + Vector2(-radius * 0.08, -radius * 0.10), radius * 0.78, Color(0.19, 0.42, 0.40, 0.54))
	draw_arc(center, radius * 1.00, 0, TAU, 160, Color(0.62, 0.94, 1.0, 0.52), 2.0, true)
	draw_arc(center, radius * 0.88, 0, TAU, 160, Color(0.48, 1.0, 0.76, 0.28), 1.5, true)
	_draw_overview_transporters(center, radius)
	_draw_overview_internal_molecules(center, radius)
	_draw_overview_flagellum(center, radius)
	_draw_overview_dna(center + Vector2(radius * 0.28, radius * 0.18), radius * 0.24)

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

func _draw_status_overlay(center: Vector2, radius: float) -> void:
	var transporter_count := 0
	var enzyme_count := 0
	var molecules := 0
	if simulation != null:
		for item in simulation.transporter_list():
			transporter_count += int(item.get("count", 0))
		for count in simulation.active_enzymes.values():
			enzyme_count += int(count)
		molecules = simulation.present_molecule_ids().size()
	var left := Vector2(28, 46)
	_draw_inline_metric(left, "Integrity", "98%", Color("72e58e"))
	_draw_inline_metric(left + Vector2(0, 34), "ATP", "%.0f" % (simulation.resources.get("ATP", 0.0) if simulation != null else 0.0), Color("ffe064"))
	_draw_inline_metric(left + Vector2(0, 68), "NADH", "%.0f" % (simulation.resources.get("NADH", 0.0) if simulation != null else 0.0), Color("5ca8ff"))
	var right := Vector2(size.x - 226, 46)
	_draw_inline_metric(right, "Pools", str(molecules), Color("64d878"))
	_draw_inline_metric(right + Vector2(0, 34), "Transporters", str(transporter_count), Color("76f4ff"))
	_draw_inline_metric(right + Vector2(0, 68), "Enzymes", str(enzyme_count), Color("d47cff"))
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.46, radius * 1.14), "Sparse early cell: visible transporters and internal molecule activity grow as systems are built.", HORIZONTAL_ALIGNMENT_CENTER, radius * 0.92, 15, Color(0.74, 0.92, 0.90, 0.78))

func _draw_inline_metric(pos: Vector2, label: String, value: String, color: Color) -> void:
	draw_circle(pos + Vector2(8, -5), 5.0, color)
	draw_string(ThemeDB.fallback_font, pos + Vector2(22, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dbeff2"))
	draw_string(ThemeDB.fallback_font, pos + Vector2(136, 0), value, HORIZONTAL_ALIGNMENT_RIGHT, 70, 14, color.lightened(0.12))

func _draw_overview_dna(center: Vector2, radius: float) -> void:
	var points_a := PackedVector2Array()
	var points_b := PackedVector2Array()
	for i in 42:
		var t := float(i) / 41.0
		var x := (t - 0.5) * radius * 2.4
		var y := sin(t * TAU * 2.2 + _elapsed * 0.28) * radius * 0.40
		points_a.append(center + Vector2(x, y))
		points_b.append(center + Vector2(x, -y))
	draw_polyline(points_a, Color(0.96, 0.82, 0.62, 0.42), 1.7, true)
	draw_polyline(points_b, Color(0.86, 0.72, 0.55, 0.36), 1.7, true)
	for i in range(0, 42, 4):
		draw_line(points_a[i], points_b[i], Color(0.90, 0.82, 0.70, 0.28), 1.0, true)

func _draw_exploration_background() -> void:
	if _background_texture == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color("07181c"), true)
		return
	var source_size := Vector2(_background_texture.get_width(), _background_texture.get_height())
	var target := _cover_rect(source_size, Rect2(Vector2.ZERO, size))
	var drift := Vector2(
		fposmod(camera_position.x * -0.018, maxf(1.0, target.size.x - size.x + 1.0)),
		fposmod(camera_position.y * -0.018, maxf(1.0, target.size.y - size.y + 1.0))
	)
	target.position -= drift
	draw_texture_rect(_background_texture, target, false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.08, 0.09, 0.22), true)

func _draw_exploration_medium(alpha: float) -> void:
	for i in 34:
		var t := float(i) / 33.0
		var color := Color("0b2730").lerp(Color("1c4249"), t)
		draw_rect(Rect2(Vector2(0, size.y * t), Vector2(size.x, size.y / 33.0 + 1.0)), Color(color.r, color.g, color.b, 0.32 * alpha), true)
	var center := size * 0.5
	draw_circle(center + Vector2(size.x * 0.22, -size.y * 0.18), maxf(size.x, size.y) * 0.52, Color(0.32, 0.70, 0.74, 0.030 * alpha))
	draw_circle(center + Vector2(-size.x * 0.18, size.y * 0.20), maxf(size.x, size.y) * 0.34, Color(0.18, 0.55, 0.52, 0.022 * alpha))
	_draw_clouds(alpha * 0.75)
	_draw_current_streaks(alpha)
	_draw_suspended_particles(alpha)

func _draw_parallax_particle_overlay(alpha: float, foreground := false) -> void:
	if _particle_overlay_texture == null:
		return
	var texture_size := Vector2(_particle_overlay_texture.get_width(), _particle_overlay_texture.get_height())
	var scale_value := maxf(size.x / texture_size.x, size.y / texture_size.y) * 1.12
	var draw_size := texture_size * scale_value
	var speed := 0.060 if foreground else 0.026
	var offset := Vector2(
		fposmod(-camera_position.x * speed, draw_size.x),
		fposmod(-camera_position.y * speed, draw_size.y)
	)
	for x in range(-1, 2):
		for y in range(-1, 2):
			var pos := Vector2(x * draw_size.x, y * draw_size.y) + offset - draw_size * 0.5
			draw_texture_rect(_particle_overlay_texture, Rect2(pos, draw_size), false, Color(1, 1, 1, alpha))

func _draw_current_streaks(alpha: float) -> void:
	for i in 18:
		var seed := float(abs(("current:%d" % i).hash() % 10000)) / 10000.0
		var y := lerpf(40.0, size.y - 40.0, fmod(seed * 5.91, 1.0))
		var x := fmod(seed * 13.71 + _elapsed * (0.008 + seed * 0.006), 1.0) * size.x
		var length := 72.0 + seed * 160.0
		var start := Vector2(x - length * 0.5, y + sin(_elapsed * 0.18 + seed * 11.0) * 16.0)
		var end := start + Vector2(length, -length * 0.10)
		draw_line(start, end, Color(0.70, 1.0, 0.95, 0.026 * alpha), 1.3, true)

func _draw_suspended_particles(alpha: float) -> void:
	for particle in _particles:
		var base: Vector2 = particle.get("pos", Vector2.ZERO)
		var speed := float(particle.get("speed", 1.0))
		var phase := float(particle.get("phase", 0.0))
		var drift_amount := float(particle.get("drift", 12.0))
		var depth := float(particle.get("depth", 0.55))
		var drift := Vector2(sin(_elapsed * speed + phase), cos(_elapsed * speed * 0.7 + phase)) * drift_amount
		var screen: Vector2 = _world_to_screen(base + drift)
		if not Rect2(Vector2(-40, -40), size + Vector2(80, 80)).has_point(screen):
			continue
		var radius := float(particle.get("radius", 2.0)) * zoom * lerpf(0.45, 1.16, depth)
		var color: Color = particle.get("color", Color("8fcfd3"))
		var flicker := 0.74 + sin(_elapsed * speed * 1.8 + phase) * 0.26
		draw_circle(screen, maxf(0.55, radius), Color(color.r, color.g, color.b, 0.08 * flicker * alpha * depth))
		if radius > 2.2:
			draw_circle(screen, maxf(0.45, radius * 0.32), Color(1, 1, 1, 0.07 * flicker * alpha * depth))

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
		if _object_texture != null:
			_draw_environment_sprite(item, pos, alpha)
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

func _draw_environment_sprite(item: Dictionary, pos: Vector2, alpha: float) -> void:
	var kind := str(item.get("type", ""))
	var scale_value := float(item.get("scale", 1.0)) * zoom
	var region := _object_sprite_region(kind, int(item.get("variant", 0)))
	var phase := pos.x * 0.013 + pos.y * 0.007
	var pulse := 1.0 + sin(_elapsed * 1.7 + phase) * 0.025
	var target_size := _object_sprite_size(kind, region) * scale_value * pulse
	var angle := float(item.get("angle", 0.0)) + sin(_elapsed * 0.42 + phase) * 0.018
	var bob := Vector2(0, sin(_elapsed * 1.1 + phase) * 3.0)
	_draw_texture_region_centered(_object_texture, region, pos + bob, target_size, angle, Color(1, 1, 1, alpha))

func _object_sprite_region(kind: String, variant: int) -> Rect2:
	match kind:
		"bacteria":
			var regions := [
				Rect2(Vector2(57, 50), Vector2(297, 268)),
				Rect2(Vector2(786, 57), Vector2(301, 257)),
				Rect2(Vector2(1127, 79), Vector2(311, 235)),
			]
			return regions[variant % regions.size()]
		"hostile":
			return Rect2(Vector2(396, 59), Vector2(324, 263))
		"sugar":
			var regions := [
				Rect2(Vector2(62, 410), Vector2(232, 212)),
				Rect2(Vector2(360, 424), Vector2(226, 196)),
			]
			return regions[variant % regions.size()]
		"sulfur":
			var regions := [
				Rect2(Vector2(626, 384), Vector2(252, 246)),
				Rect2(Vector2(880, 432), Vector2(208, 198)),
			]
			return regions[variant % regions.size()]
		"nitrogen":
			return Rect2(Vector2(1086, 420), Vector2(368, 208))
		"dead_cell":
			var regions := [
				Rect2(Vector2(100, 733), Vector2(313, 186)),
				Rect2(Vector2(534, 710), Vector2(231, 214)),
			]
			return regions[variant % regions.size()]
		"virus":
			var regions := [
				Rect2(Vector2(932, 752), Vector2(189, 177)),
				Rect2(Vector2(1245, 759), Vector2(158, 165)),
			]
			return regions[variant % regions.size()]
	return Rect2(Vector2(57, 50), Vector2(297, 268))

func _object_sprite_size(kind: String, region := Rect2()) -> Vector2:
	match kind:
		"bacteria", "hostile":
			return Vector2(250, 170)
		"sugar":
			return _fit_sprite_size(region, 170.0, 150.0)
		"nitrogen":
			return _fit_sprite_size(region, 170.0, 122.0)
		"sulfur":
			return _fit_sprite_size(region, 172.0, 160.0)
		"dead_cell":
			return Vector2(260, 190)
		"virus":
			return Vector2(120, 110)
	return Vector2(120, 100)

func _fit_sprite_size(region: Rect2, max_width: float, max_height: float) -> Vector2:
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return Vector2(max_width, max_height)
	var scale := minf(max_width / region.size.x, max_height / region.size.y)
	return region.size * scale

func _draw_texture_region_centered(texture: Texture2D, region: Rect2, center: Vector2, target_size: Vector2, angle: float, modulate: Color) -> void:
	var x_axis := Vector2.RIGHT.rotated(angle) * target_size.x
	var y_axis := Vector2.DOWN.rotated(angle) * target_size.y
	var top_left := center - x_axis * 0.5 - y_axis * 0.5
	draw_set_transform_matrix(Transform2D(x_axis / region.size.x, y_axis / region.size.y, top_left))
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, region.size), region, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_cell() -> void:
	var pos := _world_to_screen(cell_position)
	var radius := BASE_CELL_RADIUS * zoom
	var forward := Vector2.RIGHT.rotated(cell_angle)
	var back := -forward
	var normal := Vector2(-forward.y, forward.x)
	if _player_cell_texture != null:
		var frame_count := 6
		var frame := int(floor(_elapsed * (5.0 + _swim_power * 1.5))) % frame_count
		var frame_w := float(_player_cell_texture.get_width()) / float(frame_count)
		var region := Rect2(Vector2(0, 0), Vector2(frame_w, _player_cell_texture.get_height()))
		region.position.x += region.size.x * float(frame)
		draw_circle(pos, radius * 0.84, Color(0.12, 0.95, 1.0, 0.035))
		_draw_texture_region_centered(_player_cell_texture, region, pos, Vector2(215, 215) * zoom, cell_angle + PI * 0.5, Color(1, 1, 1, 1))
	else:
		_draw_flagellum(pos + back * radius * 0.84, back, normal, radius, 1.0)
		draw_circle(pos, radius * 0.62, Color(0.12, 0.95, 1.0, 0.025))
		_draw_player_cell(pos, cell_angle, radius, 1.0)
		_draw_heading_indicator(pos, forward, normal, radius, 1.0)

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

func _draw_flagellum(anchor: Vector2, dir: Vector2, normal: Vector2, radius: float, alpha: float) -> void:
	var points := PackedVector2Array()
	var anim := _elapsed * (7.0 + _swim_power * 8.0)
	for i in 44:
		var t := float(i) / 43.0
		var taper := 1.0 - t * 0.58
		var wave := sin(t * TAU * 2.8 + anim) * radius * 0.10 * (0.20 + t) * (0.32 + _swim_power)
		var current := sin(_elapsed * 0.9 + t * 5.0) * radius * 0.015
		points.append(anchor + dir * radius * 1.76 * t + normal * (wave + current) * taper)
	draw_polyline(points, Color(0.0, 0.0, 0.0, 0.68 * alpha), maxf(2.0, radius * 0.050), true)
	draw_polyline(points, Color(0.22, 0.96, 1.0, (0.10 + _swim_power * 0.12) * alpha), maxf(2.0, radius * 0.067), true)
	draw_polyline(points, Color(0.58, 1.0, 0.96, 0.84 * alpha), maxf(1.0, radius * 0.020), true)
	draw_circle(anchor, maxf(2.0, radius * 0.040), Color(0.0, 0.025, 0.035, 0.76 * alpha))
	draw_circle(anchor, maxf(1.0, radius * 0.024), Color(0.58, 1.0, 0.96, 0.66 * alpha))

func _draw_heading_indicator(pos: Vector2, forward: Vector2, normal: Vector2, radius: float, alpha: float) -> void:
	if alpha <= 0.02:
		return
	var edge := PackedVector2Array()
	for i in 24:
		var t := lerpf(-0.86, 0.86, float(i) / 23.0)
		var curve := cos(t) * radius * 0.67
		edge.append(pos + forward * curve + normal * sin(t) * radius * 0.31)
	draw_polyline(edge, Color(0.72, 1.0, 0.94, (0.10 + propulsion_energy * 0.16) * alpha), maxf(1.0, radius * 0.014), true)
	for i in 5:
		var t := lerpf(-0.64, 0.64, float(i) / 4.0)
		var plume_start := pos - forward * radius * 0.74 + normal * sin(t) * radius * 0.18
		var plume_end := plume_start - forward * radius * (0.18 + propulsion_energy * 0.18)
		draw_line(plume_start, plume_end, Color(0.42, 1.0, 0.90, 0.045 * alpha * (0.4 + propulsion_energy)), maxf(1.0, radius * 0.006), true)

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
func _draw_player_cell(pos: Vector2, angle: float, radius: float, alpha := 1.0) -> void:
	var rx := radius * 0.78
	var ry := radius * 0.34
	var shell := PackedVector2Array()
	var inner := PackedVector2Array()
	var cytoplasm := PackedVector2Array()
	for i in 88:
		var a := float(i) / 88.0 * TAU
		var wobble := 1.0 + sin(a * 5.0 + _elapsed * 0.55) * 0.026 + sin(a * 9.0 - _elapsed * 0.34) * 0.010
		shell.append(pos + Vector2(cos(a) * rx * wobble, sin(a) * ry * wobble).rotated(angle))
		inner.append(pos + Vector2(cos(a) * rx * 0.91, sin(a) * ry * 0.82).rotated(angle))
		cytoplasm.append(pos + Vector2(cos(a) * rx * 0.78, sin(a) * ry * 0.66).rotated(angle))
	draw_colored_polygon(shell, Color(0.0, 0.018, 0.024, 0.82 * alpha))
	draw_colored_polygon(inner, Color(0.13, 0.58, 0.67, 0.74 * alpha))
	draw_colored_polygon(cytoplasm, Color(0.13, 0.47, 0.52, 0.78 * alpha))
	var forward := Vector2.RIGHT.rotated(angle)
	var normal := Vector2(-forward.y, forward.x)
	for i in 9:
		var seed := float(abs(("player-cell-patch:%d" % i).hash() % 10000)) / 10000.0
		var seed_b := float(abs(("player-cell-patch-b:%d" % i).hash() % 10000)) / 10000.0
		var local := Vector2(lerpf(-0.50, 0.50, seed), lerpf(-0.34, 0.34, seed_b))
		var patch := pos + forward * local.x * rx + normal * local.y * ry
		var patch_radius := radius * lerpf(0.045, 0.095, seed_b)
		draw_circle(patch, patch_radius, Color(0.42, 1.0, 0.82, 0.055 * alpha))
	for i in 88:
		if i % 7 != 0:
			continue
		var a := float(i) / 88.0 * TAU
		var p := pos + Vector2(cos(a) * rx * 0.93, sin(a) * ry * 0.84).rotated(angle)
		draw_circle(p, maxf(1.0, radius * 0.017), Color(0.78, 1.0, 0.92, 0.30 * alpha))
	draw_arc(pos, rx * 0.64, angle - 0.78, angle + 0.78, 24, Color(1, 1, 1, 0.18 * alpha), maxf(1.0, radius * 0.016), true)
	for i in 18:
		var seed := float(abs(("player-cell-dot:%d" % i).hash() % 10000)) / 10000.0
		var seed_b := float(abs(("player-cell-dot-b:%d" % i).hash() % 10000)) / 10000.0
		var local := Vector2(lerpf(-0.58, 0.58, seed), lerpf(-0.44, 0.44, seed_b))
		var dot := pos + forward * local.x * rx + normal * local.y * ry
		var color := Color("a8fff0") if i % 3 != 0 else Color("ffe064")
		draw_circle(dot, maxf(1.0, radius * (0.014 + seed_b * 0.012)), Color(0, 0, 0, 0.26 * alpha))
		draw_circle(dot, maxf(1.0, radius * (0.010 + seed_b * 0.010)), Color(color.r, color.g, color.b, 0.30 * alpha))

func _draw_deposit(pos: Vector2, scale_value: float, color: Color, count: int, alpha := 1.0) -> void:
	for i in count:
		var angle := float(i) / float(count) * TAU + _elapsed * 0.04
		var offset := Vector2(cos(angle), sin(angle)) * (14.0 + fposmod(i * 11.0, 36.0)) * zoom * scale_value
		var r := (8.0 + fposmod(i * 5.0, 8.0)) * zoom * scale_value
		draw_circle(pos + offset, r + 11.0 * zoom, Color(color.r, color.g, color.b, 0.045 * alpha))
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

func _draw_propulsion_widget() -> void:
	var panel := Rect2(Vector2(18, size.y - 86), Vector2(218, 58))
	draw_rect(panel, Color(0.035, 0.10, 0.13, 0.58), true)
	draw_rect(panel, Color(0.46, 0.96, 1.0, 0.42), false, 1.0)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 22), "Flagellum output", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.76, 0.92, 0.92, 0.90))
	var bar := Rect2(panel.position + Vector2(12, 34), Vector2(panel.size.x - 24, 10))
	draw_rect(bar, Color(0.01, 0.04, 0.05, 0.86), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * propulsion_energy, bar.size.y)), Color("76f4ff"), true)
	draw_rect(bar, Color(0.8, 1.0, 0.94, 0.24), false, 1.0)

func _world_to_screen(world: Vector2) -> Vector2:
	return (world - camera_position) * zoom + size * 0.5

func _cover_rect(source_size: Vector2, bounds: Rect2) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return bounds
	var scale_value := maxf(bounds.size.x / source_size.x, bounds.size.y / source_size.y)
	var fitted := source_size * scale_value
	return Rect2(bounds.position + (bounds.size - fitted) * 0.5, fitted)

func _load_texture(path: String) -> Texture2D:
	var actual_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(actual_path):
		return null
	var image := Image.load_from_file(actual_path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

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
	var saved := _load_saved_map_objects()
	if not saved.is_empty():
		_environment = saved
		return
	_environment = [
		{"type": "sugar", "pos": Vector2(520, -220), "scale": 1.3},
		{"type": "sugar", "pos": Vector2(-1560, -360), "scale": 0.82},
		{"type": "sugar", "pos": Vector2(1720, 1120), "scale": 0.92},
		{"type": "sulfur", "pos": Vector2(980, 420), "scale": 1.2},
		{"type": "sulfur", "pos": Vector2(-1840, 980), "scale": 0.78},
		{"type": "nitrogen", "pos": Vector2(-840, 680), "scale": 1.1},
		{"type": "nitrogen", "pos": Vector2(1480, -980), "scale": 0.74},
		{"type": "bacteria", "variant": 0, "pos": Vector2(-720, -520), "angle": 0.4, "scale": 0.80, "color": Color("97b4aa")},
		{"type": "bacteria", "variant": 2, "pos": Vector2(1260, -620), "angle": -0.2, "scale": 0.95, "color": Color("92aaa2")},
		{"type": "bacteria", "variant": 3, "pos": Vector2(2120, 230), "angle": 0.15, "scale": 0.55, "color": Color("6f8f8a")},
		{"type": "bacteria", "variant": 2, "pos": Vector2(-2060, -1120), "angle": -0.48, "scale": 0.52, "color": Color("769893")},
		{"type": "hostile", "pos": Vector2(-1180, 160), "angle": -0.6, "scale": 0.72},
		{"type": "hostile", "pos": Vector2(380, 760), "angle": 0.8, "scale": 0.62},
		{"type": "dead_cell", "variant": 0, "pos": Vector2(-360, 1150), "angle": 0.25, "scale": 0.92},
		{"type": "dead_cell", "variant": 1, "pos": Vector2(1880, -260), "angle": -0.18, "scale": 0.72},
		{"type": "virus", "pos": Vector2(840, -860), "scale": 0.9},
		{"type": "virus", "pos": Vector2(-1480, -820), "scale": 0.75},
		{"type": "virus", "pos": Vector2(1540, 760), "scale": 0.85}
	]

func _load_saved_map_objects() -> Array[Dictionary]:
	var path := ProjectSettings.globalize_path(MAP_PATH)
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var loaded: Array = parsed.get("objects", [])
	var objects: Array[Dictionary] = []
	for item in loaded:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		objects.append({
			"type": str(item.get("type", "sugar")),
			"variant": int(item.get("variant", 0)),
			"pos": Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))),
			"scale": float(item.get("scale", 1.0)),
			"angle": float(item.get("angle", 0.0))
		})
	return objects

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
	for i in 420:
		var seed := float(abs(("particle:%d" % i).hash() % 10000)) / 10000.0
		var seed_b := float(abs(("particle-b:%d" % i).hash() % 10000)) / 10000.0
		var depth := 0.24 + fmod(seed * 5.37 + seed_b * 2.11, 0.76)
		_particles.append({
			"pos": Vector2(lerpf(WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x, seed), lerpf(WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y, seed_b)),
			"phase": seed * TAU * 4.0,
			"speed": 0.25 + seed_b * 0.6,
			"drift": 10.0 + seed * 34.0,
			"radius": 0.8 + seed_b * 2.8,
			"depth": depth,
			"color": Color("8fcfd3") if i % 6 != 0 else (Color("d8ed67") if i % 2 == 0 else Color("ef7779"))
		})
