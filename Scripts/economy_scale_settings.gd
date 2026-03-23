class_name EconomyScaleSettings
extends Resource

## Multiplier applied to each show type's `Cost_Per_Block_x1M` in `showtypes.json`
## to get nominal **USD per 30-minute block** (e.g. 1.25 × 1,000,000 = $1.25M per block).
@export var showtype_cost_block_dollar_scale: float = 1_000_000.0
