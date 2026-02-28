# Core Package

This package contains base architectural components for MagicPixel application.

## Modules

### Arch
Architecture layer containing core components for implementing Redux-like architecture pattern:

- **Reducer** - Protocol for handling events and state changes
- **EffectHandler** - Protocol for handling side effects
- **ViewStore** - Main class for connecting UI and business logic

### ArchAsync
Swift Concurrency version of Arch with async/await, AsyncStream for effects, and @Observable:

- **Reducer** - Protocol with Sendable types
- **EffectHandler** - Protocol with `events: AsyncStream<Event>` and `handle(_ effect:)`
- **ViewStore** - @MainActor, @Observable class for SwiftUI integration

Requires iOS 17+, macOS 14+, tvOS 17+, watchOS 10+.

## Usage

### Arch (callback-based)
```swift
import Arch

let viewStore = ViewStore(
    initial: initialState,
    reducer: myReducer,
    effectHandler: myEffectHandler
)
viewStore.handle(event)
```

### ArchAsync (Swift Concurrency)
```swift
import ArchAsync

@MainActor
let viewStore = ViewStore(
    initial: initialState,
    reducer: myReducer,
    effectHandler: myEffectHandler
)
viewStore.handle(event)
```

## Testing

To run tests:

```bash
swift test
```

## Dependencies

- Swift 5.10+
- iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ (package-level platforms for ArchAsync) 