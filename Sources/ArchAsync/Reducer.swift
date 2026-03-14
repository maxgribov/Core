//
//  Reducer.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation

/// A pure function that processes events and updates state.
///
/// Reducer is the core decision-making component of the architecture.
/// It must be free of side effects — all asynchronous or external work
/// should be represented as an ``Effect`` returned from ``reduce(_:_:)``.
public protocol Reducer<State, Event, Effect>: Sendable {
    /// The type that represents the current state of the feature.
    associatedtype State
    /// The type that represents user or system actions.
    associatedtype Event
    /// The type that represents side effects to be executed.
    associatedtype Effect

    /// Processes an event by mutating the current state and optionally returning an effect.
    ///
    /// - Parameters:
    ///   - state: The current state, modified in place.
    ///   - event: The event to process.
    /// - Returns: An optional effect to be executed by the ``EffectHandler``, or `nil` if no side effect is needed.
    func reduce(_ state: inout State, _ event: Event) -> Effect?
}
