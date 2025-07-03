//
//  ViewStoreTests.swift
//
//
//  Created by Max Gribov on 17.03.2024.
//

import XCTest
import Arch

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

    func test_handle_invokesHandleEffectOnReducerReturnsEffect() {

        let (sut, reducer, effectHandler) = makeSUT(state: makeSampleState())
        let effect = makeSampleEffect()
        reducer.stub = [(makeSampleState(), effect)]

        expect(effectHandler, invokedEffects: [effect], on: {

            sut.handle(makeSampleEvent())
        })
    }

    func test_handle_invokesReducerOnHandleEffectEvent() {

        let (sut, reducer, effectHandler) = makeSUT(state: makeSampleState())
        reducer.stub = [(makeSampleState(), makeSampleEffect()),
                        (makeSampleState(), nil)]
        let sutEvent = makeSampleEvent()
        sut.handle(sutEvent)

        let effectHandlerEvent = makeSampleEvent()
        effectHandler.simulateDispatch(with: effectHandlerEvent)

        XCTAssertEqual(reducer.messages.map(\.event),
                       [sutEvent, effectHandlerEvent])
    }

    //MARK: - Helpers

    private typealias SUT = ViewStore<SampleState, SampleEvent, SampleEffect, ReducerSpy, EffectHandlerSpy>

    private func makeSUT(
        state: SampleState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (
        sut: SUT,
        reducer: ReducerSpy,
        effectHandler: EffectHandlerSpy
    ) {

        let reducerSpy = ReducerSpy()
        let effectHandlerSpy = EffectHandlerSpy()
        let sut = SUT(
            initial: state,
            reducer: reducerSpy,
            effectHandler: effectHandlerSpy
        )

        trackForMemoryLeaks(reducerSpy, file: file, line: line)
        trackForMemoryLeaks(reducerSpy, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)

        return (sut, reducerSpy, effectHandlerSpy)
    }

    private struct SampleState: Equatable {
        let id: UUID
        let value: String
    }

    private enum SampleEvent: Equatable {
        case event(UUID)
    }

    private enum SampleEffect: Equatable {
        case effect(UUID)
    }

    private class ReducerSpy: Reducer {
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

    private class EffectHandlerSpy: EffectHandler {
        private(set) var messages: [(effect: SampleEffect, dispatch: @Sendable (Event) -> Void)] = []
        var callsCount: Int { messages.count }

        func handle(_ effect: SampleEffect, _ dispatch: @escaping @Sendable (SampleEvent) -> Void) {
            messages.append((effect, dispatch))
        }

        func simulateDispatch(with event: SampleEvent, at index: Int = 0) {
            messages[index].dispatch(event)
        }
    }

    private func expect(
        _ effectsHandler: EffectHandlerSpy,
        invokedEffects expectedEffects: [SampleEffect],
        on action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        action()

        let receivedMessages = effectsHandler.messages.map(\.effect)
        XCTAssertEqual(receivedMessages, expectedEffects, file: file, line: line)
    }

    private func makeSampleState(
        id: UUID = UUID(),
        value: String = ""
    ) -> SampleState {
        SampleState(
            id: id,
            value: value
        )
    }

    private func makeSampleEvent(
        _ id: UUID = UUID()
    ) -> SampleEvent {
        .event(id)
    }

    private func makeSampleEffect(
        _ id: UUID = UUID()
    ) -> SampleEffect {
        .effect(id)
    }
}
