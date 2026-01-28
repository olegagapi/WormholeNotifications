import Foundation

/// A token representing an active listener registration.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public struct ListenerToken: Hashable, Sendable {
    internal let id: UUID
    internal let identifier: MessageIdentifier

    internal init(id: UUID = UUID(), identifier: MessageIdentifier) {
        self.id = id
        self.identifier = identifier
    }
}

/// A modern Swift actor for inter-process communication between an app and its extensions.
///
/// Wormhole provides a simple API for sending and receiving messages between your app
/// and its extensions (Today widgets, Watch apps, etc.) using app groups.
///
/// ## Usage
///
/// ```swift
/// // Define a message type
/// struct CounterUpdate: Codable, Sendable {
///     let count: Int
/// }
///
/// // Initialize with your app group
/// let wormhole = try Wormhole(appGroupIdentifier: "group.com.example.app")
///
/// // Send a message
/// try await wormhole.send(CounterUpdate(count: 42), to: "counter")
///
/// // Receive messages
/// for try await update in wormhole.messages(CounterUpdate.self, for: "counter") {
///     print("Count: \(update.count)")
/// }
/// ```
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public actor Wormhole {

    // MARK: - Properties

    private let transiting: any TransitingStrategy
    private let serializer: MessageSerializer
    private let notificationCenter: DarwinNotificationCenter
    private let notificationPrefix: String

    private var listeners: [MessageIdentifier: [ListenerRegistration]] = [:]
    private var darwinTokens: [MessageIdentifier: DarwinNotificationCenter.ObserverToken] = [:]
    private var typedStreamContinuations: [MessageIdentifier: [UUID: StreamContinuationWrapper]] = [:]

    // MARK: - Initialization

    /// Creates a Wormhole with the specified app group identifier.
    ///
    /// - Parameters:
    ///   - appGroupIdentifier: The app group identifier for shared storage.
    ///   - directory: Optional subdirectory within the app group container.
    /// - Throws: `WormholeError.invalidAppGroupIdentifier` if the app group cannot be accessed.
    public init(appGroupIdentifier: String, directory: String? = nil) throws {
        self.transiting = try FileTransiting(appGroupIdentifier: appGroupIdentifier, subdirectory: directory)
        self.serializer = JSONSerializer()
        self.notificationCenter = DarwinNotificationCenter.shared
        self.notificationPrefix = appGroupIdentifier
    }

    /// Creates a Wormhole with the specified configuration.
    ///
    /// - Parameter configuration: The configuration options.
    /// - Throws: `WormholeError` if initialization fails.
    public init(configuration: Configuration) throws {
        switch configuration.transitingStrategy {
        case .file:
            self.transiting = try FileTransiting(
                appGroupIdentifier: configuration.appGroupIdentifier,
                subdirectory: configuration.directory
            )
        case .coordinatedFile:
            self.transiting = try CoordinatedFileTransiting(
                appGroupIdentifier: configuration.appGroupIdentifier,
                subdirectory: configuration.directory
            )
        case .userDefaults:
            self.transiting = UserDefaultsTransiting(appGroupIdentifier: configuration.appGroupIdentifier)
        }

        self.serializer = JSONSerializer()
        self.notificationCenter = DarwinNotificationCenter.shared
        self.notificationPrefix = configuration.appGroupIdentifier
    }

    /// Creates a Wormhole with a specific directory (for testing).
    ///
    /// - Parameter directory: The directory URL for message storage.
    public init(directory: URL) {
        self.transiting = FileTransiting(directory: directory)
        self.serializer = JSONSerializer()
        self.notificationCenter = DarwinNotificationCenter.shared
        self.notificationPrefix = "wormhole.test"
    }

    // MARK: - Sending Messages

    /// Sends a Codable message to the specified identifier.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - identifier: The message identifier.
    /// - Throws: A `WormholeError` if sending fails.
    public func send<T: Codable & Sendable>(_ message: T, to identifier: MessageIdentifier) async throws {
        let data: Data
        do {
            data = try serializer.encode(message)
        } catch {
            throw WormholeError.serializationFailed(error)
        }

        try await transiting.write(data, for: identifier)
        postNotification(for: identifier)
    }

    /// Sends a signal without payload to the specified identifier.
    ///
    /// Use this when you only need to notify listeners without sending data.
    ///
    /// - Parameter identifier: The message identifier.
    public func signal(_ identifier: MessageIdentifier) {
        postNotification(for: identifier)
    }

    // MARK: - Reading Messages

    /// Reads the current message for the specified identifier.
    ///
    /// - Parameters:
    ///   - type: The type to decode the message as.
    ///   - identifier: The message identifier.
    /// - Returns: The decoded message, or `nil` if no message exists.
    /// - Throws: A `WormholeError` if reading fails.
    public func message<T: Codable>(_ type: T.Type, for identifier: MessageIdentifier) async throws -> T? {
        guard let data = try await transiting.read(for: identifier) else {
            return nil
        }

        do {
            return try serializer.decode(from: data)
        } catch {
            throw WormholeError.deserializationFailed(error)
        }
    }

    // MARK: - Listening (AsyncSequence)

    /// Returns an async stream of messages for the specified identifier.
    ///
    /// - Parameters:
    ///   - type: The type to decode messages as.
    ///   - identifier: The message identifier.
    /// - Returns: An `AsyncThrowingStream` that yields messages as they arrive.
    public func messages<T: Codable & Sendable>(
        _ type: T.Type,
        for identifier: MessageIdentifier
    ) -> AsyncThrowingStream<T, Error> {
        let streamId = UUID()

        return AsyncThrowingStream { continuation in
            // Register with stream continuations
            Task {
                await self.registerStreamContinuation(
                    id: streamId,
                    for: identifier,
                    continuation: continuation,
                    decoder: { data in
                        try self.serializer.decode(from: data) as T
                    }
                )
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.unregisterStreamContinuation(id: streamId, for: identifier)
                }
            }
        }
    }

    private func registerStreamContinuation<T>(
        id: UUID,
        for identifier: MessageIdentifier,
        continuation: AsyncThrowingStream<T, Error>.Continuation,
        decoder: @escaping (Data) throws -> T
    ) {
        // Store a wrapper that decodes and yields
        let wrapper = StreamContinuationWrapper { [weak self] data in
            guard self != nil else { return }
            do {
                let decoded = try decoder(data)
                continuation.yield(decoded)
            } catch {
                continuation.finish(throwing: error)
            }
        }

        if typedStreamContinuations[identifier] == nil {
            typedStreamContinuations[identifier] = [:]
        }
        typedStreamContinuations[identifier]?[id] = wrapper

        // Set up Darwin notification observer if needed
        if darwinTokens[identifier] == nil {
            let token = notificationCenter.addObserver(for: notificationName(for: identifier)) { [weak self] in
                Task { [weak self] in
                    await self?.handleNotification(for: identifier)
                }
            }
            darwinTokens[identifier] = token
        }
    }

    private func unregisterStreamContinuation(id: UUID, for identifier: MessageIdentifier) {
        typedStreamContinuations[identifier]?.removeValue(forKey: id)

        // Clean up Darwin observer if no more listeners
        if (typedStreamContinuations[identifier]?.isEmpty ?? true) &&
           (listeners[identifier]?.isEmpty ?? true) {
            typedStreamContinuations.removeValue(forKey: identifier)
            if let darwinToken = darwinTokens.removeValue(forKey: identifier) {
                notificationCenter.removeObserver(darwinToken)
            }
        }
    }

    // MARK: - Listening (Callback)

    /// Registers a listener for messages at the specified identifier.
    ///
    /// - Parameters:
    ///   - identifier: The message identifier.
    ///   - type: The type to decode messages as.
    ///   - handler: The closure to invoke when a message is received.
    /// - Returns: A token that can be used to stop listening.
    public func listen<T: Codable & Sendable>(
        for identifier: MessageIdentifier,
        as type: T.Type,
        handler: @escaping @Sendable (T) -> Void
    ) -> ListenerToken {
        let token = ListenerToken(identifier: identifier)

        let registration = ListenerRegistration(token: token) { [weak self] in
            guard let self = self else { return }
            Task {
                if let data = try? await self.transiting.read(for: identifier),
                   let message: T = try? self.serializer.decode(from: data) {
                    handler(message)
                }
            }
        }

        if listeners[identifier] == nil {
            listeners[identifier] = []
        }
        listeners[identifier]?.append(registration)

        // Set up Darwin notification if needed
        if darwinTokens[identifier] == nil {
            let darwinToken = notificationCenter.addObserver(for: notificationName(for: identifier)) { [weak self] in
                Task { [weak self] in
                    await self?.handleNotification(for: identifier)
                }
            }
            darwinTokens[identifier] = darwinToken
        }

        return token
    }

    /// Stops listening for messages with the specified token.
    ///
    /// - Parameter token: The token returned when listening was started.
    public func stopListening(_ token: ListenerToken) {
        listeners[token.identifier]?.removeAll { $0.token == token }

        // Remove Darwin observer if no more listeners
        if listeners[token.identifier]?.isEmpty ?? true {
            listeners.removeValue(forKey: token.identifier)
            if let darwinToken = darwinTokens.removeValue(forKey: token.identifier) {
                notificationCenter.removeObserver(darwinToken)
            }
        }
    }

    // MARK: - Cleanup

    /// Clears the message for the specified identifier.
    ///
    /// - Parameter identifier: The message identifier.
    /// - Throws: A `WormholeError` if clearing fails.
    public func clearMessage(for identifier: MessageIdentifier) async throws {
        try await transiting.delete(for: identifier)
    }

    /// Clears all stored messages.
    ///
    /// - Throws: A `WormholeError` if clearing fails.
    public func clearAllMessages() async throws {
        try await transiting.deleteAll()
    }

    // MARK: - Internal (for testing)

    /// Notifies listeners for a specific identifier (exposed for testing).
    internal func notifyListeners(for identifier: MessageIdentifier) {
        handleNotification(for: identifier)
    }

    // MARK: - Private

    private func notificationName(for identifier: MessageIdentifier) -> String {
        "\(notificationPrefix).\(identifier.rawValue)"
    }

    private func postNotification(for identifier: MessageIdentifier) {
        notificationCenter.post(name: notificationName(for: identifier))
    }

    private func handleNotification(for identifier: MessageIdentifier) {
        // Notify callback listeners
        listeners[identifier]?.forEach { $0.callback() }

        // Notify stream listeners
        Task {
            if let data = try? await transiting.read(for: identifier) {
                typedStreamContinuations[identifier]?.values.forEach { wrapper in
                    wrapper.yield(data)
                }
            }
        }
    }
}

// MARK: - Supporting Types

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
private struct ListenerRegistration {
    let token: ListenerToken
    let callback: @Sendable () -> Void
}

/// A type-erased wrapper for stream continuations that handles decoding.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
private struct StreamContinuationWrapper: Sendable {
    private let _yield: @Sendable (Data) -> Void

    init(yield: @escaping @Sendable (Data) -> Void) {
        self._yield = yield
    }

    func yield(_ data: Data) {
        _yield(data)
    }
}
