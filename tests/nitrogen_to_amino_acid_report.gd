extends SceneTree

const Graph := preload("res://scripts/core/molecule_graph.gd")
const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

func _init() -> void:
	print("")
	print("NITROGEN TO AMINO ACID ROUTE REPORT")
	print("===================================")
	_report_current_game_route()
	_report_graph_route_with_cut()
	quit(0)

func _report_current_game_route() -> void:
	var sim = SimulationStateScript.new()
	var glucose_id := _glucose_id(sim)
	var start_amino := float(sim.resources.get("Amino Acids", 0.0))
	var start_n := float(sim.resources.get("N", 0.0))
	var start_nadh := float(sim.resources.get("NADH", 0.0))
	var aminase_targets := sim.valid_targets("aminase", glucose_id)
	print("Current starting toolset")
	print("  Starter: %s %s" % [sim.molecule_types[glucose_id].get("name", "Molecule"), sim.molecule_types[glucose_id].get("formula", "?")])
	print("  Aminase targets on starter: %d" % aminase_targets.size())
	if aminase_targets.is_empty():
		print("  Result: nitrogen cannot enter the starter molecule.")
		return
	var preview := sim.preview_products("aminase", glucose_id, int(aminase_targets[0]))
	print("  Aminase preview: %s" % _formula_list(preview))
	var is_target := false
	for product in preview:
		if sim.is_target_molecule(product):
			is_target = true
	print("  Aminase product is amino acid target: %s" % str(is_target))
	assert(sim.design_enzyme("aminase", glucose_id, int(aminase_targets[0])) == true)
	for i in 100:
		sim.tick(0.25)
	print("  After aminase only: Amino Acids %.1f (%+.1f), N %.1f (%+.1f), NADH %.1f (%+.1f)" % [
		float(sim.resources.get("Amino Acids", 0.0)),
		float(sim.resources.get("Amino Acids", 0.0)) - start_amino,
		float(sim.resources.get("N", 0.0)),
		float(sim.resources.get("N", 0.0)) - start_n,
		float(sim.resources.get("NADH", 0.0)),
		float(sim.resources.get("NADH", 0.0)) - start_nadh
	])
	print("  Read: aminase adds nitrogen, but it makes a large C6 amino precursor, not the C2 amino acid sink.")

func _report_graph_route_with_cut() -> void:
	var starter := Graph.initial_glucose_like()
	var aminase_targets := Graph.valid_aminase_targets(starter)
	print("")
	print("Chemistry route if C-C cleavage is available")
	if aminase_targets.is_empty():
		print("  No aminase target exists; route impossible.")
		return
	var aminated_products := Graph.apply_aminase(starter, int(aminase_targets[0]))
	if aminated_products.is_empty():
		print("  Aminase product failed.")
		return
	var aminated: Dictionary = aminated_products[0]
	print("  Step 1 aminase: %s -> %s" % [starter.get("formula", "?"), aminated.get("formula", "?")])
	var lyase_targets := Graph.valid_lyase_targets(aminated)
	var target_sim = SimulationStateScript.new()
	var found_target := false
	for target_index in lyase_targets:
		var products := Graph.apply_lyase(aminated, int(target_index))
		var product_formulas := _formula_list(products)
		var target_flags: Array[String] = []
		for product in products:
			if target_sim.is_target_molecule(product):
				found_target = true
				target_flags.append("%s TARGET" % product.get("formula", "?"))
		if not target_flags.is_empty():
			print("  Step 2 lyase target %d: %s -> %s" % [int(target_index), product_formulas, ", ".join(target_flags)])
	if found_target:
		print("  Result: nitrogen-to-amino-acid is chemically possible as aminase, then lyase cuts off the N-C-COOH end.")
		print("  Design blocker: lyase is currently locked in the starting enzyme set, so the live starter cannot complete this route yet.")
	else:
		print("  Result: no lyase cut produced the amino acid target; the target matcher or cleavage rule needs adjustment.")

func _glucose_id(sim) -> String:
	for id in sim.molecule_types.keys():
		if sim.molecule_types[id].get("name", "") == "Glucose":
			return str(id)
	return str(sim.present_molecule_ids()[0])

func _formula_list(products: Array) -> String:
	var formulas: Array[String] = []
	for product in products:
		formulas.append(str(product.get("formula", "?")))
	return "[" + ", ".join(formulas) + "]"
