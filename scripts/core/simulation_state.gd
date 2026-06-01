extends RefCounted
class_name SimulationState

const Catalog := preload("res://scripts/core/data_catalog.gd")

signal changed
signal event_logged(message: String)

var time_seconds := 0.0
var paused := false
var speed := 1.0
var generation := 1
var toxicity := 0.0
var hostility := 0.12
var starvation := 0.0
var selected_molecule := "glucose"

var resources: Dictionary = {}
var outside: Dictionary = {}
var transporters_owned: Dictionary = {}
var enzymes_owned: Dictionary = {}
var proteins_owned: Dictionary = {}
var tech_unlocked: Dictionary = {}
var protein_queue: Array[Dictionary] = []
var reaction_queue: Array[Dictionary] = []
var research_points := 0.0
var cell_size := 1.0

func _init() -> void:
	reset()

func reset() -> void:
	time_seconds = 0.0
	paused = false
	speed = 1.0
	generation = 1
	toxicity = 0.0
	hostility = 0.12
	starvation = 0.0
	selected_molecule = "glucose"
	resources = {
		"glucose": 8.0,
		"oxygen_group": 3.0,
		"nitrogen_group": 1.0,
		"phosphate": 2.0,
		"sulfur": 0.0,
		"atp": 18.0,
		"electrons": 4.0,
		"amino_acids": 28.0,
		"dna_parts": 0.0,
		"rna_parts": 2.0,
		"lipids": 5.0
	}
	outside = {
		"glucose": 120.0,
		"oxygen_group": 22.0,
		"nitrogen_group": 18.0,
		"phosphate": 14.0,
		"sulfur": 5.0
	}
	transporters_owned = {"glucose_channel": 1}
	enzymes_owned = {}
	proteins_owned = {"ribosome": 1}
	tech_unlocked = {}
	protein_queue = []
	reaction_queue = []
	research_points = 0.0
	cell_size = 1.0
	emit_signal("event_logged", "New culture started.")
	emit_signal("changed")

func tick(delta: float) -> void:
	if paused:
		return
	var dt := delta * speed
	time_seconds += dt
	_tick_transport(dt)
	_tick_reactions(dt)
	_tick_protein_queue(dt)
	_tick_pressure(dt)
	emit_signal("changed")

func toggle_pause() -> void:
	paused = not paused
	emit_signal("changed")

func set_speed(value: float) -> void:
	speed = clampf(value, 0.25, 4.0)
	emit_signal("changed")

func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if resources.get(key, 0.0) + 0.001 < float(cost[key]):
			return false
	return true

func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for key in cost:
		resources[key] = resources.get(key, 0.0) - float(cost[key])
	return true

func add_resources(output: Dictionary) -> void:
	for key in output:
		resources[key] = resources.get(key, 0.0) + float(output[key])

func select_molecule(id: String) -> void:
	if not Catalog.molecules().has(id):
		return
	selected_molecule = id
	emit_signal("changed")

func reaction_options_for(molecule_id: String) -> Array[String]:
	var options: Array[String] = []
	for id in Catalog.enzyme_actions().keys():
		var data: Dictionary = Catalog.enzyme_actions()[id]
		var input: Dictionary = data.get("input", {})
		if input.has(molecule_id):
			options.append(id)
	return options

func reaction_preview(id: String) -> Dictionary:
	var data: Dictionary = Catalog.enzyme_actions().get(id, {})
	if data.is_empty():
		return {}
	var owned := int(enzymes_owned.get(id, 0)) > 0
	var input: Dictionary = data.get("input", {})
	var design_cost: Dictionary = data.get("protein_cost", {})
	var missing_input := missing_resources(input)
	var missing_design := missing_resources(design_cost)
	return {
		"id": id,
		"name": data.get("name", id),
		"description": data.get("description", ""),
		"owned": owned,
		"input": input,
		"output": data.get("output", {}),
		"design_cost": design_cost,
		"duration": float(data.get("duration", 0.0)),
		"missing_input": missing_input,
		"missing_design": missing_design,
		"can_design": owned or missing_design.is_empty(),
		"can_run": owned and missing_input.is_empty(),
		"can_design_and_run": (owned or missing_design.is_empty()) and missing_input.is_empty()
	}

func missing_resources(cost: Dictionary) -> Dictionary:
	var missing := {}
	for key in cost:
		var needed := float(cost[key])
		var available := float(resources.get(key, 0.0))
		if available + 0.001 < needed:
			missing[key] = needed - available
	return missing

func build_transporter(id: String) -> bool:
	var data: Dictionary = Catalog.transporters().get(id, {})
	if data.is_empty():
		return false
	if not pay(data.get("build_cost", {})):
		emit_signal("event_logged", "Not enough resources for %s." % data.get("name", id))
		return false
	transporters_owned[id] = int(transporters_owned.get(id, 0)) + 1
	emit_signal("event_logged", "Built transporter: %s." % data.get("name", id))
	emit_signal("changed")
	return true

func design_enzyme(id: String) -> bool:
	var data: Dictionary = Catalog.enzyme_actions().get(id, {})
	if data.is_empty():
		return false
	if enzymes_owned.get(id, 0) > 0:
		queue_reaction(id)
		return true
	var cost: Dictionary = data.get("protein_cost", {})
	if not pay(cost):
		emit_signal("event_logged", "Not enough resources to design %s." % data.get("name", id))
		return false
	enzymes_owned[id] = 1
	emit_signal("event_logged", "Designed enzyme: %s." % data.get("name", id))
	queue_reaction(id)
	emit_signal("changed")
	return true

func queue_reaction(id: String) -> bool:
	var data: Dictionary = Catalog.enzyme_actions().get(id, {})
	if data.is_empty():
		return false
	if enzymes_owned.get(id, 0) <= 0:
		return design_enzyme(id)
	if not can_afford(data.get("input", {})):
		emit_signal("event_logged", "Missing substrates for %s." % data.get("name", id))
		return false
	pay(data.get("input", {}))
	reaction_queue.append({
		"id": id,
		"name": data.get("name", id),
		"remaining": float(data.get("duration", 4.0)),
		"duration": float(data.get("duration", 4.0)),
		"output": data.get("output", {})
	})
	emit_signal("event_logged", "Queued reaction: %s." % data.get("name", id))
	emit_signal("changed")
	return true

func queue_protein(id: String) -> bool:
	var data: Dictionary = Catalog.proteins().get(id, {})
	if data.is_empty():
		return false
	if not pay(data.get("build_cost", {})):
		emit_signal("event_logged", "Not enough resources for %s." % data.get("name", id))
		return false
	protein_queue.append({
		"id": id,
		"name": data.get("name", id),
		"remaining": float(data.get("duration", 8.0)),
		"duration": float(data.get("duration", 8.0))
	})
	emit_signal("event_logged", "Queued protein: %s." % data.get("name", id))
	emit_signal("changed")
	return true

func research_tech(id: String) -> bool:
	var data: Dictionary = Catalog.techs().get(id, {})
	if data.is_empty() or tech_unlocked.get(id, false):
		return false
	var cost := float(data.get("cost", 0.0))
	if research_points + 0.001 < cost:
		emit_signal("event_logged", "Need more DNA research for %s." % data.get("name", id))
		return false
	research_points -= cost
	tech_unlocked[id] = true
	emit_signal("event_logged", "Unlocked tech: %s." % data.get("name", id))
	emit_signal("changed")
	return true

func _tick_transport(dt: float) -> void:
	var catalog: Dictionary = Catalog.transporters()
	for id in transporters_owned:
		var count := int(transporters_owned[id])
		var data: Dictionary = catalog.get(id, {})
		var molecule: String = data.get("molecule", "")
		if molecule == "" or outside.get(molecule, 0.0) <= 0.0:
			continue
		var amount: float = minf(float(data.get("rate", 0.0)) * count * dt, float(outside.get(molecule, 0.0)))
		var atp_cost: float = amount * float(data.get("atp_cost_per_unit", 0.0))
		if atp_cost > 0.0 and resources.get("atp", 0.0) < atp_cost:
			continue
		outside[molecule] -= amount
		resources[molecule] = resources.get(molecule, 0.0) + amount
		resources["atp"] = resources.get("atp", 0.0) - atp_cost

func _tick_reactions(dt: float) -> void:
	for i in range(reaction_queue.size() - 1, -1, -1):
		var item := reaction_queue[i]
		item["remaining"] = float(item["remaining"]) - dt
		if float(item["remaining"]) <= 0.0:
			add_resources(item.get("output", {}))
			reaction_queue.remove_at(i)
			emit_signal("event_logged", "Reaction complete: %s." % item.get("name", "Reaction"))

func _tick_protein_queue(dt: float) -> void:
	var ribosomes: int = maxi(1, int(proteins_owned.get("ribosome", 1)))
	var active_lanes: int = mini(ribosomes, protein_queue.size())
	for i in range(active_lanes - 1, -1, -1):
		var item := protein_queue[i]
		item["remaining"] = float(item["remaining"]) - dt
		if float(item["remaining"]) <= 0.0:
			var id: String = item.get("id", "")
			proteins_owned[id] = int(proteins_owned.get(id, 0)) + 1
			if id == "ribosome":
				resources["rna_parts"] = resources.get("rna_parts", 0.0) + 0.5
			emit_signal("event_logged", "Protein complete: %s." % item.get("name", id))
			protein_queue.remove_at(i)

func _tick_pressure(dt: float) -> void:
	resources["atp"] = resources.get("atp", 0.0) - (0.08 + cell_size * 0.025) * dt
	if resources.get("atp", 0.0) <= 0.0:
		resources["atp"] = 0.0
		starvation = min(1.0, starvation + 0.035 * dt)
	else:
		starvation = max(0.0, starvation - 0.02 * dt)
	toxicity = clampf(toxicity + max(0.0, resources.get("sulfur", 0.0) - 8.0) * 0.001 * dt - int(proteins_owned.get("detox_pump", 0)) * 0.008 * dt, 0.0, 1.0)
	hostility = clampf(hostility + 0.0015 * dt - int(tech_unlocked.get("chemotaxis", false)) * 0.0007 * dt, 0.0, 1.0)
	cell_size = 1.0 + resources.get("lipids", 0.0) * 0.018
	if resources.get("dna_parts", 0.0) >= 1.0:
		var converted = floorf(resources["dna_parts"])
		resources["dna_parts"] -= converted
		research_points += converted

func pressure_label() -> String:
	var worst: float = maxf(starvation, maxf(toxicity, hostility))
	if worst > 0.72:
		return "Critical"
	if worst > 0.42:
		return "Pressured"
	return "Stable"
