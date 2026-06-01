extends Control

const CellViewScript := preload("res://scripts/ui/cell_view.gd")
const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")
const Catalog := preload("res://scripts/core/data_catalog.gd")
const Save := preload("res://scripts/core/save_game.gd")

var sim = SimulationStateScript.new()
var resource_box: VBoxContainer
var outside_box: VBoxContainer
var action_panel: VBoxContainer
var queue_box: VBoxContainer
var event_log: RichTextLabel
var status_label: Label
var cell_view: Control
var active_view := "metabolism"
var selected_reaction := ""
var view_buttons: Dictionary = {}
var _last_action_signature := ""

func _ready() -> void:
	sim.changed.connect(_refresh)
	sim.event_logged.connect(_log_event)
	_build_ui()
	_refresh()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause_toggle"):
		sim.toggle_pause()
	if Input.is_action_just_pressed("speed_up"):
		sim.set_speed(sim.speed + 0.25)
	if Input.is_action_just_pressed("speed_down"):
		sim.set_speed(sim.speed - 0.25)
	sim.tick(delta)

func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var left := _panel(300)
	root.add_child(left)
	left.add_child(_title("Sim Cell", "Pauseable biochemical design"))
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(status_label)
	left.add_child(_button_row([
		["Pause", func(): sim.toggle_pause()],
		["- Speed", func(): sim.set_speed(sim.speed - 0.25)],
		["+ Speed", func(): sim.set_speed(sim.speed + 0.25)]
	]))
	left.add_child(_button_row([
		["Save", func(): _save()],
		["Load", func(): _load()],
		["Reset", func(): sim.reset()]
	]))
	left.add_child(_section_label("Internal Resources"))
	resource_box = VBoxContainer.new()
	left.add_child(resource_box)
	left.add_child(_section_label("Outside Pools"))
	outside_box = VBoxContainer.new()
	left.add_child(outside_box)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	cell_view = CellViewScript.new()
	cell_view.simulation = sim
	cell_view.custom_minimum_size = Vector2(760, 620)
	cell_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(cell_view)
	event_log = RichTextLabel.new()
	event_log.custom_minimum_size = Vector2(0, 120)
	event_log.scroll_following = true
	event_log.bbcode_enabled = false
	center.add_child(event_log)

	var right := _panel(420)
	root.add_child(right)
	right.add_child(_section_label("View"))
	right.add_child(_button_row([
		["Metabolism", func(): _set_view("metabolism")],
		["Membrane", func(): _set_view("membrane")],
		["Proteins", func(): _set_view("proteins")],
		["DNA", func(): _set_view("dna")]
	]))
	action_panel = VBoxContainer.new()
	action_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(action_panel)
	right.add_child(_section_label("Active Queues"))
	queue_box = VBoxContainer.new()
	right.add_child(queue_box)

func _panel(width: float) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 10)
	return panel

func _title(title: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 28)
	box.add_child(h)
	var s := Label.new()
	s.text = subtitle
	s.modulate = Color(0.62, 0.78, 0.75)
	box.add_child(s)
	return box

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.modulate = Color("54d7c3")
	return label

func _button_row(defs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for def in defs:
		var button := Button.new()
		button.text = def[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(def[1])
		row.add_child(button)
	return row

func _set_view(id: String) -> void:
	active_view = id
	_last_action_signature = ""
	_refresh()

func _select_molecule(id: String) -> void:
	sim.select_molecule(id)
	var options: Array[String] = sim.reaction_options_for(id)
	selected_reaction = options[0] if not options.is_empty() else ""
	_last_action_signature = ""
	_refresh()

func _select_reaction(id: String) -> void:
	selected_reaction = id
	_last_action_signature = ""
	_refresh()

func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = "State: %s | Time: %.0fs | Speed: %.2fx | Research: %.0f" % [
		"Paused" if sim.paused else sim.pressure_label(),
		sim.time_seconds,
		sim.speed,
		sim.research_points
	]
	_fill_resource_box()
	_fill_outside_box()
	_refresh_action_panel_if_needed()
	_fill_queue_box()

func _refresh_action_panel_if_needed() -> void:
	var signature := _action_signature()
	if signature == _last_action_signature:
		return
	_last_action_signature = signature
	_fill_action_panel()

func _action_signature() -> String:
	var parts: Array[String] = [active_view, sim.selected_molecule, selected_reaction, str(sim.research_points)]
	for id in sim.enzymes_owned.keys():
		parts.append("enzyme:%s:%s" % [id, str(sim.enzymes_owned[id])])
	for id in sim.transporters_owned.keys():
		parts.append("transporter:%s:%s" % [id, str(sim.transporters_owned[id])])
	for id in sim.proteins_owned.keys():
		parts.append("protein:%s:%s" % [id, str(sim.proteins_owned[id])])
	for id in sim.tech_unlocked.keys():
		parts.append("tech:%s:%s" % [id, str(sim.tech_unlocked[id])])
	for id in Catalog.molecules().keys():
		parts.append("resource:%s:%.1f" % [id, float(sim.resources.get(id, 0.0))])
	return "|".join(parts)

func _fill_resource_box() -> void:
	_clear(resource_box)
	for id in Catalog.molecules().keys():
		var data: Dictionary = Catalog.molecules()[id]
		resource_box.add_child(_metric_row(data.get("name", id), sim.resources.get(id, 0.0), data.get("color", Color.WHITE)))

func _fill_outside_box() -> void:
	_clear(outside_box)
	for id in sim.outside.keys():
		var data: Dictionary = Catalog.molecules().get(id, {"name": id, "color": Color.WHITE})
		outside_box.add_child(_metric_row(data.get("name", id), sim.outside.get(id, 0.0), data.get("color", Color.WHITE)))

func _metric_row(label_text: String, value: float, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(118, 0)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.max_value = 40.0
	bar.value = min(value, 40.0)
	bar.modulate = color
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var amount := Label.new()
	amount.text = "%.1f" % value
	amount.custom_minimum_size = Vector2(52, 0)
	row.add_child(amount)
	return row

func _fill_action_panel() -> void:
	_clear(action_panel)
	if active_view == "metabolism":
		_fill_metabolism_panel()
	elif active_view == "membrane":
		action_panel.add_child(_title("Membrane Overview", "Build transporters for outside molecules."))
		for id in Catalog.transporters().keys():
			action_panel.add_child(_transporter_card(id))
	elif active_view == "proteins":
		action_panel.add_child(_title("Protein Synthesis", "Queue buildable machines using amino acids and ATP."))
		for id in Catalog.proteins().keys():
			action_panel.add_child(_protein_card(id))
	elif active_view == "dna":
		action_panel.add_child(_title("DNA Research", "DNA parts automatically convert into research points."))
		for id in Catalog.techs().keys():
			action_panel.add_child(_tech_card(id))

func _fill_metabolism_panel() -> void:
	action_panel.add_child(_title("Enzyme Designer", "Select a substrate, inspect possible enzyme transformations, then design or run."))
	action_panel.add_child(_selected_molecule_summary())
	action_panel.add_child(_section_label("Molecule"))
	var molecule_grid := GridContainer.new()
	molecule_grid.columns = 2
	molecule_grid.add_theme_constant_override("h_separation", 6)
	molecule_grid.add_theme_constant_override("v_separation", 6)
	action_panel.add_child(molecule_grid)
	for id in _metabolism_molecule_ids():
		molecule_grid.add_child(_molecule_button(id))
	var options: Array[String] = sim.reaction_options_for(sim.selected_molecule)
	if selected_reaction == "" or not options.has(selected_reaction):
		selected_reaction = options[0] if not options.is_empty() else ""
	action_panel.add_child(_section_label("Compatible Transformations"))
	if options.is_empty():
		var empty := Label.new()
		empty.text = "No enzyme transformations currently use this molecule."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_panel.add_child(empty)
	for id in options:
		action_panel.add_child(_reaction_option_button(id))
	if selected_reaction != "":
		action_panel.add_child(_section_label("Reaction Preview"))
		action_panel.add_child(_enzyme_card(selected_reaction))

func _selected_molecule_summary() -> VBoxContainer:
	var data: Dictionary = Catalog.molecules().get(sim.selected_molecule, {"name": sim.selected_molecule, "formula": "?", "role": ""})
	var amount := float(sim.resources.get(sim.selected_molecule, 0.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var label := Label.new()
	label.text = "%s  %s  %.1f available" % [data.get("name", sim.selected_molecule), data.get("formula", ""), amount]
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	var role := Label.new()
	role.text = data.get("role", "")
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.modulate = Color(0.72, 0.84, 0.82)
	box.add_child(role)
	return box

func _metabolism_molecule_ids() -> Array[String]:
	return [
		"glucose",
		"oxygen_group",
		"nitrogen_group",
		"phosphate",
		"electrons",
		"atp",
		"amino_acids",
		"dna_parts",
		"rna_parts",
		"lipids"
	]

func _molecule_button(id: String) -> Button:
	var data: Dictionary = Catalog.molecules().get(id, {"name": id, "formula": "?"})
	var button := Button.new()
	button.text = "%s\n%s %.1f" % [data.get("name", id), data.get("formula", ""), float(sim.resources.get(id, 0.0))]
	button.toggle_mode = true
	button.button_pressed = sim.selected_molecule == id
	button.custom_minimum_size = Vector2(0, 54)
	button.pressed.connect(func(): _select_molecule(id))
	return button

func _reaction_option_button(id: String) -> Button:
	var preview: Dictionary = sim.reaction_preview(id)
	var button := Button.new()
	var status := "ready"
	if bool(preview.get("owned", false)):
		status = "built"
	elif not bool(preview.get("can_design", false)):
		status = "missing enzyme material"
	elif not bool(preview.get("can_design_and_run", false)):
		status = "missing substrate"
	button.text = "%s\n%s -> %s | %s" % [
		preview.get("name", id),
		_format_dict(preview.get("input", {})),
		_format_dict(preview.get("output", {})),
		status
	]
	button.toggle_mode = true
	button.button_pressed = selected_reaction == id
	button.custom_minimum_size = Vector2(0, 58)
	button.pressed.connect(func(): _select_reaction(id))
	return button

func _enzyme_card(id: String) -> VBoxContainer:
	var data: Dictionary = Catalog.enzyme_actions()[id]
	var preview: Dictionary = sim.reaction_preview(id)
	var owned := bool(preview.get("owned", false))
	var missing_design: Dictionary = preview.get("missing_design", {})
	var missing_input: Dictionary = preview.get("missing_input", {})
	var button_text := "Run Reaction" if owned else "Design Enzyme + Run"
	var disabled := not bool(preview.get("can_design_and_run", false))
	var meta := "Input %s\nOutput %s\nEnzyme cost %s\nDuration %.1fs" % [
		_format_dict(data.get("input", {})),
		_format_dict(data.get("output", {})),
		_format_dict(data.get("protein_cost", {})),
		float(data.get("duration", 0.0))
	]
	if not missing_design.is_empty():
		meta += "\nMissing design material: %s" % _format_dict(missing_design)
	if not missing_input.is_empty():
		meta += "\nMissing substrate: %s" % _format_dict(missing_input)
	return _card(
		data.get("name", id),
		data.get("description", ""),
		meta,
		button_text,
		func(): sim.design_enzyme(id),
		disabled
	)

func _transporter_card(id: String) -> VBoxContainer:
	var data: Dictionary = Catalog.transporters()[id]
	var cost: Dictionary = data.get("build_cost", {})
	var missing := sim.missing_resources(cost)
	var meta := "Owned %d | Cost %s" % [int(sim.transporters_owned.get(id, 0)), _format_dict(cost)]
	if not missing.is_empty():
		meta += "\nMissing: %s" % _format_dict(missing)
	return _card(
		data.get("name", id),
		data.get("description", ""),
		meta,
		"Build Transporter",
		func(): sim.build_transporter(id),
		not missing.is_empty()
	)

func _protein_card(id: String) -> VBoxContainer:
	var data: Dictionary = Catalog.proteins()[id]
	var cost: Dictionary = data.get("build_cost", {})
	var missing := sim.missing_resources(cost)
	var meta := "Owned %d | Cost %s" % [int(sim.proteins_owned.get(id, 0)), _format_dict(cost)]
	if not missing.is_empty():
		meta += "\nMissing: %s" % _format_dict(missing)
	return _card(
		data.get("name", id),
		data.get("description", ""),
		meta,
		"Queue Protein",
		func(): sim.queue_protein(id),
		not missing.is_empty()
	)

func _tech_card(id: String) -> VBoxContainer:
	var data: Dictionary = Catalog.techs()[id]
	var unlocked := bool(sim.tech_unlocked.get(id, false))
	var cost := float(data.get("cost", 0.0))
	var locked_by_points: bool = sim.research_points + 0.001 < cost
	var meta := "Tier %d | Cost %.0f DNA research | Available %.0f" % [int(data.get("tier", 1)), cost, sim.research_points]
	return _card(
		"%s%s" % [data.get("name", id), " unlocked" if unlocked else ""],
		data.get("description", ""),
		meta,
		"Unlock",
		func(): sim.research_tech(id),
		unlocked or locked_by_points
	)

func _card(title: String, body: String, meta: String, button_text: String, callback: Callable, disabled := false) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 17)
	box.add_child(title_label)
	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.modulate = Color(0.72, 0.84, 0.82)
	box.add_child(body_label)
	var meta_label := Label.new()
	meta_label.text = meta
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.modulate = Color(0.94, 0.78, 0.36)
	box.add_child(meta_label)
	var button := Button.new()
	button.text = button_text
	button.disabled = disabled
	button.pressed.connect(callback)
	box.add_child(button)
	return box

func _fill_queue_box() -> void:
	_clear(queue_box)
	if sim.reaction_queue.is_empty() and sim.protein_queue.is_empty():
		var empty := Label.new()
		empty.text = "No active synthesis."
		empty.modulate = Color(0.62, 0.78, 0.75)
		queue_box.add_child(empty)
	for item in sim.reaction_queue:
		queue_box.add_child(_queue_label("Reaction", item))
	for item in sim.protein_queue:
		queue_box.add_child(_queue_label("Protein", item))

func _queue_label(kind: String, item: Dictionary) -> Label:
	var label := Label.new()
	var remaining := float(item.get("remaining", 0.0))
	var duration: float = maxf(0.01, float(item.get("duration", 1.0)))
	label.text = "%s: %s %.0f%%" % [kind, item.get("name", "?"), (1.0 - remaining / duration) * 100.0]
	return label

func _format_dict(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key in values:
		var name: String = Catalog.molecules().get(key, {"name": key}).get("name", key)
		parts.append("%s %.1f" % [name, float(values[key])])
	return ", ".join(parts)

func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _log_event(message: String) -> void:
	if event_log == null:
		return
	event_log.append_text("[%05.1f] %s\n" % [sim.time_seconds, message])

func _save() -> void:
	if Save.save_state(sim):
		_log_event("Saved culture.")
	else:
		_log_event("Save failed.")

func _load() -> void:
	if not Save.load_state(sim):
		_log_event("No saved culture found.")
