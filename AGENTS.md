# Repository Guidelines

## Project Structure & Module Organization
`DartMud.dart` is the server entrypoint and opens the listening socket on `127.0.0.1:5700`. `Connection.dart` handles low-level socket I/O. Game logic lives under `lib/`, with core modules such as `Mudlib.dart`, `Commands.dart`, `Login.dart`, `User.dart`, and `Room.dart`; room content is defined in `lib/rooms/`. Persistent player files are written to `users/*.usr`. Keep new gameplay code in `lib/` and reserve top-level files for entrypoint or transport concerns.

## Build, Test, and Development Commands
This repository predates modern Dart package layout, so there is no `pubspec.yaml` or formal build script.

- `dart DartMud.dart` starts the server if you have a legacy-compatible Dart runtime.
- `telnet localhost 5700` connects to the running MUD for manual testing.
- `git status` reviews your worktree before and after changes.

If the current Dart SDK rejects the old `#library`, `#import`, or `#source` syntax, treat the project as a legacy codebase and note compatibility issues in your PR.

## Coding Style & Naming Conventions
Follow the existing style: 2-space indentation, opening braces on the same line, and concise doc comments for non-obvious behavior. Preserve the repository’s naming patterns: `PascalCase` for classes (`ServerManager`), `camelCase` for methods and fields (`processCmd`, `currentRoom`), and short file names that match the main type or concern (`User.dart`, `Manager.dart`). Keep room definitions grouped under `lib/rooms/`.

## Testing Guidelines
There is no automated test suite yet. Validate changes with a manual smoke test: start the server, connect with `telnet`, create a user, run basic commands such as `help`, `look`, `say`, and `shutdown`, and confirm user files are written under `users/`. When fixing bugs, describe the exact manual reproduction steps in the PR.

## Commit & Pull Request Guidelines
Existing commits use short, imperative summaries such as `Updated readme file with basic usage information` and `Corrected onError callbacks to accept Exception`. Keep commit subjects brief, specific, and focused on one change. PRs should include a clear description, manual test notes, compatibility risks for modern Dart SDKs, and terminal excerpts when behavior changes are easiest to review from session output.

## Security & Configuration Notes
Do not expose this server publicly. The README explicitly notes weak security, no password encryption, and incomplete telnet support; keep testing on localhost unless hardening work is part of the change.
