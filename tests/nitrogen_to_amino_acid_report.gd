extends SceneTree

const Graph := preload("res://scripts/core/molecule_graph.gd")
const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

func _init() -> void:
	print("")
	print("NITROGEN TO AMINO ACID ROUTE REPORT")
	print("===================================")
	_report_current_game_route()
	_report_graph_route_with_cut()
	_report_live_route_with_atp_lyase()
	_report_self_funded_route()
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
		print("  Result: nitrogen-to-amino-acid is chemically possible as aminase, then ATP-spending lyase cuts off the N-C-COOH end.")
		print("  Design read: lyase is now available at start, so the live route is gated by ATP, N, and NADH rather than by enzyme unlock.")
	else:
		print("  Result: no lyase cut produced the amino acid target; the target matcher or cleavage rule needs adjustment.")

func _report_live_route_with_atp_lyase() -> void:
	var sim = SimulationStateScript.new()
	var glucose_id := _glucose_id(sim)
	var start_amino := float(sim.resources.get("Amino Acids", 0.0))
	var start_atp := float(sim.resources.get("ATP", 0.0))
	var start_n := float(sim.resources.get("N", 0.0))
	var start_nadh := float(sim.resources.get("NADH", 0.0))
	print("")
	print("Live route with starting lyase")
	var aminase_targets := sim.valid_targets("aminase", glucose_id)
	if aminase_targets.is_empty():
		print("  Failed: no aminase target on starter.")
		return
	assert(sim.design_enzyme("aminase", glucose_id, int(aminase_targets[0])) == true)
	for i in 80:
		sim.tick(0.25)
	var aminated_id := _find_formula_with_amount(sim, "C₆O₅N")
	if aminated_id.is_empty():
		print("  Failed: aminase did not accumulate C₆O₅N.")
		return
	var lyase_target := _target_cut_to_amino_acid(sim, aminated_id)
	if lyase_target < 0:
		print("  Failed: no lyase target on C₆O₅N creates the amino acid sink.")
		return
	assert(sim.design_enzyme("lyase", aminated_id, lyase_target) == true)
	for i in 160:
		sim.tick(0.25)
	print("  Designed route: aminase C₆O₆ -> C₆O₅N, then ATP-lyase C₆O₅N -> C₂O₂N target.")
	print("  Resources after route: Amino Acids %.1f (%+.1f), ATP %.1f (%+.1f), N %.1f (%+.1f), NADH %.1f (%+.1f)" % [
		float(sim.resources.get("Amino Acids", 0.0)),
		float(sim.resources.get("Amino Acids", 0.0)) - start_amino,
		float(sim.resources.get("ATP", 0.0)),
		float(sim.resources.get("ATP", 0.0)) - start_atp,
		float(sim.resources.get("N", 0.0)),
		float(sim.resources.get("N", 0.0)) - start_n,
		float(sim.resources.get("NADH", 0.0)),
		float(sim.resources.get("NADH", 0.0)) - start_nadh
	])
	print("  Remaining key molecules: %s" % _top_molecule_text(sim))
	print("  Read: ATP-gated lyase makes amino-acid release possible but ties production to an ATP-positive branch.")

func _report_self_funded_route() -> void:
	var sim = SimulationStateScript.new()
	var glucose_id := _glucose_id(sim)
	var start_amino := float(sim.resources.get("Amino Acids", 0.0))
	var start_atp := float(sim.resources.get("ATP", 0.0))
	print("")
	print("Self-funded ATP branch plus amino release")
	var decarb_targets := sim.valid_targets("decarboxylase", glucose_id)
	var aminase_targets := sim.valid_targets("aminase", glucose_id)
	if decarb_targets.is_empty() or aminase_targets.is_empty():
		print("  Failed: starter lacks decarboxylase or aminase target.")
		return
	assert(sim.design_enzyme("decarboxylase", glucose_id, int(decarb_targets[0])) == true)
	assert(sim.queue_enzyme_build(str(sim.pathway_list()[0].get("id", "")), 2) == true)
	for i in 40:
		sim.tick(0.25)
	assert(sim.design_enzyme("aminase", glucose_id, int(aminase_targets[0])) == true)
	for i in 80:
		sim.tick(0.25)
	var aminated_id := _find_formula_with_amount(sim, "C₆O₅N")
	if aminated_id.is_empty():
		print("  Failed: aminase did not accumulate C₆O₅N.")
		return
	var lyase_target := _target_cut_to_amino_acid(sim, aminated_id)
	if lyase_target < 0:
		print("  Failed: no lyase target on C₆O₅N creates amino acid target.")
		return
	assert(sim.design_enzyme("lyase", aminated_id, lyase_target) == true)
	for i in 200:
		sim.tick(0.25)
	var build_amino_cost := 10.0
	var amino_delta := float(sim.resources.get("Amino Acids", 0.0)) - start_amino
	print("  Resources after route: Amino Acids %.1f (%+.1f net, about %.1f gross before enzyme build cost), ATP %.1f (%+.1f)" % [
		float(sim.resources.get("Amino Acids", 0.0)),
		amino_delta,
		amino_delta + build_amino_cost,
		float(sim.resources.get("ATP", 0.0)),
		float(sim.resources.get("ATP", 0.0)) - start_atp
	])
	print("  Active molecules: %s" % _top_molecule_text(sim))
	print("  Read: decarboxylase can pay for lyase, but N/NADH still limit how much amino acid is made.")

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

func _find_formula_with_amount(sim, formula: String) -> String:
	var best := ""
	var best_amount := 0.0
	for id in sim.molecule_types.keys():
		if str(sim.molecule_types[id].get("formula", "")) != formula:
			continue
		var amount := float(sim.molecule_amounts.get(id, 0.0))
		if amount > best_amount:
			best = str(id)
			best_amount = amount
	return best

func _target_cut_to_amino_acid(sim, molecule_id: String) -> int:
	for target_index in sim.valid_targets("lyase", molecule_id):
		for product in sim.preview_products("lyase", molecule_id, int(target_index)):
			if sim.is_target_molecule(product):
				return int(target_index)
	return -1

func _top_molecule_text(sim) -> String:
	var entries: Array[Dictionary] = []
	for molecule_id in sim.present_molecule_ids():
		entries.append({
			"formula": sim.molecule_types[molecule_id].get("formula", "?"),
			"amount": float(sim.molecule_amounts.get(molecule_id, 0.0))
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("amount", 0.0)) > float(b.get("amount", 0.0))
	)
	var parts: Array[String] = []
	for i in mini(entries.size(), 5):
		parts.append("%s %.1f" % [entries[i].get("formula", "?"), float(entries[i].get("amount", 0.0))])
	return ", ".join(parts)
