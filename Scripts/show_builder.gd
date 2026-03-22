class_name ShowBuilder

###############################################################
# show_builder.gd
#
# WHAT THIS FILE DOES (in plain terms)
# ------------------------------------
# The game stores “who works on which show” in your data files: people,
# contracts, show titles, and what *kind* of show it is (sitcom, news, etc.).
#
# This file’s job is to **gather that into one bundle per show** so the rating
# step can score it. It does **not** do any math on quality—it only decides
# **which people belong to the show** and **which skills** we pass along for
# each kind of job (on-camera vs writers vs showrunner).
#
# Each person’s skills live on their record as numbered traits (acting, writing,
# broadcasting, and so on). We only **read** those numbers here.
#
# WHAT GETS HANDED TO THE RATING STEP
# -----------------------------------
# • **What kind of show it is** — e.g. evening news vs sitcom. That matters later
#   because “on-camera” skills are weighted differently for news than for comedy.
#
# • **Everyone who appears on camera** — leads, support, hosts, anchors,
#   co-hosts, reporters. They’re tagged as “lead” or “support” so the rating
#   step can average them differently (stars vs ensemble).
#
# • **The writing room** — staff writers, head writer, and showrunners listed
#   as writers. Head writers and showrunners count **more heavily** when we score
#   the room as a whole.
#
# • **Showrunners listed again separately** — one list for “who runs the show,”
#   because that’s its own ingredient in the final quality mix. News and reality
#   formats use **Executive Producer** contracts for that pillar instead of (or in
#   addition to) Showrunner.
#
# WHY A SHOWRUNNER SHOWS UP TWICE
# -------------------------------
# The showrunner is both **the boss of the story** (writing-room math) and
# **the leadership score** (showrunner pillar). So they appear in the writer
# list *and* the showrunner list. Same person, two roles in the formula.
###############################################################

## Look up one skill number for a person (zero if we never stored that skill).
static func _f(person: Dictionary, trait_id: String) -> float:
	return TalentTraitSchema.read_trait(person, trait_id)


## Skills we care about for **on-camera** people: acting, comedy, drama,
## broadcasting, and the “spectrum” traits (distance, worldview, energy, etc.).
## These feed the “how good is the cast / hosts” part of the model.
static func extract_actor_traits(person: Dictionary) -> Dictionary:
	return {
		"ACT": _f(person, TalentTraitSchema.KEY_ACT),
		"COM": _f(person, TalentTraitSchema.KEY_COM),
		"DRM": _f(person, TalentTraitSchema.KEY_DRM),
		"BCN": _f(person, TalentTraitSchema.KEY_BCN),
		"DIST": _f(person, TalentTraitSchema.KEY_DIST),
		"WVW": _f(person, TalentTraitSchema.KEY_WVW),
		"EDY": _f(person, TalentTraitSchema.KEY_EDY),
		"VUL": _f(person, TalentTraitSchema.KEY_VUL),
	}


## Skills we care about for **writers** (including when a showrunner is counted
## as part of the writing room): writing craft plus comedy vs drama tone.
static func extract_writer_traits(person: Dictionary) -> Dictionary:
	return {
		"WRI": _f(person, TalentTraitSchema.KEY_WRI),
		"COM": _f(person, TalentTraitSchema.KEY_COM),
		"DRM": _f(person, TalentTraitSchema.KEY_DRM),
	}


## Skills we care about for **showrunner leadership**—running the room, tone,
## logistics. Extra traits are carried for possible future rules; the current
## score uses only part of this list.
static func extract_showrunner_traits(person: Dictionary) -> Dictionary:
	return {
		"LOG": _f(person, TalentTraitSchema.KEY_LOG),
		"COM": _f(person, TalentTraitSchema.KEY_COM),
		"DRM": _f(person, TalentTraitSchema.KEY_DRM),
		"DIST": _f(person, TalentTraitSchema.KEY_DIST),
		"WVW": _f(person, TalentTraitSchema.KEY_WVW),
	}


## Build the bundle for one show title: walk every contract for that show,
## find the person, and sort them into the lists above.
static func build_show_object(show_name, people, contracts, shows, showtypes) -> Dictionary:
	var show_entry = null
	for s in shows:
		if s["Show_Name"] == show_name:
			show_entry = s
			break
	if show_entry == null:
		push_error("Show not found: " + show_name)
		return {}

	var show_type_entry = null
	for t in showtypes:
		if t["ShowType_ID"] == show_entry["ShowType_ID"]:
			show_type_entry = t
			break
	if show_type_entry == null:
		push_error("ShowType not found")
		return {}

	var show_type: String = show_type_entry.get("show_type", "")

	var actors: Array = []
	var writers: Array = []
	var showrunners: Array = []
	var leadership_ep := show_type.begins_with("news_") or show_type.begins_with("reality_")

	for c in contracts:
		if c["Show_Name"] != show_name:
			continue
		var person = null
		for p in people:
			if p["Person_Name"] == c["Person_Name"]:
				person = p
				break
		if person == null:
			continue

		var role: String = c["Role"]

		# Faces and voices on screen: “lead” vs “support” changes how we average them later.
		if role == "Lead Actor":
			actors.append({"name": person["Person_Name"], "role": "lead", "traits": extract_actor_traits(person)})
		elif role == "Support Actor":
			actors.append({"name": person["Person_Name"], "role": "support", "traits": extract_actor_traits(person)})
		elif role in ["Host", "Anchor"]:
			# Treated like a lead for scoring (main voice of the show).
			actors.append({"name": person["Person_Name"], "role": "lead", "traits": extract_actor_traits(person)})
		elif role in ["Co-Host", "Reporter"]:
			actors.append({"name": person["Person_Name"], "role": "support", "traits": extract_actor_traits(person)})
		elif role == "Head Writer":
			writers.append({"name": person["Person_Name"], "role": "head", "traits": extract_writer_traits(person)})
		elif role == "Staff Writer":
			writers.append({"name": person["Person_Name"], "role": "staff", "traits": extract_writer_traits(person)})
		elif role == "Showrunner":
			showrunners.append({"name": person["Person_Name"], "traits": extract_showrunner_traits(person)})
			writers.append({"name": person["Person_Name"], "role": "showrunner", "traits": extract_writer_traits(person)})
		elif role == "Executive Producer" and leadership_ep:
			# News and reality use EPs as the leadership pillar (same traits as showrunner in the model).
			showrunners.append({"name": person["Person_Name"], "traits": extract_showrunner_traits(person)})

	return {
		"showType": show_type,
		"actors": actors,
		"writers": writers,
		"showrunners": showrunners
	}
