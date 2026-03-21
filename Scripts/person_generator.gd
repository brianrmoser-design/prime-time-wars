class_name PersonGenerator

###############################################################
# person_generator.gd
#
# Generates fictional people for the talent pool. Uses Data/traits.json
# for trait definitions. Supports:
# - Full universe: generate a balanced pool of appropriate size.
# - Gradual: generate a batch to replace death/retirement.
###############################################################

## All trait keys used in people.json (Fame, Attractiveness, then traits.*)
const TRAIT_IDS := ["P", "C", "W", "I", "ED", "DC", "SH", "CT", "TI", "BF", "LC", "CC"]
const NO_SKILL := 15
const MIN_TRAIT := 35
const MAX_TRAIT := 100

## Skill tiers: weight = relative chance to pick. Higher tier = better primary traits.
const SKILL_TIERS := {
	"elite":   {"weight": 5,   "min": 90, "max": 100},
	"great":   {"weight": 15,  "min": 80, "max": 89},
	"good":    {"weight": 25,  "min": 70, "max": 79},
	"average":  {"weight": 40,  "min": 55, "max": 69},
	"below_avg": {"weight": 15,  "min": 40, "max": 54}
}

## Archetypes: which traits are primary (high), secondary (mid), or none (15/low).
## Primary = use tier range; secondary = mid band (55-75); none = NO_SKILL or low random.
const ARCHETYPES := {
	"lead_actor":      {"primary": ["P", "C", "I", "ED", "DC", "SH", "CT"], "secondary": ["W"], "none": ["TI", "BF", "LC", "CC"]},
	"support_actor":   {"primary": ["P", "C", "ED", "DC", "SH", "CT"], "secondary": ["W", "I"], "none": ["TI", "BF", "LC", "CC"]},
	"host":            {"primary": ["P", "C", "W", "SH", "CT", "BF"], "secondary": ["I", "ED"], "none": ["DC", "TI", "LC", "CC"]},
	"anchor":          {"primary": ["P", "C", "W", "TI", "BF"], "secondary": ["ED", "DC"], "none": ["I", "SH", "CT", "LC", "CC"]},
	"reporter":        {"primary": ["C", "W", "TI", "BF"], "secondary": ["P", "ED"], "none": ["I", "DC", "SH", "CT", "LC", "CC"]},
	"judge":           {"primary": ["P", "C", "W", "SH"], "secondary": ["I", "CT", "BF"], "none": ["ED", "DC", "TI", "LC", "CC"]},
	"staff_writer":    {"primary": ["W", "ED", "DC", "SH"], "secondary": [], "none": ["P", "C", "I", "CT", "TI", "BF", "LC", "CC"]},
	"head_writer":     {"primary": ["W", "ED", "DC", "SH"], "secondary": ["C", "LC"], "none": ["P", "I", "CT", "TI", "BF", "CC"]},
	"showrunner":      {"primary": ["C", "W", "CC", "LC", "ED", "DC", "SH"], "secondary": [], "none": ["P", "I", "CT", "TI", "BF"]},
	"exec_producer":   {"primary": ["C", "LC", "CC"], "secondary": ["W", "ED", "DC", "SH"], "none": ["P", "I", "CT", "TI", "BF"]}
}

## Default pool balance: fraction of generated people per archetype (must sum to 1.0).
const DEFAULT_BALANCE := {
	"lead_actor": 0.08,
	"support_actor": 0.18,
	"host": 0.04,
	"anchor": 0.06,
	"reporter": 0.08,
	"judge": 0.02,
	"staff_writer": 0.22,
	"head_writer": 0.06,
	"showrunner": 0.08,
	"exec_producer": 0.18
}

## Replacement rate: fraction of pool that "exits" per year (death/retirement). Used for gradual gen.
const DEFAULT_ANNUAL_EXIT_RATE := 0.02

## Save an array of person dicts to a JSON file (e.g. active universe's people_generated.json).
static func save_people_to_json(people: Array, path: String) -> bool:
	var json_str := JSON.stringify(people)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(json_str)
	f.close()
	return true

var _rng := RandomNumberGenerator.new()
var _traits_data: Array = []
## Legacy short lists when no CSV is loaded (see set_name_lists / load_name_database_from_csv).
var _name_first: PackedStringArray = []
var _name_last: PackedStringArray = []
var _name_db_loaded: bool = false
## Each entry: name, gender, origin, era_peak (int), weight (float)
var _first_name_rows: Array = []
## Each entry: name, origin, weight (float); also indexed by origin in _last_by_origin
var _last_name_rows: Array = []
var _last_by_origin: Dictionary = {}
## Sum of weights per origin (from first-name rows) for origin picking.
var _origin_weight: Dictionary = {}


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_init_names()


func _init_names() -> void:
	_name_first = PackedStringArray([
		"Alex", "Jordan", "Sam", "Morgan", "Casey", "Riley", "Quinn", "Avery", "Blake", "Drew",
		"Jamie", "Cameron", "Skyler", "Reese", "Sage", "Finley", "Parker", "Emery", "Hayden", "Kendall",
		"Taylor", "Reed", "Dakota", "River", "Phoenix", "Charlie", "Frankie", "Harper", "Ellis", "Adrian"
	])
	_name_last = PackedStringArray([
		"Bennett", "Chen", "Foster", "Gray", "Hayes", "Kim", "Lawson", "Morgan", "Park", "Reed",
		"Shaw", "Wells", "Brooks", "Cole", "Dunn", "Ellis", "Fox", "Grant", "Hunt", "Knight",
		"Lane", "Mills", "Page", "Quinn", "Ross", "Stone", "Vance", "Webb", "York", "Zimmerman"
	])
	_name_db_loaded = false


## Load trait definitions from Data/traits.json (optional; used for validation or future use).
func load_traits_from_project() -> bool:
	var path := "res://Data/traits.json"
	if not FileAccess.file_exists(path):
		path = "res://data/traits.json"
	if not FileAccess.file_exists(path):
		return false
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var json = JSON.new()
	var err = json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return false
	_traits_data = json.get_data()
	return true


## Provide custom first/last name arrays (e.g. from a JSON). Call before generating.
func set_name_lists(first: PackedStringArray, last: PackedStringArray) -> void:
	if first.size() > 0:
		_name_first = first
	if last.size() > 0:
		_name_last = last
	_name_db_loaded = false


## Load era- and origin-aware names from CSV (same columns as database_first_names / database_last_names).
## First: Name,Gender,Origin,Era_Peak,Weight — Last: Name,Origin,Weight
func load_name_database_from_csv(first_path: String, last_path: String) -> bool:
	var t1 := _read_utf8_file(first_path)
	var t2 := _read_utf8_file(last_path)
	if t1.is_empty() or t2.is_empty():
		return false
	_first_name_rows = _parse_first_names_csv(t1)
	_last_name_rows = _parse_last_names_csv(t2)
	if _first_name_rows.is_empty() or _last_name_rows.is_empty():
		return false
	_rebuild_last_by_origin()
	_rebuild_origin_weights()
	_name_db_loaded = true
	return true


## Default project paths under res://Data/name_lists/
func load_default_name_database() -> bool:
	var a := "res://Data/name_lists/database_first_names.csv"
	var b := "res://Data/name_lists/database_last_names.csv"
	if not FileAccess.file_exists(a) or not FileAccess.file_exists(b):
		return false
	return load_name_database_from_csv(a, b)


## Generate one person with the given archetype and optional skill tier (random if empty).
func generate_person(archetype: String, skill_tier: String = "") -> Dictionary:
	if not ARCHETYPES.has(archetype):
		archetype = ARCHETYPES.keys()[_rng.randi() % ARCHETYPES.size()]
	if skill_tier.is_empty() or not SKILL_TIERS.has(skill_tier):
		skill_tier = _pick_skill_tier()
	var arch = ARCHETYPES[archetype]
	var tier = SKILL_TIERS[skill_tier]
	var traits := _build_traits(arch, tier)
	var fame := _roll_fame_for_archetype(archetype, skill_tier)
	var attractiveness := _roll_attractiveness_for_archetype(archetype, skill_tier)
	var dob_str := _random_dob()
	var birth_year := int(dob_str.substr(0, 4))
	var gender := "Male" if _rng.randi() % 2 == 0 else "Female"
	var person := {
		"Person_ID": _next_id(),
		"Person_Name": _random_full_name(gender, birth_year),
		"DOB": dob_str,
		"Fame": str(clampi(fame, 35, 100)),
		"Attractiveness": str(clampi(attractiveness, 35, 100))
	}
	for key in TRAIT_IDS:
		person["traits." + key] = str(traits.get(key, NO_SKILL))
	return person


## Generate a batch of people with the given balance. balance_map: archetype -> count (or fraction 0–1).
## If values are <= 1 they are treated as fractions and multiplied by total n.
func generate_batch(n: int, balance_map: Dictionary = {}) -> Array:
	var counts := _balance_to_counts(n, balance_map)
	var out: Array = []
	for arch in counts:
		var c = counts[arch]
		for _i in c:
			out.append(generate_person(arch))
	return out


## Generate enough people to replace exits over one period. pool_size = current talent pool size.
## annual_exit_rate = fraction that leave per year (e.g. 0.02 = 2%). Returns new people to add.
func generate_replacement_batch(pool_size: int, annual_exit_rate: float = DEFAULT_ANNUAL_EXIT_RATE) -> Array:
	var n = max(1, int(ceil(pool_size * annual_exit_rate)))
	return generate_batch(n, DEFAULT_BALANCE)


## Generate a full universe: size and balance derived from shows + contracts, or use target_size + default balance.
## Returns array of person dicts. Pass existing people to avoid duplicate IDs/names if appending.
func generate_full_universe(shows: Array, contracts: Array, target_multiplier: float = 2.0, existing_people: Array = []) -> Array:
	var slot_count := contracts.size()
	if slot_count == 0:
		slot_count = shows.size() * 12
	var target_size: int = max(50, int(ceil(slot_count * target_multiplier)))
	var balance: Dictionary = DEFAULT_BALANCE.duplicate()
	if contracts.size() > 0:
		_fill_balance_from_contracts(contracts, balance)
	var existing_ids: Dictionary = {}
	var existing_names: Dictionary = {}
	for p in existing_people:
		existing_ids[p.get("Person_ID", "")] = true
		existing_names[p.get("Person_Name", "")] = true
	_set_id_name_avoid(existing_ids, existing_names)
	var out = generate_batch(target_size, balance)
	_clear_id_name_avoid()
	return out


func _pick_skill_tier() -> String:
	var total := 0
	for t in SKILL_TIERS:
		total += SKILL_TIERS[t].weight
	var r := _rng.randf() * total
	for t in SKILL_TIERS:
		r -= SKILL_TIERS[t].weight
		if r <= 0:
			return t
	return "average"


func _build_traits(arch: Dictionary, tier: Dictionary) -> Dictionary:
	var out := {}
	for key in TRAIT_IDS:
		out[key] = NO_SKILL
	for key in arch.get("primary", []):
		out[key] = _rng.randi_range(tier.min, tier.max)
	for key in arch.get("secondary", []):
		out[key] = _rng.randi_range(55, 75)
	for key in arch.get("none", []):
		if _rng.randf() < 0.15:
			out[key] = _rng.randi_range(40, 55)
		else:
			out[key] = NO_SKILL
	return out


func _roll_fame_for_archetype(archetype: String, _skill_tier: String) -> int:
	var base := 50
	if archetype in ["lead_actor", "host", "anchor"]:
		base = 65
	elif archetype in ["showrunner", "exec_producer"]:
		base = 55
	elif archetype in ["staff_writer", "head_writer"]:
		base = 42
	var spread := 25
	return clampi(_rng.randi_range(base - spread, base + spread), 35, 100)


func _roll_attractiveness_for_archetype(archetype: String, _skill_tier: String) -> int:
	var on_screen := ["lead_actor", "support_actor", "host", "anchor", "reporter", "judge"]
	var base := 50
	if archetype in on_screen:
		base = 58
	var spread := 28
	return clampi(_rng.randi_range(base - spread, base + spread), 35, 100)


func _random_dob() -> String:
	var year := _rng.randi_range(1940, 2000)
	var month := _rng.randi_range(1, 12)
	var day := _rng.randi_range(1, 28)
	return "%04d-%02d-%02d" % [year, month, day]


var _id_counter := 0
var _avoid_ids: Dictionary = {}
var _avoid_names: Dictionary = {}


func _next_id() -> String:
	var max_attempts := 1000000
	for _attempt in max_attempts:
		_id_counter += 1
		var id := "PERS_%06d" % (_id_counter % 1000000)
		if not _avoid_ids.get(id, false):
			return id
	return "PERS_%06d" % (_rng.randi_range(900000, 999999))


func _random_full_name(gender: String, birth_year: int) -> String:
	for _attempt in 40:
		var n := ""
		if _name_db_loaded:
			n = _talent_name_from_database(gender, birth_year)
		else:
			n = _name_first[_rng.randi() % _name_first.size()] + " " + _name_last[_rng.randi() % _name_last.size()]
		if not _avoid_names.get(n, false):
			return n
	return "Generated_%d" % _rng.randi_range(10000, 99999)


## Era-adjusted weighted pick (matches typical peak-year name popularity falloff).
func _talent_name_from_database(gender: String, birth_year: int) -> String:
	var origin := _pick_origin_by_weight()
	var first_pool: Array = []
	for row in _first_name_rows:
		if str(row.get("gender", "")) != gender:
			continue
		if str(row.get("origin", "")) != origin:
			continue
		var peak: int = int(row.get("era_peak", 1975))
		var w0: float = float(row.get("weight", 1.0))
		var w: float = w0 / (1.0 + abs(birth_year - peak) * 0.1)
		first_pool.append({"name": row.get("name", ""), "w": w})
	if first_pool.is_empty():
		for row in _first_name_rows:
			if str(row.get("origin", "")) != origin:
				continue
			var peak2: int = int(row.get("era_peak", 1975))
			var w0b: float = float(row.get("weight", 1.0))
			var wb: float = w0b / (1.0 + abs(birth_year - peak2) * 0.1)
			first_pool.append({"name": row.get("name", ""), "w": wb})
	if first_pool.is_empty():
		return _legacy_random_name_fragment() + " " + _legacy_random_name_fragment()

	var first: String = _weighted_pick_name(first_pool)
	var last_pool: Array = _last_entries_for_origin(origin)
	if last_pool.is_empty():
		last_pool = _last_name_rows
	var last: String = _weighted_pick_name(last_pool)
	return first + " " + last


func _legacy_random_name_fragment() -> String:
	if _name_first.size() > 0 and _rng.randf() < 0.5:
		return _name_first[_rng.randi() % _name_first.size()]
	if _name_last.size() > 0:
		return _name_last[_rng.randi() % _name_last.size()]
	return "X"


func _pick_origin_by_weight() -> String:
	var total := 0.0
	for o in _origin_weight:
		total += float(_origin_weight[o])
	if total <= 0.0:
		return "Western"
	var r := _rng.randf() * total
	for o in _origin_weight:
		r -= float(_origin_weight[o])
		if r <= 0.0:
			return str(o)
	return "Western"


func _last_entries_for_origin(origin: String) -> Array:
	return _last_by_origin.get(origin, [])


func _weighted_pick_name(entries: Array) -> String:
	var total := 0.0
	for e in entries:
		total += float(e.get("w", 0.0))
	if total <= 0.0 and entries.size() > 0:
		return str(entries[_rng.randi() % entries.size()].get("name", "?"))
	var r := _rng.randf() * total
	for e in entries:
		r -= float(e.get("w", 0.0))
		if r <= 0.0:
			return str(e.get("name", "?"))
	return str(entries[entries.size() - 1].get("name", "?"))


func _read_utf8_file(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _parse_first_names_csv(text: String) -> Array:
	var rows: Array = []
	var lines := text.split("\n")
	var start := 1
	if lines.size() > 0 and not lines[0].to_lower().begins_with("name,"):
		start = 0
	for i in range(start, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		if parts.size() < 5:
			continue
		rows.append({
			"name": parts[0].strip_edges(),
			"gender": parts[1].strip_edges(),
			"origin": parts[2].strip_edges(),
			"era_peak": parts[3].strip_edges().to_int(),
			"weight": parts[4].strip_edges().to_float()
		})
	return rows


func _parse_last_names_csv(text: String) -> Array:
	var rows: Array = []
	var lines := text.split("\n")
	var start := 1
	if lines.size() > 0 and not lines[0].to_lower().begins_with("name,"):
		start = 0
	for i in range(start, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		if parts.size() < 3:
			continue
		rows.append({
			"name": parts[0].strip_edges(),
			"origin": parts[1].strip_edges(),
			"weight": parts[2].strip_edges().to_float()
		})
	return rows


func _rebuild_last_by_origin() -> void:
	_last_by_origin.clear()
	for row in _last_name_rows:
		var o: String = str(row.get("origin", ""))
		if not _last_by_origin.has(o):
			_last_by_origin[o] = []
		_last_by_origin[o].append({"name": row.get("name", ""), "w": float(row.get("weight", 1.0))})


func _rebuild_origin_weights() -> void:
	_origin_weight.clear()
	for row in _first_name_rows:
		var o: String = str(row.get("origin", ""))
		_origin_weight[o] = float(_origin_weight.get(o, 0.0)) + float(row.get("weight", 0.0))


func _set_id_name_avoid(ids: Dictionary, names: Dictionary) -> void:
	_avoid_ids = ids
	_avoid_names = names
	_id_counter = _existing_people_max_id(ids)


func _clear_id_name_avoid() -> void:
	_avoid_ids = {}
	_avoid_names = {}


func _existing_people_max_id(ids: Dictionary) -> int:
	var max_val := 0
	for id_key in ids:
		if id_key is String and id_key.begins_with("PERS_"):
			var num = id_key.replace("PERS_", "").to_int()
			max_val = max(max_val, num)
	return max_val


func _balance_to_counts(n: int, balance_map: Dictionary) -> Dictionary:
	var counts := {}
	if balance_map.is_empty():
		balance_map = DEFAULT_BALANCE
	var total_frac := 0.0
	for arch in balance_map:
		var v = balance_map[arch]
		total_frac += v if v > 1 else 0.0
	var use_fractions := total_frac <= 1.0
	for arch in balance_map:
		var v = balance_map[arch]
		var c := int(v) if not use_fractions else int(round(n * float(v)))
		counts[arch] = max(0, c)
	var sum_c := 0
	for arch in counts:
		sum_c += counts[arch]
	if sum_c == 0:
		counts["support_actor"] = n
		return counts
	while sum_c > n:
		var keys_with_count := []
		for arch in counts:
			if counts[arch] > 0:
				keys_with_count.append(arch)
		if keys_with_count.is_empty():
			break
		var k = keys_with_count[_rng.randi() % keys_with_count.size()]
		counts[k] -= 1
		sum_c -= 1
	while sum_c < n:
		var k = counts.keys()[_rng.randi() % counts.size()]
		counts[k] = counts.get(k, 0) + 1
		sum_c += 1
	return counts


func _infer_balance_from_contracts(contracts: Array) -> Dictionary:
	var balance: Dictionary = {}
	_fill_balance_from_contracts(contracts, balance)
	return balance if not balance.is_empty() else DEFAULT_BALANCE.duplicate()


func _fill_balance_from_contracts(contracts: Array, balance: Dictionary) -> void:
	balance.clear()
	var role_count: Dictionary = {}
	for c in contracts:
		var r = c.get("Role", "")
		if r.is_empty():
			continue
		var arch := _role_to_archetype(r)
		role_count[arch] = role_count.get(arch, 0) + 1
	var total := 0
	for arch in role_count:
		total += role_count[arch]
	if total == 0:
		return
	for arch in role_count:
		balance[arch] = float(role_count[arch]) / float(total)
	_fill_missing_archetypes(balance)


static func _role_to_archetype(role: String) -> String:
	var m := {
		"Lead Actor": "lead_actor",
		"Support Actor": "support_actor",
		"Host": "host",
		"Anchor": "anchor",
		"Co-Host": "host",
		"Reporter": "reporter",
		"Judge": "judge",
		"Staff Writer": "staff_writer",
		"Head Writer": "head_writer",
		"Showrunner": "showrunner",
		"Executive Producer": "exec_producer"
	}
	return m.get(role, "support_actor")


func _fill_missing_archetypes(balance: Dictionary) -> void:
	var default_frac := 0.02
	for arch in ARCHETYPES:
		if not balance.has(arch):
			balance[arch] = default_frac
	var total := 0.0
	for arch in balance:
		total += balance[arch]
	if total > 0:
		for arch in balance:
			balance[arch] = balance[arch] / total
