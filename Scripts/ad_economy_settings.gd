class_name AdEconomySettings
extends Resource

## Multiplier for BASE_AD_VALUE in `res://Data/time_slots.csv`.
## Example: base 12.0 × 15000 = 180,000 nominal dollars per 30-minute slot (tune for your economy).
@export var ad_slot_value_multiplier: float = 15000.0
