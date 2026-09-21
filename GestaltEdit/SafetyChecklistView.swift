import SwiftUI

struct SafetyChecklistView: View {
    private var isVerifiedBuild: Bool {
        GestaltAccess.isRunningSupportedOS()
    }

    private var hasLegacyPrimitive: Bool {
        GestaltAccess.isLegacyAccessPrimitiveAvailable()
    }

    private var backupStatus: ChecklistStatus {
        do {
            return try GestaltBackupStore.list().isEmpty ? .warning : .ready
        } catch {
            return .blocked
        }
    }

    var body: some View {
        List {
            Section {
                Label("Preflight Safety Check", systemImage: "checklist.checked")
                    .font(.headline)
                Text("Review the conditions GestaltEdit uses before a protected-device change. This screen does not perform any write.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Write Gate") {
                checklistRow(
                    title: "Verified iOS build",
                    detail: isVerifiedBuild
                        ? "This build is in the verified write range."
                        : "This build is not verified. Protected-device writes remain disabled.",
                    status: isVerifiedBuild ? .ready : .blocked
                )

                checklistRow(
                    title: "Legacy access symbols",
                    detail: hasLegacyPrimitive
                        ? "Required legacy symbols are present."
                        : "Required legacy symbols are unavailable.",
                    status: hasLegacyPrimitive ? .ready : .blocked
                )
            }

            Section("Recovery") {
                checklistRow(
                    title: "Local backup history",
                    detail: backupDetail,
                    status: backupStatus
                )

                checklistRow(
                    title: "Automatic backup",
                    detail: "GestaltEdit creates a fresh backup before applying staged changes.",
                    status: .ready
                )
            }

            Section("Current Result") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(canAttemptProtectedWrite ? "Preflight conditions met" : "Protected write unavailable")
                            .font(.subheadline.weight(.semibold))
                        Text(resultDetail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: canAttemptProtectedWrite ? "checkmark.shield.fill" : "lock.shield.fill")
                        .foregroundStyle(canAttemptProtectedWrite ? .green : .orange)
                }
            }

            Section("Offline Tools") {
                NavigationLink {
                    MobileGestaltLabView()
                } label: {
                    Label("Open MobileGestalt Lab", systemImage: "flask")
                }

                Text("Offline plist inspection, editing, and comparison remain available even when protected-device writes are disabled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Safety Check")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canAttemptProtectedWrite: Bool {
        isVerifiedBuild && hasLegacyPrimitive
    }

    private var backupDetail: String {
        switch backupStatus {
        case .ready:
            return "At least one local backup is available."
        case .warning:
            return "No saved backup is currently available. A fresh backup is still required before apply."
        case .blocked:
            return "Backup history could not be read."
        }
    }

    private var resultDetail: String {
        if !isVerifiedBuild {
            return "Research Mode is active. Unsupported-build writes stay disabled."
        }
        if !hasLegacyPrimitive {
            return "The required legacy access symbols are unavailable, so the write path cannot proceed."
        }
        return "The compatibility gates pass. The normal Review Changes flow still performs the final backup and confirmation checks."
    }

    @ViewBuilder
    private func checklistRow(title: String, detail: String, status: ChecklistStatus) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private enum ChecklistStatus {
    case ready
    case warning
    case blocked

    var symbol: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .blocked: return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: return .green
        case .warning: return .orange
        case .blocked: return .red
        }
    }
}
