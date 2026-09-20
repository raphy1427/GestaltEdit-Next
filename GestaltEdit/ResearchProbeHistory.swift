import Foundation

enum ResearchProbeHistory {
    struct Entry: Codable, Identifiable {
        let id: UUID
        let recordedAt: Date
        let osVersion: String
        let build: String
        let fingerprint: String
        let result: String
        let assessment: String
        let writeAttempted: Bool
    }

    private static let key = "GestaltEditNext.ResearchProbeHistory.v1"
    private static let limit = 10

    static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return entries.sorted { $0.recordedAt > $1.recordedAt }
    }

    static func record(_ probe: ResearchProbeResult) -> [Entry] {
        let assessment = ResearchProbeAssessment.evaluate(probe)
        let entry = Entry(
            id: probe.runID,
            recordedAt: probe.generatedAt,
            osVersion: probe.raw["osVersion"] as? String ?? GestaltAccess.currentOSVersionString(),
            build: probe.raw["build"] as? String ?? GestaltAccess.currentOSBuild(),
            fingerprint: probe.diagnosticFingerprint,
            result: probe.summary,
            assessment: assessment.title,
            writeAttempted: probe.writeAttempted
        )

        var entries = load()
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(limit))

        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return entries
    }

    static func latest(forBuild build: String) -> Entry? {
        load().first { $0.build == build }
    }
}
