import SwiftUI
import MapKit

/// Snapshot of block data captured at completion time, before the live state resets.
struct CompletedBlockSnapshot {
    let grossPayout: Decimal
    let totalMiles: Decimal
    let mileageDeduction: Decimal
    let totalProfit: Decimal
    let packageCount: Int
    let stopCount: Int
    let timeRange: String
    let routeData: Data?
}

struct WatchWorkModeView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WatchWorkModeViewModel()
    @State private var showCompleteConfirmation = false
    @State private var selectedTab = 0
    @State private var showFullMap = false
    @State private var completedSnapshot: CompletedBlockSnapshot?
    @State private var showSummary = false

    var body: some View {
        Group {
            if showSummary, let snapshot = completedSnapshot {
                WatchBlockCompletionSummary(snapshot: snapshot) {
                    showSummary = false
                    completedSnapshot = nil
                    showCompleteConfirmation = false
                    sessionManager.showingCompletionSummary = false
                    sessionManager.workModeBlockID = nil
                    dismiss()
                }
            } else {
                workModeContent
            }
        }
        .navigationBarBackButtonHidden(showSummary || sessionManager.workModeBlockID != nil)
    }

    private var workModeContent: some View {
        TabView(selection: $selectedTab) {
            statsPage
                .tag(0)

            controlsPage
                .tag(1)

            mapPage
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
    }

    // MARK: - Page 1: Live Stats

    private var statsPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Gross payout
                VStack(spacing: 2) {
                    Text("Gross")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(WatchFormatters.currencyString(viewModel.grossPayout))
                        .font(.title2)
                        .fontWeight(.bold)
                }

                HStack(spacing: 16) {
                    // Miles
                    VStack(spacing: 2) {
                        Text("Miles")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(WatchFormatters.milesString(viewModel.totalMiles))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    // Deduction
                    VStack(spacing: 2) {
                        Text("Deduction")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("-\(WatchFormatters.currencyString(viewModel.liveMileageDeduction))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }

                Divider()

                // Total profit
                VStack(spacing: 2) {
                    Text("Profit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(WatchFormatters.currencyString(viewModel.totalProfit))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.totalProfit >= 0 ? .green : .red)
                }

                // GPS indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isTracking ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isTracking ? "GPS Active" : "GPS Off")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                // Time info
                if let block = viewModel.block {
                    Text(WatchFormatters.timeRangeString(
                        start: block.startTime,
                        end: block.endTime,
                        duration: block.durationMinutes
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Page 2: Controls

    private var controlsPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Package count
                HStack {
                    Text("Packages")
                        .font(.caption)
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            let newVal = max(0, viewModel.packageCount - 1)
                            viewModel.updatePackageCount(newVal)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("\(viewModel.packageCount)")
                            .font(.headline)
                            .frame(minWidth: 30)
                            .multilineTextAlignment(.center)

                        Button {
                            viewModel.updatePackageCount(viewModel.packageCount + 1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // Stop count
                HStack {
                    Text("Stops")
                        .font(.caption)
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            let newVal = max(0, viewModel.stopCount - 1)
                            viewModel.updateStopCount(newVal)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("\(viewModel.stopCount)")
                            .font(.headline)
                            .frame(minWidth: 30)
                            .multilineTextAlignment(.center)

                        Button {
                            viewModel.updateStopCount(viewModel.stopCount + 1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // Tracking toggle
                Button {
                    if viewModel.isTracking {
                        viewModel.stopTracking()
                    } else {
                        viewModel.startTracking()
                    }
                } label: {
                    Label(
                        viewModel.isTracking ? "Stop GPS" : "Start GPS",
                        systemImage: viewModel.isTracking ? "location.slash.fill" : "location.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isTracking ? .orange : .blue)

                // Complete block
                Button {
                    showCompleteConfirmation = true
                } label: {
                    Label("End Block", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .confirmationDialog(
                    "End this block?",
                    isPresented: $showCompleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("End Block", role: .destructive) {
                        // Capture current stats before the block data resets
                        completedSnapshot = CompletedBlockSnapshot(
                            grossPayout: viewModel.grossPayout,
                            totalMiles: viewModel.totalMiles,
                            mileageDeduction: viewModel.liveMileageDeduction,
                            totalProfit: viewModel.totalProfit,
                            packageCount: viewModel.packageCount,
                            stopCount: viewModel.stopCount,
                            timeRange: viewModel.block.map {
                                WatchFormatters.timeRangeString(start: $0.startTime, end: $0.endTime, duration: $0.durationMinutes)
                            } ?? "",
                            routeData: viewModel.block?.routePointsEncoded
                        )
                        viewModel.completeBlock()
                        sessionManager.showingCompletionSummary = true
                        showSummary = true
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Page 3: Map

    private var mapPage: some View {
        ZStack {
            if let block = viewModel.block,
               let routeData = block.routePointsEncoded,
               let coordinates = decodeRoutePoints(routeData),
               !coordinates.isEmpty {
                // Non-interactive map preview — tap to open full interactive map
                Map(interactionModes: []) {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.blue, lineWidth: 3)
                    if let last = coordinates.last {
                        Annotation("", coordinate: last) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                        }
                    }
                }
                .onTapGesture {
                    showFullMap = true
                }

                // Hint overlay
                VStack {
                    Spacer()
                    Text("Tap to expand")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(.bottom, 4)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No Route Data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !viewModel.isTracking {
                        Text("Start GPS to track route")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .sheet(isPresented: $showFullMap) {
            if let block = viewModel.block,
               let routeData = block.routePointsEncoded,
               let coordinates = decodeRoutePoints(routeData),
               !coordinates.isEmpty {
                FullRouteMapView(coordinates: coordinates)
            }
        }
    }

    // MARK: - Route Decoding

    /// Route data is stored as [RouteSegment] where each segment has [RoutePoint].
    /// RoutePoint has latitude, longitude, timestamp.
    private func decodeRoutePoints(_ data: Data) -> [CLLocationCoordinate2D]? {
        struct RoutePointDTO: Codable {
            let latitude: Double
            let longitude: Double
            let timestamp: Date
        }
        struct RouteSegmentDTO: Codable {
            let points: [RoutePointDTO]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try segments format first (current format)
        if let segments = try? decoder.decode([RouteSegmentDTO].self, from: data) {
            let coords = segments.flatMap(\.points).map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            return coords.isEmpty ? nil : coords
        }

        // Fallback to flat array of route points
        if let points = try? decoder.decode([RoutePointDTO].self, from: data) {
            let coords = points.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            return coords.isEmpty ? nil : coords
        }

        return nil
    }
}

// MARK: - Block Completion Summary

struct WatchBlockCompletionSummary: View {
    let snapshot: CompletedBlockSnapshot
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)

                Text("Block Complete")
                    .font(.headline)

                if !snapshot.timeRange.isEmpty {
                    Text(snapshot.timeRange)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                summaryRow("Gross", WatchFormatters.currencyString(snapshot.grossPayout))
                summaryRow("Miles", WatchFormatters.milesString(snapshot.totalMiles))
                summaryRow("Deduction", "-\(WatchFormatters.currencyString(snapshot.mileageDeduction))", color: .orange)

                Divider()

                HStack {
                    Text("Profit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(WatchFormatters.currencyString(snapshot.totalProfit))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(snapshot.totalProfit >= 0 ? .green : .red)
                }

                if snapshot.packageCount > 0 || snapshot.stopCount > 0 {
                    Divider()
                    HStack(spacing: 16) {
                        if snapshot.packageCount > 0 {
                            Label("\(snapshot.packageCount)", systemImage: "shippingbox.fill")
                                .font(.caption)
                        }
                        if snapshot.stopCount > 0 {
                            Label("\(snapshot.stopCount)", systemImage: "mappin.circle.fill")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }

    private func summaryRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Full Interactive Map Sheet

/// Full-screen interactive map presented as a sheet.
/// Users can pan and zoom freely, then dismiss with the standard swipe-down gesture.
struct FullRouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        Map {
            MapPolyline(coordinates: coordinates)
                .stroke(.blue, lineWidth: 3)
            if let first = coordinates.first {
                Annotation("Start", coordinate: first) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if let last = coordinates.last {
                Annotation("Current", coordinate: last) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
