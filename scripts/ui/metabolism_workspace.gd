extends Control
class_name MetabolismWorkspace

signal molecule_requested(molecule_id: String)

const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")

var simulation
var pan_offset := Vector2.ZERO
var _dragging := false
var _last_mouse := Vector2.ZERO
var _fixed_zoom := 0.72

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_mouse = event.position
		mouse_default_cursor_shape = Control.CURSOR_MOVE if _dragging else Control.CURSOR_DRAG
	elif event is InputEventMouseMotion and _dragging:
		pan_offset += event.position - _last_mouse
		_last_mouse = event.position
		queue_redraw()
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
	var ids: Array[String] = simulation.present_molecule_ids()
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
	for reaction in simulation.reactions:
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
			arrow.label = "%.2f/s" % float(reaction.get("rate", 0.0))
			arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(arrow)

func _metabolism_layout(ids: Array[String], map_width: float) -> Dictionary:
	var result := {}
	var gap := Vector2(90.0, 110.0)
	var top_y := 78.0
	var row_y := 380.0
	var row_x := 96.0
	var row_height := 0.0
	for i in ids.size():
		var id := ids[i]
		var node_size := _molecule_canvas_size(simulation.molecule_types[id], _fixed_zoom)
		var pos := Vector2(map_width * 0.5 - node_size.x * 0.5, top_y)
		if i > 0:
			if row_x + node_size.x > map_width - 80.0:
				row_x = 96.0
				row_y += row_height + gap.y
				row_height = 0.0
			pos = Vector2(row_x, row_y)
			row_x += node_size.x + gap.x
			row_height = maxf(row_height, node_size.y)
		result[id] = {"position": pos, "size": node_size}
	return result

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
	var box := VBoxContainer.new()
	box.position = pos
	box.custom_minimum_size = node_size
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(node_size.x, maxf(90.0, node_size.y - 48.0))
	canvas.scale_to_fit = false
	canvas.fixed_zoom = _fixed_zoom
	canvas.set_molecule(simulation.molecule_types[id])
	canvas.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("molecule_requested", id)
	)
	box.add_child(canvas)
	var label := Button.new()
	label.text = "%s  %.0f" % [simulation.molecule_types[id].get("formula", ""), float(simulation.molecule_amounts.get(id, 0.0))]
	label.pressed.connect(func(): emit_signal("molecule_requested", id))
	box.add_child(label)
	return box

class ArrowLine:
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
		var from := start + dir * 90.0
		var to := end - dir * 90.0
		draw_line(from, to, Color("02070b"), 9.0, true)
		draw_line(from, to, Color("f4fbff"), 4.0, true)
		var left := to - dir * 18.0 + normal * 9.0
		var right := to - dir * 18.0 - normal * 9.0
		draw_colored_polygon(PackedVector2Array([to, left, right]), Color("f4fbff"))
		draw_string(ThemeDB.fallback_font, from.lerp(to, 0.5) + Vector2(8, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f4fbff"))
