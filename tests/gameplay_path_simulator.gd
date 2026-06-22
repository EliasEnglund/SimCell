extends SceneTree

const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

const DEFAULT_DURATION := 90.0
const STEP_DT := 0.25
const WATCHED_RESOURCES := ["ATP", "NADH", "N", "Amino Acids", "DNA Points"]
const TOOL_ORDER := ["lyase", "dehydrogenase", "reductase", "oxygenase", "decarboxylase", "aminase", "desaturase"]

var _events: Array[String] = []

func _init() -> void:
	var scenario_name := _arg_value("--scenario", "all")
	if _arg_flag("--list"):
		_print_scenario_list()
		quit(0)
		return
	if scenario_name == "all":
		var selected_scenarios := _scenarios()
		_print_run_report_header(selected_scenarios)
		for scenario in selected_scenarios:
			_run_scenario(scenario)
	else:
		var found := false
		for scenario in _scenarios():
			if str(scenario.get("id", "")) == scenario_name:
				_print_run_report_header([scenario])
				_run_scenario(scenario)
				found = true
				break
		if not found:
			push_error("Unknown scenario '%s'. Use --list to see available scenarios." % scenario_name)
			quit(1)
			return
	quit(0)

func _scenarios() -> Array[Dictionary]:
	return [
		{
			"id": "baseline_import",
			"name": "Baseline Import Only",
			"notes": "No enzyme design. Shows how fast glucose accumulates from starting transporters.",
			"duration": 45.0,
			"actions": []
		},
		{
			"id": "tier1_carbon_cut",
			"name": "Tier 1 Carbon Cut",
			"notes": "Player builds the first available lyase on glucose, then watches product flow.",
			"duration": 90.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "queue_extra": 2}
			]
		},
		{
			"id": "redox_push",
			"name": "Redox Push",
			"notes": "Player oxidizes glucose first, then spends NADH with a reductase on the newest product.",
			"duration": 120.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "dehydrogenase", "molecule": "glucose", "target": "first", "queue_extra": 1},
				{"time": 12.0, "type": "design", "tool": "reductase", "molecule": "newest", "target": "first", "queue_extra": 1}
			]
		},
		{
			"id": "atp_branch",
			"name": "ATP Branch",
			"notes": "Player builds a decarboxylase route to test ATP-positive chemistry and carbon loss.",
			"duration": 120.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "decarboxylase", "molecule": "glucose", "target": "first", "queue_extra": 2}
			]
		},
		{
			"id": "amino_attempt",
			"name": "Amino Acid Attempt",
			"notes": "Player tries an early amino route: cut glucose, add nitrogen to a product, then oxygenate.",
			"duration": 150.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "queue_extra": 1},
				{"time": 12.0, "type": "design", "tool": "aminase", "molecule": "newest", "target": "first", "queue_extra": 1},
				{"time": 24.0, "type": "design", "tool": "oxygenase", "molecule": "newest", "target": "first", "queue_extra": 1}
			]
		},
		{
			"id": "candidate_scan",
			"name": "Candidate Scan",
			"notes": "Does not build. Lists valid first-step reactions from current starting molecules.",
			"duration": 0.0,
			"actions": [
				{"time": 0.0, "type": "scan"}
			]
		}
	]

func _print_scenario_list() -> void:
	print("Available gameplay simulation scenarios:")
	for scenario in _scenarios():
		print("  %s - %s" % [scenario.get("id", ""), scenario.get("notes", "")])

func _print_run_report_header(scenarios: Array) -> void:
	var sim = SimulationStateScript.new()
	print("\nSIMCELL GAMEPLAY PATH SIMULATION REPORT")
	print("======================================")
	print("Simulation count: %d" % scenarios.size())
	print("Step dt: %.2fs" % STEP_DT)
	print("Watched resources: %s" % ", ".join(WATCHED_RESOURCES))
	print("Starting resources: %s" % _resource_amounts(sim))
	print("Starting molecules: %s" % _molecule_summary(sim))
	print("Starting transporters:")
	for transporter in sim.transporter_list():
		print("  %s %s count %d rate/transporter %.2f/s total %.2f/s" % [
			str(transporter.get("direction", "")).capitalize(),
			_molecule_label(sim, str(transporter.get("molecule", ""))),
			int(transporter.get("count", 0)),
			float(transporter.get("rate_per_transporter", 0.0)),
			float(transporter.get("rate", 0.0))
		])
	print("Build assumptions:")
	print("  Enzyme build cost: %s" % _resource_delta_text(sim.ENZYME_BUILD_COST))
	print("  Transporter build cost: %s" % _resource_delta_text(sim.TRANSPORTER_BUILD_COST))
	print("  Enzyme build time: 3.0s per queued protein blueprint")
	print("First-target enzyme assumptions on starting glucose:")
	var glucose_id := _select_molecule(sim, "glucose")
	for tool in TOOL_ORDER:
		var targets: Array = sim.valid_targets(tool, glucose_id)
		if targets.is_empty():
			print("  %-14s no valid target" % tool)
			continue
		var target := int(targets[0])
		var summary: Dictionary = sim.enzyme_preview_summary(tool, glucose_id, target)
		print("  %-14s target %-2d kcat %.2f/s Km %.1f resource delta %s" % [
			tool,
			target,
			float(summary.get("kcat", 0.0)),
			18.0,
			_resource_delta_text(summary.get("resource_delta", {}))
		])

func _run_scenario(scenario: Dictionary) -> void:
	_events = []
	var sim = SimulationStateScript.new()
	sim.event_logged.connect(func(message: String): _events.append(message))
	var actions: Array = scenario.get("actions", [])
	actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	var duration := float(scenario.get("duration", DEFAULT_DURATION))
	var action_index := 0
	var next_report := 0.0
	print("\n=== %s ===" % scenario.get("name", scenario.get("id", "Scenario")))
	print("Notes: %s" % scenario.get("notes", ""))
	print("Inputs:")
	print("  Duration: %.1fs" % duration)
	print("  Initial resources: %s" % _resource_amounts(sim))
	print("  Initial molecules: %s" % _molecule_summary(sim))
	_print_action_plan(scenario)
	_print_snapshot(sim, "start")
	while sim.time_seconds <= duration + 0.0001:
		while action_index < actions.size() and float(actions[action_index].get("time", 0.0)) <= sim.time_seconds + 0.0001:
			_apply_action(sim, actions[action_index])
			action_index += 1
		if duration <= 0.0:
			break
		sim.tick(STEP_DT)
		if sim.time_seconds >= next_report:
			_print_snapshot(sim, "t=%03.0fs" % sim.time_seconds)
			next_report += maxf(30.0, duration / 3.0)
	_print_snapshot(sim, "final")
	_print_pathways(sim)
	_print_bottlenecks(sim)

func _apply_action(sim, action: Dictionary) -> void:
	var action_type := str(action.get("type", ""))
	match action_type:
		"design":
			_design_action(sim, action)
		"scan":
			_print_candidate_scan(sim)
		_:
			print("  action skipped: unknown type '%s'" % action_type)

func _design_action(sim, action: Dictionary) -> void:
	var tool := str(action.get("tool", ""))
	var molecule_id := _select_molecule(sim, str(action.get("molecule", "glucose")))
	if molecule_id.is_empty():
		print("  design failed: no molecule for selector '%s'" % action.get("molecule", ""))
		return
	var target := _select_target(sim, tool, molecule_id, str(action.get("target", "first")))
	if target < 0:
		print("  design failed: %s has no valid %s target" % [_molecule_label(sim, molecule_id), tool])
		return
	var before_blueprints: Array = sim.enzyme_blueprints.keys()
	var ok: bool = sim.design_enzyme(tool, molecule_id, target)
	if not ok:
		print("  design failed: %s on %s target %d" % [tool, _molecule_label(sim, molecule_id), target])
		return
	var blueprint_id := _new_blueprint_id(sim, before_blueprints)
	var extra := int(action.get("queue_extra", 0))
	if not blueprint_id.is_empty() and extra > 0:
		sim.queue_enzyme_build(blueprint_id, extra)
	var blueprint: Dictionary = sim.enzyme_blueprints.get(blueprint_id, {})
	print("  designed %s on %s target %d%s | kcat %.2f/s Km %.1f active now %d queued %d delta %s" % [
		tool,
		_molecule_label(sim, molecule_id),
		target,
		" (+%d extra builds)" % extra if extra > 0 else "",
		float(blueprint.get("kcat", 0.0)),
		float(blueprint.get("km", 0.0)),
		int(sim.active_enzymes.get(blueprint_id, 0)),
		_count_queued_builds(sim, blueprint_id),
		_resource_delta_text(blueprint.get("resource_delta", {}))
	])

func _print_candidate_scan(sim) -> void:
	print("  valid first-step reaction candidates:")
	for molecule_id in sim.present_molecule_ids():
		for tool in TOOL_ORDER:
			var targets: Array = sim.valid_targets(tool, molecule_id)
			if targets.is_empty():
				continue
			var target := int(targets[0])
			var products: Array = sim.product_preview_info(tool, molecule_id, target)
			var product_labels: Array[String] = []
			for product in products:
				var escaped := bool(product.get("escapes", false))
				product_labels.append("%s%s" % [product.get("formula", "?"), " gas" if escaped else ""])
			var delta: Dictionary = sim.enzyme_preview_summary(tool, molecule_id, target).get("resource_delta", {})
			print("    %-14s %-18s target %-2d -> %-24s resources %s" % [
				tool,
				_molecule_label(sim, molecule_id),
				target,
				" + ".join(product_labels),
				_resource_delta_text(delta)
			])

func _select_molecule(sim, selector: String) -> String:
	if selector == "glucose":
		for molecule_id in sim.molecule_types.keys():
			if sim.molecule_types[molecule_id].get("name", "") == "Glucose":
				return molecule_id
	if selector == "newest":
		var newest := ""
		for molecule_id in sim.molecule_types.keys():
			if not sim.outside_amounts.has(molecule_id) and sim.molecule_amounts.has(molecule_id):
				newest = molecule_id
		return newest
	if selector == "largest_pool":
		var best := ""
		var best_amount := -1.0
		for molecule_id in sim.present_molecule_ids():
			var amount := float(sim.molecule_amounts.get(molecule_id, 0.0))
			if amount > best_amount:
				best = molecule_id
				best_amount = amount
		return best
	if sim.molecule_types.has(selector):
		return selector
	for molecule_id in sim.molecule_types.keys():
		var molecule: Dictionary = sim.molecule_types[molecule_id]
		if molecule.get("formula", "") == selector or molecule.get("name", "") == selector:
			return molecule_id
	return ""

func _select_target(sim, tool: String, molecule_id: String, strategy: String) -> int:
	var targets: Array = sim.valid_targets(tool, molecule_id)
	if targets.is_empty():
		return -1
	if strategy == "last":
		return int(targets[targets.size() - 1])
	return int(targets[0])

func _new_blueprint_id(sim, before: Array) -> String:
	for blueprint_id in sim.enzyme_blueprints.keys():
		if not before.has(blueprint_id):
			return str(blueprint_id)
	return ""

func _print_snapshot(sim, label: String) -> void:
	print("  [%s] resources %s | molecules %s" % [
		label,
		_resource_summary(sim),
		_molecule_summary(sim)
	])

func _resource_summary(sim) -> String:
	var parts: Array[String] = []
	for resource_id in WATCHED_RESOURCES:
		var amount := float(sim.resources.get(resource_id, 0.0))
		var rates: Dictionary = sim.resource_rates.get(resource_id, {})
		var net := float(rates.get("production", 0.0)) - float(rates.get("consumption", 0.0))
		parts.append("%s %.1f (%+.2f/s)" % [resource_id, amount, net])
	return "; ".join(parts)

func _molecule_summary(sim) -> String:
	var entries: Array[Dictionary] = []
	for molecule_id in sim.present_molecule_ids():
		entries.append({
			"id": molecule_id,
			"formula": sim.molecule_types[molecule_id].get("formula", "?"),
			"amount": float(sim.molecule_amounts.get(molecule_id, 0.0))
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("amount", 0.0)) > float(b.get("amount", 0.0))
	)
	var parts: Array[String] = []
	for i in mini(entries.size(), 6):
		var entry := entries[i]
		parts.append("%s %.1f" % [entry.get("formula", "?"), float(entry.get("amount", 0.0))])
	return ", ".join(parts)

func _print_pathways(sim) -> void:
	print("  pathways:")
	var pathways: Array = sim.pathway_list()
	if pathways.is_empty():
		print("    none")
		return
	for pathway in pathways:
		var products: Array[String] = []
		for product_id in pathway.get("products", []):
			products.append(_molecule_label(sim, str(product_id)))
		var blueprint_id := str(pathway.get("id", pathway.get("blueprint_id", "")))
		var blueprint: Dictionary = sim.enzyme_blueprints.get(blueprint_id, pathway)
		print("    %-22s active %d queued %d kcat %.2f/s Km %.1f rate %.2f/s delta %s -> %s" % [
			pathway.get("name", "Enzyme"),
			int(pathway.get("active_count", 0)),
			int(pathway.get("queued_count", 0)),
			float(blueprint.get("kcat", 0.0)),
			float(blueprint.get("km", 0.0)),
			float(pathway.get("rate", 0.0)),
			_resource_delta_text(blueprint.get("resource_delta", {})),
			", ".join(products)
		])

func _print_bottlenecks(sim) -> void:
	var warnings: Array[String] = []
	if float(sim.resources.get("ATP", 0.0)) < 5.0:
		warnings.append("ATP is nearly depleted.")
	if float(sim.resources.get("NADH", 0.0)) < 1.0:
		warnings.append("NADH is depleted; reductase/oxygenase routes may stall.")
	if float(sim.resources.get("NADH", 0.0)) > 60.0:
		warnings.append("NADH is accumulating; add electron sinks.")
	if float(sim.resources.get("N", 0.0)) < 1.0:
		warnings.append("Nitrogen is depleted; aminase routes may stall.")
	var amino_rate := _net_resource_rate(sim, "Amino Acids")
	if amino_rate <= 0.01:
		warnings.append("No steady amino acid production yet.")
	print("  bottlenecks:")
	if warnings.is_empty():
		print("    none detected in this simplified run")
	else:
		for warning in warnings:
			print("    - %s" % warning)

func _net_resource_rate(sim, resource_id: String) -> float:
	var rates: Dictionary = sim.resource_rates.get(resource_id, {})
	return float(rates.get("production", 0.0)) - float(rates.get("consumption", 0.0))

func _molecule_label(sim, molecule_id: String) -> String:
	if not sim.molecule_types.has(molecule_id):
		return molecule_id
	return "%s[%s]" % [sim.molecule_types[molecule_id].get("formula", "?"), molecule_id.md5_text().substr(0, 6)]

func _resource_amounts(sim) -> String:
	var parts: Array[String] = []
	for resource_id in WATCHED_RESOURCES:
		parts.append("%s %.1f" % [resource_id, float(sim.resources.get(resource_id, 0.0))])
	return "; ".join(parts)

func _print_action_plan(scenario: Dictionary) -> void:
	var actions: Array = scenario.get("actions", [])
	if actions.is_empty():
		print("  Actions: none")
		return
	print("  Actions:")
	for action in actions:
		if str(action.get("type", "")) == "design":
			print("    t=%05.1fs design %-14s on %-12s target %-5s queued builds %d" % [
				float(action.get("time", 0.0)),
				str(action.get("tool", "")),
				str(action.get("molecule", "")),
				str(action.get("target", "")),
				1 + int(action.get("queue_extra", 0))
			])
		else:
			print("    t=%05.1fs %s" % [float(action.get("time", 0.0)), str(action.get("type", ""))])

func _count_queued_builds(sim, blueprint_id: String) -> int:
	var count := 0
	for item in sim.protein_queue:
		if str(item.get("id", "")) == blueprint_id:
			count += 1
	return count

func _resource_delta_text(delta: Dictionary) -> String:
	if delta.is_empty():
		return "none"
	var parts: Array[String] = []
	for key in delta.keys():
		parts.append("%s%+.1f" % [key, float(delta[key])])
	return ", ".join(parts)

func _arg_value(name: String, default_value: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == name and i + 1 < args.size():
			return args[i + 1]
	return default_value

func _arg_flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)
