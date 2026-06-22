extends SceneTree

const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

func _init() -> void:
	var sim = SimulationStateScript.new()
	assert(sim.present_molecule_ids().size() == 1)
	assert(sim.selected_molecule == "")
	var glucose_id: String = sim.present_molecule_ids()[0]
	assert(sim.molecule_types[glucose_id].get("formula", "") == "C₆O₆")
	assert(sim.outside_molecule_ids().has(glucose_id))
	assert(sim.transporter_count("import", glucose_id) == 4)
	assert(is_equal_approx(sim.transporter_rate("import", glucose_id), 8.0))
	var starting_glucose := float(sim.molecule_amounts[glucose_id])
	sim.tick(1.0)
	assert(absf(float(sim.molecule_amounts[glucose_id]) - starting_glucose - 8.0) < 0.01)
	assert(sim.build_transporter("import", glucose_id) == true)
	assert(sim.transporter_count("import", glucose_id) == 4)
	assert(sim.transporter_queued_count("import", glucose_id) == 1)
	for i in 30:
		sim.tick(0.1)
	assert(sim.transporter_count("import", glucose_id) == 5)
	assert(sim.transporter_queued_count("import", glucose_id) == 0)
	assert(sim.destroy_transporter("import", glucose_id) == true)
	assert(sim.transporter_count("import", glucose_id) == 4)
	sim.select_molecule(glucose_id)
	assert(sim.selected_molecule == glucose_id)
	sim.deselect_molecule()
	assert(sim.selected_molecule == "")
	assert(sim.enzyme_tool_unlocked("dehydrogenase") == true)
	assert(sim.enzyme_tool_unlocked("oxygenase") == true)
	assert(sim.enzyme_tool_unlocked("reductase") == true)
	assert(sim.enzyme_tool_unlocked("decarboxylase") == true)
	assert(sim.enzyme_tool_unlocked("aminase") == true)
	assert(sim.enzyme_tool_unlocked("lyase") == false)
	assert(sim.valid_targets("lyase", glucose_id).size() == 0)
	assert(sim.valid_targets("reductase", glucose_id).size() > 0)
	assert(sim.valid_targets("dehydrogenase", glucose_id).size() > 0)
	assert(sim.valid_targets("decarboxylase", glucose_id).size() == 0)
	assert(sim.valid_targets("oxygenase", glucose_id).size() > 0)
	var glucose_oxidation_target := int(sim.valid_targets("dehydrogenase", glucose_id)[0])
	assert(sim.preview_products("dehydrogenase", glucose_id, glucose_oxidation_target).size() > 0)
	assert(sim.valid_targets("desaturase", glucose_id).size() == 0)
	assert(float(sim.resources.get("NADH", 0.0)) > 0.0)
	assert(float(sim.resources.get("N", 0.0)) > 0.0)
	assert(float(sim.resources.get("ATP", 0.0)) > 0.0)
	assert(float(sim.resources.get("Amino Acids", 0.0)) > 0.0)
	assert(float(sim.resources.get("DNA Points", 0.0)) > 0.0)
	assert(sim.dna_tech_available("transporters") == true)
	var starting_dna_points := float(sim.resources.get("DNA Points", 0.0))
	assert(sim.invest_dna_research("transporters", 50.0) == true)
	assert(float(sim.resources.get("DNA Points", 0.0)) < starting_dna_points)
	assert(float(sim.dna_tech_state("transporters").get("progress", 0.0)) > 0.0)
	assert(sim.is_target_molecule(sim.target_molecule()) == true)
	var target_graph: Dictionary = sim.target_molecule()
	var target_id: String = target_graph["signature"]
	sim.molecule_types[target_id] = target_graph
	sim.molecule_amounts[target_id] = 3.0
	sim.molecule_rates[target_id] = {"production": 0.0, "consumption": 0.0}
	var starting_amino_acids := float(sim.resources.get("Amino Acids", 0.0))
	sim.tick(0.3)
	assert(float(sim.molecule_amounts.get(target_id, 0.0)) <= 0.001)
	assert(float(sim.resources.get("Amino Acids", 0.0)) > starting_amino_acids)
	var pyruvate_id := ""
	for id in sim.molecule_types.keys():
		if sim.molecule_types[id].get("name", "") == "Pyruvate":
			pyruvate_id = id
			break
	assert(pyruvate_id != "")
	assert(sim.valid_targets("reductase", pyruvate_id).size() > 0)
	var reduced_pyruvate := sim.preview_products("reductase", pyruvate_id, int(sim.valid_targets("reductase", pyruvate_id)[0]))
	assert(reduced_pyruvate.size() == 1)
	var reduced_id: String = reduced_pyruvate[0]["signature"]
	sim.molecule_types[reduced_id] = reduced_pyruvate[0]
	assert(sim.valid_targets("dehydrogenase", reduced_id).size() > 0)
	assert(sim.valid_targets("aminase", glucose_id).size() == 0)
	var aminase_target := int(sim.valid_targets("aminase", pyruvate_id)[0])
	var aminase_preview := sim.preview_products("aminase", pyruvate_id, aminase_target)
	assert(str(aminase_preview[0].get("formula", "")).contains("N"))
	var resource_sim = SimulationStateScript.new()
	var starting_n := float(resource_sim.resources.get("N", 0.0))
	var resource_pyruvate_id := ""
	for id in resource_sim.molecule_types.keys():
		if resource_sim.molecule_types[id].get("name", "") == "Pyruvate":
			resource_pyruvate_id = id
			break
	assert(resource_pyruvate_id != "")
	resource_sim.molecule_amounts[resource_pyruvate_id] = 24.0
	resource_sim.molecule_rates[resource_pyruvate_id] = {"production": 0.0, "consumption": 0.0}
	var resource_target := int(resource_sim.valid_targets("aminase", resource_pyruvate_id)[0])
	assert(resource_sim.design_enzyme("aminase", resource_pyruvate_id, resource_target) == true)
	for i in 40:
		resource_sim.tick(0.1)
	for i in 10:
		resource_sim.tick(0.1)
	assert(float(resource_sim.resources.get("N", 0.0)) < starting_n)
	var target := int(sim.valid_targets("dehydrogenase", glucose_id)[0])
	var preview := sim.preview_products("dehydrogenase", glucose_id, target)
	assert(preview.size() == 1)
	var preview_info := sim.product_preview_info("dehydrogenase", glucose_id, target)
	assert(preview_info.size() == 1)
	assert(float(sim.enzyme_preview_summary("dehydrogenase", glucose_id, target).get("equilibrium", 0.0)) > 0.0)
	assert(sim.design_enzyme("dehydrogenase", glucose_id, target) == true)
	assert(sim.protein_queue.size() == 1)
	assert(sim.pathway_list().size() == 1)
	var blueprint_id: String = sim.pathway_list()[0].get("id", "")
	assert(sim.pathway_list()[0].get("status", "") == "Building")
	assert(sim.pathway_list()[0].get("products", []).size() == 1)
	assert(sim.queue_enzyme_build(blueprint_id, 2) == true)
	assert(sim.protein_queue.size() == 3)
	assert(sim.metabolism_molecule_ids().size() > sim.present_molecule_ids().size())
	for i in 40:
		sim.tick(0.1)
	assert(int(sim.active_enzymes.get(blueprint_id, 0)) == 3)
	assert(sim.destroy_active_enzyme(blueprint_id) == true)
	assert(int(sim.active_enzymes.get(blueprint_id, 0)) == 2)
	assert(sim.pathway_arrows()[0].get("status", "") == "Active")
	for i in 80:
		sim.tick(0.1)
	assert(sim.present_molecule_ids().size() > 1)
	print("Simulation smoke test passed.")
	quit(0)
