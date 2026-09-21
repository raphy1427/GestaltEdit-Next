import SwiftUI
import UniformTypeIdentifiers

struct BackupLibraryView: View {
    @State private var backups: [GestaltBackup] = []
    @State private var loadError: String?
    @State private var pendingDeletion: GestaltBackup?
    @State private var exportDocument: BackupExportDocument?
    @State private var exportFilename = "MobileGestalt_Backup.plist"
    @State private var showsExporter = false
    @State private var statusMessage: String?

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
                    LabeledContent("Backups", value: String(backups.count))
                    LabeledContent(
                        "Total size",
                        value: ByteCountFormatter.string(
                            fromByteCount: backups.reduce(Int64(0)) { $0 + $1.byteCount },
                            countStyle: .file
                        )
                    )

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
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                prepareExport(backup)
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
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
                    Text("Export creates a copy you choose where to save or share. Deleting a backup only removes GestaltEdit's local copy. Neither action modifies MobileGestalt or another system file.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Backup Library")
        .task { reload() }
        .refreshable { reload() }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: .propertyList,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                statusMessage = "Backup export completed."
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
            exportDocument = nil
        }
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

    private func prepareExport(_ backup: GestaltBackup) {
        do {
            exportDocument = BackupExportDocument(data: try GestaltBackupStore.data(for: backup))
            exportFilename = backup.url.lastPathComponent
            statusMessage = nil
            showsExporter = true
        } catch {
            statusMessage = "Could not prepare this backup for export: \(error.localizedDescription)"
        }
    }

    private func deletePendingBackup() {
        guard let backup = pendingDeletion else { return }
        pendingDeletion = nil

        do {
            try GestaltBackupStore.delete(backup)
            reload()
            statusMessage = "Backup deleted."
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct BackupDetailView: View {
    let backup: GestaltBackup

    @State private var exportDocument: BackupExportDocument?
    @State private var showsExporter = false
    @State private var exportError: String?

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

            Section("Actions") {
                Button {
                    prepareExport()
                } label: {
                    Label("Export Backup Copy", systemImage: "square.and.arrow.up")
                }

                if let exportError {
                    Text(exportError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Safety") {
                Text("This screen only reads GestaltEdit's saved local backup. Exporting creates a separate copy and does not access or write the protected MobileGestalt file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Backup Details")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: .propertyList,
            defaultFilename: backup.url.lastPathComponent
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
            exportDocument = nil
        }
    }

    private func prepareExport() {
        do {
            exportDocument = BackupExportDocument(data: try GestaltBackupStore.data(for: backup))
            exportError = nil
            showsExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct BackupExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.propertyList] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
