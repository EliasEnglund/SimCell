extends RefCounted
class_name SimulationState

const Graph := preload("res://scripts/core/molecule_graph.gd")

signal changed
signal event_logged(message: String)

const METABOLISM_TICK := 0.25
const GLUCOSE_IMPORT_PER_SECOND := 8.0

var time_seconds := 0.0
var paused := false
var speed := 1.0
var active_view := "metabolism"
var selected_molecule := ""
var selected_enzyme_tool := "lyase"
var tick_accumulator := 0.0

var molecule_types: Dictionary = {}
var molecule_amounts: Dictionary = {}
var molecule_rates: Dictionary = {}
var enzyme_blueprints: Dictionary = {}
var active_enzymes: Dictionary = {}
var protein_queue: Array[Dictionary] = []
var reactions: Array[Dictionary] = []
var research_points := 0.0
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
	selected_enzyme_tool = "lyase"
	tick_accumulator = 0.0
	molecule_types = {}
	molecule_amounts = {}
	molecule_rates = {}
	enzyme_blueprints = {}
	active_enzymes = {}
	protein_queue = []
	reactions = []
	research_points = 0.0
	toxicity = 0.0
	hostility = 0.0
	starvation = 0.0
	cell_size = 1.0
	var glucose := Graph.initial_glucose_like()
	var glucose_id: String = glucose["signature"]
	glucose["name"] = "Glucose"
	molecule_types[glucose_id] = glucose
	molecule_amounts[glucose_id] = 24.0
	molecule_rates[glucose_id] = {"production": GLUCOSE_IMPORT_PER_SECOND, "consumption": 0.0}
	selected_molecule = ""
	emit_signal("event_logged", "New culture started with glucose import at 8 molecules/s.")
	emit_signal("changed")

func tick(delta: float) -> void:
	if paused:
		return
	var dt := delta * speed
	time_seconds += dt
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

func metabolism_molecule_ids() -> Array[String]:
	var ids := present_molecule_ids()
	var seen := {}
	for id in ids:
		seen[id] = true
	for blueprint in enzyme_blueprints.values():
		var substrate_id: String = blueprint.get("substrate", "")
		if molecule_types.has(substrate_id) and not seen.has(substrate_id):
			ids.append(substrate_id)
			seen[substrate_id] = true
		for product_id in blueprint.get("products", []):
			if molecule_types.has(product_id) and not seen.has(product_id):
				ids.append(product_id)
				seen[product_id] = true
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
			"status": pathway.get("status", "Designed")
		})
	return output

func design_enzyme(tool: String, substrate_id: String, target_index: int) -> bool:
	if not molecule_types.has(substrate_id):
		return false
	var substrate: Dictionary = molecule_types[substrate_id]
	var products := preview_products(tool, substrate_id, target_index)
	if products.is_empty():
		emit_signal("event_logged", "No valid product for enzyme design.")
		return false
	var product_ids: Array[String] = []
	for graph in products:
		if _escapes_as_carbon_dioxide(graph):
			emit_signal("event_logged", "One-carbon fragment escaped as CO2 gas.")
			continue
		var product_id := _register_molecule(graph)
		product_ids.append(product_id)
	if product_ids.is_empty():
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
		"kcat": _estimate_kcat(tool, substrate, target_index),
		"km": 18.0,
		"stability": 120.0,
		"build_time": 3.0
	}
	enzyme_blueprints[blueprint_id] = blueprint
	protein_queue.append({
		"id": blueprint_id,
		"name": blueprint["name"],
		"remaining": blueprint["build_time"],
		"duration": blueprint["build_time"]
	})
	emit_signal("event_logged", "Blueprint queued: %s." % blueprint["name"])
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
	return []

func valid_targets(tool: String, molecule_id: String) -> Array[int]:
	if not molecule_types.has(molecule_id):
		return []
	var graph: Dictionary = molecule_types[molecule_id]
	if tool == "lyase":
		return Graph.valid_lyase_targets(graph)
	if tool == "reductase":
		return Graph.valid_reductase_targets(graph)
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
	var previous_amounts := molecule_amounts.duplicate(true)
	for id in molecule_types.keys():
		molecule_rates[id] = {"production": 0.0, "consumption": 0.0}
	var glucose_id := _glucose_id()
	molecule_amounts[glucose_id] = float(molecule_amounts.get(glucose_id, 0.0)) + GLUCOSE_IMPORT_PER_SECOND * dt
	molecule_rates[glucose_id]["production"] = GLUCOSE_IMPORT_PER_SECOND

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
		var consumed := minf(actual_rate * dt, float(molecule_amounts.get(substrate_id, 0.0)))
		if consumed <= 0.0:
			actual_rate = 0.0
		else:
			molecule_amounts[substrate_id] = float(molecule_amounts.get(substrate_id, 0.0)) - consumed
			molecule_rates[substrate_id]["consumption"] = float(molecule_rates[substrate_id].get("consumption", 0.0)) + actual_rate
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
			"rate": actual_rate
		})

func _tick_protein_queue(dt: float) -> void:
	for i in range(protein_queue.size() - 1, -1, -1):
		var item := protein_queue[i]
		item["remaining"] = float(item["remaining"]) - dt
		if float(item["remaining"]) <= 0.0:
			var id: String = item.get("id", "")
			active_enzymes[id] = int(active_enzymes.get(id, 0)) + 1
			emit_signal("event_logged", "Enzyme built: %s." % item.get("name", id))
			protein_queue.remove_at(i)

func _register_molecule(graph: Dictionary) -> String:
	var normalized := Graph.normalize(graph)
	var id: String = normalized["signature"]
	if not molecule_types.has(id):
		molecule_types[id] = normalized
		molecule_amounts[id] = 0.0
		molecule_rates[id] = {"production": 0.0, "consumption": 0.0}
		emit_signal("event_logged", "New molecule discovered: %s." % normalized.get("formula", "Molecule"))
	return id

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

func _enzyme_name(tool: String, substrate: Dictionary) -> String:
	var enzyme_name := "Lyase" if tool == "lyase" else "Reductase"
	var roman := "I"
	var base := "%s %s %s" % [substrate.get("formula", "Molecule"), enzyme_name, roman]
	return base

func _estimate_kcat(tool: String, substrate: Dictionary, target_index: int) -> float:
	if tool == "lyase":
		return 1.0
	if tool == "reductase":
		return 0.7
	return 0.5
