#!/usr/bin/env python3
from pathlib import Path
import shutil
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
version = (root / "NEXT-VERSION").read_text().strip()
out = root.parent / f"GestaltEdit-Next-{version}-source.zip"
ignore_names = {".git", "DerivedData", "build", ".DS_Store", "xcuserdata"}

with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if any(part in ignore_names for part in rel.parts):
            continue
        if path.is_file():
            z.write(path, Path(f"GestaltEdit-Next-{version}") / rel)
print(out)
