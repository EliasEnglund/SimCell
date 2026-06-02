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
var protein_template_box: VBoxContainer
var protein_completed_box: VBoxContainer
var protein_summary_box: VBoxContainer
var event_log: RichTextLabel
var music_player: AudioStreamPlayer
var music_button: Button
var membrane_outside_list: VBoxContainer
var membrane_inside_list: VBoxContainer
var membrane_transporter_list: VBoxContainer
var membrane_import_detail: VBoxContainer
var membrane_export_detail: VBoxContainer
var membrane_scene: Control
var selected_membrane_molecule := ""
var selected_membrane_direction := "import"
var selected_pathway := ""

var designer_tool := "lyase"
var designer_target := -1
var designer_preview: HBoxContainer
var designer_canvas: Control
var designer_info_panel: VBoxContainer

func _ready() -> void:
	sim.changed.connect(_refresh)
	sim.event_logged.connect(_log_event)
	_setup_music()
	_build_title_screen()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause_toggle"):
		sim.toggle_pause()
	sim.tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func _build_title_screen() -> void:
	var title_root := Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title_root)
	var artwork := TextureRect.new()
	var title_image := Image.load_from_file("res://assets/reference/title-art-v2.png")
	if title_image != null:
		artwork.texture = ImageTexture.create_from_image(title_image)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.set_anchors_preset(Control.PRESET_FULL_RECT)
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(artwork)
	var shade := TitleShade.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(shade)
	var frame := TitleTopFrame.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(frame)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 74)
	margin.add_theme_constant_override("margin_top", 104)
	margin.add_theme_constant_override("margin_right", 74)
	margin.add_theme_constant_override("margin_bottom", 78)
	title_root.add_child(margin)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(510, 360)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 16)
	margin.add_child(menu)
	var title := Label.new()
	title.text = "SIM CELL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 72)
	title.modulate = Color("76f4ff")
	menu.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Build metabolism. Design enzymes. Shape a living cell."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.modulate = Color(0.78, 0.9, 0.88)
	menu.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	menu.add_child(spacer)
	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(300, 58)
	play.add_theme_font_size_override("font_size", 22)
	play.add_theme_stylebox_override("normal", _nav_style(false))
	play.add_theme_stylebox_override("hover", _nav_style(true))
	play.add_theme_stylebox_override("pressed", _nav_style(true))
	play.pressed.connect(func():
		title_root.queue_free()
		_build_shell()
		_show_view("metabolism")
	)
	menu.add_child(play)
	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(300, 52)
	quit.add_theme_font_size_override("font_size", 22)
	quit.add_theme_stylebox_override("normal", _nav_style(false))
	quit.add_theme_stylebox_override("hover", _nav_style(true))
	quit.add_theme_stylebox_override("pressed", _nav_style(true))
	quit.pressed.connect(func(): get_tree().quit())
	menu.add_child(quit)

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
		["⇄", "Membrane", "membrane"],
		["▤", "Proteins", "proteins"],
		["⌁", "DNA", "dna"]
	]:
		var button := Button.new()
		button.text = "%s\n%s" % [item[0], item[1]]
		button.custom_minimum_size = Vector2(142, 58)
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_stylebox_override("normal", _nav_style(false))
		button.add_theme_stylebox_override("hover", _nav_style(true))
		button.add_theme_stylebox_override("pressed", _nav_style(true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	metabolism_workspace.pathway_requested.connect(_handle_pathway_click)
	metabolism_workspace.empty_requested.connect(_handle_empty_metabolism_click)
	map_layer.add_child(metabolism_workspace)

func _build_protein_view() -> void:
	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 12)
	content.add_child(layout)

	var left := _glow_panel("PROTEIN SYNTHESIS CONTROL")
	left.custom_minimum_size = Vector2(330, 0)
	layout.add_child(left)
	protein_summary_box = VBoxContainer.new()
	protein_summary_box.add_theme_constant_override("separation", 8)
	left.add_child(protein_summary_box)
	left.add_child(_section_label("mRNA Templates"))
	protein_template_box = VBoxContainer.new()
	protein_template_box.add_theme_constant_override("separation", 8)
	left.add_child(protein_template_box)
	left.add_child(_section_label("Cytoplasmic Context"))
	left.add_child(ProteinContextDish.new())

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10)
	layout.add_child(center)
	center.add_child(_protein_screen_title())
	queue_box = VBoxContainer.new()
	queue_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_box.add_theme_constant_override("separation", 12)
	center.add_child(queue_box)

	var right := _glow_panel("CELLULAR PROTEOME")
	right.custom_minimum_size = Vector2(300, 0)
	layout.add_child(right)
	right.add_child(_section_label("Completed Proteins"))
	protein_completed_box = VBoxContainer.new()
	protein_completed_box.add_theme_constant_override("separation", 8)
	right.add_child(protein_completed_box)

func _build_membrane_view() -> void:
	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 12)
	content.add_child(layout)

	var outside_panel := _panel_container("OUTSIDE")
	outside_panel.custom_minimum_size = Vector2(280, 0)
	layout.add_child(outside_panel)
	outside_panel.add_child(_title("Environment", "Select a molecule outside the cell to build importers."))
	membrane_outside_list = VBoxContainer.new()
	membrane_outside_list.add_theme_constant_override("separation", 8)
	outside_panel.add_child(membrane_outside_list)
	outside_panel.add_child(_section_label("Importer Builder"))
	membrane_import_detail = VBoxContainer.new()
	membrane_import_detail.add_theme_constant_override("separation", 10)
	outside_panel.add_child(membrane_import_detail)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 10)
	layout.add_child(center)
	center.add_child(_section_label("Membrane Cross-Section"))
	membrane_scene = _membrane_cross_section()
	center.add_child(membrane_scene)
	center.add_child(_section_label("Active Transporters"))
	membrane_transporter_list = VBoxContainer.new()
	membrane_transporter_list.add_theme_constant_override("separation", 8)
	center.add_child(membrane_transporter_list)

	var inside_panel := _panel_container("INSIDE CELL")
	inside_panel.custom_minimum_size = Vector2(300, 0)
	layout.add_child(inside_panel)
	inside_panel.add_child(_title("Cytoplasm", "Select a molecule inside the cell to build exporters."))
	membrane_inside_list = VBoxContainer.new()
	membrane_inside_list.add_theme_constant_override("separation", 8)
	inside_panel.add_child(membrane_inside_list)
	inside_panel.add_child(_section_label("Exporter Builder"))
	membrane_export_detail = VBoxContainer.new()
	membrane_export_detail.add_theme_constant_override("separation", 10)
	inside_panel.add_child(membrane_export_detail)

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
	if membrane_scene != null:
		membrane_scene.update_from_simulation()

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
	_clear(membrane_import_detail)
	_clear(membrane_export_detail)
	if not sim.molecule_types.has(selected_membrane_molecule):
		membrane_import_detail.add_child(_title("No molecule selected", ""))
		membrane_export_detail.add_child(_title("No molecule selected", ""))
		return
	var molecule: Dictionary = sim.molecule_types[selected_membrane_molecule]
	var count := sim.transporter_count(selected_membrane_direction, selected_membrane_molecule)
	var queued_count := sim.transporter_queued_count(selected_membrane_direction, selected_membrane_molecule)
	var next_build := sim.transporter_next_build_remaining(selected_membrane_direction, selected_membrane_molecule)
	var rate := sim.transporter_rate(selected_membrane_direction, selected_membrane_molecule)
	var action := "Importer" if selected_membrane_direction == "import" else "Exporter"
	var queue_text := " | %d building" % queued_count if queued_count > 0 else ""
	var build_text := " | next %.1fs" % next_build if queued_count > 0 else ""
	var target_detail := membrane_import_detail if selected_membrane_direction == "import" else membrane_export_detail
	var idle_detail := membrane_export_detail if selected_membrane_direction == "import" else membrane_import_detail
	idle_detail.add_child(_title("No molecule selected", ""))
	target_detail.add_child(_title("%s %s" % [molecule.get("formula", "Molecule"), action], "%d active%s | %.1f molecules/s%s" % [count, queue_text, rate, build_text]))
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
	target_detail.add_child(row)
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(260, 150)
	canvas.set_molecule(molecule)
	target_detail.add_child(canvas)

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

func _membrane_cross_section() -> Control:
	var scene := MembraneCrossSection.new()
	scene.simulation = sim
	scene.custom_minimum_size = Vector2(0, 430)
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.clip_contents = true
	return scene

func _refresh_metabolism() -> void:
	_clear(molecule_list)
	for id in sim.present_molecule_ids():
		molecule_list.add_child(_molecule_list_button(id))
	_refresh_selection_detail()
	_refresh_pathways()
	if metabolism_workspace != null:
		metabolism_workspace.selected_pathway = selected_pathway
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
	if sim.enzyme_blueprints.has(selected_pathway):
		_refresh_pathway_detail(selected_pathway)
		return
	if not sim.molecule_types.has(sim.selected_molecule):
		detail_panel.add_child(_title("No selection", "Click a molecule to design enzymes, or click an enzyme step box to manage that pathway."))
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

func _refresh_pathway_detail(blueprint_id: String) -> void:
	var pathway := _pathway_by_id(blueprint_id)
	if pathway.is_empty():
		detail_panel.add_child(_title("Pathway unavailable", "The selected enzyme pathway no longer exists."))
		return
	var product_labels: Array[String] = []
	for product_id in pathway.get("products", []):
		if sim.molecule_types.has(product_id):
			product_labels.append(sim.molecule_types[product_id].get("formula", "Product"))
	var substrate_id: String = pathway.get("substrate", "")
	var substrate_formula: String = sim.molecule_types[substrate_id].get("formula", "Substrate") if sim.molecule_types.has(substrate_id) else "Substrate"
	detail_panel.add_child(_title(pathway.get("name", "Enzyme"), "%s -> %s" % [substrate_formula, " + ".join(product_labels)]))
	var metrics := Label.new()
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metrics.modulate = Color(0.78, 0.88, 0.86)
	metrics.text = "Status %s | Rate %.2f/s\nActive %d | Queued %d | kcat %.2f/s | Stability %.0fs" % [
		pathway.get("status", "Designed"),
		float(pathway.get("rate", 0.0)),
		int(pathway.get("active_count", 0)),
		int(pathway.get("queued_count", 0)),
		float(pathway.get("kcat", 0.0)),
		float(pathway.get("stability", 0.0))
	]
	detail_panel.add_child(metrics)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var build_one := Button.new()
	build_one.text = "+ Build 1"
	build_one.custom_minimum_size = Vector2(0, 42)
	build_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_one.pressed.connect(func():
		sim.queue_enzyme_build(blueprint_id, 1)
	)
	row.add_child(build_one)
	var build_five := Button.new()
	build_five.text = "+ Build 5"
	build_five.custom_minimum_size = Vector2(0, 42)
	build_five.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_five.pressed.connect(func():
		sim.queue_enzyme_build(blueprint_id, 5)
	)
	row.add_child(build_five)
	detail_panel.add_child(row)
	var remove := Button.new()
	remove.text = "Destroy 1 Active Enzyme"
	remove.custom_minimum_size = Vector2(0, 42)
	remove.disabled = int(pathway.get("active_count", 0)) <= 0
	remove.pressed.connect(func():
		sim.destroy_active_enzyme(blueprint_id)
	)
	detail_panel.add_child(remove)
	var hint := Label.new()
	hint.text = "Queued enzymes appear in Protein Builder, then become active here when synthesis completes."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.68, 0.78, 0.76)
	detail_panel.add_child(hint)

func _refresh_pathways() -> void:
	_clear(pathway_box)
	var pathways := sim.pathway_list()
	if pathways.is_empty():
		pathway_box.add_child(_title("No enzyme pathway", "Click glucose, choose an enzyme class, select a highlighted bond, then queue the blueprint."))
		return
	for pathway in pathways:
		pathway_box.add_child(_pathway_card(pathway))

func _pathway_card(pathway: Dictionary) -> VBoxContainer:
	var box := GlowVBox.new()
	box.fill = Color("1b3440") if selected_pathway == str(pathway.get("id", "")) else Color("142531")
	box.border = Color("76f4ff") if selected_pathway == str(pathway.get("id", "")) else Color("2f7080")
	box.border_width = 1.2
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
	var select := Button.new()
	select.text = "Manage"
	select.custom_minimum_size = Vector2(0, 32)
	select.pressed.connect(func():
		_handle_pathway_click(str(pathway.get("id", "")))
	)
	box.add_child(select)
	return box

func _pathway_by_id(blueprint_id: String) -> Dictionary:
	for pathway in sim.pathway_list():
		if str(pathway.get("id", "")) == blueprint_id:
			return pathway
	return {}

func _open_enzyme_designer(molecule_id: String) -> void:
	sim.select_molecule(molecule_id)
	sim.active_view = "enzyme_designer"
	_clear(content)
	var designer_root := Control.new()
	designer_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(designer_root)
	var background := ColorRect.new()
	background.color = Color("10292d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	designer_root.add_child(background)
	var title_bar := DesignerTitleFrame.new()
	title_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	designer_root.add_child(title_bar)

	var shell := HBoxContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 24
	shell.offset_top = 54
	shell.offset_right = -24
	shell.offset_bottom = -12
	shell.add_theme_constant_override("separation", 34)
	designer_root.add_child(shell)

	var tools_panel := PanelContainer.new()
	tools_panel.custom_minimum_size = Vector2(360, 0)
	tools_panel.add_theme_stylebox_override("panel", _glow_panel_style(Color("101927"), Color("7adfff"), 3.0, 10))
	shell.add_child(tools_panel)
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 13)
	tools.offset_left = 18
	tools.offset_top = 18
	tools.offset_right = -18
	tools.offset_bottom = -18
	tools_panel.add_child(tools)
	var tools_title := Label.new()
	tools_title.text = "ENZYME FUNCTION"
	tools_title.add_theme_font_size_override("font_size", 26)
	tools_title.modulate = Color("76f4ff")
	tools.add_child(tools_title)
	tools.add_child(_tool_button("lyase", "✂", "LYASE"))
	tools.add_child(_tool_button("reductase", "=", "REDUCTASE"))
	tools.add_child(_locked_tool_card("DECARBOXYLASE"))
	tools.add_child(_locked_tool_card("SULFUR TRANSFERASE"))

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	shell.add_child(center)
	var top_spacer := HBoxContainer.new()
	top_spacer.custom_minimum_size = Vector2(0, 30)
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(top_spacer)
	designer_canvas = MoleculeCanvasScript.new()
	designer_canvas.custom_minimum_size = Vector2(760, 360)
	designer_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	designer_canvas.interactive = true
	designer_canvas.physical_touch = true
	designer_canvas.target_selected.connect(_designer_target_selected)
	center.add_child(designer_canvas)
	designer_preview = HBoxContainer.new()
	designer_preview.custom_minimum_size = Vector2(0, 210)
	designer_preview.add_theme_constant_override("separation", 12)
	center.add_child(designer_preview)

	var info_stack := VBoxContainer.new()
	info_stack.custom_minimum_size = Vector2(300, 0)
	info_stack.add_theme_constant_override("separation", 14)
	shell.add_child(info_stack)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 40)
	back.pressed.connect(func(): _show_view("metabolism"))
	info_stack.add_child(back)
	designer_info_panel = VBoxContainer.new()
	designer_info_panel.add_theme_constant_override("separation", 9)
	info_stack.add_child(designer_info_panel)
	_refresh_designer()

func _handle_molecule_click(molecule_id: String) -> void:
	selected_pathway = ""
	if sim.selected_molecule == molecule_id:
		_open_enzyme_designer(molecule_id)
	else:
		sim.select_molecule(molecule_id)

func _handle_pathway_click(blueprint_id: String) -> void:
	if not sim.enzyme_blueprints.has(blueprint_id):
		return
	selected_pathway = blueprint_id
	sim.deselect_molecule()
	_refresh()

func _handle_empty_metabolism_click() -> void:
	selected_pathway = ""
	sim.deselect_molecule()

func _tool_button(id: String, icon: String, label_text: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [icon, label_text]
	button.custom_minimum_size = Vector2(0, 112)
	button.toggle_mode = true
	button.button_pressed = designer_tool == id
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _tool_style(false))
	button.add_theme_stylebox_override("hover", _tool_style(true))
	button.add_theme_stylebox_override("pressed", _tool_style(true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func():
		designer_tool = id
		designer_target = -1
		_refresh_designer()
	)
	return button

func _locked_tool_card(label_text: String) -> Button:
	var button := Button.new()
	button.text = "\n%s" % label_text
	button.disabled = true
	button.custom_minimum_size = Vector2(0, 112)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("disabled", _tool_style(false))
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
	_refresh_designer_info(molecule)
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

func _refresh_designer_info(molecule: Dictionary) -> void:
	if designer_info_panel == null:
		return
	_clear(designer_info_panel)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _glow_panel_style(Color("263b4a"), Color("7adfff"), 2.0, 8))
	designer_info_panel.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.offset_left = 16
	box.offset_top = 14
	box.offset_right = -16
	box.offset_bottom = -14
	card.add_child(box)
	var formula := Label.new()
	formula.text = molecule.get("formula", "Molecule")
	formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	formula.add_theme_font_size_override("font_size", 32)
	formula.modulate = Color("f4fbff")
	formula.add_theme_stylebox_override("normal", _formula_badge_style())
	box.add_child(formula)
	var name := Label.new()
	name.text = "NAME: %s" % str(molecule.get("name", "Molecule")).to_upper()
	name.add_theme_font_size_override("font_size", 18)
	box.add_child(name)
	var amount := Label.new()
	amount.text = "Nr: %.0f" % float(sim.molecule_amounts.get(sim.selected_molecule, 0.0))
	amount.add_theme_font_size_override("font_size", 18)
	box.add_child(amount)
	var rates: Dictionary = sim.molecule_rates.get(sim.selected_molecule, {"production": 0.0, "consumption": 0.0})
	var change := Label.new()
	change.text = "Change: %+.1f/s" % (float(rates.get("production", 0.0)) - float(rates.get("consumption", 0.0)))
	change.add_theme_font_size_override("font_size", 18)
	box.add_child(change)
	var toxicity_label := Label.new()
	toxicity_label.text = "Toxicity: None"
	toxicity_label.add_theme_font_size_override("font_size", 18)
	box.add_child(toxicity_label)

func _glow_panel_style(fill: Color, border: Color, width: float, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border.r, border.g, border.b, 0.35)
	style.shadow_size = 10
	style.content_margin_left = 18
	style.content_margin_top = 18
	style.content_margin_right = 18
	style.content_margin_bottom = 18
	return style

func _tool_style(active: bool) -> StyleBoxFlat:
	var style := _glow_panel_style(Color("243b4b") if active else Color("253747"), Color("73dfff"), 1.5, 8)
	style.shadow_size = 8 if active else 4
	return style

func _nav_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1f3340") if active else Color("142531")
	style.border_color = Color("76f4ff") if active else Color("2f7080")
	style.set_border_width_all(1.5)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.45, 0.95, 1.0, 0.22 if active else 0.10)
	style.shadow_size = 7 if active else 3
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	return style

func _formula_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("c8c8c8")
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func _restore_main_shell() -> void:
	_show_view("metabolism")

func _refresh_protein_queue() -> void:
	_clear(protein_summary_box)
	_clear(protein_template_box)
	_clear(queue_box)
	_clear(protein_completed_box)
	var active_ribosomes: int = sim.protein_queue.size()
	var completed_count := 0
	for count in sim.active_enzymes.values():
		completed_count += int(count)
	var speed := 1.0 + minf(1.5, float(completed_count) * 0.05)
	protein_summary_box.add_child(_title("Active Ribosomes: %d" % active_ribosomes, "Overall synthesis speed: x%.1f" % speed))
	protein_summary_box.add_child(_protein_metric_row("Blueprints", sim.enzyme_blueprints.size(), "Completed", completed_count))
	var pathways := sim.pathway_list()
	if pathways.is_empty():
		protein_template_box.add_child(_title("No templates", "Design an enzyme from metabolism to create the first mRNA template."))
	else:
		var index := 1
		for pathway in pathways:
			protein_template_box.add_child(_protein_template_card(pathway, index))
			index += 1
	if sim.protein_queue.is_empty():
		queue_box.add_child(_empty_ribosome_card())
	var ribosome_index := 1
	for item in sim.protein_queue:
		var duration := maxf(0.01, float(item.get("duration", 1.0)))
		var progress := clampf(1.0 - float(item.get("remaining", 0.0)) / duration, 0.0, 1.0)
		queue_box.add_child(_ribosome_card(item, ribosome_index, progress))
		ribosome_index += 1
	var completed_any := false
	for pathway in pathways:
		var count := int(pathway.get("active_count", 0))
		if count <= 0:
			continue
		completed_any = true
		protein_completed_box.add_child(_completed_protein_card(pathway, count))
	if not completed_any:
		protein_completed_box.add_child(_title("No completed proteins", "Queued ribosomes will add active enzymes here when synthesis finishes."))

func _protein_screen_title() -> Control:
	var frame := DesignerTitleFrame.new()
	frame.custom_minimum_size = Vector2(0, 54)
	var label := Label.new()
	label.text = "CELLULAR ARCHITECT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = Color("76f4ff")
	frame.add_child(label)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	return frame

func _glow_panel(title_text: String) -> VBoxContainer:
	var panel := GlowVBox.new()
	panel.fill = Color(0.07, 0.13, 0.17, 0.78)
	panel.border = Color("73dfff")
	panel.border_width = 1.5
	panel.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color("9defff")
	panel.add_child(title)
	return panel

func _protein_metric_row(left_label: String, left_value: int, right_label: String, right_value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_metric_pill(left_label, str(left_value)))
	row.add_child(_metric_pill(right_label, str(right_value)))
	return row

func _metric_pill(label_text: String, value_text: String) -> VBoxContainer:
	var box := GlowVBox.new()
	box.fill = Color("152a34")
	box.border = Color("2f7080")
	box.border_width = 1.0
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	label.modulate = Color(0.72, 0.84, 0.82)
	box.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 20)
	value.modulate = Color("8cff6a")
	box.add_child(value)
	return box

func _protein_template_card(pathway: Dictionary, index: int) -> HBoxContainer:
	var row := GlowHBox.new()
	row.fill = Color("142531")
	row.border = Color("2f7080")
	row.border_width = 1.0
	row.custom_minimum_size = Vector2(0, 64)
	row.add_theme_constant_override("separation", 8)
	var icon := ProteinGlyph.new()
	icon.kind = str(pathway.get("tool", "enzyme"))
	icon.custom_minimum_size = Vector2(54, 54)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title := Label.new()
	title.text = "%d. %s" % [index, pathway.get("name", "Enzyme")]
	title.add_theme_font_size_override("font_size", 15)
	text.add_child(title)
	var queued := int(pathway.get("queued_count", 0))
	var active := int(pathway.get("active_count", 0))
	var status := str(pathway.get("status", "Designed"))
	var detail := Label.new()
	detail.text = "%s | active %d | queued %d" % [status, active, queued]
	detail.modulate = Color(0.72, 0.84, 0.82)
	text.add_child(detail)
	return row

func _ribosome_card(item: Dictionary, index: int, progress: float) -> VBoxContainer:
	var card := GlowVBox.new()
	card.fill = Color(0.07, 0.16, 0.19, 0.84)
	card.border = Color("73dfff")
	card.border_width = 1.6
	card.custom_minimum_size = Vector2(0, 118)
	card.add_theme_constant_override("separation", 8)
	var header := Label.new()
	header.text = "RIBOSOME %d: ENZYME SYNTHESIS" % index
	header.add_theme_font_size_override("font_size", 19)
	header.modulate = Color("9defff")
	card.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var icon := ProteinGlyph.new()
	icon.kind = str(item.get("name", "enzyme"))
	icon.custom_minimum_size = Vector2(68, 68)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 8)
	row.add_child(text)
	var name := Label.new()
	name.text = "Synthesis: %s" % item.get("name", "Enzyme")
	name.add_theme_font_size_override("font_size", 18)
	text.add_child(name)
	var bar := ProgressBar.new()
	bar.value = progress * 100.0
	bar.show_percentage = true
	bar.custom_minimum_size = Vector2(0, 30)
	bar.add_theme_stylebox_override("background", _progress_style(false))
	bar.add_theme_stylebox_override("fill", _progress_style(true))
	text.add_child(bar)
	var remaining := Label.new()
	remaining.text = "%.1fs remaining | %.0f%% done" % [float(item.get("remaining", 0.0)), progress * 100.0]
	remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	remaining.modulate = Color(0.78, 0.9, 0.82)
	text.add_child(remaining)
	return card

func _empty_ribosome_card() -> VBoxContainer:
	var card := GlowVBox.new()
	card.fill = Color(0.06, 0.12, 0.15, 0.72)
	card.border = Color("2f7080")
	card.border_width = 1.2
	card.custom_minimum_size = Vector2(0, 118)
	card.add_child(_title("No active ribosomes", "Design an enzyme in the metabolism view to queue protein synthesis."))
	return card

func _completed_protein_card(pathway: Dictionary, count: int) -> HBoxContainer:
	var row := GlowHBox.new()
	row.fill = Color("142531")
	row.border = Color("2f7080")
	row.border_width = 1.0
	row.custom_minimum_size = Vector2(0, 72)
	row.add_theme_constant_override("separation", 10)
	var icon := ProteinGlyph.new()
	icon.kind = str(pathway.get("tool", "enzyme"))
	icon.custom_minimum_size = Vector2(58, 58)
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var name := Label.new()
	name.text = pathway.get("name", "Enzyme")
	name.add_theme_font_size_override("font_size", 15)
	labels.add_child(name)
	var detail := Label.new()
	detail.text = "Active count x%d | %.2f/s" % [count, float(pathway.get("rate", 0.0))]
	detail.modulate = Color(0.72, 0.84, 0.82)
	labels.add_child(detail)
	return row

func _progress_style(fill: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("76f4ff") if fill else Color("10202a")
	style.border_color = Color("b8fbff") if fill else Color("477988")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.45, 0.95, 1.0, 0.24 if fill else 0.08)
	style.shadow_size = 7 if fill else 2
	return style

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

class GlowVBox:
	extends VBoxContainer

	var fill := Color("142531")
	var border := Color("73dfff")
	var border_width := 1.2

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size).grow(-2.0)
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(border.r, border.g, border.b, 0.18), false, border_width + 7.0)
		draw_rect(rect, border, false, border_width)

class GlowHBox:
	extends HBoxContainer

	var fill := Color("142531")
	var border := Color("73dfff")
	var border_width := 1.2

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size).grow(-2.0)
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(border.r, border.g, border.b, 0.16), false, border_width + 6.0)
		draw_rect(rect, border, false, border_width)

class ProteinGlyph:
	extends Control

	var kind := "enzyme"

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.33
		var seed := float(abs(kind.hash() % 1000)) / 1000.0
		draw_circle(center, radius + 7.0, Color("02070b"))
		draw_circle(center, radius + 3.0, Color("243b4b"))
		var colors := [Color("8cff6a"), Color("76f4ff"), Color("a34ed0"), Color("ffe064"), Color("e95058")]
		for i in 8:
			var angle := seed * TAU + float(i) * TAU / 8.0
			var arm := Vector2(cos(angle), sin(angle)) * radius * (0.42 + 0.25 * sin(float(i) + seed * 8.0))
			var p := center + arm
			var color: Color = colors[(i + int(seed * 10.0)) % colors.size()]
			draw_circle(p, radius * 0.28, Color("02070b"))
			draw_circle(p, radius * 0.22, color.darkened(0.08))
			draw_circle(p + Vector2(radius * 0.06, -radius * 0.08), radius * 0.07, Color(1, 1, 1, 0.35))
			if i > 0:
				var prev_angle := seed * TAU + float(i - 1) * TAU / 8.0
				var prev := center + Vector2(cos(prev_angle), sin(prev_angle)) * radius * 0.50
				draw_line(prev, p, Color(0.8, 0.95, 0.95, 0.24), 3.0, true)
		draw_circle(center, radius * 0.28, Color("02070b"))
		draw_circle(center, radius * 0.21, Color("728186").lightened(0.2))

class ProteinContextDish:
	extends Control

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 150)

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y * 0.58)
		var rx := size.x * 0.36
		var ry := size.y * 0.28
		_draw_dish_ellipse(center, rx, ry, Color(0.04, 0.08, 0.1, 0.70))
		_draw_dish_arc(center, rx, ry, 0.0, TAU, 80, Color("8db9c4"), 2.0)
		_draw_dish_arc(center + Vector2(0, 8), rx * 0.94, ry * 0.72, 0.0, PI, 60, Color(0.45, 0.95, 1.0, 0.22), 2.0)
		for i in 10:
			var t := float(i) / 10.0
			var angle := t * TAU + 0.4
			var pos := center + Vector2(cos(angle) * rx * (0.25 + fmod(t * 2.3, 0.55)), sin(angle) * ry * 0.55)
			draw_circle(pos, 13.0, Color("02070b"))
			draw_circle(pos, 10.0, Color("243b4b"))
			if i % 3 == 0:
				draw_circle(pos, 5.0, Color("8cff6a"))

	func _draw_dish_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 80:
			var angle := float(i) / 80.0 * TAU
			points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_colored_polygon(points, color)

	func _draw_dish_arc(center: Vector2, rx: float, ry: float, start_angle: float, end_angle: float, steps: int, color: Color, width: float) -> void:
		var points := PackedVector2Array()
		for i in steps + 1:
			var angle := lerpf(start_angle, end_angle, float(i) / float(steps))
			points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_polyline(points, color, width, true)

class MembraneCrossSection:
	extends Control

	var simulation
	var _particles := {}
	var _signature := ""
	var _elapsed := 0.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_elapsed += delta
		_update_particle_transforms()
		queue_redraw()

	func update_from_simulation() -> void:
		if simulation == null:
			return
		var desired := _desired_particles()
		var keys: Array[String] = []
		for item in desired:
			keys.append(item["key"])
		keys.sort()
		var next_signature := ",".join(keys)
		if next_signature == _signature:
			return
		_signature = next_signature
		var stale_keys: Array = []
		for key in _particles.keys():
			if not keys.has(key):
				stale_keys.append(key)
		for key in stale_keys:
			var old_node: Control = _particles[key].get("node", null)
			if old_node != null:
				old_node.queue_free()
			_particles.erase(key)
		for item in desired:
			var key: String = item["key"]
			if _particles.has(key):
				continue
			var node := FloatingMolecule3D.new()
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.spin_seed = float(item.get("seed", 0.0))
			node.set_molecule(simulation.molecule_types[item["id"]])
			add_child(node)
			item["node"] = node
			_particles[key] = item
		_update_particle_transforms()
		queue_redraw()

	func _desired_particles() -> Array[Dictionary]:
		var desired: Array[Dictionary] = []
		_append_side_particles(desired, "outside", simulation.outside_molecule_ids())
		_append_side_particles(desired, "inside", simulation.present_molecule_ids())
		return desired

	func _append_side_particles(desired: Array[Dictionary], side: String, ids: Array[String]) -> void:
		var counts := {}
		var side_count := 0
		for id in ids:
			var amount := float(simulation.outside_amounts.get(id, 0.0)) if side == "outside" else float(simulation.molecule_amounts.get(id, 0.0))
			var count := clampi(int(ceil(sqrt(maxf(amount, 0.0)) / 1.35)), 1, 18)
			counts[id] = count
			side_count += count
		var slot := 0
		for id in ids:
			var count := int(counts.get(id, 1))
			for i in count:
				var seed := float(abs(("%s:%s:%d" % [side, id, i]).hash() % 10000)) / 10000.0
				desired.append({
					"key": "%s:%s:%d" % [side, id, i],
					"id": id,
					"side": side,
					"seed": seed,
					"slot": slot,
					"side_count": side_count,
					"x_jitter": fmod(seed * 7.13 + 0.19, 1.0) - 0.5,
					"y_jitter": fmod(seed * 11.31 + 0.43, 1.0) - 0.5,
					"motion_seed": fmod(seed * 17.71 + 0.29, 1.0),
					"depth": 0.48 + fmod(seed * 3.71, 0.42)
				})
				slot += 1

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("10292d"), true)
		var outside_rect := Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.48))
		var inside_rect := Rect2(Vector2(0, size.y * 0.52), Vector2(size.x, size.y * 0.48))
		draw_rect(outside_rect, Color("143036"), true)
		draw_rect(inside_rect, Color("0d2528"), true)
		for y in range(18, int(size.y * 0.45), 54):
			draw_line(Vector2(0, y), Vector2(size.x, y + 22.0), Color(0.45, 0.95, 1.0, 0.035), 1.0, true)
		for y in range(int(size.y * 0.56), int(size.y), 62):
			draw_line(Vector2(0, y + 18.0), Vector2(size.x, y), Color(0.55, 1.0, 0.72, 0.025), 1.0, true)
		var center_y := size.y * 0.5
		var top := center_y - 34.0
		var bottom := center_y + 34.0
		draw_rect(Rect2(Vector2(0, top), Vector2(size.x, bottom - top)), Color("162b35"), true)
		draw_line(Vector2(0, top), Vector2(size.x, top), Color("76f4ff"), 2.0, true)
		draw_line(Vector2(0, bottom), Vector2(size.x, bottom), Color("76f4ff"), 2.0, true)
		for x in range(16, int(size.x) + 34, 34):
			var wobble := sin(_elapsed * 1.4 + float(x) * 0.04) * 2.0
			draw_circle(Vector2(x, top + wobble), 8.0, Color("4a90df"))
			draw_circle(Vector2(x + 17, bottom - wobble), 8.0, Color("a34ed0"))
			draw_line(Vector2(x, top + 8.0 + wobble), Vector2(x + 17, bottom - 8.0 - wobble), Color(0.82, 0.94, 0.96, 0.18), 2.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(18, 30), "OUTSIDE ENVIRONMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.82, 0.94, 0.96, 0.72))
		draw_string(ThemeDB.fallback_font, Vector2(18, size.y - 22), "CYTOPLASM", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.82, 0.94, 0.96, 0.72))
		if simulation == null:
			return
		var arrows: Array = simulation.membrane_transport_arrows()
		var start_x := maxf(120.0, size.x * 0.26)
		var spacing := 92.0
		for i in min(arrows.size(), 6):
			var arrow: Dictionary = arrows[i]
			var x: float = start_x + i * spacing + sin(_elapsed + float(i)) * 3.0
			var import_direction: bool = arrow.get("direction", "") == "import"
			var channel_top := Vector2(x, top - 14.0)
			var channel_bottom := Vector2(x, bottom + 14.0)
			draw_line(channel_top, channel_bottom, Color("02070b"), 18.0, true)
			draw_line(channel_top, channel_bottom, Color("253747"), 13.0, true)
			draw_line(channel_top, channel_bottom, Color("76f4ff"), 2.0, true)
			var from := Vector2(x, top - 58.0 if import_direction else bottom + 58.0)
			var to := Vector2(x, bottom + 58.0 if import_direction else top - 58.0)
			var color := Color("8cff6a") if import_direction else Color("ffe064")
			draw_line(from, to, Color("02070b"), 8.0, true)
			draw_line(from, to, color, 4.0, true)
			var dir := (to - from).normalized()
			var left := to - dir * 12.0 + Vector2(-dir.y, dir.x) * 7.0
			var right := to - dir * 12.0 - Vector2(-dir.y, dir.x) * 7.0
			draw_colored_polygon(PackedVector2Array([to, left, right]), color)
			draw_string(ThemeDB.fallback_font, Vector2(x - 30.0, center_y + 82.0), "%s x%d" % [arrow.get("formula", ""), int(arrow.get("count", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

	func _update_particle_transforms() -> void:
		for key in _particles.keys():
			var item: Dictionary = _particles[key]
			var node: Control = item.get("node", null)
			if node == null:
				continue
			var molecule: Dictionary = simulation.molecule_types.get(item.get("id", ""), {})
			var atom_count: int = maxi(1, int(molecule.get("atoms", []).size()))
			var node_size := Vector2(58.0 + float(atom_count) * 5.0, 46.0 + float(mini(atom_count, 7)) * 3.5)
			node.custom_minimum_size = node_size
			node.size = node_size
			var seed := float(item.get("seed", 0.0))
			var x_jitter := float(item.get("x_jitter", 0.0))
			var y_jitter := float(item.get("y_jitter", 0.0))
			var motion_seed := float(item.get("motion_seed", seed))
			var depth := float(item.get("depth", 0.7))
			var side := str(item.get("side", "outside"))
			var side_count := maxi(1, int(item.get("side_count", 1)))
			var slot := int(item.get("slot", 0))
			var columns := maxi(1, int(ceil(sqrt(float(side_count) * 1.35))))
			var rows := maxi(1, int(ceil(float(side_count) / float(columns))))
			var spread_slot := int(fposmod(float(slot * 7) + seed * float(side_count), float(side_count)))
			var col := spread_slot % columns
			var row := spread_slot / columns
			var x_seed := (float(col) + 0.5 + x_jitter * 0.45) / float(columns)
			var y_seed := (float(row) + 0.5 + y_jitter * 0.45) / float(rows)
			var y_min: float = 52.0 if side == "outside" else size.y * 0.61
			var y_max: float = size.y * 0.36 if side == "outside" else size.y - 80.0
			var x: float = lerpf(72.0, maxf(84.0, size.x - 96.0), x_seed)
			var y: float = lerpf(y_min, y_max, y_seed)
			var drift := Vector2(
				sin(_elapsed * (0.12 + motion_seed * 0.06) + seed * 19.0),
				cos(_elapsed * (0.10 + motion_seed * 0.05) + seed * 13.0)
			) * (12.0 + 12.0 * depth)
			var perspective: float = 0.40 + depth * 0.18 + sin(_elapsed * 0.35 + seed * 23.0) * 0.018
			node.position = Vector2(x, y) + drift - node_size * 0.5
			node.rotation = sin(_elapsed * (0.10 + motion_seed * 0.05) + seed * TAU) * 0.06
			node.scale = Vector2(perspective, perspective)

class FloatingMolecule3D:
	extends Control

	var molecule: Dictionary = {}
	var spin_seed := 0.0
	var _elapsed := 0.0

	func _ready() -> void:
		set_process(true)

	func set_molecule(value: Dictionary) -> void:
		molecule = value
		queue_redraw()

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		if molecule.is_empty():
			return
		var atoms: Array = molecule.get("atoms", [])
		var bonds: Array = molecule.get("bonds", [])
		if atoms.is_empty():
			return
		var projected := _project_atoms(atoms)
		var projected_bonds: Array[Dictionary] = []
		for i in bonds.size():
			var bond: Dictionary = bonds[i]
			var a_index := int(bond.get("a", 0))
			var b_index := int(bond.get("b", 0))
			if a_index >= projected.size() or b_index >= projected.size():
				continue
			var a: Dictionary = projected[a_index]
			var b: Dictionary = projected[b_index]
			projected_bonds.append({
				"a": a,
				"b": b,
				"order": int(bond.get("order", 1)),
				"z": (float(a.get("z", 0.0)) + float(b.get("z", 0.0))) * 0.5
			})
		projected_bonds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("z", 0.0)) < float(b.get("z", 0.0))
		)
		for bond in projected_bonds:
			_draw_projected_bond(bond)
		projected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("z", 0.0)) < float(b.get("z", 0.0))
		)
		for atom in projected:
			_draw_projected_atom(atom)

	func _project_atoms(atoms: Array) -> Array[Dictionary]:
		var min_pos := Vector2(INF, INF)
		var max_pos := Vector2(-INF, -INF)
		for atom in atoms:
			var pos: Vector2 = atom.get("pos", Vector2.ZERO)
			min_pos.x = minf(min_pos.x, pos.x)
			min_pos.y = minf(min_pos.y, pos.y)
			max_pos.x = maxf(max_pos.x, pos.x)
			max_pos.y = maxf(max_pos.y, pos.y)
		var graph_center := (min_pos + max_pos) * 0.5
		var graph_size := max_pos - min_pos
		var fit := minf(size.x / maxf(1.0, graph_size.x + 120.0), size.y / maxf(1.0, graph_size.y + 120.0))
		var scale := clampf(fit * 1.25, 0.26, 0.46)
		var yaw := _elapsed * (0.18 + spin_seed * 0.16) + spin_seed * TAU
		var pitch := sin(_elapsed * (0.12 + spin_seed * 0.08) + spin_seed * 9.0) * 0.52
		var roll := _elapsed * (0.10 + spin_seed * 0.12) + spin_seed * 5.0
		var cy := cos(yaw)
		var sy := sin(yaw)
		var cp := cos(pitch)
		var sp := sin(pitch)
		var cr := cos(roll)
		var sr := sin(roll)
		var center := size * 0.5
		var camera := 620.0
		var output: Array[Dictionary] = []
		for i in atoms.size():
			var atom: Dictionary = atoms[i]
			var source: Vector2 = atom.get("pos", Vector2.ZERO) - graph_center
			var x0 := source.x * scale
			var y0 := source.y * scale
			var z0 := source.y * scale * 0.18
			var x1 := x0 * cy + z0 * sy
			var z1 := -x0 * sy + z0 * cy
			var y1 := y0 * cp - z1 * sp
			var z2 := y0 * sp + z1 * cp
			var x2 := x1 * cr - y1 * sr
			var y2 := x1 * sr + y1 * cr
			var perspective := camera / maxf(120.0, camera - z2)
			output.append({
				"element": str(atom.get("element", "C")),
				"screen": center + Vector2(x2, y2) * perspective,
				"z": z2,
				"scale": perspective
			})
		return output

	func _draw_projected_bond(bond: Dictionary) -> void:
		var a: Dictionary = bond.get("a", {})
		var b: Dictionary = bond.get("b", {})
		var start: Vector2 = a.get("screen", Vector2.ZERO)
		var end: Vector2 = b.get("screen", Vector2.ZERO)
		var dir := end - start
		if dir.length() < 1.0:
			return
		dir = dir.normalized()
		var normal := Vector2(-dir.y, dir.x)
		var avg_scale := (float(a.get("scale", 1.0)) + float(b.get("scale", 1.0))) * 0.5
		var width := 6.0 * avg_scale
		var trim := 22.0 * avg_scale
		var offsets := [0.0]
		if int(bond.get("order", 1)) == 2:
			offsets = [-5.0 * avg_scale, 5.0 * avg_scale]
		for offset in offsets:
			var p0: Vector2 = start + dir * trim + normal * float(offset)
			var p1: Vector2 = end - dir * trim + normal * float(offset)
			draw_line(p0, p1, Color("02070b"), width + 6.0, true)
			draw_line(p0, p1, Color("dbeff2"), width + 1.5, true)
			draw_line(p0 + normal * 0.6, p1 + normal * 0.6, Color(1, 1, 1, 0.6), maxf(1.0, width * 0.32), true)

	func _draw_projected_atom(atom: Dictionary) -> void:
		var element := str(atom.get("element", "C"))
		var pos: Vector2 = atom.get("screen", Vector2.ZERO)
		var depth := clampf((float(atom.get("z", 0.0)) + 130.0) / 260.0, 0.0, 1.0)
		var radius := _atom_radius(element) * float(atom.get("scale", 1.0)) * lerpf(0.82, 1.16, depth)
		var base := _atom_color(element).lerp(Color.WHITE, depth * 0.16)
		draw_circle(pos + Vector2(0, radius * 0.20), radius + 5.0, Color(0.0, 0.0, 0.0, 0.33))
		draw_circle(pos, radius + 5.0, Color("02070b"))
		draw_circle(pos, radius + 1.5, base.lightened(0.35))
		draw_circle(pos, radius - 1.0, base.darkened(0.16))
		for i in 8:
			var t := float(i) / 7.0
			var r := lerpf(radius * 0.84, radius * 0.20, t)
			var offset := Vector2(-radius * 0.16, -radius * 0.15) * (1.0 - t)
			var shade := base.darkened(0.12).lerp(base.lightened(0.28), t)
			draw_circle(pos + offset, r, Color(shade.r, shade.g, shade.b, 0.28))
		draw_circle(pos + Vector2(radius * 0.26, -radius * 0.39), radius * 0.20, Color(1, 1, 1, 0.42))
		draw_circle(pos + Vector2(radius * 0.31, -radius * 0.43), radius * 0.10, Color(1, 1, 1, 0.22))

	func _atom_radius(element: String) -> float:
		if element == "C":
			return 15.0
		return 13.5

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

class DesignerTitleFrame:
	extends Control

	func _draw() -> void:
		var cyan := Color("76f4ff")
		var glow := Color(0.45, 0.95, 1.0, 0.22)
		var y := 26.0
		var tab_width := 360.0
		var tab_half := tab_width * 0.5
		var center_x := size.x * 0.5
		var tab_left := center_x - tab_half
		var tab_right := center_x + tab_half
		var points := PackedVector2Array([
			Vector2(0, y),
			Vector2(tab_left - 34.0, y),
			Vector2(tab_left - 18.0, y + 17.0),
			Vector2(tab_left + 14.0, y + 20.0),
			Vector2(tab_right - 14.0, y + 20.0),
			Vector2(tab_right + 18.0, y + 17.0),
			Vector2(tab_right + 34.0, y),
			Vector2(size.x, y)
		])
		draw_polyline(points, Color("02070b"), 9.0, true)
		draw_polyline(points, glow, 7.0, true)
		draw_polyline(points, cyan, 3.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(center_x - 145.0, 21.0), "ENZYME DESIGNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, cyan)

class TitleTopFrame:
	extends Control

	func _draw() -> void:
		var cyan := Color("76f4ff")
		var glow := Color(0.45, 0.95, 1.0, 0.22)
		var y := 34.0
		var tab_width := 430.0
		var center_x := size.x * 0.5
		var tab_left := center_x - tab_width * 0.5
		var tab_right := center_x + tab_width * 0.5
		var points := PackedVector2Array([
			Vector2(0, y),
			Vector2(tab_left - 42.0, y),
			Vector2(tab_left - 22.0, y + 18.0),
			Vector2(tab_left + 16.0, y + 22.0),
			Vector2(tab_right - 16.0, y + 22.0),
			Vector2(tab_right + 22.0, y + 18.0),
			Vector2(tab_right + 42.0, y),
			Vector2(size.x, y)
		])
		draw_polyline(points, Color("02070b"), 9.0, true)
		draw_polyline(points, glow, 7.0, true)
		draw_polyline(points, cyan, 3.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(center_x - 88.0, 28.0), "SIM CELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, cyan)

class TitleBackground:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("10292d"), true)
		var cyan := Color("76f4ff")
		for i in 9:
			var x := size.x * (0.12 + float(i) * 0.1)
			var y := size.y * (0.28 + sin(float(i) * 1.7) * 0.08)
			var r := 24.0 + float(i % 3) * 7.0
			draw_circle(Vector2(x, y), r + 6.0, Color("02070b"))
			draw_circle(Vector2(x, y), r, Color("728186").darkened(0.12))
			draw_circle(Vector2(x + r * 0.32, y - r * 0.36), r * 0.18, Color(1, 1, 1, 0.38))
			if i > 0:
				var previous_x := size.x * (0.12 + float(i - 1) * 0.1)
				var previous_y := size.y * (0.28 + sin(float(i - 1) * 1.7) * 0.08)
				draw_line(Vector2(previous_x, previous_y), Vector2(x, y), Color("02070b"), 13.0, true)
				draw_line(Vector2(previous_x, previous_y), Vector2(x, y), Color("dbeff2"), 6.0, true)
		draw_line(Vector2(0, size.y - 88.0), Vector2(size.x, size.y - 88.0), Color(0.45, 0.95, 1.0, 0.18), 3.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(36, size.y - 42.0), "SIMULATION PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cyan)

class TitleShade:
	extends Control

	func _draw() -> void:
		var left := Rect2(Vector2.ZERO, Vector2(size.x * 0.54, size.y))
		draw_rect(left, Color(0.01, 0.05, 0.07, 0.62), true)
		for i in 18:
			var t := float(i) / 17.0
			var x := lerpf(size.x * 0.34, size.x * 0.70, t)
			draw_rect(Rect2(Vector2(x, 0), Vector2(size.x * 0.03, size.y)), Color(0.01, 0.05, 0.07, 0.28 * (1.0 - t)), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.18), true)
		for y in range(0, int(size.y), 6):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.5, 1.0, 1.0, 0.025), 1.0)
		var cyan := Color("76f4ff")
		draw_line(Vector2(0, 34), Vector2(size.x * 0.38, 34), Color(cyan.r, cyan.g, cyan.b, 0.7), 3.0, true)
		draw_line(Vector2(size.x * 0.62, 34), Vector2(size.x, 34), Color(cyan.r, cyan.g, cyan.b, 0.7), 3.0, true)
		draw_line(Vector2(0, size.y - 54), Vector2(size.x, size.y - 54), Color(cyan.r, cyan.g, cyan.b, 0.22), 2.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(74, size.y - 24), "SIMULATION PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(cyan.r, cyan.g, cyan.b, 0.85))
