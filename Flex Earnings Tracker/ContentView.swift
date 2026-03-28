import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var tabSelectionState = TabSelectionState()
    @Query private var settings: [AppSettings]
    @State private var colorSchemeOverride: ColorScheme? = nil
    @StateObject private var blockNavigationState = BlockNavigationState()
    @StateObject private var workModeCoordinator = WorkModeCoordinator()

    private var activeSettings: AppSettings? {
        settings.first
    }

    private var needsOnboarding: Bool {
        guard let activeSettings else { return false }
        return !activeSettings.hasCompletedOnboarding
    }

    var body: some View {
        ZStack {
            TabView(selection: $tabSelectionState.selectedTab) {
                CalculatorView()
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
        .environmentObject(blockNavigationState)
        .environmentObject(workModeCoordinator)
        .environmentObject(tabSelectionState)
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
    let blockNavigationState = BlockNavigationState()
    let workModeCoordinator = WorkModeCoordinator()
    let tabSelectionState = TabSelectionState()

    ContentView()
        .modelContainer(for: [Block.self, Expense.self, AuditEntry.self, AppSettings.self], inMemory: true)
        .environmentObject(MileageTracker.shared)
        .environmentObject(blockNavigationState)
        .environmentObject(workModeCoordinator)
        .environmentObject(tabSelectionState)
}
