import SwiftUI
import MapKit

struct WatchWorkModeView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @StateObject private var viewModel = WatchWorkModeViewModel()
    @State private var showCompleteConfirmation = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            statsPage
                .tag(0)

            controlsPage
                .tag(1)

            mapPage
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .navigationBarBackButtonHidden(sessionManager.workModeBlockID != nil)
        .onChange(of: sessionManager.workModeBlockID) {
            if sessionManager.workModeBlockID == nil {
                // Block completed, will auto-navigate back
            }
        }
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
                        viewModel.completeBlock()
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
                Map {
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
