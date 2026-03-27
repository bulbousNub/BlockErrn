import SwiftUI
import SwiftData

struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query private var blocks: [Block]
    @State private var showManualAdd: Bool = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                FlexErrnTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerCard
                        ForEach(groupedBlocks) { section in
                            sectionCard(section)
                        }
                    }
                    .padding()
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Blocks Log")
            .sheet(isPresented: $showManualAdd) {
                NewBlockSheet()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocks log")
                        .font(.title2)
                        .bold()
                    Text("Manual entries live here, along with every block you’ve tracked.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showManualAdd = true
                } label: {
                    Label("Add Block", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            Text("Quickly review mileage, profit, and status per day.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .flexErrnCardStyle()
    }

    private func sectionCard(_ section: BlockSection) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(sectionHeader(for: section))
                    .font(.headline)
                ForEach(section.blocks, id: \.id) { block in
                    NavigationLink(destination: BlockDetailView(block: block)) {
                        blockCard(block)
                    }
                    .buttonStyle(.plain)
                }
            }
        .flexErrnCardStyle()
    }

    @ViewBuilder
    private func blockCard(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(block.date, style: .date)
                    .font(.subheadline)
                Spacer()
                Text(block.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu {
                    Button("Complete") { complete(block) }
                        .disabled(block.status == .completed)
                    Button("Mark Cancelled") { cancel(block) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }

            Text("\(blockTimeFormatter.string(from: block.startTime ?? block.date)) – \(blockTimeFormatter.string(from: block.endTime ?? block.date))")
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
                    Text("Miles: \(formatDecimal(block.miles))")
                        .font(.caption2)
                    Text("Profit: \(formatCurrency(block.totalProfit))")
                        .font(.caption2)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var groupedBlocks: [BlockSection] {
        let today = calendar.startOfDay(for: Date())
        var futureGroups: [Date: [Block]] = [:]
        var pastGroups: [Date: [Block]] = [:]

        for block in blocks {
            let day = calendar.startOfDay(for: block.date)
            if day > today {
                futureGroups[day, default: []].append(block)
            } else {
                pastGroups[day, default: []].append(block)
            }
        }

        let futureSections = futureGroups.map { date, items in
            BlockSection(date: date, blocks: items.sorted(by: { $0.date > $1.date }), isFuture: true)
        }.sorted(by: { $0.date > $1.date })

        let pastSections = pastGroups.map { date, items in
            BlockSection(date: date, blocks: items.sorted(by: { $0.date > $1.date }), isFuture: false)
        }.sorted(by: { $0.date > $1.date })

        return futureSections + pastSections
    }

    private func sectionHeader(for section: BlockSection) -> String {
        let formatter = Self.sectionFormatter
        let title = formatter.string(from: section.date)
        return section.isFuture ? "\(title) — Upcoming" : title
    }

    private func cancel(_ block: Block) {
        guard block.status != .cancelled else { return }
        block.status = .cancelled
        logStatusChange(for: block, note: "Marked cancelled from log.")
        block.updatedAt = Date()
        try? context.save()
    }

    private func complete(_ block: Block) {
        guard block.status != .completed else { return }
        block.status = .completed
        logStatusChange(for: block, note: "Marked completed from log.")
        block.updatedAt = Date()
        try? context.save()
    }

    private func logStatusChange(for block: Block, note: String) {
        let entry = AuditEntry(action: .statusChanged, note: note)
        block.auditEntries.append(entry)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let ns = value as NSDecimalNumber
        return ns.stringValue
    }

    private struct BlockSection: Identifiable {
        let date: Date
        let blocks: [Block]
        let isFuture: Bool

        var id: Date { date }
    }

    private static let sectionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
