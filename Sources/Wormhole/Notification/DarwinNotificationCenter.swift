import Foundation

/// A Swift wrapper around CFNotificationCenter for Darwin notifications.
///
/// Darwin notifications are the mechanism used to signal between processes
/// on iOS/macOS. They are lightweight signals that don't carry payload data.
///
/// - Note: This class uses `NSLock` for thread safety because Darwin notification
///   callbacks are invoked synchronously from C and cannot use Swift concurrency.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public final class DarwinNotificationCenter: @unchecked Sendable {

    /// The shared Darwin notification center.
    public static let shared = DarwinNotificationCenter()

    /// A token returned when registering an observer.
    public struct ObserverToken: Hashable, Sendable {
        /// The unique identifier for this observer.
        public let id: UUID

        /// The notification name this observer is registered for.
        public let name: String

        /// Creates a new observer token.
        public init(id: UUID, name: String) {
            self.id = id
            self.name = name
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        public static func == (lhs: ObserverToken, rhs: ObserverToken) -> Bool {
            lhs.id == rhs.id
        }
    }

    private struct Observer {
        let token: ObserverToken
        let callback: @Sendable () -> Void
    }

    private var observers: [String: [Observer]] = [:]
    private let lock = NSLock()

    private init() {}

    /// Adds an observer for a Darwin notification.
    ///
    /// - Parameters:
    ///   - name: The notification name to observe.
    ///   - callback: The closure to invoke when the notification is received.
    /// - Returns: A token that can be used to remove the observer.
    @discardableResult
    public func addObserver(
        for name: String,
        callback: @escaping @Sendable () -> Void
    ) -> ObserverToken {
        let token = ObserverToken(id: UUID(), name: name)
        let observer = Observer(token: token, callback: callback)

        lock.lock()
        let isFirstObserverForName = observers[name] == nil || observers[name]!.isEmpty
        if observers[name] == nil {
            observers[name] = []
        }
        observers[name]!.append(observer)
        lock.unlock()

        // Only register with CFNotificationCenter if this is the first observer for this name
        if isFirstObserverForName {
            registerWithDarwin(name: name)
        }

        return token
    }

    /// Removes an observer.
    ///
    /// - Parameter token: The token returned when the observer was added.
    public func removeObserver(_ token: ObserverToken) {
        lock.lock()
        if var nameObservers = observers[token.name] {
            nameObservers.removeAll { $0.token == token }
            if nameObservers.isEmpty {
                observers.removeValue(forKey: token.name)
                lock.unlock()
                unregisterWithDarwin(name: token.name)
            } else {
                observers[token.name] = nameObservers
                lock.unlock()
            }
        } else {
            lock.unlock()
        }
    }

    /// Posts a Darwin notification.
    ///
    /// - Parameter name: The notification name to post.
    public func post(name: String) {
        let cfName = name as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(cfName),
            nil,
            nil,
            true
        )
    }

    // MARK: - Internal for Testing

    /// Invokes all callbacks for a notification name.
    internal func notifyObservers(for name: String) {
        lock.lock()
        let callbacks = observers[name]?.map { $0.callback } ?? []
        lock.unlock()

        for callback in callbacks {
            callback()
        }
    }

    // MARK: - Private

    private func registerWithDarwin(name: String) {
        let cfName = name as CFString

        // Store self as an unretained pointer for the callback
        let observer = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, name, _, _ in
                guard let observer = observer,
                      let name = name?.rawValue as String? else {
                    return
                }

                let center = Unmanaged<DarwinNotificationCenter>
                    .fromOpaque(observer)
                    .takeUnretainedValue()

                center.notifyObservers(for: name)
            },
            cfName,
            nil,
            .deliverImmediately
        )
    }

    private func unregisterWithDarwin(name: String) {
        let cfName = name as CFString
        let observer = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            CFNotificationName(cfName),
            nil
        )
    }
}
