import 'dart:convert';
import 'dart:io';

import '../model/user_account.dart';

class UserStore {
  UserStore({this.basePath = 'users'});

  final String basePath;

  Future<UserAccount?> load(String username) async {
    final file = File('$basePath/$username.usr');
    if (!await file.exists()) {
      return null;
    }

    final jsonMap = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return UserAccount.fromJson(jsonMap);
  }

  Future<void> save(UserAccount account) async {
    final directory = Directory(basePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File('$basePath/${account.username}.usr');
    await file.writeAsString('${jsonEncode(account.toJson())}\n');
  }
}
