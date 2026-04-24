typedef CommandHandler = Future<void> Function(CommandContext context, String args);

class CommandContext {}

class CommandRegistry {
  final Map<String, CommandHandler> _handlers = <String, CommandHandler>{};

  void register(String name, CommandHandler handler) {
    if (_handlers.containsKey(name)) {
      throw StateError('Duplicate command: $name');
    }
    _handlers[name] = handler;
  }

  CommandHandler? lookup(String name) => _handlers[name];
}
