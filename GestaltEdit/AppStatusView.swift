import SwiftUI

struct AppStatusView: View {
    @State private var backupCount = 0
    @State private var backupLoadFailed = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    private var osBuild: String {
        let build = GestaltAccess.currentOSBuild()
        return build.isEmpty ? "Unknown" : build
    }

    private var isVerifiedBuild: Bool {
        GestaltAccess.isRunningSupportedOS()
    }

    var body: some View {
        List {
            Section("App") {
                LabeledContent("Name", value: "GestaltEdit Next")
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: appBuild)
            }

            Section("Device") {
                LabeledContent("Model", value: GestaltAccess.currentDeviceIdentifier())
                LabeledContent("iOS", value: GestaltAccess.currentOSVersionString())
                LabeledContent("Darwin build", value: osBuild)
            }

            Section("Compatibility") {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isVerifiedBuild ? "Verified build" : "Research Mode")
                            .font(.subheadline.weight(.semibold))
                        Text(isVerifiedBuild
                             ? "This build is in GestaltEdit's verified beta 1–4 write range."
                             : "MobileGestalt writes are disabled on this build.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: isVerifiedBuild ? "checkmark.shield.fill" : "lock.shield.fill")
                        .foregroundStyle(isVerifiedBuild ? .green : .orange)
                }

                LabeledContent("Write support", value: isVerifiedBuild ? "Verified" : "Disabled")
                LabeledContent("Legacy symbols",
                               value: GestaltAccess.isLegacyAccessPrimitiveAvailable() ? "Present" : "Unavailable")
            }

            Section("Local Data") {
                LabeledContent("Saved backups", value: backupLoadFailed ? "Unavailable" : String(backupCount))
                LabeledContent("Research reports", value: String(ResearchProbeHistory.load().count))
                Text("Backups and research summaries stay on this device unless you explicitly share or export them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Safety") {
                Text(isVerifiedBuild
                     ? "GestaltEdit creates a backup before applying staged changes. System modifications can still require a restore if iOS becomes unstable."
                     : "Research Mode is read-only. The tweak editor and MobileGestalt write path remain unavailable on this build.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Status")
        .task { refreshLocalData() }
        .refreshable { refreshLocalData() }
    }

    private func refreshLocalData() {
        do {
            backupCount = try GestaltBackupStore.list().count
            backupLoadFailed = false
        } catch {
            backupLoadFailed = true
        }
    }
}
