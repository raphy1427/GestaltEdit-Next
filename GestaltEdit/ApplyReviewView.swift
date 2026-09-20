import SwiftUI

struct ApplyReviewView: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @Environment(\.dismiss) private var dismiss

    private var selectedDefinitions: [GestaltTweakDefinition] {
        viewModel.selectedTweaks
            .compactMap { GestaltTweakCatalog.definition(for: $0) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var dynamicIslandTitle: String? {
        guard let subtype = viewModel.dynamicIslandSubtype else { return nil }
        let option = DynamicIslandOption.all.first { $0.subtype == subtype }
        return option.map { "Dynamic Island: \($0.title)" } ?? "Dynamic Island subtype: \(subtype)"
    }

    private var modelNameTitle: String? {
        guard viewModel.changesModelName else { return nil }
        let name = viewModel.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Change model name" : "Model name: \(name)"
    }

    private var hasRiskyChanges: Bool {
        selectedDefinitions.contains(where: \.isRisky) || viewModel.stagesAIRegion
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Pending changes", value: String(viewModel.stagedChangeCount))
                    Label(
                        hasRiskyChanges ? "Includes higher-risk changes" : "No catalogued high-risk changes",
                        systemImage: hasRiskyChanges ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"
                    )
                    .foregroundStyle(hasRiskyChanges ? .orange : .green)
                }

                if !selectedDefinitions.isEmpty {
                    Section("Tweaks") {
                        ForEach(selectedDefinitions) { definition in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(definition.title)
                                        .font(.subheadline.weight(.semibold))
                                    if definition.isRisky {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .accessibilityLabel("Higher risk")
                                    }
                                }
                                Text(definition.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if dynamicIslandTitle != nil || modelNameTitle != nil || viewModel.stagesAIRegion {
                    Section("Other Changes") {
                        if let dynamicIslandTitle {
                            Label(dynamicIslandTitle, systemImage: "rectangle.topthird.inset.filled")
                        }

                        if let modelNameTitle {
                            Label(modelNameTitle, systemImage: "iphone")
                        }

                        if viewModel.stagesAIRegion {
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Enable Siri AI (US Region)")
                                    Text(viewModel.requiresForcedAIEnable
                                         ? "This device requires identity spoofing for this option."
                                         : "Apply the US-region MobileGestalt configuration.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "globe.americas.fill")
                            }
                        }
                    }
                }

                Section("Before Applying") {
                    Label("A backup is created automatically before the write.", systemImage: "archivebox.fill")
                    Text("Review the list above. After applying, GestaltEdit verifies the saved plist and refreshes SpringBoard.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        dismiss()
                        viewModel.applySelectedTweaks()
                    } label: {
                        Label("Apply \(viewModel.stagedChangeCount) Changes", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBusy || viewModel.stagedChangeCount == 0)
                }
            }
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
