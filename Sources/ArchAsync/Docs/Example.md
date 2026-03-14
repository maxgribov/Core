
# ArchAsync Framework Architecture Example

This document provides a minimal, clear example of implementing the ArchAsync architecture pattern. ArchAsync is an async/await-based variant of the Arch framework, using `AsyncStream` for effect-to-event communication instead of callbacks. The example demonstrates a simple Todo application that focuses on core ArchAsync principles and patterns.

## Overview

The ArchAsync framework implements a unidirectional data flow architecture with the following core components:

- **ViewStore**: Central coordinator that manages State, Events, Effects, Reducer, and EffectHandler; uses Swift Observation (`@Observable`)
- **State**: Immutable data structure representing the current state
- **Event**: User actions and system events
- **Effect**: Side effects that need to be performed
- **Reducer**: Pure function that updates state based on events
- **EffectHandler**: Handles side effects asynchronously and yields events via `AsyncStream`

## Simple Todo Application Example

### 1. Define the State

```swift
import Foundation
import ArchAsync

enum TodoState: Sendable {
    case idle
    case loading
    case todos([Todo])
    case failure(String)
}

struct Todo: Identifiable, Codable, Sendable {
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
enum TodoEvent: Sendable {
    case viewDidLoad
    case todosLoaded([Todo])
    case loadingFailed(String)
}
```

### 3. Define Effects

```swift
enum TodoEffect: Sendable {
    case loadTodos
}
```

### 4. Implement the Reducer

```swift
import ArchAsync

struct TodoReducer: Reducer {

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

The EffectHandler returns an `AsyncStream<Event>` per effect. Use `AsyncStream.single(_:)` for effects that produce a single event.

```swift
import ArchAsync
import Foundation

protocol TodoStorage: Sendable {
    func loadTodos() async throws -> [Todo]
}

final class TodoEffectHandler: EffectHandler, Sendable {
    private let storage: TodoStorage
    private let tasksBag = TasksBag()

    init(storage: TodoStorage) {
        self.storage = storage
    }

    deinit {
        tasksBag.cancelAll()
    }

    func handle(_ effect: TodoEffect) -> AsyncStream<TodoEvent> {
        switch effect {
        case .loadTodos:
            let storage = self.storage
            return AsyncStream { continuation in
                let task = Task {
                    do {
                        let todos = try await storage.loadTodos()
                        guard !Task.isCancelled else { return }
                        continuation.yield(.todosLoaded(todos))
                    } catch {
                        guard !Task.isCancelled else { return }
                        continuation.yield(.loadingFailed(error.localizedDescription))
                    }
                    continuation.finish()
                }
                self.tasksBag.add(task)
            }
        }
    }
}
```

### 6. Create the ViewStore

```swift
import ArchAsync

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

With `@Observable`, the ViewStore is used directly without `@ObservedObject`. The view automatically tracks access to `viewStore.state` and re-renders on changes.

```swift
import SwiftUI

struct TodoListView: View {
    var viewStore: TodoViewStore

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

final class UserDefaultsTodoStorage: TodoStorage, Sendable {
    private let key = "saved_todos"

    func loadTodos() async throws -> [Todo] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let todos = try? JSONDecoder().decode([Todo].self, from: data) else {
            return [
                Todo(title: "Learn SwiftUI"),
                Todo(title: "Master ArchAsync pattern"),
                Todo(title: "Build amazing apps")
            ]
        }
        return todos
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