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
	set_anchors_preset(PRESET_FULL_RECT)
	if not UniverseConfig.set_from_command_line:
		UniverseConfig.set_universe(_UNIVERSE_IDS[clampi(initial_universe, 0, _UNIVERSE_IDS.size() - 1)])
	_setup_universe_selector()
	_setup_tooltips()
	_load_data()
	_populate_day_filter()
	_populate_shows_network_filter()
	_populate_schedule_network_filter()
	_shows_tree.column_title_clicked.connect(_on_shows_column_clicked)
	_people_tree.column_title_clicked.connect(_on_people_column_clicked)
	_schedule_tree.column_title_clicked.connect(_on_schedule_column_clicked)
	_shows_tree.select_mode = Tree.SELECT_ROW
	_shows_tree.item_selected.connect(func(): _queue_show_detail_refresh())
	_shows_tree.item_mouse_selected.connect(func(_p, _b): _queue_show_detail_refresh())
	_shows_tree.cell_selected.connect(func(): _queue_show_detail_refresh())
	_shows_tree.nothing_selected.connect(_clear_show_detail)
	_shows_filter.text_changed.connect(func(_t): _build_shows_tree())
	_shows_network_filter.item_selected.connect(func(_i):
		_update_shows_network_filter_tooltip()
		_build_shows_tree()
	)
	_people_filter.text_changed.connect(func(_t): _build_people_tree())
	_schedule_day_filter.item_selected.connect(func(_i):
		_update_schedule_day_filter_tooltip()
		_build_schedule_tree()
	)
	_schedule_network_filter.item_selected.connect(func(_i):
		_update_schedule_network_filter_tooltip()
		_build_schedule_tree()
	)
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
	_update_universe_option_tooltip()


func _setup_tooltips() -> void:
	_shows_filter.tooltip_text = "Filter shows by name, show type, or network. Partial text matches any of those fields."
	_people_filter.tooltip_text = "Filter people by person name or assigned show name (partial match)."
	_schedule_day_filter.tooltip_text = "Limit the schedule grid to one weekday, or All."
	_schedule_network_filter.tooltip_text = "Limit the schedule grid to one network, or All."


func _update_universe_option_tooltip() -> void:
	var i := _universe_option.selected
	if i >= 0 and i < _universe_option.item_count:
		_universe_option.tooltip_text = _universe_option.get_item_text(i)


func _update_shows_network_filter_tooltip() -> void:
	var i := _shows_network_filter.selected
	if i >= 0 and i < _shows_network_filter.item_count:
		_shows_network_filter.tooltip_text = _shows_network_filter.get_item_text(i)


func _update_schedule_network_filter_tooltip() -> void:
	var i := _schedule_network_filter.selected
	if i >= 0 and i < _schedule_network_filter.item_count:
		_schedule_network_filter.tooltip_text = _schedule_network_filter.get_item_text(i)


func _update_schedule_day_filter_tooltip() -> void:
	var i := _schedule_day_filter.selected
	if i >= 0 and i < _schedule_day_filter.item_count:
		_schedule_day_filter.tooltip_text = _schedule_day_filter.get_item_text(i)


func _on_universe_selected(option_index: int) -> void:
	var i := clampi(option_index, 0, _UNIVERSE_IDS.size() - 1)
	UniverseConfig.set_universe(_UNIVERSE_IDS[i])
	_update_universe_option_tooltip()
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
	_update_schedule_day_filter_tooltip()


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
	_update_shows_network_filter_tooltip()


func _populate_schedule_network_filter() -> void:
	_schedule_network_filter.clear()
	_schedule_network_filter.add_item("All", 0)
	var network_names = _schedule_data.get("network_names", [])
	for i in network_names.size():
		_schedule_network_filter.add_item(network_names[i], i + 1)
	_schedule_network_filter.selected = 0
	_update_schedule_network_filter_tooltip()


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
		_tree_cell(item, 0, str(slot.get("network_name", slot.get("network_id", ""))))
		_tree_cell(item, 1, day_label)
		_tree_cell(item, 2, str(slot.get("time_range_12h", slot.get("time", ""))))
		_tree_cell(item, 3, str(slot.get("show_name", "")))
		_tree_cell(item, 4, str(slot.get("type_name", slot.get("show_type", ""))))
		_tree_cell(item, 5, _fmt(slot.get("base_show_quality", 0)))
		_tree_cell(item, 6, str(slot.get("time_band", "")))
		_tree_cell(item, 7, _fmt(slot.get("effectiveness", 0)))
		_tree_cell(item, 8, _fmt(slot.get("effective_quality", 0)))
		_tree_cell(item, 9, dur_str)
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
	_show_detail.text = ""
	_show_detail.tooltip_text = ""
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
		_tree_cell(item, 0, r["show_name"])
		_tree_cell(item, 1, str(r.get("network", "")))
		_tree_cell(item, 2, type_name)
		_tree_cell(item, 3, _fmt(result["castScore"]))
		_tree_cell(item, 4, _fmt(result["writingScore"]))
		_tree_cell(item, 5, _fmt(result["showrunnerScore"]))
		_tree_cell(item, 6, _fmt(result["baseShowQuality"]))
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


func _queue_show_detail_refresh() -> void:
	# Tree can finish updating selected_item after this signal; defer so get_selected() is correct.
	call_deferred("_apply_show_detail")


func _clear_show_detail() -> void:
	_show_detail.text = ""
	_show_detail.tooltip_text = ""


func _apply_show_detail() -> void:
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
	var st := str(r.get("show_type", ""))
	var is_news_or_reality := st.begins_with("news_") or st.begins_with("reality_")
	var news_omits_writing: bool = st.begins_with("news_") and result["writers"].is_empty()
	var bb = []
	bb.append("[b]%s[/b]  %s  |  %s\n" % [r["show_name"], network, type_name])
	var lead_col := "Leadership (EP/SR)" if is_news_or_reality else "Showrunner"
	bb.append("Cast score: %s  |  Writing: %s  |  %s: %s\n" % [_fmt(result["castScore"]), _fmt(result["writingScore"]), lead_col, _fmt(result["showrunnerScore"])])
	if news_omits_writing:
		bb.append("Base show quality: %s (news, no writing room: 5/7×cast + 2/7×leadership)\n" % _fmt(result["baseShowQuality"]))
	else:
		bb.append("Base show quality: %s (0.5×cast + 0.3×writing + 0.2×showrunner)\n" % _fmt(result["baseShowQuality"]))

	bb.append("\n[b]Cast (lead 60% / support 40%):[/b]\n")
	for a in result["actors"]:
		bb.append("  • %s (%s): %s\n" % [a["name"], a["role"], _fmt(a["score"])])

	bb.append("\n[b]Writers (head×1.5, showrunner×2, room factor):[/b]\n")
	if result["writers"].is_empty() and st.begins_with("news_"):
		bb.append("  — none listed; base quality uses cast + leadership only.\n")
	else:
		for w in result["writers"]:
			bb.append("  • %s (%s): %s\n" % [w["name"], w["role"], _fmt(w["score"])])

	var lead_title := "Showrunners (avg if multiple)" if not is_news_or_reality else "Executive producers / showrunners (avg if multiple)"
	bb.append("\n[b]%s:[/b]\n" % lead_title)
	for sr in result["showrunners"]:
		bb.append("  • %s: %s\n" % [sr["name"], _fmt(sr["score"])])

	var detail := "".join(bb)
	_show_detail.text = detail
	_show_detail.tooltip_text = _show_detail.get_parsed_text()


func _people_trait_column_count() -> int:
	return TalentTraitSchema.DASHBOARD_COLUMNS.size()


func _people_column_count() -> int:
	return 1 + _people_trait_column_count() + 3


func _build_people_tree() -> void:
	var filter_text = _people_filter.text.strip_edges().to_lower()
	var trait_cols = _people_trait_column_count()
	var col_count = _people_column_count()
	var actor_col = col_count - 1
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
	_sort_people(rows, trait_cols, col_count, actor_col)

	_people_tree.clear()
	var titles: PackedStringArray = ["Name"]
	for col in TalentTraitSchema.DASHBOARD_COLUMNS:
		titles.append(col["title"])
	titles.append_array(["Show", "Role", "On-air"])
	for i in titles.size():
		_people_tree.set_column_title(i, titles[i])
	var root = _people_tree.create_item()

	for row in rows:
		var item = _people_tree.create_item(root)
		for col in range(mini(col_count, row.size())):
			var val = row[col]
			var is_numeric_col = (col >= 1 and col <= trait_cols) or col == actor_col
			var cell := _fmt(val) if is_numeric_col and (val is float or val is int) else str(val)
			_tree_cell(item, col, cell)


func _people_row(p: Dictionary, a: Variant) -> Array:
	var arr: Array = [p["person_name"]]
	for col in TalentTraitSchema.DASHBOARD_COLUMNS:
		arr.append(p[col["title"]])
	if a != null:
		arr.append(a["show_name"])
		arr.append(a["role_label"] if a.get("role_label", "") else a["role"])
		arr.append(a["actor_score"])
	else:
		arr.append("")
		arr.append("")
		arr.append(-1.0)
	return arr


func _sort_people(rows: Array, trait_cols: int, col_count: int, actor_col: int) -> void:
	var col = clampi(_people_sort_col, 0, col_count - 1)
	var asc = _people_sort_asc
	var numeric_cols: Array = []
	for i in range(1, trait_cols + 1):
		numeric_cols.append(i)
	numeric_cols.append(actor_col)
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
	if column >= 0 and column < _people_column_count():
		if _people_sort_col == column:
			_people_sort_asc = !_people_sort_asc
		else:
			_people_sort_col = column
			_people_sort_asc = true
		_build_people_tree()


static func _tree_cell(item: TreeItem, column: int, text: String) -> void:
	item.set_text(column, text)
	item.set_tooltip_text(column, text)


static func _fmt(v) -> String:
	if v is float or v is int:
		return ("%.2f" % v).replace(".00", "")
	return str(v)
