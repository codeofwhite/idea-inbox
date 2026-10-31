import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'security/device_identity.dart';
import 'storage/idea_repository.dart';
import 'sync/client.dart';
import 'sync/pairing.dart';
import 'sync/protocol.dart';
import 'sync/server.dart';
import 'screens/inbox_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/settings_screen.dart';

class AppController extends ChangeNotifier {
  final DeviceIdentity identity;
  final PairingStore pairing;
  final IdeaRepository repository;
  final navigatorKey = GlobalKey<NavigatorState>();
  late final SyncClient client;
  late final SyncServer server;
  String status = '尚未同步';
  DateTime? lastSuccess;
  bool busy = false;
  AppController(this.identity, this.pairing, this.repository) {
    client = SyncClient(identity, pairing, repository);
    server = SyncServer(
      identity: identity,
      pairing: pairing,
      repository: repository,
      onStatus: (value) {
        status = value;
        if (value.startsWith('同步完成')) lastSuccess = DateTime.now();
        notifyListeners();
      },
      confirmPairing: (id) async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        return await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('允许这部手机配对？'),
                content: Text('手机标识：$id\n\n只批准你刚刚扫码的手机。配对将替换现有设备。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('拒绝'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('允许配对'),
                  ),
                ],
              ),
            ) ??
            false;
      },
    );
    repository.addListener(notifyListeners);
  }
  void setStatus(String value) {
    status = value;
    notifyListeners();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      status = '失败：${friendlyError(error)}';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> sync() => run(() async {
    status = '正在同步…';
    notifyListeners();
    final result = await client.sync();
    lastSuccess = DateTime.now();
    status = '同步完成：发送 ${result.sent} 个修订，接收 ${result.received} 个修订';
  });
  Future<void> pair(PairingOffer offer) => run(() async {
    status = '等待电脑确认配对…';
    notifyListeners();
    await client.pair(offer);
    status = '配对成功，请点击同步';
  });
  Future<void> revoke() => run(() async {
    server.cancelOffer();
    await pairing.revoke();
    status = '已撤销配对，本地记录保留';
  });
}

class IdeaInboxApp extends StatelessWidget {
  final AppController controller;
  const IdeaInboxApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: controller.navigatorKey,
    title: 'Idea Inbox',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff42685a)),
      scaffoldBackgroundColor: const Color(0xfff8faf7),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: _Shell(controller),
  );
}

class _Shell extends StatefulWidget {
  final AppController controller;
  const _Shell(this.controller);
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final pages = [
        InboxScreen(controller: controller),
        DevicesScreen(controller: controller),
        SettingsScreen(controller: controller),
      ];
      final wide = MediaQuery.sizeOf(context).width >= 800;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Idea Inbox'),
          actions: [
            if (!Platform.isWindows)
              TextButton.icon(
                onPressed: controller.busy ? null : controller.sync,
                icon: const Icon(Icons.sync),
                label: const Text('同步'),
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            if (controller.busy) const LinearProgressIndicator(),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.offline_bolt_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(controller.status)),
                    const SizedBox(width: 8),
                    Text(
                      '待同步 ${controller.repository.pending(controller.pairing.peer?.id)}',
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: selected,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (value) =>
                          setState(() => selected = value),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.lightbulb_outline),
                          label: Text('灵感'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.devices),
                          label: Text('设备'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          label: Text('设置'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: IndexedStack(index: selected, children: pages),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (value) =>
                    setState(() => selected = value),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.lightbulb_outline),
                    label: '灵感',
                  ),
                  NavigationDestination(icon: Icon(Icons.devices), label: '设备'),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: '设置',
                  ),
                ],
              ),
      );
    },
  );
}
