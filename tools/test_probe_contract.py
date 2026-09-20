#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
access = (root / "GestaltEdit/GestaltAccess.m").read_text()
bridge = (root / "GestaltEdit/BadQueryBridge.m").read_text()
result = (root / "GestaltEdit/ResearchProbeResult.swift").read_text()
assessment = (root / "GestaltEdit/ResearchProbeAssessment.swift").read_text()

checks = []
def check(name, ok):
    checks.append((name, bool(ok)))

check("probe schema version present", 'result[@"schemaVersion"] = @2;' in access)
check("probe explicitly records no write", 'result[@"writeAttempted"] = @NO;' in access)
probe_body = access.split('- (NSDictionary<NSString *, id> *)runReadOnlyProbe', 1)[1].split('#pragma mark - Connection', 1)[0]
check("probe uses O_RDONLY", 'O_RDONLY | O_CLOEXEC | O_NOFOLLOW' in probe_body)
check("probe does not use O_WRONLY", 'O_WRONLY' not in probe_body)
check("probe does not use O_RDWR", 'O_RDWR' not in probe_body)
check("typed result forces exported writeAttempted false", 'export["writeAttempted"] = false' in result)
check("assessment handles query-result patch point", 'case "query-result"' in assessment)
check("assessment warns not to bypass build check", "Do not bypass the app's build check" in assessment)
check("bridge frees query after token", 'free(token);\n    api->freeQuery(query);' in bridge)
check("lease invalidates sandbox handle", 'releaseSandboxExtension(_sandboxHandle)' in bridge)

for name, ok in checks:
    print(("PASS" if ok else "FAIL") + " - " + name)

if not all(ok for _, ok in checks):
    sys.exit(1)
print("\nResearch probe contract tests passed.")
