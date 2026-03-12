//
//  EffectHandler.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation

public protocol EffectHandler<Effect, Event>: Sendable {
    associatedtype Effect
    associatedtype Event

    var events: AsyncStream<Event> { get }
    func handle(_ effect: Effect) async
}
