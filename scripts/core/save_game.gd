extends RefCounted
class_name SaveGame

const SAVE_PATH := "user://simcell_save.json"

static func save_state(sim) -> bool:
	var payload := {
		"time_seconds": sim.time_seconds,
		"generation": sim.generation,
		"resources": sim.resources,
		"outside": sim.outside,
		"transporters_owned": sim.transporters_owned,
		"enzymes_owned": sim.enzymes_owned,
		"proteins_owned": sim.proteins_owned,
		"tech_unlocked": sim.tech_unlocked,
		"protein_queue": sim.protein_queue,
		"reaction_queue": sim.reaction_queue,
		"research_points": sim.research_points,
		"toxicity": sim.toxicity,
		"hostility": sim.hostility,
		"starvation": sim.starvation
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true

static func load_state(sim) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	sim.time_seconds = float(parsed.get("time_seconds", 0.0))
	sim.generation = int(parsed.get("generation", 1))
	sim.resources = parsed.get("resources", sim.resources)
	sim.outside = parsed.get("outside", sim.outside)
	sim.transporters_owned = parsed.get("transporters_owned", sim.transporters_owned)
	sim.enzymes_owned = parsed.get("enzymes_owned", sim.enzymes_owned)
	sim.proteins_owned = parsed.get("proteins_owned", sim.proteins_owned)
	sim.tech_unlocked = parsed.get("tech_unlocked", sim.tech_unlocked)
	sim.protein_queue = parsed.get("protein_queue", [])
	sim.reaction_queue = parsed.get("reaction_queue", [])
	sim.research_points = float(parsed.get("research_points", 0.0))
	sim.toxicity = float(parsed.get("toxicity", 0.0))
	sim.hostility = float(parsed.get("hostility", 0.12))
	sim.starvation = float(parsed.get("starvation", 0.0))
	sim.emit_signal("event_logged", "Loaded saved culture.")
	sim.emit_signal("changed")
	return true
