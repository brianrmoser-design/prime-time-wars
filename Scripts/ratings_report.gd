class_name RatingsReport

###############################################################
# ratings_report.gd
#
# Retrieves and aggregates data for the ratings dashboard:
# - All shows with full rating breakdowns (cast, writers, showrunners, math)
# - All people with talent traits plus on-air score per assignment
###############################################################

###############################################################
# get_all_show_ratings
#
# Returns an array of dictionaries, one per show:
#   show_name, show_type, result (full rate_show output: actors, writers,
#   showrunners, castScore, writingScore, showrunnerScore, baseShowQuality)
###############################################################

static func get_all_show_ratings() -> Array:
	var data = DataLoader.load_data()
	var people = data["people"]
	var contracts = data["contracts"]
	var shows = data["shows"]
	var showtypes = data["showtypes"]

	var type_id_to_name = {}
	for t in showtypes:
		type_id_to_name[t["ShowType_ID"]] = t.get("TypeName", t.get("show_type", ""))

	var out = []
	for show_entry in shows:
		var show_name = show_entry["Show_Name"]
		var show_obj = ShowBuilder.build_show_object(show_name, people, contracts, shows, showtypes)
		if show_obj.is_empty():
			continue
		var result = RatingEngine.rate_show(show_obj)
		var type_id = show_entry.get("ShowType_ID", "")
		var type_name = type_id_to_name.get(type_id, show_obj["showType"])
		out.append({
			"show_name": show_name,
			"show_type": show_obj["showType"],
			"type_name": type_name,
			"network": show_entry.get("Network", ""),
			"result": result
		})
	return out


###############################################################
# get_all_people_with_scores
#
# Returns an array of dictionaries, one per person:
#   person_name, person_id, columns from TalentTraitSchema.DASHBOARD_COLUMNS (title → value),
#   assignments: [ { show_name, show_type, role, actor_score } ]  (on-air roles only)
###############################################################

static func get_all_people_with_scores() -> Array:
	var data = DataLoader.load_data()
	var people = data["people"]
	var contracts = data["contracts"]
	var shows = data["shows"]
	var showtypes = data["showtypes"]

	var show_type_by_name = {}
	for show_entry in shows:
		var show_name = show_entry["Show_Name"]
		for t in showtypes:
			if t["ShowType_ID"] == show_entry["ShowType_ID"]:
				show_type_by_name[show_name] = t.get("show_type", "")
				break

	var out: Array = []
	for p in people:
		var name: String = p["Person_Name"]
		var row: Dictionary = {
			"person_name": name,
			"person_id": p.get("Person_ID", ""),
			"assignments": []
		}
		for col in TalentTraitSchema.DASHBOARD_COLUMNS:
			var title: String = col["title"]
			if col["kind"] == "top":
				row[title] = TalentTraitSchema.read_top_field(p, col["key"])
			else:
				row[title] = TalentTraitSchema.read_trait(p, col["key"])

		for c in contracts:
			if c["Person_Name"] != name:
				continue
			var sn = c["Show_Name"]
			var role = c["Role"]
			var show_type: String = show_type_by_name.get(sn, "")
			var is_actor_role = (role == "Lead Actor" or role == "Support Actor" or role in ["Host", "Anchor", "Co-Host", "Reporter"])
			if not is_actor_role:
				continue
			var traits = ShowBuilder.extract_actor_traits(p)
			var actor_score: float = RatingEngine.compute_on_air_score(traits, show_type)
			var role_key = "lead"
			if role in ["Support Actor", "Co-Host", "Reporter"]:
				role_key = "support"
			elif role in ["Lead Actor", "Host", "Anchor"]:
				role_key = "lead"
			row["assignments"].append({
				"show_name": sn,
				"show_type": show_type,
				"role": role_key,
				"role_label": role,
				"actor_score": actor_score
			})

		out.append(row)
	return out


###############################################################
# People export (full records + every contract rating kind)
#
# Each row is the person dict from data, plus `assignments`: per contract
# with on_air / writer / showrunner scores (same engine as dashboard & shows).
###############################################################

static func _show_type_by_name(shows: Array, showtypes: Array) -> Dictionary:
	var out := {}
	for show_entry in shows:
		var show_name = show_entry["Show_Name"]
		for t in showtypes:
			if t["ShowType_ID"] == show_entry["ShowType_ID"]:
				out[show_name] = t.get("show_type", "")
				break
	return out


## One entry per contract line; Showrunner produces writer + showrunner rows (matches ShowBuilder).
static func build_assignment_ratings_for_person(
	p: Dictionary,
	contracts: Array,
	show_type_by_name: Dictionary
) -> Array:
	var name: String = str(p.get("Person_Name", ""))
	var out: Array = []
	var w_traits := ShowBuilder.extract_writer_traits(p)
	var sr_traits := ShowBuilder.extract_showrunner_traits(p)
	var writer_score: float = RatingEngine.compute_writer_score(w_traits)
	var sr_score: float = RatingEngine.compute_showrunner_score(sr_traits)

	for c in contracts:
		if str(c.get("Person_Name", "")) != name:
			continue
		var sn: String = str(c.get("Show_Name", ""))
		var role: String = str(c.get("Role", ""))
		var st: String = str(show_type_by_name.get(sn, ""))
		var a_traits := ShowBuilder.extract_actor_traits(p)
		var on_air := RatingEngine.compute_on_air_score(a_traits, st)

		if role in ["Lead Actor", "Host", "Anchor"]:
			out.append(
				{"show_name": sn, "show_type": st, "role_label": role, "rating_kind": "on_air", "lead_or_support": "lead", "score": on_air}
			)
		elif role in ["Support Actor", "Co-Host", "Reporter"]:
			out.append(
				{
					"show_name": sn,
					"show_type": st,
					"role_label": role,
					"rating_kind": "on_air",
					"lead_or_support": "support",
					"score": on_air
				}
			)
		elif role == "Judge":
			out.append(
				{"show_name": sn, "show_type": st, "role_label": role, "rating_kind": "on_air", "lead_or_support": "lead", "score": on_air}
			)
		elif role in ["Head Writer", "Staff Writer"]:
			out.append({"show_name": sn, "show_type": st, "role_label": role, "rating_kind": "writer", "score": writer_score})
		elif role == "Showrunner":
			out.append({"show_name": sn, "show_type": st, "role_label": role, "rating_kind": "writer", "score": writer_score})
			out.append({"show_name": sn, "show_type": st, "role_label": role, "rating_kind": "showrunner", "score": sr_score})
		elif role == "Executive Producer":
			out.append({"show_name": sn, "show_type": st, "role_label": role, "rating_kind": "showrunner", "score": sr_score})
	return out


## Full person rows: duplicate of each `people.json` row plus `assignments` (all rating lines).
static func get_all_people_export_rows() -> Array:
	var data: Dictionary = DataLoader.load_data()
	var people: Array = data["people"]
	var contracts: Array = data["contracts"]
	var shows: Array = data["shows"]
	var showtypes: Array = data["showtypes"]
	var st_map: Dictionary = _show_type_by_name(shows, showtypes)
	var out: Array = []
	for p in people:
		var row: Dictionary = (p as Dictionary).duplicate(true)
		row["assignments"] = build_assignment_ratings_for_person(p, contracts, st_map)
		out.append(row)
	return out


static func get_people_ratings_export_document() -> Dictionary:
	return {
		"universe_id": UniverseConfig.universe_id,
		"export_version": 1,
		"generated_at": Time.get_datetime_string_from_system(),
		"people": get_all_people_export_rows()
	}


static func export_people_ratings_to_json_string() -> String:
	return JSON.stringify(get_people_ratings_export_document(), "\t")


static func _csv_escape_cell(s: String) -> String:
	if s.find(",") >= 0 or s.find("\"") >= 0 or s.find("\n") >= 0 or s.find("\r") >= 0:
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s


static func export_people_ratings_to_csv_string() -> String:
	var rows: Array = get_all_people_export_rows()
	var trait_keys: Array[String] = [
		TalentTraitSchema.KEY_ACT,
		TalentTraitSchema.KEY_WRI,
		TalentTraitSchema.KEY_BCN,
		TalentTraitSchema.KEY_LOG,
		TalentTraitSchema.KEY_COM,
		TalentTraitSchema.KEY_DRM,
		TalentTraitSchema.KEY_DIST,
		TalentTraitSchema.KEY_WVW,
		TalentTraitSchema.KEY_EDY,
		TalentTraitSchema.KEY_VUL,
		TalentTraitSchema.KEY_STM,
		TalentTraitSchema.KEY_EGO,
		TalentTraitSchema.KEY_PRO,
		TalentTraitSchema.KEY_VICE
	]
	var header: PackedStringArray = PackedStringArray(
		[
			"Person_ID",
			"Person_Name",
			"DOB",
			"Fame",
			"Attractiveness",
			"Ethnicity",
			"PlaceOfBirth"
		]
	)
	for tk in trait_keys:
		header.append(tk.replace("traits.", "trait_"))
	header.append("assignments_json")
	var lines: Array[String] = []
	var hdr_parts: PackedStringArray = PackedStringArray()
	for i in header.size():
		hdr_parts.append(_csv_escape_cell(header[i]))
	lines.append(",".join(hdr_parts))
	for row in rows:
		var vals: PackedStringArray = PackedStringArray()
		vals.append(_csv_escape_cell(str(row.get("Person_ID", ""))))
		vals.append(_csv_escape_cell(str(row.get("Person_Name", ""))))
		vals.append(_csv_escape_cell(str(row.get("DOB", ""))))
		vals.append(_csv_escape_cell(str(row.get("Fame", ""))))
		vals.append(_csv_escape_cell(str(row.get("Attractiveness", ""))))
		vals.append(_csv_escape_cell(str(row.get("Ethnicity", ""))))
		vals.append(_csv_escape_cell(str(row.get("PlaceOfBirth", ""))))
		for tk in trait_keys:
			vals.append(_csv_escape_cell(str(row.get(tk, ""))))
		vals.append(_csv_escape_cell(JSON.stringify(row.get("assignments", []))))
		lines.append(",".join(vals))
	return "\n".join(lines)


static func save_people_ratings_export_json(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("RatingsReport: could not write %s" % path)
		return false
	f.store_string(export_people_ratings_to_json_string())
	f.close()
	return true


static func save_people_ratings_export_csv(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("RatingsReport: could not write %s" % path)
		return false
	f.store_string(export_people_ratings_to_csv_string())
	f.close()
	return true


static func _num(v) -> float:
	if v is String:
		return float(v) if v.is_valid_float() else 0.0
	if v is int or v is float:
		return float(v)
	return 0.0


###############################################################
# Schedule: time bands (day keys "0"-"6" = Sunday through Saturday)
# 06:00-11:59 Morning, 12:00-16:59 Daytime, 17:00-19:59 Evening,
# 20:00-22:59 Prime, 23:00-05:59 Late
###############################################################

const TIME_BAND_MORNING := "Morning"
const TIME_BAND_DAYTIME := "Daytime"
const TIME_BAND_EVENING := "Evening"
const TIME_BAND_PRIME := "Prime"
const TIME_BAND_LATE := "Late"

static func _mins_from_time(time_str: String) -> int:
	var parts = time_str.split(":")
	var h = int(parts[0]) if parts.size() >= 1 and parts[0].is_valid_int() else 0
	var m = int(parts[1]) if parts.size() >= 2 and parts[1].is_valid_int() else 0
	return h * 60 + m


static func _time_to_12h(time_str: String) -> String:
	var mins = _mins_from_time(time_str)
	var h = int(mins / 60.0) % 24
	var m = mins % 60
	if h == 0:
		return "12:%02da" % m
	if h < 12:
		return "%d:%02da" % [h, m]
	if h == 12:
		return "12:%02dp" % m
	return "%d:%02dp" % [h - 12, m]


static func _time_to_12h_range(time_str: String, blocks: int) -> String:
	var start_mins = _mins_from_time(time_str)
	var end_mins = start_mins + blocks * 30
	var start_h = int(start_mins / 60.0) % 24
	var start_m = start_mins % 60
	var end_h = int(end_mins / 60.0) % 24
	var end_m = end_mins % 60
	var start_s = ""
	var end_s = ""
	if start_h == 0:
		start_s = "12:%02da" % start_m
	elif start_h < 12:
		start_s = "%d:%02da" % [start_h, start_m]
	elif start_h == 12:
		start_s = "12:%02dp" % start_m
	else:
		start_s = "%d:%02dp" % [start_h - 12, start_m]
	if end_h == 0:
		end_s = "12:%02da" % end_m
	elif end_h < 12:
		end_s = "%d:%02da" % [end_h, end_m]
	elif end_h == 12:
		end_s = "12:%02dp" % end_m
	else:
		end_s = "%d:%02dp" % [end_h - 12, end_m]
	return start_s + "-" + end_s


static func _time_to_band(time_str: String) -> String:
	var mins = _mins_from_time(time_str)
	if mins >= 6 * 60 and mins < 12 * 60:
		return TIME_BAND_MORNING
	if mins >= 12 * 60 and mins < 17 * 60:
		return TIME_BAND_DAYTIME
	if mins >= 17 * 60 and mins < 20 * 60:
		return TIME_BAND_EVENING
	if mins >= 20 * 60 and mins < 23 * 60:
		return TIME_BAND_PRIME
	return TIME_BAND_LATE


static func _effectiveness_for_band(showtype_entry: Dictionary, band: String) -> float:
	var key = ""
	match band:
		TIME_BAND_MORNING: key = "Morning_Eff"
		TIME_BAND_DAYTIME: key = "Daytime_Eff"
		TIME_BAND_EVENING: key = "Evening_Eff"
		TIME_BAND_PRIME: key = "Prime_Eff"
		TIME_BAND_LATE: key = "Late_Eff"
		_: return 1.0
	return _num(showtype_entry.get(key, 0))


###############################################################
# get_resolved_schedule_with_ratings
###############################################################

static func get_resolved_schedule_with_ratings() -> Dictionary:
	var data = DataLoader.load_data()
	var people = data["people"]
	var contracts = data["contracts"]
	var shows = data["shows"]
	var showtypes = data["showtypes"]
	var schedule = data.get("schedule", {})
	var networks_list = data.get("networks", [])

	var id_to_name = DataLoader.get_show_id_to_name(shows)
	var show_entry_by_id = {}
	for s in shows:
		show_entry_by_id[s["Show_ID"]] = s
	var showtype_by_type_id = {}
	for t in showtypes:
		showtype_by_type_id[t["ShowType_ID"]] = t
	var network_id_to_name = {}
	for n in networks_list:
		network_id_to_name[n["Network_ID"]] = n.get("Network_Name", n["Network_ID"])

	var slots = []
	var network_ids = []
	var day_keys = ["0", "1", "2", "3", "4", "5", "6"]

	for net_id in schedule.keys():
		if net_id not in network_ids:
			network_ids.append(net_id)
	var networks_sorted = network_ids
	networks_sorted.sort()
	var network_names = []
	for nid in networks_sorted:
		network_names.append(network_id_to_name.get(nid, nid))

	for net_id in networks_sorted:
		var net_data = schedule.get(net_id, {})
		for day in day_keys:
			var day_slots = net_data.get(day, [])
			for slot in day_slots:
				var show_id = slot.get("show", "")
				var show_name = id_to_name.get(show_id, "")
				var time_str = slot.get("time", "")
				var blocks = slot.get("blocks", 0)
				if show_name == "":
					slots.append({
						"network_id": net_id,
						"network_name": network_id_to_name.get(net_id, net_id),
						"day": day,
						"time": time_str,
						"time_range_12h": _time_to_12h_range(time_str, blocks),
						"duration_mins": blocks * 30,
						"show_id": show_id,
						"show_name": "",
						"blocks": blocks,
						"show_type": "",
						"type_name": "",
						"base_show_quality": 0.0,
						"cast_score": 0.0,
						"writing_score": 0.0,
						"showrunner_score": 0.0,
						"time_band": _time_to_band(time_str),
						"effectiveness": 0.0,
						"effective_quality": 0.0
					})
					continue
				var show_obj = ShowBuilder.build_show_object(show_name, people, contracts, shows, showtypes)
				var result = RatingEngine.rate_show(show_obj) if not show_obj.is_empty() else {}
				var base_q = (result.get("baseShowQuality", 0.0) as float) if result else 0.0
				var cast_s = (result.get("castScore", 0.0) as float) if result else 0.0
				var writing_s = (result.get("writingScore", 0.0) as float) if result else 0.0
				var sr_s = (result.get("showrunnerScore", 0.0) as float) if result else 0.0
				var show_entry = show_entry_by_id.get(show_id, {})
				var type_id = show_entry.get("ShowType_ID", "")
				var showtype_entry = showtype_by_type_id.get(type_id, {})
				var show_type = show_entry.get("show_type", "")
				var type_name = showtype_entry.get("TypeName", show_type)
				var duration_mins = _num(show_entry.get("Duration_mins", blocks * 30))
				if duration_mins <= 0:
					duration_mins = blocks * 30
				var band = _time_to_band(time_str)
				var eff = _effectiveness_for_band(showtype_entry, band)
				var effective_q = base_q * eff
				slots.append({
					"network_id": net_id,
					"network_name": network_id_to_name.get(net_id, net_id),
					"day": day,
					"time": time_str,
					"time_range_12h": _time_to_12h_range(time_str, blocks),
					"duration_mins": int(duration_mins),
					"show_id": show_id,
					"show_name": show_name,
					"blocks": blocks,
					"show_type": show_type,
					"type_name": type_name,
					"base_show_quality": base_q,
					"cast_score": cast_s,
					"writing_score": writing_s,
					"showrunner_score": sr_s,
					"time_band": band,
					"effectiveness": eff,
					"effective_quality": effective_q
				})
	return {
		"networks": networks_sorted,
		"network_names": network_names,
		"days": day_keys,
		"day_labels": ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
		"slots": slots
	}
