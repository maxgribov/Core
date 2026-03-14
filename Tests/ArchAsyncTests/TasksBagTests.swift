//
//  TasksBagTests.swift
//  Core
//
//  Created by Max Gribov on 14.03.2026.
//

import XCTest
@testable import ArchAsync

final class TasksBagTests: XCTestCase {

    func test_init_hasNoTasks() {
        let sut = TasksBag()

        XCTAssertTrue(sut.tasks.isEmpty)
    }

    func test_add_storesTask() {
        let sut = TasksBag()
        let task = Task<Void, Never> {}

        sut.add(task)

        XCTAssertEqual(sut.tasks.count, 1)
    }

    func test_cancelAll_cancelsAllStoredTasks() {
        let sut = TasksBag()
        let task1 = Task<Void, Never> {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        let task2 = Task<Void, Never> {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        sut.add(task1)
        sut.add(task2)
        sut.cancelAll()

        XCTAssertTrue(task1.isCancelled)
        XCTAssertTrue(task2.isCancelled)
    }

    func test_cancelAll_removesAllTasks() {
        let sut = TasksBag()
        sut.add(Task<Void, Never> {})
        sut.add(Task<Void, Never> {})

        sut.cancelAll()

        XCTAssertTrue(sut.tasks.isEmpty)
    }

    func test_add_removesCancelledTasks() {
        let sut = TasksBag()
        let cancelledTask = Task<Void, Never> {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        sut.add(cancelledTask)
        cancelledTask.cancel()

        sut.add(Task<Void, Never> {})

        XCTAssertEqual(sut.tasks.count, 1)
    }

}
