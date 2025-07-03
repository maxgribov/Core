//
//  ViewStore.swift
//
//
//  Created by Max Gribov on 17.03.2024.
//

import Foundation

public final class ViewStore<State, Event, Effect, R, E>: ObservableObject, @unchecked Sendable
where R: Reducer,
      R.State == State,
      R.Event == Event,
      R.Effect == Effect,
      E: EffectHandler,
      E.Effect == Effect,
      E.Event == Event {

    @Published public private(set) var state: State

    private let reducer: R
    public let effectHandler: E

    public init(
        initial state: State,
        reducer: R,
        effectHandler: E
    ) {
        self.state = state
        self.reducer = reducer
        self.effectHandler = effectHandler
    }

    public func handle(_ event: Event) {
        if let effect = reducer.reduce(&state, event) {
            effectHandler.handle(effect) { [weak self] event in
                self?.handle(event)
            }
        }
    }
}

extension ViewStore: Equatable {
    public static func == (lhs: ViewStore<State, Event, Effect, R, E>, rhs: ViewStore<State, Event, Effect, R, E>) -> Bool {
        lhs.state == rhs.state
    }
}

extension ViewStore: Hashable where State: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(state)
    }
}
