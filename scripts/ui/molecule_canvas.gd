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
		var radius := 26.0 if element == "C" else 22.0
		var base := Color("69787c") if element == "C" else Color("e95058")
		draw_circle(pos, radius + 5.0, Color("02080c"))
		draw_circle(pos, radius, base.darkened(0.16))
		draw_circle(pos + Vector2(-4, -4), radius * 0.72, base.lightened(0.12))
		draw_circle(pos + Vector2(radius * 0.28, -radius * 0.36), radius * 0.22, Color(1, 1, 1, 0.34))

func _draw_bond(a: Vector2, b: Vector2, order: int, highlight: bool, selected: bool) -> void:
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var color := Color("e9f6f7")
	var outline := Color("02080c")
	var width := 7.0
	if highlight:
		color = Color("73e6ff")
		width = 8.0
	if selected:
		color = Color("8cff6a")
		width = 9.0
	var offsets := [0.0]
	if order == 2:
		offsets = [-6.0, 6.0]
	for offset in offsets:
		var start: Vector2 = a + dir * 22.0 + normal * offset
		var end: Vector2 = b - dir * 22.0 + normal * offset
		draw_line(start, end, outline, width + 5.0, true)
		draw_line(start, end, color, width, true)

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
