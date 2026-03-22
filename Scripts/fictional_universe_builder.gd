extends Node

## Rebuilds res://universes/fictional/ to ~660 people, ~60 shows, matching 2008 contract density.
## Uses CSV name lists (era-weighted) via PersonGenerator. Run this scene (F6) to regenerate JSON.
## Seed keeps output stable across runs.

@export var seed_value: int = 42
@export var target_people: int = 660
@export var show_count: int = 60
@export var run_on_ready: bool = true


func _ready() -> void:
	if run_on_ready:
		build_fictional_universe()


func build_fictional_universe() -> void:
	var gen := PersonGenerator.new(seed_value)
	if not gen.load_default_name_database():
		push_error("FictionalUniverseBuilder: add CSVs under res://Data/name_lists/")
		return
	var d2008: Dictionary = DataLoader.load_data_from_directory("res://universes/2008")
	var shows_2008: Array = d2008["shows"]
	if shows_2008.size() < show_count:
		push_error("2008 bundle has fewer than %d shows" % show_count)
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

	_write_json("res://universes/fictional/universe.json", manifest)
	_write_json("res://universes/fictional/networks.json", d2008["networks"])
	_write_json("res://universes/fictional/showtypes.json", d2008["showtypes"])
	_write_json("res://universes/fictional/shows.json", new_shows)
	_write_json("res://universes/fictional/people.json", people)
	_write_json("res://universes/fictional/contracts.json", new_contracts)
	_write_json("res://universes/fictional/schedule.json", new_sched)
	print("Fictional universe written: %d people, %d shows, %d contracts." % [people.size(), new_shows.size(), new_contracts.size()])


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


func _write_json(path: String, data: Variant) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
