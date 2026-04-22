# MUD Server Modernization Design

## Goal
Modernize this rudimentary Dart MUD server in three ordered phases so it runs on a current Dart toolchain, becomes testable and maintainable, and can then be optimized with measurement instead of guesswork.

## Scope
This design covers three linked sub-projects:

1. Dart 3 compatibility and package modernization
2. Maintainability and testability improvements
3. Runtime performance and connection scalability improvements

Small behavior and API changes are acceptable where they simplify the migration, but the core user-facing loop should remain intact: start server, connect over telnet, create or load a user, run room and chat commands, and shut the server down cleanly.

## Current State
The repository is a pre-`pubspec` Dart codebase using legacy `#library`, `#import`, and `#source` directives. Top-level files handle entrypoint and socket transport, while `lib/` contains world logic, login flow, commands, rooms, and persistence. The code uses synchronous file I/O for user data, manual telnet testing, and has no automated test suite. Compatibility with current Dart SDKs is likely broken.

## Approach
Use an incremental in-place migration. The codebase is small enough that a staged upgrade is practical, and retaining the current behavior as a reference reduces regression risk. Each phase should leave the server in a runnable state, with the next phase building on stable outputs from the previous one.

This is preferred over a full rewrite because the server is still small and understandable, and preferred over a compatibility-only patch because later maintainability and performance work would otherwise be done on unstable foundations.

## Phase 1: Dart 3 Compatibility
Convert the repository into a standard Dart package with modern entrypoint and library layout. Replace legacy directives with normal `import` statements, introduce null safety, and update APIs that have changed since the original code was written. Create a clear package boundary between executable startup code and reusable server modules.

Expected structural changes:

- Add `pubspec.yaml`
- Move the server entrypoint to `bin/`
- Keep domain logic under `lib/`
- Add `test/` for automated validation
- Add package-level import paths instead of relative `#source` inclusion

Primary success criteria:

- `dart run` starts the server on a current Dart SDK
- A telnet client can still connect locally
- Core login, command dispatch, room movement, and shutdown flows still work

## Phase 2: Maintainability and Testability
Refactor the code around explicit responsibilities. The existing code mixes transport, session state, world rules, command dispatch, and persistence in ways that make safe changes difficult. This phase introduces cleaner boundaries and enough tests to support later optimization.

Target module boundaries:

- Transport/server: socket accept loop and connection lifecycle
- Session/login: authentication, onboarding, prompt transitions
- Game world: rooms, objects, users, movement
- Command system: parsing, registration, dispatch, help text
- Persistence: user load/save storage interface and implementation

Testing strategy:

- Add unit tests for command parsing, room movement, and persistence behavior
- Add focused integration tests for login/session flow where practical
- Prefer dependency injection over globals so modules can be tested in isolation
- Preserve a small manual smoke-test checklist for telnet behavior

Primary success criteria:

- Core behaviors are covered by repeatable automated tests
- New features or fixes do not require reading the whole server to make safe changes
- Global mutable state is reduced or isolated behind narrow interfaces

## Phase 3: Performance and Scalability
Optimize only after compatibility and tests are in place. The current likely hotspots are synchronous disk access, command/session flow tied directly to socket events, and coarse-grained object management. Performance work should be driven by simple profiling and load experiments, not assumptions.

Priority optimization areas:

- Replace blocking user persistence with asynchronous storage operations where safe
- Reduce avoidable allocations and repeated scans in command and room operations
- Improve connection/session lifecycle handling for multiple simultaneous users
- Add lightweight instrumentation for connect, login, command latency, and save/load timing

Primary success criteria:

- The server remains responsive under multiple concurrent local clients
- User save/load operations no longer stall unrelated sessions
- Performance changes are backed by measurable before/after results

## Error Handling and Compatibility Policy
The migration may clean up rough edges in command parsing, error reporting, and internal APIs. Small incompatible changes are acceptable if they reduce complexity, but externally visible gameplay behavior should only change when the new behavior is clearly more correct or operationally safer. Any such changes should be documented in the implementation plans and PR notes.

## Risks
- Dart 3 migration may expose large API breakage because the source uses very old libraries and syntax.
- Introducing null safety may require revisiting assumptions across the whole object model.
- Testability work may reveal that some current behaviors depend on hidden global state.
- Async persistence changes may create ordering bugs if session shutdown is not handled carefully.

## Deliverables
- A Dart 3-compatible package layout
- Automated tests for the core gameplay loop
- A refactored module structure with clearer interfaces
- Basic performance instrumentation and measured optimization passes

## Recommended Execution Order
Execute the work as three separate implementation plans, one per phase, with each plan ending in runnable, verifiable software. Do not begin optimization work until the compatibility and testability phases are complete enough to support reliable measurement.
