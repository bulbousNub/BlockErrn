import SwiftUI
import SwiftData

struct EraseDataView: View {
    @Environment(\.modelContext) private var context
    @Query private var blocks: [Block]
    @Query private var settings: [AppSettings]

    @State private var showConfirmation: Bool = false
    @State private var statusMessage: String?
    @State private var statusStyle: DataMessageStyle = .info

    var body: some View {
        ZStack {
            FlexErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Erase All Content and Settings")
                                    .font(.title2)
                                    .bold()
                                Text("This removes every block, expense, and custom preference so you can start over or secure your device for resale.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "trash.slash")
                                .font(.system(size: 44))
                                .foregroundColor(.red)
                        }
                        Text("Everything is permanent—Trash the app data only if you are sure you want a clean slate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(role: .destructive) {
                            showConfirmation = true
                        } label: {
                            Label("Clear All Data", systemImage: "trash")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(.red)

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(statusStyle.color)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: FlexErrnTheme.cardShadowColor, radius: 20, x: 0, y: 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        }
        .navigationTitle("Erase All Content")
        .alert("Delete all saved data?", isPresented: $showConfirmation) {
            Button("Delete Everything", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes every block, expense, and setting. The action cannot be undone.")
        }
    }

    private func clearAllData() {
        for block in blocks {
            context.delete(block)
        }
        for setting in settings {
            context.delete(setting)
        }
        try? context.save()
        statusMessage = "All data removed. Blocks and settings cleared."
        statusStyle = .info
    }
}

