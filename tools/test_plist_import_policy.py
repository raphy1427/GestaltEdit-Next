#!/usr/bin/env python3
"""Validate GestaltEdit's offline plist import size policy."""
import plistlib
import sys

MAX_IMPORT_BYTES = 32 * 1024 * 1024
failures = []

def check(ok, message):
    print(("PASS" if ok else "FAIL") + " - " + message)
    if not ok:
        failures.append(message)

def accepted(data):
    if not data or len(data) > MAX_IMPORT_BYTES:
        return False
    try:
        root = plistlib.loads(data)
    except Exception:
        return False
    return isinstance(root, dict) and isinstance(root.get("CacheExtra"), dict)

valid = plistlib.dumps({"CacheExtra": {"Example": True}}, fmt=plistlib.FMT_BINARY)
check(accepted(valid), "valid synthetic plist is accepted")
check(not accepted(b""), "empty import is rejected")
check(not accepted(b"x" * (MAX_IMPORT_BYTES + 1)), "import above 32 MB is rejected")
check(not accepted(plistlib.dumps(["not", "a", "dictionary"])), "array root is rejected")
check(not accepted(plistlib.dumps({"CacheData": {}})), "missing CacheExtra is rejected")
check(not accepted(b"not a plist"), "corrupt data is rejected")

if failures:
    sys.exit(1)
print("\nOffline plist import policy validation passed.")
