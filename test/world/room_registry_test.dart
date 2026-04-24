import 'package:dartmud/src/world/rooms/room.dart';
import 'package:dartmud/src/world/rooms/room_registry.dart';
import 'package:test/test.dart';

void main() {
  test('room registry lazily builds registered rooms', () {
    final rooms = RoomRegistry();

    rooms.register(
      'void',
      () => Room(id: 'void', name: 'The Void', description: 'Fallback'),
    );

    expect(rooms['void']?.name, 'The Void');
  });
}
