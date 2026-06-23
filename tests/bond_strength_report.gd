extends SceneTree

const Graph := preload("res://scripts/core/molecule_graph.gd")
const SimulationStateScript := preload("res://scripts/core/simulation_state.gd")

func _init() -> void:
	var sim = SimulationStateScript.new()
	var glucose_id: String = sim.present_molecule_ids()[0]
	var graph: Dictionary = sim.molecule_types[glucose_id]
	print("\nSTARTING MOLECULE BOND STRENGTH REPORT")
	print("=======================================")
	var atoms: Array = graph.get("atoms", [])
	var bonds: Array = graph.get("bonds", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
			continue
		if atoms[a].get("element", "") != Graph.CARBON or atoms[b].get("element", "") != Graph.CARBON:
			continue
		print("  bond %d: C%d-C%d = %.1f%%" % [i, a, b, Graph.bond_strength(graph, i)])
	quit(0)
