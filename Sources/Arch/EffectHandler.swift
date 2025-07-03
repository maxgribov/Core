//
//  File.swift
//
//
//  Created by Max Gribov on 17.03.2024.
//

import Foundation

public protocol EffectHandler<Effect, Event> {

    associatedtype Effect: Equatable
    associatedtype Event: Equatable

    func handle(_ effect: Effect, _ dispatch: @escaping @Sendable (Event) -> Void)
}
