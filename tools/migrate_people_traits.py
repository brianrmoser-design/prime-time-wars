#!/usr/bin/env python3
"""
One-time migration: legacy traits.P, traits.C, … → talent traits.ACT, traits.WRI, …
Run from project root:
  python tools/migrate_people_traits.py
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PEOPLE_PATHS = [
    ROOT / "universes" / "2008" / "people.json",
    ROOT / "universes" / "2008" / "people_generated.json",
    ROOT / "universes" / "fictional" / "people.json",
]

OLD_KEYS = ["P", "C", "W", "I", "ED", "DC", "SH", "CT", "TI", "BF", "LC", "CC"]


def _g(person: dict, short: str) -> float:
    v = person.get(f"traits.{short}")
    if v is None:
        return 0.0
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _clamp(x: int, lo: int, hi: int) -> int:
    return max(lo, min(hi, x))


def migrate_person(person: dict) -> bool:
    if not any(f"traits.{k}" in person for k in OLD_KEYS):
        return False
    P, C, W, I, ED, DC, SH, CT, TI, BF, LC, CC = (_g(person, k) for k in OLD_KEYS)
    person["traits.ACT"] = str(_clamp(int(round((P + C + I) / 3)), 20, 100))
    person["traits.WRI"] = str(_clamp(int(round((ED + DC + SH) / 3)), 20, 100))
    person["traits.BCN"] = str(_clamp(int(round((TI + BF + C) / 3)), 20, 100))
    person["traits.LOG"] = str(_clamp(int(round((LC + CC) / 2)), 20, 100))
    person["traits.COM"] = str(_clamp(int(round((SH + CT + W) / 3)), 20, 100))
    person["traits.DRM"] = str(_clamp(int(round((ED + DC + I) / 3)), 20, 100))
    person["traits.DIST"] = str(50)
    person["traits.WVW"] = str(50)
    person["traits.EDY"] = str(_clamp(int(round(I)), 20, 100))
    person["traits.VUL"] = str(50)
    person["traits.STM"] = str(55)
    person["traits.EGO"] = str(50)
    person["traits.PRO"] = str(_clamp(int(round(C)), 20, 100))
    for k in OLD_KEYS:
        person.pop(f"traits.{k}", None)
    return True


def migrate_file(path: Path) -> tuple[int, int]:
    if not path.is_file():
        print(f"Skip (missing): {path}")
        return 0, 0
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        print(f"Skip (not a list): {path}")
        return 0, 0
    n = 0
    for p in data:
        if isinstance(p, dict) and migrate_person(p):
            n += 1
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print(f"Migrated {n} / {len(data)} people in {path}")
    return n, len(data)


def main() -> None:
    total_m = 0
    for p in PEOPLE_PATHS:
        m, _ = migrate_file(p)
        total_m += m
    print(f"Done. Total rows migrated: {total_m}")


if __name__ == "__main__":
    main()
