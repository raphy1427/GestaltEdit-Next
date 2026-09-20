#!/usr/bin/env python3
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "GestaltEdit"
PBX = ROOT / "GestaltEdit.xcodeproj" / "project.pbxproj"

required = [
    SRC / "GestaltEditApp.swift",
    SRC / "ContentView.swift",
    SRC / "GestaltViewModel.swift",
    SRC / "GestaltAccess.h",
    SRC / "GestaltAccess.m",
    SRC / "BadQueryBridge.h",
    SRC / "BadQueryBridge.m",
    SRC / "GestaltEdit-Bridging-Header.h",
    PBX,
]

failures = []

for path in required:
    if path.exists():
        print(f"PASS - exists: {path.relative_to(ROOT)}")
    else:
        failures.append(f"missing {path.relative_to(ROOT)}")
        print(f"FAIL - missing: {path.relative_to(ROOT)}")

if PBX.exists():
    text = PBX.read_text(errors="replace")
    checks = {
        "iOS deployment target is 27.0": "IPHONEOS_DEPLOYMENT_TARGET = 27.0;" in text,
        "Swift version configured": "SWIFT_VERSION = 5.0;" in text,
        "automatic signing configured": "CODE_SIGN_STYLE = Automatic;" in text,
        "filesystem-synchronized source group": "PBXFileSystemSynchronizedRootGroup" in text,
    }
    for name, ok in checks.items():
        print(("PASS" if ok else "FAIL") + " - " + name)
        if not ok:
            failures.append(name)

bridge = SRC / "GestaltEdit-Bridging-Header.h"
if bridge.exists():
    b = bridge.read_text()
    ok = '#import "GestaltAccess.h"' in b
    print(("PASS" if ok else "FAIL") + " - bridging header imports GestaltAccess.h")
    if not ok:
        failures.append("bridging header missing GestaltAccess.h")

content = SRC / "ContentView.swift"
if content.exists():
    c = content.read_text()
    ok = "Task.detached" not in c
    print(("PASS" if ok else "FAIL") + " - Research Mode avoids non-Sendable Task.detached bridge")
    if not ok:
        failures.append("Task.detached remains in Research Mode")

swiftc = shutil.which("swiftc")
if swiftc:
    swift_files = sorted(SRC.glob("*.swift"))
    for path in swift_files:
        proc = subprocess.run([swiftc, "-parse", str(path)], capture_output=True, text=True)
        if proc.returncode == 0:
            print(f"PASS - swift parse: {path.name}")
        else:
            print(f"FAIL - swift parse: {path.name}")
            failures.append(f"Swift parse failed: {path.name}: {proc.stderr.strip()}")
else:
    print("SKIP - swiftc not available; Swift parse validation not run")

# Basic Objective-C structural checks that do not require Apple's SDK.
for name in ["GestaltAccess.m", "BadQueryBridge.m"]:
    path = SRC / name
    if not path.exists():
        continue
    t = path.read_text()
    impls = len(re.findall(r"@implementation\b", t))
    ends = len(re.findall(r"@end\b", t))
    ok = ends >= impls and impls > 0
    print(("PASS" if ok else "FAIL") + f" - Objective-C structure: {name}")
    if not ok:
        failures.append(f"Objective-C structure check failed: {name}")

if failures:
    print("\nPreflight FAILED:")
    for item in failures:
        print(" - " + item)
    sys.exit(1)

print("\nGestaltEdit Next preflight passed. Full compilation still requires Xcode + the iOS SDK.")
