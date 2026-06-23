extends RefCounted
class_name SimulationState

const Graph := preload("res://scripts/core/molecule_graph.gd")

signal changed
signal event_logged(message: String)

const METABOLISM_TICK := 0.25
const TRANSPORTER_RATE_PER_SECOND := 2.0
const TRANSPORTER_BUILD_TIME := 2.5
const STARTING_GLUCOSE_TRANSPORTERS := 4
const RESOURCE_AMINO_ACIDS := "Amino Acids"
const RESOURCE_ATP := "ATP"
const RESOURCE_NADH := "NADH"
const RESOURCE_NITROGEN := "N"
const RESOURCE_DNA_POINTS := "DNA Points"
const STARTING_AMINO_ACIDS := 40.0
const STARTING_ATP := 80.0
const STARTING_DNA_POINTS := 260.0
const ENZYME_BUILD_COST := {RESOURCE_AMINO_ACIDS: 2.0, RESOURCE_ATP: 1.0}
const TRANSPORTER_BUILD_COST := {RESOURCE_AMINO_ACIDS: 1.0, RESOURCE_ATP: 1.0}
const REDOX_BALANCE_LIMIT := 12.0
const STARTING_ENZYME_TOOLS := ["lyase", "dehydrogenase", "oxygenase", "reductase", "aminase", "nitrate_reductase"]

var time_seconds := 0.0
var paused := false
var speed := 1.0
var active_view := "metabolism"
var selected_molecule := ""
var selected_enzyme_tool := "dehydrogenase"
var tick_accumulator := 0.0

var molecule_types: Dictionary = {}
var molecule_amounts: Dictionary = {}
var molecule_rates: Dictionary = {}
var resources: Dictionary = {}
var resource_rates: Dictionary = {}
var outside_amounts: Dictionary = {}
var outside_rates: Dictionary = {}
var transporters: Dictionary = {}
var transporter_queue: Array[Dictionary] = []
var enzyme_blueprints: Dictionary = {}
var active_enzymes: Dictionary = {}
var protein_queue: Array[Dictionary] = []
var reactions: Array[Dictionary] = []
var experimental_all_enzyme_tools_unlocked := false
var research_points := 0.0
var dna_research: Dictionary = {}
var toxicity := 0.0
var hostility := 0.0
var starvation := 0.0
var cell_size := 1.0

func _init() -> void:
	reset()

func reset() -> void:
	time_seconds = 0.0
	paused = false
	speed = 1.0
	active_view = "metabolism"
	selected_enzyme_tool = "dehydrogenase"
	tick_accumulator = 0.0
	molecule_types = {}
	molecule_amounts = {}
	molecule_rates = {}
	resources = {
		RESOURCE_ATP: STARTING_ATP,
		RESOURCE_AMINO_ACIDS: STARTING_AMINO_ACIDS,
		RESOURCE_NADH: 0.0,
		RESOURCE_NITROGEN: 6.0,
		RESOURCE_DNA_POINTS: STARTING_DNA_POINTS
	}
	resource_rates = {}
	ensure_default_resources()
	outside_amounts = {}
	outside_rates = {}
	transporters = {}
	transporter_queue = []
	enzyme_blueprints = {}
	active_enzymes = {}
	protein_queue = []
	reactions = []
	experimental_all_enzyme_tools_unlocked = false
	research_points = 0.0
	dna_research = {}
	ensure_dna_research_defaults()
	toxicity = 0.0
	hostility = 0.0
	starvation = 0.0
	cell_size = 1.0
	var glucose := Graph.initial_glucose_like()
	var glucose_id: String = glucose["signature"]
	glucose["name"] = "Glucose"
	molecule_types[glucose_id] = glucose
	molecule_amounts[glucose_id] = 24.0
	molecule_rates[glucose_id] = {"production": 0.0, "consumption": 0.0}
	outside_amounts[glucose_id] = 10000.0
	outside_rates[glucose_id] = {"production": 0.0, "consumption": 0.0}
	var outside_sources := {
		"Formic Acid": 220.0,
		"Ethanol": 180.0,
		"Pyruvate": 140.0,
		"Hydrogen": 120.0,
		"Nitrate": 90.0,
		"Sulfate": 70.0
	}
	for source in Graph.outside_source_molecules():
		var source_id: String = source["signature"]
		molecule_types[source_id] = source
		outside_amounts[source_id] = float(outside_sources.get(source.get("name", ""), 100.0))
		outside_rates[source_id] = {"production": 0.0, "consumption": 0.0}
	transporters[_transporter_id("import", glucose_id)] = {
		"id": _transporter_id("import", glucose_id),
		"direction": "import",
		"molecule": glucose_id,
		"count": STARTING_GLUCOSE_TRANSPORTERS,
		"rate_per_transporter": TRANSPORTER_RATE_PER_SECOND,
		"visual_variant": 0
	}
	selected_molecule = ""
	emit_signal("event_logged", "New culture started with glucose importers at 8 molecules/s.")
	emit_signal("changed")

func ensure_default_resources() -> void:
	var defaults := {
		RESOURCE_ATP: STARTING_ATP,
		RESOURCE_AMINO_ACIDS: STARTING_AMINO_ACIDS,
		RESOURCE_NADH: 0.0,
		RESOURCE_NITROGEN: 6.0,
		RESOURCE_DNA_POINTS: STARTING_DNA_POINTS
	}
	for id in defaults.keys():
		if not resources.has(id):
			resources[id] = defaults[id]
		if not resource_rates.has(id):
			resource_rates[id] = {"production": 0.0, "consumption": 0.0}

func ensure_dna_research_defaults() -> void:
	if dna_research.is_empty():
		dna_research = {
			"origin": {"progress": 0.0, "unlocked": true}
		}

func dna_techs() -> Array[Dictionary]:
	return [
		{"id": "origin", "name": "Origin Genome", "cost": 0.0, "parents": [], "icon": "res://assets/dna_tree/icons/origin_genome.png", "pos": Vector2(0.0, 980.0)},
		{"id": "transporters", "name": "Transporter Design", "cost": 180.0, "parents": ["origin"], "icon": "res://assets/dna_tree/icons/transporters.png", "pos": Vector2(-430.0, 660.0)},
		{"id": "enzymes", "name": "Enzyme Classes", "cost": 200.0, "parents": ["origin"], "icon": "res://assets/dna_tree/icons/enzymes.png", "pos": Vector2(0.0, 610.0)},
		{"id": "proteins", "name": "Protein Synthesis", "cost": 180.0, "parents": ["origin"], "icon": "res://assets/dna_tree/icons/protein_synthesis.png", "pos": Vector2(430.0, 660.0)},
		{"id": "atp", "name": "ATP Economy", "cost": 220.0, "parents": ["enzymes"], "icon": "res://assets/dna_tree/icons/atp_economy.png", "pos": Vector2(-220.0, 290.0)},
		{"id": "redox", "name": "Redox Balance", "cost": 220.0, "parents": ["enzymes"], "icon": "res://assets/dna_tree/icons/redox_balance.png", "pos": Vector2(220.0, 290.0)},
		{"id": "membrane_stability", "name": "Membrane Stability", "cost": 240.0, "parents": ["transporters"], "icon": "res://assets/dna_tree/icons/membrane_stability.png", "pos": Vector2(-640.0, 260.0)},
		{"id": "dna_editing", "name": "DNA Editing", "cost": 260.0, "parents": ["proteins"], "icon": "res://assets/dna_tree/icons/dna_editing.png", "pos": Vector2(640.0, 260.0)},
		{"id": "metabolic_branching", "name": "Metabolic Branching", "cost": 300.0, "parents": ["atp", "redox"], "icon": "res://assets/dna_tree/icons/metabolic_branching.png", "pos": Vector2(0.0, -40.0)}
	]

func dna_tech_by_id(tech_id: String) -> Dictionary:
	for tech in dna_techs():
		if tech.get("id", "") == tech_id:
			return tech
	return {}

func dna_tech_state(tech_id: String) -> Dictionary:
	ensure_dna_research_defaults()
	return dna_research.get(tech_id, {"progress": 0.0, "unlocked": false})

func dna_tech_available(tech_id: String) -> bool:
	var tech := dna_tech_by_id(tech_id)
	if tech.is_empty():
		return false
	for parent_id in tech.get("parents", []):
		if not bool(dna_tech_state(str(parent_id)).get("unlocked", false)):
			return false
	return true

func invest_dna_research(tech_id: String, amount: float = 25.0) -> bool:
	var tech := dna_tech_by_id(tech_id)
	if tech.is_empty() or tech_id == "origin" or not dna_tech_available(tech_id):
		return false
	var state := dna_tech_state(tech_id)
	if bool(state.get("unlocked", false)):
		return false
	var cost := float(tech.get("cost", 0.0))
	var remaining := maxf(0.0, cost - float(state.get("progress", 0.0)))
	var spent := minf(minf(amount, remaining), float(resources.get(RESOURCE_DNA_POINTS, 0.0)))
	if spent <= 0.0:
		emit_signal("event_logged", "Not enough DNA points for research.")
		return false
	resources[RESOURCE_DNA_POINTS] = float(resources.get(RESOURCE_DNA_POINTS, 0.0)) - spent
	state["progress"] = float(state.get("progress", 0.0)) + spent
	if float(state["progress"]) >= cost:
		state["unlocked"] = true
		emit_signal("event_logged", "DNA technology unlocked: %s." % tech.get("name", tech_id))
	else:
		state["unlocked"] = false
	dna_research[tech_id] = state
	emit_signal("changed")
	return true

func target_molecule() -> Dictionary:
	return Graph.amino_acid_target()

func is_target_molecule_id(molecule_id: String) -> bool:
	return molecule_types.has(molecule_id) and is_target_molecule(molecule_types[molecule_id])

func is_target_molecule(graph: Dictionary) -> bool:
	var atoms: Array = graph.get("atoms", [])
	var counts := {Graph.CARBON: 0, Graph.OXYGEN: 0, Graph.NITROGEN: 0}
	for atom in atoms:
		var element := str(atom.get("element", ""))
		if counts.has(element):
			counts[element] = int(counts[element]) + 1
		elif not element.is_empty():
			return false
	if int(counts[Graph.CARBON]) != 2 or int(counts[Graph.OXYGEN]) != 2 or int(counts[Graph.NITROGEN]) != 1:
		return false
	for carbon_index in atoms.size():
		if atoms[carbon_index].get("element", "") != Graph.CARBON:
			continue
		var has_nitrogen := false
		var carboxyl_carbon := -1
		for neighbor in Graph._neighbors(graph, carbon_index):
			var neighbor_index := int(neighbor)
			var neighbor_element := str(atoms[neighbor_index].get("element", ""))
			if neighbor_element == Graph.NITROGEN:
				has_nitrogen = true
			elif neighbor_element == Graph.CARBON:
				carboxyl_carbon = neighbor_index
		if has_nitrogen and carboxyl_carbon >= 0 and Graph._oxygen_neighbor_count(graph, carboxyl_carbon) == 2:
			return true
	return false

func redox_balance() -> Dictionary:
	var rates: Dictionary = resource_rates.get(RESOURCE_NADH, {"production": 0.0, "consumption": 0.0})
	var production := float(rates.get("production", 0.0))
	var consumption := float(rates.get("consumption", 0.0))
	var balance := float(resources.get(RESOURCE_NADH, 0.0))
	return {
		"balance": balance,
		"limit": REDOX_BALANCE_LIMIT,
		"fraction": clampf((balance + REDOX_BALANCE_LIMIT) / (REDOX_BALANCE_LIMIT * 2.0), 0.0, 1.0),
		"production": production,
		"consumption": consumption,
		"net": production - consumption,
		"balanced": absf(balance) < REDOX_BALANCE_LIMIT * 0.18
	}

func tick(delta: float) -> void:
	if paused:
		return
	var dt := delta * speed
	time_seconds += dt
	_tick_transporter_queue(dt)
	tick_accumulator += dt
	_tick_protein_queue(dt)
	while tick_accumulator >= METABOLISM_TICK:
		_tick_metabolism(METABOLISM_TICK)
		tick_accumulator -= METABOLISM_TICK
	emit_signal("changed")

func toggle_pause() -> void:
	paused = not paused
	emit_signal("changed")

func set_speed(value: float) -> void:
	speed = clampf(value, 0.25, 4.0)
	emit_signal("changed")

func select_molecule(id: String) -> void:
	if not molecule_types.has(id):
		return
	selected_molecule = id
	emit_signal("changed")

func deselect_molecule() -> void:
	selected_molecule = ""
	emit_signal("changed")

func present_molecule_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in molecule_amounts.keys():
		if float(molecule_amounts.get(id, 0.0)) > 0.001:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return molecule_types[a].get("formula", "") < molecule_types[b].get("formula", "")
	)
	return ids

func outside_molecule_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in outside_amounts.keys():
		if molecule_types.has(id) and float(outside_amounts.get(id, 0.0)) > 0.001:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return molecule_types[a].get("formula", "") < molecule_types[b].get("formula", "")
	)
	return ids

func known_molecule_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in molecule_types.keys():
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return molecule_types[a].get("formula", "") < molecule_types[b].get("formula", "")
	)
	return ids

func transporter_list() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for id in transporters.keys():
		var transporter: Dictionary = transporters[id].duplicate(true)
		var count := int(transporter.get("count", 0))
		var queued_count := transporter_queued_count(str(transporter.get("direction", "")), str(transporter.get("molecule", "")))
		if count <= 0 and queued_count <= 0:
			continue
		transporter["rate"] = count * float(transporter.get("rate_per_transporter", TRANSPORTER_RATE_PER_SECOND))
		transporter["queued_count"] = queued_count
		transporter["next_build_remaining"] = transporter_next_build_remaining(str(transporter.get("direction", "")), str(transporter.get("molecule", "")))
		output.append(transporter)
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%s:%s" % [a.get("direction", ""), molecule_types.get(a.get("molecule", ""), {}).get("formula", "")]
		var b_key := "%s:%s" % [b.get("direction", ""), molecule_types.get(b.get("molecule", ""), {}).get("formula", "")]
		return a_key < b_key
	)
	return output

func transporter_count(direction: String, molecule_id: String) -> int:
	var id := _transporter_id(direction, molecule_id)
	return int(transporters.get(id, {}).get("count", 0))

func transporter_rate(direction: String, molecule_id: String) -> float:
	return transporter_count(direction, molecule_id) * TRANSPORTER_RATE_PER_SECOND

func transporter_queued_count(direction: String, molecule_id: String) -> int:
	var count := 0
	for item in transporter_queue:
		if item.get("direction", "") == direction and item.get("molecule", "") == molecule_id:
			count += 1
	return count

func transporter_next_build_remaining(direction: String, molecule_id: String) -> float:
	var remaining := INF
	for item in transporter_queue:
		if item.get("direction", "") == direction and item.get("molecule", "") == molecule_id:
			remaining = minf(remaining, float(item.get("remaining", 0.0)))
	return remaining if remaining < INF else 0.0

func build_transporter(direction: String, molecule_id: String) -> bool:
	if not molecule_types.has(molecule_id) or not ["import", "export"].has(direction):
		return false
	if direction == "import" and not outside_amounts.has(molecule_id):
		return false
	if not _spend_build_cost(TRANSPORTER_BUILD_COST):
		emit_signal("event_logged", "Not enough amino acids or ATP to build transporter.")
		return false
	var id := _transporter_id(direction, molecule_id)
	if not transporters.has(id):
		transporters[id] = {
			"id": id,
			"direction": direction,
			"molecule": molecule_id,
			"count": 0,
			"rate_per_transporter": TRANSPORTER_RATE_PER_SECOND,
			"visual_variant": randi() % 4
		}
	transporter_queue.append({
		"id": id,
		"direction": direction,
		"molecule": molecule_id,
		"remaining": TRANSPORTER_BUILD_TIME,
		"duration": TRANSPORTER_BUILD_TIME
	})
	emit_signal("event_logged", "Queued %s transporter for %s." % [direction, molecule_types[molecule_id].get("formula", "molecule")])
	emit_signal("changed")
	return true

func destroy_transporter(direction: String, molecule_id: String) -> bool:
	var id := _transporter_id(direction, molecule_id)
	if not transporters.has(id) or int(transporters[id].get("count", 0)) <= 0:
		return false
	transporters[id]["count"] = int(transporters[id].get("count", 0)) - 1
	emit_signal("event_logged", "Removed %s transporter for %s." % [direction, molecule_types[molecule_id].get("formula", "molecule")])
	emit_signal("changed")
	return true

func metabolism_molecule_ids() -> Array[String]:
	var ids: Array[String] = []
	var seen := {}
	var root_id := _glucose_id()
	if molecule_types.has(root_id):
		ids.append(root_id)
		seen[root_id] = true
	for blueprint in enzyme_blueprints.values():
		var substrate_id: String = blueprint.get("substrate", "")
		if molecule_types.has(substrate_id) and not seen.has(substrate_id):
			ids.append(substrate_id)
			seen[substrate_id] = true
		for product_id in blueprint.get("products", []):
			if molecule_types.has(product_id) and not seen.has(product_id):
				ids.append(product_id)
				seen[product_id] = true
	for id in present_molecule_ids():
		if molecule_types.has(id) and not seen.has(id):
			ids.append(id)
			seen[id] = true
	return ids

func pathway_list() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for blueprint_id in enzyme_blueprints.keys():
		var blueprint: Dictionary = enzyme_blueprints[blueprint_id].duplicate(true)
		var active_count := int(active_enzymes.get(blueprint_id, 0))
		var queued_count := 0
		var shortest_remaining := INF
		for item in protein_queue:
			if item.get("id", "") == blueprint_id:
				queued_count += 1
				shortest_remaining = minf(shortest_remaining, float(item.get("remaining", 0.0)))
		var rate := 0.0
		for reaction in reactions:
			if reaction.get("blueprint_id", "") == blueprint_id:
				rate = float(reaction.get("rate", 0.0))
				break
		blueprint["active_count"] = active_count
		blueprint["queued_count"] = queued_count
		blueprint["next_build_remaining"] = shortest_remaining if queued_count > 0 else 0.0
		blueprint["rate"] = rate
		blueprint["status"] = "Active" if active_count > 0 else ("Building" if queued_count > 0 else "Designed")
		output.append(blueprint)
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return output

func pathway_arrows() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for pathway in pathway_list():
		output.append({
			"blueprint_id": pathway.get("id", ""),
			"name": pathway.get("name", "Enzyme"),
			"tool": pathway.get("tool", ""),
			"substrate": pathway.get("substrate", ""),
			"products": pathway.get("products", []),
			"rate": float(pathway.get("rate", 0.0)),
			"active_count": int(pathway.get("active_count", 0)),
			"queued_count": int(pathway.get("queued_count", 0)),
			"status": pathway.get("status", "Designed"),
			"kcat": float(pathway.get("kcat", 0.0)),
			"km": float(pathway.get("km", 0.0)),
			"stability": float(pathway.get("stability", 0.0)),
			"resource_delta": pathway.get("resource_delta", {}),
			"bond_strength": float(pathway.get("bond_strength", -1.0))
		})
	return output

func enzyme_tools() -> Array[Dictionary]:
	return [
		{"id": "dehydrogenase", "label": "DEHYDROGENASE", "icon": "⇧", "summary": "C-O to C=O + NADH", "unlocked": true},
		{"id": "oxygenase", "label": "CARBOXYL OXIDASE", "icon": "O", "summary": "C=O to COOH + NADH", "unlocked": true},
		{"id": "reductase", "label": "REDUCTASE", "icon": "−", "summary": "C=O to C-O, spends NADH", "unlocked": true},
		{"id": "aminase", "label": "AMINATION", "icon": "N", "summary": "C=O to C-N, removes O", "unlocked": true},
		{"id": "nitrate_reductase", "label": "NITRATE REDUCTASE", "icon": "NO₃", "summary": "NO₃ to N pool, spends NADH", "unlocked": true},
		{"id": "lyase", "label": "LYASE", "icon": "✂", "summary": "Break C-C; ATP depends on bond strength", "unlocked": true},
		{"id": "desaturase", "label": "DESATURASE", "icon": "=", "summary": "C-C to C=C", "unlocked": false}
	]

func enzyme_tool_unlocked(tool: String) -> bool:
	if experimental_all_enzyme_tools_unlocked:
		return true
	return STARTING_ENZYME_TOOLS.has(tool)

func membrane_transport_arrows() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for transporter in transporter_list():
		var molecule_id: String = transporter.get("molecule", "")
		if not molecule_types.has(molecule_id):
			continue
		output.append({
			"direction": transporter.get("direction", ""),
			"molecule": molecule_id,
			"formula": molecule_types[molecule_id].get("formula", "Molecule"),
			"rate": float(transporter.get("rate", 0.0)),
			"count": int(transporter.get("count", 0)),
			"queued_count": int(transporter.get("queued_count", 0)),
			"visual_variant": int(transporter.get("visual_variant", 0))
		})
	return output

func product_preview_info(tool: String, substrate_id: String, target_index: int) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for product in preview_products(tool, substrate_id, target_index):
		output.append({
			"graph": product,
			"formula": product.get("formula", "Product"),
			"escapes": _escapes_as_carbon_dioxide(product)
		})
	return output

func enzyme_preview_summary(tool: String, substrate_id: String, target_index: int) -> Dictionary:
	if not molecule_types.has(substrate_id) or target_index < 0:
		return {}
	var substrate: Dictionary = molecule_types[substrate_id]
	var kept_products: Array[String] = []
	var gas_products := 0
	for product in product_preview_info(tool, substrate_id, target_index):
		if bool(product.get("escapes", false)):
			gas_products += 1
		else:
			kept_products.append(product.get("formula", "Product"))
	if kept_products.is_empty() and tool == "nitrate_reductase":
		kept_products.append("N pool")
	return {
		"name": _enzyme_name(tool, substrate),
		"kcat": _estimate_kcat(tool, substrate, target_index),
		"km": 18.0,
		"stability": 120.0,
		"equilibrium": _equilibrium_level(tool),
		"build_time": 3.0,
		"build_cost": ENZYME_BUILD_COST.duplicate(true),
		"resource_delta": _resource_delta(tool, substrate, target_index),
		"products": kept_products,
		"gas_products": gas_products,
		"bond_strength": Graph.bond_strength(substrate, target_index) if tool == "lyase" else -1.0
	}

func design_enzyme(tool: String, substrate_id: String, target_index: int) -> bool:
	if not enzyme_tool_unlocked(tool):
		emit_signal("event_logged", "%s is locked. Unlock this enzyme class in the DNA tree." % tool.capitalize())
		return false
	if not molecule_types.has(substrate_id):
		return false
	var substrate: Dictionary = molecule_types[substrate_id]
	var products := preview_products(tool, substrate_id, target_index)
	var resource_delta := _resource_delta(tool, substrate, target_index)
	var resource_only := _resource_only_tool(tool)
	if products.is_empty() and not resource_only:
		emit_signal("event_logged", "No valid product for enzyme design.")
		return false
	var product_ids: Array[String] = []
	for graph in products:
		if _escapes_as_carbon_dioxide(graph):
			emit_signal("event_logged", "One-carbon fragment escaped as CO2 gas.")
			continue
		var product_id := _register_molecule(graph)
		product_ids.append(product_id)
	if product_ids.is_empty() and not resource_only:
		emit_signal("event_logged", "Reaction product escaped the cell as gas.")
		return false
	var blueprint_id := "%s:%s:%d" % [tool, substrate_id.md5_text(), target_index]
	var blueprint := {
		"id": blueprint_id,
		"name": _enzyme_name(tool, substrate),
		"tool": tool,
		"substrate": substrate_id,
		"target_index": target_index,
		"products": product_ids,
		"resource_delta": resource_delta,
		"kcat": _estimate_kcat(tool, substrate, target_index),
		"km": 18.0,
		"stability": 120.0,
		"equilibrium": _equilibrium_level(tool),
		"build_time": 3.0,
		"build_cost": ENZYME_BUILD_COST.duplicate(true),
		"bond_strength": Graph.bond_strength(substrate, target_index) if tool == "lyase" else -1.0
	}
	enzyme_blueprints[blueprint_id] = blueprint
	if not _queue_protein_build(blueprint_id):
		emit_signal("event_logged", "Blueprint saved, but not enough amino acids or ATP to build enzyme.")
		emit_signal("changed")
		return true
	emit_signal("event_logged", "Blueprint queued: %s." % blueprint["name"])
	emit_signal("changed")
	return true

func queue_enzyme_build(blueprint_id: String, count: int = 1) -> bool:
	if not enzyme_blueprints.has(blueprint_id) or count <= 0:
		return false
	var queued := 0
	for i in count:
		if _queue_protein_build(blueprint_id):
			queued += 1
	if queued <= 0:
		emit_signal("event_logged", "Not enough amino acids or ATP to queue enzyme build.")
		emit_signal("changed")
		return false
	emit_signal("event_logged", "Queued %d enzyme build%s: %s." % [queued, "" if queued == 1 else "s", enzyme_blueprints[blueprint_id].get("name", "Enzyme")])
	emit_signal("changed")
	return true

func destroy_active_enzyme(blueprint_id: String) -> bool:
	var count := int(active_enzymes.get(blueprint_id, 0))
	if count <= 0:
		return false
	active_enzymes[blueprint_id] = count - 1
	if int(active_enzymes[blueprint_id]) <= 0:
		active_enzymes.erase(blueprint_id)
	emit_signal("event_logged", "Removed active enzyme: %s." % enzyme_blueprints.get(blueprint_id, {}).get("name", "Enzyme"))
	emit_signal("changed")
	return true

func preview_products(tool: String, substrate_id: String, target_index: int) -> Array[Dictionary]:
	if not molecule_types.has(substrate_id):
		return []
	var graph: Dictionary = molecule_types[substrate_id]
	if tool == "lyase":
		return Graph.apply_lyase(graph, target_index)
	if tool == "reductase":
		return Graph.apply_reductase(graph, target_index)
	if tool == "dehydrogenase":
		return Graph.apply_dehydrogenase(graph, target_index)
	if tool == "oxygenase":
		return Graph.apply_oxygenase(graph, target_index)
	if tool == "aminase":
		return Graph.apply_aminase(graph, target_index)
	if tool == "nitrate_reductase":
		return []
	if tool == "desaturase":
		return Graph.apply_desaturase(graph, target_index)
	return []

func valid_targets(tool: String, molecule_id: String) -> Array[int]:
	if not enzyme_tool_unlocked(tool):
		return []
	if not molecule_types.has(molecule_id):
		return []
	var graph: Dictionary = molecule_types[molecule_id]
	if tool == "lyase":
		return Graph.valid_lyase_targets(graph)
	if tool == "reductase":
		return Graph.valid_reductase_targets(graph)
	if tool == "dehydrogenase":
		return Graph.valid_dehydrogenase_targets(graph)
	if tool == "oxygenase":
		return Graph.valid_oxygenase_targets(graph)
	if tool == "aminase":
		return Graph.valid_aminase_targets(graph)
	if tool == "nitrate_reductase":
		return Graph.valid_nitrate_reductase_targets(graph)
	if tool == "desaturase":
		return Graph.valid_desaturase_targets(graph)
	return []

func reaction_list_for(substrate_id: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for blueprint_id in active_enzymes.keys():
		var blueprint: Dictionary = enzyme_blueprints.get(blueprint_id, {})
		if blueprint.get("substrate", "") == substrate_id:
			output.append(blueprint)
	return output

func pressure_label() -> String:
	var worst := maxf(starvation, maxf(toxicity, hostility))
	if worst > 0.72:
		return "Critical"
	if worst > 0.42:
		return "Pressured"
	return "Stable"

func _tick_metabolism(dt: float) -> void:
	for id in molecule_types.keys():
		molecule_rates[id] = {"production": 0.0, "consumption": 0.0}
	for id in outside_amounts.keys():
		outside_rates[id] = {"production": 0.0, "consumption": 0.0}
	for id in resources.keys():
		resource_rates[id] = {"production": 0.0, "consumption": 0.0}
	_apply_membrane_transport(dt)
	_tick_spontaneous_bond_breaks(dt)
	var previous_amounts := molecule_amounts.duplicate(true)

	var demand_by_substrate := {}
	var reaction_demands: Array[Dictionary] = []
	for blueprint_id in active_enzymes.keys():
		var count := int(active_enzymes.get(blueprint_id, 0))
		if count <= 0:
			continue
		var blueprint: Dictionary = enzyme_blueprints.get(blueprint_id, {})
		var substrate_id: String = blueprint.get("substrate", "")
		var substrate_amount := float(molecule_amounts.get(substrate_id, 0.0))
		var demand := count * float(blueprint.get("kcat", 1.0)) * substrate_amount / (float(blueprint.get("km", 1.0)) + substrate_amount)
		demand *= _equilibrium_factor(blueprint)
		reaction_demands.append({"blueprint": blueprint, "demand": demand})
		demand_by_substrate[substrate_id] = float(demand_by_substrate.get(substrate_id, 0.0)) + demand

	reactions = []
	for item in reaction_demands:
		var blueprint: Dictionary = item["blueprint"]
		var substrate_id: String = blueprint.get("substrate", "")
		var demand := float(item["demand"])
		var total_demand := float(demand_by_substrate.get(substrate_id, 0.0))
		var available_rate := float(previous_amounts.get(substrate_id, 0.0)) / dt
		var actual_rate := demand
		if total_demand > available_rate and total_demand > 0.0:
			actual_rate = available_rate * demand / total_demand
		actual_rate = _limit_rate_by_resources(blueprint, actual_rate, dt)
		var consumed := minf(actual_rate * dt, float(molecule_amounts.get(substrate_id, 0.0)))
		if consumed <= 0.0:
			actual_rate = 0.0
		else:
			molecule_amounts[substrate_id] = float(molecule_amounts.get(substrate_id, 0.0)) - consumed
			molecule_rates[substrate_id]["consumption"] = float(molecule_rates[substrate_id].get("consumption", 0.0)) + actual_rate
			_apply_resource_delta(blueprint, consumed, dt)
			var products: Array = blueprint.get("products", [])
			for product_id in products:
				molecule_amounts[product_id] = float(molecule_amounts.get(product_id, 0.0)) + consumed
				if not molecule_rates.has(product_id):
					molecule_rates[product_id] = {"production": 0.0, "consumption": 0.0}
				molecule_rates[product_id]["production"] = float(molecule_rates[product_id].get("production", 0.0)) + actual_rate
		reactions.append({
			"blueprint_id": blueprint.get("id", ""),
			"name": blueprint.get("name", "Enzyme"),
			"tool": blueprint.get("tool", ""),
			"substrate": substrate_id,
			"products": blueprint.get("products", []),
			"rate": actual_rate,
			"equilibrium_factor": _equilibrium_factor(blueprint)
		})
	_convert_target_molecules(dt)

func _tick_spontaneous_bond_breaks(dt: float) -> void:
	var candidates: Array[Dictionary] = []
	for molecule_id in molecule_types.keys():
		var amount := float(molecule_amounts.get(molecule_id, 0.0))
		if amount <= 0.001:
			continue
		var graph: Dictionary = molecule_types[molecule_id]
		for target_index in Graph.valid_lyase_targets(graph):
			var strength := Graph.bond_strength(graph, int(target_index))
			if strength >= 20.0:
				continue
			var rate := (20.0 - strength) / 20.0 * 0.22 * amount / (18.0 + amount)
			if rate <= 0.0:
				continue
			candidates.append({
				"molecule_id": molecule_id,
				"target_index": int(target_index),
				"rate": rate
			})
	for item in candidates:
		var molecule_id := str(item.get("molecule_id", ""))
		if not molecule_types.has(molecule_id):
			continue
		var consumed := minf(float(item.get("rate", 0.0)) * dt, float(molecule_amounts.get(molecule_id, 0.0)))
		if consumed <= 0.0:
			continue
		var products := Graph.apply_lyase(molecule_types[molecule_id], int(item.get("target_index", -1)))
		if products.is_empty():
			continue
		molecule_amounts[molecule_id] = float(molecule_amounts.get(molecule_id, 0.0)) - consumed
		molecule_rates[molecule_id]["consumption"] = float(molecule_rates[molecule_id].get("consumption", 0.0)) + consumed / maxf(dt, 0.0001)
		for graph in products:
			if _escapes_as_carbon_dioxide(graph):
				continue
			var product_id := _register_molecule(graph)
			molecule_amounts[product_id] = float(molecule_amounts.get(product_id, 0.0)) + consumed
			if not molecule_rates.has(product_id):
				molecule_rates[product_id] = {"production": 0.0, "consumption": 0.0}
			molecule_rates[product_id]["production"] = float(molecule_rates[product_id].get("production", 0.0)) + consumed / maxf(dt, 0.0001)

func _tick_protein_queue(dt: float) -> void:
	for i in range(protein_queue.size() - 1, -1, -1):
		var item := protein_queue[i]
		item["remaining"] = float(item["remaining"]) - dt
		if float(item["remaining"]) <= 0.0:
			var id: String = item.get("id", "")
			active_enzymes[id] = int(active_enzymes.get(id, 0)) + 1
			emit_signal("event_logged", "Enzyme built: %s." % item.get("name", id))
			protein_queue.remove_at(i)

func _queue_protein_build(blueprint_id: String) -> bool:
	if not enzyme_blueprints.has(blueprint_id):
		return false
	if not _spend_build_cost(ENZYME_BUILD_COST):
		return false
	var blueprint: Dictionary = enzyme_blueprints[blueprint_id]
	protein_queue.append({
		"id": blueprint_id,
		"name": blueprint.get("name", "Enzyme"),
		"remaining": float(blueprint.get("build_time", 3.0)),
		"duration": float(blueprint.get("build_time", 3.0))
	})
	return true

func _tick_transporter_queue(dt: float) -> void:
	for i in range(transporter_queue.size() - 1, -1, -1):
		var item := transporter_queue[i]
		item["remaining"] = float(item.get("remaining", 0.0)) - dt
		if float(item["remaining"]) <= 0.0:
			var id: String = item.get("id", "")
			if transporters.has(id):
				transporters[id]["count"] = int(transporters[id].get("count", 0)) + 1
				emit_signal("event_logged", "Transporter built: %s %s." % [item.get("direction", ""), molecule_types[item.get("molecule", "")].get("formula", "molecule")])
			transporter_queue.remove_at(i)

func _register_molecule(graph: Dictionary) -> String:
	var normalized := Graph.normalize(graph)
	var id: String = normalized["signature"]
	if not molecule_types.has(id):
		molecule_types[id] = normalized
		molecule_amounts[id] = 0.0
		molecule_rates[id] = {"production": 0.0, "consumption": 0.0}
		emit_signal("event_logged", "New molecule discovered: %s." % normalized.get("formula", "Molecule"))
	return id

func _apply_membrane_transport(dt: float) -> void:
	for transporter in transporter_list():
		var molecule_id: String = transporter.get("molecule", "")
		if not molecule_types.has(molecule_id):
			continue
		var direction: String = transporter.get("direction", "")
		var requested_rate := float(transporter.get("rate", 0.0))
		if direction == "import":
			var available := float(outside_amounts.get(molecule_id, 0.0))
			var moved := minf(requested_rate * dt, available)
			if moved <= 0.0:
				continue
			var actual_rate := moved / dt
			outside_amounts[molecule_id] = available - moved
			molecule_amounts[molecule_id] = float(molecule_amounts.get(molecule_id, 0.0)) + moved
			_ensure_rate_entries(molecule_id)
			molecule_rates[molecule_id]["production"] = float(molecule_rates[molecule_id].get("production", 0.0)) + actual_rate
			outside_rates[molecule_id]["consumption"] = float(outside_rates[molecule_id].get("consumption", 0.0)) + actual_rate
		elif direction == "export":
			var available_inside := float(molecule_amounts.get(molecule_id, 0.0))
			var exported := minf(requested_rate * dt, available_inside)
			if exported <= 0.0:
				continue
			var export_rate := exported / dt
			molecule_amounts[molecule_id] = available_inside - exported
			outside_amounts[molecule_id] = float(outside_amounts.get(molecule_id, 0.0)) + exported
			_ensure_rate_entries(molecule_id)
			molecule_rates[molecule_id]["consumption"] = float(molecule_rates[molecule_id].get("consumption", 0.0)) + export_rate
			outside_rates[molecule_id]["production"] = float(outside_rates[molecule_id].get("production", 0.0)) + export_rate

func _ensure_rate_entries(molecule_id: String) -> void:
	if not molecule_rates.has(molecule_id):
		molecule_rates[molecule_id] = {"production": 0.0, "consumption": 0.0}
	if not outside_rates.has(molecule_id):
		outside_rates[molecule_id] = {"production": 0.0, "consumption": 0.0}

func _limit_rate_by_resources(blueprint: Dictionary, requested_rate: float, dt: float) -> float:
	var limited := requested_rate
	var delta: Dictionary = blueprint.get("resource_delta", {})
	for resource_id in delta.keys():
		var per_reaction := float(delta[resource_id])
		if resource_id == RESOURCE_NADH:
			var balance := float(resources.get(RESOURCE_NADH, 0.0))
			var remaining_redox_capacity := REDOX_BALANCE_LIMIT - balance if per_reaction > 0.0 else REDOX_BALANCE_LIMIT + balance
			limited = minf(limited, maxf(0.0, remaining_redox_capacity) / maxf(dt * absf(per_reaction), 0.0001))
			continue
		if per_reaction >= 0.0:
			continue
		var available := float(resources.get(resource_id, 0.0))
		limited = minf(limited, available / maxf(dt * absf(per_reaction), 0.0001))
	return limited

func _equilibrium_factor(blueprint: Dictionary) -> float:
	var products: Array = blueprint.get("products", [])
	if products.is_empty():
		return 1.0
	var level := float(blueprint.get("equilibrium", 180.0))
	if level <= 0.0:
		return 1.0
	var highest_product := 0.0
	for product_id in products:
		highest_product = maxf(highest_product, float(molecule_amounts.get(product_id, 0.0)))
	var pressure := highest_product / level
	if pressure >= 1.0:
		return 0.0
	return clampf(1.0 - pressure, 0.0, 1.0)

func _apply_resource_delta(blueprint: Dictionary, reactions_done: float, dt: float) -> void:
	var delta: Dictionary = blueprint.get("resource_delta", {})
	for resource_id in delta.keys():
		var change := float(delta[resource_id]) * reactions_done
		if is_zero_approx(change):
			continue
		if resource_id == RESOURCE_NADH:
			resources[resource_id] = clampf(float(resources.get(resource_id, 0.0)) + change, -REDOX_BALANCE_LIMIT, REDOX_BALANCE_LIMIT)
		else:
			resources[resource_id] = maxf(0.0, float(resources.get(resource_id, 0.0)) + change)
		if not resource_rates.has(resource_id):
			resource_rates[resource_id] = {"production": 0.0, "consumption": 0.0}
		var rate := absf(change) / maxf(dt, 0.0001)
		if change >= 0.0:
			resource_rates[resource_id]["production"] = float(resource_rates[resource_id].get("production", 0.0)) + rate
		else:
			resource_rates[resource_id]["consumption"] = float(resource_rates[resource_id].get("consumption", 0.0)) + rate

func _convert_target_molecules(dt: float) -> void:
	for molecule_id in molecule_amounts.keys():
		var amount := float(molecule_amounts.get(molecule_id, 0.0))
		if amount <= 0.001 or not is_target_molecule_id(molecule_id):
			continue
		molecule_amounts[molecule_id] = 0.0
		ensure_default_resources()
		resources[RESOURCE_AMINO_ACIDS] = float(resources.get(RESOURCE_AMINO_ACIDS, 0.0)) + amount
		resource_rates[RESOURCE_AMINO_ACIDS]["production"] = float(resource_rates[RESOURCE_AMINO_ACIDS].get("production", 0.0)) + amount / maxf(dt, 0.0001)
		if not molecule_rates.has(molecule_id):
			molecule_rates[molecule_id] = {"production": 0.0, "consumption": 0.0}
		molecule_rates[molecule_id]["consumption"] = float(molecule_rates[molecule_id].get("consumption", 0.0)) + amount / maxf(dt, 0.0001)
		emit_signal("event_logged", "Amino acid target converted into %.0f amino acid resource." % amount)

func _spend_build_cost(cost: Dictionary) -> bool:
	ensure_default_resources()
	for resource_id in cost.keys():
		if float(resources.get(resource_id, 0.0)) < float(cost[resource_id]):
			return false
	for resource_id in cost.keys():
		var value := float(cost[resource_id])
		resources[resource_id] = float(resources.get(resource_id, 0.0)) - value
		if not resource_rates.has(resource_id):
			resource_rates[resource_id] = {"production": 0.0, "consumption": 0.0}
		resource_rates[resource_id]["consumption"] = float(resource_rates[resource_id].get("consumption", 0.0)) + value
	return true

func _escapes_as_carbon_dioxide(graph: Dictionary) -> bool:
	var carbon_count := 0
	for atom in graph.get("atoms", []):
		if atom.get("element", "") == Graph.CARBON:
			carbon_count += 1
	return carbon_count == 1

func _glucose_id() -> String:
	for id in molecule_types.keys():
		if molecule_types[id].get("name", "") == "Glucose":
			return id
	return selected_molecule

func _transporter_id(direction: String, molecule_id: String) -> String:
	return "%s:%s" % [direction, molecule_id.md5_text()]

func _enzyme_name(tool: String, substrate: Dictionary) -> String:
	var names := {
		"lyase": "Lyase",
		"reductase": "Reductase",
		"dehydrogenase": "Dehydrogenase",
		"oxygenase": "Oxygenase",
		"decarboxylase": "Decarboxylase",
		"aminase": "Amination Enzyme",
		"nitrate_reductase": "Nitrate Reductase",
		"desaturase": "Desaturase"
	}
	var enzyme_name: String = names.get(tool, "Enzyme")
	var roman := "I"
	var base := "%s %s %s" % [substrate.get("formula", "Molecule"), enzyme_name, roman]
	return base

func _estimate_kcat(tool: String, substrate: Dictionary, target_index: int) -> float:
	if tool == "lyase":
		var strength := Graph.bond_strength(substrate, target_index)
		return clampf(1.35 - strength / 120.0, 0.28, 1.0)
	if tool == "reductase":
		return 0.7
	if tool == "dehydrogenase":
		return 0.8
	if tool == "oxygenase":
		return 0.55
	if tool == "decarboxylase":
		return 0.45
	if tool == "aminase":
		return 0.5
	if tool == "nitrate_reductase":
		return 0.45
	if tool == "desaturase":
		return 0.65
	return 0.5

func _equilibrium_level(tool: String) -> float:
	if tool == "decarboxylase":
		return 999999.0
	if tool == "dehydrogenase":
		return 140.0
	if tool == "reductase":
		return 110.0
	if tool == "aminase":
		return 80.0
	if tool == "nitrate_reductase":
		return 999999.0
	return 160.0

func _resource_delta(tool: String, substrate: Dictionary = {}, target_index: int = -1) -> Dictionary:
	if tool == "lyase":
		if not substrate.is_empty() and target_index >= 0:
			var strength := Graph.bond_strength(substrate, target_index)
			if strength < 50.0:
				return {RESOURCE_ATP: 1.0}
			if strength < 70.0:
				return {}
		return {RESOURCE_ATP: -1.0}
	if tool == "reductase":
		return {RESOURCE_NADH: -1.0}
	if tool == "dehydrogenase":
		return {RESOURCE_NADH: 1.0}
	if tool == "oxygenase":
		return {RESOURCE_NADH: 1.0}
	if tool == "decarboxylase":
		return {RESOURCE_ATP: 1.0}
	if tool == "aminase":
		return {RESOURCE_NITROGEN: -1.0, RESOURCE_NADH: -1.0}
	if tool == "nitrate_reductase":
		return {RESOURCE_NADH: -2.0, RESOURCE_NITROGEN: 1.0}
	if tool == "desaturase":
		return {RESOURCE_NADH: 1.0}
	return {}

func _resource_only_tool(tool: String) -> bool:
	return tool == "nitrate_reductase"
