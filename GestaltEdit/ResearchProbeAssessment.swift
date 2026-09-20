import Foundation

struct ResearchProbeAssessment {
    let title: String
    let explanation: String
    let nextStep: String
    let severity: Severity

    enum Severity: Equatable {
        case informational
        case limited
        case blocked
    }

    static func evaluate(_ probe: ResearchProbeResult) -> ResearchProbeAssessment {
        if probe.writeAttempted {
            return .init(
                title: "Safety invariant violated",
                explanation: "The diagnostic unexpectedly reported a write attempt. Do not continue testing this build.",
                nextStep: "Stop and inspect the source before running another probe.",
                severity: .blocked
            )
        }

        if probe.readSucceeded {
            return .init(
                title: "Legacy path still grants read access",
                explanation: "The old access chain reached the MobileGestalt cache and a read-only open/read succeeded. This proves only read reachability; it does not prove that writes are possible or safe.",
                nextStep: "Preserve this report. The next engineering step is to compare the read-capable path with the separately guarded write path without writing to the real plist.",
                severity: .informational
            )
        }

        if probe.readOpenSucceeded {
            return .init(
                title: "Read-only open succeeded but read failed",
                explanation: "The sandbox path progressed far enough to open the file descriptor, but the kernel rejected or failed the actual read.",
                nextStep: "Use the recorded errno and exact stage to inspect whether file-protection or descriptor behavior changed on this build.",
                severity: .limited
            )
        }

        if probe.leaseAcquired {
            return .init(
                title: "Sandbox lease acquired, file open blocked",
                explanation: "The legacy query produced and consumed a sandbox extension, but the MobileGestalt plist could not be opened read-only.",
                nextStep: "Compare the target path, sandbox extension class, and post-lease access result against a known beta 1–4 device or upstream implementation.",
                severity: .limited
            )
        }

        switch probe.leaseStage ?? probe.stage {
        case "symbol-discovery", "symbols":
            return .init(
                title: "Required private symbols are unavailable",
                explanation: "At least one ContainerManager or sandbox-extension symbol used by the legacy method is no longer available under the expected name.",
                nextStep: "Compare exported symbols and upstream changes before considering any deeper testing.",
                severity: .blocked
            )
        case "query-create":
            return .init(
                title: "Container query creation failed",
                explanation: "The private APIs are present, but the legacy query object could not be created.",
                nextStep: "Check whether the query API contract changed on this iOS build.",
                severity: .blocked
            )
        case "query-configure":
            return .init(
                title: "Legacy query setup did not complete",
                explanation: "The query was created but failed before a result could be requested.",
                nextStep: "Compare the class, part, domain and flags with current ContainerManager behavior.",
                severity: .blocked
            )
        case "query-result":
            return .init(
                title: "ContainerManager rejected the legacy query",
                explanation: "The old traversal-style query reached ContainerManager but did not return a usable result. This is a strong indication that the original primitive is patched at the query/result layer.",
                nextStep: "Do not bypass the app's build check. A replacement access primitive would be needed before MobileGestalt writes can be considered.",
                severity: .blocked
            )
        case "sandbox-token":
            return .init(
                title: "No sandbox token was issued",
                explanation: "ContainerManager returned a result, but it did not yield the sandbox extension expected by the old method.",
                nextStep: "Compare result object behavior and token-generation semantics with a known supported beta.",
                severity: .blocked
            )
        case "sandbox-consume":
            return .init(
                title: "Sandbox token could not be consumed",
                explanation: "A token was produced but iOS refused to activate it for this process.",
                nextStep: "Inspect sandbox-extension behavior on this build; do not attempt writes.",
                severity: .blocked
            )
        default:
            return .init(
                title: "Probe did not reach read access",
                explanation: probe.detail,
                nextStep: "Use the JSON report to compare the failing stage with a supported build or upstream research.",
                severity: .limited
            )
        }
    }
}
