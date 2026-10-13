import 'dart:io';

import 'package:gamebox/data/bsy_scraper.dart';
import 'package:gamebox/data/scraper.dart';

/// 宿主机上验证「其他」八个栏目的解析：跑真实页面，打印条数与首尾样例。
/// 模拟器 debug 版抓一次太慢，改 parser 后先看这里。
void main() async {
  final log = File('build/_probe_columns.log').openWrite();
  void p(String s) => log.writeln(s);
  final http = Http();

  for (final e in bsyColumnSources.entries) {
    final type = e.key;
    try {
      final bodies = await Future.wait([
        for (final url in e.value.urls) http.getDecoded(url),
      ]);
      final list = [for (final body in bodies) ...e.value.parse(body)].indexed
          .map((x) => x.$2.copyWith(sortOrder: x.$1))
          .toList();
      p('\n===== $type n=${list.length} ${e.value.urls.join(' ')}');
      for (final row in [
        ...list.take(4),
        ...list.length > 8 ? [list.last] : [],
      ]) {
        p(
          '  ${row.uid} | ${row.title} | sub=${row.subtitle} | '
          'thumb=${row.thumb.isEmpty ? '-' : 'y'} | blocks=${_blocks(row.blocks)} | '
          'src=${row.sourceUrl}',
        );
      }
      final groups = list.map((r) => r.subtitle).toSet().toList();
      p('  groups(${groups.length})=${groups.take(8).join(' / ')}');
      final noTitle = list.where((r) => r.title.isEmpty).length;
      final dupUid = list.length - list.map((r) => r.uid).toSet().length;
      if (noTitle != 0 || dupUid != 0) {
        p('  !! emptyTitle=$noTitle dupUid=$dupUid');
      }
    } catch (err) {
      p('\n===== $type FAIL $err');
    }
  }

  await log.close();
}

String _blocks(List<Map<String, dynamic>> blocks) {
  if (blocks.isEmpty) return '[]';
  return blocks
      .map((b) {
        if (b['k'] == 'kv') {
          return 'kv(${(b['rows'] as List).map((r) => r.join('=')).join(',')})';
        }
        if (b['k'] == 'text') {
          return 'text(${b['title'] ?? ''}:${_cut('${b['t']}', 24)})';
        }
        return '${b['k']}';
      })
      .join(' ');
}

String _cut(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';
