import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/scraper.dart';
import '../state/app_update.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import 'app_update.dart';

/// 设置页：游戏排序（第一个即启动默认）+ 每个游戏单独的自动刷新开关。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final scrapers = ref.watch(scrapersProvider);
    final upd = ref.watch(appUpdateProvider);
    final order = settings.orderBy(scrapers.keys);
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Title('游戏排序', '排在第一个的游戏是启动时进入的那个'),
          _Card(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.length,
              onReorderItem: (oldIndex, newIndex) async {
                final ids = [...order];
                ids.insert(newIndex, ids.removeAt(oldIndex));
                await ref.read(settingsProvider.notifier).setGameOrder(ids);
                // 排序即默认：第一个换了就跟着切过去，免得改完看不出效果。
                if (ids.first != ref.read(filterProvider).game) {
                  ref.read(filterProvider.notifier).setGame(ids.first);
                }
              },
              itemBuilder: (_, i) => ListTile(
                key: ValueKey(order[i]),
                leading: _Badge(gameId: order[i], scrapers: scrapers),
                title: Text(scrapers[order[i]]!.gameName),
                subtitle: i == 0 ? Text('默认启动', style: TextStyle(color: accent)) : null,
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle, color: Color(0xFF68727F)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Title('自动刷新', '打开时：进入该游戏或栏目页，发现没有数据会自动抓一次'),
          _Card(
            child: Column(
              children: [
                for (final (i, id) in order.indexed)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      6,
                      12,
                      i + 1 == order.length ? 6 : 0,
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.autoRefreshOf(id),
                      activeThumbColor: accent,
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setAutoRefresh(id, v),
                      title: Text(scrapers[id]!.gameName),
                      subtitle: const Text('关闭后只能在页面右上角手动点 ↻ 抓取'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _Title('关于', '在线更新：读版本清单 → 下载 APK → 校验 sha256 → 交给系统安装器'),
          _Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
              title: const Text('检查更新'),
              subtitle: Text(
                (upd.notice?.isNotEmpty ?? false)
                    ? upd.notice!
                    : '当前版本 ${upd.versionLabel}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3B2)),
              ),
              trailing: upd.checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, color: Color(0xFF68727F)),
              enabled: !upd.checking,
              onTap: () async {
                // 和抽屉那行同样规矩：先抓住根 Navigator，await 之后这一行可能已经没了。
                final nav = Navigator.of(context, rootNavigator: true);
                final newer = await ref.read(appUpdateProvider.notifier).check();
                if (!newer || !nav.mounted) return;
                final force = ref.read(appUpdateProvider).remote?.force ?? false;
                await showAppUpdateDialog(nav, force: force);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final String note;
  const _Title(this.text, this.note);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent),
          ),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3B2))),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF232A35)),
    ),
    child: child,
  );
}

/// 与选择游戏抽屉同款的首字方块徽标。
class _Badge extends StatelessWidget {
  final String gameId;
  final Map<String, GameScraper> scrapers;
  const _Badge({required this.gameId, required this.scrapers});

  @override
  Widget build(BuildContext context) {
    final accent = gameAccent[gameId] ?? fgColor;
    final name = scrapers[gameId]!.gameName;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: Text(
          name.characters.first,
          style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
