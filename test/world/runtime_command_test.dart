import 'dart:async';
import 'dart:io';

import 'package:dartmud/src/server/client_connection.dart';
import 'package:dartmud/src/world/mud_runtime.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dartmud-runtime-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('successful login transitions to gameplay and saves on disconnect', () async {
    final runtime = MudRuntime(userBasePath: tempDir.path);
    final connection = FakeConnection();

    runtime.accept(connection);
    connection.addLine('c');
    connection.addLine('andy');
    connection.addLine('secret');
    connection.addLine('secret');
    await pumpEventQueue();

    expect(connection.output, contains('The Void'));

    connection.addLine('prompt hp>');
    connection.addLine('exit');
    await pumpEventQueue();

    final saved = File('${tempDir.path}/andy.usr');
    expect(await saved.exists(), isTrue);
    expect(await saved.readAsString(), contains('"prompt":"hp> "'));
  });

  test('say, who, broadcast and shutdown behave across sessions', () async {
    final runtime = MudRuntime(userBasePath: tempDir.path);
    final alpha = FakeConnection();
    final beta = FakeConnection();

    runtime.accept(alpha);
    runtime.accept(beta);

    alpha
      ..addLine('c')
      ..addLine('alan')
      ..addLine('secret')
      ..addLine('secret');
    beta
      ..addLine('c')
      ..addLine('beta')
      ..addLine('secret')
      ..addLine('secret');
    await pumpEventQueue();
    await pumpEventQueue();

    alpha.addLine('say hello');
    alpha.addLine('who');
    alpha.addLine('broadcast reboot soon');
    await pumpEventQueue();

    expect(alpha.output, contains('You say: hello'));
    expect(beta.output, contains('alan says: hello'));
    expect(alpha.output, contains('Currently logged in users'));
    expect(alpha.output, contains('alan'));
    expect(alpha.output, contains('beta'));
    expect(beta.output, contains('Broadcast (alan): reboot soon'));

    alpha.addLine('shutdown');
    await pumpEventQueue();

    expect(alpha.closed, isTrue);
    expect(beta.closed, isTrue);
  });

  test('home command moves Matt to the initialized home room', () async {
    final runtime = MudRuntime(userBasePath: tempDir.path);
    final connection = FakeConnection();

    runtime.accept(connection);
    connection
      ..addLine('c')
      ..addLine('Matt')
      ..addLine('secret')
      ..addLine('secret');
    await pumpEventQueue();

    connection.addLine('north');
    await pumpEventQueue();
    expect(connection.output, contains('Maliche Square'));

    connection.addLine('home');
    await pumpEventQueue();
    expect(connection.output, contains('Simple Workshop'));
  });

  test('ed command enters editor mode and writes long description', () async {
    final runtime = MudRuntime(userBasePath: tempDir.path);
    final connection = FakeConnection();

    runtime.accept(connection);
    connection
      ..addLine('c')
      ..addLine('writer')
      ..addLine('secret')
      ..addLine('secret');
    await pumpEventQueue();

    connection
      ..addLine('ed')
      ..addLine('a')
      ..addLine('A careful description.')
      ..addLine('.')
      ..addLine('q');
    await pumpEventQueue();

    connection.addLine('exit');
    await pumpEventQueue();

    final saved = File('${tempDir.path}/writer.usr');
    expect(await saved.readAsString(), contains('"longDesc":"A careful description.\\n"'));
  });
}

class FakeConnection implements ClientConnection {
  final StreamController<String> _controller = StreamController<String>();
  final StringBuffer _buffer = StringBuffer();
  bool closed = false;

  @override
  Stream<String> get lines => _controller.stream;

  String get output => _buffer.toString();

  void addLine(String line) {
    if (!closed) {
      _controller.add(line);
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await _controller.close();
  }

  @override
  void write(String value) {
    _buffer.write(value);
  }

  @override
  void writeln(String value) {
    _buffer.writeln(value);
  }
}
