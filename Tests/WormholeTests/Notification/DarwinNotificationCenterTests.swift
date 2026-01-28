import Testing
import Foundation
@testable import Wormhole

@Suite("DarwinNotificationCenter Tests")
struct DarwinNotificationCenterTests {

    // MARK: - Observer Registration Tests

    @Test("Register observer for notification")
    func registerObserver() async throws {
        let center = DarwinNotificationCenter.shared
        var receivedCount = 0

        let token = center.addObserver(for: "test.register") {
            receivedCount += 1
        }

        // Cleanup
        center.removeObserver(token)

        // Should have registered successfully (no crash)
        #expect(token.name == "test.register")
    }

    @Test("Remove observer stops notifications")
    func removeObserver() async throws {
        let center = DarwinNotificationCenter.shared
        var receivedCount = 0

        let token = center.addObserver(for: "test.remove") {
            receivedCount += 1
        }

        center.removeObserver(token)

        // Post after removal
        center.post(name: "test.remove")

        // Give time for potential delivery
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        #expect(receivedCount == 0)
    }

    @Test("Remove non-existent observer does not crash")
    func removeNonExistent() {
        let center = DarwinNotificationCenter.shared
        let fakeToken = DarwinNotificationCenter.ObserverToken(
            id: UUID(),
            name: "non.existent"
        )

        // Should not crash
        center.removeObserver(fakeToken)
    }

    // MARK: - Multiple Observers Tests

    @Test("Multiple observers for same name")
    func multipleObserversSameName() async throws {
        let center = DarwinNotificationCenter.shared
        var count1 = 0
        var count2 = 0

        let token1 = center.addObserver(for: "test.multiple") {
            count1 += 1
        }

        let token2 = center.addObserver(for: "test.multiple") {
            count2 += 1
        }

        defer {
            center.removeObserver(token1)
            center.removeObserver(token2)
        }

        center.post(name: "test.multiple")

        // Give time for delivery
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        #expect(count1 >= 1)
        #expect(count2 >= 1)
    }

    @Test("Remove one observer keeps others")
    func removeOneKeepsOthers() async throws {
        let center = DarwinNotificationCenter.shared
        var count1 = 0
        var count2 = 0

        let token1 = center.addObserver(for: "test.keepOthers") {
            count1 += 1
        }

        let token2 = center.addObserver(for: "test.keepOthers") {
            count2 += 1
        }

        defer {
            center.removeObserver(token2)
        }

        // Remove first observer
        center.removeObserver(token1)

        // Post notification
        center.post(name: "test.keepOthers")

        // Give time for delivery
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Only second observer should receive
        #expect(count1 == 0)
        #expect(count2 >= 1)
    }

    // MARK: - Notification Callback Tests

    @Test("Callback invoked on notification")
    func callbackInvoked() async throws {
        let center = DarwinNotificationCenter.shared
        let expectation = LockedValue(false)

        let token = center.addObserver(for: "test.callback") {
            expectation.setValue(true)
        }

        defer {
            center.removeObserver(token)
        }

        center.post(name: "test.callback")

        // Wait for callback with timeout
        for _ in 0..<20 {
            if expectation.getValue() {
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        #expect(expectation.getValue() == true)
    }

    @Test("Post notification with identifier prefix")
    func postWithIdentifierPrefix() async throws {
        let center = DarwinNotificationCenter.shared
        let expectation = LockedValue(false)

        let notificationName = "com.example.wormhole.testMessage"

        let token = center.addObserver(for: notificationName) {
            expectation.setValue(true)
        }

        defer {
            center.removeObserver(token)
        }

        center.post(name: notificationName)

        // Wait for callback
        for _ in 0..<20 {
            if expectation.getValue() {
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(expectation.getValue() == true)
    }

    // MARK: - Thread Safety Tests

    @Test("Concurrent observer additions")
    func concurrentAdditions() async throws {
        let center = DarwinNotificationCenter.shared
        var tokens: [DarwinNotificationCenter.ObserverToken] = []
        let tokensLock = NSLock()

        await withTaskGroup(of: DarwinNotificationCenter.ObserverToken.self) { group in
            for i in 0..<10 {
                group.addTask {
                    center.addObserver(for: "test.concurrent.\(i)") {}
                }
            }

            for await token in group {
                tokensLock.lock()
                tokens.append(token)
                tokensLock.unlock()
            }
        }

        // Cleanup
        for token in tokens {
            center.removeObserver(token)
        }

        #expect(tokens.count == 10)
    }

    @Test("Concurrent post and observe")
    func concurrentPostAndObserve() async throws {
        let center = DarwinNotificationCenter.shared
        let counter = LockedValue(0)

        let token = center.addObserver(for: "test.concurrentPost") {
            counter.increment()
        }

        defer {
            center.removeObserver(token)
        }

        // Post multiple times concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    center.post(name: "test.concurrentPost")
                }
            }
        }

        // Wait for callbacks
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Should have received at least some notifications
        #expect(counter.getValue() >= 1)
    }

    // MARK: - ObserverToken Tests

    @Test("ObserverToken is Hashable")
    func tokenIsHashable() {
        let token1 = DarwinNotificationCenter.ObserverToken(id: UUID(), name: "a")
        let token2 = DarwinNotificationCenter.ObserverToken(id: UUID(), name: "b")

        var set: Set<DarwinNotificationCenter.ObserverToken> = []
        set.insert(token1)
        set.insert(token2)

        #expect(set.count == 2)
    }

    @Test("ObserverToken equality based on id")
    func tokenEquality() {
        let id = UUID()
        let token1 = DarwinNotificationCenter.ObserverToken(id: id, name: "a")
        let token2 = DarwinNotificationCenter.ObserverToken(id: id, name: "a")
        let token3 = DarwinNotificationCenter.ObserverToken(id: UUID(), name: "a")

        #expect(token1 == token2)
        #expect(token1 != token3)
    }
}

// MARK: - Test Helpers

/// A thread-safe value wrapper for testing
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
