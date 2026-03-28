import SwiftUI
import SwiftData
import Charts

struct PeriodStats: Identifiable {
    let start: Date
    let label: String
    let grossTotal: Decimal
    let tipTotal: Decimal
    let averageMiles: Decimal
    let totalMiles: Decimal
    let blocks: [Block]

    var id: Date { start }

    var totalDurationMinutes: Int {
        blocks.reduce(0) { $0 + $1.durationMinutes }
    }

    var totalHours: Decimal {
        Decimal(totalDurationMinutes) / 60
    }

    var grossPlusTips: Decimal {
        grossTotal + tipTotal
    }

    var grossPerHour: Decimal {
        guard totalHours > 0 else { return grossTotal }
        return grossTotal / totalHours
    }

    var grossPlusTipsPerHour: Decimal {
        guard totalHours > 0 else { return grossPlusTips }
        return grossPlusTips / totalHours
    }

    var totalExpenses: Decimal {
        blocks.reduce(0) { $0 + $1.additionalExpensesTotal }
    }

    var totalMileageDeduction: Decimal {
        blocks.reduce(0) { $0 + $1.mileageDeduction }
    }

    var totalProfit: Decimal {
        blocks.reduce(0) { $0 + $1.totalProfit }
    }

    var profitPerHour: Decimal {
        guard totalHours > 0 else { return totalProfit }
        return totalProfit / totalHours
    }
}

enum TrendFrequency {
    case week
    case month

    func label(for date: Date) -> String {
        let formatter = DateFormatter()
        switch self {
        case .week:
            formatter.dateFormat = "MMM d"
            return "Week of \(formatter.string(from: date))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
}

struct ChartCallout: View {
    let stat: PeriodStats?

    var body: some View {
        if let stat {
            HStack {
                VStack(alignment: .leading) {
                    Text(stat.label)
                        .font(.subheadline)
                        .bold()
                    Text("Gross \(formatCurrencyDecimal(stat.grossTotal)) • Tips \(formatCurrencyDecimal(stat.tipTotal))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatMiles(stat.totalMiles))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    private func formatCurrencyDecimal(_ value: Decimal) -> String {
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
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.title3)
                .bold()
            Text(caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 2)
    }
}

struct TrendDetailView: View {
    let stats: PeriodStats
    let frequency: TrendFrequency

    var body: some View {
        ZStack {
            FlexErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    summaryCard
                    blocksCard
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(stats.label)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.headline)
            summaryRow(title: "Total hours worked", value: formatHours(stats.totalHours))
            summaryRow(title: "Total gross pay", value: formatCurrency(stats.grossTotal))
            summaryRow(title: "Total tips earned", value: formatCurrency(stats.tipTotal))
            summaryRow(title: "Gross + tips", value: formatCurrency(stats.grossPlusTips))
            summaryRow(title: "Gross $/hr", value: formatCurrency(stats.grossPerHour))
            summaryRow(title: "Gross + tips $/hr", value: formatCurrency(stats.grossPlusTipsPerHour))
            summaryRow(title: "Total miles", value: formatMiles(stats.totalMiles))
            summaryRow(title: "Mileage deduction", value: formatCurrency(stats.totalMileageDeduction))
            summaryRow(title: "Total expenses", value: formatCurrency(stats.totalExpenses))
            summaryRow(title: "Total profit", value: formatCurrency(stats.totalProfit))
            summaryRow(title: "Profit $/hr", value: formatCurrency(stats.profitPerHour))
        }
        .flexErrnCardStyle()
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
        }
    }

    private func formatHours(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return "\(formatter.string(from: value as NSDecimalNumber) ?? "0.0") h"
    }

    private var blocksCard: some View {
        let sortedBlocks = stats.blocks.sorted(by: { $0.date > $1.date })
        return VStack(alignment: .leading, spacing: 12) {
            Text("Blocks")
                .font(.headline)
            ForEach(sortedBlocks, id: \.id) { block in
                NavigationLink(destination: BlockDetailView(block: block)) {
                    TrendBlockRow(block: block)
                }
                .buttonStyle(.plain)
                if block.id != sortedBlocks.last?.id {
                    Divider()
                }
            }
        }
        .flexErrnCardStyle()
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
}

struct TrendBlockRow: View {
    let block: Block

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var workModeCoordinator: WorkModeCoordinator
    @EnvironmentObject private var tabSelectionState: TabSelectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(block.date, style: .date)
                    .font(.subheadline)
                if isUpcoming(block) {
                    Text("Upcoming")
                        .font(.caption2)
                        .padding(4)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                }
                Spacer()
                Text(block.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu {
                    Button("Make Active") {
                        workModeCoordinator.forceActive(block)
                        tabSelectionState.selectedTab = 0
                    }
                    Button("Mark Cancelled") { cancel(block) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }

            Text("\(blockTimeFormatter.string(from: startDate(for: block))) – \(blockTimeFormatter.string(from: endDate(for: block)))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gross: \(formatCurrency(block.grossPayout))")
                        .font(.caption2)
                    Text("Expenses: \(formatCurrency(block.additionalExpensesTotal))")
                        .font(.caption2)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Miles: \(block.roundedMilesDisplay)")
                        .font(.caption2)
                    Text("Profit: \(formatCurrency(block.totalProfit))")
                        .font(.caption2)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func cancel(_ block: Block) {
        guard block.status != .cancelled else { return }
        block.status = .cancelled
        logStatusChange(for: block, note: "Marked cancelled from trends")
        block.updatedAt = Date()
        try? context.save()
    }

    private func logStatusChange(for block: Block, note: String) {
        let entry = AuditEntry(action: .statusChanged, note: note)
        block.auditEntries.append(entry)
    }

    private func startDate(for block: Block) -> Date {
        block.startTime ?? block.date
    }

    private func endDate(for block: Block) -> Date {
        if let end = block.endTime {
            return end
        }
        let start = startDate(for: block)
        let duration = max(1, block.durationMinutes)
        return start.addingTimeInterval(TimeInterval(duration * 60))
    }

    private func isUpcoming(_ block: Block) -> Bool {
        startDate(for: block) > Date()
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

struct TrendSummaryRow: View {
    let stats: PeriodStats
    let frequency: TrendFrequency

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stats.label)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gross: \(formatCurrency(stats.grossTotal))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Expenses: \(formatCurrency(stats.totalExpenses))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Miles: \(formatMiles(stats.totalMiles))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Profit: \(formatCurrency(stats.totalProfit))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
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
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return "\(formatter.string(from: value as NSDecimalNumber) ?? "0") mi"
    }
}

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
