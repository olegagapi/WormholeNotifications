# Wormhole: Modern Swift Rewrite Plan

A complete Swift rewrite of MMWormhole for iOS 15+, using modern concurrency, TDD approach, and Swift Package Manager.

## Overview

**Current State:** Objective-C library using NSKeyedArchiver, Darwin notifications, and NSCoding
**Target State:** Swift 5.9+ library using Codable, async/await, actors, and AsyncSequence

**Implementation Status:** All Phases Complete (127 tests passing)

---

## Package Structure

```
Wormhole/
├── Package.swift
├── Sources/
│   └── Wormhole/
│       ├── Core/
│       │   ├── Wormhole.swift                    # Main actor-based API
│       │   ├── WormholeConfiguration.swift       # Configuration types
│       │   ├── WormholeError.swift               # Error definitions
│       │   └── MessageIdentifier.swift           # Type-safe identifiers
│       ├── Transiting/
│       │   ├── TransitingStrategy.swift          # Protocol definition
│       │   ├── FileTransiting.swift              # File-based storage
│       │   ├── CoordinatedFileTransiting.swift   # NSFileCoordinator variant
│       │   └── UserDefaultsTransiting.swift      # UserDefaults with app groups
│       ├── Notification/
│       │   └── DarwinNotificationCenter.swift    # CFNotificationCenter wrapper
│       └── Serialization/
│           ├── MessageSerializer.swift           # Serialization protocol
│           └── JSONSerializer.swift              # Default JSON implementation
├── Tests/
│   └── WormholeTests/
│       ├── Core/
│       ├── Transiting/
│       ├── Notification/
│       ├── Integration/
│       └── Mocks/
└── README.md
```

---

## Core API Design

### Main Wormhole Actor

```swift
@available(iOS 15.0, *)
public actor Wormhole {

    // MARK: - Initialization
    public init(appGroupIdentifier: String, directory: String? = nil) throws
    public init(configuration: Configuration) throws

    // MARK: - Sending Messages
    public func send<T: Codable & Sendable>(_ message: T, to identifier: MessageIdentifier) async throws
    public func signal(_ identifier: MessageIdentifier) async throws

    // MARK: - Reading Messages
    public func message<T: Codable>(_ type: T.Type, for identifier: MessageIdentifier) async throws -> T?

    // MARK: - Listening (AsyncSequence - Primary)
    public func messages<T: Codable & Sendable>(_ type: T.Type, for identifier: MessageIdentifier) -> AsyncThrowingStream<T, Error>

    // MARK: - Listening (Callback - Convenience)
    public func listen<T: Codable & Sendable>(for identifier: MessageIdentifier, as type: T.Type, handler: @escaping @Sendable (T) -> Void) -> ListenerToken
    public func stopListening(_ token: ListenerToken)

    // MARK: - Cleanup
    public func clearMessage(for identifier: MessageIdentifier) async throws
    public func clearAllMessages() async throws
}
```

### Supporting Types

```swift
// Type-safe message identifiers
public struct MessageIdentifier: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String
}

// Configuration
public struct Configuration: Sendable {
    public let appGroupIdentifier: String
    public let directory: String?
    public let transitingStrategy: TransitingType
    public let serializationFormat: SerializationFormat
}

public enum TransitingType: Sendable {
    case file
    case coordinatedFile
    case userDefaults
}

// Listener management
public struct ListenerToken: Hashable, Sendable {
    internal let id: UUID
    internal let identifier: MessageIdentifier
}
```

### Transiting Protocol

```swift
public protocol TransitingStrategy: Actor {
    func write(_ data: Data, for identifier: MessageIdentifier) async throws -> Bool
    func read(for identifier: MessageIdentifier) async throws -> Data?
    func delete(for identifier: MessageIdentifier) async throws
    func deleteAll() async throws
}
```

---

## Implementation Phases (TDD)

### Phase 1: Foundation (Tests First) ✅ COMPLETE

**1.1 Core Types**
- [x] Write tests for `MessageIdentifier` (equality, hashing, string literal init)
- [x] Write tests for `WormholeError` (all cases, LocalizedError)
- [x] Write tests for `Configuration` (defaults, validation)
- [x] Implement types to pass tests

**1.2 Serialization**
- [x] Write tests for `JSONSerializer` encode/decode
- [x] Write round-trip tests for common Codable types
- [x] Write error handling tests (malformed data)
- [x] Implement `MessageSerializer` protocol and `JSONSerializer`

### Phase 2: Transiting Strategies (Tests First) ✅ COMPLETE

**2.1 FileTransiting**
- [x] Write tests: directory creation
- [x] Write tests: file path generation (`.message` extension)
- [x] Write tests: write/read round-trip
- [x] Write tests: delete individual message
- [x] Write tests: delete all messages
- [x] Write tests: concurrent access
- [x] Implement `FileTransiting` actor

**2.2 CoordinatedFileTransiting**
- [x] Write tests: NSFileCoordinator integration
- [x] Write tests: concurrent access safety
- [x] Implement `CoordinatedFileTransiting` actor

**2.3 UserDefaultsTransiting**
- [x] Write tests: basic write/read
- [x] Write tests: key prefix isolation
- [x] Write tests: delete operations
- [x] Implement `UserDefaultsTransiting` actor

### Phase 3: Darwin Notification Bridge (Tests First) ✅ COMPLETE

**3.1 DarwinNotificationCenter**
- [x] Write tests: observer registration/removal
- [x] Write tests: multiple observers for same name
- [x] Write tests: notification callback invocation
- [x] Implement `DarwinNotificationCenter` wrapper

### Phase 4: Core Wormhole Actor (Tests First) ✅ COMPLETE

**4.1 Basic Operations**
- [x] Write tests: send Codable message
- [x] Write tests: read message
- [x] Write tests: signal (no payload)
- [x] Write tests: clear message
- [x] Write tests: clear all messages
- [x] Implement basic Wormhole operations

**4.2 Listening**
- [x] Write tests: AsyncSequence message stream
- [x] Write tests: callback-based listener
- [x] Write tests: stop listening
- [x] Write tests: multiple listeners same identifier
- [x] Implement listening functionality

**4.3 Integration**
- [x] Write tests: full round-trip (send -> notify -> receive)
- [x] Write tests: multiple wormhole instances
- [ ] Write performance benchmarks

### Phase 5: Documentation & Polish ✅ COMPLETE

- [x] README with usage examples
- [x] Migration guide from Objective-C
- [x] Example project
- [x] Removed legacy Objective-C code
- [x] Updated CHANGELOG.md

---

## Thread Safety Strategy

| Component | Isolation | Rationale |
|-----------|-----------|-----------|
| `Wormhole` | Actor | Manages listeners dictionary |
| `FileTransiting` | Actor | Serializes file operations |
| `CoordinatedFileTransiting` | Actor | NSFileCoordinator provides coordination |
| `UserDefaultsTransiting` | Actor | Consistency with other strategies |
| `DarwinNotificationCenter` | NSLock | C callbacks require synchronous access |
| `MessageSerializer` | Sendable | Stateless, thread-safe by design |

---

## Package.swift

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Wormhole",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "Wormhole", targets: ["Wormhole"])
    ],
    targets: [
        .target(name: "Wormhole", path: "Sources/Wormhole"),
        .testTarget(name: "WormholeTests", dependencies: ["Wormhole"], path: "Tests/WormholeTests")
    ]
)
```

---

## API Migration Reference

| Objective-C | Swift |
|-------------|-------|
| `initWithApplicationGroupIdentifier:optionalDirectory:` | `init(appGroupIdentifier:directory:)` |
| `passMessageObject:identifier:` | `send(_:to:) async throws` |
| `messageWithIdentifier:` | `message(_:for:) async throws` |
| `listenForMessageWithIdentifier:listener:` | `messages(_:for:)` / `listen(for:as:handler:)` |
| `stopListeningForMessageWithIdentifier:` | `stopListening(_:)` |
| `clearMessageContentsForIdentifier:` | `clearMessage(for:) async throws` |
| `clearAllMessageContents` | `clearAllMessages() async throws` |

---

## Usage Example

```swift
// Define message types
struct CounterUpdate: Codable, Sendable {
    let count: Int
    let timestamp: Date
}

// Initialize
let wormhole = try Wormhole(appGroupIdentifier: "group.com.example.app")

// Send from app
try await wormhole.send(CounterUpdate(count: 42, timestamp: .now), to: "counter")

// Receive in extension (AsyncSequence)
for try await update in wormhole.messages(CounterUpdate.self, for: "counter") {
    print("Count: \(update.count)")
}

// Or callback-based
let token = wormhole.listen(for: "counter", as: CounterUpdate.self) { update in
    print("Count: \(update.count)")
}
wormhole.stopListening(token)
```

---

## Key Files to Reference

- `Source/MMWormhole.h` - Core API patterns
- `Source/MMWormhole.m` - Darwin notification implementation
- `Source/MMWormholeFileTransiting.m` - File storage patterns
- `Example/MMWormhole/MMWormholeTests/` - Test patterns

---

## Verification Plan

1. **Unit Tests**: Run `swift test` - all tests must pass ✅ (127 tests passing)
2. **Integration Test**: Create test app + widget using the library
3. **Manual Test**: Send message from app, verify receipt in widget
4. **Performance**: Compare benchmarks with original Objective-C implementation
