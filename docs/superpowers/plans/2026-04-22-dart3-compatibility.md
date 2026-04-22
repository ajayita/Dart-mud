# Dart 3 Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the legacy MUD into a runnable Dart 3 package without losing the core telnet gameplay loop.

**Architecture:** Repackage the project as a standard Dart application with a `bin/` entrypoint and `lib/src/` modules. Replace deprecated directives and APIs first, then stabilize behavior with smoke tests and a small regression test harness.

**Tech Stack:** Dart 3, `package:test`, `dart:io`, JSON file persistence

---

### Task 1: Create Modern Package Layout

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `bin/dartmud.dart`
- Create: `lib/dartmud.dart`
- Create: `test/smoke/package_layout_test.dart`
- Modify: `.gitignore`

- [ ] **Step 1: Write the failing package-layout test**

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('modern package files exist', () {
    expect(File('pubspec.yaml').existsSync(), isTrue);
    expect(File('bin/dartmud.dart').existsSync(), isTrue);
    expect(File('lib/dartmud.dart').existsSync(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/smoke/package_layout_test.dart -r expanded`
Expected: FAIL with missing file assertions or package-resolution errors.

- [ ] **Step 3: Add package metadata and entrypoint scaffolding**

```yaml
name: dartmud
description: A rudimentary telnet MUD server modernized for Dart 3.
version: 0.1.0
environment:
  sdk: ^3.0.0
dev_dependencies:
  lints: ^5.0.0
  test: ^1.25.0
```

```dart
import 'package:dartmud/dartmud.dart';

Future<void> main() async {
  final server = DartMudServer();
  await server.start();
}
```

```dart
library dartmud;

export 'src/server/dartmud_server.dart';
```

- [ ] **Step 4: Add analyzer configuration and ignore generated runtime data**

```yaml
include: package:lints/recommended.yaml

linter:
  rules:
    avoid_print: false
```

```gitignore
.dart_tool/
build/
users/*.usr
```

- [ ] **Step 5: Run the test suite and package tooling**

Run: `dart pub get && dart test test/smoke/package_layout_test.dart -r expanded && dart analyze`
Expected: package test PASS, analyzer either PASS or fail only on not-yet-migrated source files that are not imported.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml analysis_options.yaml .gitignore bin/dartmud.dart lib/dartmud.dart test/smoke/package_layout_test.dart
git commit -m "build: create Dart 3 package scaffold"
```

### Task 2: Migrate Server Bootstrap and Socket Transport

**Files:**
- Create: `lib/src/server/dartmud_server.dart`
- Create: `lib/src/server/client_connection.dart`
- Create: `test/server/server_start_test.dart`
- Modify: `DartMud.dart`
- Modify: `Connection.dart`

- [ ] **Step 1: Write the failing server start test**

```dart
import 'package:dartmud/dartmud.dart';
import 'package:test/test.dart';

void main() {
  test('server can start and stop on loopback', () async {
    final server = DartMudServer(host: '127.0.0.1', port: 0);
    await server.start();
    expect(server.isRunning, isTrue);
    await server.stop();
    expect(server.isRunning, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/server/server_start_test.dart -r expanded`
Expected: FAIL because `DartMudServer` does not exist.

- [ ] **Step 3: Implement modern async server bootstrap**

```dart
import 'dart:io';

import 'client_connection.dart';
import '../world/mud_runtime.dart';

class DartMudServer {
  DartMudServer({this.host = '127.0.0.1', this.port = 5700});

  final String host;
  final int port;
  final MudRuntime _runtime = MudRuntime();
  ServerSocket? _socket;

  bool get isRunning => _socket != null;

  Future<void> start() async {
    _socket = await ServerSocket.bind(host, port);
    _socket!.listen((socket) {
      final connection = ClientConnection(socket);
      _runtime.accept(connection);
    });
  }

  Future<void> stop() async {
    await _runtime.shutdown();
    await _socket?.close();
    _socket = null;
  }
}
```

- [ ] **Step 4: Replace legacy `Connection` stream handling with Dart 3 stream APIs**

```dart
import 'dart:convert';
import 'dart:io';

class ClientConnection {
  ClientConnection(this.socket) {
    _lines = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  final Socket socket;
  late final Stream<String> _lines;

  Stream<String> get lines => _lines;
  void write(String value) => socket.write(value);
  void writeln(String value) => socket.write('$value\n');
  Future<void> close() => socket.close();
}
```

- [ ] **Step 5: Run focused verification**

Run: `dart test test/server/server_start_test.dart -r expanded && dart analyze`
Expected: server start test PASS, analyzer identifies remaining migration work in world modules only.

- [ ] **Step 6: Commit**

```bash
git add lib/src/server/dartmud_server.dart lib/src/server/client_connection.dart test/server/server_start_test.dart bin/dartmud.dart lib/dartmud.dart
git commit -m "refactor: modernize server bootstrap"
```

### Task 3: Port World Runtime, Login, and Persistence to Modern Imports

**Files:**
- Create: `lib/src/world/mud_runtime.dart`
- Create: `lib/src/world/login/login_controller.dart`
- Create: `lib/src/world/persistence/user_store.dart`
- Create: `lib/src/world/model/user_account.dart`
- Create: `test/world/login_controller_test.dart`
- Modify: `lib/Mudlib.dart`
- Modify: `lib/Login.dart`
- Modify: `lib/User.dart`

- [ ] **Step 1: Write the failing login test**

```dart
import 'package:dartmud/src/world/login/login_controller.dart';
import 'package:test/test.dart';

void main() {
  test('new users move through create-account flow', () async {
    final controller = LoginController();
    final prompt = controller.start();
    expect(prompt, contains('Create'));
    expect(controller.handleLine('c'), contains('username'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/world/login_controller_test.dart -r expanded`
Expected: FAIL because `LoginController` and its dependencies do not exist.

- [ ] **Step 3: Introduce null-safe runtime and persistence types**

```dart
class UserAccount {
  UserAccount({
    required this.username,
    required this.password,
    this.prompt = '> ',
    this.longDescription = '',
  });

  final String username;
  final String password;
  final String prompt;
  final String longDescription;

  Map<String, Object?> toJson() => {
        'username': username,
        'password': password,
        'prompt': prompt,
        'longDesc': longDescription,
      };
}
```

```dart
import 'dart:convert';
import 'dart:io';

import '../model/user_account.dart';

class UserStore {
  Future<UserAccount?> load(String username) async {
    final file = File('users/$username.usr');
    if (!await file.exists()) return null;
    final jsonMap = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return UserAccount(
      username: jsonMap['username']! as String,
      password: jsonMap['password']! as String,
      prompt: (jsonMap['prompt'] as String?) ?? '> ',
      longDescription: (jsonMap['longDesc'] as String?) ?? '',
    );
  }
}
```

- [ ] **Step 4: Port the login state machine behind a modern controller**

```dart
enum LoginStage { chooseMode, existingUser, existingPassword, newUser, newPassword, confirmPassword }

class LoginController {
  LoginStage stage = LoginStage.chooseMode;

  String start() => 'Welcome to DartMud!\n\nDo you wish to [C]reate an account or [L]ogin?: ';

  String handleLine(String line) {
    switch (stage) {
      case LoginStage.chooseMode:
        if (line.toLowerCase().startsWith('c')) {
          stage = LoginStage.newUser;
          return 'Please choose a username for your new character: ';
        }
        stage = LoginStage.existingUser;
        return 'Please enter your username: ';
      case LoginStage.existingUser:
        stage = LoginStage.existingPassword;
        return 'Please enter your password: ';
      case LoginStage.existingPassword:
        return 'Password received. Loading your character...';
      case LoginStage.newUser:
        stage = LoginStage.newPassword;
        return 'Please choose a password: ';
      case LoginStage.newPassword:
        stage = LoginStage.confirmPassword;
        return 'Please confirm your password: ';
      case LoginStage.confirmPassword:
        return 'Passwords match. Creating your character...';
    }
  }
}
```

- [ ] **Step 5: Run targeted verification**

Run: `dart test test/world/login_controller_test.dart -r expanded && dart analyze`
Expected: login test PASS; analyzer still reports remaining import fixes in commands/rooms until Task 4.

- [ ] **Step 6: Commit**

```bash
git add lib/src/world/mud_runtime.dart lib/src/world/login/login_controller.dart lib/src/world/persistence/user_store.dart lib/src/world/model/user_account.dart test/world/login_controller_test.dart
git commit -m "refactor: port runtime login and persistence"
```

### Task 4: Port Commands, Rooms, and Legacy Domain Types

**Files:**
- Create: `lib/src/world/commands/command_registry.dart`
- Create: `lib/src/world/rooms/room.dart`
- Create: `lib/src/world/rooms/room_registry.dart`
- Create: `lib/src/world/model/game_object.dart`
- Create: `lib/src/world/model/container.dart`
- Create: `test/world/room_registry_test.dart`
- Modify: `lib/Commands.dart`
- Modify: `lib/Room.dart`
- Modify: `lib/GameObject.dart`
- Modify: `lib/Container.dart`

- [ ] **Step 1: Write the failing room movement test**

```dart
import 'package:dartmud/src/world/rooms/room_registry.dart';
import 'package:test/test.dart';

void main() {
  test('room registry lazily builds registered rooms', () {
    final rooms = RoomRegistry();
    rooms.register('void', () => Room(id: 'void', name: 'The Void', description: 'Fallback'));
    expect(rooms['void']?.name, 'The Void');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/world/room_registry_test.dart -r expanded`
Expected: FAIL because the modern room types do not exist.

- [ ] **Step 3: Implement null-safe room and registry types**

```dart
class Room {
  Room({required this.id, required this.name, required this.description});

  final String id;
  final String name;
  final String description;
  final Map<String, String> exits = {};
}
```

```dart
typedef RoomFactory = Room Function();

class RoomRegistry {
  final Map<String, RoomFactory> _factories = {};
  final Map<String, Room> _cache = {};

  void register(String id, RoomFactory factory) => _factories[id] = factory;
  Room? operator [](String id) => _cache[id] ??= _factories[id]?.call();
}
```

- [ ] **Step 4: Port command registration away from global mutable singletons**

```dart
typedef CommandHandler = Future<void> Function(CommandContext context, String args);

class CommandRegistry {
  final Map<String, CommandHandler> _handlers = {};

  void register(String name, CommandHandler handler) {
    if (_handlers.containsKey(name)) {
      throw StateError('Duplicate command: $name');
    }
    _handlers[name] = handler;
  }

  CommandHandler? lookup(String name) => _handlers[name];
}
```

- [ ] **Step 5: Run full phase verification**

Run: `dart test -r expanded && dart analyze && dart run bin/dartmud.dart`
Expected: tests PASS, analyzer PASS, server starts and logs a loopback bind message.

- [ ] **Step 6: Commit**

```bash
git add lib/src/world/commands/command_registry.dart lib/src/world/rooms/room.dart lib/src/world/rooms/room_registry.dart lib/src/world/model/game_object.dart lib/src/world/model/container.dart test/world/room_registry_test.dart
git commit -m "refactor: port world commands and rooms to Dart 3"
```
