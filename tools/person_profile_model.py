"""
Twin of Scripts/person_profile_model.gd — keep logic aligned when changing generation rules.

Consolidates iterative “2008 TV” drafts:
- Career profiles (journeyman / specialist / suit / phenom / hyphenate)
- Bell-curve core skills + COM/DRM creative bounds
- Skewed STM/EGO/PRO, optional Vice + demographics
"""

from __future__ import annotations

import math
import random
from enum import IntEnum

REFERENCE_YEAR = 2008
MIN_SKILL = 20.0
MAX_SKILL = 100.0


class CareerProfile(IntEnum):
    JOURNEYMAN = 0
    SPECIALIST = 1
    SUIT = 2
    PHENOM = 3
    HYPHENATE = 4


def roll_bell(rng: random.Random, mean: float, std_dev: float) -> float:
    u1 = max(rng.random(), 1e-9)
    u2 = rng.random()
    z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2)
    return z0 * std_dev + mean


def roll_career_profile(rng: random.Random) -> CareerProfile:
    r = rng.random()
    if r < 0.60:
        return CareerProfile.JOURNEYMAN
    if r < 0.85:
        return CareerProfile.SPECIALIST
    if r < 0.95:
        return CareerProfile.SUIT
    if r < 0.98:
        return CareerProfile.PHENOM
    return CareerProfile.HYPHENATE


def roll_core_four_skills(rng: random.Random, profile: CareerProfile) -> dict[str, int]:
    act = roll_bell(rng, 50.0, 15.0)
    wri = roll_bell(rng, 50.0, 15.0)
    bcn = roll_bell(rng, 40.0, 20.0)
    log_cmd = roll_bell(rng, 35.0, 15.0)

    if profile == CareerProfile.JOURNEYMAN:
        act = max(MIN_SKILL, min(75.0, act))
        wri = max(MIN_SKILL, min(75.0, wri))
    elif profile == CareerProfile.SPECIALIST:
        if rng.random() > 0.5:
            act = roll_bell(rng, 82.0, 7.0)
            wri = max(MIN_SKILL, min(45.0, wri))
        else:
            wri = roll_bell(rng, 82.0, 7.0)
            act = max(MIN_SKILL, min(45.0, act))
    elif profile == CareerProfile.SUIT:
        log_cmd = roll_bell(rng, 85.0, 8.0)
        act = max(MIN_SKILL, min(40.0, act))
        wri = max(MIN_SKILL, min(40.0, wri))
    elif profile == CareerProfile.PHENOM:
        act = roll_bell(rng, 94.0, 4.0)
        wri = roll_bell(rng, 45.0, 15.0)
    else:  # HYPHENATE
        act = roll_bell(rng, 88.0, 6.0)
        wri = roll_bell(rng, 88.0, 6.0)

    return {
        "ACT": int(round(max(MIN_SKILL, min(MAX_SKILL, act)))),
        "WRI": int(round(max(MIN_SKILL, min(MAX_SKILL, wri)))),
        "BCN": int(round(max(MIN_SKILL, min(MAX_SKILL, bcn)))),
        "LOG": int(round(max(MIN_SKILL, min(MAX_SKILL, log_cmd)))),
    }


def roll_com_drm_bounded(rng: random.Random, act_skill: int, wri_skill: int) -> dict[str, int]:
    hi = float(max(act_skill, wri_skill))
    creative_floor = hi / 2.0
    creative_ceil = hi + 20.0
    half_lo = creative_floor / 2.0
    half_hi = creative_ceil / 2.0
    com = max(half_lo, min(half_hi, roll_bell(rng, 50.0, 20.0)))
    drm = max(half_lo, min(half_hi, roll_bell(rng, 50.0, 20.0)))
    return {"COM": int(round(com)), "DRM": int(round(drm))}


def roll_ego(rng: random.Random) -> int:
    r = rng.random()
    if r < 0.60:
        return rng.randint(30, 50)
    if r < 0.90:
        return rng.randint(70, 85)
    return rng.randint(90, 100)


def roll_stm(rng: random.Random) -> int:
    return int(round(max(30.0, min(MAX_SKILL, roll_bell(rng, 75.0, 10.0)))))


def roll_pro(rng: random.Random) -> int:
    return int(round(max(20.0, min(MAX_SKILL, roll_bell(rng, 75.0, 12.0)))))


def roll_vice(rng: random.Random) -> int:
    if rng.random() > 0.15:
        return 0
    return rng.randint(40, 95)


def roll_attractiveness_base(rng: random.Random, profile: CareerProfile, act_after_core: int) -> int:
    app_base = roll_bell(rng, 55.0, 18.0)
    if profile == CareerProfile.PHENOM or (profile == CareerProfile.SPECIALIST and act_after_core > 80):
        app_base = max(app_base, rng.uniform(72.0, 98.0))
    return int(round(max(MIN_SKILL, min(MAX_SKILL, app_base))))


def roll_fame_career_component(rng: random.Random, birth_year: int, profile: CareerProfile) -> float:
    age = max(0, REFERENCE_YEAR - birth_year)
    career_years = max(1, age - 22)
    mult = 2.5 if profile == CareerProfile.PHENOM else 0.8
    return float(career_years) * mult + roll_bell(rng, 10.0, 20.0)


_ETHNICITIES = [
    "Caucasian",
    "African American",
    "Hispanic",
    "Asian",
    "Middle Eastern",
    "South Asian",
]


def roll_ethnicity_2008(rng: random.Random) -> str:
    r = rng.random()
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


_BIRTH_HUB_LABELS = {
    "US_LA": "Los Angeles, CA",
    "US_NYC": "New York, NY",
    "US_CHI": "Chicago, IL",
    "US_OTHER": "United States (Other)",
    "CAN": "Canada",
    "UK": "United Kingdom",
    "AUS": "Australia",
}


def roll_place_of_birth(rng: random.Random, profile: CareerProfile) -> str:
    r = rng.random()
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
