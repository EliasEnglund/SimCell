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
	if _arg_flag("--balance-matrix"):
		_run_balance_matrix()
		quit(0)
		return
	if _arg_flag("--energy-matrix"):
		_run_energy_matrix()
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
	print("\nBalance matrix:")
	print("  --balance-matrix - Runs enzyme on/off and parameter cases for gameplay analysis.")
	print("  --energy-matrix - Tests COOH/decarboxylase ATP economy and nitrogen entry options.")

func _print_run_report_header(scenarios: Array) -> void:
	var sim = SimulationStateScript.new()
	sim.experimental_all_enzyme_tools_unlocked = true
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
			float(summary.get("km", 0.0)),
			_resource_delta_text(summary.get("resource_delta", {}))
		])

func _run_scenario(scenario: Dictionary) -> void:
	_events = []
	var sim = SimulationStateScript.new()
	sim.experimental_all_enzyme_tools_unlocked = true
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
	if not blueprint_id.is_empty():
		_apply_blueprint_overrides(sim, blueprint_id, action)
		blueprint = sim.enzyme_blueprints.get(blueprint_id, {})
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

func _apply_blueprint_overrides(sim, blueprint_id: String, action: Dictionary) -> void:
	if not sim.enzyme_blueprints.has(blueprint_id):
		return
	var blueprint: Dictionary = sim.enzyme_blueprints[blueprint_id]
	if action.has("kcat"):
		blueprint["kcat"] = float(action["kcat"])
	if action.has("km"):
		blueprint["km"] = float(action["km"])
	if action.has("resource_delta"):
		blueprint["resource_delta"] = action["resource_delta"]
	sim.enzyme_blueprints[blueprint_id] = blueprint

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

func _run_balance_matrix() -> void:
	var cases := _balance_cases()
	print("\nSIMCELL ENZYME BALANCE MATRIX")
	print("=============================")
	print("Simulation count: %d" % cases.size())
	print("Step dt: %.2fs" % STEP_DT)
	print("Goal model: import glucose, build a handful of enzymes, convert carbon fragments toward amino acid resources, keep ATP/NADH/N from hard-blocking flux.")
	print("Biochemistry anchor: glycolysis-like oxidation should create ATP and NADH; anaerobic play must spend NADH through reductive/fermentation-like sinks or it becomes a design pressure.")
	print("")
	var results: Array[Dictionary] = []
	for case in cases:
		results.append(_run_balance_case(case))
	_print_balance_table(results)
	_print_balance_interpretation(results)

func _balance_cases() -> Array[Dictionary]:
	return [
		{
			"id": "import_only",
			"name": "Import Only",
			"duration": 120.0,
			"glucose_import_rate": 8.0,
			"actions": [],
			"design_goal": "Baseline: glucose source with no metabolism."
		},
		{
			"id": "lyase_one",
			"name": "One Lyase",
			"duration": 120.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 1}
			],
			"design_goal": "Single early enzyme should visibly transform substrate near 1/s once built."
		},
		{
			"id": "lyase_handful",
			"name": "Handful Lyases",
			"duration": 120.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 4}
			],
			"design_goal": "Checks whether a handful of enzymes can keep up with starter import."
		},
		{
			"id": "slow_low_affinity",
			"name": "Slow Low-Affinity Lyase",
			"duration": 120.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 4, "kcat": 0.45, "km": 42.0}
			],
			"design_goal": "Bad enzyme numbers should create substrate buildup and teach why upgrades matter."
		},
		{
			"id": "good_handful",
			"name": "Good Handful Lyase",
			"duration": 120.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 4, "kcat": 1.35, "km": 12.0}
			],
			"design_goal": "Good tier-1 enzyme should be a clear improvement without making import irrelevant."
		},
		{
			"id": "amino_no_n_unlock",
			"name": "Amino Attempt No N Unlock",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 2},
				{"time": 16.0, "type": "design", "tool": "aminase", "molecule": "newest", "target": "first", "count": 2},
				{"time": 32.0, "type": "design", "tool": "oxygenase", "molecule": "newest", "target": "first", "count": 1}
			],
			"design_goal": "Expected blocker: nitrogen pool runs out before stable amino production."
		},
		{
			"id": "amino_aminase_off",
			"name": "Amino Route Without Aminase",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"resources": {"N": 40.0},
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 2},
				{"time": 32.0, "type": "design", "tool": "oxygenase", "molecule": "newest", "target": "first", "count": 1}
			],
			"design_goal": "Controlled off-test: without aminase, nitrogen cannot enter the carbon product route."
		},
		{
			"id": "amino_oxygenase_off",
			"name": "Amino Route Without Oxygenase",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"resources": {"N": 40.0},
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 2},
				{"time": 16.0, "type": "design", "tool": "aminase", "molecule": "newest", "target": "first", "count": 2}
			],
			"design_goal": "Controlled off-test: with nitrogen but no oxygenation, the route should still miss N-C-COOH."
		},
		{
			"id": "amino_with_n_pool",
			"name": "Amino Attempt With N Pool",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"resources": {"N": 40.0},
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 2},
				{"time": 16.0, "type": "design", "tool": "aminase", "molecule": "newest", "target": "first", "count": 2},
				{"time": 32.0, "type": "design", "tool": "oxygenase", "molecule": "newest", "target": "first", "count": 1}
			],
			"design_goal": "Tests whether nitrogen unlock alone solves amino production."
		},
		{
			"id": "redox_source_only",
			"name": "Redox Source Only",
			"duration": 150.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "dehydrogenase", "molecule": "glucose", "target": "first", "count": 3}
			],
			"design_goal": "Expected pressure: NADH accumulates if oxidation has no sink."
		},
		{
			"id": "redox_source_sink",
			"name": "Redox Source And Sink",
			"duration": 150.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "dehydrogenase", "molecule": "glucose", "target": "first", "count": 2},
				{"time": 16.0, "type": "design", "tool": "reductase", "molecule": "newest", "target": "first", "count": 2}
			],
			"design_goal": "Fermentation-like pair: oxidation creates NADH, reduction spends it."
		},
		{
			"id": "atp_carbon_loss",
			"name": "ATP Carbon-Loss Branch",
			"duration": 150.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "decarboxylase", "molecule": "glucose", "target": "first", "count": 3}
			],
			"design_goal": "ATP-positive branch should help energy but leak carbon as CO2."
		}
	]

func _run_energy_matrix() -> void:
	var cases := _energy_cases()
	print("\nSIMCELL COOH / ATP / NITROGEN ECONOMY TEST")
	print("==========================================")
	print("Simulation count: %d" % cases.size())
	print("Hypothesis: early ATP comes only from decarboxylating COOH ends. CO -> COOH preparation creates NADH, so ATP production must be paired with a redox sink. Nitrogen entry can start as direct N-resource amination, while imported N-substrate ligation needs a new enzyme class.")
	print("")
	print("Biochemical mapping for the prototype:")
	print("  CO -> COOH: aldehyde dehydrogenase / aldehyde oxidase style reaction. Game rule tested here: add O to a carbonyl-like end and produce NADH.")
	print("  COOH -> CO2 + ATP: decarboxylase / substrate-level phosphorylation abstraction. Game rule tested here: lose carboxyl carbon and gain ATP.")
	print("  NADH sink: reductase / fermentation-like reduction. Game rule tested here: consume NADH to reduce C=O or C=C.")
	print("  Direct N attachment: aminase/transaminase abstraction using internal N resource.")
	print("  Imported N attachment: would require nitrate/ammonia assimilation plus aminotransferase or ligase; current prototype does not yet support this as molecule-to-molecule chemistry.")
	print("")
	var results: Array[Dictionary] = []
	for case in cases:
		results.append(_run_balance_case(case))
	_print_energy_table(results)
	_print_energy_interpretation(results)

func _energy_cases() -> Array[Dictionary]:
	return [
		{
			"id": "cooh_decarb_only",
			"name": "Existing COOH Decarboxylase",
			"duration": 150.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "decarboxylase", "molecule": "glucose", "target": "first", "count": 4, "kcat": 0.70, "km": 16.0}
			],
			"design_goal": "Can the player get ATP immediately from existing COOH-like glucose ends?"
		},
		{
			"id": "co_to_cooh_only",
			"name": "CO To COOH Prep Only",
			"duration": 150.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "oxygenase", "molecule": "glucose", "target": "first", "count": 3, "kcat": 0.75, "km": 18.0, "resource_delta": {"NADH": 1.0}}
			],
			"design_goal": "COOH preparation should create NADH pressure without directly producing ATP."
		},
		{
			"id": "cooh_prep_then_decarb",
			"name": "COOH Prep Then Decarb",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "oxygenase", "molecule": "glucose", "target": "first", "count": 3, "kcat": 0.75, "km": 18.0, "resource_delta": {"NADH": 1.0}},
				{"time": 24.0, "type": "design", "tool": "decarboxylase", "molecule": "newest", "target": "first", "count": 3, "kcat": 0.70, "km": 16.0}
			],
			"design_goal": "Test the proposed ATP loop: make more COOH ends, then decarboxylate them."
		},
		{
			"id": "cooh_prep_decarb_redox",
			"name": "COOH Prep Decarb Redox Sink",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "oxygenase", "molecule": "glucose", "target": "first", "count": 2, "kcat": 0.75, "km": 18.0, "resource_delta": {"NADH": 1.0}},
				{"time": 24.0, "type": "design", "tool": "decarboxylase", "molecule": "newest", "target": "first", "count": 3, "kcat": 0.70, "km": 16.0},
				{"time": 40.0, "type": "design", "tool": "reductase", "molecule": "newest", "target": "first", "count": 3, "kcat": 0.80, "km": 18.0}
			],
			"design_goal": "Check whether a reduction branch can spend NADH produced by COOH preparation."
		},
		{
			"id": "direct_n_amination_low_n",
			"name": "Direct N Amination Low N",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 2},
				{"time": 20.0, "type": "design", "tool": "aminase", "molecule": "newest", "target": "first", "count": 2}
			],
			"design_goal": "Direct N-resource amination should work briefly, then reveal nitrogen starvation."
		},
		{
			"id": "direct_n_amination_high_n",
			"name": "Direct N Amination High N",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"resources": {"N": 60.0},
			"actions": [
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 2},
				{"time": 20.0, "type": "design", "tool": "aminase", "molecule": "newest", "target": "first", "count": 2}
			],
			"design_goal": "Increasing internal N should reveal whether nitrogen supply alone solves amination flux."
		},
		{
			"id": "imported_n_gap",
			"name": "Imported N Substrate Gap",
			"duration": 180.0,
			"glucose_import_rate": 8.0,
			"actions": [
				{"time": 0.0, "type": "transporter", "direction": "import", "molecule": "Nitrate", "count": 3},
				{"time": 0.0, "type": "design", "tool": "lyase", "molecule": "glucose", "target": "first", "count": 2},
				{"time": 20.0, "type": "design", "tool": "aminase", "molecule": "newest", "target": "first", "count": 2}
			],
			"design_goal": "Shows that importing nitrate does not yet feed N-resource amination without a nitrate assimilation enzyme."
		}
	]

func _print_energy_table(results: Array[Dictionary]) -> void:
	print("ENERGY / NITROGEN CASE SUMMARY")
	print("------------------------------")
	print("%-28s %-18s %-20s %-20s %-24s %s" % ["Case", "ATP outcome", "NADH outcome", "N outcome", "Active steps", "Design read"])
	for result in results:
		print("%-28s %-18s %-20s %-20s %-24s %s" % [
			result.get("id", ""),
			_resource_delta_from_start(result, "ATP"),
			_resource_delta_from_start(result, "NADH"),
			_resource_delta_from_start(result, "N"),
			_short_pathway_rates(result.get("pathways", [])),
			_energy_design_read(result)
		])
	print("")
	print("DETAILS")
	print("-------")
	for result in results:
		print("%s: %s" % [result.get("name", ""), result.get("goal", "")])
		print("  Designed: %s" % _designed_detail(result.get("designed", [])))
		print("  Pathways: %s" % _pathway_detail(result.get("pathways", [])))
		print("  Resources: ATP %s | NADH %s | N %s | AA %s" % [
			_resource_delta_from_start(result, "ATP"),
			_resource_delta_from_start(result, "NADH"),
			_resource_delta_from_start(result, "N"),
			_resource_delta_from_start(result, "Amino Acids")
		])
		print("  Redox: %s" % _redox_detail(result))
		print("  Interpretation: %s" % _energy_design_read(result))

func _print_energy_interpretation(results: Array[Dictionary]) -> void:
	print("")
	print("DESIGN INTERPRETATION")
	print("---------------------")
	print("- Required starting ATP enzymes: a carboxyl-forming oxidase/dehydrogenase and a decarboxylase. The carboxyl-forming step should create NADH; decarboxylase should create ATP while losing carbon.")
	print("- Real-world analogy: aldehyde dehydrogenase oxidizes an aldehyde toward carboxylic acid and reduces NAD+ to NADH. Decarboxylases remove carboxyl groups as CO2; in this game we can abstract a coupled ATP yield from that carbon-loss step.")
	print("- Redox consequence: if COOH preparation creates NADH, an anaerobic player needs reductase/fermentation sinks. Otherwise NADH accumulates and oxidation should eventually stall or become inefficient.")
	print("- Nitrogen option A: direct aminase/transaminase uses an internal N resource. This is easiest to teach and should be tier 1.")
	print("- Nitrogen option B: nitrate/ammonia import needs an assimilation enzyme that converts imported N substrate into the N resource, or a ligase/transaminase that transfers N from an imported molecule onto carbon. That is a separate unlock, not supported by current generic graph chemistry.")
	print("- Practical progression: Tier 1 can be COOH maker, decarboxylase, reductase sink, direct aminase. Tier 2 can add nitrate assimilation/imported-N ligases. Tier 3 can add more efficient redox/respiration to make oxidation-heavy routes scalable.")

func _resource_delta_from_start(result: Dictionary, resource_id: String) -> String:
	var initial: Dictionary = result.get("initial_resources", {})
	var final: Dictionary = result.get("final_resources", {})
	var start := float(initial.get(resource_id, 0.0))
	var end := float(final.get(resource_id, 0.0))
	return "%.1f (%+.1f)" % [end, end - start]

func _short_pathway_rates(pathways: Array) -> String:
	if pathways.is_empty():
		return "none"
	var parts: Array[String] = []
	for pathway in pathways:
		var tool := str(pathway.get("tool", pathway.get("name", "?")))
		parts.append("%s %.2f/s" % [tool.substr(0, 5), float(pathway.get("rate", 0.0))])
	return "; ".join(parts)

func _energy_design_read(result: Dictionary) -> String:
	var case_id := str(result.get("id", ""))
	var initial: Dictionary = result.get("initial_resources", {})
	var final: Dictionary = result.get("final_resources", {})
	var atp_delta := float(final.get("ATP", 0.0)) - float(initial.get("ATP", 0.0))
	var nadh_delta := float(final.get("NADH", 0.0)) - float(initial.get("NADH", 0.0))
	var n_delta := float(final.get("N", 0.0)) - float(initial.get("N", 0.0))
	if case_id == "cooh_decarb_only":
		return "ATP works if COOH already exists; this gives an immediate but carbon-losing energy route." if atp_delta > 20.0 else "Too little ATP from existing COOH."
	if case_id == "co_to_cooh_only":
		return "COOH-prep creates NADH pressure without ATP, as intended." if nadh_delta > 20.0 and atp_delta <= 0.0 else "COOH-prep rule needs retuning."
	if case_id == "cooh_prep_then_decarb":
		return "Combines ATP gain with NADH buildup; needs a sink unlock." if atp_delta > 20.0 and nadh_delta > 20.0 else "Combined route did not create the intended ATP/redox pressure."
	if case_id == "cooh_prep_decarb_redox":
		return "Reductase helps but must be strong enough to match COOH-prep NADH output." if nadh_delta > 20.0 else "Redox sink can balance this route at current numbers."
	if case_id == "direct_n_amination_low_n":
		return "Direct amination is teachable but N-starved at starter pools." if n_delta <= -5.0 else "Direct amination did not create meaningful N pressure."
	if case_id == "direct_n_amination_high_n":
		return "Extra N improves uptime, but target amino-acid chemistry still needs a route to N-C-COOH." if n_delta < 0.0 else "High N did not engage the aminase route."
	if case_id == "imported_n_gap":
		return "Nitrate import alone does not feed aminase; add nitrate assimilation or N-transfer ligase."
	return str(result.get("bottleneck", ""))

func _run_balance_case(case: Dictionary) -> Dictionary:
	var sim = SimulationStateScript.new()
	sim.experimental_all_enzyme_tools_unlocked = true
	_apply_balance_setup(sim, case)
	var initial_resources: Dictionary = sim.resources.duplicate(true)
	var initial_molecules: Dictionary = sim.molecule_amounts.duplicate(true)
	var unlock_report := _unlock_report(sim)
	var actions: Array = case.get("actions", [])
	actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)
	var duration := float(case.get("duration", DEFAULT_DURATION))
	var action_index := 0
	var max_rates := _empty_rate_tracker()
	var glucose_flux := {"import_peak": 0.0, "consumption_peak": 0.0, "net_accumulation_peak": 0.0}
	var designed: Array[Dictionary] = []
	while sim.time_seconds <= duration + 0.0001:
		while action_index < actions.size() and float(actions[action_index].get("time", 0.0)) <= sim.time_seconds + 0.0001:
			var designed_item := _apply_balance_action(sim, actions[action_index])
			if not designed_item.is_empty():
				designed.append(designed_item)
			action_index += 1
		if duration <= 0.0:
			break
		sim.tick(STEP_DT)
		_track_peak_rates(sim, max_rates)
		_track_glucose_flux(sim, glucose_flux)
	var result := {
		"id": case.get("id", ""),
		"name": case.get("name", ""),
		"goal": case.get("design_goal", ""),
		"duration": duration,
		"glucose_import_rate": float(case.get("glucose_import_rate", 8.0)),
		"designed": designed,
		"initial_resources": initial_resources,
		"initial_molecules": initial_molecules,
		"available_unlocks": unlock_report,
		"final_resources": sim.resources.duplicate(true),
		"final_molecules": sim.molecule_amounts.duplicate(true),
		"max_rates": max_rates,
		"glucose_flux": glucose_flux,
		"pathways": sim.pathway_list(),
		"bottleneck": "",
		"blockers": [],
		"unlock": "",
		"verdict": "",
		"score": 0.0
	}
	_annotate_balance_result(result)
	return result

func _apply_balance_setup(sim, case: Dictionary) -> void:
	for resource_id in Dictionary(case.get("resources", {})).keys():
		sim.resources[resource_id] = float(case["resources"][resource_id])
	var glucose_id := _select_molecule(sim, "glucose")
	var import_rate := float(case.get("glucose_import_rate", 8.0))
	if not glucose_id.is_empty():
		var transporter_id := "import:%s" % glucose_id.md5_text()
		if sim.transporters.has(transporter_id):
			var count := maxi(1, int(sim.transporters[transporter_id].get("count", 1)))
			sim.transporters[transporter_id]["rate_per_transporter"] = import_rate / float(count)

func _apply_balance_action(sim, action: Dictionary) -> Dictionary:
	var action_type := str(action.get("type", ""))
	if action_type == "transporter":
		return _apply_transporter_action(sim, action)
	if action_type != "design":
		return {}
	var tool := str(action.get("tool", ""))
	var molecule_id := _select_molecule(sim, str(action.get("molecule", "glucose")))
	if molecule_id.is_empty():
		return {"tool": tool, "status": "failed: missing molecule"}
	var target := _select_target(sim, tool, molecule_id, str(action.get("target", "first")))
	if target < 0:
		return {"tool": tool, "status": "failed: no valid target", "substrate": _molecule_label(sim, molecule_id)}
	var before_blueprints: Array = sim.enzyme_blueprints.keys()
	var ok: bool = sim.design_enzyme(tool, molecule_id, target)
	if not ok:
		return {"tool": tool, "status": "failed: design rejected", "substrate": _molecule_label(sim, molecule_id)}
	var blueprint_id := _new_blueprint_id(sim, before_blueprints)
	_apply_blueprint_overrides(sim, blueprint_id, action)
	var count := maxi(1, int(action.get("count", 1)))
	if count > 1:
		sim.queue_enzyme_build(blueprint_id, count - 1)
	var blueprint: Dictionary = sim.enzyme_blueprints.get(blueprint_id, {})
	return {
		"id": blueprint_id,
		"tool": tool,
		"substrate": _molecule_label(sim, molecule_id),
		"target": target,
		"count": count,
		"kcat": float(blueprint.get("kcat", 0.0)),
		"km": float(blueprint.get("km", 0.0)),
		"delta": blueprint.get("resource_delta", {}),
		"status": "queued"
	}

func _apply_transporter_action(sim, action: Dictionary) -> Dictionary:
	var molecule_id := _select_molecule(sim, str(action.get("molecule", "")))
	if molecule_id.is_empty():
		return {"tool": "transporter", "status": "failed: missing molecule"}
	var direction := str(action.get("direction", "import"))
	var count := maxi(1, int(action.get("count", 1)))
	var id := "%s:%s" % [direction, molecule_id.md5_text()]
	if not sim.transporters.has(id):
		sim.transporters[id] = {
			"id": id,
			"direction": direction,
			"molecule": molecule_id,
			"count": 0,
			"rate_per_transporter": sim.TRANSPORTER_RATE_PER_SECOND,
			"visual_variant": 0
		}
	sim.transporters[id]["count"] = int(sim.transporters[id].get("count", 0)) + count
	return {
		"id": id,
		"tool": "%s transporter" % direction,
		"substrate": _molecule_label(sim, molecule_id),
		"target": -1,
		"count": count,
		"kcat": 0.0,
		"km": 0.0,
		"delta": {},
		"status": "active"
	}

func _empty_rate_tracker() -> Dictionary:
	var output := {}
	for resource_id in WATCHED_RESOURCES:
		output[resource_id] = {"production": 0.0, "consumption": 0.0, "net": 0.0}
	return output

func _track_peak_rates(sim, max_rates: Dictionary) -> void:
	for resource_id in WATCHED_RESOURCES:
		var rates: Dictionary = sim.resource_rates.get(resource_id, {})
		var production := float(rates.get("production", 0.0))
		var consumption := float(rates.get("consumption", 0.0))
		var net := production - consumption
		var entry: Dictionary = max_rates.get(resource_id, {"production": 0.0, "consumption": 0.0, "net": 0.0})
		entry["production"] = maxf(float(entry.get("production", 0.0)), production)
		entry["consumption"] = maxf(float(entry.get("consumption", 0.0)), consumption)
		entry["net"] = maxf(float(entry.get("net", 0.0)), absf(net))
		max_rates[resource_id] = entry

func _track_glucose_flux(sim, glucose_flux: Dictionary) -> void:
	var glucose_id := _select_molecule(sim, "glucose")
	if glucose_id.is_empty():
		return
	var rates: Dictionary = sim.molecule_rates.get(glucose_id, {})
	var outside_rates: Dictionary = sim.outside_rates.get(glucose_id, {})
	var import_rate := float(outside_rates.get("consumption", 0.0))
	var consumption := float(rates.get("consumption", 0.0))
	var net_accumulation := import_rate - consumption
	glucose_flux["import_peak"] = maxf(float(glucose_flux.get("import_peak", 0.0)), import_rate)
	glucose_flux["consumption_peak"] = maxf(float(glucose_flux.get("consumption_peak", 0.0)), consumption)
	glucose_flux["net_accumulation_peak"] = maxf(float(glucose_flux.get("net_accumulation_peak", 0.0)), net_accumulation)

func _annotate_balance_result(result: Dictionary) -> void:
	var final_resources: Dictionary = result.get("final_resources", {})
	var initial_resources: Dictionary = result.get("initial_resources", {})
	var max_rates: Dictionary = result.get("max_rates", {})
	var amino_peak := float(Dictionary(max_rates.get("Amino Acids", {})).get("production", 0.0))
	var nad_final := float(final_resources.get("NADH", 0.0))
	var n_final := float(final_resources.get("N", 0.0))
	var atp_final := float(final_resources.get("ATP", 0.0))
	var amino_net := float(final_resources.get("Amino Acids", 0.0)) - float(initial_resources.get("Amino Acids", 0.0))
	var avg_pathway_rate := _average_pathway_rate(result.get("pathways", []))
	var glucose_flux: Dictionary = result.get("glucose_flux", {})
	var import_rate := maxf(float(result.get("glucose_import_rate", 0.0)), 0.0001)
	var glucose_coverage := float(glucose_flux.get("consumption_peak", 0.0)) / import_rate
	var blockers: Array[String] = []
	if str(result.get("id", "")).begins_with("amino") and amino_peak <= 0.01:
		blockers.append("target-not-reached")
	if n_final <= 0.1:
		blockers.append("nitrogen-starved")
	if nad_final <= 1.0:
		blockers.append("nadh-depleted")
	if nad_final >= 60.0:
		blockers.append("nadh-overflow")
	if atp_final <= 8.0:
		blockers.append("atp-starved")
	if avg_pathway_rate < 1.0 and not result.get("designed", []).is_empty():
		blockers.append("enzyme-limited")
	if glucose_coverage < 0.35 and not result.get("designed", []).is_empty():
		blockers.append("import-underused")
	if amino_net < 0.0 and str(result.get("id", "")).begins_with("amino"):
		blockers.append("build-cost-not-repaid")
	var blocker := "none"
	var unlock := "Tune enzyme placement/counts after route is viable."
	if amino_peak <= 0.01 and str(result.get("id", "")).begins_with("amino"):
		blocker = "No amino acid sink flux; current generic reactions do not reach N-C-COOH in this tested path."
		unlock = "Add target-aware carbon-shortening or carboxyl/amination reactions, then rerun with nitrogen import."
	elif n_final <= 0.1:
		blocker = "Nitrogen depleted."
		unlock = "Unlock nitrate/ammonia import and nitrogen assimilation before amino-acid scaling."
	elif nad_final <= 1.0:
		blocker = "NADH depleted."
		unlock = "Unlock oxidative routes that generate NADH or reduce NADH-consuming steps."
	elif nad_final >= 60.0:
		blocker = "NADH accumulating."
		unlock = "Unlock fermentation-like reductase sinks or oxygen respiration to consume reducing power."
	elif atp_final <= 8.0:
		blocker = "ATP nearly depleted."
		unlock = "Unlock substrate-level phosphorylation or ATP-positive carbon-loss branch."
	elif avg_pathway_rate < 1.0 and not result.get("designed", []).is_empty():
		blocker = "Flux below 1/s target for a functioning enzyme set."
		unlock = "Increase kcat, lower Km, or require 2-4 enzyme copies for this step."
	elif amino_net < 0.0 and str(result.get("id", "")).begins_with("amino"):
		blocker = "Route spends amino acids on enzymes but does not repay the investment yet."
		unlock = "Gate this route behind a missing enzyme unlock or add a clearer first amino-acid product path."
	elif glucose_coverage < 0.35 and not result.get("designed", []).is_empty():
		blocker = "Starter import is underused; enzymes are not consuming enough of the glucose supply."
		unlock = "Increase active enzyme count, raise kcat, lower Km, or reduce starter import until the player expands metabolism."
	result["bottleneck"] = blocker
	result["blockers"] = blockers
	result["unlock"] = unlock
	result["score"] = _balance_score(result, amino_peak, avg_pathway_rate)
	result["verdict"] = _goal_verdict(result, amino_peak, avg_pathway_rate)

func _goal_verdict(result: Dictionary, amino_peak: float, avg_pathway_rate: float) -> String:
	var case_id := str(result.get("id", ""))
	if case_id.begins_with("amino"):
		if amino_peak > 0.05:
			return "PASS amino flux"
		return "FAIL no amino flux"
	if case_id == "import_only":
		return "BASELINE"
	if str(result.get("bottleneck", "")).contains("NADH accumulating"):
		return "PRESSURE redox"
	var glucose_flux: Dictionary = result.get("glucose_flux", {})
	var coverage := float(glucose_flux.get("consumption_peak", 0.0)) / maxf(float(result.get("glucose_import_rate", 0.0)), 0.0001)
	if coverage < 0.35 and not result.get("designed", []).is_empty():
		return "FAIL low coverage"
	if avg_pathway_rate >= 1.0:
		return "PASS visible flux"
	return "FAIL slow flux"

func _balance_score(result: Dictionary, amino_peak: float, avg_pathway_rate: float) -> float:
	var score := 0.0
	score += minf(avg_pathway_rate, 4.0) * 10.0
	score += minf(amino_peak, 4.0) * 12.0
	var final_resources: Dictionary = result.get("final_resources", {})
	if float(final_resources.get("ATP", 0.0)) > 10.0:
		score += 8.0
	if float(final_resources.get("NADH", 0.0)) >= 2.0 and float(final_resources.get("NADH", 0.0)) <= 50.0:
		score += 8.0
	if float(final_resources.get("N", 0.0)) > 1.0:
		score += 6.0
	return score

func _average_pathway_rate(pathways: Array) -> float:
	if pathways.is_empty():
		return 0.0
	var total := 0.0
	var active := 0
	for pathway in pathways:
		var rate := float(pathway.get("rate", 0.0))
		if rate > 0.0:
			total += rate
			active += 1
	return total / maxf(1.0, float(active))

func _print_balance_table(results: Array[Dictionary]) -> void:
	print("CASE SUMMARY")
	print("------------")
	print("%-22s %-16s %-23s %-21s %-18s %-32s %s" % ["Case", "Verdict", "Glucose flux", "Final resources", "Utilization", "Peak resource rates", "Blockers"])
	for result in results:
		print("%-22s %-16s %-23s %-21s %-18s %-32s %s" % [
			result.get("id", ""),
			result.get("verdict", ""),
			_compact_glucose_flux(result),
			_compact_resource_result(result),
			_compact_utilization(result.get("pathways", [])),
			_compact_peak_rates(result),
			_compact_blockers(result)
		])
	print("")
	print("DETAILS")
	print("-------")
	for result in results:
		print("%s: %s" % [result.get("name", ""), result.get("goal", "")])
		print("  Verdict: %s" % result.get("verdict", ""))
		print("  Designed: %s" % _designed_detail(result.get("designed", [])))
		print("  Pathways: %s" % _pathway_detail(result.get("pathways", [])))
		print("  Glucose import/consumption: %s" % _compact_glucose_flux(result))
		print("  Redox: %s" % _redox_detail(result))
		print("  Available unlocks at start: %s" % result.get("available_unlocks", "none"))
		print("  Ranked blockers: %s" % _compact_blockers(result))
		print("  Unlock/next design move: %s" % result.get("unlock", ""))

func _compact_glucose_flux(result: Dictionary) -> String:
	var flux: Dictionary = result.get("glucose_flux", {})
	var import_peak := float(flux.get("import_peak", result.get("glucose_import_rate", 0.0)))
	var consumption_peak := float(flux.get("consumption_peak", 0.0))
	var accumulation_peak := float(flux.get("net_accumulation_peak", 0.0))
	var ratio := consumption_peak / maxf(import_peak, 0.0001)
	return "in %.1f use %.1f +%.1f/s %.0f%%" % [import_peak, consumption_peak, accumulation_peak, ratio * 100.0]

func _compact_utilization(pathways: Array) -> String:
	if pathways.is_empty():
		return "none"
	var values: Array[String] = []
	for pathway in pathways:
		var active := int(pathway.get("active_count", 0))
		var kcat := float(pathway.get("kcat", 0.0))
		var theoretical := float(active) * kcat
		var actual := float(pathway.get("rate", 0.0))
		var utilization := actual / maxf(theoretical, 0.0001)
		values.append("%.0f%%" % (utilization * 100.0))
	return ", ".join(values)

func _compact_enzyme_summary(designed: Array) -> String:
	if designed.is_empty():
		return "none"
	var parts: Array[String] = []
	for item in designed:
		parts.append("%sx%d" % [str(item.get("tool", "?")).substr(0, 4), int(item.get("count", 0))])
	return ", ".join(parts)

func _compact_resource_result(result: Dictionary) -> String:
	var final_resources: Dictionary = result.get("final_resources", {})
	return "ATP %.0f NADH %.1f N %.1f AA %.0f" % [
		float(final_resources.get("ATP", 0.0)),
		float(final_resources.get("NADH", 0.0)),
		float(final_resources.get("N", 0.0)),
		float(final_resources.get("Amino Acids", 0.0))
	]

func _compact_peak_rates(result: Dictionary) -> String:
	var max_rates: Dictionary = result.get("max_rates", {})
	var aa := float(Dictionary(max_rates.get("Amino Acids", {})).get("production", 0.0))
	var nadh: Dictionary = max_rates.get("NADH", {})
	var nadh_prod := float(nadh.get("production", 0.0))
	var nadh_cons := float(nadh.get("consumption", 0.0))
	var atp_prod := float(Dictionary(max_rates.get("ATP", {})).get("production", 0.0))
	return "AA %.2f/s NADH +%.2f/-%.2f ATP %.2f/s" % [aa, nadh_prod, nadh_cons, atp_prod]

func _redox_detail(result: Dictionary) -> String:
	var max_rates: Dictionary = result.get("max_rates", {})
	var nadh: Dictionary = max_rates.get("NADH", {})
	var final_resources: Dictionary = result.get("final_resources", {})
	var final_nadh := float(final_resources.get("NADH", 0.0))
	return "peak production %.2f/s, peak consumption %.2f/s, final pool %.1f" % [
		float(nadh.get("production", 0.0)),
		float(nadh.get("consumption", 0.0)),
		final_nadh
	]

func _compact_blockers(result: Dictionary) -> String:
	var blockers: Array = result.get("blockers", [])
	if blockers.is_empty():
		return "none"
	var output: Array[String] = []
	for blocker in blockers:
		output.append(str(blocker))
	return ", ".join(output)

func _designed_detail(designed: Array) -> String:
	if designed.is_empty():
		return "none"
	var parts: Array[String] = []
	for item in designed:
		parts.append("%s x%d kcat %.2f Km %.1f delta %s" % [
			item.get("tool", "?"),
			int(item.get("count", 0)),
			float(item.get("kcat", 0.0)),
			float(item.get("km", 0.0)),
			_resource_delta_text(item.get("delta", {}))
		])
	return "; ".join(parts)

func _pathway_detail(pathways: Array) -> String:
	if pathways.is_empty():
		return "none"
	var parts: Array[String] = []
	for pathway in pathways:
		parts.append("%s active %d rate %.2f/s" % [
			pathway.get("name", "Enzyme"),
			int(pathway.get("active_count", 0)),
			float(pathway.get("rate", 0.0))
		])
	return "; ".join(parts)

func _unlock_report(sim) -> String:
	if not sim.has_method("dna_techs"):
		return "none"
	var affordable: Array[String] = []
	var available_locked: Array[String] = []
	var dna_points := float(sim.resources.get("DNA Points", 0.0))
	for tech in sim.dna_techs():
		var tech_id := str(tech.get("id", ""))
		if tech_id == "origin" or bool(sim.dna_tech_state(tech_id).get("unlocked", false)):
			continue
		if sim.dna_tech_available(tech_id):
			available_locked.append("%s %.0f DNA" % [tech.get("name", tech_id), float(tech.get("cost", 0.0))])
			if float(tech.get("cost", 0.0)) <= dna_points:
				affordable.append(str(tech.get("name", tech_id)))
	if affordable.is_empty() and available_locked.is_empty():
		return "none"
	if affordable.is_empty():
		return "available: %s" % "; ".join(available_locked)
	return "affordable now: %s" % ", ".join(affordable)

func _print_balance_interpretation(results: Array[Dictionary]) -> void:
	print("")
	print("GAMEPLAY INTERPRETATION")
	print("-----------------------")
	print("- Starter goal: make the first self-funding amino acid route. The current simulation shows glucose import and carbon cutting clearly, but the tested generic amino route does not yet reach the exact N-C-COOH target.")
	print("- Starting barrier: nitrogen is intentionally scarce. Aminase routes consume N, so nitrate/ammonia transport or assimilation is the first meaningful unlock if amino-acid production is the first goal.")
	print("- Redox barrier: dehydrogenase/desaturase create NADH; reductase/oxygenase consume it. Anaerobic progression should force the player to unlock a fermentation-style NADH sink before oxidation-heavy pathways can run continuously.")
	print("- Energy rule proposal: carbon oxidation and decarboxylation branches can create ATP, while ligation/phosphorylation/protein building consume ATP. This makes carbon loss a real tradeoff instead of a free bonus.")
	print("- Number target: with substrate pools above Km, 1 enzyme at kcat around 1.0/s gives about 0.6-1.0/s flux; 2-4 enzymes gives visible early-game throughput without needing dozens of copies.")
	print("- Parameter target: tier-1 enzymes should start around kcat 0.6-1.0/s and Km 18-30; improved enzymes can move toward kcat 1.2-1.8/s and Km 8-15. Bad enzymes below kcat 0.5 or above Km 40 are useful as teaching examples, not core progression.")

func _arg_value(name: String, default_value: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == name and i + 1 < args.size():
			return args[i + 1]
	return default_value

func _arg_flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)
