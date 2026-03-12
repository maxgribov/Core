//
//  EffectHandlerSpy.swift
//  Core
//
//  Created by Max Gribov on 12.03.2026.
//

import ArchAsync

final class EffectHandlerSpy<Event: Sendable, Effect>: EffectHandler, @unchecked Sendable {
    private let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
    private(set) var messages: [Effect] = []
    var callsCount: Int { messages.count }
    var onHandleCalled: (@Sendable () -> Void)?

    var events: AsyncStream<Event> { stream }

    func handle(_ effect: Effect) async {
        messages.append(effect)
        onHandleCalled?()
    }

    func simulateDispatch(with event: Event) {
        continuation.yield(event)
    }
}
