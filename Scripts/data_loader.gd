class_name DataLoader

###############################################################
# load_data
#
# Loads JSON for the active universe (see UniverseConfig autoload).
# Each universe folder contains: people, contracts, shows, showtypes,
# schedule, networks — same shapes as before when they lived under Data/.
#
###############################################################

static func load_data() -> Dictionary:
	var root: String = UniverseConfig.get_data_directory()
	return load_data_from_directory(root)


static func load_data_from_directory(root: String) -> Dictionary:
	var people = load_json("%s/people.json" % root)
	var contracts = load_json("%s/contracts.json" % root)
	var shows = load_json("%s/shows.json" % root)
	var showtypes = load_json("%s/showtypes.json" % root)
	var schedule = load_json("%s/schedule.json" % root)
	var networks = load_json("%s/networks.json" % root)

	return {
		"people": people,
		"contracts": contracts,
		"shows": shows,
		"showtypes": showtypes,
		"schedule": schedule,
		"networks": networks
	}


###############################################################
# get_show_id_to_name
#
# Returns a dictionary mapping Show_ID -> Show_Name for use with
# schedule (which references shows by Show_ID). Day keys "0"-"6"
# are Sunday through Saturday.
###############################################################

static func get_show_id_to_name(shows) -> Dictionary:
	var out = {}
	for s in shows:
		var sid = s.get("Show_ID", "")
		var name_key = s.get("Show_Name", "")
		if sid != "":
			out[sid] = name_key
	return out


###############################################################
# Helper function for reading JSON
###############################################################

static func load_json(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: could not open %s" % path)
		return null
	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("DataLoader: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null

	return json.get_data()
