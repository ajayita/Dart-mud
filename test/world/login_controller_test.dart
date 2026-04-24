import 'dart:io';

import 'package:dartmud/src/world/login/login_controller.dart';
import 'package:dartmud/src/world/model/user_account.dart';
import 'package:dartmud/src/world/persistence/user_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late UserStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dartmud-login-test-');
    store = UserStore(basePath: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('create-account flow persists a compatible user file', () async {
    final controller = LoginController(userStore: store);

    expect(controller.start(), contains('Create'));

    var result = await controller.handleLine('c');
    expect(result.message, contains('username'));
    expect(result.isComplete, isFalse);

    result = await controller.handleLine('andy');
    expect(result.message, contains('password'));

    result = await controller.handleLine('swordfish');
    expect(result.message, contains('confirm'));

    result = await controller.handleLine('swordfish');
    expect(result.isComplete, isTrue);
    expect(result.account?.username, 'andy');

    final saved = File('${tempDir.path}/andy.usr');
    expect(await saved.exists(), isTrue);
    expect(await saved.readAsString(), contains('"username":"andy"'));
    expect(await saved.readAsString(), endsWith('\n'));
  });

  test('existing-user login loads saved data and verifies password', () async {
    await store.save(
      UserAccount(
        username: 'matt',
        password: 'secret',
        prompt: 'hp> ',
        longDescription: 'A builder.',
      ),
    );

    final controller = LoginController(userStore: store);
    await controller.handleLine('l');
    await controller.handleLine('matt');
    final result = await controller.handleLine('secret');

    expect(result.isComplete, isTrue);
    expect(result.account?.prompt, 'hp> ');
    expect(result.account?.longDescription, 'A builder.');
  });

  test('invalid username attempts disconnect after three failures', () async {
    final controller = LoginController(userStore: store);
    await controller.handleLine('l');

    await controller.handleLine('missing');
    await controller.handleLine('missing');
    final result = await controller.handleLine('missing');

    expect(result.shouldDisconnect, isTrue);
    expect(result.message, contains('Too many failed attempts'));
  });

  test('password confirmation retries then disconnects after three failures', () async {
    final controller = LoginController(userStore: store);
    await controller.handleLine('c');
    await controller.handleLine('newuser');
    await controller.handleLine('secret');

    await controller.handleLine('wrong1');
    await controller.handleLine('secret');
    await controller.handleLine('wrong2');
    await controller.handleLine('secret');
    final result = await controller.handleLine('wrong3');

    expect(result.shouldDisconnect, isTrue);
    expect(result.message, contains('Too many failed attempts'));
  });
}
