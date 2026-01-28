import Foundation

/// A type-safe identifier for messages sent through the Wormhole.
///
/// Message identifiers serve as unique keys for storing and retrieving messages
/// between an app and its extensions. They can be created from string literals
/// for convenience.
///
/// ```swift
/// let counter: MessageIdentifier = "counter"
/// let update = MessageIdentifier(rawValue: "status.update")
/// ```
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public struct MessageIdentifier: RawRepresentable, Hashable, Sendable {

    /// The underlying string value of the identifier.
    public let rawValue: String

    /// Creates a message identifier with the given raw value.
    ///
    /// - Parameter rawValue: The string to use as the identifier.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByStringLiteral

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
extension MessageIdentifier: ExpressibleByStringLiteral {

    /// Creates a message identifier from a string literal.
    ///
    /// - Parameter value: The string literal to use as the identifier.
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
extension MessageIdentifier: CustomStringConvertible {

    public var description: String {
        rawValue
    }
}
