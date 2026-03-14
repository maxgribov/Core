//
//  EffectHandler.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation

/// Executes side effects asynchronously and returns resulting events as an `AsyncStream`.
///
/// Implement this protocol to handle effects produced by the ``Reducer``.
/// Each call to `handle(_:)` returns an `AsyncStream` of events that the ``ViewStore``
/// subscribes to. Use the convenience helpers `AsyncStream.single(_:)` and
/// `AsyncStream.empty` for common cases.
public protocol EffectHandler<Effect, Event>: Sendable {
    /// The type of effect this handler can execute.
    associatedtype Effect
    /// The type of event emitted back to the ``ViewStore`` after handling an effect.
    associatedtype Event

    /// Handles the given effect and returns a stream of resulting events.
    ///
    /// - Parameter effect: The effect to handle.
    /// - Returns: An `AsyncStream` of events produced by this effect.
    func handle(_ effect: Effect) async -> AsyncStream<Event>
}
