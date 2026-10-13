import 'dart:io';

import 'package:gamebox/data/bsy_scraper.dart';
import 'package:gamebox/data/scraper.dart';

void main() async {
  final log = File('build/_probe_temple.log').openWrite();
  final map = await BsyScraper(Http()).crawlAll();
  final temples = map['temple'] ?? const <ScrapedEntity>[];
  final withThumb = temples.where((e) => e.thumb.isNotEmpty).toList();
  log.writeln(
    'types=${map.keys.toList()} temple=${temples.length} thumb=${withThumb.length}',
  );
  for (final e in temples.take(12)) {
    log.writeln('  ${e.sortOrder} ${e.title} | sub=${e.subtitle} | thumb=${e.thumb}');
  }
  log.writeln('--- 没有头像的条目 ---');
  for (final e in temples.where((e) => e.thumb.isEmpty)) {
    log.writeln('  ${e.title} | ${e.subtitle}');
  }
  await log.close();
}
