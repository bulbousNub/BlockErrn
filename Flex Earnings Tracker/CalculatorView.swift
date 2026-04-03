import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import Combine

struct CalculatorView: View {

    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    @State private var grossBaseText: String = ""
    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 0

    @State private var hourlyRate: String = ""
    @State private var showValidation: Bool = false
    @State private var dateMode: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var selectedStartTime: Date = CalculatorView.nextQuarter(from: Date())
    @State private var selectedEndTime: Date = CalculatorView.nextQuarter(from: Date()).addingTimeInterval(2 * 60 * 60)
    @State private var hasTipsOnHome: Bool = false

    @State private var showAcceptedAlert: Bool = false
    @State private var acceptedBlock: Block? = nil
    @State private var currentTime: Date = Date()
    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var startReminderEnabled: Bool = true
    @State private var preEndReminderEnabled: Bool = true
    @State private var endReminderEnabled: Bool = true
    @State private var tipReminderEnabled: Bool = false
    @State private var workModeBlock: Block? = nil
    @State private var workModeCollapsed: Bool = false
    @State private var showWorkModeExpenseSheet: Bool = false
    @State private var startedBlockID: UUID? = nil
    @State private var blockPendingCompletion: Block? = nil
    @State private var showCompleteBlockAlert: Bool = false
    @State private var blockPendingStart: Block? = nil
    @State private var showSwitchBlockAlert: Bool = false
    @State private var showResetMilesAlert: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var mileageTracker: MileageTracker
    @EnvironmentObject private var blockNavigationState: BlockNavigationState
    @EnvironmentObject private var workModeCoordinator: WorkModeCoordinator
    @EnvironmentObject private var tabSelectionState: TabSelectionState

    private var activeSettings: AppSettings? {
        settings.first
    }

    private var shouldShowPlanCard: Bool {
        !(activeSettings?.hasDismissedPlanCard ?? false)
    }

    private var workModeActive: Bool {
        workModeBlock != nil
    }

    private var workModeRouteSegments: [[RoutePoint]]? {
        guard let block = workModeBlock else { return nil }
        var segments = block.routeSegments ?? []
        if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
            let live = mileageTracker.currentRoutePoints
            if !live.isEmpty {
                segments.append(live)
            }
        }
        return segments.isEmpty ? nil : segments
    }

    private var workModeMileageDisplay: String? {
        guard let block = workModeBlock else { return nil }
        let totalMiles = liveMiles(for: block)
        guard totalMiles > 0 else { return nil }
        let value = NSDecimalNumber(decimal: totalMiles).doubleValue
        return String(format: "%.2f mi", value)
    }

    private func enterWorkMode(_ block: Block) {
        withAnimation {
            startedBlockID = block.id
            workModeBlock = block
            workModeCollapsed = true
        }
    }

    private func showCalculatorView() {
        withAnimation {
            workModeBlock = nil
            workModeCollapsed = false
        }
    }

    private func exitWorkMode() {
        withAnimation {
            workModeBlock = nil
            workModeCollapsed = false
        }
    }

    private func handleWorkModeStop() {
        guard let block = workModeBlock else { return }
            if let (sessionMiles, routePoints) = mileageTracker.stopTracking(for: block.id) {
                let oldMiles = block.miles
                block.miles += Decimal(sessionMiles)
                block.appendRouteSegment(routePoints)
                block.recordAuditEntry(
                    action: .milesUpdated,
                    field: "miles",
                    oldValue: auditDecimalString(oldMiles),
                    newValue: auditDecimalString(block.miles),
                    note: "Captured during work mode stop"
                )
                block.updatedAt = Date()
                try? context.save()
            }
    }

    private func requestResetTrackedMiles() {
        showResetMilesAlert = true
    }

    private func performResetTrackedMiles() {
        guard let block = workModeBlock else { return }
        if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
            _ = mileageTracker.stopTracking(for: block.id)
        }
        block.miles = 0
        block.routePoints = nil
        block.updatedAt = Date()
        context.saveIfNeeded()
    }

    private func completeBlockAfterStoppingGPS(_ block: Block) {
        if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
            handleWorkModeStop()
        }
        let completionTime = Date()
        block.userCompletionTime = completionTime
        block.recordAuditEntry(
            action: .updated,
            field: "userCompletionTime",
            newValue: auditDateString(completionTime),
            note: "Completed via work mode"
        )
        complete(block, note: "Completed from work mode")
        withAnimation {
            workModeBlock = nil
            workModeCollapsed = false
        }
        blockNavigationState.blockToOpen = block
        tabSelectionState.selectedTab = 1
        workModeCoordinator.remove(block)
        blockPendingCompletion = nil
    }

    private func requestCompleteBlock(_ block: Block) {
        blockPendingCompletion = block
        showCompleteBlockAlert = true
    }

    private func startBlock(_ block: Block) {
        if let current = workModeBlock, current.id != block.id {
            blockPendingStart = block
            showSwitchBlockAlert = true
        } else {
            workModeCoordinator.forceActive(block)
            let startTime = Date()
            block.userStartTime = startTime
            block.recordAuditEntry(
                action: .updated,
                field: "userStartTime",
                newValue: auditDateString(startTime),
                note: "Started via work mode"
            )
            try? context.saveIfNeeded()
            enterWorkMode(block)
        }
    }

    @ViewBuilder
    private var workModeSection: some View {
        if let workBlock = workModeBlock {
                VStack(spacing: 12) {
                    WorkModeView(
                        block: workBlock,
                        routeSegments: workModeRouteSegments,
                        mileageDisplay: workModeMileageDisplay,
                        isTracking: mileageTracker.isTracking && mileageTracker.currentBlockID == workBlock.id,
                        onAddExpense: { showWorkModeExpenseSheet = true },
                        onStartTracking: {
                            mileageTracker.requestAuthorization()
                            mileageTracker.startTracking(for: workBlock.id)
                        },
                        onStopTracking: handleWorkModeStop,
                        onResetTrackedMiles: requestResetTrackedMiles
                    )
                    Button {
                        showCalculatorView()
                    } label: {
                        Label("Show Calculator", systemImage: "calculator")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }

    private var datePickerControlColor: Color {
        colorScheme == .light ? .primary : .accentColor
    }

    private var reminderBeforeStartMinutes: Int {
        settings.first?.reminderBeforeStartMinutes ?? 45
    }

    private var reminderBeforeEndMinutes: Int {
        settings.first?.reminderBeforeEndMinutes ?? 15
    }

    private var tipReminderHourCount: Int {
        settings.first?.tipReminderHours ?? 24
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlockErrnTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                if !activeBlocks.isEmpty {
                    sectionBlockList(
                        title: "Active blocks",
                        blocks: activeBlocks,
                        showStartButton: true,
                        showMenu: false,
                        onStartBlock: startBlock,
                        onCompleteBlock: requestCompleteBlock
                    )
                }
                if workModeBlock == nil && !upcomingBlocks.isEmpty {
                    sectionBlockList(title: "Upcoming blocks", blocks: upcomingBlocks, showStartButton: false, showCompleteAction: false)
                }
                workModeSection
                if !workModeCollapsed {
                    if shouldShowPlanCard {
                        heroCard
                    }
                    calculateAndAcceptCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
                .refreshable {
                    startTimer()
                }
            }
            .navigationTitle("BlockErrn")
            .onAppear {
                startTimer()
                preEndReminderEnabled = settings.first?.includePreReminder ?? true
            }
            .onReceive(timer) { currentTime = $0 }
            .onChange(of: selectedHours) { _ in
                syncEndToDuration()
            }
            .onChange(of: selectedMinutes) { _ in
                syncEndToDuration()
            }
            .alert("Block Accepted", isPresented: $showAcceptedAlert) {
                Button("View in Log") {
                    tabSelectionState.selectedTab = 1
                }
                Button("Done", role: .cancel) { }
            } message: {
                Text("Add miles, tips, and expenses in the Log to finish profiling the block.")
            }
            .alert("Complete block", isPresented: $showCompleteBlockAlert) {
                Button("Stop GPS & complete block") {
                    if let block = blockPendingCompletion {
                        completeBlockAfterStoppingGPS(block)
                    }
                }
                Button("Cancel", role: .cancel) {
                    blockPendingCompletion = nil
                }
            } message: {
                Text("This will stop GPS tracking and mark the block as completed. The event is always reversible via the log if you need to reopen it.")
            }
            .alert("Switch active block", isPresented: $showSwitchBlockAlert) {
                Button("Switch") {
                    guard let target = blockPendingStart else { return }
                    if mileageTracker.isTracking && mileageTracker.currentBlockID == workModeBlock?.id {
                        handleWorkModeStop()
                    }
                    enterWorkMode(target)
                    blockPendingStart = nil
                }
                Button("Cancel", role: .cancel) {
                    blockPendingStart = nil
                }
            } message: {
                Text("Stop GPS tracking for the current block and switch to the new one?")
            }
            .alert("Reset tracked miles", isPresented: $showResetMilesAlert) {
                Button("Reset") {
                    performResetTrackedMiles()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will stop GPS tracking (if active) and clear the miles recorded for the current block.")
            }
            .sheet(isPresented: $showWorkModeExpenseSheet) {
                if let block = workModeBlock {
                    AddExpenseSheet(block: Binding(get: { block }, set: { _ in }))
                }
            }
            .onChange(of: workModeCoordinator.blockToStart) { block in
                guard let block = block else { return }
                if let current = workModeBlock, current.id != block.id, mileageTracker.isTracking && mileageTracker.currentBlockID == current.id {
                    handleWorkModeStop()
                }
                workModeCoordinator.forceActive(block)
                block.recordAuditEntry(
                    action: .updated,
                    field: "activeState",
                    newValue: "true",
                    note: "Promoted via work mode coordinator"
                )
                context.saveIfNeeded()
                enterWorkMode(block)
                workModeCoordinator.blockToStart = nil
            }
            .onChange(of: workModeCoordinator.blockToStop) { block in
                guard let block = block else { return }
                if workModeBlock?.id == block.id {
                    withAnimation {
                        workModeBlock = nil
                        workModeCollapsed = false
                    }
                }
                workModeCoordinator.blockToStop = nil
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan with confidence")
                .font(.headline)
            Text("Use the tiles below to model your next trip—the tracker handles gross, tips, mileage, and reminders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Tap Got it once you’ve reviewed the quick tips so this card can stay out of the way.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Got it") {
                    acknowledgePlanCard()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
        }
        .flexErrnCardStyle()
    }

    private func acknowledgePlanCard() {
        guard let settingsInstance = activeSettings else { return }
        settingsInstance.hasDismissedPlanCard = true
        try? context.save()
    }

    private var calculateAndAcceptCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Calculate & Accept Block")
                    .font(.headline)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)
                TextField("Base Pay", text: $grossBaseText)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.leading)
                    .keyboardDoneToolbar()
            }
            .padding(.vertical, 8)
            Divider()
            HStack(alignment: .top, spacing: 12) {
                durationMenuPicker(title: "Hours", value: $selectedHours, options: Array(0..<9))
                durationMenuPicker(title: "Minutes", value: $selectedMinutes, options: [0, 15, 30, 45])
                Toggle("", isOn: $hasTipsOnHome)
                    .toggleStyle(.switch)
                    .overlay(
                        Text("Has tips")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .offset(y: -16),
                        alignment: .top
                    )
                    .padding(.top, 8)
                Spacer()
                Button {
                    computeHourly()
                } label: {
                    Text("Compute")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .textCase(.none)
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            if !hourlyRate.isEmpty {
                HStack {
                    Text("Hourly rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(hourlyRate)
                        .font(.title3)
                        .bold()
                }
            }
            if showValidation {
                Text("Enter a valid amount and select a duration greater than 0.")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            Divider()
            VStack(spacing: 16) {
                HStack {
                    Text("Block Schedule")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: $dateMode) {
                        Text("Today").tag(0)
                        Text("Tomorrow").tag(1)
                        Text("Future").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .onChange(of: dateMode) { mode in
                        let calendar = Calendar.current
                        switch mode {
                        case 0:
                            alignScheduleDate(with: Date())
                        case 1:
                            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                            alignScheduleDate(with: tomorrow)
                        default:
                            let validFuture = selectedDate > Date() ? selectedDate : (calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                            alignScheduleDate(with: validFuture)
                        }
                    }
                }
                if dateMode == 2 {
                    DatePicker("Select date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .tint(datePickerControlColor)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("Start time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: Binding(get: { selectedStartTime }, set: startTimeChanged), displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("End time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: Binding(get: { selectedEndTime }, set: endTimeChanged), displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
                Divider()
                HStack {
                    Text("Block Reminders")
                        .font(.headline)
                    Spacer()
                }
                reminderToggleGrid
            }
            Button {
                acceptBlock()
            } label: {
                Text("Accept Block")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
        }
        .flexErrnCardStyle()
    }

    private var reminderToggleGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 8) {
            reminderToggle(
                title: "\(reminderBeforeStartMinutes) Minutes Before Start",
                isOn: $startReminderEnabled
            )
            reminderToggle(
                title: "\(reminderBeforeEndMinutes) Minutes Before End",
                isOn: $preEndReminderEnabled
            )
            reminderToggle(
                title: "Reminder at Block End",
                isOn: $endReminderEnabled
            )
            reminderToggle(
                title: "\(tipReminderHourCount)-hour Tip Reminder",
                isOn: $tipReminderEnabled,
                disabled: !hasTipsOnHome
            )
        }
    }

    private func reminderToggle(title: String, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(disabled ? .secondary : .primary)
                .multilineTextAlignment(.leading)
        }
        .toggleStyle(.switch)
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(disabled ? 0.4 : 0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(disabled ? 0.15 : 0.25), lineWidth: 1)
        )
    }

    private func sectionBlockList(
        title: String,
        blocks: [Block],
        showStartButton: Bool,
        showCompleteAction: Bool = true,
        showMenu: Bool = true,
        onStartBlock: ((Block) -> Void)? = nil,
        onCompleteBlock: ((Block) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ForEach(blocks, id: \.id) { block in
                NavigationLink(destination: BlockDetailView(block: block)) {
                BlockCard(
                    block: block,
                    showStartButton: showStartButton,
                    isWorkModeBlock: workModeBlock?.id == block.id,
                    isResumableBlock: startedBlockID == block.id && workModeBlock?.id != block.id,
                    showCompleteAction: showCompleteAction,
                    showMenu: showMenu && (workModeBlock?.id != block.id),
                    onStartBlock: onStartBlock,
                    onCompleteBlock: onCompleteBlock
                )
                }
                .buttonStyle(.plain)
            }
        }
        .flexErrnCardStyle()
    }

    @ViewBuilder
    private func BlockCard(
        block: Block,
        showStartButton: Bool,
        isWorkModeBlock: Bool = false,
        isResumableBlock: Bool = false,
        showCompleteAction: Bool = true,
        showMenu: Bool = true,
        onStartBlock: ((Block) -> Void)? = nil,
        onCompleteBlock: ((Block) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(block.date, style: .date)
                    .font(.subheadline)
                Spacer()
                Text(block.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if showMenu {
                    Menu {
                        if block.isEligibleForMakeActive {
                            Button("Make Active") {
                                workModeCoordinator.forceActive(block)
                                block.recordAuditEntry(
                                    action: .updated,
                                    field: "activeState",
                                    newValue: "true",
                                    note: "Promoted from calculator view"
                                )
                                context.saveIfNeeded()
                                tabSelectionState.selectedTab = 0
                            }
                        }
                        if showCompleteAction {
                            Button("Complete") { complete(block) }
                                .disabled(block.status == .completed)
                        }
                        Button("Cancel") { cancel(block) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            Text("\(blockTimeFormatter.string(from: startDate(for: block))) – \(blockTimeFormatter.string(from: endDate(for: block)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            let liveMiles = liveMiles(for: block)
            let mileageCost = liveMileageExpense(for: block)
            let liveProfitValue = liveProfit(for: block)
            let milesLabel = formatRoundedMileage(liveMiles)
            let shouldShowMetrics = isWorkModeBlock || isResumableBlock
            if shouldShowMetrics {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gross: \(formatCurrency(block.grossPayout))")
                            .font(.caption2)
                        if block.shouldIncludeExpensesDeduction {
                            Text("Expenses: \(formatCurrency(block.additionalExpensesTotal))")
                                .font(.caption2)
                        }
                        if block.shouldIncludeMileageDeduction {
                            Text("Mileage cost: \(formatCurrency(mileageCost))")
                                .font(.caption2)
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Miles: \(milesLabel)")
                            .font(.caption2)
                        Text("Profit: \(formatCurrency(liveProfitValue))")
                            .font(.caption2)
                    }
                }
            }
            if let start = onStartBlock {
                Button {
                    if isWorkModeBlock {
                        onCompleteBlock?(block)
                    } else {
                        start(block)
                    }
                } label: {
                    Label(
                        isWorkModeBlock ? "Complete Block" : (isResumableBlock ? "Resume Block" : "Start Block"),
                        systemImage: isWorkModeBlock ? "checkmark.circle.fill" : (isResumableBlock ? "arrow.clockwise" : "play.circle.fill")
                    )
                        .font(.caption)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    private func startTimer() {
        currentTime = Date()
    }

    private struct WorkModeView: View {
        let block: Block
        let routeSegments: [[RoutePoint]]?
        let mileageDisplay: String?
        let isTracking: Bool
        let onAddExpense: () -> Void
        let onStartTracking: () -> Void
        let onStopTracking: () -> Void
        let onResetTrackedMiles: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Work Mode")
                        .font(.headline)
                    Spacer()
                    Menu {
                        Button("Reset Tracked Miles") {
                            onResetTrackedMiles()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                WorkModeMapView(routeSegments: routeSegments, showsEndAnnotation: !isTracking)
                    .frame(height: 200)
                if let mileage = mileageDisplay {
                    HStack {
                        Spacer()
                        Text("Miles: \(mileage)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Button("Add Expense") {
                        onAddExpense()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.accentColor)

                    Spacer()

                    Button(isTracking ? "Stop Tracking" : "Start Tracking") {
                        if isTracking {
                            onStopTracking()
                        } else {
                            onStartTracking()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.accentColor)
                }
            }
            .flexErrnCardStyle()
        }
    }

    private struct WorkModeMapView: UIViewRepresentable {
        let routeSegments: [[RoutePoint]]?
        let showsEndAnnotation: Bool

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            mapView.delegate = context.coordinator
            mapView.showsCompass = false
            mapView.showsUserLocation = true
            mapView.isRotateEnabled = false
            mapView.isPitchEnabled = false
            mapView.layer.cornerRadius = 16
            context.coordinator.attach(mapView)
            return mapView
        }

        func updateUIView(_ mapView: MKMapView, context: Context) {
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
            mapView.userTrackingMode = showsEndAnnotation ? .none : .follow
            context.coordinator.shouldFollowUser = !showsEndAnnotation

            let segments = routeSegments?.map { $0.map(\.coordinate) }.filter { !$0.isEmpty } ?? []
            guard !segments.isEmpty else {
                if let location = context.coordinator.lastKnownLocation {
                    mapView.setRegion(Self.regionForCoordinate(location.coordinate), animated: false)
                } else {
                    let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902)
                    mapView.region = MKCoordinateRegion(center: defaultCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                }
                return
            }

            let allCoords = segments.flatMap { $0 }
            let region = regionForCoordinates(allCoords)
            mapView.setRegion(region, animated: false)

            if allCoords.count > 1 {
                for segment in segments {
                    let polyline = MKPolyline(coordinates: segment, count: segment.count)
                    mapView.addOverlay(polyline)
                }
            }

            let totalSegments = segments.count
            let completedSegmentCount = showsEndAnnotation ? totalSegments : max(0, totalSegments - 1)

            for (index, segment) in segments.enumerated() {
                if let start = segment.first {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = start
                    annotation.title = title(for: index, total: totalSegments, type: .start)
                    mapView.addAnnotation(annotation)
                }

                if index < completedSegmentCount, let end = segment.last, regionContains(region, coordinate: end) {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = end
                    annotation.title = title(for: index, total: totalSegments, type: .end)
                    mapView.addAnnotation(annotation)
                }
            }
        }

        private func regionForCoordinates(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
            let latitudes = coords.map(\.latitude)
            let longitudes = coords.map(\.longitude)
            let maxLat = latitudes.max() ?? 0
            let minLat = latitudes.min() ?? 0
            let maxLong = longitudes.max() ?? 0
            let minLong = longitudes.min() ?? 0
            let center = CLLocationCoordinate2D(latitude: (maxLat + minLat) / 2, longitude: (maxLong + minLong) / 2)
            let span = MKCoordinateSpan(latitudeDelta: max(0.005, (maxLat - minLat) * 1.5), longitudeDelta: max(0.005, (maxLong - minLong) * 1.5))
            return MKCoordinateRegion(center: center, span: span)
        }

        private static func regionForCoordinate(_ coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
            MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }

        private func regionContains(_ region: MKCoordinateRegion, coordinate: CLLocationCoordinate2D) -> Bool {
            let latInRange = coordinate.latitude >= region.center.latitude - region.span.latitudeDelta/2 &&
                coordinate.latitude <= region.center.latitude + region.span.latitudeDelta/2
            let lonInRange = coordinate.longitude >= region.center.longitude - region.span.longitudeDelta/2 &&
                coordinate.longitude <= region.center.longitude + region.span.longitudeDelta/2
            return latInRange && lonInRange
        }

        private enum AnnotationType { case start, end }

        private func title(for index: Int, total: Int, type: AnnotationType) -> String {
            if total == 1 {
                return type == .start ? "Start" : "End"
            }
            let label = type == .start ? "Start" : "End"
            return "\(label) - \(index + 1)"
        }

        fileprivate class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
            private let locationManager = CLLocationManager()
            private weak var mapView: MKMapView?
            var lastKnownLocation: CLLocation?
            var shouldFollowUser: Bool = false

            override init() {
                super.init()
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.requestWhenInUseAuthorization()
                locationManager.requestLocation()
            }

            func attach(_ mapView: MKMapView) {
                self.mapView = mapView
                locationManager.requestLocation()
            }

            func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                if let polyline = overlay as? MKPolyline {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = UIColor.systemBlue
                    renderer.lineWidth = 4
                    return renderer
                }
                return MKOverlayRenderer(overlay: overlay)
            }

            func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
                guard let location = locations.last else { return }
                lastKnownLocation = location
                let shouldCenter = shouldFollowUser || (mapView?.overlays.isEmpty ?? true)
                guard shouldCenter else { return }
                mapView?.setRegion(WorkModeMapView.regionForCoordinate(location.coordinate), animated: true)
            }

            func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
                // ignore
            }
        }
    }

    private func liveMiles(for block: Block) -> Decimal {
        let baseMiles = block.miles
        guard
            mileageTracker.isTracking,
            mileageTracker.currentBlockID == block.id
        else {
            return baseMiles
        }
        return baseMiles + Decimal(mileageTracker.currentMiles)
    }

    private func mileageRate(for block: Block) -> Decimal {
        activeSettings?.irsMileageRate ?? block.irsRateSnapshot
    }

    private func roundedMilesDecimal(_ miles: Decimal) -> Decimal {
        var mutableMiles = miles
        var rounded = Decimal()
        NSDecimalRound(&rounded, &mutableMiles, 0, .plain)
        return rounded
    }

    private func formatRoundedMileage(_ miles: Decimal) -> String {
        let wholeMiles = NSDecimalNumber(decimal: roundedMilesDecimal(miles)).intValue
        return "\(wholeMiles) mi"
    }

    private func liveMileageExpense(for block: Block) -> Decimal {
        let rate = mileageRate(for: block)
        guard block.shouldIncludeMileageDeduction else { return 0 }
        let miles = liveMiles(for: block)
        let usedMiles = roundedMilesDecimal(miles)
        return usedMiles * rate
    }

    private func liveProfit(for block: Block) -> Decimal {
        let gross = block.grossPayout
        let expenses = block.shouldIncludeExpensesDeduction ? block.additionalExpensesTotal : 0
        let mileage = liveMileageExpense(for: block)
        return gross - expenses - mileage
    }


    private func durationMenuPicker(title: String, value: Binding<Int>, options: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        value.wrappedValue = option
                    } label: {
                        Text("\(option)")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(value.wrappedValue)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(minWidth: 24)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            }
            .menuStyle(.borderlessButton)
            .tint(.primary)
        }
        .frame(minWidth: 60)
    }

    private func computeHourly() {
        guard let gross = Decimal(string: grossBaseText), gross >= 0 else { showValidation = true; return }
        let totalMinutes = selectedHours * 60 + selectedMinutes
        guard totalMinutes > 0 else { showValidation = true; return }

        let hrs = Decimal(totalMinutes) / 60
        let hourly = (hrs == 0) ? 0 : (gross / hrs)
        hourlyRate = formatCurrency(hourly)
        showValidation = false
    }

    private func acceptBlock() {
        guard let gross = Decimal(string: grossBaseText), gross >= 0 else { showValidation = true; return }
        let totalMinutes = selectedHours * 60 + selectedMinutes
        guard totalMinutes > 0 else { showValidation = true; return }

        let rate = settings.first?.irsMileageRate ?? 0.70
        let blockDate = (dateMode == 0) ? Date() : selectedDate
        let startDate = combine(date: blockDate, time: selectedStartTime)
        let endDate = combine(date: blockDate, time: selectedEndTime)
        let block = Block(date: blockDate, durationMinutes: totalMinutes, grossBase: gross, irsRateSnapshot: rate, startTime: startDate, endTime: endDate)
        block.hasTips = hasTipsOnHome
        block.auditEntries.append(AuditEntry(action: AuditAction.created, note: "Block accepted from calculator"))
        logBlockCreationFields(for: block, note: "Captured during calculator entry", currencyFormatter: currencyString)
        context.insert(block)
        let reminderConfig = NotificationManager.ReminderConfiguration(
            startMinutes: reminderBeforeStartMinutes,
            preEndMinutes: reminderBeforeEndMinutes,
            tipHours: tipReminderHourCount,
            startEnabled: startReminderEnabled,
            preEndEnabled: preEndReminderEnabled,
            endEnabled: endReminderEnabled,
            tipEnabled: tipReminderEnabled,
            hasTips: hasTipsOnHome
        )
        NotificationManager.shared.scheduleBlockReminders(for: block, config: reminderConfig)
        try? context.save()
        acceptedBlock = block
        showAcceptedAlert = shouldShowAcceptedAlert(for: block)
        grossBaseText = ""
        selectedHours = 0
        selectedMinutes = 0
        hourlyRate = ""
        dateMode = 0
        selectedDate = Date()
        resetTimePickers()
        hasTipsOnHome = false
    }

    private func cancel(_ block: Block) {
        guard block.status != .cancelled else { return }
        block.status = .cancelled
        logStatusChange(for: block, note: "Marked cancelled from calculator")
        block.updatedAt = Date()
        context.saveIfNeeded()
    }

    private func complete(_ block: Block, note: String = "Marked completed from calculator") {
        guard block.status != .completed else { return }
        block.status = .completed
        logStatusChange(for: block, note: note)
        block.updatedAt = Date()
        context.saveIfNeeded()
    }

    private func logStatusChange(for block: Block, note: String) {
        let entry = AuditEntry(action: .statusChanged, note: note)
        block.auditEntries.append(entry)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let ns = value as NSDecimalNumber
        return ns.stringValue
    }

    private var upcomingBlocks: [Block] {
        _ = currentTime
        let now = Date()
        let calendar = Calendar.current
        let windowEnd = calendar.date(byAdding: .day, value: 2, to: now) ?? now
        let activeIDs = Set(activeBlocks.map { $0.id })
        return blocks
            .filter { block in
                guard block.status == .accepted else { return false }
                let start = startDate(for: block)
                guard start > now, start <= windowEnd else { return false }
                return !activeIDs.contains(block.id)
            }
        .sorted { startDate(for: $0) < startDate(for: $1) }
    }

    private var activeBlocks: [Block] {
        _ = currentTime
        let now = Date()
        let window = now.addingTimeInterval(45 * 60)
        return blocks
            .filter { block in
                guard block.status == .accepted else { return false }
                let start = startDate(for: block)
                let end = endDate(for: block)
                let isForced = workModeCoordinator.forcedActiveBlockIDs.contains(block.id)
                return (start <= window && end > now) || isForced
            }
            .sorted { startDate(for: $0) < startDate(for: $1) }
    }

    private func shouldShowAcceptedAlert(for block: Block) -> Bool {
        let now = Date()
        let start = startDate(for: block)
        let end = endDate(for: block)
        let activeWindow = now.addingTimeInterval(45 * 60)
        if start <= activeWindow && end > now {
            return false
        }
        let calendar = Calendar.current
        let upcomingWindow = calendar.date(byAdding: .day, value: 2, to: now) ?? now
        if start > now && start <= upcomingWindow {
            return false
        }
        return true
    }

    private func alignScheduleDate(with date: Date) {
        let previousStart = selectedStartTime
        let previousEnd = selectedEndTime
        selectedDate = date
        selectedStartTime = combine(date: date, time: previousStart)
        selectedEndTime = combine(date: date, time: previousEnd)
    }

    private func startDate(for block: Block) -> Date {
        block.scheduledStartDate
    }

    private func endDate(for block: Block) -> Date {
        block.scheduledEndDate
    }

    @Query(sort: [SortDescriptor(\Block.date)]) private var blocks: [Block]

    private func durationText(for totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        } else {
            return "\(minutes)m"
        }
    }

    private func startTimeChanged(_ newValue: Date) {
        selectedStartTime = combine(date: selectedDate, time: newValue)
        syncEndToDuration()
    }

    private func endTimeChanged(_ newValue: Date) {
        selectedEndTime = combine(date: selectedDate, time: newValue)
        syncDurationFromTimeRange()
    }

    private func syncDurationToTimeRange() {
        let diff = Int(max(1, selectedEndTime.timeIntervalSince(selectedStartTime) / 60))
        selectedHours = diff / 60
        selectedMinutes = diff % 60
    }

    private func syncEndToDuration() {
        let totalMinutes = selectedHours * 60 + selectedMinutes
        selectedEndTime = selectedStartTime.addingTimeInterval(TimeInterval(totalMinutes * 60))
    }

    private func syncDurationFromTimeRange() {
        syncDurationToTimeRange()
    }

    private func resetTimePickers() {
        let nextStart = CalculatorView.nextQuarter(from: Date())
        selectedStartTime = combine(date: Date(), time: nextStart)
        selectedEndTime = nextStart.addingTimeInterval(TimeInterval(max(1, selectedHours * 60 + selectedMinutes) * 60))
    }

    private static func nextQuarter(from date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let minute = components.minute else { return date }
        let remainder = minute % 15
        let delta = remainder == 0 ? 0 : (15 - remainder)
        return calendar.date(byAdding: .minute, value: delta, to: date) ?? date
    }

    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        return calendar.date(from: dateComponents) ?? date
    }
}

private extension ModelContext {
    func saveIfNeeded() {
        guard hasChanges else { return }
        try? save()
    }
}
