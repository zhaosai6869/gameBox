import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

const costColors = <int, Color>{
  1: Color(0xFF9AA3B2),
  2: Color(0xFF4ED08A),
  3: Color(0xFF43A8FF),
  4: Color(0xFFB45CFF),
  5: Color(0xFFFFC53D),
  6: Color(0xFFFF6FD6),
  7: Color(0xFFFF5C5C),
};

Color costColor(int cost) => costColors[cost] ?? const Color(0xFF9AA3B2);

/// 英雄详情页条目的 uid，与 JccScraper 的 champion 命名一致。
/// id 为空表示这条棋子没有对应的入库条目（官方重复条目/宠物），此时不给跳转。
String championUid(String mode, String id) => id.isEmpty ? '' : 'jcc:$mode:champion:$id';

/// 4399 的图库（newsimg.5054399.com）没有 Referer 会直接 403，其余站点保持默认请求。
Map<String, String>? imageHeaders(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.endsWith('5054399.com') || host.endsWith('img4399.com')) {
    return const {'Referer': 'https://news.4399.com/'};
  }
  return null;
}

class RemoteThumb extends StatelessWidget {
  final String url;
  final double size;
  final String seed;
  const RemoteThumb({super.key, required this.url, required this.size, this.seed = ''});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return placeholderThumb(seed, size, Theme.of(context).colorScheme.primary);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        headers: imageHeaders(url),
        loadingBuilder: (_, child, prog) => prog == null
            ? child
            : placeholderThumb(seed, size, Theme.of(context).colorScheme.primary),
        errorBuilder: (_, _, _) =>
            placeholderThumb(seed, size, Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// 详情正文里的配图：按宽度铺满、保持原始比例（关卡攻略的截图多为横竖不一的长图）。
class ArticleImage extends StatelessWidget {
  final String url;
  const ArticleImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) => Image.network(
        url,
        width: box.maxWidth,
        fit: BoxFit.contain,
        headers: imageHeaders(url),
        loadingBuilder: (_, child, prog) => prog == null
            ? child
            : const SizedBox(
                height: 90,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              ),
        errorBuilder: (_, _, _) => const SizedBox(
          height: 46,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: Color(0xFF3A4250), size: 26),
          ),
        ),
      ),
    );
  }
}

/// 六边形徽标（评级 S/A、主C 标记）。
class HexBadge extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  const HexBadge({
    super.key,
    required this.text,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _HexPainter(color)),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.5,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color color;
  _HexPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color != color;
}

/// 阵容棋子头像：费用描边 + 装备角标 + 主C 标记 + 星级；给了 uid 时点击跳英雄详情。
class ChessAvatar extends StatelessWidget {
  final String pic;
  final String name;
  final int cost;
  final int star;
  final bool carry;
  final List<String> items;
  final double size;
  final String uid;
  const ChessAvatar({
    super.key,
    required this.size,
    this.pic = '',
    this.name = '',
    this.cost = 0,
    this.star = 0,
    this.carry = false,
    this.items = const [],
    this.uid = '',
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final avatar = SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: size * 0.3),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0xFF10151C),
                  borderRadius: BorderRadius.circular(size * 0.18),
                  border: Border.all(
                    color: costColor(cost),
                    width: (size * 0.06).clamp(1.5, 3.5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.13),
                  child: pic.isEmpty
                      ? Center(
                          child: Text(
                            name.isEmpty ? '' : name.characters.first,
                            style: TextStyle(
                              color: costColor(cost),
                              fontSize: size * 0.42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Image.network(
                          pic,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              name.isEmpty ? '' : name.characters.first,
                              style: TextStyle(
                                color: costColor(cost),
                                fontSize: size * 0.42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (items.isNotEmpty)
                Positioned(
                  top: -size * 0.28,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final u in items.take(3))
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: size * 0.015),
                          child: Container(
                            width: size * 0.3,
                            height: size * 0.3,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1B222C),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.network(
                                u,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (carry)
                Positioned(
                  right: -size * 0.08,
                  bottom: -size * 0.06,
                  child: HexBadge(text: 'C', size: size * 0.36, color: Colors.black),
                ),
            ],
          ),
          SizedBox(
            height: size * 0.26,
            child: star > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < star; i++)
                        Icon(Icons.star, size: size * 0.2, color: accent),
                    ],
                  )
                : null,
          ),
        ],
      ),
    );
    if (uid.isEmpty) return avatar;
    return InkWell(
      borderRadius: BorderRadius.circular(size * 0.18),
      onTap: () => context.push('/detail/${Uri.encodeComponent(uid)}'),
      child: avatar,
    );
  }
}

class BlocksView extends StatelessWidget {
  final List<Map<String, dynamic>> blocks;

  /// 条目所属模式（Entity.mode），用来拼英雄详情页 uid；空表示这些块里的棋子不给跳转。
  final String mode;
  const BlocksView(this.blocks, {super.key, this.mode = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final b in blocks) _block(context, b)],
    );
  }

  Widget _block(BuildContext context, Map<String, dynamic> b) {
    final accent = Theme.of(context).colorScheme.primary;
    switch (b['k']) {
      case 'card':
        return const SizedBox.shrink();
      case 'heroCard':
        return const SizedBox.shrink();
      case 'itemCard':
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ItemCardView(b, showTitle: false, mode: mode),
        );
      case 'lineupCode':
        return _LineupCodeBlock(b);
      case 'stats':
        return _StatsBlock(b);
      case 'skill':
        return _SkillBlock(b);
      case 'heroTraits':
        return _HeroTraitsBlock(b, mode: mode);
      case 'kv':
        final rows = (b['rows'] as List).cast<List>();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Table(
            columnWidths: const {0: FixedColumnWidth(88), 1: FlexColumnWidth()},
            children: [
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${r[0]}',
                        style: const TextStyle(color: Color(0xFF9AA3B2)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('${r[1]}', style: const TextStyle(color: fgColor)),
                    ),
                  ],
                ),
            ],
          ),
        );
      case 'tags':
        final items = (b['items'] as List).cast<String>();
        final title = b['title'] as String?;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title.isNotEmpty) _BlockTitle(title, accent),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in items)
                    Chip(
                      label: Text(t, style: TextStyle(color: accent, fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        );
      case 'text':
        final title = b['title'] as String?;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    title,
                    style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                  ),
                ),
              Text('${b['t']}', style: const TextStyle(color: fgColor, height: 1.6)),
            ],
          ),
        );
      case 'list':
        final items = (b['items'] as List).cast<String>();
        final title = b['title'] as String?;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title.isNotEmpty)
                Text(
                  title,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 4),
              for (final s in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(width: 6, height: 6, color: accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s,
                          style: const TextStyle(color: fgColor, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'board':
        return _BoardBlock(b, mode: mode);
      case 'heroes':
        return _Section(
          title: '${b['title']}',
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final h in (b['items'] as List).cast<Map>().map(
                (m) => m.cast<String, dynamic>(),
              ))
                ChessAvatar(
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
                  uid: championUid(mode, '${h['id']}'),
                ),
            ],
          ),
        );
      case 'traits':
        return _Section(
          title: '${b['title']}',
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final t in (b['items'] as List).cast<Map>().map(
                (m) => m.cast<String, dynamic>(),
              ))
                SizedBox(
                  width: 52,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: accent, width: 1.4),
                            ),
                            child: ClipOval(
                              child: '${t['pic']}'.isEmpty
                                  ? ColoredBox(
                                      color: cardBg,
                                      child: Center(
                                        child: Text(
                                          '${t['name']}'.characters.first,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: fgColor,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Image.network(
                                      '${t['pic']}',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                '${t['num']}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${t['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB9C2CF)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'hexes':
        final items = (b['items'] as List)
            .cast<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        final replace = '${b['replace'] ?? ''}';
        return _Section(
          title: '${b['title']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final h in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.withValues(alpha: .5)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: '${h['pic']}'.isEmpty
                              ? null
                              : Image.network(
                                  '${h['pic']}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${h['name']}',
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${h['desc']}',
                              style: const TextStyle(
                                color: Color(0xFFB9C2CF),
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (replace.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '备选：$replace',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3B2)),
                  ),
                ),
            ],
          ),
        );
      case 'stages':
        final items = (b['items'] as List)
            .cast<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        return _Section(
          title: '${b['title']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${s['level']}级',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3B2)),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final h in (s['heroes'] as List).cast<Map>().map(
                                (m) => m.cast<String, dynamic>(),
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChessAvatar(
                                    size: 40,
                                    pic: '${h['pic']}',
                                    name: '${h['name']}',
                                    cost: h['cost'] is int
                                        ? h['cost'] as int
                                        : int.tryParse('${h['cost']}') ?? 0,
                                    items: (h['items'] as List? ?? const [])
                                        .cast<String>(),
                                    uid: championUid(mode, '${h['id']}'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case 'table':
        return _TableBlock(rows: (b['rows'] as List).cast<List>(), accent: accent);
      case 'img':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ArticleImage(url: '${b['url']}'),
        );
      case 'gallery':
        final items = (b['items'] as List).cast<String>();
        final title = b['title'] as String?;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 6),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final it in items)
                      Builder(
                        builder: (_) {
                          final parts = it.split('|');
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RemoteThumb(
                                  url: parts.length > 1 ? parts[1] : '',
                                  size: 92,
                                  seed: parts[0],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 92,
                                  child: Text(
                                    parts[0],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9AA3B2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// 列宽按该列最长单元格字数给权重，太长压平、太短撑开，避免出现 1 px 列。
int _clampedFlex(int maxCellChars) =>
    maxCellChars < 2 ? 2 : (maxCellChars > 12 ? 12 : maxCellChars);

/// 4399 文章里用 `<table>` 承载的攻略数据（称号路线、推荐搭配等）。
class _TableBlock extends StatelessWidget {
  final List<List> rows;
  final Color accent;
  const _TableBlock({required this.rows, required this.accent});

  static const Color _bg = Color(0xFF171C24);
  static const Color _line = Color(0xFF242B36);

  @override
  Widget build(BuildContext context) {
    final cols = rows.fold<int>(0, (a, r) => r.length > a ? r.length : a);
    if (cols == 0) return const SizedBox.shrink();
    final flex = [
      for (var c = 0; c < cols; c++)
        _clampedFlex(
          rows
              .where((r) => r.length > c)
              .map((r) => '${r[c]}'.length)
              .fold<int>(1, (a, b) => a > b ? a : b),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, r) in rows.indexed)
              if (r.length == 1)
                Padding(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: i + 1 == rows.length ? 8 : 2,
                    left: 8,
                    right: 8,
                  ),
                  child: Text(
                    '${r[0]}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: i == 0 ? BorderSide.none : const BorderSide(color: _line),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < r.length; c++)
                        Expanded(
                          flex: flex[c],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            child: Text(
                              '${r[c]}',
                              style: const TextStyle(
                                color: fgColor,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _BlockTitle(this.text, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// 阵容站位：官方 location 为「行,列」，第 1 行是前排。
class _BoardBlock extends StatelessWidget {
  final Map<String, dynamic> b;
  final String mode;
  const _BoardBlock(this.b, {this.mode = ''});

  @override
  Widget build(BuildContext context) {
    final cells = (b['cells'] as List)
        .cast<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final note = '${b['note'] ?? ''}';
    return _Section(
      title: '${b['title']}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final size = ((box.maxWidth - 20 - 6 * 6) / 7).floorToDouble();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131922),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF232C38)),
                ),
                child: Column(
                  children: [
                    for (var r = 1; r <= 4; r++)
                      Padding(
                        padding: EdgeInsets.only(bottom: r == 4 ? 0 : 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var c = 1; c <= 7; c++)
                              Padding(
                                padding: EdgeInsets.only(right: c == 7 ? 0 : 6),
                                child: SizedBox(
                                  width: size,
                                  child:
                                      _cellAt(cells, r, c) ??
                                      Container(
                                        height: size,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A222D),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                note,
                style: const TextStyle(
                  color: Color(0xFFB9C2CF),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _cellAt(List<Map<String, dynamic>> cells, int r, int c) {
    for (final h in cells) {
      final hr = h['r'] is int ? h['r'] as int : int.tryParse('${h['r']}') ?? 0;
      final hc = h['c'] is int ? h['c'] as int : int.tryParse('${h['c']}') ?? 0;
      if (hr == r && hc == c) {
        return ChessAvatar(
          size: 34,
          pic: '${h['pic']}',
          name: '${h['name']}',
          cost: h['cost'] is int ? h['cost'] as int : int.tryParse('${h['cost']}') ?? 0,
          star: h['star'] is int ? h['star'] as int : int.tryParse('${h['star']}') ?? 0,
          carry: h['carry'] == true,
          items: (h['items'] as List? ?? const []).cast<String>(),
          uid: championUid(mode, '${h['id']}'),
        );
      }
    }
    return null;
  }
}

/// 英雄数据：官方 chess 的八项初始属性。
class _StatsBlock extends StatelessWidget {
  final Map<String, dynamic> b;
  const _StatsBlock(this.b);

  /// 图二每个属性带一枚小图标，官方只有属性名，图标按标签本地映射。
  static IconData _icon(String label) => switch (label) {
    '生命' => Icons.favorite,
    '护甲' => Icons.shield,
    '魔抗' => Icons.shield_outlined,
    '法力' => Icons.water_drop,
    '攻击' => Icons.bolt,
    '攻速' => Icons.speed,
    '射程' => Icons.straighten,
    '暴击' => Icons.auto_awesome,
    _ => Icons.edit_note,
  };

  @override
  Widget build(BuildContext context) {
    final rows = (b['rows'] as List).cast<List>();
    final note = '${b['note'] ?? ''}';
    return _Section(
      title: '${b['title']}',
      trailing: note.isEmpty
          ? null
          : Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFF68727F))),
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 8.0;
          final w = ((box.maxWidth - 3 * gap) / 4).floorToDouble();
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final r in rows)
                SizedBox(
                  width: w,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131922),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF232C38)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _icon('${r[0]}'),
                              size: 13,
                              color: const Color(0xFF7A8494),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${r[0]}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF8B95A3),
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${r[1]}',
                          style: const TextStyle(
                            color: fgColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 英雄技能：描述 + 一/二/三星数值。
class _SkillBlock extends StatelessWidget {
  final Map<String, dynamic> b;
  const _SkillBlock(this.b);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final values = (b['values'] as List? ?? const [])
        .cast<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    return _Section(
      title: '${b['title']}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131922),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF232C38)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B222C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: .55)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: '${b['pic']}'.isEmpty
                        ? null
                        : Image.network(
                            '${b['pic']}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${b['name']}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '法力 ${b['mana']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A3)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ('${b['desc']}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${b['desc']}',
                  style: const TextStyle(color: fgColor, fontSize: 13, height: 1.6),
                ),
              ),
            if (values.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '右侧数值按 ${values.first['tiers'] is List ? (values.first['tiers'] as List).length : 3} 档排列（低星 → 高星）',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF68727F)),
                ),
              ),
            for (final v in values)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${v['label']}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFB9C2CF),
                            ),
                          ),
                          if ('${v['formula']}'.isNotEmpty)
                            Text(
                              '${v['formula']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF7A8494),
                                height: 1.25,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Text(
                        '[${(v['tiers'] as List).join(' / ')}]',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: fgColor,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 英雄羁绊：羁绊图标 + 成员头像 + 各档位效果。
class _HeroTraitsBlock extends StatelessWidget {
  final Map<String, dynamic> b;
  final String mode;
  const _HeroTraitsBlock(this.b, {this.mode = ''});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final items = (b['items'] as List)
        .cast<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    return _Section(
      title: '${b['title']}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final t in items) _traitCard(context, accent, t)],
      ),
    );
  }

  Widget _traitCard(BuildContext context, Color accent, Map<String, dynamic> t) {
    final members = (t['members'] as List? ?? const [])
        .cast<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final levels = (t['levels'] as List? ?? const []).cast<String>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131922),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF232C38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 1.4),
                ),
                child: ClipOval(
                  child: '${t['pic']}'.isEmpty
                      ? ColoredBox(
                          color: cardBg,
                          child: Center(
                            child: Text(
                              '${t['name']}'.characters.first,
                              style: const TextStyle(fontSize: 13, color: fgColor),
                            ),
                          ),
                        )
                      : Image.network(
                          '${t['pic']}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                ),
              ),
              Expanded(
                child: Text(
                  '${t['name']}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                t['type'] == 1 ? '职业' : '种族',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B95A3)),
              ),
            ],
          ),
          if (members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final h in members)
                    SizedBox(
                      width: 38,
                      child: Column(
                        children: [
                          ChessAvatar(
                            size: 32,
                            pic: '${h['pic']}',
                            name: '${h['name']}',
                            cost: h['cost'] is int
                                ? h['cost'] as int
                                : int.tryParse('${h['cost']}') ?? 0,
                            uid: championUid(mode, '${h['id']}'),
                          ),
                          Text(
                            '${h['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9AA3B2),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if ('${t['numList'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n
                      in '${t['numList']}'.split('|').where((s) => s.trim().isNotEmpty))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B222C),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: accent.withValues(alpha: .35)),
                      ),
                      child: Text(
                        n.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: fgColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          for (final s in levels)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                s,
                style: const TextStyle(
                  color: Color(0xFFB9C2CF),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 官方 shareCode：阵容码，复制后可在游戏内粘贴导入。
class _LineupCodeBlock extends StatelessWidget {
  final Map<String, dynamic> b;
  const _LineupCodeBlock(this.b);

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('阵容码已复制'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final code = '${b['code']}';
    return _Section(
      title: '${b['title']}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF131922),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF232C38)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '复制后在游戏内粘贴即可导入',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF8B95A3)),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _copy(context, code),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('复制'),
              style: TextButton.styleFrom(foregroundColor: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// 装备卡：官方 itemCard 块的统一渲染，装备弹窗与详情页共用。
/// 官方数据没有「装备解读」点评和携带者大数据，常见携带改为按已抓阵容反查。
class ItemCardView extends StatelessWidget {
  final Map<String, dynamic> b;
  final bool showTitle;
  final String mode;
  const ItemCardView(this.b, {super.key, this.showTitle = true, this.mode = ''});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final name = '${b['name'] ?? ''}';
    final pic = '${b['pic'] ?? ''}';
    final stats = (b['stats'] as List? ?? const [])
        .map((s) => '$s'.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final desc = '${b['desc'] ?? ''}'.trim();
    final comps = [
      for (final m in [
        (b['s1'] as Map? ?? const {}).cast<String, dynamic>(),
        (b['s2'] as Map? ?? const {}).cast<String, dynamic>(),
      ])
        if ('${m['pic'] ?? ''}'.isNotEmpty) m,
    ];
    final carriers = (b['carriers'] as List? ?? const [])
        .map((m) => (m as Map).cast<String, dynamic>())
        .toList();
    final hasTitle = showTitle && name.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RemoteThumb(url: pic, size: 58, seed: name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTitle)
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: fgColor,
                        height: 1.25,
                      ),
                    ),
                  if (comps.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: hasTitle ? 6 : 0),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < comps.length; i++) ...[
                            if (i > 0)
                              const Text(
                                '+',
                                style: TextStyle(fontSize: 13, color: Color(0xFF8B95A3)),
                              ),
                            _component(comps[i]),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (stats.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in stats)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131922),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 11.5, color: accent)),
                  ),
              ],
            ),
          ),
        if (desc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              desc,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: Color(0xFFD6DCE5),
              ),
            ),
          ),
        if (carriers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '常见携带',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2, bottom: 6),
                  child: Text(
                    '按官方阵容中该装备的出现次数排序',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8B95A3)),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in carriers)
                        SizedBox(
                          width: 50,
                          child: Column(
                            children: [
                              ChessAvatar(
                                size: 42,
                                pic: '${c['pic'] ?? ''}',
                                name: '${c['name'] ?? ''}',
                                cost: int.tryParse('${c['cost']}') ?? 0,
                                uid: championUid(mode, '${c['id']}'),
                              ),
                              Text(
                                '${c['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFB9C2CF),
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
          ),
      ],
    );
  }

  Widget _component(Map<String, dynamic> m) {
    final label = '${m['name'] ?? ''}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RemoteThumb(url: '${m['pic']}', size: 26, seed: label),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFFB9C2CF))),
      ],
    );
  }
}

/// 栏目页顶部的一行筛选 chips：「全部」打头，后面跟各选项，横向滚动。
/// 不思议迷宫的阵营 / 称号 / 栏目分组与金铲铲的强化符文档位共用这一套样式。
Widget filterChipRow(
  String label,
  List<String> options,
  String active,
  Color accent,
  ValueChanged<String> onPick,
) {
  return SizedBox(
    height: 40,
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9AA4B2)),
          ),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 5),
            children: [
              _filterChip('全部', '', active, accent, onPick),
              for (final o in options) _filterChip(o, o, active, accent, onPick),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _filterChip(
  String text,
  String value,
  String active,
  Color accent,
  ValueChanged<String> onPick,
) {
  final on = active == value;
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12.5)),
      backgroundColor: on ? accent.withValues(alpha: 0.16) : null,
      labelStyle: TextStyle(color: on ? accent : null),
      onPressed: () => onPick(value),
    ),
  );
}
