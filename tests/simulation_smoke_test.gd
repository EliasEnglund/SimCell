extends SceneTree

const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

func _init() -> void:
	var sim := SimulationStateScript.new()
	assert(sim.resources.get("atp", 0.0) > 0.0)
	sim.select_molecule("glucose")
	assert(sim.selected_molecule == "glucose")
	assert(sim.reaction_options_for("glucose").has("glycolytic_split"))
	var preview: Dictionary = sim.reaction_preview("glycolytic_split")
	assert(preview.get("can_design_and_run", false) == true)
	assert(sim.build_transporter("phosphate_pump") == true)
	assert(sim.design_enzyme("glycolytic_split") == true)
	for i in 80:
		sim.tick(0.1)
	assert(sim.resources.get("electrons", 0.0) >= 5.0)
	assert(sim.queue_protein("storage_enzyme") == true)
	for i in 100:
		sim.tick(0.1)
	assert(sim.proteins_owned.get("storage_enzyme", 0) >= 1)
	sim.resources["dna_parts"] = 10.0
	sim.tick(0.1)
	assert(sim.research_points >= 10.0)
	assert(sim.research_tech("chemotaxis") == true)
	print("Simulation smoke test passed.")
	quit(0)
