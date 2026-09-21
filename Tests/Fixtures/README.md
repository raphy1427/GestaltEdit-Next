# GestaltEdit synthetic plist fixtures

These files are **test data only**. They are not extracted from an iPhone and must not be presented as genuine MobileGestalt data.

- `mobilegestalt-baseline.plist` covers common property-list value types and nested values.
- `mobilegestalt-comparison.plist` changes values, removes one field, and adds another so the offline comparison UI exercises changed/added/removed results.

The fixtures intentionally include `CacheData` and `CacheExtra` containers because GestaltEdit's offline lab/comparison workflows expect MobileGestalt-style structure. They contain no device identifiers or protected data.

Real-device compatibility remains a separate validation milestone.
