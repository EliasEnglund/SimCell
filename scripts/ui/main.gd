extends Control

const CellViewScript := preload("res://scripts/ui/cell_view.gd")
const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")
const MetabolismWorkspaceScript := preload("res://scripts/ui/metabolism_workspace.gd")
const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

var sim = SimulationStateScript.new()
var root: VBoxContainer
var content: Control
var bottom_nav: HBoxContainer
var status_label: Label
var molecule_list: VBoxContainer
var detail_panel: VBoxContainer
var pathway_box: VBoxContainer
var map_layer: Control
var metabolism_workspace: Control
var queue_box: VBoxContainer
var event_log: RichTextLabel
var music_player: AudioStreamPlayer
var music_button: Button
var membrane_outside_list: VBoxContainer
var membrane_inside_list: VBoxContainer
var membrane_transporter_list: VBoxContainer
var membrane_detail: VBoxContainer
var membrane_band: Control
var selected_membrane_molecule := ""
var selected_membrane_direction := "import"

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().quit()

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
	music_button.text = "♪"
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
	music_player.autoplay = false
	add_child(music_player)

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
		_build_membrane_view()
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
	side.add_child(_section_label("Pathways"))
	pathway_box = VBoxContainer.new()
	side.add_child(pathway_box)

	map_layer = Control.new()
	map_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_layer.clip_contents = true
	layout.add_child(map_layer)
	metabolism_workspace = MetabolismWorkspaceScript.new()
	metabolism_workspace.simulation = sim
	metabolism_workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
	metabolism_workspace.clip_contents = true
	metabolism_workspace.molecule_requested.connect(_handle_molecule_click)
	metabolism_workspace.empty_requested.connect(_handle_empty_metabolism_click)
	map_layer.add_child(metabolism_workspace)

func _build_protein_view() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	content.add_child(box)
	box.add_child(_title("PROTEIN BUILDER", "Designed enzyme blueprints auto-queue here before becoming active in metabolism."))
	queue_box = VBoxContainer.new()
	box.add_child(queue_box)

func _build_membrane_view() -> void:
	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 14)
	content.add_child(layout)

	var outside_panel := _panel_container("OUTSIDE")
	outside_panel.custom_minimum_size = Vector2(300, 0)
	layout.add_child(outside_panel)
	membrane_outside_list = VBoxContainer.new()
	membrane_outside_list.add_theme_constant_override("separation", 8)
	outside_panel.add_child(membrane_outside_list)

	var membrane_panel := _panel_container("MEMBRANE")
	membrane_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(membrane_panel)
	membrane_band = _membrane_band()
	membrane_panel.add_child(membrane_band)
	membrane_detail = VBoxContainer.new()
	membrane_detail.add_theme_constant_override("separation", 10)
	membrane_panel.add_child(membrane_detail)
	membrane_panel.add_child(_section_label("Active Transporters"))
	membrane_transporter_list = VBoxContainer.new()
	membrane_transporter_list.add_theme_constant_override("separation", 8)
	membrane_panel.add_child(membrane_transporter_list)

	var inside_panel := _panel_container("INSIDE CELL")
	inside_panel.custom_minimum_size = Vector2(300, 0)
	layout.add_child(inside_panel)
	membrane_inside_list = VBoxContainer.new()
	membrane_inside_list.add_theme_constant_override("separation", 8)
	inside_panel.add_child(membrane_inside_list)

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
	if sim.active_view == "membrane" and membrane_outside_list != null:
		_refresh_membrane()
	if sim.active_view == "proteins" and queue_box != null:
		_refresh_protein_queue()

func _refresh_membrane() -> void:
	if selected_membrane_molecule.is_empty():
		var outside_ids := sim.outside_molecule_ids()
		if not outside_ids.is_empty():
			selected_membrane_molecule = outside_ids[0]
			selected_membrane_direction = "import"
	_clear(membrane_outside_list)
	for id in sim.outside_molecule_ids():
		membrane_outside_list.add_child(_membrane_molecule_button(id, "outside"))
	_clear(membrane_inside_list)
	for id in sim.present_molecule_ids():
		membrane_inside_list.add_child(_membrane_molecule_button(id, "inside"))
	_refresh_membrane_detail()
	_refresh_transporter_list()
	if membrane_band != null:
		membrane_band.queue_redraw()

func _membrane_molecule_button(id: String, location: String) -> Button:
	var molecule: Dictionary = sim.molecule_types[id]
	var amount := float(sim.outside_amounts.get(id, 0.0)) if location == "outside" else float(sim.molecule_amounts.get(id, 0.0))
	var rates: Dictionary = sim.outside_rates.get(id, {"production": 0.0, "consumption": 0.0}) if location == "outside" else sim.molecule_rates.get(id, {"production": 0.0, "consumption": 0.0})
	var direction := "import" if location == "outside" else "export"
	var button := Button.new()
	button.text = "%s  %.0f\n+%.1f/s  -%.1f/s" % [
		molecule.get("formula", "Molecule"),
		amount,
		float(rates.get("production", 0.0)),
		float(rates.get("consumption", 0.0))
	]
	button.toggle_mode = true
	button.button_pressed = selected_membrane_molecule == id and selected_membrane_direction == direction
	button.custom_minimum_size = Vector2(0, 68)
	button.pressed.connect(func():
		selected_membrane_molecule = id
		selected_membrane_direction = direction
		_refresh_membrane()
	)
	return button

func _refresh_membrane_detail() -> void:
	_clear(membrane_detail)
	if not sim.molecule_types.has(selected_membrane_molecule):
		membrane_detail.add_child(_title("No molecule selected", "Select an outside molecule to build an importer or an inside molecule to build an exporter."))
		return
	var molecule: Dictionary = sim.molecule_types[selected_membrane_molecule]
	var count := sim.transporter_count(selected_membrane_direction, selected_membrane_molecule)
	var queued_count := sim.transporter_queued_count(selected_membrane_direction, selected_membrane_molecule)
	var next_build := sim.transporter_next_build_remaining(selected_membrane_direction, selected_membrane_molecule)
	var rate := sim.transporter_rate(selected_membrane_direction, selected_membrane_molecule)
	var action := "Importer" if selected_membrane_direction == "import" else "Exporter"
	var queue_text := " | %d building" % queued_count if queued_count > 0 else ""
	var build_text := " | next %.1fs" % next_build if queued_count > 0 else ""
	membrane_detail.add_child(_title("%s %s" % [molecule.get("formula", "Molecule"), action], "%d active%s | %.1f molecules/s%s" % [count, queue_text, rate, build_text]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var build := Button.new()
	build.text = "+ Queue Build"
	build.custom_minimum_size = Vector2(128, 44)
	build.pressed.connect(func():
		sim.build_transporter(selected_membrane_direction, selected_membrane_molecule)
	)
	row.add_child(build)
	var remove := Button.new()
	remove.text = "- Destroy"
	remove.custom_minimum_size = Vector2(128, 44)
	remove.disabled = count <= 0
	remove.pressed.connect(func():
		sim.destroy_transporter(selected_membrane_direction, selected_membrane_molecule)
	)
	row.add_child(remove)
	membrane_detail.add_child(row)
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(260, 150)
	canvas.set_molecule(molecule)
	membrane_detail.add_child(canvas)

func _refresh_transporter_list() -> void:
	_clear(membrane_transporter_list)
	var list := sim.transporter_list()
	if list.is_empty():
		membrane_transporter_list.add_child(_title("No transporters", "Build importers or exporters from the molecule lists."))
		return
	for transporter in list:
		membrane_transporter_list.add_child(_transporter_card(transporter))

func _transporter_card(transporter: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var molecule_id: String = transporter.get("molecule", "")
	var molecule: Dictionary = sim.molecule_types.get(molecule_id, {})
	var name := Label.new()
	name.text = "%s %s" % [str(transporter.get("direction", "transport")).capitalize(), molecule.get("formula", "Molecule")]
	name.add_theme_font_size_override("font_size", 16)
	name.modulate = Color("76f4ff")
	box.add_child(name)
	var detail := Label.new()
	var queued_count := int(transporter.get("queued_count", 0))
	var build_text := " | %d building" % queued_count if queued_count > 0 else ""
	detail.text = "%d active%s | %.1f/s total" % [int(transporter.get("count", 0)), build_text, float(transporter.get("rate", 0.0))]
	detail.modulate = Color(0.72, 0.84, 0.82)
	box.add_child(detail)
	return box

func _membrane_band() -> Control:
	var band := MembraneBand.new()
	band.simulation = sim
	band.custom_minimum_size = Vector2(0, 96)
	return band

func _refresh_metabolism() -> void:
	_clear(molecule_list)
	for id in sim.present_molecule_ids():
		molecule_list.add_child(_molecule_list_button(id))
	_refresh_selection_detail()
	_refresh_pathways()
	if metabolism_workspace != null:
		metabolism_workspace.rebuild()

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
	button.pressed.connect(func(): _handle_molecule_click(id))
	return button

func _refresh_selection_detail() -> void:
	_clear(detail_panel)
	if not sim.molecule_types.has(sim.selected_molecule):
		detail_panel.add_child(_title("No molecule selected", "Click a molecule once to select it, then click it again to design an enzyme."))
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
			_handle_molecule_click(sim.selected_molecule)
	)
	detail_panel.add_child(canvas)
	var button := Button.new()
	button.text = "Design Enzyme"
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(func(): _open_enzyme_designer(sim.selected_molecule))
	detail_panel.add_child(button)

func _refresh_pathways() -> void:
	_clear(pathway_box)
	var pathways := sim.pathway_list()
	if pathways.is_empty():
		pathway_box.add_child(_title("No enzyme pathway", "Click glucose, choose an enzyme class, select a highlighted bond, then queue the blueprint."))
		return
	for pathway in pathways:
		pathway_box.add_child(_pathway_card(pathway))

func _pathway_card(pathway: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var name := Label.new()
	name.text = pathway.get("name", "Enzyme")
	name.add_theme_font_size_override("font_size", 16)
	name.modulate = Color("76f4ff")
	box.add_child(name)
	var product_labels: Array[String] = []
	for product_id in pathway.get("products", []):
		if sim.molecule_types.has(product_id):
			product_labels.append(sim.molecule_types[product_id].get("formula", "Product"))
	var status := Label.new()
	status.text = "%s | %s -> %s" % [
		pathway.get("status", "Designed"),
		sim.molecule_types[pathway.get("substrate", "")].get("formula", "Substrate") if sim.molecule_types.has(pathway.get("substrate", "")) else "Substrate",
		" + ".join(product_labels)
	]
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.modulate = Color(0.78, 0.88, 0.86)
	box.add_child(status)
	var details := Label.new()
	var build_text := ""
	if int(pathway.get("queued_count", 0)) > 0:
		build_text = " | build %.1fs" % float(pathway.get("next_build_remaining", 0.0))
	details.text = "Rate %.2f/s | Enzymes %d%s" % [
		float(pathway.get("rate", 0.0)),
		int(pathway.get("active_count", 0)),
		build_text
	]
	details.modulate = Color(0.68, 0.78, 0.76)
	box.add_child(details)
	return box

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

func _handle_molecule_click(molecule_id: String) -> void:
	if sim.selected_molecule == molecule_id:
		_open_enzyme_designer(molecule_id)
	else:
		sim.select_molecule(molecule_id)

func _handle_empty_metabolism_click() -> void:
	sim.deselect_molecule()

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
		designer_preview.add_child(_title("Select Target", "%d highlighted bonds can be modified by %s." % [designer_canvas.valid_targets.size(), designer_tool.capitalize()]))
		return
	var summary := sim.enzyme_preview_summary(designer_tool, sim.selected_molecule, designer_target)
	var products := sim.product_preview_info(designer_tool, sim.selected_molecule, designer_target)
	var summary_panel := VBoxContainer.new()
	summary_panel.custom_minimum_size = Vector2(240, 180)
	summary_panel.add_child(_title(summary.get("name", "Enzyme Blueprint"), "kcat %.2f/s | stability %.0fs | build %.0fs" % [
		float(summary.get("kcat", 0.0)),
		float(summary.get("stability", 0.0)),
		float(summary.get("build_time", 0.0))
	]))
	var kept_products: Array = summary.get("products", [])
	var kept_label := Label.new()
	kept_label.text = "Products: %s" % (" + ".join(kept_products) if not kept_products.is_empty() else "none")
	kept_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_panel.add_child(kept_label)
	if int(summary.get("gas_products", 0)) > 0:
		var gas := Label.new()
		gas.text = "CO2 escape: %d fragment" % int(summary.get("gas_products", 0))
		gas.modulate = Color("ffe064")
		summary_panel.add_child(gas)
	designer_preview.add_child(summary_panel)
	for product_info in products:
		var product: Dictionary = product_info.get("graph", {})
		var panel := VBoxContainer.new()
		panel.custom_minimum_size = Vector2(220, 180)
		var canvas = MoleculeCanvasScript.new()
		canvas.custom_minimum_size = Vector2(220, 140)
		canvas.set_molecule(product)
		if bool(product_info.get("escapes", false)):
			canvas.modulate = Color(1, 1, 1, 0.45)
		panel.add_child(canvas)
		var label := Label.new()
		label.text = "%s -> escapes as CO2" % product.get("formula", "Product") if bool(product_info.get("escapes", false)) else product.get("formula", "Product")
		label.modulate = Color("ffe064") if bool(product_info.get("escapes", false)) else Color(0.9, 0.96, 0.95)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(label)
		designer_preview.add_child(panel)
	var confirm := Button.new()
	confirm.text = "Create Blueprint + Queue Protein"
	confirm.custom_minimum_size = Vector2(240, 64)
	confirm.disabled = kept_products.is_empty()
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

func _panel_container(title_text: String) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color("76f4ff")
	panel.add_child(title)
	return panel

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

class MembraneBand:
	extends Control

	var simulation

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("10292d"), true)
		var center_y := size.y * 0.5
		var top := center_y - 18.0
		var bottom := center_y + 18.0
		draw_line(Vector2(0, top), Vector2(size.x, top), Color("76f4ff"), 2.0, true)
		draw_line(Vector2(0, bottom), Vector2(size.x, bottom), Color("76f4ff"), 2.0, true)
		for x in range(20, int(size.x), 34):
			draw_circle(Vector2(x, top), 8.0, Color("4a90df"))
			draw_circle(Vector2(x + 16, bottom), 8.0, Color("a34ed0"))
		draw_string(ThemeDB.fallback_font, Vector2(18, center_y + 5), "TRANSPORTER MEMBRANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f4fbff"))
		if simulation == null:
			return
		var arrows: Array = simulation.membrane_transport_arrows()
		var start_x := maxf(220.0, size.x * 0.32)
		var spacing := 74.0
		for i in min(arrows.size(), 6):
			var arrow: Dictionary = arrows[i]
			var x: float = start_x + i * spacing
			var import_direction: bool = arrow.get("direction", "") == "import"
			var from := Vector2(x, top - 24.0 if import_direction else bottom + 24.0)
			var to := Vector2(x, bottom + 24.0 if import_direction else top - 24.0)
			var color := Color("8cff6a") if import_direction else Color("ffe064")
			draw_line(from, to, Color("02070b"), 8.0, true)
			draw_line(from, to, color, 4.0, true)
			var dir := (to - from).normalized()
			var left := to - dir * 12.0 + Vector2(-dir.y, dir.x) * 7.0
			var right := to - dir * 12.0 - Vector2(-dir.y, dir.x) * 7.0
			draw_colored_polygon(PackedVector2Array([to, left, right]), color)
			draw_string(ThemeDB.fallback_font, Vector2(x - 22.0, center_y + 36.0), "%s x%d" % [arrow.get("formula", ""), int(arrow.get("count", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
