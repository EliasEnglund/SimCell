extends Control

const CellViewScript := preload("res://scripts/ui/cell_view.gd")
const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")
const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

var sim = SimulationStateScript.new()
var root: VBoxContainer
var content: Control
var bottom_nav: HBoxContainer
var status_label: Label
var molecule_list: VBoxContainer
var detail_panel: VBoxContainer
var map_layer: Control
var queue_box: VBoxContainer
var event_log: RichTextLabel
var music_player: AudioStreamPlayer
var music_button: Button

var designer_tool := "lyase"
var designer_target := -1
var designer_preview: HBoxContainer
var designer_canvas: Control

func _ready() -> void:
	sim.changed.connect(_refresh)
	sim.event_logged.connect(_log_event)
	_setup_music()
	_build_shell()
	_show_view("metabolism")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause_toggle"):
		sim.toggle_pause()
	sim.tick(delta)

func _build_shell() -> void:
	root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 42)
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := Label.new()
	title.text = "SIM CELL"
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("76f4ff")
	header.add_child(title)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(status_label)
	music_button = Button.new()
	music_button.text = "♫"
	music_button.custom_minimum_size = Vector2(42, 34)
	music_button.pressed.connect(_toggle_music)
	header.add_child(music_button)
	for def in [["Ⅱ", func(): sim.toggle_pause()], ["-", func(): sim.set_speed(sim.speed - 0.25)], ["+", func(): sim.set_speed(sim.speed + 0.25)]]:
		var button := Button.new()
		button.text = def[0]
		button.custom_minimum_size = Vector2(42, 34)
		button.pressed.connect(def[1])
		header.add_child(button)
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	bottom_nav = HBoxContainer.new()
	bottom_nav.custom_minimum_size = Vector2(0, 72)
	bottom_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_nav.add_theme_constant_override("separation", 8)
	root.add_child(bottom_nav)
	for item in [
		["◎", "Cell", "cell"],
		["⌬", "Metabolism", "metabolism"],
		["◌", "Membrane", "membrane"],
		["▣", "Proteins", "proteins"],
		["⌁", "DNA", "dna"]
	]:
		var button := Button.new()
		button.text = "%s\n%s" % [item[0], item[1]]
		button.custom_minimum_size = Vector2(132, 58)
		button.pressed.connect(func(view_id = item[2]): _show_view(view_id))
		bottom_nav.add_child(button)

func _setup_music() -> void:
	music_player = AudioStreamPlayer.new()
	var stream := AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes("res://assets/audio/enzymatic_waltz.mp3")
	stream.loop = true
	music_player.stream = stream
	music_player.volume_db = -12.0
	music_player.autoplay = true
	add_child(music_player)
	music_player.play()

func _toggle_music() -> void:
	if music_player == null:
		return
	if music_player.playing:
		music_player.stop()
		music_button.text = "♪"
	else:
		music_player.play()
		music_button.text = "♫"

func _show_view(view_id: String) -> void:
	sim.active_view = view_id
	_clear(content)
	if view_id == "cell":
		_build_cell_view()
	elif view_id == "metabolism":
		_build_metabolism_view()
	elif view_id == "membrane":
		_build_placeholder("MEMBRANE TRANSPORT", "Transporters will control which external molecules enter the cell.")
	elif view_id == "proteins":
		_build_protein_view()
	elif view_id == "dna":
		_build_placeholder("DNA TECH TREE", "DNA research unlocks new transporters, enzyme classes, movement, and defense.")
	_refresh()

func _build_cell_view() -> void:
	var cell_view = CellViewScript.new()
	cell_view.simulation = sim
	cell_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(cell_view)

func _build_metabolism_view() -> void:
	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 12)
	content.add_child(layout)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.add_theme_constant_override("separation", 8)
	layout.add_child(side)
	side.add_child(_section_label("Molecules In Cell"))
	molecule_list = VBoxContainer.new()
	side.add_child(molecule_list)
	side.add_child(_section_label("Selection"))
	detail_panel = VBoxContainer.new()
	side.add_child(detail_panel)

	map_layer = Control.new()
	map_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(map_layer)

func _build_protein_view() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	content.add_child(box)
	box.add_child(_title("PROTEIN BUILDER", "Designed enzyme blueprints auto-queue here before becoming active in metabolism."))
	queue_box = VBoxContainer.new()
	box.add_child(queue_box)

func _build_placeholder(title: String, subtitle: String) -> void:
	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(box)
	box.add_child(_title(title, subtitle))

func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = "Time %.1fs | %s | %.2fx | Molecules %d | Enzymes %d" % [
		sim.time_seconds,
		"Paused" if sim.paused else "Running",
		sim.speed,
		sim.present_molecule_ids().size(),
		sim.active_enzymes.size()
	]
	if sim.active_view == "metabolism" and molecule_list != null:
		_refresh_metabolism()
	if sim.active_view == "proteins" and queue_box != null:
		_refresh_protein_queue()

func _refresh_metabolism() -> void:
	_clear(molecule_list)
	for id in sim.present_molecule_ids():
		molecule_list.add_child(_molecule_list_button(id))
	_refresh_selection_detail()
	_draw_metabolism_map()

func _molecule_list_button(id: String) -> Button:
	var molecule: Dictionary = sim.molecule_types[id]
	var rates: Dictionary = sim.molecule_rates.get(id, {"production": 0.0, "consumption": 0.0})
	var button := Button.new()
	button.text = "%s  %.1f\n+%.1f/s  -%.1f/s" % [
		molecule.get("formula", "Molecule"),
		float(sim.molecule_amounts.get(id, 0.0)),
		float(rates.get("production", 0.0)),
		float(rates.get("consumption", 0.0))
	]
	button.toggle_mode = true
	button.button_pressed = sim.selected_molecule == id
	button.custom_minimum_size = Vector2(0, 62)
	button.pressed.connect(func(): _select_and_open_designer(id))
	return button

func _refresh_selection_detail() -> void:
	_clear(detail_panel)
	if not sim.molecule_types.has(sim.selected_molecule):
		return
	var molecule: Dictionary = sim.molecule_types[sim.selected_molecule]
	var amount := float(sim.molecule_amounts.get(sim.selected_molecule, 0.0))
	var rates: Dictionary = sim.molecule_rates.get(sim.selected_molecule, {"production": 0.0, "consumption": 0.0})
	detail_panel.add_child(_title(molecule.get("formula", "Molecule"), "Amount %.1f | +%.1f/s | -%.1f/s" % [
		amount,
		float(rates.get("production", 0.0)),
		float(rates.get("consumption", 0.0))
	]))
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(220, 135)
	canvas.set_molecule(molecule)
	canvas.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_enzyme_designer(sim.selected_molecule)
	)
	detail_panel.add_child(canvas)
	var button := Button.new()
	button.text = "Design Enzyme"
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(func(): _open_enzyme_designer(sim.selected_molecule))
	detail_panel.add_child(button)

func _draw_metabolism_map() -> void:
	_clear(map_layer)
	var background := ColorRect.new()
	background.color = Color("10292d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_layer.add_child(background)
	var title := Label.new()
	title.text = "METABOLIC LANDSCAPE"
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("76f4ff")
	title.position = Vector2(28, 18)
	map_layer.add_child(title)
	var ids := sim.present_molecule_ids()
	var positions := {}
	var map_width: float = maxf(760.0, map_layer.size.x)
	var layout := _metabolism_layout(ids, map_width)
	for i in ids.size():
		var id := ids[i]
		var item: Dictionary = layout[id]
		positions[id] = item["position"]
		map_layer.add_child(_map_molecule_node(id, item["position"], item["size"]))
	for reaction in sim.reactions:
		map_layer.add_child(_reaction_node(reaction, positions))

func _metabolism_layout(ids: Array[String], map_width: float) -> Dictionary:
	var result := {}
	var fixed_zoom := 0.72
	var gap := Vector2(74.0, 82.0)
	var top_y := 72.0
	var row_y := 360.0
	var row_x := 82.0
	var row_height := 0.0
	for i in ids.size():
		var id := ids[i]
		var size := _molecule_canvas_size(sim.molecule_types[id], fixed_zoom)
		var pos := Vector2(map_width * 0.5 - size.x * 0.5, top_y)
		if i > 0:
			if row_x + size.x > map_width - 60.0:
				row_x = 82.0
				row_y += row_height + gap.y
				row_height = 0.0
			pos = Vector2(row_x, row_y)
			row_x += size.x + gap.x
			row_height = maxf(row_height, size.y)
		result[id] = {"position": pos, "size": size}
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
	canvas.fixed_zoom = 0.72
	canvas.set_molecule(sim.molecule_types[id])
	canvas.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_and_open_designer(id)
	)
	box.add_child(canvas)
	var label := Button.new()
	label.text = "%s  %.0f" % [sim.molecule_types[id].get("formula", ""), float(sim.molecule_amounts.get(id, 0.0))]
	label.pressed.connect(func(): _select_and_open_designer(id))
	box.add_child(label)
	return box

func _reaction_node(reaction: Dictionary, positions: Dictionary) -> Control:
	var substrate: String = reaction.get("substrate", "")
	var products: Array = reaction.get("products", [])
	var source: Vector2 = positions.get(substrate, Vector2(180, 120))
	var target := source + Vector2(250, 90)
	if not products.is_empty():
		target = positions.get(products[0], target)
	var label := Label.new()
	label.text = "%s\n%.2f/s" % [reaction.get("name", "Enzyme"), float(reaction.get("rate", 0.0))]
	label.position = source.lerp(target, 0.5) + Vector2(0, 42)
	label.modulate = Color("f4f8ff")
	return label

func _open_enzyme_designer(molecule_id: String) -> void:
	sim.select_molecule(molecule_id)
	_clear(root)
	var shell := HBoxContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 18)
	root.add_child(shell)
	var tools := VBoxContainer.new()
	tools.custom_minimum_size = Vector2(330, 0)
	tools.add_theme_constant_override("separation", 12)
	shell.add_child(tools)
	tools.add_child(_title("ENZYME FUNCTION", "Choose enzyme class, then click a highlighted target."))
	tools.add_child(_tool_button("lyase", "✂", "LYASE"))
	tools.add_child(_tool_button("reductase", "=", "REDUCTASE"))
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(center)
	var header := HBoxContainer.new()
	center.add_child(header)
	var title := Label.new()
	title.text = "ENZYME DESIGNER"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color("76f4ff")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): _restore_main_shell())
	header.add_child(back)
	designer_canvas = MoleculeCanvasScript.new()
	designer_canvas.custom_minimum_size = Vector2(760, 430)
	designer_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	designer_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	designer_canvas.interactive = true
	designer_canvas.target_selected.connect(_designer_target_selected)
	center.add_child(designer_canvas)
	designer_preview = HBoxContainer.new()
	designer_preview.custom_minimum_size = Vector2(0, 210)
	designer_preview.add_theme_constant_override("separation", 12)
	center.add_child(designer_preview)
	_refresh_designer()

func _select_and_open_designer(molecule_id: String) -> void:
	sim.select_molecule(molecule_id)
	_open_enzyme_designer(molecule_id)

func _tool_button(id: String, icon: String, label_text: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [icon, label_text]
	button.custom_minimum_size = Vector2(0, 112)
	button.toggle_mode = true
	button.button_pressed = designer_tool == id
	button.pressed.connect(func():
		designer_tool = id
		designer_target = -1
		_refresh_designer()
	)
	return button

func _designer_target_selected(index: int) -> void:
	designer_target = index
	_refresh_designer()

func _refresh_designer() -> void:
	if designer_canvas == null:
		return
	var molecule: Dictionary = sim.molecule_types[sim.selected_molecule]
	designer_canvas.set_molecule(molecule)
	designer_canvas.valid_targets = sim.valid_targets(designer_tool, sim.selected_molecule)
	designer_canvas.selected_target = designer_target
	designer_canvas.queue_redraw()
	_clear(designer_preview)
	if designer_target < 0:
		designer_preview.add_child(_title("Select Target", "Highlighted bonds can be modified by the selected enzyme class."))
		return
	var products := sim.preview_products(designer_tool, sim.selected_molecule, designer_target)
	for product in products:
		var panel := VBoxContainer.new()
		panel.custom_minimum_size = Vector2(220, 180)
		var canvas = MoleculeCanvasScript.new()
		canvas.custom_minimum_size = Vector2(220, 140)
		canvas.set_molecule(product)
		panel.add_child(canvas)
		var label := Label.new()
		label.text = product.get("formula", "Product")
		panel.add_child(label)
		designer_preview.add_child(panel)
	var confirm := Button.new()
	confirm.text = "Create Blueprint + Auto-Queue"
	confirm.custom_minimum_size = Vector2(240, 64)
	confirm.pressed.connect(func():
		sim.design_enzyme(designer_tool, sim.selected_molecule, designer_target)
		_restore_main_shell()
	)
	designer_preview.add_child(confirm)

func _restore_main_shell() -> void:
	_clear(root)
	_build_shell()
	_show_view("metabolism")

func _refresh_protein_queue() -> void:
	_clear(queue_box)
	if sim.protein_queue.is_empty():
		queue_box.add_child(_title("No active builds", "Design an enzyme from metabolism to create a blueprint."))
	for item in sim.protein_queue:
		var duration := maxf(0.01, float(item.get("duration", 1.0)))
		queue_box.add_child(_title(item.get("name", "Enzyme"), "%.0f%% complete" % ((1.0 - float(item.get("remaining", 0.0)) / duration) * 100.0)))

func _title(title_text: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(0.72, 0.84, 0.82)
	box.add_child(sub)
	return box

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color("76f4ff")
	label.add_theme_font_size_override("font_size", 16)
	return label

func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _log_event(message: String) -> void:
	if event_log == null:
		return
	event_log.append_text("[%05.1f] %s\n" % [sim.time_seconds, message])
