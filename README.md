# Wormhole

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2015%20|%20macOS%2012%20|%20watchOS%208-blue.svg)](https://developer.apple.com)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

A modern Swift library for real-time message passing between an iOS/macOS app and its extensions.

## Overview

Wormhole creates a bridge between your app and its extensions (widgets, watch apps, etc.) using shared app groups. Messages are persisted to the shared container and notifications are delivered via Darwin notifications, enabling near-instant communication even when both processes are running simultaneously.

**Key Features:**
- Modern async/await API built on Swift actors
- Type-safe messaging with Codable
- AsyncSequence support for reactive message streams
- Multiple storage strategies (file, coordinated file, UserDefaults)
- Darwin notification-based real-time updates

## Requirements

- iOS 15.0+ / macOS 12.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add Wormhole to your project using Xcode:

1. File > Add Package Dependencies
2. Enter the repository URL
3. Select version requirements

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mutualmobile/MMWormhole.git", from: "3.0.0")
]
```

Then add it as a dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["Wormhole"]
)
```

## Quick Start

### 1. Configure App Groups

Before using Wormhole, configure a shared app group in your app and extension targets:

1. Select your target in Xcode
2. Go to Signing & Capabilities
3. Add the "App Groups" capability
4. Create or select a group (e.g., `group.com.yourcompany.yourapp`)
5. Repeat for your extension target

### 2. Define Message Types

Create Codable types for your messages:

```swift
struct CounterUpdate: Codable, Sendable {
    let count: Int
    let timestamp: Date
}
```

### 3. Send Messages

```swift
import Wormhole

// Initialize with your app group
let wormhole = try Wormhole(appGroupIdentifier: "group.com.yourcompany.yourapp")

// Send a message
try await wormhole.send(CounterUpdate(count: 42, timestamp: .now), to: "counter")
```

### 4. Receive Messages

Using AsyncSequence (recommended):

```swift
for try await update in wormhole.messages(CounterUpdate.self, for: "counter") {
    print("Received count: \(update.count)")
}
```

Or using callbacks:

```swift
let token = wormhole.listen(for: "counter", as: CounterUpdate.self) { update in
    print("Received count: \(update.count)")
}

// Later, when done listening:
wormhole.stopListening(token)
```

## API Reference

### Initialization

```swift
// Simple initialization
let wormhole = try Wormhole(appGroupIdentifier: "group.com.example.app")

// With optional subdirectory
let wormhole = try Wormhole(
    appGroupIdentifier: "group.com.example.app",
    directory: "wormhole"
)

// With full configuration
let config = Configuration(
    appGroupIdentifier: "group.com.example.app",
    directory: "wormhole",
    transitingStrategy: .coordinatedFile
)
let wormhole = try Wormhole(configuration: config)
```

### Sending Messages

```swift
// Send a Codable message
try await wormhole.send(myMessage, to: "identifier")

// Send a signal (notification only, no payload)
wormhole.signal("identifier")
```

### Reading Messages

```swift
// Read the current message (if any)
if let update = try await wormhole.message(CounterUpdate.self, for: "counter") {
    print("Current count: \(update.count)")
}
```

### Listening for Messages

**AsyncSequence (recommended for SwiftUI/async contexts):**

```swift
// Returns an AsyncThrowingStream
for try await message in wormhole.messages(MyMessage.self, for: "identifier") {
    // Handle message
}
```

**Callback-based:**

```swift
let token = wormhole.listen(for: "identifier", as: MyMessage.self) { message in
    // Handle message
}

// Stop listening when done
wormhole.stopListening(token)
```

### Cleanup

```swift
// Clear a specific message
try await wormhole.clearMessage(for: "identifier")

// Clear all messages
try await wormhole.clearAllMessages()
```

## Configuration

### Transiting Strategies

Wormhole supports three storage strategies:

| Strategy | Description | Best For |
|----------|-------------|----------|
| `.file` | Basic file storage (default) | Most use cases |
| `.coordinatedFile` | Uses NSFileCoordinator | Heavy concurrent access |
| `.userDefaults` | Shared UserDefaults | Simple, small messages |

```swift
let config = Configuration(
    appGroupIdentifier: "group.com.example.app",
    transitingStrategy: .coordinatedFile
)
```

### Message Identifiers

Message identifiers are type-safe and support string literals:

```swift
// Using string literals
try await wormhole.send(message, to: "counter")

// Or create explicitly
let identifier = MessageIdentifier("counter")
try await wormhole.send(message, to: identifier)
```

## Migration from MMWormhole (2.x)

If you're upgrading from the Objective-C version:

| MMWormhole 2.x | Wormhole 3.0 |
|----------------|--------------|
| `initWithApplicationGroupIdentifier:optionalDirectory:` | `init(appGroupIdentifier:directory:)` |
| `passMessageObject:identifier:` | `send(_:to:) async throws` |
| `messageWithIdentifier:` | `message(_:for:) async throws` |
| `listenForMessageWithIdentifier:listener:` | `messages(_:for:)` or `listen(for:as:handler:)` |
| `stopListeningForMessageWithIdentifier:` | `stopListening(_:)` |
| `clearMessageContentsForIdentifier:` | `clearMessage(for:) async throws` |
| `clearAllMessageContents` | `clearAllMessages() async throws` |

**Key Differences:**
- All operations are now `async` and require `await`
- Messages must conform to `Codable` (not `NSCoding`)
- JSON serialization replaces `NSKeyedArchiver`
- The API uses Swift actors for thread safety
- WatchConnectivity support has been removed (use file-based transiting)

## Troubleshooting

**Messages not received:**
1. Verify both targets have the same app group in Capabilities
2. Check that all three checkmarks appear in App Groups setup
3. Ensure you're using the correct app group identifier

**Serialization errors:**
1. Verify your message types conform to `Codable`
2. Check that all properties are encodable
3. For custom types, implement `Codable` properly

## License

Wormhole is available under the MIT license. See the [LICENSE](LICENSE) file for details.

## Credits

Wormhole was originally created by [Conrad Stoll](http://conradstoll.com) at [Mutual Mobile](http://www.mutualmobile.com).

Swift 3.0 rewrite with modern concurrency support.
