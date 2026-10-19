"""Review / append the Arsenal content design; never exports or touches Unity.

Default is a read-only review. Root integration may use --apply after finishing
the shared schemas/runtime. Exact existing rows are a no-op; conflicting IDs
are rejected before any write. All other rows and table metadata are retained.
"""
from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
import tempfile


ROOT = Path(__file__).resolve().parents[3]
DESIGN = ROOT / "Art/ArsenalExpansion202610/design.json"
ART = "Assets/DynamicAsset/ArsenalExpansion202610"
PATHS = {
    "EquipmentAssetTable": "Equipment/EquipmentAssetTable",
    "EquipmentItemTable": "Equipment/EquipmentItemTable",
    "EquipmentGripTable": "Equipment/EquipmentGripTable",
    "EquipmentHoldAdjustmentTable": "Equipment/EquipmentHoldAdjustmentTable",
    "EquipmentSocketTable": "Equipment/EquipmentSocketTable",
    "EquipmentWeaponTable": "Equipment/EquipmentWeaponTable",
    "EquipmentRuneTable": "Equipment/EquipmentRuneTable",
    "CombatEffectTable": "Adventure/CombatEffectTable",
    "BuffTable": "Adventure/BuffTable",
    "CombatSkillTable": "Adventure/CombatSkillTable",
    "SkillAtlasTable": "Progression/SkillAtlasTable",
    "ShopEntryTable": "Shop/ShopEntryTable",
    "LootEntryTable": "Loot/LootEntryTable",
}


def path_for(name):
    return ROOT / "Config/Tables" / (PATHS[name] + ".json")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def fill(schema, row):
    """Materialize declared defaults; unknown/missing required fields are errors."""
    result = copy.deepcopy(row)
    fields = {field["name"]: field for field in schema["fields"]}
    assert not result.keys() - fields.keys(), (schema["name"], result.keys() - fields.keys())
    for name, field in fields.items():
        if name not in result:
            assert "default" in field, f"Missing {schema['name']}.{name}"
            result[name] = copy.deepcopy(field["default"])
        value = result[name]
        if "values" in field:
            values = value if field["type"].endswith("[]") else [value]
            assert all(item in field["values"] for item in values), f"Invalid enum {schema['name']}.{name}: {value}"
        if field["type"] in ("int", "float"):
            if "min" in field:
                assert value >= field["min"], f"Below minimum {schema['name']}.{name}"
            if "max" in field:
                assert value <= field["max"], f"Above maximum {schema['name']}.{name}"
    return result


def build():
    design = read_json(DESIGN)
    weapons, attachments = design["weapons"], design["attachments"]
    assert [row["id"] for row in weapons] == list(range(601, 621))
    assert [row["id"] for row in attachments] == list(range(701, 721))
    assert len({row["model"] for row in weapons + attachments}) == 40
    assert [sum(row["categoryId"] == kind for row in weapons) for kind in range(1, 8)] == [3, 3, 3, 3, 3, 3, 2]
    tables = {name: read_json(path_for(name)) for name in PATHS}
    existing = {name: {row["id"]: row for row in table["rows"]} for name, table in tables.items()}
    result = {name: [] for name in PATHS}
    effect_fields = {f["name"] for f in tables["CombatEffectTable"]["fields"]}
    assert {"recipient", "requiredTags", "forbiddenTags", "removeTags", "removeCategories", "affectsContainers"} <= effect_fields, "Root effect schema is not ready"
    skill_fields = {f["name"] for f in tables["CombatSkillTable"]["fields"]}
    assert {"maxTargets", "splashRadius"} <= skill_fields, "Root multi-target skill schema is not ready"

    def add(name, row):
        result[name].append(fill(tables[name], row))

    for row in design["effects"]:
        add("CombatEffectTable", row)
    for row in design["buffs"]:
        add("BuffTable", row)
    for row in design["skills"]:
        base = copy.deepcopy(existing["CombatSkillTable"][row["baseSkillId"]])
        base.update({key: value for key, value in row.items() if key != "baseSkillId"})
        add("CombatSkillTable", base)
        assert base["contexts"] == ["battle"] and not base["affectsContainers"], "Special procs must not farm containers"

    for row in weapons + attachments:
        item_id = row["id"]
        add("EquipmentAssetTable", dict(id=item_id, name=row["model"], modelPath=row["unityFbx"],
            prefabPath=f"{ART}/Weapons/{row['model']}.prefab" if item_id < 700 else row["unityFbx"]))
        if item_id < 700:
            item = copy.deepcopy(existing["EquipmentItemTable"][row["baseWeaponId"]])
            item.update(id=item_id, name=row["name"], assetId=item_id,
                iconPath=f"{ART}/Icons/Item_{item_id}.png", iconMode="model", iconPadding=1.18)
        else:
            item = dict(id=item_id, name=row["name"], kind="module" if row["slotKind"] in ("thruster", "rail", "edge") else "rune",
                assetId=item_id, iconPath=f"{ART}/Icons/Item_{item_id}.png", width=row["inventoryWidth"],
                height=row["inventoryHeight"], iconMode="model", iconRotation=[8, 22, -10], iconPadding=1.18)
        add("EquipmentItemTable", item)
        add("ShopEntryTable", dict(id=item_id, templateId=1, itemId=item_id,
            chance=row["shopChance"], minCount=1, maxCount=1, price=row["value"]))

    for socket in design["sockets"]:
        add("EquipmentSocketTable", socket)
    new_skills = {row["id"]: row for row in result["CombatSkillTable"]}
    layout = {}
    for row in weapons:
        item_id = row["id"]
        base = copy.deepcopy(existing["EquipmentWeaponTable"][row["baseWeaponId"]])
        base.update(id=item_id, categoryId=row["categoryId"], level=row["level"],
            damageMultiplier=row["damageMultiplier"], socketIds=row["socketIds"], skillIds=row["skillIds"],
            gripId=item_id, onHitEffectIds=[], description=row["description"])
        assert base["kind"] == row["class"]
        add("EquipmentWeaponTable", base)
        grip = copy.deepcopy(existing["EquipmentGripTable"][existing["EquipmentWeaponTable"][row["baseWeaponId"]]["gripId"]])
        grip.update(id=item_id, name=row["name"] + " · 基准握点")
        add("EquipmentGripTable", grip)
        adjustments = sorted((entry for entry in existing["EquipmentHoldAdjustmentTable"].values()
                              if entry["weaponId"] == row["baseWeaponId"]), key=lambda entry: entry["id"])
        for index, adjustment in enumerate(adjustments, 1):
            copied = copy.deepcopy(adjustment)
            copied.update(id=item_id * 10 + index, weaponId=item_id)
            add("EquipmentHoldAdjustmentTable", copied)
        # Atlas is mandatory for every skill. No ProfessionSkill / ActiveSkillPool
        # row is added: these remain exclusively equipment-granted abilities.
        for skill_id in row["skillIds"]:
            if skill_id < 1601:
                continue
            skill = new_skills[skill_id]
            source = next(s for s in design["skills"] if s["id"] == skill_id)
            node = copy.deepcopy(existing["SkillAtlasTable"][source["baseSkillId"]])
            category = node["categoryId"]
            offset = layout.get(category, 0)
            layout[category] = offset + 1
            start_y = max(n["y"] for n in existing["SkillAtlasTable"].values()
                if n["categoryId"] == category and n["id"] not in new_skills) + 180
            node.update(id=skill_id, x=145 + 220 * (offset % 3), y=start_y + 160 * (offset // 3),
                prerequisiteIds=[source["baseSkillId"]], prerequisiteMode="all",
                tags=["武器专属", row["name"], skill["proficiency"]])
            add("SkillAtlasTable", node)

    rune_fields = {field["name"] for field in tables["EquipmentRuneTable"]["fields"]}
    for row in attachments:
        add("EquipmentRuneTable", {name: row[name] for name in rune_fields if name in row})
    for row in design["loot"]:
        add("LootEntryTable", dict(row, chance=100, minCount=1, maxCount=1))
    pools = {row["id"]: row for row in read_json(ROOT / "Config/Tables/Loot/LootPoolTable.json")["rows"]}
    assert all(pools[row["poolId"]].get("mode") == "weighted" for row in design["loot"]), "Do not inflate independent loot probabilities"

    # Resolve declared references against both existing rows and this complete batch.
    references = {}
    for table_path in (ROOT / "Config/Tables").rglob("*.json"):
        table = read_json(table_path)
        if "rows" in table and "name" in table:
            references[table["name"]] = {row[table.get("key", "id")] for row in table["rows"]}
    for name, rows in result.items():
        ids = {row["id"] for row in rows}
        assert len(ids) == len(rows), f"Duplicate new IDs in {name}"
        references[name].update(ids)
    for name, rows in result.items():
        for field in tables[name]["fields"]:
            if "ref" not in field:
                continue
            values = references[field["ref"]]
            for row in rows:
                selected = row[field["name"]]
                selected = selected if field["type"].endswith("[]") else [selected]
                assert all(value in values for value in selected), f"Broken reference {name}:{row['id']} {field['name']}"
    assert {row["id"] for row in result["CombatSkillTable"]} == {row["id"] for row in result["SkillAtlasTable"]}
    return result


def prepare(generated):
    pending, report = [], {}
    for name, rows in generated.items():
        path = path_for(name)
        before = path.read_bytes()
        table = json.loads(before.decode("utf-8-sig"))
        existing = {row["id"]: row for row in table["rows"]}
        assert len(existing) == len(table["rows"]), f"Duplicate source IDs in {name}"
        added, unchanged = 0, 0
        for row in rows:
            if row["id"] in existing:
                assert existing[row["id"]] == row, f"ID collision {name}:{row['id']}; refusing to overwrite"
                unchanged += 1
            else:
                table["rows"].append(row)
                added += 1
        if added:
            after = (json.dumps(table, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            pending.append((path, before, after))
        report[name] = {"add": added, "unchanged": unchanged}
    return pending, report


def apply(pending):
    for path, before, _ in pending:
        assert path.read_bytes() == before, f"Source changed during review: {path}"
    for path, before, after in pending:
        assert path.read_bytes() == before, f"Source changed during commit: {path}"
        handle, temp_path = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
        try:
            with os.fdopen(handle, "wb") as stream:
                stream.write(after)
            os.replace(temp_path, path)
        finally:
            if os.path.exists(temp_path):
                os.unlink(temp_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    generated = build()
    pending, report = prepare(generated)
    if args.apply:
        apply(pending)
    print(json.dumps({"mode": "applied" if args.apply else "review", "tables": report}, indent=2))


if __name__ == "__main__":
    main()
