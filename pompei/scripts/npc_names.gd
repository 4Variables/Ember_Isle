class_name NpcNames

const NAMES: Array[String] = [
	"James", "Marcus", "Livia", "Julia", "Gaius", "Octavia", "Lucius", "Claudia",
	"Felix", "Aurelia", "Titus", "Cornelia", "Quintus", "Flavia", "Decimus", "Valeria",
	"Sextus", "Camilla", "Brutus", "Drusilla", "Cassius", "Antonia", "Nero", "Lucretia",
	"Maximus", "Sabina", "Rufus", "Helena", "Severus", "Portia",
]

static var _unused: Array[String] = []

# Every name is used once before any repeats.
static func pick() -> String:
	if _unused.is_empty():
		_unused = NAMES.duplicate()
		_unused.shuffle()
	return _unused.pop_back()
