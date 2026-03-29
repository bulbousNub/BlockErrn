import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @State private var irsRateText: String = ""
    @State private var selectedAppearance: AppearancePreference = .system
    @State private var mileageSavedMessage: String?
    @State private var showExpenseCategoryEditor: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                FlexErrnTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        SectionCard(title: "Appearance") {
                            Picker("Theme", selection: $selectedAppearance) {
                                ForEach(AppearancePreference.allCases) { appearance in
                                    Text(appearance.displayName).tag(appearance)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedAppearance) { _ in syncAppearancePreference() }
                        }

                        SectionCard(title: "Expenses") {
                            HStack {
                                Spacer()
                                Button {
                                    showExpenseCategoryEditor = true
                                } label: {
                                    Label("Manage expense categories", systemImage: "list.bullet")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.capsule)
                                .tint(.accentColor)
                                Spacer()
                            }
                        }

                        SectionCard(title: "Mileage deduction rate (cents)") {
                            TextField("IRS mileage rate (cents per mile)", text: $irsRateText)
                                .keyboardType(.numberPad)
                                .keyboardDoneToolbar()
                                .onChange(of: irsRateText) { _ in mileageSavedMessage = nil }
                                .onSubmit { save() }
                            Text("IRS rate is shown in cents (70 = $0.70/mi). It determines the mileage deduction when you add new blocks and matches the current IRS standard rate; changes are not retroactive but only affect future entries.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let message = mileageSavedMessage {
                                Text(message)
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                }
                            }

                        SectionCard(title: "Erase All Content and Settings") {
                            NavigationLink {
                                EraseDataView()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Completely remove every block, expense, and custom preference for a fresh start.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }

                        SectionCard(title: "About FlexErrn") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("A pocket-friendly ride-by-ride calculator with configurable themes, expense categories, and protected backups.")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                NavigationLink {
                                    LicensesView()
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("Licenses")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                    }
                    .padding()
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .sheet(isPresented: $showExpenseCategoryEditor) {
                if let appSettings = settings.first {
                    ExpenseCategoryEditor(appSettings: appSettings)
                } else {
                    Text("No settings available.")
                }
            }
            .onAppear { loadSettings() }
            .task(id: settings.first?.id) { loadSettings() }
            .onChange(of: settings.first?.preferredAppearanceRaw) { _ in loadSettings() }
        }
    }


    private func save() {
        guard let cents = Int(irsRateText), cents >= 0 else { return }
        let rate = Decimal(cents) / Decimal(100)
        if let s = settings.first {
            s.irsMileageRate = rate
        } else {
            let s = AppSettings(irsMileageRate: rate, preferredAppearance: selectedAppearance)
            context.insert(s)
        }
        try? context.save()
        setMileageSavedMessage("Mileage rate saved")
    }

    private func syncAppearancePreference() {
        if let s = settings.first {
            s.preferredAppearance = selectedAppearance
        } else {
            let newSetting = AppSettings(
                irsMileageRate: settings.first?.irsMileageRate ?? 0.70,
                preferredAppearance: selectedAppearance
            )
            context.insert(newSetting)
        }
        try? context.save()
    }



    private func formatCents(_ value: Decimal) -> String {
        let cents = NSDecimalNumber(decimal: value * Decimal(100)).intValue
        return "\(cents)"
    }

    private func setMileageSavedMessage(_ text: String) {
        mileageSavedMessage = text
    }

    private func loadSettings() {
        let rate = settings.first?.irsMileageRate ?? 0.70
        irsRateText = formatCents(rate)
        selectedAppearance = settings.first?.preferredAppearance ?? .system
    }

}

private struct LicensesView: View {
    private let licenseEntries: [LicenseEntry] = [
        LicenseEntry(
            title: "ZIPFoundation",
            subtitle: "MIT License",
            licenseText:
                """
                Copyright (c) 2017-2025 Thomas Zoechling (https://www.peakstep.com)

                Permission is hereby granted, free of charge, to any person obtaining a copy
                of this software and associated documentation files (the \"Software\"), to deal
                in the Software without restriction, including without limitation the rights
                to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
                copies of the Software, and to permit persons to whom the Software is
                furnished to do so, subject to the following conditions:

                The above copyright notice and this permission notice shall be included in all
                copies or substantial portions of the Software.

                THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
                FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
                AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
                LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
                OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
                SOFTWARE.
                """
        )
    ]

    var body: some View {
        ZStack {
            FlexErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(licenseEntries) { entry in
                        SectionCard(title: entry.title) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(entry.licenseText)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Licenses")
    }
}

private struct LicenseEntry: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let licenseText: String
}

private struct SectionCard<Content: View>: View {
    let title: String
    let background: AnyShapeStyle
    let content: Content

    init(title: String, background: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial), @ViewBuilder content: () -> Content) {
        self.title = title
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: FlexErrnTheme.cardShadowColor, radius: 20, x: 0, y: 10)
    }
}

private struct ExpenseCategoryEditor: View {
    var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var descriptors: [ExpenseCategoryDescriptor]
    @State private var newCategoryName: String = ""

    init(appSettings: AppSettings) {
        self.appSettings = appSettings
        _descriptors = State(initialValue: appSettings.expenseCategoryDescriptors)
    }

    var body: some View {
        ZStack {
            FlexErrnTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 20) {
                header
                addRow
                descriptorList
                actionRow
            }
            .padding(24)
        }
        .presentationDetents([.fraction(0.75)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Expense categories")
                .font(.title3)
                .bold()
            Text("Add, rename, or reorder the list of categories used while logging expenses.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New category")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Category name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                Button("Add") {
                    addCategory()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .flexErrnCardStyle()
    }

    private var descriptorList: some View {
        List {
            ForEach($descriptors) { $descriptor in
                HStack {
                    Image(systemName: "line.horizontal.3")
                        .foregroundColor(.secondary)
                    TextField("Category name", text: $descriptor.name)
                        .autocorrectionDisabled(true)
                }
                .padding(.vertical, 4)
            }
            .onDelete { descriptors.remove(atOffsets: $0) }
            .onMove { descriptors.move(fromOffsets: $0, toOffset: $1) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
        .frame(maxHeight: 320)
        .flexErrnCardStyle()
    }

    private var actionRow: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            Spacer()
            Button("Save") {
                saveChanges()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.top, 4)
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let descriptor = ExpenseCategoryDescriptor.custom(name: trimmed)
        descriptors.append(descriptor)
        newCategoryName = ""
    }

    private func saveChanges() {
        appSettings.expenseCategoryDescriptors = descriptors
        dismiss()
    }
}
