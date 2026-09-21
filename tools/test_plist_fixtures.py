#!/usr/bin/env python3
"""Validate GestaltEdit's synthetic MobileGestalt-style plist fixtures."""
from pathlib import Path
import plistlib
import sys

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / "Tests" / "Fixtures"
BASE = FIX / "mobilegestalt-baseline.plist"
COMP = FIX / "mobilegestalt-comparison.plist"

failures = []

def check(ok, message):
    print(("PASS" if ok else "FAIL") + " - " + message)
    if not ok:
        failures.append(message)

def load(path):
    with path.open("rb") as handle:
        return plistlib.load(handle)

for path in (BASE, COMP):
    check(path.exists(), f"fixture exists: {path.name}")

if not failures:
    baseline = load(BASE)
    comparison = load(COMP)
    for name, obj in (("baseline", baseline), ("comparison", comparison)):
        check(isinstance(obj, dict), f"{name} top level is a dictionary")
        check(isinstance(obj.get("CacheExtra"), dict), f"{name} contains CacheExtra dictionary")
        check(isinstance(obj.get("CacheData"), dict), f"{name} contains CacheData dictionary")

    cache = baseline["CacheExtra"]
    check(isinstance(cache.get("BooleanExample"), bool), "boolean fixture parses as bool")
    check(isinstance(cache.get("StringExample"), str), "string fixture parses as string")
    check(type(cache.get("IntegerExample")) is int, "integer fixture parses as int")
    check(isinstance(cache.get("RealExample"), float), "real fixture parses as float")
    check(hasattr(cache.get("DateExample"), "isoformat"), "date fixture parses as date")
    check(isinstance(cache.get("DataExample"), bytes), "data fixture parses as bytes")
    check(isinstance(cache.get("ArrayExample"), list), "array fixture parses as array")
    check(isinstance(cache.get("DictionaryExample"), dict), "nested fixture parses as dictionary")

    left = baseline["CacheExtra"]
    right = comparison["CacheExtra"]
    check(left["ChangedInComparison"] != right["ChangedInComparison"], "changed-value case is present")
    check("RemovedInComparison" in left and "RemovedInComparison" not in right, "removed-key case is present")
    check("AddedInComparison" not in left and "AddedInComparison" in right, "added-key case is present")

if failures:
    print("\nFixture validation FAILED:")
    for failure in failures:
        print(" - " + failure)
    sys.exit(1)

print("\nSynthetic plist fixture validation passed.")
