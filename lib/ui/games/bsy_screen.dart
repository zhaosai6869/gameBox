import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/bsy_scraper.dart';
import '../../data/db.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../blocks_view.dart';
import '../game_popup.dart';

/// 不思议迷宫专属页面：底部菜单「冈布奥 / 关卡 / 密令 / 神庙试炼 / 其他」。
///
/// 「冈布奥」来自官方图鉴（带阵营/称号分类），「关卡」与「神庙试炼」来自 4399 专区；
/// 「其他」下的九个栏目只有入口卡片，内容待接入。
class BsyScreen extends ConsumerStatefulWidget {
  const BsyScreen({super.key});

  @override
  ConsumerState<BsyScreen> createState() => _BsyScreenState();
}

class _BsyScreenState extends ConsumerState<BsyScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scraper = ref.watch(scrapersProvider)['bsy']!;
    final crawl = ref.watch(crawlProvider);

    return Scaffold(
      appBar: AppBar(
        title: GameTitleButton(gameName: scraper.gameName),
        actions: [
          if (crawl.running)
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
              onPressed: () => ref.read(crawlProvider.notifier).refresh('bsy'),
              tooltip: '抓取最新数据',
            ),
        ],
      ),
      body: Column(
        children: [
          if (crawl.error != null)
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
            child: IndexedStack(
              index: _index,
              children: [for (final k in _BsyKind.values) _BsySection(kind: k)],
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
          for (final k in _BsyKind.values)
            NavigationDestination(icon: Icon(k.icon), label: k.label),
        ],
      ),
    );
  }
}

enum _BsyKind {
  gumball('冈布奥', Icons.emoji_emotions_outlined),
  level('关卡', Icons.map_outlined),
  code('密令', Icons.key_outlined),
  temple('神庙试炼', Icons.workspace_premium_outlined),
  other('其他', Icons.category_outlined);

  final String label;
  final IconData icon;
  const _BsyKind(this.label, this.icon);
}

/// 只有 subtitle 本身是分类维度的栏目才显示筛选行；其余栏目（神龙许愿、机械祭坛…）
/// 的 subtitle 是说明文字，拿来做 chips 只会刷屏。
const bsyColumnGroups = {'feiting': '类别', 'yaoji': '等级', 'dp': '分区'};

/// 这四个栏目的条目信息全在列表行里（左柱 + 右柱 → 奖励 / 祭品 → 产出 / 提交 → 获得 /
/// 问题 → 答案），详情页只是把同一份 kv 再摆一次，按要求不再点击跳转。
const bsyListOnlyColumns = {'shizhu', 'jitan', 'shrine', 'quiz'};

/// 「其他」分区下的十二个栏目入口，全部已接好源：十一个是 `bsyColumnSources` 里的页面
/// （飞艇图鉴按类别分三页），「游戏攻略」是 `bsyGuideModules` 那十四篇固定文章。
/// 条目在栏目页首次打开时按需抓。
const bsyOtherColumns = <({String type, String label, IconData icon, String source})>[
  (type: 'feiting', label: '飞艇图鉴', icon: Icons.rocket_launch, source: '3DM 手游'),
  (type: 'robot', label: '天空机器人', icon: Icons.smart_toy_outlined, source: '3DM 手游'),
  (type: 'abyss', label: '深渊咆哮', icon: Icons.nights_stay, source: '4399 专区'),
  (type: 'shenlong', label: '神龙许愿', icon: Icons.auto_awesome, source: '4399 专区'),
  (type: 'yaoji', label: '药剂大全', icon: Icons.local_pharmacy, source: '4399 专区'),
  (type: 'shizhu', label: '命运石柱', icon: Icons.castle, source: '18183 专区'),
  (type: 'jitan', label: '机械祭坛', icon: Icons.electrical_services, source: '4399 专区'),
  (type: 'shrine', label: '东方神龛', icon: Icons.temple_buddhist, source: '4399 专区'),
  (type: 'dp', label: 'DP 攻略', icon: Icons.workspace_premium, source: '4399 专区'),
  (type: 'sky', label: '天空副本', icon: Icons.flight, source: '4399 专区'),
  (type: 'quiz', label: '天空问题', icon: Icons.help_outline, source: '4399 答题器'),
  (type: 'guide', label: '游戏攻略', icon: Icons.menu_book_outlined, source: '4399 专区'),
];

/// 入口卡片的副标题：抓过的报条数，没抓过的提示「打开时抓取」，没源的报「内容待接入」。
/// 游戏攻略是代码里写死的模块目录（`bsyGuideModules`，不联网），所以直接报模块数。
String _columnHint(String type, String source, int rows) {
  if (type == 'guide') return '${bsyGuideModules.length} 个模块 · $source';
  if (!bsyColumnHasSource(type)) return '内容待接入';
  return rows > 0 ? '共 $rows 条 · $source' : '$source · 打开时抓取';
}

class _BsySection extends ConsumerStatefulWidget {
  final _BsyKind kind;
  const _BsySection({required this.kind});

  @override
  ConsumerState<_BsySection> createState() => _BsySectionState();
}

class _BsySectionState extends ConsumerState<_BsySection> {
  final _ctrl = TextEditingController();
  String _query = '';
  String _camp = '';
  String _honor = '';
  String _templeSection = '';
  bool _autoCrawled = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.read(crawlProvider.notifier).refresh('bsy');

  @override
  Widget build(BuildContext context) {
    switch (widget.kind) {
      case _BsyKind.gumball:
        return _gumballs();
      case _BsyKind.level:
        return _levels();
      case _BsyKind.temple:
        return _temples();
      case _BsyKind.other:
        return _columns();
      case _BsyKind.code:
        return _placeholder();
    }
  }

  /// 空库时自动抓一次（冈布奥与关卡共用一次刷新，刷新本身是全游戏的）。
  /// `ready` 表示 DB 流已经出过值：首帧 `rows.value` 还是 null，只按 `all.isEmpty`
  /// 判断会把「还没查到」当成「库里没有」，切一次 tab 就重抓一遍全量。
  /// 设置里关掉该游戏的自动刷新后，这里只做本地展示，抓取只认手动 ↻ 与下拉刷新。
  void _autoCrawlIfEmpty(List<Entity> all, bool running, {required bool ready}) {
    if (!ready) return;
    if (!ref.watch(settingsProvider).autoRefreshOf('bsy')) return;
    if (all.isEmpty && !running && !_autoCrawled) {
      _autoCrawled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Widget _searchBox(String hint) =>
      _searchField(hint, _ctrl, (v) => setState(() => _query = v));

  Widget _footer(int count) => _listFooter(count);

  Widget _gumballs() {
    final accent = gameAccent['bsy']!;
    final crawl = ref.watch(crawlProvider);
    final rows = ref.watch(
      entitiesQueryProvider((game: 'bsy', mode: '', type: 'gumball', query: '')),
    );
    final all = rows.value ?? const <Entity>[];
    _autoCrawlIfEmpty(all, crawl.running, ready: rows.hasValue);

    final q = _query.trim();
    final list = all.where((e) {
      final tags = bsyGbaTags(e.subtitle);
      if (_camp.isNotEmpty && tags.camp != _camp) return false;
      if (_honor.isNotEmpty && tags.honor != _honor) return false;
      if (q.isEmpty) return true;
      return e.title.contains(q) || e.subtitle.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _searchBox('搜索冈布奥名、阵营、称号')),
          SliverToBoxAdapter(
            child: filterChipRow(
              '阵营',
              bsyCamps.values.toList(),
              _camp,
              accent,
              (v) => setState(() => _camp = v),
            ),
          ),
          SliverToBoxAdapter(
            child: filterChipRow(
              '称号',
              bsyHonors.values.toList(),
              _honor,
              accent,
              (v) => setState(() => _honor = v),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty(crawl.running))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 118,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _tile(list[i], accent),
                  childCount: list.length,
                ),
              ),
            ),
          _footer(list.length),
        ],
      ),
    );
  }

  Widget _levels() {
    final crawl = ref.watch(crawlProvider);
    final rows = ref.watch(
      entitiesQueryProvider((game: 'bsy', mode: '', type: 'level', query: '')),
    );
    final all = rows.value ?? const <Entity>[];
    _autoCrawlIfEmpty(all, crawl.running, ready: rows.hasValue);

    final q = _query.trim();
    final list = q.isEmpty
        ? all
        : all.where((e) => e.title.contains(q) || e.subtitle.contains(q)).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _searchBox('搜索关卡名')),
          if (list.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty(crawl.running))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _EntityRow(list[i]),
                  childCount: list.length,
                ),
              ),
            ),
          _footer(list.length),
        ],
      ),
    );
  }

  Widget _columns() {
    final rows = ref.watch(
      entitiesQueryProvider((game: 'bsy', mode: '', type: null, query: '')),
    );
    final all = rows.value ?? const <Entity>[];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      children: [
        for (final c in bsyOtherColumns)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: Icon(c.icon, color: gameAccent['bsy']),
              title: Text(
                c.label,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _columnHint(c.type, c.source, all.where((e) => e.type == c.type).length),
                style: const TextStyle(fontSize: 12, color: Color(0xFF68727F)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF68727F)),
              onTap: () => context.push('/bsy/column?type=${c.type}'),
            ),
          ),
      ],
    );
  }

  /// 神庙试炼：条目都是某个冈布奥的试炼，左侧用它的图鉴头像；列表按官方分区（subtitle）筛选。
  Widget _temples() {
    final accent = gameAccent['bsy']!;
    final crawl = ref.watch(crawlProvider);
    final rows = ref.watch(
      entitiesQueryProvider((game: 'bsy', mode: '', type: 'temple', query: '')),
    );
    final all = rows.value ?? const <Entity>[];
    _autoCrawlIfEmpty(all, crawl.running, ready: rows.hasValue);

    final q = _query.trim();
    final list = all.where((e) {
      if (_templeSection.isNotEmpty && e.subtitle != _templeSection) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.title.contains(q) || e.subtitle.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _searchBox('搜索试炼名')),
          if (all.length > 1)
            SliverToBoxAdapter(
              child: filterChipRow(
                '分区',
                all.map((e) => e.subtitle).where((s) => s.isNotEmpty).toSet().toList(),
                _templeSection,
                accent,
                (v) => setState(() => _templeSection = v),
              ),
            ),
          if (list.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty(crawl.running))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _EntityRow(list[i]),
                  childCount: list.length,
                ),
              ),
            ),
          _footer(list.length),
        ],
      ),
    );
  }

  Widget _tile(Entity e, Color accent) {
    final tags = bsyGbaTags(e.subtitle);
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFE6E9EF),
                  height: 1.25,
                ),
              ),
            ),
            if (tags.honor.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                tags.honor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: accent),
              ),
            ],
            if (tags.camp.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                tags.camp,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF68727F)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    final accent = gameAccent['bsy']!;
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(widget.kind.icon, size: 52, color: accent.withValues(alpha: 0.35)),
        const SizedBox(height: 14),
        Center(
          child: Text(
            '${widget.kind.label} · 数据待接入',
            style: const TextStyle(color: Color(0xFF68727F), fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// 「其他」里某个栏目的页面。十个页面型栏目已接好源（`bsyColumnSources`），条目在首次
/// 打开时按需抓一次；「游戏攻略」的目录直接来自 `bsyGuideModules`。
class BsyColumnScreen extends ConsumerStatefulWidget {
  final String type;

  const BsyColumnScreen({super.key, required this.type});

  @override
  ConsumerState<BsyColumnScreen> createState() => _BsyColumnScreenState();
}

class _BsyColumnScreenState extends ConsumerState<BsyColumnScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  String _group = '';
  String _autoCrawlFor = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      ref.read(crawlProvider.notifier).refreshColumn('bsy', widget.type);

  @override
  Widget build(BuildContext context) {
    final col = bsyOtherColumns.where((c) => c.type == widget.type).firstOrNull;
    final label = col?.label ?? '其他';
    final accent = gameAccent['bsy']!;
    final crawl = ref.watch(crawlProvider);
    final hasSource = bsyColumnHasSource(widget.type);
    final rows = ref.watch(
      entitiesQueryProvider((game: 'bsy', mode: '', type: widget.type, query: '')),
    );
    final all = rows.value ?? const <Entity>[];
    final working = crawl.running && crawl.mode == widget.type;

    if (hasSource &&
        ref.watch(settingsProvider).autoRefreshOf('bsy') &&
        rows.hasValue &&
        all.isEmpty &&
        !crawl.running &&
        _autoCrawlFor != widget.type) {
      _autoCrawlFor = widget.type;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }

    final q = _query.trim();
    final list = all.where((e) {
      if (_group.isNotEmpty && e.subtitle != _group) return false;
      if (q.isEmpty) return true;
      return e.title.contains(q) || e.subtitle.contains(q) || e.payload.contains(q);
    }).toList();
    final groupLabel = bsyColumnGroups[widget.type];
    final listOnly = bsyListOnlyColumns.contains(widget.type);
    final groups = groupLabel == null
        ? const <String>[]
        : all.map((e) => e.subtitle).where((s) => s.isNotEmpty).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            if (hasSource) ...[
              SliverToBoxAdapter(
                child: _searchField('搜索$label', _ctrl, (v) => setState(() => _query = v)),
              ),
              if (groups.length > 1)
                SliverToBoxAdapter(
                  child: filterChipRow(groupLabel!, groups, _group, accent, (v) {
                    setState(() => _group = v);
                    // 换分组后列表可能很长，回到顶部才看得见剩下的行。
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                  }),
                ),
              if (crawl.error != null && crawl.mode == widget.type)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Text(
                      crawl.error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ),
            ],
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: hasSource
                    ? _empty(working, hint: '下拉可重新抓取')
                    : _columnPlaceholder(col),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _EntityRow(list[i], tappable: !listOnly, full: listOnly),
                    childCount: list.length,
                  ),
                ),
              ),
            if (hasSource) _listFooter(list.length),
          ],
        ),
      ),
    );
  }

  Widget _columnPlaceholder(
    ({String type, String label, IconData icon, String source})? col,
  ) {
    final accent = gameAccent['bsy']!;
    // 用 Column 而不是 ListView：SliverFillRemaining 里再套一个可滚动子树不会画出来。
    return Column(
      children: [
        const SizedBox(height: 120),
        Icon(
          col?.icon ?? Icons.category_outlined,
          size: 52,
          color: accent.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 14),
        Text(
          '${col?.label ?? '该栏目'} · 内容待接入',
          style: const TextStyle(color: Color(0xFF68727F), fontSize: 13),
        ),
      ],
    );
  }
}

/// 搜索框：栏目页与五个分区共用。
Widget _searchField(
  String hint,
  TextEditingController ctrl,
  ValueChanged<String> onChanged,
) => Padding(
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
  child: TextField(
    controller: ctrl,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search, size: 20),
      hintText: hint,
      isDense: true,
    ),
    onChanged: onChanged,
  ),
);

Widget _listFooter(int count) => SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Center(
      child: Text(
        '共 $count 条',
        style: const TextStyle(color: Color(0xFF68727F), fontSize: 12),
      ),
    ),
  ),
);

/// 一行分类筛选：左侧固定标签 + 横向滚动的「全部 / 各分类」chips。
Widget _empty(bool running, {String hint = ''}) {
  return Column(
    children: [
      const SizedBox(height: 90),
      const Icon(Icons.inbox_outlined, size: 46, color: Color(0xFF3A4250)),
      const SizedBox(height: 12),
      Text(
        running
            ? '正在抓取数据…'
            : hint.isEmpty
            ? '没有内容，下拉或点击上方 ↻ 抓取'
            : '没有内容，$hint',
        style: const TextStyle(color: Color(0xFF68727F)),
      ),
    ],
  );
}

/// 一行条目：左侧缩略图（没有图就退回首字色块），点开进详情。
/// `tappable: false` 给纯列表栏目（`bsyListOnlyColumns`）用：不跳详情、没有箭头；
/// 条目自己那行没有源文章（`sourceUrl` 空，如深渊咆哮表格里没链接的冈布奥）同样不可点。
/// `full: true` 时标题与副标题不再单行截断，整段内容要在列表里看全 ——
/// 天空问题的题干前段是 NPC 开场白，截断后九行「伙计！我在操作机械时…」分不开。
class _EntityRow extends StatelessWidget {
  final Entity e;
  final bool tappable;
  final bool full;
  const _EntityRow(this.e, {this.tappable = true, this.full = false});

  @override
  Widget build(BuildContext context) {
    // 没有源文章的行不进详情页：点进去只会抓到一张空页。
    final canOpen = tappable && e.sourceUrl.isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: RemoteThumb(url: e.thumb, size: 52, seed: e.title),
        title: Text(
          e.title,
          maxLines: full ? null : 1,
          overflow: full ? null : TextOverflow.ellipsis,
        ),
        subtitle: Text(
          e.subtitle,
          maxLines: full ? null : 1,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: canOpen
            ? const Icon(Icons.chevron_right, color: Color(0xFF68727F), size: 20)
            : null,
        onTap: canOpen
            ? () => context.push('/detail/${Uri.encodeComponent(e.uid)}')
            : null,
      ),
    );
  }
}
