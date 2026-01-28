import WidgetKit
import SwiftUI
import Wormhole

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now, counter: 0, message: "Placeholder")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            // Refresh every 5 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: entry.date)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> SimpleEntry {
        do {
            let wormhole = try Wormhole(appGroupIdentifier: appGroupIdentifier, directory: "wormhole")

            let counter = try await wormhole.message(CounterMessage.self, for: MessageID.counter)
            let textMessage = try await wormhole.message(TextMessage.self, for: MessageID.textFromApp)

            return SimpleEntry(
                date: .now,
                counter: counter?.count ?? 0,
                message: textMessage?.text ?? "No message"
            )
        } catch {
            return SimpleEntry(date: .now, counter: 0, message: "Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Timeline Entry

struct SimpleEntry: TimelineEntry {
    let date: Date
    let counter: Int
    let message: String
}

// MARK: - Widget View

struct WormholeDemoWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.blue)
                Text("Wormhole")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            Text("\(entry.counter)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Counter")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Wormhole")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text("\(entry.counter)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                Text("Counter")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Message from App")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.message)
                    .font(.body)
                    .lineLimit(3)

                Spacer()

                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

// MARK: - Widget Configuration

struct WormholeDemoWidget: Widget {
    let kind: String = "WormholeDemoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WormholeDemoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wormhole Demo")
        .description("Shows counter and messages from the main app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct WormholeDemoWidgetBundle: WidgetBundle {
    var body: some Widget {
        WormholeDemoWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    WormholeDemoWidget()
} timeline: {
    SimpleEntry(date: .now, counter: 42, message: "Hello from app!")
}

#Preview(as: .systemMedium) {
    WormholeDemoWidget()
} timeline: {
    SimpleEntry(date: .now, counter: 42, message: "Hello from app!")
}
