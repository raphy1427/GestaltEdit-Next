#!/usr/bin/env python3
"""Verify synthetic plist fixtures survive safe offline plist round trips."""

from pathlib import Path
import plistlib

FIXTURE_DIR = Path("Tests/Fixtures")
FIXTURES = (
    FIXTURE_DIR / "mobilegestalt-baseline.plist",
    FIXTURE_DIR / "mobilegestalt-comparison.plist",
)


def normalized_roundtrip(payload: object, fmt: plistlib.PlistFormat) -> object:
    encoded = plistlib.dumps(payload, fmt=fmt, sort_keys=True)
    return plistlib.loads(encoded)


def main() -> None:
    for path in FIXTURES:
        original = plistlib.loads(path.read_bytes())
        assert isinstance(original, dict), f"{path}: top level must be a dictionary"

        xml = normalized_roundtrip(original, plistlib.FMT_XML)
        binary = normalized_roundtrip(original, plistlib.FMT_BINARY)

        assert xml == original, f"{path}: XML round trip changed values or types"
        assert binary == original, f"{path}: binary round trip changed values or types"
        assert xml == binary, f"{path}: XML and binary decoders disagree"

        xml_once = plistlib.dumps(original, fmt=plistlib.FMT_XML, sort_keys=True)
        xml_twice = plistlib.dumps(plistlib.loads(xml_once), fmt=plistlib.FMT_XML, sort_keys=True)
        assert xml_once == xml_twice, f"{path}: canonical XML serialization is not deterministic"

        print(f"PASS - {path} round trips losslessly through XML and binary plist formats")


if __name__ == "__main__":
    main()
