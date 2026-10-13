import 'dart:convert';

import 'scraper.dart';

class SeasonInfo {
  final String seasonId;
  final String mode;
  final String season;
  final String name;
  final String version;
  final String lineupUrl;
  const SeasonInfo(
    this.seasonId,
    this.mode,
    this.season,
    this.name,
    this.version,
    this.lineupUrl,
  );
}

SeasonInfo? parseSeasonInfo(String basicConfig) {
  final sid = RegExp(r"var id = '([^']+)'").firstMatch(basicConfig)?.group(1);
  final channel =
      RegExp(r"var channel = '([^']+)'").firstMatch(basicConfig)?.group(1) ?? '11';
  final cdn = RegExp(r"var cdn_dir = '([^']*)'").firstMatch(basicConfig)?.group(1) ?? '';
  final version = RegExp(r"var mode = '(\d+)'").firstMatch(basicConfig)?.group(1) ?? '';
  if (sid == null) return null;
  final entry = RegExp('\\{[^{}]*id: "$sid"[^{}]*\\}').firstMatch(basicConfig)?.group(0);
  if (entry == null) return null;
  final mode = RegExp(r'mode: "(\d+)"').firstMatch(entry)?.group(1) ?? '';
  final season = RegExp(r'season: "([^"]+)"').firstMatch(entry)?.group(1) ?? '';
  final name =
      RegExp(r'set_name: "([^"]+)"').firstMatch(entry)?.group(1) ??
      RegExp(r'name: "([^"]+)"').firstMatch(entry)?.group(1) ??
      season;
  final lineupRaw = RegExp("'$sid':\\s*`([^`]+)`").firstMatch(basicConfig)?.group(1);
  if (mode.isEmpty || season.isEmpty || lineupRaw == null) return null;
  final lineupUrl = lineupRaw
      .replaceAll(r'${channel}', channel)
      .replaceAll(r'${cdn_dir}', cdn);
  return SeasonInfo(sid, mode, season, name, version, lineupUrl);
}

/// basicConfig.js -> 全部模式条目（含各自的阵容列表地址）。
List<GameMode> parseModes(String basicConfig) {
  final channel =
      RegExp(r"var channel = '([^']+)'").firstMatch(basicConfig)?.group(1) ?? '11';
  final out = <GameMode>[];
  final seen = <String>{};
  for (final m in RegExp('\\{[^{}]*\\bid: "([^"]+)"[^{}]*\\}').allMatches(basicConfig)) {
    final obj = m.group(0)!;
    final id = RegExp(r'\bid: "([^"]+)"').firstMatch(obj)?.group(1) ?? '';
    final mode = RegExp(r'mode: "([^"]+)"').firstMatch(obj)?.group(1) ?? '';
    final season = RegExp(r'season: "([^"]+)"').firstMatch(obj)?.group(1) ?? '';
    if (id.isEmpty || mode.isEmpty || season.isEmpty) continue;
    final name =
        (RegExp(r'set_name: "([^"]+)"').firstMatch(obj)?.group(1) ??
                RegExp(r'name: "([^"]+)"').firstMatch(obj)?.group(1) ??
                id)
            .replaceAll(r'\n', '');
    if (name.isEmpty || !seen.add('$mode:$season')) continue;
    out.add(
      GameMode(
        id: id,
        name: name,
        mode: mode,
        season: season,
        lineupUrl: _lineupUrl(basicConfig, id, channel),
      ),
    );
  }
  return out;
}

String _lineupUrl(String basicConfig, String id, String channel) {
  final raw = RegExp("'$id'\\s*:\\s*`([^`]+)`").firstMatch(basicConfig)?.group(1) ?? '';
  return raw.replaceAll(r'${channel}', channel);
}

/// versiondataconfig.js -> 当前赛季最新版本的各数据文件相对路径（chess/equip/hex/trait/galaxy）
Map<String, String> pickVersionFiles(
  String versionDataConfig,
  String mode,
  String season,
) {
  final list = jsonDecode(versionDataConfig) as List;
  Map<String, dynamic>? best;
  String bestTime = '';
  for (final e in list.cast<Map<String, dynamic>>()) {
    if (e['mode'] != mode || e['season'] != season) continue;
    if (e['is_newest_version'] != 1) continue;
    final t = '${e['version_start_time'] ?? ''}';
    if (best == null || t.compareTo(bestTime) >= 0) {
      best = e;
      bestTime = t;
    }
  }
  if (best == null) return {};
  final out = <String, String>{};
  const map = {
    'herourl': 'chess',
    'equipurl': 'equip',
    'hexurl': 'hex',
    'traiturl': 'trait',
    'galaxyurl': 'galaxy',
    'adventureurl': 'adventure',
  };
  map.forEach((col, key) {
    final v = best![col];
    if (v is String && v.isNotEmpty) out[key] = v;
  });
  return out;
}

/// basicConfig.js 的 mechanism_tab -> 特殊机制的类别（官方注释掉的条目不算）。
List<MechCategory> parseMechanismTabs(String basicConfig) {
  final src = basicConfig.split('\n').where((l) => !l.trim().startsWith('//')).join('\n');
  final out = <MechCategory>[];
  for (final m in RegExp(
    r'\{[^{}]*hex_data:\s*\[\s*\{([^{}]*)\}\s*\]\s*\}',
  ).allMatches(src)) {
    final obj = m.group(0)!;
    final inner = m.group(1)!;
    // 官方 basicConfig.js 的键名不带引号（`mode: "11"`），这里同时兼容带引号的写法。
    String g(String key, String from) =>
        RegExp('\\b$key["\']?\\s*:\\s*"([^"]+)"').firstMatch(from)?.group(1) ?? '';
    final id = g('id', inner);
    final name = g('name', inner);
    if (id.isEmpty || name.isEmpty) continue;
    final mode = g('mode', obj);
    if (mode.isEmpty || out.any((c) => c.name == name)) continue;
    out.add(
      MechCategory(
        id: id,
        name: name,
        modeId: g('id', obj),
        mode: mode,
        season: g('season', obj),
      ),
    );
  }
  return out;
}

/// 官方机制条目：galaxy.js 用 {id,name,desc,logo}，adventure.js 用 {adventureId,title,desc,logo,price}。
/// 官网把后者标成「小精灵」，两类共用一套字段映射。
List<Map<String, dynamic>> parseMechEntries(Map<String, dynamic> data) {
  final out = <Map<String, dynamic>>[];
  for (final v in data.values) {
    if (v is! Map) continue;
    final m = v.cast<String, dynamic>();
    final name = '${m['name'] ?? m['title'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    out.add({
      'id': '${m['id'] ?? m['adventureId'] ?? ''}',
      'name': name,
      'desc': '${m['desc'] ?? ''}'.trim(),
      'pic': '${m['logo'] ?? ''}'.trim(),
      'video': '${m['video'] ?? ''}'.trim(),
      'price': '${m['price'] ?? ''}'.trim(),
    });
  }
  out.sort(
    (a, b) =>
        (int.tryParse('${a['id']}') ?? 0).compareTo(int.tryParse('${b['id']}') ?? 0),
  );
  return out;
}

class TraitGroup {
  final String checkId;
  final String name;
  final String picture;
  final String numList;
  final String prefix;
  final List<String> levels;

  /// 官方 type：0=种族，1=职业。
  final int type;

  /// 每个可达档位的 {num,color,text}，color 是官方档位配色序号，text 已去掉「(3)」前缀。
  final List<Map<String, dynamic>> tiers;
  TraitGroup(
    this.checkId,
    this.name,
    this.picture,
    this.numList,
    this.prefix,
    this.levels,
    this.type,
    this.tiers,
  );
}

Map<String, TraitGroup> groupTraits(Map<String, dynamic> data) {
  final byCheck = <String, List<Map<String, dynamic>>>{};
  for (final v in data.values) {
    if (v is! Map) continue;
    final m = v.cast<String, dynamic>();
    final cid = '${m['checkId']}';
    if (cid.isEmpty || cid == 'null') continue;
    (byCheck[cid] ??= <Map<String, dynamic>>[]).add(m);
  }
  final out = <String, TraitGroup>{};
  byCheck.forEach((cid, rows) {
    rows.sort(
      (a, b) => (int.tryParse('${a['level']}') ?? 0).compareTo(
        int.tryParse('${b['level']}') ?? 0,
      ),
    );
    final first = rows.first;
    // desc2 每行都装着全部档位，realDesc 才是单档效果。
    final levels = <String>{};
    final tiers = <Map<String, dynamic>>[];
    for (final r in rows) {
      final real = '${r['realDesc'] ?? ''}'.trim();
      final one = real.isNotEmpty
          ? real
          : '${r['desc2'] ?? r['desc'] ?? ''}'.split('|').first.trim();
      if (one.isNotEmpty) levels.add(one);
      // 档位徽标只认 realDesc：末档常留空（效果并在上档描述里），回退 desc2 会重复首档。
      if (real.isEmpty) continue;
      final text = real.replaceFirst(RegExp(r'^\(\d+\)'), '').trim();
      if (text.isEmpty) continue;
      tiers.add({
        'num': '${r['num'] ?? ''}'.trim(),
        'color': int.tryParse('${r['color']}') ?? 0,
        'text': text,
      });
    }
    out[cid] = TraitGroup(
      cid,
      '${first['name']}',
      '${first['picture'] ?? ''}',
      '${first['numList'] ?? ''}',
      '${first['prefix'] ?? ''}',
      levels.toList(),
      int.tryParse('${first['type']}') ?? 0,
      tiers,
    );
  });
  return out;
}

Map<String, dynamic>? decodeDataMap(String body) {
  final j = jsonDecode(body);
  if (j is Map && j['data'] is Map) return j['data'].cast<String, dynamic>();
  return null;
}

/// basicConfig.js 的 baseUrlManager.hero_pic_big -> {'11_S100030': '//…/{{pic_name}}.jpg'}。
Map<String, String> parseHeroPicMap(String basicConfig, [String key = 'hero_pic_big']) {
  final at = basicConfig.indexOf(key);
  if (at < 0) return const {};
  final open = basicConfig.indexOf('{', at);
  if (open < 0) return const {};
  // 模板里的 {{pic_name}} 也是成对花括号，按深度配对找块尾。
  var end = -1;
  var depth = 0;
  for (var i = open; i < basicConfig.length; i++) {
    final ch = basicConfig[i];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  if (end < 0) return const {};
  final out = <String, String>{};
  for (final m in RegExp(
    r'"([^"]+)"\s*:\s*"([^"]+)"',
  ).allMatches(basicConfig.substring(open + 1, end))) {
    out[m.group(1)!] = m.group(2)!;
  }
  return out;
}

String championBanner(
  Map<String, String> picMap,
  String mode,
  String season,
  String paint,
) {
  if (paint.isEmpty) return '';
  final tpl = picMap['${mode}_$season'] ?? '';
  if (tpl.isEmpty) return '';
  final url = tpl.replaceAll('{{pic_name}}', paint);
  return url.startsWith('//') ? 'https:$url' : url;
}

/// 羁绊 id 串 -> [{id,name,pic,type}]，type 沿用官方 0=种族 / 1=职业。
List<Map<String, dynamic>> traitRefs(String raw, Map<String, TraitGroup> traits) {
  final out = <Map<String, dynamic>>[];
  for (final id in raw.split(RegExp(r'[|,;/ ]'))) {
    final t = traits[id.trim()];
    if (t == null) continue;
    if (out.any((e) => e['id'] == t.checkId)) continue;
    out.add({'id': t.checkId, 'name': t.name, 'pic': t.picture, 'type': t.type});
  }
  return out;
}

/// 英雄名册：官方 chess 按 mapID 把同一英雄重复三条，同名只留 id 最小的一条，
/// 并按费用、名字排序。
List<Map<String, dynamic>> championRoster(Iterable<Map<String, dynamic>> rows) {
  final all = rows
      .where((m) => '${m['heroType']}' == '0' && '${m['name']}'.isNotEmpty)
      .toList();
  all.sort((a, b) {
    final c = (int.tryParse('${a['price']}') ?? 99).compareTo(
      int.tryParse('${b['price']}') ?? 99,
    );
    if (c != 0) return c;
    final n = '${a['name']}'.compareTo('${b['name']}');
    return n != 0 ? n : '${a['id']}'.compareTo('${b['id']}');
  });
  final seen = <String>{};
  return [
    for (final m in all)
      if (seen.add('${m['name']}')) m,
  ];
}

/// skillValueDesc 每段形如「护盾值：279=225+60%【护甲】 200/300/450」，
/// 尾部即一/二/三星数值；没有档位串的段落只是重复公式，直接丢弃。
List<Map<String, dynamic>> parseSkillValues(String brief, String valueDesc) {
  final descs = valueDesc
      .split('|')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final briefs = brief
      .split('|')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < descs.length; i++) {
    final d = descs[i];
    final tail = RegExp(r'\s*[0-9][\d.]*%?(?:/[0-9][\d.]*%?){2,}\s*$').firstMatch(d);
    final tiers =
        tail?.group(0)!.trim().split('/') ??
        (i < briefs.length ? briefs[i].split('/') : const <String>[]);
    if (tiers.length < 2) continue;
    final body = (tail == null ? d : d.substring(0, tail.start)).trim();
    // 标签在首个数字/括号之前，其余是这一星级的算式，用来区分同名段落。
    final cut = body.indexOf(RegExp(r'[0-9【（(]'));
    final label = (cut < 0 ? body : body.substring(0, cut))
        .replaceAll(RegExp(r'[：:\s]+$'), '')
        .trim();
    if (label.isEmpty) continue;
    out.add({
      'label': label,
      'formula': cut < 0 ? '' : body.substring(cut).trim(),
      'tiers': tiers,
    });
  }
  return out;
}

/// 官方 basicDesc 形如「 +35物理加成 +35%暴击率」，按空格拆成属性条目。
List<String> parseEquipStats(String basicDesc) =>
    basicDesc.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

/// 装备分类展示顺序，对应资料库里的分组标题。
const equipCatOrder = ['基础装备', '成型装备', '转职纹章', '神器装备', '光明武器', '辅助装备', '特殊装备'];

int equipCatRank(String cat) {
  final i = equipCatOrder.indexOf(cat);
  return i < 0 ? equipCatOrder.length : i;
}

/// lineup 的棋子条目（hero_location / levelMap 值）-> 卡片与棋盘共用的棋子描述。
/// `canonById` 把官方原始 hero_id 换成英雄名册入库的那条 id，前端据此跳详情页；查不到则留空，不给跳转。
List<Map<String, dynamic>> lineupCardHeroes(
  Object? locs,
  Map<String, dynamic> chessMap,
  Map<String, dynamic> equipMap,
  Set<String> star3,
  Map<String, String> canonById,
) {
  if (locs is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final l in locs.whereType<Map>().map((m) => m.cast<String, dynamic>())) {
    if ('${l['chess_type']}' != 'hero') continue;
    final hid = '${l['hero_id']}';
    final c = chessMap[hid];
    if (c is! Map) continue;
    final parts = '${l['location'] ?? ''}'.split(',');
    final eids = '${l['equipment_id'] ?? ''}'
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    out.add({
      'id': canonById[hid] ?? '',
      'name': '${c['name']}',
      'pic': '${c['picture'] ?? ''}',
      'cost': int.tryParse('${c['price']}') ?? 0,
      'carry': l['is_carry_hero'] == true,
      'star': star3.contains(hid) ? 3 : 0,
      'eids': eids,
      'items': [
        for (final eid in eids)
          if (equipMap[eid] is Map &&
              '${(equipMap[eid] as Map)['picture'] ?? ''}'.isNotEmpty)
            '${(equipMap[eid] as Map)['picture']}',
      ],
      'r': parts.length == 2 ? int.tryParse(parts[0].trim()) ?? 0 : 0,
      'c': parts.length == 2 ? int.tryParse(parts[1].trim()) ?? 0 : 0,
    });
  }
  return out;
}

/// 官方 lineup 的 quality 为 S/A/B 档，S 优先展示。
int _qualityRank(String q) => const {'S': 0, 'A': 1, 'B': 2, 'C': 3}[q] ?? 9;

/// 官方数据没有「速升/追三星」标签，由成型等级与三星棋子推导。
String lineupStyleTag(int level, bool chaseThree) =>
    chaseThree ? '$level级追三星' : '速升$level级';

int lineupFinalLevel(Object? levelMap) {
  if (levelMap is! Map) return 0;
  var best = 0;
  levelMap.forEach((k, v) {
    if (v is! List || v.isEmpty) return;
    final n = int.tryParse('$k') ?? 0;
    if (n > best) best = n;
  });
  return best;
}

List<Map<String, dynamic>> lineupStages(
  Object? levelMap,
  Map<String, dynamic> chessMap,
  Map<String, dynamic> equipMap,
  Set<String> star3,
  Map<String, String> canonById,
) {
  if (levelMap is! Map) return const [];
  final out = <Map<String, dynamic>>[];
  final levels =
      levelMap.keys.map((k) => int.tryParse('$k') ?? 0).where((n) => n > 0).toList()
        ..sort();
  for (final lv in levels) {
    final heroes = lineupCardHeroes(
      levelMap['$lv'],
      chessMap,
      equipMap,
      star3,
      canonById,
    );
    if (heroes.isNotEmpty) out.add({'level': lv, 'heroes': heroes});
  }
  return out;
}

/// 官方 chess 把同一英雄按 1/2/3 星与多条 mapID 重复列出，入库只留 `championRoster` 保留的那条。
/// 这里把任意原始 id 归一到那条 id，保证前端点棋子头像跳的英雄详情页一定存在（归一不到的留空，不给跳）。
Map<String, String> canonicalChampionIds(
  Iterable<Map<String, dynamic>> rows,
  List<Map<String, dynamic>> roster,
) {
  final keptByName = <String, String>{
    for (final m in roster) '${m['name']}': '${m['id']}',
  };
  final out = <String, String>{};
  for (final m in rows) {
    final name = '${m['name']}';
    if ('${m['heroType']}' != '0' || name.isEmpty) continue;
    out['${m['id']}'] = keptByName[name] ?? '';
  }
  return out;
}

List<Map<String, dynamic>> lineupTraits(
  Object? contact,
  Map<String, TraitGroup> traitMap,
) {
  if (contact is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final c in contact.whereType<Map>().map((m) => m.cast<String, dynamic>())) {
    final t = traitMap['${c['id']}'];
    if (t == null) continue;
    out.add({
      'name': t.name,
      'pic': t.picture,
      'num': '${c['num'] ?? ''}',
      'level': '${c['level'] ?? ''}',
    });
  }
  return out;
}

List<Map<String, dynamic>> lineupHexes(Object? hexbuff, Map<String, dynamic> hexMap) {
  if (hexbuff is! Map) return const [];
  final out = <Map<String, dynamic>>[];
  for (final hid in '${hexbuff['recomm'] ?? ''}'.split(',')) {
    final h = hexMap[hid.trim()];
    if (h is! Map) continue;
    out.add({
      'name': '${h['name']}',
      'pic': '${h['icon'] ?? ''}',
      'desc': '${h['desc'] ?? ''}',
      'level': '${h['level'] ?? ''}',
    });
  }
  return out;
}

/// 强化符文的档位中文读法，按下标就是官方 level（1 → 一级）。栏目页的档位筛选
/// chips 按这个顺序排，不用从条目里现攒再排序。
const jccAugmentTiers = ['一级', '二级', '三级', '四级', '五级', '六级'];

/// 官方 hex 的 level 是数字档位，界面按中文读法写进 subtitle（「tier 3」→「三级」）。
/// 传说符文（is_legend）把「传说」拼在同一维度后面，于是它在 chips 里自成一档。
String jccAugmentTier(Object? level, {bool legend = false}) {
  final n = (int.tryParse('$level') ?? 0) - 1;
  final tier = n >= 0 && n < jccAugmentTiers.length ? jccAugmentTiers[n] : '$level';
  return legend ? '$tier · 传说' : tier;
}

class JccScraper extends GameScraper {
  static const jsBase = 'https://game.gtimg.cn/images/lol/act/jkzlk/js';
  static const configUrl = 'https://jcc.qq.com/data-js/basicConfig.js';

  /// App 内提供的模式，按官方 (mode, season) 定位。
  static const wantedModes = <List<String>>[
    ['11', 'S100030'],
    ['16', 'S100024'],
    ['18', 'S19'],
    ['16', 'S19'],
    ['1', 'S1'],
  ];

  final Http http;
  List<GameMode>? _modes;
  String? _basicRaw;

  JccScraper(this.http);

  @override
  String get gameId => 'jcc';
  @override
  String get gameName => '金铲铲之战';
  @override
  Map<String, String> get typeLabels => const {
    'champion': '棋子',
    'trait': '羁绊',
    'item': '装备',
    'augment': '强化符文',
    'mech': '特殊机制',
    'lineup': '阵容',
  };
  @override
  List<String> get typeOrder => const [
    'lineup',
    'champion',
    'trait',
    'item',
    'augment',
    'mech',
  ];

  @override
  Future<void> init() async {}

  @override
  Future<List<GameMode>> loadModes() async {
    final cached = _modes;
    if (cached != null && cached.isNotEmpty) return cached;
    _basicRaw = await http.get(configUrl);
    final all = parseModes(_basicRaw!);
    final picked = <GameMode>[];
    for (final want in wantedModes) {
      for (final m in all) {
        if (m.mode == want[0] &&
            m.season == want[1] &&
            !picked.any((p) => p.id == m.id)) {
          picked.add(m);
          break;
        }
      }
    }
    if (picked.isEmpty) throw Exception('basicConfig.js 未匹配到任何模式');
    return _modes = picked;
  }

  @override
  Future<Map<String, List<ScrapedEntity>>> crawlAll({String mode = ''}) async {
    final modes = await loadModes();
    GameMode? target;
    for (final m in modes) {
      if (m.id == mode) {
        target = m;
        break;
      }
    }
    target ??= modes.first;
    final mp = target.id;

    final verRaw = await http.get('$jsBase/config/versiondataconfig.js');
    final files = pickVersionFiles(verRaw, target.mode, target.season);
    if (files.isEmpty) {
      throw Exception(
        'versiondataconfig 未找到模式 ${target.name} (mode=${target.mode} season=${target.season})',
      );
    }
    if (target.lineupUrl.isEmpty) throw Exception('模式 ${target.name} 没有阵容列表地址');

    final results = await Future.wait([
      http.get('$jsBase${files['chess']}'),
      http.get('$jsBase${files['equip']}'),
      http.get('$jsBase${files['hex']}'),
      http.get('$jsBase${files['trait']}'),
      http.get(target.lineupUrl),
    ]);
    final chessJson = jsonDecode(results[0]);
    final chessMap = chessJson['data'] is Map
        ? (chessJson['data'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final equipMap = decodeDataMap(results[1]) ?? {};
    final hexMap = decodeDataMap(results[2]) ?? {};
    final traitMap = groupTraits(decodeDataMap(results[3]) ?? {});
    final lineupJson = jsonDecode(results[4]);

    final versionTag = '${chessJson['version'] ?? ''} ${target.name}';
    final picMap = parseHeroPicMap(_basicRaw ??= await http.get(configUrl));

    final chess = championRoster(
      chessMap.values.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
    );
    final canonById = canonicalChampionIds(
      chessMap.values.whereType<Map>().map((e) => e.cast<String, dynamic>()),
      chess,
    );
    final membersByTrait = <String, List<Map<String, dynamic>>>{};
    final refsById = <String, List<Map<String, dynamic>>>{};
    for (final m in chess) {
      final refs = traitRefs('${m['species']},${m['class']}', traitMap);
      refsById['${m['id']}'] = refs;
      for (final r in refs) {
        (membersByTrait['${r['id']}'] ??= <Map<String, dynamic>>[]).add({
          'id': '${m['id']}',
          'name': '${m['name']}',
          'pic': '${m['picture'] ?? ''}',
          'cost': int.tryParse('${m['price']}') ?? 0,
        });
      }
    }
    membersByTrait.forEach((k, list) {
      list.sort((a, b) => (a['cost'] as int).compareTo(b['cost'] as int));
      if (list.length > 12) membersByTrait[k] = list.sublist(0, 12);
    });

    final traitEntities = <ScrapedEntity>[];
    var ti = 0;
    final orderedTraits = traitMap.values.toList()
      ..sort((a, b) {
        final t = a.type.compareTo(b.type);
        if (t != 0) return t;
        final n = (int.tryParse('${a.tiers.firstOrNull?['num']}') ?? 99).compareTo(
          int.tryParse('${b.tiers.firstOrNull?['num']}') ?? 99,
        );
        return n != 0 ? n : a.name.compareTo(b.name);
      });
    for (final t in orderedTraits) {
      traitEntities.add(
        ScrapedEntity(
          uid: 'jcc:$mp:trait:${t.checkId}',
          gameId: 'jcc',
          mode: mp,
          type: 'trait',
          title: t.name,
          subtitle: '(${t.numList.replaceAll('|', ') · (')})',
          thumb: t.picture,
          sourceUrl: 'https://jcc.qq.com/',
          sortOrder: ti++,
          blocks: [
            {
              'k': 'traitCard',
              'name': t.name,
              'pic': t.picture,
              'type': t.type,
              'prefix': t.prefix,
              'tiers': t.tiers,
              'members': membersByTrait[t.checkId] ?? const [],
            },
          ],
        ),
      );
    }

    final championEntities = <ScrapedEntity>[];

    var ci = 0;
    for (final m in chess) {
      final id = '${m['id']}';
      final refs = refsById[id] ?? const <Map<String, dynamic>>[];
      final cost = int.tryParse('${m['price']}') ?? 0;
      final skillDesc = '${m['skillDesc']}'.trimRight();
      final skillName = '${m['skillName']}'.trim();
      final traitText = [for (final r in refs) '${r['name']}'].join(' · ');
      championEntities.add(
        ScrapedEntity(
          uid: 'jcc:$mp:champion:$id',
          gameId: 'jcc',
          mode: mp,
          type: 'champion',
          title: '${m['name']}',
          subtitle: '$cost费${traitText.isEmpty ? '' : ' · $traitText'}',
          thumb: '${m['picture'] ?? ''}',
          sourceUrl: 'https://jcc.qq.com/',
          sortOrder: ci++,
          blocks: [
            {
              'k': 'heroCard',
              'cost': cost,
              'pic': '${m['picture'] ?? ''}',
              'banner': championBanner(
                picMap,
                target.mode,
                target.season,
                '${m['heroPaint'] ?? ''}',
              ),
              'traits': refs,
              'version': versionTag,
            },
            {
              'k': 'stats',
              'title': '英雄数据',
              // 官方 chess.js 只有 initXxx 一套数值，二/三星成长不在公开数据里。
              'note': '官方源仅提供 1 星初始属性',
              'rows': [
                ['攻击', '${m['initAttackDamage']}'],
                ['生命', '${m['initHP']}'],
                ['护甲', '${m['armor']}'],
                ['魔抗', '${m['magicResist']}'],
                ['攻速', '${m['attackSpeed']}'],
                ['射程', '${m['attackRange']}'],
                ['法力', '${m['initMP']}/${m['maxMP']}'],
                ['暴击', '${m['criticalStrikeChance']}'],
              ],
            },
            if (skillName.isNotEmpty)
              {
                'k': 'skill',
                'title': '英雄技能',
                'name': skillName,
                'pic': '${m['skillIcon'] ?? ''}',
                'mana': '${m['initMP']}/${m['maxMP']}',
                'desc': skillDesc,
                'values': parseSkillValues(
                  '${m['skillBriefValue'] ?? ''}',
                  '${m['skillValueDesc'] ?? ''}',
                ),
              },
            if (refs.isNotEmpty)
              {
                'k': 'heroTraits',
                'title': '英雄羁绊',
                'items': [
                  for (final r in refs)
                    if (traitMap['${r['id']}'] != null)
                      {
                        'name': r['name'],
                        'pic': r['pic'],
                        'type': r['type'],
                        'numList': traitMap['${r['id']}']!.numList,
                        'prefix': traitMap['${r['id']}']!.prefix,
                        'levels': traitMap['${r['id']}']!.levels,
                        'members': membersByTrait['${r['id']}'] ?? const [],
                      },
                ],
              },
          ],
        ),
      );
    }

    final itemEntities = <ScrapedEntity>[];

    final augmentEntities = <ScrapedEntity>[];
    var hi = 0;
    for (final h in hexMap.values.whereType<Map>().map(
      (m) => m.cast<String, dynamic>(),
    )) {
      final id = '${h['id']}';
      augmentEntities.add(
        ScrapedEntity(
          uid: 'jcc:$mp:augment:$id',
          gameId: 'jcc',
          mode: mp,
          type: 'augment',
          title: '${h['name']}',
          subtitle: jccAugmentTier(h['level'], legend: '${h['is_legend']}' == '1'),
          thumb: '${h['icon'] ?? ''}',
          sourceUrl: 'https://jcc.qq.com/#/hex',
          sortOrder: hi++,
          blocks: [
            {'k': 'text', 't': '${h['desc']}'},
          ],
        ),
      );
    }

    final lineupEntities = <ScrapedEntity>[];
    final li = lineupJson is Map ? (lineupJson['lineup_list'] as List? ?? []) : [];
    final rows = <Map<String, dynamic>>[];
    for (final raw in li.whereType<Map>().map((m) => m.cast<String, dynamic>())) {
      if ('${raw['status']}' != '5') continue;
      Map<String, dynamic>? detail;
      try {
        detail = jsonDecode('${raw['detail'] ?? '{}'}');
      } catch (_) {
        continue;
      }
      if (detail == null || '${detail['line_name'] ?? ''}'.isEmpty) continue;
      rows.add({'raw': raw, 'd': detail});
    }
    rows.sort((a, b) {
      final ra = a['raw'] as Map<String, dynamic>, rb = b['raw'] as Map<String, dynamic>;
      final q = _qualityRank('${ra['quality']}')
          .compareTo(_qualityRank('${rb['quality']}'));
      if (q != 0) return q;
      return (int.tryParse('${rb['sortID']}') ?? 0).compareTo(
        int.tryParse('${ra['sortID']}') ?? 0,
      );
    });
    var n = 0;
    // 装备 -> 常见携带者（按出现次数、费用排序），官方没有大数据我们用阵容反查。
    final carriersByEquip = <String, Map<String, Map<String, dynamic>>>{};
    for (final r in rows) {
      final raw = r['raw'] as Map<String, dynamic>;
      final d = r['d'] as Map<String, dynamic>;
      final star3 = '${d['level_3_heros'] ?? ''}'
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      final heroes = lineupCardHeroes(
        d['hero_location'],
        chessMap,
        equipMap,
        star3,
        canonById,
      );
      if (heroes.isEmpty) continue;
      for (final h in heroes) {
        for (final eid in (h['eids'] as List).cast<String>()) {
          final byHero = carriersByEquip.putIfAbsent(
            eid,
            () => <String, Map<String, dynamic>>{},
          );
          final hero = byHero.putIfAbsent(
            '${h['name']}',
            () => {
              'id': '${h['id']}',
              'name': '${h['name']}',
              'pic': '${h['pic']}',
              'cost': h['cost'],
              'times': 0,
            },
          );
          hero['times'] = (hero['times'] as int) + 1;
        }
      }
      final level = lineupFinalLevel(d['levelMap']);
      final tag = lineupStyleTag(level, star3.isNotEmpty);
      final quality = '${raw['quality'] ?? ''}';
      final like = int.tryParse('${raw['like']}') ?? 0;
      final difficulty = level <= 6
          ? 1
          : level <= 8
          ? 2
          : 3;

      final core = [
        for (final h in heroes)
          if (h['carry'] == true || (h['items'] as List).isNotEmpty) h,
      ];
      final traits = lineupTraits(d['contact'], traitMap);
      final hexes = lineupHexes(d['hexbuff'], hexMap);
      final stages = lineupStages(d['levelMap'], chessMap, equipMap, star3, canonById);
      final order = <String>[
        for (final eid in '${d['equipment_order'] ?? ''}'.split(','))
          if (equipMap[eid.trim()] is Map) '${(equipMap[eid.trim()] as Map)['name']}',
      ];
      final hb = d['hexbuff'];
      final replace = hb is Map
          ? '${hb['replace'] ?? ''}'
                .split(',')
                .map((s) => '${hexMap[s.trim()]?['name'] ?? ''}')
                .where((s) => s.isNotEmpty)
                .join('、')
          : '';
      // 官方 shareCode 即游戏内导入用的阵容码，仅部分阵容有。
      final shareCode = '${d['shareCode'] ?? ''}'.trim();

      lineupEntities.add(
        ScrapedEntity(
          uid: 'jcc:$mp:lineup:${raw['id']}',
          gameId: 'jcc',
          mode: mp,
          type: 'lineup',
          title: '${d['line_name']}',
          subtitle: '$quality · $tag',
          sourceUrl: 'https://jcc.qq.com/',
          sortOrder: n++,
          blocks: [
            {
              'k': 'card',
              'quality': quality,
              'tag': tag,
              'level': level,
              'difficulty': difficulty,
              'popularity': like,
              'code': shareCode,
              'heroes': heroes,
            },
            if (shareCode.isNotEmpty)
              {'k': 'lineupCode', 'title': '阵容码', 'code': shareCode},
            if (heroes.isNotEmpty)
              {
                'k': 'board',
                'title': '阵容站位',
                'cells': heroes,
                'note': '${d['location_info'] ?? ''}',
              },
            if (core.isNotEmpty) {'k': 'heroes', 'title': '核心英雄', 'items': core},
            if ('${d['equipment_info'] ?? ''}'.isNotEmpty)
              {'k': 'text', 'title': '装备分配', 't': '${d['equipment_info']}'},
            if (order.isNotEmpty) {'k': 'tags', 'title': '装备优先', 'items': order},
            if (traits.isNotEmpty) {'k': 'traits', 'title': '当前羁绊效果', 'items': traits},
            if (hexes.isNotEmpty)
              {'k': 'hexes', 'title': '强化符文推荐', 'items': hexes, 'replace': replace},
            if ('${d['hex_info'] ?? ''}'.isNotEmpty)
              {'k': 'text', 'title': '强化符文思路', 't': '${d['hex_info']}'},
            if (stages.isNotEmpty) {'k': 'stages', 'title': '分阶段阵容', 'items': stages},
            if ('${d['early_info'] ?? ''}'.isNotEmpty)
              {
                'k': 'text',
                'title': '开局（${d['early_round'] ?? ''}）',
                't': '${d['early_info']}',
              },
            if ('${d['d_time'] ?? ''}'.isNotEmpty)
              {
                'k': 'text',
                'title': '过渡与成型（${d['metaphase_round'] ?? ''}）',
                't': '${d['d_time']}',
              },
            if ('${d['enemy_info'] ?? ''}'.isNotEmpty)
              {'k': 'text', 'title': '对手分析', 't': '${d['enemy_info']}'},
            {
              'k': 'kv',
              'rows': [
                ['成型等级', '$level 级'],
                ['版本', '${raw['simulator_edition'] ?? ''}'],
                ['推荐时间', '${raw['rel_time'] ?? ''}'],
              ],
            },
          ],
        ),
      );
    }

    final items =
        equipMap.values.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
          ..sort((a, b) {
            final c = equipCatRank('${a['type']}')
                .compareTo(equipCatRank('${b['type']}'));
            if (c != 0) return c;
            return (int.tryParse('${a['id']}') ?? 0).compareTo(
              int.tryParse('${b['id']}') ?? 0,
            );
          });
    var ii = 0;
    for (final e in items) {
      final id = '${e['id']}';
      final s1 = '${e['synthesis1'] ?? '0'}';
      final s2 = '${e['synthesis2'] ?? '0'}';
      final carriers = (carriersByEquip[id]?.values.toList() ?? <Map<String, dynamic>>[])
        ..sort((a, b) {
          final t = (b['times'] as int).compareTo(a['times'] as int);
          return t != 0 ? t : (a['cost'] as int).compareTo(b['cost'] as int);
        });
      Map<String, dynamic> comp(String eid) {
        if (eid.isEmpty) return const {};
        final c = equipMap[eid];
        return c is Map
            ? {'id': eid, 'name': '${c['name']}', 'pic': '${c['picture'] ?? ''}'}
            : {'id': eid, 'name': eid, 'pic': ''};
      }

      itemEntities.add(
        ScrapedEntity(
          uid: 'jcc:$mp:item:$id',
          gameId: 'jcc',
          mode: mp,
          type: 'item',
          title: '${e['name']}',
          subtitle: '${e['type']}',
          thumb: '${e['picture'] ?? ''}',
          sourceUrl: 'https://jcc.qq.com/',
          sortOrder: ii++,
          blocks: [
            {
              'k': 'itemCard',
              'id': id,
              'name': '${e['name']}',
              'cat': '${e['type']}',
              'pic': '${e['picture'] ?? ''}',
              'stats': parseEquipStats('${e['basicDesc'] ?? ''}'),
              'desc': '${e['desc'] ?? ''}'.trim(),
              's1': comp(s1 == '0' ? '' : s1),
              's2': comp(s2 == '0' ? '' : s2),
              'carriers': carriers.take(8).toList(),
            },
          ],
        ),
      );
    }

    return {
      'champion': championEntities,
      'trait': traitEntities,
      'item': itemEntities,
      'augment': augmentEntities,
      'lineup': lineupEntities,
    }..removeWhere((_, v) => v.isEmpty);
  }

  @override
  Future<List<MechCategory>> loadMechCategories() async =>
      parseMechanismTabs(_basicRaw ??= await http.get(configUrl));

  @override
  Future<List<ScrapedEntity>> crawlMech() async {
    final cats = await loadMechCategories();
    if (cats.isEmpty) return const [];
    final verRaw = await http.get('$jsBase/config/versiondataconfig.js');
    final out = <ScrapedEntity>[];
    for (final c in cats) {
      final path = pickVersionFiles(verRaw, c.mode, c.season)[c.id] ?? '';
      if (path.isEmpty) continue;
      Map<String, dynamic> map;
      try {
        map = decodeDataMap(await http.get('$jsBase$path')) ?? {};
      } catch (_) {
        // 官方某个类别的数据文件偶发缺失：只跳过这个类别，不拖垮整次抓取。
        continue;
      }
      final entries = parseMechEntries(map);
      for (var i = 0; i < entries.length; i++) {
        final m = entries[i];
        final price = '${m['price']}';
        out.add(
          ScrapedEntity(
            uid: 'jcc:mech:${c.id}:${m['id']}',
            gameId: 'jcc',
            mode: c.modeId,
            type: 'mech',
            title: '${m['name']}',
            subtitle: price.isEmpty ? '' : '$price金币',
            thumb: '${m['pic']}',
            sourceUrl: 'https://jcc.qq.com/#/mech',
            sortOrder: i,
            blocks: [
              if ('${m['pic']}'.isNotEmpty) {'k': 'img', 'url': '${m['pic']}'},
              {'k': 'text', 't': '${m['desc']}'},
            ],
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<List<Map<String, dynamic>>>? fetchDetail(ScrapedEntity entity) => null;

  /// 五个模式各一步，特殊机制一步（它自己跨模式）——官方某些模式某类数据本就是空的，
  /// 所以按模式分步比合并成一步更容易看出到底哪块没更新上。
  @override
  Future<List<CrawlStep>> updateSteps() async {
    final modes = await loadModes();
    return [
      for (final m in modes) (label: m.name, run: () => crawlAll(mode: m.id)),
      (label: '特殊机制', run: () async => {'mech': await crawlMech()}),
    ];
  }
}
