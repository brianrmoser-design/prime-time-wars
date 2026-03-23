extends RefCounted

## -----------------------------------------------------------------------------
## Career profile layer for person generation (consolidated from iterative drafts).
##
## This module is intentionally separate from [PersonGenerator] so the math is
## documented in one place. It models a **second axis** beside job archetype:
## - **Archetype** (lead_actor, staff_writer, …) = what kind of contracts they fill.
## - **Career profile** (below) = how their overall ability distribution looks
##   on a 2008-style TV bell curve (journeymen vs phenoms vs suits, etc.).
##
## Evolution of the source drafts (for maintainers):
## - **Draft 0:** Introduced Profile enum, Gaussian “bell” skills, profile governor
##   on ACT/WRI/BCN/LOG, and COM/DRM tied to max(ACT,WRI) via floor/ceiling.
## - **Draft 1:** Added casting/fame/vice/spectrum ideas; was a stub and duplicated
##   concepts—**superseded** by 2+3.
## - **Draft 2:** Unified into one pipeline: refined SUIT/PHENOM curves, creative
##   pool for COM/DRM, skewed STM/PRO/EGO, appearance “star floor,” fame from age.
## - **Draft 3:** Same math as 2 plus optional **demographics** (ethnicity, place
##   of birth) for flavor; does not replace name origin from CSVs.
##
## Obsolete ideas **not** carried forward: duplicate helpers, invalid dict access
## like `stats.ACT` (GDScript needs `stats["ACT"]`), and mixing id/name-only
## person dicts from draft 0 with this project’s Person_ID / traits.* schema.
## -----------------------------------------------------------------------------

## Used for fame vs. career length (matches classic 2008 network-era sim anchor).
const REFERENCE_YEAR := 2008

## Floor/ceiling for rolled skills (draft 2+3; aligns with “no total unknown” floor).
const MIN_SKILL := 20.0
const MAX_SKILL := 100.0

## -----------------------------------------------------------------------------
## Career profile distribution (draft 0–3 agreed on these weights).
## Most industry people are replaceable mid-level talent; a thin tail is elite.
## -----------------------------------------------------------------------------
enum CareerProfile {
	JOURNEYMAN, ## ~60% — reliable mid-level; caps on ACT/WRI so few hit “star” highs.
	SPECIALIST, ## ~25% — strong actor **or** strong writer, not both.
	SUIT, ## ~10% — high LOG (exec/showrunner path); damped on-camera/writing peaks.
	PHENOM, ## ~3% — generational on-camera talent; “network handsome” bias in attractiveness.
	HYPHENATE, ## ~2% — rare elite at both acting and writing (e.g. writer-performer).
}


## Roll which **career shape** this person gets (independent of job archetype).
static func roll_career_profile(rng: RandomNumberGenerator) -> CareerProfile:
	var r := rng.randf()
	if r < 0.60:
		return CareerProfile.JOURNEYMAN
	if r < 0.85:
		return CareerProfile.SPECIALIST
	if r < 0.95:
		return CareerProfile.SUIT
	if r < 0.98:
		return CareerProfile.PHENOM
	return CareerProfile.HYPHENATE


## Gaussian sample (Box–Muller). Used for “natural” talent scatter.
static func roll_bell(rng: RandomNumberGenerator, mean: float, std_dev: float) -> float:
	var u1: float = rng.randf()
	# Avoid log(0) which would explode the transform.
	u1 = maxf(u1, 1e-9)
	var u2: float = rng.randf()
	var z0: float = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return z0 * std_dev + mean


## Core four skills after the profile governor (draft 2/3 structure).
## Returns integer traits in [MIN_SKILL, MAX_SKILL] for ACT, WRI, BCN, LOG.
static func roll_core_four_skills(rng: RandomNumberGenerator, profile: CareerProfile) -> Dictionary:
	var act := roll_bell(rng, 50.0, 15.0)
	var wri := roll_bell(rng, 50.0, 15.0)
	var bcn := roll_bell(rng, 40.0, 20.0)
	var log_cmd := roll_bell(rng, 35.0, 15.0)

	match profile:
		CareerProfile.JOURNEYMAN:
			act = clampf(act, MIN_SKILL, 75.0)
			wri = clampf(wri, MIN_SKILL, 75.0)
		CareerProfile.SPECIALIST:
			if rng.randf() > 0.5:
				# Strong performer, weaker writer — typical “actor’s actor.”
				act = roll_bell(rng, 82.0, 7.0)
				wri = clampf(wri, MIN_SKILL, 45.0)
			else:
				# Strong writer, weaker performer — room/staff heavy.
				wri = roll_bell(rng, 82.0, 7.0)
				act = clampf(act, MIN_SKILL, 45.0)
		CareerProfile.SUIT:
			# Exec / logistics-first: command high, performance writing capped.
			log_cmd = roll_bell(rng, 85.0, 8.0)
			act = clampf(act, MIN_SKILL, 40.0)
			wri = clampf(wri, MIN_SKILL, 40.0)
		CareerProfile.PHENOM:
			# Generational on-camera; writing often secondary.
			act = roll_bell(rng, 94.0, 4.0)
			wri = roll_bell(rng, 45.0, 15.0)
		CareerProfile.HYPHENATE:
			# Rare: credible at both at a high level.
			act = roll_bell(rng, 88.0, 6.0)
			wri = roll_bell(rng, 88.0, 6.0)

	return {
		"ACT": int(round(clampf(act, MIN_SKILL, MAX_SKILL))),
		"WRI": int(round(clampf(wri, MIN_SKILL, MAX_SKILL))),
		"BCN": int(round(clampf(bcn, MIN_SKILL, MAX_SKILL))),
		"LOG": int(round(clampf(log_cmd, MIN_SKILL, MAX_SKILL))),
	}


## -----------------------------------------------------------------------------
## Creative pair (COM/DRM): “you can’t be wildly creative in a lane you can’t
## technically reach.” Draft 2+3: pool is bounded by max(ACT,WRI).
## Each of COM and DRM gets half the floor and half the ceiling band.
## -----------------------------------------------------------------------------
static func roll_com_drm_bounded(
	rng: RandomNumberGenerator,
	act_skill: int,
	wri_skill: int
) -> Dictionary:
	var hi: float = float(max(act_skill, wri_skill))
	var creative_floor: float = hi / 2.0
	var creative_ceil: float = hi + 20.0
	var half_lo: float = creative_floor / 2.0
	var half_hi: float = creative_ceil / 2.0
	var com := clampf(roll_bell(rng, 50.0, 20.0), half_lo, half_hi)
	var drm := clampf(roll_bell(rng, 50.0, 20.0), half_lo, half_hi)
	return {"COM": int(round(com)), "DRM": int(round(drm))}


## Bimodal ego: most are manageable; some are confident; few are “diva” (draft 2/3).
static func roll_ego(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < 0.60:
		return rng.randi_range(30, 50)
	if r < 0.90:
		return rng.randi_range(70, 85)
	return rng.randi_range(90, 100)


## Stamina / professionalism: right-skewed “show up and deliver” (draft 2/3).
static func roll_stm(rng: RandomNumberGenerator) -> int:
	return int(round(clampf(roll_bell(rng, 75.0, 10.0), 30.0, MAX_SKILL)))


static func roll_pro(rng: RandomNumberGenerator) -> int:
	return int(round(clampf(roll_bell(rng, 75.0, 12.0), 20.0, MAX_SKILL)))


## Hidden reliability / substance issues — see talent_trait_dictionary.csv “Vice”.
## ~85% have no notable score (0); tail gets a hidden numeric hook for future events.
static func roll_vice(rng: RandomNumberGenerator) -> int:
	if rng.randf() > 0.15:
		return 0
	return rng.randi_range(40, 95)


## -----------------------------------------------------------------------------
## Attractiveness: baseline bell + “network star floor” for phenoms / hot specialists.
## Still merged with on-screen archetype logic in PersonGenerator.
## -----------------------------------------------------------------------------
static func roll_attractiveness_base(
	rng: RandomNumberGenerator,
	profile: CareerProfile,
	act_after_core: int
) -> int:
	var app_base := roll_bell(rng, 55.0, 18.0)
	if profile == CareerProfile.PHENOM or (
		profile == CareerProfile.SPECIALIST and act_after_core > 80
	):
		app_base = maxf(app_base, rng.randf_range(72.0, 98.0))
	return int(round(clampf(app_base, MIN_SKILL, MAX_SKILL)))


## Fame: career-years × profile multiplier + luck (draft 2/3). Blended with archetype in caller.
static func roll_fame_career_component(
	rng: RandomNumberGenerator,
	birth_year: int,
	profile: CareerProfile
) -> float:
	var age: int = maxi(0, REFERENCE_YEAR - birth_year)
	var career_years: int = maxi(1, age - 22)
	var mult: float = 2.5 if profile == CareerProfile.PHENOM else 0.8
	return float(career_years) * mult + roll_bell(rng, 10.0, 20.0)


## -----------------------------------------------------------------------------
## Optional flavor fields (draft 3). Safe extra keys on people.json; not used by ratings.
## -----------------------------------------------------------------------------

const _ETHNICITIES: Array[String] = [
	"Caucasian",
	"African American",
	"Hispanic",
	"Asian",
	"Middle Eastern",
	"South Asian",
]


## Rough 2008 US TV casting distribution (draft 3 — adjust if you add region-specific pools).
static func roll_ethnicity_2008(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if r < 0.70:
		return _ETHNICITIES[0]
	if r < 0.82:
		return _ETHNICITIES[1]
	if r < 0.90:
		return _ETHNICITIES[2]
	if r < 0.95:
		return _ETHNICITIES[3]
	if r < 0.98:
		return _ETHNICITIES[4]
	return _ETHNICITIES[5]


const _BIRTH_HUB_LABELS: Dictionary = {
	"US_LA": "Los Angeles, CA",
	"US_NYC": "New York, NY",
	"US_CHI": "Chicago, IL",
	"US_OTHER": "United States (Other)",
	"CAN": "Canada",
	"UK": "United Kingdom",
	"AUS": "Australia",
}


## Biased hubs; phenoms/hyphs get slight UK/Canada tilt (draft 3 narrative flavor).
static func roll_place_of_birth(rng: RandomNumberGenerator, profile: CareerProfile) -> String:
	var r := rng.randf()
	if profile == CareerProfile.PHENOM and r < 0.25:
		return _BIRTH_HUB_LABELS["UK"]
	if profile == CareerProfile.HYPHENATE and r < 0.20:
		return _BIRTH_HUB_LABELS["CAN"]
	if r < 0.30:
		return _BIRTH_HUB_LABELS["US_LA"]
	if r < 0.50:
		return _BIRTH_HUB_LABELS["US_NYC"]
	if r < 0.60:
		return _BIRTH_HUB_LABELS["US_CHI"]
	if r < 0.85:
		return _BIRTH_HUB_LABELS["US_OTHER"]
	if r < 0.92:
		return _BIRTH_HUB_LABELS["UK"]
	if r < 0.97:
		return _BIRTH_HUB_LABELS["CAN"]
	return _BIRTH_HUB_LABELS["AUS"]
