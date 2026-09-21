import SwiftUI

struct BackupLibraryView: View {
    @State private var backups: [GestaltBackup] = []
    @State private var loadError: String?
    @State private var pendingDeletion: GestaltBackup?

    var body: some View {
        List {
            if let loadError {
                Section {
                    ContentUnavailableView(
                        "Backups Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                }
            } else if backups.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Backups Yet",
                        systemImage: "archivebox",
                        description: Text("GestaltEdit creates a local backup before a supported write. Backups stay on this device until you delete them.")
                    )
                }
            } else {
                Section("Saved Backups") {
                    ForEach(backups) { backup in
                        NavigationLink {
                            BackupDetailView(backup: backup)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(backup.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)

                                Text(backup.createdAt.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(ByteCountFormatter.string(fromByteCount: backup.byteCount, countStyle: .file))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = backup
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Section {
                    Text("Deleting a backup only removes GestaltEdit's local copy. It does not modify MobileGestalt or any other system file.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Backup Library")
        .task { reload() }
        .refreshable { reload() }
        .confirmationDialog(
            "Delete this backup?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Backup", role: .destructive) {
                deletePendingBackup()
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func reload() {
        do {
            backups = try GestaltBackupStore.list()
            loadError = nil
        } catch {
            backups = []
            loadError = error.localizedDescription
        }
    }

    private func deletePendingBackup() {
        guard let backup = pendingDeletion else { return }
        pendingDeletion = nil

        do {
            try GestaltBackupStore.delete(backup)
            reload()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct BackupDetailView: View {
    let backup: GestaltBackup

    private var inspection: BackupInspection {
        GestaltBackupInspector.inspect(backup)
    }

    var body: some View {
        let result = inspection

        List {
            Section("Backup") {
                LabeledContent("Created", value: backup.createdAt.formatted(date: .abbreviated, time: .standard))
                LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: backup.byteCount, countStyle: .file))
                Text(backup.name)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("Integrity") {
                Label(
                    result.isValid ? "Structure looks valid" : "Backup needs attention",
                    systemImage: result.isValid ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(result.isValid ? .green : .orange)

                LabeledContent("Format", value: result.format)
                LabeledContent("Top-level keys", value: String(result.topLevelKeyCount))
                LabeledContent("CacheExtra keys", value: String(result.cacheExtraKeyCount))
                LabeledContent("Parsed size", value: ByteCountFormatter.string(fromByteCount: Int64(result.byteCount), countStyle: .file))

                Text(result.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Safety") {
                Text("This screen only reads GestaltEdit's saved local backup. It does not access or write the protected MobileGestalt file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Backup Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
