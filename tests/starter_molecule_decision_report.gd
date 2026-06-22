extends SceneTree

const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")
const WATCHED_RESOURCES := ["ATP", "NADH", "N", "Amino Acids"]

func _init() -> void:
	print("")
	print("STARTER MOLECULE DECISION REPORT")
	print("================================")
	_print_starter_options()
	print("")
	_run_scenario("ATP first", [
		{"tool": "decarboxylase", "molecule": "glucose", "count": 3}
	])
	_run_scenario("Amination first", [
		{"tool": "aminase", "molecule": "glucose", "count": 2}
	])
	_run_scenario("Oxidize then decarboxylate", [
		{"tool": "oxygenase", "molecule": "glucose", "count": 2},
		{"wait": 16.0},
		{"tool": "decarboxylase", "molecule": "newest", "count": 2}
	])
	_run_scenario("Redox pair", [
		{"tool": "dehydrogenase", "molecule": "glucose", "count": 2},
		{"wait": 16.0},
		{"tool": "reductase", "molecule": "newest", "count": 2}
	])
	print("")
	print("Design read:")
	print("- The new starter has immediate ATP, amination, dehydrogenase, and reduction hooks.")
	print("- Carboxyl oxidase now correctly rejects the internal C=O because COOH formation is only valid on terminal carbonyl carbons.")
	print("- Decarboxylase gives a simple ATP branch but removes the terminal COOH, so it competes with amination context.")
	print("- Aminase can act immediately on the second-to-last C=O because the neighboring terminal carbon is COOH.")
	print("- Dehydrogenase branches produce NADH; without a strong sink, NADH accumulation remains the intended early pressure.")
	quit(0)

func _print_starter_options() -> void:
	var sim = SimulationStateScript.new()
	var glucose_id := _glucose_id(sim)
	var graph: Dictionary = sim.molecule_types[glucose_id]
	print("Starter: %s  %s" % [graph.get("name", "Molecule"), graph.get("formula", "?")])
	for tool in ["decarboxylase", "aminase", "oxygenase", "dehydrogenase", "reductase"]:
		var targets := sim.valid_targets(tool, glucose_id)
		var previews: Array[String] = []
		for i in mini(targets.size(), 3):
			var products := sim.preview_products(tool, glucose_id, int(targets[i]))
			var formulas: Array[String] = []
			for product in products:
				formulas.append(str(product.get("formula", "?")))
			previews.append("[%s]" % ", ".join(formulas))
		print("  %-14s targets %d  preview %s" % [tool, targets.size(), " ".join(previews)])

func _run_scenario(label: String, actions: Array) -> void:
	var sim = SimulationStateScript.new()
	var start_resources := _resource_amounts(sim)
	var start_glucose := float(sim.molecule_amounts.get(_glucose_id(sim), 0.0))
	var designed: Array[String] = []
	for action in actions:
		if action.has("wait"):
			_tick(sim, float(action["wait"]))
			continue
		var molecule_id := _select_molecule(sim, str(action.get("molecule", "glucose")))
		var tool := str(action.get("tool", ""))
		var targets := sim.valid_targets(tool, molecule_id)
		if targets.is_empty():
			designed.append("%s failed: no target on %s" % [tool, _molecule_label(sim, molecule_id)])
			continue
		var before: Array = sim.enzyme_blueprints.keys()
		var target := int(targets[0])
		if sim.design_enzyme(tool, molecule_id, target):
			var blueprint_id := _new_blueprint_id(sim, before)
			var count := maxi(1, int(action.get("count", 1)))
			if count > 1 and blueprint_id != "":
				sim.queue_enzyme_build(blueprint_id, count - 1)
			designed.append("%s x%d on %s" % [tool, count, _molecule_label(sim, molecule_id)])
			_tick(sim, 4.0)
		else:
			designed.append("%s failed: design rejected" % tool)
	_tick(sim, 90.0)
	var end_resources := _resource_amounts(sim)
	var end_glucose := float(sim.molecule_amounts.get(_glucose_id(sim), 0.0))
	print(label)
	print("  Designed: %s" % "; ".join(designed))
	print("  Resources: %s" % _resource_delta_text(start_resources, end_resources))
	print("  Glucose: %.1f -> %.1f, consumption %.2f/s, import %.2f/s" % [
		start_glucose,
		end_glucose,
		float(sim.molecule_rates.get(_glucose_id(sim), {}).get("consumption", 0.0)),
		float(sim.molecule_rates.get(_glucose_id(sim), {}).get("production", 0.0))
	])
	print("  Top molecules: %s" % _top_molecule_text(sim))
	print("  Active steps: %s" % _pathway_text(sim))

func _tick(sim, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var dt := minf(0.25, seconds - elapsed)
		sim.tick(dt)
		elapsed += dt

func _glucose_id(sim) -> String:
	for id in sim.molecule_types.keys():
		if sim.molecule_types[id].get("name", "") == "Glucose":
			return str(id)
	return str(sim.present_molecule_ids()[0])

func _select_molecule(sim, selector: String) -> String:
	if selector == "glucose":
		return _glucose_id(sim)
	if selector == "newest":
		var glucose_id := _glucose_id(sim)
		var best := glucose_id
		var best_amount := 0.0
		for id in sim.molecule_types.keys():
			if str(id) == glucose_id:
				continue
			var amount := float(sim.molecule_amounts.get(id, 0.0))
			if amount > best_amount:
				best = str(id)
				best_amount = amount
		return best
	return selector

func _new_blueprint_id(sim, before: Array) -> String:
	for blueprint_id in sim.enzyme_blueprints.keys():
		if not before.has(blueprint_id):
			return str(blueprint_id)
	return ""

func _resource_amounts(sim) -> Dictionary:
	var output := {}
	for resource_id in WATCHED_RESOURCES:
		output[resource_id] = float(sim.resources.get(resource_id, 0.0))
	return output

func _resource_delta_text(start: Dictionary, end: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in WATCHED_RESOURCES:
		var s := float(start.get(resource_id, 0.0))
		var e := float(end.get(resource_id, 0.0))
		parts.append("%s %.1f (%+.1f)" % [resource_id, e, e - s])
	return "; ".join(parts)

func _top_molecule_text(sim) -> String:
	var entries: Array[Dictionary] = []
	for molecule_id in sim.present_molecule_ids():
		entries.append({
			"id": str(molecule_id),
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

func _pathway_text(sim) -> String:
	var parts: Array[String] = []
	for pathway in sim.pathway_list():
		parts.append("%s %.2f/s" % [pathway.get("name", "Enzyme"), float(pathway.get("rate", 0.0))])
	if parts.is_empty():
		return "none"
	return "; ".join(parts)

func _molecule_label(sim, molecule_id: String) -> String:
	if not sim.molecule_types.has(molecule_id):
		return molecule_id
	return str(sim.molecule_types[molecule_id].get("formula", "?"))
