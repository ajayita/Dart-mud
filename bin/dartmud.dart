import 'package:dartmud/dartmud.dart';

Future<void> main() async {
  final server = DartMudServer();
  await server.start();
}
