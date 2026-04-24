import 'dart:io';

import '../world/mud_runtime.dart';
import 'client_connection.dart';

class DartMudServer {
  DartMudServer({
    this.host = '127.0.0.1',
    this.port = 5700,
    String userBasePath = 'users',
  }) : _runtime = MudRuntime(userBasePath: userBasePath);

  final String host;
  final int port;
  final MudRuntime _runtime;
  ServerSocket? _socket;

  bool get isRunning => _socket != null;

  Future<void> start() async {
    _socket = await ServerSocket.bind(host, port);
    print('DartMud server listening on ${_socket!.address.address}:${_socket!.port}');
    _socket!.listen((socket) {
      _runtime.accept(SocketClientConnection(socket));
    });
  }

  Future<void> stop() async {
    await _runtime.shutdown();
    await _socket?.close();
    _socket = null;
  }
}
