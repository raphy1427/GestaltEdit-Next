#!/usr/bin/env python3
"""Generate additional binary and malformed plist fixtures for offline validation."""
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / "Tests" / "Fixtures"
source = FIX / "mobilegestalt-baseline.plist"
with source.open("rb") as handle:
    baseline = plistlib.load(handle)

with (FIX / "mobilegestalt-baseline-binary.plist").open("wb") as handle:
    plistlib.dump(baseline, handle, fmt=plistlib.FMT_BINARY, sort_keys=False)

# Valid plist, intentionally missing CacheExtra.
missing = dict(baseline)
missing.pop("CacheExtra", None)
with (FIX / "missing-cache-extra.plist").open("wb") as handle:
    plistlib.dump(missing, handle, fmt=plistlib.FMT_XML, sort_keys=False)

# Valid plist with an invalid top-level shape for GestaltEdit.
with (FIX / "array-root.plist").open("wb") as handle:
    plistlib.dump(["not", "a", "dictionary"], handle, fmt=plistlib.FMT_XML)

# Deliberately corrupt bytes for parser error handling.
(FIX / "corrupt.plist").write_bytes(b"not-a-property-list\x00\xff")

print("Generated binary and negative plist fixtures.")
