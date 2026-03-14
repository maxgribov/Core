# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
swift build                          # Build all targets
swift test                           # Build and run all tests (12 tests)
swift test --filter ArchTests        # Run only Arch (callback-based) tests
swift test --filter ArchAsyncTests   # Run only ArchAsync tests
swift test --filter testMethodName   # Run a single test by name
```

StrictConcurrency is enabled for all targets via `swiftSettings` in Package.swift.

## Architecture

This is a Swift Package (`Core`) providing two Redux/Elm-inspired unidirectional data flow architectures for SwiftUI — with no external dependencies.

### Two modules, same pattern

| | **Arch** (callback-based) | **ArchAsync** (Swift Concurrency) |
|---|---|---|
| Effect dispatch | Callback `(Event) -> Void` | Returns `AsyncStream<Event>` per effect |
| ViewStore | `ObservableObject` | `@Observable`, `@MainActor` |
| Effect execution | Synchronous dispatch | `Task.detached` |

**Data flow:** Event → Reducer (pure: `inout State + Event → Effect?`) → EffectHandler (side effects) → dispatches new Events back into the cycle.

**ViewStore** is the central coordinator: holds published state, invokes the reducer, forwards effects to the handler, and feeds handler-emitted events back into itself.

### Key protocols (per module)

- **Reducer** — pure function: mutates state, optionally returns an effect
- **EffectHandler** — executes side effects; in Arch via callback, in ArchAsync returns `AsyncStream<Event>` per effect

### Test conventions

- `makeSUT()` factory returning the system-under-test (with dependencies in ArchAsync)
- Spy implementations (`ReducerSpy`, `EffectHandlerSpy`) for verifying calls
- `trackForMemoryLeaks()` helper on every SUT to detect retain cycles
- ArchAsync tests use `XCTestExpectation` + `fulfillment(of:timeout:)` for async assertions

## Platform requirements

iOS 17+, macOS 14+, tvOS 17+, watchOS 10+ (Swift 5.10+, Observation framework required by ArchAsync).
