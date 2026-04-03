import SwiftUI
import WidgetKit
import ActivityKit

struct BlockErrnLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlockTrackingAttributes.self) { context in
            // Lock Screen / Banner presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded presentation
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.scheduledStart, style: .time)
                            .font(.caption2)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(context.attributes.scheduledEnd, style: .time)
                            .font(.caption2)
                    } icon: {
                        Image(systemName: "flag.checkered")
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                        Text(String(format: "%.2f mi tracked", context.state.currentMiles))
                            .font(.headline)
                            .contentTransition(.numericText())
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
            } compactTrailing: {
                Text(String(format: "%.1f mi", context.state.currentMiles))
                    .font(.caption)
                    .contentTransition(.numericText())
            } minimal: {
                Text(String(format: "%.1f", context.state.currentMiles))
                    .font(.caption)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<BlockTrackingAttributes>) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BlockErrn")
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context.attributes.scheduledStart, style: .time)
                        .font(.subheadline)
                    Text("–")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(context.attributes.scheduledEnd, style: .time)
                        .font(.subheadline)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                Text(String(format: "%.2f mi", context.state.currentMiles))
                    .font(.title3)
                    .bold()
                    .contentTransition(.numericText())
            }
        }
        .padding()
    }
}
