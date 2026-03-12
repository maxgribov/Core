//
//  ReducerSpy.swift
//  Core
//
//  Created by Max Gribov on 12.03.2026.
//

import ArchAsync

final class ReducerSpy<State, Event, Effect>: Reducer, @unchecked Sendable {
    private(set) var messages: [(state: State, event: Event)] = []
    var callsCount: Int { messages.count }
    var stub: [(state: State, effect: Effect?)]?
    var reduceCallObserver: (([(state: State, event: Event)]) -> Void)?

    func reduce(_ state: inout State, _ event: Event) -> Effect? {
        messages.append((state, event))
        reduceCallObserver?(messages)

        guard let stub else {
            return nil
        }

        let stubIndex = messages.count - 1
        state = stub[stubIndex].state
        let effect = stub[stubIndex].effect

        return effect
    }
}
