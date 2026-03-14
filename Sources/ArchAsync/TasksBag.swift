//
//  TasksBag.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation

final class TasksBag: @unchecked Sendable {

    private final class Entry: @unchecked Sendable {
        let task: Task<Void, Never>
        private let _lock = NSLock()
        private var _complete: Bool = false

        var isComplete: Bool {
            _lock.withLock { _complete }
        }

        init(_ task: Task<Void, Never>) {
            self.task = task
        }

        func markComplete() {
            _lock.withLock { _complete = true }
        }
    }

    private let lock = NSLock()
    private var entries: [Entry] = []

    var tasks: [Task<Void, Never>] {
        lock.withLock { entries.map(\.task) }
    }

    func add(_ task: Task<Void, Never>) {
        let entry = Entry(task)
        lock.withLock {
            entries.removeAll { $0.isComplete || $0.task.isCancelled }
            entries.append(entry)
        }
        Task.detached { [weak entry] in
            await task.value
            entry?.markComplete()
        }
    }

    func cancelAll() {
        lock.withLock {
            entries.forEach { $0.task.cancel() }
            entries.removeAll()
        }
    }
}
