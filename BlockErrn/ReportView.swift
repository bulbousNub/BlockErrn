import SwiftUI
import SwiftData
import PDFKit

// MARK: - Report Configuration

enum ReportSection: String, CaseIterable, Identifiable {
    case summary
    case earningsBreakdown
    case blockLog
    case expenseBreakdown
    case mileageDeductions
    case tipsBreakdown
    case efficiencyMetrics

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .summary: return "Summary Overview"
        case .earningsBreakdown: return "Earnings Breakdown"
        case .blockLog: return "Block Log"
        case .expenseBreakdown: return "Expense Breakdown"
        case .mileageDeductions: return "Mileage & Deductions"
        case .tipsBreakdown: return "Tips Breakdown"
        case .efficiencyMetrics: return "Efficiency Metrics"
        }
    }

    var icon: String {
        switch self {
        case .summary: return "chart.pie"
        case .earningsBreakdown: return "dollarsign.circle"
        case .blockLog: return "list.bullet.rectangle"
        case .expenseBreakdown: return "cart"
        case .mileageDeductions: return "car"
        case .tipsBreakdown: return "giftcard"
        case .efficiencyMetrics: return "gauge.with.dots.needle.67percent"
        }
    }
}

enum ReportDateFilter: String, CaseIterable, Identifiable {
    case allTime
    case thisWeek
    case thisMonth
    case last30Days
    case last90Days
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allTime: return "All Time"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .custom: return "Custom Range"
        }
    }
}

enum ReportStatusFilter: String, CaseIterable, Identifiable {
    case all
    case completed
    case accepted
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All Statuses"
        case .completed: return "Completed"
        case .accepted: return "Accepted"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - ReportView

struct ReportView: View {
    @Query private var blocks: [Block]
    @State private var selectedSections: Set<ReportSection> = Set(ReportSection.allCases)
    @State private var dateFilter: ReportDateFilter = .allTime
    @State private var statusFilter: ReportStatusFilter = .completed
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var showPDFPreview: Bool = false
    @State private var generatedPDFData: Data?
    @State private var isGenerating: Bool = false

    private var filteredBlocks: [Block] {
        let calendar = Calendar.current
        let now = Date()

        var result = blocks

        // Status filter
        switch statusFilter {
        case .all: break
        case .completed: result = result.filter { $0.status == .completed }
        case .accepted: result = result.filter { $0.status == .accepted }
        case .cancelled: result = result.filter { $0.status == .cancelled }
        }

        // Date filter
        switch dateFilter {
        case .allTime: break
        case .thisWeek:
            let startOfWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            if let weekStart = calendar.date(from: startOfWeek) {
                result = result.filter { $0.date >= weekStart }
            }
        case .thisMonth:
            let startOfMonth = calendar.dateComponents([.year, .month], from: now)
            if let monthStart = calendar.date(from: startOfMonth) {
                result = result.filter { $0.date >= monthStart }
            }
        case .last30Days:
            let cutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            result = result.filter { $0.date >= cutoff }
        case .last90Days:
            let cutoff = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            result = result.filter { $0.date >= cutoff }
        case .custom:
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate)) ?? customEndDate
            result = result.filter { $0.date >= start && $0.date < end }
        }

        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard
                    dateFilterCard
                    statusFilterCard
                    sectionsCard
                    generateButton
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Generate Report")
        .sheet(isPresented: $showPDFPreview) {
            if let data = generatedPDFData {
                PDFPreviewView(pdfData: data)
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Earnings Report")
                        .font(.title2)
                        .bold()
                    Text("Generate a branded PDF report of your earnings data. Choose which sections to include, filter by date range and status, then preview and share.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "doc.richtext")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(filteredBlocks.count) blocks match your current filters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .blockErrnCardStyle()
    }

    // MARK: - Date Filter

    private var dateFilterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Range")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ReportDateFilter.allCases) { filter in
                    Button {
                        dateFilter = filter
                    } label: {
                        Text(filter.displayName)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(dateFilter == filter ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(dateFilter == filter ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if dateFilter == .custom {
                HStack {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Start")
                            .font(.subheadline)
                        Text("End")
                            .font(.subheadline)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        DatePicker("", selection: $customStartDate, displayedComponents: .date)
                            .labelsHidden()
                        DatePicker("", selection: $customEndDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .padding(.top, 4)
            }
        }
        .blockErrnCardStyle()
    }

    // MARK: - Status Filter

    private var statusFilterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Block Status")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(ReportStatusFilter.allCases) { filter in
                    Button {
                        statusFilter = filter
                    } label: {
                        Text(filter.displayName)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(statusFilter == filter ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(statusFilter == filter ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .blockErrnCardStyle()
    }

    // MARK: - Section Toggles

    private var sectionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Report Sections")
                    .font(.headline)
                Spacer()
                Button(selectedSections.count == ReportSection.allCases.count ? "Deselect All" : "Select All") {
                    if selectedSections.count == ReportSection.allCases.count {
                        selectedSections.removeAll()
                    } else {
                        selectedSections = Set(ReportSection.allCases)
                    }
                }
                .font(.caption)
            }

            ForEach(ReportSection.allCases) { section in
                Toggle(isOn: Binding(
                    get: { selectedSections.contains(section) },
                    set: { isOn in
                        if isOn {
                            selectedSections.insert(section)
                        } else {
                            selectedSections.remove(section)
                        }
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: section.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                        Text(section.displayName)
                            .font(.subheadline)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            }
        }
        .blockErrnCardStyle()
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        VStack(spacing: 12) {
            Button {
                generateReport()
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    }
                    Label(isGenerating ? "Generating..." : "Generate PDF Report", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.accentColor)
            .disabled(filteredBlocks.isEmpty || selectedSections.isEmpty || isGenerating)

            if filteredBlocks.isEmpty {
                Text("No blocks match your current filters. Adjust the date range or status filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if selectedSections.isEmpty {
                Text("Select at least one report section to generate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Generate

    private func generateReport() {
        isGenerating = true
        let blocksSnapshot = filteredBlocks
        let sectionsSnapshot = selectedSections
        let dateFilterSnapshot = dateFilter
        let customStart = customStartDate
        let customEnd = customEndDate
        let statusFilterSnapshot = statusFilter

        DispatchQueue.global(qos: .userInitiated).async {
            let renderer = BlockErrnPDFRenderer(
                blocks: blocksSnapshot,
                sections: sectionsSnapshot,
                dateFilter: dateFilterSnapshot,
                statusFilter: statusFilterSnapshot,
                customStartDate: customStart,
                customEndDate: customEnd
            )
            let data = renderer.render()

            DispatchQueue.main.async {
                generatedPDFData = data
                isGenerating = false
                showPDFPreview = true
            }
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: View {
    let pdfData: Data
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet: Bool = false

    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Report Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    let tempURL = writeTempPDF()
                    PDFActivityView(activityItems: [tempURL as Any])
                }
        }
    }

    private func writeTempPDF() -> URL {
        let timestamp = reportTimestampFormatter.string(from: Date())
        let filename = "BlockErrn-Report-\(timestamp).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? pdfData.write(to: url)
        return url
    }
}

private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil {
            pdfView.document = PDFDocument(data: data)
        }
    }
}

private struct PDFActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private let reportTimestampFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyyMMdd-HHmmss"
    return f
}()

// MARK: - PDF Renderer

final class BlockErrnPDFRenderer {
    private let blocks: [Block]
    private let sections: Set<ReportSection>
    private let dateFilter: ReportDateFilter
    private let statusFilter: ReportStatusFilter
    private let customStartDate: Date
    private let customEndDate: Date

    // Page geometry
    private let pageWidth: CGFloat = 612   // US Letter
    private let pageHeight: CGFloat = 792
    private let marginLeft: CGFloat = 50
    private let marginRight: CGFloat = 50
    private let marginTop: CGFloat = 60
    private let marginBottom: CGFloat = 60
    private var contentWidth: CGFloat { pageWidth - marginLeft - marginRight }
    private var maxY: CGFloat { pageHeight - marginBottom }

    // Theme colors (from BlockErrnTheme)
    private let brandNavy = UIColor(red: 0.12, green: 0.22, blue: 0.48, alpha: 1.0)
    private let brandBlue = UIColor(red: 0.0, green: 0.40, blue: 0.64, alpha: 1.0)
    private let brandLight = UIColor(red: 0.28, green: 0.45, blue: 0.78, alpha: 1.0)
    private let accentGreen = UIColor.systemGreen
    private let textPrimary = UIColor.black
    private let textSecondary = UIColor.darkGray
    private let textMuted = UIColor.gray
    private let dividerColor = UIColor(white: 0.85, alpha: 1.0)
    private let rowAltColor = UIColor(white: 0.96, alpha: 1.0)

    // Fonts
    private let titleFont = UIFont.systemFont(ofSize: 26, weight: .bold)
    private let subtitleFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    private let sectionHeaderFont = UIFont.systemFont(ofSize: 18, weight: .bold)
    private let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
    private let bodyBoldFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
    private let captionFont = UIFont.systemFont(ofSize: 9, weight: .regular)
    private let tableHeaderFont = UIFont.systemFont(ofSize: 9, weight: .bold)

    // State
    private var currentY: CGFloat = 0
    private var pageNumber: Int = 0
    private var context: UIGraphicsPDFRendererContext?

    init(blocks: [Block], sections: Set<ReportSection>, dateFilter: ReportDateFilter, statusFilter: ReportStatusFilter, customStartDate: Date, customEndDate: Date) {
        self.blocks = blocks
        self.sections = sections
        self.dateFilter = dateFilter
        self.statusFilter = statusFilter
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
    }

    func render() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        return renderer.pdfData { ctx in
            self.context = ctx
            beginNewPage()
            drawCoverHeader()

            let orderedSections: [ReportSection] = [
                .summary, .earningsBreakdown, .blockLog,
                .expenseBreakdown, .mileageDeductions, .tipsBreakdown,
                .efficiencyMetrics
            ]

            for section in orderedSections {
                guard sections.contains(section) else { continue }
                ensureSpace(120)
                switch section {
                case .summary: drawSummarySection()
                case .earningsBreakdown: drawEarningsBreakdown()
                case .blockLog: drawBlockLog()
                case .expenseBreakdown: drawExpenseBreakdown()
                case .mileageDeductions: drawMileageSection()
                case .tipsBreakdown: drawTipsBreakdown()
                case .efficiencyMetrics: drawEfficiencyMetrics()
                }
            }

            drawFooter()
        }
    }

    // MARK: - Page Management

    private func beginNewPage() {
        let pageBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        context?.beginPage(withBounds: pageBounds, pageInfo: [:])
        pageNumber += 1
        currentY = marginTop

        // Draw subtle header line on non-first pages
        if pageNumber > 1 {
            drawTopBanner(compact: true)
        }
    }

    private func ensureSpace(_ needed: CGFloat) {
        if currentY + needed > maxY {
            drawFooter()
            beginNewPage()
        }
    }

    // MARK: - Cover / Header

    private func drawCoverHeader() {
        // Gradient banner
        let bannerHeight: CGFloat = 100
        let bannerRect = CGRect(x: 0, y: 0, width: pageWidth, height: bannerHeight)
        let cgContext = UIGraphicsGetCurrentContext()!

        let colors = [brandNavy.cgColor, brandBlue.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
        cgContext.saveGState()
        cgContext.addRect(bannerRect)
        cgContext.clip()
        cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: pageWidth, y: bannerHeight), options: [])
        cgContext.restoreGState()

        // Title text on banner
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.white
        ]
        let title = "BlockErrn Earnings Report"
        title.draw(at: CGPoint(x: marginLeft, y: 28), withAttributes: titleAttrs)

        // Subtitle on banner
        let dateRangeText = dateRangeDescription()
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        dateRangeText.draw(at: CGPoint(x: marginLeft, y: 60), withAttributes: subAttrs)

        // Block count on banner right side
        let countText = "\(blocks.count) blocks"
        let countAttrs: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let countSize = countText.size(withAttributes: countAttrs)
        countText.draw(at: CGPoint(x: pageWidth - marginRight - countSize.width, y: 60), withAttributes: countAttrs)

        currentY = bannerHeight + 20

        // Generated date
        let genDateStr = "Generated \(reportDateFormatter.string(from: Date()))"
        let genAttrs: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: textMuted
        ]
        genDateStr.draw(at: CGPoint(x: marginLeft, y: currentY), withAttributes: genAttrs)
        currentY += 20
        drawDivider()
        currentY += 10
    }

    private func drawTopBanner(compact: Bool) {
        let bannerHeight: CGFloat = 30
        let bannerRect = CGRect(x: 0, y: 0, width: pageWidth, height: bannerHeight)
        let cgContext = UIGraphicsGetCurrentContext()!

        let colors = [brandNavy.cgColor, brandBlue.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
        cgContext.saveGState()
        cgContext.addRect(bannerRect)
        cgContext.clip()
        cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: pageWidth, y: bannerHeight), options: [])
        cgContext.restoreGState()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        "BlockErrn Earnings Report".draw(at: CGPoint(x: marginLeft, y: 8), withAttributes: attrs)

        let pageStr = "Page \(pageNumber)"
        let pageSize = pageStr.size(withAttributes: attrs)
        pageStr.draw(at: CGPoint(x: pageWidth - marginRight - pageSize.width, y: 8), withAttributes: attrs)

        currentY = bannerHeight + 15
    }

    // MARK: - Footer

    private func drawFooter() {
        let footerY = pageHeight - 35
        drawLine(y: footerY - 5)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: textMuted
        ]

        let leftText = "BlockErrn — blockerrn.com"
        leftText.draw(at: CGPoint(x: marginLeft, y: footerY), withAttributes: attrs)

        let rightText = "Page \(pageNumber)"
        let rightSize = rightText.size(withAttributes: attrs)
        rightText.draw(at: CGPoint(x: pageWidth - marginRight - rightSize.width, y: footerY), withAttributes: attrs)
    }

    // MARK: - Summary Section

    private func drawSummarySection() {
        drawSectionHeader("Summary Overview")

        let totalGross = blocks.reduce(Decimal(0)) { $0 + $1.grossPayout }
        let totalTips = blocks.reduce(Decimal(0)) { $0 + ($1.tipsAmount ?? 0) }
        let totalProfit = blocks.reduce(Decimal(0)) { $0 + $1.totalProfit }
        let totalMiles = blocks.reduce(Decimal(0)) { $0 + $1.roundedMiles }
        let totalExpenses = blocks.reduce(Decimal(0)) { $0 + $1.additionalExpensesTotal }
        let totalMileageDed = blocks.reduce(Decimal(0)) { $0 + $1.mileageDeduction }
        let totalMinutes = blocks.reduce(0) { $0 + $1.durationMinutes }
        let totalHours = Decimal(totalMinutes) / 60
        let grossPerHour: Decimal = totalHours > 0 ? totalGross / totalHours : 0
        let profitPerHour: Decimal = totalHours > 0 ? totalProfit / totalHours : 0

        // Summary stat boxes (2 columns, 4 rows)
        let statBoxWidth = (contentWidth - 20) / 2
        let statBoxHeight: CGFloat = 50

        let stats: [(label: String, value: String)] = [
            ("Total Gross", formatCurrency(totalGross)),
            ("Total Tips", formatCurrency(totalTips)),
            ("Total Profit", formatCurrency(totalProfit)),
            ("Total Hours", formatHours(totalHours)),
            ("Gross $/hr", formatCurrency(grossPerHour)),
            ("Profit $/hr", formatCurrency(profitPerHour)),
            ("Total Miles", formatMiles(totalMiles)),
            ("Blocks", "\(blocks.count)"),
            ("Mileage Deduction", formatCurrency(totalMileageDed)),
            ("Total Expenses", formatCurrency(totalExpenses))
        ]

        for i in stride(from: 0, to: stats.count, by: 2) {
            ensureSpace(statBoxHeight + 10)
            let y = currentY
            drawStatBox(x: marginLeft, y: y, width: statBoxWidth, height: statBoxHeight, label: stats[i].label, value: stats[i].value)
            if i + 1 < stats.count {
                drawStatBox(x: marginLeft + statBoxWidth + 20, y: y, width: statBoxWidth, height: statBoxHeight, label: stats[i + 1].label, value: stats[i + 1].value)
            }
            currentY = y + statBoxHeight + 8
        }

        currentY += 10
    }

    private func drawStatBox(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, label: String, value: String) {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let cgContext = UIGraphicsGetCurrentContext()!

        // Background
        cgContext.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        UIColor(white: 0.95, alpha: 1.0).setFill()
        path.fill()

        // Left accent bar
        let accentRect = CGRect(x: x, y: y, width: 4, height: height)
        let accentPath = UIBezierPath(roundedRect: accentRect, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 8, height: 8))
        brandBlue.setFill()
        accentPath.fill()
        cgContext.restoreGState()

        // Label
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: textSecondary
        ]
        label.draw(at: CGPoint(x: x + 14, y: y + 8), withAttributes: labelAttrs)

        // Value
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: textPrimary
        ]
        value.draw(at: CGPoint(x: x + 14, y: y + 24), withAttributes: valueAttrs)
    }

    // MARK: - Earnings Breakdown

    private func drawEarningsBreakdown() {
        drawSectionHeader("Earnings Breakdown")

        let totalGross = blocks.reduce(Decimal(0)) { $0 + $1.grossPayout }
        let totalBase = blocks.reduce(Decimal(0)) { $0 + $1.grossBase }
        let totalTips = blocks.reduce(Decimal(0)) { $0 + ($1.tipsAmount ?? 0) }
        let totalExpenses = blocks.reduce(Decimal(0)) { $0 + $1.additionalExpensesTotal }
        let totalMileageDed = blocks.reduce(Decimal(0)) { $0 + $1.mileageDeduction }
        let totalProfit = blocks.reduce(Decimal(0)) { $0 + $1.totalProfit }

        let rows: [(String, String)] = [
            ("Base Pay", formatCurrency(totalBase)),
            ("Tips", formatCurrency(totalTips)),
            ("Gross Earnings", formatCurrency(totalGross)),
            ("", ""),
            ("Mileage Deduction", "- " + formatCurrency(totalMileageDed)),
            ("Expenses", "- " + formatCurrency(totalExpenses)),
            ("", ""),
            ("Net Profit", formatCurrency(totalProfit))
        ]

        for (i, row) in rows.enumerated() {
            if row.0.isEmpty {
                ensureSpace(12)
                drawDivider()
                currentY += 6
                continue
            }
            ensureSpace(18)
            let isTotal = row.0 == "Gross Earnings" || row.0 == "Net Profit"
            let font = isTotal ? bodyBoldFont : bodyFont
            let color = isTotal ? textPrimary : textSecondary

            let labelAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            row.0.draw(at: CGPoint(x: marginLeft + 10, y: currentY), withAttributes: labelAttrs)

            let valueSize = row.1.size(withAttributes: labelAttrs)
            row.1.draw(at: CGPoint(x: pageWidth - marginRight - valueSize.width - 10, y: currentY), withAttributes: labelAttrs)

            currentY += 18
            if isTotal && i < rows.count - 1 {
                currentY += 2
            }
        }

        currentY += 15
    }

    // MARK: - Block Log

    private func drawBlockLog() {
        drawSectionHeader("Block Log")

        // Table header
        let columns: [(String, CGFloat)] = [
            ("Date", 76),
            ("Duration", 54),
            ("Gross", 64),
            ("Tips", 54),
            ("Miles", 48),
            ("Expenses", 66),
            ("Profit", 66),
            ("Status", 84)
        ]

        ensureSpace(30)
        drawTableHeader(columns: columns)

        for (index, block) in blocks.enumerated() {
            ensureSpace(20)

            let y = currentY
            if index % 2 == 1 {
                let rowRect = CGRect(x: marginLeft, y: y - 2, width: contentWidth, height: 18)
                rowAltColor.setFill()
                UIBezierPath(rect: rowRect).fill()
            }

            let values: [String] = [
                shortDateFormatter.string(from: block.date),
                "\(block.durationMinutes)m",
                formatCurrency(block.grossPayout),
                formatCurrency(block.tipsAmount ?? 0),
                "\(NSDecimalNumber(decimal: block.roundedMiles).intValue)",
                formatCurrency(block.additionalExpensesTotal),
                formatCurrency(block.totalProfit),
                block.status.displayName
            ]

            var x = marginLeft + 5
            for (colIdx, col) in columns.enumerated() {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: textPrimary
                ]
                let text = values[colIdx]
                let constrainedRect = CGRect(x: x, y: y, width: col.1 - 5, height: 16)
                text.draw(in: constrainedRect, withAttributes: attrs)
                x += col.1
            }

            currentY += 18
        }

        currentY += 15
    }

    private func drawTableHeader(columns: [(String, CGFloat)]) {
        let headerRect = CGRect(x: marginLeft, y: currentY - 2, width: contentWidth, height: 18)
        brandNavy.setFill()
        UIBezierPath(roundedRect: headerRect, cornerRadius: 4).fill()

        var x = marginLeft + 5
        for col in columns {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: tableHeaderFont,
                .foregroundColor: UIColor.white
            ]
            col.0.draw(at: CGPoint(x: x, y: currentY), withAttributes: attrs)
            x += col.1
        }

        currentY += 20
    }

    // MARK: - Expense Breakdown

    private func drawExpenseBreakdown() {
        drawSectionHeader("Expense Breakdown")

        var categoryTotals: [String: Decimal] = [:]
        for block in blocks {
            for expense in block.expenses {
                let name = ExpenseCategory(rawValue: expense.categoryRaw)?.displayName ?? expense.categoryRaw
                categoryTotals[name, default: 0] += expense.amount
            }
        }

        if categoryTotals.isEmpty {
            drawInfoText("No expenses recorded in the selected blocks.")
            return
        }

        let sorted = categoryTotals.sorted { $0.value > $1.value }
        let grandTotal = sorted.reduce(Decimal(0)) { $0 + $1.value }

        // Bar chart representation
        let barMaxWidth = contentWidth - 160
        for item in sorted {
            ensureSpace(28)
            let fraction = grandTotal > 0 ? CGFloat(NSDecimalNumber(decimal: item.value / grandTotal).doubleValue) : 0
            let barWidth = max(4, barMaxWidth * fraction)
            let pctString = String(format: "%.1f%%", fraction * 100)

            let labelAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: textPrimary]
            item.key.draw(at: CGPoint(x: marginLeft + 10, y: currentY), withAttributes: labelAttrs)

            // Bar
            let barRect = CGRect(x: marginLeft + 110, y: currentY + 2, width: barWidth, height: 12)
            brandLight.setFill()
            UIBezierPath(roundedRect: barRect, cornerRadius: 3).fill()

            // Value + %
            let valueStr = "\(formatCurrency(item.value))  \(pctString)"
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: textSecondary]
            valueStr.draw(at: CGPoint(x: marginLeft + 115 + barWidth, y: currentY + 2), withAttributes: valueAttrs)

            currentY += 24
        }

        ensureSpace(20)
        drawDivider()
        currentY += 6
        let totalAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: textPrimary]
        "Total Expenses".draw(at: CGPoint(x: marginLeft + 10, y: currentY), withAttributes: totalAttrs)
        let totalStr = formatCurrency(grandTotal)
        let totalSize = totalStr.size(withAttributes: totalAttrs)
        totalStr.draw(at: CGPoint(x: pageWidth - marginRight - totalSize.width - 10, y: currentY), withAttributes: totalAttrs)
        currentY += 25
    }

    // MARK: - Mileage & Deductions

    private func drawMileageSection() {
        drawSectionHeader("Mileage & Deductions")

        let totalMiles = blocks.reduce(Decimal(0)) { $0 + $1.roundedMiles }
        let totalDed = blocks.reduce(Decimal(0)) { $0 + $1.mileageDeduction }
        let avgMiles: Decimal = blocks.isEmpty ? 0 : totalMiles / Decimal(blocks.count)
        let irsRate = blocks.first?.irsRateSnapshot ?? Decimal(0.70)

        let rows: [(String, String)] = [
            ("Total Miles Driven", formatMiles(totalMiles)),
            ("Average Miles per Block", formatMiles(avgMiles)),
            ("IRS Mileage Rate", formatCurrency(irsRate) + "/mi"),
            ("Total Mileage Deduction", formatCurrency(totalDed))
        ]

        for row in rows {
            ensureSpace(20)
            let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: textPrimary]
            row.0.draw(at: CGPoint(x: marginLeft + 10, y: currentY), withAttributes: attrs)
            let valSize = row.1.size(withAttributes: attrs)
            row.1.draw(at: CGPoint(x: pageWidth - marginRight - valSize.width - 10, y: currentY), withAttributes: attrs)
            currentY += 20
        }

        currentY += 15
    }

    // MARK: - Tips Breakdown

    private func drawTipsBreakdown() {
        drawSectionHeader("Tips Breakdown")

        let blocksWithTips = blocks.filter { ($0.tipsAmount ?? 0) > 0 }
        let totalTips = blocks.reduce(Decimal(0)) { $0 + ($1.tipsAmount ?? 0) }
        let totalGross = blocks.reduce(Decimal(0)) { $0 + $1.grossPayout }
        let tipPercent: Decimal = totalGross > 0 ? totalTips / totalGross * 100 : 0
        let avgTip: Decimal = blocksWithTips.isEmpty ? 0 : totalTips / Decimal(blocksWithTips.count)
        let maxTip = blocks.compactMap(\.tipsAmount).max() ?? 0

        let rows: [(String, String)] = [
            ("Total Tips Earned", formatCurrency(totalTips)),
            ("Blocks with Tips", "\(blocksWithTips.count) of \(blocks.count)"),
            ("Average Tip (tipped blocks)", formatCurrency(avgTip)),
            ("Highest Tip", formatCurrency(maxTip)),
            ("Tips as % of Gross", String(format: "%.1f%%", NSDecimalNumber(decimal: tipPercent).doubleValue))
        ]

        for row in rows {
            ensureSpace(20)
            let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: textPrimary]
            row.0.draw(at: CGPoint(x: marginLeft + 10, y: currentY), withAttributes: attrs)
            let valSize = row.1.size(withAttributes: attrs)
            row.1.draw(at: CGPoint(x: pageWidth - marginRight - valSize.width - 10, y: currentY), withAttributes: attrs)
            currentY += 20
        }

        currentY += 15
    }

    // MARK: - Efficiency Metrics

    private func drawEfficiencyMetrics() {
        drawSectionHeader("Efficiency Metrics")

        let totalMiles = blocks.reduce(Decimal(0)) { $0 + $1.roundedMiles }
        let totalProfit = blocks.reduce(Decimal(0)) { $0 + $1.totalProfit }
        let totalPkgs = blocks.compactMap(\.packageCount).reduce(0, +)
        let totalStops = blocks.compactMap(\.stopCount).reduce(0, +)
        let totalScheduledMin = blocks.reduce(0) { $0 + $1.durationMinutes }
        let totalActualMin = blocks.reduce(0) { total, block in
            guard let s = block.userStartTime, let e = block.userCompletionTime else { return total }
            return total + max(0, Int(e.timeIntervalSince(s) / 60))
        }
        let actualHrs = Decimal(totalActualMin) / 60
        let scheduledHrs = Decimal(totalScheduledMin) / 60

        var rows: [(String, String)] = []

        if totalMiles > 0 {
            rows.append(("Profit per Mile", formatCurrency(totalProfit / totalMiles)))
        }
        if !blocks.isEmpty {
            rows.append(("Miles per Block", formatMiles(totalMiles / Decimal(blocks.count))))
        }
        if actualHrs > 0 && totalPkgs > 0 {
            let pkgsHr = Decimal(totalPkgs) / actualHrs
            rows.append(("Packages per Hour", String(format: "%.1f", NSDecimalNumber(decimal: pkgsHr).doubleValue)))
        }
        if actualHrs > 0 && totalStops > 0 {
            let stopsHr = Decimal(totalStops) / actualHrs
            rows.append(("Stops per Hour", String(format: "%.1f", NSDecimalNumber(decimal: stopsHr).doubleValue)))
        }

        rows.append(("Total Packages", "\(totalPkgs)"))
        rows.append(("Total Stops", "\(totalStops)"))

        if totalActualMin > 0 {
            rows.append(("Scheduled Hours", formatHours(scheduledHrs)))
            rows.append(("Actual Worked Hours", formatHours(actualHrs)))
            let diff = actualHrs - scheduledHrs
            let diffStr = String(format: "%+.1fh", NSDecimalNumber(decimal: diff).doubleValue)
            rows.append(("Schedule Difference", diffStr))
        }

        if rows.isEmpty {
            drawInfoText("Not enough data to calculate efficiency metrics.")
            return
        }

        for row in rows {
            ensureSpace(20)
            let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: textPrimary]
            row.0.draw(at: CGPoint(x: marginLeft + 10, y: currentY), withAttributes: attrs)
            let valSize = row.1.size(withAttributes: attrs)
            row.1.draw(at: CGPoint(x: pageWidth - marginRight - valSize.width - 10, y: currentY), withAttributes: attrs)
            currentY += 20
        }

        currentY += 15
    }

    // MARK: - Drawing Helpers

    private func drawSectionHeader(_ title: String) {
        ensureSpace(40)

        // Accent line
        let accentRect = CGRect(x: marginLeft, y: currentY, width: 40, height: 3)
        brandBlue.setFill()
        UIBezierPath(roundedRect: accentRect, cornerRadius: 1.5).fill()
        currentY += 8

        let attrs: [NSAttributedString.Key: Any] = [
            .font: sectionHeaderFont,
            .foregroundColor: brandNavy
        ]
        title.draw(at: CGPoint(x: marginLeft, y: currentY), withAttributes: attrs)
        currentY += 28
    }

    private func drawDivider() {
        drawLine(y: currentY)
        currentY += 1
    }

    private func drawLine(y: CGFloat) {
        let cgContext = UIGraphicsGetCurrentContext()!
        cgContext.saveGState()
        cgContext.setStrokeColor(dividerColor.cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: marginLeft, y: y))
        cgContext.addLine(to: CGPoint(x: pageWidth - marginRight, y: y))
        cgContext.strokePath()
        cgContext.restoreGState()
    }

    private func drawInfoText(_ text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: textMuted
        ]
        text.draw(at: CGPoint(x: marginLeft + 10, y: currentY), withAttributes: attrs)
        currentY += 20
    }

    // MARK: - Formatters

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private func formatMiles(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return "\(formatter.string(from: value as NSDecimalNumber) ?? "0") mi"
    }

    private func formatHours(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return "\(formatter.string(from: value as NSDecimalNumber) ?? "0")h"
    }

    private func dateRangeDescription() -> String {
        switch dateFilter {
        case .allTime: return "All Time • \(statusFilter.displayName)"
        case .thisWeek: return "This Week • \(statusFilter.displayName)"
        case .thisMonth: return "This Month • \(statusFilter.displayName)"
        case .last30Days: return "Last 30 Days • \(statusFilter.displayName)"
        case .last90Days: return "Last 90 Days • \(statusFilter.displayName)"
        case .custom:
            let start = shortDateFormatter.string(from: customStartDate)
            let end = shortDateFormatter.string(from: customEndDate)
            return "\(start) – \(end) • \(statusFilter.displayName)"
        }
    }
}

private let reportDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .long
    f.timeStyle = .short
    return f
}()

private let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MM/dd/yy"
    return f
}()
