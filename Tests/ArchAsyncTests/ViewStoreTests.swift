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
        let (sut, _) = makeSUT(state: initialState)

        XCTAssertEqual(sut.state, initialState)
    }

    func test_init_shouldNotCallCollaborators() {
        let (_, deps) = makeSUT(state: makeSampleState())

        XCTAssertEqual(deps.reducer.callsCount, 0)
        XCTAssertEqual(deps.effectHandler.callsCount, 0)
    }

    func test_handle_invokesReducerOnAnyEvent() {
        let state = makeSampleState()
        let (sut, deps) = makeSUT(state: state)

        let event = makeSampleEvent()
        sut.handle(event)

        XCTAssertEqual(deps.reducer.messages.map(\.state), [state])
        XCTAssertEqual(deps.reducer.messages.map(\.event), [event])
    }

    func test_handle_updatesStateOnReducerStateUpdate() {
        let (sut, deps) = makeSUT(state: makeSampleState())
        let updatedState = makeSampleState(value: "updated")
        deps.reducer.stub = [(updatedState, nil)]

        sut.handle(makeSampleEvent())

        XCTAssertEqual(sut.state, updatedState)
    }

    func test_handle_invokesHandleEffectOnReducerReturnsEffect() async {
        let (sut, deps) = makeSUT(state: makeSampleState())
        let effect = makeSampleEffect()
        deps.reducer.stub = [(makeSampleState(), effect)]

        let expectation = expectation(description: "handle called")
        deps.effectHandler.onHandleCalled = { expectation.fulfill() }
        sut.handle(makeSampleEvent())
        await fulfillment(of: [expectation], timeout: 0.1)

        XCTAssertEqual(deps.effectHandler.messages, [effect])
    }

    func test_handle_invokesReducerOnHandleEffectEvent() async {
        let (sut, deps) = makeSUT(state: makeSampleState())
        deps.reducer.stub = [
            (makeSampleState(), makeSampleEffect()),
            (makeSampleState(), nil)
        ]
        let sutEvent = makeSampleEvent()
        let effectHandlerEvent = makeSampleEvent()

        let handleCalled = expectation(description: "handle called")
        deps.effectHandler.onHandleCalled = { handleCalled.fulfill() }

        let allReducerCalls = expectation(description: "wait for all reducer calls")
        allReducerCalls.expectedFulfillmentCount = 2
        deps.reducer.reduceCallObserver = { _ in
            allReducerCalls.fulfill()
        }

        sut.handle(sutEvent)
        await fulfillment(of: [handleCalled], timeout: 0.1)
        deps.effectHandler.simulateDispatch(with: effectHandlerEvent)
        await fulfillment(of: [allReducerCalls], timeout: 0.1)

        XCTAssertEqual(deps.reducer.messages.map(\.event), [sutEvent, effectHandlerEvent])
    }

    func test_deinit_cancelsInFlightEffects() async {
        let effectStarted = expectation(description: "effect started")
        let effectCancelled = expectation(description: "effect cancelled")

        var sut: SUT?
        let deps: Dependencies
        (sut, deps) = makeSUT(state: makeSampleState())

        deps.effectHandler.streamProvider = { @Sendable _ in
            AsyncStream { continuation in
                effectStarted.fulfill()
                continuation.onTermination = { @Sendable _ in
                    effectCancelled.fulfill()
                }
            }
        }
        deps.reducer.stub = [(makeSampleState(), makeSampleEffect())]

        sut?.handle(makeSampleEvent())
        await fulfillment(of: [effectStarted], timeout: 0.5)

        sut = nil
        await fulfillment(of: [effectCancelled], timeout: 1.0)
    }

    func test_deinit_stopsProcessingEffectHandlerEvents() async {
        let deps: Dependencies
        do {
            var sut: SUT?
            (sut, deps) = makeSUT(state: makeSampleState())
            _ = sut
            sut = nil
        }

        deps.effectHandler.simulateDispatch(with: makeSampleEvent())
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(deps.reducer.callsCount, 0)
    }

    func test_handle_multipleEffectsHandledConcurrently() async {
        let (sut, deps) = makeSUT(state: makeSampleState())
        let effectCount = 10
        deps.reducer.stub = (0..<effectCount).map { _ in (makeSampleState(), makeSampleEffect()) }

        let allHandled = expectation(description: "all effects handled")
        allHandled.expectedFulfillmentCount = effectCount
        deps.effectHandler.onHandleCalled = { allHandled.fulfill() }

        for _ in 0..<effectCount {
            sut.handle(makeSampleEvent())
        }

        await fulfillment(of: [allHandled], timeout: 1.0)
        XCTAssertEqual(deps.effectHandler.messages.count, effectCount)
    }

    //MARK: - Helpers
    
    private typealias SUT = ViewStore<SampleState, SampleEvent, SampleEffect, ReducerSpy<SampleState, SampleEvent, SampleEffect>, EffectHandlerSpy<SampleEvent, SampleEffect>>

    private func makeSUT(
        state: SampleState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: SUT, deps: Dependencies) {
        let reducerSpy = ReducerSpy<SampleState, SampleEvent, SampleEffect>()
        let effectHandlerSpy = EffectHandlerSpy<SampleEvent, SampleEffect>()
        let sut = SUT(
            initial: state,
            reducer: reducerSpy,
            effectHandler: effectHandlerSpy
        )

        trackForMemoryLeaks(reducerSpy, file: file, line: line)
        trackForMemoryLeaks(effectHandlerSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, Dependencies(reducer: reducerSpy, effectHandler: effectHandlerSpy))
    }
    
    private struct Dependencies {
        let reducer: ReducerSpy<SampleState, SampleEvent, SampleEffect>
        let effectHandler: EffectHandlerSpy<SampleEvent, SampleEffect>
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
