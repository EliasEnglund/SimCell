extends RefCounted
class_name MoleculeGraph

const CARBON := "C"
const OXYGEN := "O"

static func initial_glucose_like() -> Dictionary:
	var atoms: Array[Dictionary] = []
	var bonds: Array[Dictionary] = []
	var carbon_positions := [
		Vector2(-230.0, 28.0),
		Vector2(-150.0, -26.0),
		Vector2(-68.0, 26.0),
		Vector2(18.0, -24.0),
		Vector2(104.0, 24.0),
		Vector2(190.0, -20.0)
	]
	var oxygen_offsets := [
		Vector2(-84.0, 66.0),
		Vector2(0.0, -86.0),
		Vector2(0.0, 82.0),
		Vector2(0.0, -82.0),
		Vector2(0.0, 82.0),
		Vector2(78.0, -46.0)
	]
	for i in 6:
		atoms.append({
			"element": CARBON,
			"pos": carbon_positions[i]
		})
		atoms.append({
			"element": OXYGEN,
			"pos": carbon_positions[i] + oxygen_offsets[i]
		})
	for i in 5:
		bonds.append({"a": i * 2, "b": (i + 1) * 2, "order": 1})
	for i in 6:
		bonds.append({"a": i * 2, "b": i * 2 + 1, "order": 2 if i == 5 else 1})
	return normalize({"name": "Glucose", "atoms": atoms, "bonds": bonds})

static func demo_molecules() -> Array[Dictionary]:
	return [
		_demo_nitrogen_fragment(),
		_demo_phosphate_fragment(),
		_demo_sulfur_fragment()
	]

static func _demo_nitrogen_fragment() -> Dictionary:
	return normalize({
		"name": "Amino Fragment",
		"atoms": [
			{"element": CARBON, "pos": Vector2(-82.0, 16.0)},
			{"element": CARBON, "pos": Vector2(0.0, -24.0)},
			{"element": CARBON, "pos": Vector2(84.0, 16.0)},
			{"element": OXYGEN, "pos": Vector2(0.0, -104.0)},
			{"element": "N", "pos": Vector2(154.0, -44.0)}
		],
		"bonds": [
			{"a": 0, "b": 1, "order": 1},
			{"a": 1, "b": 2, "order": 1},
			{"a": 1, "b": 3, "order": 2},
			{"a": 2, "b": 4, "order": 1}
		]
	})

static func _demo_phosphate_fragment() -> Dictionary:
	return normalize({
		"name": "Phosphorylated Fragment",
		"atoms": [
			{"element": CARBON, "pos": Vector2(-70.0, 22.0)},
			{"element": CARBON, "pos": Vector2(18.0, -18.0)},
			{"element": OXYGEN, "pos": Vector2(102.0, -60.0)},
			{"element": "P", "pos": Vector2(186.0, -14.0)},
			{"element": OXYGEN, "pos": Vector2(258.0, -78.0)}
		],
		"bonds": [
			{"a": 0, "b": 1, "order": 1},
			{"a": 1, "b": 2, "order": 1},
			{"a": 2, "b": 3, "order": 1},
			{"a": 3, "b": 4, "order": 2}
		]
	})

static func _demo_sulfur_fragment() -> Dictionary:
	return normalize({
		"name": "Sulfur Fragment",
		"atoms": [
			{"element": CARBON, "pos": Vector2(-80.0, 18.0)},
			{"element": CARBON, "pos": Vector2(0.0, -24.0)},
			{"element": CARBON, "pos": Vector2(82.0, 16.0)},
			{"element": "S", "pos": Vector2(154.0, 74.0)}
		],
		"bonds": [
			{"a": 0, "b": 1, "order": 1},
			{"a": 1, "b": 2, "order": 1},
			{"a": 2, "b": 3, "order": 1}
		]
	})

static func clone(graph: Dictionary) -> Dictionary:
	var atoms: Array[Dictionary] = []
	var bonds: Array[Dictionary] = []
	for atom in graph.get("atoms", []):
		atoms.append({
			"element": atom.get("element", CARBON),
			"pos": atom.get("pos", Vector2.ZERO)
		})
	for bond in graph.get("bonds", []):
		bonds.append({
			"a": int(bond.get("a", 0)),
			"b": int(bond.get("b", 0)),
			"order": int(bond.get("order", 1))
		})
	return normalize({
		"name": graph.get("name", ""),
		"atoms": atoms,
		"bonds": bonds
	})

static func normalize(graph: Dictionary) -> Dictionary:
	graph["formula"] = formula(graph)
	graph["signature"] = signature(graph)
	if str(graph.get("name", "")).is_empty():
		graph["name"] = graph["formula"]
	return graph

static func formula(graph: Dictionary) -> String:
	var counts := {}
	for atom in graph.get("atoms", []):
		var element: String = atom.get("element", "")
		counts[element] = int(counts.get(element, 0)) + 1
	var order := [CARBON, OXYGEN, "N", "P", "S"]
	var parts: Array[String] = []
	for element in order:
		var count := int(counts.get(element, 0))
		if count > 0:
			parts.append("%s%s" % [element, _subscript(count)])
	for element in counts.keys():
		if not order.has(element):
			parts.append("%s%s" % [element, _subscript(int(counts[element]))])
	return "".join(parts)

static func signature(graph: Dictionary) -> String:
	var atoms: Array = graph.get("atoms", [])
	var atom_parts: Array[String] = []
	for i in atoms.size():
		atom_parts.append("%d:%s" % [i, atoms[i].get("element", "")])
	var bond_parts: Array[String] = []
	for bond in graph.get("bonds", []):
		var a := int(bond.get("a", 0))
		var b := int(bond.get("b", 0))
		var low = mini(a, b)
		var high = maxi(a, b)
		bond_parts.append("%d-%d:%d" % [low, high, int(bond.get("order", 1))])
	bond_parts.sort()
	return "%s|%s" % [",".join(atom_parts), ",".join(bond_parts)]

static func valid_lyase_targets(graph: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a >= 0 and b >= 0 and atoms[a].get("element") == CARBON and atoms[b].get("element") == CARBON:
			targets.append(i)
	return targets

static func valid_reductase_targets(graph: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		var e1: String = atoms[a].get("element", "")
		var e2: String = atoms[b].get("element", "")
		if (e1 == CARBON and e2 == OXYGEN) or (e1 == OXYGEN and e2 == CARBON):
			targets.append(i)
	return targets

static func apply_reductase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	var product := clone(graph)
	var bonds: Array = product.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	var order := int(bonds[bond_index].get("order", 1))
	bonds[bond_index]["order"] = 1 if order > 1 else 2
	product["bonds"] = bonds
	product["name"] = product.get("formula", "Molecule")
	return [normalize(product)]

static func apply_lyase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	var source := clone(graph)
	var bonds: Array = source.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	bonds.remove_at(bond_index)
	source["bonds"] = bonds
	return _connected_components(source)

static func _connected_components(graph: Dictionary) -> Array[Dictionary]:
	var atoms: Array = graph.get("atoms", [])
	var bonds: Array = graph.get("bonds", [])
	var adjacency: Array[Array] = []
	for i in atoms.size():
		adjacency.append([])
	for bond in bonds:
		var a := int(bond.get("a", 0))
		var b := int(bond.get("b", 0))
		adjacency[a].append(b)
		adjacency[b].append(a)
	var seen := {}
	var products: Array[Dictionary] = []
	for start in atoms.size():
		if seen.has(start):
			continue
		var stack := [start]
		var component: Array[int] = []
		seen[start] = true
		while not stack.is_empty():
			var current: int = stack.pop_back()
			component.append(current)
			for next in adjacency[current]:
				if not seen.has(next):
					seen[next] = true
					stack.append(next)
		products.append(_subgraph(graph, component))
	return products

static func _subgraph(graph: Dictionary, component: Array[int]) -> Dictionary:
	var index_map := {}
	var atoms: Array[Dictionary] = []
	var source_atoms: Array = graph.get("atoms", [])
	var center := Vector2.ZERO
	for old_index in component:
		center += source_atoms[old_index].get("pos", Vector2.ZERO)
	center /= max(1, component.size())
	for old_index in component:
		index_map[old_index] = atoms.size()
		atoms.append({
			"element": source_atoms[old_index].get("element", CARBON),
			"pos": source_atoms[old_index].get("pos", Vector2.ZERO) - center
		})
	var new_bonds: Array[Dictionary] = []
	for bond in graph.get("bonds", []):
		var a := int(bond.get("a", 0))
		var b := int(bond.get("b", 0))
		if index_map.has(a) and index_map.has(b):
			new_bonds.append({
				"a": int(index_map[a]),
				"b": int(index_map[b]),
				"order": int(bond.get("order", 1))
			})
	var product := normalize({"atoms": atoms, "bonds": new_bonds})
	product["name"] = product["formula"]
	return product

static func _subscript(value: int) -> String:
	if value <= 1:
		return ""
	var digits := {
		"0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
		"5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"
	}
	var output := ""
	for ch in str(value):
		output += digits.get(ch, ch)
	return output
