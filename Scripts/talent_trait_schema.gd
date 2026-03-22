class_name TalentTraitSchema

## Canonical storage on `people.json` rows: flat keys (`"traits.ACT"`, …).
## Design reference: `res://Data/other files/talent_trait_dictionary.csv`.

const KEY_ACT := "traits.ACT"
const KEY_WRI := "traits.WRI"
const KEY_BCN := "traits.BCN"
const KEY_LOG := "traits.LOG"
const KEY_COM := "traits.COM"
const KEY_DRM := "traits.DRM"
const KEY_DIST := "traits.DIST"
const KEY_WVW := "traits.WVW"
const KEY_EDY := "traits.EDY"
const KEY_VUL := "traits.VUL"
const KEY_STM := "traits.STM"
const KEY_EGO := "traits.EGO"
const KEY_PRO := "traits.PRO"

## Dashboard column order (short labels → person dict field).
const DASHBOARD_COLUMNS: Array = [
	{"title": "Fame", "kind": "top", "key": "Fame"},
	{"title": "App", "kind": "top", "key": "Attractiveness"},
	{"title": "ACT", "kind": "trait", "key": KEY_ACT},
	{"title": "WRI", "kind": "trait", "key": KEY_WRI},
	{"title": "BCN", "kind": "trait", "key": KEY_BCN},
	{"title": "LOG", "kind": "trait", "key": KEY_LOG},
	{"title": "COM", "kind": "trait", "key": KEY_COM},
	{"title": "DRM", "kind": "trait", "key": KEY_DRM},
	{"title": "Dist", "kind": "trait", "key": KEY_DIST},
	{"title": "WVw", "kind": "trait", "key": KEY_WVW},
	{"title": "En", "kind": "trait", "key": KEY_EDY},
	{"title": "Vul", "kind": "trait", "key": KEY_VUL},
	{"title": "Sta", "kind": "trait", "key": KEY_STM},
	{"title": "Ego", "kind": "trait", "key": KEY_EGO},
	{"title": "Pro", "kind": "trait", "key": KEY_PRO},
]


static func read_top_field(person: Dictionary, key: String) -> float:
	return _num(person.get(key, 0))


static func read_trait(person: Dictionary, trait_key: String) -> float:
	return _num(person.get(trait_key, 0))


static func _num(v) -> float:
	if v is String:
		return float(v) if v.is_valid_float() else 0.0
	if v is int or v is float:
		return float(v)
	return 0.0
