class_name DataLoader

###############################################################
# load_data
#
# Equivalent to JS loadData()
#
# Loads JSON files and returns a dictionary containing:
# people
# contracts
# shows
# showtypes
# schedule
# networks
###############################################################

static func load_data():

	var people = load_json("res://data/people.json")
	var contracts = load_json("res://data/contracts.json")
	var shows = load_json("res://data/shows.json")
	var showtypes = load_json("res://data/showtypes.json")
	var schedule = load_json("res://data/schedule.json")
	var networks = load_json("res://data/networks.json")

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

static func load_json(path):

	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()

	var json = JSON.new()
	json.parse(text)

	return json.get_data()
