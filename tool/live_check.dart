import '../lib/data/bsy_scraper.dart';
import '../lib/data/jcc_scraper.dart';
import '../lib/data/scraper.dart';

Future<void> main() async {
  final http = Http();
  for (final s in [JccScraper(http), BsyScraper(http)]) {
    try {
      final map = await s.crawlAll();
      final summary = map.entries.map((e) => '${e.key}=${e.value.length}').join(' ');
      print('${s.gameId}: OK $summary');
      for (final e in map.entries) {
        final first = e.value.isEmpty ? null : e.value.first;
        print(
          '  ${e.key} first: ${first?.title} | ${first?.subtitle} | ${first?.thumb} | blocks=${first?.blocks.length}',
        );
      }
    } catch (err) {
      print('${s.gameId}: FAIL $err');
    }
  }
  // bsy 详情抽查
  final bsy = BsyScraper(http);
  final list = await bsy.crawlAll();
  for (final t in ['gumball', 'strategy']) {
    final e = list[t]!.first;
    final blocks = await bsy.fetchDetail(e);
    print(
      'bsy:$t detail ${e.title}: blocks=${blocks?.length} kinds=${blocks?.map((b) => b['k']).toSet()}',
    );
  }
}
