//
//  Reducer.swift
//  
//
//  Created by Max Gribov on 17.03.2024.
//

import Foundation

public protocol Reducer<State, Event, Effect> {
    
    associatedtype State: Equatable
    associatedtype Event: Equatable
    associatedtype Effect: Equatable
    
    func reduce(_ state: inout State, _ event: Event) -> Effect?
}
