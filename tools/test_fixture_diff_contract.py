#!/usr/bin/env python3
"""Validate the synthetic comparison fixtures' expected semantic diff contract."""

from pathlib import Path
import plistlib

FIXTURES = Path(__file__).resolve().parents[1] / "Tests" / "Fixtures"
BASELINE = FIXTURES / "mobilegestalt-baseline.plist"
COMPARISON = FIXTURES / "mobilegestalt-comparison.plist"


def load(path: Path) -> dict:
    with path.open("rb") as handle:
        value = plistlib.load(handle)
    assert isinstance(value, dict), f"{path.name}: root must be a dictionary"
    assert isinstance(value.get("CacheExtra"), dict), f"{path.name}: CacheExtra must be a dictionary"
    return value


def classify(left: dict, right: dict) -> tuple[set[str], set[str], set[str]]:
    left_extra = left["CacheExtra"]
    right_extra = right["CacheExtra"]
    keys = set(left_extra) | set(right_extra)
    added = {key for key in keys if key not in left_extra}
    removed = {key for key in keys if key not in right_extra}
    changed = {
        key
        for key in keys
        if key in left_extra and key in right_extra and left_extra[key] != right_extra[key]
    }
    return added, removed, changed


def main() -> None:
    baseline = load(BASELINE)
    comparison = load(COMPARISON)

    # Keep top-level metadata stable so this pair isolates CacheExtra comparison behavior.
    assert baseline["FixtureVersion"] == comparison["FixtureVersion"]
    assert baseline["CacheData"] == comparison["CacheData"]

    added, removed, changed = classify(baseline, comparison)
    assert added == {"AddedInComparison"}, f"unexpected added keys: {sorted(added)}"
    assert removed == {"RemovedInComparison"}, f"unexpected removed keys: {sorted(removed)}"
    assert changed == {"StringExample", "IntegerExample", "ChangedInComparison"}, (
        f"unexpected changed keys: {sorted(changed)}"
    )

    print("PASS - synthetic fixture diff contract: 1 added, 1 removed, 3 changed")


if __name__ == "__main__":
    main()
