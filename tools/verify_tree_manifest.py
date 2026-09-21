#!/usr/bin/env python3
"""Verify that the checked-in tree manifest matches tracked project files."""
from pathlib import Path
import hashlib, json, sys

root=Path(__file__).resolve().parents[1]
manifest_path=root/"GESTALTEDIT-NEXT-MANIFEST.json"
manifest=json.loads(manifest_path.read_text())
expected_version=(root/"NEXT-VERSION").read_text().strip()
failures=[]
if manifest.get("internalVersion") != expected_version:
    failures.append(f"manifest version {manifest.get('internalVersion')} != {expected_version}")

include=[root/"GestaltEdit",root/"GestaltEdit.xcodeproj",root/".github"/"workflows",root/"tools"]
actual={}
for base in include:
    if not base.exists(): continue
    for p in sorted(x for x in base.rglob("*") if x.is_file()):
        rel=p.relative_to(root).as_posix()
        if rel.endswith((".DS_Store",".xcuserstate")): continue
        actual[rel]={"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"bytes":p.stat().st_size}

listed={x["path"]:{"sha256":x["sha256"],"bytes":x["bytes"]} for x in manifest.get("files",[])}
for path in sorted(set(actual)-set(listed)): failures.append("missing from manifest: "+path)
for path in sorted(set(listed)-set(actual)): failures.append("stale manifest entry: "+path)
for path in sorted(set(actual)&set(listed)):
    if actual[path] != listed[path]: failures.append("metadata mismatch: "+path)

for f in failures: print("FAIL - "+f)
if failures: sys.exit(1)
print(f"PASS - manifest {expected_version} matches {len(actual)} project files")
