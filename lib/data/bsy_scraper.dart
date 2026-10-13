import 'dart:convert';

import 'package:html/dom.dart' as hdom;
import 'package:html/parser.dart' as hparser;

import 'scraper.dart';

String _abs(String url, String host) {
  if (url.startsWith('//')) return 'https:$url';
  if (url.startsWith('http')) return url;
  if (url.startsWith('/')) return '$host$url';
  return url;
}

String _text(hdom.Element? el) {
  if (el == null) return '';
  final sb = StringBuffer();
  void rec(hdom.Node n) {
    if (n is hdom.Text) {
      sb.write(n.text);
      return;
    }
    if (n is hdom.Element) {
      if (n.localName == 'br') {
        sb.write('\n');
        return;
      }
      for (final c in n.nodes) {
        rec(c);
      }
    }
  }

  for (final c in el.nodes) {
    rec(c);
  }
  return sb
      .toString()
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\s*\n\s*'), '\n')
      .trim();
}

const host = 'https://gumballs.leiting.com';

/// 站点按 User-Agent 给两套模板：手机版（Http 默认）列表项是 `<a href="details.php">`，
/// 桌面版是 `<li data-id>`。称号筛选（`type=`）只在桌面版生效，手机版会忽略它返回全量。
const desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

/// 官方图鉴的两个分类维度，四组阵营与三个称号各自正好覆盖全部 399 只。
const bsyCamps = <String, String>{
  '1': '奥鲁维之刃',
  '2': '卡纳斯的启示',
  '3': '游荡者之歌',
  '4': '深渊的咆哮',
};
const bsyHonors = <String, String>{'1': '战斗系', '2': '魔法系', '3': '冒险系'};

/// 冈布奥的 subtitle 固定写成「阵营 · 称号」，列表页按这两段做分类筛选。
({String camp, String honor}) bsyGbaTags(String subtitle) {
  final parts = subtitle.split(' · ');
  return (
    camp: parts.isEmpty ? '' : parts.first,
    honor: parts.length < 2 ? '' : parts[1],
  );
}

/// 桌面版模板里的冈布奥 id 序列（`<li data-id="N">`，无链接）。
List<String> parseBsyDesktopIds(String body) {
  final doc = hparser.parse(body);
  return doc
      .querySelectorAll('li[data-id]')
      .map((li) => li.attributes['data-id'] ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}

/// 关卡攻略的来源站：4399 的不思议迷宫专区，整站 gb2312 编码、不随 UA 换模板。
const newsHost = 'https://news.4399.com';
const bsyLevelListUrl = '$newsHost/slmbsymg/guanka/';

/// 神庙试炼的汇总页：一张表格里按分区列出所有试炼条目，每行三个链接。
const bsyTempleListUrl = '$newsHost/slmbsymg/xinde/m/748970.html';

/// 关卡列表：`<li><a href="/slmbsymg/guanka/m/<id>.html"><img src alt/>关卡名</a></li>`。
/// 页头「热点」区还有指向同一文章的链接，按 id 去重只留列表里的那次。
List<ScrapedEntity> parseBsyLevelList(String body) {
  final doc = hparser.parse(body);
  final out = <ScrapedEntity>[];
  final seen = <String>{};
  for (final a in doc.querySelectorAll('li a')) {
    final href = a.attributes['href'] ?? '';
    final id = RegExp(r'/guanka/m/(\d+)\.html').firstMatch(href)?.group(1);
    if (id == null || seen.contains(id)) continue;
    final img = a.querySelector('img');
    final alt = (img?.attributes['alt'] ?? '').replaceFirst('不思议迷宫', '');
    final title = _text(a).isNotEmpty ? _text(a) : alt;
    if (title.isEmpty) continue;
    seen.add(id);
    out.add(
      ScrapedEntity(
        uid: 'bsy:level:$id',
        gameId: 'bsy',
        type: 'level',
        title: title,
        subtitle: '4399 关卡攻略',
        thumb: _abs(img?.attributes['src'] ?? '', newsHost),
        sourceUrl: _abs(href, newsHost),
        sortOrder: out.length,
      ),
    );
  }
  return out;
}

/// 神庙试炼汇总页：正文第一张表格里按分区列出所有条目，每行三个链接；
/// 表格后面还有一张「不思议迷宫攻略」的站内推荐表，不能算进来，所以只取第一张。
/// 分区标题行只有一个 `<td>`，用它给后面的条目分组（写进 subtitle）。
/// 只收名字能对上图鉴冈布奥的条目：对不上的（「雪山神庙开启方法」「天空称号加点」
/// 「试炼宝珠获得」这类）是教程和杂项而不是某个冈布奥的试炼，头像也无从取。
List<ScrapedEntity> parseBsyTempleList(
  String body, {
  required Map<String, String> gumballThumbs,
}) {
  // 冈布奥那轮没抓到时就整批不交，免得把库里已有的试炼清空。
  if (gumballThumbs.isEmpty) return const [];
  final doc = hparser.parse(body);
  final table = doc.querySelector('.w700 .content table') ?? doc.querySelector('table');
  if (table == null) return const [];
  final out = <ScrapedEntity>[];
  final seen = <String>{};
  var section = '';
  for (final tr in table.querySelectorAll('tr')) {
    // 只有一个 td 的是分区标题行；标题行里也可能挂着一个链接（如「古仪式祭品」）。
    if (tr.querySelectorAll('td').length < 2) {
      final head = _text(tr).split('\n').first.trim();
      if (head.isNotEmpty) section = head;
    }
    for (final a in tr.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      final id = RegExp(r'/m/(\d+)\.html').firstMatch(href)?.group(1);
      final title = _text(a);
      if (id == null || title.isEmpty || seen.contains(id)) continue;
      // 先占住 id，指向同一篇文章的其它写法才不会漏进来。
      seen.add(id);
      final thumb = bsyTempleThumb(title, gumballThumbs);
      if (thumb.isEmpty) continue;
      out.add(
        ScrapedEntity(
          uid: 'bsy:temple:$id',
          gameId: 'bsy',
          type: 'temple',
          title: title,
          subtitle: section,
          thumb: thumb,
          sourceUrl: _abs(href, newsHost),
          sortOrder: out.length,
        ),
      );
    }
  }
  return out;
}

/// 试炼条目对应的冈布奥头像：先去掉「(的)试炼」尾巴，再补/去「冈布奥」后缀试。
String bsyTempleThumb(String title, Map<String, String> gumballThumbs) {
  final stem = RegExp(r'^(.*?)的?试炼$').firstMatch(title)?.group(1) ?? title;
  for (final name in [stem, '$stem冈布奥']) {
    final url = gumballThumbs[name];
    if (url != null && url.isNotEmpty) return url;
  }
  return '';
}

/// 4399 文章页正文：`.coninfo` 的作者与日期 + `.content` 里图文相间的段落。
/// 关卡与神庙试炼两类条目都是 4399 文章，共用这套解析。
List<Map<String, dynamic>> parseBsyNewsDetail(String body) {
  final doc = hparser.parse(body);
  final blocks = <Map<String, dynamic>>[];
  final infos = doc
      .querySelectorAll('.coninfo span')
      .map((s) => _text(s))
      .where((s) => s.isNotEmpty)
      .toList();
  final rows = <List<String>>[
    if (infos.isNotEmpty) ['作者', infos.first],
    if (infos.length > 1) ['发布于', '20${infos[1]}'],
  ];
  if (rows.isNotEmpty) blocks.add({'k': 'kv', 'rows': rows});

  final content = doc.querySelector('.w700 .content') ?? doc.querySelector('.content');
  if (content != null) {
    appendArticleBlocks(blocks, content, newsHost);
  }
  return blocks;
}

/// 4399 文章正文里站尾那张「不思议迷宫攻略」导航表：整站同一段 HTML，单元格首格固定是
/// 栏目名。有的文章（如卡纳斯的启示 797833）前面连「▍精彩推荐」这类标记段落都没有，
/// 只能按表头文字识别。
const bsyNavTableHead = '不思议迷宫攻略';

/// 文章表格 → 逐行单元格文本（空单元格丢掉）。导航表返回 null 表示不收。
List<List<String>>? _newsTableRows(hdom.Element table) {
  final rows = <List<String>>[];
  for (final tr in table.querySelectorAll('tr')) {
    final cells = tr
        .querySelectorAll('td,th')
        .map(_text)
        .where((s) => s.isNotEmpty)
        .toList();
    if (cells.isEmpty) continue;
    if (cells.contains(bsyNavTableHead)) return null;
    rows.add(cells);
  }
  return rows.isEmpty ? null : rows;
}

/// 正文里表示「下面是站尾推荐」的小标题写法，各篇不一样，遇到任意一条就停止摊平。
const bsyArticleStopWords = ['精彩推荐', '更多精彩', '更多相关攻略和资讯', '小编推荐', 'QQ群号'];

/// 把文章容器里的段落、图片与表格按顺序摊平成 text/img/table 块；
/// 遇到 [bsyArticleStopWords] 里任一条就停（尾部是站内推荐链接与导航表）。
void appendArticleBlocks(
  List<Map<String, dynamic>> blocks,
  hdom.Element content,
  String host, {
  List<String> stopWords = bsyArticleStopWords,
}) {
  void walk(hdom.Element el) {
    for (final node in el.nodes) {
      if (node is! hdom.Element) continue;
      if (node.localName == 'img') {
        final src = node.attributes['src'] ?? node.attributes['data-src'] ?? '';
        if (src.isNotEmpty) {
          blocks.add({'k': 'img', 'url': _abs(src, host)});
        }
      } else if (node.localName == 'br') {
        // 忽略换行标签，段落文本已含内容
      } else if (node.localName == 'table') {
        final rows = _newsTableRows(node);
        if (rows != null) blocks.add({'k': 'table', 'rows': rows});
      } else if (const {
        'p',
        'div',
        'li',
        'h1',
        'h2',
        'h3',
        'span',
        'center',
      }.contains(node.localName)) {
        if (stopWords.any((w) => _text(node).contains(w))) return;
        final hasBlockChild = node.querySelectorAll('div,p,img,li,table').isNotEmpty;
        if (hasBlockChild) {
          walk(node);
        } else {
          final t = _text(node);
          if (t.isNotEmpty && !blocks.any((b) => b['t'] == t)) {
            blocks.add({'k': 'text', 't': t});
          }
        }
      }
    }
  }

  walk(content);
}

/// 「其他」各栏目的源页面。除药剂大全是列表页、天空问题是答题器工具页外，
/// 其余都是**一篇 4399/18183 文章**，条目要从正文的段落或表格里拆出来；
/// 拆出来的条目在抓取时就把正文写进 blocks，
/// 只有本身是一篇独立文章的条目（药剂、DP、部分天空副本）留给详情页懒抓。
const bsyWishUrl = '$newsHost/slmbsymg/wenda/m/622695.html';
const bsyAbyssUrl = '$newsHost/slmbsymg/xinde/m/620245.html';
const bsyPotionListUrl = '$newsHost/slmbsymg/yaoji/';
const bsyStoneUrl = 'https://m.18183.com/bsymg/201701/788039.html';
const bsyAltarUrl = '$newsHost/slmbsymg/wenda/m/708585.html';
const bsyShrineUrl = '$newsHost/slmbsymg/xinde/m/794100.html';
const bsyDpListUrl = '$newsHost/slmbsymg/xinde/m/859392.html';
const bsySkyUrl = '$newsHost/slmbsymg/xinde/m/711774.html';
const bsyQuizUrl = 'https://www.yxhhdl.com/tools/bsymg/dtq/wap/';

/// 4399 文章正文容器；关卡/神庙/栏目页共用这套模板。
hdom.Element? _newsContent(String body) {
  final doc = hparser.parse(body);
  return doc.querySelector('.w700 .content') ?? doc.querySelector('.content');
}

/// 神龙许愿：正文里「我要…：说明」逐条排布，一条愿望一个条目。
/// 相邻愿望常用「；」连在同一段里（「我要大量的矿石…；我要无上的权利…」），
/// 所以先把正文整体摊平再按分号切，段末的「（不思议迷宫xx大全）」这类链接尾巴丢掉。
List<ScrapedEntity> parseBsyWishList(String body) {
  final content = _newsContent(body);
  if (content == null) return const [];
  final out = <ScrapedEntity>[];
  final flat = _text(content).replaceAll('\n', '；');
  for (final seg in flat.split(RegExp(r'[；;]'))) {
    final m = RegExp(r'^(我要|我想|请您)([^：:]{1,12})[：:]\s*(.+)$').firstMatch(seg.trim());
    if (m == null) continue;
    final desc = m.group(3)!.trim();
    if (desc.isEmpty) continue;
    out.add(
      ScrapedEntity(
        uid: 'bsy:shenlong:${out.length}',
        gameId: 'bsy',
        type: 'shenlong',
        title: '${m.group(1)}${m.group(2)}',
        subtitle: desc,
        sourceUrl: bsyWishUrl,
        sortOrder: out.length,
        blocks: [
          {'k': 'text', 'title': '许愿效果', 't': desc},
        ],
      ),
    );
  }
  return out;
}

/// 药剂等级写在链接路径里（`/yaoji/<等级>/m/<id>.html`），页面顶部「全部」那张表
/// 会把四个等级各列一遍，所以按文章 id 去重、等级取 href。
const bsyPotionGrades = {'1': '一级', '2': '二级', '3': '三级', '4': '四级'};

List<ScrapedEntity> parseBsyPotionList(String body) {
  final doc = hparser.parse(body);
  final out = <ScrapedEntity>[];
  final seen = <String>{};
  for (final a in doc.querySelectorAll('li a')) {
    final href = a.attributes['href'] ?? '';
    final m = RegExp(r'/yaoji/(\d)/m/(\d+)\.html').firstMatch(href);
    if (m == null || seen.contains(m.group(2))) continue;
    final title = _text(a);
    if (title.isEmpty) continue;
    seen.add(m.group(2)!);
    // 靠后的条目是懒加载的，图片地址在 lz_src 里。
    final img = a.querySelector('img');
    out.add(
      ScrapedEntity(
        uid: 'bsy:yaoji:${m.group(2)}',
        gameId: 'bsy',
        type: 'yaoji',
        title: title,
        subtitle: bsyPotionGrades[m.group(1)] ?? '',
        thumb: _abs(
          (img?.attributes['src'] ??
              img?.attributes['lz_src'] ??
              img?.attributes['data-src'] ??
              ''),
          newsHost,
        ),
        sourceUrl: _abs(href, newsHost),
        sortOrder: out.length,
      ),
    );
  }
  return out;
}

/// 药剂文章正文是一张「名称 / 阶位 / 来源 / 功效」表格。
/// 名称、阶位在列表行里已经有了，正文只留其余行；表格后那行「>>>药剂大全<<<」站内链接只有一个格子，跳过。
List<Map<String, dynamic>> parseBsyPotionDetail(String body) {
  final table = _newsContent(body)?.querySelector('table');
  final rows = <List<String>>[];
  for (final tr in table?.querySelectorAll('tr') ?? const <hdom.Element>[]) {
    final cells = tr
        .querySelectorAll('td')
        .map(_text)
        .where((s) => s.isNotEmpty)
        .toList();
    if (cells.length < 2) continue;
    final label = cells[cells.length - 2];
    if (label == '名称' || label == '阶位') continue;
    rows.add([label, cells.last]);
  }
  return [
    if (rows.isNotEmpty) {'k': 'kv', 'rows': rows},
  ];
}

/// 命运石柱：正文那张三列表按「左柱冈布奥 | 右柱冈布奥 | 奖励」逐行列出（90 组）。
/// 只有一根柱的行也收（另一侧留空），整行缺奖励的丢掉。
List<ScrapedEntity> parseBsyStoneList(String body) {
  final doc = hparser.parse(body);
  final table = doc
      .querySelectorAll('table')
      .firstWhere(
        (t) => t.querySelectorAll('tr td').length > 6,
        orElse: () => hdom.Element.tag('table'),
      );
  final out = <ScrapedEntity>[];
  for (final tr in table.querySelectorAll('tr')) {
    final td = tr.querySelectorAll('td');
    if (td.length < 3) continue;
    final left = _text(td[0]);
    final right = _text(td[1]);
    final reward = _text(td[2]);
    if (reward.isEmpty || (left.isEmpty && right.isEmpty)) continue;
    out.add(
      ScrapedEntity(
        uid: 'bsy:shizhu:${out.length}',
        gameId: 'bsy',
        type: 'shizhu',
        title: [left, right].where((s) => s.isNotEmpty).join(' + '),
        subtitle: reward,
        sourceUrl: bsyStoneUrl,
        sortOrder: out.length,
        blocks: [
          {
            'k': 'kv',
            'rows': [
              if (left.isNotEmpty) ['左侧冈布奥', left],
              if (right.isNotEmpty) ['右侧冈布奥', right],
              ['石柱奖励', reward],
            ],
          },
        ],
      ),
    );
  }
  return out;
}

/// 机械祭坛：正文从「可放置的物品及奖励内容如下：」之后开始逐行「祭品：产出」，
/// 到「放不同的物品可以获得不同的奖励」结束（前面是问答，后面是站尾推荐）。
List<ScrapedEntity> parseBsyAltarList(String body) {
  final content = _newsContent(body);
  if (content == null) return const [];
  final out = <ScrapedEntity>[];
  var started = false;
  for (final line in _text(content).split('\n')) {
    final s = line.trim();
    if (!started) {
      if (s.endsWith('如下：') || s.endsWith('如下:')) started = true;
      continue;
    }
    if (s.startsWith('放不同的物品')) break;
    final m = RegExp(r'^([^：:]{2,12})[：:]\s*(.+)$').firstMatch(s);
    if (m == null) continue;
    final item = m.group(1)!.trim();
    final reward = m.group(2)!.trim();
    out.add(
      ScrapedEntity(
        uid: 'bsy:jitan:${out.length}',
        gameId: 'bsy',
        type: 'jitan',
        title: item,
        subtitle: reward,
        sourceUrl: bsyAltarUrl,
        sortOrder: out.length,
        blocks: [
          {
            'k': 'kv',
            'rows': [
              ['摆放祭品', item],
              ['祭坛产出', reward],
            ],
          },
        ],
      ),
    );
  }
  return out;
}

/// 东方神龛：正文逐行「提交X，获得Y——附加条件」。
/// 「——」后面是出该道具的条件（哪个冈布奥出战/链接）。这一栏只做列表展示、
/// 不进详情页，所以条件连带写进 subtitle，别只留在 blocks 里。
List<ScrapedEntity> parseBsyShrineList(String body) {
  final content = _newsContent(body);
  if (content == null) return const [];
  final out = <ScrapedEntity>[];
  for (final line in _text(content).split('\n')) {
    final s = line.trim();
    final m = RegExp(r'^提交(.+?)，(?:可?获得)?(.+)$').firstMatch(s);
    if (m == null) continue;
    final parts = m.group(2)!.split(RegExp(r'—+|--+'));
    final reward = parts.first.trim();
    final note = parts.length > 1 ? parts.sublist(1).join('——').trim() : '';
    if (reward.isEmpty) continue;
    out.add(
      ScrapedEntity(
        uid: 'bsy:shrine:${out.length}',
        gameId: 'bsy',
        type: 'shrine',
        title: m.group(1)!.trim(),
        subtitle: note.isEmpty ? reward : '$reward —— $note',
        sourceUrl: bsyShrineUrl,
        sortOrder: out.length,
        blocks: [
          {
            'k': 'kv',
            'rows': [
              ['提交道具', m.group(1)!.trim()],
              ['获得奖励', reward],
              if (note.isNotEmpty) ['说明', note],
            ],
          },
        ],
      ),
    );
  }
  return out;
}

/// DP 攻略汇总：正文第一张表格按「主线 / 资料片副本」分区，每行三个迷宫链接，
/// 每个迷宫是一篇独立 4399 文章（详情懒抓）。占位的「-」单元格没有链接，自然跳过。
List<ScrapedEntity> parseBsyDpList(String body) {
  final doc = hparser.parse(body);
  final table = doc.querySelector('.w700 .content table') ?? doc.querySelector('table');
  if (table == null) return const [];
  final out = <ScrapedEntity>[];
  final seen = <String>{};
  var section = '';
  for (final tr in table.querySelectorAll('tr')) {
    if (tr.querySelectorAll('td').length < 2) {
      final head = _text(tr).split('\n').first.trim();
      if (head.isNotEmpty) section = head;
    }
    for (final a in tr.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      final id = RegExp(r'/m/(\d+)\.html').firstMatch(href)?.group(1);
      final title = _text(a);
      if (id == null || title.isEmpty || !seen.add(id)) continue;
      out.add(
        ScrapedEntity(
          uid: 'bsy:dp:$id',
          gameId: 'bsy',
          type: 'dp',
          title: title,
          subtitle: section,
          sourceUrl: _abs(href, newsHost),
          sortOrder: out.length,
        ),
      );
    }
  }
  return out;
}

/// 天空副本：正文按【副本名】分节，节里第一行常是「探索等级≥N」，其余是打法。
/// 有些节只写「由于是图片攻略，请点击 查看 >>>文章<<<」，那就把 sourceUrl 指向那篇
/// 文章并留空 blocks，进详情页时懒抓正文。
List<ScrapedEntity> parseBsySkyList(String body) {
  final content = _newsContent(body);
  if (content == null) return const [];
  final out = <ScrapedEntity>[];
  final pending = <String, String>{'title': '', 'level': ''};
  final lines = <String>[];
  var article = '';

  void flush() {
    final title = pending['title']!;
    if (title.isEmpty) return;
    final level = pending['level']!;
    final blocks = <Map<String, dynamic>>[
      if (level.isNotEmpty)
        {
          'k': 'kv',
          'rows': [
            ['探索等级', level],
          ],
        },
      for (final l in lines)
        if (!l.startsWith('由于是图片攻略') && !l.startsWith('攻略较繁琐')) {'k': 'text', 't': l},
    ];
    out.add(
      ScrapedEntity(
        uid: 'bsy:sky:${out.length}',
        gameId: 'bsy',
        type: 'sky',
        title: title,
        subtitle: level.isEmpty ? '天空副本' : '探索等级≥$level',
        // 指向独立文章的条目不写 blocks，交给详情页懒抓。
        sourceUrl: article.isNotEmpty ? article : bsySkyUrl,
        sortOrder: out.length,
        blocks: article.isNotEmpty ? const [] : blocks,
      ),
    );
    lines.clear();
    article = '';
    pending['title'] = '';
    pending['level'] = '';
  }

  for (final p in content.querySelectorAll('p')) {
    final t = _text(p);
    if (t.isEmpty) continue;
    final head = RegExp(r'^【(.+?)】$').firstMatch(t);
    if (head != null) {
      flush();
      pending['title'] = head.group(1)!.trim();
      continue;
    }
    if (pending['title']!.isEmpty) continue;
    final level = RegExp(r'^探索等级\s*[≥>=]+\s*(\d+)').firstMatch(t);
    if (level != null) {
      pending['level'] = level.group(1)!;
      continue;
    }
    final href = p
        .querySelectorAll('a')
        .map((a) => a.attributes['href'] ?? '')
        .firstWhere((h) => RegExp(r'/m/\d+\.html').hasMatch(h), orElse: () => '');
    if (href.isNotEmpty) article = _abs(href, newsHost);
    lines.add(t);
  }
  flush();
  return out;
}

/// 天空问题：4399 答题器的 wap 页面把整份题库写在正文脚本里（`var list = [{"question":…,"answer":…}]`，
/// 76 条），页面上那张 `#datiList` 表格只渲染前 10 行，所以取脚本里的 JSON 而不是表格。
/// 站点是 GB2312，先过 `Http.getDecoded`；题库没有「提问者」字段，NPC 的开场白连在
/// 问题前面（「伙计！我在操作机械时…」），原样保留才能被搜到。
List<ScrapedEntity> parseBsyQuiz(String body) {
  final raw = RegExp(
    r'var list\s*=\s*(\[.*?\])\s*[;<]',
    dotAll: true,
  ).firstMatch(body)?.group(1);
  if (raw == null) return const [];
  final List<dynamic> items;
  try {
    items = jsonDecode(raw) as List<dynamic>;
  } on FormatException {
    return const [];
  }
  final out = <ScrapedEntity>[];
  for (final item in items) {
    if (item is! Map) continue;
    final question = (item['question'] ?? '').toString().trim();
    final answer = (item['answer'] ?? '').toString().trim();
    if (question.isEmpty || answer.isEmpty) continue;
    out.add(
      ScrapedEntity(
        uid: 'bsy:quiz:${out.length}',
        gameId: 'bsy',
        type: 'quiz',
        title: question,
        subtitle: answer,
        sourceUrl: bsyQuizUrl,
        sortOrder: out.length,
        blocks: [
          {
            'k': 'kv',
            'rows': [
              ['问题', question],
              ['答案', answer],
            ],
          },
        ],
      ),
    );
  }
  return out;
}

/// 「游戏攻略」栏目的十四个模块。这不是从某个列表页拆出来的目录，而是一篇篇独立
/// 4399 文章的固定清单，所以条目直接由代码生成（不联网），正文留给详情页懒抓。
const bsyGuideModules = <({String title, String url})>[
  (title: '新手指南', url: '$newsHost/slmbsymg/xinde/m/796256.html'),
  (title: '魔法系称号', url: '$newsHost/slmbsymg/xinde/m/618591.html'),
  (title: '战斗系称号', url: '$newsHost/slmbsymg/xinde/m/618552.html'),
  (title: '冒险系称号', url: '$newsHost/slmbsymg/xinde/m/618574.html'),
  (title: '游荡者之歌', url: '$newsHost/slmbsymg/xinde/m/799041.html'),
  (title: '奥鲁维之刃', url: '$newsHost/slmbsymg/xinde/m/797678.html'),
  (title: '卡纳斯的启示', url: '$newsHost/slmbsymg/xinde/m/797833.html'),
  (title: '深渊的咆哮', url: bsyAbyssUrl),
  (title: '扫荡功能', url: '$newsHost/slmbsymg/xinde/m/621848.html'),
  (title: '新手常见问题', url: '$newsHost/slmbsymg/xinde/m/809274.html'),
  (title: '冈布奥宝宝', url: '$newsHost/slmbsymg/xinde/m/761253.html'),
  (title: '冈布奥推荐', url: '$newsHost/slmbsymg/xinde/m/784722.html'),
  (title: '神龙收藏品', url: '$newsHost/slmbsymg/xinde/m/726241.html'),
  (title: '称号搭配', url: '$newsHost/slmbsymg/xinde/m/716343.html'),
];

List<ScrapedEntity> parseBsyGuideModules() => [
  for (final (i, m) in bsyGuideModules.indexed)
    ScrapedEntity(
      uid: 'bsy:guide:$i',
      gameId: 'bsy',
      type: 'guide',
      title: m.title,
      sourceUrl: m.url,
      sortOrder: i,
    ),
];

/// 3DM 手游的不思议迷宫图鉴页：飞艇图鉴按类别拆成三页（科技类 84 / 魔法类 85 /
/// 特种类 86，每页七架，第二页起是空的），天空机器人只有一页 30 台。
/// 站点是 UTF-8，但响应头不一定带 charset，仍走 getDecoded。
const bsy3dmHost = 'https://shouyou.3dmgame.com';
const bsyFeitingUrls = <String>[
  '$bsy3dmHost/zt/259_gl_fttj_84_1/',
  '$bsy3dmHost/zt/259_gl_fttj_85_1/',
  '$bsy3dmHost/zt/259_gl_fttj_86_1/',
];
const bsyRobotUrl = '$bsy3dmHost/zt/259_gl_tkjqr_1/';

/// 3DM 图鉴页 `.info` 里的一条：名字 + 缩略图（懒加载在 `data-original`）+ 那篇 /gl/ 文章。
/// 指向专区/下载的链接没有数字文章 id，会被自然过滤掉。
List<({String id, String name, String thumb, String url})> _bsy3dmItems(
  hdom.Document doc,
) {
  final out = <({String id, String name, String thumb, String url})>[];
  for (final a in doc.querySelectorAll('.info a')) {
    final href = a.attributes['href'] ?? '';
    final name = _text(a.querySelector('span'));
    final id = RegExp(r'/gl/(\d+)\.html').firstMatch(href)?.group(1);
    if (name.isEmpty || id == null) continue;
    final img = a.querySelector('img');
    out.add((
      id: id,
      name: name,
      thumb: _abs(
        img?.attributes['data-original'] ?? img?.attributes['src'] ?? '',
        bsy3dmHost,
      ),
      url: _abs(href, bsy3dmHost),
    ));
  }
  return out;
}

/// 飞艇图鉴列表页：类别 tabs 里当前页自己带 `class="on"`，所以同一个解析函数能吃三页，
/// 每条的 subtitle 就是它所属类别（栏目页拿它做筛选 chips）。条目正文不在列表页，
/// 点进去是另一篇 /gl/ 文章，交给详情页懒抓。
List<ScrapedEntity> parseBsyFeiting(String body) {
  final doc = hparser.parse(body);
  final group = _text(
    doc.querySelector('.bq_list a.on') ?? doc.querySelector('.bq_list a'),
  );
  return [
    for (final (i, it) in _bsy3dmItems(doc).indexed)
      ScrapedEntity(
        uid: 'bsy:feiting:${it.id}',
        gameId: 'bsy',
        type: 'feiting',
        title: it.name,
        subtitle: group,
        thumb: it.thumb,
        sourceUrl: it.url,
        sortOrder: i,
      ),
  ];
}

/// 天空机器人列表页：一页 30 台，没有类别维度，正文同样是各自那篇 /gl/ 文章。
List<ScrapedEntity> parseBsyRobot(String body) {
  return [
    for (final (i, it) in _bsy3dmItems(hparser.parse(body)).indexed)
      ScrapedEntity(
        uid: 'bsy:robot:${it.id}',
        gameId: 'bsy',
        type: 'robot',
        title: it.name,
        thumb: it.thumb,
        sourceUrl: it.url,
        sortOrder: i,
      ),
  ];
}

/// 3DM 文章正文（`.news_warp_center`）摊平成 text/table/img；结尾两句是站方套话
/// （「以上就是……全部内容」「本文内容来源于互联网」），不算图鉴内容，遇到就停。
const bsy3dmArticleStopWords = ['本文内容来源于互联网', '以上就是不思议迷宫'];

List<Map<String, dynamic>> parseBsy3dmDetail(String body) {
  final doc = hparser.parse(body);
  final blocks = <Map<String, dynamic>>[];
  final time = _text(doc.querySelector('.news_warp_top .time span'));
  if (time.isNotEmpty) {
    blocks.add({
      'k': 'kv',
      'rows': [
        ['发布于', time],
      ],
    });
  }
  final content = doc.querySelector('.news_warp_center');
  if (content != null) {
    appendArticleBlocks(blocks, content, bsy3dmHost, stopWords: bsy3dmArticleStopWords);
  }
  return blocks;
}

/// 深渊咆哮：正文那张表格里一格一个冈布奥（头像 + 下面那行名字）。
/// 有的格子名字带 4399 文章链接（二级数据），条目把 sourceUrl 指过去、
/// 详情页懒抓；没链接的格子只有图和名，sourceUrl 留空、列表里不可点。
List<ScrapedEntity> parseBsyAbyss(String body) {
  final table = _newsContent(body)?.querySelector('table');
  final out = <ScrapedEntity>[];
  for (final td in table?.querySelectorAll('td') ?? const <hdom.Element>[]) {
    final img = td.querySelector('img');
    final name = _text(td);
    if (img == null || name.isEmpty) continue; // 表头那格没有图
    final href = td.querySelector('a')?.attributes['href'] ?? '';
    final id = RegExp(r'/m/(\d+)\.html').firstMatch(href)?.group(1);
    out.add(
      ScrapedEntity(
        uid: 'bsy:abyss:${id ?? name}',
        gameId: 'bsy',
        type: 'abyss',
        title: name,
        thumb: _abs(img.attributes['src'] ?? '', newsHost),
        sourceUrl: id == null ? '' : _abs(href, newsHost),
        sortOrder: out.length,
      ),
    );
  }
  return out;
}

/// 「其他」各栏目对应的源页面与解析函数；不在表里的栏目继续留白。
/// `urls` 可以有多个：类别分页的栏目（飞艇图鉴）一次把几页都抓回来再合并。
const bsyColumnSources =
    <String, ({List<String> urls, List<ScrapedEntity> Function(String) parse})>{
      'feiting': (urls: bsyFeitingUrls, parse: parseBsyFeiting),
      'robot': (urls: [bsyRobotUrl], parse: parseBsyRobot),
      'abyss': (urls: [bsyAbyssUrl], parse: parseBsyAbyss),
      'shenlong': (urls: [bsyWishUrl], parse: parseBsyWishList),
      'yaoji': (urls: [bsyPotionListUrl], parse: parseBsyPotionList),
      'shizhu': (urls: [bsyStoneUrl], parse: parseBsyStoneList),
      'jitan': (urls: [bsyAltarUrl], parse: parseBsyAltarList),
      'shrine': (urls: [bsyShrineUrl], parse: parseBsyShrineList),
      'dp': (urls: [bsyDpListUrl], parse: parseBsyDpList),
      'sky': (urls: [bsySkyUrl], parse: parseBsySkyList),
      'quiz': (urls: [bsyQuizUrl], parse: parseBsyQuiz),
    };

/// 栏目页有没有可抓的源 —— 「游戏攻略」的目录写死在 `bsyGuideModules` 里，
/// 不在 `bsyColumnSources`（那张表按「页面 + 解析函数」建模），所以单独并进来。
bool bsyColumnHasSource(String type) =>
    type == 'guide' || bsyColumnSources.containsKey(type);

class BsyScraper extends GameScraper {
  final Http http;

  BsyScraper(this.http);

  @override
  String get gameId => 'bsy';
  @override
  String get gameName => '不思议迷宫';
  @override
  Map<String, String> get typeLabels => const {
    'gumball': '冈布奥图鉴',
    'strategy': '迷宫攻略',
    'level': '关卡攻略',
    'temple': '神庙试炼',
    'feiting': '飞艇图鉴',
    'robot': '天空机器人',
    'abyss': '深渊咆哮',
    'shenlong': '神龙许愿',
    'yaoji': '药剂大全',
    'shizhu': '命运石柱',
    'jitan': '机械祭坛',
    'shrine': '东方神龛',
    'dp': 'DP 攻略',
    'sky': '天空副本',
    'quiz': '天空问题',
    'guide': '游戏攻略',
  };
  @override
  List<String> get typeOrder => const ['gumball', 'level', 'temple', 'strategy'];

  @override
  Future<void> init() async {}

  /// 「其他」栏目页首次打开时按需抓自己那一类：一次只有这个栏目自己的几个页面，
  /// 几秒出结果，不把它们并进右上角 ↻ 的全量刷新。
  @override
  Future<List<ScrapedEntity>>? crawlColumn(String type) {
    // 游戏攻略的十四个模块是代码里的固定目录，不联网。
    if (type == 'guide') return Future.value(parseBsyGuideModules());
    final src = bsyColumnSources[type];
    return src == null ? null : _crawlColumn(src);
  }

  /// 一个栏目可能对应多个类别页（飞艇图鉴按科技/魔法/特种分三页），并发抓回后按页序
  /// 合并，再把 sortOrder 重排成全局序号：每页都从 0 开始的话合并顺序会乱。
  Future<List<ScrapedEntity>> _crawlColumn(
    ({List<String> urls, List<ScrapedEntity> Function(String) parse}) src,
  ) async {
    final bodies = await Future.wait([for (final url in src.urls) http.getDecoded(url)]);
    final merged = [for (final body in bodies) ...src.parse(body)];
    return [for (final (i, row) in merged.indexed) row.copyWith(sortOrder: i)];
  }

  /// 主干（图鉴/关卡/神庙/攻略）一步，「其他」十二个栏目各一步。
  /// 主干里四类共用一次 crawlAll，因为它们在同一次抓取里互相要合并（称号筛选页
  /// 的 id 要并回阵营页），拆不开。
  @override
  Future<List<CrawlStep>> updateSteps() async {
    final labels = typeLabels;
    return [
      (label: [for (final t in typeOrder) labels[t] ?? t].join(' · '), run: crawlAll),
      for (final t in [...bsyColumnSources.keys, 'guide'])
        (
          label: labels[t] ?? t,
          run: () async {
            final rows = await crawlColumn(t);
            if (rows == null) throw Exception('该栏目没有数据源');
            return {t: rows};
          },
        ),
    ];
  }

  @override
  Future<Map<String, List<ScrapedEntity>>> crawlAll({String mode = ''}) async {
    final camps = bsyCamps.entries.toList();
    final honors = bsyHonors.entries.toList();
    final strategyPages = <String>[
      '$host/strategy/',
      for (var t = 1; t <= 8; t++) '$host/strategy/?type=$t',
    ];

    final campBodies = await Future.wait(
      camps.map((e) => http.get('$host/gumballs/?group=${e.key}')),
    );
    final honorBodies = await Future.wait(
      honors.map(
        (e) => http.get(
          '$host/gumballs/?group=0&type=${e.key}',
          headers: const {'User-Agent': desktopUserAgent},
        ),
      ),
    );
    final strategyBodies = await Future.wait(strategyPages.map((u) => http.get(u)));

    final honorById = <String, String>{};
    for (var i = 0; i < honors.length; i++) {
      for (final id in parseBsyDesktopIds(honorBodies[i])) {
        honorById.putIfAbsent(id, () => honors[i].value);
      }
    }

    final gumballs = <String, ScrapedEntity>{};
    for (var i = 0; i < camps.length; i++) {
      final rows = parseBsyListPage(
        campBodies[i],
        '/gumballs/details.php?id=',
        'gumball',
      );
      for (var k = 0; k < rows.length; k++) {
        final r = rows[k];
        final id = r.uid.split(':').last;
        final honor = honorById[id] ?? '';
        gumballs.putIfAbsent(
          r.uid,
          () => ScrapedEntity(
            uid: r.uid,
            gameId: 'bsy',
            type: 'gumball',
            title: r.title,
            subtitle: honor.isEmpty ? camps[i].value : '${camps[i].value} · $honor',
            thumb: r.thumb,
            sourceUrl: r.sourceUrl,
            sortOrder: i * 1000 + k,
          ),
        );
      }
    }

    final strategies = <String, ScrapedEntity>{};
    for (var i = 0; i < strategyPages.length; i++) {
      for (final e in parseBsyListPage(
        strategyBodies[i],
        '/strategy/details.php?id=',
        'strategy',
      )) {
        strategies.putIfAbsent(e.uid, () => e);
      }
    }

    final gList = gumballs.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final sList = strategies.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // 关卡攻略与神庙试炼来自 4399 专区（GBK 站，响应头不带 charset，必须按 meta 解码）。
    // 抓失败只让对应格子空着，不要把冈布奥和攻略的刷新一起拖垮。
    final levels = await _crawlLevels();
    final temples = await _crawlTemples({
      for (final g in gList)
        if (g.thumb.isNotEmpty) g.title: g.thumb,
    });

    return {'gumball': gList, 'strategy': sList, 'level': levels, 'temple': temples}
      ..removeWhere((_, v) => v.isEmpty);
  }

  Future<List<ScrapedEntity>> _crawlLevels() async {
    try {
      return parseBsyLevelList(await http.getDecoded(bsyLevelListUrl));
    } catch (_) {
      return const [];
    }
  }

  Future<List<ScrapedEntity>> _crawlTemples(Map<String, String> gumballThumbs) async {
    try {
      return parseBsyTempleList(
        await http.getDecoded(bsyTempleListUrl),
        gumballThumbs: gumballThumbs,
      );
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>>? fetchDetail(ScrapedEntity entity) async {
    // 关卡、神庙试炼、DP 汇总、天空副本、深渊咆哮的二级页与「游戏攻略」的十四个模块
    // 都是 4399 文章。
    if (const {'level', 'temple', 'dp', 'sky', 'abyss', 'guide'}.contains(entity.type)) {
      // 4399 是 GBK 站，走按 meta 解码的那条路。
      return parseBsyNewsDetail(await http.getDecoded(entity.sourceUrl));
    }
    // 药剂文章是固定表格，正文摊平成图文会丢字段，单独解析。
    if (entity.type == 'yaoji') {
      return parseBsyPotionDetail(await http.getDecoded(entity.sourceUrl));
    }
    // 飞艇图鉴与天空机器人的正文在 3DM 文章里（.news_warp_center），和 4399 模板不同名。
    if (const {'feiting', 'robot'}.contains(entity.type)) {
      return parseBsy3dmDetail(await http.getDecoded(entity.sourceUrl));
    }
    final body = await http.get(entity.sourceUrl);
    final doc = hparser.parse(body);
    final blocks = <Map<String, dynamic>>[];
    if (entity.type == 'gumball') {
      final skins = <String>[];
      for (final slide in doc.querySelectorAll('.swiper-container-six .swiper-slide')) {
        final img = slide.querySelector('img');
        if (img == null) continue;
        skins.add(
          '${_text(slide.querySelector('p'))}|${_abs(img.attributes['src'] ?? '', host)}',
        );
      }
      if (skins.isNotEmpty) {
        blocks.add({'k': 'gallery', 'title': '装束', 'items': skins});
      }

      final short = <List<String>>[];
      final long = <Map<String, String>>[];
      for (final sec in doc.querySelectorAll('.gba_details_classify .classify_details')) {
        final label = _text(sec.querySelector('h3'));
        if (label.isEmpty) continue;
        final lines = sec
            .querySelectorAll('.classify_frame p')
            .map((p) => _text(p))
            .where((s) => s.isNotEmpty)
            .toList();
        if (lines.isEmpty) continue;
        if (label == '阵营' || label == '称号') {
          short.add([label, lines.join('；')]);
        } else {
          long.add({'title': label, 't': lines.join('\n')});
        }
      }
      if (short.isNotEmpty) blocks.insert(0, {'k': 'kv', 'rows': short});
      blocks.addAll(long.map((e) => {'k': 'text', 'title': e['title'], 't': e['t']}));
    } else {
      final time = _text(doc.querySelector('.headlines_time'));
      final author = _text(doc.querySelector('.headlines_author'));
      if (time.isNotEmpty || author.isNotEmpty) {
        blocks.add({
          'k': 'kv',
          'rows': [
            if (author.isNotEmpty) ['作者', author],
            if (time.isNotEmpty) ['发布于', time],
          ],
        });
      }
      final content = doc.querySelector('.inpage_content');
      if (content != null) appendArticleBlocks(blocks, content, host);
    }
    return blocks;
  }
}

List<ScrapedEntity> parseBsyListPage(String body, String linkPart, String type) {
  final doc = hparser.parse(body);
  final out = <ScrapedEntity>[];
  var idx = 0;
  for (final a in doc.querySelectorAll('a')) {
    final href = a.attributes['href'] ?? '';
    if (!href.contains(linkPart)) continue;
    final id = RegExp(r'id=(\d+)').firstMatch(href)?.group(1);
    if (id == null) continue;
    final img = a.querySelector('img');
    final title = _text(a.querySelector('span')).isNotEmpty
        ? _text(a.querySelector('span'))
        : (img?.attributes['alt'] ?? '');
    if (title.isEmpty) continue;
    out.add(
      ScrapedEntity(
        uid: 'bsy:$type:$id',
        gameId: 'bsy',
        type: type,
        title: title,
        subtitle: type == 'gumball' ? '官网图鉴' : '官方攻略',
        thumb: _abs(img?.attributes['src'] ?? '', host),
        sourceUrl: '$host$linkPart$id',
        sortOrder: idx++,
      ),
    );
  }
  return out;
}
