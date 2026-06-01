extends Control
class_name MetabolismWorkspace

signal molecule_requested(molecule_id: String)

const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")

var simulation
var pan_offset := Vector2.ZERO
var _dragging := false
var _last_mouse := Vector2.ZERO
var _drag_distance := 0.0
var _fixed_zoom := 0.72
var _layout_positions := {}

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			_dragging = true
			_drag_distance = 0.0
			_last_mouse = event.position
			mouse_default_cursor_shape = Control.CURSOR_MOVE
		elif not event.pressed:
			_dragging = false
			mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif event is InputEventMouseMotion and _dragging:
		pan_offset += event.position - _last_mouse
		_drag_distance += event.position.distance_to(_last_mouse)
		_last_mouse = event.position
		_rebuild()

func rebuild() -> void:
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if simulation == null:
		return
	var background := ColorRect.new()
	background.color = Color("10292d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title := Label.new()
	title.text = "METABOLIC LANDSCAPE"
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("76f4ff")
	title.position = Vector2(28, 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var ids: Array[String] = simulation.metabolism_molecule_ids()
	var layout := _metabolism_layout(ids, maxf(760.0, size.x))
	var positions := {}
	var sizes := {}
	for id in ids:
		var item: Dictionary = layout[id]
		positions[id] = item["position"] + pan_offset
		sizes[id] = item["size"]
	_draw_reaction_arrows(positions, sizes)
	for id in ids:
		add_child(_map_molecule_node(id, positions[id], sizes[id]))

func _draw_reaction_arrows(positions: Dictionary, sizes: Dictionary) -> void:
	for reaction in simulation.pathway_arrows():
		var substrate: String = reaction.get("substrate", "")
		var products: Array = reaction.get("products", [])
		if not positions.has(substrate):
			continue
		var source_center: Vector2 = positions[substrate] + sizes[substrate] * 0.5
		for product_id in products:
			if not positions.has(product_id):
				continue
			var target_center: Vector2 = positions[product_id] + sizes[product_id] * 0.5
			var arrow := ArrowLine.new()
			arrow.start = source_center
			arrow.end = target_center
			arrow.rate = float(reaction.get("rate", 0.0))
			arrow.active = int(reaction.get("active_count", 0)) > 0
			arrow.queued = int(reaction.get("queued_count", 0)) > 0
			arrow.label = _arrow_label(reaction)
			arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(arrow)

func _arrow_label(pathway: Dictionary) -> String:
	var rate := float(pathway.get("rate", 0.0))
	if int(pathway.get("active_count", 0)) > 0:
		return "%.2f/s" % rate
	if int(pathway.get("queued_count", 0)) > 0:
		return "building"
	return "designed"

func _metabolism_layout(ids: Array[String], map_width: float) -> Dictionary:
	var result := {}
	var sizes := {}
	for id in ids:
		sizes[id] = _molecule_canvas_size(simulation.molecule_types[id], _fixed_zoom)
	if ids.is_empty():
		return result
	var first_id := ids[0]
	if not _layout_positions.has(first_id):
		var first_size: Vector2 = sizes[first_id]
		_layout_positions[first_id] = Vector2(map_width * 0.5 - first_size.x * 0.5, 78.0)
	for pathway in simulation.pathway_arrows():
		var substrate_id: String = pathway.get("substrate", "")
		if not _layout_positions.has(substrate_id):
			continue
		var products: Array = pathway.get("products", [])
		for i in products.size():
			var product_id: String = products[i]
			if not sizes.has(product_id) or _layout_positions.has(product_id):
				continue
			var source_pos: Vector2 = _layout_positions[substrate_id]
			var source_size: Vector2 = sizes[substrate_id]
			var product_size: Vector2 = sizes[product_id]
			var x_offset := (float(i) - float(products.size() - 1) * 0.5) * (product_size.x + 70.0)
			var preferred := Vector2(source_pos.x + source_size.x * 0.5 - product_size.x * 0.5 + x_offset, source_pos.y + source_size.y + 120.0)
			_layout_positions[product_id] = _open_position(preferred, product_size, sizes)
	var gap := Vector2(90.0, 110.0)
	var row_y := 380.0
	var row_x := 96.0
	var row_height := 0.0
	for i in ids.size():
		var id := ids[i]
		var node_size: Vector2 = sizes[id]
		if not _layout_positions.has(id):
			if row_x + node_size.x > map_width - 80.0:
				row_x = 96.0
				row_y += row_height + gap.y
				row_height = 0.0
			_layout_positions[id] = _open_position(Vector2(row_x, row_y), node_size, sizes)
			row_x += node_size.x + gap.x
			row_height = maxf(row_height, node_size.y)
		result[id] = {"position": _layout_positions[id], "size": node_size}
	return result

func _open_position(preferred: Vector2, node_size: Vector2, sizes: Dictionary) -> Vector2:
	var gap := Vector2(84.0, 104.0)
	var candidate := preferred
	for attempt in 18:
		if not _overlaps_existing(candidate, node_size, sizes):
			return candidate
		candidate = preferred + Vector2((attempt % 3 - 1) * (node_size.x + gap.x), (attempt / 3 + 1) * (node_size.y + gap.y))
	return candidate

func _overlaps_existing(pos: Vector2, node_size: Vector2, sizes: Dictionary) -> bool:
	var rect := Rect2(pos, node_size).grow(34.0)
	for id in _layout_positions.keys():
		if not sizes.has(id):
			continue
		var other := Rect2(_layout_positions[id], sizes[id]).grow(34.0)
		if rect.intersects(other):
			return true
	return false

func _molecule_canvas_size(molecule: Dictionary, zoom: float) -> Vector2:
	var atoms: Array = molecule.get("atoms", [])
	if atoms.is_empty():
		return Vector2(180, 140)
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for atom in atoms:
		var pos: Vector2 = atom.get("pos", Vector2.ZERO)
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
	var graph_size := (max_pos - min_pos).max(Vector2(80.0, 80.0))
	return graph_size * zoom + Vector2(88.0, 116.0)

func _map_molecule_node(id: String, pos: Vector2, node_size: Vector2) -> Control:
	var box := Control.new()
	box.position = pos
	box.custom_minimum_size = node_size
	box.size = node_size
	if simulation.selected_molecule == id:
		var highlight := SelectionHighlight.new()
		highlight.position = Vector2(-12, -12)
		highlight.custom_minimum_size = node_size + Vector2(24, 24)
		highlight.size = node_size + Vector2(24, 24)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(highlight)
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(node_size.x, maxf(90.0, node_size.y - 48.0))
	canvas.size = canvas.custom_minimum_size
	canvas.scale_to_fit = false
	canvas.fixed_zoom = _fixed_zoom
	canvas.set_molecule(simulation.molecule_types[id])
	if float(simulation.molecule_amounts.get(id, 0.0)) <= 0.001:
		canvas.modulate = Color(1, 1, 1, 0.48)
	var pressed_on_molecule := false
	canvas.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressed_on_molecule = true
			elif pressed_on_molecule and _drag_distance <= 6.0:
				pressed_on_molecule = false
				emit_signal("molecule_requested", id)
			elif not event.pressed:
				pressed_on_molecule = false
	)
	box.add_child(canvas)
	var label := Button.new()
	label.position = Vector2(0, canvas.custom_minimum_size.y)
	label.size = Vector2(node_size.x, 42.0)
	label.custom_minimum_size = label.size
	label.text = "%s  %.0f" % [simulation.molecule_types[id].get("formula", ""), float(simulation.molecule_amounts.get(id, 0.0))]
	if float(simulation.molecule_amounts.get(id, 0.0)) <= 0.001:
		label.text = "%s  preview" % simulation.molecule_types[id].get("formula", "")
	label.pressed.connect(func():
		if _drag_distance <= 6.0:
			emit_signal("molecule_requested", id)
	)
	box.add_child(label)
	return box

class SelectionHighlight:
	extends Control

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("10292d"), true)
		draw_rect(rect, Color("8cff6a"), false, 4.0)
		draw_rect(rect.grow(-5.0), Color("76f4ff"), false, 1.5)

class ArrowLine:
	extends Control

	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var label := ""
	var rate := 0.0
	var active := false
	var queued := false

	func _draw() -> void:
		var delta := end - start
		if delta.length() < 8.0:
			return
		var dir := delta.normalized()
		var normal := Vector2(-dir.y, dir.x)
		var from := start + dir * 90.0
		var to := end - dir * 90.0
		var line_color := Color("f4fbff")
		if active:
			line_color = Color("8cff6a")
		elif queued:
			line_color = Color("76f4ff")
		else:
			line_color = Color("8aa1a7")
		draw_line(from, to, Color("02070b"), 9.0, true)
		draw_line(from, to, line_color, 4.0, true)
		var left := to - dir * 18.0 + normal * 9.0
		var right := to - dir * 18.0 - normal * 9.0
		draw_colored_polygon(PackedVector2Array([to, left, right]), line_color)
		draw_string(ThemeDB.fallback_font, from.lerp(to, 0.5) + Vector2(8, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, line_color)
