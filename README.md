# Core Package

This package contains base architectural components for MagicPixel application.

## Modules

### Arch
Architecture layer containing core components for implementing Redux-like architecture pattern:

- **Reducer** - Protocol for handling events and state changes
- **EffectHandler** - Protocol for handling side effects
- **ViewStore** - Main class for connecting UI and business logic

## Usage

```swift
import Arch

// Creating ViewStore
let viewStore = ViewStore(
    initial: initialState,
    reducer: myReducer,
    effectHandler: myEffectHandler
)

// Dispatching events
viewStore.handle(event)
```

## Testing

To run tests:

```bash
swift test
```

## Dependencies

- Swift 5.10+
- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+ 