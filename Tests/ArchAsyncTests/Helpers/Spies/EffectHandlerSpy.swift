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
    private let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
    private var _messages: [Effect] = []

    var messages: [Effect] { lock.withLock { _messages } }
    var callsCount: Int { messages.count }
    var onHandleCalled: (@Sendable () -> Void)?
    var handleBlock: (@Sendable (Effect) async -> Void)?

    func handle(_ effect: Effect) async -> AsyncStream<Event> {
        lock.withLock { _messages.append(effect) }
        await handleBlock?(effect)
        onHandleCalled?()
        return stream
    }

    func simulateDispatch(with event: Event) {
        continuation.yield(event)
    }
}
