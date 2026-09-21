import SwiftUI
import UniformTypeIdentifiers

struct MobileGestaltCompareView: View {
    @State private var left: ComparedPlist?
    @State private var right: ComparedPlist?
    @State private var importingSide: CompareSide?
    @State private var searchText = ""
    @State private var showUnchanged = false
    @State private var selectedKinds: Set<PlistDiffKind> = [.changed, .added, .removed]
    @State private var notice: String?

    private var diff: [PlistDiffEntry] {
        guard let left, let right else { return [] }
        return PlistDiffEngine.compare(left: left, right: right)
    }

    private var filteredDiff: [PlistDiffEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return diff.filter { entry in
            if !showUnchanged && entry.kind == .unchanged { return false }
            if entry.kind != .unchanged && !selectedKinds.contains(entry.kind) { return false }
            guard !query.isEmpty else { return true }
            return entry.path.localizedCaseInsensitiveContains(query)
                || entry.leftSummary.localizedCaseInsensitiveContains(query)
                || entry.rightSummary.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Section {
                Label("Compare MobileGestalt Files", systemImage: "arrow.left.arrow.right")
                    .font(.headline)

                Text("Compare two imported property lists offline. Nothing is read from or written to the protected device file.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Files") {
                importRow(side: .left, file: left)
                importRow(side: .right, file: right)
            }

            if left != nil && right != nil {
                summarySection
                optionsSection
                differencesSection
            } else {
                Section {
                    ContentUnavailableView(
                        "Choose Two Plists",
                        systemImage: "doc.on.doc",
                        description: Text("Import a baseline file and a comparison file to see exactly which MobileGestalt fields differ.")
                    )
                }
            }

            if let notice {
                Section("Status") {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Compare Plists")
        .searchable(text: $searchText, prompt: "Search changed keys or values")
        .fileImporter(
            isPresented: Binding(
                get: { importingSide != nil },
                set: { if !$0 { importingSide = nil } }
            ),
            allowedContentTypes: [.propertyList],
            allowsMultipleSelection: false
        ) { result in
            guard let side = importingSide else { return }
            importingSide = nil

            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importPlist(from: url, side: side)
            case .failure(let error):
                notice = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func importRow(side: CompareSide, file: ComparedPlist?) -> some View {
        Button {
            importingSide = side
        } label: {
            HStack(spacing: 12) {
                Image(systemName: file == nil ? "doc.badge.plus" : "doc.text")
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(side.title)
                        .foregroundStyle(.primary)
                    if let file {
                        Text(file.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("\(file.topLevel.count) top-level · \(file.cacheExtra.count) CacheExtra")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Tap to import a plist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var summarySection: some View {
        let added = diff.filter { $0.kind == .added }.count
        let removed = diff.filter { $0.kind == .removed }.count
        let changed = diff.filter { $0.kind == .changed }.count
        let unchanged = diff.filter { $0.kind == .unchanged }.count

        return Section("Summary") {
            LabeledContent("Changed", value: String(changed))
            LabeledContent("Added", value: String(added))
            LabeledContent("Removed", value: String(removed))
            LabeledContent("Unchanged", value: String(unchanged))
            LabeledContent("Total compared", value: String(diff.count))
        }
    }

    private var optionsSection: some View {
        Section("View") {
            Toggle("Show unchanged fields", isOn: $showUnchanged)

            ForEach([PlistDiffKind.changed, .added, .removed], id: \.rawValue) { kind in
                Toggle(isOn: Binding(
                    get: { selectedKinds.contains(kind) },
                    set: { enabled in
                        if enabled { selectedKinds.insert(kind) }
                        else { selectedKinds.remove(kind) }
                    }
                )) {
                    Label(kind.label, systemImage: kind.symbol)
                        .foregroundStyle(kind.tint)
                }
            }
        }
    }

    private var differencesSection: some View {
        Section(showUnchanged ? "Fields" : "Differences") {
            if filteredDiff.isEmpty {
                Label(
                    searchText.isEmpty ? "No differences found" : "No matching fields",
                    systemImage: "checkmark.circle"
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(filteredDiff) { entry in
                    NavigationLink {
                        PlistDiffDetailView(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Image(systemName: entry.kind.symbol)
                                    .foregroundStyle(entry.kind.tint)
                                Text(entry.path)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Text(entry.kind.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(entry.kind.tint)

                            if entry.kind != .unchanged {
                                Text("Before: \(entry.leftSummary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text("After: \(entry.rightSummary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func importPlist(from url: URL, side: CompareSide) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let parsed = try ComparedPlist(name: url.lastPathComponent, data: data)
            switch side {
            case .left:
                left = parsed
            case .right:
                right = parsed
            }
            notice = "Imported \(url.lastPathComponent)."
        } catch {
            notice = error.localizedDescription
        }
    }
}

private enum CompareSide {
    case left
    case right

    var title: String {
        switch self {
        case .left: return "Baseline"
        case .right: return "Comparison"
        }
    }
}

private struct ComparedPlist {
    let name: String
    let topLevel: [String: Any]
    let cacheExtra: [String: Any]

    init(name: String, data: Data) throws {
        var format = PropertyListSerialization.PropertyListFormat.binary
        let root = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &format
        )

        guard let dictionary = root as? [String: Any] else {
            throw ComparePlistError.notDictionary
        }

        guard let cache = dictionary["CacheExtra"] as? [String: Any] else {
            throw ComparePlistError.missingCacheExtra
        }

        self.name = name
        self.cacheExtra = cache

        var top = dictionary
        top.removeValue(forKey: "CacheExtra")
        self.topLevel = top
    }
}

private enum ComparePlistError: LocalizedError {
    case notDictionary
    case missingCacheExtra

    var errorDescription: String? {
        switch self {
        case .notDictionary:
            return "The selected plist does not have a dictionary at its top level."
        case .missingCacheExtra:
            return "The selected plist does not contain a CacheExtra dictionary."
        }
    }
}

private enum PlistDiffKind: Int, Comparable {
    case changed = 0
    case added = 1
    case removed = 2
    case unchanged = 3

    static func < (lhs: PlistDiffKind, rhs: PlistDiffKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .changed: return "Changed"
        case .added: return "Added"
        case .removed: return "Removed"
        case .unchanged: return "Unchanged"
        }
    }

    var symbol: String {
        switch self {
        case .changed: return "pencil.circle.fill"
        case .added: return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        case .unchanged: return "checkmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .changed: return .orange
        case .added: return .green
        case .removed: return .red
        case .unchanged: return .secondary
        }
    }
}

private struct PlistDiffEntry: Identifiable {
    let path: String
    let kind: PlistDiffKind
    let leftValue: Any?
    let rightValue: Any?

    var id: String { path }
    var leftSummary: String { PlistDiffFormatter.summary(leftValue) }
    var rightSummary: String { PlistDiffFormatter.summary(rightValue) }
}

private enum PlistDiffEngine {
    static func compare(left: ComparedPlist, right: ComparedPlist) -> [PlistDiffEntry] {
        var result: [PlistDiffEntry] = []

        let topKeys = Set(left.topLevel.keys).union(right.topLevel.keys)
        for key in topKeys {
            result.append(entry(
                path: key,
                left: left.topLevel[key],
                right: right.topLevel[key]
            ))
        }

        let cacheKeys = Set(left.cacheExtra.keys).union(right.cacheExtra.keys)
        for key in cacheKeys {
            result.append(entry(
                path: "CacheExtra.\(key)",
                left: left.cacheExtra[key],
                right: right.cacheExtra[key]
            ))
        }

        return result.sorted {
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
        }
    }

    private static func entry(path: String, left: Any?, right: Any?) -> PlistDiffEntry {
        let kind: PlistDiffKind
        switch (left, right) {
        case (nil, nil):
            kind = .unchanged
        case (nil, _):
            kind = .added
        case (_, nil):
            kind = .removed
        default:
            kind = PlistDiffFormatter.equal(left, right) ? .unchanged : .changed
        }

        return PlistDiffEntry(
            path: path,
            kind: kind,
            leftValue: left,
            rightValue: right
        )
    }
}

private enum PlistDiffFormatter {
    static func equal(_ lhs: Any?, _ rhs: Any?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }

        do {
            let leftData = try PropertyListSerialization.data(
                fromPropertyList: ["value": lhs],
                format: .binary,
                options: 0
            )
            let rightData = try PropertyListSerialization.data(
                fromPropertyList: ["value": rhs],
                format: .binary,
                options: 0
            )
            return leftData == rightData
        } catch {
            return String(describing: lhs) == String(describing: rhs)
        }
    }

    static func summary(_ value: Any?) -> String {
        guard let value else { return "Not present" }

        if let value = value as? Bool {
            return value ? "true" : "false"
        }
        if let value = value as? String {
            return value.isEmpty ? "Empty string" : value
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

private struct PlistDiffDetailView: View {
    let entry: PlistDiffEntry

    var body: some View {
        List {
            Section("Field") {
                Text(entry.path)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)

                Label(entry.kind.label, systemImage: entry.kind.symbol)
                    .foregroundStyle(entry.kind.tint)
            }

            Section("Baseline") {
                diffValue(entry.leftValue)
            }

            Section("Comparison") {
                diffValue(entry.rightValue)
            }
        }
        .navigationTitle("Field Difference")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func diffValue(_ value: Any?) -> some View {
        if let value {
            Text(PlistDiffFormatter.summary(value))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        } else {
            Text("Not present")
                .foregroundStyle(.secondary)
        }
    }
}
