import '../model/user_account.dart';
import '../persistence/user_store.dart';

enum LoginStage {
  chooseMode,
  existingUser,
  existingPassword,
  newUser,
  newPassword,
  confirmPassword,
  done,
}

class LoginResult {
  LoginResult({
    required this.message,
    this.account,
    this.isComplete = false,
    this.shouldDisconnect = false,
  });

  final String message;
  final UserAccount? account;
  final bool isComplete;
  final bool shouldDisconnect;
}

class LoginController {
  LoginController({required this.userStore});

  static const int userMinLength = 4;
  static const int maxTries = 3;

  final UserStore userStore;
  LoginStage stage = LoginStage.chooseMode;
  int _usernameTries = 0;
  int _passwordTries = 0;
  String? _newUsername;
  String? _newPassword;
  UserAccount? _existingAccount;

  String start() =>
      '\nWelcome to DartMud!\n\nDo you wish to [C]reate (Create) an account or [L]ogin?: ';

  Future<LoginResult> handleLine(String line) async {
    final input = line.trim();
    switch (stage) {
      case LoginStage.chooseMode:
        return _receivedCreateOrLogin(input);
      case LoginStage.existingUser:
        return _receivedExistingUsername(input);
      case LoginStage.existingPassword:
        return _receivedExistingPassword(input);
      case LoginStage.newUser:
        return _receivedNewUsername(input);
      case LoginStage.newPassword:
        return _receivedNewPassword(input);
      case LoginStage.confirmPassword:
        return _receivedNewPasswordConfirmation(input);
      case LoginStage.done:
        return LoginResult(message: '');
    }
  }

  LoginResult _receivedCreateOrLogin(String input) {
    if (input.isNotEmpty) {
      final choice = input[0].toLowerCase();
      if (choice == 'l') {
        stage = LoginStage.existingUser;
        return LoginResult(message: 'Please enter your username: ');
      }
      if (choice == 'c') {
        stage = LoginStage.newUser;
        return LoginResult(
          message: '\n\nPlease choose a username for your new character: ',
        );
      }
    }

    return LoginResult(message: 'Please choose C or L to create or login: ');
  }

  Future<LoginResult> _receivedExistingUsername(String input) async {
    final userData = await userStore.load(input);
    if (userData != null) {
      _existingAccount = userData;
      stage = LoginStage.existingPassword;
      return LoginResult(message: 'Please enter your password: ');
    }

    if (input.toLowerCase() == 'create') {
      stage = LoginStage.newUser;
      return LoginResult(
        message: 'You have choosen to create a new user.\n\nPlease choose a '
            'new username: ',
      );
    }

    _usernameTries += 1;
    if (_usernameTries >= maxTries) {
      return LoginResult(
        message: '\nToo many failed attempts. Now disconnecting!\n',
        shouldDisconnect: true,
      );
    }

    return LoginResult(
      message: '\n$input is not a valid username.\nPlease enter your username '
          "or choose 'create': ",
    );
  }

  Future<LoginResult> _receivedExistingPassword(String input) async {
    if (input == _existingAccount!.password) {
      stage = LoginStage.done;
      return LoginResult(
        message: '',
        account: _existingAccount,
        isComplete: true,
      );
    }

    _passwordTries += 1;
    if (_passwordTries >= maxTries) {
      return LoginResult(
        message: '\nToo many failed attempts. Now disconnecting!\n',
        shouldDisconnect: true,
      );
    }

    return LoginResult(message: '\nInvalid password. Try again: ');
  }

  Future<LoginResult> _receivedNewUsername(String input) async {
    if (input.length < userMinLength) {
      return LoginResult(
        message: 'That username is too short.\nPlease choose a username at '
            'least $userMinLength characters long: ',
      );
    }
    if (input.contains(' ')) {
      return LoginResult(
        message: 'Username may not contain spaces.\nPlease use a username '
            'which only contains letters: ',
      );
    }
    final existing = await userStore.load(input);
    if (existing != null) {
      return LoginResult(
        message: 'That username already exists.\nPlease choose a different '
            'username: ',
      );
    }

    _newUsername = input;
    stage = LoginStage.newPassword;
    return LoginResult(
      message: 'Please choose a password of at least $userMinLength '
          'characters: ',
    );
  }

  Future<LoginResult> _receivedNewPassword(String input) async {
    if (input.length < userMinLength) {
      return LoginResult(
        message: 'Your password must be at least $userMinLength characters '
            'long.\nPlease choose a password: ',
      );
    }
    _newPassword = input;
    stage = LoginStage.confirmPassword;
    return LoginResult(message: 'Please confirm your password: ');
  }

  Future<LoginResult> _receivedNewPasswordConfirmation(String input) async {
    if (input != _newPassword) {
      _passwordTries += 1;
      if (_passwordTries >= maxTries) {
        return LoginResult(
          message: '\nToo many failed attempts. Now disconnecting!\n',
          shouldDisconnect: true,
        );
      }
      stage = LoginStage.newPassword;
      return LoginResult(
        message: 'Your passwords do not match. Please choose a password: ',
      );
    }

    final account = UserAccount(
      username: _newUsername!,
      password: _newPassword!,
      prompt: '> ',
      longDescription: '',
    );
    await userStore.save(account);
    stage = LoginStage.done;
    return LoginResult(
      message: '',
      account: account,
      isComplete: true,
    );
  }
}
