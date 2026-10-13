import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/scraper.dart';
import '../state/providers.dart';
import '../state/settings.dart';

/// 抽屉里点「设置」时带出的返回值，由本函数负责在抽屉关闭后再跳转。
const _openSettings = 'settings';

/// 仿 uView u-popup mode="left"：从左侧滑出的游戏切换弹出层。
Future<void> showGamePopup(BuildContext context, WidgetRef ref) async {
  final scrapers = ref.read(scrapersProvider);
  final order = ref.read(settingsProvider).orderBy(scrapers.keys);
  final games = [for (final id in order) scrapers[id]!];
  final current = ref.read(filterProvider).game;
  final result = await showGeneralDialog<Object?>(
    context: context,
    barrierLabel: 'game-switch',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => _GamePanel(games: games, current: current),
    transitionBuilder: (_, anim, _, child) {
      final v = Curves.easeOutCubic.transform(anim.value);
      return FractionalTranslation(translation: Offset(v - 1, 0), child: child);
    },
  );
  if (result == _openSettings && context.mounted) context.push('/settings');
}

/// AppBar 上的「游戏名 ▾」按钮，点击弹出左侧切换层。
class GameTitleButton extends ConsumerWidget {
  final String gameName;
  const GameTitleButton({super.key, required this.gameName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => showGamePopup(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(gameName),
            Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _GamePanel extends StatelessWidget {
  final List<GameScraper> games;
  final String current;
  const _GamePanel({required this.games, required this.current});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.72;
    final accent = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: cardBg,
        child: Container(
          width: width,
          height: double.infinity,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    '选择游戏',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final s in games)
                        _GameItem(
                          gameId: s.gameId,
                          gameName: s.gameName,
                          selected: s.gameId == current,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                InkWell(
                  onTap: () => Navigator.of(context).pop(_openSettings),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20, color: accent),
                        const SizedBox(width: 12),
                        const Text('设置', style: TextStyle(fontSize: 15, color: fgColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameItem extends ConsumerWidget {
  final String gameId;
  final String gameName;
  final bool selected;
  const _GameItem({required this.gameId, required this.gameName, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = gameAccent[gameId] ?? fgColor;
    final progress = ref.watch(updateProvider);
    final mine = progress.gameId == gameId;
    return InkWell(
      onTap: () {
        if (!selected) ref.read(filterProvider.notifier).setGame(gameId);
        Navigator.of(context).pop();
      },
      child: Container(
        color: selected ? accent.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      gameName.characters.first,
                      style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    gameName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? accent : fgColor,
                    ),
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: accent, size: 20),
                _UpdateButton(
                  gameId: gameId,
                  gameName: gameName,
                  accent: accent,
                  busy: progress.running,
                  mine: mine,
                ),
              ],
            ),
            if (mine) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.total == 0 ? null : progress.done / progress.total,
                  minHeight: 5,
                  backgroundColor: _line,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.done}/${progress.total} ${progress.current}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: _muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _muted = Color(0xFF9AA3B2);
const _line = Color(0xFF232A35);
const _fail = Color(0xFFFF6B6B);
const _warn = Color(0xFFE8B84B);

/// 抽屉行右侧的「更新」按钮：跑完弹逐条结果。
class _UpdateButton extends ConsumerWidget {
  final String gameId;
  final String gameName;
  final Color accent;

  /// 有任务在跑（不一定是本游戏）时禁点，避免两次抓取互相覆盖。
  final bool busy;
  final bool mine;
  const _UpdateButton({
    required this.gameId,
    required this.gameName,
    required this.accent,
    required this.busy,
    required this.mine,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = !busy;
    return Tooltip(
      message: mine ? '正在更新…' : '更新该游戏全部已接入数据',
      child: IconButton(
        onPressed: enabled
            ? () async {
                // 先拿到根 Navigator 再 await：抽屉可能在中途被用户关掉，
                // 那时这一行的 context 已经没了，回执会悄悄丢失。
                final nav = Navigator.of(context, rootNavigator: true);
                if (!await confirmFullUpdate(context, gameName, accent)) return;
                final results = await ref.read(updateProvider.notifier).run(gameId);
                await showUpdateResult(
                  nav,
                  gameName: gameName,
                  accent: accent,
                  results: results,
                );
              }
            : null,
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        color: accent,
        icon: Icon(mine ? Icons.hourglass_top : Icons.sync),
      ),
    );
  }
}

/// 全量更新会覆盖该游戏所有栏目的旧数据、期间锁住其他刷新，所以点一下先确认。
/// 返回 false（含点空白处取消）就不开跑。
Future<bool> confirmFullUpdate(
  BuildContext context,
  String gameName,
  Color accent,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _line),
          ),
          title: Text(
            '更新 $gameName 全部数据？',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
          content: const Text(
            '会重新抓取该游戏所有已接入栏目并覆盖库里的旧数据，跑完前不能再次触发更新。',
            style: TextStyle(fontSize: 13, height: 1.5, color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消', style: TextStyle(fontSize: 14, color: _muted)),
            ),
            // 确认框挂在当前页的主题下，主色是「正在看的那个游戏」的色；这里按
            // 被更新游戏的主题色走，免得给不思议迷宫弹了个金铲铲的金色按钮。
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                '开始更新',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
        ),
      ) ??
      false;
}

/// 更新结束后逐条汇报：成功多少条、哪些失败、失败原因。
///
/// 用有界宽度的 Dialog 而不是 AlertDialog：AlertDialog 的内容被 IntrinsicWidth
/// 量尺寸，行里的 Expanded 只贡献 0 宽，失败原因一长串就把栏目名挤成竖排、
/// 整块内容顶出屏幕（widget test 复现过）。
Future<void> showUpdateResult(
  NavigatorState nav, {
  required String gameName,
  required Color accent,
  required List<StepResult> results,
}) {
  final failed = results.where((r) => !r.ok).toList();
  final empty = results.where((r) => r.empty).toList();
  final total = results.fold<int>(0, (a, r) => a + r.count);
  final title = failed.isEmpty ? '$gameName 更新完成' : '$gameName 有 ${failed.length} 项失败';
  final subtitle = failed.isEmpty
      ? '${results.length} 步全部成功，共写入 $total 条'
      : '${results.length - failed.length}/${results.length} 步成功，共写入 $total 条'
            '${empty.isEmpty ? '' : '，${empty.length} 步没抓到内容'}';
  return nav.push<void>(
    RawDialogRoute<void>(
      barrierLabel: '更新结果',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      pageBuilder: (ctx, _, _) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 46),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: failed.isEmpty ? fgColor : _fail,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: _muted)),
              const SizedBox(height: 6),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 4),
                  children: [for (final r in results) _StepLine(r: r, accent: accent)],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('知道了', style: TextStyle(color: accent)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 一步一行：栏目名和条数并排，失败原因或「没抓到」单独一行，免得窄屏挤字。
class _StepLine extends StatelessWidget {
  final StepResult r;
  final Color accent;
  const _StepLine({required this.r, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                !r.ok
                    ? Icons.cancel
                    : r.empty
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 16,
                color: !r.ok
                    ? _fail
                    : r.empty
                    ? _warn
                    : accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.label,
                  style: TextStyle(fontSize: 13, color: r.ok ? fgColor : _fail),
                ),
              ),
              if (r.ok && !r.empty)
                Text('${r.count} 条', style: const TextStyle(fontSize: 12, color: _muted)),
            ],
          ),
          if (!r.ok || r.empty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                r.detail,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: r.ok ? _warn : _fail,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
