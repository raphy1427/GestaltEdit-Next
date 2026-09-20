#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "GestaltEdit"
access = (SRC / "GestaltAccess.m").read_text()
auto = (SRC / "AutomationCommand.swift").read_text()
view = (SRC / "ContentView.swift").read_text()

checks = {
    "low-level connect has build gate": "if (!GestaltAccess.isRunningSupportedOS)" in access,
    "save method has independent build gate": access.count("if (!GestaltAccess.isRunningSupportedOS)") >= 2,
    "automation has build gate": "guard GestaltAccess.isRunningSupportedOS() else" in auto,
    "research probe opens read-only": "O_RDONLY | O_CLOEXEC | O_NOFOLLOW" in access,
    "research UI labels write probe disabled": 'LabeledContent("MobileGestalt write probe", value: "Disabled")' in view,
    "research probe does not call saveGestalt": "runReadOnlyProbe" in access and "saveGestalt" not in access[access.index("- (NSDictionary<NSString *, id> *)runReadOnlyProbe"):access.index("#pragma mark - Connection")],
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("PASS" if ok else "FAIL") + " - " + name)

if failed:
    print(f"\n{len(failed)} audit check(s) failed.")
    sys.exit(1)
print("\nResearch Mode static safety audit passed.")
