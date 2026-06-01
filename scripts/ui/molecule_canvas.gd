extends Control
class_name MoleculeCanvas

signal target_selected(target_index: int)

var molecule: Dictionary = {}
var valid_targets: Array[int] = []
var interactive := false
var selected_target := -1
var scale_to_fit := true

func set_molecule(value: Dictionary) -> void:
	molecule = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := _nearest_valid_bond(event.position)
		if target >= 0:
			selected_target = target
			emit_signal("target_selected", target)
			queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10292d"))
	if molecule.is_empty():
		return
	var transform := _graph_transform()
	_draw_bonds(transform)
	_draw_atoms(transform)

func _draw_bonds(transform: Transform2D) -> void:
	var atoms: Array = molecule.get("atoms", [])
	var bonds: Array = molecule.get("bonds", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var a: Vector2 = transform * atoms[int(bond.get("a", 0))].get("pos", Vector2.ZERO)
		var b: Vector2 = transform * atoms[int(bond.get("b", 0))].get("pos", Vector2.ZERO)
		var highlight := valid_targets.has(i)
		var selected := selected_target == i
		_draw_bond(a, b, int(bond.get("order", 1)), highlight, selected)

func _draw_atoms(transform: Transform2D) -> void:
	var atoms: Array = molecule.get("atoms", [])
	for atom in atoms:
		var pos: Vector2 = transform * atom.get("pos", Vector2.ZERO)
		var element: String = atom.get("element", "C")
		var radius := 28.0 if element == "C" else 24.0
		var base := Color("728186") if element == "C" else Color("e85058")
		_draw_atom(pos, radius, base)

func _draw_bond(a: Vector2, b: Vector2, order: int, highlight: bool, selected: bool) -> void:
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var color := Color("dbeff2")
	var outline := Color("02070b")
	var inner := Color("f4fbff")
	var width := 8.0
	if highlight:
		color = Color("73e6ff")
		inner = Color("c8fbff")
		width = 9.0
	if selected:
		color = Color("8cff6a")
		inner = Color("e7ffd8")
		width = 10.0
	var offsets := [0.0]
	if order == 2:
		offsets = [-7.0, 7.0]
	for offset in offsets:
		var start: Vector2 = a + dir * 22.0 + normal * offset
		var end: Vector2 = b - dir * 22.0 + normal * offset
		draw_line(start, end, outline, width + 7.0, true)
		draw_line(start, end, color.darkened(0.08), width + 2.0, true)
		draw_line(start + normal * 0.7, end + normal * 0.7, inner, maxf(2.0, width * 0.32), true)

func _draw_atom(pos: Vector2, radius: float, base: Color) -> void:
	draw_circle(pos, radius + 6.0, Color("02070b"))
	draw_circle(pos, radius + 2.0, base.lightened(0.34))
	draw_circle(pos, radius - 1.0, base.darkened(0.20))
	var steps := 8
	for i in steps:
		var t := float(i) / float(steps - 1)
		var r := lerpf(radius * 0.84, radius * 0.20, t)
		var offset := Vector2(-radius * 0.16, -radius * 0.15) * (1.0 - t)
		var shade := base.darkened(0.12).lerp(base.lightened(0.28), t)
		draw_circle(pos + offset, r, Color(shade.r, shade.g, shade.b, 0.28))
	draw_circle(pos + Vector2(radius * 0.26, -radius * 0.39), radius * 0.20, Color(1, 1, 1, 0.42))
	draw_circle(pos + Vector2(radius * 0.31, -radius * 0.43), radius * 0.10, Color(1, 1, 1, 0.22))

func _nearest_valid_bond(point: Vector2) -> int:
	var atoms: Array = molecule.get("atoms", [])
	var bonds: Array = molecule.get("bonds", [])
	var transform := _graph_transform()
	var best := -1
	var best_distance := 26.0
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
	var available := (size - Vector2(80, 80)).max(Vector2(80, 80))
	var zoom = minf(available.x / graph_size.x, available.y / graph_size.y)
	if not scale_to_fit:
		zoom = 1.0
	zoom = clampf(zoom, 0.45, 1.8)
	var center_offset: Vector2 = size * 0.5 - (min_pos + graph_size * 0.5) * zoom
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, center_offset)
