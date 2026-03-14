//
//  AsyncStream+Convenience.swift
//  Core
//
//  Created by Max Gribov on 14.03.2026.
//

extension AsyncStream where Element: Sendable {
    /// Creates a stream that yields a single element and finishes.
    public static func single(_ element: Element) -> AsyncStream<Element> {
        .init { $0.yield(element); $0.finish() }
    }

    /// An empty stream that finishes immediately.
    public static var empty: AsyncStream<Element> {
        .init { $0.finish() }
    }
}
