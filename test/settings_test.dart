import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamebox/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('AppSettings.orderBy 保留已排好的顺序，没排过的游戏放最后', () {
    expect(const AppSettings().orderBy(['jcc', 'bsy']), ['jcc', 'bsy']);
    expect(const AppSettings(gameOrder: ['bsy']).orderBy(['jcc', 'bsy']), ['bsy', 'jcc']);
    // 源里已经不存在的游戏不会从设置里带出来。
    expect(const AppSettings(gameOrder: ['xxx', 'bsy']).orderBy(['jcc', 'bsy']), [
      'bsy',
      'jcc',
    ]);
  });

  test('设置从 SharedPreferences 恢复：自动刷新默认开，排序按存进来的顺序', () async {
    SharedPreferences.setMockInitialValues({
      'settings.autoRefresh.bsy': false,
      'settings.gameOrder': <String>['bsy', 'jcc'],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final settings = container.read(settingsProvider);
    expect(settings.autoRefreshOf('jcc'), isTrue);
    expect(settings.autoRefreshOf('bsy'), isFalse);
    expect(settings.orderBy(['jcc', 'bsy']), ['bsy', 'jcc']);

    final notifier = container.read(settingsProvider.notifier);
    await notifier.setAutoRefresh('jcc', false);
    await notifier.setGameOrder(['jcc', 'bsy']);
    expect(prefs.getBool('settings.autoRefresh.jcc'), isFalse);
    expect(prefs.getStringList('settings.gameOrder'), ['jcc', 'bsy']);
    expect(container.read(settingsProvider).orderBy(['jcc', 'bsy']), ['jcc', 'bsy']);
  });
}
