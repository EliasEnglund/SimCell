extends SceneTree

const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")
const MetabolismWorkspaceScript := preload("res://scripts/ui/metabolism_workspace.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_window := get_root()
	root_window.size = Vector2i(1420, 760)
	var sim = SimulationStateScript.new()
	var glucose_id: String = sim.present_molecule_ids()[0]
	var tools := ["lyase", "reductase", "dehydrogenase", "oxygenase", "decarboxylase", "aminase", "desaturase"]
	for tool in tools:
		var targets := sim.valid_targets(tool, glucose_id)
		if targets.is_empty():
			continue
		sim.design_enzyme(tool, glucose_id, int(targets[0]))
		var blueprint_id: String = sim.pathway_list()[sim.pathway_list().size() - 1].get("id", "")
		sim.active_enzymes[blueprint_id] = 1

	var background := ColorRect.new()
	background.color = Color("07181c")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_window.add_child(background)
	var title := Label.new()
	title.text = "ENZYME STEP VISUAL CHECK"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("76f4ff")
	root_window.add_child(title)

	var arrows := sim.pathway_arrows()
	for i in arrows.size():
		var box := MetabolismWorkspaceScript.EnzymeStepBox.new()
		box.simulation = sim
		box.reaction = arrows[i]
		box.fixed_zoom = 0.42
		box.size = Vector2(310, 150)
		box.custom_minimum_size = box.size
		box.position = Vector2(36 + (i % 3) * 450, 82 + (i / 3) * 230)
		root_window.add_child(box)
		var label := Label.new()
		label.text = str(arrows[i].get("tool", "")).to_upper()
		label.position = box.position + Vector2(0, box.size.y + 8)
		label.add_theme_font_size_override("font_size", 18)
		label.modulate = Color("f4fbff")
		root_window.add_child(label)

	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	var image := root_window.get_texture().get_image()
	var output_dir := ProjectSettings.globalize_path("res://tmp")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := "res://tmp/enzyme_step_capture.png"
	var err := image.save_png(output_path)
	if err != OK:
		push_error("Failed to save enzyme step capture: %s" % err)
	else:
		print("Saved enzyme step capture to %s" % ProjectSettings.globalize_path(output_path))
	quit(0)
