//
//  Reducer.swift
//  Core
//
//  Created by Max Gribov on 28.02.2026.
//

import Foundation

public protocol Reducer<State, Event, Effect>: Sendable {
    associatedtype State
    associatedtype Event
    associatedtype Effect

    func reduce(_ state: inout State, _ event: Event) -> Effect?
}
