import Foundation

/// A message containing a counter value shared between app and widget.
struct CounterMessage: Codable, Sendable {
    let count: Int
    let updatedAt: Date

    init(count: Int, updatedAt: Date = .now) {
        self.count = count
        self.updatedAt = updatedAt
    }
}

/// A text message sent from the app to the widget.
struct TextMessage: Codable, Sendable {
    let text: String
    let sentAt: Date

    init(text: String, sentAt: Date = .now) {
        self.text = text
        self.sentAt = sentAt
    }
}

/// Message identifiers used for communication.
enum MessageID {
    static let counter = "counter"
    static let textFromApp = "textFromApp"
    static let textFromWidget = "textFromWidget"
}

/// The app group identifier shared between the app and widget.
///
/// **Important:** You must replace this with your own app group identifier
/// configured in your Apple Developer account and Xcode project capabilities.
let appGroupIdentifier = "group.com.example.wormholedemo"
