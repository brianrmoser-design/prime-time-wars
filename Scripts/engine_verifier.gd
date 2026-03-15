###############################################################
# engine_verifier.gd
#
# PURPOSE
#
# This script verifies that the Godot scoring engine produces
# the same results as the original JavaScript engine.
#
# It does this by:
#
# 1. Loading all JSON data
# 2. Building show objects
# 3. Running the scoring engine
# 4. Printing results for every show
#
###############################################################

extends Node


###############################################################
# _ready
#
# Runs automatically when the scene starts.
###############################################################

func _ready():

	print("\n===============================")
	print("ENGINE VERIFICATION STARTED")
	print("===============================\n")

	run_verification()



###############################################################
# run_verification
#
# Main verification loop.
###############################################################

func run_verification():

	# Load all JSON data using the loader
	var data = DataLoader.load_data()

	var people = data["people"]
	var contracts = data["contracts"]
	var shows = data["shows"]
	var showtypes = data["showtypes"]

	print("Loaded:")
	print("People:", people.size())
	print("Contracts:", contracts.size())
	print("Shows:", shows.size())
	print("ShowTypes:", showtypes.size())
	print("\n")

	###########################################################
	# Iterate through every show
	###########################################################

	for show_entry in shows:

		var show_name = show_entry["Show_Name"]

		print("----------------------------------")
		print("Testing show:", show_name)

		#######################################################
		# Build show object (same as JS buildShowObject)
		#######################################################

		var show_obj = ShowBuilder.build_show_object(
			show_name,
			people,
			contracts,
			shows,
			showtypes
		)

		if show_obj.is_empty():
			print("ERROR: show object failed")
			continue

		#######################################################
		# Run scoring engine (same as JS rateShow)
		#######################################################

		var result = RatingEngine.rate_show(show_obj)

		#######################################################
		# Print breakdown
		#######################################################

		print("Cast Score:", result["castScore"])
		print("Writing Score:", result["writingScore"])
		print("Showrunner Score:", result["showrunnerScore"])
		print("Base Show Quality:", result["baseShowQuality"])

		print("")
