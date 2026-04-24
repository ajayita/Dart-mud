enum EditorMode { command, input }

class EditorRange {
  EditorRange._(this.first, this.last);

  factory EditorRange.parse(String value) {
    final parts = value.trim().split(',');
    if (parts.length == 1) {
      final number = int.parse(parts.first.trim());
      return EditorRange._(number, number);
    }

    if (parts.length != 2) {
      throw const FormatException('Invalid range');
    }

    final lower = int.parse(parts.first.trim());
    final upperPart = parts.last.trim();
    final upper = upperPart == r'$' ? 9999 : int.parse(upperPart);
    if (lower > upper) {
      throw const FormatException('Invalid range');
    }
    return EditorRange._(lower, upper);
  }

  final int first;
  final int last;

  int get length => last - first + 1;

  bool includes(int value) => value >= first && value <= last;
}

class EditorResult {
  EditorResult({
    required this.output,
    this.finishedText,
    this.isDone = false,
  });

  final String output;
  final String? finishedText;
  final bool isDone;
}

class EditorSession {
  final List<String> _buffer = <String>[];
  final List<String> _pendingInput = <String>[];
  EditorMode _mode = EditorMode.command;
  int _currentLine = 1;

  String start() => ': ';

  EditorResult handleInput(String input) {
    if (_mode == EditorMode.input) {
      return _handleInputMode(input);
    }
    return _handleCommandMode(input);
  }

  EditorResult _handleInputMode(String input) {
    if (input == '.') {
      _buffer.insertAll(_currentLine, _pendingInput);
      _currentLine += _pendingInput.length;
      _pendingInput.clear();
      _mode = EditorMode.command;
      return EditorResult(output: ': ');
    }

    _pendingInput.add('$input\n');
    return EditorResult(output: '~ ');
  }

  EditorResult _handleCommandMode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return EditorResult(output: ': ');
    }

    final match = RegExp(r'^(?:(.+?)\s+)?([a-z])$').firstMatch(trimmed);
    String? args;
    late String command;
    if (match != null) {
      args = match.group(1)?.trim();
      command = match.group(2)!;
    } else {
      final parts = trimmed.split(RegExp(r'\s+'));
      command = parts.first;
      args = parts.length > 1 ? trimmed.substring(command.length).trim() : null;
    }

    switch (command) {
      case 'h':
        return EditorResult(output: '${_helpText()}\n: ');
      case 'q':
        final text = _buffer.join();
        return EditorResult(output: '', finishedText: text, isDone: true);
      case 'i':
        _mode = EditorMode.input;
        _currentLine = (_currentLine - 1).clamp(0, _buffer.length);
        return EditorResult(output: '~ ');
      case 'a':
        _mode = EditorMode.input;
        _currentLine = _buffer.isEmpty ? 0 : _currentLine.clamp(0, _buffer.length);
        return EditorResult(output: '~ ');
      case 'p':
        return EditorResult(output: '${_printLines(args)}: ');
      case 'd':
        _deleteLines(args);
        return EditorResult(output: ': ');
      case 'c':
        _changeLines(args);
        return EditorResult(output: '~ ');
      default:
        return EditorResult(output: ': ');
    }
  }

  String _printLines(String? args) {
    if (_buffer.isEmpty) {
      return ': ';
    }
    final range = _resolveRange(args);
    final start = range.first - 1;
    final end = range.last > _buffer.length ? _buffer.length : range.last;
    _currentLine = end;
    final lines = <String>[];
    for (var index = start; index < end; index++) {
      lines.add('${index + 1} : ${_buffer[index]}');
    }
    return lines.join();
  }

  void _deleteLines(String? args) {
    if (_buffer.isEmpty) {
      return;
    }
    final range = _resolveRange(args);
    final start = range.first - 1;
    final end = range.last > _buffer.length ? _buffer.length : range.last;
    _buffer.removeRange(start, end);
    _currentLine = range.first > _buffer.length ? _buffer.length : range.first;
    if (_currentLine <= 0) {
      _currentLine = 1;
    }
  }

  void _changeLines(String? args) {
    if (_buffer.isEmpty) {
      _currentLine = 0;
      _mode = EditorMode.input;
      return;
    }
    final range = _resolveRange(args);
    final start = range.first - 1;
    final end = range.last > _buffer.length ? _buffer.length : range.last;
    _buffer.removeRange(start, end);
    _currentLine = start.clamp(0, _buffer.length);
    _mode = EditorMode.input;
  }

  EditorRange _resolveRange(String? args) {
    if (args == null || args.isEmpty) {
      return EditorRange._(_currentLine, _currentLine);
    }
    return EditorRange.parse(args);
  }

  String _helpText() {
    return 'Editor Help:\n'
        'h <cmd>     Display help.\n'
        'i           Insert before current line.\n'
        'a           Append after current line.\n'
        'c <range>   Change a line range.\n'
        'p <range>   Print a line range.\n'
        'd <range>   Delete a line range.\n'
        'q           Quit editor.';
  }
}
