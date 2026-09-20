# GestaltEdit Next - Research Mode

This development build keeps the original GestaltEdit beta 1-4 behavior intact, but changes unsupported iOS 27 builds from a dead-end warning into a safe diagnostic Research Mode.

## Safety behavior

On an unsupported build, Research Mode:

- shows the exact iOS version, Darwin build, and device identifier;
- checks only whether the legacy ContainerManager symbols are present;
- does **not** create a `bad_query` container query;
- does **not** consume a sandbox extension;
- does **not** open `com.apple.MobileGestalt.plist`;
- does **not** attempt a read or write;
- leaves the original verified beta 1-4 path unchanged.

The next milestone is a separate, explicitly read-only diagnostic path.


## Internal milestone 0.2 — Read-only probe

Research Mode now includes a manual, read-only diagnostic for iOS/iPadOS 27 builds outside the verified beta 1–4 write window. The probe may exercise the legacy sandbox-access primitive, but it opens `com.apple.MobileGestalt.plist` with `O_RDONLY` only, reads at most a 16-byte prefix for reachability testing, exposes no plist values, performs no write, and releases the temporary sandbox lease before returning.


## Internal milestone 0.3 — Diagnostic breakdown

Research Mode now reports the legacy ContainerManager symbols individually, records whether the MobileGestalt path appears readable before and after the temporary sandbox lease, captures non-sensitive file metadata after a successful read-only open, and can copy a compact diagnostic report for comparing builds. It still performs no write test and does not expose MobileGestalt contents.


## Internal milestone 0.4 — Structured legacy-query tracing

The read-only probe now records the exact legacy access stage reached: symbol discovery, query creation, query configuration, ContainerManager result lookup, sandbox-token creation, sandbox-token consumption, or active lease. This should make a post-beta-4 failure substantially easier to localize once the test build is run on hardware. No write path was added.

## Internal milestone 0.5 — Non-blocking probe + fuller report

The Research Mode probe now runs off the main UI thread so a rejected or slow private-API call cannot freeze the interface while diagnostics are collected. The UI keeps a visible progress state, updates only after the probe finishes, and the copied report now includes the read-only file metadata already gathered by the Objective-C layer (UID, GID, mode and size). No write capability was added.

## Internal milestone 0.6 — Write-lock hardening

Research Mode's safety boundary is now enforced outside the UI as well. The command-line `--set-us-region` automation path explicitly refuses to run on any build outside the verified beta 1–4 allowlist, so launching the app with automation arguments cannot bypass the Research Mode screen. The lower-level `connectWithError:` method already enforces the same allowlist, giving the project two independent write guards.

## Internal milestone 0.7 — Compile-readiness and defense-in-depth audit

The verified beta build list is now centralized in a single immutable set instead of a long boolean expression. `saveGestalt:error:` also has its own explicit verified-build guard before serialization or any write-oriented file open, so a future refactor of `connectWithError:` cannot accidentally remove the Research Mode write boundary. A small static audit tool was added under `tools/` to verify that the low-level connection path, save path, automation path, and Research Mode UI all retain their write protections and that the research probe still opens the target with `O_RDONLY` only.

## Internal milestone 0.8 — Swift syntax validation

All Swift source files in the cumulative project were run through `swiftc -parse` and passed parser validation: AutomationCommand.swift, ContentView.swift, GestaltBackupStore.swift, GestaltEditApp.swift, GestaltModels.swift, GestaltTweaks.swift, GestaltViewModel.swift, and NeoSpringView.swift. This is a syntax check only; a full iOS/Xcode build still requires Apple's iOS SDK and signing environment.

## Internal milestone 0.9 — Concurrency cleanup + build preflight

The Research Mode probe no longer returns an Objective-C `[String: Any]` dictionary across a detached Swift task boundary. It now performs the blocking probe on a GCD user-initiated queue and publishes the result back on the main queue, avoiding a likely Swift concurrency/Sendable warning or future error while keeping the UI responsive. A new `tools/preflight.py` script validates the expected source files, Xcode project settings, bridging header, Research Mode concurrency pattern, Swift syntax, and basic Objective-C source structure before the first real Xcode build.

## Internal milestone 0.10 — Typed diagnostics + machine-readable reports

Research Mode now wraps the Objective-C probe dictionary in a typed Swift `ResearchProbeResult`, adds a stable diagnostic schema version, and can export either a human-readable report or pretty-printed JSON. The low-level probe also records whether the target path exists, whether it is a symlink, and explicit `errno` text for read-only open/read failures. No MobileGestalt contents are included in reports and no write path is enabled.

## Internal milestone 0.11 — Probe interpretation + regression contract

Research Mode now interprets each diagnostic stage into a concise engineering assessment and next step, distinguishing symbol loss, query rejection, token-generation failure, token-consumption failure, lease-without-open, and successful read-only reachability. Reports can also be shared directly from the app. A new regression-contract test verifies that the probe remains read-only, never reports a write, releases the sandbox lease, and keeps the build-check warning in the interpretation layer.

## Internal milestone 0.12 — Free Xcode 27 CI + separate app identity

The project now includes a GitHub Actions CI workflow using GitHub's `xcode-27` hosted runner. It runs the safety audit, preflight, probe-contract tests, performs a real unsigned iOS build with Xcode 27, packages the resulting app as an unsigned IPA, and uploads the IPA plus the full Xcode build log as workflow artifacts. This gives the project a no-cost build path when hosted in a public GitHub repository. The development app now uses display name `GestaltEdit Next`, bundle identifier `me.ssus.gestaltedit.next`, marketing version `1.3.0`, and build number `9`, so it can be kept separate from the original GestaltEdit during testing.

No external API is required by the app itself; Research Mode is fully local and does not send diagnostic data anywhere.

## Internal milestone 0.13 — Reproducible source snapshot + report provenance

Diagnostic reports now include the app marketing version and build number, making hardware reports traceable to the exact test build. The repository includes a deterministic SHA-256 manifest generator and a source-packaging script so each checkpoint can be archived reproducibly without build artifacts or user-specific Xcode data. The app remains fully local and performs no network calls.

### First hardware-test gate

At this point the next unknown cannot be resolved statically: the post-beta-4 device must execute the read-only probe so we can see which private-access stage actually fails. Before that test, the Xcode 27 CI build should pass. The first device test must use Research Mode only; no MobileGestalt write path is enabled on the unsupported build.


## Internal milestone 0.14 — Hardware-test provenance + compact summary

Research Mode now gives every probe run a unique run ID and UTC timestamp, includes both in text/JSON exports, and adds a compact hardware-test summary for quickly sending the exact device/build/result without exposing MobileGestalt contents. The screen also includes an explicit four-step hardware-test protocol so unsupported builds are tested consistently. Build number is now 10. No write behavior was added or enabled.
