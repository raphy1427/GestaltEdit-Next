import SwiftUI
import UniformTypeIdentifiers

struct MobileGestaltLabView: View {
    @State private var document: MobileGestaltLabDocument?
    @State private var searchText = ""
    @State private var showsImporter = false
    @State private var showsExporter = false
    @State private var exportDocument: PlistExportDocument?
    @State private var activeField: LabFieldRoute?
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section {
                Label("MobileGestalt Lab", systemImage: "flask")
                    .font(.headline)

                Text("Import and inspect a MobileGestalt property list offline. Changes made here only affect the imported copy until you export it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Research Tools") {
                NavigationLink {
                    MobileGestaltCompareView()
                } label: {
                    Label("Compare Two Plists", systemImage: "arrow.left.arrow.right")
                }

                Text("Compare two MobileGestalt files to find added, removed, changed, and unchanged fields.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let document {
                summarySection(document)
                changesSection(document)

                keySection(
                    title: "CacheExtra",
                    keys: filtered(document.cacheExtraKeys, section: .cacheExtra, document: document),
                    section: .cacheExtra,
                    document: document
                )

                keySection(
                    title: "Top Level",
                    keys: filtered(document.topLevelKeys, section: .topLevel, document: document),
                    section: .topLevel,
                    document: document
                )

                Section("Actions") {
                    Button {
                        if let export = try? document.exportDocument() {
                            exportDocument = export
                            showsExporter = true
                            statusMessage = nil
                        } else {
                            statusMessage = "Could not prepare this plist for export."
                        }
                    } label: {
                        Label("Export Modified Plist", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        self.document = document.resetChanges()
                        statusMessage = "All offline changes were reset."
                    } label: {
                        Label("Reset Offline Changes", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(document.changedPaths.isEmpty)
                }
            } else {
                Section {
                    Button {
                        showsImporter = true
                    } label: {
                        Label("Import MobileGestalt Plist", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("This feature never reads or writes the protected MobileGestalt file on the device. It only works with a plist you explicitly import.")
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
        .navigationTitle("MobileGestalt Lab")
        .searchable(text: $searchText, prompt: "Search keys or values")
        .toolbar {
            if document != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showsImporter = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .accessibilityLabel("Import Another Plist")
                }
            }
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importPlist(from: url)
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: .propertyList,
            defaultFilename: "com.apple.MobileGestalt.modified.plist"
        ) { result in
            switch result {
            case .success:
                statusMessage = "Export completed."
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
        .sheet(item: $activeField) { route in
            if let value = document?.value(at: route) {
                LabFieldEditor(route: route, value: value) { newValue in
                    guard var updated = document else { return }
                    updated.setValue(newValue, at: route)
                    document = updated
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func summarySection(_ document: MobileGestaltLabDocument) -> some View {
        Section("Imported File") {
            LabeledContent("Format", value: document.formatName)
            LabeledContent("Top-level keys", value: String(document.topLevelKeys.count))
            LabeledContent("CacheExtra keys", value: String(document.cacheExtraKeys.count))
            LabeledContent("Offline changes", value: String(document.changedPaths.count))
            LabeledContent("File size", value: ByteCountFormatter.string(fromByteCount: Int64(document.sourceByteCount), countStyle: .file))
            LabeledContent("CacheData", value: document.hasCacheData ? "Present" : "Not present")
            if let cacheDataKeyCount = document.cacheDataKeyCount {
                LabeledContent("CacheData keys", value: String(cacheDataKeyCount))
            }
            LabeledContent("Structure", value: document.structureSummary)
            LabeledContent("Validation", value: document.validationSummary)

            Label("Valid MobileGestalt-style plist", systemImage: "checkmark.shield.fill")
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private func changesSection(_ document: MobileGestaltLabDocument) -> some View {
        if !document.changedPaths.isEmpty {
            Section("Changes") {
                ForEach(document.changedPaths, id: \.self) { path in
                    Text(path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func keySection(
        title: String,
        keys: [String],
        section: LabFieldSection,
        document: MobileGestaltLabDocument
    ) -> some View {
        Section(title) {
            if keys.isEmpty {
                Text("No Results")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(keys, id: \.self) { key in
                    let route = LabFieldRoute(section: section, key: key)
                    let value = document.value(at: route)

                    Button {
                        activeField = route
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(key)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(LabValueFormatter.summary(value))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if document.isChanged(route) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.orange)
                                    .accessibilityLabel("Modified")
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func filtered(
        _ keys: [String],
        section: LabFieldSection,
        document: MobileGestaltLabDocument
    ) -> [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return keys }

        return keys.filter { key in
            let route = LabFieldRoute(section: section, key: key)
            let summary = LabValueFormatter.summary(document.value(at: route))
            return key.localizedCaseInsensitiveContains(query)
                || summary.localizedCaseInsensitiveContains(query)
        }
    }

    private func importPlist(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            document = try MobileGestaltLabDocument(data: data)
            searchText = ""
            activeField = nil
            statusMessage = "Imported successfully. No device file was changed."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private enum LabFieldSection: String, Hashable {
    case cacheExtra
    case topLevel
}

private struct LabFieldRoute: Identifiable, Hashable {
    let section: LabFieldSection
    let key: String

    var id: String {
        "\(section.rawValue)/\(key)"
    }

    var displayPath: String {
        switch section {
        case .cacheExtra:
            return "CacheExtra.\(key)"
        case .topLevel:
            return key
        }
    }
}

private struct MobileGestaltLabDocument {
    private let original: [String: Any]
    private(set) var current: [String: Any]
    let format: PropertyListSerialization.PropertyListFormat
    let sourceByteCount: Int

    init(data: Data) throws {
        guard !data.isEmpty else {
            throw MobileGestaltLabError.emptyFile
        }
        let maximumImportBytes = 32 * 1024 * 1024
        guard data.count <= maximumImportBytes else {
            throw MobileGestaltLabError.fileTooLarge(data.count)
        }

        var detectedFormat = PropertyListSerialization.PropertyListFormat.binary
        let root = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &detectedFormat
        )

        guard let dictionary = root as? [String: Any] else {
            throw MobileGestaltLabError.notDictionary
        }

        guard dictionary["CacheExtra"] is [String: Any] else {
            throw MobileGestaltLabError.missingCacheExtra
        }

        original = dictionary
        current = dictionary
        format = detectedFormat
        sourceByteCount = data.count
    }

    var formatName: String {
        switch format {
        case .binary:
            return "Binary"
        case .xml:
            return "XML"
        case .openStep:
            return "OpenStep"
        @unknown default:
            return "Unknown"
        }
    }

    var hasCacheData: Bool {
        current["CacheData"] is [String: Any]
    }

    var cacheDataKeyCount: Int? {
        (current["CacheData"] as? [String: Any])?.count
    }

    var structureSummary: String {
        let cacheData = hasCacheData ? "CacheData" : "no CacheData"
        return "CacheExtra + \(cacheData)"
    }

    var cacheExtraKeys: [String] {
        ((current["CacheExtra"] as? [String: Any]) ?? [:]).keys.sorted()
    }

    var topLevelKeys: [String] {
        current.keys.filter { $0 != "CacheExtra" }.sorted()
    }

    var changedPaths: [String] {
        let topLevel = Set(original.keys).union(current.keys)
            .filter { $0 != "CacheExtra" }
            .compactMap { key -> String? in
                valuesEqual(original[key], current[key]) ? nil : key
            }

        let originalCache = original["CacheExtra"] as? [String: Any] ?? [:]
        let currentCache = current["CacheExtra"] as? [String: Any] ?? [:]
        let cache = Set(originalCache.keys).union(currentCache.keys)
            .compactMap { key -> String? in
                valuesEqual(originalCache[key], currentCache[key]) ? nil : "CacheExtra.\(key)"
            }

        return (topLevel + cache).sorted()
    }

    func value(at route: LabFieldRoute) -> Any? {
        switch route.section {
        case .topLevel:
            return current[route.key]
        case .cacheExtra:
            return (current["CacheExtra"] as? [String: Any])?[route.key]
        }
    }

    mutating func setValue(_ value: Any, at route: LabFieldRoute) {
        switch route.section {
        case .topLevel:
            current[route.key] = value
        case .cacheExtra:
            var cache = current["CacheExtra"] as? [String: Any] ?? [:]
            cache[route.key] = value
            current["CacheExtra"] = cache
        }
    }

    func isChanged(_ route: LabFieldRoute) -> Bool {
        switch route.section {
        case .topLevel:
            return !valuesEqual(original[route.key], current[route.key])
        case .cacheExtra:
            let originalCache = original["CacheExtra"] as? [String: Any] ?? [:]
            let currentCache = current["CacheExtra"] as? [String: Any] ?? [:]
            return !valuesEqual(originalCache[route.key], currentCache[route.key])
        }
    }

    func resetChanges() -> MobileGestaltLabDocument {
        var copy = self
        copy.current = original
        return copy
    }

    func exportDocument() throws -> PlistExportDocument {
        let outputFormat: PropertyListSerialization.PropertyListFormat =
            format == .openStep ? .xml : format

        let data = try PropertyListSerialization.data(
            fromPropertyList: current,
            format: outputFormat,
            options: 0
        )

        return PlistExportDocument(data: data)
    }

    private func valuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (nil, _), (_, nil):
            return false
        default:
            guard let lhs, let rhs else { return false }

            do {
                let left = try PropertyListSerialization.data(
                    fromPropertyList: ["value": lhs],
                    format: .binary,
                    options: 0
                )
                let right = try PropertyListSerialization.data(
                    fromPropertyList: ["value": rhs],
                    format: .binary,
                    options: 0
                )
                return left == right
            } catch {
                return String(describing: lhs) == String(describing: rhs)
            }
        }
    }
}

private enum MobileGestaltLabError: LocalizedError {
    case notDictionary
    case missingCacheExtra
    case emptyFile
    case fileTooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .notDictionary:
            return "The selected file is a property list, but its top level is not a dictionary."
        case .missingCacheExtra:
            return "The selected plist does not contain a CacheExtra dictionary, so it does not look like a MobileGestalt cache file."
        case .emptyFile:
            return "The selected file is empty."
        case .fileTooLarge(let byteCount):
            let megabytes = Double(byteCount) / 1_048_576
            return String(format: "The selected plist is %.1f MB. The offline Lab currently limits imports to 32 MB.", megabytes)
        }
    }
}

private enum LabEditableKind: Equatable {
    case bool
    case string
    case integer
    case floatingPoint
    case readOnly
}

private struct LabFieldEditor: View {
    @Environment(\.dismiss) private var dismiss

    let route: LabFieldRoute
    let originalValue: Any
    let save: (Any) -> Void

    @State private var boolValue: Bool
    @State private var textValue: String
    @State private var errorMessage: String?

    private let kind: LabEditableKind

    init(route: LabFieldRoute, value: Any, save: @escaping (Any) -> Void) {
        self.route = route
        originalValue = value
        self.save = save

        if let value = value as? Bool {
            kind = .bool
            _boolValue = State(initialValue: value)
            _textValue = State(initialValue: "")
        } else if let value = value as? String {
            kind = .string
            _boolValue = State(initialValue: false)
            _textValue = State(initialValue: value)
        } else if let value = value as? Int {
            kind = .integer
            _boolValue = State(initialValue: false)
            _textValue = State(initialValue: String(value))
        } else if let value = value as? Double {
            kind = .floatingPoint
            _boolValue = State(initialValue: false)
            _textValue = State(initialValue: String(value))
        } else if let value = value as? NSNumber {
            let objcType = String(cString: value.objCType)
            if objcType == "f" || objcType == "d" {
                kind = .floatingPoint
            } else {
                kind = .integer
            }
            _boolValue = State(initialValue: false)
            _textValue = State(initialValue: value.stringValue)
        } else {
            kind = .readOnly
            _boolValue = State(initialValue: false)
            _textValue = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Field") {
                    Text(route.displayPath)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section("Value") {
                    switch kind {
                    case .bool:
                        Toggle("Enabled", isOn: $boolValue)

                    case .string:
                        TextEditor(text: $textValue)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 120)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                    case .integer, .floatingPoint:
                        TextField("Value", text: $textValue)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                    case .readOnly:
                        Text(LabValueFormatter.summary(originalValue))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)

                        Text("Arrays, dictionaries, dates, and binary data are read-only in this version of the Lab.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                if kind != .readOnly {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done", action: commit)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func commit() {
        switch kind {
        case .bool:
            save(boolValue)
            dismiss()

        case .string:
            save(textValue)
            dismiss()

        case .integer:
            guard let value = Int(textValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                errorMessage = "Enter a valid whole number."
                return
            }
            save(value)
            dismiss()

        case .floatingPoint:
            guard let value = Double(textValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                errorMessage = "Enter a valid number."
                return
            }
            save(value)
            dismiss()

        case .readOnly:
            break
        }
    }
}

private enum LabValueFormatter {
    static func summary(_ value: Any?) -> String {
        guard let value else { return "nil" }

        if let value = value as? Bool {
            return value ? "true" : "false"
        }
        if let value = value as? String {
            return value
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        if let value = value as? Data {
            return "Data · \(ByteCountFormatter.string(fromByteCount: Int64(value.count), countStyle: .file))"
        }
        if let value = value as? Date {
            return value.formatted(date: .numeric, time: .standard)
        }
        if let value = value as? [Any] {
            return "Array · \(value.count) items"
        }
        if let value = value as? [String: Any] {
            return "Dictionary · \(value.count) keys"
        }

        return String(describing: value)
    }
}

private struct PlistExportDocument: FileDocument {
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
