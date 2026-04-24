import '../model/container.dart';
import '../model/game_object.dart';
import '../user.dart';

class Room extends ContainerImpl {
  Room({
    required this.id,
    required String name,
    required String description,
  }) : exits = <String, String>{},
       super(name, description);

  final String id;
  final Map<String, String> exits;

  @override
  bool addObject(GameObject obj) {
    final added = super.addObject(obj);
    if (added && obj is User) {
      obj.currentRoom = this;
    }
    return added;
  }

  bool addExit(String direction, String targetRoomId) {
    if (exits.containsKey(direction)) {
      throw StateError('The room already has an exit to the $direction');
    }
    exits[direction] = targetRoomId;
    return true;
  }

  List<User> getUsers() => inventory.whereType<User>().toList(growable: false);

  List<User> getOtherUsers(User currentUser) {
    return getUsers().where((user) => user != currentUser).toList(growable: false);
  }

  bool hasExit(String direction) => exits.containsKey(direction);

  String? getExit(String direction) => exits[direction];

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(name)
      ..writeln(longDescription);
    if (exits.isEmpty) {
      buffer.write('You see no exits.');
    } else {
      buffer.write('Exits: ${exits.keys.join(', ')}');
    }
    return buffer.toString();
  }
}
