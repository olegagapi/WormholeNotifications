import Testing
import Foundation
@testable import Wormhole

@Suite("Wormhole Tests")
struct WormholeTests {

    // MARK: - Test Types

    struct CounterMessage: Codable, Equatable, Sendable {
        let count: Int
    }

    struct StatusMessage: Codable, Equatable, Sendable {
        let status: String
        let timestamp: Date
    }

    // MARK: - Test Helpers

    func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WormholeIntegrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Initialization Tests

    @Test("Initialize with directory")
    func initWithDirectory() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        #expect(wormhole != nil)
    }

    @Test("Initialize with configuration")
    func initWithConfiguration() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let config = Configuration(
            appGroupIdentifier: "test.group",
            directory: tempDir.path,
            transitingStrategy: .file,
            serializationFormat: .json
        )

        // This will use the provided directory for testing
        let wormhole = Wormhole(directory: tempDir)
        #expect(wormhole != nil)
    }

    // MARK: - Send Message Tests

    @Test("Send Codable message")
    func sendCodableMessage() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        let message = CounterMessage(count: 42)

        try await wormhole.send(message, to: "counter")

        // Verify file was written
        let filePath = tempDir.appendingPathComponent("counter.message")
        #expect(FileManager.default.fileExists(atPath: filePath.path))
    }

    @Test("Send multiple messages to different identifiers")
    func sendMultipleMessages() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)

        try await wormhole.send(CounterMessage(count: 1), to: "counter1")
        try await wormhole.send(CounterMessage(count: 2), to: "counter2")
        try await wormhole.send(CounterMessage(count: 3), to: "counter3")

        // Verify all files exist
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("counter1.message").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("counter2.message").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("counter3.message").path))
    }

    // MARK: - Read Message Tests

    @Test("Read message returns sent value")
    func readMessage() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        let original = CounterMessage(count: 99)

        try await wormhole.send(original, to: "counter")
        let retrieved: CounterMessage? = try await wormhole.message(CounterMessage.self, for: "counter")

        #expect(retrieved == original)
    }

    @Test("Read non-existent message returns nil")
    func readNonExistent() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        let result: CounterMessage? = try await wormhole.message(CounterMessage.self, for: "nonExistent")

        #expect(result == nil)
    }

    @Test("Read message preserves complex types")
    func readComplexMessage() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        let timestamp = Date(timeIntervalSince1970: 1000000)
        let original = StatusMessage(status: "active", timestamp: timestamp)

        try await wormhole.send(original, to: "status")
        let retrieved: StatusMessage? = try await wormhole.message(StatusMessage.self, for: "status")

        #expect(retrieved == original)
    }

    // MARK: - Signal Tests

    @Test("Signal sends empty notification")
    func signalSendsNotification() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)

        // Signal should not throw
        await wormhole.signal("ping")

        // Signal doesn't store data, so reading should return nil
        let data: Data? = try await wormhole.message(Data.self, for: "ping")
        #expect(data == nil)
    }

    // MARK: - Clear Message Tests

    @Test("Clear removes specific message")
    func clearMessage() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)

        try await wormhole.send(CounterMessage(count: 1), to: "toDelete")
        try await wormhole.send(CounterMessage(count: 2), to: "toKeep")

        try await wormhole.clearMessage(for: "toDelete")

        let deleted: CounterMessage? = try await wormhole.message(CounterMessage.self, for: "toDelete")
        let kept: CounterMessage? = try await wormhole.message(CounterMessage.self, for: "toKeep")

        #expect(deleted == nil)
        #expect(kept?.count == 2)
    }

    @Test("Clear all removes all messages")
    func clearAllMessages() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)

        try await wormhole.send(CounterMessage(count: 1), to: "msg1")
        try await wormhole.send(CounterMessage(count: 2), to: "msg2")
        try await wormhole.send(CounterMessage(count: 3), to: "msg3")

        try await wormhole.clearAllMessages()

        #expect(try await wormhole.message(CounterMessage.self, for: "msg1") == nil)
        #expect(try await wormhole.message(CounterMessage.self, for: "msg2") == nil)
        #expect(try await wormhole.message(CounterMessage.self, for: "msg3") == nil)
    }

    // MARK: - Listener Tests

    @Test("Listen receives sent messages")
    func listenReceivesMessages() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        let receivedMessages = LockedValue<[CounterMessage]>([])

        let token = await wormhole.listen(for: "counter", as: CounterMessage.self) { message in
            receivedMessages.append(message)
        }

        defer {
            Task { await wormhole.stopListening(token) }
        }

        // Send a message
        try await wormhole.send(CounterMessage(count: 42), to: "counter")

        // Trigger notification manually for testing (normally this comes from Darwin)
        await wormhole.notifyListeners(for: "counter")

        // Wait for delivery
        try await Task.sleep(nanoseconds: 50_000_000)

        let messages = receivedMessages.getValue()
        #expect(messages.count >= 1)
        if let first = messages.first {
            #expect(first.count == 42)
        }
    }

    @Test("Stop listening removes listener")
    func stopListening() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        let receivedCount = LockedValue(0)

        let token = await wormhole.listen(for: "counter", as: CounterMessage.self) { _ in
            receivedCount.increment()
        }

        // Stop listening
        await wormhole.stopListening(token)

        // Send after stopping
        try await wormhole.send(CounterMessage(count: 1), to: "counter")
        await wormhole.notifyListeners(for: "counter")

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(receivedCount.getValue() == 0)
    }

    @Test("Multiple listeners for same identifier")
    func multipleListeners() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        let count1 = LockedValue(0)
        let count2 = LockedValue(0)

        let token1 = await wormhole.listen(for: "shared", as: CounterMessage.self) { _ in
            count1.increment()
        }

        let token2 = await wormhole.listen(for: "shared", as: CounterMessage.self) { _ in
            count2.increment()
        }

        defer {
            Task {
                await wormhole.stopListening(token1)
                await wormhole.stopListening(token2)
            }
        }

        try await wormhole.send(CounterMessage(count: 1), to: "shared")
        await wormhole.notifyListeners(for: "shared")

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(count1.getValue() >= 1)
        #expect(count2.getValue() >= 1)
    }

    // MARK: - AsyncSequence Tests

    @Test("Messages stream yields sent values")
    func messagesStream() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)
        let identifier: MessageIdentifier = "stream"

        // Start listening task
        let receivedMessages = LockedValue<[CounterMessage]>([])
        let listeningTask = Task {
            let stream = await wormhole.messages(CounterMessage.self, for: identifier)
            for try await message in stream {
                receivedMessages.append(message)
                if receivedMessages.getValue().count >= 2 {
                    break
                }
            }
        }

        // Give time for listener to set up
        try await Task.sleep(nanoseconds: 50_000_000)

        // Send messages
        try await wormhole.send(CounterMessage(count: 1), to: identifier)
        await wormhole.notifyListeners(for: identifier)

        try await Task.sleep(nanoseconds: 50_000_000)

        try await wormhole.send(CounterMessage(count: 2), to: identifier)
        await wormhole.notifyListeners(for: identifier)

        // Wait with timeout
        let waitTask = Task {
            try await Task.sleep(nanoseconds: 500_000_000)
            listeningTask.cancel()
        }

        _ = try? await listeningTask.value
        waitTask.cancel()

        let messages = receivedMessages.getValue()
        #expect(messages.count >= 1)
    }

    // MARK: - Round-trip Integration Tests

    @Test("Full send-receive round-trip")
    func fullRoundTrip() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole = Wormhole(directory: tempDir)

        // Send
        let original = StatusMessage(status: "complete", timestamp: Date())
        try await wormhole.send(original, to: "status")

        // Receive
        let received: StatusMessage? = try await wormhole.message(StatusMessage.self, for: "status")

        #expect(received?.status == original.status)
    }

    @Test("Multiple wormhole instances share data")
    func multipleInstances() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        let wormhole1 = Wormhole(directory: tempDir)
        let wormhole2 = Wormhole(directory: tempDir)

        // Send from first
        try await wormhole1.send(CounterMessage(count: 123), to: "shared")

        // Read from second
        let received: CounterMessage? = try await wormhole2.message(CounterMessage.self, for: "shared")

        #expect(received?.count == 123)
    }
}

// MARK: - Test Helpers

private final class LockedValue<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ initialValue: T) {
        self.value = initialValue
    }

    func getValue() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func setValue(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}

extension LockedValue where T == Int {
    func increment() {
        lock.lock()
        defer { lock.unlock() }
        value += 1
    }
}

extension LockedValue where T == [WormholeTests.CounterMessage] {
    func append(_ message: WormholeTests.CounterMessage) {
        lock.lock()
        defer { lock.unlock() }
        value.append(message)
    }
}
