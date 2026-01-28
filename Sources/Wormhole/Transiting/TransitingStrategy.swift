import Foundation

/// A protocol defining how messages are persisted between processes.
///
/// Transiting strategies handle the storage and retrieval of message data
/// in a location accessible to both the main app and its extensions.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public protocol TransitingStrategy: Actor {

    /// Writes message data for the given identifier.
    ///
    /// - Parameters:
    ///   - data: The serialized message data to write.
    ///   - identifier: The message identifier.
    /// - Returns: `true` if the write succeeded, `false` otherwise.
    /// - Throws: A `WormholeError` if the write fails.
    @discardableResult
    func write(_ data: Data, for identifier: MessageIdentifier) async throws -> Bool

    /// Reads message data for the given identifier.
    ///
    /// - Parameter identifier: The message identifier.
    /// - Returns: The stored data, or `nil` if no message exists.
    /// - Throws: A `WormholeError` if the read fails.
    func read(for identifier: MessageIdentifier) async throws -> Data?

    /// Deletes the message for the given identifier.
    ///
    /// - Parameter identifier: The message identifier.
    /// - Throws: A `WormholeError` if the deletion fails.
    func delete(for identifier: MessageIdentifier) async throws

    /// Deletes all stored messages.
    ///
    /// - Throws: A `WormholeError` if the deletion fails.
    func deleteAll() async throws
}
