import 'dart:io';

import 'package:gamebox/data/bsy_scraper.dart';
import 'package:gamebox/data/scraper.dart';

void main(List<String> args) async {
  final log = File('build/_probe.log').openWrite();
  void p(String s) => log.writeln(s);
  final http = Http();
  final scraper = BsyScraper(http);

  final listBody = await http.getDecoded(bsyLevelListUrl);
  p('list chars=${listBody.length}');
  final levels = parseBsyLevelList(listBody);
  p('levels=${levels.length}');
  for (final e in levels.take(6)) {
    p(
      '  ${e.sortOrder} ${e.uid} | ${e.title} | sub=${e.subtitle} | thumb=${e.thumb} | ${e.sourceUrl}',
    );
  }
  final titles = levels.map((e) => e.title).toSet();
  p('distinct titles=${titles.length}');

  for (final id in args.isEmpty ? <String>['929112', '711774'] : args) {
    final e = levels.firstWhere(
      (x) => x.uid.endsWith(':$id'),
      orElse: () => ScrapedEntity(
        uid: 'bsy:level:$id',
        gameId: 'bsy',
        type: 'level',
        title: '手工传入',
        sourceUrl: 'https://news.4399.com/slmbsymg/guanka/m/$id.html',
      ),
    );
    final blocks = await scraper.fetchDetail(e);
    p('detail $id blocks=${blocks?.length}');
    for (final b in blocks ?? const <Map<String, dynamic>>[]) {
      final t = '${b['t'] ?? b['url'] ?? b['rows'] ?? ''}';
      p('  ${b['k']} | ${t.length > 80 ? '${t.substring(0, 80)}…' : t}');
    }
  }

  await log.close();
}
