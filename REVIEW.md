# Code Review Guidelines

## Architecture (Redux/Elm pattern)

- Reducer must be a pure function — no side effects, only state mutation and optional effect return
- EffectHandler is the only place for side effects
- Each EffectHandler invocation must return an isolated stream (not shared across calls)
- Event flow is closed-loop: Event → Reducer → Effect → EffectHandler → Event

## Swift Concurrency

- Tasks created inside objects must be cancelled on deinit
- Task collections (TasksBag, etc.) must prune completed tasks — check for unbounded growth
- `async` in protocol signatures only when async initialization is genuinely needed
- Verify Sendable conformance and correct actor isolation
- AsyncStream continuation must call `finish()` on all termination paths

## Resource management

- Collections with append but no remove — potential memory leak
- deinit must properly release resources (cancel tasks, finish streams)
- Check for retain cycles, especially in closures captured by Task

## Tests

- Spy objects must be isolated between calls (no shared state across invocations)
- `trackForMemoryLeaks()` is required on every SUT
- Verify that assertions actually test the claimed behavior
