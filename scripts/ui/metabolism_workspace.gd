extends Control
class_name MetabolismWorkspace

signal molecule_requested(molecule_id: String)
signal empty_requested

const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")
const WORLD_BOUNDS := Rect2(Vector2(-1500.0, 22.0), Vector2(4200.0, 3200.0))
const EDGE_VISIBLE_MARGIN := Vector2(96.0, 120.0)

var simulation
var pan_offset := Vector2.ZERO
var zoom := 1.0
var _dragging := false
var _last_mouse := Vector2.ZERO
var _drag_distance := 0.0
var _fixed_zoom := 0.72
var _layout_positions := {}
var _visible_positions := {}
var _visible_sizes := {}
var _press_started_in_workspace := false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture and get_global_rect().has_point(event.position):
		_zoom_at(event.factor, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and get_global_rect().has_point(event.position) and event.ctrl_pressed:
		_zoom_at(1.08, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and get_global_rect().has_point(event.position) and event.ctrl_pressed:
		_zoom_at(1.0 / 1.08, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			_dragging = true
			_drag_distance = 0.0
			_last_mouse = event.position
			_press_started_in_workspace = true
			mouse_default_cursor_shape = Control.CURSOR_MOVE
		elif not event.pressed:
			if _press_started_in_workspace and _drag_distance <= 6.0 and get_global_rect().has_point(event.position):
				var molecule_id := _molecule_at(event.position - global_position)
				if molecule_id.is_empty():
					emit_signal("empty_requested")
				else:
					emit_signal("molecule_requested", molecule_id)
			_dragging = false
			_press_started_in_workspace = false
			mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif event is InputEventMouseMotion and _dragging:
		pan_offset += event.position - _last_mouse
		_drag_distance += event.position.distance_to(_last_mouse)
		_last_mouse = event.position
		_clamp_pan()
		_rebuild()

func _zoom_at(factor: float, local_focus: Vector2) -> void:
	var previous_zoom := zoom
	zoom = clampf(zoom * factor, 0.5, 2.0)
	if is_equal_approx(previous_zoom, zoom):
		return
	var world_focus := (local_focus - pan_offset) / previous_zoom
	pan_offset = local_focus - world_focus * zoom
	_clamp_pan()
	_rebuild()

func _clamp_pan() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var min_x := size.x - (WORLD_BOUNDS.position.x + WORLD_BOUNDS.size.x) * zoom - EDGE_VISIBLE_MARGIN.x
	var max_x := -WORLD_BOUNDS.position.x * zoom + EDGE_VISIBLE_MARGIN.x
	var min_y := size.y - (WORLD_BOUNDS.position.y + WORLD_BOUNDS.size.y) * zoom - EDGE_VISIBLE_MARGIN.y
	var max_y := -WORLD_BOUNDS.position.y * zoom + EDGE_VISIBLE_MARGIN.y
	if min_x > max_x:
		pan_offset.x = (min_x + max_x) * 0.5
	else:
		pan_offset.x = clampf(pan_offset.x, min_x, max_x)
	if min_y > max_y:
		pan_offset.y = (min_y + max_y) * 0.5
	else:
		pan_offset.y = clampf(pan_offset.y, min_y, max_y)

func rebuild() -> void:
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if simulation == null:
		return
	var background := ColorRect.new()
	background.color = Color("07181c")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var boundary := BoundaryLayer.new()
	boundary.world_bounds = WORLD_BOUNDS
	boundary.pan_offset = pan_offset
	boundary.zoom = zoom
	boundary.set_anchors_preset(Control.PRESET_FULL_RECT)
	boundary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boundary)
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
		positions[id] = item["position"] * zoom + pan_offset
		sizes[id] = item["size"] * zoom
	_visible_positions = positions
	_visible_sizes = sizes
	_draw_membrane_transport_arrows(positions, sizes)
	_draw_reaction_arrows(positions, sizes)
	for id in ids:
		add_child(_map_molecule_node(id, positions[id], sizes[id]))

func _molecule_at(local_position: Vector2) -> String:
	for id in _visible_positions.keys():
		var rect := Rect2(_visible_positions[id], _visible_sizes[id])
		if rect.has_point(local_position):
			return id
	return ""

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

func _draw_membrane_transport_arrows(positions: Dictionary, sizes: Dictionary) -> void:
	for transport in simulation.membrane_transport_arrows():
		var molecule_id: String = transport.get("molecule", "")
		if not positions.has(molecule_id) or float(transport.get("rate", 0.0)) <= 0.0:
			continue
		var center: Vector2 = positions[molecule_id] + sizes[molecule_id] * 0.5
		var arrow := ArrowLine.new()
		if transport.get("direction", "") == "import":
			arrow.start = center + Vector2(0.0, -190.0 * zoom)
			arrow.end = center + Vector2(0.0, -72.0 * zoom)
			arrow.label = "membrane +%.1f/s" % float(transport.get("rate", 0.0))
			arrow.active = true
		else:
			arrow.start = center + Vector2(0.0, 72.0 * zoom)
			arrow.end = center + Vector2(0.0, 190.0 * zoom)
			arrow.label = "export %.1f/s" % float(transport.get("rate", 0.0))
			arrow.queued = true
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
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(node_size.x, maxf(90.0, node_size.y - 48.0))
	canvas.size = canvas.custom_minimum_size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.scale_to_fit = false
	canvas.fixed_zoom = _fixed_zoom * zoom
	canvas.selection_glow = simulation.selected_molecule == id
	canvas.set_molecule(simulation.molecule_types[id])
	if float(simulation.molecule_amounts.get(id, 0.0)) <= 0.001:
		canvas.modulate = Color(1, 1, 1, 0.48)
	box.add_child(canvas)
	var label := Button.new()
	label.position = Vector2(0, canvas.custom_minimum_size.y)
	label.size = Vector2(node_size.x, 42.0)
	label.custom_minimum_size = label.size
	label.scale = Vector2.ONE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "%s  %.0f" % [simulation.molecule_types[id].get("formula", ""), float(simulation.molecule_amounts.get(id, 0.0))]
	if float(simulation.molecule_amounts.get(id, 0.0)) <= 0.001:
		label.text = "%s  preview" % simulation.molecule_types[id].get("formula", "")
	box.add_child(label)
	return box

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

class BoundaryLayer:
	extends Control

	var world_bounds := Rect2()
	var pan_offset := Vector2.ZERO
	var zoom := 1.0

	func _draw() -> void:
		var rect := Rect2(world_bounds.position * zoom + pan_offset, world_bounds.size * zoom)
		draw_rect(rect, Color("10292d"), true)
		draw_rect(rect, Color("0d3a42"), false, 5.0)
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), Color("76f4ff"), 4.0, true)
		draw_line(rect.position + Vector2(0.0, 8.0), rect.position + Vector2(rect.size.x, 8.0), Color(0.55, 1.0, 0.9, 0.35), 2.0, true)
