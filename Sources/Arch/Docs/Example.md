
# Arch Framework Architecture Example

This document provides a minimal, clear example of implementing the Arch architecture pattern based on the MagicPixel application analysis. The example demonstrates a simple Todo application that focuses on core Arch principles and patterns without unnecessary complexity.

## Overview

The Arch framework implements a unidirectional data flow architecture with the following core components:

- **ViewStore**: Central coordinator that manages State, Events, Effects, Reducer, and EffectHandler
- **State**: Immutable data structure representing the current state
- **Event**: User actions and system events
- **Effect**: Side effects that need to be performed
- **Reducer**: Pure function that updates state based on events
- **EffectHandler**: Handles side effects and external interactions

## Core Architecture Pattern

```
View → Event → Reducer → State → View
                    ↓
                 Effect → EffectHandler → External Events
```

## Simple Todo Application Example

### 1. Define the State

```swift
import Foundation
import Arch

enum TodoState: Equatable {
    case idle
    case loading
    case todos([Todo])
    case failure(String)
}

struct Todo: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    
    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}
```

### 2. Define Events

```swift
enum TodoEvent: Equatable {
    case viewDidLoad
    case todosLoaded([Todo])
    case loadingFailed(String)
}
```

### 3. Define Effects

```swift
enum TodoEffect: Equatable {
    case loadTodos
}
```

### 4. Implement the Reducer

```swift
import Arch

final class TodoReducer: Reducer {
    
    func reduce(_ state: inout TodoState, _ event: TodoEvent) -> TodoEffect? {
        switch event {
        case .viewDidLoad:
            state = .loading
            return .loadTodos
            
        case .todosLoaded(let todos):
            state = .todos(todos)
            return nil
            
        case .loadingFailed(let message):
            state = .failure(message)
            return nil
        }
    }
}
```

### 5. Implement the EffectHandler

```swift
import Arch
import Combine
import Foundation

protocol TodoStorage {
    func loadTodos() async throws -> [Todo]
}

final class TodoEffectHandler: EffectHandler {
    private let storage: TodoStorage
    private var cancellables = Set<AnyCancellable>()
    
    init(storage: TodoStorage) {
        self.storage = storage
    }
    
    func handle(_ effect: TodoEffect, _ dispatch: @escaping @Sendable (TodoEvent) -> Void) {
        switch effect {
        case .loadTodos:
            Task {
                do {
                    let todos = try await storage.loadTodos()
                    await MainActor.run {
                        dispatch(.todosLoaded(todos))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(.loadingFailed(error.localizedDescription))
                    }
                }
            }
        }
    }
}
```

### 6. Create the ViewStore

```swift
import Arch

typealias TodoViewStore = ViewStore<TodoState, TodoEvent, TodoEffect, TodoReducer, TodoEffectHandler>

extension TodoViewStore {
    @MainActor
    static func build(storage: TodoStorage) -> TodoViewStore {
        TodoViewStore(
            initial: .idle,
            reducer: TodoReducer(),
            effectHandler: TodoEffectHandler(storage: storage)
        )
    }
}
```

### 7. SwiftUI Views

We use only two simple SwiftUI components to keep the example minimal:

```swift
import SwiftUI

struct TodoListView: View {
    @ObservedObject var viewStore: TodoViewStore
    
    var body: some View {
        NavigationView {
            Group {
                switch viewStore.state {
                case .idle:
                    Text("Tap to load todos")
                        .foregroundColor(.gray)
                        .onTapGesture {
                            viewStore.handle(.viewDidLoad)
                        }
                    
                case .loading:
                    ProgressView("Loading todos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .todos(let todos):
                    List {
                        ForEach(todos) { todo in
                            TodoRowView(todo: todo)
                        }
                    }
                    
                case .failure(let message):
                    VStack(spacing: 16) {
                        Text("Error: \(message)")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            viewStore.handle(.viewDidLoad)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Todos")
            .onAppear {
                viewStore.handle(.viewDidLoad)
            }
        }
    }
}

struct TodoRowView: View {
    let todo: Todo
    
    var body: some View {
        HStack {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(todo.isCompleted ? .green : .gray)
            
            Text(todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundColor(todo.isCompleted ? .gray : .primary)
            
            Spacer()
        }
    }
}

```

### 8. Storage Implementation

```swift
import Foundation

final class UserDefaultsTodoStorage: TodoStorage {
    private let key = "saved_todos"
    
    func loadTodos() async throws -> [Todo] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                guard let data = UserDefaults.standard.data(forKey: self.key),
                      let todos = try? JSONDecoder().decode([Todo].self, from: data) else {
                    // Return some sample data for demonstration
                    continuation.resume(returning: [
                        Todo(title: "Learn SwiftUI"),
                        Todo(title: "Master Arch pattern"),
                        Todo(title: "Build amazing apps")
                    ])
                    return
                }
                continuation.resume(returning: todos)
            }
        }
    }
}
```

### 9. App Entry Point

```swift
import SwiftUI

@main
struct TodoApp: App {
    let todoStorage = UserDefaultsTodoStorage()
    
    var body: some Scene {
        WindowGroup {
            TodoListView(
                viewStore: TodoViewStore.build(storage: todoStorage)
            )
        }
    }
}
```

## Key Architecture Principles

### 1. Unidirectional Data Flow
- Views dispatch events to ViewStore
- Reducer processes events and updates state
- State changes trigger view updates
- Side effects are handled separately

### 2. Separation of Concerns
- **State**: Pure data structure
- **Reducer**: Pure business logic
- **EffectHandler**: Side effects and external interactions
- **Views**: UI rendering and user interaction

### 3. Testability
Each component can be tested in isolation:

```swift
import XCTest
@testable import TodoApp

final class TodoReducerTests: XCTestCase {

    func test_reduce_deliversLoadTodosEffectAndSetsLoadingState_onViewDidLoadEvent() {
        let sut = makeSUT()
        let initialState = TodoState.idle
        var state = initialState
        
        let result = sut.reduce(&state, .viewDidLoad)
        
        XCTAssertEqual(state, .loading)
        XCTAssertEqual(result, .loadTodos)
    }
    
    func test_reduce_setsTodosStateAndDeliversNilEffect_onTodosLoadedEvent() {
        let sut = makeSUT()
        let todos = makeTodos()
        let initialState = TodoState.loading
        var state = initialState
        
        let result = sut.reduce(&state, .todosLoaded(todos))
        
        XCTAssertEqual(state, .todos(todos))
        XCTAssertNil(result)
    }
    
    func test_reduce_setsFailureStateAndDeliversNilEffect_onLoadingFailedEvent() {
        let sut = makeSUT()
        let errorMessage = "Network error"
        let initialState = TodoState.loading
        var state = initialState
        
        let result = sut.reduce(&state, .loadingFailed(errorMessage))
        
        XCTAssertEqual(state, .failure(errorMessage))
        XCTAssertNil(result)
    }
    
    func test_reduce_doesNotChangeState_onTodosLoadedEventFromIdleState() {
        let sut = makeSUT()
        let todos = makeTodos()
        let initialState = TodoState.idle
        var state = initialState
        
        let result = sut.reduce(&state, .todosLoaded(todos))
        
        XCTAssertEqual(state, .todos(todos))
        XCTAssertNil(result)
    }
    
    func test_reduce_doesNotChangeState_onLoadingFailedEventFromIdleState() {
        let sut = makeSUT()
        let errorMessage = "Network error"
        let initialState = TodoState.idle
        var state = initialState
        
        let result = sut.reduce(&state, .loadingFailed(errorMessage))
        
        XCTAssertEqual(state, .failure(errorMessage))
        XCTAssertNil(result)
    }

    //MARK: - Helpers
    
    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> TodoReducer {
        let sut = TodoReducer()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
    
    private func makeTodos() -> [Todo] {
        [
            Todo(title: "Learn SwiftUI"),
            Todo(title: "Master Arch pattern"),
            Todo(title: "Build amazing apps")
        ]
    }
}
```

### 4. Composability
Scenes can be composed together by including child ViewStores in parent state:

```swift
struct AppState: Equatable {
    let todoStore: TodoViewStore
    var detailStore: TodoDetailViewStore?
}

enum AppEvent: Equatable {
    case openTodoDetail(Todo.ID)
    case closeTodoDetail
    case refreshTodos
}

// Example of handling child state changes
extension AppReducer {
    func reduce(_ state: inout AppState, _ event: AppEvent) -> AppEffect? {
        switch event {
        case .refreshTodos:
            // Trigger reload on child store
            state.todoStore.handle(.viewDidLoad)
            return nil
        }
    }
}
```

## Common Patterns

### 1. Factory Methods
Always provide static factory methods for ViewStore creation:

```swift
extension TodoViewStore {
    static func build(storage: TodoStorage) -> TodoViewStore {
        // ViewStore initialization
    }
}
```

### 2. External Events
For parent-child communication:

```swift
enum ExternalTodoEvent: Equatable {
    case todosLoaded([Todo])
    case loadingFailed(String)
}

// In EffectHandler
var externalEvents: AnyPublisher<ExternalTodoEvent, Never> {
    externalEventsSubject.eraseToAnyPublisher()
}
```

## Best Practices

### 1. Keep State Normalized
- Avoid nested complex objects
- Use computed properties for derived state
- Maintain single source of truth

### 2. Make Events Descriptive
- Use past tense for what happened
- Include necessary data as associated values
- Keep events granular but not overly verbose

### 3. Handle Errors Gracefully
- Always handle async operation failures
- Provide meaningful error messages
- Don't let errors crash the reducer

### 4. Use Dependency Injection
- Inject dependencies through initializers
- Use protocols for testability
- Keep dependencies explicit

### 5. Maintain Clean Architecture
- One scene per module/feature
- Keep related components together
- Follow consistent naming conventions

This architecture promotes predictability, testability, maintainability, and composability while providing a clear separation of concerns and unidirectional data flow.

## Simplified Example Summary

This simplified Todo application example focuses on the core Arch architecture patterns:

- ✅ **Enum-based state modeling** - type-safe state representation using Swift enums
- ✅ **Loading data from storage** - demonstrates asynchronous operations
- ✅ **Displaying data** - shows how state drives UI updates  
- ✅ **Loading states** - explicit loading, success, and failure states
- ✅ **Error handling** - graceful error management with retry functionality
- ✅ **Pure business logic** - all logic contained in the reducer
- ✅ **Side effects separation** - external operations handled in EffectHandler
- ✅ **Minimal UI components** - just two SwiftUI views for maximum clarity

## Key Benefits of Enum-Based State

Using `enum` for state modeling provides several advantages:

1. **Type Safety** - Impossible to have invalid state combinations
2. **Clarity** - Each state is explicit and well-defined
3. **Exhaustive Matching** - Compiler ensures all states are handled
4. **Simplicity** - Eliminates complex boolean flag combinations
5. **Testability** - Easy to test state transitions

This ultra-minimal example makes the Arch architecture patterns crystal clear for learning the fundamental concepts. With just two SwiftUI views and enum-based state, it eliminates all unnecessary complexity while demonstrating the complete data flow cycle.