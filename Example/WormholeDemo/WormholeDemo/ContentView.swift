import SwiftUI
import Wormhole

struct ContentView: View {
    @State private var counter = 0
    @State private var messageText = ""
    @State private var receivedMessage = "No messages yet"
    @State private var wormhole: Wormhole?
    @State private var listenerToken: ListenerToken?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Counter") {
                    HStack {
                        Text("Count: \(counter)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button("Increment") {
                            counter += 1
                            sendCounter()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Text("This counter syncs with the widget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Send Message to Widget") {
                    TextField("Enter a message", text: $messageText)
                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(messageText.isEmpty)
                }

                Section("Received from Widget") {
                    Text(receivedMessage)
                        .foregroundStyle(.secondary)
                }

                if let error = errorMessage {
                    Section("Error") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section("Setup Instructions") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To use this demo:")
                            .fontWeight(.semibold)
                        Text("1. Create an App Group in your Apple Developer account")
                        Text("2. Add the App Group capability to both targets")
                        Text("3. Update `appGroupIdentifier` in MessageTypes.swift")
                        Text("4. Add the widget to your home screen")
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Wormhole Demo")
        }
        .task {
            await setupWormhole()
        }
    }

    private func setupWormhole() async {
        do {
            let wh = try Wormhole(appGroupIdentifier: appGroupIdentifier, directory: "wormhole")
            self.wormhole = wh

            // Read current counter value
            if let message = try await wh.message(CounterMessage.self, for: MessageID.counter) {
                counter = message.count
            }

            // Listen for messages from widget
            listenerToken = wh.listen(for: MessageID.textFromWidget, as: TextMessage.self) { message in
                Task { @MainActor in
                    receivedMessage = "\(message.text)\n(at \(message.sentAt.formatted(date: .omitted, time: .shortened)))"
                }
            }
        } catch {
            errorMessage = "Failed to initialize Wormhole: \(error.localizedDescription)"
        }
    }

    private func sendCounter() {
        Task {
            do {
                try await wormhole?.send(CounterMessage(count: counter), to: MessageID.counter)
            } catch {
                errorMessage = "Failed to send counter: \(error.localizedDescription)"
            }
        }
    }

    private func sendMessage() {
        Task {
            do {
                try await wormhole?.send(TextMessage(text: messageText), to: MessageID.textFromApp)
                messageText = ""
            } catch {
                errorMessage = "Failed to send message: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
}
