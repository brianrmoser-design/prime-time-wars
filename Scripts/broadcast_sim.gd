class_name BroadcastSim
extends RefCounted

const _TimeSlotTable = preload("res://Scripts/time_slot_table.gd")
const _ShowTypeEconomy = preload("res://Scripts/showtype_economy.gd")

## Very simple cash sim: static slot ad table × blocks, minus showtype cost × blocks.
## No ratings→ads, no competition, no talent contracts. Negative cash is allowed and reported.

const STARTING_CASH_PER_NETWORK := 10_000_000.0
const DEFAULT_AD_SETTINGS_PATH := "res://Resources/ad_economy_settings.tres"
const DEFAULT_ECONOMY_SCALE_PATH := "res://Resources/economy_scale_settings.tres"

enum Period { ONE_WEEK, ONE_DAY }


static func _day_keys_for_period(period: Period, day_index: int) -> PackedStringArray:
	var d := clampi(day_index, 0, 6)
	if period == Period.ONE_DAY:
		return PackedStringArray([str(d)])
	var out: PackedStringArray = PackedStringArray()
	for i in 7:
		out.append(str(i))
	return out


static func _load_settings(ad_settings: Variant, economy_scale: Variant) -> Dictionary:
	var ad = ad_settings
	var ec = economy_scale
	if ad == null:
		ad = load(DEFAULT_AD_SETTINGS_PATH)
	if ec == null:
		ec = load(DEFAULT_ECONOMY_SCALE_PATH)
	return {"ad": ad, "economy": ec}


static func _collect_events(
	data: Dictionary,
	day_keys: PackedStringArray,
	ad_settings: Variant,
	economy_scale: Variant
) -> Array:
	var schedule: Dictionary = data.get("schedule", {})
	var shows: Array = data["shows"]
	var showtypes: Array = data["showtypes"]
	var show_entry_by_id := {}
	for s in shows:
		show_entry_by_id[str(s.get("Show_ID", ""))] = s
	var showtype_by_type_id := {}
	for t in showtypes:
		showtype_by_type_id[str(t.get("ShowType_ID", ""))] = t

	_TimeSlotTable.load_from_csv()

	var evs: Array = []
	for net_id in schedule.keys():
		var net_data: Dictionary = schedule[net_id]
		for day in day_keys:
			var day_slots: Array = net_data.get(day, [])
			for slot in day_slots:
				var show_id := str(slot.get("show", ""))
				if show_id.is_empty():
					continue
				var show_entry: Dictionary = show_entry_by_id.get(show_id, {})
				if show_entry.is_empty():
					continue
				var blocks := float(slot.get("blocks", 1))
				if blocks < 1.0:
					blocks = 1.0
				var type_id := str(show_entry.get("ShowType_ID", ""))
				var st_entry: Dictionary = showtype_by_type_id.get(type_id, {})
				var time_str := str(slot.get("time", ""))
				var ad_per_block: float = _TimeSlotTable.get_ad_value_dollars_for_schedule_day_time(
					day, time_str, ad_settings
				)
				var ad: float = ad_per_block * blocks
				var cost: float = _ShowTypeEconomy.cost_usd_for_blocks(st_entry, blocks, economy_scale)
				var day_i := int(day) if str(day).is_valid_int() else 0
				var tmin := RatingsReport._mins_from_time(time_str)
				evs.append(
					{
						"network_id": str(net_id),
						"day": str(day),
						"day_i": day_i,
						"time_mins": tmin,
						"show_id": show_id,
						"show_name": str(show_entry.get("Show_Name", "")),
						"ad_revenue": ad,
						"production_cost": cost,
					}
				)

	evs.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a["day_i"] != b["day_i"]:
				return int(a["day_i"]) < int(b["day_i"])
			if a["time_mins"] != b["time_mins"]:
				return int(a["time_mins"]) < int(b["time_mins"])
			return str(a["network_id"]).naturalnocasecmp_to(str(b["network_id"])) < 0
	)
	return evs


static func _network_name_map(data: Dictionary) -> Dictionary:
	var out := {}
	for n in data.get("networks", []):
		out[str(n.get("Network_ID", ""))] = str(n.get("Network_Name", n.get("Network_ID", "")))
	return out


static func run(
	period: Period = Period.ONE_WEEK,
	day_index: int = 0,
	ad_settings: Variant = null,
	economy_scale: Variant = null
) -> Dictionary:
	var settings := _load_settings(ad_settings, economy_scale)
	var data: Dictionary = DataLoader.load_data()
	var day_keys := _day_keys_for_period(period, day_index)
	var evs: Array = _collect_events(data, day_keys, settings.ad, settings.economy)
	var id_to_name := _network_name_map(data)

	var net_ids: Array = []
	for n in data.get("networks", []):
		net_ids.append(str(n.get("Network_ID", "")))
	net_ids.sort()
	for ev in evs:
		var nid: String = ev["network_id"]
		if not nid in net_ids:
			net_ids.append(nid)
	net_ids.sort()

	var net_rows: Array = []
	for nid in net_ids:
		var cash := STARTING_CASH_PER_NETWORK
		var min_cash := cash
		var ad_sum := 0.0
		var cost_sum := 0.0
		for ev in evs:
			if str(ev["network_id"]) != nid:
				continue
			var a: float = float(ev["ad_revenue"])
			var c: float = float(ev["production_cost"])
			ad_sum += a
			cost_sum += c
			cash += a - c
			min_cash = minf(min_cash, cash)
		var net_pl := ad_sum - cost_sum
		net_rows.append(
			{
				"network_id": nid,
				"network_name": id_to_name.get(nid, nid),
				"starting_cash": STARTING_CASH_PER_NETWORK,
				"total_ad_revenue": ad_sum,
				"total_production_cost": cost_sum,
				"net_pl": net_pl,
				"ending_cash": STARTING_CASH_PER_NETWORK + net_pl,
				"min_cash_during": min_cash,
				"went_negative": min_cash < 0.0 or (STARTING_CASH_PER_NETWORK + net_pl) < 0.0
			}
		)

	var show_map: Dictionary = {}
	for ev in evs:
		var sid: String = ev["show_id"]
		if not show_map.has(sid):
			var se: Dictionary = {}
			for s in data["shows"]:
				if str(s.get("Show_ID", "")) == sid:
					se = s
					break
			show_map[sid] = {
				"show_id": sid,
				"show_name": ev["show_name"],
				"network_name": str(se.get("Network", "")),
				"total_ad_revenue": 0.0,
				"total_production_cost": 0.0
			}
		var g: Dictionary = show_map[sid]
		g["total_ad_revenue"] = float(g["total_ad_revenue"]) + float(ev["ad_revenue"])
		g["total_production_cost"] = float(g["total_production_cost"]) + float(ev["production_cost"])

	var show_rows: Array = show_map.values()
	show_rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a["show_name"]).naturalnocasecmp_to(str(b["show_name"])) < 0
	)
	for g in show_rows:
		var tad: float = float(g["total_ad_revenue"])
		var tc: float = float(g["total_production_cost"])
		g["net_pl"] = tad - tc

	return {
		"period": "one_week" if period == Period.ONE_WEEK else "one_day",
		"day_index": day_index if period == Period.ONE_DAY else -1,
		"starting_cash_per_network": STARTING_CASH_PER_NETWORK,
		"slot_count": evs.size(),
		"networks": net_rows,
		"shows": show_rows
	}


static func get_export_document(
	period: Period,
	day_index: int = 0,
	ad_settings: Variant = null,
	economy_scale: Variant = null
) -> Dictionary:
	var result: Dictionary = run(period, day_index, ad_settings, economy_scale)
	return {
		"universe_id": UniverseConfig.universe_id,
		"export_version": 1,
		"generated_at": Time.get_datetime_string_from_system(),
		"sim": result
	}


static func _csv_escape(s: String) -> String:
	if s.find(",") >= 0 or s.find("\"") >= 0 or s.find("\n") >= 0 or s.find("\r") >= 0:
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s


static func export_to_csv_string(doc: Dictionary) -> String:
	var sim: Dictionary = doc.get("sim", {})
	var lines: PackedStringArray = PackedStringArray()
	lines.append("section," + _csv_escape("universe_id") + "," + _csv_escape(str(doc.get("universe_id", ""))))
	lines.append("section," + _csv_escape("period") + "," + _csv_escape(str(sim.get("period", ""))))
	lines.append("section," + _csv_escape("starting_cash_per_network") + "," + str(sim.get("starting_cash_per_network", 0)))
	lines.append("")
	lines.append("network_id,network_name,starting_cash,total_ad_revenue,total_production_cost,net_pl,ending_cash,min_cash_during,went_negative")
	for r in sim.get("networks", []):
		var row: Dictionary = r
		var parts: PackedStringArray = PackedStringArray(
			[
				_csv_escape(str(row.get("network_id", ""))),
				_csv_escape(str(row.get("network_name", ""))),
				str(row.get("starting_cash", 0)),
				str(row.get("total_ad_revenue", 0)),
				str(row.get("total_production_cost", 0)),
				str(row.get("net_pl", 0)),
				str(row.get("ending_cash", 0)),
				str(row.get("min_cash_during", 0)),
				str(row.get("went_negative", false))
			]
		)
		lines.append(",".join(parts))
	lines.append("")
	lines.append("show_id,show_name,network_name,total_ad_revenue,total_production_cost,net_pl")
	for r in sim.get("shows", []):
		var row2: Dictionary = r
		var parts2: PackedStringArray = PackedStringArray(
			[
				_csv_escape(str(row2.get("show_id", ""))),
				_csv_escape(str(row2.get("show_name", ""))),
				_csv_escape(str(row2.get("network_name", ""))),
				str(row2.get("total_ad_revenue", 0)),
				str(row2.get("total_production_cost", 0)),
				str(row2.get("net_pl", 0))
			]
		)
		lines.append(",".join(parts2))
	return "\n".join(lines)


static func save_export_json(path: String, doc: Dictionary) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("BroadcastSim: could not write %s" % path)
		return false
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	return true


static func save_export_csv(path: String, doc: Dictionary) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("BroadcastSim: could not write %s" % path)
		return false
	f.store_string(export_to_csv_string(doc))
	f.close()
	return true
