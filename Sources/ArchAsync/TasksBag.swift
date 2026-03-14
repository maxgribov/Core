//
//  TasksBag.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation

public final class TasksBag: @unchecked Sendable {

    private let lock = NSLock()
    private(set) var tasks: [Task<Void, Never>] = []

    public init() {}

    public func add(_ task: Task<Void, Never>) {
        lock.withLock {
            // Only cancelled tasks are pruned; completed ones linger as lightweight structs.
            // Tracking completion would require a detached Task per entry, adding complexity.
            tasks.removeAll { $0.isCancelled }
            tasks.append(task)
        }
    }

    public func cancelAll() {
        lock.withLock {
            tasks.forEach { $0.cancel() }
            tasks.removeAll()
        }
    }
}
