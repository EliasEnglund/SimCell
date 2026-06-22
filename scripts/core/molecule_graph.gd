extends RefCounted
class_name MoleculeGraph

const CARBON := "C"
const OXYGEN := "O"
const NITROGEN := "N"

static func amino_acid_target() -> Dictionary:
	return normalize({
		"name": "Amino Acid Target",
		"atoms": [
			{"element": NITROGEN, "pos": Vector2(-126.0, 0.0)},
			{"element": CARBON, "pos": Vector2(-44.0, 0.0)},
			{"element": CARBON, "pos": Vector2(42.0, 0.0)},
			{"element": OXYGEN, "pos": Vector2(122.0, -42.0)},
			{"element": OXYGEN, "pos": Vector2(124.0, 42.0)}
		],
		"bonds": [
			{"a": 0, "b": 1, "order": 1},
			{"a": 1, "b": 2, "order": 1},
			{"a": 2, "b": 3, "order": 2},
			{"a": 2, "b": 4, "order": 1}
		]
	})

static func initial_glucose_like() -> Dictionary:
	var atoms: Array[Dictionary] = [
		{"element": CARBON, "pos": Vector2(-230.0, 20.0)},
		{"element": CARBON, "pos": Vector2(-146.0, -28.0)},
		{"element": CARBON, "pos": Vector2(-62.0, 20.0)},
		{"element": CARBON, "pos": Vector2(22.0, -28.0)},
		{"element": CARBON, "pos": Vector2(106.0, 20.0)},
		{"element": CARBON, "pos": Vector2(190.0, -28.0)},
		{"element": OXYGEN, "pos": Vector2(-226.0, 108.0)},
		{"element": OXYGEN, "pos": Vector2(-148.0, -116.0)},
		{"element": OXYGEN, "pos": Vector2(-60.0, 108.0)},
		{"element": OXYGEN, "pos": Vector2(24.0, -116.0)},
		{"element": OXYGEN, "pos": Vector2(108.0, 108.0)},
		{"element": OXYGEN, "pos": Vector2(266.0, -72.0)}
	]
	var bonds: Array[Dictionary] = [
		{"a": 0, "b": 1, "order": 1},
		{"a": 1, "b": 2, "order": 1},
		{"a": 2, "b": 3, "order": 1},
		{"a": 3, "b": 4, "order": 1},
		{"a": 4, "b": 5, "order": 1},
		{"a": 0, "b": 6, "order": 1},
		{"a": 1, "b": 7, "order": 1},
		{"a": 2, "b": 8, "order": 1},
		{"a": 3, "b": 9, "order": 1},
		{"a": 4, "b": 10, "order": 1},
		{"a": 5, "b": 11, "order": 2}
	]
	return normalize({"name": "Glucose", "atoms": atoms, "bonds": bonds})

static func outside_source_molecules() -> Array[Dictionary]:
	return [
		simple_molecule("Formic Acid", [
			{"element": CARBON, "pos": Vector2(-42.0, 0.0)},
			{"element": OXYGEN, "pos": Vector2(44.0, -42.0)},
			{"element": OXYGEN, "pos": Vector2(46.0, 42.0)}
		], [
			{"a": 0, "b": 1, "order": 2},
			{"a": 0, "b": 2, "order": 1}
		]),
		simple_molecule("Ethanol", [
			{"element": CARBON, "pos": Vector2(-82.0, 8.0)},
			{"element": CARBON, "pos": Vector2(0.0, -8.0)},
			{"element": OXYGEN, "pos": Vector2(82.0, -28.0)}
		], [
			{"a": 0, "b": 1, "order": 1},
			{"a": 1, "b": 2, "order": 1}
		]),
		simple_molecule("Pyruvate", [
			{"element": CARBON, "pos": Vector2(-104.0, 28.0)},
			{"element": CARBON, "pos": Vector2(-20.0, -18.0)},
			{"element": CARBON, "pos": Vector2(72.0, 24.0)},
			{"element": OXYGEN, "pos": Vector2(-20.0, -96.0)},
			{"element": OXYGEN, "pos": Vector2(146.0, -18.0)},
			{"element": OXYGEN, "pos": Vector2(150.0, 70.0)}
		], [
			{"a": 0, "b": 1, "order": 1},
			{"a": 1, "b": 2, "order": 1},
			{"a": 1, "b": 3, "order": 2},
			{"a": 2, "b": 4, "order": 1},
			{"a": 2, "b": 5, "order": 2}
		]),
		simple_molecule("Hydrogen", [
			{"element": "H", "pos": Vector2(-34.0, 0.0)},
			{"element": "H", "pos": Vector2(34.0, 0.0)}
		], [
			{"a": 0, "b": 1, "order": 1}
		], "H₂"),
		simple_molecule("Nitrate", [
			{"element": NITROGEN, "pos": Vector2(0.0, 0.0)},
			{"element": OXYGEN, "pos": Vector2(0.0, -78.0)},
			{"element": OXYGEN, "pos": Vector2(-68.0, 42.0)},
			{"element": OXYGEN, "pos": Vector2(68.0, 42.0)}
		], [
			{"a": 0, "b": 1, "order": 1},
			{"a": 0, "b": 2, "order": 1},
			{"a": 0, "b": 3, "order": 2}
		], "NO₃"),
		simple_molecule("Sulfate", [
			{"element": "S", "pos": Vector2(0.0, 0.0)},
			{"element": OXYGEN, "pos": Vector2(0.0, -82.0)},
			{"element": OXYGEN, "pos": Vector2(-74.0, 0.0)},
			{"element": OXYGEN, "pos": Vector2(74.0, 0.0)},
			{"element": OXYGEN, "pos": Vector2(0.0, 82.0)}
		], [
			{"a": 0, "b": 1, "order": 2},
			{"a": 0, "b": 2, "order": 1},
			{"a": 0, "b": 3, "order": 1},
			{"a": 0, "b": 4, "order": 2}
		], "SO₄")
	]

static func simple_molecule(name: String, atoms: Array[Dictionary], bonds: Array[Dictionary], display_formula: String = "") -> Dictionary:
	var graph := normalize({"name": name, "atoms": atoms, "bonds": bonds})
	if not display_formula.is_empty():
		graph["formula"] = display_formula
	return graph

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
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
			continue
		var e1: String = atoms[a].get("element", "")
		var e2: String = atoms[b].get("element", "")
		var carbon_index := a if e1 == CARBON else b
		if int(bond.get("order", 1)) > 1 and ((e1 == CARBON and e2 == OXYGEN) or (e1 == OXYGEN and e2 == CARBON)) and not _is_carboxyl_carbon(graph, carbon_index):
			targets.append(i)
	return targets

static func apply_reductase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	var product := clone(graph)
	var bonds: Array = product.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	var order := int(bonds[bond_index].get("order", 1))
	if order <= 1:
		return []
	bonds[bond_index]["order"] = 1
	product["bonds"] = bonds
	product["name"] = product.get("formula", "Molecule")
	return [normalize(product)]

static func valid_dehydrogenase_targets(graph: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
			continue
		var e1: String = atoms[a].get("element", "")
		var e2: String = atoms[b].get("element", "")
		var carbon_index := a if e1 == CARBON else b
		if not ((e1 == CARBON and e2 == OXYGEN) or (e1 == OXYGEN and e2 == CARBON)):
			continue
		var order := int(bond.get("order", 1))
		if order == 1 and not _has_double_oxygen_neighbor(graph, carbon_index):
			targets.append(i)
		elif order == 2 and not _is_carboxyl_carbon(graph, carbon_index):
			targets.append(i)
	return targets

static func apply_dehydrogenase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	var bond: Dictionary = bonds[bond_index]
	var a := int(bond.get("a", -1))
	var b := int(bond.get("b", -1))
	if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
		return []
	var e1: String = atoms[a].get("element", "")
	var e2: String = atoms[b].get("element", "")
	var carbon_index := a if e1 == CARBON else b
	if not ((e1 == CARBON and e2 == OXYGEN) or (e1 == OXYGEN and e2 == CARBON)):
		return []
	if int(bond.get("order", 1)) == 1:
		return _set_bond_order(graph, bond_index, 2)
	if int(bond.get("order", 1)) == 2 and not _is_carboxyl_carbon(graph, carbon_index):
		return _add_carboxyl_oxygen(graph, bond_index)
	return []

static func valid_desaturase_targets(graph: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
			continue
		if int(bond.get("order", 1)) == 1 and atoms[a].get("element", "") == CARBON and atoms[b].get("element", "") == CARBON:
			targets.append(i)
	return targets

static func apply_desaturase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	return _set_bond_order(graph, bond_index, 2)

static func valid_oxygenase_targets(graph: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		if int(bond.get("order", 1)) != 2:
			continue
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
			continue
		var e1: String = atoms[a].get("element", "")
		var e2: String = atoms[b].get("element", "")
		var carbon_index := a if e1 == CARBON else b
		if ((e1 == CARBON and e2 == OXYGEN) or (e1 == OXYGEN and e2 == CARBON)) and not _is_carboxyl_carbon(graph, carbon_index):
			targets.append(i)
	return targets

static func apply_oxygenase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	return _add_carboxyl_oxygen(graph, bond_index)

static func valid_aminase_targets(graph: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		if int(bond.get("order", 1)) != 2:
			continue
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
			continue
		var carbon_index := -1
		var oxygen_index := -1
		if atoms[a].get("element", "") == CARBON and atoms[b].get("element", "") == OXYGEN:
			carbon_index = a
			oxygen_index = b
		elif atoms[b].get("element", "") == CARBON and atoms[a].get("element", "") == OXYGEN:
			carbon_index = b
			oxygen_index = a
		if carbon_index < 0 or oxygen_index < 0:
			continue
		if _has_carboxyl_neighbor(graph, carbon_index):
			targets.append(i)
	return targets

static func apply_aminase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	var product := clone(graph)
	var atoms: Array = product.get("atoms", [])
	var bonds: Array = product.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	var bond: Dictionary = bonds[bond_index]
	var a := int(bond.get("a", -1))
	var b := int(bond.get("b", -1))
	if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
		return []
	var carbon_index := a if atoms[a].get("element", "") == CARBON else b
	var oxygen_index := b if carbon_index == a else a
	if atoms[carbon_index].get("element", "") != CARBON or atoms[oxygen_index].get("element", "") != OXYGEN:
		return []
	if int(bonds[bond_index].get("order", 1)) != 2 or not _has_carboxyl_neighbor(product, carbon_index):
		return []
	bonds[bond_index]["order"] = 1
	var carbon_pos: Vector2 = atoms[carbon_index].get("pos", Vector2.ZERO)
	var oxygen_pos: Vector2 = atoms[oxygen_index].get("pos", carbon_pos + Vector2.UP)
	var dir := (carbon_pos - oxygen_pos).normalized()
	if dir.length() <= 0.0:
		dir = Vector2.RIGHT
	var normal := Vector2(-dir.y, dir.x)
	var new_index := atoms.size()
	atoms.append({"element": NITROGEN, "pos": carbon_pos + normal * 84.0})
	bonds.append({"a": carbon_index, "b": new_index, "order": 1})
	product["atoms"] = atoms
	product["bonds"] = bonds
	product["name"] = product.get("formula", "Molecule")
	return [normalize(product)]

static func valid_decarboxylase_targets(graph: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size() or atoms[a].get("element", "") != CARBON or atoms[b].get("element", "") != CARBON:
			continue
		if _is_carboxyl_carbon(graph, a) or _is_carboxyl_carbon(graph, b):
			targets.append(i)
	return targets

static func apply_decarboxylase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	var source := clone(graph)
	var atoms: Array = source.get("atoms", [])
	var bonds: Array = source.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	var bond: Dictionary = bonds[bond_index]
	var a := int(bond.get("a", -1))
	var b := int(bond.get("b", -1))
	if a < 0 or b < 0:
		return []
	var remove_carbon := _preferred_carboxyl_carbon(source, a, b)
	if remove_carbon < 0:
		return []
	var remove := {remove_carbon: true}
	for neighbor in _neighbors(source, remove_carbon):
		if atoms[int(neighbor)].get("element", "") == OXYGEN:
			remove[int(neighbor)] = true
	var kept: Array[int] = []
	for i in atoms.size():
		if not remove.has(i):
			kept.append(i)
	if kept.is_empty():
		return []
	return [_subgraph(source, kept)]

static func apply_lyase(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	var source := clone(graph)
	var bonds: Array = source.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	bonds.remove_at(bond_index)
	source["bonds"] = bonds
	return _connected_components(source)

static func _set_bond_order(graph: Dictionary, bond_index: int, order: int) -> Array[Dictionary]:
	var product := clone(graph)
	var bonds: Array = product.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	if int(bonds[bond_index].get("order", 1)) == order:
		return []
	bonds[bond_index]["order"] = order
	product["bonds"] = bonds
	product["name"] = product.get("formula", "Molecule")
	return [normalize(product)]

static func _valid_bonds_with_carbon(graph: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var bonds: Array = graph.get("bonds", [])
	var atoms: Array = graph.get("atoms", [])
	for i in bonds.size():
		var bond: Dictionary = bonds[i]
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
			continue
		if atoms[a].get("element", "") == CARBON or atoms[b].get("element", "") == CARBON:
			targets.append(i)
	return targets

static func _add_atom_to_bond_carbon(graph: Dictionary, bond_index: int, element: String) -> Array[Dictionary]:
	var product := clone(graph)
	var atoms: Array = product.get("atoms", [])
	var bonds: Array = product.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	var bond: Dictionary = bonds[bond_index]
	var a := int(bond.get("a", -1))
	var b := int(bond.get("b", -1))
	if a < 0 or b < 0:
		return []
	var carbon_index := a if atoms[a].get("element", "") == CARBON else b
	if atoms[carbon_index].get("element", "") != CARBON:
		return []
	var carbon_pos: Vector2 = atoms[carbon_index].get("pos", Vector2.ZERO)
	var other_index := b if carbon_index == a else a
	var other_pos: Vector2 = atoms[other_index].get("pos", carbon_pos + Vector2.RIGHT)
	var dir := (carbon_pos - other_pos).normalized()
	if dir.length() <= 0.0:
		dir = Vector2.UP
	var normal := Vector2(-dir.y, dir.x)
	var side := -1.0 if _oxygen_neighbor_count(product, carbon_index) > 0 else 1.0
	var new_pos := carbon_pos + (normal * side + dir * 0.24).normalized() * 86.0
	var new_index := atoms.size()
	atoms.append({"element": element, "pos": new_pos})
	bonds.append({"a": carbon_index, "b": new_index, "order": 1})
	product["atoms"] = atoms
	product["bonds"] = bonds
	product["name"] = product.get("formula", "Molecule")
	return [normalize(product)]

static func _add_carboxyl_oxygen(graph: Dictionary, bond_index: int) -> Array[Dictionary]:
	var product := clone(graph)
	var atoms: Array = product.get("atoms", [])
	var bonds: Array = product.get("bonds", [])
	if bond_index < 0 or bond_index >= bonds.size():
		return []
	var bond: Dictionary = bonds[bond_index]
	if int(bond.get("order", 1)) != 2:
		return []
	var a := int(bond.get("a", -1))
	var b := int(bond.get("b", -1))
	if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size():
		return []
	var carbon_index := a if atoms[a].get("element", "") == CARBON else b
	var oxygen_index := b if carbon_index == a else a
	if atoms[carbon_index].get("element", "") != CARBON or atoms[oxygen_index].get("element", "") != OXYGEN:
		return []
	if _is_carboxyl_carbon(product, carbon_index):
		return []
	var carbon_pos: Vector2 = atoms[carbon_index].get("pos", Vector2.ZERO)
	var oxygen_pos: Vector2 = atoms[oxygen_index].get("pos", carbon_pos + Vector2.RIGHT)
	var dir := (carbon_pos - oxygen_pos).normalized()
	if dir.length() <= 0.0:
		dir = Vector2.RIGHT
	var normal := Vector2(-dir.y, dir.x)
	var side := -1.0
	for neighbor in _neighbors(product, carbon_index):
		if int(neighbor) == oxygen_index:
			continue
		var neighbor_pos: Vector2 = atoms[int(neighbor)].get("pos", carbon_pos)
		if signf((neighbor_pos - carbon_pos).dot(normal)) == side:
			side = 1.0
			break
	var new_index := atoms.size()
	atoms.append({"element": OXYGEN, "pos": carbon_pos + (normal * side + dir * 0.15).normalized() * 86.0})
	bonds.append({"a": carbon_index, "b": new_index, "order": 1})
	product["atoms"] = atoms
	product["bonds"] = bonds
	product["name"] = product.get("formula", "Molecule")
	return [normalize(product)]

static func _preferred_carboxyl_carbon(graph: Dictionary, a: int, b: int) -> int:
	if _is_carboxyl_carbon(graph, a):
		return a
	if _is_carboxyl_carbon(graph, b):
		return b
	var a_oxygen := _oxygen_neighbor_count(graph, a)
	var b_oxygen := _oxygen_neighbor_count(graph, b)
	if a_oxygen > b_oxygen:
		return a
	if b_oxygen > a_oxygen:
		return b
	var a_degree := _bond_degree(graph, a)
	var b_degree := _bond_degree(graph, b)
	if a_degree <= b_degree:
		return a
	return b

static func _is_carboxyl_carbon(graph: Dictionary, atom_index: int) -> bool:
	var atoms: Array = graph.get("atoms", [])
	if atom_index < 0 or atom_index >= atoms.size() or atoms[atom_index].get("element", "") != CARBON:
		return false
	var oxygen_neighbors := 0
	var has_double_oxygen := false
	for bond in graph.get("bonds", []):
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		var other := -1
		if a == atom_index:
			other = b
		elif b == atom_index:
			other = a
		if other < 0 or other >= atoms.size():
			continue
		if atoms[other].get("element", "") == OXYGEN:
			oxygen_neighbors += 1
			if int(bond.get("order", 1)) >= 2:
				has_double_oxygen = true
	return oxygen_neighbors >= 2 and has_double_oxygen

static func _has_double_oxygen_neighbor(graph: Dictionary, atom_index: int) -> bool:
	var atoms: Array = graph.get("atoms", [])
	if atom_index < 0 or atom_index >= atoms.size() or atoms[atom_index].get("element", "") != CARBON:
		return false
	for bond in graph.get("bonds", []):
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		var other := -1
		if a == atom_index:
			other = b
		elif b == atom_index:
			other = a
		if other < 0 or other >= atoms.size():
			continue
		if atoms[other].get("element", "") == OXYGEN and int(bond.get("order", 1)) >= 2:
			return true
	return false

static func _has_carboxyl_neighbor(graph: Dictionary, atom_index: int) -> bool:
	var atoms: Array = graph.get("atoms", [])
	if atom_index < 0 or atom_index >= atoms.size():
		return false
	for neighbor in _neighbors(graph, atom_index):
		if _is_carboxyl_carbon(graph, int(neighbor)):
			return true
	return false

static func _oxygen_neighbor_count(graph: Dictionary, atom_index: int) -> int:
	var count := 0
	var atoms: Array = graph.get("atoms", [])
	for neighbor in _neighbors(graph, atom_index):
		if atoms[int(neighbor)].get("element", "") == OXYGEN:
			count += 1
	return count

static func _bond_degree(graph: Dictionary, atom_index: int) -> int:
	return _neighbors(graph, atom_index).size()

static func _neighbors(graph: Dictionary, atom_index: int) -> Array[int]:
	var output: Array[int] = []
	for bond in graph.get("bonds", []):
		var a := int(bond.get("a", -1))
		var b := int(bond.get("b", -1))
		if a == atom_index:
			output.append(b)
		elif b == atom_index:
			output.append(a)
	return output

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
