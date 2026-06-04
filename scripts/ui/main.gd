extends Control

const CellViewScript := preload("res://scripts/ui/cell_view.gd")
const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")
const MetabolismWorkspaceScript := preload("res://scripts/ui/metabolism_workspace.gd")
const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")
const MoleculeGraphScript := preload("res://scripts/core/molecule_graph.gd")

const VIEW_ICON_PATHS := {
	"cell": "res://assets/art_lab/icons/views/cell.png",
	"metabolism": "res://assets/art_lab/icons/views/metabolism.png",
	"membrane": "res://assets/art_lab/icons/views/membrane.png",
	"proteins": "res://assets/art_lab/icons/views/proteins.png",
	"dna": "res://assets/art_lab/icons/views/dna.png",
	"art_lab": "res://assets/art_lab/icons/views/art_lab.png"
}

var sim = SimulationStateScript.new()
var root: VBoxContainer
var content: Control
var bottom_nav: HBoxContainer
var status_label: Label
var view_title_label: Label
var resource_summary_box: HBoxContainer
var molecule_summary_box: HBoxContainer
var top_stat_popup: PanelContainer
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
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 74)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_right", 74)
	margin.add_theme_constant_override("margin_bottom", 78)
	title_root.add_child(margin)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(680, 420)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 16)
	margin.add_child(menu)
	var logo := TextureRect.new()
	var logo_image := Image.load_from_file("res://assets/reference/sim-cell-logo.png")
	if logo_image != null:
		logo.texture = ImageTexture.create_from_image(logo_image)
	logo.custom_minimum_size = Vector2(660, 236)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(logo)
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
		_show_view("cell")
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
	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 58)
	header_panel.add_theme_stylebox_override("panel", _top_bar_style())
	root.add_child(header_panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header_panel.add_child(header)
	resource_summary_box = HBoxContainer.new()
	resource_summary_box.custom_minimum_size = Vector2(430, 0)
	resource_summary_box.add_theme_constant_override("separation", 14)
	header.add_child(resource_summary_box)
	view_title_label = Label.new()
	view_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_title_label.add_theme_font_size_override("font_size", 24)
	view_title_label.modulate = Color("76f4ff")
	header.add_child(view_title_label)
	molecule_summary_box = HBoxContainer.new()
	molecule_summary_box.custom_minimum_size = Vector2(360, 0)
	molecule_summary_box.alignment = BoxContainer.ALIGNMENT_END
	molecule_summary_box.add_theme_constant_override("separation", 14)
	header.add_child(molecule_summary_box)
	status_label = Label.new()
	status_label.visible = false
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
	bottom_nav.add_theme_constant_override("separation", 14)
	root.add_child(bottom_nav)
	for item in [
		["Cell", "cell"],
		["Metabolism", "metabolism"],
		["Membrane", "membrane"],
		["Proteins", "proteins"],
		["DNA", "dna"],
		["Art Lab", "art_lab"]
	]:
		var button := Button.new()
		button.text = ""
		button.icon = _texture_from_png(str(VIEW_ICON_PATHS.get(item[1], "")))
		button.expand_icon = true
		button.custom_minimum_size = Vector2(96, 62)
		button.add_theme_stylebox_override("normal", _transparent_nav_style())
		button.add_theme_stylebox_override("hover", _transparent_nav_style(Color(0.45, 1.0, 1.0, 0.12)))
		button.add_theme_stylebox_override("pressed", _transparent_nav_style(Color(0.55, 1.0, 0.78, 0.16)))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(func(view_id = item[1]): _show_view(view_id))
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
		_build_dna_view()
	elif view_id == "art_lab":
		_build_art_lab_view()
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
	layout.add_theme_constant_override("separation", 10)
	content.add_child(layout)

	var outside_panel := _glow_panel("EXTRACELLULAR COMPOSITION")
	outside_panel.custom_minimum_size = Vector2(340, 0)
	layout.add_child(outside_panel)
	membrane_outside_list = VBoxContainer.new()
	membrane_outside_list.add_theme_constant_override("separation", 9)
	outside_panel.add_child(membrane_outside_list)
	outside_panel.add_child(_section_label("Importer Builder"))
	membrane_import_detail = VBoxContainer.new()
	membrane_import_detail.add_theme_constant_override("separation", 10)
	outside_panel.add_child(membrane_import_detail)

	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	membrane_scene = _membrane_cross_section()
	membrane_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(membrane_scene)

	var right_panel := _glow_panel("SOURCE METABOLITES")
	right_panel.custom_minimum_size = Vector2(340, 0)
	layout.add_child(right_panel)
	right_panel.add_child(_section_label("Inside Cell"))
	membrane_inside_list = VBoxContainer.new()
	membrane_inside_list.add_theme_constant_override("separation", 9)
	right_panel.add_child(membrane_inside_list)
	right_panel.add_child(_section_label("Active Transporters"))
	membrane_transporter_list = VBoxContainer.new()
	membrane_transporter_list.add_theme_constant_override("separation", 8)
	right_panel.add_child(membrane_transporter_list)
	right_panel.add_child(_section_label("Exporter Builder"))
	membrane_export_detail = VBoxContainer.new()
	membrane_export_detail.add_theme_constant_override("separation", 10)
	right_panel.add_child(membrane_export_detail)

func _build_placeholder(title: String, subtitle: String) -> void:
	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(box)
	box.add_child(_title(title, subtitle))

func _build_dna_view() -> void:
	var tree := DNATechTreeWorkspace.new()
	tree.simulation = sim
	tree.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree.tech_clicked.connect(func(tech_id: String):
		sim.invest_dna_research(tech_id, 50.0)
	)
	content.add_child(tree)

func _build_art_lab_view() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(margin)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 18)
	margin.add_child(stack)
	stack.add_child(_title("ART LAB", "Temporary prototype view for comparing generated UI assets and art styles."))
	stack.add_child(_art_molecule_variant_section())
	stack.add_child(_art_selected_molecule_examples_section())
	stack.add_child(_art_icon_section("Basic Resources", [
		["Energy (ATP)", "res://assets/art_lab/icons/resources/atp_simple.png"],
		["Electrons (NADH)", "res://assets/art_lab/icons/resources/nadh_simple.png"],
		["Amino Acids", "res://assets/art_lab/icons/resources/amino_acids_simple.png"],
		["DNA", "res://assets/art_lab/icons/resources/dna_simple.png"],
		["RNA", "res://assets/art_lab/icons/resources/rna_simple.png"]
	]))
	stack.add_child(_art_icon_section("Source Metabolites And Elements", [
		["Glucose", "res://assets/art_lab/icons/elements/glucose_simple.png"],
		["Nitrogen", "res://assets/art_lab/icons/elements/nitrogen_simple.png"],
		["Sulfur", "res://assets/art_lab/icons/elements/sulfur_simple.png"],
		["Phosphorus", "res://assets/art_lab/icons/elements/phosphorus_simple.png"]
	]))
	stack.add_child(_art_icon_section("View Navigation", [
		["Cell", VIEW_ICON_PATHS["cell"]],
		["Metabolism", VIEW_ICON_PATHS["metabolism"]],
		["Membrane", VIEW_ICON_PATHS["membrane"]],
		["Proteins", VIEW_ICON_PATHS["proteins"]],
		["DNA", VIEW_ICON_PATHS["dna"]],
		["Art Lab", VIEW_ICON_PATHS["art_lab"]]
	], 132.0))
	stack.add_child(_art_sheet_section("Generated Sheets", [
		["Simple Resources", "res://assets/art_lab/sheets/resource_icons_simple_sheet.png"],
		["Simple Elements", "res://assets/art_lab/sheets/source_icons_simple_sheet.png"],
		["Detailed Resources", "res://assets/art_lab/sheets/resource_icons_sheet.png"],
		["Detailed Elements", "res://assets/art_lab/sheets/source_icons_sheet.png"],
		["Views", "res://assets/art_lab/sheets/view_icons_sheet.png"]
	]))
	stack.add_child(_art_sheet_section("Membrane Transporter Concepts", [
		["20 transporter variants", "res://assets/art_lab/membrane/transporter-variants.png"]
	], 520.0))
	stack.add_child(_art_sheet_section("Membrane Unit And Strip Concepts", [
		["Phospholipid units and repeatable membrane strips", "res://assets/art_lab/membrane/membrane-variants.png"]
	], 470.0))
	stack.add_child(_art_sheet_section("Layered Phospholipid Palettes", [
		["Separated heads, separated tails, assembled units, and bilayer previews", "res://assets/art_lab/membrane/layered-phospholipid-palette.png"]
	], 520.0))
	stack.add_child(_art_phospholipid_animation_section())

func _art_molecule_variant_section() -> Control:
	var panel := _glow_panel("Molecule Style Variants")
	var note := Label.new()
	note.text = "Pick the number you prefer. These variants test atom radius, black stroke, inner rim, bond thickness, bond spacing, and atom distance."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	panel.add_child(grid)
	var molecule: Dictionary = sim.molecule_types.get(sim.selected_molecule, {})
	if molecule.is_empty() and not sim.molecule_types.is_empty():
		molecule = sim.molecule_types[sim.molecule_types.keys()[0]]
	var variants := [
		{"n": 1, "name": "Thin Edge Base", "zoom": 0.58, "atom": 1.00, "bond": 0.66, "spacing": 1.08, "outline": 5.2, "rim": 0.8, "rim_light": 0.07, "trim": 1.08, "gap": 8.8, "gloss": 0.45},
		{"n": 2, "name": "Closer Atoms", "zoom": 0.59, "atom": 1.00, "bond": 0.64, "spacing": 1.04, "outline": 5.0, "rim": 0.7, "rim_light": 0.06, "trim": 1.10, "gap": 9.0, "gloss": 0.45},
		{"n": 3, "name": "Larger Atoms", "zoom": 0.58, "atom": 1.06, "bond": 0.64, "spacing": 1.06, "outline": 5.2, "rim": 0.8, "rim_light": 0.07, "trim": 1.15, "gap": 9.0, "gloss": 0.46},
		{"n": 4, "name": "Very Thin Edge", "zoom": 0.58, "atom": 1.02, "bond": 0.64, "spacing": 1.07, "outline": 4.2, "rim": 0.6, "rim_light": 0.06, "trim": 1.10, "gap": 9.2, "gloss": 0.44},
		{"n": 5, "name": "Balanced Close", "zoom": 0.60, "atom": 1.04, "bond": 0.68, "spacing": 1.05, "outline": 5.6, "rim": 0.8, "rim_light": 0.07, "trim": 1.13, "gap": 9.0, "gloss": 0.46},
		{"n": 6, "name": "Soft Gradient Close", "zoom": 0.59, "atom": 1.02, "bond": 0.62, "spacing": 1.06, "outline": 5.0, "rim": 0.7, "rim_light": 0.05, "trim": 1.10, "gap": 9.6, "gloss": 0.40},
		{"n": 7, "name": "Clear Double Bonds", "zoom": 0.58, "atom": 1.00, "bond": 0.62, "spacing": 1.08, "outline": 5.2, "rim": 0.8, "rim_light": 0.07, "trim": 1.08, "gap": 10.5, "gloss": 0.45},
		{"n": 8, "name": "Thicker Clear Bonds", "zoom": 0.58, "atom": 1.00, "bond": 0.76, "spacing": 1.08, "outline": 5.4, "rim": 0.7, "rim_light": 0.06, "trim": 1.10, "gap": 10.2, "gloss": 0.45},
		{"n": 9, "name": "Designer Close Thin Edge", "zoom": 0.61, "atom": 1.08, "bond": 0.68, "spacing": 1.04, "outline": 5.6, "rim": 0.8, "rim_light": 0.07, "trim": 1.18, "gap": 9.4, "gloss": 0.48}
	]
	for variant in variants:
		grid.add_child(_art_molecule_variant_card(molecule, variant))
	return panel

func _selected_molecule_style() -> Dictionary:
	return {"zoom": 0.60, "atom": 1.04, "bond": 0.68, "spacing": 1.05, "outline": 5.6, "rim": 0.8, "rim_light": 0.07, "trim": 1.13, "gap": 9.0, "gloss": 0.46}

func _art_selected_molecule_examples_section() -> Control:
	var panel := _glow_panel("Selected Molecule Style Examples")
	var note := Label.new()
	note.text = "Variant 5 applied to different molecule shapes and elements."
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 14)
	panel.add_child(row)
	var examples: Array = [
		["Glucose substrate", MoleculeGraphScript.initial_glucose_like()],
		["Amino acid target", MoleculeGraphScript.amino_acid_target()]
	]
	for demo in MoleculeGraphScript.demo_molecules():
		examples.append([str(demo.get("name", demo.get("formula", "Molecule"))), demo])
	for item in examples:
		row.add_child(_art_molecule_example_card(str(item[0]), item[1], _selected_molecule_style()))
	return panel

func _art_molecule_example_card(label_text: String, molecule: Dictionary, style: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(292, 230)
	card.add_theme_constant_override("separation", 6)
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(292, 176)
	canvas.size = canvas.custom_minimum_size
	canvas.draw_background = true
	canvas.scale_to_fit = false
	canvas.fixed_zoom = float(style.get("zoom", 0.60))
	canvas.atom_scale = float(style.get("atom", 1.0))
	canvas.bond_scale = float(style.get("bond", 1.0))
	canvas.graph_spacing_scale = float(style.get("spacing", 1.0))
	canvas.atom_outline_extra = float(style.get("outline", 4.6))
	canvas.atom_inner_stroke_extra = float(style.get("rim", 1.3))
	canvas.atom_inner_stroke_lighten = float(style.get("rim_light", 0.12))
	canvas.atom_gloss_alpha = float(style.get("gloss", 0.42))
	canvas.bond_trim_scale = float(style.get("trim", 1.0))
	canvas.double_bond_gap = float(style.get("gap", 7.0))
	canvas.set_molecule(molecule)
	card.add_child(canvas)
	var label := Label.new()
	label.text = "%s  |  %s" % [label_text, molecule.get("formula", "")]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color("dbeff2")
	card.add_child(label)
	return card

func _art_molecule_variant_card(molecule: Dictionary, variant: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(292, 260)
	card.add_theme_constant_override("separation", 6)
	var canvas = MoleculeCanvasScript.new()
	canvas.custom_minimum_size = Vector2(292, 186)
	canvas.size = canvas.custom_minimum_size
	canvas.draw_background = true
	canvas.scale_to_fit = false
	canvas.fixed_zoom = float(variant.get("zoom", 0.62))
	canvas.atom_scale = float(variant.get("atom", 1.0))
	canvas.bond_scale = float(variant.get("bond", 1.0))
	canvas.graph_spacing_scale = float(variant.get("spacing", 1.0))
	canvas.atom_outline_extra = float(variant.get("outline", 4.6))
	canvas.atom_inner_stroke_extra = float(variant.get("rim", 1.3))
	canvas.atom_inner_stroke_lighten = float(variant.get("rim_light", 0.12))
	canvas.atom_gloss_alpha = float(variant.get("gloss", 0.42))
	canvas.bond_trim_scale = float(variant.get("trim", 1.0))
	canvas.double_bond_gap = float(variant.get("gap", 7.0))
	canvas.set_molecule(molecule)
	card.add_child(canvas)
	var number := Label.new()
	number.text = "%d" % int(variant.get("n", 0))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 30)
	number.modulate = Color("76f4ff")
	card.add_child(number)
	var label := Label.new()
	label.text = str(variant.get("name", "Variant"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color("dbeff2")
	card.add_child(label)
	return card

func _art_icon_section(label_text: String, items: Array, image_size: float = 146.0) -> Control:
	var panel := _glow_panel(label_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	for item in items:
		row.add_child(_art_icon_card(str(item[0]), str(item[1]), image_size))
	return panel

func _art_icon_card(label_text: String, path: String, image_size: float) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(maxf(150.0, image_size + 24.0), image_size + 48.0)
	card.add_theme_constant_override("separation", 8)
	var texture := TextureRect.new()
	texture.texture = _texture_from_png(path)
	texture.custom_minimum_size = Vector2(image_size, image_size)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(texture)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color("dbeff2")
	card.add_child(label)
	return card

func _art_sheet_section(label_text: String, items: Array, image_height: float = 190.0) -> Control:
	var panel := _glow_panel(label_text)
	for item in items:
		var title := Label.new()
		title.text = str(item[0])
		title.add_theme_font_size_override("font_size", 16)
		title.modulate = Color("76f4ff")
		panel.add_child(title)
		var texture := TextureRect.new()
		texture.texture = _texture_from_png(str(item[1]))
		texture.custom_minimum_size = Vector2(0.0, image_height)
		texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(texture)
	return panel

func _art_phospholipid_animation_section() -> Control:
	var panel := _glow_panel("Stationary Phospholipid Animation Test")
	var note := Label.new()
	note.text = "A phospholipid can stay in place while cycling subtle sprite-like frames: head shine, radius, and tail bend change without moving the anchor point."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var variants := [
		["Subtle", Color("58c7ef"), Color("f08b24")],
		["Teal Amber", Color("28c7bc"), Color("f1b42c")],
		["Pearl Rust", Color("dbe5e8"), Color("c96332")]
	]
	for item in variants:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(240, 230)
		card.add_theme_constant_override("separation", 8)
		var preview := PhospholipidAnimationPreview.new()
		preview.custom_minimum_size = Vector2(230, 176)
		preview.head_color = item[1]
		preview.tail_color = item[2]
		card.add_child(preview)
		var label := Label.new()
		label.text = str(item[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color("dbeff2")
		card.add_child(label)
		row.add_child(card)
	return panel

func _texture_from_png(path: String) -> Texture2D:
	var actual_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var image := Image.load_from_file(actual_path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = "Time %.1fs | %s | %.2fx | ATP %.0f | AA %.0f | NADH %.1f | N %.1f | Molecules %d | Enzymes %d" % [
		sim.time_seconds,
		"Paused" if sim.paused else "Running",
		sim.speed,
		float(sim.resources.get("ATP", 0.0)),
		float(sim.resources.get("Amino Acids", 0.0)),
		float(sim.resources.get("NADH", 0.0)),
		float(sim.resources.get("N", 0.0)),
		sim.present_molecule_ids().size(),
		sim.active_enzymes.size()
	]
	if view_title_label != null:
		view_title_label.text = _view_title(sim.active_view)
	if resource_summary_box != null:
		_set_top_stat_group(resource_summary_box, [
			["res://assets/art_lab/icons/resources/atp_simple.png", "%.0f" % float(sim.resources.get("ATP", 0.0)), Color("8cff6a"), "Energy (ATP)"],
			["res://assets/art_lab/icons/resources/nadh_simple.png", "%.1f" % float(sim.resources.get("NADH", 0.0)), Color("76f4ff"), "Electrons (NADH)"],
			["res://assets/art_lab/icons/resources/amino_acids_simple.png", "%.0f" % float(sim.resources.get("Amino Acids", 0.0)), Color("8cff6a"), "Amino Acids"],
			["res://assets/art_lab/icons/elements/nitrogen_simple.png", "%.1f" % float(sim.resources.get("N", 0.0)), Color("76a8ff"), "Nitrogen"],
			["res://assets/art_lab/icons/resources/dna_simple.png", "%.0f" % float(sim.resources.get("DNA Points", 0.0)), Color("76f4ff"), "DNA Points"]
		])
	if molecule_summary_box != null:
		var glucose_id := _glucose_molecule_id()
		var glucose_amount := float(sim.molecule_amounts.get(glucose_id, 0.0)) if not glucose_id.is_empty() else 0.0
		_set_top_stat_group(molecule_summary_box, [
			["res://assets/art_lab/icons/elements/glucose_simple.png", "%.0f" % glucose_amount, Color("8cff6a"), "Glucose"],
			["res://assets/art_lab/icons/views/metabolism.png", "%d" % sim.present_molecule_ids().size(), Color("dbeff2"), "Molecule Types"],
			["res://assets/art_lab/icons/views/proteins.png", "%d" % sim.active_enzymes.size(), Color("dbeff2"), "Active Enzymes"]
		])
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
		membrane_outside_list.add_child(_membrane_source_card(id, "outside"))
	_clear(membrane_inside_list)
	for id in sim.outside_molecule_ids():
		membrane_inside_list.add_child(_membrane_source_card(id, "inside"))
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

func _membrane_source_card(id: String, location: String) -> Button:
	var molecule: Dictionary = sim.molecule_types[id]
	var amount := float(sim.outside_amounts.get(id, 0.0)) if location == "outside" else float(sim.molecule_amounts.get(id, 0.0))
	var rates: Dictionary = sim.outside_rates.get(id, {"production": 0.0, "consumption": 0.0}) if location == "outside" else sim.molecule_rates.get(id, {"production": 0.0, "consumption": 0.0})
	var direction := "import" if location == "outside" else "export"
	var button := Button.new()
	var sign := "-" if location == "outside" else "+"
	button.text = "%s  %s  %.0f\n%s%.1f/s  transport x%d" % [
		_molecule_color_symbol(id),
		molecule.get("formula", "Molecule"),
		amount,
		sign,
		float(rates.get("consumption", 0.0) if location == "outside" else rates.get("production", 0.0)),
		sim.transporter_count(direction, id)
	]
	button.toggle_mode = true
	button.button_pressed = selected_membrane_molecule == id and selected_membrane_direction == direction
	button.custom_minimum_size = Vector2(0, 72)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", _molecule_color(id).lightened(0.58))
	button.add_theme_color_override("font_hover_color", Color("f4fbff"))
	button.add_theme_color_override("font_pressed_color", Color("f4fbff"))
	button.add_theme_stylebox_override("normal", _source_card_style(false, id))
	button.add_theme_stylebox_override("hover", _source_card_style(true, id))
	button.add_theme_stylebox_override("pressed", _source_card_style(true, id))
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
	var color_note := Label.new()
	color_note.text = "%s colored source metabolite in the membrane scene" % _molecule_color_symbol(selected_membrane_molecule)
	color_note.modulate = _molecule_color(selected_membrane_molecule).lightened(0.40)
	color_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_detail.add_child(color_note)
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
	canvas.draw_background = false
	canvas.scale_to_fit = true
	canvas.atom_scale = 0.78
	canvas.bond_scale = 0.76
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
	var build_cost: Dictionary = pathway.get("build_cost", {})
	if not build_cost.is_empty():
		var cost_label := Label.new()
		cost_label.text = "Build cost: %s" % _resource_cost_text(build_cost)
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_label.modulate = Color("8cff6a")
		detail_panel.add_child(cost_label)
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
	var resource_delta: Dictionary = pathway.get("resource_delta", {})
	if not resource_delta.is_empty():
		var resources := Label.new()
		resources.text = _resource_delta_text(resource_delta)
		resources.modulate = Color("ffe064")
		box.add_child(resources)
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
	for tool in sim.enzyme_tools():
		tools.add_child(_tool_button(str(tool.get("id", "")), str(tool.get("icon", "")), str(tool.get("label", "")), str(tool.get("summary", ""))))

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

func _tool_button(id: String, icon: String, label_text: String, summary: String = "") -> Button:
	var button := Button.new()
	button.text = "%s  %s\n%s" % [icon, label_text, summary]
	button.custom_minimum_size = Vector2(0, 74)
	button.toggle_mode = true
	button.button_pressed = designer_tool == id
	button.add_theme_font_size_override("font_size", 16)
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
	var resource_delta: Dictionary = summary.get("resource_delta", {})
	if not resource_delta.is_empty():
		var resource_label := Label.new()
		resource_label.text = "Resources: %s" % _resource_delta_text(resource_delta)
		resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		resource_label.modulate = Color("ffe064")
		summary_panel.add_child(resource_label)
	var build_cost: Dictionary = summary.get("build_cost", {})
	if not build_cost.is_empty():
		var build_cost_label := Label.new()
		build_cost_label.text = "Build cost: %s" % _resource_cost_text(build_cost)
		build_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		build_cost_label.modulate = Color("8cff6a")
		summary_panel.add_child(build_cost_label)
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

func _resource_delta_text(delta: Dictionary) -> String:
	var parts: Array[String] = []
	for key in delta.keys():
		var value := float(delta[key])
		if value > 0.0:
			parts.append("+%.0f %s" % [value, key])
		elif value < 0.0:
			parts.append("-%.0f %s" % [absf(value), key])
	return ", ".join(parts) if not parts.is_empty() else "none"

func _resource_cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in cost.keys():
		var value := float(cost[key])
		if value > 0.0:
			parts.append("%.0f %s" % [value, key])
	return ", ".join(parts) if not parts.is_empty() else "free"

func _view_title(view_id: String) -> String:
	var titles := {
		"cell": "CELL OVERVIEW",
		"metabolism": "METABOLIC LANDSCAPE",
		"membrane": "MEMBRANE TRANSPORT",
		"proteins": "PROTEIN BUILDER",
		"dna": "DNA TECH TREE",
		"art_lab": "ART LAB",
		"enzyme_designer": "ENZYME DESIGNER"
	}
	return titles.get(view_id, view_id.to_upper())

func _glucose_molecule_id() -> String:
	for id in sim.molecule_types.keys():
		var molecule: Dictionary = sim.molecule_types[id]
		if molecule.get("name", "") == "Glucose":
			return id
	return ""

func _set_top_stat_group(container: HBoxContainer, items: Array) -> void:
	if container.get_child_count() != items.size():
		_clear(container)
		for item in items:
			container.add_child(_top_stat_item(
				str(item[0]),
				str(item[1]),
				item[2] if item.size() > 2 else Color("dbeff2"),
				str(item[3]) if item.size() > 3 else "Resource"
			))
		return
	for i in items.size():
		var item: Array = items[i]
		var row := container.get_child(i)
		row.set_meta("icon_path", str(item[0]))
		row.set_meta("stat_name", str(item[3]) if item.size() > 3 else "Resource")
		row.set_meta("stat_value", str(item[1]))
		var label := row.get_node_or_null("ValueLabel") as Label
		if label != null:
			label.text = str(item[1])
			label.modulate = item[2] if item.size() > 2 else Color("dbeff2")

func _top_stat_item(icon_path: String, value: String, color: Color, stat_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta("icon_path", icon_path)
	row.set_meta("stat_name", stat_name)
	row.set_meta("stat_value", value)
	row.mouse_entered.connect(func():
		_show_top_stat_popup(row)
	)
	row.mouse_exited.connect(_hide_top_stat_popup)
	var icon := TextureRect.new()
	icon.texture = _texture_from_png(icon_path)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name = "ValueLabel"
	label.text = value
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row

func _show_top_stat_popup(source: Control) -> void:
	_hide_top_stat_popup()
	top_stat_popup = PanelContainer.new()
	top_stat_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_stat_popup.add_theme_stylebox_override("panel", _glow_panel_style(Color("10242c"), Color("76f4ff"), 1.2, 7))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top_stat_popup.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _texture_from_png(str(source.get_meta("icon_path", "")))
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = str(source.get_meta("stat_name", "Resource"))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.modulate = Color("f4fbff")
	text_box.add_child(name_label)
	var value_label := Label.new()
	value_label.text = str(source.get_meta("stat_value", "0"))
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.modulate = Color("76f4ff")
	text_box.add_child(value_label)
	add_child(top_stat_popup)
	top_stat_popup.position = source.get_global_rect().position - global_position + Vector2(0, source.size.y + 8.0)

func _hide_top_stat_popup() -> void:
	if top_stat_popup == null:
		return
	top_stat_popup.queue_free()
	top_stat_popup = null

func _top_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07181c")
	style.border_color = Color("4bc7d8")
	style.set_border_width(SIDE_TOP, 2)
	style.set_border_width(SIDE_BOTTOM, 2)
	style.shadow_color = Color(0.2, 0.95, 1.0, 0.18)
	style.shadow_size = 10
	style.content_margin_left = 16
	style.content_margin_top = 8
	style.content_margin_right = 16
	style.content_margin_bottom = 8
	return style

func _transparent_nav_style(fill: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style

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

func _molecule_color(id: String) -> Color:
	if sim != null and sim.molecule_types.has(id):
		var molecule: Dictionary = sim.molecule_types[id]
		var name := str(molecule.get("name", "")).to_lower()
		if name == "glucose" or str(molecule.get("formula", "")) == "C₆O₂":
			return Color("64d66f")
	var palette := [
		Color("64d66f"),
		Color("56a8ff"),
		Color("e95058"),
		Color("b956de"),
		Color("ffe064"),
		Color("5dd4d1"),
		Color("ff9c5a")
	]
	return palette[abs(id.hash()) % palette.size()]

func _molecule_color_symbol(_id: String) -> String:
	return "●"

func _source_card_style(active: bool, id: String) -> StyleBoxFlat:
	var color := _molecule_color(id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b3440") if active else Color("122532")
	style.border_color = color.lightened(0.18) if active else Color(color.r, color.g, color.b, 0.48)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(color.r, color.g, color.b, 0.28 if active else 0.10)
	style.shadow_size = 8 if active else 3
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
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

	var membrane_texture: Texture2D
	var transporter_texture: Texture2D
	var simulation
	var _particles := {}
	var _signature := ""
	var _elapsed := 0.0
	var _membrane_scroll := 0.0
	var _dragging := false
	var _last_drag_position := Vector2.ZERO
	const VISIBLE_MEMBRANE_ARC := 0.42

	func _ready() -> void:
		membrane_texture = _load_texture_from_file("res://assets/membrane/membrane-repeat-style4.png")
		transporter_texture = _load_texture_from_file("res://assets/membrane/transporter-sheet.png")
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(true)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_last_drag_position = event.position
			accept_event()
		elif event is InputEventMouseMotion and _dragging:
			var delta: Vector2 = event.position - _last_drag_position
			_last_drag_position = event.position
			if size.x > 1.0:
				_membrane_scroll = fposmod(_membrane_scroll - delta.x / size.x * VISIBLE_MEMBRANE_ARC, 1.0)
				_update_particle_transforms()
				queue_redraw()
			accept_event()

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
			var node := FloatingSourceParticle.new()
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.seed = float(item.get("seed", 0.0))
			node.color = _source_color(str(item.get("id", "")))
			node.shape = _source_shape(str(item.get("id", "")))
			node.formula = simulation.molecule_types[item["id"]].get("formula", "")
			add_child(node)
			item["node"] = node
			_particles[key] = item
		_update_particle_transforms()
		queue_redraw()

	func _load_texture_from_file(path: String) -> Texture2D:
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(path))
		if error != OK:
			push_warning("Could not load membrane image: %s" % path)
			return null
		return ImageTexture.create_from_image(image)

	func _desired_particles() -> Array[Dictionary]:
		var desired: Array[Dictionary] = []
		_append_side_particles(desired, "outside", simulation.outside_molecule_ids())
		_append_side_particles(desired, "inside", simulation.outside_molecule_ids())
		return desired

	func _append_side_particles(desired: Array[Dictionary], side: String, ids: Array[String]) -> void:
		var counts := {}
		var side_count := 0
		for id in ids:
			var amount := float(simulation.outside_amounts.get(id, 0.0)) if side == "outside" else float(simulation.molecule_amounts.get(id, 0.0))
			if amount <= 0.01:
				continue
			var count := clampi(int(ceil(sqrt(maxf(amount, 0.0)) / (2.8 if side == "outside" else 2.2))), 1, 26)
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
		_draw_scene_background(rect)
		_draw_layered_membrane()
		draw_string(ThemeDB.fallback_font, Vector2(18, 32), "EXTRACELLULAR SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.82, 0.94, 0.96, 0.66))
		draw_string(ThemeDB.fallback_font, Vector2(18, size.y - 24), "CYTOPLASM", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.88, 0.78, 0.62))
		if simulation == null:
			return
		_draw_transporter_proteins()

	func _draw_scene_background(rect: Rect2) -> void:
		draw_rect(rect, Color("102b34"), true)
		var anchor := _anchor_points(96, 0.0, false)
		var outside_poly := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0)])
		for i in range(anchor.size() - 1, -1, -1):
			outside_poly.append(anchor[i])
		var inside_poly := PackedVector2Array()
		for point in anchor:
			inside_poly.append(point)
		inside_poly.append(Vector2(size.x, size.y))
		inside_poly.append(Vector2(0, size.y))
		draw_colored_polygon(outside_poly, Color("123d49"))
		draw_colored_polygon(inside_poly, Color("f2b58c"))
		for i in 18:
			var t := float(i) / 17.0
			draw_rect(Rect2(Vector2(0, size.y * t), Vector2(size.x, size.y / 18.0 + 1.0)), Color(0.58, 0.95, 1.0, 0.025 * (1.0 - t)), true)
		draw_circle(Vector2(size.x * 0.50, size.y * 0.77), size.x * 0.56, Color(1.0, 0.73, 0.54, 0.16))
		draw_circle(Vector2(size.x * 0.54, size.y * 0.78), size.x * 0.42, Color(1.0, 0.93, 0.78, 0.08))
		for i in 22:
			var y := lerpf(22.0, size.y * 0.45, float(i) / 21.0)
			var wave := sin(_elapsed * 0.16 + float(i) * 0.62) * 18.0
			draw_line(Vector2(-40.0, y + wave), Vector2(size.x + 40.0, y - 28.0 + wave), Color(0.72, 0.96, 1.0, 0.035), 2.0, true)
		for i in 36:
			var seed := float(abs(("water-speck:%d" % i).hash() % 10000)) / 10000.0
			var p := Vector2(lerpf(20.0, size.x - 20.0, fmod(seed * 7.31, 1.0)), lerpf(22.0, size.y - 22.0, fmod(seed * 11.17, 1.0)))
			var drift := Vector2(sin(_elapsed * 0.08 + seed * 17.0), cos(_elapsed * 0.07 + seed * 13.0)) * 5.0
			draw_circle(p + drift, 1.2 + fmod(seed * 5.0, 2.2), Color(0.82, 1.0, 0.94, 0.08 + seed * 0.06))

	func _draw_layered_membrane() -> void:
		if membrane_texture != null:
			_draw_tiled_membrane()
			return
		_draw_curved_membrane()

	func _draw_tiled_membrane() -> void:
		var tile_count := 12
		var spacing := 1.0 / float(tile_count)
		var phase := fposmod(_membrane_scroll / VISIBLE_MEMBRANE_ARC * spacing, spacing)
		for i in range(-1, tile_count + 1):
			var t := (float(i) + 0.5) * spacing + phase
			if t < -0.08 or t > 1.08:
				continue
			_draw_membrane_tile(t, 1.0, 0.0, 1.0)

	func _draw_membrane_tile(t: float, scale: float, layer_offset: float, alpha: float) -> void:
		var sample := _anchor_sample(t, false)
		var anchor: Vector2 = sample["point"]
		var tangent: Vector2 = sample["tangent"]
		var normal: Vector2 = sample["inside_normal"]
		var source_size := membrane_texture.get_size()
		var source := Rect2(Vector2.ZERO, source_size)
		var target_height := 112.0 * scale
		var target_width := 170.0 * scale
		var center := anchor + normal * layer_offset
		var angle := tangent.angle()
		var rect := Rect2(Vector2(-target_width * 0.5, -target_height * 0.5), Vector2(target_width, target_height))
		draw_set_transform(center, angle, Vector2.ONE)
		draw_texture_rect_region(membrane_texture, rect, source, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _anchor_points(steps: int, layer_offset: float = 0.0, animated: bool = true) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in steps + 1:
			var t := float(i) / float(steps)
			points.append(_anchor_sample(t, animated)["point"] + Vector2(0, layer_offset))
		return points

	func _anchor_sample(t: float, animated: bool = true) -> Dictionary:
		var x := lerpf(-size.x * 0.12, size.x * 1.12, t)
		var arch := -sin(t * PI) * size.y * 0.15
		var wave := 0.0
		if animated:
			wave = sin(t * TAU * 1.55 - _elapsed * 0.95) * 5.2 + sin(t * TAU * 3.1 + _elapsed * 0.72) * 1.5
		var point := Vector2(x, size.y * 0.67 + arch + wave)
		var dt := 0.006
		var p2 := _anchor_point_static(clampf(t + dt, 0.0, 1.0), animated)
		var p1 := _anchor_point_static(clampf(t - dt, 0.0, 1.0), animated)
		var tangent := (p2 - p1).normalized()
		var inside_normal := Vector2(-tangent.y, tangent.x)
		if inside_normal.y < 0.0:
			inside_normal = -inside_normal
		return {"point": point, "tangent": tangent, "inside_normal": inside_normal}

	func _anchor_point_static(t: float, animated: bool) -> Vector2:
		var x := lerpf(-size.x * 0.12, size.x * 1.12, t)
		var arch := -sin(t * PI) * size.y * 0.15
		var wave := 0.0
		if animated:
			wave = sin(t * TAU * 1.55 - _elapsed * 0.95) * 5.2 + sin(t * TAU * 3.1 + _elapsed * 0.72) * 1.5
		return Vector2(x, size.y * 0.67 + arch + wave)

	func _draw_curved_membrane() -> void:
		var center := Vector2(size.x * 0.52, size.y * 1.04)
		var rx := size.x * 0.74
		var top_ry := size.y * 0.56
		var bottom_ry := top_ry + 56.0
		var top_points := _ellipse_arc_points(center, rx, top_ry, PI * 1.08, PI * 1.92, 96)
		var bottom_points := _ellipse_arc_points(center, rx, bottom_ry, PI * 1.08, PI * 1.92, 96)
		var band := PackedVector2Array()
		for p in top_points:
			band.append(p)
		for i in range(bottom_points.size() - 1, -1, -1):
			band.append(bottom_points[i])
		draw_colored_polygon(band, Color("9e6a43"))
		for i in 4:
			var offset := float(i) * 8.0
			draw_polyline(_ellipse_arc_points(center, rx, top_ry + 12.0 + offset, PI * 1.08, PI * 1.92, 96), Color(0.26, 0.11, 0.06, 0.22), 1.6, true)
		draw_polyline(top_points, Color("02070b"), 12.0, true)
		draw_polyline(bottom_points, Color("02070b"), 12.0, true)
		draw_polyline(top_points, Color("74c6e4"), 8.0, true)
		draw_polyline(bottom_points, Color("74c6e4"), 8.0, true)
		for i in 92:
			var t := float(i) / 91.0
			var angle := lerpf(PI * 1.08, PI * 1.92, t)
			var top := center + Vector2(cos(angle) * rx, sin(angle) * top_ry)
			var bottom := center + Vector2(cos(angle) * rx, sin(angle) * bottom_ry)
			var wobble := sin(_elapsed * 0.8 + float(i) * 0.45) * 1.4
			var normal := (bottom - top).normalized()
			var tangent := Vector2(-normal.y, normal.x)
			var tail_start := top + normal * 9.0 + tangent * wobble
			var tail_end := bottom - normal * 9.0 - tangent * wobble
			draw_line(tail_start, tail_end, Color("33160c"), 4.0, true)
			draw_line(tail_start, tail_end, Color("d89a69"), 2.4, true)
			draw_circle(top, 7.2, Color("02070b"))
			draw_circle(bottom, 7.2, Color("02070b"))
			draw_circle(top, 5.8, Color("80cce8"))
			draw_circle(bottom, 5.8, Color("80cce8"))
			draw_circle(top + Vector2(-1.4, -1.6), 2.0, Color(1, 1, 1, 0.25))
			draw_circle(bottom + Vector2(-1.4, -1.6), 2.0, Color(1, 1, 1, 0.20))
		draw_polyline(top_points, Color(0.55, 1.0, 1.0, 0.28), 2.0, true)
		draw_polyline(bottom_points, Color(0.55, 1.0, 1.0, 0.20), 2.0, true)

	func _draw_transporter_proteins() -> void:
		var arrows: Array = simulation.membrane_transport_arrows()
		var total := arrows.size()
		if total <= 0:
			return
		for i in total:
			var arrow: Dictionary = arrows[i]
			var world_t := (float(i) + 0.5) / float(total)
			var screen_t := _world_to_visible_t(world_t)
			if screen_t < 0.0:
				continue
			var t := screen_t
			var placement := _membrane_placement(t)
			var top: Vector2 = placement["top"]
			var bottom: Vector2 = placement["bottom"]
			var mid: Vector2 = top.lerp(bottom, 0.5)
			var normal: Vector2 = placement["normal"]
			var tangent: Vector2 = placement["tangent"]
			var protein_color: Color = _source_color(str(arrow.get("molecule", ""))).lightened(0.12)
			var count := maxi(1, int(arrow.get("count", 0)) + int(arrow.get("queued_count", 0)))
			var copies := 1
			for copy_index in range(copies - 1, -1, -1):
				var depth := float(copy_index) / float(maxi(1, copies - 1))
				var offset := tangent * (-depth * 22.0) - normal * (depth * 34.0)
				var scale := 1.0 - depth * 0.20
				var alpha := 1.0
				_draw_single_transporter(top + offset, bottom + offset, tangent, normal, protein_color, scale, alpha, copy_index == 0)

	func _world_to_visible_t(world_t: float) -> float:
		var rel := fposmod(world_t - _membrane_scroll + 0.5, 1.0) - 0.5
		var half_visible := VISIBLE_MEMBRANE_ARC * 0.5
		if absf(rel) > half_visible:
			return -1.0
		return clampf(rel / VISIBLE_MEMBRANE_ARC + 0.5, 0.0, 1.0)

	func _visible_to_world_t(screen_t: float) -> float:
		return fposmod(_membrane_scroll + (screen_t - 0.5) * VISIBLE_MEMBRANE_ARC, 1.0)

	func _membrane_placement(t: float) -> Dictionary:
		var sample := _anchor_sample(t, true)
		var anchor: Vector2 = sample["point"]
		var normal: Vector2 = sample["inside_normal"]
		var top := anchor - normal * 48.0
		var bottom := anchor + normal * 48.0
		return {
			"top": top,
			"bottom": bottom,
			"normal": normal,
			"tangent": sample["tangent"]
		}

	func _draw_single_transporter(top: Vector2, bottom: Vector2, tangent: Vector2, normal: Vector2, base_color: Color, scale: float, alpha: float, front: bool) -> void:
		if transporter_texture != null:
			_draw_transporter_sprite(top, bottom, tangent, normal, base_color, scale, alpha, front)
			return
		var color := Color(base_color.r, base_color.g, base_color.b, alpha)
		var dark := Color(base_color.darkened(0.34).r, base_color.darkened(0.34).g, base_color.darkened(0.34).b, alpha)
		var light := Color(base_color.lightened(0.34).r, base_color.lightened(0.34).g, base_color.lightened(0.34).b, alpha)
		var top_pull := 56.0 * scale
		var bottom_push := 18.0 * scale if front else 4.0 * scale
		var bridge_a := top - normal * 20.0 * scale - tangent * 16.0 * scale
		var bridge_b := top - normal * 28.0 * scale + tangent * 16.0 * scale
		draw_line(bridge_a, bridge_b, Color(0.0, 0.02, 0.04, alpha), 22.0 * scale, true)
		draw_line(bridge_a, bridge_b, color.darkened(0.08), 16.0 * scale, true)
		for side in [-1.0, 1.0]:
			var lane := tangent * float(side) * 13.0 * scale
			var a := top + lane - normal * top_pull
			var b := bottom + lane + normal * bottom_push
			draw_line(a, b, Color(0.0, 0.02, 0.04, alpha), 20.0 * scale, true)
			draw_line(a, b, dark, 15.0 * scale, true)
			draw_line(a + tangent * 2.0 * scale, b + tangent * 2.0 * scale, light, 4.0 * scale, true)
			draw_circle(a, 9.5 * scale, Color(0.0, 0.02, 0.04, alpha))
			draw_circle(a, 7.0 * scale, color.lightened(0.18))
		var gate_top := top - normal * 10.0 * scale
		var gate_bottom := bottom + normal * (12.0 * scale if front else 1.0)
		draw_line(gate_top, gate_bottom, Color(0.0, 0.02, 0.04, alpha), 10.0 * scale, true)
		draw_line(gate_top, gate_bottom, color.lightened(0.06), 6.0 * scale, true)

	func _draw_transporter_sprite(top: Vector2, bottom: Vector2, tangent: Vector2, normal: Vector2, base_color: Color, scale: float, alpha: float, front: bool) -> void:
		var source := _transporter_source_rect(base_color)
		var membrane_height := top.distance_to(bottom)
		var target_height := membrane_height * (2.18 if front else 1.90) * scale
		var target_width := target_height * (source.size.x / source.size.y)
		var center := top.lerp(bottom, 0.52) - normal * (target_height * 0.02)
		var rect := Rect2(Vector2(-target_width * 0.5, -target_height * 0.5), Vector2(target_width, target_height))
		draw_set_transform(center, 0.0, Vector2.ONE)
		draw_texture_rect_region(transporter_texture, rect, source, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _transporter_source_rect(base_color: Color) -> Rect2:
		var sheet_size := transporter_texture.get_size()
		var slot_width := sheet_size.x / 4.0
		var index := 1
		if base_color.r > base_color.g and base_color.r > base_color.b:
			index = 2
		elif base_color.b > base_color.r and base_color.b > base_color.g:
			index = 1
		elif base_color.r > 0.55 and base_color.b > 0.55:
			index = 3
		return Rect2(Vector2(slot_width * float(index), 0.0), Vector2(slot_width, sheet_size.y))

	func _draw_transport_arrow(mid: Vector2, tangent: Vector2, normal: Vector2, direction: String, source_color: Color) -> void:
		var import_direction := direction == "import"
		var arrow_color := Color("89ff7b") if import_direction else Color("ff6c73")
		arrow_color = arrow_color.lerp(source_color.lightened(0.2), 0.18)
		var from := mid - normal * (82.0 if import_direction else -76.0)
		var to := mid + normal * (76.0 if import_direction else -82.0)
		draw_line(from, to, Color(0.0, 0.02, 0.03, 0.72), 10.0, true)
		draw_line(from, to, arrow_color, 5.0, true)
		draw_line(from, to, Color(1.0, 1.0, 1.0, 0.26), 1.8, true)
		var dir := (to - from).normalized()
		draw_colored_polygon(PackedVector2Array([to, to - dir * 16.0 + tangent * 8.5, to - dir * 16.0 - tangent * 8.5]), arrow_color)

	func _ellipse_arc_points(center: Vector2, rx: float, ry: float, start_angle: float, end_angle: float, steps: int) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in steps + 1:
			var angle := lerpf(start_angle, end_angle, float(i) / float(steps))
			points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		return points

	func _update_particle_transforms() -> void:
		for key in _particles.keys():
			var item: Dictionary = _particles[key]
			var node: Control = item.get("node", null)
			if node == null:
				continue
			var node_size := Vector2(8.5, 8.5) * (0.86 + float(item.get("depth", 0.7)) * 0.44)
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
			var y_min: float = 54.0 if side == "outside" else size.y * 0.63
			var y_max: float = size.y * 0.38 if side == "outside" else size.y - 72.0
			var screen_x_seed := _world_to_visible_t(x_seed)
			if screen_x_seed < 0.0:
				node.visible = false
				continue
			node.visible = true
			var x: float = lerpf(72.0, maxf(84.0, size.x - 96.0), screen_x_seed)
			var y: float = lerpf(y_min, y_max, y_seed)
			var drift := Vector2(
				sin(_elapsed * (0.12 + motion_seed * 0.06) + seed * 19.0),
				cos(_elapsed * (0.10 + motion_seed * 0.05) + seed * 13.0)
			) * (12.0 + 12.0 * depth)
			var perspective: float = 0.72 + depth * 0.28 + sin(_elapsed * 0.35 + seed * 23.0) * 0.018
			node.position = Vector2(x, y) + drift - node_size * 0.5
			node.rotation = sin(_elapsed * (0.16 + motion_seed * 0.08) + seed * TAU) * 0.18
			node.scale = Vector2(perspective, perspective)

	func _source_color(id: String) -> Color:
		if simulation != null and simulation.molecule_types.has(id):
			var molecule: Dictionary = simulation.molecule_types[id]
			var name := str(molecule.get("name", "")).to_lower()
			if name == "glucose" or str(molecule.get("formula", "")) == "C₆O₂":
				return Color("58d874")
			var formula := str(molecule.get("formula", ""))
			if formula.contains("N"):
				return Color("4da7ff")
			if formula.contains("P"):
				return Color("b85ff2")
			if formula.contains("S"):
				return Color("ffe069")
		var palette := [
			Color("64d66f"),
			Color("56a8ff"),
			Color("e95058"),
			Color("b956de"),
			Color("ffe064"),
			Color("5dd4d1"),
			Color("ff9c5a")
		]
		return palette[abs(id.hash()) % palette.size()]

	func _source_shape(id: String) -> String:
		if simulation != null and simulation.molecule_types.has(id):
			var molecule: Dictionary = simulation.molecule_types[id]
			var name := str(molecule.get("name", "")).to_lower()
			var formula := str(molecule.get("formula", ""))
			if name == "glucose" or formula == "C₆O₂":
				return "hexagon"
			if formula.contains("P"):
				return "diamond"
			if formula.contains("N"):
				return "circle"
			if formula.contains("S"):
				return "circle"
		return "circle"

class PhospholipidAnimationPreview:
	extends Control

	var head_color := Color("58c7ef")
	var tail_color := Color("f08b24")
	var _elapsed := 0.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0e2d34"), true)
		var center := size * 0.5 + Vector2(0, 4)
		var frame := int(floor(_elapsed * 8.0)) % 6
		var bend := sin(float(frame) / 6.0 * TAU) * 2.2
		var shine := 0.78 + 0.10 * sin(float(frame) / 6.0 * TAU)
		var radius := 26.0 + sin(float(frame) / 6.0 * TAU + 0.7) * 0.7
		var tail_top := center + Vector2(0, radius * 0.66)
		for side in [-1.0, 1.0]:
			var start := tail_top + Vector2(float(side) * 7.0, 0)
			var end := center + Vector2(float(side) * (12.0 + bend), 70.0)
			_draw_preview_tail(start, end, float(side), bend)
		draw_circle(center, radius + 3.0, Color("02070b"))
		draw_circle(center, radius, head_color)
		draw_circle(center + Vector2(radius * 0.20, -radius * 0.28), radius * 0.32, Color(1, 1, 1, shine))
		draw_arc(center, radius * 0.72, -1.0, 2.1, 18, Color(1, 1, 1, 0.13), 2.0, true)
		var frame_text := "frame %d/6" % (frame + 1)
		draw_string(ThemeDB.fallback_font, Vector2(12, size.y - 14), frame_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dbeff2"))

	func _draw_preview_tail(start: Vector2, end: Vector2, side: float, bend: float) -> void:
		var points := PackedVector2Array()
		for i in 8:
			var t := float(i) / 7.0
			var wiggle := sin(t * TAU * 1.1 + bend * 0.7) * 2.0
			points.append(start.lerp(end, t) + Vector2(side * wiggle, 0))
		draw_polyline(points, Color("02070b"), 9.0, true)
		draw_polyline(points, tail_color, 6.2, true)
		draw_polyline(points, tail_color.lightened(0.34), 2.0, true)

class FloatingSourceParticle:
	extends Control

	var color := Color("64d66f")
	var shape := "circle"
	var seed := 0.0
	var formula := ""
	var _elapsed := 0.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.38
		var pulse := 0.5 + 0.5 * sin(_elapsed * 0.7 + seed * TAU)
		draw_circle(center + Vector2(0, radius * 0.24), radius * 1.05, Color(0.0, 0.0, 0.0, 0.22))
		if shape == "hexagon":
			_draw_regular_polygon(center, radius + 3.0, 6, Color("02070b"))
			_draw_regular_polygon(center, radius + 0.5, 6, color.lightened(0.18))
			_draw_regular_polygon(center, radius - 2.0, 6, color.darkened(0.05))
			draw_circle(center + Vector2(radius * 0.22, -radius * 0.30), radius * 0.16, Color(1, 1, 1, 0.34))
		elif shape == "diamond":
			_draw_regular_polygon(center, radius + 3.0, 4, Color("02070b"), PI * 0.25)
			_draw_regular_polygon(center, radius + 0.5, 4, color.lightened(0.20), PI * 0.25)
			_draw_regular_polygon(center, radius - 2.0, 4, color.darkened(0.08), PI * 0.25)
			draw_circle(center + Vector2(radius * 0.22, -radius * 0.30), radius * 0.15, Color(1, 1, 1, 0.32))
		else:
			draw_circle(center, radius + 3.0, Color("02070b"))
			draw_circle(center, radius + 1.0, color.lightened(0.22))
			draw_circle(center, radius - 1.0, color.darkened(0.10))
			draw_arc(center, radius * (0.56 + pulse * 0.08), -0.9, 2.3, 24, Color(1, 1, 1, 0.14), 2.0, true)
			draw_circle(center + Vector2(radius * 0.28, -radius * 0.38), radius * 0.18, Color(1, 1, 1, 0.38))

	func _draw_regular_polygon(center: Vector2, radius: float, sides: int, fill: Color, rotation_offset: float = 0.0) -> void:
		var points := PackedVector2Array()
		for i in sides:
			var angle := rotation_offset - PI * 0.5 + TAU * float(i) / float(sides)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, fill)

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
		draw_string(ThemeDB.fallback_font, Vector2(36, size.y - 42.0), "Game designer: Elias Englund   Producer: Fredrik Jonsson", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cyan)

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
		draw_string(ThemeDB.fallback_font, Vector2(74, size.y - 24), "Game designer: Elias Englund   Producer: Fredrik Jonsson", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(cyan.r, cyan.g, cyan.b, 0.85))

class DNATechTreeWorkspace:
	extends Control

	signal tech_clicked(tech_id: String)

	var simulation
	var pan_offset := Vector2.ZERO
	var _dragging := false
	var _last_mouse := Vector2.ZERO
	var _drag_distance := 0.0
	var _hovered := ""
	var _background: Texture2D
	var _strand: Texture2D
	var _icons := {}

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		pan_offset = _initial_pan_offset()
		_background = _texture_from_png_local("res://assets/dna_tree/background.png")
		_strand = _texture_from_png_local("res://assets/dna_tree/dna_strand_connector.png")
		if simulation != null:
			for tech in simulation.dna_techs():
				_icons[tech.get("id", "")] = _texture_from_png_local(str(tech.get("icon", "")))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_distance = 0.0
				_last_mouse = event.position
				mouse_default_cursor_shape = Control.CURSOR_MOVE
			else:
				if _dragging and _drag_distance <= 6.0:
					var tech_id := _tech_at(event.position)
					if not tech_id.is_empty():
						emit_signal("tech_clicked", tech_id)
				_dragging = false
				mouse_default_cursor_shape = Control.CURSOR_DRAG
		elif event is InputEventMouseMotion:
			_hovered = _tech_at(event.position)
			if _dragging:
				pan_offset += event.position - _last_mouse
				pan_offset = pan_offset.clamp(Vector2(-1400.0, -1300.0), Vector2(1400.0, 720.0))
				_drag_distance += event.position.distance_to(_last_mouse)
				_last_mouse = event.position
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("07181c"), true)
		if _background != null:
			var bg_rect := Rect2(Vector2.ZERO, size)
			draw_texture_rect(_background, bg_rect, false, Color(1, 1, 1, 0.24))
		if simulation == null:
			return
		var center := size * 0.5 + pan_offset
		_draw_links(center)
		for tech in simulation.dna_techs():
			_draw_tech_node(tech, center)
		_draw_hint()

	func _draw_links(center: Vector2) -> void:
		for tech in simulation.dna_techs():
			var child_id := str(tech.get("id", ""))
			for parent_id in tech.get("parents", []):
				var parent: Dictionary = simulation.dna_tech_by_id(str(parent_id))
				if parent.is_empty():
					continue
				var parent_pos: Vector2 = center + parent.get("pos", Vector2.ZERO)
				var child_pos: Vector2 = center + tech.get("pos", Vector2.ZERO)
				var state: Dictionary = simulation.dna_tech_state(child_id)
				var cost := maxf(1.0, float(tech.get("cost", 1.0)))
				var progress := 1.0 if bool(state.get("unlocked", false)) else clampf(float(state.get("progress", 0.0)) / cost, 0.0, 1.0)
				_draw_dna_link(parent_pos, child_pos, progress, simulation.dna_tech_available(child_id))

	func _draw_dna_link(a: Vector2, b: Vector2, progress: float, available: bool) -> void:
		var delta := b - a
		var length := delta.length()
		if length < 10.0:
			return
		var dir := delta.normalized()
		var angle := dir.angle()
		var mid := a.lerp(b, 0.5)
		var transform := Transform2D(angle, mid)
		var rect := Rect2(Vector2(-length * 0.5, -18.0), Vector2(length, 36.0))
		if _strand != null:
			draw_set_transform_matrix(transform)
			draw_texture_rect(_strand, rect, false, Color(0.35, 0.55, 0.58, 0.34 if available else 0.18))
			if progress > 0.0:
				var progress_rect := Rect2(rect.position, Vector2(rect.size.x * progress, rect.size.y))
				draw_texture_rect(_strand, progress_rect, false, Color(0.55, 1.0, 0.72, 0.82))
			draw_set_transform_matrix(Transform2D())
		else:
			draw_line(a, b, Color(0.32, 0.82, 0.86, 0.30), 6.0, true)
			draw_line(a, a.lerp(b, progress), Color("8cff6a"), 6.0, true)

	func _draw_tech_node(tech: Dictionary, center: Vector2) -> void:
		var id := str(tech.get("id", ""))
		var pos: Vector2 = center + tech.get("pos", Vector2.ZERO)
		var state: Dictionary = simulation.dna_tech_state(id)
		var unlocked := bool(state.get("unlocked", false))
		var available: bool = simulation.dna_tech_available(id)
		var cost := maxf(1.0, float(tech.get("cost", 1.0)))
		var progress := 1.0 if unlocked else clampf(float(state.get("progress", 0.0)) / cost, 0.0, 1.0)
		var radius := 58.0 if id == "origin" else 50.0
		var border := Color("8cff6a") if unlocked else (Color("76f4ff") if available else Color("415962"))
		var fill := Color(0.05, 0.13, 0.16, 0.96)
		draw_circle(pos, radius + 10.0, Color(border.r, border.g, border.b, 0.13 if available else 0.05))
		draw_circle(pos, radius + 3.0, Color("02070b"))
		draw_circle(pos, radius, fill)
		draw_arc(pos, radius + 2.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color("8cff6a"), 5.0, true)
		draw_arc(pos, radius + 2.0, 0.0, TAU, 64, border, 2.0, true)
		var icon: Texture2D = _icons.get(id, null)
		if icon != null:
			var icon_rect := Rect2(pos - Vector2(radius * 0.68, radius * 0.68), Vector2(radius * 1.36, radius * 1.36))
			var tint := Color(1, 1, 1, 1.0 if unlocked or available else 0.32)
			if not unlocked and not available:
				tint = Color(0.48, 0.58, 0.60, 0.34)
			draw_texture_rect(icon, icon_rect, false, tint)
		if not unlocked and not available:
			draw_circle(pos, radius, Color(0, 0, 0, 0.48))
		var label_color := Color("f4fbff") if unlocked or available else Color("71878c")
		draw_string(ThemeDB.fallback_font, pos + Vector2(-70.0, radius + 28.0), str(tech.get("name", id)), HORIZONTAL_ALIGNMENT_CENTER, 140.0, 13, label_color)
		if id == _hovered:
			_draw_tech_tooltip(tech, pos, progress, unlocked, available)

	func _draw_tech_tooltip(tech: Dictionary, pos: Vector2, progress: float, unlocked: bool, available: bool) -> void:
		var rect := Rect2(pos + Vector2(62.0, -48.0), Vector2(210.0, 82.0))
		draw_rect(rect, Color(0.04, 0.10, 0.13, 0.94), true)
		draw_rect(rect, Color("76f4ff"), false, 1.4)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 22), str(tech.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f4fbff"))
		var status := "Unlocked" if unlocked else ("Available" if available else "Locked")
		var cost := float(tech.get("cost", 0.0))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 45), "%s  %.0f/%.0f DNA" % [status, progress * cost, cost], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8cff6a") if available else Color("9aaeb2"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 66), "Click to invest 50 DNA points", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dbeff2"))

	func _draw_hint() -> void:
		var text := "DNA Points %.0f | Drag to pan | Click available technologies to research" % float(simulation.resources.get("DNA Points", 0.0))
		draw_string(ThemeDB.fallback_font, Vector2(28.0, size.y - 26.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dbeff2"))

	func _tech_at(local: Vector2) -> String:
		if simulation == null:
			return ""
		var center := size * 0.5 + pan_offset
		for tech in simulation.dna_techs():
			var id := str(tech.get("id", ""))
			var radius := 58.0 if id == "origin" else 50.0
			var pos: Vector2 = center + tech.get("pos", Vector2.ZERO)
			if local.distance_to(pos) <= radius:
				return id
		return ""

	func _initial_pan_offset() -> Vector2:
		if simulation == null:
			return Vector2.ZERO
		var origin: Dictionary = simulation.dna_tech_by_id("origin")
		if origin.is_empty():
			return Vector2.ZERO
		var origin_pos: Vector2 = origin.get("pos", Vector2.ZERO)
		return -origin_pos

	func _texture_from_png_local(path: String) -> Texture2D:
		var image := Image.load_from_file(path)
		if image == null:
			return null
		return ImageTexture.create_from_image(image)
