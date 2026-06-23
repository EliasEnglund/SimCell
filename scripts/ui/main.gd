extends Control

const CellViewScript := preload("res://scripts/ui/cell_view.gd")
const MoleculeCanvasScript := preload("res://scripts/ui/molecule_canvas.gd")
const MetabolismWorkspaceScript := preload("res://scripts/ui/metabolism_workspace.gd")
const MapDesignerViewScript := preload("res://scripts/ui/map_designer_view.gd")
const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")
const MoleculeGraphScript := preload("res://scripts/core/molecule_graph.gd")

const VIEW_ICON_PATHS := {
	"cell": "res://assets/art_lab/icons/views/cell.png",
	"exploration": "res://assets/art_lab/icons/views/exploration.png",
	"metabolism": "res://assets/art_lab/icons/views/metabolism.png",
	"membrane": "res://assets/art_lab/icons/views/membrane.png",
	"proteins": "res://assets/art_lab/icons/views/proteins.png",
	"dna": "res://assets/art_lab/icons/views/dna.png",
	"art_lab": "res://assets/art_lab/icons/views/art_lab.png",
	"map_designer": "res://assets/art_lab/icons/views/map_designer.png"
}
const ENZYME_SELECTOR_SHEET := "res://assets/art_lab/enzyme_selector/enzyme_selector_runtime_atlas.png"

var sim = SimulationStateScript.new()
var root: VBoxContainer
var content: Control
var bottom_nav: BoxContainer
var nav_buttons := {}
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
var membrane_transporter_list: VBoxContainer
var membrane_import_detail: VBoxContainer
var membrane_export_detail: VBoxContainer
var membrane_scene: Control
var membrane_build_button: Button
var selected_membrane_molecule := ""
var selected_membrane_direction := "import"
var hovered_membrane_molecule := ""
var membrane_outside_signature := ""
var membrane_transporter_signature := ""
var membrane_scroll := 0.5
var membrane_transporter_slots := {}
var selected_pathway := ""
var metabolism_layout_positions := {}
var metabolism_manual_positions := {}
var metabolism_goal_positions := {}
var metabolism_route_bends := {}
var metabolism_import_sources := {}
var metabolism_pan_offset := Vector2.ZERO
var metabolism_zoom := 1.0
var metabolism_molecule_list_signature := ""
var metabolism_molecule_buttons := {}
var hovered_metabolism_molecule := ""
var exploration_state := {}

var designer_tool := "dehydrogenase"
var designer_category := ""
var designer_target := -1
var designer_preview: HBoxContainer
var designer_canvas: Control
var designer_info_panel: VBoxContainer
var enzyme_selector_sheet_texture: Texture2D

func _ready() -> void:
	get_tree().auto_accept_quit = true
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
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
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	var nav_panel := PanelContainer.new()
	nav_panel.custom_minimum_size = Vector2(74, 0)
	nav_panel.add_theme_stylebox_override("panel", _side_nav_panel_style())
	body.add_child(nav_panel)
	bottom_nav = VBoxContainer.new()
	bottom_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_nav.add_theme_constant_override("separation", 8)
	nav_panel.add_child(bottom_nav)
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	for item in [
		["Cell", "cell"],
		["Explore", "exploration"],
		["Metabolism", "metabolism"],
		["Membrane", "membrane"],
		["Proteins", "proteins"],
		["DNA", "dna"],
		["Art Lab", "art_lab"],
		["Map Designer", "map_designer"]
	]:
		var button := Button.new()
		button.text = ""
		button.icon = _texture_from_png(str(VIEW_ICON_PATHS.get(item[1], "")))
		button.expand_icon = true
		button.custom_minimum_size = Vector2(52, 52)
		button.tooltip_text = item[0]
		button.set_meta("view_id", item[1])
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _transparent_nav_style())
		button.add_theme_stylebox_override("hover", _transparent_nav_style(Color(0.45, 1.0, 1.0, 0.12)))
		button.add_theme_stylebox_override("pressed", _transparent_nav_style(Color(0.55, 1.0, 0.78, 0.16)))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(func(view_id = item[1]): _show_view(view_id))
		bottom_nav.add_child(button)
		nav_buttons[item[1]] = button

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
	elif view_id == "exploration":
		_build_exploration_view()
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
	elif view_id == "map_designer":
		_build_map_designer_view()
	_refresh()
	_update_nav_buttons()

func _update_nav_buttons() -> void:
	for view_id in nav_buttons.keys():
		var button: Button = nav_buttons[view_id]
		var active: bool = str(view_id) == sim.active_view
		button.self_modulate = Color(1, 1, 1, 1) if active else Color(0.72, 0.86, 0.88, 0.78)
		button.add_theme_stylebox_override("normal", _transparent_nav_style(Color(0.50, 1.0, 0.90, 0.14) if active else Color.TRANSPARENT, active))
		button.add_theme_stylebox_override("hover", _transparent_nav_style(Color(0.45, 1.0, 1.0, 0.16), active))
		button.add_theme_stylebox_override("pressed", _transparent_nav_style(Color(0.55, 1.0, 0.78, 0.20), true))

func _build_cell_view() -> void:
	var cell_view = CellViewScript.new()
	cell_view.simulation = sim
	cell_view.view_mode = "overview"
	cell_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	cell_view.clip_contents = true
	content.add_child(cell_view)

func _build_exploration_view() -> void:
	var cell_view = CellViewScript.new()
	cell_view.simulation = sim
	cell_view.view_mode = "exploration"
	cell_view.set_persistent_state(exploration_state)
	cell_view.state_changed.connect(func(next_state: Dictionary):
		exploration_state = next_state
	)
	cell_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	cell_view.clip_contents = true
	content.add_child(cell_view)

func _build_map_designer_view() -> void:
	var designer = MapDesignerViewScript.new()
	designer.set_anchors_preset(Control.PRESET_FULL_RECT)
	designer.clip_contents = true
	content.add_child(designer)

func _build_metabolism_view() -> void:
	metabolism_molecule_list_signature = ""
	metabolism_molecule_buttons = {}
	hovered_metabolism_molecule = ""
	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	content.add_child(layout)

	var side_shell := PanelContainer.new()
	side_shell.custom_minimum_size = Vector2(340, 0)
	side_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_shell.add_theme_stylebox_override("panel", _metabolism_panel_style())
	layout.add_child(side_shell)
	var side := VBoxContainer.new()
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	side_shell.add_child(side)
	var title := Label.new()
	title.text = "METABOLISM CONTROL"
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color("adfaff")
	side.add_child(title)
	side.add_child(_section_label("Molecules In Cell"))
	var molecule_scroll := ScrollContainer.new()
	molecule_scroll.custom_minimum_size = Vector2(0, 170)
	molecule_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	molecule_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(molecule_scroll)
	molecule_list = VBoxContainer.new()
	molecule_list.add_theme_constant_override("separation", 8)
	molecule_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	molecule_scroll.add_child(molecule_list)
	side.add_child(_section_label("Selection"))
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(0, 270)
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(detail_scroll)
	detail_panel = VBoxContainer.new()
	detail_panel.add_theme_constant_override("separation", 10)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_panel)
	pathway_box = VBoxContainer.new()

	map_layer = Control.new()
	map_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_layer.clip_contents = true
	layout.add_child(map_layer)
	metabolism_workspace = MetabolismWorkspaceScript.new()
	metabolism_workspace.simulation = sim
	metabolism_workspace.use_persistent_layout(metabolism_layout_positions, metabolism_manual_positions, metabolism_goal_positions, metabolism_route_bends, metabolism_import_sources)
	metabolism_workspace.use_persistent_camera(metabolism_pan_offset, metabolism_zoom)
	metabolism_workspace.camera_changed.connect(func(new_pan: Vector2, new_zoom: float):
		metabolism_pan_offset = new_pan
		metabolism_zoom = new_zoom
	)
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
	membrane_outside_signature = ""
	membrane_transporter_signature = ""

	var left_panel := _membrane_side_panel("MEMBRANE INVENTORY")
	left_panel.custom_minimum_size = Vector2(340, 0)
	layout.add_child(left_panel)
	left_panel.add_child(_section_label("Active Import / Export"))
	var transporter_scroll := ScrollContainer.new()
	transporter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transporter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(transporter_scroll)
	membrane_transporter_list = VBoxContainer.new()
	membrane_transporter_list.add_theme_constant_override("separation", 8)
	membrane_transporter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transporter_scroll.add_child(membrane_transporter_list)
	membrane_import_detail = VBoxContainer.new()
	membrane_import_detail.add_theme_constant_override("separation", 10)
	membrane_export_detail = VBoxContainer.new()
	membrane_export_detail.add_theme_constant_override("separation", 10)

	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	membrane_scene = _membrane_cross_section()
	membrane_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(membrane_scene)
	membrane_build_button = Button.new()
	membrane_build_button.visible = false
	membrane_build_button.text = "Build Importer"
	membrane_build_button.custom_minimum_size = Vector2(190, 44)
	membrane_build_button.add_theme_font_size_override("font_size", 16)
	membrane_build_button.add_theme_stylebox_override("normal", _build_importer_button_style(false))
	membrane_build_button.add_theme_stylebox_override("hover", _build_importer_button_style(true))
	membrane_build_button.add_theme_stylebox_override("pressed", _build_importer_button_style(true))
	membrane_build_button.pressed.connect(_build_selected_importer)
	center.add_child(membrane_build_button)
	membrane_build_button.set_anchor(SIDE_LEFT, 0.5)
	membrane_build_button.set_anchor(SIDE_RIGHT, 0.5)
	membrane_build_button.set_anchor(SIDE_TOP, 1.0)
	membrane_build_button.set_anchor(SIDE_BOTTOM, 1.0)
	membrane_build_button.offset_left = -95
	membrane_build_button.offset_right = 95
	membrane_build_button.offset_top = -68
	membrane_build_button.offset_bottom = -24

	var right_panel := _membrane_side_panel("OUTSIDE MOLECULES")
	right_panel.custom_minimum_size = Vector2(340, 0)
	right_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	right_panel.set_deferred("mouse_filter", Control.MOUSE_FILTER_STOP)
	right_panel.gui_input.connect(_handle_membrane_empty_click)
	layout.add_child(right_panel)
	right_panel.add_child(_section_label("Extracellular Sources"))
	var outside_scroll := ScrollContainer.new()
	outside_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outside_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outside_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	outside_scroll.set_deferred("mouse_filter", Control.MOUSE_FILTER_STOP)
	outside_scroll.gui_input.connect(_handle_membrane_empty_click)
	right_panel.add_child(outside_scroll)
	membrane_outside_list = VBoxContainer.new()
	membrane_outside_list.add_theme_constant_override("separation", 9)
	membrane_outside_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outside_scroll.add_child(membrane_outside_list)

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
	stack.add_child(_title("ART LAB", "Current in-game icon references plus focused enzyme selector concepts. Old animation, membrane, molecule-style, and broad concept experiments are hidden from this view."))
	stack.add_child(_art_sheet_section("Enzyme Selector Icon Concepts", [
		["1 Reaction-forward card concepts", "res://assets/art_lab/enzyme_selector/enzyme_selector_icon_concepts_01.png"],
		["2 Element class and reaction icon concepts", "res://assets/art_lab/enzyme_selector/enzyme_selector_icon_concepts_02.png"]
	], 390.0))
	stack.add_child(_art_icon_section("Basic Resources", [
		["Energy (ATP)", "res://assets/art_lab/icons/resources/atp_simple.png"],
		["Electrons (NADH)", "res://assets/art_lab/icons/resources/nadh_simple.png"],
		["Amino Acids", "res://assets/art_lab/icons/resources/amino_acids_simple.png"],
		["DNA", "res://assets/art_lab/icons/resources/dna_simple.png"],
		["RNA", "res://assets/art_lab/icons/resources/rna_simple.png"]
	]))
	stack.add_child(_art_icon_section("Source Metabolites And Elements", [
		["Glucose", "res://assets/art_lab/icons/elements/glucose_simple.png"],
		["Nitrogen", "res://assets/art_lab/icons/elements/nitrogen_simple_clean.png"],
		["Sulfur", "res://assets/art_lab/icons/elements/sulfur_simple.png"],
		["Phosphorus", "res://assets/art_lab/icons/elements/phosphorus_simple.png"]
	]))
	stack.add_child(_art_icon_section("View Navigation", [
		["Cell", VIEW_ICON_PATHS["cell"]],
		["Exploration", VIEW_ICON_PATHS["exploration"]],
		["Metabolism", VIEW_ICON_PATHS["metabolism"]],
		["Membrane", VIEW_ICON_PATHS["membrane"]],
		["Proteins", VIEW_ICON_PATHS["proteins"]],
		["DNA", VIEW_ICON_PATHS["dna"]],
		["Art Lab", VIEW_ICON_PATHS["art_lab"]],
		["Map Designer", VIEW_ICON_PATHS["map_designer"]]
	], 132.0))
	stack.add_child(_art_sheet_section("Generated Sheets", [
		["Simple Resources", "res://assets/art_lab/sheets/resource_icons_simple_sheet.png"],
		["Simple Elements", "res://assets/art_lab/sheets/source_icons_simple_sheet.png"],
		["Detailed Resources", "res://assets/art_lab/sheets/resource_icons_sheet.png"],
		["Detailed Elements", "res://assets/art_lab/sheets/source_icons_sheet.png"],
		["Views", "res://assets/art_lab/sheets/view_icons_sheet.png"]
	]))

func _art_exploration_cell_concepts_section() -> Control:
	var panel := _glow_panel("Exploration Cell Concepts")
	var note := Label.new()
	note.text = "Generated bitmap tests for replacing the code-drawn exploration cell. The animation preview cycles frames to test a living membrane / flagellum feel without redrawing the cell in code."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	panel.add_child(_art_sheet_section("Rendered Exploration Styles", [
		["Four rendered directions: painterly, microscope illustration, clean sprite, watercolor", "res://assets/art_lab/exploration/cell-rendered-concepts.png"]
	], 360.0))
	panel.add_child(_art_sheet_section("Pixel Exploration Styles", [
		["Four pixel-art directions: crisp 16-bit, detailed 32-bit, chunky arcade, glowing hybrid", "res://assets/art_lab/exploration/cell-pixel-concepts.png"]
	], 360.0))
	panel.add_child(_art_sheet_section("Exploration Background And Parallax", [
		["Generated swimming-background concept, used behind the current exploration view", "res://assets/art_lab/exploration/exploration-background.png"],
		["Transparent parallax particle overlay, intended to move at a different speed than the camera", "res://assets/art_lab/exploration/parallax-particles-alpha.png"]
	], 300.0))
	panel.add_child(_art_sheet_section("Exploration Object Concepts", [
		["Transparent static sprites: bacteria, glucose, sulfur, nitrogen, broken cells, virus/debris", "res://assets/art_lab/exploration/exploration-objects-alpha.png"],
		["Transparent idle-animation concept rows: bacteria, glucose, sulfur, broken cell", "res://assets/art_lab/exploration/exploration-object-animation-alpha.png"]
	], 360.0))
	var cycle_panel := _glow_panel("Sprite Cycle Test")
	var cycle_note := Label.new()
	cycle_note.text = "This preview reads a six-frame generated sheet and cycles it. It is a quick test of using pre-rendered frames for membrane breathing and flagellum movement."
	cycle_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cycle_note.modulate = Color("dbeff2")
	cycle_panel.add_child(cycle_note)
	var preview := CellSpriteCyclePreview.new()
	preview.sheet_path = "res://assets/art_lab/exploration/cell-animation-cycle.png"
	preview.frame_count = 6
	preview.custom_minimum_size = Vector2(760, 230)
	cycle_panel.add_child(preview)
	panel.add_child(cycle_panel)
	return panel

func _art_flagellum_animation_section() -> Control:
	var panel := _glow_panel("Flagellum Animation Concepts")
	var note := Label.new()
	note.text = "Prototype-only flagellum sprite sheets. Each row is a separate state: idle, wind-up, and full swimming. The anchor dot marks where the sprite attaches to the cell, so the animation should cycle without jumping."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	panel.add_child(_art_sheet_section("Generated Flagellum Sheet", [
		["Variant 1: clean cyan filament. Rows: idle, wind-up, swim.", "res://assets/art_lab/exploration/flagellum-animation-alpha.png"],
		["Variant 2: thicker ribbon filament. Rows: idle, wind-up, swim.", "res://assets/art_lab/exploration/flagellum-ribbon-animation-alpha.png"],
		["Variant 3: organic filament. Rows: idle, wind-up, swim.", "res://assets/art_lab/exploration/flagellum-organic-animation-alpha.png"],
		["Variant 4: AI painted filament, used in exploration. Rows: idle, wind-up, swim.", "res://assets/art_lab/exploration/flagellum-ai-alpha.png"]
	], 330.0))
	var variants := [
		["1 Clean Cyan", "res://assets/art_lab/exploration/flagellum-animation-alpha.png"],
		["2 Ribbon", "res://assets/art_lab/exploration/flagellum-ribbon-animation-alpha.png"],
		["3 Organic", "res://assets/art_lab/exploration/flagellum-organic-animation-alpha.png"],
		["4 AI Painted", "res://assets/art_lab/exploration/flagellum-ai-alpha.png"]
	]
	for variant in variants:
		var title := Label.new()
		title.text = str(variant[0])
		title.add_theme_font_size_override("font_size", 16)
		title.modulate = Color("76f4ff")
		panel.add_child(title)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var states := [
			["Idle", 0],
			["Wind-up", 1],
			["Swim", 2]
		]
		for item in states:
			var card := VBoxContainer.new()
			card.custom_minimum_size = Vector2(270, 190)
			card.add_theme_constant_override("separation", 6)
			var preview := FlagellumSpritePreview.new()
			preview.sheet_path = str(variant[1])
			preview.row_index = int(item[1])
			preview.custom_minimum_size = Vector2(260, 150)
			card.add_child(preview)
			var label := Label.new()
			label.text = str(item[0])
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.modulate = Color("dbeff2")
			card.add_child(label)
			row.add_child(card)
	var attached_panel := _glow_panel("Attached Flagellum Rotation Test")
	var attached_note := Label.new()
	attached_note.text = "The same sheets attached to the current exploration cell sprite while the full cell rotates. This is for checking anchor placement before the flagellum is used in exploration."
	attached_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attached_note.modulate = Color("dbeff2")
	attached_panel.add_child(attached_note)
	var attached_row := HBoxContainer.new()
	attached_row.add_theme_constant_override("separation", 14)
	attached_panel.add_child(attached_row)
	for variant in variants:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(360, 300)
		card.add_theme_constant_override("separation", 6)
		var attached_preview := AttachedFlagellumPreview.new()
		attached_preview.cell_sheet_path = "res://assets/art_lab/exploration/player-cell-idle-alpha.png"
		attached_preview.flagellum_sheet_path = str(variant[1])
		attached_preview.flagellum_row_index = 2
		attached_preview.custom_minimum_size = Vector2(350, 250)
		card.add_child(attached_preview)
		var attached_label := Label.new()
		attached_label.text = str(variant[0])
		attached_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		attached_label.modulate = Color("dbeff2")
		card.add_child(attached_label)
		attached_row.add_child(card)
	panel.add_child(attached_panel)
	return panel

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

func _art_enzyme_card_variants_section() -> Control:
	var panel := _glow_panel("Enzyme Hover Card Variants")
	var note := Label.new()
	note.text = "These are hover-card directions for arrows in The Metabolism. Each card shows function, Kcat, Km, stability, amino-acid price, and heat effect. Pick the number that is easiest to read while still feeling like SimCell."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	panel.add_child(grid)
	var variants := [
		{
			"n": 1,
			"name": "Compact Tooltip",
			"subtitle": "LYASE | C-C bond cleavage",
			"function": "Splits one carbon-carbon bond and creates two downstream products.",
			"kcat": 1.2,
			"km": 18.0,
			"stability": 72.0,
			"price": 36.0,
			"heat": 0.8,
			"mode": 0,
			"accent": Color("8cff6a")
		},
		{
			"n": 2,
			"name": "Blueprint Card",
			"subtitle": "DEHYDROGENASE | redox step",
			"function": "Converts C-O into C=O and produces NADH. Strong output but adds redox pressure.",
			"kcat": 0.85,
			"km": 11.0,
			"stability": 54.0,
			"price": 52.0,
			"heat": 1.4,
			"mode": 1,
			"accent": Color("76f4ff")
		},
		{
			"n": 3,
			"name": "Kinetic Dashboard",
			"subtitle": "AMINASE | adds nitrogen",
			"function": "Consumes N and installs it on a two-carbon backbone to approach amino acid production.",
			"kcat": 0.42,
			"km": 7.5,
			"stability": 86.0,
			"price": 74.0,
			"heat": 0.35,
			"mode": 2,
			"accent": Color("7fa8ff")
		},
		{
			"n": 4,
			"name": "Cost And Risk",
			"subtitle": "DECARBOXYLASE | CO2 release",
			"function": "Removes a one-carbon gas product. Useful cleanup, but wastes carbon if overused.",
			"kcat": 1.75,
			"km": 24.0,
			"stability": 38.0,
			"price": 28.0,
			"heat": 2.0,
			"mode": 3,
			"accent": Color("ffb35f")
		},
		{
			"n": 5,
			"name": "Scientific Tooltip",
			"subtitle": "OXYGENASE | adds oxygen",
			"function": "Adds oxygen to a carbon site. Opens routes toward acids and energy extraction.",
			"kcat": 0.64,
			"km": 9.0,
			"stability": 62.0,
			"price": 48.0,
			"heat": 0.95,
			"mode": 4,
			"accent": Color("e95058")
		},
		{
			"n": 6,
			"name": "Game Readout",
			"subtitle": "PHOSPHORYLASE | ATP gate",
			"function": "Consumes ATP to prime the molecule for a higher-value downstream reaction.",
			"kcat": 0.58,
			"km": 13.0,
			"stability": 68.0,
			"price": 61.0,
			"heat": 1.1,
			"mode": 5,
			"accent": Color("b956de")
		}
	]
	for variant in variants:
		var card := EnzymeHoverCardMockup.new()
		card.custom_minimum_size = Vector2(440, 286)
		card.data = variant
		grid.add_child(card)
	return panel

func _art_enzyme_reaction_selector_section() -> Control:
	var panel := _glow_panel("Enzyme Reaction Selector Concepts")
	var note := Label.new()
	note.text = "Concept directions for organizing enzyme groups and sub-reactions in the enzyme designer. The intended hierarchy is element group first, then specific reaction action: carbon reactions, oxygen reactions, nitrogen reactions, sulfur reactions, and phosphate reactions."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	panel.add_child(_art_sheet_section("Selector Layout Sheets", [
		["1 Compact group selector", "res://assets/art_lab/enzyme_reactions/01_compact_group_selector.png"],
		["2 Expanded reaction drawer", "res://assets/art_lab/enzyme_reactions/02_expanded_reaction_drawer.png"],
		["3 Reaction storyboard cards", "res://assets/art_lab/enzyme_reactions/03_reaction_storyboard_cards.png"],
		["4 Scientific reaction cards", "res://assets/art_lab/enzyme_reactions/04_scientific_reaction_cards.png"],
		["5 Elemental radial selector", "res://assets/art_lab/enzyme_reactions/05_elemental_radial_selector.png"],
		["6 Premium hover panels", "res://assets/art_lab/enzyme_reactions/06_premium_hover_panels.png"]
	], 360.0))
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

func _art_ai_membrane_concepts_section() -> Control:
	var panel := _glow_panel("AI Artist Membrane Concepts")
	var note := Label.new()
	note.text = "Six raster concept directions for the membrane view. These are visual-direction tests, not yet the final scrollable membrane asset."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	var concepts := [
		["1 Painterly Depth", "res://assets/art_lab/membrane/ai_concepts/01_painterly_depth.png"],
		["2 Cinematic Microscope", "res://assets/art_lab/membrane/ai_concepts/02_cinematic_microscope.png"],
		["3 Game Concept High Contrast", "res://assets/art_lab/membrane/ai_concepts/03_game_concept_high_contrast.png"],
		["4 Bioluminescent Teal", "res://assets/art_lab/membrane/ai_concepts/04_bioluminescent_teal.png"],
		["5 Scientific Cutaway", "res://assets/art_lab/membrane/ai_concepts/05_scientific_cutaway.png"],
		["6 Deep Perspective Surface", "res://assets/art_lab/membrane/ai_concepts/06_deep_perspective_surface.png"]
	]
	for item in concepts:
		var title := Label.new()
		title.text = str(item[0])
		title.add_theme_font_size_override("font_size", 16)
		title.modulate = Color("76f4ff")
		panel.add_child(title)
		var texture := TextureRect.new()
		texture.texture = _texture_from_png(str(item[1]))
		texture.custom_minimum_size = Vector2(0.0, 320.0)
		texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(texture)
	return panel

func _art_prerendered_membrane_section() -> Control:
	var panel := _glow_panel("Prerendered Seamless Membrane Concepts")
	var note := Label.new()
	note.text = "Tileable raster membrane strips tested on a curved scrolling path. These are candidates for replacing the code-drawn membrane while still allowing horizontal membrane scrolling."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("dbeff2")
	panel.add_child(note)
	var variants := [
		["1 Depth Blue/Amber", "res://assets/art_lab/membrane/prerendered/membrane_depth_blue_amber.png"],
		["2 Dense Cyan Depth", "res://assets/art_lab/membrane/prerendered/membrane_cyan_dense_depth.png"],
		["3 Microscope Soft", "res://assets/art_lab/membrane/prerendered/membrane_microscope_soft.png"],
		["4 High Contrast Game", "res://assets/art_lab/membrane/prerendered/membrane_high_contrast_game.png"]
	]
	for item in variants:
		var title := Label.new()
		title.text = str(item[0])
		title.add_theme_font_size_override("font_size", 16)
		title.modulate = Color("76f4ff")
		panel.add_child(title)
		var preview := MembraneStripScrollPreview.new()
		preview.strip_path = str(item[1])
		preview.custom_minimum_size = Vector2(0, 270)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(preview)
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

func _enzyme_selector_card_texture(card_number: int) -> Texture2D:
	if card_number <= 0:
		return null
	if enzyme_selector_sheet_texture == null:
		enzyme_selector_sheet_texture = _texture_from_png(ENZYME_SELECTOR_SHEET)
	if enzyme_selector_sheet_texture == null:
		return null
	var region := _enzyme_selector_icon_region(card_number)
	if region.size == Vector2.ZERO:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = enzyme_selector_sheet_texture
	atlas.region = region
	return atlas

func _enzyme_selector_icon_region(card_number: int) -> Rect2:
	var regions := {
		1: Rect2(165, 76, 220, 150),
		2: Rect2(565, 92, 430, 122),
		3: Rect2(1080, 76, 420, 145),
		4: Rect2(72, 315, 410, 150),
		5: Rect2(565, 315, 425, 150),
		6: Rect2(1070, 292, 438, 168),
		7: Rect2(64, 520, 420, 165),
		8: Rect2(550, 515, 450, 170),
		9: Rect2(1080, 520, 420, 165),
		10: Rect2(70, 738, 440, 172),
		11: Rect2(560, 735, 440, 172),
		12: Rect2(1075, 748, 420, 150)
	}
	return regions.get(card_number, Rect2())

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
			["res://assets/art_lab/icons/elements/nitrogen_simple_clean.png", "%.1f" % float(sim.resources.get("N", 0.0)), Color("76a8ff"), "Nitrogen"],
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
	var next_outside_signature := _membrane_outside_signature()
	if next_outside_signature != membrane_outside_signature:
		membrane_outside_signature = next_outside_signature
		_clear(membrane_outside_list)
		for id in _outside_molecule_ids_by_amount():
			membrane_outside_list.add_child(_membrane_source_card(id, "outside"))
	_refresh_membrane_detail()
	var next_transporter_signature := _membrane_transporter_signature()
	if next_transporter_signature != membrane_transporter_signature:
		membrane_transporter_signature = next_transporter_signature
		_refresh_transporter_list()
	_apply_membrane_focus()

func _apply_membrane_focus() -> void:
	_ensure_membrane_transporter_slots()
	if membrane_build_button != null:
		membrane_build_button.visible = not selected_membrane_molecule.is_empty() and sim.molecule_types.has(selected_membrane_molecule)
		if membrane_build_button.visible:
			membrane_build_button.text = "Build %s Importer" % sim.molecule_types[selected_membrane_molecule].get("formula", "Molecule")
	if membrane_scene != null:
		membrane_scene.highlight_molecule = selected_membrane_molecule if not selected_membrane_molecule.is_empty() else hovered_membrane_molecule
		membrane_scene.transporter_slots = membrane_transporter_slots.duplicate(true)
		membrane_scene.update_from_simulation()

func _clear_membrane_selection() -> void:
	selected_membrane_molecule = ""
	selected_membrane_direction = "import"
	membrane_outside_signature = ""
	membrane_transporter_signature = ""
	_refresh_membrane()

func _handle_membrane_empty_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_clear_membrane_selection()
		accept_event()

func _build_selected_importer() -> void:
	if selected_membrane_molecule.is_empty():
		return
	if sim.build_transporter("import", selected_membrane_molecule):
		_ensure_membrane_transporter_slot("import", selected_membrane_molecule)
	membrane_transporter_signature = ""
	_refresh_membrane()

func _membrane_source_card(id: String, location: String) -> Button:
	var molecule: Dictionary = sim.molecule_types[id]
	var amount := float(sim.outside_amounts.get(id, 0.0)) if location == "outside" else float(sim.molecule_amounts.get(id, 0.0))
	var rates: Dictionary = sim.outside_rates.get(id, {"production": 0.0, "consumption": 0.0}) if location == "outside" else sim.molecule_rates.get(id, {"production": 0.0, "consumption": 0.0})
	var direction := "import" if location == "outside" else "export"
	var button := Button.new()
	var selected := selected_membrane_molecule == id and selected_membrane_direction == direction
	button.text = "%s  %-8s  %7.0f   %+.1f/s   x%d" % [
		_molecule_color_symbol(id),
		molecule.get("formula", "Molecule"),
		amount,
		-float(rates.get("consumption", 0.0) if location == "outside" else rates.get("production", 0.0)),
		sim.transporter_count(direction, id)
	]
	button.toggle_mode = true
	button.button_pressed = selected
	button.custom_minimum_size = Vector2(0, 34)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", _molecule_color(id).lightened(0.58))
	button.add_theme_color_override("font_hover_color", Color("f4fbff"))
	button.add_theme_color_override("font_pressed_color", Color("f4fbff"))
	button.add_theme_stylebox_override("normal", _membrane_list_row_style(selected, id, false))
	button.add_theme_stylebox_override("hover", _membrane_list_row_style(true, id, true))
	button.add_theme_stylebox_override("pressed", _membrane_list_row_style(true, id, false))
	button.pressed.connect(func():
		if selected_membrane_molecule == id and selected_membrane_direction == direction:
			selected_membrane_molecule = ""
			selected_membrane_direction = "import"
		else:
			selected_membrane_molecule = id
			selected_membrane_direction = direction
		membrane_outside_signature = ""
		membrane_transporter_signature = ""
		_refresh_membrane()
	)
	button.mouse_entered.connect(func():
		hovered_membrane_molecule = id
		_apply_membrane_focus()
	)
	button.mouse_exited.connect(func():
		if hovered_membrane_molecule == id:
			hovered_membrane_molecule = ""
			_apply_membrane_focus()
	)
	return button

func _refresh_membrane_detail() -> void:
	_clear(membrane_import_detail)
	_clear(membrane_export_detail)

func _refresh_transporter_list() -> void:
	_clear(membrane_transporter_list)
	var list := sim.transporter_list()
	if list.is_empty():
		membrane_transporter_list.add_child(_title("No transporters", "Build importers or exporters from the molecule lists."))
		return
	for transporter in list:
		membrane_transporter_list.add_child(_transporter_card(transporter))

func _transporter_card(transporter: Dictionary) -> Control:
	var molecule_id: String = transporter.get("molecule", "")
	var selected := selected_membrane_molecule == molecule_id and selected_membrane_direction == str(transporter.get("direction", ""))
	var box := GlowVBox.new()
	box.fill = Color("17303a") if selected else Color(0.05, 0.14, 0.18, 0.74)
	box.border = _molecule_color(molecule_id).lightened(0.20) if selected else Color("2f7080")
	box.border_width = 1.4 if selected else 0.8
	box.custom_minimum_size = Vector2(0, 58)
	box.add_theme_constant_override("separation", 2)
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 14)
	inset.add_theme_constant_override("margin_right", 12)
	inset.add_theme_constant_override("margin_top", 8)
	inset.add_theme_constant_override("margin_bottom", 8)
	box.add_child(inset)
	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 2)
	inset.add_child(labels)
	var molecule: Dictionary = sim.molecule_types.get(molecule_id, {})
	var name := Label.new()
	name.text = "%s %s" % [str(transporter.get("direction", "transport")).capitalize(), molecule.get("formula", "Molecule")]
	name.add_theme_font_size_override("font_size", 16)
	name.modulate = _molecule_color(molecule_id).lightened(0.44)
	labels.add_child(name)
	var detail := Label.new()
	var queued_count := int(transporter.get("queued_count", 0))
	var build_text := " | %d building" % queued_count if queued_count > 0 else ""
	detail.text = "%d active%s | %.1f/s total" % [int(transporter.get("count", 0)), build_text, float(transporter.get("rate", 0.0))]
	detail.modulate = Color("b9d4d8")
	labels.add_child(detail)
	return box

func _outside_molecule_ids_by_amount() -> Array[String]:
	var ids := sim.outside_molecule_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var amount_a := float(sim.outside_amounts.get(a, 0.0))
		var amount_b := float(sim.outside_amounts.get(b, 0.0))
		if not is_equal_approx(amount_a, amount_b):
			return amount_a > amount_b
		return sim.molecule_types[a].get("formula", "") < sim.molecule_types[b].get("formula", "")
	)
	return ids

func _membrane_outside_signature() -> String:
	var parts: Array[String] = [selected_membrane_molecule, selected_membrane_direction]
	for id in _outside_molecule_ids_by_amount():
		parts.append(id)
	return "|".join(parts)

func _membrane_transporter_signature() -> String:
	var parts: Array[String] = [selected_membrane_molecule, selected_membrane_direction]
	for transporter in sim.transporter_list():
		parts.append("%s:%s:%d:%d" % [
			transporter.get("direction", ""),
			transporter.get("molecule", ""),
			int(transporter.get("count", 0)),
			int(transporter.get("queued_count", 0))
		])
	return "|".join(parts)

func _membrane_cross_section() -> Control:
	_ensure_membrane_transporter_slots()
	var scene := MembraneCrossSection.new()
	scene.simulation = sim
	scene.transporter_slots = membrane_transporter_slots.duplicate(true)
	scene.set_scroll_position(membrane_scroll)
	scene.scroll_changed.connect(func(next_scroll: float):
		membrane_scroll = next_scroll
	)
	scene.custom_minimum_size = Vector2(0, 430)
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.clip_contents = true
	return scene

func _ensure_membrane_transporter_slots() -> void:
	var glucose_id := _glucose_molecule_id()
	if not glucose_id.is_empty():
		_ensure_membrane_transporter_slot("import", glucose_id)
	for transporter in sim.transporter_list():
		_ensure_membrane_transporter_slot(str(transporter.get("direction", "")), str(transporter.get("molecule", "")))

func _ensure_membrane_transporter_slot(direction: String, molecule_id: String) -> void:
	if direction.is_empty() or molecule_id.is_empty():
		return
	var key := "%s:%s" % [direction, molecule_id]
	if membrane_transporter_slots.has(key):
		return
	var next_slot := 0
	for value in membrane_transporter_slots.values():
		next_slot = maxi(next_slot, int(value) + 1)
	membrane_transporter_slots[key] = next_slot

func _refresh_metabolism() -> void:
	var ids := sim.present_molecule_ids()
	var signature := ",".join(ids)
	if signature != metabolism_molecule_list_signature:
		metabolism_molecule_list_signature = signature
		metabolism_molecule_buttons = {}
		_clear(molecule_list)
		for id in ids:
			var button := _molecule_list_button(id)
			metabolism_molecule_buttons[id] = button
			molecule_list.add_child(button)
	for id in ids:
		if metabolism_molecule_buttons.has(id):
			_update_molecule_list_button(metabolism_molecule_buttons[id], id)
	_refresh_selection_detail()
	if metabolism_workspace != null:
		metabolism_workspace.selected_pathway = selected_pathway
		metabolism_workspace.rebuild()

func _molecule_list_button(id: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 62)
	button.add_theme_font_size_override("font_size", 15)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_molecule_list_button(button, id)
	button.mouse_entered.connect(func():
		hovered_metabolism_molecule = id
		_set_metabolism_hover(id)
	)
	button.mouse_exited.connect(func():
		if hovered_metabolism_molecule == id:
			hovered_metabolism_molecule = ""
			_set_metabolism_hover("")
	)
	button.pressed.connect(func(): _handle_molecule_click(id))
	return button

func _update_molecule_list_button(button: Button, id: String) -> void:
	if not sim.molecule_types.has(id):
		return
	var molecule: Dictionary = sim.molecule_types[id]
	var rates: Dictionary = sim.molecule_rates.get(id, {"production": 0.0, "consumption": 0.0})
	button.text = "%s  %.1f\n+%.1f/s  -%.1f/s" % [
		molecule.get("formula", "Molecule"),
		float(sim.molecule_amounts.get(id, 0.0)),
		float(rates.get("production", 0.0)),
		float(rates.get("consumption", 0.0))
	]
	button.button_pressed = sim.selected_molecule == id
	var selected: bool = sim.selected_molecule == id
	var color := _molecule_color(id)
	button.add_theme_stylebox_override("normal", _metabolism_molecule_row_style(id, false, false))
	button.add_theme_stylebox_override("hover", _metabolism_molecule_row_style(id, false, true))
	button.add_theme_stylebox_override("pressed", _metabolism_molecule_row_style(id, true, false))
	button.add_theme_stylebox_override("focus", _metabolism_molecule_row_style(id, true, true))
	button.add_theme_color_override("font_color", color.lightened(0.46) if selected else Color("dbeff2"))
	button.add_theme_color_override("font_hover_color", color.lightened(0.60))
	button.add_theme_color_override("font_pressed_color", color.lightened(0.70))

func _set_metabolism_hover(id: String) -> void:
	if metabolism_workspace == null or metabolism_workspace.highlighted_molecule_id == id:
		return
	metabolism_workspace.highlighted_molecule_id = id
	metabolism_workspace.rebuild()

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
	button.add_theme_stylebox_override("normal", _build_importer_button_style(false))
	button.add_theme_stylebox_override("hover", _build_importer_button_style(true))
	button.add_theme_stylebox_override("pressed", _build_importer_button_style(true))
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
	var resource_delta: Dictionary = pathway.get("resource_delta", {})
	if not resource_delta.is_empty():
		metrics.text += "\nPer reaction: %s" % _resource_delta_text(resource_delta)
	var bond_strength := float(pathway.get("bond_strength", -1.0))
	if bond_strength >= 0.0:
		metrics.text += "\nTarget bond strength: %.0f%%" % bond_strength
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
	build_one.add_theme_stylebox_override("normal", _build_importer_button_style(false))
	build_one.add_theme_stylebox_override("hover", _build_importer_button_style(true))
	build_one.add_theme_stylebox_override("pressed", _build_importer_button_style(true))
	build_one.pressed.connect(func():
		sim.queue_enzyme_build(blueprint_id, 1)
	)
	row.add_child(build_one)
	var build_five := Button.new()
	build_five.text = "+ Build 5"
	build_five.custom_minimum_size = Vector2(0, 42)
	build_five.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_five.add_theme_stylebox_override("normal", _build_importer_button_style(false))
	build_five.add_theme_stylebox_override("hover", _build_importer_button_style(true))
	build_five.add_theme_stylebox_override("pressed", _build_importer_button_style(true))
	build_five.pressed.connect(func():
		sim.queue_enzyme_build(blueprint_id, 5)
	)
	row.add_child(build_five)
	detail_panel.add_child(row)
	var remove := Button.new()
	remove.text = "Destroy 1 Active Enzyme"
	remove.custom_minimum_size = Vector2(0, 42)
	remove.disabled = int(pathway.get("active_count", 0)) <= 0
	remove.add_theme_stylebox_override("normal", _build_importer_button_style(false))
	remove.add_theme_stylebox_override("hover", _build_importer_button_style(true))
	remove.add_theme_stylebox_override("pressed", _build_importer_button_style(true))
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
	select.add_theme_stylebox_override("normal", _build_importer_button_style(false))
	select.add_theme_stylebox_override("hover", _build_importer_button_style(true))
	select.add_theme_stylebox_override("pressed", _build_importer_button_style(true))
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
	if sim.active_view != "enzyme_designer":
		designer_category = ""
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
	_populate_enzyme_selector(tools)

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

func _populate_enzyme_selector(tools: VBoxContainer) -> void:
	var subheading := Label.new()
	subheading.add_theme_font_size_override("font_size", 13)
	subheading.modulate = Color(0.70, 0.90, 0.93)
	subheading.text = "REACTION CLASS" if designer_category == "" else "%s REACTIONS" % _enzyme_category_label(designer_category).to_upper()
	tools.add_child(subheading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 13)
	scroll.add_child(list)

	if designer_category == "":
		for category in _enzyme_categories():
			list.add_child(_enzyme_category_button(category))
	else:
		var category_tools := _enzyme_tools_for_category(designer_category)
		if category_tools.is_empty():
			list.add_child(_empty_enzyme_category_card(designer_category))
		for tool in category_tools:
			list.add_child(_tool_button(str(tool.get("id", "")), int(tool.get("card", 0)), str(tool.get("label", "")), str(tool.get("summary", ""))))
		var back := Button.new()
		back.text = "←  BACK TO REACTION CLASSES"
		back.custom_minimum_size = Vector2(0, 48)
		back.add_theme_font_size_override("font_size", 14)
		back.add_theme_stylebox_override("normal", _category_style(Color("22323f"), Color("73dfff"), false))
		back.add_theme_stylebox_override("hover", _category_style(Color("253d4c"), Color("73dfff"), true))
		back.add_theme_stylebox_override("pressed", _category_style(Color("253d4c"), Color("73dfff"), true))
		back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		back.pressed.connect(func():
			designer_category = ""
			_open_enzyme_designer(sim.selected_molecule)
		)
		tools.add_child(back)

func _enzyme_categories() -> Array[Dictionary]:
	return [
		{"id": "carbon", "label": "CARBON", "card": 1, "summary": "Harvest ATP from COOH ends, then unlock carbon reshaping", "color": Color("7fe6b7"), "tools": ["decarboxylase", "lyase", "desaturase"]},
		{"id": "oxygen", "label": "OXYGEN", "card": 2, "summary": "C-O, C=O, and COOH redox chemistry", "color": Color("77dfff"), "tools": ["dehydrogenase", "oxygenase", "reductase"]},
		{"id": "nitrogen", "label": "NITROGEN", "card": 3, "summary": "Assimilate nitrate, then install nitrogen groups for amino products", "color": Color("7ca7ff"), "tools": ["nitrate_reductase", "aminase"]},
		{"id": "sulfur", "label": "SULFUR", "card": 4, "summary": "Future sulfur chemistry", "color": Color("ffe36b"), "tools": []},
		{"id": "phosphate", "label": "PHOSPHATE", "card": 5, "summary": "Future ATP and nucleotide chemistry", "color": Color("c67cff"), "tools": []}
	]

func _enzyme_category_label(category_id: String) -> String:
	for category in _enzyme_categories():
		if str(category.get("id", "")) == category_id:
			return str(category.get("label", "Reaction"))
	return "Reaction"

func _enzyme_category_for_tool(tool_id: String) -> String:
	for category in _enzyme_categories():
		var tools: Array = category.get("tools", [])
		if tools.has(tool_id):
			return str(category.get("id", ""))
	return ""

func _enzyme_tools_for_category(category_id: String) -> Array[Dictionary]:
	var allowed: Array = []
	for category in _enzyme_categories():
		if str(category.get("id", "")) == category_id:
			allowed = category.get("tools", [])
			break
	var output: Array[Dictionary] = []
	for tool_id in allowed:
		for tool in sim.enzyme_tools():
			if str(tool.get("id", "")) == str(tool_id):
				var enriched := tool.duplicate(true)
				enriched["card"] = _enzyme_tool_card_number(str(tool.get("id", "")))
				output.append(enriched)
				break
	return output

func _enzyme_tool_card_number(tool_id: String) -> int:
	var cards := {
		"lyase": 6,
		"reductase": 7,
		"dehydrogenase": 8,
		"oxygenase": 9,
		"decarboxylase": 10,
		"aminase": 11,
		"desaturase": 12,
		"nitrate_reductase": 13
	}
	return int(cards.get(tool_id, 0))

func _enzyme_category_button(category: Dictionary) -> Control:
	var tool_count: int = category.get("tools", []).size()
	var category_id := str(category.get("id", ""))
	var is_active_category := _enzyme_category_for_tool(designer_tool) == category_id
	var starter_count := 0
	for tool_id in category.get("tools", []):
		if sim.enzyme_tool_unlocked(str(tool_id)):
			starter_count += 1
	var status := "%d starter / %d locked" % [starter_count, maxi(0, tool_count - starter_count)] if tool_count > 0 else "Locked"
	if is_active_category:
		status = "Selected: %s" % designer_tool.capitalize()
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 4)
	var accent: Color = category.get("color", Color("73dfff"))
	var button := EnzymeSelectorCardButton.new()
	button.card_kind = "category"
	button.enzyme_id = category_id
	button.accent = accent
	button.locked = tool_count <= 0
	button.tooltip_text = "%s: %s (%s)" % [str(category.get("label", "")), str(category.get("summary", "")), status]
	button.custom_minimum_size = Vector2(0, 86)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _category_style(Color("263f50") if is_active_category else Color("243747"), accent, is_active_category))
	button.add_theme_stylebox_override("hover", _category_style(Color("263f50"), accent, true))
	button.add_theme_stylebox_override("pressed", _category_style(Color("263f50"), accent, true))
	button.add_theme_stylebox_override("disabled", _category_style(Color("172430"), Color(accent.r, accent.g, accent.b, 0.34), false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func():
		designer_category = category_id
		if not is_active_category:
			var tools: Array = category.get("tools", [])
			for tool_id in tools:
				if sim.enzyme_tool_unlocked(str(tool_id)):
					designer_tool = str(tool_id)
					designer_target = -1
					break
		_open_enzyme_designer(sim.selected_molecule)
	)
	wrapper.add_child(button)
	wrapper.add_child(_selector_caption(str(category.get("label", "")), status, accent))
	return wrapper

func _category_style(fill: Color, border: Color, active: bool) -> StyleBoxFlat:
	var style := _glow_panel_style(fill, Color(border.r, border.g, border.b, 0.55 if active else 0.25), 0.8 if active else 0.0, 8)
	style.shadow_color = Color(border.r, border.g, border.b, 0.18 if active else 0.06)
	style.shadow_size = 7 if active else 2
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	return style

func _tool_button(id: String, card_number: int, label_text: String, summary: String = "") -> Control:
	var unlocked := sim.enzyme_tool_unlocked(id)
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 4)
	var button := EnzymeSelectorCardButton.new()
	button.card_kind = "tool"
	button.enzyme_id = id
	button.locked = not unlocked
	button.accent = Color("73dfff") if unlocked else Color("405865")
	button.tooltip_text = "%s: %s" % [label_text, summary] if unlocked else "%s locked: unlock this reaction class later." % label_text
	button.custom_minimum_size = Vector2(0, 86)
	button.toggle_mode = true
	button.button_pressed = designer_tool == id and unlocked
	button.disabled = not unlocked
	button.add_theme_font_size_override("font_size", 16)
	button.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.48, 0.55, 0.58, 0.72)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	button.add_theme_stylebox_override("normal", _tool_style(false) if unlocked else _category_style(Color("172430"), Color("405865"), false))
	button.add_theme_stylebox_override("hover", _tool_style(true) if unlocked else _category_style(Color("172430"), Color("405865"), false))
	button.add_theme_stylebox_override("pressed", _tool_style(true) if unlocked else _category_style(Color("172430"), Color("405865"), false))
	button.add_theme_stylebox_override("disabled", _category_style(Color("172430"), Color("405865"), false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func():
		if not unlocked:
			return
		designer_tool = id
		designer_target = -1
		_refresh_designer()
	)
	wrapper.add_child(button)
	var caption_summary := summary if unlocked else "Locked"
	wrapper.add_child(_selector_caption(label_text, caption_summary, Color("73dfff") if designer_tool == id and unlocked else (Color("76888c") if not unlocked else Color("dbeff2"))))
	return wrapper

func _selector_caption(title_text: String, subtitle: String, accent: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = accent
	box.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.modulate = Color(0.76, 0.84, 0.84)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	return box

func _empty_enzyme_category_card(category_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _glow_panel_style(Color("172430"), Color("355b66"), 1.0, 8))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "NO REACTIONS YET"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color("76f4ff")
	box.add_child(title)
	var copy := Label.new()
	copy.text = "%s chemistry will unlock in a later prototype." % _enzyme_category_label(category_id).capitalize()
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.modulate = Color(0.72, 0.84, 0.82)
	box.add_child(copy)
	return panel

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
	var equilibrium_label := Label.new()
	equilibrium_label.text = "Equilibrium: slows as products approach %.0f molecules" % float(summary.get("equilibrium", 0.0))
	equilibrium_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equilibrium_label.modulate = Color("9fd8df")
	summary_panel.add_child(equilibrium_label)
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
		"cell": "CELL STATUS",
		"exploration": "EXPLORATION",
		"metabolism": "THE METABOLISM",
		"membrane": "MEMBRANE TRANSPORT",
		"proteins": "PROTEIN BUILDER",
		"dna": "DNA TECH TREE",
		"art_lab": "ART LAB",
		"map_designer": "MAP DESIGNER",
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

func _side_nav_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.080, 0.095, 0.92)
	style.border_color = Color(0.30, 0.78, 0.86, 0.72)
	style.set_border_width(SIDE_RIGHT, 2)
	style.shadow_color = Color(0.2, 0.95, 1.0, 0.10)
	style.shadow_size = 7
	style.content_margin_left = 8
	style.content_margin_top = 12
	style.content_margin_right = 8
	style.content_margin_bottom = 12
	return style

func _transparent_nav_style(fill: Color = Color.TRANSPARENT, active := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.64, 1.0, 0.92, 0.72) if active else Color(0.42, 0.95, 1.0, 0.20 if fill.a > 0.0 else 0.08)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.35, 1.0, 0.85, 0.18 if active else 0.0)
	style.shadow_size = 6 if active else 0
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
	var border := Color("73dfff")
	border.a = 0.58 if active else 0.20
	var style := _glow_panel_style(Color("243b4b") if active else Color("253747"), border, 0.8 if active else 0.0, 8)
	style.shadow_size = 7 if active else 2
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
		if name.contains("formic"):
			return Color("a5f3d0")
		if name.contains("ethanol"):
			return Color("8bd7ff")
		if name.contains("pyruvate"):
			return Color("ff8a7a")
		if name.contains("hydrogen"):
			return Color("d7f6ff")
		if name.contains("nitrate"):
			return Color("6fa8ff")
		if name.contains("sulfate"):
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

func _molecule_color_symbol(_id: String) -> String:
	return "●"

func _membrane_list_row_style(active: bool, id: String, hover: bool) -> StyleBoxFlat:
	var color := _molecule_color(id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.18) if active else Color(0.02, 0.10, 0.13, 0.20 if hover else 0.04)
	style.border_color = Color(color.r, color.g, color.b, 0.88 if active else 0.34 if hover else 0.0)
	style.set_border_width_all(1 if active or hover else 0)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(color.r, color.g, color.b, 0.18 if active else 0.0)
	style.shadow_size = 5 if active else 0
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _metabolism_molecule_row_style(id: String, active: bool, hover: bool) -> StyleBoxFlat:
	var color := _molecule_color(id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.18) if active else Color(0.03, 0.12, 0.14, 0.72 if hover else 0.52)
	style.border_color = Color(color.r, color.g, color.b, 0.88 if active else 0.45 if hover else 0.22)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(color.r, color.g, color.b, 0.22 if active else 0.10 if hover else 0.0)
	style.shadow_size = 7 if active else 4 if hover else 0
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _metabolism_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.095, 0.105, 0.94)
	style.border_color = Color("6df3ff")
	style.set_border_width_all(2)
	style.shadow_color = Color(0.25, 0.95, 1.0, 0.18)
	style.shadow_size = 9
	style.content_margin_left = 18
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 14
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

func _membrane_side_panel(title_text: String) -> VBoxContainer:
	var panel := GlowVBox.new()
	panel.fill = Color(0.025, 0.105, 0.135, 0.90)
	panel.border = Color("6df3ff")
	panel.border_width = 1.4
	panel.add_theme_constant_override("separation", 10)
	panel.add_theme_constant_override("margin_left", 10)
	panel.add_theme_constant_override("margin_right", 10)
	panel.add_theme_constant_override("margin_top", 8)
	panel.add_theme_constant_override("margin_bottom", 8)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color("adfaff")
	var title_inset := MarginContainer.new()
	title_inset.add_theme_constant_override("margin_left", 12)
	title_inset.add_theme_constant_override("margin_right", 12)
	title_inset.add_theme_constant_override("margin_top", 8)
	title_inset.add_theme_constant_override("margin_bottom", 0)
	title_inset.add_child(title)
	panel.add_child(title_inset)
	return panel

func _metabolism_side_panel(title_text: String) -> VBoxContainer:
	var panel := GlowVBox.new()
	panel.fill = Color(0.030, 0.095, 0.105, 0.92)
	panel.border = Color("6df3ff")
	panel.border_width = 1.4
	panel.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color("adfaff")
	panel.add_child(title)
	return panel

func _build_importer_button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("153d36") if active else Color("0e2c2f")
	style.border_color = Color("8cff6a") if active else Color("5de5c7")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.35, 1.0, 0.70, 0.30 if active else 0.16)
	style.shadow_size = 10 if active else 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

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

class EnzymeHoverCardMockup:
	extends Control

	var data := {}

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size).grow(-4.0)
		var accent: Color = data.get("accent", Color("76f4ff"))
		var mode := int(data.get("mode", 0))
		_draw_frame(rect, accent, mode)
		_draw_number(rect, accent)
		_draw_title(rect, accent)
		_draw_function(rect.position + Vector2(18.0, 78.0), rect.size.x - 36.0)
		match mode:
			0:
				_draw_bar_stack(rect, accent)
				_draw_tags(rect, accent)
			1:
				_draw_glyph(rect.position + Vector2(68.0, 170.0), 44.0, accent)
				_draw_metric_tiles(rect, accent)
				_draw_cost_strip(rect, accent)
			2:
				_draw_dials(rect, accent)
				_draw_heat_tag(rect.position + Vector2(rect.size.x - 112.0, rect.end.y - 36.0), 92.0)
			3:
				_draw_resource_boxes(rect)
				_draw_bar(rect.position + Vector2(20.0, rect.end.y - 36.0), rect.size.x - 40.0, "Catalytic value", "%.2f/s   %.0fs" % [float(data.get("kcat", 0.0)), float(data.get("stability", 0.0))], (_norm_kcat() + _norm_stability()) * 0.5, Color("8cff6a"))
			4:
				_draw_science_table(rect, accent)
			_:
				_draw_glyph(rect.position + Vector2(66.0, 180.0), 48.0, accent)
				_draw_game_rows(rect, accent)
				_draw_tags(rect, accent)

	func _draw_frame(rect: Rect2, accent: Color, mode: int) -> void:
		var fills := [
			Color(0.035, 0.10, 0.12, 0.96),
			Color(0.02, 0.07, 0.11, 0.96),
			Color(0.04, 0.09, 0.10, 0.98),
			Color(0.09, 0.065, 0.045, 0.97),
			Color(0.025, 0.095, 0.115, 0.96),
			Color(0.045, 0.10, 0.145, 0.97)
		]
		draw_rect(rect, fills[mode % fills.size()], true)
		draw_rect(rect.grow(2.0), Color(accent.r, accent.g, accent.b, 0.14), false, 8.0)
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.82), false, 1.5)
		draw_line(rect.position + Vector2(16.0, 50.0), rect.position + Vector2(rect.size.x - 16.0, 50.0), Color(accent.r, accent.g, accent.b, 0.22), 1.0)
		if mode == 1:
			for i in 7:
				var x := rect.position.x + 18.0 + float(i) * 58.0
				draw_line(Vector2(x, rect.position.y + 8.0), Vector2(x + 42.0, rect.end.y - 8.0), Color(accent.r, accent.g, accent.b, 0.035), 1.0)

	func _draw_number(rect: Rect2, accent: Color) -> void:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(rect.size.x - 38.0, 33.0), "%d" % int(data.get("n", 0)), HORIZONTAL_ALIGNMENT_CENTER, 24.0, 26, Color(accent.r, accent.g, accent.b, 0.92))

	func _draw_title(rect: Rect2, accent: Color) -> void:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(18.0, 28.0), str(data.get("name", "Enzyme Card")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 66.0, 18, Color("f4fbff"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(18.0, 49.0), str(data.get("subtitle", "ENZYME")), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 66.0, 11, accent)

	func _draw_function(pos: Vector2, width: float) -> void:
		var words := str(data.get("function", "")).split(" ")
		var line := ""
		var y := pos.y
		for word in words:
			var test := str(word) if line.is_empty() else "%s %s" % [line, str(word)]
			if test.length() > 60:
				draw_string(ThemeDB.fallback_font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, width, 12, Color(0.80, 0.92, 0.92, 0.90))
				line = str(word)
				y += 17.0
			else:
				line = test
		if not line.is_empty():
			draw_string(ThemeDB.fallback_font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, width, 12, Color(0.80, 0.92, 0.92, 0.90))

	func _draw_bar_stack(rect: Rect2, accent: Color) -> void:
		var y := rect.position.y + 134.0
		_draw_bar(Vector2(rect.position.x + 20.0, y), rect.size.x - 40.0, "Kcat", "%.2f/s" % float(data.get("kcat", 0.0)), _norm_kcat(), accent)
		_draw_bar(Vector2(rect.position.x + 20.0, y + 32.0), rect.size.x - 40.0, "Affinity", "Km %.1f" % float(data.get("km", 0.0)), _norm_inverse_km(), Color("76f4ff"))
		_draw_bar(Vector2(rect.position.x + 20.0, y + 64.0), rect.size.x - 40.0, "Stability", "%.0fs" % float(data.get("stability", 0.0)), _norm_stability(), Color("8cff6a"))

	func _draw_bar(pos: Vector2, width: float, label: String, value: String, progress: float, color: Color) -> void:
		draw_string(ThemeDB.fallback_font, pos + Vector2(0.0, 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, 76.0, 12, Color(0.72, 0.86, 0.86, 0.78))
		var bar := Rect2(pos + Vector2(86.0, 2.0), Vector2(width - 166.0, 12.0))
		draw_rect(bar, Color(0.0, 0.0, 0.0, 0.24), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0.0, 1.0), bar.size.y)), Color(color.r, color.g, color.b, 0.84), true)
		draw_rect(bar, Color(color.r, color.g, color.b, 0.42), false, 1.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(width - 70.0, 13.0), value, HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 12, Color("f4fbff"))

	func _draw_tags(rect: Rect2, accent: Color) -> void:
		var y := rect.end.y - 34.0
		_draw_tag(Rect2(Vector2(rect.position.x + 20.0, y), Vector2(114.0, 22.0)), "Cost %.0f aa" % float(data.get("price", 0.0)), Color("ffe064"))
		_draw_tag(Rect2(Vector2(rect.position.x + 144.0, y), Vector2(102.0, 22.0)), "Heat +%.1f" % float(data.get("heat", 0.0)), _heat_color())
		_draw_tag(Rect2(Vector2(rect.position.x + 256.0, y), Vector2(124.0, 22.0)), "Unique trait", accent)

	func _draw_tag(rect: Rect2, text: String, color: Color) -> void:
		draw_rect(rect, Color(color.r, color.g, color.b, 0.13), true)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.58), false, 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, 11, color.lightened(0.20))

	func _draw_metric_tiles(rect: Rect2, accent: Color) -> void:
		var top := rect.position + Vector2(120.0, 140.0)
		_draw_tile(Rect2(top, Vector2(74.0, 58.0)), "Kcat", "%.2f" % float(data.get("kcat", 0.0)), accent)
		_draw_tile(Rect2(top + Vector2(84.0, 0.0), Vector2(74.0, 58.0)), "Km", "%.1f" % float(data.get("km", 0.0)), Color("dbeff2"))
		_draw_tile(Rect2(top + Vector2(168.0, 0.0), Vector2(82.0, 58.0)), "Stable", "%.0fs" % float(data.get("stability", 0.0)), Color("8cff6a"))
		_draw_tile(Rect2(top + Vector2(260.0, 0.0), Vector2(74.0, 58.0)), "Heat", "+%.1f" % float(data.get("heat", 0.0)), _heat_color())

	func _draw_tile(rect: Rect2, label: String, value: String, color: Color) -> void:
		draw_rect(rect, Color(color.r, color.g, color.b, 0.10), true)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.44), false, 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16.0, 11, Color(0.72, 0.88, 0.88, 0.78))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 44.0), value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16.0, 16, color.lightened(0.16))

	func _draw_cost_strip(rect: Rect2, accent: Color) -> void:
		var strip := Rect2(rect.position + Vector2(20.0, rect.end.y - 34.0), Vector2(rect.size.x - 40.0, 18.0))
		draw_rect(strip, Color(0.0, 0.0, 0.0, 0.22), true)
		draw_rect(Rect2(strip.position, Vector2(strip.size.x * _norm_price(), strip.size.y)), Color("ffe064"), true)
		draw_rect(strip, Color(accent.r, accent.g, accent.b, 0.34), false, 1.0)
		draw_string(ThemeDB.fallback_font, strip.position + Vector2(8.0, 14.0), "Protein synthesis price: %.0f amino acids" % float(data.get("price", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, strip.size.x - 16.0, 10, Color("07181c"))

	func _draw_dials(rect: Rect2, accent: Color) -> void:
		var y := rect.position.y + 176.0
		_draw_dial(Vector2(rect.position.x + 86.0, y), 42.0, _norm_kcat(), "Kcat", accent)
		_draw_dial(Vector2(rect.position.x + 196.0, y), 42.0, _norm_inverse_km(), "Affinity", Color("76f4ff"))
		_draw_dial(Vector2(rect.position.x + 306.0, y), 42.0, _norm_stability(), "Stable", Color("8cff6a"))

	func _draw_dial(center: Vector2, radius: float, progress: float, label: String, color: Color) -> void:
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.20))
		draw_arc(center, radius - 5.0, -PI * 0.70, PI * 1.30, 44, Color(color.r, color.g, color.b, 0.20), 6.0, true)
		draw_arc(center, radius - 5.0, -PI * 0.70, -PI * 0.70 + PI * 2.0 * clampf(progress, 0.0, 1.0), 44, color, 6.0, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(-radius, 4.0), "%d%%" % int(progress * 100.0), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 14, Color("f4fbff"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-radius, radius + 18.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 11, Color(0.78, 0.90, 0.90, 0.82))

	func _draw_resource_boxes(rect: Rect2) -> void:
		_draw_resource_box(Rect2(rect.position + Vector2(22.0, 138.0), Vector2(184.0, 92.0)), "Build Price", "%.0f amino acids" % float(data.get("price", 0.0)), Color("ffe064"), _norm_price())
		_draw_resource_box(Rect2(rect.position + Vector2(218.0, 138.0), Vector2(190.0, 92.0)), "Heat Effect", "+%.1f heat / reaction" % float(data.get("heat", 0.0)), _heat_color(), _norm_heat())

	func _draw_resource_box(rect: Rect2, title: String, value: String, color: Color, progress: float) -> void:
		draw_rect(rect, Color(color.r, color.g, color.b, 0.10), true)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.48), false, 1.2)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12.0, 23.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 13, Color("f4fbff"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12.0, 48.0), value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 13, color.lightened(0.18))
		var bar := Rect2(rect.position + Vector2(12.0, 66.0), Vector2(rect.size.x - 24.0, 9.0))
		draw_rect(bar, Color(0.0, 0.0, 0.0, 0.24), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), color, true)

	func _draw_science_table(rect: Rect2, accent: Color) -> void:
		var table := Rect2(rect.position + Vector2(20.0, 135.0), Vector2(rect.size.x - 40.0, 96.0))
		draw_rect(table, Color(0.0, 0.0, 0.0, 0.18), true)
		draw_rect(table, Color(accent.r, accent.g, accent.b, 0.28), false, 1.0)
		var rows := [
			["Turnover", "Kcat", "%.2f reactions/s" % float(data.get("kcat", 0.0)), accent],
			["Affinity", "Km", "%.1f substrate units" % float(data.get("km", 0.0)), Color("dbeff2")],
			["Lifetime", "Stability", "%.0f seconds" % float(data.get("stability", 0.0)), Color("8cff6a")],
			["Burden", "Cost / Heat", "%.0f aa  |  +%.1f" % [float(data.get("price", 0.0)), float(data.get("heat", 0.0))], _heat_color()]
		]
		for i in rows.size():
			var row_y := table.position.y + 22.0 + float(i) * 20.0
			draw_string(ThemeDB.fallback_font, Vector2(table.position.x + 10.0, row_y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, 82.0, 12, Color(0.72, 0.88, 0.88, 0.82))
			draw_string(ThemeDB.fallback_font, Vector2(table.position.x + 94.0, row_y), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, 76.0, 12, rows[i][3])
			draw_string(ThemeDB.fallback_font, Vector2(table.position.x + 178.0, row_y), rows[i][2], HORIZONTAL_ALIGNMENT_LEFT, table.size.x - 188.0, 12, Color("f4fbff"))
		_draw_heat_tag(rect.position + Vector2(22.0, rect.end.y - 36.0), 110.0)

	func _draw_game_rows(rect: Rect2, accent: Color) -> void:
		var start := rect.position + Vector2(130.0, 137.0)
		_draw_bar(start, 270.0, "Speed", "%.2f/s" % float(data.get("kcat", 0.0)), _norm_kcat(), accent)
		_draw_bar(start + Vector2(0.0, 32.0), 270.0, "Affinity", "Km %.1f" % float(data.get("km", 0.0)), _norm_inverse_km(), Color("76f4ff"))
		_draw_bar(start + Vector2(0.0, 64.0), 270.0, "Lifetime", "%.0fs" % float(data.get("stability", 0.0)), _norm_stability(), Color("8cff6a"))

	func _draw_heat_tag(pos: Vector2, width: float) -> void:
		_draw_tag(Rect2(pos, Vector2(width, 22.0)), "heat +%.1f" % float(data.get("heat", 0.0)), _heat_color())

	func _draw_glyph(center: Vector2, radius: float, accent: Color) -> void:
		for i in 7:
			var angle := float(i) / 7.0 * TAU + float(data.get("n", 0)) * 0.31
			var p := center + Vector2(cos(angle), sin(angle)) * radius * (0.54 + float(i % 3) * 0.13)
			draw_line(center, p, Color(accent.r, accent.g, accent.b, 0.18), 3.0, true)
			draw_circle(p, radius * 0.18, Color(accent.r, accent.g, accent.b, 0.28))
		draw_circle(center, radius * 0.54, Color("02070b"))
		draw_circle(center, radius * 0.46, Color(accent.r, accent.g, accent.b, 0.20))
		draw_arc(center, radius * 0.32, 0.0, TAU * 0.78, 32, accent, 3.0, true)
		draw_circle(center + Vector2(radius * 0.14, -radius * 0.18), radius * 0.08, Color(1.0, 1.0, 1.0, 0.55))

	func _norm_kcat() -> float:
		return clampf(float(data.get("kcat", 0.0)) / 2.0, 0.0, 1.0)

	func _norm_inverse_km() -> float:
		return clampf(1.0 - float(data.get("km", 0.0)) / 30.0, 0.0, 1.0)

	func _norm_stability() -> float:
		return clampf(float(data.get("stability", 0.0)) / 100.0, 0.0, 1.0)

	func _norm_price() -> float:
		return clampf(float(data.get("price", 0.0)) / 90.0, 0.0, 1.0)

	func _norm_heat() -> float:
		return clampf(float(data.get("heat", 0.0)) / 2.2, 0.0, 1.0)

	func _heat_color() -> Color:
		var heat := float(data.get("heat", 0.0))
		if heat >= 1.5:
			return Color("ff7a5c")
		if heat >= 0.9:
			return Color("ffb35f")
		return Color("8cff6a")

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

	signal scroll_changed(next_scroll: float)

	var environment_texture: Texture2D
	var membrane_texture: Texture2D
	var transporter_texture: Texture2D
	var simulation
	var highlight_molecule := ""
	var transporter_slots := {}
	var _particles := {}
	var _signature := ""
	var _elapsed := 0.0
	var _membrane_scroll := 0.5
	var _dragging := false
	var _last_drag_position := Vector2.ZERO
	const VISIBLE_MEMBRANE_ARC := 0.42

	func set_scroll_position(next_scroll: float) -> void:
		_membrane_scroll = fposmod(next_scroll, 1.0)

	func _ready() -> void:
		environment_texture = _load_texture_from_file("res://assets/membrane/membrane-environment-clouds.png")
		membrane_texture = _load_texture_from_file("res://assets/membrane/flat-layered-membrane-reference-style.png")
		transporter_texture = _load_texture_from_file("res://assets/membrane/transporter-sheet-opaque.png")
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
				scroll_changed.emit(_membrane_scroll)
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
		_draw_membrane_body()
		_draw_membrane_front_heads()
		if simulation != null:
			_draw_transporter_proteins()
		draw_string(ThemeDB.fallback_font, Vector2(18, 32), "EXTRACELLULAR SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.82, 0.94, 0.96, 0.66))
		draw_string(ThemeDB.fallback_font, Vector2(18, size.y - 24), "CYTOPLASM", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.88, 0.78, 0.62))

	func _draw_scene_background(rect: Rect2) -> void:
		if environment_texture != null:
			draw_texture_rect(environment_texture, rect, false)
		else:
			draw_rect(rect, Color("102b34"), true)
		var split_y := _membrane_center_y()
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, split_y)), Color(0.02, 0.18, 0.22, 0.34), true)
		draw_rect(Rect2(Vector2(0.0, split_y), Vector2(size.x, size.y - split_y)), Color(0.42, 0.30, 0.22, 0.22), true)
		for i in 12:
			var t := float(i) / 11.0
			draw_rect(Rect2(Vector2(0.0, split_y * t), Vector2(size.x, split_y / 12.0 + 1.0)), Color(0.56, 0.95, 1.0, 0.025 * (1.0 - t)), true)
		for i in 10:
			var t := float(i) / 9.0
			draw_rect(Rect2(Vector2(0.0, split_y + (size.y - split_y) * t), Vector2(size.x, (size.y - split_y) / 10.0 + 1.0)), Color(1.0, 0.78, 0.55, 0.035 * (1.0 - t)), true)
		draw_rect(Rect2(Vector2(0.0, split_y - 2.0), Vector2(size.x, 4.0)), Color(0.0, 0.04, 0.05, 0.32), true)
		for i in 18:
			var t := float(i) / 17.0
			draw_rect(Rect2(Vector2(0, size.y * t), Vector2(size.x, size.y / 18.0 + 1.0)), Color(0.58, 0.95, 1.0, 0.014 * (1.0 - t)), true)
		for i in 22:
			var y := lerpf(22.0, split_y - 20.0, float(i) / 21.0)
			var wave := sin(_elapsed * 0.16 + float(i) * 0.62) * 18.0
			draw_line(Vector2(-40.0, y + wave), Vector2(size.x + 40.0, y - 28.0 + wave), Color(0.72, 0.96, 1.0, 0.035), 2.0, true)
		for i in 36:
			var seed := float(abs(("water-speck:%d" % i).hash() % 10000)) / 10000.0
			var p := Vector2(lerpf(20.0, size.x - 20.0, fmod(seed * 7.31, 1.0)), lerpf(22.0, size.y - 22.0, fmod(seed * 11.17, 1.0)))
			var drift := Vector2(sin(_elapsed * 0.08 + seed * 17.0), cos(_elapsed * 0.07 + seed * 13.0)) * 5.0
			draw_circle(p + drift, 1.2 + fmod(seed * 5.0, 2.2), Color(0.82, 1.0, 0.94, 0.08 + seed * 0.06))

	func _draw_membrane_body() -> void:
		if membrane_texture != null:
			_draw_scrolling_membrane_texture()
			return
		var rect := _fallback_membrane_rect()
		draw_rect(rect, Color("1d4248"), true)
		draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y * 0.36), Vector2(rect.size.x, rect.size.y * 0.28)), Color("607f7f"), true)

	func _draw_membrane_front_heads() -> void:
		if membrane_texture == null:
			_draw_lipid_head_row(-44.0, 48, 1.0, 1.0)
			_draw_lipid_head_row(44.0, 48, 0.94, 1.0)

	func _membrane_texture_rect() -> Rect2:
		if membrane_texture == null:
			return _fallback_membrane_rect()
		var aspect := membrane_texture.get_size().x / membrane_texture.get_size().y
		var width := size.x * 1.04
		var height := minf(width / aspect, size.y * 0.44)
		width = height * aspect
		var x := (size.x - width) * 0.5
		var y := size.y * 0.50 - height * 0.52
		return Rect2(Vector2(x, y), Vector2(width, height))

	func _draw_scrolling_membrane_texture() -> void:
		var rect := _membrane_texture_rect()
		var tile_width := rect.size.x
		var visible_width := rect.size.x * 0.92
		var offset := -fposmod((_membrane_scroll / VISIBLE_MEMBRANE_ARC) * visible_width, tile_width)
		var x := rect.position.x + offset
		while x > rect.position.x - tile_width:
			x -= tile_width
		while x < rect.position.x + rect.size.x + tile_width:
			draw_texture_rect(membrane_texture, Rect2(Vector2(x, rect.position.y), rect.size), false)
			x += tile_width

	func _fallback_membrane_rect() -> Rect2:
		var height := size.y * 0.28
		return Rect2(Vector2(-size.x * 0.02, size.y * 0.50 - height * 0.50), Vector2(size.x * 1.04, height))

	func _membrane_center_y() -> float:
		var rect := _membrane_texture_rect()
		return rect.position.y + rect.size.y * 0.56

	func _draw_membrane_depth_rows() -> void:
		_draw_lipid_head_row(-57.0, 52, 0.52, 0.45, -15.0)
		_draw_lipid_head_row(57.0, 52, 0.44, 0.38, -15.0)
		_draw_lipid_head_row(-51.0, 50, 0.68, 0.58, -7.0)
		_draw_lipid_head_row(51.0, 50, 0.60, 0.52, -7.0)

	func _membrane_edge_points(offset: float, steps: int) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in steps + 1:
			var sample := _anchor_sample(float(i) / float(steps), false)
			points.append(sample["point"] + sample["inside_normal"] * offset)
		return points

	func _membrane_inner_band(top_offset: float, bottom_offset: float, steps: int) -> PackedVector2Array:
		var top := _membrane_edge_points(top_offset, steps)
		var bottom := _membrane_edge_points(bottom_offset, steps)
		var band := PackedVector2Array()
		for point in top:
			band.append(point)
		for i in range(bottom.size() - 1, -1, -1):
			band.append(bottom[i])
		return band

	func _draw_tail_lattice() -> void:
		var visible_tail_count := 60
		var total_world_count := int(ceil(float(visible_tail_count) / VISIBLE_MEMBRANE_ARC))
		for i in total_world_count:
			var world_t := (float(i) + 0.5) / float(total_world_count)
			var screen_t := _world_to_visible_t(world_t)
			if screen_t < 0.0:
				continue
			var sample := _anchor_sample(screen_t, false)
			var anchor: Vector2 = sample["point"]
			var normal: Vector2 = sample["inside_normal"]
			var tangent: Vector2 = sample["tangent"]
			var phase := sin(world_t * TAU * 14.0) * 2.8
			var top := anchor + normal * -31.0 + tangent * phase
			var bottom := anchor + normal * 31.0 - tangent * phase
			draw_line(top, bottom, Color(0.11, 0.045, 0.018, 0.56), 5.0, true)
			draw_line(top, bottom, Color(0.86, 0.43, 0.14, 0.86), 3.2, true)
			draw_line(top + tangent * 1.5, bottom + tangent * 1.5, Color(1.0, 0.70, 0.32, 0.42), 1.15, true)

	func _draw_lipid_head_row(edge_offset: float, visible_count: int, brightness: float, alpha: float, depth_shift: float = 0.0) -> void:
		var total_world_count := int(ceil(float(visible_count) / VISIBLE_MEMBRANE_ARC))
		for i in total_world_count:
			var world_t := (float(i) + 0.5) / float(total_world_count)
			var screen_t := _world_to_visible_t(world_t)
			if screen_t < 0.0:
				continue
			var sample := _anchor_sample(screen_t, false)
			var normal: Vector2 = sample["inside_normal"]
			var tangent: Vector2 = sample["tangent"]
			var point: Vector2 = sample["point"] + normal * edge_offset - normal * depth_shift
			var radius := 7.3 + brightness * 1.2
			var fill := Color(0.22, 0.62, 0.88, alpha).lightened(0.16 * brightness)
			var rim := Color(0.005, 0.025, 0.035, alpha)
			draw_circle(point, radius + 2.2, rim)
			draw_circle(point, radius, fill)
			draw_circle(point + tangent * -1.4 + normal * -2.5, radius * 0.46, Color(0.75, 0.96, 1.0, alpha * 0.30))
			draw_circle(point + tangent * -2.2 + normal * -3.0, radius * 0.20, Color(1.0, 1.0, 1.0, alpha * 0.36))

	func _anchor_points(steps: int, layer_offset: float = 0.0, animated: bool = true) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in steps + 1:
			var t := float(i) / float(steps)
			points.append(_anchor_sample(t, animated)["point"] + Vector2(0, layer_offset))
		return points

	func _anchor_sample(t: float, animated: bool = true) -> Dictionary:
		var point := _anchor_point_static(t, false)
		var tangent := Vector2.RIGHT
		var inside_normal := Vector2.DOWN
		return {"point": point, "tangent": tangent, "inside_normal": inside_normal}

	func _anchor_point_static(t: float, animated: bool) -> Vector2:
		var rect := _membrane_texture_rect()
		var x := lerpf(rect.position.x + rect.size.x * 0.04, rect.position.x + rect.size.x * 0.96, t)
		return Vector2(x, _membrane_center_y())

	func _draw_transporter_proteins() -> void:
		var arrows: Array = simulation.membrane_transport_arrows()
		var total := arrows.size()
		if total <= 0:
			return
		for i in total:
			var arrow: Dictionary = arrows[i]
			var world_t := _transporter_world_t(arrow)
			var screen_t := _world_to_visible_t_with_margin(world_t, 0.16)
			if screen_t < 0.0:
				continue
			var t := screen_t
			var placement := _membrane_placement(t)
			var top: Vector2 = placement["top"]
			var bottom: Vector2 = placement["bottom"]
			var normal: Vector2 = placement["normal"]
			var tangent: Vector2 = placement["tangent"]
			var molecule_id := str(arrow.get("molecule", ""))
			var visual_variant := int(arrow.get("visual_variant", 0))
			var protein_color: Color = _source_color(molecule_id).lightened(0.12)
			var copies := clampi(int(arrow.get("count", 0)) + int(arrow.get("queued_count", 0)), 1, 9)
			for copy_index in range(copies - 1, -1, -1):
				var depth := float(copy_index) / float(maxi(1, copies - 1))
				var offset := tangent * (-depth * 18.0) - normal * (depth * 18.0)
				var scale := 1.0 - depth * 0.10
				var alpha := 1.0
				_draw_single_transporter(top + offset, bottom + offset, tangent, normal, protein_color, scale, alpha, copy_index == 0, visual_variant)

	func _transporter_world_t(arrow: Dictionary) -> float:
		var direction := str(arrow.get("direction", ""))
		var molecule_id := str(arrow.get("molecule", ""))
		var key := "%s:%s" % [direction, molecule_id]
		if transporter_slots.has(key):
			return fposmod(0.5 + float(transporter_slots[key]) * 0.055, 1.0)
		var seed := float(abs(key.hash() % 10000)) / 10000.0
		return fposmod(0.15 + seed * 0.70, 1.0)

	func _world_to_visible_t(world_t: float) -> float:
		return _world_to_visible_t_with_margin(world_t, 0.0)

	func _world_to_visible_t_with_margin(world_t: float, margin: float) -> float:
		var rel := fposmod(world_t - _membrane_scroll + 0.5, 1.0) - 0.5
		var half_visible := VISIBLE_MEMBRANE_ARC * 0.5
		if absf(rel) > half_visible + margin * VISIBLE_MEMBRANE_ARC:
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

	func _draw_single_transporter(top: Vector2, bottom: Vector2, tangent: Vector2, normal: Vector2, base_color: Color, scale: float, alpha: float, front: bool, visual_variant: int = 0) -> void:
		if transporter_texture != null:
			_draw_transporter_sprite(top, bottom, tangent, normal, base_color, scale, alpha, front, visual_variant)
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

	func _draw_transporter_sprite(top: Vector2, bottom: Vector2, tangent: Vector2, normal: Vector2, base_color: Color, scale: float, alpha: float, front: bool, visual_variant: int) -> void:
		var source := _transporter_source_rect(base_color, visual_variant)
		var membrane_height := top.distance_to(bottom)
		var target_height := membrane_height * (2.18 if front else 1.90) * scale
		var target_width := target_height * (source.size.x / source.size.y)
		var center := top.lerp(bottom, 0.52) - normal * (target_height * 0.02)
		var rect := Rect2(Vector2(-target_width * 0.5, -target_height * 0.5), Vector2(target_width, target_height))
		var rotation := normal.angle() - PI * 0.5
		draw_set_transform(center, rotation, Vector2.ONE)
		draw_texture_rect_region(transporter_texture, rect, source, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _transporter_source_rect(base_color: Color, visual_variant: int = -1) -> Rect2:
		var sheet_size := transporter_texture.get_size()
		var slot_width := sheet_size.x / 4.0
		var index := wrapi(visual_variant, 0, 4) if visual_variant >= 0 else 1
		if visual_variant < 0:
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

	func _update_particle_transforms() -> void:
		for key in _particles.keys():
			var item: Dictionary = _particles[key]
			var node: Control = item.get("node", null)
			if node == null:
				continue
			var node_size := Vector2(8.5, 8.5) * (0.86 + float(item.get("depth", 0.7)) * 0.44)
			node.custom_minimum_size = node_size
			node.size = node_size
			var molecule_id := str(item.get("id", ""))
			var focus_alpha := 1.0
			if not highlight_molecule.is_empty() and molecule_id != highlight_molecule:
				focus_alpha = 0.18
			node.modulate = Color(1.0, 1.0, 1.0, focus_alpha)
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
			var screen_x_seed := _world_to_visible_t(x_seed)
			if screen_x_seed < 0.0:
				node.visible = false
				continue
			node.visible = true
			var sample := _anchor_sample(screen_x_seed, false)
			var anchor: Vector2 = sample["point"]
			var normal: Vector2 = sample["inside_normal"]
			var tangent: Vector2 = sample["tangent"]
			var distance_from_membrane := lerpf(66.0, 260.0, y_seed)
			var side_sign := -1.0 if side == "outside" else 1.0
			var lane_spread := (x_jitter * 0.55 + sin(seed * TAU) * 0.18) * 54.0
			var drift := Vector2(
				sin(_elapsed * (0.12 + motion_seed * 0.06) + seed * 19.0),
				cos(_elapsed * (0.10 + motion_seed * 0.05) + seed * 13.0)
			) * (12.0 + 12.0 * depth)
			var perspective: float = 0.72 + depth * 0.28 + sin(_elapsed * 0.35 + seed * 23.0) * 0.018
			node.position = anchor + normal * side_sign * distance_from_membrane + tangent * lane_spread + drift - node_size * 0.5
			node.rotation = tangent.angle() + sin(_elapsed * (0.16 + motion_seed * 0.08) + seed * TAU) * 0.18
			node.scale = Vector2(perspective, perspective)

	func _source_color(id: String) -> Color:
		if simulation != null and simulation.molecule_types.has(id):
			var molecule: Dictionary = simulation.molecule_types[id]
			var name := str(molecule.get("name", "")).to_lower()
			if name == "glucose" or str(molecule.get("formula", "")) == "C₆O₂":
				return Color("58d874")
			if name.contains("formic"):
				return Color("a5f3d0")
			if name.contains("ethanol"):
				return Color("8bd7ff")
			if name.contains("pyruvate"):
				return Color("ff8a7a")
			if name.contains("hydrogen"):
				return Color("d7f6ff")
			if name.contains("nitrate"):
				return Color("6fa8ff")
			if name.contains("sulfate"):
				return Color("ffe069")
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
			if name.contains("hydrogen"):
				return "circle"
			if name.contains("pyruvate"):
				return "triangle"
			if formula.contains("P"):
				return "diamond"
			if formula.contains("N"):
				return "triangle"
			if formula.contains("S"):
				return "diamond"
		return "circle"

class CellSpriteCyclePreview:
	extends Control

	var sheet_path := ""
	var frame_count := 1
	var frame_rate := 6.0
	var _elapsed := 0.0
	var _texture: Texture2D

	func _ready() -> void:
		_texture = _load_texture(sheet_path)
		set_process(true)

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b242b"), true)
		for i in 18:
			var t := float(i) / 17.0
			draw_line(Vector2(0, size.y * t), Vector2(size.x, size.y * t), Color(0.45, 0.95, 1.0, 0.018), 1.0)
		if _texture == null or frame_count <= 0:
			draw_string(ThemeDB.fallback_font, size * 0.5, "Missing sprite sheet", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("dbeff2"))
			return
		var frame := int(floor(_elapsed * frame_rate)) % frame_count
		var frame_width := float(_texture.get_width()) / float(frame_count)
		var source := Rect2(Vector2(frame_width * frame, 0), Vector2(frame_width, _texture.get_height()))
		var target := _fit_rect(Vector2(frame_width, _texture.get_height()), Rect2(Vector2(14, 16), size - Vector2(28, 48)))
		draw_texture_rect_region(_texture, target, source)
		draw_rect(target, Color(0.46, 0.96, 1.0, 0.28), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(18, size.y - 16), "Cycling frame %d/%d at %.1f fps" % [frame + 1, frame_count, frame_rate], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dbeff2"))

	func _fit_rect(source_size: Vector2, bounds: Rect2) -> Rect2:
		var scale_value := minf(bounds.size.x / source_size.x, bounds.size.y / source_size.y)
		var fitted := source_size * scale_value
		return Rect2(bounds.position + (bounds.size - fitted) * 0.5, fitted)

	func _load_texture(path: String) -> Texture2D:
		var actual_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		var image := Image.load_from_file(actual_path)
		if image == null:
			return null
		return ImageTexture.create_from_image(image)

class MembraneStripScrollPreview:
	extends Control

	var strip_path := ""
	var _texture: Texture2D
	var _elapsed := 0.0

	func _ready() -> void:
		_texture = _load_texture(strip_path)
		set_process(true)

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b242b"), true)
		_draw_split_background()
		if _texture == null:
			draw_string(ThemeDB.fallback_font, Vector2(18, 34), "Missing membrane strip", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dbeff2"))
			return
		var segment_width := 78.0
		var target_height := 188.0
		var scroll_px := fmod(_elapsed * 56.0, float(_texture.get_width()))
		var segments := int(ceil(size.x / segment_width)) + 4
		for i in range(-2, segments):
			var x := float(i) * segment_width
			var t := clampf((x + segment_width * 0.5) / maxf(1.0, size.x), 0.0, 1.0)
			var y := _curve_y(t)
			var y_next := _curve_y(clampf(t + segment_width / maxf(1.0, size.x), 0.0, 1.0))
			var angle := atan2(y_next - y, segment_width)
			var source_x := fmod(scroll_px + float(i + 2) * segment_width, float(_texture.get_width()))
			var source := Rect2(Vector2(source_x, 0.0), Vector2(minf(segment_width, float(_texture.get_width()) - source_x), float(_texture.get_height())))
			_draw_curved_segment(source, Vector2(x, y), segment_width, target_height, angle)
			if source.size.x < segment_width:
				var wrap_source := Rect2(Vector2.ZERO, Vector2(segment_width - source.size.x, float(_texture.get_height())))
				_draw_curved_segment(wrap_source, Vector2(x + source.size.x, y), segment_width - source.size.x, target_height, angle)
		_draw_seam_markers()
		draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 14), "animated seamless scroll test along curved membrane path", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dbeff2"))

	func _draw_split_background() -> void:
		var curve := PackedVector2Array()
		for i in 72:
			var t := float(i) / 71.0
			curve.append(Vector2(t * size.x, _curve_y(t)))
		var outside := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0)])
		for i in range(curve.size() - 1, -1, -1):
			outside.append(curve[i] + Vector2(0, -24))
		var inside := PackedVector2Array()
		for point in curve:
			inside.append(point + Vector2(0, 42))
		inside.append(Vector2(size.x, size.y))
		inside.append(Vector2(0, size.y))
		draw_colored_polygon(outside, Color("123d49"))
		draw_colored_polygon(inside, Color("f2b58c", 0.82))
		for i in 16:
			var y := size.y * float(i) / 15.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.72, 0.96, 1.0, 0.025), 1.0)

	func _curve_y(t: float) -> float:
		return size.y * 0.54 - sin(t * PI) * size.y * 0.16

	func _draw_curved_segment(source: Rect2, center_left: Vector2, width: float, height: float, angle: float) -> void:
		var center := center_left + Vector2(width * 0.5, 0.0)
		var target := Rect2(Vector2(-width * 0.5, -height * 0.50), Vector2(width + 1.0, height))
		draw_set_transform(center, angle, Vector2.ONE)
		draw_texture_rect_region(_texture, target, source)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_seam_markers() -> void:
		for x in [size.x * 0.25, size.x * 0.5, size.x * 0.75]:
			draw_line(Vector2(x, 20), Vector2(x, size.y - 20), Color(1.0, 1.0, 1.0, 0.035), 1.0)

	func _load_texture(path: String) -> Texture2D:
		var actual_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		var image := Image.load_from_file(actual_path)
		if image == null:
			return null
		return ImageTexture.create_from_image(image)

class FlagellumSpritePreview:
	extends Control

	var sheet_path := ""
	var row_index := 0
	var frame_count := 8
	var row_count := 3
	var _texture: Texture2D
	var _elapsed := 0.0

	func _ready() -> void:
		set_process(true)
		_texture = _load_texture(sheet_path)

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b242b"), true)
		for i in 8:
			var x := size.x * float(i) / 7.0
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.45, 0.95, 1.0, 0.025), 1.0)
		if _texture == null:
			draw_string(ThemeDB.fallback_font, Vector2(18, 36), "Missing flagellum sheet", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dbeff2"))
			return
		var frame := int(floor(_elapsed * 8.0)) % frame_count
		var frame_w := float(_texture.get_width()) / float(frame_count)
		var frame_h := float(_texture.get_height()) / float(row_count)
		var source := Rect2(Vector2(frame_w * float(frame), frame_h * float(row_index)), Vector2(frame_w, frame_h))
		var target := _fit_rect(source.size, Rect2(Vector2(14, 18), size - Vector2(28, 40)))
		draw_texture_rect_region(_texture, target, source)
		var anchor := Vector2(target.position.x + target.size.x * 0.16, target.position.y + target.size.y * 0.5)
		draw_circle(anchor, 9.0, Color(1.0, 0.2, 0.9, 0.18))
		draw_circle(anchor, 4.5, Color("ff76f4"))
		draw_rect(target, Color(0.46, 0.96, 1.0, 0.26), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 15), "frame %d/%d" % [frame + 1, frame_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dbeff2"))

	func _fit_rect(source_size: Vector2, bounds: Rect2) -> Rect2:
		var scale_value := minf(bounds.size.x / source_size.x, bounds.size.y / source_size.y)
		var fitted := source_size * scale_value
		return Rect2(bounds.position + (bounds.size - fitted) * 0.5, fitted)

	func _load_texture(path: String) -> Texture2D:
		var actual_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		var image := Image.load_from_file(actual_path)
		if image == null:
			return null
		return ImageTexture.create_from_image(image)

class AttachedFlagellumPreview:
	extends Control

	var cell_sheet_path := ""
	var flagellum_sheet_path := ""
	var cell_frame_count := 6
	var flagellum_frame_count := 8
	var flagellum_row_count := 3
	var flagellum_row_index := 2
	var _cell_texture: Texture2D
	var _flagellum_texture: Texture2D
	var _elapsed := 0.0

	func _ready() -> void:
		_cell_texture = _load_texture(cell_sheet_path)
		_flagellum_texture = _load_texture(flagellum_sheet_path)
		set_process(true)

	func _process(delta: float) -> void:
		_elapsed += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b242b"), true)
		for i in 10:
			var y := size.y * float(i) / 9.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.45, 0.95, 1.0, 0.025), 1.0)
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.38, Color(0.30, 0.95, 1.0, 0.035))
		if _cell_texture == null or _flagellum_texture == null:
			draw_string(ThemeDB.fallback_font, Vector2(18, 34), "Missing cell or flagellum sheet", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dbeff2"))
			return
		var angle := _elapsed * 0.55
		var cell_frame := int(floor(_elapsed * 4.0)) % cell_frame_count
		var flagellum_frame := int(floor(_elapsed * 8.0)) % flagellum_frame_count
		var cell_frame_w := float(_cell_texture.get_width()) / float(cell_frame_count)
		var cell_source := Rect2(Vector2(cell_frame_w * float(cell_frame), 0.0), Vector2(cell_frame_w, _cell_texture.get_height()))
		var flag_frame_w := float(_flagellum_texture.get_width()) / float(flagellum_frame_count)
		var flag_frame_h := float(_flagellum_texture.get_height()) / float(flagellum_row_count)
		var flag_source := Rect2(Vector2(flag_frame_w * float(flagellum_frame), flag_frame_h * float(flagellum_row_index)), Vector2(flag_frame_w, flag_frame_h))
		var center := size * 0.5 + Vector2(22.0, 4.0)
		var forward := Vector2.RIGHT.rotated(angle)
		var back := -forward
		var cell_draw_size := minf(size.x, size.y) * 0.42
		var cell_rect := Rect2(Vector2(-cell_draw_size * 0.5, -cell_draw_size * 0.5), Vector2(cell_draw_size, cell_draw_size))
		var flag_height := cell_draw_size * 0.42
		var flag_width := flag_height * (flag_source.size.x / flag_source.size.y)
		var flag_anchor_u := 0.16
		var flag_anchor := center + back * cell_draw_size * 0.34
		draw_set_transform(flag_anchor, back.angle(), Vector2.ONE)
		var flag_rect := Rect2(Vector2(-flag_width * flag_anchor_u, -flag_height * 0.5), Vector2(flag_width, flag_height))
		draw_texture_rect_region(_flagellum_texture, flag_rect, flag_source)
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.2, 0.9, 0.22))
		draw_set_transform(center, angle + PI * 0.5, Vector2.ONE)
		draw_texture_rect_region(_cell_texture, cell_rect, cell_source)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(flag_anchor, 4.0, Color("ff76f4"))
		draw_line(center, center + forward * cell_draw_size * 0.58, Color("76f4ff", 0.38), 2.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(14, size.y - 15), "rotating attachment test", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dbeff2"))

	func _load_texture(path: String) -> Texture2D:
		var actual_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
		var image := Image.load_from_file(actual_path)
		if image == null:
			return null
		return ImageTexture.create_from_image(image)

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
		elif shape == "triangle":
			_draw_regular_polygon(center, radius + 3.0, 3, Color("02070b"), PI * 0.5)
			_draw_regular_polygon(center, radius + 0.5, 3, color.lightened(0.18), PI * 0.5)
			_draw_regular_polygon(center, radius - 2.0, 3, color.darkened(0.06), PI * 0.5)
			draw_circle(center + Vector2(radius * 0.10, -radius * 0.26), radius * 0.15, Color(1, 1, 1, 0.34))
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

class EnzymeSelectorCardButton:
	extends Button

	var card_kind := "tool"
	var enzyme_id := ""
	var accent := Color("73dfff")
	var locked := false

	func _ready() -> void:
		text = ""
		clip_contents = true

	func _draw() -> void:
		var rect := Rect2(Vector2(16.0, 10.0), size - Vector2(32.0, 20.0))
		var bg := Color("0e2932") if not locked else Color("17232a")
		var edge := accent if not locked else Color("425661")
		draw_rect(rect.grow(4.0), Color(edge.r, edge.g, edge.b, 0.05), true)
		draw_rect(rect, bg, true)
		draw_line(rect.position + Vector2(8.0, 0), rect.position + Vector2(rect.size.x - 8.0, 0), Color(edge.r, edge.g, edge.b, 0.24 if not locked else 0.10), 2.0, true)
		var content := rect.grow(-8.0)
		if locked:
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.28), true)
		if card_kind == "category":
			_draw_category_icon(content)
		else:
			_draw_tool_icon(content)

	func _draw_category_icon(rect: Rect2) -> void:
		var center := rect.get_center()
		match enzyme_id:
			"carbon":
				_draw_atom(center, 20.0, Color("78878a"))
			"oxygen":
				_draw_atom(center + Vector2(-34, 0), 16.0, Color("78878a"))
				_draw_bond(center + Vector2(-18, 0), center + Vector2(18, 0), 2)
				_draw_atom(center + Vector2(34, 0), 16.0, Color("e95058"))
			"nitrogen":
				_draw_atom(center + Vector2(-28, 12), 16.0, Color("4a90df"))
				_draw_bond(center + Vector2(-10, 4), center + Vector2(20, -10), 1)
				_draw_atom(center + Vector2(34, -16), 14.0, Color("78878a"))
			"sulfur":
				_draw_atom(center, 20.0, Color("ffe064"))
			"phosphate":
				_draw_atom(center, 20.0, Color("a34ed0"))
			_:
				_draw_atom(center, 18.0, Color("78878a"))

	func _draw_tool_icon(rect: Rect2) -> void:
		var y := rect.get_center().y
		var left := rect.position.x + rect.size.x * 0.28
		var right := rect.position.x + rect.size.x * 0.72
		var mid := rect.get_center().x
		_draw_arrow(Vector2(mid - 18.0, y), Vector2(mid + 18.0, y))
		match enzyme_id:
			"decarboxylase":
				_draw_carboxyl(Vector2(left, y), 0.78)
				_draw_atom(Vector2(right - 10.0, y), 15.0, Color("78878a"))
				_draw_text_small("CO2", Vector2(right + 22.0, y + 5.0), Color("dbeff2"))
			"lyase":
				_draw_chain(Vector2(left, y), false)
				_draw_scissors(Vector2(left + 34.0, y - 4.0))
				_draw_chain(Vector2(right - 16.0, y), true)
			"desaturase":
				_draw_two_atom(Vector2(left, y), 1, Color("78878a"), Color("78878a"))
				_draw_two_atom(Vector2(right, y), 2, Color("78878a"), Color("78878a"))
			"dehydrogenase":
				_draw_two_atom(Vector2(left, y), 1, Color("78878a"), Color("e95058"))
				_draw_two_atom(Vector2(right, y), 2, Color("78878a"), Color("e95058"))
			"reductase":
				_draw_two_atom(Vector2(left, y), 2, Color("78878a"), Color("e95058"))
				_draw_two_atom(Vector2(right, y), 1, Color("78878a"), Color("e95058"))
			"oxygenase":
				_draw_two_atom(Vector2(left, y), 2, Color("78878a"), Color("e95058"))
				_draw_carboxyl(Vector2(right, y), 0.62)
			"aminase":
				_draw_alpha_keto(Vector2(left, y), 0.58, false)
				_draw_alpha_keto(Vector2(right, y), 0.58, true)
			"nitrate_reductase":
				_draw_atom(Vector2(left - 16.0, y), 15.0, Color("4a90df"))
				_draw_atom(Vector2(left + 10.0, y - 18.0), 10.0, Color("e95058"))
				_draw_atom(Vector2(left + 12.0, y + 17.0), 10.0, Color("e95058"))
				_draw_atom(Vector2(left + 32.0, y), 10.0, Color("e95058"))
				_draw_text_small("N pool", Vector2(right - 6.0, y + 5.0), Color("7ca7ff"))
			_:
				_draw_chain(Vector2(left, y), false)
				_draw_chain(Vector2(right, y), false)

	func _draw_atom(pos: Vector2, radius: float, color: Color) -> void:
		var alpha := 0.48 if locked else 1.0
		draw_circle(pos + Vector2(0, radius * 0.18), radius + 4.0, Color(0, 0, 0, 0.28 * alpha))
		draw_circle(pos, radius + 4.0, Color(0.01, 0.03, 0.05, alpha))
		draw_circle(pos, radius + 1.0, color.lightened(0.18) * Color(1, 1, 1, alpha))
		draw_circle(pos, radius - 2.0, color.darkened(0.12) * Color(1, 1, 1, alpha))
		draw_circle(pos + Vector2(radius * 0.30, -radius * 0.38), radius * 0.20, Color(1, 1, 1, 0.46 * alpha))

	func _draw_bond(a: Vector2, b: Vector2, order: int) -> void:
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var offsets := [0.0] if order == 1 else [-4.0, 4.0]
		for offset in offsets:
			var p0 := a + normal * float(offset)
			var p1 := b + normal * float(offset)
			draw_line(p0, p1, Color("02070b"), 8.0, true)
			draw_line(p0, p1, Color("dbeff2", 0.72 if not locked else 0.30), 4.0, true)
			draw_line(p0 + normal * 0.5, p1 + normal * 0.5, Color(1, 1, 1, 0.36 if not locked else 0.12), 1.2, true)

	func _draw_two_atom(center: Vector2, order: int, color_a: Color, color_b: Color) -> void:
		var a := center + Vector2(-22.0, 0)
		var b := center + Vector2(22.0, 0)
		_draw_bond(a + Vector2(14, 0), b - Vector2(14, 0), order)
		_draw_atom(a, 14.0, color_a)
		_draw_atom(b, 14.0, color_b)

	func _draw_chain(center: Vector2, split: bool) -> void:
		var points := [center + Vector2(-38, 8), center + Vector2(-12, -8), center + Vector2(14, 8), center + Vector2(40, -8)]
		for i in points.size() - 1:
			if split and i == 1:
				continue
			_draw_bond(points[i], points[i + 1], 1)
		for point in points:
			_draw_atom(point, 10.5, Color("78878a"))

	func _draw_carboxyl(center: Vector2, scale: float) -> void:
		var c := center
		var o1 := center + Vector2(34, -18) * scale
		var o2 := center + Vector2(36, 20) * scale
		_draw_bond(c + Vector2(12, -6) * scale, o1 - Vector2(10, -5) * scale, 2)
		_draw_bond(c + Vector2(12, 7) * scale, o2 - Vector2(10, 5) * scale, 1)
		_draw_atom(c, 15.0 * scale, Color("78878a"))
		_draw_atom(o1, 13.0 * scale, Color("e95058"))
		_draw_atom(o2, 13.0 * scale, Color("e95058"))

	func _draw_alpha_keto(center: Vector2, scale: float, with_n: bool) -> void:
		var c1 := center + Vector2(-36, 12) * scale
		var c2 := center
		var c3 := center + Vector2(42, 10) * scale
		_draw_bond(c1, c2, 1)
		_draw_bond(c2, c3, 1)
		_draw_bond(c2, c2 + Vector2(0, -44) * scale, 2)
		_draw_atom(c1, 13.0 * scale, Color("78878a"))
		_draw_atom(c2, 13.0 * scale, Color("78878a"))
		_draw_carboxyl(c3, scale * 0.72)
		_draw_atom(c2 + Vector2(0, -44) * scale, 11.5 * scale, Color("e95058"))
		if with_n:
			_draw_bond(c2, c2 + Vector2(-8, 44) * scale, 1)
			_draw_atom(c2 + Vector2(-8, 44) * scale, 11.5 * scale, Color("4a90df"))

	func _draw_arrow(a: Vector2, b: Vector2) -> void:
		var color := Color("9df7ff", 0.78 if not locked else 0.28)
		draw_line(a, b, Color(0, 0, 0, 0.5), 7.0, true)
		draw_line(a, b, color, 4.0, true)
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var tip := b
		var wing := 9.0
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 15.0 + normal * wing, tip - dir * 15.0 - normal * wing]), color)

	func _draw_scissors(center: Vector2) -> void:
		var color := Color("f4fbff", 0.82 if not locked else 0.30)
		draw_line(center + Vector2(-18, 18), center + Vector2(18, -20), color, 2.5, true)
		draw_line(center + Vector2(-12, -18), center + Vector2(20, 18), color, 2.5, true)
		draw_arc(center + Vector2(20, -22), 5.0, 0.0, TAU, 16, color, 2.0)
		draw_arc(center + Vector2(24, 18), 5.0, 0.0, TAU, 16, color, 2.0)

	func _draw_text_small(text_value: String, pos: Vector2, color: Color) -> void:
		draw_string(ThemeDB.fallback_font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

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
