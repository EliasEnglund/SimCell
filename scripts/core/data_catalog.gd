extends RefCounted
class_name DataCatalog

static func molecules() -> Dictionary:
	return {
		"glucose": {
			"name": "Glucose",
			"formula": "C6O6",
			"role": "Primary carbon source for early metabolism.",
			"color": Color("8ff0a4")
		},
		"oxygen_group": {
			"name": "Oxygen group",
			"formula": "O",
			"role": "Used for oxidation and redox reactions.",
			"color": Color("77c6ff")
		},
		"nitrogen_group": {
			"name": "Nitrogen group",
			"formula": "N",
			"role": "Required to create amino acid and nucleotide outputs.",
			"color": Color("b9a3ff")
		},
		"phosphate": {
			"name": "Phosphate",
			"formula": "PO4",
			"role": "Weakens carbon bonds and feeds ATP/DNA/RNA production.",
			"color": Color("ffd166")
		},
		"sulfur": {
			"name": "Sulfur",
			"formula": "S",
			"role": "Advanced protein chemistry; toxic if accumulated later.",
			"color": Color("f4a261")
		},
		"atp": {
			"name": "ATP",
			"formula": "ATP",
			"role": "Energy carrier spent on active transport and synthesis.",
			"color": Color("f7e36d")
		},
		"electrons": {
			"name": "Electrons",
			"formula": "e-",
			"role": "Redox capacity generated or spent by enzyme actions.",
			"color": Color("7dd3fc")
		},
		"amino_acids": {
			"name": "Amino acids",
			"formula": "C2NO2",
			"role": "Protein construction material.",
			"color": Color("ff9fb2")
		},
		"dna_parts": {
			"name": "DNA parts",
			"formula": "DNA",
			"role": "Research progress and gene unlocks.",
			"color": Color("c0fdfb")
		},
		"rna_parts": {
			"name": "RNA parts",
			"formula": "RNA",
			"role": "Ribosome construction material.",
			"color": Color("9bf6ff")
		},
		"lipids": {
			"name": "Lipids",
			"formula": "L",
			"role": "Membrane expansion and cell size.",
			"color": Color("f4d35e")
		}
	}

static func transporters() -> Dictionary:
	return {
		"glucose_channel": {
			"name": "Glucose Channel",
			"molecule": "glucose",
			"rate": 0.85,
			"atp_cost_per_unit": 0.0,
			"build_cost": {"amino_acids": 6.0},
			"description": "Passive carbon import when glucose is nearby."
		},
		"phosphate_pump": {
			"name": "Phosphate Pump",
			"molecule": "phosphate",
			"rate": 0.34,
			"atp_cost_per_unit": 0.12,
			"build_cost": {"amino_acids": 8.0, "atp": 4.0},
			"description": "Active import for phosphate-dependent chemistry."
		},
		"nitrogen_porter": {
			"name": "Nitrogen Porter",
			"molecule": "nitrogen_group",
			"rate": 0.28,
			"atp_cost_per_unit": 0.18,
			"build_cost": {"amino_acids": 9.0, "atp": 5.0},
			"description": "Imports nitrogen groups for amino acids and nucleotides."
		}
	}

static func enzyme_actions() -> Dictionary:
	return {
		"glycolytic_split": {
			"name": "C-C Lyase Split",
			"input": {"glucose": 1.0, "atp": 1.0},
			"output": {"electrons": 2.0, "oxygen_group": 1.0},
			"protein_cost": {"amino_acids": 7.0},
			"duration": 4.0,
			"description": "Break glucose into smaller redox-rich fragments."
		},
		"amination": {
			"name": "Amination",
			"input": {"glucose": 0.5, "nitrogen_group": 1.0, "electrons": 1.0},
			"output": {"amino_acids": 3.0},
			"protein_cost": {"amino_acids": 9.0, "atp": 3.0},
			"duration": 5.0,
			"description": "Attach nitrogen to carbon fragments to make protein material."
		},
		"phosphorylation": {
			"name": "Phosphorylation",
			"input": {"glucose": 0.5, "phosphate": 1.0},
			"output": {"atp": 3.0},
			"protein_cost": {"amino_acids": 10.0, "phosphate": 2.0},
			"duration": 5.5,
			"description": "Use phosphate chemistry to grow the ATP pool."
		},
		"nucleotide_synthesis": {
			"name": "Nucleotide Synthesis",
			"input": {"glucose": 0.5, "nitrogen_group": 1.0, "phosphate": 1.0, "atp": 1.0},
			"output": {"dna_parts": 1.3, "rna_parts": 0.8},
			"protein_cost": {"amino_acids": 12.0, "atp": 4.0},
			"duration": 7.0,
			"description": "Create DNA and RNA parts from carbon, nitrogen, and phosphate."
		},
		"lipid_synthesis": {
			"name": "Lipid Synthesis",
			"input": {"glucose": 1.0, "electrons": 1.0, "atp": 1.0},
			"output": {"lipids": 2.2},
			"protein_cost": {"amino_acids": 8.0, "atp": 3.0},
			"duration": 6.0,
			"description": "Turn carbon and redox power into membrane material."
		}
	}

static func proteins() -> Dictionary:
	return {
		"ribosome": {
			"name": "Ribosome",
			"kind": "machine",
			"build_cost": {"amino_acids": 14.0, "rna_parts": 5.0, "atp": 8.0},
			"duration": 10.0,
			"description": "Adds another parallel protein synthesis lane."
		},
		"storage_enzyme": {
			"name": "Storage Enzyme",
			"kind": "machine",
			"build_cost": {"amino_acids": 10.0, "atp": 4.0},
			"duration": 7.0,
			"description": "Reduces glucose waste and improves carbon stability."
		},
		"detox_pump": {
			"name": "Detox Pump",
			"kind": "defense",
			"build_cost": {"amino_acids": 12.0, "atp": 6.0},
			"duration": 8.0,
			"description": "Offsets early toxicity pressure from aggressive imports."
		}
	}

static func techs() -> Dictionary:
	return {
		"chemotaxis": {
			"name": "Chemotaxis",
			"tier": 1,
			"cost": 8.0,
			"description": "Reveals richer deposits and improves import planning."
		},
		"storage": {
			"name": "Storage Enzyme",
			"tier": 1,
			"cost": 10.0,
			"description": "Unlocks better storage behavior and stabilizes carbon excess."
		},
		"cyclases": {
			"name": "Cyclases",
			"tier": 1,
			"cost": 12.0,
			"description": "Unlocks future bond-weakening chemistry."
		},
		"nitrogen_enzymes": {
			"name": "Nitrogen Enzymes",
			"tier": 1,
			"cost": 14.0,
			"description": "Improves amino acid and nucleotide production."
		},
		"flagellum": {
			"name": "Flagellum",
			"tier": 1,
			"cost": 16.0,
			"description": "Future movement unlock for exploring deposits."
		}
	}
