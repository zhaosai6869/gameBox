import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/scraper.dart';
import '../state/providers.dart';
import 'blocks_view.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final String uid;
  const DetailScreen({super.key, required this.uid});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  bool _loadingDetail = false;
  bool _autoTried = false;
  String? _detailError;

  Future<void> _loadDetail(Entity e) async {
    final gameId = e.uid.split(':').first;
    final scraper = ref.read(scrapersProvider)[gameId];
    if (scraper == null) return;
    setState(() {
      _loadingDetail = true;
      _detailError = null;
    });
    try {
      final blocks = await scraper.fetchDetail(
        ScrapedEntity(
          uid: e.uid,
          gameId: e.gameId,
          type: e.type,
          title: e.title,
          subtitle: e.subtitle,
          thumb: e.thumb,
          sourceUrl: e.sourceUrl,
          sortOrder: e.sortOrder,
        ),
      );
      if (blocks != null) {
        await ref
            .read(dbProvider)
            .updateOne(
              e.copyWith(
                payload: jsonEncode(blocks),
                crawledAt: DateTime.now().toIso8601String(),
              ),
            );
      }
    } catch (err) {
      if (mounted) setState(() => _detailError = '$err');
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entity = ref.watch(entityProvider(widget.uid));
    return Scaffold(
      appBar: AppBar(title: Text(entity.value?.title ?? '详情')),
      body: entity.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误：$e')),
        data: (row) {
          if (row == null) return const Center(child: Text('条目已不存在'));
          final blocks = decodeBlocks(row.payload);
          final accent = gameAccent[row.gameId] ?? theme0(context);
          Map<String, dynamic> card = const {};
          Map<String, dynamic> hero = const {};
          for (final b in blocks) {
            if (b['k'] == 'card') card = b;
            if (b['k'] == 'heroCard') hero = b;
          }
          final heroes = card['heroes'] is List
              ? (card['heroes'] as List)
                    .cast<Map>()
                    .map((m) => m.cast<String, dynamic>())
                    .toList()
              : const <Map<String, dynamic>>[];
          final banner = heroes.isEmpty
              ? ''
              : '${(heroes.firstWhere((h) => h['carry'] == true, orElse: () => heroes.first)['pic'])}';
          // 列表只存索引，正文进页面才抓；失败时下面那张手动卡片可重试。
          if (blocks.isEmpty &&
              row.sourceUrl.isNotEmpty &&
              !_autoTried &&
              !_loadingDetail) {
            _autoTried = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadDetail(row);
            });
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (hero.isNotEmpty) ...[
                _HeroHeader(hero: hero, title: row.title),
                const SizedBox(height: 12),
              ] else if (card.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 148,
                            width: double.infinity,
                            child: banner.isEmpty
                                ? const ColoredBox(color: cardBg)
                                : Image.network(
                                    banner,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(color: cardBg),
                                  ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x00000000), Color(0xCC000000)],
                                ),
                              ),
                              child: Row(
                                children: [
                                  HexBadge(
                                    text: '${card['quality'] ?? ''}',
                                    size: 26,
                                    color: '${card['quality']}' == 'S'
                                        ? const Color(0xFFF2653A)
                                        : const Color(0xFF3FA7FF),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.title,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.25,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Text(
                                            '${card['tag'] ?? ''} · 成型 ${card['level'] ?? '?'} 级',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFD6DCE5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RemoteThumb(url: row.thumb, size: 84, seed: row.title),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (row.subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                row.subtitle,
                                style: const TextStyle(color: Color(0xFF9AA3B2)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (hero.isEmpty && card.isEmpty) const SizedBox(height: 12),
              if (blocks.isEmpty && row.sourceUrl.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: _loadingDetail
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Icon(Icons.article_outlined, color: accent),
                    title: Text(_loadingDetail ? '正在抓取详情…' : '抓取详情页'),
                    subtitle: _detailError != null
                        ? Text(
                            _detailError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          )
                        : Text(
                            row.sourceUrl,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: _loadingDetail ? null : () => _loadDetail(row),
                  ),
                ),
              BlocksView(blocks, mode: row.mode),
              if (row.sourceUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    '来源：${row.sourceUrl}\n采集：${row.crawledAt.substring(0, row.crawledAt.length > 16 ? 16 : row.crawledAt.length)}',
                    style: const TextStyle(color: Color(0xFF68727F), fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Color theme0(BuildContext context) => Theme.of(context).colorScheme.primary;

/// 英雄详情头部：官方原画横幅 + 居中头像（费用徽标）+ 名字 + 带图标的羁绊行。
/// 参考图里的「称号」和皮肤槽官方源没有字段，不伪造。
class _HeroHeader extends StatelessWidget {
  final Map<String, dynamic> hero;
  final String title;
  const _HeroHeader({required this.hero, required this.title});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cost = hero['cost'] is int
        ? hero['cost'] as int
        : int.tryParse('${hero['cost']}') ?? 0;
    final banner = '${hero['banner'] ?? ''}';
    final version = '${hero['version'] ?? ''}';
    final traits = (hero['traits'] as List? ?? const [])
        .cast<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final origins = traits.where((t) => t['type'] != 1).toList();
    final classes = traits.where((t) => t['type'] == 1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                banner.isEmpty
                    ? const ColoredBox(color: cardBg)
                    : Image.network(
                        banner,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(color: cardBg),
                      ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x4D000000), Color(0x00000000), Color(0xF20E1116)],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
                if (version.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        version,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFD6DCE5)),
                      ),
                    ),
                  ),
                if (classes.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [for (final t in classes) _classChip(t, accent)],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -34),
          child: Column(
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: costColor(cost), width: 2.5),
                        color: const Color(0xFF10151C),
                      ),
                      child: ClipOval(
                        child: '${hero['pic']}'.isEmpty
                            ? null
                            : Image.network(
                                '${hero['pic']}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: costColor(cost),
                          border: Border.all(color: const Color(0xFF0E1116), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            cost <= 0 ? '-' : '$cost',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              if (traits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final t in [...origins, ...classes]) _traitLabel(t),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _classChip(Map<String, dynamic> t, Color accent) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _traitIcon(t, 14),
        const SizedBox(width: 5),
        Text(
          '${t['name']}',
          style: TextStyle(fontSize: 11.5, color: accent, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _traitLabel(Map<String, dynamic> t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _traitIcon(t, 16),
      const SizedBox(width: 4),
      Text(
        '${t['name']}',
        style: const TextStyle(fontSize: 12.5, color: Color(0xFFD6DCE5)),
      ),
    ],
  );

  Widget _traitIcon(Map<String, dynamic> t, double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(color: Color(0xFF1B222C), shape: BoxShape.circle),
    child: ClipOval(
      child: '${t['pic']}'.isEmpty
          ? Center(
              child: Text(
                '${t['name']}'.characters.first,
                style: const TextStyle(fontSize: 9, color: Color(0xFFB9C2CF)),
              ),
            )
          : Image.network(
              '${t['pic']}',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
    ),
  );
}
