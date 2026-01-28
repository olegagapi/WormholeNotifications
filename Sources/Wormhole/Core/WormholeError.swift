import Foundation

/// Errors that can occur during Wormhole operations.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public enum WormholeError: Error, Sendable {

    /// The app group identifier is invalid or the app group container could not be accessed.
    ///
    /// This typically occurs when:
    /// - The identifier doesn't match any configured app group
    /// - The app hasn't been signed with the appropriate entitlements
    /// - The app group container doesn't exist
    case invalidAppGroupIdentifier(String)

    /// Failed to create the message storage directory.
    ///
    /// The associated error contains details about the filesystem failure.
    case directoryCreationFailed(Error)

    /// Failed to serialize a message for storage.
    ///
    /// The associated error contains details about the encoding failure.
    case serializationFailed(Error)

    /// Failed to deserialize a message from storage.
    ///
    /// The associated error contains details about the decoding failure.
    case deserializationFailed(Error)

    /// Failed to write message data to storage.
    ///
    /// The associated error contains details about the write failure.
    case writeFailed(Error)

    /// Failed to read message data from storage.
    ///
    /// The associated error contains details about the read failure.
    case readFailed(Error)

    /// Failed to register for Darwin notifications.
    ///
    /// The associated string is the notification name that failed to register.
    case notificationRegistrationFailed(String)
}

// MARK: - LocalizedError

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
extension WormholeError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .invalidAppGroupIdentifier(let identifier):
            return "Invalid app group identifier: '\(identifier)'. Ensure the app group is properly configured in your entitlements."

        case .directoryCreationFailed(let error):
            return "Failed to create message storage directory: \(error.localizedDescription)"

        case .serializationFailed(let error):
            return "Failed to encode message: \(error.localizedDescription)"

        case .deserializationFailed(let error):
            return "Failed to decode message: \(error.localizedDescription)"

        case .writeFailed(let error):
            return "Failed to write message to storage: \(error.localizedDescription)"

        case .readFailed(let error):
            return "Failed to read message from storage: \(error.localizedDescription)"

        case .notificationRegistrationFailed(let name):
            return "Failed to register for notification: '\(name)'"
        }
    }
}
