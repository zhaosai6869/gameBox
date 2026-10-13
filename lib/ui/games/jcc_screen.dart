import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/db.dart';
import '../../data/jcc_scraper.dart';
import '../../data/scraper.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../blocks_view.dart';
import '../game_popup.dart';

/// 金铲铲之战专属页面：底部菜单「阵容 / 羁绊 / 英雄 / 装备 / 其他」。
class JccScreen extends ConsumerStatefulWidget {
  const JccScreen({super.key});

  @override
  ConsumerState<JccScreen> createState() => _JccScreenState();
}

class _JccScreenState extends ConsumerState<JccScreen> {
  static const _labels = ['阵容', '羁绊', '英雄', '装备', '其他'];
  static const _icons = [
    Icons.auto_awesome_mosaic_outlined,
    Icons.hub_outlined,
    Icons.person_outline,
    Icons.shield_outlined,
    Icons.category_outlined,
  ];

  int _index = 0;
  String _autoCrawlFor = '';

  String get _mode => ref.read(jccModeProvider);

  Future<void> _refresh() => ref.read(crawlProvider.notifier).refresh('jcc', mode: _mode);

  void _pickMode(String id) {
    if (_mode == id) return;
    ref.read(jccModeProvider.notifier).setMode(id);
  }

  @override
  Widget build(BuildContext context) {
    final modeList = ref.watch(gameModesProvider('jcc')).value ?? const <GameMode>[];
    final mode = ref.watch(jccModeProvider);
    final crawl = ref.watch(crawlProvider);
    final busy = crawl.running && crawl.mode == mode;
    final all = ref.watch(
      entitiesQueryProvider((game: 'jcc', mode: mode, type: null, query: '')),
    );

    if (mode.isEmpty && modeList.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickMode(modeList.first.id));
    }
    if (mode.isNotEmpty &&
        ref.watch(settingsProvider).autoRefreshOf('jcc') &&
        _autoCrawlFor != mode &&
        !crawl.running &&
        (all.value?.isEmpty ?? false)) {
      _autoCrawlFor = mode;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }

    // 「其他」分区本身不放模式行：模式属于各栏目内部的数据维度。
    final showModes = modeList.length > 1 && _Kind.values[_index] != _Kind.other;

    return Scaffold(
      appBar: AppBar(
        title: const GameTitleButton(gameName: '金铲铲之战'),
        actions: [
          if (busy)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: mode.isEmpty ? null : _refresh,
              tooltip: '抓取当前模式',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(showModes ? 44 : 0),
          child: showModes
              ? _ModeRow(active: mode, onPick: _pickMode)
              : const SizedBox.shrink(),
        ),
      ),
      body: Column(
        children: [
          if (crawl.error != null && crawl.mode == mode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      crawl.error!,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: mode.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _index,
                    children: [
                      for (final k in _Kind.values)
                        _JccSection(kind: k, mode: mode, rows: all),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
        ],
      ),
    );
  }
}

enum _Kind { lineup, trait, champion, item, other }

/// 「其他」分区下的栏目：type 即 Entity.type，对应官方 jcc.qq.com 的资料库子页。
/// byMode=false 表示该栏目的数据不随模式切换（特殊机制按官方 mechanism_tab 的类别归属）。
const jccOtherColumns =
    <({String type, String label, String source, IconData icon, bool byMode})>[
      (
        type: 'augment',
        label: '强化符文',
        source: 'jcc.qq.com/#/hex',
        icon: Icons.auto_awesome,
        byMode: true,
      ),
      (
        type: 'mech',
        label: '特殊机制',
        source: 'jcc.qq.com/#/mech',
        icon: Icons.settings_suggest,
        byMode: false,
      ),
    ];

/// 模式选择行：只有一个模式时不占位。
class _ModeRow extends ConsumerWidget {
  final String active;
  final ValueChanged<String> onPick;

  const _ModeRow({required this.active, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = ref.watch(gameModesProvider('jcc')).value ?? const <GameMode>[];
    if (modes.length < 2) return const SizedBox.shrink();
    final accent = gameAccent['jcc']!;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        itemCount: modes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = modes[i];
          final on = m.id == active;
          return ActionChip(
            label: Text(
              m.name,
              style: TextStyle(fontSize: 12.5, color: on ? accent : null),
            ),
            backgroundColor: on ? accent.withValues(alpha: 0.16) : null,
            onPressed: () => onPick(m.id),
          );
        },
      ),
    );
  }
}

const _kindTypes = {
  _Kind.lineup: 'lineup',
  _Kind.trait: 'trait',
  _Kind.champion: 'champion',
  _Kind.item: 'item',
};

class _JccSection extends ConsumerStatefulWidget {
  final _Kind kind;
  final String mode;
  final AsyncValue<List<Entity>> rows;

  const _JccSection({required this.kind, required this.mode, required this.rows});

  @override
  ConsumerState<_JccSection> createState() => _JccSectionState();
}

class _JccSectionState extends ConsumerState<_JccSection> {
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _match(Entity e) {
    final t = _kindTypes[widget.kind];
    if (t != null) return e.type == t;
    if (widget.kind == _Kind.other) {
      return jccOtherColumns.any((c) => c.type == e.type);
    }
    return !const ['lineup', 'trait', 'champion', 'item'].contains(e.type);
  }

  @override
  Widget build(BuildContext context) {
    final scraper = ref.watch(scrapersProvider)['jcc']!;
    final crawl = ref.watch(crawlProvider);
    final q = _query.trim();
    final all = (widget.rows.value ?? const <Entity>[]).where(_match).toList();
    final list = all.where((e) {
      if (q.isEmpty) return true;
      return e.title.contains(q) || e.subtitle.contains(q) || e.payload.contains(q);
    }).toList();

    if (widget.kind == _Kind.champion) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(crawlProvider.notifier).refresh('jcc', mode: widget.mode),
        child: Column(
          children: [
            _searchBox(scraper, hint: '搜索英雄名、技能介绍'),
            Expanded(
              child: all.isEmpty
                  ? _empty(crawl.running && crawl.mode == widget.mode)
                  : _HeroTable(entities: all, rows: _heroRows(all)),
            ),
          ],
        ),
      );
    }

    if (widget.kind == _Kind.trait) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(crawlProvider.notifier).refresh('jcc', mode: widget.mode),
        child: Column(
          children: [
            _searchBox(scraper, hint: '搜索羁绊名、效果'),
            Expanded(
              child: all.isEmpty
                  ? _empty(crawl.running && crawl.mode == widget.mode)
                  : _TraitsView(cards: _traitCards(list), mode: widget.mode),
            ),
          ],
        ),
      );
    }

    if (widget.kind == _Kind.item) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(crawlProvider.notifier).refresh('jcc', mode: widget.mode),
        child: Column(
          children: [
            _searchBox(scraper),
            Expanded(
              child: all.isEmpty
                  ? _empty(crawl.running && crawl.mode == widget.mode)
                  : _ItemsView(rows: _itemRows(list), flat: q.trim().isNotEmpty),
            ),
          ],
        ),
      );
    }

    if (widget.kind == _Kind.other) {
      final cats = ref.watch(mechCategoriesProvider).value ?? const <MechCategory>[];
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(crawlProvider.notifier).refresh('jcc', mode: widget.mode),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          children: [
            for (final c in jccOtherColumns)
              _columnCard(
                c,
                c.byMode
                    ? '共 ${all.where((e) => e.type == c.type).length} 条'
                    : cats.isEmpty
                    ? '官方分类'
                    : cats.map((k) => k.name).join(' · '),
              ),
          ],
        ),
      );
    }

    final grid = widget.kind != _Kind.lineup && widget.kind != _Kind.other;

    return RefreshIndicator(
      onRefresh: () => ref.read(crawlProvider.notifier).refresh('jcc', mode: widget.mode),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _searchBox(scraper)),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _empty(crawl.running && crawl.mode == widget.mode),
            )
          else if (grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 118,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _tile(list[i]),
                  childCount: list.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => widget.kind == _Kind.lineup
                      ? _lineupCard(list[i])
                      : _row(list[i], scraper.typeLabels[list[i].type] ?? ''),
                  childCount: list.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  '共 ${list.length} 条',
                  style: const TextStyle(color: Color(0xFF68727F), fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 「其他」分区的一个栏目入口，点进去才是列表。
  Widget _columnCard(
    ({String type, String label, String source, IconData icon, bool byMode}) c,
    String detail,
  ) {
    final accent = gameAccent['jcc']!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(c.icon, color: accent),
        title: Text(
          c.label,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$detail · 官方 ${c.source}',
          maxLines: 2,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF68727F)),
        onTap: () => context.push('/jcc/column?type=${c.type}'),
      ),
    );
  }

  Widget _searchBox(GameScraper scraper, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 20),
          hintText: hint ?? '搜索${_label(scraper)}',
          isDense: true,
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  /// 英雄表格行数据来自 heroCard 块；解码开销大，按数据集对象缓存一次。
  List<_HeroRow> _heroCache = const [];
  Object? _heroCacheSrc;

  List<_HeroRow> _heroRows(List<Entity> entities) {
    if (!identical(_heroCacheSrc, widget.rows) || _heroCache.length != entities.length) {
      _heroCache = [for (final e in entities) _HeroRow.decode(e)];
      _heroCacheSrc = widget.rows;
    }
    return _heroCache;
  }

  /// 羁绊卡片数据来自 traitCard 块；解码开销大，按数据集对象缓存一次。
  List<_TraitCard> _traitCache = const [];
  Object? _traitCacheSrc;

  List<_TraitCard> _traitCards(List<Entity> entities) {
    if (!identical(_traitCacheSrc, widget.rows) ||
        _traitCache.length != entities.length) {
      _traitCache = [for (final e in entities) _TraitCard.decode(e)];
      _traitCacheSrc = widget.rows;
    }
    return _traitCache;
  }

  /// 装备卡片数据来自 itemCard 块；解码开销大，按数据集对象缓存一次。
  List<_ItemRow> _itemCache = const [];
  Object? _itemCacheSrc;

  List<_ItemRow> _itemRows(List<Entity> entities) {
    if (!identical(_itemCacheSrc, widget.rows) || _itemCache.length != entities.length) {
      _itemCache = [for (final e in entities) _ItemRow.decode(e)];
      _itemCacheSrc = widget.rows;
    }
    return _itemCache;
  }

  String _label(GameScraper scraper) {
    switch (widget.kind) {
      case _Kind.lineup:
        return '阵容';
      case _Kind.trait:
        return '羁绊';
      case _Kind.champion:
        return '英雄';
      case _Kind.item:
        return '装备';
      case _Kind.other:
        return '其他';
    }
  }

  Widget _empty(bool running) {
    return Column(
      children: [
        const SizedBox(height: 90),
        const Center(
          child: Icon(Icons.inbox_outlined, size: 46, color: Color(0xFF3A4250)),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _query.trim().isNotEmpty
                ? '没有匹配结果'
                : running
                ? '正在抓取数据…'
                : '暂无数据，下拉刷新',
            style: const TextStyle(color: Color(0xFF68727F)),
          ),
        ),
      ],
    );
  }

  Widget _lineupCard(Entity e) {
    final accent = Theme.of(context).colorScheme.primary;
    final blocks = decodeBlocks(e.payload);
    Map<String, dynamic>? card;
    for (final b in blocks) {
      if (b['k'] == 'card') card = b;
    }
    final heroes = card == null
        ? const <Map<String, dynamic>>[]
        : (card['heroes'] as List)
              .cast<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList();
    final quality = '${card?['quality'] ?? ''}';
    final tag = '${card?['tag'] ?? ''}';
    final difficulty = card?['difficulty'] is int
        ? card!['difficulty'] as int
        : int.tryParse('${card?['difficulty']}') ?? 0;
    final popularity = card?['popularity'] is int
        ? card!['popularity'] as int
        : int.tryParse('${card?['popularity']}') ?? 0;

    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      onTap: () => context.push('/detail/${Uri.encodeComponent(e.uid)}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: const BoxDecoration(
          color: Color(0xFF171C24),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HexBadge(
                  text: quality,
                  size: 24,
                  color: quality == 'S'
                      ? const Color(0xFFF2653A)
                      : const Color(0xFF3FA7FF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (tag.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      tag,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A3)),
                    ),
                  ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '详情 ›',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF8B95A3)),
                  ),
                ),
              ],
            ),
            if (heroes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final h in heroes)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChessAvatar(
                            size: 46,
                            pic: '${h['pic']}',
                            name: '${h['name']}',
                            cost: h['cost'] is int
                                ? h['cost'] as int
                                : int.tryParse('${h['cost']}') ?? 0,
                            star: h['star'] is int
                                ? h['star'] as int
                                : int.tryParse('${h['star']}') ?? 0,
                            carry: h['carry'] == true,
                            items: (h['items'] as List? ?? const []).cast<String>(),
                            uid: championUid(e.mode, '${h['id']}'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: Color(0xFF232C38)),
            ),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    '成型难度',
                    difficulty > 0
                        ? _stars(difficulty, accent)
                        : const Text('-', style: TextStyle(color: Color(0xFF68727F))),
                  ),
                ),
                Expanded(
                  child: _metric(
                    '流行度',
                    popularity > 0
                        ? _stars(popularity, accent)
                        : const Text('-', style: TextStyle(color: Color(0xFF68727F))),
                  ),
                ),
                Expanded(
                  child: _metric(
                    '平均排名',
                    const Text('-', style: TextStyle(color: Color(0xFF68727F))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A3))),
          const SizedBox(width: 6),
          Flexible(child: value),
        ],
      ),
    );
  }

  Widget _stars(int n, Color color) {
    final filled = n.clamp(0, 3);
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < filled ? Icons.star : Icons.star_border,
            size: 15,
            color: i < filled ? color : const Color(0xFF4A5361),
          ),
      ],
    );
  }

  Widget _row(Entity e, String typeLabel) => _EntityTile(entity: e, label: typeLabel);

  Widget _tile(Entity e) {
    final accent = Theme.of(context).colorScheme.primary;
    var sub = e.subtitle;
    if (sub.length > 14) sub = '${sub.substring(0, 14)}…';
    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      onTap: () => context.push('/detail/${Uri.encodeComponent(e.uid)}'),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF171C24),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RemoteThumb(url: e.thumb, size: 56, seed: e.title),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                e.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFE6E9EF),
                  height: 1.25,
                ),
              ),
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 英雄表格行：费用 + 种族（带图标）+ 职业（带图标），取自 heroCard 块。
class _TraitRef {
  final String name;
  final String pic;
  const _TraitRef(this.name, this.pic);
}

class _HeroRow {
  final Entity e;
  final int cost;
  final List<_TraitRef> origins;
  final List<_TraitRef> classes;

  const _HeroRow({
    required this.e,
    required this.cost,
    required this.origins,
    required this.classes,
  });

  factory _HeroRow.decode(Entity e) {
    var cost = 0;
    final origins = <_TraitRef>[];
    final classes = <_TraitRef>[];
    for (final b in decodeBlocks(e.payload)) {
      if (b['k'] != 'heroCard') continue;
      cost = b['cost'] is int ? b['cost'] as int : int.tryParse('${b['cost']}') ?? 0;
      for (final t in (b['traits'] as List? ?? const []).cast<Map>().map(
        (m) => m.cast<String, dynamic>(),
      )) {
        final name = '${t['name']}';
        if (name.isEmpty) continue;
        (t['type'] == 1 ? classes : origins).add(_TraitRef(name, '${t['pic'] ?? ''}'));
      }
    }
    return _HeroRow(e: e, cost: cost, origins: origins, classes: classes);
  }
}

/// 英雄列表：英雄 / 种族 / 职业 / 费用 四列，支持筛选与排序。
class _HeroTable extends StatefulWidget {
  final List<Entity> entities;
  final List<_HeroRow> rows;

  const _HeroTable({required this.entities, required this.rows});

  @override
  State<_HeroTable> createState() => _HeroTableState();
}

class _HeroTableState extends State<_HeroTable> {
  String? _origin;
  String? _class;
  int? _cost;
  bool _byCost = true;
  bool _ascending = true;

  List<_HeroRow> _visible(List<_HeroRow> rows) {
    final out = rows.where((r) {
      if (_origin != null && !r.origins.any((t) => t.name == _origin)) {
        return false;
      }
      if (_class != null && !r.classes.any((t) => t.name == _class)) {
        return false;
      }
      if (_cost != null && r.cost != _cost) return false;
      return true;
    }).toList();
    out.sort((a, b) {
      final c = _byCost ? a.cost.compareTo(b.cost) : a.e.title.compareTo(b.e.title);
      if (c != 0) return _ascending ? c : -c;
      return a.e.sortOrder.compareTo(b.e.sortOrder);
    });
    return out;
  }

  List<T> _options<T>(Iterable<T> values) => [
    ...{...values},
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final rows = _visible(widget.rows);
    final originOptions = _options(
      widget.rows.expand((r) => r.origins.map((t) => t.name)),
    );
    final classOptions = _options(
      widget.rows.expand((r) => r.classes.map((t) => t.name)),
    );
    final costOptions = _options<int>(
      widget.rows.map((r) => r.cost).where((c) => c > 0).toList()..sort(),
    );
    if (_origin != null && !originOptions.contains(_origin)) _origin = null;
    if (_class != null && !classOptions.contains(_class)) _class = null;
    if (_cost != null && !costOptions.contains(_cost)) _cost = null;

    if (widget.rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: Text('暂无英雄', style: TextStyle(color: Color(0xFF68727F))),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: _filter<String>(
                  '种族',
                  _origin,
                  originOptions,
                  (v) => setState(() => _origin = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filter<String>(
                  '职业',
                  _class,
                  classOptions,
                  (v) => setState(() => _class = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filter<int?>(
                  '费用',
                  _cost,
                  costOptions,
                  (v) => setState(() => _cost = v),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(flex: 6, child: _headerCell('英雄', !_byCost, accent)),
              const Expanded(
                flex: 4,
                child: Text(
                  '种族',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF8B95A3)),
                ),
              ),
              const Expanded(
                flex: 4,
                child: Text(
                  '职业',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF8B95A3)),
                ),
              ),
              SizedBox(width: 44, child: _headerCell('费用', _byCost, accent)),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF232C38)),
        Expanded(
          child: rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text('没有符合条件的英雄', style: TextStyle(color: Color(0xFF68727F))),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                    color: Color(0xFF1F2733),
                  ),
                  itemBuilder: (_, i) => _heroRow(rows[i], accent),
                ),
        ),
      ],
    );
  }

  Widget _headerCell(String text, bool sorted, Color accent) {
    return InkWell(
      onTap: () => setState(() {
        if (_byCost == (text == '费用')) {
          _ascending = !_ascending;
        } else {
          _byCost = text == '费用';
          _ascending = true;
        }
      }),
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: sorted ? accent : const Color(0xFF8B95A3),
                fontWeight: sorted ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (sorted)
            Icon(
              _ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 13,
              color: accent,
            )
          else
            const Icon(Icons.unfold_more, size: 13, color: Color(0xFF5A6472)),
        ],
      ),
    );
  }

  Widget _heroRow(_HeroRow r, Color accent) {
    return InkWell(
      onTap: () => context.push('/detail/${Uri.encodeComponent(r.e.uid)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 6,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10151C),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: costColor(r.cost), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: r.e.thumb.isEmpty
                          ? _thumbFallback(r)
                          : Image.network(
                              r.e.thumb,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _thumbFallback(r),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: fgColor),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 4, child: _traitColumn(r.origins)),
            Expanded(flex: 4, child: _traitColumn(r.classes)),
            SizedBox(
              width: 44,
              child: Text(
                r.cost <= 0 ? '-' : '${r.cost}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: costColor(r.cost),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 立绘缺失或加载失败时用名字首字兜底，避免整列空白。
  Widget _thumbFallback(_HeroRow r) => Center(
    child: Text(
      r.e.title.characters.first,
      style: TextStyle(
        color: costColor(r.cost),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  /// 一列羁绊：官方图标 + 名称，最多两条。
  Widget _traitColumn(List<_TraitRef> refs) {
    if (refs.isEmpty) {
      return const Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF68727F)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in refs.take(2))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: t.pic.isEmpty
                      ? ColoredBox(
                          color: const Color(0xFF1B222C),
                          child: Center(
                            child: Text(
                              t.name.characters.first,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFB9C2CF),
                              ),
                            ),
                          ),
                        )
                      : ClipOval(
                          child: Image.network(
                            t.pic,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFB9C2CF)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _filter<T>(String label, T? value, List<T> options, ValueChanged<T?> onChanged) {
    final accent = Theme.of(context).colorScheme.primary;
    final active = value != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.16) : const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? accent : const Color(0xFF232C38)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(10),
          menuMaxHeight: 330,
          dropdownColor: const Color(0xFF1B222C),
          style: TextStyle(
            fontSize: 12.5,
            color: active ? accent : const Color(0xFFB9C2CF),
          ),
          icon: const Icon(Icons.expand_more, size: 16),
          onChanged: options.isEmpty ? null : onChanged,
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text('全部$label', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            for (final o in options)
              DropdownMenuItem<T?>(
                value: o,
                child: Text('$o', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

/// 装备行：官方 itemCard 块的解码结果，合成矩阵只需要 id/分类/组件，弹窗直接复用原始块。
class _ItemRow {
  final Entity e;
  final String id;
  final String cat;
  final String pic;
  final String s1id;
  final String s2id;
  final Map<String, dynamic> card;

  const _ItemRow({
    required this.e,
    required this.cat,
    required this.pic,
    required this.card,
    this.id = '',
    this.s1id = '',
    this.s2id = '',
  });

  bool get craftable => s1id.isNotEmpty && s2id.isNotEmpty;

  factory _ItemRow.decode(Entity e) {
    for (final b in decodeBlocks(e.payload)) {
      if (b['k'] != 'itemCard') continue;
      final s1 = (b['s1'] as Map? ?? const {}).cast<String, dynamic>();
      final s2 = (b['s2'] as Map? ?? const {}).cast<String, dynamic>();
      return _ItemRow(
        e: e,
        id: '${b['id'] ?? ''}',
        cat: '${b['cat'] ?? e.subtitle}',
        pic: '${b['pic'] ?? e.thumb}',
        s1id: '${s1['id'] ?? ''}',
        s2id: '${s2['id'] ?? ''}',
        card: b,
      );
    }
    return _ItemRow(
      e: e,
      cat: e.subtitle,
      pic: e.thumb,
      card: {'name': e.title, 'pic': e.thumb},
    );
  }
}

/// 装备页：基础装备一行 → 合成列表 10×10 矩阵 → 其余分类图标网格，点击弹出装备卡。
class _ItemsView extends StatelessWidget {
  final List<_ItemRow> rows;
  final bool flat;
  const _ItemsView({required this.rows, this.flat = false});

  static String _pair(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  static String _catLabel(String cat) => switch (cat) {
    '转职纹章' => '其他转职',
    '神器装备' => '奥恩神器',
    '-1' => '其他',
    '' => '未分类',
    _ => cat,
  };

  @override
  Widget build(BuildContext context) {
    if (flat) return _flatView(context);

    final base = <_ItemRow>[];
    final byId = <String, _ItemRow>{};
    for (final r in rows) {
      if (r.id.isNotEmpty) byId[r.id] = r;
      if (r.cat == '基础装备') base.add(r);
    }

    final pairs = <String, _ItemRow>{};
    for (final r in rows) {
      if (!r.craftable) continue;
      final a = byId[r.s1id], b = byId[r.s2id];
      if (a == null || b == null) continue;
      if (a.cat != '基础装备' || b.cat != '基础装备') continue;
      pairs.putIfAbsent(_pair(r.s1id, r.s2id), () => r);
    }

    final inMatrix = <String>{
      for (final r in base) r.id,
      for (final r in pairs.values) r.id,
    };
    final groups = <String, List<_ItemRow>>{};
    for (final r in rows) {
      if (inMatrix.contains(r.id)) continue;
      (groups[r.cat] ??= <_ItemRow>[]).add(r);
    }

    return LayoutBuilder(
      builder: (context, box) {
        final side = (box.maxWidth - 24) / 11;
        final bside = (box.maxWidth - 24) / (base.isEmpty ? 11 : base.length);
        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            if (base.isNotEmpty) ...[
              _header(context, '基础装备', base.length),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(children: [for (final r in base) _cell(context, r, bside)]),
              ),
            ],
            if (pairs.isNotEmpty) ...[
              _header(context, '合成列表', pairs.length),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: side,
                          child: const Text(
                            '基础\n装备',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.25,
                              color: Color(0xFF8B95A3),
                            ),
                          ),
                        ),
                        for (final b in base) _cell(context, b, side),
                      ],
                    ),
                    for (final rb in base)
                      Row(
                        children: [
                          _cell(context, rb, side),
                          for (final cb in base)
                            _cell(context, pairs[_pair(rb.id, cb.id)], side),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            for (final g in groups.entries) ...[
              _header(context, _catLabel(g.key), g.value.length),
              _grid(context, g.value),
            ],
          ],
        );
      },
    );
  }

  Widget _flatView(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 84,
        childAspectRatio: 0.82,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: rows.length,
      itemBuilder: (_, i) => _labeledIcon(context, rows[i]),
    );
  }

  Widget _header(BuildContext context, String title, int count) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: const Color(0xFF131922),
      child: Row(
        children: [
          Container(width: 3, height: 13, color: accent),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
          const Spacer(),
          Text(
            '$count 件',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF68727F)),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, List<_ItemRow> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: LayoutBuilder(
        builder: (context, box) {
          const columns = 6;
          final cell = (box.maxWidth - 5 * 6) / columns;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in items)
                SizedBox(
                  width: cell,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [_icon(context, r, cell), _name(r)],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _name(_ItemRow r) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        r.e.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: Color(0xFFB9C2CF), height: 1.2),
      ),
    );
  }

  Widget _labeledIcon(BuildContext context, _ItemRow r) {
    return LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight * 0.72;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [_icon(context, r, cell), _name(r)],
        );
      },
    );
  }

  Widget _cell(BuildContext context, _ItemRow? r, double cell) {
    return SizedBox(
      width: cell,
      height: cell,
      child: r == null ? _blank(cell) : _icon(context, r, cell),
    );
  }

  Widget _blank(double cell) {
    return Padding(
      padding: EdgeInsets.all(cell * 0.06),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12171E),
          borderRadius: BorderRadius.circular(cell * 0.16),
        ),
      ),
    );
  }

  Widget _icon(BuildContext context, _ItemRow r, double cell) {
    return Padding(
      padding: EdgeInsets.all(cell * 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(cell * 0.16),
        onTap: () => showDialog(context: context, builder: (_) => _ItemDialog(r)),
        child: RemoteThumb(
          url: r.pic.isEmpty ? r.e.thumb : r.pic,
          size: cell * 0.88,
          seed: r.e.title,
        ),
      ),
    );
  }
}

/// 装备弹窗：官方属性与效果 + 阵容反查的常见携带。
class _ItemDialog extends StatelessWidget {
  final _ItemRow row;
  const _ItemDialog(this.row);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 70),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF232C38)),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(right: 6),
              child: ItemCardView(row.card, mode: row.e.mode),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF8B95A3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 羁绊卡片：官方 traitCard 块的解码结果，种族/职业两段同页展示，不进详情页。
class _TraitCard {
  final Entity e;
  final int type;
  final String pic;
  final String prefix;
  final List<Map<String, dynamic>> tiers;
  final List<Map<String, dynamic>> members;

  const _TraitCard({
    required this.e,
    required this.type,
    required this.pic,
    required this.prefix,
    required this.tiers,
    required this.members,
  });

  factory _TraitCard.decode(Entity e) {
    var type = 0;
    var pic = e.thumb;
    var prefix = '';
    var tiers = const <Map<String, dynamic>>[];
    var members = const <Map<String, dynamic>>[];
    for (final b in decodeBlocks(e.payload)) {
      if (b['k'] != 'traitCard') continue;
      type = b['type'] is int ? b['type'] as int : int.tryParse('${b['type']}') ?? 0;
      pic = '${b['pic'] ?? e.thumb}';
      prefix = '${b['prefix'] ?? ''}'.trim();
      tiers = (b['tiers'] as List? ?? const [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
      members = (b['members'] as List? ?? const [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    }
    return _TraitCard(
      e: e,
      type: type,
      pic: pic,
      prefix: prefix,
      tiers: tiers,
      members: members,
    );
  }
}

/// 羁绊页：顶部「种族 / 职业」两段切换，卡片左侧图标+成员头像，右侧机制说明与档位效果。
class _TraitsView extends StatefulWidget {
  final List<_TraitCard> cards;

  /// 成员头像跳英雄详情需要用到当前模式。
  final String mode;
  const _TraitsView({required this.cards, required this.mode});

  @override
  State<_TraitsView> createState() => _TraitsViewState();
}

class _TraitsViewState extends State<_TraitsView> {
  bool _origin = true;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final shown = widget.cards.where((c) => (c.type == 1) != _origin).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              Expanded(child: _tab('种族', _origin)),
              Expanded(child: _tab('职业', !_origin)),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF232C38)),
        Expanded(
          child: shown.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text('没有符合条件的羁绊', style: TextStyle(color: Color(0xFF68727F))),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(shown[i], accent),
                ),
        ),
      ],
    );
  }

  Widget _tab(String label, bool active) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => setState(() => _origin = label == '种族'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? accent : const Color(0xFF8B95A3),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 26,
              height: 2.5,
              decoration: BoxDecoration(
                color: active ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(_TraitCard c, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232C38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1B222C),
                    border: Border.all(color: accent.withValues(alpha: .45)),
                  ),
                  child: ClipOval(
                    child: c.pic.isEmpty
                        ? Center(
                            child: Text(
                              c.e.title.characters.first,
                              style: TextStyle(
                                fontSize: 19,
                                color: accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Image.network(
                            c.pic,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                  ),
                ),
                if (c.members.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [for (final m in c.members.take(8)) _member(m)],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.e.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
                if (c.prefix.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      c.prefix,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF9AA3B2),
                        height: 1.55,
                      ),
                    ),
                  ),
                for (final t in c.tiers)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tierBadge(
                          '${t['num']}',
                          t['color'] is int
                              ? t['color'] as int
                              : int.tryParse('${t['color']}') ?? 0,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${t['text']}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: fgColor,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 档位徽标：官方 color 序号沿用 App 内的费用色板，保持同一套色彩语言。
  Widget _tierBadge(String num, int color) {
    final bg = costColor(color <= 0 ? 1 : color);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: Text(
          num.isEmpty ? '-' : num,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0E1116),
          ),
        ),
      ),
    );
  }

  Widget _member(Map<String, dynamic> m) {
    final cost = m['cost'] is int ? m['cost'] as int : int.tryParse('${m['cost']}') ?? 0;
    final name = '${m['name']}';
    final pic = '${m['pic']}';
    final uid = championUid(widget.mode, '${m['id']}');
    final face = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10151C),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: costColor(cost), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: pic.isEmpty
            ? Center(
                child: Text(
                  name.characters.first,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: costColor(cost),
                  ),
                ),
              )
            : Image.network(
                pic,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    name.characters.first,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: costColor(cost),
                    ),
                  ),
                ),
              ),
      ),
    );
    return SizedBox(
      width: 38,
      height: 38,
      child: Tooltip(
        message: name,
        child: uid.isEmpty
            ? face
            : InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => context.push('/detail/${Uri.encodeComponent(uid)}'),
                child: face,
              ),
      ),
    );
  }
}

/// 通用条目行：图标 + 名称 + 副标题（缺失时用类型名），点击进详情。
/// `tappable: false` 给「行内就能看全」的栏目（强化符文 / 特殊机制）用：不跳详情；
/// 这时把官方效果正文放进 `desc`，摊在副标题下面整段显示，不再单行截断。
class _EntityTile extends StatelessWidget {
  final Entity entity;
  final String label;
  final bool tappable;
  final String desc;

  const _EntityTile({
    required this.entity,
    required this.label,
    this.tappable = true,
    this.desc = '',
  });

  @override
  Widget build(BuildContext context) {
    final full = desc.isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: RemoteThumb(url: entity.thumb, size: 52, seed: entity.title),
        title: Text(
          entity.title,
          maxLines: full ? null : 1,
          overflow: full ? null : TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行内已经摊开正文时，副标题空着就别拿栏目名去占一行。
            if (entity.subtitle.isNotEmpty || !full)
              Text(
                entity.subtitle.isEmpty ? label : entity.subtitle,
                maxLines: full ? null : 2,
              ),
            if (full)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF9AA3B2),
                  ),
                ),
              ),
          ],
        ),
        onTap: tappable
            ? () => context.push('/detail/${Uri.encodeComponent(entity.uid)}')
            : null,
      ),
    );
  }
}

/// 「其他」分区某个栏目的列表页（强化符文 / 特殊机制），模式在这一页的顶部选择。
class JccColumnScreen extends ConsumerStatefulWidget {
  final String type;

  const JccColumnScreen({super.key, required this.type});

  @override
  ConsumerState<JccColumnScreen> createState() => _JccColumnScreenState();
}

class _JccColumnScreenState extends ConsumerState<JccColumnScreen> {
  String _query = '';
  String _autoCrawlFor = '';
  String _cat = '';
  String _tier = '';
  final _ctrl = TextEditingController();

  bool get _isMech => widget.type == 'mech';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _refresh(String mode) => _isMech
      ? ref.read(crawlProvider.notifier).refreshMech()
      : ref.read(crawlProvider.notifier).refresh('jcc', mode: mode);

  @override
  Widget build(BuildContext context) {
    final scraper = ref.watch(scrapersProvider)['jcc']!;
    final crawl = ref.watch(crawlProvider);
    final appMode = ref.watch(jccModeProvider);
    final cats = _isMech
        ? ref.watch(mechCategoriesProvider).value ?? const <MechCategory>[]
        : const <MechCategory>[];
    if (_isMech && cats.isNotEmpty && !cats.any((c) => c.id == _cat)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _cat = cats.first.id),
      );
    }
    final cat = cats.where((c) => c.id == _cat).firstOrNull;
    // 特殊机制按官方 mechanism_tab 的类别取数，类别自带归属模式；其余栏目跟着选中的模式走。
    final mode = _isMech ? (cat?.modeId ?? '') : appMode;
    final busyKey = _isMech ? mechCrawlMode : mode;
    final col = jccOtherColumns.where((c) => c.type == widget.type).firstOrNull;
    final label = col?.label ?? scraper.typeLabels[widget.type] ?? '其他';
    final rows = ref.watch(
      entitiesQueryProvider((game: 'jcc', mode: mode, type: widget.type, query: '')),
    );
    final all = rows.value ?? const <Entity>[];
    final accent = gameAccent['jcc']!;
    final q = _query.trim();
    // 只有强化符文有档位这一维（特殊机制的维度是顶部那排类别 tab）。
    final tiers = _isMech
        ? const <String>[]
        : [
            for (final t in jccAugmentTiers)
              for (final s in all.map((e) => e.subtitle).toSet())
                if (s.startsWith(t)) s,
          ];
    // 切到别的模式后原来选的档位可能一个都没有，那就等于没筛，别留个空列表。
    final tier = tiers.contains(_tier) ? _tier : '';
    final list = all
        .where((e) => tier.isEmpty || e.subtitle == tier)
        .where(
          (e) =>
              q.isEmpty ||
              e.title.contains(q) ||
              e.subtitle.contains(q) ||
              e.payload.contains(q),
        )
        .toList();
    final working = crawl.running && crawl.mode == busyKey;

    if (mode.isNotEmpty &&
        ref.watch(settingsProvider).autoRefreshOf('jcc') &&
        !crawl.running &&
        _autoCrawlFor != busyKey &&
        all.isEmpty) {
      _autoCrawlFor = busyKey;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(mode));
    }

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: RefreshIndicator(
        onRefresh: () => _refresh(mode),
        child: Column(
          children: [
            if (_isMech)
              _catTabs(cats)
            else
              _ModeRow(
                active: appMode,
                onPick: (id) => ref.read(jccModeProvider.notifier).setMode(id),
              ),
            if (crawl.error != null && crawl.mode == busyKey)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        crawl.error!,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: '搜索${_isMech ? (cat?.name ?? label) : label}',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (tiers.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: filterChipRow(
                  '档位',
                  tiers,
                  tier,
                  accent,
                  (v) => setState(() => _tier = v),
                ),
              ),
            Expanded(
              child: list.isEmpty
                  // ListView 而非空 Container：否则下拉刷新手势不生效。
                  ? ListView(
                      children: [
                        const SizedBox(height: 90),
                        const Center(
                          child: Icon(
                            Icons.inbox_outlined,
                            size: 46,
                            color: Color(0xFF3A4250),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            q.isNotEmpty
                                ? '没有匹配结果'
                                : working
                                ? '正在抓取数据…'
                                : '暂无数据，下拉刷新',
                            style: const TextStyle(color: Color(0xFF68727F)),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _EntityTile(
                        entity: list[i],
                        label: label,
                        // 这两个栏目的正文就一行效果说明，摊在列表里看全，不再进详情页。
                        tappable: false,
                        desc: _descOf(list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 特殊机制的类别 tab（官方 mechanism_tab：奇遇 / 小精灵）。
  Widget _catTabs(List<MechCategory> cats) {
    if (cats.length < 2) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              for (final c in cats)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _cat = c.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: _cat == c.id
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _cat == c.id ? accent : const Color(0xFF8B95A3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 26,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: _cat == c.id ? accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF232C38)),
      ],
    );
  }

  /// 摊进行内显示的效果正文：官方 desc 存在 payload 的第一个 text 块里。
  String _descOf(Entity e) {
    for (final b in decodeBlocks(e.payload)) {
      if (b['k'] == 'text') return '${b['t']}';
    }
    return '';
  }
}
