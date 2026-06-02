extends Control
class_name MetabolismWorkspace

signal molecule_requested(molecule_id: String)
signal empty_requested
signal pathway_requested(blueprint_id: String)

const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")
const WORLD_BOUNDS := Rect2(Vector2(-1500.0, 22.0), Vector2(4200.0, 3200.0))
const EDGE_VISIBLE_MARGIN := Vector2(96.0, 120.0)

var simulation
var selected_pathway := ""
var pan_offset := Vector2.ZERO
var zoom := 1.0
var _dragging := false
var _last_mouse := Vector2.ZERO
var _drag_distance := 0.0
var _fixed_zoom := 0.46
var _layout_positions := {}
var _visible_positions := {}
var _visible_sizes := {}
var _visible_reaction_steps := {}
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
				var pathway_id := _pathway_at(event.position - global_position)
				if not pathway_id.is_empty():
					emit_signal("pathway_requested", pathway_id)
				elif molecule_id.is_empty():
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
	var step_layout := _reaction_step_layout(positions, sizes)
	_visible_positions = positions
	_visible_sizes = sizes
	_visible_reaction_steps = step_layout
	_draw_membrane_transport_arrows(positions, sizes)
	_draw_reaction_arrows(positions, sizes, step_layout)
	for key in step_layout.keys():
		add_child(_reaction_step_node(step_layout[key]))
	for id in ids:
		add_child(_map_molecule_node(id, positions[id], sizes[id]))

func _molecule_at(local_position: Vector2) -> String:
	for id in _visible_positions.keys():
		var rect := Rect2(_visible_positions[id], _visible_sizes[id])
		if rect.has_point(local_position):
			return id
	return ""

func _pathway_at(local_position: Vector2) -> String:
	for id in _visible_reaction_steps.keys():
		var item: Dictionary = _visible_reaction_steps[id]
		var rect: Rect2 = item.get("rect", Rect2())
		if rect.has_point(local_position):
			return id
	return ""

func _draw_reaction_arrows(positions: Dictionary, sizes: Dictionary, step_layout: Dictionary) -> void:
	for reaction in simulation.pathway_arrows():
		var step_key: String = reaction.get("blueprint_id", "")
		var substrate: String = reaction.get("substrate", "")
		var products: Array = reaction.get("products", [])
		if not positions.has(substrate):
			continue
		var source_center: Vector2 = positions[substrate] + sizes[substrate] * 0.5
		var source_bottom: Vector2 = positions[substrate] + Vector2(sizes[substrate].x * 0.5, sizes[substrate].y)
		var step_rect: Rect2 = step_layout.get(step_key, {}).get("rect", Rect2())
		var step_center := step_rect.get_center()
		if step_rect.size.x > 0.0:
			var enzyme_arrow := RoutedArrowLine.new()
			var step_top := Vector2(step_center.x, step_rect.position.y)
			enzyme_arrow.points = [source_bottom, step_top]
			enzyme_arrow.rate = float(reaction.get("rate", 0.0))
			enzyme_arrow.active = int(reaction.get("active_count", 0)) > 0
			enzyme_arrow.queued = int(reaction.get("queued_count", 0)) > 0
			enzyme_arrow.label = _arrow_label(reaction)
			enzyme_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(enzyme_arrow)
		var product_index := 0
		var visible_product_count := 0
		for product_id in products:
			if positions.has(product_id):
				visible_product_count += 1
		for product_id in products:
			if not positions.has(product_id):
				continue
			var target_top: Vector2 = positions[product_id] + Vector2(sizes[product_id].x * 0.5, 0.0)
			var arrow := RoutedArrowLine.new()
			if step_rect.size.x > 0.0:
				var lane_offset := (float(product_index) - float(visible_product_count - 1) * 0.5) * minf(44.0 * zoom, step_rect.size.x * 0.26)
				var start := Vector2(step_center.x + lane_offset, step_rect.end.y)
				var split_y := start.y + maxf(36.0 * zoom, minf(92.0 * zoom, (target_top.y - start.y) * 0.42))
				arrow.points = [
					start,
					Vector2(start.x, split_y),
					Vector2(target_top.x, split_y),
					target_top
				]
			else:
				arrow.points = [source_bottom, target_top]
			arrow.rate = float(reaction.get("rate", 0.0))
			arrow.active = int(reaction.get("active_count", 0)) > 0
			arrow.queued = int(reaction.get("queued_count", 0)) > 0
			arrow.label = ""
			arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(arrow)
			product_index += 1

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

func _reaction_step_layout(positions: Dictionary, sizes: Dictionary) -> Dictionary:
	var layout := {}
	for reaction in simulation.pathway_arrows():
		var blueprint_id: String = reaction.get("blueprint_id", "")
		var substrate: String = reaction.get("substrate", "")
		var products: Array = reaction.get("products", [])
		if blueprint_id.is_empty() or not positions.has(substrate) or products.is_empty():
			continue
		var valid_products: Array[Vector2] = []
		for product_id in products:
			if positions.has(product_id):
				valid_products.append(positions[product_id] + sizes[product_id] * 0.5)
		if valid_products.is_empty():
			continue
		var source_rect := Rect2(positions[substrate], sizes[substrate])
		var target_top := INF
		for center in valid_products:
			target_top = minf(target_top, center.y)
		var step_size := Vector2(210.0, 112.0) * zoom
		var center_x := source_rect.get_center().x
		var upper_y := source_rect.end.y + 56.0 * zoom
		var lower_y := target_top - 70.0 * zoom
		var center_y := (upper_y + lower_y) * 0.5
		if lower_y < upper_y:
			center_y = source_rect.end.y + 96.0 * zoom
		var center := Vector2(center_x, center_y)
		layout[blueprint_id] = {
			"rect": Rect2(center - step_size * 0.5, step_size),
			"reaction": reaction
		}
	return layout

func _reaction_step_node(item: Dictionary) -> Control:
	var reaction: Dictionary = item.get("reaction", {})
	var rect: Rect2 = item.get("rect", Rect2())
	var box := EnzymeStepBox.new()
	box.simulation = simulation
	box.reaction = reaction
	box.fixed_zoom = _fixed_zoom * zoom * 0.86
	box.selected = selected_pathway == str(reaction.get("blueprint_id", ""))
	box.position = rect.position
	box.size = rect.size
	box.custom_minimum_size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

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
		var placed_products: Array[String] = []
		for product_id in products:
			if sizes.has(product_id) and product_id != first_id:
				placed_products.append(product_id)
		if placed_products.is_empty():
			continue
		var source_pos: Vector2 = _layout_positions[substrate_id]
		var source_size: Vector2 = sizes[substrate_id]
		var group_gap := 86.0
		var group_width := -group_gap
		for product_id in placed_products:
			var product_size: Vector2 = sizes[product_id]
			group_width += product_size.x + group_gap
		var cursor_x := source_pos.x + source_size.x * 0.5 - group_width * 0.5
		for product_id in placed_products:
			var product_size: Vector2 = sizes[product_id]
			var preferred := Vector2(cursor_x, source_pos.y + source_size.y + 260.0)
			var opened := _open_position(preferred, product_size, sizes, false, product_id)
			if opened.y > preferred.y + product_size.y * 0.5:
				opened = _open_position(preferred + Vector2(0.0, product_size.y + 116.0), product_size, sizes, false, product_id)
			if opened.y < preferred.y:
				opened.y = preferred.y
			_layout_positions[product_id] = opened
			cursor_x += product_size.x + group_gap
	var gap := Vector2(72.0, 86.0)
	var row_y := 320.0
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

func _open_position(preferred: Vector2, node_size: Vector2, sizes: Dictionary, allow_side_shift: bool = true, ignore_id: String = "") -> Vector2:
	var gap := Vector2(84.0, 104.0)
	var candidate := preferred
	for attempt in 18:
		if not _overlaps_existing(candidate, node_size, sizes, ignore_id):
			return candidate
		var side_shift := (attempt % 3 - 1) * (node_size.x + gap.x) if allow_side_shift else 0.0
		candidate = preferred + Vector2(side_shift, (attempt / 3 + 1) * (node_size.y + gap.y))
	return candidate

func _overlaps_existing(pos: Vector2, node_size: Vector2, sizes: Dictionary, ignore_id: String = "") -> bool:
	var rect := Rect2(pos, node_size).grow(34.0)
	for id in _layout_positions.keys():
		if str(id) == ignore_id:
			continue
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
	return graph_size * zoom + Vector2(54.0, 72.0)

func _map_molecule_node(id: String, pos: Vector2, node_size: Vector2) -> Control:
	var box := Control.new()
	box.position = pos
	box.custom_minimum_size = node_size
	box.size = node_size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(node_size.x, maxf(62.0, node_size.y - 34.0))
	canvas.size = canvas.custom_minimum_size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.scale_to_fit = false
	canvas.fixed_zoom = _fixed_zoom * zoom
	canvas.atom_scale = 0.68
	canvas.bond_scale = 0.62
	canvas.selection_glow = simulation.selected_molecule == id
	canvas.set_molecule(simulation.molecule_types[id])
	if float(simulation.molecule_amounts.get(id, 0.0)) <= 0.001:
		canvas.modulate = Color(1, 1, 1, 0.48)
	box.add_child(canvas)
	var label := Button.new()
	label.position = Vector2(0, canvas.custom_minimum_size.y)
	label.size = Vector2(node_size.x, 30.0)
	label.custom_minimum_size = label.size
	label.scale = Vector2.ONE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
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
		var from := start + dir * 56.0
		var to := end - dir * 56.0
		var line_color := Color("f4fbff")
		if active:
			line_color = Color("8cff6a")
		elif queued:
			line_color = Color("76f4ff")
		else:
			line_color = Color("8aa1a7")
		draw_line(from, to, Color("02070b"), 7.0, true)
		draw_line(from, to, line_color, 3.0, true)
		var left := to - dir * 14.0 + normal * 7.0
		var right := to - dir * 14.0 - normal * 7.0
		draw_colored_polygon(PackedVector2Array([to, left, right]), line_color)
		if not label.is_empty():
			draw_string(ThemeDB.fallback_font, from.lerp(to, 0.5) + Vector2(7, -7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, line_color)

class RoutedArrowLine:
	extends Control

	var points: Array[Vector2] = []
	var label := ""
	var rate := 0.0
	var active := false
	var queued := false

	func _draw() -> void:
		if points.size() < 2:
			return
		var line_color := Color("f4fbff")
		if active:
			line_color = Color("8cff6a")
		elif queued:
			line_color = Color("76f4ff")
		else:
			line_color = Color("8aa1a7")
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			if a.distance_to(b) < 4.0:
				continue
			draw_line(a, b, Color("02070b"), 7.0, true)
			draw_line(a, b, line_color, 3.0, true)
		var end: Vector2 = points[points.size() - 1]
		var previous: Vector2 = points[points.size() - 2]
		var dir := (end - previous).normalized()
		if dir.length() <= 0.0:
			return
		var normal := Vector2(-dir.y, dir.x)
		var left := end - dir * 14.0 + normal * 7.0
		var right := end - dir * 14.0 - normal * 7.0
		draw_colored_polygon(PackedVector2Array([end, left, right]), line_color)
		if not label.is_empty():
			var label_pos: Vector2 = points[0].lerp(points[1], 0.55) + Vector2(7, -7)
			draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, line_color)

class EnzymeStepBox:
	extends Control

	var simulation
	var reaction: Dictionary = {}
	var fixed_zoom := 0.52
	var selected := false

	func _ready() -> void:
		set_process(true)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size).grow(-4.0)
		var cyan := Color("8cff6a") if selected else Color("76f4ff")
		draw_rect(rect, Color(0.08, 0.16, 0.20, 0.86), true)
		draw_rect(rect, Color(cyan.r, cyan.g, cyan.b, 0.28 if selected else 0.20), false, 12.0 if selected else 9.0)
		draw_rect(rect, cyan, false, 3.0 if selected else 2.0)
		if simulation == null:
			return
		var substrate_id: String = reaction.get("substrate", "")
		if not simulation.molecule_types.has(substrate_id):
			return
		var molecule: Dictionary = simulation.molecule_types[substrate_id]
		var transform := _molecule_transform(molecule)
		var target_index := _reaction_target_index()
		var tool := str(reaction.get("tool", ""))
		if tool == "lyase" and target_index >= 0:
			_draw_lyase_cycle(molecule, transform, target_index, rect)
		else:
			_draw_molecule(molecule, transform)
			_draw_enzyme_cycle_overlay(molecule, transform, target_index, rect, tool)
		_draw_step_label(rect)

	func _molecule_transform(molecule: Dictionary) -> Transform2D:
		var atoms: Array = molecule.get("atoms", [])
		var min_pos := Vector2(INF, INF)
		var max_pos := Vector2(-INF, -INF)
		for atom in atoms:
			var pos: Vector2 = atom.get("pos", Vector2.ZERO)
			min_pos = min_pos.min(pos)
			max_pos = max_pos.max(pos)
		var graph_size := (max_pos - min_pos).max(Vector2(80.0, 80.0))
		var scale := minf(size.x * 0.62 / graph_size.x, size.y * 0.66 / graph_size.y)
		scale = minf(scale, fixed_zoom)
		var graph_center := (min_pos + max_pos) * 0.5
		var center := Vector2(size.x * 0.50, size.y * 0.40)
		return Transform2D(Vector2(scale, 0.0), Vector2(0.0, scale), center - graph_center * scale)

	func _product_transform(product: Dictionary, origin: Vector2, product_scale: float) -> Transform2D:
		var atoms: Array = product.get("atoms", [])
		var min_pos := Vector2(INF, INF)
		var max_pos := Vector2(-INF, -INF)
		for atom in atoms:
			var pos: Vector2 = atom.get("pos", Vector2.ZERO)
			min_pos = min_pos.min(pos)
			max_pos = max_pos.max(pos)
		var graph_center := (min_pos + max_pos) * 0.5
		return Transform2D(Vector2(product_scale, 0.0), Vector2(0.0, product_scale), origin - graph_center * product_scale)

	func _draw_molecule(molecule: Dictionary, transform: Transform2D) -> void:
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		for bond in bonds:
			var a_index := int(bond.get("a", 0))
			var b_index := int(bond.get("b", 0))
			if a_index >= atoms.size() or b_index >= atoms.size():
				continue
			var a: Vector2 = transform * atoms[a_index].get("pos", Vector2.ZERO)
			var b: Vector2 = transform * atoms[b_index].get("pos", Vector2.ZERO)
			_draw_step_bond(a, b, int(bond.get("order", 1)), 1.0)
		for atom in atoms:
			var pos: Vector2 = transform * atom.get("pos", Vector2.ZERO)
			_draw_step_atom(pos, str(atom.get("element", "C")))

	func _draw_breaking_bond(molecule: Dictionary, transform: Transform2D, target_index: int) -> void:
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		if target_index >= bonds.size():
			return
		var bond: Dictionary = bonds[target_index]
		var a_index := int(bond.get("a", 0))
		var b_index := int(bond.get("b", 0))
		if a_index >= atoms.size() or b_index >= atoms.size():
			return
		var a: Vector2 = transform * atoms[a_index].get("pos", Vector2.ZERO)
		var b: Vector2 = transform * atoms[b_index].get("pos", Vector2.ZERO)
		var intensity := smoothstep(0.15, 0.95, abs(sin(Time.get_ticks_msec() * 0.0032)))
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var center := a.lerp(b, 0.5)
		var gap := 7.0 + 13.0 * intensity
		_draw_step_bond(a, center - dir * gap, int(bond.get("order", 1)), 0.55 + 0.45 * intensity, Color("ffe064"))
		_draw_step_bond(center + dir * gap, b, int(bond.get("order", 1)), 0.55 + 0.45 * intensity, Color("ffe064"))
		var sparks := PackedVector2Array()
		for i in 7:
			var p := center + dir * lerpf(-gap, gap, float(i) / 6.0)
			var wave := sin(float(i) * 2.2 + Time.get_ticks_msec() * 0.011) * 9.0 * intensity
			sparks.append(p + normal * wave)
		draw_polyline(sparks, Color("76f4ff"), 5.0 * intensity, true)
		draw_polyline(sparks, Color("fff1a8"), maxf(1.0, 2.0 * intensity), true)

	func _draw_lyase_cycle(molecule: Dictionary, transform: Transform2D, target_index: int, rect: Rect2) -> void:
		var cycle := fmod(Time.get_ticks_msec() * 0.00036, 1.0)
		var break_amount := smoothstep(0.18, 0.50, cycle) * (1.0 - smoothstep(0.72, 0.90, cycle))
		var alpha := 1.0 - smoothstep(0.72, 0.90, cycle)
		if cycle > 0.90:
			alpha = smoothstep(0.90, 0.99, cycle)
			break_amount = 0.0
		_draw_molecule_fragment_stage(molecule, transform, target_index, break_amount, alpha)
		var bond_center := _bond_screen_center(molecule, transform, target_index)
		if bond_center != Vector2(INF, INF):
			var scissors_alpha := smoothstep(0.08, 0.20, cycle) * (1.0 - smoothstep(0.58, 0.76, cycle))
			var scissors_drop := Vector2(0.0, lerpf(-6.0, 3.0, smoothstep(0.10, 0.46, cycle)))
			_draw_scissors_alpha(bond_center + Vector2(24.0, -14.0) + scissors_drop, minf(rect.size.x, rect.size.y) / 142.0, scissors_alpha)

	func _draw_molecule_fragment_stage(molecule: Dictionary, transform: Transform2D, target_index: int, break_amount: float, alpha: float) -> void:
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		var components := _split_components(molecule, target_index)
		var offsets: Array[Vector2] = []
		offsets.resize(atoms.size())
		for atom_index in atoms.size():
			offsets[atom_index] = Vector2.ZERO
		if components.size() >= 2:
			var bond: Dictionary = bonds[target_index]
			var a_index := int(bond.get("a", 0))
			var b_index := int(bond.get("b", 0))
			var a_pos: Vector2 = transform * atoms[a_index].get("pos", Vector2.ZERO)
			var b_pos: Vector2 = transform * atoms[b_index].get("pos", Vector2.ZERO)
			var split_dir := (b_pos - a_pos).normalized()
			if split_dir.length() <= 0.0:
				split_dir = Vector2.RIGHT
			for component_index in components.size():
				var component: Array = components[component_index]
				var side := -1.0 if component.has(a_index) else 1.0
				var drift := split_dir * side * 40.0 * break_amount
				for atom_index in component:
					offsets[int(atom_index)] = drift
		for i in bonds.size():
			var bond: Dictionary = bonds[i]
			var a_index := int(bond.get("a", 0))
			var b_index := int(bond.get("b", 0))
			if a_index >= atoms.size() or b_index >= atoms.size():
				continue
			if i == target_index and break_amount > 0.03:
				continue
			var a: Vector2 = transform * atoms[a_index].get("pos", Vector2.ZERO) + offsets[a_index]
			var b: Vector2 = transform * atoms[b_index].get("pos", Vector2.ZERO) + offsets[b_index]
			var color := Color("ffe064") if i == target_index and break_amount > 0.0 else Color.TRANSPARENT
			_draw_step_bond(a, b, int(bond.get("order", 1)), alpha * (1.0 - break_amount * 0.8 if i == target_index else 1.0), color)
		for atom_index in atoms.size():
			var atom: Dictionary = atoms[atom_index]
			var pos: Vector2 = transform * atom.get("pos", Vector2.ZERO) + offsets[atom_index]
			_draw_step_atom_alpha(pos, str(atom.get("element", "C")), alpha)

	func _split_components(molecule: Dictionary, skipped_bond_index: int) -> Array:
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		var adjacency := []
		for i in atoms.size():
			adjacency.append([])
		for i in bonds.size():
			if i == skipped_bond_index:
				continue
			var bond: Dictionary = bonds[i]
			var a := int(bond.get("a", 0))
			var b := int(bond.get("b", 0))
			if a >= atoms.size() or b >= atoms.size():
				continue
			adjacency[a].append(b)
			adjacency[b].append(a)
		var visited := {}
		var components := []
		for start in atoms.size():
			if visited.has(start):
				continue
			var component := []
			var stack := [start]
			visited[start] = true
			while not stack.is_empty():
				var current: int = stack.pop_back()
				component.append(current)
				for neighbor in adjacency[current]:
					if not visited.has(neighbor):
						visited[neighbor] = true
						stack.append(neighbor)
			components.append(component)
		return components

	func _bond_screen_center(molecule: Dictionary, transform: Transform2D, target_index: int) -> Vector2:
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		if target_index >= bonds.size():
			return Vector2(INF, INF)
		var bond: Dictionary = bonds[target_index]
		var a_index := int(bond.get("a", 0))
		var b_index := int(bond.get("b", 0))
		if a_index >= atoms.size() or b_index >= atoms.size():
			return Vector2(INF, INF)
		var a: Vector2 = transform * atoms[a_index].get("pos", Vector2.ZERO)
		var b: Vector2 = transform * atoms[b_index].get("pos", Vector2.ZERO)
		return a.lerp(b, 0.5)

	func _draw_reaction_pulse(rect: Rect2) -> void:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		draw_circle(rect.get_center(), 24.0 + 20.0 * pulse, Color(0.45, 0.95, 1.0, 0.10 * (1.0 - pulse)))

	func _draw_enzyme_cycle_overlay(molecule: Dictionary, transform: Transform2D, target_index: int, rect: Rect2, tool: String) -> void:
		var cycle := fmod(Time.get_ticks_msec() * 0.00048, 1.0)
		var phase := smoothstep(0.12, 0.72, cycle) * (1.0 - smoothstep(0.82, 0.98, cycle))
		var bond := _target_bond_points(molecule, transform, target_index)
		if bond.is_empty():
			_draw_reaction_pulse(rect)
			return
		var a: Vector2 = bond.get("a", rect.get_center())
		var b: Vector2 = bond.get("b", rect.get_center())
		var center: Vector2 = a.lerp(b, 0.5)
		var dir := (b - a).normalized()
		if dir.length() <= 0.0:
			dir = Vector2.RIGHT
		var normal := Vector2(-dir.y, dir.x)
		match tool:
			"reductase":
				_draw_reductase_effect(a, b, center, normal, phase, cycle)
			"dehydrogenase":
				_draw_dehydrogenase_effect(a, b, center, normal, phase, cycle)
			"oxygenase":
				_draw_add_atom_effect(molecule, transform, target_index, "O", Color("e95058"), phase, cycle)
			"decarboxylase":
				_draw_decarboxylase_effect(molecule, transform, target_index, phase, cycle)
			"aminase":
				_draw_add_atom_effect(molecule, transform, target_index, "N", Color("4a90df"), phase, cycle)
			"desaturase":
				_draw_desaturase_effect(a, b, center, normal, phase, cycle)
			_:
				_draw_reaction_pulse(rect)

	func _draw_reductase_effect(a: Vector2, b: Vector2, center: Vector2, normal: Vector2, phase: float, cycle: float) -> void:
		var nad_pos := center + Vector2(-58.0, -34.0).lerp(Vector2(0.0, 0.0), phase)
		_draw_resource_bead(nad_pos, "NADH", Color("76f4ff"), 1.0 - smoothstep(0.64, 0.92, cycle))
		var intensity := 0.28 + 0.72 * phase
		_draw_step_bond(a, b, 1, intensity, Color("8cff6a"))
		draw_line(center - normal * 18.0, center + normal * 18.0, Color(0.55, 1.0, 0.42, 0.36 * phase), 3.0, true)

	func _draw_dehydrogenase_effect(a: Vector2, b: Vector2, center: Vector2, normal: Vector2, phase: float, cycle: float) -> void:
		var nad_pos := center.lerp(center + Vector2(56.0, -38.0), phase)
		_draw_resource_bead(nad_pos, "+NADH", Color("76f4ff"), smoothstep(0.22, 0.72, cycle))
		_draw_step_bond(a, b, 2, 0.35 + 0.65 * phase, Color("ffe064"))
		_draw_spark_line(center - normal * 17.0, center + normal * 17.0, normal, phase, Color("ffe064"))

	func _draw_desaturase_effect(a: Vector2, b: Vector2, center: Vector2, normal: Vector2, phase: float, cycle: float) -> void:
		_draw_step_bond(a, b, 1, 0.45, Color("dbeff2"))
		var offset := normal * 4.0
		var grow_a := a.lerp(center, 1.0 - phase) + offset
		var grow_b := b.lerp(center, 1.0 - phase) + offset
		draw_line(grow_a, grow_b, Color("02070b"), 5.4, true)
		draw_line(grow_a, grow_b, Color("ffe064"), 2.4, true)
		_draw_resource_bead(center.lerp(center + Vector2(52.0, -30.0), phase), "+NADH", Color("76f4ff"), smoothstep(0.28, 0.80, cycle))

	func _draw_add_atom_effect(molecule: Dictionary, transform: Transform2D, target_index: int, element: String, color: Color, phase: float, cycle: float) -> void:
		var carbon := _target_carbon_point(molecule, transform, target_index)
		if carbon == Vector2(INF, INF):
			return
		var source := carbon + Vector2(58.0, -42.0)
		var atom_pos := source.lerp(carbon + Vector2(34.0, -22.0), phase)
		var alpha := 1.0 - smoothstep(0.84, 0.98, cycle)
		draw_line(carbon, atom_pos, Color(0.0, 0.0, 0.0, 0.75 * phase * alpha), 5.0, true)
		draw_line(carbon, atom_pos, Color(color.r, color.g, color.b, 0.92 * phase * alpha), 2.0, true)
		_draw_step_atom_alpha(atom_pos, element, alpha)
		var label := "-NADH" if element == "O" else "-N"
		draw_string(ThemeDB.fallback_font, atom_pos + Vector2(10.0, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color.lightened(0.28))

	func _draw_decarboxylase_effect(molecule: Dictionary, transform: Transform2D, target_index: int, phase: float, cycle: float) -> void:
		var carbon := _target_carboxyl_point(molecule, transform, target_index)
		if carbon == Vector2(INF, INF):
			return
		var bubble := carbon.lerp(carbon + Vector2(0.0, -58.0), phase)
		var alpha := 1.0 - smoothstep(0.72, 0.98, cycle)
		draw_circle(carbon, 22.0 + 8.0 * phase, Color(1.0, 0.88, 0.32, 0.14 * alpha))
		draw_line(carbon + Vector2(-18.0, 0.0), carbon + Vector2(18.0, 0.0), Color("ffe064"), 2.0, true)
		draw_circle(bubble, 18.0, Color(0.0, 0.0, 0.0, 0.45 * alpha))
		draw_circle(bubble, 14.0, Color(0.68, 0.88, 0.92, 0.34 * alpha))
		draw_string(ThemeDB.fallback_font, bubble + Vector2(-17.0, 5.0), "CO2", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.96, 1.0, 1.0, alpha))

	func _draw_resource_bead(pos: Vector2, text: String, color: Color, alpha: float) -> void:
		if alpha <= 0.01:
			return
		draw_circle(pos, 13.0, Color(0.0, 0.0, 0.0, 0.62 * alpha))
		draw_circle(pos, 10.0, Color(color.r, color.g, color.b, 0.86 * alpha))
		draw_circle(pos + Vector2(3.0, -4.0), 3.0, Color(1, 1, 1, 0.38 * alpha))
		draw_string(ThemeDB.fallback_font, pos + Vector2(12.0, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(color.lightened(0.32).r, color.lightened(0.32).g, color.lightened(0.32).b, alpha))

	func _draw_spark_line(a: Vector2, b: Vector2, normal: Vector2, phase: float, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 6:
			var t := float(i) / 5.0
			var wave := sin(t * TAU * 2.0 + Time.get_ticks_msec() * 0.01) * 6.0 * phase
			points.append(a.lerp(b, t) + normal * wave)
		draw_polyline(points, Color(color.r, color.g, color.b, 0.42 * phase), 4.0, true)
		draw_polyline(points, Color("f4fbff"), maxf(1.0, 1.2 * phase), true)

	func _draw_scissors(center: Vector2, scale: float) -> void:
		_draw_scissors_alpha(center, scale, 1.0)

	func _draw_scissors_alpha(center: Vector2, scale: float, alpha: float) -> void:
		if alpha <= 0.01:
			return
		var pivot := center
		var blade_a := pivot + Vector2(-28.0, 26.0) * scale
		var blade_b := pivot + Vector2(28.0, -28.0) * scale
		var blade_c := pivot + Vector2(-20.0, -4.0) * scale
		var blade_d := pivot + Vector2(34.0, 20.0) * scale
		var outline := Color(0.0, 0.0, 0.0, 0.82 * alpha)
		var metal := Color(0.96, 0.98, 1.0, alpha)
		draw_line(blade_a, blade_b, outline, 5.0 * scale, true)
		draw_line(blade_c, blade_d, outline, 5.0 * scale, true)
		draw_line(blade_a, blade_b, metal, 2.4 * scale, true)
		draw_line(blade_c, blade_d, metal, 2.4 * scale, true)
		draw_circle(pivot, 3.8 * scale, outline)
		draw_circle(pivot, 2.1 * scale, metal)
		for p in [pivot + Vector2(25.0, -30.0) * scale, pivot + Vector2(40.0, 13.0) * scale]:
			draw_arc(p, 6.5 * scale, 0.0, TAU, 24, outline, 4.0 * scale, true)
			draw_arc(p, 6.5 * scale, 0.0, TAU, 24, metal, 2.0 * scale, true)

	func _draw_step_label(rect: Rect2) -> void:
		var text := str(reaction.get("tool", "enzyme")).to_upper()
		var color := Color("8cff6a") if int(reaction.get("active_count", 0)) > 0 else Color("76f4ff")
		var status := "ACTIVE" if int(reaction.get("active_count", 0)) > 0 else ("BUILDING" if int(reaction.get("queued_count", 0)) > 0 else "DESIGNED")
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 10.0, rect.end.y - 10.0), "%s | %s" % [text, status], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)

	func _draw_step_bond(a: Vector2, b: Vector2, order: int, alpha: float, color_override: Color = Color.TRANSPARENT) -> void:
		if a.distance_to(b) < 4.0:
			return
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var color := color_override if color_override.a > 0.0 else Color("dbeff2")
		var offsets := [0.0]
		if order == 2:
			offsets = [-3.0, 3.0]
		for offset in offsets:
			var start: Vector2 = a + dir * 13.0 + normal * float(offset)
			var end: Vector2 = b - dir * 13.0 + normal * float(offset)
			draw_line(start, end, Color("02070b"), 5.4, true)
			draw_line(start, end, Color(color.r, color.g, color.b, alpha), 2.4, true)
			draw_line(start + normal * 0.6, end + normal * 0.6, Color(1, 1, 1, 0.45 * alpha), 1.0, true)

	func _draw_step_atom(pos: Vector2, element: String) -> void:
		var radius := 12.5 if element == "C" else 11.0
		var base := _atom_color(element)
		draw_circle(pos, radius + 4.0, Color("02070b"))
		draw_circle(pos, radius + 1.0, base.lightened(0.3))
		draw_circle(pos, radius - 1.0, base.darkened(0.14))
		draw_circle(pos + Vector2(radius * 0.26, -radius * 0.39), radius * 0.20, Color(1, 1, 1, 0.42))

	func _draw_molecule_with_alpha(molecule: Dictionary, transform: Transform2D, alpha: float) -> void:
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		for bond in bonds:
			var a_index := int(bond.get("a", 0))
			var b_index := int(bond.get("b", 0))
			if a_index >= atoms.size() or b_index >= atoms.size():
				continue
			var a: Vector2 = transform * atoms[a_index].get("pos", Vector2.ZERO)
			var b: Vector2 = transform * atoms[b_index].get("pos", Vector2.ZERO)
			_draw_step_bond(a, b, int(bond.get("order", 1)), alpha)
		for atom in atoms:
			var pos: Vector2 = transform * atom.get("pos", Vector2.ZERO)
			_draw_step_atom_alpha(pos, str(atom.get("element", "C")), alpha)

	func _draw_step_atom_alpha(pos: Vector2, element: String, alpha: float) -> void:
		var radius := 12.5 if element == "C" else 11.0
		var base := _atom_color(element)
		draw_circle(pos, radius + 3.0, Color(0.0, 0.0, 0.0, alpha))
		draw_circle(pos, radius + 1.0, Color(base.lightened(0.3).r, base.lightened(0.3).g, base.lightened(0.3).b, alpha))
		draw_circle(pos, radius - 1.0, Color(base.darkened(0.14).r, base.darkened(0.14).g, base.darkened(0.14).b, alpha))
		draw_circle(pos + Vector2(radius * 0.26, -radius * 0.39), radius * 0.20, Color(1, 1, 1, 0.36 * alpha))

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

	func _reaction_target_index() -> int:
		var blueprint_id: String = reaction.get("blueprint_id", "")
		if simulation != null and simulation.enzyme_blueprints.has(blueprint_id):
			return int(simulation.enzyme_blueprints[blueprint_id].get("target_index", -1))
		return -1

	func _target_bond_points(molecule: Dictionary, transform: Transform2D, target_index: int) -> Dictionary:
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		if target_index < 0 or target_index >= bonds.size():
			return {}
		var bond: Dictionary = bonds[target_index]
		var a_index := int(bond.get("a", 0))
		var b_index := int(bond.get("b", 0))
		if a_index >= atoms.size() or b_index >= atoms.size():
			return {}
		return {
			"a": transform * atoms[a_index].get("pos", Vector2.ZERO),
			"b": transform * atoms[b_index].get("pos", Vector2.ZERO),
			"a_index": a_index,
			"b_index": b_index
		}

	func _target_carbon_point(molecule: Dictionary, transform: Transform2D, target_index: int) -> Vector2:
		var atoms: Array = molecule.get("atoms", [])
		var bond := _target_bond_points(molecule, transform, target_index)
		if bond.is_empty():
			return Vector2(INF, INF)
		var a_index := int(bond.get("a_index", -1))
		var b_index := int(bond.get("b_index", -1))
		if a_index >= 0 and atoms[a_index].get("element", "") == "C":
			return bond.get("a", Vector2(INF, INF))
		if b_index >= 0 and atoms[b_index].get("element", "") == "C":
			return bond.get("b", Vector2(INF, INF))
		return Vector2(INF, INF)

	func _target_carboxyl_point(molecule: Dictionary, transform: Transform2D, target_index: int) -> Vector2:
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		var bond := _target_bond_points(molecule, transform, target_index)
		if bond.is_empty():
			return Vector2(INF, INF)
		var best_index := int(bond.get("a_index", -1))
		var best_score := -1
		for candidate in [int(bond.get("a_index", -1)), int(bond.get("b_index", -1))]:
			if candidate < 0 or candidate >= atoms.size():
				continue
			var score := 0
			for test_bond in bonds:
				var a := int(test_bond.get("a", -1))
				var b := int(test_bond.get("b", -1))
				var other := -1
				if a == candidate:
					other = b
				elif b == candidate:
					other = a
				if other >= 0 and other < atoms.size() and atoms[other].get("element", "") == "O":
					score += 1
			if score > best_score:
				best_score = score
				best_index = candidate
		if best_index == int(bond.get("b_index", -1)):
			return bond.get("b", Vector2(INF, INF))
		return bond.get("a", Vector2(INF, INF))

	func _product_molecules() -> Array[Dictionary]:
		var output: Array[Dictionary] = []
		for product_id in reaction.get("products", []):
			if simulation != null and simulation.molecule_types.has(product_id):
				output.append(simulation.molecule_types[product_id])
		return output

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
