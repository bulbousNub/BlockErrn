import SwiftUI
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
        List {
            Section("Summary") {
                HStack {
                    Text("Gross")
                    Spacer()
                    Text(formatCurrency(stats.grossTotal))
                }
                HStack {
                    Text("Tips")
                    Spacer()
                    Text(formatCurrency(stats.tipTotal))
                }
                HStack {
                    Text("Avg miles/block")
                    Spacer()
                    Text(formatMiles(stats.averageMiles))
                }
            }
            Section("Blocks") {
                ForEach(stats.blocks.sorted(by: { $0.date > $1.date }), id: \.id) { block in
                    VStack(alignment: .leading) {
                        Text(block.date, style: .date)
                            .font(.headline)
                        Text("\(block.grossPayout, format: .currency(code: "USD")) • \(block.miles, format: .number) mi")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(stats.label)
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

struct TrendSummaryRow: View {
    let stats: PeriodStats
    let frequency: TrendFrequency

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(stats.label)
                    .font(.body)
                    .bold()
                Text("Gross \(formatCurrency(stats.grossTotal)) • Tips \(formatCurrency(stats.tipTotal))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatMiles(stats.averageMiles))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
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

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
