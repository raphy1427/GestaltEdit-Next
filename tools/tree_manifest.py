#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
include_roots = [root / "GestaltEdit", root / "GestaltEdit.xcodeproj", root / ".github" / "workflows", root / "tools"]
files = []
for base in include_roots:
    if not base.exists():
        continue
    for path in sorted(p for p in base.rglob("*") if p.is_file()):
        rel = path.relative_to(root).as_posix()
        if rel.endswith((".DS_Store", ".xcuserstate")):
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        files.append({"path": rel, "sha256": digest, "bytes": path.stat().st_size})

manifest = {
    "project": "GestaltEdit Next",
    "internalVersion": (root / "NEXT-VERSION").read_text().strip(),
    "files": files,
}
out = root / "GESTALTEDIT-NEXT-MANIFEST.json"
out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
print(f"Wrote {out.name} with {len(files)} files")
