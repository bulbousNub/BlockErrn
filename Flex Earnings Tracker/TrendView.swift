import SwiftUI
import SwiftData
import Charts

struct TrendView: View {
    @Query private var blocks: [Block]
    @State private var refreshCounter: Int = 0

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            ZStack {
                BlockErrnTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    if blocks.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            earningsAndMileageCard

                            TrendSectionCard(title: "Weekly trends") {
                                grossCharts
                            }

                        TrendPreviewCard(title: "Recent Weeks", stats: weeklyStats, frequency: .week, limit: 3)
                        TrendPreviewCard(title: "Recent Months", stats: monthlyStats, frequency: .month, limit: 3)
                    }
                        .padding()
                        .padding(.bottom, 32)
                    }
                }
                .refreshable {
                    refreshStats()
                }
            }
            .navigationTitle("Trends")
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 80))
                    .foregroundStyle(colorScheme == .light ? .black : .white)
                Text("No Trends Yet")
                    .font(.title2)
                    .bold()
                    .foregroundColor(colorScheme == .light ? .black : .white)
                Text("Accept your first block and track mileage to populate this page with earnings, tips, and upcoming blocks.")
                    .font(.body)
                    .foregroundColor(colorScheme == .light ? .black : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height * 0.65)
    }

    @State private var highlightedWeek: PeriodStats? = nil
    @State private var highlightedMonth: PeriodStats? = nil

    private var header: some View {
        HStack(alignment: .top) {
            Text("Earnings & Mileage")
                .font(.title2)
                .bold()
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(upcomingBlocksCount) Upcoming Blocks")
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("\(blocks.count) Total Blocks Tracked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var earningsAndMileageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
        metricGrid
        }
        .flexErrnCardStyle()
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(minimum: 140), spacing: 12), GridItem(.flexible(minimum: 140), spacing: 12)], spacing: 12) {
            weeklyMetricCards
            monthlyMetricCards
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var weeklyMetricCards: some View {
        if let latestWeekly = latestCompletedWeeklyStat {
            MetricCard(title: "$ Earned\nThis Week", value: formatCurrency(latestWeekly.grossTotal), caption: "Latest gross")
            MetricCard(title: "Miles Driven This Week", value: formatMiles(latestWeekly.totalMiles), caption: "All blocks")
        }
    }

    @ViewBuilder
    private var monthlyMetricCards: some View {
        if let latestMonthly = latestCompletedMonthlyStat {
            MetricCard(title: "$ Earned\nThis Month", value: formatCurrency(latestMonthly.grossTotal), caption: "Latest gross")
            MetricCard(title: "Miles Driven This Month", value: formatMiles(latestMonthly.totalMiles), caption: "All blocks")
        }
    }

    @ViewBuilder

    private var grossCharts: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gross per week")
                .font(.headline)
            weeklyChart
            ChartCallout(stat: highlightedWeek ?? weeklyChartData.first)

            Text("Gross per month")
                .font(.headline)
            monthlyChart
            ChartCallout(stat: highlightedMonth ?? monthlyChartData.first)
        }
    }

    private var weeklyChart: some View {
        Chart {
            ForEach(weeklyChartData) { stat in
                LineMark(x: .value("Week", stat.start), y: .value("Gross", stat.grossTotal.doubleValue))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
                PointMark(x: .value("Week", stat.start), y: .value("Gross", stat.grossTotal.doubleValue))
                    .foregroundStyle(.blue)
            }
        }
        .chartXAxis {
            AxisMarks(values: weeklyChartData.map(\.start)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(weekLabelFormatter.string(from: date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let double = value.as(Double.self) {
                        Text(formatCurrencyDecimal(Decimal(double)))
                    }
                }
            }
        }
        .chartYScale(domain: 0...(monthlyGrossMax * Decimal(1.1)))
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                if let date: Date = proxy.value(atX: gesture.location.x, as: Date.self) {
                                    highlightedWeek = nearestWeeklyStat(to: date)
                                }
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { highlightedWeek = nil }
                            }
                    )
            }
        }
        .frame(height: 180)
    }

    private var monthlyChart: some View {
        Chart {
            ForEach(monthlyChartData) { stat in
                BarMark(
                    x: .value("Month", stat.start),
                    y: .value("Gross", stat.grossTotal.doubleValue)
                )
                .foregroundStyle(.green)
            }
        }
        .chartXAxis {
            AxisMarks(values: monthlyChartData.map(\.start)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabelFormatter.string(from: date))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                    }
                }
            }
        }
        .chartXScale(domain: monthlyDateDomain ?? fallbackMonthlyDateDomain)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let double = value.as(Double.self) {
                        Text(formatCurrencyDecimal(Decimal(double)))
                    }
                }
            }
        }
        .chartPlotStyle { content in
            content.padding(.horizontal, 12)
        }
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                if let date: Date = proxy.value(atX: gesture.location.x, as: Date.self) {
                                    highlightedMonth = nearestMonthlyStat(to: date)
                                }
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { highlightedMonth = nil }
                            }
                    )
            }
        }
        .frame(height: 180)
    }

    private func formatCurrencyDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func nearestWeeklyStat(to date: Date) -> PeriodStats? {
        weeklyChartData.min(by: {
            abs($0.start.timeIntervalSince1970 - date.timeIntervalSince1970)
                < abs($1.start.timeIntervalSince1970 - date.timeIntervalSince1970)
        })
    }

    private func nearestMonthlyStat(to date: Date) -> PeriodStats? {
        monthlyChartData.min(by: {
            abs($0.start.timeIntervalSince1970 - date.timeIntervalSince1970)
                < abs($1.start.timeIntervalSince1970 - date.timeIntervalSince1970)
        })
    }

    private var weeklyStats: [PeriodStats] {
        periodStats(for: .week)
    }

    private var monthlyStats: [PeriodStats] {
        periodStats(for: .month)
    }

    private var weeklyChartData: [PeriodStats] {
        Array(completedWeeklyStats.prefix(8)).reversed()
    }

    private var monthlyChartData: [PeriodStats] {
        Array(completedMonthlyStats.prefix(8)).reversed()
    }

    private var completedWeeklyStats: [PeriodStats] {
        let today = calendar.startOfDay(for: Date())
        return weeklyStats.filter {
            calendar.startOfDay(for: $0.start) <= today
        }
    }

    private var completedMonthlyStats: [PeriodStats] {
        let today = calendar.startOfDay(for: Date())
        return monthlyStats.filter {
            calendar.startOfDay(for: $0.start) <= today
        }
    }

    private var latestCompletedWeeklyStat: PeriodStats? {
        completedWeeklyStats.first
    }

    private var latestCompletedMonthlyStat: PeriodStats? {
        completedMonthlyStats.first
    }

    private var monthlyGrossMax: Decimal {
        monthlyChartData.map(\.grossTotal).max() ?? 0
    }

    private var monthlyDateDomain: ClosedRange<Date>? {
        guard
            let first = monthlyChartData.first?.start,
            let last = monthlyChartData.last?.start
        else { return nil }
        let end = calendar.date(byAdding: .month, value: 1, to: last) ?? last
        return first...end
    }

    private var fallbackMonthlyDateDomain: ClosedRange<Date> {
        let start = monthlyChartData.first?.start ?? Date()
        let last = monthlyChartData.last?.start ?? start
        return start...last
    }

    private func periodStats(for frequency: TrendFrequency) -> [PeriodStats] {
        let relevantBlocks = blocks.filter { $0.status == .completed }
        var buckets: [Date: [Block]] = [:]
        for block in relevantBlocks {
            let periodStart: Date
            switch frequency {
            case .week:
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: block.date)
                periodStart = calendar.date(from: comps) ?? block.date
            case .month:
                let comps = calendar.dateComponents([.year, .month], from: block.date)
                periodStart = calendar.date(from: comps) ?? block.date
            }
            buckets[periodStart, default: []].append(block)
        }

        return buckets.map { (start, group) in
            let label = frequency.label(for: start)
            let grossTotal = group.reduce(0) { $0 + $1.grossPayout }
            let tipTotal = group.reduce(0) { $0 + ($1.tipsAmount ?? 0) }
            let totalMiles = group.reduce(0) { $0 + $1.roundedMiles }
            let averageMiles = group.isEmpty ? 0 : totalMiles / Decimal(group.count)
            return PeriodStats(start: start, label: label, grossTotal: grossTotal, tipTotal: tipTotal, averageMiles: averageMiles, totalMiles: totalMiles, blocks: group)
        }
        .sorted(by: { $0.start > $1.start })
    }

    private struct TrendPreviewCard: View {
        let title: String
        let stats: [PeriodStats]
        let frequency: TrendFrequency
        let limit: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    if !stats.isEmpty {
                        ThemedSeeAllLink(destination: TrendListView(stats: stats, frequency: frequency))
                    }
                }
                ForEach(stats.prefix(limit)) { stat in
                    NavigationLink(destination: TrendDetailView(stats: stat, frequency: frequency)) {
                        TrendSummaryRow(stats: stat, frequency: frequency)
                            .flexErrnCardStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
            .flexErrnCardStyle()
        }
    }

    private struct ThemedSeeAllLink<Destination: View>: View {
        let destination: Destination
        var body: some View {
            NavigationLink(destination: destination) {
                HStack(spacing: 4) {
                    Text("See all")
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(BlockErrnTheme.backgroundGradient, in: Capsule())
            }
        }
    }

    private struct TrendListView: View {
        let stats: [PeriodStats]
        let frequency: TrendFrequency

        var body: some View {
            ZStack {
                BlockErrnTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(stats) { stat in
                            NavigationLink(destination: TrendDetailView(stats: stat, frequency: frequency)) {
                                TrendSummaryRow(stats: stat, frequency: frequency)
                                    .flexErrnCardStyle()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(frequency == .week ? "Weekly History" : "Monthly History")
        }
    }

    private var scheduledBlocksThisWeek: [Block] {
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else { return [] }
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        return blocks.filter {
            $0.status == .accepted && blockStart($0) >= weekStart && blockStart($0) < weekEnd
        }
    }

    private var scheduledGrossThisWeek: Decimal {
        scheduledBlocksThisWeek.reduce(0) { $0 + $1.grossPayout }
    }

    private var upcomingBlocksCount: Int {
        let now = Date()
        return blocks.filter { block in
            block.status == .accepted && blockStart(block) > now
        }.count
    }

    private func blockStart(_ block: Block) -> Date {
        block.startTime ?? block.date
    }

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
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return "\(formatter.string(from: value as NSDecimalNumber) ?? "0") mi"
    }

    private func refreshStats() {
        refreshCounter += 1
    }
}

private struct TrendSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .bold()
            content
        }
        .flexErrnCardStyle()
    }
}

private let weekLabelFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter
}()

private let monthLabelFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM yyyy"
    return formatter
}()
