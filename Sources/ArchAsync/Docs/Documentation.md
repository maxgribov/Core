# ArchAsync Architecture

## Overview

ArchAsync is an async/await-based variant of the Arch unidirectional data flow architecture for iOS applications in Swift. It uses `AsyncStream` for effect-to-event communication instead of callbacks and Swift Observation (`@Observable`) for UI binding. The architecture is designed for modern Swift Concurrency and provides predictable state management with native async support.

## Core Components

### 1. State
Represents the current state of the application or part of the application. Must conform to `Sendable` for safe concurrent use.

### 2. Event
Describes user actions or system actions that can change the state. Must conform to `Sendable`.

### 3. Effect
Describes side effects (API calls, navigation, file operations, etc.) that can occur as a result of event processing. Must conform to `Sendable`.

## Protocols

### Reducer

```swift
public protocol Reducer<State, Event, Effect>: Sendable {
    associatedtype State
    associatedtype Event
    associatedtype Effect

    func reduce(_ state: inout State, _ event: Event) -> Effect?
}
```

**Purpose**: A pure function that receives the current state and event, modifies the state, and can return an effect for execution.

**Sendable**: The protocol requires `Sendable` conformance because the reducer is captured by `ViewStore` and used across concurrency boundaries.

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
public protocol EffectHandler<Effect, Event>: Sendable {
    associatedtype Effect
    associatedtype Event

    func handle(_ effect: Effect) async -> AsyncStream<Event>
}
```

**Purpose**: Handles side effects asynchronously and returns resulting events as an `AsyncStream` per effect.

**Sendable**: Required because effects are handled via `Task.detached`, so the handler is captured across isolation boundaries.

**Requirements**:
- `handle(_:)`: Async method that processes effects and returns an `AsyncStream<Event>` of resulting events

**Principles**:
- Each effect produces its own independent stream of events
- Uses `AsyncStream` for event feedback — no shared stream or continuation boilerplate needed
- Use convenience helpers `AsyncStream.single(_:)` and `AsyncStream.empty` for common cases

## Main Class

### ViewStore

```swift
@MainActor
@Observable
public final class ViewStore<State, Event, Effect, R, E>
where R: Reducer, R.State == State, R.Event == Event, R.Effect == Effect,
      E: EffectHandler, E.Effect == Effect, E.Event == Event,
      State: Sendable, Event: Sendable, Effect: Sendable
```

**Purpose**: The central component of the architecture that connects all parts together. Runs on the main actor for UI updates.

**Constraints**: `State`, `Event`, and `Effect` must all be `Sendable` because they cross concurrency boundaries (effects are handled via `Task.detached`, events arrive from `AsyncStream`).

**Properties**:
- `state`: Current state (public, read-only)
- `reducer`: Reducer for processing events (private)
- `effectHandler`: Effect handler (private)
- `taskBag`: A `TasksBag` instance that tracks all spawned tasks (private)

**Methods**:
- `init(initial:reducer:effectHandler:)`: Initialization with initial state
- `handle(_:)`: Event processing
- `deinit`: Cancels all running tasks via `taskBag.cancelAll()`

**Features**:
- `@MainActor` isolates UI updates to the main thread
- Marked with `@Observable` for SwiftUI integration
- Each effect is handled via `Task.detached`; the returned per-effect stream is iterated in the same task
- Uses `TasksBag` (thread-safe via `NSLock`) to track all spawned tasks
- Cancels all tasks on `deinit`, stopping in-flight effects and stream iteration
- The stream iteration loop checks `Task.isCancelled` to stop promptly on cancellation

### TasksBag

```swift
final class TasksBag: @unchecked Sendable
```

An internal, thread-safe container for tracking spawned `Task` instances. Uses `NSLock` for synchronization. Provides `add(_:)` to register tasks and `cancelAll()` to cancel and remove all tracked tasks.

## Data Flow

1. **Event** → ViewStore receives event through `handle(_:)`
2. **Reduction** → Reducer changes state and returns effect
3. **UI Update** → New state triggers observation, view re-renders
4. **Effect Handling** → EffectHandler executes effect asynchronously (via `Task.detached`) and returns per-effect `AsyncStream<Event>`
5. **Stream Iteration** → ViewStore iterates the returned stream and calls `handle(_:)` for each event

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Event     │───▶│   Reducer   │───▶│   Effect    │
└─────────────┘    └─────────────┘    └─────────────┘
        ▲                   │                   │
        │                   ▼                   ▼
        │           ┌─────────────┐    ┌─────────────┐
        └───────────│    State    │    │EffectHandler│
                    └─────────────┘    └─────────────┘
                                               │
                                               ▼
                                        AsyncStream<Event>
```

## Architecture Benefits

1. **Predictability**: All state changes occur through a single entry point
2. **Testability**: Pure reducer functions are easy to test
3. **Native async**: First-class async/await support without callback nesting
4. **Swift Concurrency**: Designed for structured concurrency and actor isolation
5. **Modern UI**: Uses Swift Observation for efficient view updates
6. **Modularity**: Components are loosely coupled and easily replaceable
7. **Cancellation**: All tasks are automatically cancelled on `ViewStore` deallocation

## Usage Example

```swift
struct AppState: Sendable {
    var counter: Int = 0
    var isLoading: Bool = false
}

enum AppEvent: Sendable {
    case increment
    case decrement
    case loadData
    case dataLoaded(String)
}

enum AppEffect: Sendable {
    case loadDataFromAPI
}

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

final class AppEffectHandler: EffectHandler, Sendable {
    func handle(_ effect: AppEffect) async -> AsyncStream<AppEvent> {
        switch effect {
        case .loadDataFromAPI:
            let data = await loadDataFromServer()
            return .single(.dataLoaded(data))
        }
    }
}

let viewStore = ViewStore(
    initial: AppState(),
    reducer: AppReducer(),
    effectHandler: AppEffectHandler()
)
```

## Recommendations

1. **Sendable types**: State, Event, and Effect must be `Sendable` — this is enforced by the generic constraints on `ViewStore`
2. **Use enum for events**: This makes code more type-safe
3. **Use convenience helpers**: Use `AsyncStream.single(_:)` for effects that produce one event, and `AsyncStream.empty` for effects that produce none
4. **Test reducers**: Pure reduction logic is easy to unit test
5. **Isolate side effects**: All asynchronous logic should be in EffectHandler
6. **Struct reducers**: Prefer `struct` for reducers — they are pure functions with no mutable state

## SwiftUI Integration

ViewStore uses `@Observable`, so pass it directly to views. The view automatically tracks access to `viewStore.state` and re-renders on changes:

```swift
typealias ContentViewStore = ViewStore<AppState, AppEvent, AppEffect, AppReducer, AppEffectHandler>

struct ContentView: View {
    var viewStore: ContentViewStore

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
