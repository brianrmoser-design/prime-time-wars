extends Node

## Rebuilds res://universes/fictional/ to ~660 people, ~60 shows, matching 2008 contract density.
## Uses CSV name lists (era-weighted) via PersonGenerator.
##
## How to run: open this scene → **Project → Run Current Scene** (F6), or set it as main scene and F5.
## Watch **Output** (not only Debugger): errors and prints go there. If nothing updates on disk,
## writes to res:// failed (see _ensure_output_dir / _write_json) or an early return printed an error.
##
## Seed keeps output stable across runs.

@export var seed_value: int = 42
@export var target_people: int = 660
@export var show_count: int = 60
@export var run_on_ready: bool = true


func _ready() -> void:
	if run_on_ready:
		build_fictional_universe()


func build_fictional_universe() -> void:
	print("FictionalUniverseBuilder: starting…")
	var gen := PersonGenerator.new(seed_value)
	if not gen.load_default_name_database():
		push_error("FictionalUniverseBuilder: add CSVs under res://Data/name_lists/")
		print("FAILED: could not load database_first_names.csv / database_last_names.csv")
		return
	if not _ensure_output_dir():
		push_error("FictionalUniverseBuilder: could not create res://universes/fictional/")
		print("FAILED: output folder (see error above)")
		return
	var d2008: Dictionary = DataLoader.load_data_from_directory("res://universes/2008")
	if not _validate_bundle(d2008, "res://universes/2008"):
		return
	var shows_2008: Array = d2008["shows"]
	if shows_2008.size() < show_count:
		push_error("2008 bundle has fewer than %d shows" % show_count)
		print("FAILED: universes/2008/shows.json has only %d shows (need %d)" % [shows_2008.size(), show_count])
		return

	var title_rng := RandomNumberGenerator.new()
	title_rng.seed = seed_value
	var titles := _make_unique_titles(show_count, title_rng)

	var chosen: Array = []
	var old_show_names: Dictionary = {}
	var old_id_to_new_id: Dictionary = {}
	var old_show_name_to_new: Dictionary = {}

	for i in show_count:
		var src: Dictionary = (shows_2008[i] as Dictionary).duplicate(true)
		chosen.append(src)
		var old_name: String = str(src.get("Show_Name", ""))
		var old_id: String = str(src.get("Show_ID", ""))
		old_show_names[old_name] = true
		var new_id := "SHOW_FIC_%05d" % (i + 1)
		var new_title: String = titles[i]
		old_id_to_new_id[old_id] = new_id
		old_show_name_to_new[old_name] = new_title

	var filtered_contracts: Array = []
	for c in d2008["contracts"]:
		var cdict: Dictionary = c
		var sn: String = str(cdict.get("Show_Name", ""))
		if old_show_names.get(sn, false):
			filtered_contracts.append(cdict.duplicate(true))

	var unique_old: Dictionary = {}
	for c in filtered_contracts:
		unique_old[str(c.get("Person_Name", ""))] = true
	var sorted_old: Array = unique_old.keys()
	sorted_old.sort()

	var people: Array = gen.generate_batch(target_people, PersonGenerator.DEFAULT_BALANCE)
	if sorted_old.size() > people.size():
		push_error("Need at least as many generated people as unique contract talent (%d)" % sorted_old.size())
		print(
			"FAILED: unique names in contracts for these shows = %d. Raise target_people above that (or reduce show_count)."
			% sorted_old.size()
		)
		return

	var old_person_to_new: Dictionary = {}
	for i in sorted_old.size():
		old_person_to_new[sorted_old[i]] = str((people[i] as Dictionary).get("Person_Name", ""))

	var new_contracts: Array = []
	for c in filtered_contracts:
		var nc: Dictionary = c.duplicate(true)
		var oshow: String = str(nc.get("Show_Name", ""))
		var oper: String = str(nc.get("Person_Name", ""))
		nc["Show_Name"] = old_show_name_to_new.get(oshow, oshow)
		nc["Person_Name"] = old_person_to_new.get(oper, oper)
		new_contracts.append(nc)

	var new_shows: Array = []
	for i in show_count:
		var row: Dictionary = (chosen[i] as Dictionary).duplicate(true)
		row["Show_ID"] = old_id_to_new_id[str(row.get("Show_ID", ""))]
		row["Show_Name"] = titles[i]
		new_shows.append(row)

	var sched_in: Dictionary = d2008["schedule"]
	var new_sched: Dictionary = {}
	for net_id in sched_in.keys():
		var net_data: Dictionary = sched_in[net_id]
		var out_net: Dictionary = {}
		for day in net_data.keys():
			var slots: Array = net_data[day]
			var out_slots: Array = []
			for slot in slots:
				var sdict: Dictionary = slot
				var oid: String = str(sdict.get("show", ""))
				if old_id_to_new_id.has(oid):
					var ns: Dictionary = sdict.duplicate(true)
					ns["show"] = old_id_to_new_id[oid]
					out_slots.append(ns)
			out_net[day] = out_slots
		new_sched[net_id] = out_net

	var manifest := {
		"id": "fictional",
		"display_name": "Fictional Universe",
		"description": "Generated lineup (~%d people, %d shows) from 2008 structure with CSV names." % [target_people, show_count]
	}

	var ok := true
	ok = _write_json("res://universes/fictional/universe.json", manifest) and ok
	ok = _write_json("res://universes/fictional/networks.json", d2008["networks"]) and ok
	ok = _write_json("res://universes/fictional/showtypes.json", d2008["showtypes"]) and ok
	ok = _write_json("res://universes/fictional/shows.json", new_shows) and ok
	ok = _write_json("res://universes/fictional/people.json", people) and ok
	ok = _write_json("res://universes/fictional/contracts.json", new_contracts) and ok
	ok = _write_json("res://universes/fictional/schedule.json", new_sched) and ok
	if ok:
		print("Fictional universe written: %d people, %d shows, %d contracts." % [people.size(), new_shows.size(), new_contracts.size()])
		print("Files: res://universes/fictional/*.json — refresh FileSystem dock if needed.")
	else:
		push_error("FictionalUniverseBuilder: one or more writes failed (see errors above).")
		print("FAILED: could not write all JSON files. Editor must allow writing to the project folder.")


func _make_unique_titles(n: int, rng: RandomNumberGenerator) -> PackedStringArray:
	var w1 := [
		"Neon", "Silver", "Midnight", "Northern", "Southern", "Eastern", "Western", "Royal",
		"Second", "First", "Twin", "Cold", "Red", "Blue", "Black", "White", "Golden", "Stone",
		"Iron", "Crystal", "Pacific", "Atlantic", "Central", "Metro", "Grand", "Little", "Great",
		"False", "True", "High", "Low", "Dark", "Bright", "Silent", "Broken", "Perfect", "Empty",
		"Lost", "Found", "Secret", "Open", "Final", "Early", "Late", "Summer", "Winter", "Spring"
	]
	var w2 := [
		"Harbor", "Crossing", "Division", "Mercy", "Station", "District", "Heights", "Ridge",
		"Falls", "Bridge", "Point", "Bay", "Court", "Place", "Line", "Room", "Passage", "Ward",
		"City", "County", "Law", "Order", "Fire", "Skies", "Dawn", "Night", "Star", "Field",
		"Creek", "Lane", "Circle", "Square", "Park", "Tower", "Hall", "Gate", "Road", "Run",
		"Shore", "Lake", "River", "Mountain", "Valley", "Street", "House", "Room", "Club", "Beat"
	]
	var used: Dictionary = {}
	var out: PackedStringArray = []
	var guard := 0
	while out.size() < n and guard < n * 200:
		guard += 1
		var t: String = w1[rng.randi() % w1.size()] + " " + w2[rng.randi() % w2.size()]
		if used.get(t, false):
			continue
		used[t] = true
		out.append(t)
	while out.size() < n:
		out.append("Working Title %d" % (out.size() + 1))
	return out


func _validate_bundle(d: Dictionary, label: String) -> bool:
	var keys := ["people", "contracts", "shows", "showtypes", "schedule", "networks"]
	for k in keys:
		if not d.has(k) or d[k] == null:
			push_error("FictionalUniverseBuilder: missing or null '%s' in %s" % [k, label])
			print("FAILED: could not load JSON for key: ", k)
			return false
	return true


## Ensures res://universes/fictional exists (Godot does not create parent dirs on write).
func _ensure_output_dir() -> bool:
	var dir := DirAccess.open("res://")
	if dir == null:
		push_error("FictionalUniverseBuilder: DirAccess.open(res://) failed")
		return false
	var err := dir.make_dir_recursive("universes/fictional")
	return err == OK


func _write_json(path: String, data: Variant) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write %s (check folder exists and editor may write to project)" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true
