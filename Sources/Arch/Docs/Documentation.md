# Arch Architecture

## Overview

Arch is a unidirectional data flow architecture implementation for iOS applications in Swift. The architecture is based on Redux/Elm Architecture principles and provides predictable state management for applications.

## Core Components

### 1. State
Represents the current state of the application or part of the application. Must conform to the `Equatable` protocol for state comparison.

### 2. Event
Describes user actions or system actions that can change the state. Must conform to the `Equatable` protocol.

### 3. Effect
Describes side effects (API calls, navigation, file operations, etc.) that can occur as a result of event processing. Must conform to the `Equatable` protocol.

## Protocols

### Reducer

```swift
public protocol Reducer<State, Event, Effect> {
    associatedtype State: Equatable
    associatedtype Event: Equatable
    associatedtype Effect: Equatable
    
    func reduce(_ state: inout State, _ event: Event) -> Effect?
}
```

**Purpose**: A pure function that receives the current state and event, modifies the state, and can return an effect for execution.

**Parameters**:
- `state`: Current state (passed by reference for modification)
- `event`: Event to process

**Returns**: Optional effect for execution

**Principles**:
- Function should be pure (no side effects)
- All state changes occur synchronously
- Side effects are extracted into separate Effect

### EffectHandler

```swift
public protocol EffectHandler<Effect, Event> {
    associatedtype Effect: Equatable
    associatedtype Event: Equatable

    func handle(_ effect: Effect, _ dispatch: @escaping @Sendable (Event) -> Void)
}
```

**Purpose**: Handles side effects and can generate new events.

**Parameters**:
- `effect`: Effect to handle
- `dispatch`: Callback function for dispatching new events

**Principles**:
- Handles asynchronous operations
- Can generate new events through dispatch
- Isolates side effects from main logic

## Main Class

### ViewStore

```swift
public final class ViewStore<State, Event, Effect, R, E>: ObservableObject, @unchecked Sendable
```

**Purpose**: The central component of the architecture that connects all parts together.

**Properties**:
- `state`: Current state (public, read-only)
- `reducer`: Reducer for processing events
- `effectHandler`: Effect handler

**Methods**:
- `init(initial:reducer:effectHandler:)`: Initialization with initial state
- `handle(_:)`: Event processing

**Features**:
- Inherits from `ObservableObject` for SwiftUI integration
- Marked as `@unchecked Sendable` for concurrent code support
- Implements `Equatable` and `Hashable` for comparison and hashing

## Data Flow

1. **Event** → ViewStore receives event through `handle(_:)`
2. **Reduction** → Reducer changes state and returns effect
3. **UI Update** → New state is published through `@Published`
4. **Effect Handling** → EffectHandler executes side effects
5. **New Events** → EffectHandler can generate new events

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Event     │───▶│   Reducer   │───▶│   Effect    │
└─────────────┘    └─────────────┘    └─────────────┘
                            │                   │
                            ▼                   ▼
                    ┌─────────────┐    ┌─────────────┐
                    │    State    │    │EffectHandler│
                    └─────────────┘    └─────────────┘
                            ▲                   │
                            │                   │
                            └───────────────────┘
```

## Architecture Benefits

1. **Predictability**: All state changes occur through a single entry point
2. **Testability**: Pure functions are easy to test
3. **Debugging**: Easy to trace data flow and state changes
4. **Modularity**: Components are loosely coupled and easily replaceable
5. **Scalability**: Architecture scales well for large applications

## Usage Example

```swift
// State definition
struct AppState: Equatable {
    var counter: Int = 0
    var isLoading: Bool = false
}

// Event definition
enum AppEvent: Equatable {
    case increment
    case decrement
    case loadData
    case dataLoaded(String)
}

// Effect definition
enum AppEffect: Equatable {
    case loadDataFromAPI
}

// Reducer implementation
struct AppReducer: Reducer {
    func reduce(_ state: inout AppState, _ event: AppEvent) -> AppEffect? {
        switch event {
        case .increment:
            state.counter += 1
            return nil
        case .decrement:
            state.counter -= 1
            return nil
        case .loadData:
            state.isLoading = true
            return .loadDataFromAPI
        case .dataLoaded:
            state.isLoading = false
            return nil
        }
    }
}

// Effect handler implementation
struct AppEffectHandler: EffectHandler {
    func handle(_ effect: AppEffect, _ dispatch: @escaping @Sendable (AppEvent) -> Void) {
        switch effect {
        case .loadDataFromAPI:
            // Asynchronous data loading
            Task {
                let data = await loadDataFromServer()
                dispatch(.dataLoaded(data))
            }
        }
    }
}

// Usage
let viewStore = ViewStore(
    initial: AppState(),
    reducer: AppReducer(),
    effectHandler: AppEffectHandler()
)
```

## Recommendations

1. **Keep state minimal**: Include only necessary data
2. **Use enum for events**: This makes code more type-safe
3. **Group related effects**: Create separate enums for different modules
4. **Test reducers**: This is the most important part for testing
5. **Isolate side effects**: All asynchronous logic should be in EffectHandler

## SwiftUI Integration

ViewStore implements `ObservableObject`, which allows easy integration with SwiftUI:

```swift
struct ContentView: View {
    @StateObject private var viewStore = ViewStore(...)
    
    var body: some View {
        VStack {
            Text("Counter: \(viewStore.state.counter)")
            Button("Increment") {
                viewStore.handle(.increment)
            }
        }
    }
}
```

## Conclusion

The Arch architecture provides a clear and predictable structure for state management in iOS applications. It combines the best practices of functional programming with Swift and SwiftUI capabilities. 