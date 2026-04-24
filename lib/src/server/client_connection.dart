import 'dart:convert';
import 'dart:io';

abstract class ClientConnection {
  Stream<String> get lines;
  void write(String value);
  void writeln(String value);
  Future<void> close();
}

class SocketClientConnection implements ClientConnection {
  SocketClientConnection(this.socket) {
    _lines = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  final Socket socket;
  late final Stream<String> _lines;

  @override
  Stream<String> get lines => _lines;

  @override
  void write(String value) => socket.write(value);

  @override
  void writeln(String value) => socket.write('$value\n');

  @override
  Future<void> close() async {
    socket.write('Goodbye!\n');
    await socket.close();
  }
}
