//
//  ReducerSpy.swift
//  Core
//
//  Created by Max Gribov on 12.03.2026.
//

import Foundation
import ArchAsync

final class ReducerSpy<State, Event, Effect>: Reducer, @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [(state: State, event: Event)] = []
    var messages: [(state: State, event: Event)] { lock.withLock { _messages } }
    var callsCount: Int { messages.count }
    var stub: [(state: State, effect: Effect?)]?
    var reduceCallObserver: (([(state: State, event: Event)]) -> Void)?

    func reduce(_ state: inout State, _ event: Event) -> Effect? {
        let currentMessages = lock.withLock {
            _messages.append((state, event))
            return _messages
        }
        reduceCallObserver?(currentMessages)

        guard let stub else {
            return nil
        }

        let stubIndex = currentMessages.count - 1
        state = stub[stubIndex].state
        let effect = stub[stubIndex].effect

        return effect
    }
}
