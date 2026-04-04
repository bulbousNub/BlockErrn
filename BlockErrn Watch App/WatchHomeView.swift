import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @State private var showNewBlockFlow = false
    @State private var navigateToWorkMode = false

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.activeBlocks.isEmpty && sessionManager.upcomingBlocks.isEmpty {
                    emptyState
                } else {
                    blockList
                }
            }
            .navigationTitle("BlockErrn")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewBlockFlow = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewBlockFlow) {
                WatchNewBlockFlow()
                    .environmentObject(sessionManager)
            }
            .navigationDestination(isPresented: $navigateToWorkMode) {
                WatchWorkModeView()
                    .environmentObject(sessionManager)
            }
            .onChange(of: sessionManager.workModeBlockID) {
                if sessionManager.workModeBlockID != nil {
                    navigateToWorkMode = true
                }
            }
            .onAppear {
                sessionManager.activateSession()
                if sessionManager.workModeBlockID != nil {
                    navigateToWorkMode = true
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            if sessionManager.lastSyncDate == nil {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Connecting...")
                    .font(.headline)
                Text("Open BlockErrn on your iPhone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "tray")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No Blocks")
                    .font(.headline)
                Text("Tap + to create a block")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var blockList: some View {
        List {
            if !sessionManager.activeBlocks.isEmpty {
                Section("Active") {
                    ForEach(sessionManager.activeBlocks) { block in
                        NavigationLink {
                            if sessionManager.workModeBlockID == block.id {
                                WatchWorkModeView()
                                    .environmentObject(sessionManager)
                            } else {
                                WatchBlockDetailView(block: block)
                                    .environmentObject(sessionManager)
                            }
                        } label: {
                            WatchBlockRow(block: block, isWorkMode: sessionManager.workModeBlockID == block.id)
                        }
                    }
                }
            }

            if !sessionManager.upcomingBlocks.isEmpty {
                Section("Upcoming") {
                    ForEach(sessionManager.upcomingBlocks) { block in
                        NavigationLink {
                            WatchBlockDetailView(block: block)
                                .environmentObject(sessionManager)
                        } label: {
                            WatchBlockRow(block: block, isWorkMode: false)
                        }
                    }
                }
            }

            if let syncDate = sessionManager.lastSyncDate {
                Section {
                    HStack {
                        Image(systemName: sessionManager.isReachable ? "iphone" : "iphone.slash")
                            .foregroundStyle(sessionManager.isReachable ? .green : .secondary)
                        Text("Synced \(syncDate, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
