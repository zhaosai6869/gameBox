import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bsy_scraper.dart';
import '../data/db.dart';
import '../data/jcc_scraper.dart';
import '../data/scraper.dart';
import 'settings.dart';

final dbProvider = Provider<AppDatabase>((_) => AppDatabase());

final httpProvider = Provider<Http>((_) => Http());

final scrapersProvider = Provider<Map<String, GameScraper>>(
  (ref) => {
    'jcc': JccScraper(ref.read(httpProvider)),
    'bsy': BsyScraper(ref.read(httpProvider)),
  },
);

class UiFilter {
  final String game;
  final String? type;
  final String query;
  const UiFilter({this.game = 'jcc', this.type, this.query = ''});

  UiFilter copyWith({String? game, String? type, String? query}) =>
      UiFilter(game: game ?? this.game, type: type, query: query ?? this.query);
}

class FilterNotifier extends Notifier<UiFilter> {
  @override
  UiFilter build() {
    final order = ref.read(settingsProvider).orderBy(ref.read(scrapersProvider).keys);
    return UiFilter(game: order.isEmpty ? 'jcc' : order.first);
  }

  void setGame(String game) => state = UiFilter(game: game);
  void setType(String? type) => state = state.copyWith(type: type);
  void setQuery(String query) => state = state.copyWith(query: query);
}

final filterProvider = NotifierProvider<FilterNotifier, UiFilter>(FilterNotifier.new);

final entitiesProvider = StreamProvider.autoDispose<List<Entity>>((ref) {
  final f = ref.watch(filterProvider);
  return ref.watch(dbProvider).watch(gameId: f.game, type: f.type, query: f.query);
});

/// 当前选中的金铲铲模式：主页和「其他」栏目页共用，模式行只在需要它的页面上显示。
class JccModeNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setMode(String id) => state = id;
}

final jccModeProvider = NotifierProvider<JccModeNotifier, String>(JccModeNotifier.new);

final gameModesProvider = FutureProvider.family<List<GameMode>, String>(
  (ref, gameId) => ref.watch(scrapersProvider)[gameId]!.loadModes(),
);

typedef EntityQuery = ({String game, String mode, String? type, String query});

final entitiesQueryProvider = StreamProvider.autoDispose
    .family<List<Entity>, EntityQuery>(
      (ref, q) => ref
          .watch(dbProvider)
          .watch(gameId: q.game, mode: q.mode, type: q.type, query: q.query),
    );

final entityProvider = StreamProvider.autoDispose.family<Entity?, String>(
  (ref, uid) => ref.watch(dbProvider).watchUid(uid),
);

/// 特殊机制的类别（官方 mechanism_tab：奇遇 / 小精灵）。
final mechCategoriesProvider = FutureProvider.autoDispose<List<MechCategory>>(
  (ref) => ref.watch(scrapersProvider)['jcc']!.loadMechCategories(),
);

/// 特殊机制不走模式：refreshMech 期间用这个哨兵值标记进度。
const mechCrawlMode = 'mech';

class CrawlState {
  final bool running;
  final String mode;
  final String? error;
  final int lastCount;
  final DateTime? lastAt;
  const CrawlState({
    this.running = false,
    this.mode = '',
    this.error,
    this.lastCount = 0,
    this.lastAt,
  });
}

class CrawlNotifier extends Notifier<CrawlState> {
  @override
  CrawlState build() => const CrawlState();

  /// 抽屉里的「更新」在跑时不叠加全量刷新，两边会互相覆盖同一批行。
  bool get _busy => state.running || ref.read(updateProvider).running;

  Future<void> refresh(String gameId, {String mode = ''}) async {
    if (_busy) return;
    state = CrawlState(running: true, mode: mode);
    try {
      final scraper = ref.read(scrapersProvider)[gameId];
      if (scraper == null) throw Exception('未知游戏 $gameId');
      final map = await scraper.crawlAll(mode: mode);
      final db = ref.read(dbProvider);
      final now = DateTime.now().toIso8601String();
      var total = 0;
      for (final e in map.entries) {
        final rows = e.value.map((s) => rowToEntity(s, now)).toList();
        await db.replaceForType(
          gameId,
          rows.isEmpty ? mode : rows.first.mode,
          e.key,
          rows,
        );
        total += rows.length;
      }
      state = CrawlState(mode: mode, lastCount: total, lastAt: DateTime.now());
    } catch (e) {
      state = CrawlState(
        mode: mode,
        error: '$e',
        lastCount: state.lastCount,
        lastAt: state.lastAt,
      );
    }
  }

  /// 「其他」里某个栏目单独抓一次：栏目页首次打开时触发，不并进全量刷新。
  Future<void> refreshColumn(String gameId, String type) async {
    if (_busy) return;
    state = CrawlState(running: true, mode: type);
    try {
      final scraper = ref.read(scrapersProvider)[gameId];
      if (scraper == null) throw Exception('未知游戏 $gameId');
      final rows = await scraper.crawlColumn(type);
      if (rows == null) {
        state = const CrawlState();
        return;
      }
      // 一条都没解析出来时不动库里已有的数据，免得源站改版把栏目清空。
      if (rows.isEmpty) throw Exception('没有解析到内容，已保留原有数据');
      final now = DateTime.now().toIso8601String();
      await ref
          .read(dbProvider)
          .replaceForType(
            gameId,
            '',
            type,
            rows.map((s) => rowToEntity(s, now)).toList(),
          );
      state = CrawlState(mode: type, lastCount: rows.length, lastAt: DateTime.now());
    } catch (e) {
      state = CrawlState(
        mode: type,
        error: '$e',
        lastCount: state.lastCount,
        lastAt: state.lastAt,
      );
    }
  }

  /// 特殊机制：一次抓齐所有类别（奇遇 / 小精灵），按类别各自归属的模式分别落库。
  Future<void> refreshMech() async {
    if (_busy) return;
    state = const CrawlState(running: true, mode: mechCrawlMode);
    try {
      final scraper = ref.read(scrapersProvider)['jcc'];
      if (scraper == null) throw Exception('未知游戏 jcc');
      final list = await scraper.crawlMech();
      final db = ref.read(dbProvider);
      final now = DateTime.now().toIso8601String();
      final byMode = <String, List<Entity>>{};
      for (final s in list) {
        (byMode[s.mode] ??= <Entity>[]).add(rowToEntity(s, now));
      }
      for (final e in byMode.entries) {
        await db.replaceForType('jcc', e.key, 'mech', e.value);
      }
      state = CrawlState(
        mode: mechCrawlMode,
        lastCount: list.length,
        lastAt: DateTime.now(),
      );
    } catch (e) {
      state = CrawlState(
        mode: mechCrawlMode,
        error: '$e',
        lastCount: state.lastCount,
        lastAt: state.lastAt,
      );
    }
  }
}

Entity rowToEntity(ScrapedEntity s, String crawledAt) => Entity(
  uid: s.uid,
  gameId: s.gameId,
  mode: s.mode,
  type: s.type,
  title: s.title,
  subtitle: s.subtitle,
  thumb: s.thumb,
  payload: jsonEncode(s.blocks),
  sourceUrl: s.sourceUrl,
  sortOrder: s.sortOrder,
  crawledAt: crawledAt,
);

final crawlProvider = NotifierProvider<CrawlNotifier, CrawlState>(CrawlNotifier.new);

/// 「更新」跑完一步的结果。
class StepResult {
  final String label;
  final int count;

  /// 非空即失败（网络挂了 / 解析炸了）。
  final String? error;
  const StepResult(this.label, {this.count = 0, this.error});

  bool get ok => error == null;

  /// 抓到了但一条都没有：不算失败，也**不会**删掉库里已有的数据。
  bool get empty => ok && count == 0;

  String get detail => error ?? (empty ? '未抓到内容，已保留原有数据' : '$count 条');
}

class UpdateState {
  final String gameId;
  final int done;
  final int total;
  final String current;
  const UpdateState({this.gameId = '', this.done = 0, this.total = 0, this.current = ''});

  bool get running => gameId.isNotEmpty;
}

/// 抽屉里「更新」按钮的分步执行器：一步 = 一个模式或一个栏目，
/// 单步失败只记在自己名下，已抓到的数据照常落库。
class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  /// 每一步的结果。点按钮一定有回执：抢不到抓取锁时也返回一条失败，
  /// 而不是静默什么都不发生。
  Future<List<StepResult>> run(String gameId) async {
    if (state.running || ref.read(crawlProvider).running) {
      return [const StepResult('更新', error: '已有抓取任务在跑，请稍后再点')];
    }
    final scraper = ref.read(scrapersProvider)[gameId];
    if (scraper == null) {
      return [StepResult(gameId, error: '未知游戏 $gameId')];
    }
    final List<CrawlStep> steps;
    try {
      steps = await scraper.updateSteps();
    } catch (e) {
      return [StepResult('更新清单', error: crawlReason(e))];
    }
    final results = <StepResult>[];
    for (final (i, s) in steps.indexed) {
      state = UpdateState(gameId: gameId, done: i, total: steps.length, current: s.label);
      // 让出一次事件循环，进度条才有机会画出来（解析在主 isolate 上会卡住）。
      await Future.delayed(Duration.zero);
      try {
        final count = await _writeStep(gameId, await s.run());
        results.add(StepResult(s.label, count: count));
      } catch (e) {
        results.add(StepResult(s.label, error: crawlReason(e)));
      }
    }
    state = UpdateState(done: steps.length, total: steps.length);
    return results;
  }

  /// 按条目自带的 (mode, type) 分组替换。0 条的类不会出现在 map 里（两个 scraper
  /// 都 removeWhere 过），所以旧数据天然不会被清空。
  Future<int> _writeStep(String gameId, Map<String, List<ScrapedEntity>> map) async {
    final db = ref.read(dbProvider);
    final now = DateTime.now().toIso8601String();
    final grouped = <({String mode, String type}), List<Entity>>{};
    for (final e in map.entries) {
      for (final s in e.value) {
        (grouped[(mode: s.mode, type: e.key)] ??= <Entity>[]).add(rowToEntity(s, now));
      }
    }
    var total = 0;
    for (final g in grouped.entries) {
      await db.replaceForType(gameId, g.key.mode, g.key.type, g.value);
      total += g.value.length;
    }
    return total;
  }
}

/// 失败原因要给用户看，Dio 的异常串又长又带堆栈味。太长时掐中间：源地址开头和
/// 真正的报错尾巴都留着——只留前 160 字会把 'Failed host lookup' 截没。
String crawlReason(Object e) {
  final s = '$e';
  final m = RegExp(r'Exception: (.*?)(?:\n|$)').firstMatch(s);
  final text = (m?.group(1) ?? s).trim();
  if (text.length <= 170) return text;
  return '${text.substring(0, 100)}…${text.substring(text.length - 60)}';
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);
