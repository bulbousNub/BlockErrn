import SwiftUI
import SwiftData

struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query private var blocks: [Block]
    @State private var showManualAdd: Bool = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            List {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        showManualAdd = true
                    } label: {
                        Label("Add Block Manually", systemImage: "plus.square.on.square")
                            .fontWeight(.semibold)
                    }
                    Text("Add historical blocks here while the home calculator stays limited to today or future dates.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(groupedBlocks) { section in
                    Section(header: Text(sectionHeader(for: section))) {
                        ForEach(section.blocks, id: \.id) { block in
                            NavigationLink(destination: BlockDetailView(block: block)) {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(block.date, style: .date)
                                        Spacer()
                                        Text(block.status.displayName)
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack {
                                        Text("Miles: \(formatDecimal(block.miles))")
                                        Spacer()
                                        Text("Expenses: \(formatCurrency(block.additionalExpensesTotal))")
                                        Spacer()
                                        Text("Raw: \(formatCurrency(block.grossPayout))")
                                        Spacer()
                                        Text("Profit: \(formatCurrency(block.totalProfit))")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    Text("\(blockTimeFormatter.string(from: block.startTime ?? block.date)) – \(blockTimeFormatter.string(from: block.endTime ?? block.date))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if block.status != .completed {
                                    Button {
                                        complete(block)
                                    } label: {
                                        Label("Complete", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                        .onDelete { offsets in delete(offsets, in: section) }
                    }
                }
            }
            .navigationTitle("Blocks Log")
            .sheet(isPresented: $showManualAdd) {
                NewBlockSheet()
            }
        }
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

    private func delete(_ offsets: IndexSet, in section: BlockSection) {
        for index in offsets {
            let block = section.blocks[index]
            block.status = .cancelled
            logStatusChange(for: block, note: "Marked cancelled from log.")
            block.updatedAt = Date()
        }
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
