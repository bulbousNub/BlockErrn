import SwiftUI
import SwiftData
import SafariServices

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @ObservedObject private var store = StoreKitManager.shared
    @State private var irsRateText: String = ""
    @State private var selectedAppearance: AppearancePreference = .system
    
    @State private var showExpenseCategoryEditor: Bool = false
    @State private var showGitHub: Bool = false
    @State private var showProUpgrade: Bool = false
    @State private var reminderBeforeStartMinutes: Int = 45
    @State private var reminderBeforeEndMinutes: Int = 15
    @State private var tipReminderHours: Int = 24

    var body: some View {
        NavigationStack {
            ZStack {
                BlockErrnTheme.backgroundGradient.ignoresSafeArea()
                GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !store.isProUnlocked {
                            proTile
                        }

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

                        SectionCard(title: "Reminders") {
                            VStack(alignment: .leading, spacing: 14) {
                                reminderField(
                                    label: "Prior to Block Start",
                                    value: $reminderBeforeStartMinutes,
                                    placeholder: "45",
                                    unit: "minutes",
                                    onChange: updateReminderBeforeStart
                                )
                                reminderField(
                                    label: "Prior to Block End",
                                    value: $reminderBeforeEndMinutes,
                                    placeholder: "15",
                                    unit: "minutes",
                                    onChange: updateReminderBeforeEnd
                                )
                                reminderField(
                                    label: "Tip reminder",
                                    value: $tipReminderHours,
                                    placeholder: "24",
                                    unit: tipReminderHours == 1 ? "hour" : "hours",
                                    onChange: updateTipReminderHours
                                )
                            }
                            .keyboardDoneToolbar()
                        }

                        SectionCard(title: "Mileage deduction rate (cents)") {
                            TextField("IRS mileage rate (cents per mile)", text: $irsRateText)
                                .keyboardType(.numberPad)
                                .keyboardDoneToolbar()
                                .onChange(of: irsRateText) { _ in saveIRSRate() }
                            Text("IRS rate is shown in cents (70 = $0.70/mi). It determines the mileage deduction when you add new blocks and matches the current IRS standard rate; changes are not retroactive but only affect future entries.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            }

                        SectionCard(title: "About BlockErrn") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Block-by-block earnings tracker for gig delivery drivers. Track mileage, expenses, and profit across iPhone, Apple Watch, and CarPlay.")
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

                                Button {
                                    showGitHub = true
                                } label: {
                                    HStack {
                                        Image(systemName: "cat.fill")
                                        Text("GitHub")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
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

                                NavigationLink {
                                    ContactView()
                                } label: {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                        Text("Contact")
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

                        if store.isProUnlocked {
                            proTile
                        }

                        SectionCard {
                            NavigationLink {
                                EraseDataView()
                            } label: {
                                HStack {
                                    Text("Erase All Content and Settings")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                    }
                    .padding()
                    .padding(.bottom, 32)
                    .frame(width: geo.size.width)
                }
                }
            }
            .navigationTitle("Settings")
            
            .sheet(isPresented: $showExpenseCategoryEditor) {
                if let appSettings = settings.first {
                    ExpenseCategoryEditor(appSettings: appSettings)
                } else {
                    Text("No settings available.")
                }
            }
            .sheet(isPresented: $showGitHub) {
                SafariView(url: URL(string: "https://github.com/bulbousNub/BlockErrn/")!)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showProUpgrade) {
                NavigationStack {
                    ProUpgradeView()
                }
            }
            .onAppear { loadSettings() }
            .task(id: settings.first?.id) { loadSettings() }
            .onChange(of: settings.first?.preferredAppearanceRaw) { _ in loadSettings() }
        }
    }


    private var proTile: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.isProUnlocked ? "Pro Unlocked" : "Upgrade to Pro")
                            .font(.headline)
                        Text(store.isProUnlocked
                             ? "You have full access to all features."
                             : "Receipt capture, full trends, iCloud backup, PDF reports, and more.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                if !store.isProUnlocked {
                    Button {
                        showProUpgrade = true
                    } label: {
                        HStack {
                            Text("View Plans")
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

                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func saveIRSRate() {
        guard let cents = Int(irsRateText), cents >= 0 else { return }
        let rate = Decimal(cents) / Decimal(100)
        if let s = settings.first {
            s.irsMileageRate = rate
        } else {
            let s = AppSettings(irsMileageRate: rate, preferredAppearance: selectedAppearance)
            context.insert(s)
        }
        try? context.save()
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

    private func loadSettings() {
        let rate = settings.first?.irsMileageRate ?? 0.70
        irsRateText = formatCents(rate)
        selectedAppearance = settings.first?.preferredAppearance ?? .system
        reminderBeforeStartMinutes = settings.first?.reminderBeforeStartMinutes ?? 45
        reminderBeforeEndMinutes = settings.first?.reminderBeforeEndMinutes ?? 15
        tipReminderHours = settings.first?.tipReminderHours ?? 24
    }

    private func reminderField(
        label: String,
        value: Binding<Int>,
        placeholder: String,
        unit: String,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        return HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(width: reminderLabelWidth, alignment: .leading)
            HStack(spacing: 4) {
                TextField(placeholder, value: value, formatter: integerFormatter)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.15))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .frame(width: 90)
                    .onChange(of: value.wrappedValue, perform: onChange)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
        }
    }

    private var reminderLabelWidth: CGFloat {
        180
    }

    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        return formatter
    }

    private func updateReminderBeforeStart(_ minutes: Int) {
        guard let s = settings.first else { return }
        s.reminderBeforeStartMinutes = minutes
        try? context.save()
    }

    private func updateReminderBeforeEnd(_ minutes: Int) {
        guard let s = settings.first else { return }
        s.reminderBeforeEndMinutes = minutes
        try? context.save()
    }

    private func updateTipReminderHours(_ hours: Int) {
        guard let s = settings.first else { return }
        s.tipReminderHours = hours
        try? context.save()
    }

}

private struct LicensesView: View {
    private let licenseEntries: [LicenseEntry] = [
        LicenseEntry(
            title: "BlockErrn",
            subtitle: "Apache License 2.0",
            licenseText:
                """
                Copyright 2025 TeJay Guilliams

                Licensed under the Apache License, Version 2.0 (the "License"); \
                you may not use this file except in compliance with the License. \
                You may obtain a copy of the License at

                    http://www.apache.org/licenses/LICENSE-2.0

                Unless required by applicable law or agreed to in writing, software \
                distributed under the License is distributed on an "AS IS" BASIS, \
                WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. \
                See the License for the specific language governing permissions and \
                limitations under the License.
                """
        ),
        LicenseEntry(
            title: "ZIPFoundation",
            subtitle: "MIT License",
            licenseText:
                """
                Copyright (c) 2017-2025 Thomas Zoechling (https://www.peakstep.com)

                Permission is hereby granted, free of charge, to any person obtaining a copy \
                of this software and associated documentation files (the \"Software\"), to deal \
                in the Software without restriction, including without limitation the rights \
                to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                copies of the Software, and to permit persons to whom the Software is \
                furnished to do so, subject to the following conditions:

                The above copyright notice and this permission notice shall be included in all \
                copies or substantial portions of the Software.

                THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
                IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
                FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
                AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
                LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
                OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
                SOFTWARE.
                """
        )
    ]

    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
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

                    SectionCard(title: "Disclaimer") {
                        Text("BlockErrn is an independent project and is not affiliated with, endorsed by, or sponsored by Amazon.com, Inc. or any of its subsidiaries, including Amazon Flex.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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

struct SectionCard<Content: View>: View {
    let title: String?
    let background: AnyShapeStyle
    let content: Content

    init(title: String? = nil, background: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial), @ViewBuilder content: () -> Content) {
        self.title = title
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: BlockErrnTheme.cardShadowColor, radius: 20, x: 0, y: 10)
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
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
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

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
