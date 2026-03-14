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
      State: Sendable, Event: Sendable, Effect: Sendable {

    public private(set) var state: State

    private let reducer: R
    private let effectHandler: E

    @ObservationIgnored
    private let taskBag = TasksBag()

    public init(initial state: State, reducer: R, effectHandler: E) {
        self.state = state
        self.reducer = reducer
        self.effectHandler = effectHandler

        subscribeEffectHandlerEvents()
    }

    deinit {
        taskBag.cancelAll()
    }

    public func handle(_ event: Event) {
        if let effect = reducer.reduce(&state, event) {
            let handler = effectHandler
            let task = Task.detached {
                await handler.handle(effect)
            }
            taskBag.add(task)
        }
    }

    private func subscribeEffectHandlerEvents() {
        let events = effectHandler.events
        let task = Task { [weak self] in
            for await event in events {
                if Task.isCancelled { return }
                self?.handle(event)
            }
        }
        taskBag.add(task)
    }
}

final class TasksBag: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [Task<Void, Never>] = []

    func add(_ task: Task<Void, Never>) {
        lock.withLock { tasks.append(task) }
    }

    func cancelAll() {
        lock.withLock {
            tasks.forEach { $0.cancel() }
            tasks.removeAll()
        }
    }
}
