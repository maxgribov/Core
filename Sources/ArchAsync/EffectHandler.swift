//
//  EffectHandler.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation

/// Executes side effects asynchronously and emits resulting events through an `AsyncStream`.
///
/// Implement this protocol to handle effects produced by the ``Reducer``.
/// Use `AsyncStream.makeStream(of: Event.self)` to create the stream and its continuation,
/// then yield events via the continuation after async work completes.
public protocol EffectHandler<Effect, Event>: Sendable {
    /// The type of effect this handler can execute.
    associatedtype Effect
    /// The type of event emitted back to the ``ViewStore`` after handling an effect.
    associatedtype Event

    /// A stream of events produced by this handler in response to effects.
    var events: AsyncStream<Event> { get }

    /// Executes the given effect asynchronously.
    ///
    /// - Parameter effect: The effect to handle.
    func handle(_ effect: Effect) async
}
