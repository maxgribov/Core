//
//  EffectHandlerSpy.swift
//  Core
//
//  Created by Max Gribov on 12.03.2026.
//

import Foundation
import ArchAsync

final class EffectHandlerSpy<Event: Sendable, Effect>: EffectHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [Effect] = []
    private var continuations: [AsyncStream<Event>.Continuation] = []

    var messages: [Effect] { lock.withLock { _messages } }
    var callsCount: Int { messages.count }
    var onHandleCalled: (@Sendable () -> Void)?
    var streamProvider: (@Sendable (Effect) -> AsyncStream<Event>)?

    func handle(_ effect: Effect) -> AsyncStream<Event> {
        let (currentStreamProvider, currentOnHandleCalled) = lock.withLock {
            _messages.append(effect)
            return (streamProvider, onHandleCalled)
        }
        if let currentStreamProvider {
            let stream = currentStreamProvider(effect)
            currentOnHandleCalled?()
            return stream
        }
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        lock.withLock { continuations.append(continuation) }
        currentOnHandleCalled?()
        return stream
    }

    func simulateDispatch(with event: Event, at index: Int? = nil) {
        lock.withLock {
            if let index {
                continuations[index].yield(event)
            } else {
                continuations.forEach { $0.yield(event) }
            }
        }
    }
}
