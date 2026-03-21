###############################################################
# ratings_dashboard.gd
#
# UI for sortable, filterable charts of shows and people with ratings.
# Uses RatingsReport for data. Shows tab: list of shows + detail panel
# with full cast/writers/showrunners and the math. People tab: traits
# plus actor score per assignment.
###############################################################

extends Control

## Applied when this scene loads, unless a command-line universe=… was passed (see UniverseConfig).
@export_enum("2008", "fictional") var initial_universe: int = 0

# Report data (cached)
var _show_ratings: Array = []
var _people_with_scores: Array = []
var _schedule_data: Dictionary = {}

const _UNIVERSE_IDS: PackedStringArray = ["2008", "fictional"]

# Sort: column index and direction
var _shows_sort_col: int = 0
var _shows_sort_asc: bool = true
var _people_sort_col: int = 0
var _people_sort_asc: bool = true
var _schedule_sort_col: int = 0
var _schedule_sort_asc: bool = true

@onready var _shows_filter: LineEdit = $MarginContainer/VBoxContainer/TabContainer/Shows/ShowsFilter
@onready var _shows_network_filter: OptionButton = $MarginContainer/VBoxContainer/TabContainer/Shows/ShowsFilterRow2/ShowsNetworkFilter
@onready var _shows_tree: Tree = $MarginContainer/VBoxContainer/TabContainer/Shows/HSplitContainer/ShowsTree
@onready var _show_detail: RichTextLabel = $MarginContainer/VBoxContainer/TabContainer/Shows/HSplitContainer/ShowDetail/DetailScroll/DetailVBox/DetailLabel
@onready var _people_filter: LineEdit = $MarginContainer/VBoxContainer/TabContainer/People/PeopleFilter
@onready var _people_tree: Tree = $MarginContainer/VBoxContainer/TabContainer/People/PeopleTree
@onready var _schedule_day_filter: OptionButton = $MarginContainer/VBoxContainer/TabContainer/Schedule/ScheduleFilterRow/ScheduleDayFilter
@onready var _schedule_network_filter: OptionButton = $MarginContainer/VBoxContainer/TabContainer/Schedule/ScheduleFilterRow/ScheduleNetworkFilter
@onready var _schedule_tree: Tree = $MarginContainer/VBoxContainer/TabContainer/Schedule/ScheduleTree
@onready var _universe_option: OptionButton = $MarginContainer/VBoxContainer/UniverseRow/UniverseOption


func _ready() -> void:
	if not UniverseConfig.set_from_command_line:
		UniverseConfig.set_universe(_UNIVERSE_IDS[clampi(initial_universe, 0, _UNIVERSE_IDS.size() - 1)])
	_setup_universe_selector()
	_load_data()
	_populate_day_filter()
	_populate_shows_network_filter()
	_populate_schedule_network_filter()
	_shows_tree.column_title_clicked.connect(_on_shows_column_clicked)
	_people_tree.column_title_clicked.connect(_on_people_column_clicked)
	_schedule_tree.column_title_clicked.connect(_on_schedule_column_clicked)
	_shows_tree.item_selected.connect(_on_show_selected)
	_shows_filter.text_changed.connect(func(_t): _build_shows_tree())
	_shows_network_filter.item_selected.connect(func(_i): _build_shows_tree())
	_people_filter.text_changed.connect(func(_t): _build_people_tree())
	_schedule_day_filter.item_selected.connect(func(_i): _build_schedule_tree())
	_schedule_network_filter.item_selected.connect(func(_i): _build_schedule_tree())
	_build_shows_tree()
	_build_people_tree()
	_build_schedule_tree()


func _setup_universe_selector() -> void:
	_universe_option.clear()
	_universe_option.add_item("2008 (historical)", 0)
	_universe_option.add_item("Fictional", 1)
	var cur := UniverseConfig.universe_id
	var idx := 0
	for i in _UNIVERSE_IDS.size():
		if _UNIVERSE_IDS[i] == cur:
			idx = i
			break
	_universe_option.select(idx)
	if not _universe_option.item_selected.is_connected(_on_universe_selected):
		_universe_option.item_selected.connect(_on_universe_selected)


func _on_universe_selected(option_index: int) -> void:
	var i := clampi(option_index, 0, _UNIVERSE_IDS.size() - 1)
	UniverseConfig.set_universe(_UNIVERSE_IDS[i])
	_load_data()
	_populate_day_filter()
	_populate_shows_network_filter()
	_populate_schedule_network_filter()
	_build_shows_tree()
	_build_people_tree()
	_build_schedule_tree()


func _load_data() -> void:
	_show_ratings = RatingsReport.get_all_show_ratings()
	_people_with_scores = RatingsReport.get_all_people_with_scores()
	_schedule_data = RatingsReport.get_resolved_schedule_with_ratings()


func _populate_day_filter() -> void:
	_schedule_day_filter.clear()
	_schedule_day_filter.add_item("All", 0)
	for i in range(7):
		var labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
		_schedule_day_filter.add_item(labels[i], i + 1)
	_schedule_day_filter.selected = 0


func _populate_shows_network_filter() -> void:
	var seen = {}
	for r in _show_ratings:
		var n = r.get("network", "")
		if n != "" and not seen.has(n):
			seen[n] = true
	var nets = seen.keys()
	nets.sort()
	_shows_network_filter.clear()
	_shows_network_filter.add_item("All", 0)
	for i in nets.size():
		_shows_network_filter.add_item(nets[i], i + 1)
	_shows_network_filter.selected = 0


func _populate_schedule_network_filter() -> void:
	_schedule_network_filter.clear()
	_schedule_network_filter.add_item("All", 0)
	var network_names = _schedule_data.get("network_names", [])
	for i in network_names.size():
		_schedule_network_filter.add_item(network_names[i], i + 1)
	_schedule_network_filter.selected = 0


func _build_schedule_tree() -> void:
	var day_idx = _schedule_day_filter.selected
	var net_idx = _schedule_network_filter.selected
	var day_keys = _schedule_data.get("days", ["0", "1", "2", "3", "4", "5", "6"])
	var day_labels = _schedule_data.get("day_labels", ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
	var networks = _schedule_data.get("networks", [])
	var all_slots = _schedule_data.get("slots", [])

	var filtered = []
	for slot in all_slots:
		if day_idx >= 1 and day_idx <= 7:
			var want_day = day_keys[day_idx - 1]
			if slot["day"] != want_day:
				continue
		if net_idx >= 1 and net_idx <= networks.size():
			if slot["network_id"] != networks[net_idx - 1]:
				continue
		filtered.append(slot)
	_sort_schedule_slots(filtered)

	_schedule_tree.clear()
	_schedule_tree.set_column_title(0, "Network")
	_schedule_tree.set_column_title(1, "Day")
	_schedule_tree.set_column_title(2, "Time")
	_schedule_tree.set_column_title(3, "Show Name")
	_schedule_tree.set_column_title(4, "Show Type")
	_schedule_tree.set_column_title(5, "Base Q")
	_schedule_tree.set_column_title(6, "Band")
	_schedule_tree.set_column_title(7, "Eff")
	_schedule_tree.set_column_title(8, "Effective Q")
	_schedule_tree.set_column_title(9, "Duration")
	var root = _schedule_tree.create_item()
	for slot in filtered:
		var item = _schedule_tree.create_item(root)
		var day_label = day_labels[int(slot["day"])] if str(slot["day"]).is_valid_int() else str(slot["day"])
		var dur_mins = slot.get("duration_mins", slot.get("blocks", 0) * 30)
		var dur_str = str(dur_mins) + " min"
		item.set_text(0, slot.get("network_name", slot.get("network_id", "")))
		item.set_text(1, day_label)
		item.set_text(2, slot.get("time_range_12h", slot.get("time", "")))
		item.set_text(3, slot.get("show_name", ""))
		item.set_text(4, slot.get("type_name", slot.get("show_type", "")))
		item.set_text(5, _fmt(slot.get("base_show_quality", 0)))
		item.set_text(6, slot.get("time_band", ""))
		item.set_text(7, _fmt(slot.get("effectiveness", 0)))
		item.set_text(8, _fmt(slot.get("effective_quality", 0)))
		item.set_text(9, dur_str)
		item.set_metadata(0, slot)


func _sort_schedule_slots(filtered: Array) -> void:
	var col = clampi(_schedule_sort_col, 0, 9)
	var asc = _schedule_sort_asc
	var keys = ["network_name", "day", "time_range_12h", "show_name", "type_name", "base_show_quality", "time_band", "effectiveness", "effective_quality", "duration_mins"]
	var key = keys[col] if col < keys.size() else keys[0]
	var numeric_keys = ["base_show_quality", "effectiveness", "effective_quality", "duration_mins"]
	var is_numeric = key in numeric_keys
	filtered.sort_custom(func(a, b):
		var va: Variant = a.get(key, 0) if is_numeric else a.get(key, "")
		var vb: Variant = b.get(key, 0) if is_numeric else b.get(key, "")
		if key == "day":
			var na = int(va) if str(va).is_valid_int() else 0
			var nb = int(vb) if str(vb).is_valid_int() else 0
			return (na < nb) if asc else (na > nb)
		if va is int or va is float:
			return (va < vb) if asc else (va > vb)
		if vb is int or vb is float:
			va = str(va)
			vb = str(vb)
		return (va as String).naturalnocasecmp_to(vb as String) < 0 if asc else (va as String).naturalnocasecmp_to(vb as String) > 0
	)


func _on_schedule_column_clicked(column: int, _mouse_button_index: int = 0) -> void:
	if column >= 0 and column < 10:
		if _schedule_sort_col == column:
			_schedule_sort_asc = !_schedule_sort_asc
		else:
			_schedule_sort_col = column
			_schedule_sort_asc = true
		_build_schedule_tree()


func _build_shows_tree() -> void:
	var filter_text = _shows_filter.text.strip_edges().to_lower()
	var net_idx = _shows_network_filter.selected
	var want_network = "" if net_idx <= 0 else _shows_network_filter.get_item_text(net_idx)

	var rows = []
	for r in _show_ratings:
		var nw = r.get("network", "")
		if want_network != "" and nw != want_network:
			continue
		var name_lower = r["show_name"].to_lower()
		var type_lower = (r.get("type_name", r["show_type"]) as String).to_lower()
		var net_lower = nw.to_lower()
		if filter_text.is_empty() or filter_text in name_lower or filter_text in type_lower or filter_text in net_lower:
			rows.append(r)

	_sort_shows(rows)

	_shows_tree.clear()
	_shows_tree.set_column_title(0, "Show Name")
	_shows_tree.set_column_title(1, "Network")
	_shows_tree.set_column_title(2, "Show Type")
	_shows_tree.set_column_title(3, "Cast")
	_shows_tree.set_column_title(4, "Writing")
	_shows_tree.set_column_title(5, "Showrunner")
	_shows_tree.set_column_title(6, "Base Quality")
	var root = _shows_tree.create_item()

	for r in rows:
		var result = r["result"]
		var item = _shows_tree.create_item(root)
		var type_name = r.get("type_name", r["show_type"])
		item.set_text(0, r["show_name"])
		item.set_text(1, r.get("network", ""))
		item.set_text(2, type_name)
		item.set_text(3, _fmt(result["castScore"]))
		item.set_text(4, _fmt(result["writingScore"]))
		item.set_text(5, _fmt(result["showrunnerScore"]))
		item.set_text(6, _fmt(result["baseShowQuality"]))
		item.set_metadata(0, r)


func _sort_shows(rows: Array) -> void:
	var col = _shows_sort_col
	var asc = _shows_sort_asc
	var keys = ["show_name", "network", "type_name", "castScore", "writingScore", "showrunnerScore", "baseShowQuality"]
	var key = keys[clampi(col, 0, keys.size() - 1)]
	rows.sort_custom(func(a, b):
		var va = _show_sort_value(a, key)
		var vb = _show_sort_value(b, key)
		if va is String and vb is String:
			return (va as String).naturalnocasecmp_to(vb as String) < 0 if asc else (va as String).naturalnocasecmp_to(vb as String) > 0
		return (va < vb) if asc else (va > vb)
	)


func _show_sort_value(r: Dictionary, key: String):
	var res = r.get("result", {})
	match key:
		"show_name": return r.get("show_name", "")
		"network": return r.get("network", "")
		"type_name": return r.get("type_name", r.get("show_type", ""))
		"castScore": return res.get("castScore", 0.0)
		"writingScore": return res.get("writingScore", 0.0)
		"showrunnerScore": return res.get("showrunnerScore", 0.0)
		"baseShowQuality": return res.get("baseShowQuality", 0.0)
	return r.get(key, "")


func _on_shows_column_clicked(column: int, _mouse_button_index: int = 0) -> void:
	if column >= 0 and column < 7:
		if _shows_sort_col == column:
			_shows_sort_asc = !_shows_sort_asc
		else:
			_shows_sort_col = column
			_shows_sort_asc = true
		_build_shows_tree()


func _on_show_selected() -> void:
	var item = _shows_tree.get_selected()
	if item == null:
		_show_detail.text = ""
		return
	var meta = item.get_metadata(0)
	if meta == null:
		_show_detail.text = ""
		return
	var r = meta
	var result = r["result"]
	var type_name = r.get("type_name", r["show_type"])
	var network = r.get("network", "")
	var bb = []
	bb.append("[b]%s[/b]  %s  |  %s\n" % [r["show_name"], network, type_name])
	bb.append("Cast score: %s  |  Writing: %s  |  Showrunner: %s\n" % [_fmt(result["castScore"]), _fmt(result["writingScore"]), _fmt(result["showrunnerScore"])])
	bb.append("Base show quality: %s (0.5×cast + 0.3×writing + 0.2×showrunner)\n" % _fmt(result["baseShowQuality"]))

	bb.append("\n[b]Cast (lead 60% / support 40%):[/b]\n")
	for a in result["actors"]:
		bb.append("  • %s (%s): %s\n" % [a["name"], a["role"], _fmt(a["score"])])

	bb.append("\n[b]Writers (head×1.5, showrunner×2, room factor):[/b]\n")
	for w in result["writers"]:
		bb.append("  • %s (%s): %s\n" % [w["name"], w["role"], _fmt(w["score"])])

	bb.append("\n[b]Showrunners (avg if multiple):[/b]\n")
	for sr in result["showrunners"]:
		bb.append("  • %s: %s\n" % [sr["name"], _fmt(sr["score"])])

	_show_detail.text = "".join(bb)


func _build_people_tree() -> void:
	var filter_text = _people_filter.text.strip_edges().to_lower()
	# Flatten: one row per person per actor assignment (or one row per person with blank assignment if none)
	var rows = []
	for p in _people_with_scores:
		var name_lower = p["person_name"].to_lower()
		if p["assignments"].is_empty():
			if filter_text.is_empty() or filter_text in name_lower:
				rows.append(_people_row(p, null))
		else:
			for a in p["assignments"]:
				var show_lower = a["show_name"].to_lower()
				if filter_text.is_empty() or filter_text in name_lower or filter_text in show_lower:
					rows.append(_people_row(p, a))
					break  # one row per person: use first assignment for display
	# Actually do one row per assignment so we can see each show
	rows.clear()
	for p in _people_with_scores:
		var name_lower = p["person_name"].to_lower()
		if p["assignments"].is_empty():
			if filter_text.is_empty() or filter_text in name_lower:
				rows.append(_people_row(p, null))
		else:
			for a in p["assignments"]:
				var show_lower = a["show_name"].to_lower()
				if filter_text.is_empty() or filter_text in name_lower or filter_text in show_lower:
					rows.append(_people_row(p, a))
	_sort_people(rows)

	_people_tree.clear()
	var titles = ["Name", "Fame", "P", "C", "W", "I", "ED", "DC", "SH", "CT", "TI", "BF", "LC", "CC", "Show", "Role", "Actor"]
	for i in titles.size():
		_people_tree.set_column_title(i, titles[i])
	var root = _people_tree.create_item()

	for row in rows:
		var item = _people_tree.create_item(root)
		for col in range(min(18, row.size())):
			var val = row[col]
			var is_numeric_col = (col >= 1 and col <= 13) or col == 17
			item.set_text(col, _fmt(val) if is_numeric_col and (val is float or val is int) else str(val))


func _people_row(p: Dictionary, a: Variant) -> Array:
	var arr = [
		p["person_name"],
		p["Fame"], p["P"], p["C"], p["W"], p["I"], p["ED"], p["DC"], p["SH"], p["CT"], p["TI"], p["BF"], p["LC"], p["CC"]
	]
	if a != null:
		arr.append(a["show_name"])
		arr.append(a["role_label"] if a.get("role_label", "") else a["role"])
		arr.append(a["actor_score"])  # keep numeric for sorting
	else:
		arr.append("")
		arr.append("")
		arr.append(-1.0)  # sentinel so empty sorts last
	return arr


func _sort_people(rows: Array) -> void:
	var col = clampi(_people_sort_col, 0, 17)
	var asc = _people_sort_asc
	var numeric_cols = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17]  # Fame..CC, Actor
	rows.sort_custom(func(a, b):
		var va = a[col] if col < a.size() else ""
		var vb = b[col] if col < b.size() else ""
		if col in numeric_cols:
			var na: float = -999.0
			var nb: float = -999.0
			if va is int or va is float:
				na = float(va)
			elif str(va).is_valid_float():
				na = float(va)
			if vb is int or vb is float:
				nb = float(vb)
			elif str(vb).is_valid_float():
				nb = float(vb)
			return (na < nb) if asc else (na > nb)
		# string columns
		var sa = str(va)
		var sb = str(vb)
		var cmp = sa.naturalnocasecmp_to(sb)
		return cmp < 0 if asc else cmp > 0
	)


func _on_people_column_clicked(column: int, _mouse_button_index: int = 0) -> void:
	if column >= 0 and column < 18:
		if _people_sort_col == column:
			_people_sort_asc = !_people_sort_asc
		else:
			_people_sort_col = column
			_people_sort_asc = true
		_build_people_tree()


static func _fmt(v) -> String:
	if v is float or v is int:
		return ("%.2f" % v).replace(".00", "")
	return str(v)
