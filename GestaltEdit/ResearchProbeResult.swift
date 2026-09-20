import Foundation

struct ResearchProbeResult {
    let raw: [String: Any]
    let runID: UUID
    let generatedAt: Date

    init(raw: [String: Any], runID: UUID = UUID(), generatedAt: Date = Date()) {
        self.raw = raw
        self.runID = runID
        self.generatedAt = generatedAt
    }

    var schemaVersion: Int { (raw["schemaVersion"] as? NSNumber)?.intValue ?? 1 }
    var stage: String { raw["stage"] as? String ?? "unknown" }
    var leaseStage: String? { raw["leaseStage"] as? String }
    var detail: String { raw["detail"] as? String ?? "No detail available." }
    var readSucceeded: Bool { raw["readSucceeded"] as? Bool ?? false }
    var readOpenSucceeded: Bool { raw["readOpenSucceeded"] as? Bool ?? false }
    var leaseAcquired: Bool { raw["leaseAcquired"] as? Bool ?? false }
    var writeAttempted: Bool { raw["writeAttempted"] as? Bool ?? false }

    var failureLayer: String {
        if readSucceeded { return "none" }
        if readOpenSucceeded { return "read" }
        if leaseAcquired { return "file-open" }

        switch leaseStage ?? stage {
        case "symbol-discovery", "symbols": return "symbol-discovery"
        case "query-create": return "query-create"
        case "query-configure": return "query-configure"
        case "query-result": return "query-result"
        case "sandbox-token": return "sandbox-token"
        case "sandbox-consume": return "sandbox-consume"
        default: return stage
        }
    }

    var queryResultReturned: Bool {
        if leaseAcquired || readOpenSucceeded || readSucceeded { return true }
        guard let leaseStage else { return false }
        return ["sandbox-token", "sandbox-consume", "lease-active"].contains(leaseStage)
    }

    var sandboxTokenIssued: Bool {
        if leaseAcquired || readOpenSucceeded || readSucceeded { return true }
        guard let leaseStage else { return false }
        return ["sandbox-consume", "lease-active"].contains(leaseStage)
    }

    var diagnosticFingerprint: String {
        let build = string("build", fallback: GestaltAccess.currentOSBuild())
        return [build, stage, leaseStage ?? "none", failureLayer].joined(separator: "|")
    }

    var summary: String {
        if readSucceeded { return "Read-only access succeeded" }
        if readOpenSucceeded { return "Opened read-only; read failed" }
        if leaseAcquired { return "Lease acquired; open failed" }
        switch stage {
        case "symbols": return "Required symbols unavailable"
        case "blocked": return "Probe blocked on this OS"
        case "lease": return "Legacy access primitive failed"
        default: return "Probe failed at \(stage)"
        }
    }

    var textReport: String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        var lines = [
            "GestaltEdit Next Research Report",
            "Run ID: \(runID.uuidString)",
            "Generated: \(Self.iso8601.string(from: generatedAt))",
            "App: \(appVersion) (\(appBuild))",
            "Schema: \(schemaVersion)",
            "Device: \(string("device", fallback: GestaltAccess.currentDeviceIdentifier()))",
            "iOS: \(string("osVersion", fallback: GestaltAccess.currentOSVersionString()))",
            "Build: \(string("build", fallback: GestaltAccess.currentOSBuild()))",
            "Verified write support: no",
            "Write attempted: \(yesNo(writeAttempted))",
            "Stage: \(stage)",
            "Failure layer: \(failureLayer)",
            "Diagnostic fingerprint: \(diagnosticFingerprint)",
            "Query result returned: \(yesNo(queryResultReturned))",
            "Sandbox token issued: \(yesNo(sandboxTokenIssued))"
        ]

        if let leaseStage { lines.append("Legacy query stage: \(leaseStage)") }

        let orderedKeys = [
            "leaseAcquired", "preLeaseReadable", "postLeaseReadable",
            "readOpenSucceeded", "readSucceeded", "fileExists", "isSymlink",
            "fileSize", "fileUID", "fileGID", "fileMode", "sampleBytesRead",
            "preLeaseErrnoText", "postLeaseErrnoText", "openErrnoText",
            "readErrnoText", "targetPath"
        ]

        for key in orderedKeys {
            if let value = raw[key] {
                lines.append("\(key): \(String(describing: value))")
            }
        }
        lines.append("Detail: \(detail)")
        return lines.joined(separator: "\n")
    }

    var jsonReport: String {
        var export = raw
        export["reportType"] = "GestaltEditNextResearchProbe"
        export["runID"] = runID.uuidString
        export["generatedAt"] = Self.iso8601.string(from: generatedAt)
        export["appVersion"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        export["appBuild"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        export["verifiedWriteSupport"] = false
        export["writeAttempted"] = false
        export["failureLayer"] = failureLayer
        export["diagnosticFingerprint"] = diagnosticFingerprint
        export["queryResultReturned"] = queryResultReturned
        export["sandboxTokenIssued"] = sandboxTokenIssued

        guard JSONSerialization.isValidJSONObject(export),
              let data = try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    var compactSummary: String {
        let assessment = ResearchProbeAssessment.evaluate(self)
        return [
            "GestaltEdit Next hardware test",
            "Run: \(runID.uuidString)",
            "iOS: \(string("osVersion", fallback: GestaltAccess.currentOSVersionString()))",
            "Build: \(string("build", fallback: GestaltAccess.currentOSBuild()))",
            "Result: \(summary)",
            "Failure layer: \(failureLayer)",
            "Fingerprint: \(diagnosticFingerprint)",
            "Assessment: \(assessment.title)",
            "Write attempted: \(yesNo(writeAttempted))"
        ].joined(separator: "\n")
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func string(_ key: String, fallback: String) -> String {
        (raw[key] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
    }

    private func yesNo(_ value: Bool) -> String { value ? "yes" : "no" }
}
