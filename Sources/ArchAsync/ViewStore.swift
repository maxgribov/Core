//
//  ViewStore.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation
import Observation

@MainActor
@Observable
public final class ViewStore<State, Event, Effect, R, E>
where R: Reducer, R.State == State, R.Event == Event, R.Effect == Effect,
      E: EffectHandler, E.Effect == Effect, E.Event == Event,
      Event: Sendable, Effect: Sendable {

    public private(set) var state: State

    private let reducer: R
    private let effectHandler: E

    @ObservationIgnored
    private nonisolated(unsafe) var effectTask: Task<Void, Never>?

    public init(initial state: State, reducer: R, effectHandler: E) {
        self.state = state
        self.reducer = reducer
        self.effectHandler = effectHandler

        subscribeEffectHandlerEvents()
    }

    deinit {
        effectTask?.cancel()
    }

    public func handle(_ event: Event) {
        if let effect = reducer.reduce(&state, event) {
            let handler = effectHandler
            Task.detached {
                await handler.handle(effect)
            }
        }
    }
    
    private func subscribeEffectHandlerEvents() {
        let events = effectHandler.events
        effectTask = Task { [weak self] in
            for await event in events {
                if Task.isCancelled { return }
                await MainActor.run { [weak self] in
                    self?.handle(event)
                }
            }
        }
    }
}
