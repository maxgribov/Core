//
//  ViewStoreTests.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import XCTest
import ArchAsync

@MainActor
final class ViewStoreTests: XCTestCase {

    func test_init_deliversStateEqualToInitialState() {
        let initialState = makeSampleState()
        let (sut, _, _) = makeSUT(state: initialState)

        XCTAssertEqual(sut.state, initialState)
    }

    func test_init_shouldNotCallCollaborators() {
        let (_, reducer, effectHandler) = makeSUT(state: makeSampleState())

        XCTAssertEqual(reducer.callsCount, 0)
        XCTAssertEqual(effectHandler.callsCount, 0)
    }

    func test_handle_invokesReducerOnAnyEvent() {
        let state = makeSampleState()
        let (sut, reducer, _) = makeSUT(state: state)

        let event = makeSampleEvent()
        sut.handle(event)

        XCTAssertEqual(reducer.messages.map(\.state), [state])
        XCTAssertEqual(reducer.messages.map(\.event), [event])
    }

    func test_handle_updatesStateOnReducerStateUpdate() {
        let (sut, reducer, _) = makeSUT(state: makeSampleState())
        let updatedState = makeSampleState(value: "updated")
        reducer.stub = [(updatedState, nil)]

        sut.handle(makeSampleEvent())

        XCTAssertEqual(sut.state, updatedState)
    }

    func test_handle_invokesHandleEffectOnReducerReturnsEffect() async {
        let (sut, reducer, effectHandler) = makeSUT(state: makeSampleState())
        let effect = makeSampleEffect()
        reducer.stub = [(makeSampleState(), effect)]

        let expectation = expectation(description: "handle called")
        effectHandler.onHandleCalled = { expectation.fulfill() }
        sut.handle(makeSampleEvent())
        await fulfillment(of: [expectation], timeout: 0.1)

        XCTAssertEqual(effectHandler.messages, [effect])
    }

    func test_handle_invokesReducerOnHandleEffectEvent() async {
        let (sut, reducer, effectHandler) = makeSUT(state: makeSampleState())
        reducer.stub = [
            (makeSampleState(), makeSampleEffect()),
            (makeSampleState(), nil)
        ]
        let sutEvent = makeSampleEvent()
        let effectHandlerEvent = makeSampleEvent()
        
        let expectation = expectation(description: "reducer receives effect handler event")
        reducer.reduceCallObserver = { messages in
            if messages.count == 2 {
                expectation.fulfill()
            }
        }
        
        sut.handle(sutEvent)
        effectHandler.simulateDispatch(with: effectHandlerEvent)
        await fulfillment(of: [expectation], timeout: 0.1)

        XCTAssertEqual(reducer.messages.map(\.event), [sutEvent, effectHandlerEvent])
    }

    private typealias SUT = ViewStore<SampleState, SampleEvent, SampleEffect, ReducerSpy, EffectHandlerSpy>

    private func makeSUT(
        state: SampleState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: SUT, reducer: ReducerSpy, effectHandler: EffectHandlerSpy) {
        let reducerSpy = ReducerSpy()
        let effectHandlerSpy = EffectHandlerSpy()
        let sut = SUT(
            initial: state,
            reducer: reducerSpy,
            effectHandler: effectHandlerSpy
        )

        trackForMemoryLeaks(reducerSpy, file: file, line: line)
        trackForMemoryLeaks(effectHandlerSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, reducerSpy, effectHandlerSpy)
    }

    private struct SampleState: Equatable, Sendable {
        let id: UUID
        let value: String
    }

    private enum SampleEvent: Equatable, Sendable {
        case event(UUID)
    }

    private enum SampleEffect: Equatable, Sendable {
        case effect(UUID)
    }

    private final class ReducerSpy: Reducer, @unchecked Sendable {
        private(set) var messages: [(state: SampleState, event: SampleEvent)] = []
        var callsCount: Int { messages.count }
        var stub: [(state: SampleState, effect: SampleEffect?)]?
        var reduceCallObserver: (([(state: SampleState, event: SampleEvent)]) -> Void)?

        func reduce(_ state: inout SampleState, _ event: SampleEvent) -> SampleEffect? {
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

    private final class EffectHandlerSpy: EffectHandler, @unchecked Sendable {
        private let (stream, continuation) = AsyncStream.makeStream(of: SampleEvent.self)
        private(set) var messages: [SampleEffect] = []
        var callsCount: Int { messages.count }
        var onHandleCalled: (@Sendable () -> Void)?

        var events: AsyncStream<SampleEvent> { stream }

        func handle(_ effect: SampleEffect) async {
            messages.append(effect)
            onHandleCalled?()
        }

        func simulateDispatch(with event: SampleEvent) {
            continuation.yield(event)
        }
    }

    private func makeSampleState(
        id: UUID = UUID(),
        value: String = ""
    ) -> SampleState {
        SampleState(id: id, value: value)
    }

    private func makeSampleEvent(_ id: UUID = UUID()) -> SampleEvent {
        .event(id)
    }

    private func makeSampleEffect(_ id: UUID = UUID()) -> SampleEffect {
        .effect(id)
    }
}
