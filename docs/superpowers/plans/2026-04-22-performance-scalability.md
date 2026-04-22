# Performance and Scalability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve responsiveness and concurrency of the modernized MUD server with measured, low-risk optimizations.

**Architecture:** Add lightweight instrumentation first, then optimize blocking persistence and hot-path command or room operations. Keep behavior stable and prefer changes that reduce latency under multiple simultaneous local clients.

**Tech Stack:** Dart 3, `dart:io`, `dart:async`, `package:test`, simple benchmark harnesses

---

### Task 1: Add Instrumentation and Baseline Benchmarks

**Files:**
- Create: `lib/src/diagnostics/runtime_metrics.dart`
- Create: `tool/benchmark_smoke.dart`
- Create: `test/perf/runtime_metrics_test.dart`
- Modify: `lib/src/world/mud_runtime.dart`
- Modify: `lib/src/server/dartmud_server.dart`

- [ ] **Step 1: Write the failing metrics test**

```dart
import 'package:dartmud/src/diagnostics/runtime_metrics.dart';
import 'package:test/test.dart';

void main() {
  test('metrics capture durations by operation name', () {
    final metrics = RuntimeMetrics();
    metrics.record('login', const Duration(milliseconds: 4));
    expect(metrics.snapshot()['login']?.count, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/perf/runtime_metrics_test.dart -r expanded`
Expected: FAIL because metrics types do not exist.

- [ ] **Step 3: Implement in-process metrics collection**

```dart
class MetricSample {
  MetricSample(this.count, this.total);

  final int count;
  final Duration total;
}

class RuntimeMetrics {
  final Map<String, MetricSample> _samples = {};

  void record(String name, Duration duration) {
    final current = _samples[name];
    _samples[name] = current == null
        ? MetricSample(1, duration)
        : MetricSample(current.count + 1, current.total + duration);
  }

  Map<String, MetricSample> snapshot() => Map.unmodifiable(_samples);
}
```

- [ ] **Step 4: Add a repeatable benchmark harness**

```dart
Future<void> main() async {
  final stopwatch = Stopwatch()..start();
  final server = DartMudServer(host: '127.0.0.1', port: 0);
  await server.start();
  stopwatch.stop();
  print('startup_ms=${stopwatch.elapsedMilliseconds}');
  await server.stop();
}
```

- [ ] **Step 5: Run baseline verification**

Run: `dart test test/perf/runtime_metrics_test.dart -r expanded && dart run tool/benchmark_smoke.dart`
Expected: metrics test PASS and benchmark prints a startup timing line.

- [ ] **Step 6: Commit**

```bash
git add lib/src/diagnostics/runtime_metrics.dart tool/benchmark_smoke.dart test/perf/runtime_metrics_test.dart lib/src/world/mud_runtime.dart lib/src/server/dartmud_server.dart
git commit -m "perf: add runtime metrics and baseline benchmark"
```

### Task 2: Remove Blocking Persistence From the Session Hot Path

**Files:**
- Create: `lib/src/world/persistence/account_write_queue.dart`
- Create: `test/perf/account_write_queue_test.dart`
- Modify: `lib/src/world/persistence/account_repository.dart`
- Modify: `lib/src/world/persistence/user_store.dart`
- Modify: `lib/src/world/session/login_service.dart`

- [ ] **Step 1: Write the failing write-queue test**

```dart
import 'package:dartmud/src/world/persistence/account_write_queue.dart';
import 'package:test/test.dart';

void main() {
  test('queue serializes writes for the same repository', () async {
    final queue = AccountWriteQueue();
    final events = <int>[];
    await Future.wait([
      queue.enqueue(() async => events.add(1)),
      queue.enqueue(() async => events.add(2)),
    ]);
    expect(events, [1, 2]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/perf/account_write_queue_test.dart -r expanded`
Expected: FAIL because the queue does not exist.

- [ ] **Step 3: Implement a serialized async write queue**

```dart
class AccountWriteQueue {
  Future<void> _tail = Future.value();

  Future<void> enqueue(Future<void> Function() action) {
    _tail = _tail.then((_) => action());
    return _tail;
  }
}
```

- [ ] **Step 4: Route account saves through the queue**

```dart
class QueuedAccountRepository implements AccountRepository {
  QueuedAccountRepository(this.delegate, this.queue);

  final AccountRepository delegate;
  final AccountWriteQueue queue;

  @override
  Future<UserAccount?> load(String username) => delegate.load(username);

  @override
  Future<void> save(UserAccount account) {
    return queue.enqueue(() => delegate.save(account));
  }
}
```

- [ ] **Step 5: Run verification**

Run: `dart test test/perf/account_write_queue_test.dart -r expanded && dart test -r expanded`
Expected: queue test PASS and the full suite still PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/world/persistence/account_write_queue.dart lib/src/world/persistence/account_repository.dart lib/src/world/persistence/user_store.dart lib/src/world/session/login_service.dart test/perf/account_write_queue_test.dart
git commit -m "perf: queue persistence writes off the hot path"
```

### Task 3: Optimize Command Parsing and Room Access Hot Paths

**Files:**
- Create: `test/perf/command_dispatcher_perf_test.dart`
- Modify: `tool/benchmark_smoke.dart`
- Modify: `lib/src/world/commands/command_dispatcher.dart`
- Modify: `lib/src/world/commands/command_registry.dart`
- Modify: `lib/src/world/rooms/room_registry.dart`

- [ ] **Step 1: Write the failing hot-path regression test**

```dart
import 'package:dartmud/src/world/commands/command_dispatcher.dart';
import 'package:test/test.dart';

void main() {
  test('parse does not allocate when no args are present', () {
    final parsed = CommandDispatcher(registry: CommandRegistry()).parse('look');
    expect(parsed.args, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails or exposes weak API contracts**
 - [ ] **Step 2: Run test to verify current parser behavior and capture a baseline**

Run: `dart test test/perf/command_dispatcher_perf_test.dart -r expanded`
Expected: PASS for correctness; record the benchmark output before changing the parser.

- [ ] **Step 3: Tighten parsing and lookup APIs**

```dart
class CommandDispatcher {
  ParsedCommand parse(String line) {
    final trimmed = line.trim();
    final space = trimmed.indexOf(' ');
    return space < 0
        ? ParsedCommand(trimmed, '')
        : ParsedCommand(trimmed.substring(0, space), trimmed.substring(space + 1).trim());
  }
}
```

```dart
class RoomRegistry {
  final Map<String, Room> _cache = {};

  Room? lookup(String id) => _cache[id];
}
```

- [ ] **Step 4: Benchmark command and room lookups**

```dart
void main() {
  final dispatcher = CommandDispatcher(registry: CommandRegistry());
  final watch = Stopwatch()..start();
  for (var i = 0; i < 100000; i++) {
    dispatcher.parse('say hello');
  }
  watch.stop();
  print('parse_100k_us=${watch.elapsedMicroseconds}');
}
```

- [ ] **Step 5: Run verification**

Run: `dart test test/perf/command_dispatcher_perf_test.dart -r expanded && dart run tool/benchmark_smoke.dart`
Expected: correctness test PASS and benchmark output available for before/after comparison.

- [ ] **Step 6: Commit**

```bash
git add lib/src/world/commands/command_dispatcher.dart lib/src/world/commands/command_registry.dart lib/src/world/rooms/room_registry.dart test/perf/command_dispatcher_perf_test.dart tool/benchmark_smoke.dart
git commit -m "perf: optimize command parsing and room lookup"
```

### Task 4: Validate Multi-Client Responsiveness

**Files:**
- Create: `tool/load_test.dart`
- Create: `test/perf/multi_client_smoke_test.dart`
- Create: `test/support/perf_harness.dart`
- Modify: `lib/src/server/client_connection.dart`
- Modify: `lib/src/server/dartmud_server.dart`

- [ ] **Step 1: Write the failing multi-client smoke test**

```dart
import 'package:test/test.dart';
import '../support/perf_harness.dart';

void main() {
  test('multiple sessions can connect and disconnect cleanly', () async {
    final server = await PerfHarness.start();
    await server.connectClients(5);
    expect(server.connectedClients, 5);
    await server.stop();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/perf/multi_client_smoke_test.dart -r expanded`
Expected: FAIL because the harness and connection counting hooks do not exist.

- [ ] **Step 3: Add connection counters and a simple load harness**

```dart
class DartMudServer {
  int activeConnections = 0;

  Future<void> start() async {
    _socket = await ServerSocket.bind(host, port);
    _socket!.listen((socket) {
      activeConnections++;
      socket.done.whenComplete(() => activeConnections--);
      _runtime.accept(ClientConnection(socket));
    });
  }
}
```

```dart
class PerfHarness {
  PerfHarness(this.server, this.port);

  final DartMudServer server;
  final int port;
  final List<Socket> sockets = [];

  int get connectedClients => sockets.length;

  static Future<PerfHarness> start() async {
    final server = DartMudServer(host: '127.0.0.1', port: 0);
    await server.start();
    return PerfHarness(server, server.boundPort);
  }

  Future<void> connectClients(int count) async {
    for (var i = 0; i < count; i++) {
      sockets.add(await Socket.connect('127.0.0.1', port));
    }
  }

  Future<void> stop() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.stop();
  }
}
```

```dart
Future<void> main() async {
  final harness = await PerfHarness.start();
  await harness.connectClients(10);
  print('connected=${harness.connectedClients}');
  await harness.stop();
}
```

- [ ] **Step 4: Run measured load verification**

Run: `dart test test/perf/multi_client_smoke_test.dart -r expanded && dart run tool/load_test.dart`
Expected: smoke test PASS and load tool prints a connection count without hangs.

- [ ] **Step 5: Run full phase verification**

Run: `dart test -r expanded && dart analyze`
Expected: full suite PASS, analyzer PASS.

- [ ] **Step 6: Commit**

```bash
git add tool/load_test.dart test/perf/multi_client_smoke_test.dart lib/src/server/client_connection.dart lib/src/server/dartmud_server.dart
git commit -m "perf: verify multi-client responsiveness"
```
