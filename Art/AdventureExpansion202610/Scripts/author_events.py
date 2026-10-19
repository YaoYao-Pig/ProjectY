"""Review or append the 20 travel stories without replacing unrelated source rows.

Run from any directory. The default is a read-only review; --apply writes the
three source tables after checking every reserved ID. Export is deliberately a
separate root integration step: node Tools/ConfigEditor/exporter.mjs.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
import os
from pathlib import Path
import re
import tempfile


ROOT = Path(__file__).resolve().parents[3]
MANIFEST = ROOT / "Art/AdventureExpansion202610/events.json"
ART_ROOT = "Assets/DynamicAsset/UI/Art/Story/Expansion202610"
TABLE_PATHS = {
    "AdventureEventTable": "Config/Tables/Adventure/AdventureEventTable.json",
    "AdventureChoiceTable": "Config/Tables/Adventure/AdventureChoiceTable.json",
    "WorldTravelEventTable": "Config/Tables/Travel/WorldTravelEventTable.json",
}
CHOICE_BASE = {
    "minScouting": 0, "costCoins": 0, "rewardCoins": 0, "healParty": False,
    "traitIds": [], "encounterIds": [], "requiredTraitIds": [],
    "forbiddenTraitIds": [], "removeTraitIds": [], "unlockTreeIds": [],
    "experience": 0, "potentialPoints": 0, "recipient": "subject",
    "itemIds": [], "itemCounts": [], "obstacleAction": "",
    "effectIds": [], "timeMinutes": 0, "hideRewards": False,
}
REFERENCE_PATHS = {
    "itemIds": "Config/Tables/Equipment/EquipmentItemTable.json",
    "effectIds": "Config/Tables/Adventure/CombatEffectTable.json",
    "traitIds": "Config/Tables/Adventure/CombatTraitTable.json",
    "requiredTraitIds": "Config/Tables/Adventure/CombatTraitTable.json",
    "forbiddenTraitIds": "Config/Tables/Adventure/CombatTraitTable.json",
    "removeTraitIds": "Config/Tables/Adventure/CombatTraitTable.json",
    "unlockTreeIds": "Config/Tables/Progression/TalentTreeTable.json",
    "encounterIds": "Config/Tables/Adventure/CombatEncounterTable.json",
}


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def index_rows(path: str):
    rows = read_json(ROOT / path)["rows"]
    result = {row["id"]: row for row in rows}
    assert len(result) == len(rows), f"Duplicate source IDs in {path}"
    return result


def free_exit(choice):
    """An exit is usable without money, traits, scouting or inventory capacity."""
    keys = ("costCoins", "minScouting", "rewardCoins", "timeMinutes",
            "experience", "potentialPoints", "healParty", "obstacleAction",
            "itemIds", "effectIds", "encounterIds", "traitIds",
            "requiredTraitIds", "forbiddenTraitIds", "removeTraitIds",
            "unlockTreeIds")
    return all(not choice.get(key, CHOICE_BASE[key]) for key in keys)


def build_rows():
    events = read_json(MANIFEST)
    assert [event["id"] for event in events] == list(range(201, 221)), "Expected exactly IDs 201..220"
    assert sum(e["presentation"] == "simple" for e in events) == 8
    assert sum(e["presentation"] == "complex" for e in events) == 12
    assert len({e["slug"] for e in events}) == 20, "Illustration slugs must be unique"
    assert len({e["title"] for e in events}) == 20, "Event titles must be unique"
    assert len({e["illustration_scene"] for e in events}) == 20, "Each event needs its own scene"
    refs = {key: index_rows(path) for key, path in REFERENCE_PATHS.items()}
    attributes = {row["code"] for row in index_rows("Config/Tables/Progression/GrowthAttributeTable.json").values()}
    schema = read_json(ROOT / TABLE_PATHS["AdventureChoiceTable"])
    fields = {field["name"]: field for field in schema["fields"]}
    assert {"effectIds", "timeMinutes", "hideRewards"} <= fields.keys(), "Root must integrate choice schema before applying stories"
    generated = {name: [] for name in TABLE_PATHS}
    for event in events:
        event_id = event["id"]
        assert re.fullmatch(r"[a-z][a-z0-9_]+", event["slug"])
        assert event["presentation"] in ("simple", "complex")
        assert event["actorAttribute"] in attributes
        assert len(event["description"]) >= 50 and len(event["illustration_scene"]) >= 100
        assert event["weight"] > 0 and event["regionTypes"]
        assert all(region in (1, 2, 3, 4, 5, 6) for region in event["regionTypes"])
        assert len(event["regionTypes"]) == len(set(event["regionTypes"]))
        assert 1 <= len(event["choices"]) <= 9
        choices = []
        for offset, authored in enumerate(event["choices"], 1):
            unknown = authored.keys() - fields.keys()
            assert not unknown, f"{event_id}: unknown choice fields {unknown}"
            row = copy.deepcopy(CHOICE_BASE)
            for name, field in fields.items():
                if name not in row and "default" in field:
                    row[name] = copy.deepcopy(field["default"])
            row.update(copy.deepcopy(authored))
            row["id"] = event_id * 10 + offset
            assert row.keys() == fields.keys(), f"{row['id']}: choice schema mismatch"
            assert row["label"] and row["result"]
            assert row["recipient"] in ("subject", "party")
            assert row["obstacleAction"] == "", "No area obstacle context exists during travel"
            assert isinstance(row["hideRewards"], bool)
            assert isinstance(row["timeMinutes"], (int, float)) and math.isfinite(row["timeMinutes"])
            assert 0 <= row["timeMinutes"] <= 1440
            assert len(row["itemIds"]) == len(row["itemCounts"])
            assert all(isinstance(count, int) and count > 0 for count in row["itemCounts"])
            assert len(row["encounterIds"]) <= 1
            for key, targets in refs.items():
                assert all(target in targets for target in row[key]), f"{row['id']}: invalid {key}"
            for effect_id in row["effectIds"]:
                assert refs["effectIds"][effect_id]["kind"] in ("heal", "damage", "apply_buff")
            choices.append(row)
        if event["presentation"] == "simple":
            assert len(choices) == 1
            assert not any(choices[0][key] for key in (
                "costCoins", "minScouting", "requiredTraitIds", "forbiddenTraitIds", "encounterIds"))
            # Inventory rewards are filtered by existing CanVisit/CanGrant before selection.
        else:
            assert any(free_exit(choice) for choice in choices), f"{event_id}: needs an unconditional exit"
        if event_id == 212:
            assert all(choice["hideRewards"] for choice in choices), "Puzzle must not reveal its answer via reward summaries"
        generated["AdventureEventTable"].append({
            "id": event_id, "name": event["title"], "description": event["description"],
            "repeatable": False, "choiceIds": [row["id"] for row in choices],
            "presentation": event["presentation"],
            "illustration": f"{ART_ROOT}/{event['slug']}.png",
            "actorAttribute": event["actorAttribute"],
            "logKind": "discovery" if event["presentation"] == "simple" else "event",
        })
        generated["AdventureChoiceTable"].extend(choices)
        generated["WorldTravelEventTable"].append({
            "id": event_id, "regionTypes": event["regionTypes"], "weight": event["weight"],
            "eventId": event_id, "encounterId": 0,
        })
    return generated


def prepare(generated):
    pending, report = [], {}
    for table_name, desired in generated.items():
        path = ROOT / TABLE_PATHS[table_name]
        before = path.read_bytes()
        source = json.loads(before.decode("utf-8-sig"))
        existing = {row["id"]: row for row in source["rows"]}
        assert len(existing) == len(source["rows"]), f"Duplicate IDs in {table_name}"
        added, unchanged = 0, 0
        for row in desired:
            if row["id"] in existing:
                assert existing[row["id"]] == row, f"Reserved ID collision: {table_name}:{row['id']}; refusing to overwrite"
                unchanged += 1
            else:
                source["rows"].append(row)
                added += 1
        if added:
            after = (json.dumps(source, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            pending.append((path, before, after))
        report[table_name] = {"add": added, "unchanged": unchanged}
    return pending, report


def apply(pending):
    # Recheck all snapshots before the first write; unrelated concurrent changes are not overwritten.
    for path, before, _ in pending:
        assert path.read_bytes() == before, f"Source changed during review: {path}"
    for path, before, after in pending:
        assert path.read_bytes() == before, f"Source changed during commit: {path}"
        handle, name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
        try:
            with os.fdopen(handle, "wb") as stream:
                stream.write(after)
            os.replace(name, path)
        finally:
            if os.path.exists(name):
                os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Append validated rows; exact repeat is a no-op")
    args = parser.parse_args()
    generated = build_rows()
    pending, report = prepare(generated)
    if args.apply:
        apply(pending)
    print(json.dumps({"mode": "applied" if args.apply else "review", "tables": report}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
