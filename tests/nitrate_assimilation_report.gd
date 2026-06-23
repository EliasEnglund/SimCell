extends SceneTree

const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

func _init() -> void:
	var sim = SimulationStateScript.new()
	var nitrate_id := _find_molecule_by_name(sim, "Nitrate")
	assert(not nitrate_id.is_empty())
	sim.molecule_amounts[nitrate_id] = 18.0
	sim.molecule_rates[nitrate_id] = {"production": 0.0, "consumption": 0.0}
	var targets := sim.valid_targets("nitrate_reductase", nitrate_id)
	assert(targets.size() == 1)
	var start_n := float(sim.resources.get("N", 0.0))
	var start_nadh := float(sim.resources.get("NADH", 0.0))
	var start_nitrate := float(sim.molecule_amounts.get(nitrate_id, 0.0))
	assert(sim.design_enzyme("nitrate_reductase", nitrate_id, int(targets[0])) == true)
	for i in 80:
		sim.tick(0.25)
	var end_n := float(sim.resources.get("N", 0.0))
	var end_nadh := float(sim.resources.get("NADH", 0.0))
	var end_nitrate := float(sim.molecule_amounts.get(nitrate_id, 0.0))
	print("")
	print("NITRATE ASSIMILATION REPORT")
	print("===========================")
	print("Rule: NO3 + 2 NADH -> N pool")
	print("Starting nitrate %.1f, N %.1f, NADH %.1f" % [start_nitrate, start_n, start_nadh])
	print("Ending nitrate %.1f, N %.1f (%+.1f), NADH %.1f (%+.1f)" % [
		end_nitrate,
		end_n,
		end_n - start_n,
		end_nadh,
		end_nadh - start_nadh
	])
	print("Read: nitrate assimilation works as a reductive sink; it is capped by available NADH.")
	assert(end_n > start_n)
	assert(end_nadh < start_nadh)
	assert(end_nitrate < start_nitrate)
	quit(0)

func _find_molecule_by_name(sim, name: String) -> String:
	for id in sim.molecule_types.keys():
		if str(sim.molecule_types[id].get("name", "")) == name:
			return str(id)
	return ""
