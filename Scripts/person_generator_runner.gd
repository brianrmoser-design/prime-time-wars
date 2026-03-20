extends Node

## Run this scene (F6) to generate people and optionally save to JSON.
## Edit the mode and path below, then run.

enum Mode { FULL_UNIVERSE, REPLACEMENT_BATCH, CUSTOM_BATCH }

@export var mode: Mode = Mode.FULL_UNIVERSE
@export var save_path: String = "res://Data/people_generated.json"
@export var replacement_pool_size: int = 500
@export var custom_batch_size: int = 20
@export var do_save: bool = true

func _ready() -> void:
	var data = DataLoader.load_data()
	var shows: Array = data.get("shows", [])
	var contracts: Array = data.get("contracts", [])
	var existing: Array = data.get("people", [])

	var gen = PersonGenerator.new()
	gen.load_traits_from_project()

	var people: Array = []
	match mode:
		Mode.FULL_UNIVERSE:
			people = gen.generate_full_universe(shows, contracts, 2.0, existing)
			print("Generated full universe: ", people.size(), " people")
		Mode.REPLACEMENT_BATCH:
			people = gen.generate_replacement_batch(replacement_pool_size, 0.02)
			print("Generated replacement batch: ", people.size(), " people")
		Mode.CUSTOM_BATCH:
			people = gen.generate_batch(custom_batch_size, {})
			print("Generated custom batch: ", people.size(), " people")

	if do_save and people.size() > 0:
		if PersonGenerator.save_people_to_json(people, save_path):
			print("Saved to ", save_path)
		else:
			print("Failed to save to ", save_path)
	else:
		print("Not saving (do_save=false or 0 people)")
