#!/usr/bin/env python3
"""
CLI twin of Scripts/fictional_universe_builder.gd — regenerates universes/fictional/.
Run from project root:  python tools/build_fictional_universe.py
Requires: universes/2008/*.json, Data/name_lists/*.csv
"""

from __future__ import annotations

import csv
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
U2008 = ROOT / "universes" / "2008"
UFIC = ROOT / "universes" / "fictional"
NAMES = ROOT / "Data" / "name_lists"

TRAIT_IDS = ["P", "C", "W", "I", "ED", "DC", "SH", "CT", "TI", "BF", "LC", "CC"]
NO_SKILL = 15

SKILL_TIERS = {
    "elite": {"weight": 5, "min": 90, "max": 100},
    "great": {"weight": 15, "min": 80, "max": 89},
    "good": {"weight": 25, "min": 70, "max": 79},
    "average": {"weight": 40, "min": 55, "max": 69},
    "below_avg": {"weight": 15, "min": 40, "max": 54},
}

ARCHETYPES = {
    "lead_actor": {"primary": ["P", "C", "I", "ED", "DC", "SH", "CT"], "secondary": ["W"], "none": ["TI", "BF", "LC", "CC"]},
    "support_actor": {"primary": ["P", "C", "ED", "DC", "SH", "CT"], "secondary": ["W", "I"], "none": ["TI", "BF", "LC", "CC"]},
    "host": {"primary": ["P", "C", "W", "SH", "CT", "BF"], "secondary": ["I", "ED"], "none": ["DC", "TI", "LC", "CC"]},
    "anchor": {"primary": ["P", "C", "W", "TI", "BF"], "secondary": ["ED", "DC"], "none": ["I", "SH", "CT", "LC", "CC"]},
    "reporter": {"primary": ["C", "W", "TI", "BF"], "secondary": ["P", "ED"], "none": ["I", "DC", "SH", "CT", "LC", "CC"]},
    "judge": {"primary": ["P", "C", "W", "SH"], "secondary": ["I", "CT", "BF"], "none": ["ED", "DC", "TI", "LC", "CC"]},
    "staff_writer": {"primary": ["W", "ED", "DC", "SH"], "secondary": [], "none": ["P", "C", "I", "CT", "TI", "BF", "LC", "CC"]},
    "head_writer": {"primary": ["W", "ED", "DC", "SH"], "secondary": ["C", "LC"], "none": ["P", "I", "CT", "TI", "BF", "CC"]},
    "showrunner": {"primary": ["C", "W", "CC", "LC", "ED", "DC", "SH"], "secondary": [], "none": ["P", "I", "CT", "TI", "BF"]},
    "exec_producer": {"primary": ["C", "LC", "CC"], "secondary": ["W", "ED", "DC", "SH"], "none": ["P", "I", "CT", "TI", "BF"]},
}

DEFAULT_BALANCE = {
    "lead_actor": 0.08,
    "support_actor": 0.18,
    "host": 0.04,
    "anchor": 0.06,
    "reporter": 0.08,
    "judge": 0.02,
    "staff_writer": 0.22,
    "head_writer": 0.06,
    "showrunner": 0.08,
    "exec_producer": 0.18,
}


class PersonGenPy:
    def __init__(self, rng: random.Random):
        self.rng = rng
        self._id_counter = 0
        self._first_rows: list[dict] = []
        self._last_by_origin: dict[str, list[dict]] = {}
        self._origin_weight: dict[str, float] = {}

    def load_csv(self, first_path: Path, last_path: Path) -> None:
        self._first_rows = []
        with first_path.open(newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                self._first_rows.append(
                    {
                        "name": row["Name"],
                        "gender": row["Gender"],
                        "origin": row["Origin"],
                        "era_peak": int(row["Era_Peak"]),
                        "weight": float(row["Weight"]),
                    }
                )
        last_rows = []
        with last_path.open(newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                last_rows.append({"name": row["Name"], "origin": row["Origin"], "weight": float(row["Weight"])})
        self._last_by_origin = {}
        for row in last_rows:
            self._last_by_origin.setdefault(row["origin"], []).append({"name": row["name"], "w": row["weight"]})
        self._origin_weight = {}
        for row in self._first_rows:
            self._origin_weight[row["origin"]] = self._origin_weight.get(row["origin"], 0.0) + row["weight"]

    def _pick_skill_tier(self) -> str:
        total = sum(SKILL_TIERS[t]["weight"] for t in SKILL_TIERS)
        r = self.rng.random() * total
        for t, d in SKILL_TIERS.items():
            r -= d["weight"]
            if r <= 0:
                return t
        return "average"

    def _build_traits(self, arch: dict, tier: dict) -> dict[str, int]:
        out = {k: NO_SKILL for k in TRAIT_IDS}
        for key in arch["primary"]:
            out[key] = self.rng.randint(tier["min"], tier["max"])
        for key in arch["secondary"]:
            out[key] = self.rng.randint(55, 75)
        for key in arch["none"]:
            if self.rng.random() < 0.15:
                out[key] = self.rng.randint(40, 55)
            else:
                out[key] = NO_SKILL
        return out

    def _roll_fame(self, archetype: str) -> int:
        base = 50
        if archetype in ("lead_actor", "host", "anchor"):
            base = 65
        elif archetype in ("showrunner", "exec_producer"):
            base = 55
        elif archetype in ("staff_writer", "head_writer"):
            base = 42
        return max(35, min(100, self.rng.randint(base - 25, base + 25)))

    def _roll_attr(self, archetype: str) -> int:
        on_screen = {"lead_actor", "support_actor", "host", "anchor", "reporter", "judge"}
        base = 58 if archetype in on_screen else 50
        return max(35, min(100, self.rng.randint(base - 28, base + 28)))

    def _pick_origin(self) -> str:
        total = sum(self._origin_weight.values())
        r = self.rng.random() * total
        for o, w in self._origin_weight.items():
            r -= w
            if r <= 0:
                return o
        return "Western"

    def _weighted_pick(self, entries: list[dict]) -> str:
        total = sum(e["w"] for e in entries)
        if total <= 0 and entries:
            return str(self.rng.choice(entries)["name"])
        r = self.rng.random() * total
        for e in entries:
            r -= e["w"]
            if r <= 0:
                return str(e["name"])
        return str(entries[-1]["name"])

    def _talent_name(self, gender: str, birth_year: int) -> str:
        origin = self._pick_origin()
        pool = []
        for row in self._first_rows:
            if row["gender"] != gender or row["origin"] != origin:
                continue
            w = row["weight"] / (1.0 + abs(birth_year - row["era_peak"]) * 0.1)
            pool.append({"name": row["name"], "w": w})
        if not pool:
            for row in self._first_rows:
                if row["origin"] != origin:
                    continue
                w = row["weight"] / (1.0 + abs(birth_year - row["era_peak"]) * 0.1)
                pool.append({"name": row["name"], "w": w})
        first = self._weighted_pick(pool)
        last_pool = list(self._last_by_origin.get(origin) or [])
        if not last_pool:
            last_pool = []
            for rows in self._last_by_origin.values():
                last_pool.extend(rows)
        last = self._weighted_pick(last_pool)
        return f"{first} {last}"

    def _next_id(self) -> str:
        self._id_counter += 1
        return f"PERS_{self._id_counter % 1000000:06d}"

    def generate_person(self, archetype: str) -> dict:
        if archetype not in ARCHETYPES:
            archetype = self.rng.choice(list(ARCHETYPES.keys()))
        tier_name = self._pick_skill_tier()
        tier = SKILL_TIERS[tier_name]
        arch = ARCHETYPES[archetype]
        traits = self._build_traits(arch, tier)
        y = self.rng.randint(1940, 2000)
        m = self.rng.randint(1, 12)
        d = self.rng.randint(1, 28)
        dob = f"{y:04d}-{m:02d}-{d:02d}"
        gender = "Male" if self.rng.random() < 0.5 else "Female"
        name = self._talent_name(gender, y)
        person = {
            "Person_ID": self._next_id(),
            "Person_Name": name,
            "DOB": dob,
            "Fame": str(self._roll_fame(archetype)),
            "Attractiveness": str(self._roll_attr(archetype)),
        }
        for k in TRAIT_IDS:
            person[f"traits.{k}"] = str(traits[k])
        return person

    def generate_batch(self, n: int, balance: dict | None = None) -> list[dict]:
        balance = balance or DEFAULT_BALANCE
        counts: dict[str, int] = {}
        total_frac = sum(v for v in balance.values() if v <= 1.0)
        use_frac = total_frac <= 1.0
        for arch, v in balance.items():
            counts[arch] = int(round(n * float(v))) if use_frac else int(v)
        s = sum(counts.values())
        while s > n:
            k = self.rng.choice([a for a, c in counts.items() if c > 0])
            counts[k] -= 1
            s -= 1
        while s < n:
            k = self.rng.choice(list(counts.keys()))
            counts[k] += 1
            s += 1
        out: list[dict] = []
        for arch, c in counts.items():
            for _ in range(c):
                out.append(self.generate_person(arch))
        return out


def make_titles(n: int, rng: random.Random) -> list[str]:
    w1 = [
        "Neon", "Silver", "Midnight", "Northern", "Southern", "Eastern", "Western", "Royal",
        "Second", "First", "Twin", "Cold", "Red", "Blue", "Black", "White", "Golden", "Stone",
        "Iron", "Crystal", "Pacific", "Atlantic", "Central", "Metro", "Grand", "Little", "Great",
        "False", "True", "High", "Low", "Dark", "Bright", "Silent", "Broken", "Perfect", "Empty",
        "Lost", "Found", "Secret", "Open", "Final", "Early", "Late", "Summer", "Winter", "Spring",
    ]
    w2 = [
        "Harbor", "Crossing", "Division", "Mercy", "Station", "District", "Heights", "Ridge",
        "Falls", "Bridge", "Point", "Bay", "Court", "Place", "Line", "Room", "Passage", "Ward",
        "City", "County", "Law", "Order", "Fire", "Skies", "Dawn", "Night", "Star", "Field",
        "Creek", "Lane", "Circle", "Square", "Park", "Tower", "Hall", "Gate", "Road", "Run",
        "Shore", "Lake", "River", "Mountain", "Valley", "Street", "House", "Room", "Club", "Beat",
    ]
    used = set()
    titles = []
    guard = 0
    while len(titles) < n and guard < n * 200:
        guard += 1
        t = f"{rng.choice(w1)} {rng.choice(w2)}"
        if t in used:
            continue
        used.add(t)
        titles.append(t)
    while len(titles) < n:
        titles.append(f"Working Title {len(titles) + 1}")
    return titles


def main() -> None:
    seed_value = 42
    target_people = 660
    show_count = 60

    rng = random.Random(seed_value)
    gen = PersonGenPy(rng)
    gen.load_csv(NAMES / "database_first_names.csv", NAMES / "database_last_names.csv")

    with (U2008 / "shows.json").open(encoding="utf-8") as f:
        shows_2008 = json.load(f)
    with (U2008 / "contracts.json").open(encoding="utf-8") as f:
        contracts_2008 = json.load(f)
    with (U2008 / "schedule.json").open(encoding="utf-8") as f:
        sched_2008 = json.load(f)
    with (U2008 / "networks.json").open(encoding="utf-8") as f:
        networks = json.load(f)
    with (U2008 / "showtypes.json").open(encoding="utf-8") as f:
        showtypes = json.load(f)

    chosen = shows_2008[:show_count]
    old_show_names = {s["Show_Name"] for s in chosen}
    old_id_to_new = {}
    titles = make_titles(show_count, rng)
    old_show_name_to_new = {}

    for i, src in enumerate(chosen):
        oid = str(src["Show_ID"])
        nid = f"SHOW_FIC_{i + 1:05d}"
        old_id_to_new[oid] = nid
        old_show_name_to_new[src["Show_Name"]] = titles[i]

    filtered = [dict(c) for c in contracts_2008 if c["Show_Name"] in old_show_names]
    unique_old = sorted({c["Person_Name"] for c in filtered})
    people = gen.generate_batch(target_people, DEFAULT_BALANCE)
    if len(unique_old) > len(people):
        raise SystemExit(f"Need more people: {len(unique_old)} unique vs {len(people)}")
    old_to_new = {o: people[i]["Person_Name"] for i, o in enumerate(unique_old)}

    new_contracts = []
    for c in filtered:
        nc = dict(c)
        nc["Show_Name"] = old_show_name_to_new[c["Show_Name"]]
        nc["Person_Name"] = old_to_new[c["Person_Name"]]
        new_contracts.append(nc)

    new_shows = []
    for i, src in enumerate(chosen):
        row = dict(src)
        row["Show_ID"] = f"SHOW_FIC_{i + 1:05d}"
        row["Show_Name"] = titles[i]
        new_shows.append(row)

    new_sched = {}
    for net_id, net_data in sched_2008.items():
        out_net = {}
        for day, slots in net_data.items():
            out_slots = []
            for slot in slots:
                oid = str(slot["show"])
                if oid in old_id_to_new:
                    ns = dict(slot)
                    ns["show"] = old_id_to_new[oid]
                    out_slots.append(ns)
            out_net[day] = out_slots
        new_sched[net_id] = out_net

    manifest = {
        "id": "fictional",
        "display_name": "Fictional Universe",
        "description": f"Generated lineup (~{target_people} people, {show_count} shows) from 2008 structure with CSV names.",
    }

    UFIC.mkdir(parents=True, exist_ok=True)
    for name, data in [
        ("universe.json", manifest),
        ("networks.json", networks),
        ("showtypes.json", showtypes),
        ("shows.json", new_shows),
        ("people.json", people),
        ("contracts.json", new_contracts),
        ("schedule.json", new_sched),
    ]:
        path = UFIC / name
        path.write_text(json.dumps(data, indent="\t") + "\n", encoding="utf-8")

    print(f"Wrote {UFIC}: {len(people)} people, {len(new_shows)} shows, {len(new_contracts)} contracts.")


if __name__ == "__main__":
    main()
