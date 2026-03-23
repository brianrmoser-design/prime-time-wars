class_name ShowTypeEconomy
extends RefCounted

## JSON key on each showtypes row (see `universes/*/showtypes.json`).
const KEY_COST_PER_BLOCK_X1M := "Cost_Per_Block_x1M"

## Default when no [EconomyScaleSettings] is passed to helpers.
const DEFAULT_BLOCK_DOLLAR_SCALE := 1_000_000.0


static func _num(v) -> float:
	if v is String:
		return float(v) if v.is_valid_float() else 0.0
	if v is int or v is float:
		return float(v)
	return 0.0


## Raw multiplier from JSON (× [member EconomyScaleSettings.showtype_cost_block_dollar_scale] for USD per block).
static func read_cost_per_block_x1m(entry: Dictionary) -> float:
	return _num(entry.get(KEY_COST_PER_BLOCK_X1M, 0.0))


## Nominal USD for one 30-minute production block for this show type.
## Pass `load("res://Resources/economy_scale_settings.tres")` (or any [EconomyScaleSettings]) to override scale.
static func cost_usd_per_block(entry: Dictionary, settings = null) -> float:
	var scale := DEFAULT_BLOCK_DOLLAR_SCALE
	if settings != null:
		var s = settings.get("showtype_cost_block_dollar_scale")
		if s != null:
			scale = float(s)
	return read_cost_per_block_x1m(entry) * scale


## e.g. `blocks` from schedule (each block = 30 min).
static func cost_usd_for_blocks(entry: Dictionary, blocks: float, settings = null) -> float:
	return cost_usd_per_block(entry, settings) * maxf(0.0, blocks)
