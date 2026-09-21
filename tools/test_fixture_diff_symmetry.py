#!/usr/bin/env python3
"""Verify semantic diff behavior is symmetric for synthetic plist fixtures."""

from pathlib import Path
import plistlib

FIXTURES = Path(__file__).resolve().parents[1] / "Tests" / "Fixtures"
BASELINE = FIXTURES / "mobilegestalt-baseline.plist"
COMPARISON = FIXTURES / "mobilegestalt-comparison.plist"


def load_cache_extra(path: Path) -> dict:
    with path.open("rb") as handle:
        root = plistlib.load(handle)
    assert isinstance(root, dict), f"{path.name}: root must be a dictionary"
    cache_extra = root.get("CacheExtra")
    assert isinstance(cache_extra, dict), f"{path.name}: CacheExtra must be a dictionary"
    return cache_extra


def classify(left: dict, right: dict) -> tuple[set[str], set[str], set[str], set[str]]:
    keys = set(left) | set(right)
    added = {key for key in keys if key not in left}
    removed = {key for key in keys if key not in right}
    changed = {key for key in keys if key in left and key in right and left[key] != right[key]}
    unchanged = {key for key in keys if key in left and key in right and left[key] == right[key]}
    return added, removed, changed, unchanged


def main() -> None:
    baseline = load_cache_extra(BASELINE)
    comparison = load_cache_extra(COMPARISON)

    forward = classify(baseline, comparison)
    reverse = classify(comparison, baseline)

    forward_added, forward_removed, forward_changed, forward_unchanged = forward
    reverse_added, reverse_removed, reverse_changed, reverse_unchanged = reverse

    assert forward_added == reverse_removed, "forward additions must become reverse removals"
    assert forward_removed == reverse_added, "forward removals must become reverse additions"
    assert forward_changed == reverse_changed, "changed keys must be direction-independent"
    assert forward_unchanged == reverse_unchanged, "unchanged keys must be direction-independent"

    all_forward = forward_added | forward_removed | forward_changed | forward_unchanged
    assert all_forward == set(baseline) | set(comparison), "every synthetic key must be classified exactly once"
    assert sum(map(len, forward)) == len(all_forward), "diff categories must not overlap"

    print(
        "PASS - synthetic fixture diff symmetry: "
        f"{len(forward_added)} added, {len(forward_removed)} removed, "
        f"{len(forward_changed)} changed, {len(forward_unchanged)} unchanged"
    )


if __name__ == "__main__":
    main()
