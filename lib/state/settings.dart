import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// main() 里先取到实例再 override，这样设置项在首帧就是同步可读的，
/// 不会出现「先进默认游戏、下一秒跳到排序第一个」的闪动。
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('main() 必须 override prefsProvider'),
);

/// 自动刷新默认开：等于沿用「进页面发现没数据就按需抓一次」的现有行为。
const autoRefreshDefault = true;

class AppSettings {
  /// 用户在设置页排好的游戏 id 顺序；没排过就是空，由 [orderBy] 回退到传入顺序。
  final List<String> gameOrder;
  final Map<String, bool> autoRefresh;

  const AppSettings({this.gameOrder = const [], this.autoRefresh = const {}});

  AppSettings copyWith({List<String>? gameOrder, Map<String, bool>? autoRefresh}) =>
      AppSettings(
        gameOrder: gameOrder ?? this.gameOrder,
        autoRefresh: autoRefresh ?? this.autoRefresh,
      );

  /// UI 侧判断要不要按需自动抓：`ref.watch(settingsProvider).autoRefreshOf(id)`。
  bool autoRefreshOf(String gameId) => autoRefresh[gameId] ?? autoRefreshDefault;

  /// 已知的游戏 id 按设置里的顺序排；设置里没有的（新加的游戏）排在后面。
  List<String> orderBy(Iterable<String> ids) {
    final known = ids.toList();
    return [
      for (final id in gameOrder)
        if (known.contains(id)) id,
      for (final id in known)
        if (!gameOrder.contains(id)) id,
    ];
  }
}

String _orderKey = 'settings.gameOrder';
String _autoKey(String gameId) => 'settings.autoRefresh.$gameId';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(prefsProvider);
    return AppSettings(
      gameOrder: prefs.getStringList(_orderKey) ?? const [],
      autoRefresh: {
        for (final id in prefs.getKeys())
          if (id.startsWith('settings.autoRefresh.'))
            id.substring('settings.autoRefresh.'.length): prefs.getBool(id)!,
      },
    );
  }

  Future<void> setGameOrder(List<String> ids) async {
    state = state.copyWith(gameOrder: ids);
    await ref.read(prefsProvider).setStringList(_orderKey, ids);
  }

  Future<void> setAutoRefresh(String gameId, bool value) async {
    state = state.copyWith(autoRefresh: {...state.autoRefresh, gameId: value});
    await ref.read(prefsProvider).setBool(_autoKey(gameId), value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
