#!/usr/bin/env python3
"""Validate positive and negative synthetic plist fixtures."""
from pathlib import Path
import plistlib
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / "Tests" / "Fixtures"
subprocess.run([sys.executable, str(ROOT / "tools" / "generate_plist_edge_fixtures.py")], check=True)

failures=[]

def check(ok,msg):
    print(("PASS" if ok else "FAIL")+" - "+msg)
    if not ok: failures.append(msg)

with (FIX/"mobilegestalt-baseline.plist").open("rb") as f:
    xml=plistlib.load(f)
with (FIX/"mobilegestalt-baseline-binary.plist").open("rb") as f:
    binary=plistlib.load(f)
check(xml==binary,"binary fixture round-trips to the same property-list values")
check((FIX/"mobilegestalt-baseline-binary.plist").read_bytes().startswith(b"bplist00"),"binary fixture uses binary plist format")

with (FIX/"missing-cache-extra.plist").open("rb") as f:
    missing=plistlib.load(f)
check(isinstance(missing,dict) and "CacheExtra" not in missing,"missing-CacheExtra negative fixture is valid")

with (FIX/"array-root.plist").open("rb") as f:
    array=plistlib.load(f)
check(isinstance(array,list),"array-root negative fixture is valid")

try:
    plistlib.loads((FIX/"corrupt.plist").read_bytes())
    corrupt_rejected=False
except Exception:
    corrupt_rejected=True
check(corrupt_rejected,"corrupt plist is rejected by the parser")

if failures:
    sys.exit(1)
print("\nEdge-case plist fixture validation passed.")
