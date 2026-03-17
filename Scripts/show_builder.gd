class_name ShowBuilder

###############################################################
# extract_actor_traits
###############################################################

static func extract_actor_traits(person):

	return {
		"P": float(person.get("traits.P", 0)),
		"C": float(person.get("traits.C", 0)),
		"W": float(person.get("traits.W", 0)),
		"I": float(person.get("traits.I", 0)),
		"ED": float(person.get("traits.ED", 0)),
		"DC": float(person.get("traits.DC", 0)),
		"SH": float(person.get("traits.SH", 0)),
		"CT": float(person.get("traits.CT", 0)),
		"TI": float(person.get("traits.TI", 0)),
		"BF": float(person.get("traits.BF", 0)),
		"LC": float(person.get("traits.LC", 0)),
		"CC": float(person.get("traits.CC", 0))
	}


###############################################################
# extract_writer_traits
###############################################################

static func extract_writer_traits(person):

	return {
		"W": float(person.get("traits.W", 0)),
		"ED": float(person.get("traits.ED", 0)),
		"DC": float(person.get("traits.DC", 0)),
		"SH": float(person.get("traits.SH", 0))
	}


###############################################################
# extract_showrunner_traits
###############################################################

static func extract_showrunner_traits(person):

	return {
		"C": float(person.get("traits.C", 0)),
		"W": float(person.get("traits.W", 0)),
		"CC": float(person.get("traits.CC", 0)),
		"LC": float(person.get("traits.LC", 0)),
		"ED": float(person.get("traits.ED", 0)),
		"DC": float(person.get("traits.DC", 0)),
		"SH": float(person.get("traits.SH", 0))
	}


###############################################################
# build_show_object
#
# Direct translation of JS buildShowObject()
###############################################################

static func build_show_object(show_name, people, contracts, shows, showtypes):

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

	var show_type = show_type_entry.get("show_type")

	var actors = []
	var writers = []
	var showrunners = []

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

		var role = c["Role"]

		if role == "Lead Actor":
			actors.append({
				"name": person["Person_Name"],
				"role": "lead",
				"traits": extract_actor_traits(person)
			})

		elif role == "Support Actor":
			actors.append({
				"name": person["Person_Name"],
				"role": "support",
				"traits": extract_actor_traits(person)
			})

		elif role in ["Host", "Anchor"]:
			# Hosts and anchors are scored as lead on-air talent (talk, news, reality, sports).
			actors.append({
				"name": person["Person_Name"],
				"role": "lead",
				"traits": extract_actor_traits(person)
			})

		elif role in ["Co-Host", "Reporter"]:
			# Co-hosts and reporters are scored as support on-air talent.
			actors.append({
				"name": person["Person_Name"],
				"role": "support",
				"traits": extract_actor_traits(person)
			})

		elif role == "Head Writer":
			writers.append({
				"name": person["Person_Name"],
				"role": "head",
				"traits": extract_writer_traits(person)
			})

		elif role == "Staff Writer":
			writers.append({
				"name": person["Person_Name"],
				"role": "staff",
				"traits": extract_writer_traits(person)
			})

		elif role == "Showrunner":

			showrunners.append({
				"name": person["Person_Name"],
				"traits": extract_showrunner_traits(person)
			})

			writers.append({
				"name": person["Person_Name"],
				"role": "showrunner",
				"traits": extract_writer_traits(person)
			})

	return {
		"showType": show_type,
		"actors": actors,
		"writers": writers,
		"showrunners": showrunners
	}
