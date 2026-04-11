import SwiftUI
import SwiftData
import Charts

struct TrendView: View {
    @Query private var blocks: [Block]
    @ObservedObject private var store = StoreKitManager.shared
    @State private var refreshCounter: Int = 0
    @State private var showProUpgrade = false

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
                            // Top-level metric cards (#7 + reworked)
                            earningsOverviewCard

                            // Weekly earnings chart (reworked — gross + profit)
                            TrendSectionCard(title: "Weekly Earnings") {
                                weeklyEarningsSection
                            }

                            // Monthly earnings chart (reworked — gross + profit bars)
                            TrendSectionCard(title: "Monthly Earnings") {
                                monthlyEarningsSection
                            }

                            // #1 Profit/hr trend
                            if weeklyChartData.contains(where: { $0.totalHours > 0 }) {
                                TrendSectionCard(title: "Profit per Hour") {
                                    profitPerHourSection
                                }
                            }

                            // #2 Tips trend
                            if weeklyChartData.contains(where: { $0.tipTotal > 0 }) {
                                TrendSectionCard(title: "Tips Trend") {
                                    tipsTrendSection
                                }
                            }

                            // #3 Expense breakdown by category
                            if !allExpensesByCategory.isEmpty {
                                TrendSectionCard(title: "Expense Breakdown") {
                                    expenseBreakdownSection
                                }
                            }

                            // #4 Block count & hours per period
                            TrendSectionCard(title: "Blocks & Hours") {
                                blocksAndHoursSection
                            }

                            // #5 Actual vs Scheduled hours
                            if weeklyChartData.contains(where: { $0.blocksWithActualTimes > 0 }) {
                                TrendSectionCard(title: "Actual vs Scheduled") {
                                    actualVsScheduledSection
                                }
                            }

                            // #6 Efficiency metrics
                            efficiencyCard

                            // Recent weeks / months drill-down
                            if store.isProUnlocked {
                                TrendPreviewCard(title: "Recent Weeks", stats: weeklyStats, frequency: .week, limit: 3)
                                TrendPreviewCard(title: "Recent Months", stats: monthlyStats, frequency: .month, limit: 3)
                            } else {
                                // Show current week/month only, lock the rest
                                if let current = weeklyStats.first {
                                    TrendPreviewCard(title: "This Week", stats: [current], frequency: .week, limit: 1)
                                }
                                ProLockedBanner(feature: "Full Trend History") {
                                    showProUpgrade = true
                                }
                                .flexErrnCardStyle()
                            }
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
            .sheet(isPresented: $showProUpgrade) {
                NavigationStack {
                    ProUpgradeView()
                }
            }
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

    // MARK: - Chart highlight state

    @State private var highlightedWeek: PeriodStats? = nil
    @State private var highlightedMonth: PeriodStats? = nil

    // MARK: - #7 Top-Level Metric Cards (reworked with profit + profit/hr)

    private var earningsOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Earnings Overview")
                    .font(.title2)
                    .bold()
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(upcomingBlocksCount) Upcoming")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(completedBlockCount) Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // This Week
            if let week = latestCompletedWeeklyStat {
                Text("This Week")
                    .font(.subheadline)
                    .bold()
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.flexible(minimum: 100), spacing: 10), GridItem(.flexible(minimum: 100), spacing: 10), GridItem(.flexible(minimum: 100), spacing: 10)], spacing: 10) {
                    MetricCard(title: "Gross", value: formatCurrency(week.grossTotal), caption: "\(week.blockCount) blocks")
                    MetricCard(title: "Profit", value: formatCurrency(week.totalProfit), caption: formatCurrency(week.profitPerHour) + "/hr")
                    MetricCard(title: "Miles", value: formatMiles(week.totalMiles), caption: formatCurrency(week.totalMileageDeduction) + " ded.")
                }
            }

            // This Month
            if let month = latestCompletedMonthlyStat {
                Text("This Month")
                    .font(.subheadline)
                    .bold()
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.flexible(minimum: 100), spacing: 10), GridItem(.flexible(minimum: 100), spacing: 10), GridItem(.flexible(minimum: 100), spacing: 10)], spacing: 10) {
                    MetricCard(title: "Gross", value: formatCurrency(month.grossTotal), caption: "\(month.blockCount) blocks")
                    MetricCard(title: "Profit", value: formatCurrency(month.totalProfit), caption: formatCurrency(month.profitPerHour) + "/hr")
                    MetricCard(title: "Miles", value: formatMiles(month.totalMiles), caption: formatCurrency(month.totalMileageDeduction) + " ded.")
                }
            }
        }
        .flexErrnCardStyle()
    }

    // MARK: - Reworked Weekly Earnings (gross + profit overlay)

    private var weeklyEarningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            weeklyEarningsChart
            ChartCallout(stat: highlightedWeek ?? weeklyChartData.last)
        }
    }

    private var weeklyEarningsChart: some View {
        Chart {
            ForEach(weeklyChartData) { stat in
                LineMark(
                    x: .value("Week", stat.start),
                    y: .value("Amount", stat.grossTotal.doubleValue)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Type", "Gross"))
                PointMark(
                    x: .value("Week", stat.start),
                    y: .value("Amount", stat.grossTotal.doubleValue)
                )
                .foregroundStyle(by: .value("Type", "Gross"))

                LineMark(
                    x: .value("Week", stat.start),
                    y: .value("Amount", stat.totalProfit.doubleValue)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Type", "Profit"))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                PointMark(
                    x: .value("Week", stat.start),
                    y: .value("Amount", stat.totalProfit.doubleValue)
                )
                .foregroundStyle(by: .value("Type", "Profit"))
            }
        }
        .chartForegroundStyleScale(["Gross": .blue, "Profit": .green])
        .chartLegend(position: .top, alignment: .leading)
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
                        Text(formatCurrencyShort(Decimal(double)))
                    }
                }
            }
        }
        .chartYScale(domain: 0...(weeklyGrossMax * Decimal(1.15)))
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
        .frame(height: 200)
    }

    // MARK: - Reworked Monthly Earnings (side-by-side gross + profit bars)

    private var monthlyEarningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthlyEarningsChart
            ChartCallout(stat: highlightedMonth ?? monthlyChartData.last)
        }
    }

    private var monthlyEarningsChart: some View {
        Chart {
            ForEach(monthlyChartData) { stat in
                BarMark(
                    x: .value("Month", stat.start),
                    y: .value("Amount", stat.grossTotal.doubleValue)
                )
                .foregroundStyle(by: .value("Type", "Gross"))
                .position(by: .value("Type", "Gross"))

                BarMark(
                    x: .value("Month", stat.start),
                    y: .value("Amount", stat.totalProfit.doubleValue)
                )
                .foregroundStyle(by: .value("Type", "Profit"))
                .position(by: .value("Type", "Profit"))
            }
        }
        .chartForegroundStyleScale(["Gross": .blue, "Profit": .green])
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: monthlyChartData.map(\.start)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(monthLabelFormatter.string(from: date))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
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
                        Text(formatCurrencyShort(Decimal(double)))
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
        .frame(height: 200)
    }

    // MARK: - #1 Profit per Hour Trend

    private var profitPerHourSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly profit/hr trend")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(weeklyChartData) { stat in
                    if stat.totalHours > 0 {
                        AreaMark(
                            x: .value("Week", stat.start),
                            y: .value("$/hr", stat.profitPerHour.doubleValue)
                        )
                        .foregroundStyle(.green.opacity(0.15))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Week", stat.start),
                            y: .value("$/hr", stat.profitPerHour.doubleValue)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.green)

                        PointMark(
                            x: .value("Week", stat.start),
                            y: .value("$/hr", stat.profitPerHour.doubleValue)
                        )
                        .foregroundStyle(.green)
                        .annotation(position: .top, spacing: 4) {
                            Text(formatCurrencyShort(stat.profitPerHour))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
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
                            Text(formatCurrencyShort(Decimal(double)))
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: - #2 Tips Trend

    private var tipsTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly tips earned")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(weeklyChartData) { stat in
                    BarMark(
                        x: .value("Week", stat.start),
                        y: .value("Tips", stat.tipTotal.doubleValue)
                    )
                    .foregroundStyle(.orange.gradient)
                    .annotation(position: .top, spacing: 2) {
                        if stat.tipTotal > 0 {
                            Text(formatCurrencyShort(stat.tipTotal))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
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
                            Text(formatCurrencyShort(Decimal(double)))
                        }
                    }
                }
            }
            .frame(height: 160)

            // Tip rate stat
            if let latest = latestCompletedWeeklyStat, latest.grossTotal > 0 {
                let tipPercent = latest.tipTotal / latest.grossTotal * 100
                HStack {
                    Text("Tips as % of gross this week:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", NSDecimalNumber(decimal: tipPercent).doubleValue))
                        .font(.caption)
                        .bold()
                }
            }
        }
    }

    // MARK: - #3 Expense Breakdown by Category

    private var allExpensesByCategory: [(category: String, total: Decimal)] {
        var categoryTotals: [String: Decimal] = [:]
        let completedBlocks = blocks.filter { $0.status == .completed }
        for block in completedBlocks {
            for expense in block.expenses {
                let name = ExpenseCategory(rawValue: expense.categoryRaw)?.displayName ?? expense.categoryRaw
                categoryTotals[name, default: 0] += expense.amount
            }
        }
        return categoryTotals
            .map { (category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    private let categoryColors: [Color] = [.red, .orange, .yellow, .purple, .pink, .cyan, .mint, .indigo]

    private var expenseBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let data = allExpensesByCategory
            let grandTotal = data.reduce(Decimal(0)) { $0 + $1.total }

            Chart(data, id: \.category) { item in
                SectorMark(
                    angle: .value("Amount", item.total.doubleValue),
                    innerRadius: .ratio(0.55),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Category", item.category))
                .cornerRadius(4)
            }
            .chartLegend(position: .bottom, alignment: .center, spacing: 12)
            .frame(height: 200)

            // Category breakdown list
            ForEach(Array(data.enumerated()), id: \.element.category) { index, item in
                HStack {
                    Circle()
                        .fill(categoryColors[index % categoryColors.count])
                        .frame(width: 10, height: 10)
                    Text(item.category)
                        .font(.caption)
                    Spacer()
                    Text(formatCurrency(item.total))
                        .font(.caption)
                        .bold()
                    if grandTotal > 0 {
                        let pct = item.total / grandTotal * 100
                        Text(String(format: "(%.0f%%)", NSDecimalNumber(decimal: pct).doubleValue))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - #4 Blocks & Hours per Period

    private var blocksAndHoursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly blocks & hours")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(weeklyChartData) { stat in
                    BarMark(
                        x: .value("Week", stat.start),
                        y: .value("Hours", stat.totalHours.doubleValue)
                    )
                    .foregroundStyle(.indigo.gradient)
                    .annotation(position: .top, spacing: 2) {
                        Text("\(stat.blockCount)b")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
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
                            Text(String(format: "%.0fh", double))
                        }
                    }
                }
            }
            .frame(height: 160)

            // Summary row
            if let week = latestCompletedWeeklyStat, let month = latestCompletedMonthlyStat {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(week.blockCount) blocks, \(formatHours(week.totalHours))")
                            .font(.caption)
                            .bold()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("This month")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(month.blockCount) blocks, \(formatHours(month.totalHours))")
                            .font(.caption)
                            .bold()
                    }
                }
            }
        }
    }

    // MARK: - #5 Actual vs Scheduled Hours

    private var actualVsScheduledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduled hours vs actual worked hours per week")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(weeklyChartData) { stat in
                    if stat.blocksWithActualTimes > 0 {
                        BarMark(
                            x: .value("Week", stat.start),
                            y: .value("Hours", stat.totalHours.doubleValue)
                        )
                        .foregroundStyle(by: .value("Type", "Scheduled"))
                        .position(by: .value("Type", "Scheduled"))

                        BarMark(
                            x: .value("Week", stat.start),
                            y: .value("Hours", stat.actualWorkedHours.doubleValue)
                        )
                        .foregroundStyle(by: .value("Type", "Actual"))
                        .position(by: .value("Type", "Actual"))
                    }
                }
            }
            .chartForegroundStyleScale(["Scheduled": .gray.opacity(0.5), "Actual": .blue])
            .chartLegend(position: .top, alignment: .leading)
            .chartXAxis {
                AxisMarks(values: weeklyChartData.filter({ $0.blocksWithActualTimes > 0 }).map(\.start)) { value in
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
                            Text(String(format: "%.0fh", double))
                        }
                    }
                }
            }
            .frame(height: 170)

            // Overtime / undertime summary for latest week
            if let week = latestCompletedWeeklyStat, week.blocksWithActualTimes > 0 {
                let diff = week.actualWorkedHours - week.totalHours
                let diffDouble = NSDecimalNumber(decimal: diff).doubleValue
                HStack {
                    Text("This week difference:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%+.1fh", diffDouble))
                        .font(.caption)
                        .bold()
                        .foregroundStyle(diff >= 0 ? .red : .green)
                }
                Text(diff >= 0 ? "You worked longer than scheduled" : "You finished earlier than scheduled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - #6 Efficiency Metrics

    private var efficiencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Efficiency")
                .font(.title3)
                .bold()

            let allCompleted = blocks.filter { $0.status == .completed }
            let totalMiles = allCompleted.reduce(Decimal(0)) { $0 + $1.roundedMiles }
            let totalProfit = allCompleted.reduce(Decimal(0)) { $0 + $1.totalProfit }
            let totalPkgs = allCompleted.compactMap(\.packageCount).reduce(0, +)
            let totalStps = allCompleted.compactMap(\.stopCount).reduce(0, +)
            let totalActualMinutes = allCompleted.reduce(0) { total, block in
                guard let s = block.userStartTime, let e = block.userCompletionTime else { return total }
                return total + max(0, Int(e.timeIntervalSince(s) / 60))
            }
            let actualHrs = Decimal(totalActualMinutes) / 60

            LazyVGrid(columns: [GridItem(.flexible(minimum: 100), spacing: 10), GridItem(.flexible(minimum: 100), spacing: 10)], spacing: 10) {
                if totalMiles > 0 {
                    MetricCard(
                        title: "Profit/Mile",
                        value: formatCurrency(totalProfit / totalMiles),
                        caption: "All-time"
                    )
                }
                if !allCompleted.isEmpty {
                    MetricCard(
                        title: "Miles/Block",
                        value: formatMiles(totalMiles / Decimal(allCompleted.count)),
                        caption: "Avg per block"
                    )
                }
                if actualHrs > 0 && totalPkgs > 0 {
                    let pkgsPerHr = Decimal(totalPkgs) / actualHrs
                    MetricCard(
                        title: "Pkgs/Hour",
                        value: formatDecimal(pkgsPerHr),
                        caption: "\(totalPkgs) total"
                    )
                }
                if actualHrs > 0 && totalStps > 0 {
                    let stopsPerHr = Decimal(totalStps) / actualHrs
                    MetricCard(
                        title: "Stops/Hour",
                        value: formatDecimal(stopsPerHr),
                        caption: "\(totalStps) total"
                    )
                }
            }
        }
        .flexErrnCardStyle()
    }

    // MARK: - Data Helpers

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

    private var weeklyGrossMax: Decimal {
        weeklyChartData.map(\.grossTotal).max() ?? 0
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

    private var completedBlockCount: Int {
        blocks.filter { $0.status == .completed }.count
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

    // MARK: - Sub-views

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

    // MARK: - Formatters

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

    private func formatCurrencyShort(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
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

    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
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
