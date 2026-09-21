#!/usr/bin/env python3
"""Ensure offline plist fixtures remain unmistakably synthetic test data."""
from pathlib import Path
import plistlib
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = sorted((ROOT / "Tests" / "Fixtures").glob("mobilegestalt-*.plist"))
failures = []


def check(ok, message):
    print(("PASS" if ok else "FAIL") + " - " + message)
    if not ok:
        failures.append(message)


check(bool(FIXTURES), "synthetic MobileGestalt-style fixtures are present")
for path in FIXTURES:
    try:
        with path.open("rb") as handle:
            root = plistlib.load(handle)
    except Exception as exc:
        failures.append(f"{path.name} parses: {exc}")
        continue

    cache_data = root.get("CacheData", {}) if isinstance(root, dict) else {}
    check(isinstance(root.get("FixtureVersion") if isinstance(root, dict) else None, str),
          f"{path.name} declares FixtureVersion")
    check(cache_data.get("ExampleBuild") == "TEST-ONLY",
          f"{path.name} build marker is TEST-ONLY")
    model = cache_data.get("ExampleModel", "")
    check(isinstance(model, str) and "Test-Device" in model,
          f"{path.name} model is explicitly synthetic")

    text = path.read_bytes()
    for forbidden in (b"SerialNumber", b"UniqueDeviceID", b"InternationalMobileEquipmentIdentity", b"IntegratedCircuitCardIdentity"):
        check(forbidden not in text, f"{path.name} excludes real-device identifier field {forbidden.decode()}")

if failures:
    print("\nSynthetic fixture provenance validation FAILED:")
    for failure in failures:
        print(" - " + failure)
    sys.exit(1)

print("\nSynthetic fixture provenance validation passed.")
