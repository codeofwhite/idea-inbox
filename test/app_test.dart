import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idea_inbox/app.dart';
import 'package:idea_inbox/security/device_identity.dart';
import 'package:idea_inbox/storage/database.dart';
import 'package:idea_inbox/storage/idea_repository.dart';
import 'package:idea_inbox/sync/pairing.dart';

import 'sync_test.dart' show MemorySecrets;

void main() {
  testWidgets('capture an idea without any network connection', (tester) async {
    final identity = DeviceIdentity(MemorySecrets());
    await identity.initialize();
    final db = AppDatabase(':memory:');
    final repository = IdeaRepository(db, identity.id);
    final controller = AppController(
      identity,
      PairingStore(identity.secrets),
      repository,
    );
    await tester.pumpWidget(IdeaInboxApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '公交车上记下的想法');
    await tester.tap(find.text('保存到本机'));
    await tester.pumpAndSettle();
    expect(repository.ideas.single.display.text, '公交车上记下的想法');
    expect(find.text('公交车上记下的想法'), findsOneWidget);
    expect(controller.server.running, false);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    repository.dispose();
    db.close();
  });

  testWidgets('phone layout remains usable with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final identity = DeviceIdentity(MemorySecrets());
    await identity.initialize();
    final db = AppDatabase(':memory:');
    final repository = IdeaRepository(db, identity.id);
    final controller = AppController(
      identity,
      PairingStore(identity.secrets),
      repository,
    );
    await tester.pumpWidget(IdeaInboxApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byType(TextField).first,
      'small screen capture',
    );
    await tester.ensureVisible(find.text('\u4fdd\u5b58\u5230\u672c\u673a'));
    await tester.tap(find.text('\u4fdd\u5b58\u5230\u672c\u673a'));
    await tester.pumpAndSettle();
    expect(repository.ideas.single.display.text, 'small screen capture');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    repository.dispose();
    db.close();
  });
}
