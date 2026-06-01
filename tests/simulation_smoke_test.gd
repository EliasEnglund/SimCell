extends SceneTree

const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

func _init() -> void:
	var sim = SimulationStateScript.new()
	var glucose_id: String = sim.selected_molecule
	assert(sim.present_molecule_ids().size() == 1)
	assert(sim.molecule_types[glucose_id].get("formula", "") == "C₆O₆")
	assert(sim.valid_targets("lyase", glucose_id).size() > 0)
	assert(sim.valid_targets("reductase", glucose_id).size() > 0)
	var target := int(sim.valid_targets("lyase", glucose_id)[0])
	var preview := sim.preview_products("lyase", glucose_id, target)
	assert(preview.size() == 2)
	assert(sim.design_enzyme("lyase", glucose_id, target) == true)
	assert(sim.protein_queue.size() == 1)
	assert(sim.pathway_list().size() == 1)
	assert(sim.pathway_list()[0].get("status", "") == "Building")
	assert(sim.metabolism_molecule_ids().size() > sim.present_molecule_ids().size())
	for i in 40:
		sim.tick(0.1)
	assert(sim.active_enzymes.size() == 1)
	assert(sim.pathway_arrows()[0].get("status", "") == "Active")
	for i in 80:
		sim.tick(0.1)
	assert(sim.present_molecule_ids().size() > 1)
	print("Simulation smoke test passed.")
	quit(0)
