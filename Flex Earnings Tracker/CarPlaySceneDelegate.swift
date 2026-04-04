#if canImport(CarPlay)
import CarPlay
import UIKit
import MapKit
import SwiftData
import Foundation

@objcMembers
public class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate, CPInterfaceControllerDelegate {
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private var refreshTimer: Timer?
    private var workModeBlockID: UUID?
    private lazy var mapHost = CarPlayMapHostViewController()
    private let context = ModelStorage.shared.context
    private let mileageTracker = MileageTracker.shared
    private var isShowingActiveBlockDetail = false
    private var activeWorkModeTemplate: CPInformationTemplate?
    private var activeDetailTemplate: CPInformationTemplate?
    private var detailBlockID: UUID?
    private var activeDashboardTab: CPTabBarTemplate?

    @objc(templateApplicationScene:didConnectInterfaceController:)
    public dynamic func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        interfaceController.delegate = self
        startDashboardRefresh()
        Task { await self.updateDashboard() }
    }

    @objc(templateApplicationScene:didConnectInterfaceController:toWindow:)
    public dynamic func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window
        interfaceController.delegate = self
        window.rootViewController = mapHost
        startDashboardRefresh()
        Task { await self.updateDashboard() }
    }

    public dynamic func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        stopDashboardRefresh()
        self.interfaceController = nil
        self.carWindow = nil
        workModeBlockID = nil
        activeWorkModeTemplate = nil
        activeDetailTemplate = nil
        activeDashboardTab = nil
        mapHost.clearRoute()
    }

    func interfaceController(_ interfaceController: CPInterfaceController, didSelect template: CPTemplate) {
        // no-op
    }

    private func startDashboardRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { await self?.refreshInterface() }
        }
        refreshTimer?.tolerance = 2
        Task { await refreshInterface() }
    }

    private func stopDashboardRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func fetchBlocks() -> [Block] {
        let descriptor = FetchDescriptor<Block>(sortBy: [SortDescriptor(\.date)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private struct BlockCatalog {
        let blocks: [Block]
        let now: Date
        let forcedActiveIDs: Set<UUID>

        var activeBlocks: [Block] {
            let window = now.addingTimeInterval(45 * 60)
            return blocks.filter {
                guard $0.status == .accepted else { return false }
                let start = $0.scheduledStartDate
                let end = $0.scheduledEndDate
                let isForced = forcedActiveIDs.contains($0.id)
                return (start <= window && end > now) || isForced
            }
        }

        var upcomingBlocks: [Block] {
            let calendar = Calendar.current
            let windowEnd = calendar.date(byAdding: .day, value: 2, to: now) ?? now
            let activeIDs = Set(activeBlocks.map { $0.id })
            return blocks.filter {
                guard $0.status == .accepted else { return false }
                let start = $0.scheduledStartDate
                return start > now && start <= windowEnd && !activeIDs.contains($0.id)
            }
        }
    }

    private func updateDashboard() async {
        guard let interfaceController else { return }
        let blocks = fetchBlocks()
        let forcedIDs = WorkModeCoordinator.shared.forcedActiveBlockIDs
        let catalog = BlockCatalog(blocks: blocks, now: Date(), forcedActiveIDs: forcedIDs)

        // Update existing tab contents in-place to avoid resetting the
        // selected tab and causing a visible "bounce" on CarPlay.
        if let existingTab = activeDashboardTab,
           let templates = existingTab.templates as? [CPListTemplate],
           templates.count == 2 {
            let activeSection = makeListSection(for: catalog.activeBlocks, title: "Active", isActive: true)
            let upcomingSection = makeListSection(for: catalog.upcomingBlocks, title: "Upcoming", isActive: false)
            templates[0].updateSections([activeSection])
            templates[1].updateSections([upcomingSection])
            return
        }

        let dashboard = makeDashboardTemplate(active: catalog.activeBlocks, upcoming: catalog.upcomingBlocks)
        activeDashboardTab = dashboard
        interfaceController.setRootTemplate(dashboard, animated: true, completion: nil)
    }

    private func refreshInterface() async {
        guard let interfaceController else { return }

        // Sync with iOS app: if a block was started from the phone,
        // MileageTracker will be tracking but CarPlay's workModeBlockID won't be set.
        if workModeBlockID == nil, mileageTracker.isTracking, let trackingID = mileageTracker.currentBlockID {
            if let block = fetchBlock(by: trackingID) {
                workModeBlockID = trackingID
                isShowingActiveBlockDetail = false
                activeDetailTemplate = nil
                showWorkMode(for: block)
                return
            }
        }

        if let blockID = workModeBlockID, let block = fetchBlock(by: blockID) {
            // If the block was completed (from iOS or CarPlay), exit work mode.
            if block.status == .completed {
                workModeBlockID = nil
                activeWorkModeTemplate = nil
                mapHost.clearRoute()
                await updateDashboard()
                return
            }
            if let existing = activeWorkModeTemplate {
                existing.items = makeWorkModeItems(for: block)
                existing.actions = makeWorkModeActions(for: block)
                updateWorkModeGPSIndicator(on: existing)
            } else {
                let workTemplate = makeWorkModeTemplate(for: block)
                interfaceController.setRootTemplate(workTemplate, animated: true, completion: nil)
            }
            return
        }

        // If showing the block detail screen, check whether that block
        // was started from the iOS app (userStartTime set or tracking began).
        if isShowingActiveBlockDetail, let detailTemplate = activeDetailTemplate {
            // Find the block being viewed by checking which block has a
            // userStartTime that was recently set or is being tracked
            if mileageTracker.isTracking, let trackingID = mileageTracker.currentBlockID,
               let block = fetchBlock(by: trackingID) {
                workModeBlockID = trackingID
                isShowingActiveBlockDetail = false
                activeDetailTemplate = nil
                showWorkMode(for: block)
                return
            }
            // Also update the detail items to reflect any changes
            if let blockID = detailBlockID, let block = fetchBlock(by: blockID) {
                detailTemplate.items = makeBlockDetailItems(for: block)
            }
            return
        }

        await updateDashboard()
    }

    private func fetchBlock(by id: UUID) -> Block? {
        let descriptor = FetchDescriptor<Block>(
            predicate: #Predicate<Block> { $0.id == id },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func makeDashboardTemplate(active: [Block], upcoming: [Block]) -> CPTabBarTemplate {
        let activeTemplate = CPListTemplate(
            title: "Active blocks",
            sections: [makeListSection(for: active, title: "Active", isActive: true)]
        )
        activeTemplate.tabTitle = "Active"
        activeTemplate.tabImage = UIImage(systemName: "bolt.fill")

        let upcomingTemplate = CPListTemplate(
            title: "Upcoming blocks",
            sections: [makeListSection(for: upcoming, title: "Upcoming", isActive: false)]
        )
        upcomingTemplate.tabTitle = "Upcoming"
        upcomingTemplate.tabImage = UIImage(systemName: "calendar")

        return CPTabBarTemplate(templates: [activeTemplate, upcomingTemplate])
    }

    private func makeListSection(for blocks: [Block], title: String, isActive: Bool) -> CPListSection {
        let items: [CPListItem]
        if blocks.isEmpty {
            let empty = CPListItem(text: "No \(title.lowercased()) blocks", detailText: "Connect to your phone to add more")
            items = [empty]
        } else {
            items = blocks.map { block in
                let header = dateFormatter.string(from: block.scheduledStartDate)
                let detail = "\(timeFormatter.string(from: block.scheduledStartDate)) – \(timeFormatter.string(from: block.scheduledEndDate))"
                let item = CPListItem(text: header, detailText: detail)
                item.userInfo = block.id as NSCopying?
                if isActive {
                    item.handler = { [weak self] _, completion in
                        self?.showActiveBlockDetail(block)
                        completion()
                    }
                } else {
                    item.handler = { [weak self] _, completion in
                        self?.promptMakeActive(block)
                        completion()
                    }
                }
                return item
            }
        }
        return CPListSection(items: items)
    }

    private func promptMakeActive(_ block: Block) {
        guard let interfaceController else { return }
        let makeActiveAction = CPAlertAction(title: "Make Active", style: .default) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            DispatchQueue.main.async {
                WorkModeCoordinator.shared.forceActive(block)
            }
            block.recordAuditEntry(
                action: .updated,
                field: "activeState",
                newValue: "true",
                note: "Promoted via CarPlay"
            )
            try? self?.context.save()
            Task { await self?.updateDashboard() }
        }
        let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
        let alert = CPAlertTemplate(
            titleVariants: ["Move this block to Active?"],
            actions: [makeActiveAction, cancelAction]
        )
        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }

    private func showActiveBlockDetail(_ block: Block) {
        guard let interfaceController else { return }

        // If this block is already being tracked (started from iOS app),
        // go straight to work mode instead of showing "Start Block"
        if mileageTracker.isTracking && mileageTracker.currentBlockID == block.id {
            workModeBlockID = block.id
            showWorkMode(for: block)
            return
        }

        activeDashboardTab = nil
        isShowingActiveBlockDetail = true
        detailBlockID = block.id
        let detailTemplate = makeActiveBlockDetailTemplate(for: block)
        activeDetailTemplate = detailTemplate
        interfaceController.setRootTemplate(detailTemplate, animated: true, completion: nil)
    }

    private func makeActiveBlockDetailTemplate(for block: Block) -> CPInformationTemplate {
        let items = makeBlockDetailItems(for: block)

        let startButton = CPTextButton(title: "Start Block", textStyle: .confirm) { [weak self] _ in
            self?.handleStart(block: block)
        }
        let backButton = CPTextButton(title: "Back", textStyle: .cancel) { [weak self] _ in
            self?.activeDetailTemplate = nil
            self?.detailBlockID = nil
            self?.isShowingActiveBlockDetail = false
            Task { await self?.refreshInterface() }
        }

        return CPInformationTemplate(
            title: "Block Details",
            layout: .twoColumn,
            items: items,
            actions: [startButton, backButton]
        )
    }

    private func makeBlockDetailItems(for block: Block) -> [CPInformationItem] {
        let currentLiveMiles = liveMiles(for: block)
        let milesDetail = String(format: "%.2f mi (%@)", NSDecimalNumber(decimal: currentLiveMiles).doubleValue, formatCurrency(liveMileageDeduction(for: block)))
        let schedule = "\(timeFormatter.string(from: block.scheduledStartDate)) – \(timeFormatter.string(from: block.scheduledEndDate))"
        return [
            CPInformationItem(title: "Schedule", detail: schedule),
            CPInformationItem(title: "Gross", detail: formatCurrency(block.grossPayout)),
            CPInformationItem(title: "Miles", detail: milesDetail),
            CPInformationItem(title: "Expenses", detail: formatCurrency(block.additionalExpensesTotal)),
            CPInformationItem(title: "Profit", detail: formatCurrency(liveProfit(for: block)))
        ]
    }

    private func handleStart(block: Block) {
        guard block.status == .accepted else { return }
        workModeBlockID = block.id
        let startTime = block.userStartTime ?? Date()
        if block.userStartTime == nil {
            block.userStartTime = startTime
            block.recordAuditEntry(action: .updated, field: "userStartTime", newValue: auditDateString(startTime), note: "Started via CarPlay")
        }
        try? context.save()

        // Only start GPS tracking if not already tracking for this block
        // (the iOS app may have already started it)
        let alreadyTracking = mileageTracker.isTracking && mileageTracker.currentBlockID == block.id
        if !alreadyTracking {
            mileageTracker.requestAuthorization()
            mileageTracker.startTracking(for: block.id)
            LiveActivityManager.shared.startActivity(
                blockID: block.id,
                scheduledStart: block.scheduledStartDate,
                scheduledEnd: block.scheduledEndDate
            )
        }
        DispatchQueue.main.async {
            WorkModeCoordinator.shared.startManually(block)
        }
        isShowingActiveBlockDetail = false
        showWorkMode(for: block)
        Task { await refreshInterface() }
    }

    private func showWorkMode(for block: Block) {
        guard let interfaceController else { return }
        activeDashboardTab = nil
        mapHost.updateRoute(block.routeSegments ?? [])
        carWindow?.rootViewController = mapHost
        let workTemplate = makeWorkModeTemplate(for: block)
        activeWorkModeTemplate = workTemplate
        interfaceController.setRootTemplate(workTemplate, animated: true, completion: nil)
    }

    private func makeWorkModeTemplate(for block: Block) -> CPInformationTemplate {
        let items = makeWorkModeItems(for: block)
        let actions = makeWorkModeActions(for: block)

        let template = CPInformationTemplate(
            title: "BlockErrn - Work Mode",
            layout: .twoColumn,
            items: items,
            actions: actions
        )

        updateWorkModeGPSIndicator(on: template)

        return template
    }

    private func makeWorkModeActions(for block: Block) -> [CPTextButton] {
        let isCurrentlyTracking = mileageTracker.isTracking && mileageTracker.currentBlockID == block.id

        let trackingButton: CPTextButton
        if isCurrentlyTracking {
            trackingButton = CPTextButton(title: "Stop Tracking", textStyle: .normal) { [weak self] _ in
                self?.handleStopTracking(block: block)
            }
        } else {
            trackingButton = CPTextButton(title: "Start Tracking", textStyle: .confirm) { [weak self] _ in
                self?.handleStartTracking(block: block)
            }
        }

        let completeBlockButton = CPTextButton(title: "End Block", textStyle: .cancel) { [weak self] _ in
            self?.confirmCompleteBlock(block)
        }

        return [trackingButton, completeBlockButton]
    }

    private func updateWorkModeGPSIndicator(on template: CPInformationTemplate) {
        let isTracking = mileageTracker.isTracking && mileageTracker.currentBlockID == workModeBlockID
        let iconName = isTracking ? "location.fill" : "location.slash"
        let tintColor: UIColor = isTracking ? .systemBlue : .systemGray
        if let image = UIImage(systemName: iconName)?.withTintColor(tintColor, renderingMode: .alwaysOriginal) {
            let gpsIndicator = CPBarButton(image: image) { _ in }
            template.trailingNavigationBarButtons = [gpsIndicator]
        }
    }

    private func handleStopTracking(block: Block) {
        guard workModeBlockID == block.id else { return }
        if let (sessionMiles, routePoints) = mileageTracker.stopTracking(for: block.id) {
            let oldMiles = block.miles
            block.miles += Decimal(sessionMiles)
            block.appendRouteSegment(routePoints)
            block.recordAuditEntry(
                action: .milesUpdated,
                field: "miles",
                oldValue: auditDecimalString(oldMiles),
                newValue: auditDecimalString(block.miles),
                note: "Tracking paused via CarPlay"
            )
            block.updatedAt = Date()
            try? context.save()
            LiveActivityManager.shared.updateMiles(NSDecimalNumber(decimal: block.miles).doubleValue)
        }
        // Rebuild the work mode template to swap tracking button state
        rebuildWorkModeTemplate(for: block)
    }

    private func handleStartTracking(block: Block) {
        guard workModeBlockID == block.id else { return }
        mileageTracker.requestAuthorization()
        mileageTracker.startTracking(for: block.id)
        // Rebuild the work mode template to swap tracking button state
        rebuildWorkModeTemplate(for: block)
    }

    private func rebuildWorkModeTemplate(for block: Block) {
        guard let interfaceController else { return }
        let workTemplate = makeWorkModeTemplate(for: block)
        activeWorkModeTemplate = workTemplate
        interfaceController.setRootTemplate(workTemplate, animated: false, completion: nil)
    }

    private func makeWorkModeItems(for block: Block) -> [CPInformationItem] {
        let currentLiveMiles = liveMiles(for: block)
        let milesDetail = String(format: "%.2f mi (%@)", NSDecimalNumber(decimal: currentLiveMiles).doubleValue, formatCurrency(liveMileageDeduction(for: block)))
        let schedule = "\(timeFormatter.string(from: block.scheduledStartDate)) – \(timeFormatter.string(from: block.scheduledEndDate))"
        return [
            CPInformationItem(title: "Schedule", detail: schedule),
            CPInformationItem(title: "Gross", detail: formatCurrency(block.grossPayout)),
            CPInformationItem(title: "Miles", detail: milesDetail),
            CPInformationItem(title: "Expenses", detail: formatCurrency(block.additionalExpensesTotal)),
            CPInformationItem(title: "Profit", detail: formatCurrency(liveProfit(for: block)))
        ]
    }

    private func liveMiles(for block: Block) -> Decimal {
        if workModeBlockID == block.id || (mileageTracker.isTracking && mileageTracker.currentBlockID == block.id) {
            return block.miles + Decimal(mileageTracker.currentMiles)
        }
        return block.miles
    }

    private func liveMileageDeduction(for block: Block) -> Decimal {
        var miles = liveMiles(for: block)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &miles, 0, .plain)
        return rounded * block.irsRateSnapshot
    }

    private func liveProfit(for block: Block) -> Decimal {
        let mileageCost = block.shouldIncludeMileageDeduction ? liveMileageDeduction(for: block) : 0
        return block.grossPayout - mileageCost - block.effectiveExpensesDeduction
    }

    private func confirmCompleteBlock(_ block: Block) {
        guard let interfaceController else { return }
        let confirmAction = CPAlertAction(title: "Complete Block", style: .destructive) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            self?.stopBlock(block)
        }
        let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
        let alert = CPAlertTemplate(
            titleVariants: ["Stop GPS & complete this block?"],
            actions: [confirmAction, cancelAction]
        )
        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }

    private func stopBlock(_ block: Block) {
        guard workModeBlockID == block.id else { return }
        if let (sessionMiles, routePoints) = mileageTracker.stopTracking(for: block.id) {
            block.miles += Decimal(sessionMiles)
            block.appendRouteSegment(routePoints)
            block.recordAuditEntry(action: .milesUpdated, field: "miles", newValue: auditDecimalString(block.miles), note: "Captured via CarPlay")
        }
        LiveActivityManager.shared.endActivity(finalMiles: NSDecimalNumber(decimal: block.miles).doubleValue)
        block.recordAuditEntry(action: .updated, field: "userCompletionTime", newValue: auditDateString(Date()), note: "Completed via CarPlay")
        block.userCompletionTime = Date()
        block.status = .completed
        NotificationManager.shared.cancelNonTipReminders(for: block.id)
        block.recordAuditEntry(action: .statusChanged, field: "status", newValue: BlockStatus.completed.displayName)
        try? context.save()
        DispatchQueue.main.async {
            WorkModeCoordinator.shared.stopManually(block)
        }
        workModeBlockID = nil
        activeWorkModeTemplate = nil
        mapHost.clearRoute()
        isShowingActiveBlockDetail = false
        Task { await refreshInterface() }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

final class CarPlayMapHostViewController: UIViewController, MKMapViewDelegate {
    private let mapView = MKMapView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
        mapView.showsUserLocation = true
        view.addSubview(mapView)
    }

    func updateRoute(_ segments: [[RoutePoint]]) {
        mapView.removeOverlays(mapView.overlays)
        let polylines = segments.compactMap { segment -> MKPolyline? in
            guard segment.count > 1 else { return nil }
            let coords = segment.map { $0.coordinate }
            return MKPolyline(coordinates: coords, count: coords.count)
        }
        mapView.addOverlays(polylines)
        if let region = polylines.reduce(nil, { (current: MKMapRect?, polyline: MKPolyline) -> MKMapRect? in
            let rect = polyline.boundingMapRect
            return current.map { $0.union(rect) } ?? rect
        }) {
            mapView.setVisibleMapRect(region, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: true)
        }
    }

    func clearRoute() {
        mapView.removeOverlays(mapView.overlays)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineWidth = 5
            renderer.strokeColor = .systemBlue
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

// Objective-C compatibility shims for Info.plist class name variants
@objc(CarPlaySceneDelegate)
public final class CarPlaySceneDelegateObjCShim: CarPlaySceneDelegate {}

@objc(BlockErrnCarPlaySceneDelegate)
public final class BlockErrnCarPlaySceneDelegateObjCShim: CarPlaySceneDelegate {}
#endif
