extends RefCounted
class_name SaveGame

const SAVE_PATH := "user://simcell_save.json"

static func save_state(sim) -> bool:
	var payload := {
		"time_seconds": sim.time_seconds,
		"paused": sim.paused,
		"speed": sim.speed,
		"molecule_amounts": sim.molecule_amounts,
		"outside_amounts": sim.outside_amounts,
		"transporters": sim.transporters,
		"transporter_queue": sim.transporter_queue,
		"enzyme_blueprints": sim.enzyme_blueprints,
		"active_enzymes": sim.active_enzymes,
		"protein_queue": sim.protein_queue,
		"research_points": sim.research_points,
		"toxicity": sim.toxicity,
		"hostility": sim.hostility,
		"starvation": sim.starvation,
		"cell_size": sim.cell_size
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
	sim.paused = bool(parsed.get("paused", sim.paused))
	sim.speed = float(parsed.get("speed", sim.speed))
	sim.molecule_amounts = parsed.get("molecule_amounts", sim.molecule_amounts)
	sim.outside_amounts = parsed.get("outside_amounts", sim.outside_amounts)
	sim.transporters = parsed.get("transporters", sim.transporters)
	sim.transporter_queue = parsed.get("transporter_queue", [])
	sim.enzyme_blueprints = parsed.get("enzyme_blueprints", sim.enzyme_blueprints)
	sim.active_enzymes = parsed.get("active_enzymes", sim.active_enzymes)
	sim.protein_queue = parsed.get("protein_queue", [])
	sim.research_points = float(parsed.get("research_points", 0.0))
	sim.toxicity = float(parsed.get("toxicity", 0.0))
	sim.hostility = float(parsed.get("hostility", 0.12))
	sim.starvation = float(parsed.get("starvation", 0.0))
	sim.cell_size = float(parsed.get("cell_size", sim.cell_size))
	sim.emit_signal("event_logged", "Loaded saved culture.")
	sim.emit_signal("changed")
	return true
