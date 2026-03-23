class_name TimeSlotTable
extends RefCounted

## Loads time-slot economics CSV. Supports:
## - **Legacy:** `TimeSlot_ID` (e.g. MON0600), DayPart, …, BASE_AD_VALUE
## - **Current:** `Day Code` (0–6 = Sun–Sat), `Time Code` (HH:MM), …, BASE_AD_VALUE — matches `schedule.json` day + time.

const DEFAULT_CSV_PATH := "res://Data/time_slots.csv"

static var _rows_by_id: Dictionary = {}
static var _loaded: bool = false
static var _csv_path_used: String = ""


static func clear_cache() -> void:
	_rows_by_id.clear()
	_loaded = false
	_csv_path_used = ""


static func load_from_csv(path: String = DEFAULT_CSV_PATH) -> Error:
	if _loaded and _csv_path_used == path:
		return OK
	_rows_by_id.clear()
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("TimeSlotTable: could not open %s" % path)
		return ERR_FILE_CANT_OPEN
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n")
	if lines.size() < 2:
		return ERR_INVALID_DATA
	var headers := _split_csv_row(lines[0].strip_edges())
	if headers.is_empty():
		return ERR_INVALID_DATA
	var has_legacy_id := headers.has("TimeSlot_ID")
	var has_day_time := headers.has("Day Code") and headers.has("Time Code")
	if not has_legacy_id and not has_day_time:
		push_error("TimeSlotTable: CSV needs either TimeSlot_ID or Day Code + Time Code columns.")
		return ERR_INVALID_DATA
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		var parts := _split_csv_row(line)
		if parts.size() < headers.size():
			continue
		var row := {}
		for j in headers.size():
			row[headers[j]] = parts[j]
		var id: String = ""
		if has_legacy_id:
			id = str(row.get("TimeSlot_ID", "")).strip_edges()
		elif has_day_time:
			id = make_slot_key(str(row.get("Day Code", "")).strip_edges(), str(row.get("Time Code", "")).strip_edges())
		if id != "":
			_rows_by_id[id] = row
	_loaded = true
	_csv_path_used = path
	return OK


## Canonical key for schedule alignment: `"0|06:00"` … `"6|23:30"` (day matches schedule JSON, time HH:MM).
static func make_slot_key(day_code: String, time_code: String) -> String:
	return "%s|%s" % [day_code.strip_edges(), _normalize_time(time_code)]


static func _normalize_time(t: String) -> String:
	var s := t.strip_edges()
	if s.is_empty():
		return s
	var parts := s.split(":")
	if parts.size() >= 2:
		var h := parts[0].strip_edges()
		var m := parts[1].strip_edges()
		if h.is_valid_int() and m.is_valid_int():
			return "%02d:%02d" % [int(h), int(m)]
	return s


static func _split_csv_row(line: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var cur := ""
	for i in range(line.length()):
		var c := line[i]
		if c == ",":
			parts.append(cur.strip_edges())
			cur = ""
		else:
			cur += c
	parts.append(cur.strip_edges())
	return parts


static func get_row(time_slot_id: String) -> Dictionary:
	load_from_csv()
	return _rows_by_id.get(time_slot_id, {})


## Lookup by the same `day` / `time` strings as `schedule.json` (e.g. day `"4"`, time `"22:00"`).
static func get_row_for_schedule_day_time(day: String, time: String) -> Dictionary:
	return get_row(make_slot_key(day, time))


static func get_base_ad_value(time_slot_id: String) -> float:
	var r: Dictionary = get_row(time_slot_id)
	var v = r.get("BASE_AD_VALUE", "0")
	var s := str(v)
	return float(s) if s.is_valid_float() else 0.0


static func get_base_ad_value_for_schedule_day_time(day: String, time: String) -> float:
	return get_base_ad_value(make_slot_key(day, time))


static func get_ad_value_dollars(time_slot_id: String, settings = null) -> float:
	var mult := 15000.0
	if settings != null:
		var v = settings.get("ad_slot_value_multiplier")
		if v != null:
			mult = float(v)
	return get_base_ad_value(time_slot_id) * mult


static func get_ad_value_dollars_for_schedule_day_time(day: String, time: String, settings = null) -> float:
	return get_ad_value_dollars(make_slot_key(day, time), settings)
