"""Small source-content check plus isolated non-destructive authoring regression.

No Unity, config export, gameplay save or real source-table writes are performed.
Use --applied after root integration to also verify the authored rows in source.
"""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import tempfile


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "author_events", ROOT / "Art/AdventureExpansion202610/Scripts/author_events.py")
author = importlib.util.module_from_spec(spec)
spec.loader.exec_module(author)


def write_fixture(root, tables):
    for name, path in author.TABLE_PATHS.items():
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(tables[name], ensure_ascii=False), encoding="utf-8")


def snapshots(root):
    return {name: (root / path).read_bytes() for name, path in author.TABLE_PATHS.items()}


def check_authoring(generated):
    original_root = author.ROOT
    fixture = {name: {"name": name, "description": "Unrelated schema metadata", "fields": [],
                      "rows": [{"id": 1, "sentinel": "User-authored row"}]}
               for name in generated}
    try:
        with tempfile.TemporaryDirectory(prefix="project_y_event_content_") as directory:
            author.ROOT = root = Path(directory)
            write_fixture(root, fixture)
            before = snapshots(root)
            pending, report = author.prepare(generated)
            assert before == snapshots(root), "Review changed source files"
            assert [report[name]["add"] for name in generated] == [20, 46, 20]
            author.apply(pending)
            for name, path in author.TABLE_PATHS.items():
                table = json.loads((root / path).read_text(encoding="utf-8"))
                assert table["rows"][0] == fixture[name]["rows"][0], "Unrelated row overwritten"
                assert table["description"] == fixture[name]["description"], "Metadata overwritten"
            after = snapshots(root)
            pending, report = author.prepare(generated)
            assert not pending and all(row["add"] == 0 for row in report.values())
            author.apply(pending)
            assert snapshots(root) == after, "Repeated authoring changed files"
            print("PASS append preserves unrelated rows/schema; repeated authoring is byte-identical")

            collision = copy.deepcopy(fixture)
            collision["WorldTravelEventTable"]["rows"].append({"id": 201, "sentinel": "Reserved by another author"})
            write_fixture(root, collision)
            before = snapshots(root)
            try:
                author.prepare(generated)
            except AssertionError as error:
                assert "Reserved ID collision" in str(error)
            else:
                raise AssertionError("Conflicting reserved ID was accepted")
            assert snapshots(root) == before, "Collision partially changed another table"
            print("PASS collision in final table is rejected before any real or fixture write")
    finally:
        author.ROOT = original_root


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--applied", action="store_true")
    args = parser.parse_args()
    generated = author.build_rows()
    events, choices, travel = (generated[name] for name in author.TABLE_PATHS)
    assert len(events) == len(travel) == 20 and len(choices) == 46
    assert {row["id"] for row in events} == {row["eventId"] for row in travel}
    assert {item for row in choices for item in row["itemIds"] if item >= 501} == {501, 506, 511, 519, 527}
    assert sum(bool(row["encounterIds"]) for row in choices) == 1
    assert next(row for row in choices if row["encounterIds"])["encounterIds"] == [204]
    assert {effect for row in choices for effect in row["effectIds"]} == {807, 1211, 1212, 1213}
    print("PASS 20 distinct illustrated travel events, 8 simple / 12 complex, 46 choices; all source references resolve")
    print("PASS every complex event has a free exit; simple outcomes have no stat/trait/coin gates; puzzle rewards hidden")
    check_authoring(generated)
    if args.applied:
        pending, report = author.prepare(generated)
        assert not pending and all(row["add"] == 0 for row in report.values()), "Source tables are not fully applied"
        print("PASS all authored event, choice and travel rows match applied source tables")


if __name__ == "__main__":
    main()
