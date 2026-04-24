import 'room.dart';

typedef RoomFactory = Room Function();

class RoomRegistry {
  RoomRegistry() {
    register(
      'void',
      () => Room(
        id: 'void',
        name: 'The Void',
        description: 'You are standing in the mists of the void. This is the '
            'place of nothingness. The most minimal of rooms to prevent any '
            'errors from occuring.',
      ),
    );
  }

  final Map<String, RoomFactory> _factories = <String, RoomFactory>{};
  final Map<String, Room> _cache = <String, Room>{};

  void register(String id, RoomFactory factory) {
    _factories[id] = factory;
  }

  Room? operator [](String id) {
    final factory = _factories[id];
    if (factory == null) {
      return null;
    }
    return _cache.putIfAbsent(id, factory);
  }

  Room fallbackRoom() => this['void']!;

  bool moveUser(dynamic user, String roomId) {
    final target = this[roomId];
    if (target == null) {
      return false;
    }

    final currentRoom = user.currentRoom;
    if (currentRoom != null) {
      currentRoom.removeObject(user);
    }

    if (!target.addObject(user)) {
      fallbackRoom().addObject(user);
    }

    return true;
  }
}
