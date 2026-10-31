import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'security/device_identity.dart';
import 'storage/database.dart';
import 'storage/idea_repository.dart';
import 'sync/pairing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final identity = DeviceIdentity(PlatformSecretStore());
    await identity.initialize();
    final pairing = PairingStore(identity.secrets);
    await pairing.load();
    final directory = await getApplicationSupportDirectory();
    await Directory(directory.path).create(recursive: true);
    final repository = IdeaRepository(
      AppDatabase(p.join(directory.path, 'ideas.sqlite3')),
      identity.id,
    );
    runApp(
      IdeaInboxApp(controller: AppController(identity, pairing, repository)),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                '无法打开本地数据，应用没有重置或覆盖数据。\n请保留数据目录并排查后重新打开。\n\n$error',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
