import 'dart:io';

import 'package:gamebox/data/bsy_scraper.dart';
import 'package:gamebox/data/scraper.dart';

/// 宿主机上验证 3DM 那两个图鉴栏目（飞艇图鉴 / 天空机器人）：列表页合并结果 +
/// 逐篇抓 /gl/ 正文看摊平效果。
void main() async {
  final log = File('build/_probe_3dm.log').openWrite();
  void p(String s) => log.writeln(s);
  final http = Http();

  for (final type in ['feiting', 'robot']) {
    final src = bsyColumnSources[type]!;
    final bodies = await Future.wait([for (final url in src.urls) http.getDecoded(url)]);
    final list = [for (final body in bodies) ...src.parse(body)].indexed
        .map((x) => x.$2.copyWith(sortOrder: x.$1))
        .toList();
    p(
      '\n##### $type n=${list.length} groups=${list.map((e) => e.subtitle).toSet()} '
      '${src.urls.join(' ')}',
    );
    for (final row in list) {
      p('  ${row.sortOrder} ${row.uid} | ${row.title} | ${row.subtitle} | ${row.thumb}');
    }
    for (final row in list) {
      try {
        final blocks = parseBsy3dmDetail(await http.getDecoded(row.sourceUrl));
        p('\n----- ${row.title} ${row.sourceUrl} blocks=${blocks.length}');
        for (final b in blocks) {
          if (b['k'] == 'table') {
            for (final r in (b['rows'] as List)) {
              p('  row ${(r as List).map((c) => _cut('$c', 40)).join(' | ')}');
            }
          } else if (b['k'] == 'text') {
            p('  text ${_cut('${b['t']}', 90)}');
          } else {
            p('  ${b['k']} ${b['rows'] ?? b['url']}');
          }
        }
      } catch (e) {
        p('\n----- ${row.title} FAIL $e');
      }
    }
  }
  await log.close();
}

String _cut(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';
