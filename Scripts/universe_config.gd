extends Node

## Active universe: all game JSON (people, shows, schedule, …) lives under
## res://universes/<universe_id>/.
##
## How to switch:
##   • Code: UniverseConfig.set_universe("fictional") before any DataLoader.load_data().
##   • Ratings dashboard: use the Universe dropdown at the top of the window.
##   • Inspector: on RatingsDashboard, set the "Initial Universe" export (when the scene opens).
##   • Command line (after --): universe=fictional   e.g. Godot: godot.project Run args: universe=fictional
##
## Folder names must match: res://universes/2008/, res://universes/fictional/, etc.

const UNIVERSE_2008 := "2008"
const UNIVERSE_FICTIONAL := "fictional"

var universe_id: String = UNIVERSE_2008
## True if universe=… appeared in OS.get_cmdline_user_args() (see _ready).
var set_from_command_line: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("universe="):
			var v := a.get_slice("=", 1).strip_edges()
			if v != "":
				universe_id = v
				set_from_command_line = true
			break


func set_universe(id: String) -> void:
	universe_id = id


func get_data_directory() -> String:
	return "res://universes/%s" % universe_id


func get_manifest_path() -> String:
	return "%s/universe.json" % get_data_directory()


func get_people_generated_path() -> String:
	return "%s/people_generated.json" % get_data_directory()
