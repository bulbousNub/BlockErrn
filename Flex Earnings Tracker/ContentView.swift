import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @Query private var settings: [AppSettings]
    @State private var colorSchemeOverride: ColorScheme? = nil

    private var activeSettings: AppSettings? {
        settings.first
    }

    private var needsOnboarding: Bool {
        guard let activeSettings else { return false }
        return !activeSettings.hasCompletedOnboarding
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                CalculatorView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(0)

                LogView()
                    .tabItem {
                        Label("Blocks", systemImage: "list.bullet.rectangle")
                    }
                    .tag(1)

                TrendView()
                    .tabItem {
                        Label("Trends", systemImage: "chart.bar.xaxis")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
            }

            if needsOnboarding, let settingsInstance = activeSettings {
                OnboardingView(appSettings: settingsInstance) {}
                    .environmentObject(MileageTracker.shared)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environmentObject(MileageTracker.shared)
        .preferredColorScheme(colorSchemeOverride)
        .task(id: activeSettings?.id) {
            colorSchemeOverride = activeSettings?.preferredAppearance.colorScheme
        }
        .onChange(of: activeSettings?.preferredAppearanceRaw) { _ in
            colorSchemeOverride = activeSettings?.preferredAppearance.colorScheme
        }
        .onAppear {
            colorSchemeOverride = activeSettings?.preferredAppearance.colorScheme
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Block.self, Expense.self, AuditEntry.self, AppSettings.self], inMemory: true)
        .environmentObject(MileageTracker.shared)
}
