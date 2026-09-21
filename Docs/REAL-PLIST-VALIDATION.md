# Real-device plist validation checkpoint

GestaltEdit Next can be developed and tested with synthetic fixtures up to this checkpoint. The next compatibility milestone requires a **legitimately obtained plist sample supplied by the tester**.

## What the validation needs

Use a copy of the plist, not a protected live-system path. The validation is offline and read-only. Before sharing or committing anything, remove personal/device identifiers where possible.

The app should verify only structural compatibility:

- the file parses as an XML or binary property list
- the root is a dictionary
- a `CacheExtra` dictionary is present
- whether `CacheData` is present and how many keys it contains
- value types used by real data are represented correctly in the browser
- search, comparison, diagnostics, and export round-trips behave correctly

## What this checkpoint does not authorize

It does not add or justify sandbox bypasses, exploit primitives, protected-device reads, or unsupported MobileGestalt writes. Unsupported-build writes remain disabled.

## Pass criteria

A real sample passes the compatibility checkpoint when it imports without a structural error, displays its fields without crashes or truncation bugs, can be compared against an offline copy, and an unchanged export round-trips without changing plist values.

Synthetic CI remains required even after real-device validation.
