//
//  ViewStore.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation
import Observation

/// The central coordinator of the unidirectional data flow architecture.
///
/// `ViewStore` holds the current state, invokes the ``Reducer`` on incoming events,
/// forwards returned effects to the ``EffectHandler``, and feeds handler-emitted events
/// back into the cycle. It is marked `@Observable` for SwiftUI integration and
/// `@MainActor` to ensure state mutations happen on the main thread.
///
/// All running effect tasks are cancelled automatically when the `ViewStore` is deallocated.
@MainActor
@Observable
public final class ViewStore<State, Event, Effect, R, E>
where R: Reducer, R.State == State, R.Event == Event, R.Effect == Effect,
      E: EffectHandler, E.Effect == Effect, E.Event == Event,
      State: Sendable, Event: Sendable, Effect: Sendable {

    /// The current state of the feature, updated synchronously by the reducer.
    public private(set) var state: State

    private let reducer: R
    private let effectHandler: E

    private let tasksBag = TasksBag()

    /// Creates a new view store.
    ///
    /// - Parameters:
    ///   - state: The initial state.
    ///   - reducer: The reducer that processes events and updates state.
    ///   - effectHandler: The handler that executes side effects.
    public init(initial state: State, reducer: R, effectHandler: E) {
        self.state = state
        self.reducer = reducer
        self.effectHandler = effectHandler
    }

    deinit {
        tasksBag.cancelAll()
    }

    /// Dispatches an event into the store, triggering the reducer and any resulting effects.
    ///
    /// - Parameter event: The event to process.
    public func handle(_ event: Event) {
        if let effect = reducer.reduce(&state, event) {
            let events = effectHandler.handle(effect)
            let task = Task.detached { [weak self] in
                for await event in events {
                    if Task.isCancelled { return }
                    await self?.handle(event)
                }
            }
            tasksBag.add(task)
        }
    }
}
