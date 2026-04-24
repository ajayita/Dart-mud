import '../server/client_connection.dart';
import 'login/login_controller.dart';
import 'persistence/user_store.dart';
import 'rooms/matt_rooms.dart';
import 'rooms/room_registry.dart';
import 'user.dart';

class MudRuntime {
  MudRuntime({String userBasePath = 'users'})
      : userStore = UserStore(basePath: userBasePath),
        rooms = RoomRegistry() {
    registerMattRooms(rooms);
  }

  final UserStore userStore;
  final RoomRegistry rooms;
  final List<_Session> _sessions = <_Session>[];
  final List<User> users = <User>[];
  bool _shuttingDown = false;

  void accept(ClientConnection connection) {
    final session = _Session(
      runtime: this,
      connection: connection,
      login: LoginController(userStore: userStore),
    );
    _sessions.add(session);
    connection.write(session.login.start());
    var pending = Future<void>.value();
    connection.lines.listen(
      (line) {
        pending = pending.then((_) => session.handleLine(line));
      },
      onDone: () async {
        await pending;
        await _endSession(session);
      },
      onError: (_) async {
        await pending;
        await _endSession(session);
      },
    );
  }

  Future<void> shutdown() async {
    if (_shuttingDown) {
      return;
    }
    _shuttingDown = true;
    for (final user in List<User>.from(users)) {
      user.writeln('The server is shutting down. Now disconnecting you.');
      await disconnect(user);
    }
    for (final session in List<_Session>.from(_sessions)) {
      await _closeSession(session);
    }
  }

  Future<void> disconnect(User user) async {
    await userStore.save(user.account);
    user.currentRoom?.removeObject(user);
    users.remove(user);
    for (final session in List<_Session>.from(_sessions)) {
      if (session.user == user) {
        await _closeSession(session);
        break;
      }
    }
  }

  Future<void> _endSession(_Session session) async {
    if (session.user != null) {
      await userStore.save(session.user!.account);
      session.user!.currentRoom?.removeObject(session.user!);
      users.remove(session.user);
    }
    _sessions.remove(session);
  }

  Future<void> _closeSession(_Session session) async {
    _sessions.remove(session);
    await session.connection.close();
  }

  void addUser(User user) {
    users.add(user);
    rooms.moveUser(user, '${user.name}Home') || rooms.moveUser(user, 'void');
    _look(user, null);
  }

  Future<void> processCommand(User user, String line) async {
    if (line.trim().isEmpty) {
      user.display('Huh?');
      return;
    }

    final spaceIndex = line.indexOf(' ');
    var command = line;
    String? args;
    if (spaceIndex != -1) {
      args = line.substring(spaceIndex + 1).trim();
      command = line.substring(0, spaceIndex);
    }
    command = command.toLowerCase();

    switch (command) {
      case 'exit':
        for (final other in user.currentRoom?.getOtherUsers(user) ?? const <User>[]) {
          other.display('${user.name} fades from existance.');
        }
        await disconnect(user);
        return;
      case 'shutdown':
        await shutdown();
        return;
      case 'broadcast':
        _broadcast(user, args ?? '');
        return;
      case 'help':
        _help(user, args);
        return;
      case 'look':
        _look(user, args);
        return;
      case 'home':
        if (!rooms.moveUser(user, '${user.name}Home')) {
          user.display('Unable to move home. An error occured');
          for (final other in user.currentRoom?.getOtherUsers(user) ?? const <User>[]) {
            other.display('${user.name} twitches');
          }
        } else {
          _look(user, null);
        }
        return;
      case 'who':
        _who(user);
        return;
      case 'say':
        _say(user, args ?? '');
        return;
      case 'emote':
        _emote(user, args ?? '');
        return;
      case 'prompt':
        user.prompt = '${args ?? ''} ';
        user.display('Done');
        return;
      case 'ed':
        user.startEdit((text) {
          user.long = text;
          user.display('You wrote:\n$text');
        });
        return;
      default:
        if (user.currentRoom?.hasExit(command) ?? false) {
          final moved = rooms.moveUser(user, user.currentRoom!.getExit(command)!);
          if (moved) {
            _look(user, null);
          } else {
            rooms.moveUser(user, 'void');
            user.display('An error occurred. Transporting you to the void instead.');
          }
        } else {
          user.writeln("I don't know how to '$command' yet");
          user.showPrompt();
        }
        return;
    }
  }

  void _broadcast(User user, String args) {
    for (final current in users) {
      final who = identical(current, user) ? 'You broadcast:' : 'Broadcast (${user.name}):';
      current.display('$who $args');
    }
  }

  void _help(User user, String? args) {
    if (args == null || args.isEmpty) {
      user.display(
        'Available commands:\n'
        'broadcast\n'
        'ed\n'
        'emote\n'
        'exit\n'
        'help\n'
        'home\n'
        'look\n'
        'prompt\n'
        'say\n'
        'shutdown\n'
        'who\n\n'
        'Use help <command> to get more information on a command.',
      );
      return;
    }
    user.display('Usage: $args');
  }

  void _look(User user, String? args) {
    if (args != null && args.isNotEmpty) {
      return;
    }
    final room = user.currentRoom;
    if (room == null) {
      user.display('You are nowhere.');
      return;
    }
    final buffer = StringBuffer(room.description);
    final items = room.inventory.where((item) => item != user).toList(growable: false);
    if (items.isNotEmpty) {
      buffer.write('\nYou see here: ${items.map((item) => item.short).join(', ')}');
    }
    user.display(buffer.toString());
  }

  void _who(User user) {
    user.display(
      'Currently logged in users:\n${users.map((current) => current.name).join('\n')}',
    );
  }

  void _say(User user, String args) {
    user.display('You say: $args');
    for (final other in user.currentRoom?.getOtherUsers(user) ?? const <User>[]) {
      other.display('${user.name} says: $args');
    }
  }

  void _emote(User user, String args) {
    if (args.isEmpty) {
      user.display('emote what?');
      return;
    }
    final action = '${user.name} $args';
    user.display('You emote: $action');
    for (final other in user.currentRoom?.getOtherUsers(user) ?? const <User>[]) {
      other.display(action);
    }
  }
}

class _Session {
  _Session({
    required this.runtime,
    required this.connection,
    required this.login,
  });

  final MudRuntime runtime;
  final ClientConnection connection;
  final LoginController login;
  User? user;

  Future<void> handleLine(String line) async {
    if (user == null) {
      final result = await login.handleLine(line);
      if (result.message.isNotEmpty) {
        connection.write(result.message);
      }
      if (result.shouldDisconnect) {
        await connection.close();
        return;
      }
      final account = result.account;
      if (result.isComplete && account != null) {
        user = User(connection: connection, account: account);
        runtime.addUser(user!);
      }
      return;
    }

    if (user!.isEditing) {
      user!.handleEditorInput(line);
      return;
    }

    await runtime.processCommand(user!, line.trim());
  }
}
