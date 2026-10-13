import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'state/app_update.dart';
import 'state/providers.dart';
import 'state/settings.dart';
import 'ui/app_update.dart';
import 'ui/detail_screen.dart';
import 'ui/games/bsy_screen.dart';
import 'ui/games/jcc_screen.dart';
import 'ui/home_screen.dart';
import 'ui/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const GameBoxApp(),
    ),
  );
}

final _rootNav = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNav,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'detail/:uid',
          builder: (_, st) =>
              DetailScreen(uid: Uri.decodeComponent(st.pathParameters['uid'] ?? '')),
        ),
        GoRoute(
          path: 'jcc/column',
          builder: (_, st) => JccColumnScreen(type: st.uri.queryParameters['type'] ?? ''),
        ),
        GoRoute(
          path: 'bsy/column',
          builder: (_, st) => BsyColumnScreen(type: st.uri.queryParameters['type'] ?? ''),
        ),
        GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),
  ],
);

class GameBoxApp extends ConsumerStatefulWidget {
  const GameBoxApp({super.key});

  @override
  ConsumerState<GameBoxApp> createState() => _GameBoxAppState();
}

class _GameBoxAppState extends ConsumerState<GameBoxApp> {
  @override
  void initState() {
    super.initState();
    // 首帧之后才有 Navigator 可以挂对话框。
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnLaunch());
  }

  /// 启动静默检查：只在真有新版时弹一次，失败不打扰用户。
  Future<void> _checkOnLaunch() async {
    final newer = await ref.read(appUpdateProvider.notifier).check(silent: true);
    if (!newer || !mounted) return;
    final nav = _rootNav.currentState;
    if (nav == null) return;
    final force = ref.read(appUpdateProvider).remote?.force ?? false;
    await showAppUpdateDialog(nav, force: force);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(filterProvider.select((f) => f.game));
    return MaterialApp.router(
      title: '游戏盒子',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(game),
      routerConfig: _router,
    );
  }
}
