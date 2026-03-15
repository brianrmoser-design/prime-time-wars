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
###############################################################

static func load_data():

	var people = load_json("res://data/people.json")
	var contracts = load_json("res://data/contracts.json")
	var shows = load_json("res://data/shows.json")
	var showtypes = load_json("res://data/showtypes.json")

	return {
		"people": people,
		"contracts": contracts,
		"shows": shows,
		"showtypes": showtypes
	}


###############################################################
# Helper function for reading JSON
###############################################################

static func load_json(path):

	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()

	var json = JSON.new()
	json.parse(text)

	return json.get_data()
