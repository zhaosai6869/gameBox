import 'dart:io';

import 'package:gamebox/data/bsy_scraper.dart';
import 'package:gamebox/data/scraper.dart';

/// 宿主机上验证深渊咆哮：列表页拆出的格子（有链接的进二级页）+ 逐条抓二级文章看详情页效果。
void main() async {
  final log = File('build/_probe_abyss.log').openWrite();
  void p(String s) => log.writeln(s);
  final scraper = BsyScraper(Http());

  final list = await scraper.crawlColumn('abyss');
  if (list == null) return;
  p('##### abyss n=${list.length} 无链接=${list.where((e) => e.sourceUrl.isEmpty).length}');
  for (final row in list) {
    p('  ${row.sortOrder} ${row.uid} | ${row.title} | ${row.thumb} | ${row.sourceUrl}');
  }
  for (final row in list.where((e) => e.sourceUrl.isNotEmpty)) {
    try {
      final blocks = await scraper.fetchDetail(row);
      p('\n----- ${row.title} ${row.sourceUrl} blocks=${blocks?.length}');
      for (final b in blocks ?? const <Map<String, dynamic>>[]) {
        if (b['k'] == 'table') {
          for (final r in (b['rows'] as List)) {
            p('  row ${(r as List).map((c) => _cut('$c', 46)).join(' | ')}');
          }
        } else if (b['k'] == 'text') {
          p('  text ${_cut('${b['t']}', 110)}');
        } else {
          p('  ${b['k']} ${b['rows'] ?? b['url']}');
        }
      }
    } catch (e) {
      p('\n----- ${row.title} FAIL $e');
    }
  }
  await log.close();
}

String _cut(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';
