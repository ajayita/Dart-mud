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
