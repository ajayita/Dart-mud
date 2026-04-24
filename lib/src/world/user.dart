import 'editor/editor_session.dart';
import 'model/container.dart';
import 'model/user_account.dart';
import 'rooms/room.dart';
import '../server/client_connection.dart';

typedef EditCallback = void Function(String text);

class User extends ContainerImpl {
  User({
    required this.connection,
    required this.account,
  }) : super(account.username, account.longDescription);

  final ClientConnection connection;
  final UserAccount account;
  Room? currentRoom;
  EditorSession? _editor;
  EditCallback? _editCallback;

  String get prompt => account.prompt;

  set prompt(String value) {
    if (value.isNotEmpty) {
      account.prompt = value;
    }
  }

  @override
  set long(String value) {
    super.long = value;
    account.longDescription = longDescription;
  }

  void display(String text) {
    connection.writeln('');
    connection.writeln(text);
    showPrompt();
  }

  void write(String text) => connection.write(text);

  void writeln(String text) => connection.writeln(text);

  void showPrompt() => connection.write(prompt);

  void startEdit(EditCallback callback) {
    _editor = EditorSession();
    _editCallback = callback;
    connection.write(_editor!.start());
  }

  bool get isEditing => _editor != null;

  void handleEditorInput(String line) {
    final editor = _editor!;
    final result = editor.handleInput(line);
    if (result.output.isNotEmpty) {
      connection.write(result.output);
    }
    if (result.isDone) {
      _editor = null;
      _editCallback?.call(result.finishedText ?? '');
    }
  }
}
