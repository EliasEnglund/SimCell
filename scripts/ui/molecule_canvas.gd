extends Control
class_name MoleculeCanvas

signal target_selected(target_index: int)

var molecule: Dictionary = {}
var valid_targets: Array[int] = []
var interactive := false
var selected_target := -1
var scale_to_fit := true
var fixed_zoom := 1.0
var selection_glow := false
var physical_touch := false
var draw_background := true
var atom_scale := 1.0
var bond_scale := 1.0
var graph_spacing_scale := 1.0
var atom_outline_extra := 4.6
var atom_inner_stroke_extra := 1.3
var atom_gloss_alpha := 0.42
var bond_outline_extra := 7.0
var bond_core_extra := 2.0
var bond_trim_scale := 1.0
var double_bond_gap := 7.0

var _visual_offsets: Array[Vector2] = []
var _visual_velocities: Array[Vector2] = []
var _grabbed_atom := -1
var _grabbed_bond := -1
var _hover_atom := -1
var _hover_bond := -1
var _pointer_position := Vector2.ZERO
var _press_position := Vector2.ZERO
var _pull_warning := 0.0
var _release_flash := 0.0

func _ready() -> void:
	set_process(true)

func set_molecule(value: Dictionary) -> void:
	molecule = value
	_reset_physics_state()
	queue_redraw()

func _process(delta: float) -> void:
	if molecule.is_empty() or _visual_offsets.is_empty():
		return
	if not physical_touch and _grabbed_atom < 0 and _grabbed_bond < 0 and _release_flash <= 0.0 and _all_offsets_settled():
		return
	_update_physical_touch(delta)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseMotion:
		_pointer_position = event.position
		_hover_atom = _nearest_atom(event.position)
		_hover_bond = _nearest_valid_bond(event.position) if _hover_atom < 0 else -1
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_position = event.position
		if event.pressed:
			_press_position = event.position
			if physical_touch:
				var atom := _nearest_atom(event.position)
				if atom >= 0:
					_grabbed_atom = atom
					_grabbed_bond = -1
					_hover_atom = atom
					_pull_warning = 0.0
					queue_redraw()
					return
				var bond := _nearest_valid_bond(event.position)
				if bond >= 0:
					_grabbed_bond = bond
					_grabbed_atom = -1
					_hover_bond = bond
					_pull_warning = 0.0
					queue_redraw()
					return
			_select_bond_target(event.position)
		else:
			if _grabbed_bond >= 0 and event.position.distance_to(_press_position) <= 7.0:
				_select_bond_target(event.position)
			_release_touch(false)

func _select_bond_target(point: Vector2) -> void:
	var target := _nearest_valid_bond(point)
	if target >= 0:
		selected_target = target
		emit_signal("target_selected", target)
		queue_redraw()

func _draw() -> void:
	if draw_background:
		draw_rect(Rect2(Vector2.ZERO, size), Color("10292d"))
	if molecule.is_empty():
		return
	var transform := _graph_transform()
	var zoom := _graph_zoom(transform)
	if selection_glow:
		_draw_selection_glow(transform, zoom)
	_draw_bonds(transform, zoom)
	_draw_touch_feedback(transform, zoom)
	_draw_atoms(transform, zoom)

func _draw_selection_glow(transform: Transform2D, zoom: float) -> void:
	var atoms: Array = molecule.get("atoms", [])
	var bonds: Array = molecule.get("bonds", [])
	var glow := Color(0.35, 1.0, 0.78, 0.28)
	for bond in bonds:
		var a: Vector2 = transform * atoms[int(bond.get("a", 0))].get("pos", Vector2.ZERO)
		var b: Vector2 = transform * atoms[int(bond.get("b", 0))].get("pos", Vector2.ZERO)
		var dir := (b - a).normalized()
		draw_line(a + dir * 22.0 * zoom, b - dir * 22.0 * zoom, glow, 28.0 * zoom, true)
	for atom in atoms:
		var pos: Vector2 = transform * atom.get("pos", Vector2.ZERO)
		var element: String = atom.get("element", "C")
		var radius := (_atom_radius(element) + 12.0) * zoom
		draw_circle(pos, radius + 10.0 * zoom, Color(0.35, 1.0, 0.78, 0.08))
		draw_circle(pos, radius + 4.0 * zoom, glow)

func _draw_bonds(transform: Transform2D, zoom: float) -> void:
	var atoms: Array = molecule.get("atoms", [])
	var bonds: Array = molecule.get("bonds", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var atom_a := int(bond.get("a", 0))
		var atom_b := int(bond.get("b", 0))
		var a: Vector2 = _atom_screen_position(atom_a, transform)
		var b: Vector2 = _atom_screen_position(atom_b, transform)
		var highlight := valid_targets.has(i)
		var selected := selected_target == i
		var touched := _hover_bond == i or _grabbed_bond == i
		var rest_a: Vector2 = atoms[atom_a].get("pos", Vector2.ZERO)
		var rest_b: Vector2 = atoms[atom_b].get("pos", Vector2.ZERO)
		var rest_length := maxf(1.0, rest_a.distance_to(rest_b) * zoom)
		var tension := clampf((a.distance_to(b) - rest_length) / maxf(rest_length, 1.0), 0.0, 1.0)
		_draw_bond(a, b, int(bond.get("order", 1)), highlight or touched, selected, zoom, tension, touched)

func _draw_atoms(transform: Transform2D, zoom: float) -> void:
	var atoms: Array = molecule.get("atoms", [])
	for i in atoms.size():
		var atom: Dictionary = atoms[i]
		var pos: Vector2 = _atom_screen_position(i, transform)
		var element: String = atom.get("element", "C")
		var radius := _atom_radius(element) * zoom * atom_scale
		var base := _atom_color(element)
		if i == _hover_atom or i == _grabbed_atom:
			draw_circle(pos, radius + 12.0 * zoom, Color(0.45, 1.0, 0.9, 0.16))
			draw_circle(pos, radius + 5.0 * zoom, Color(0.45, 1.0, 0.9, 0.18))
		_draw_atom(pos, radius, base)

func _draw_bond(a: Vector2, b: Vector2, order: int, highlight: bool, selected: bool, zoom: float, tension: float = 0.0, touched: bool = false) -> void:
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var color := Color("dbeff2").lerp(Color("ffe064"), tension)
	var outline := Color("02070b")
	var inner := Color("f4fbff").lerp(Color("fff1a8"), tension)
	var width := (8.0 + tension * 3.0) * zoom * bond_scale
	if highlight:
		color = Color("73e6ff").lerp(Color("ffe064"), tension)
		inner = Color("c8fbff")
		width = 9.0 * zoom * bond_scale
	if touched:
		width = (11.0 + tension * 4.0) * zoom * bond_scale
	if selected:
		color = Color("8cff6a").lerp(Color("ffe064"), tension * 0.5)
		inner = Color("e7ffd8")
		width = 10.0 * zoom * bond_scale
	var offsets := [0.0]
	if order == 2:
		offsets = [-double_bond_gap * zoom * bond_scale, double_bond_gap * zoom * bond_scale]
	for offset in offsets:
		var trim := 28.0 * zoom * atom_scale * bond_trim_scale
		var start: Vector2 = a + dir * trim + normal * offset
		var end: Vector2 = b - dir * trim + normal * offset
		draw_line(start, end, outline, width + bond_outline_extra * zoom * bond_scale, true)
		draw_line(start, end, color.darkened(0.08), width + bond_core_extra * zoom * bond_scale, true)
		draw_line(start + normal * 0.7 * zoom, end + normal * 0.7 * zoom, inner, maxf(1.0, width * 0.32), true)
		if tension > 0.08:
			_draw_electric_bond(start, end, normal, zoom, tension, offset)

func _draw_electric_bond(start: Vector2, end: Vector2, normal: Vector2, zoom: float, tension: float, offset: float) -> void:
	var dir := (end - start).normalized()
	var length := start.distance_to(end)
	if length < 8.0:
		return
	var intensity := smoothstep(0.08, 0.85, tension)
	var electric := Color("76f4ff").lerp(Color("ffe064"), intensity)
	var hot := Color("f4fbff").lerp(Color("fff1a8"), intensity)
	var segment_count := 5 + int(4.0 * intensity)
	var points := PackedVector2Array()
	for i in segment_count + 1:
		var t := float(i) / float(segment_count)
		var base := start.lerp(end, t)
		var wave := sin(t * TAU * (2.0 + intensity) + offset * 0.19 + Time.get_ticks_msec() * 0.008)
		var jag := sin((t + 0.37) * TAU * 5.0 + Time.get_ticks_msec() * 0.015)
		var side := normal * (wave * 9.0 + jag * 4.0) * zoom * intensity
		if i == 0 or i == segment_count:
			side = Vector2.ZERO
		points.append(base + side)
	draw_polyline(points, Color(electric.r, electric.g, electric.b, 0.22 + 0.30 * intensity), (8.0 + intensity * 7.0) * zoom, true)
	draw_polyline(points, electric, (2.0 + intensity * 2.0) * zoom, true)
	draw_polyline(points, hot, maxf(1.0, 0.8 * zoom), true)
	var spark_count := 1 + int(3.0 * intensity)
	for s in spark_count:
		var t := fmod(Time.get_ticks_msec() * 0.0015 + float(s) * 0.31 + offset * 0.01, 1.0)
		var center := start.lerp(end, t)
		var spark_normal := normal.rotated((float(s % 2) - 0.5) * 0.8)
		var spark_len := (10.0 + 14.0 * intensity) * zoom
		draw_line(center - spark_normal * spark_len * 0.35, center + spark_normal * spark_len, Color(electric.r, electric.g, electric.b, 0.52), maxf(1.0, 1.4 * zoom), true)

func _draw_touch_feedback(transform: Transform2D, zoom: float) -> void:
	if _grabbed_atom < 0 and _grabbed_bond < 0:
		if _release_flash > 0.01:
			draw_circle(_pointer_position, 32.0 * _release_flash, Color(0.45, 1.0, 0.9, 0.18 * _release_flash))
		return
	var atom_pos := _atom_screen_position(_grabbed_atom, transform) if _grabbed_atom >= 0 else _bond_center(_grabbed_bond, transform)
	var tension_color := Color("76f4ff").lerp(Color("ffe064"), _pull_warning)
	draw_line(atom_pos, _pointer_position, Color("02070b"), 7.0, true)
	draw_line(atom_pos, _pointer_position, tension_color, 3.0, true)
	draw_circle(_pointer_position, 9.0 + 8.0 * _pull_warning, Color(tension_color.r, tension_color.g, tension_color.b, 0.26))

func _draw_atom(pos: Vector2, radius: float, base: Color) -> void:
	draw_circle(pos, radius + atom_outline_extra, Color("02070b"))
	draw_circle(pos, radius + atom_inner_stroke_extra, base.lightened(0.30))
	draw_circle(pos, radius - 1.1, base.darkened(0.14))
	draw_circle(pos + Vector2(-radius * 0.10, -radius * 0.08), radius * 0.62, Color(base.lightened(0.08).r, base.lightened(0.08).g, base.lightened(0.08).b, 0.20))
	draw_circle(pos + Vector2(radius * 0.27, -radius * 0.39), radius * 0.20, Color(1, 1, 1, atom_gloss_alpha))

func _atom_radius(element: String) -> float:
	if element == "C":
		return 28.0
	return 25.0

func _atom_color(element: String) -> Color:
	if element == "O":
		return Color("e95058")
	if element == "P":
		return Color("a34ed0")
	if element == "N":
		return Color("4a90df")
	if element == "S":
		return Color("ffe064")
	return Color("728186")

func _reset_physics_state() -> void:
	var atom_count := int(molecule.get("atoms", []).size())
	_visual_offsets = []
	_visual_velocities = []
	for i in atom_count:
		_visual_offsets.append(Vector2.ZERO)
		_visual_velocities.append(Vector2.ZERO)
	_grabbed_atom = -1
	_hover_atom = -1
	_pull_warning = 0.0
	_release_flash = 0.0

func _all_offsets_settled() -> bool:
	for i in _visual_offsets.size():
		if _visual_offsets[i].length_squared() > 0.01:
			return false
		if i < _visual_velocities.size() and _visual_velocities[i].length_squared() > 0.01:
			return false
	return true

func _update_physical_touch(delta: float) -> void:
	_release_flash = maxf(0.0, _release_flash - delta * 2.8)
	var transform := _graph_transform()
	var zoom := _graph_zoom(transform)
	var atoms: Array = molecule.get("atoms", [])
	if _grabbed_atom >= atoms.size():
		_release_touch(false)
	if _grabbed_atom >= 0:
		var rest_screen: Vector2 = transform * atoms[_grabbed_atom].get("pos", Vector2.ZERO)
		var raw_pull_screen := _pointer_position - rest_screen
		var break_distance := 165.0 * zoom
		var elastic_limit := 118.0 * zoom
		_pull_warning = clampf(raw_pull_screen.length() / break_distance, 0.0, 1.0)
		if raw_pull_screen.length() > break_distance:
			_release_touch(true)
		else:
			var softened_pull := raw_pull_screen.limit_length(elastic_limit) * 0.52
			var desired_world := softened_pull / maxf(zoom, 0.001)
			_apply_graph_pull(_grabbed_atom, desired_world)
	elif _grabbed_bond >= 0:
		_apply_bond_pull(transform, zoom)
	var stiffness := 18.0 if _grabbed_atom < 0 and _grabbed_bond < 0 else 11.0
	var damping := 7.5
	for i in _visual_offsets.size():
		var is_grabbed := i == _grabbed_atom or _bond_has_atom(_grabbed_bond, i)
		var target := _visual_offsets[i] if is_grabbed else Vector2.ZERO
		var spring := (target - _visual_offsets[i]) * stiffness
		_visual_velocities[i] += spring * delta
		_visual_velocities[i] *= maxf(0.0, 1.0 - damping * delta)
		if not is_grabbed:
			_visual_offsets[i] += _visual_velocities[i] * delta
	_visual_offsets = _relax_bond_lengths(_visual_offsets, delta)

func _apply_bond_pull(transform: Transform2D, zoom: float) -> void:
	var bonds: Array = molecule.get("bonds", [])
	if _grabbed_bond < 0 or _grabbed_bond >= bonds.size():
		_release_touch(false)
		return
	var bond: Dictionary = bonds[_grabbed_bond]
	var a := int(bond.get("a", 0))
	var b := int(bond.get("b", 0))
	var center := _bond_center(_grabbed_bond, transform)
	var raw_pull_screen := _pointer_position - center
	var break_distance := 145.0 * zoom
	var elastic_limit := 98.0 * zoom
	_pull_warning = clampf(raw_pull_screen.length() / break_distance, 0.0, 1.0)
	if raw_pull_screen.length() > break_distance:
		_release_touch(true)
		return
	var desired_world := raw_pull_screen.limit_length(elastic_limit) / maxf(zoom, 0.001) * 0.34
	_apply_graph_pull(a, desired_world)
	_apply_graph_pull(b, desired_world)

func _apply_graph_pull(atom_index: int, desired_world: Vector2) -> void:
	var distances := _atom_graph_distances(atom_index)
	for i in _visual_offsets.size():
		var graph_distance := int(distances.get(i, 99))
		if graph_distance > 4:
			continue
		var influence := pow(0.48, graph_distance)
		if i == atom_index:
			influence = 1.0
		_visual_offsets[i] = _visual_offsets[i].lerp(desired_world * influence, 0.32)

func _relax_bond_lengths(offsets: Array[Vector2], delta: float) -> Array[Vector2]:
	var atoms: Array = molecule.get("atoms", [])
	var bonds: Array = molecule.get("bonds", [])
	for bond in bonds:
		var a := int(bond.get("a", 0))
		var b := int(bond.get("b", 0))
		if a >= offsets.size() or b >= offsets.size():
			continue
		var rest_delta: Vector2 = atoms[b].get("pos", Vector2.ZERO) - atoms[a].get("pos", Vector2.ZERO)
		var current_delta := rest_delta + offsets[b] - offsets[a]
		var stretch := current_delta.length() - rest_delta.length()
		if absf(stretch) < 0.01:
			continue
		var correction := current_delta.normalized() * stretch * 0.22 * delta
		if a != _grabbed_atom and not _bond_has_atom(_grabbed_bond, a):
			offsets[a] += correction
		if b != _grabbed_atom and not _bond_has_atom(_grabbed_bond, b):
			offsets[b] -= correction
	return offsets

func _release_touch(hard: bool) -> void:
	if (_grabbed_atom >= 0 or _grabbed_bond >= 0) and hard:
		_release_flash = 1.0
		var transform := _graph_transform()
		var zoom := _graph_zoom(transform)
		if _grabbed_atom >= 0 and _grabbed_atom < _visual_velocities.size():
			var atom_pos := _atom_screen_position(_grabbed_atom, transform)
			_visual_velocities[_grabbed_atom] += (atom_pos - _pointer_position) / maxf(zoom, 0.001) * 4.0
		elif _grabbed_bond >= 0:
			var bonds: Array = molecule.get("bonds", [])
			if _grabbed_bond < bonds.size():
				var bond: Dictionary = bonds[_grabbed_bond]
				var center := _bond_center(_grabbed_bond, transform)
				var kick := (center - _pointer_position) / maxf(zoom, 0.001) * 2.6
				var a := int(bond.get("a", 0))
				var b := int(bond.get("b", 0))
				if a < _visual_velocities.size():
					_visual_velocities[a] += kick
				if b < _visual_velocities.size():
					_visual_velocities[b] += kick
	_grabbed_atom = -1
	_grabbed_bond = -1
	_pull_warning = 0.0

func _bond_has_atom(bond_index: int, atom_index: int) -> bool:
	if bond_index < 0:
		return false
	var bonds: Array = molecule.get("bonds", [])
	if bond_index >= bonds.size():
		return false
	var bond: Dictionary = bonds[bond_index]
	return int(bond.get("a", -1)) == atom_index or int(bond.get("b", -1)) == atom_index

func _bond_center(bond_index: int, transform: Transform2D) -> Vector2:
	var bonds: Array = molecule.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return Vector2.ZERO
	var bond: Dictionary = bonds[bond_index]
	return (_atom_screen_position(int(bond.get("a", 0)), transform) + _atom_screen_position(int(bond.get("b", 0)), transform)) * 0.5

func _nearest_atom(point: Vector2) -> int:
	if molecule.is_empty():
		return -1
	var atoms: Array = molecule.get("atoms", [])
	var transform := _graph_transform()
	var zoom := _graph_zoom(transform)
	var best := -1
	var best_distance := 34.0 * zoom
	for i in atoms.size():
		var pos := _atom_screen_position(i, transform)
		var distance := point.distance_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

func _atom_graph_distances(start: int) -> Dictionary:
	var distances := {start: 0}
	var queue := [start]
	var bonds: Array = molecule.get("bonds", [])
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var current_distance := int(distances[current])
		for bond in bonds:
			var a := int(bond.get("a", 0))
			var b := int(bond.get("b", 0))
			var next := -1
			if a == current:
				next = b
			elif b == current:
				next = a
			if next >= 0 and not distances.has(next):
				distances[next] = current_distance + 1
				queue.append(next)
	return distances

func _atom_screen_position(index: int, transform: Transform2D) -> Vector2:
	var atoms: Array = molecule.get("atoms", [])
	if index < 0 or index >= atoms.size():
		return Vector2.ZERO
	var offset := Vector2.ZERO
	if index < _visual_offsets.size():
		offset = _visual_offsets[index]
	return transform * (_styled_graph_position(atoms[index].get("pos", Vector2.ZERO) + offset))

func _styled_graph_position(pos: Vector2) -> Vector2:
	if is_equal_approx(graph_spacing_scale, 1.0):
		return pos
	var center := _molecule_center()
	return center + (pos - center) * graph_spacing_scale

func _molecule_center() -> Vector2:
	var atoms: Array = molecule.get("atoms", [])
	if atoms.is_empty():
		return Vector2.ZERO
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for atom in atoms:
		var pos: Vector2 = atom.get("pos", Vector2.ZERO)
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
	return (min_pos + max_pos) * 0.5

func _nearest_valid_bond(point: Vector2) -> int:
	var atoms: Array = molecule.get("atoms", [])
	var bonds: Array = molecule.get("bonds", [])
	var transform := _graph_transform()
	var best := -1
	var best_distance := 26.0 * _graph_zoom(transform)
	for i in valid_targets:
		var bond: Dictionary = bonds[i]
		var a: Vector2 = transform * atoms[int(bond.get("a", 0))].get("pos", Vector2.ZERO)
		var b: Vector2 = transform * atoms[int(bond.get("b", 0))].get("pos", Vector2.ZERO)
		var distance := _distance_to_segment(point, a, b)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((point - a).dot(ab) / maxf(1.0, ab.length_squared()), 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _graph_transform() -> Transform2D:
	var atoms: Array = molecule.get("atoms", [])
	if atoms.is_empty():
		return Transform2D.IDENTITY
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for atom in atoms:
		var pos: Vector2 = atom.get("pos", Vector2.ZERO)
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
	var graph_size := (max_pos - min_pos).max(Vector2(1.0, 1.0))
	var available := (size - Vector2(42, 42)).max(Vector2(24, 24))
	var zoom = minf(available.x / graph_size.x, available.y / graph_size.y)
	if not scale_to_fit:
		zoom = fixed_zoom
	zoom = clampf(zoom, 0.12, 1.8)
	var center_offset: Vector2 = size * 0.5 - (min_pos + graph_size * 0.5) * zoom
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, center_offset)

func _graph_zoom(transform: Transform2D) -> float:
	return transform.x.length()
