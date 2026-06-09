extends Control
class_name MetabolismWorkspace

signal molecule_requested(molecule_id: String)
signal empty_requested
signal pathway_requested(blueprint_id: String)

const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")
const WORLD_BOUNDS := Rect2(Vector2(-1500.0, 22.0), Vector2(4200.0, 3200.0))
const EDGE_VISIBLE_MARGIN := Vector2(96.0, 120.0)
const GRID_CELL := 96.0
const MOLECULE_CARD_SIZE := Vector2(GRID_CELL * 0.90, GRID_CELL * 0.90)
const ENZYME_CARD_SIZE := Vector2(GRID_CELL * 2.0, GRID_CELL)
const GOAL_CARD_SIZE := Vector2(GRID_CELL * 1.12, GRID_CELL * 1.12)

var simulation
var selected_pathway := ""
var pan_offset := Vector2.ZERO
var zoom := 1.0
var _dragging := false
var _dragging_molecule := false
var _dragging_goal := false
var _drag_molecule_id := ""
var _drag_goal_id := ""
var _drag_grab_offset_world := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _drag_distance := 0.0
var _fixed_zoom := 0.46
var _layout_positions := {}
var _manual_positions := {}
var _visible_positions := {}
var _visible_sizes := {}
var _visible_goal_positions := {}
var _visible_goal_sizes := {}
var _visible_reaction_steps := {}
var _visible_routes: Array[Dictionary] = []
var _flux_routes: Array[Dictionary] = []
var _manual_goal_positions := {}
var _press_started_in_workspace := false
var _hover_popup: Control
var _hover_key := ""
var _hover_inside := false
var _last_hover_local := Vector2.ZERO

func _ready() -> void:
	set_process(true)
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _process(_delta: float) -> void:
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag(false)

func _input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture and get_global_rect().has_point(event.position):
		_zoom_at(event.factor, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and get_global_rect().has_point(event.position) and event.ctrl_pressed:
		_zoom_at(1.08, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and get_global_rect().has_point(event.position) and event.ctrl_pressed:
		_zoom_at(1.0 / 1.08, event.position - global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			_hide_hover_popup()
			var local_press: Vector2 = event.position - global_position
			var molecule_id := _molecule_at(local_press)
			var goal_id := _goal_at(local_press) if molecule_id.is_empty() else ""
			_dragging = true
			_dragging_molecule = not molecule_id.is_empty()
			_dragging_goal = not goal_id.is_empty()
			_drag_molecule_id = molecule_id
			_drag_goal_id = goal_id
			if _dragging_molecule and _layout_positions.has(_drag_molecule_id):
				_drag_grab_offset_world = (local_press - pan_offset) / zoom - _layout_positions[_drag_molecule_id]
			elif _dragging_goal and _manual_goal_positions.has(_drag_goal_id):
				_drag_grab_offset_world = (local_press - pan_offset) / zoom - _manual_goal_positions[_drag_goal_id]
			_drag_distance = 0.0
			_last_mouse = event.position
			_press_started_in_workspace = true
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _dragging_molecule or _dragging_goal else Control.CURSOR_MOVE
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
			_finish_drag(true)
	elif event is InputEventMouseMotion and _dragging:
		if _dragging_molecule and not _drag_molecule_id.is_empty() and _visible_sizes.has(_drag_molecule_id):
			var local: Vector2 = event.position - global_position
			var world_press: Vector2 = (local - pan_offset) / zoom
			_layout_positions[_drag_molecule_id] = world_press - _drag_grab_offset_world
			_manual_positions[_drag_molecule_id] = true
		elif _dragging_goal and not _drag_goal_id.is_empty() and _visible_goal_sizes.has(_drag_goal_id):
			var local_goal: Vector2 = event.position - global_position
			var world_goal_press: Vector2 = (local_goal - pan_offset) / zoom
			_manual_goal_positions[_drag_goal_id] = world_goal_press - _drag_grab_offset_world
		else:
			pan_offset += event.position - _last_mouse
		_drag_distance += event.position.distance_to(_last_mouse)
		_last_mouse = event.position
		_clamp_pan()
		_rebuild()
	elif event is InputEventMouseMotion and get_global_rect().has_point(event.position):
		_hover_inside = true
		_last_hover_local = event.position - global_position
		_update_hover(_last_hover_local)
	elif event is InputEventMouseMotion:
		if _hover_inside:
			_hover_inside = false
			_hide_hover_popup()

func _finish_drag(rebuild_after: bool = true) -> void:
	if not _dragging:
		return
	_dragging = false
	if _dragging_molecule and not _drag_molecule_id.is_empty() and _layout_positions.has(_drag_molecule_id):
		var size_px: Vector2 = _visible_sizes.get(_drag_molecule_id, MOLECULE_CARD_SIZE * zoom)
		_layout_positions[_drag_molecule_id] = _snap_node_to_grid(_layout_positions[_drag_molecule_id], size_px / zoom)
		_manual_positions[_drag_molecule_id] = true
		rebuild_after = true
	elif _dragging_goal and not _drag_goal_id.is_empty() and _manual_goal_positions.has(_drag_goal_id):
		var goal_size_px: Vector2 = _visible_goal_sizes.get(_drag_goal_id, GOAL_CARD_SIZE * zoom)
		_manual_goal_positions[_drag_goal_id] = _snap_node_to_grid(_manual_goal_positions[_drag_goal_id], goal_size_px / zoom)
		rebuild_after = true
	_dragging_molecule = false
	_dragging_goal = false
	_drag_molecule_id = ""
	_drag_goal_id = ""
	_drag_grab_offset_world = Vector2.ZERO
	_press_started_in_workspace = false
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	if rebuild_after:
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
	var restore_hover := _hover_inside and not _dragging and get_rect().has_point(_last_hover_local)
	_hide_hover_popup()
	for child in get_children():
		child.queue_free()
	if simulation == null:
		return
	var background := ColorRect.new()
	background.color = Color("07181c")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var board := BoundaryLayer.new()
	board.world_bounds = WORLD_BOUNDS
	board.pan_offset = pan_offset
	board.zoom = zoom
	board.grid_cell = GRID_CELL
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
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
	var goal_layout := _goal_layout()
	_visible_positions = positions
	_visible_sizes = sizes
	_visible_goal_positions = {}
	_visible_goal_sizes = {}
	for goal in goal_layout:
		var goal_id := str(goal.get("id", ""))
		var goal_rect: Rect2 = goal.get("rect", Rect2())
		_visible_goal_positions[goal_id] = goal_rect.position
		_visible_goal_sizes[goal_id] = goal_rect.size
	_visible_reaction_steps = step_layout
	_visible_routes = []
	_flux_routes = []
	_draw_membrane_transport_arrows(positions, sizes)
	_draw_reaction_arrows(positions, sizes, step_layout)
	_draw_goal_arrows(positions, sizes, goal_layout)
	_draw_flux_layer()
	for id in ids:
		add_child(_map_molecule_node(id, positions[id], sizes[id]))
	for goal in goal_layout:
		add_child(_goal_node(goal))
	var goal_panel := MetabolicGoalPanel.new()
	goal_panel.simulation = simulation
	goal_panel.position = Vector2(maxf(18.0, size.x - 336.0), 52.0)
	goal_panel.size = Vector2(318.0, 184.0)
	goal_panel.custom_minimum_size = goal_panel.size
	goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(goal_panel)
	if restore_hover:
		_update_hover(_last_hover_local)

func _molecule_at(local_position: Vector2) -> String:
	for id in _visible_positions.keys():
		var rect := Rect2(_visible_positions[id], _visible_sizes[id])
		var center := rect.get_center()
		var radius := minf(rect.size.x, rect.size.y) * 0.46
		if center.distance_to(local_position) <= radius:
			return id
	return ""

func _goal_at(local_position: Vector2) -> String:
	for id in _visible_goal_positions.keys():
		var rect := Rect2(_visible_goal_positions[id], _visible_goal_sizes[id])
		var center := rect.get_center()
		var radius := minf(rect.size.x, rect.size.y) * 0.50
		if center.distance_to(local_position) <= radius:
			return id
	return ""

func _pathway_at(local_position: Vector2) -> String:
	return ""

func _node_center(pos: Vector2, node_size: Vector2) -> Vector2:
	return pos + node_size * 0.5

func _node_radius(node_size: Vector2) -> float:
	return minf(node_size.x, node_size.y) * 0.34

func _node_port(pos: Vector2, node_size: Vector2, direction: Vector2) -> Vector2:
	var center := _node_center(pos, node_size)
	if direction.length_squared() <= 0.001:
		return center
	return center + direction.normalized() * (_node_radius(node_size) + 3.0 * zoom)

func _orthogonal_route(start: Vector2, end: Vector2, vertical_first: bool = true) -> Array[Vector2]:
	if absf(start.x - end.x) < 1.0 or absf(start.y - end.y) < 1.0:
		return [start, end]
	if vertical_first:
		return [start, Vector2(start.x, end.y), end]
	return [start, Vector2(end.x, start.y), end]

func _draw_reaction_arrows(positions: Dictionary, sizes: Dictionary, step_layout: Dictionary) -> void:
	for reaction in simulation.pathway_arrows():
		var substrate: String = reaction.get("substrate", "")
		var products: Array = reaction.get("products", [])
		if not positions.has(substrate):
			continue
		var visible_products: Array[String] = []
		for product_id in products:
			if positions.has(product_id):
				visible_products.append(str(product_id))
		if visible_products.is_empty():
			continue
		var source_center := _node_center(positions[substrate], sizes[substrate])
		var product_centers: Array[Vector2] = []
		for product_id in visible_products:
			product_centers.append(_node_center(positions[product_id], sizes[product_id]))
		var average_target := Vector2.ZERO
		for center in product_centers:
			average_target += center
		average_target /= float(product_centers.size())
		var source_dir := _primary_axis(average_target - source_center)
		var source_port := _node_port(positions[substrate], sizes[substrate], source_dir)
		for product_index in visible_products.size():
			var product_id := visible_products[product_index]
			var target_center := _node_center(positions[product_id], sizes[product_id])
			var target_dir := _primary_axis(source_center - target_center)
			var target_port := _node_port(positions[product_id], sizes[product_id], target_dir)
			var arrow := RoutedArrowLine.new()
			arrow.points = _routed_between_nodes(source_port, target_port, source_dir, target_dir, visible_products.size(), product_index)
			arrow.rate = float(reaction.get("rate", 0.0))
			arrow.active = int(reaction.get("active_count", 0)) > 0
			arrow.queued = int(reaction.get("queued_count", 0)) > 0
			arrow.label = _arrow_label(reaction) if product_index == 0 else ""
			arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(arrow)
			_register_route_hover(arrow.points, reaction)
			_register_flux_route(arrow.points, substrate, product_id, reaction)

func _primary_axis(delta: Vector2) -> Vector2:
	if absf(delta.x) > absf(delta.y):
		return Vector2.RIGHT if delta.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if delta.y >= 0.0 else Vector2.UP

func _routed_between_nodes(start: Vector2, end: Vector2, start_dir: Vector2, end_dir: Vector2, branch_count: int = 1, branch_index: int = 0) -> Array[Vector2]:
	var away_base := start + start_dir.normalized() * GRID_CELL * zoom * 0.34
	var approach_base := end + end_dir.normalized() * GRID_CELL * zoom * 0.34
	var lane_offset := (float(branch_index) - float(branch_count - 1) * 0.5) * GRID_CELL * zoom * 0.16
	var away := away_base
	var approach := approach_base
	if start_dir.y != 0.0:
		away.x += lane_offset
	else:
		away.y += lane_offset
	if end_dir.y != 0.0:
		approach.x += lane_offset
	else:
		approach.y += lane_offset
	var route: Array[Vector2] = [start, away_base, away]
	if absf(away.x - approach.x) > 1.0 and absf(away.y - approach.y) > 1.0:
		if absf(start_dir.y) > 0.0:
			route.append(Vector2(away.x, approach.y))
		else:
			route.append(Vector2(approach.x, away.y))
	route.append(approach)
	route.append(approach_base)
	route.append(end)
	return _clean_route(route)

func _clean_route(points: Array[Vector2]) -> Array[Vector2]:
	var cleaned: Array[Vector2] = []
	for point in points:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_to(point) > 1.0:
			cleaned.append(point)
	return cleaned

func _register_route_hover(points: Array[Vector2], reaction: Dictionary) -> void:
	_visible_routes.append({
		"points": points.duplicate(),
		"reaction": reaction.duplicate(true),
		"key": "reaction:%s" % str(reaction.get("blueprint_id", ""))
	})

func _register_flux_route(points: Array[Vector2], from_id: String, to_id: String, reaction: Dictionary = {}) -> void:
	if points.size() < 2:
		return
	var rate := float(reaction.get("rate", 0.0))
	var active := int(reaction.get("active_count", 0)) > 0
	if not active and rate <= 0.0:
		return
	_flux_routes.append({
		"points": points.duplicate(),
		"from_color": _molecule_pebble_color(from_id),
		"to_color": _molecule_pebble_color(to_id),
		"rate": maxf(rate, 0.18),
		"active": active
	})

func _draw_flux_layer() -> void:
	if _flux_routes.is_empty():
		return
	var layer := FluxParticleLayer.new()
	layer.routes = _flux_routes.duplicate(true)
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

func _draw_goal_arrows(positions: Dictionary, sizes: Dictionary, goal_layout: Array[Dictionary]) -> void:
	for goal in goal_layout:
		var goal_id := str(goal.get("id", ""))
		var goal_rect: Rect2 = goal.get("rect", Rect2())
		if goal_id == "amino_acids":
			for molecule_id in positions.keys():
				if simulation.has_method("is_target_molecule_id") and simulation.is_target_molecule_id(str(molecule_id)):
					var target_center := goal_rect.get_center()
					var molecule_center := _node_center(positions[molecule_id], sizes[molecule_id])
					var source: Vector2 = _node_port(positions[molecule_id], sizes[molecule_id], target_center - molecule_center)
					var target: Vector2 = _node_port(goal_rect.position, goal_rect.size, source - target_center)
					var arrow := RoutedArrowLine.new()
					var mid_x: float = source.x + maxf(76.0 * zoom, (target.x - source.x) * 0.46)
					arrow.points = [source, Vector2(mid_x, source.y), Vector2(mid_x, target.y), target]
					arrow.active = float(simulation.resources.get("Amino Acids", 0.0)) > 0.0
					arrow.label = "convert to protein points"
					arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
					add_child(arrow)
					_register_flux_route(arrow.points, str(molecule_id), str(molecule_id), {"rate": 0.65, "active_count": 1})
		elif goal_id == "dna":
			var anchor := _node_port(goal_rect.position, goal_rect.size, Vector2.LEFT)
			var hint := FutureGoalArrow.new()
			hint.start = anchor + Vector2(-150.0 * zoom, 0.0)
			hint.end = anchor
			hint.label = "future nucleotide route"
			hint.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(hint)

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
		var step_size := ENZYME_CARD_SIZE * zoom
		var center_x := source_rect.get_center().x
		var upper_y := source_rect.end.y + 56.0 * zoom
		var lower_y := target_top - 70.0 * zoom
		var center_y := (upper_y + lower_y) * 0.5
		if lower_y < upper_y:
			center_y = source_rect.end.y + 96.0 * zoom
		var center := Vector2(center_x, center_y)
		var top_left := _snap_screen_to_grid(center - step_size * 0.5)
		layout[blueprint_id] = {
			"rect": Rect2(top_left, step_size),
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
		_layout_positions[first_id] = _snap_to_grid(Vector2(map_width * 0.5 - first_size.x * 0.5, GRID_CELL * 0.75))
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
		var group_gap := GRID_CELL
		var group_width := -group_gap
		for product_id in placed_products:
			var product_size: Vector2 = sizes[product_id]
			group_width += product_size.x + group_gap
		var cursor_x := source_pos.x + source_size.x * 0.5 - group_width * 0.5
		for product_id in placed_products:
			var product_size: Vector2 = sizes[product_id]
			if _manual_positions.has(product_id):
				cursor_x += product_size.x + group_gap
				continue
			var preferred := _snap_to_grid(Vector2(cursor_x, source_pos.y + source_size.y + GRID_CELL * 2.0))
			var opened := _open_position(preferred, product_size, sizes, false, product_id)
			if opened.y > preferred.y + product_size.y * 0.5:
				opened = _open_position(preferred + Vector2(0.0, product_size.y + 116.0), product_size, sizes, false, product_id)
			if opened.y < preferred.y:
				opened.y = preferred.y
			_layout_positions[product_id] = _snap_to_grid(opened)
			cursor_x += product_size.x + group_gap
	var gap := Vector2(GRID_CELL, GRID_CELL)
	var row_y := GRID_CELL * 3.0
	var row_x := GRID_CELL
	var row_height := 0.0
	for i in ids.size():
		var id := ids[i]
		var node_size: Vector2 = sizes[id]
		if not _layout_positions.has(id):
			if row_x + node_size.x > map_width - 80.0:
				row_x = 96.0
				row_y += row_height + gap.y
				row_height = 0.0
			_layout_positions[id] = _snap_to_grid(_open_position(Vector2(row_x, row_y), node_size, sizes))
			row_x += node_size.x + gap.x
			row_height = maxf(row_height, node_size.y)
		result[id] = {"position": _layout_positions[id], "size": node_size}
	return result

func _open_position(preferred: Vector2, node_size: Vector2, sizes: Dictionary, allow_side_shift: bool = true, ignore_id: String = "") -> Vector2:
	var gap := Vector2(GRID_CELL, GRID_CELL)
	var candidate := preferred
	for attempt in 18:
		if not _overlaps_existing(candidate, node_size, sizes, ignore_id):
			return candidate
		var side_shift := (attempt % 3 - 1) * (node_size.x + gap.x) if allow_side_shift else 0.0
		candidate = preferred + Vector2(side_shift, (attempt / 3 + 1) * (node_size.y + gap.y))
	return candidate

func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x / GRID_CELL) * GRID_CELL, round(pos.y / GRID_CELL) * GRID_CELL)

func _snap_node_to_grid(pos: Vector2, node_size: Vector2) -> Vector2:
	var center := pos + node_size * 0.5
	return _snap_to_grid(center) - node_size * 0.5

func _snap_screen_to_grid(pos: Vector2) -> Vector2:
	var world := (pos - pan_offset) / zoom
	return _snap_to_grid(world) * zoom + pan_offset

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
	return MOLECULE_CARD_SIZE

func _map_molecule_node(id: String, pos: Vector2, node_size: Vector2) -> Control:
	var box := MoleculePebbleNode.new()
	box.simulation = simulation
	box.molecule_id = id
	box.selected = simulation.selected_molecule == id
	box.depleted = float(simulation.molecule_amounts.get(id, 0.0)) <= 0.001
	box.is_target = simulation.has_method("is_target_molecule_id") and simulation.is_target_molecule_id(id)
	box.pebble_color = _molecule_pebble_color(id)
	box.lifted = _dragging_molecule and _drag_molecule_id == id
	box.position = pos
	box.custom_minimum_size = node_size
	box.size = node_size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

func _update_hover(local_position: Vector2) -> void:
	var molecule_id := _molecule_at(local_position)
	if not molecule_id.is_empty():
		var key := "molecule:%s" % molecule_id
		if key != _hover_key:
			_hover_key = key
			var pos: Vector2 = _visible_positions.get(molecule_id, local_position)
			var node_size: Vector2 = _visible_sizes.get(molecule_id, Vector2(128.0, 128.0))
			_show_molecule_popup(molecule_id, pos + Vector2(node_size.x + 14.0, 8.0))
		return
	var goal_id := _goal_at(local_position)
	if not goal_id.is_empty():
		var goal_key := "goal:%s" % goal_id
		if goal_key != _hover_key:
			_hover_key = goal_key
			var goal_pos: Vector2 = _visible_goal_positions.get(goal_id, local_position)
			var goal_size: Vector2 = _visible_goal_sizes.get(goal_id, Vector2(112.0, 112.0))
			_show_goal_popup(goal_id, goal_pos + Vector2(goal_size.x + 14.0, 0.0))
		return
	var route := _reaction_route_at(local_position)
	if not route.is_empty():
		var key: String = route.get("key", "reaction")
		if key != _hover_key:
			_hover_key = key
			_show_reaction_popup(route.get("reaction", {}), local_position + Vector2(18.0, -218.0))
		return
	if not _hover_key.is_empty():
		_hide_hover_popup()

func _reaction_route_at(local_position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 14.0
	for route in _visible_routes:
		var points: Array = route.get("points", [])
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var distance := _point_segment_distance(local_position, a, b)
			if distance < best_distance:
				best_distance = distance
				best = route
	return best

func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _show_molecule_popup(id: String, screen_pos: Vector2) -> void:
	_hide_hover_popup(false)
	if simulation == null or not simulation.molecule_types.has(id):
		return
	var popup := MoleculeHoverPopup.new()
	popup.simulation = simulation
	popup.molecule_id = id
	popup.position = _clamp_popup_position(screen_pos, Vector2(280.0, 220.0))
	popup.size = Vector2(280.0, 220.0)
	popup.custom_minimum_size = popup.size
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	_hover_popup = popup

func _show_reaction_popup(reaction: Dictionary, screen_pos: Vector2) -> void:
	_hide_hover_popup(false)
	if simulation == null:
		return
	var popup := ReactionHoverPopup.new()
	popup.simulation = simulation
	popup.reaction = reaction
	popup.position = _clamp_popup_position(screen_pos, Vector2(310.0, 230.0))
	popup.size = Vector2(310.0, 230.0)
	popup.custom_minimum_size = popup.size
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	_hover_popup = popup

func _show_goal_popup(goal_id: String, screen_pos: Vector2) -> void:
	_hide_hover_popup(false)
	var popup := GoalHoverPopup.new()
	popup.goal_id = goal_id
	popup.position = _clamp_popup_position(screen_pos, Vector2(280.0, 210.0))
	popup.size = Vector2(280.0, 210.0)
	popup.custom_minimum_size = popup.size
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	_hover_popup = popup

func _hide_hover_popup(reset_key: bool = true) -> void:
	if reset_key:
		_hover_key = ""
	if _hover_popup == null:
		return
	if is_instance_valid(_hover_popup):
		_hover_popup.queue_free()
	_hover_popup = null

func _clamp_popup_position(pos: Vector2, popup_size: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, 12.0, maxf(12.0, size.x - popup_size.x - 12.0)),
		clampf(pos.y, 12.0, maxf(12.0, size.y - popup_size.y - 12.0))
	)

func _molecule_pebble_color(id: String) -> Color:
	if simulation != null and simulation.molecule_types.has(id):
		var molecule: Dictionary = simulation.molecule_types[id]
		var name := str(molecule.get("name", "")).to_lower()
		if name == "glucose":
			return Color("62d66f")
		var formula := str(molecule.get("formula", ""))
		if formula.contains("N"):
			return Color("65a7ff")
		if formula.contains("S"):
			return Color("f2d45d")
		if formula.contains("P"):
			return Color("b85ff2")
	var hue := fmod(float(abs(id.hash() % 1000)) / 1000.0 + 0.29, 1.0)
	return Color.from_hsv(hue, 0.56, 0.88)

func _goal_layout() -> Array[Dictionary]:
	var base_world := _snap_to_grid(Vector2(GRID_CELL * 2.0, WORLD_BOUNDS.position.y + WORLD_BOUNDS.size.y - GRID_CELL * 5.0))
	if not _manual_goal_positions.has("amino_acids"):
		_manual_goal_positions["amino_acids"] = base_world
	if not _manual_goal_positions.has("dna"):
		_manual_goal_positions["dna"] = base_world + Vector2(GRID_CELL * 3.0, 0.0)
	var size_px := GOAL_CARD_SIZE * zoom
	return [
		{
			"id": "amino_acids",
			"title": "AMINO ACID SINK",
			"subtitle": "N-C-COOH -> protein points",
			"color": Color("8cff6a"),
			"rect": Rect2(Vector2(_manual_goal_positions["amino_acids"]) * zoom + pan_offset, size_px)
		},
		{
			"id": "dna",
			"title": "DNA POINT SINK",
			"subtitle": "5C ring + N + P route",
			"color": Color("76f4ff"),
			"rect": Rect2(Vector2(_manual_goal_positions["dna"]) * zoom + pan_offset, size_px)
		}
	]

func _goal_node(goal: Dictionary) -> Control:
	var node := GoalSinkNode.new()
	node.goal = goal
	node.lifted = _dragging_goal and _drag_goal_id == str(goal.get("id", ""))
	var rect: Rect2 = goal.get("rect", Rect2())
	node.position = rect.position
	node.size = rect.size
	node.custom_minimum_size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

class MetabolicGoalPanel:
	extends Control

	var simulation

	func _ready() -> void:
		set_process(true)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var border := Color("76f4ff")
		draw_rect(rect.grow(4.0), Color(border.r, border.g, border.b, 0.07), true)
		draw_rect(rect, Color(0.04, 0.10, 0.13, 0.88), true)
		draw_rect(rect, Color(border.r, border.g, border.b, 0.24), false, 8.0)
		draw_rect(rect, border, false, 1.6)
		draw_string(ThemeDB.fallback_font, Vector2(14.0, 28.0), "METABOLIC GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, border)
		draw_string(ThemeDB.fallback_font, Vector2(14.0, 52.0), "Make N-C-COOH, then convert it to amino acids.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dbeff2"))
		_draw_target_molecule(Vector2(58.0, 94.0))
		draw_string(ThemeDB.fallback_font, Vector2(134.0, 88.0), "TARGET", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8cff6a"))
		draw_string(ThemeDB.fallback_font, Vector2(134.0, 108.0), "N-C-COOH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f4fbff"))
		if simulation == null:
			return
		var redox: Dictionary = simulation.redox_balance() if simulation.has_method("redox_balance") else {"net": 0.0, "production": 0.0, "consumption": 0.0}
		var y := 136.0
		_draw_resource_line(Vector2(14.0, y), "ATP", float(simulation.resources.get("ATP", 0.0)), Color("ffe064"))
		_draw_resource_line(Vector2(110.0, y), "AA", float(simulation.resources.get("Amino Acids", 0.0)), Color("8cff6a"))
		_draw_resource_line(Vector2(206.0, y), "N", float(simulation.resources.get("N", 0.0)), Color("4a90df"))
		var net := float(redox.get("net", 0.0))
		var redox_color := Color("8cff6a") if absf(net) < 0.05 else Color("ffe064")
		var redox_text := "NADH %.1f  net %+.2f/s" % [float(simulation.resources.get("NADH", 0.0)), net]
		draw_string(ThemeDB.fallback_font, Vector2(14.0, 170.0), redox_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, redox_color)

	func _draw_resource_line(pos: Vector2, label: String, value: float, color: Color) -> void:
		draw_circle(pos + Vector2(8.0, -4.0), 7.5, Color("02070b"))
		draw_circle(pos + Vector2(8.0, -4.0), 5.6, color)
		draw_string(ThemeDB.fallback_font, pos + Vector2(18.0, 0.0), "%s %.0f" % [label, value], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f4fbff"))

	func _draw_target_molecule(origin: Vector2) -> void:
		var atoms := [
			{"element": "N", "pos": origin + Vector2(-40.0, 0.0)},
			{"element": "C", "pos": origin + Vector2(0.0, 0.0)},
			{"element": "C", "pos": origin + Vector2(42.0, 0.0)},
			{"element": "O", "pos": origin + Vector2(76.0, -24.0)},
			{"element": "O", "pos": origin + Vector2(78.0, 24.0)}
		]
		_draw_panel_bond(atoms[0]["pos"], atoms[1]["pos"], 1)
		_draw_panel_bond(atoms[1]["pos"], atoms[2]["pos"], 1)
		_draw_panel_bond(atoms[2]["pos"], atoms[3]["pos"], 2)
		_draw_panel_bond(atoms[2]["pos"], atoms[4]["pos"], 1)
		for atom in atoms:
			_draw_panel_atom(atom["pos"], str(atom["element"]))

	func _draw_panel_bond(a: Vector2, b: Vector2, order: int) -> void:
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var offsets := [0.0] if order == 1 else [-2.5, 2.5]
		for offset in offsets:
			var start := a + dir * 12.0 + normal * float(offset)
			var end := b - dir * 12.0 + normal * float(offset)
			draw_line(start, end, Color("02070b"), 6.0, true)
			draw_line(start, end, Color("dbeff2"), 2.4, true)

	func _draw_panel_atom(pos: Vector2, element: String) -> void:
		var radius := 13.0 if element == "C" else 12.0
		var base := _atom_color(element)
		draw_circle(pos, radius + 4.0, Color("02070b"))
		draw_circle(pos, radius + 1.0, base.lightened(0.30))
		draw_circle(pos, radius - 1.0, base.darkened(0.14))
		draw_circle(pos + Vector2(radius * 0.25, -radius * 0.36), radius * 0.20, Color(1, 1, 1, 0.42))

	func _atom_color(element: String) -> Color:
		if element == "O":
			return Color("e95058")
		if element == "N":
			return Color("4a90df")
		return Color("68777a")

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

class FluxParticleLayer:
	extends Control

	var routes: Array[Dictionary] = []

	func _ready() -> void:
		set_process(true)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var now := Time.get_ticks_msec() / 1000.0
		var drawn := 0
		for route_index in routes.size():
			if drawn >= 220:
				return
			var route: Dictionary = routes[route_index]
			var points: Array = route.get("points", [])
			var length := _route_length(points)
			if points.size() < 2 or length < 8.0:
				continue
			var rate := float(route.get("rate", 0.0))
			var count := clampi(int(ceil(rate * 5.0)), 3, 18)
			var speed := 34.0 + minf(rate, 8.0) * 11.0
			var from_color: Color = route.get("from_color", Color("8cff6a"))
			var to_color: Color = route.get("to_color", from_color)
			for i in count:
				if drawn >= 220:
					return
				var seed := float((route_index * 37 + i * 17) % 101) / 101.0
				var distance := fmod(now * speed + seed * length, length)
				var t := distance / length
				var sample_info := _sample_route_info(points, distance)
				var sample: Vector2 = sample_info.get("point", Vector2.ZERO)
				var normal: Vector2 = sample_info.get("normal", Vector2.RIGHT)
				var jitter_phase := now * (2.2 + seed) + seed * TAU
				var jitter := Vector2(cos(jitter_phase * 1.37), sin(jitter_phase * 1.91)) * (1.6 + seed * 2.4)
				var color := from_color.lerp(to_color, clampf(t, 0.0, 1.0))
				var alpha := 0.32 + 0.58 * sin(t * PI)
				var radius := 2.0 + seed * 2.4
				var side_offset := normal * (8.0 + seed * 4.0)
				draw_rect(Rect2(sample + side_offset + jitter - Vector2.ONE * radius * 0.5, Vector2.ONE * radius), Color(color.r, color.g, color.b, alpha), true)
				drawn += 1

	func _route_length(points: Array) -> float:
		var total := 0.0
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			total += a.distance_to(b)
		return total

	func _sample_route(points: Array, distance: float) -> Vector2:
		return _sample_route_info(points, distance).get("point", points[points.size() - 1])

	func _sample_route_info(points: Array, distance: float) -> Dictionary:
		var remaining := distance
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var segment := a.distance_to(b)
			if segment <= 0.001:
				continue
			if remaining <= segment:
				var dir := (b - a).normalized()
				return {
					"point": a.lerp(b, remaining / segment),
					"normal": Vector2(-dir.y, dir.x)
				}
			remaining -= segment
		var last: Vector2 = points[points.size() - 1]
		var previous: Vector2 = points[maxi(0, points.size() - 2)]
		var dir := (last - previous).normalized()
		return {"point": last, "normal": Vector2(-dir.y, dir.x)}

class FutureGoalArrow:
	extends Control

	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var label := ""

	func _draw() -> void:
		var delta := end - start
		if delta.length() < 8.0:
			return
		var dir := delta.normalized()
		var normal := Vector2(-dir.y, dir.x)
		var color := Color(0.50, 0.84, 0.92, 0.34)
		var segments := 8
		for i in segments:
			if i % 2 == 1:
				continue
			var a := start.lerp(end, float(i) / float(segments))
			var b := start.lerp(end, float(i + 1) / float(segments))
			draw_line(a, b, Color("02070b"), 7.0, true)
			draw_line(a, b, color, 3.0, true)
		var left := end - dir * 14.0 + normal * 7.0
		var right := end - dir * 14.0 - normal * 7.0
		draw_colored_polygon(PackedVector2Array([end, left, right]), color)
		if not label.is_empty():
			draw_string(ThemeDB.fallback_font, start.lerp(end, 0.46) + Vector2(8.0, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.74, 0.90, 0.92, 0.72))

class MoleculePebbleNode:
	extends Control

	var simulation
	var molecule_id := ""
	var pebble_color := Color("62d66f")
	var selected := false
	var depleted := false
	var is_target := false
	var lifted := false

	func _ready() -> void:
		set_process(true)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var lift := Vector2(0.0, -8.0) if lifted else Vector2.ZERO
		var center := size * 0.5 + lift
		var radius := minf(size.x, size.y) * 0.34
		var amount := 0.0
		var formula := "M"
		if simulation != null and simulation.molecule_types.has(molecule_id):
			amount = float(simulation.molecule_amounts.get(molecule_id, 0.0))
			formula = str(simulation.molecule_types[molecule_id].get("formula", "M"))
		var alpha := 0.46 if depleted else 1.0
		var glow_radius := radius * (1.34 if selected else 1.12)
		var glow := Color(pebble_color.r, pebble_color.g, pebble_color.b, (0.34 if selected else 0.13) * alpha)
		var shadow_radius := radius * (1.24 if lifted else 1.05)
		draw_circle(size * 0.5 + Vector2(0.0, radius * (0.46 if lifted else 0.20)), shadow_radius, Color(0.0, 0.0, 0.0, (0.42 if lifted else 0.30) * alpha))
		draw_circle(center, glow_radius, glow)
		draw_circle(center, radius + 6.0, Color(0.0, 0.015, 0.018, 0.95 * alpha))
		draw_circle(center, radius + 2.0, Color(pebble_color.lightened(0.18).r, pebble_color.lightened(0.18).g, pebble_color.lightened(0.18).b, alpha))
		draw_circle(center, radius - 2.0, Color(pebble_color.darkened(0.12).r, pebble_color.darkened(0.12).g, pebble_color.darkened(0.12).b, alpha))
		draw_arc(center, radius * 0.78, -1.15, 2.15, 24, Color(1, 1, 1, 0.16 * alpha), 2.0, true)
		draw_circle(center + Vector2(radius * 0.28, -radius * 0.34), radius * 0.18, Color(1, 1, 1, 0.42 * alpha))
		if is_target:
			draw_circle(center, radius * 0.58, Color(0.0, 0.015, 0.018, 0.62 * alpha))
			draw_arc(center, radius * 0.72, 0.0, TAU, 36, Color("8cff6a"), 2.0, true)
		if selected:
			draw_arc(center, radius + 12.0, 0.0, TAU, 48, Color("8cff6a"), 2.2, true)
		var label_color := Color("dff8f8", 0.88 * alpha)
		var text_x := center.x + radius + 10.0
		draw_string(ThemeDB.fallback_font, Vector2(text_x, center.y - 3.0), "%s" % formula, HORIZONTAL_ALIGNMENT_LEFT, -1, maxf(9.0, 12.0 * size.x / 128.0), label_color)
		var detail := "sink" if is_target and depleted else "%.0f" % amount
		draw_string(ThemeDB.fallback_font, Vector2(text_x, center.y + 15.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, maxf(8.0, 10.0 * size.x / 128.0), Color(0.70, 0.86, 0.84, 0.72 * alpha))
		_draw_storage_dust(center, radius, amount, alpha)

	func _draw_storage_dust(center: Vector2, radius: float, amount: float, alpha: float) -> void:
		if amount <= 0.001:
			return
		var count := clampi(int(sqrt(amount) * 0.9), 3, 24)
		var base := center + Vector2(radius + 34.0, -radius * 0.12)
		var time := Time.get_ticks_msec() / 1000.0
		for i in count:
			var seed := float((abs(molecule_id.hash()) + i * 31) % 97) / 97.0
			var angle := seed * TAU + time * (0.35 + seed * 0.25)
			var drift := Vector2(cos(angle), sin(angle * 1.7)) * (4.0 + seed * 10.0)
			var pos := base + Vector2(float(i % 6) * 4.0, float(i / 6) * 4.0) + drift
			var size_px := 1.6 + seed * 1.8
			draw_rect(Rect2(pos, Vector2.ONE * size_px), Color(pebble_color.r, pebble_color.g, pebble_color.b, 0.22 * alpha), true)

class MoleculeHoverPopup:
	extends Control

	var simulation
	var molecule_id := ""

	func _ready() -> void:
		if simulation == null or not simulation.molecule_types.has(molecule_id):
			return
		var canvas = MoleculeCanvasScript.new()
		canvas.position = Vector2(18.0, 48.0)
		canvas.size = Vector2(size.x - 36.0, 106.0)
		canvas.custom_minimum_size = canvas.size
		canvas.draw_background = false
		canvas.scale_to_fit = true
		canvas.atom_scale = 0.76
		canvas.bond_scale = 0.74
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.set_molecule(simulation.molecule_types[molecule_id])
		add_child(canvas)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		_draw_popup_panel(rect, Color("76f4ff"))
		if simulation == null or not simulation.molecule_types.has(molecule_id):
			return
		var molecule: Dictionary = simulation.molecule_types[molecule_id]
		var formula := str(molecule.get("formula", "Molecule"))
		var amount := float(simulation.molecule_amounts.get(molecule_id, 0.0))
		var rates: Dictionary = simulation.molecule_rates.get(molecule_id, {"production": 0.0, "consumption": 0.0})
		draw_string(ThemeDB.fallback_font, Vector2(16.0, 28.0), formula, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("f4fbff"))
		draw_string(ThemeDB.fallback_font, Vector2(16.0, size.y - 48.0), "Amount %.1f | +%.2f/s | -%.2f/s" % [amount, float(rates.get("production", 0.0)), float(rates.get("consumption", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))
		draw_string(ThemeDB.fallback_font, Vector2(16.0, size.y - 22.0), "Stats placeholder: toxicity, stability, flux role", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.90, 0.90, 0.72))

	func _draw_popup_panel(rect: Rect2, border: Color) -> void:
		draw_rect(rect, Color(0.03, 0.10, 0.12, 0.94), true)
		draw_rect(rect.grow(3.0), Color(border.r, border.g, border.b, 0.12), true)
		draw_rect(rect, Color(border.r, border.g, border.b, 0.35), false, 7.0)
		draw_rect(rect, border, false, 1.4)

class ReactionHoverPopup:
	extends Control

	var simulation
	var reaction: Dictionary = {}

	func _ready() -> void:
		var step := EnzymeStepBox.new()
		step.simulation = simulation
		step.reaction = reaction
		step.fixed_zoom = 0.42
		step.position = Vector2(16.0, 62.0)
		step.size = Vector2(size.x - 32.0, 110.0)
		step.custom_minimum_size = step.size
		step.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(step)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		_draw_popup_panel(rect, Color("ff7a67"))
		var name := str(reaction.get("name", "Enzyme reaction"))
		var tool := str(reaction.get("tool", "enzyme")).capitalize()
		draw_string(ThemeDB.fallback_font, Vector2(16.0, 28.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f4fbff"))
		draw_string(ThemeDB.fallback_font, Vector2(16.0, 50.0), _reaction_route_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.80, 0.94, 0.94, 0.84))
		draw_string(ThemeDB.fallback_font, Vector2(16.0, size.y - 36.0), "%s | %.2f/s | active %d | queued %d" % [tool, float(reaction.get("rate", 0.0)), int(reaction.get("active_count", 0)), int(reaction.get("queued_count", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbeff2"))
		draw_string(ThemeDB.fallback_font, Vector2(16.0, size.y - 14.0), "Future stats: costs, stability, redox balance", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.80, 0.90, 0.88, 0.70))

	func _reaction_route_label() -> String:
		if simulation == null:
			return "Substrate -> product"
		var substrate_id := str(reaction.get("substrate", ""))
		var substrate := "Substrate"
		if simulation.molecule_types.has(substrate_id):
			substrate = str(simulation.molecule_types[substrate_id].get("formula", "Substrate"))
		var products: Array[String] = []
		for product_id in reaction.get("products", []):
			var id := str(product_id)
			if simulation.molecule_types.has(id):
				products.append(str(simulation.molecule_types[id].get("formula", "Product")))
		var product_text := "products" if products.is_empty() else " + ".join(products)
		return "%s -> %s" % [substrate, product_text]

	func _draw_popup_panel(rect: Rect2, border: Color) -> void:
		draw_rect(rect, Color(0.05, 0.09, 0.11, 0.96), true)
		draw_rect(rect.grow(3.0), Color(border.r, border.g, border.b, 0.12), true)
		draw_rect(rect, Color(border.r, border.g, border.b, 0.33), false, 7.0)
		draw_rect(rect, border, false, 1.4)

class GoalHoverPopup:
	extends Control

	var goal_id := ""

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var border := Color("8cff6a") if goal_id == "amino_acids" else Color("76f4ff")
		draw_rect(rect, Color(0.03, 0.10, 0.12, 0.95), true)
		draw_rect(rect.grow(3.0), Color(border.r, border.g, border.b, 0.12), true)
		draw_rect(rect, Color(border.r, border.g, border.b, 0.34), false, 7.0)
		draw_rect(rect, border, false, 1.4)
		if goal_id == "amino_acids":
			draw_string(ThemeDB.fallback_font, Vector2(16.0, 30.0), "Amino Acid Sink", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f4fbff"))
			draw_string(ThemeDB.fallback_font, Vector2(16.0, 52.0), "Target formula: N-C-COOH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dbeff2"))
			_draw_amino_structure(Vector2(size.x * 0.50, 118.0), 26.0)
			draw_string(ThemeDB.fallback_font, Vector2(16.0, size.y - 22.0), "Converts completed target molecules into amino acid resource.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.90, 0.90, 0.72))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(16.0, 30.0), "DNA Point Sink", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f4fbff"))
			draw_string(ThemeDB.fallback_font, Vector2(16.0, 52.0), "Prototype target: C5NO3 ring", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dbeff2"))
			_draw_dna_target_structure(Vector2(size.x * 0.50, 118.0), 27.0)
			draw_string(ThemeDB.fallback_font, Vector2(16.0, size.y - 22.0), "Future route converts nucleotide-like molecules into DNA points.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.90, 0.90, 0.72))

	func _draw_amino_structure(center: Vector2, radius: float) -> void:
		var points := [
			{"e": "N", "p": center + Vector2(-radius * 1.60, 0.0)},
			{"e": "C", "p": center + Vector2(-radius * 0.45, 0.0)},
			{"e": "C", "p": center + Vector2(radius * 0.70, 0.0)},
			{"e": "O", "p": center + Vector2(radius * 1.55, -radius * 0.55)},
			{"e": "O", "p": center + Vector2(radius * 1.55, radius * 0.55)}
		]
		_draw_bond(points[0]["p"], points[1]["p"], 1)
		_draw_bond(points[1]["p"], points[2]["p"], 1)
		_draw_bond(points[2]["p"], points[3]["p"], 2)
		_draw_bond(points[2]["p"], points[4]["p"], 1)
		for atom in points:
			_draw_atom(atom["p"], str(atom["e"]), 12.0)

	func _draw_dna_target_structure(center: Vector2, radius: float) -> void:
		var atoms: Array[Dictionary] = []
		for i in 5:
			var angle := -PI * 0.5 + float(i) * TAU / 5.0
			atoms.append({"e": "C", "p": center + Vector2(cos(angle), sin(angle)) * radius})
		atoms.append({"e": "N", "p": center + Vector2(-radius * 0.30, -radius * 0.20)})
		atoms.append({"e": "O", "p": center + Vector2(radius * 1.42, -radius * 0.36)})
		atoms.append({"e": "O", "p": center + Vector2(radius * 1.30, radius * 0.64)})
		atoms.append({"e": "O", "p": center + Vector2(-radius * 1.42, radius * 0.18)})
		for i in 5:
			_draw_bond(atoms[i]["p"], atoms[(i + 1) % 5]["p"], 1)
		_draw_bond(atoms[1]["p"], atoms[6]["p"], 1)
		_draw_bond(atoms[2]["p"], atoms[7]["p"], 1)
		_draw_bond(atoms[4]["p"], atoms[8]["p"], 1)
		for atom in atoms:
			_draw_atom(atom["p"], str(atom["e"]), 11.0)

	func _draw_bond(a: Vector2, b: Vector2, order: int) -> void:
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var offsets := [0.0] if order == 1 else [-2.2, 2.2]
		for offset in offsets:
			draw_line(a + dir * 11.0 + normal * float(offset), b - dir * 11.0 + normal * float(offset), Color("02070b"), 5.0, true)
			draw_line(a + dir * 11.0 + normal * float(offset), b - dir * 11.0 + normal * float(offset), Color("dbeff2"), 2.0, true)

	func _draw_atom(pos: Vector2, element: String, radius: float) -> void:
		var color := Color("68777a")
		if element == "O":
			color = Color("e95058")
		elif element == "N":
			color = Color("4a90df")
		draw_circle(pos, radius + 4.0, Color("02070b"))
		draw_circle(pos, radius + 1.0, color.lightened(0.22))
		draw_circle(pos, radius - 1.0, color.darkened(0.10))
		draw_circle(pos + Vector2(radius * 0.25, -radius * 0.34), radius * 0.18, Color(1, 1, 1, 0.45))

class GoalSinkNode:
	extends Control

	var goal: Dictionary = {}
	var lifted := false

	func _ready() -> void:
		set_process(true)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var color: Color = goal.get("color", Color("8cff6a"))
		var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.003) * 0.18
		var lift := Vector2(0.0, -8.0) if lifted else Vector2.ZERO
		var center := size * 0.5 + lift
		var radius := minf(size.x, size.y) * 0.32
		draw_circle(size * 0.5 + Vector2(0.0, radius * (0.46 if lifted else 0.18)), radius * (1.35 if lifted else 1.18), Color(0.0, 0.0, 0.0, 0.42))
		draw_circle(center, radius * 1.45, Color(color.r, color.g, color.b, 0.10 + pulse * 0.07))
		draw_circle(center, radius * 1.17, Color(0.0, 0.018, 0.024, 0.94))
		draw_circle(center, radius * 0.88, Color(0.02, 0.08, 0.09, 0.96))
		draw_circle(center, radius * 0.58, Color(0.0, 0.006, 0.010, 0.98))
		for i in 4:
			var start := float(i) * TAU / 4.0 + Time.get_ticks_msec() * 0.0012
			draw_arc(center, radius * (0.72 + float(i) * 0.08), start, start + 1.75, 20, Color(color.r, color.g, color.b, 0.40 - float(i) * 0.06), 2.0, true)
		draw_arc(center, radius * 1.03, 0.0, TAU, 52, Color("02070b"), 4.0, true)
		draw_arc(center, radius * 1.03, 0.0, TAU, 52, color, 2.0, true)
		var symbol_center := center + Vector2(0.0, -radius * 0.08)
		if str(goal.get("id", "")) == "amino_acids":
			_draw_amino_symbol(symbol_center, radius * 0.55)
		else:
			_draw_dna_symbol(symbol_center, radius * 0.56)
		var label_pos := Vector2(0.0, center.y + radius + 22.0)
		draw_string(ThemeDB.fallback_font, label_pos + Vector2(0.0, 0.0), str(goal.get("title", "GOAL")), HORIZONTAL_ALIGNMENT_CENTER, size.x, maxf(9.0, 13.0 * size.x / 172.0), color)
		draw_string(ThemeDB.fallback_font, label_pos + Vector2(0.0, 20.0), str(goal.get("subtitle", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x, maxf(8.0, 10.0 * size.x / 172.0), Color(0.78, 0.91, 0.91, 0.82))

	func _draw_amino_symbol(center: Vector2, radius: float) -> void:
		var atoms := [
			{"e": "N", "p": center + Vector2(-radius * 1.25, 0.0)},
			{"e": "C", "p": center + Vector2(-radius * 0.35, 0.0)},
			{"e": "C", "p": center + Vector2(radius * 0.55, 0.0)},
			{"e": "O", "p": center + Vector2(radius * 1.25, -radius * 0.42)},
			{"e": "O", "p": center + Vector2(radius * 1.25, radius * 0.42)}
		]
		_draw_goal_bond(atoms[0]["p"], atoms[1]["p"])
		_draw_goal_bond(atoms[1]["p"], atoms[2]["p"])
		_draw_goal_bond(atoms[2]["p"], atoms[3]["p"])
		_draw_goal_bond(atoms[2]["p"], atoms[4]["p"])
		for atom in atoms:
			_draw_goal_atom(atom["p"], str(atom["e"]), radius * 0.28)

	func _draw_dna_symbol(center: Vector2, radius: float) -> void:
		for i in 9:
			var t := float(i) / 8.0
			var y := lerpf(-radius, radius, t)
			var wave := sin(t * TAU * 1.25 + Time.get_ticks_msec() * 0.002) * radius * 0.40
			var left := center + Vector2(-wave, y)
			var right := center + Vector2(wave, y)
			draw_line(left, right, Color(0.76, 1.0, 0.94, 0.42), 2.0, true)
			draw_circle(left, radius * 0.12, Color("76f4ff"))
			draw_circle(right, radius * 0.12, Color("8cff6a"))

	func _draw_goal_bond(a: Vector2, b: Vector2) -> void:
		var dir := (b - a).normalized()
		draw_line(a + dir * 8.0, b - dir * 8.0, Color("02070b"), 5.0, true)
		draw_line(a + dir * 8.0, b - dir * 8.0, Color("dbeff2"), 2.0, true)

	func _draw_goal_atom(pos: Vector2, element: String, radius: float) -> void:
		var color := Color("68777a")
		if element == "O":
			color = Color("e95058")
		elif element == "N":
			color = Color("4a90df")
		draw_circle(pos, radius + 4.0, Color("02070b"))
		draw_circle(pos, radius, color)

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
		var cyan := Color("8cff6a") if selected else Color("ff7a67")
		draw_rect(rect.grow(4.0), Color(cyan.r, cyan.g, cyan.b, 0.08), true)
		draw_rect(rect, Color(0.22, 0.07, 0.08, 0.88), true)
		draw_line(Vector2(size.x * 0.5, 0.0), Vector2(size.x * 0.5, size.y), Color(cyan.r, cyan.g, cyan.b, 0.12), 1.0, true)
		draw_line(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(cyan.r, cyan.g, cyan.b, 0.10), 1.0, true)
		draw_rect(rect.grow(-5.0), Color(0.05, 0.10, 0.12, 0.36), true)
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
	var grid_cell := 128.0

	func _draw() -> void:
		var rect := Rect2(world_bounds.position * zoom + pan_offset, world_bounds.size * zoom)
		draw_rect(rect, Color("10292d"), true)
		_draw_grid(rect)
		draw_rect(rect, Color("0d3a42"), false, 5.0)
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), Color("76f4ff"), 4.0, true)
		draw_line(rect.position + Vector2(0.0, 8.0), rect.position + Vector2(rect.size.x, 8.0), Color(0.55, 1.0, 0.9, 0.35), 2.0, true)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(26.0, 32.0), "Drag the board. Click molecules to design enzyme machines.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.95, 0.96, 0.70))

	func _draw_grid(rect: Rect2) -> void:
		var screen_spacing := grid_cell * zoom
		if screen_spacing <= 8.0:
			return
		var first_world_x: float = floor(world_bounds.position.x / grid_cell) * grid_cell
		var first_world_y: float = floor(world_bounds.position.y / grid_cell) * grid_cell
		var world_x: float = first_world_x
		while world_x <= world_bounds.end.x:
			var x: float = world_x * zoom + pan_offset.x
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.45, 1.0, 1.0, 0.105), 1.2, true)
			world_x += grid_cell
		var world_y: float = first_world_y
		while world_y <= world_bounds.end.y:
			var y: float = world_y * zoom + pan_offset.y
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.45, 1.0, 1.0, 0.105), 1.2, true)
			world_y += grid_cell
