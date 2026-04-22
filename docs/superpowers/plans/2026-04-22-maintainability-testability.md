# Maintainability and Testability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the modernized server into clear modules with repeatable automated tests for the gameplay loop.

**Architecture:** Extract transport, session/login, world state, commands, and persistence behind explicit interfaces. Replace global singletons with injected collaborators so unit and integration tests can run without a live socket server.

**Tech Stack:** Dart 3, `package:test`, `dart:io`, dependency-injected services

---

### Task 1: Introduce Storage and Session Interfaces

**Files:**
- Create: `lib/src/world/persistence/account_repository.dart`
- Create: `lib/src/world/session/session.dart`
- Create: `test/world/persistence/account_repository_test.dart`
- Modify: `lib/src/world/persistence/user_store.dart`
- Modify: `lib/src/world/mud_runtime.dart`

- [ ] **Step 1: Write the failing repository contract test**

```dart
import 'package:dartmud/src/world/model/user_account.dart';
import 'package:dartmud/src/world/persistence/account_repository.dart';
import 'package:test/test.dart';

void main() {
  test('repository can save and reload accounts', () async {
    final repo = InMemoryAccountRepository();
    final account = UserAccount(username: 'matt', password: 'secret');
    await repo.save(account);
    expect(await repo.load('matt'), isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/world/persistence/account_repository_test.dart -r expanded`
Expected: FAIL because repository abstractions do not exist.

- [ ] **Step 3: Define repository and session interfaces**

```dart
import '../model/user_account.dart';

abstract interface class AccountRepository {
  Future<UserAccount?> load(String username);
  Future<void> save(UserAccount account);
}

class InMemoryAccountRepository implements AccountRepository {
  final Map<String, UserAccount> _accounts = {};

  @override
  Future<UserAccount?> load(String username) async => _accounts[username];

  @override
  Future<void> save(UserAccount account) async {
    _accounts[account.username] = account;
  }
}
```

```dart
abstract interface class Session {
  String get id;
  String get prompt;
  Future<void> send(String text);
  Future<void> close();
}
```

- [ ] **Step 4: Adapt runtime to depend on interfaces instead of concrete file I/O**

```dart
class MudRuntime {
  MudRuntime({AccountRepository? accounts})
      : accounts = accounts ?? FileAccountRepository();

  final AccountRepository accounts;
}
```

- [ ] **Step 5: Run verification**

Run: `dart test test/world/persistence/account_repository_test.dart -r expanded && dart analyze`
Expected: repository test PASS, analyzer PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/world/persistence/account_repository.dart lib/src/world/session/session.dart lib/src/world/persistence/user_store.dart lib/src/world/mud_runtime.dart test/world/persistence/account_repository_test.dart
git commit -m "refactor: add repository and session interfaces"
```

### Task 2: Refactor Login Flow Into a Testable Session Service

**Files:**
- Create: `lib/src/world/session/login_service.dart`
- Create: `test/world/session/login_service_test.dart`
- Modify: `lib/src/world/login/login_controller.dart`
- Modify: `lib/src/world/mud_runtime.dart`

- [ ] **Step 1: Write the failing login service test**

```dart
import 'package:dartmud/src/world/persistence/account_repository.dart';
import 'package:dartmud/src/world/session/login_service.dart';
import 'package:test/test.dart';

void main() {
  test('create flow persists a new account', () async {
    final repo = InMemoryAccountRepository();
    final service = LoginService(accounts: repo);
    await service.receive('c');
    await service.receive('builder');
    await service.receive('secret');
    await service.receive('secret');
    expect(await repo.load('builder'), isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/world/session/login_service_test.dart -r expanded`
Expected: FAIL because `LoginService` does not exist.

- [ ] **Step 3: Build a stateful login service with explicit transitions**

```dart
class LoginService {
  LoginService({required this.accounts});

  final AccountRepository accounts;
  LoginStage stage = LoginStage.chooseMode;
  String? pendingUsername;
  String? pendingPassword;

  Future<String> receive(String line) async {
    switch (stage) {
      case LoginStage.chooseMode:
        stage = line.toLowerCase().startsWith('c')
            ? LoginStage.newUser
            : LoginStage.existingUser;
        return stage == LoginStage.newUser
            ? 'Please choose a username for your new character: '
            : 'Please enter your username: ';
      case LoginStage.newUser:
        pendingUsername = line.trim();
        stage = LoginStage.newPassword;
        return 'Please choose a password: ';
      case LoginStage.newPassword:
        pendingPassword = line;
        stage = LoginStage.confirmPassword;
        return 'Please confirm your password: ';
      case LoginStage.confirmPassword:
        await accounts.save(UserAccount(
          username: pendingUsername!,
          password: pendingPassword!,
        ));
        return 'Account created.';
      case LoginStage.existingUser:
        pendingUsername = line.trim();
        stage = LoginStage.existingPassword;
        return 'Please enter your password: ';
      case LoginStage.existingPassword:
        return 'Password accepted. Entering the world...';
    }
  }
}
```

- [ ] **Step 4: Move socket-bound prompt handling out of the service**

```dart
class SessionCoordinator {
  SessionCoordinator({required this.loginService, required this.session});

  final LoginService loginService;
  final Session session;

  Future<void> onLine(String line) async {
    final response = await loginService.receive(line);
    await session.send(response);
  }
}
```

- [ ] **Step 5: Run verification**

Run: `dart test test/world/session/login_service_test.dart -r expanded && dart analyze`
Expected: login service tests PASS, analyzer PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/world/session/login_service.dart lib/src/world/login/login_controller.dart lib/src/world/mud_runtime.dart test/world/session/login_service_test.dart
git commit -m "refactor: isolate login flow from sockets"
```

### Task 3: Extract Command Dispatch and World Services

**Files:**
- Create: `lib/src/world/commands/command_dispatcher.dart`
- Create: `lib/src/world/world_service.dart`
- Create: `lib/src/world/model/game_user.dart`
- Create: `test/world/commands/command_dispatcher_test.dart`
- Modify: `lib/src/world/commands/command_registry.dart`
- Modify: `lib/src/world/rooms/room_registry.dart`
- Modify: `lib/src/world/mud_runtime.dart`

- [ ] **Step 1: Write the failing dispatcher test**

```dart
import 'package:dartmud/src/world/commands/command_dispatcher.dart';
import 'package:test/test.dart';

void main() {
  test('dispatcher splits command names from arguments', () async {
    final dispatcher = CommandDispatcher(registry: CommandRegistry());
    final result = dispatcher.parse('say hello world');
    expect(result.name, 'say');
    expect(result.args, 'hello world');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/world/commands/command_dispatcher_test.dart -r expanded`
Expected: FAIL because dispatcher parsing types do not exist.

- [ ] **Step 3: Create a dedicated parser and dispatcher**

```dart
class ParsedCommand {
  ParsedCommand(this.name, this.args);

  final String name;
  final String args;
}

class CommandDispatcher {
  CommandDispatcher({required this.registry});

  final CommandRegistry registry;

  ParsedCommand parse(String line) {
    final trimmed = line.trim();
    final space = trimmed.indexOf(' ');
    if (space == -1) return ParsedCommand(trimmed.toLowerCase(), '');
    return ParsedCommand(
      trimmed.substring(0, space).toLowerCase(),
      trimmed.substring(space + 1).trim(),
    );
  }
}
```

- [ ] **Step 4: Move movement and room lookup behavior into world service**

```dart
class GameUser {
  GameUser({required this.name});

  final String name;
  Room? currentRoom;
}

class WorldService {
  WorldService({required this.rooms});

  final RoomRegistry rooms;

  bool moveUser(GameUser user, String roomId) {
    final destination = rooms[roomId];
    if (destination == null) return false;
    user.currentRoom?.remove(user);
    destination.add(user);
    user.currentRoom = destination;
    return true;
  }
}
```

- [ ] **Step 5: Run verification**

Run: `dart test test/world/commands/command_dispatcher_test.dart -r expanded && dart test -r expanded`
Expected: new dispatcher test PASS and existing suite remains PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/world/commands/command_dispatcher.dart lib/src/world/world_service.dart lib/src/world/commands/command_registry.dart lib/src/world/rooms/room_registry.dart lib/src/world/mud_runtime.dart test/world/commands/command_dispatcher_test.dart
git commit -m "refactor: separate command dispatch and world services"
```

### Task 4: Add Integration Tests for the Core Gameplay Loop

**Files:**
- Create: `test/integration/telnet_session_test.dart`
- Create: `test/support/fake_session.dart`
- Modify: `lib/src/server/client_connection.dart`
- Modify: `lib/src/world/mud_runtime.dart`

- [ ] **Step 1: Write the failing integration test**

```dart
import 'package:test/test.dart';

void main() {
  test('user can create an account and reach the default room', () async {
    final harness = await TestHarness.start();
    await harness.send('c');
    await harness.send('builder');
    await harness.send('secret');
    await harness.send('secret');
    expect(await harness.readAll(), contains('The Void'));
    await harness.stop();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/integration/telnet_session_test.dart -r expanded`
Expected: FAIL because no test harness or fake session adapter exists.

- [ ] **Step 3: Add a fake session and harness for runtime-level tests**

```dart
class FakeSession implements Session {
  @override
  String id = 'test-session';

  @override
  String prompt = '> ';

  final List<String> output = [];

  @override
  Future<void> send(String text) async => output.add(text);

  @override
  Future<void> close() async {}
}
```

- [ ] **Step 4: Wire runtime APIs to support test harness setup without a real socket**

```dart
class TestHarness {
  TestHarness(this.runtime, this.session);

  final MudRuntime runtime;
  final FakeSession session;

  static Future<TestHarness> start() async {
    final runtime = MudRuntime(accounts: InMemoryAccountRepository());
    final session = FakeSession();
    await runtime.acceptSession(session);
    return TestHarness(runtime, session);
  }
}
```

- [ ] **Step 5: Run full maintainability verification**

Run: `dart test -r expanded && dart analyze`
Expected: all unit and integration tests PASS, analyzer PASS.

- [ ] **Step 6: Commit**

```bash
git add test/integration/telnet_session_test.dart test/support/fake_session.dart lib/src/server/client_connection.dart lib/src/world/mud_runtime.dart
git commit -m "test: cover the core gameplay loop"
```
