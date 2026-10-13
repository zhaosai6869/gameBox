import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/app_update.dart';
import '../state/app_update.dart';

const _line = Color(0xFF232A35);

/// 更新对话框：既是启动自动检查的弹窗，也是设置页手动检查后的同一个框。
/// 内部 watch 状态，所以下载进度会自己刷新。`force` 时不给关闭入口。
Future<void> showAppUpdateDialog(NavigatorState nav, {required bool force}) {
  return showDialog(
    context: nav.context,
    barrierDismissible: false,
    builder: (_) => _AppUpdateDialog(force: force),
  );
}

class _AppUpdateDialog extends ConsumerWidget {
  final bool force;
  const _AppUpdateDialog({required this.force});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appUpdateProvider);
    final info = st.remote;
    if (info == null) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final canClose = !force && !st.downloading;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _line),
      ),
      title: Text(
        '发现新版本 ${info.versionName}',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: accent),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前 ${st.versionLabel} · 新版 ${formatBytes(info.size.toDouble())}'
                      '${info.sha256.isEmpty ? '' : ' · 校验 sha256'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3B2)),
                    ),
                    if (info.changelog.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        info.changelog,
                        style: const TextStyle(fontSize: 13, color: fgColor, height: 1.5),
                      ),
                    ],
                    if (st.downloading) ...[
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: st.progress != null && st.progress! >= 0
                            ? st.progress
                            : null,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        st.progress != null && st.progress! >= 0
                            ? '${(st.progress! * 100).toStringAsFixed(0)}%'
                                  '  ·  ${st.downloadedBytes ?? ''}'
                            : '已下载 ${st.downloadedBytes ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3B2)),
                      ),
                    ],
                    if (st.error != null || st.notice != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        st.error ?? st.notice!,
                        style: TextStyle(
                          fontSize: 12,
                          color: st.error == null
                              ? const Color(0xFF9AA3B2)
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (canClose)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说', style: TextStyle(color: Color(0xFF9AA3B2))),
          ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: accent),
          // 已经下好并校验过的包直接再拉一次安装器，别重下 90MB。
          onPressed: st.downloading
              ? null
              : () => st.readyToInstall
                    ? ref.read(appUpdateProvider.notifier).retryInstall()
                    : ref.read(appUpdateProvider.notifier).downloadAndInstall(),
          child: Text(
            st.readyToInstall
                ? '继续安装'
                : st.downloading
                ? '下载中…'
                : '下载并安装',
          ),
        ),
      ],
    );
  }
}
