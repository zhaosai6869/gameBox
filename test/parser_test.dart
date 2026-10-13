import 'package:flutter_test/flutter_test.dart';
import 'package:gamebox/data/bsy_scraper.dart';
import 'package:gamebox/data/jcc_scraper.dart';

void main() {
  test('jcc parseSeasonInfo 解析当前赛季与 lineup 地址', () {
    const cfg = '''
var isTest = false;
var mode = '18'
var season = 'S19'
var id = 'Mode11_S100030'
var channel = '11';
var cdn_dir = '';
      'Mode11_S100030':`https://game.gtimg.cn/images/lol/act/jkzlkauto/json/lineupJson/m100030/11/\${channel}/lineup_detail_total.json`,
      {set_id: "Mode11", mode: "11", season: "S100030", id: "Mode11_S100030", name: "奇遇", set_name: "画之灵", is_show:['mech','lineup','hero','hex','synergy']},
''';
    final info = parseSeasonInfo(cfg)!;
    expect(info.mode, '11');
    expect(info.season, 'S100030');
    expect(info.name, '画之灵');
    expect(
      info.lineupUrl,
      contains('/lineupJson/m100030/11/11/lineup_detail_total.json'),
    );
    expect(info.lineupUrl, isNot(contains(r'${')));
  });

  test('jcc parseModes 解析模式条目与各自阵容地址', () {
    const cfg = '''
var channel = '11';
      'Mode11_S100030':`https://a/lineupJson/m100030/11/\${channel}/lineup_detail_total.json`,
      '1_S1':`https://b/lineupJson/m1/\${channel}/1/lineup_detail_total.json`,
      {set_id: "Mode11", mode: "11", season: "S100030", id: "Mode11_S100030", name: "奇遇", set_name: "画之灵"},
      {set_id: "1", mode: "1", season: "S1", id: "1_S1", name: "时空裂痕", set_name: "时空裂痕"},
      {set_id: "x", mode: "9", season: "S9", id: "9_S9", name: "无阵容地址"},
''';
    final modes = parseModes(cfg);
    expect(modes.length, 3);
    expect(modes[0].name, '画之灵');
    expect(modes[0].lineupUrl, contains('/m100030/11/11/lineup_detail_total.json'));
    expect(modes[1].name, '时空裂痕');
    expect(modes[1].lineupUrl, contains('/m1/11/1/'));
    expect(modes[2].lineupUrl, isEmpty);
  });

  test('jcc pickVersionFiles 取 is_newest_version 条目', () {
    const list =
        '[{"mode":"11","season":"S100030","is_newest_version":0,"version_start_time":"2026-09-01","herourl":"/11/old/chess.js","equipurl":"/11/old/equip.js","hexurl":"/11/old/hex.js","traiturl":"/11/old/trait.js"},'
        '{"mode":"11","season":"S100030","is_newest_version":1,"version_start_time":"2026-09-29","herourl":"/11/18.11.1-S100030/chess.js","equipurl":"/11/18.11.1-S100030/equip.js","hexurl":"/11/18.11.1-S100030/hex.js","traiturl":"/11/18.11.1-S100030/trait.js","galaxyurl":"/11/18.11.1-S100030/galaxy.js","adventureurl":"/11/18.11.1-S100030/adventure.js"}]';
    final files = pickVersionFiles(list, '11', 'S100030');
    expect(files['chess'], '/11/18.11.1-S100030/chess.js');
    expect(files['trait'], '/11/18.11.1-S100030/trait.js');
    expect(files['equip'], '/11/18.11.1-S100030/equip.js');
    expect(files['hex'], '/11/18.11.1-S100030/hex.js');
    expect(files['galaxy'], '/11/18.11.1-S100030/galaxy.js');
    expect(files['adventure'], '/11/18.11.1-S100030/adventure.js');
  });

  test('jcc parseMechanismTabs 只取官方未注释的类别并保留各自模式', () {
    const cfg = '''
    mechanism_tab:[
      {set_id: "11", mode: "11", season: "S100030", version: "", id: "Mode11_S100030", name: "奇遇", hex_data:[{id:"galaxy",name:"奇遇"}]},
      {set_id: "18", mode: "18", season: "S19", version: "", id: "18_S19", name: "小精灵", hex_data:[{id:"adventure",name:"小精灵"}]},
      // {set_id: "17", mode: "17", season: "S18", id: "17_S18", name: "星神", hex_data:[{id:"godreward",name:"星神"}]},
      // {set_id: "8", mode: "8", season: "S19", id: "8_S19", name: "怪兽", hex_data:[{id:"monster",name:"怪兽"}]},
    ],
      '15_S16':[
        {id:"buff", tpl:"buff", name:"强化符文"},
      ],
    ''';
    final cats = parseMechanismTabs(cfg);
    expect(cats.length, 2);
    expect(cats[0].id, 'galaxy');
    expect(cats[0].name, '奇遇');
    expect(cats[0].modeId, 'Mode11_S100030');
    expect(cats[0].mode, '11');
    expect(cats[0].season, 'S100030');
    expect(cats[1].id, 'adventure');
    expect(cats[1].name, '小精灵');
    expect(cats[1].modeId, '18_S19');
  });

  test('jcc parseMechEntries 特殊机制按 id 排序且跳过无名条目', () {
    final data = {
      '408': {
        'id': '408',
        'name': '2星开局',
        'desc': '开局拥有1个随机的2星1费弈子。',
        'logo': 'https://x/2.png',
        'video': '',
        'bgImage': '',
      },
      '405': {
        'id': '405',
        'name': '棱彩终章',
        'desc': '最后一个强化符文将是棱彩阶。',
        'logo': 'https://x/1.png',
        'video': '',
        'bgImage': '',
      },
      '999': {'id': '999', 'name': '  ', 'desc': '无名条目', 'logo': '', 'video': ''},
    };
    expect(parseMechEntries(data.cast<String, dynamic>()), [
      {
        'id': '405',
        'name': '棱彩终章',
        'desc': '最后一个强化符文将是棱彩阶。',
        'pic': 'https://x/1.png',
        'video': '',
        'price': '',
      },
      {
        'id': '408',
        'name': '2星开局',
        'desc': '开局拥有1个随机的2星1费弈子。',
        'pic': 'https://x/2.png',
        'video': '',
        'price': '',
      },
    ]);
  });

  test('jcc parseMechEntries 兼容小精灵（adventure）字段名', () {
    final data = {
      '103': {
        'adventureId': '103',
        'title': '染血之币',
        'desc': '商店刷新时获得1金币。',
        'logo': 'https://y/coin.png',
        'price': 2,
        'category': '',
      },
      '7': {
        'adventureId': '7',
        'title': '余震',
        'desc': '每次刷新获得…',
        'logo': 'https://y/a.png',
        'price': 1,
        'category': '',
      },
    };
    expect(parseMechEntries(data.cast<String, dynamic>()), [
      {
        'id': '7',
        'name': '余震',
        'desc': '每次刷新获得…',
        'pic': 'https://y/a.png',
        'video': '',
        'price': '1',
      },
      {
        'id': '103',
        'name': '染血之币',
        'desc': '商店刷新时获得1金币。',
        'pic': 'https://y/coin.png',
        'video': '',
        'price': '2',
      },
    ]);
  });

  test('jcc jccAugmentTier 官方 level 写成中文档位，传说拼在同一维后面', () {
    expect(jccAugmentTier('1'), '一级');
    expect(jccAugmentTier(4), '四级');
    expect(jccAugmentTier('3', legend: true), '三级 · 传说');
    // 档位超出中文表（官方哪天加第七档）就原样显示数字，别抛 RangeError。
    expect(jccAugmentTier('7'), '7');
    expect(jccAugmentTier(''), '');
  });

  test('jcc groupTraits 按 checkId 聚合且 level 升序', () {
    final data = {
      'a': {
        'checkId': '200',
        'name': '护卫',
        'level': '2',
        'numList': '2|4',
        'desc2': 'B档',
        'picture': 'p.png',
        'prefix': '减伤',
        'type': 1,
      },
      'b': {
        'checkId': '200',
        'name': '护卫',
        'level': '1',
        'numList': '2|4',
        'desc2': 'A档',
        'picture': 'p.png',
        'prefix': '减伤',
        'type': 1,
      },
      'c': {
        'checkId': '238',
        'name': '剪纸仙灵',
        'level': '1',
        'numList': '3|5',
        'desc2': 'C档',
        'picture': '',
        'prefix': '',
        'type': 0,
      },
    };
    final groups = groupTraits(data.cast<String, dynamic>());
    expect(groups.length, 2);
    expect(groups['200']!.levels, ['A档', 'B档']);
    expect(groups['200']!.type, 1);
    final refs = traitRefs('238,200', groups);
    expect(refs.map((r) => r['name']), ['剪纸仙灵', '护卫']);
    expect(refs.map((r) => r['type']), [0, 1]);
    expect(traitRefs('200,200,999', groups).length, 1);
  });

  test('jcc 英雄原画地址与技能数值解析', () {
    const cfg = '''
  var baseUrlManager = {
    default_pic: '//a/logo.png',
    hero_pic_big:{
      "11_S100030":"//game.gtimg.cn/images/jk/jkimg/mode11s100030/1624x750/{{pic_name}}.jpg",
      "1_S1":"//game.gtimg.cn/images/jk/jkimg/champion/1624x750/{{pic_name}}.jpg"
    },
    hero_pic_long:{ "11_S100030":"//x/414x750/{{pic_name}}.jpg" }
  };
''';
    final pics = parseHeroPicMap(cfg);
    expect(pics.length, 2);
    expect(
      championBanner(pics, '11', 'S100030', 's11_garen'),
      'https://game.gtimg.cn/images/jk/jkimg/mode11s100030/1624x750/s11_garen.jpg',
    );
    expect(championBanner(pics, '11', 'S100030', ''), isEmpty);
    expect(championBanner(pics, '99', 'S99', 'x'), isEmpty);

    final values = parseSkillValues(
      '275/325/375|250/375/560',
      '护盾值：275【法术加成】 275/325/375|伤害：250【物理加成】 250/375/560',
    );
    expect(values.length, 2);
    expect(values[0]['label'], '护盾值');
    expect(values[0]['formula'], '275【法术加成】');
    expect(values[0]['tiers'], ['275', '325', '375']);
    expect(values[1]['label'], '伤害');
    expect(values[1]['tiers'], ['250', '375', '560']);
    expect(parseSkillValues('', ''), isEmpty);

    // 亚索：同名段落靠算式区分，无档位的重复公式段直接丢弃。
    final multi = parseSkillValues(
      '30%/45%/70%|225/250/300|60%/75%/100%|200/300/450',
      '被动伤害：27=30%【护甲】+30%【魔法抗性】 30%/45%/70%|护盾值：225 225/250/300|护盾值 【护甲】【魔法抗性】 60%/75%/100%|护盾值：279=225+60%【护甲】+60%【魔法抗性】 200/300/450|伤害：200(【法术加成】)',
    );
    expect(multi.length, 4);
    expect(multi[0]['label'], '被动伤害');
    expect(multi[0]['formula'], '27=30%【护甲】+30%【魔法抗性】');
    expect(multi[0]['tiers'], ['30%', '45%', '70%']);
    expect(multi[1]['label'], '护盾值');
    expect(multi[1]['formula'], '225');
    expect(multi[1]['tiers'], ['225', '250', '300']);
    expect(multi[2]['label'], '护盾值');
    expect(multi[2]['formula'], '【护甲】【魔法抗性】');
    expect(multi[2]['tiers'], ['60%', '75%', '100%']);
    expect(multi[3]['tiers'], ['200', '300', '450']);
  });

  test('jcc groupTraits 档位取 realDesc 且不重复', () {
    final data = {
      'a': {
        'checkId': '241',
        'name': '吉星',
        'level': '1',
        'num': '3',
        'color': '1',
        'numList': '3|5|7',
        'desc2': '(3)甲|(5)乙|(7)丙',
        'realDesc': '(3)甲',
        'picture': '',
        'prefix': '',
        'type': 0,
      },
      'b': {
        'checkId': '241',
        'name': '吉星',
        'level': '2',
        'num': '5',
        'color': '2',
        'numList': '3|5|7',
        'desc2': '(3)甲|(5)乙|(7)丙',
        'realDesc': '(5)乙',
        'picture': '',
        'prefix': '',
        'type': 0,
      },
      'c': {
        'checkId': '241',
        'name': '吉星',
        'level': '3',
        'num': '7',
        'color': '3',
        'numList': '3|5|7',
        'desc2': '(3)甲|(5)乙|(7)丙',
        'realDesc': '(7)丙',
        'picture': '',
        'prefix': '',
        'type': 0,
      },
      'd': {
        'checkId': '241',
        'name': '吉星',
        'level': '4',
        'num': '9',
        'color': '4',
        'numList': '3|5|7|9',
        'desc2': '(3)甲|(5)乙|(7)丙',
        'realDesc': '',
        'picture': '',
        'prefix': '',
        'type': 0,
      },
    };
    final group = groupTraits(data.cast<String, dynamic>())['241']!;
    expect(group.levels, ['(3)甲', '(5)乙', '(7)丙']);
    // 档位徽标用官方 num/color，正文去掉「(N)」前缀；realDesc 为空的档位丢弃。
    expect(group.tiers, [
      {'num': '3', 'color': 1, 'text': '甲'},
      {'num': '5', 'color': 2, 'text': '乙'},
      {'num': '7', 'color': 3, 'text': '丙'},
    ]);
  });

  test('jcc lineup 棋子/成型等级/标签推导', () {
    final chess = <String, dynamic>{
      '14202': {'name': '凯尔', 'price': '5', 'picture': 'kai.png'},
      '13217': {'name': '莫甘娜', 'price': '4', 'picture': 'mo.png'},
      '23217': {'name': '莫甘娜', 'price': '4', 'picture': 'mo.png'},
      '18084': {'name': '小小英雄', 'price': '0', 'picture': 'pet.png'},
    };
    final equip = <String, dynamic>{
      '2004': {'name': '无尽', 'picture': 'e1.png'},
      '2020': {'name': '蓝buff', 'picture': 'e2.png'},
    };
    final locs = [
      {'chess_type': 'pet', 'hero_id': '18084', 'location': '1,1'},
      {
        'chess_type': 'hero',
        'hero_id': '13217',
        'equipment_id': '2004,99999',
        'location': '1,4',
      },
      {
        'chess_type': 'hero',
        'hero_id': '14202',
        'equipment_id': '2004,2020',
        'is_carry_hero': true,
        'location': '4,7',
      },
    ];
    // canonById 把官方 1/2/3 星的重复条目归一到入库那条；归一不到的（如宠物）留空，前端不给跳转。
    final canon = {'13217': '13217', '23217': '13217', '14202': '14202'};
    final heroes = lineupCardHeroes(locs, chess, equip, {'13217'}, canon);
    expect(heroes.length, 2);
    expect(heroes[0]['name'], '莫甘娜');
    expect(heroes[0]['id'], '13217');
    expect(heroes[0]['star'], 3);
    expect(heroes[0]['items'], ['e1.png']);
    expect(heroes[1]['carry'], true);
    expect(heroes[1]['cost'], 5);
    expect(heroes[1]['r'], 4);
    expect(heroes[1]['c'], 7);
    final orphan = lineupCardHeroes(
      [
        {'chess_type': 'hero', 'hero_id': '23217', 'location': '2,3'},
        {'chess_type': 'hero', 'hero_id': '18084', 'location': '1,1'},
      ],
      chess,
      equip,
      {},
      canon,
    );
    expect(orphan[0]['id'], '13217');
    expect(orphan[1]['id'], '');

    expect(
      lineupFinalLevel({
        '4': [],
        '6': [
          {'a': 1},
        ],
        '8': [
          {'a': 1},
        ],
      }),
      8,
    );
    expect(lineupStyleTag(8, false), '速升8级');
    expect(lineupStyleTag(6, true), '6级追三星');
    expect(
      lineupStages(
        {
          '6': [locs[1]],
          '8': [locs[1], locs[2]],
        },
        chess,
        equip,
        {},
        canon,
      ).length,
      2,
    );
  });

  test('jcc canonicalChampionIds 同名多星条目归一到名册保留的那条', () {
    final rows = [
      {'id': '11214', 'name': '阿狸', 'price': '1', 'heroType': '0'},
      {'id': '21214', 'name': '阿狸', 'price': '1', 'heroType': '0'},
      {'id': '31214', 'name': '阿狸', 'price': '1', 'heroType': '0'},
      {'id': '12196', 'name': '亚托克斯', 'price': '2', 'heroType': '0'},
      {'id': '12311', 'name': '亚托克斯', 'price': '2', 'heroType': '0'},
      {'id': '18084', 'name': '小小英雄', 'price': '0', 'heroType': '1'},
    ];
    final roster = championRoster(rows.map((m) => m.cast<String, dynamic>()));
    final canon = canonicalChampionIds(
      rows.map((m) => m.cast<String, dynamic>()),
      roster,
    );
    expect(canon['31214'], '11214');
    expect(canon['21214'], '11214');
    expect(canon['12311'], '12196');
    expect(canon['12196'], '12196');
    expect(canon.containsKey('18084'), isFalse);
  });

  test('jcc championRoster 过滤宠物并按同名去重', () {
    final rows = [
      {'id': '21205', 'name': '盖伦', 'price': '1', 'heroType': '0'},
      {'id': '11205', 'name': '盖伦', 'price': '1', 'heroType': '0'},
      {'id': '31205', 'name': '盖伦', 'price': '1', 'heroType': '0'},
      {'id': '14202', 'name': '凯尔', 'price': '5', 'heroType': '0'},
      {'id': '18084', 'name': '小小英雄', 'price': '0', 'heroType': '1'},
      {'id': '19999', 'name': '', 'price': '2', 'heroType': '0'},
    ];
    final roster = championRoster(rows.map((m) => m.cast<String, dynamic>()));
    expect(roster.map((m) => m['name']), ['盖伦', '凯尔']);
    expect(roster.first['id'], '11205');
  });

  test('bsy parseBsyListPage 提取图鉴卡片', () {
    const html = '''
<html><body>
<a href="/gumballs/details.php?id=176"><i><img src="/images/gumballs/179.png" alt="开罗君冈布奥" /></i><span>开罗君冈布奥</span></a>
<a href="/gumballs/details.php?id=175"><img src="//cdn.x/a.png" alt="帝释天冈布奥"/><span>帝释天冈布奥</span></a>
<a href="/news/details.php?id=9"><span>无关新闻</span></a>
</body></html>''';
    final list = parseBsyListPage(html, '/gumballs/details.php?id=', 'gumball');
    expect(list.length, 2);
    expect(list[0].uid, 'bsy:gumball:176');
    expect(list[0].thumb, 'https://gumballs.leiting.com/images/gumballs/179.png');
    expect(list[1].thumb, 'https://cdn.x/a.png');
    expect(list[0].sourceUrl, 'https://gumballs.leiting.com/gumballs/details.php?id=176');
  });

  test('bsy parseBsyDesktopIds 取桌面版模板的 li data-id', () {
    // 桌面版列表项没有链接，只有 <li data-id>，称号筛选只能从这个模板拿。
    const html = '''
<html><body>
<div class="camp_tab_gba">
  <div class="swiper-container swiper-container-seven"><div class="swiper-wrapper"><div class="swiper-slide"><ul>
    <li class="active" data-id="410"><div class="pa illustrated_small_gba"><img src="/upfiles/a.png" alt="韩幹" /></div></li>
    <li data-id="409"><div class="pa illustrated_small_gba"><img src="/upfiles/b.png" alt="相土" /></div></li>
    <li><span>无 id 的干扰项</span></li>
  </ul></div></div></div>
</div>
</body></html>''';
    expect(parseBsyDesktopIds(html), ['410', '409']);
  });

  test('bsy bsyGbaTags 解析「阵营 · 称号」', () {
    expect(bsyGbaTags('奥鲁维之刃 · 战斗系').camp, '奥鲁维之刃');
    expect(bsyGbaTags('奥鲁维之刃 · 战斗系').honor, '战斗系');
    expect(bsyGbaTags('深渊的咆哮').honor, '');
    expect(bsyGbaTags('').camp, '');
    expect(bsyCamps.length, 4);
    expect(bsyHonors.length, 3);
  });

  test('bsy parseBsyLevelList 取 4399 关卡列表并按 id 去重', () {
    // 真实形状：列表项在 li 里，页头「热点」区还有指向同一篇文章的裸链接。
    const html = '''
<html><body>
<div class="hotsrch"><a href="//news.4399.com/slmbsymg/guanka/m/833472.html">诸神的棋盘</a>
<a href="//news.4399.com/slmbsymg/xinde/m/711774.html">天空副本攻略</a></div>
<ul class="clist l170 cf">
  <li><a href="//news.4399.com/slmbsymg/guanka/m/929112.html"><img src="//newsimg.5054399.com/uploads/a.jpg" alt="不思议迷宫山海秘境"/>山海秘境</a></li>
  <li><a href="//news.4399.com/slmbsymg/guanka/m/920906.html"><img src="http://x/b.jpg" alt="不思议迷宫第九十一区"/>第九十一区</a></li>
  <li><a href="/slmbsymg/guanka/m/833472.html"><img src="//newsimg.5054399.com/uploads/c.jpg" alt="不思议迷宫诸神的棋盘"/>诸神的棋盘</a></li>
  <li class="on"><a href="/slmbsymg/guanka/">关卡攻略</a></li>
  <li><a href="/other/m/123.html"><img src="//x/d.jpg" alt="没有图也没有正文"/></a></li>
</ul>
</body></html>''';
    final list = parseBsyLevelList(html);
    expect(list.map((e) => e.title).toList(), ['山海秘境', '第九十一区', '诸神的棋盘']);
    expect(list[0].uid, 'bsy:level:929112');
    expect(list[0].thumb, 'https://newsimg.5054399.com/uploads/a.jpg');
    expect(list[1].thumb, 'http://x/b.jpg');
    expect(list[2].sourceUrl, 'https://news.4399.com/slmbsymg/guanka/m/833472.html');
  });

  test('bsy parseBsyTempleList 取汇总页表格并按分区标题分组', () {
    // 真实形状：正文里第一张表才是试炼汇总，第二张是站内推荐，不能收进来。
    const html = '''
<html><body>
<div class="w700 fl"><div class="content">
<table><tbody>
  <tr><td colspan="3"><strong>雪山神庙</strong></td></tr>
  <tr><td><a href="//news.4399.com/slmbsymg/xinde/m/745866.html">雪山神庙开启方法</a></td>
      <td>&nbsp;<a href="//news.4399.com/slmbsymg/xinde/m/745873.html">冒险者试炼</a></td>
      <td><a target="_blank" href="//news.4399.com/slmbsymg/xinde/m/785392.html"><font color="#ff0000">巫医试炼</font></a></td></tr>
  <tr><td><a href="//news.4399.com/slmbsymg/guanka/m/725710.html">终结者的试炼</a></td>
      <td><a href="//news.4399.com/slmbsymg/xinde/m/745866.html">重复的条目</a></td>
      <td><a href="//news.4399.com/slmbsymg/xinde/">没有 id 的栏目链接</a></td></tr>
  <tr><td colspan="3">试炼低挂树打法合集（老坏出品）</td></tr>
  <tr><td><a href="/slmbsymg/xinde/m/887211.html">冒险者试炼</a></td><td></td><td></td></tr>
  <tr><td colspan="3">通过古仪式祭品完成试炼<br/>说明文字<a href="/slmbsymg/wenda/m/847687.html">古仪式祭品获得方法</a></td></tr>
</tbody></table>
<table><tr><td><a href="//news.4399.com/slmbsymg/xinde/m/712887.html">不思议迷宫攻略</a></td></tr></table>
</div></div>
</body></html>''';
    final list = parseBsyTempleList(
      html,
      gumballThumbs: const {
        '冒险者': 'https://g/a.png',
        '巫医': 'https://g/w.png',
        '终结者冈布奥': 'https://g/t.png',
      },
    );
    // 对不上冈布奥的一律不算试炼：「雪山神庙开启方法」是教程，「古仪式祭品获得方法」是杂项。
    expect(list.map((e) => '${e.title}|${e.subtitle}').toList(), [
      '冒险者试炼|雪山神庙',
      '巫医试炼|雪山神庙',
      '终结者的试炼|雪山神庙',
      '冒险者试炼|试炼低挂树打法合集（老坏出品）',
    ]);
    expect(list[0].uid, 'bsy:temple:745873');
    // 去掉「(的)试炼」后直接命中，或补上「冈布奥」后缀命中。
    expect(list.map((e) => e.thumb).toList(), [
      'https://g/a.png',
      'https://g/w.png',
      'https://g/t.png',
      'https://g/a.png',
    ]);
    expect(list[2].sourceUrl, 'https://news.4399.com/slmbsymg/guanka/m/725710.html');
    expect(list[3].sourceUrl, 'https://news.4399.com/slmbsymg/xinde/m/887211.html');
    // 冈布奥那轮没抓到时整批不交，别把库里已有的试炼清空。
    expect(parseBsyTempleList(html, gumballThumbs: const {}), isEmpty);
  });

  test('bsy parseBsyNewsDetail 摊平图文并在精彩推荐处截断', () {
    const html = '''
<html><body>
<div class="coninfo"><span>紫婴</span><span>20-12-03</span><span class="eye"></span></div>
<div class="w700 fl"><div class="content">
  <p>想要进入山海秘境，玩家需要<font color="#ff0000">在商店使用50钻解锁</font>。</p>
  <p align="center"><img src="//newsimg.5054399.com/uploads/2012/a.jpg" alt="图"/></p>
  <center><img src="/up/b.jpg"/></center>
  <p><font size="3">===灵根===</font></p>
  <p><font size="4"><strong><font color="#33cccc">▍ </font>精彩推荐</strong></font></p>
  <p><a href="/slmbsymg/xinde/m/712887.html">不思议迷宫攻略大全</a></p>
</div></div>
</body></html>''';
    final blocks = parseBsyNewsDetail(html);
    expect(blocks[0]['k'], 'kv');
    expect(blocks[0]['rows'], [
      ['作者', '紫婴'],
      ['发布于', '2020-12-03'],
    ]);
    expect(blocks[1], {'k': 'text', 't': '想要进入山海秘境，玩家需要在商店使用50钻解锁。'});
    expect(blocks[2], {
      'k': 'img',
      'url': 'https://newsimg.5054399.com/uploads/2012/a.jpg',
    });
    // center 里的图也要收进来，正文只到「精彩推荐」之前的站内链接。
    expect(blocks[3]['url'], 'https://news.4399.com/up/b.jpg');
    expect(blocks[4]['t'], '===灵根===');
    expect(blocks.length, 5);
  });

  test('bsy parseBsyNewsDetail 收正文表格，站尾「不思议迷宫攻略」导航表不收', () {
    const html = '''
<html><body>
<div class="w700 fl"><div class="content">
  <p>称号路线如下：</p>
  <table>
    <tr><td colspan="2">法师系</td></tr>
    <tr><th>一转</th><th>二转</th></tr>
    <tr><td>黑袍巫师</td><td>大法师</td></tr>
    <tr><td></td><td>只有一格有字</td></tr>
  </table>
  <table>
    <tr><td>不思议迷宫攻略</td><td><a href="/slmbsymg/xinde/m/796256.html">新手指南</a></td></tr>
    <tr><td>冈布奥大全</td><td>关卡大全</td></tr>
  </table>
</div></div>
</body></html>''';
    final blocks = parseBsyNewsDetail(html);
    expect(blocks.map((b) => b['k']), ['text', 'table']);
    expect(blocks[1]['rows'], [
      ['法师系'],
      ['一转', '二转'],
      ['黑袍巫师', '大法师'],
      ['只有一格有字'],
    ]);
  });

  test('bsy parseBsyGuideModules 生成十四个模块，正文留给详情页懒抓', () {
    final modules = parseBsyGuideModules();
    expect(modules.length, 14);
    expect(modules.first.uid, 'bsy:guide:0');
    expect(modules.first.title, '新手指南');
    expect(modules.last.title, '称号搭配');
    expect(modules.last.sourceUrl, '$newsHost/slmbsymg/xinde/m/716343.html');
    expect(
      modules.every((m) => m.type == 'guide' && m.blocks.isEmpty),
      isTrue,
      reason: '目录条目不该带正文，详情页按 sourceUrl 懒抓',
    );
    expect(bsyColumnHasSource('guide'), isTrue);
    expect(bsyColumnHasSource('strategy'), isFalse);
  });

  test('jcc parseEquipStats 拆分官方 basicDesc', () {
    expect(parseEquipStats(' +35物理加成 +35%暴击率'), ['+35物理加成', '+35%暴击率']);
    expect(parseEquipStats(''), isEmpty);
    expect(parseEquipStats('   '), isEmpty);
  });

  test('jcc equipCatRank 按资料库分组顺序排序', () {
    expect(equipCatOrder.first, '基础装备');
    expect(equipCatRank('基础装备') < equipCatRank('成型装备'), isTrue);
    expect(equipCatRank('成型装备') < equipCatRank('转职纹章'), isTrue);
    expect(equipCatRank('未知分类'), equipCatOrder.length);
  });

  test('bsy parseBsyWishList 按分号拆出每条愿望', () {
    // 真实形状：相邻愿望会用「；」连在同一段里，段里还夹着站内链接尾巴。
    const html = '''
<div class="w700 fl"><div class="content">
<p>不思议迷宫玩家集齐7颗龙珠后可以召唤神龙许愿。</p>
<p>我要变得富有：打怪获得30W左右游戏币（备好死亡波纹）；</p>
<p>我要大量的矿石：获得4-5阶矿石，消耗血量150点；我要无上的权利：给一些矿石材料；</p>
<p>我要您的碎片：获得神龙冈布奥碎片。</p>
<p>以上就是小编推荐：|百度搜索【4399不思议迷宫】。</p>
</div></div>''';
    final list = parseBsyWishList(html);
    expect(list.map((e) => e.title).toList(), ['我要变得富有', '我要大量的矿石', '我要无上的权利', '我要您的碎片']);
    expect(list[0].uid, 'bsy:shenlong:0');
    expect(list[0].subtitle, startsWith('打怪获得30W左右游戏币'));
    expect(list.first.blocks.single['t'], list.first.subtitle);
    expect(list.map((e) => e.sourceUrl).toSet(), {bsyWishUrl});
  });

  test('bsy parseBsyPotionList 等级取自 href，懒加载图在 lz_src', () {
    const html = '''
<ul class="clist l80 cf" >
  <li><a href="//news.4399.com/slmbsymg/yaoji/4/m/868350.html">
      <img src="//newsimg.5054399.com/a.jpg"/>伊甸之泉</a></li>
  <li><a href="//news.4399.com/slmbsymg/yaoji/4/m/868350.html">重复的条目</a></li>
</ul>
<ul class="clist l80 cf" style="display:none">
  <li><a href="//news.4399.com/slmbsymg/yaoji/1/m/728487.html">
      <img lz_src="//newsimg.5054399.com/b.jpg"/>血肉试剂</a></li>
</ul>
<ul class="navlist"><li><a href="//news.4399.com/slmbsymg/yaoji/">药剂大全栏目</a></li></ul>''';
    final list = parseBsyPotionList(html);
    expect(list.map((e) => '${e.title}|${e.subtitle}').toList(), ['伊甸之泉|四级', '血肉试剂|一级']);
    expect(list[0].uid, 'bsy:yaoji:868350');
    expect(list[0].thumb, 'https://newsimg.5054399.com/a.jpg', reason: 'src 有值时优先用 src');
    expect(list[1].thumb, 'https://newsimg.5054399.com/b.jpg');
    expect(list[1].sourceUrl, 'https://news.4399.com/slmbsymg/yaoji/1/m/728487.html');
    // 正文是独立文章，条目自己不带 blocks，留给详情页懒抓。
    expect(list[0].blocks, isEmpty);
  });

  test('bsy parseBsyPotionDetail 只留正文表格里的来源与功效', () {
    const html = '''
<div class="w700"><div class="content"><p>伊甸之泉是四阶药剂，一起来看看吧！</p>
<table><tbody>
  <tr><td rowspan="4"><img src="//newsimg.5054399.com/a.jpg"/></td><td><strong>名称</strong></td><td><p>伊甸之泉</p></td></tr>
  <tr><td><strong>阶位</strong></td><td><p align="center">4阶</p></td></tr>
  <tr><td><strong>来源</strong></td><td><p>俯瞰大厅小副本</p></td></tr>
  <tr><td><strong>功效</strong></td><td><p>攻击及魔力+3<br>每下一层恢复生命+10</p></td></tr>
  <tr><td colspan="3"><strong>&gt;&gt;&gt;</strong><a href="//news.4399.com/slmbsymg/yaoji/">不思议迷宫药剂大全</a></td></tr>
</tbody></table>
<table><tbody><tr><td>不思议迷宫攻略</td></tr></tbody></table>
</div></div>''';
    expect(parseBsyPotionDetail(html), [
      {
        'k': 'kv',
        'rows': [
          ['来源', '俯瞰大厅小副本'],
          ['功效', '攻击及魔力+3\n每下一层恢复生命+10'],
        ],
      },
    ]);
  });

  test('bsy parseBsyStoneList 收三列表格，缺奖励的行丢掉', () {
    const html = '''
<div class="content-box"><table><tbody>
  <tr><td>吟游诗人</td><td>创世神</td><td>50000金币</td></tr>
  <tr><td>装甲</td><td></td><td>30000金币</td></tr>
  <tr><td>空行</td><td>有</td><td></td></tr>
</tbody></table></div>''';
    final list = parseBsyStoneList(html);
    expect(list.map((e) => '${e.title}|${e.subtitle}').toList(), [
      '吟游诗人 + 创世神|50000金币',
      '装甲|30000金币',
    ]);
    expect(list[0].uid, 'bsy:shizhu:0');
    expect(list[1].blocks.single['rows'].length, 2, reason: '右侧为空的行不给该字段');
    expect(list[0].sourceUrl, bsyStoneUrl);
  });

  test('bsy parseBsyAltarList 从「如下：」之后收到「放不同的物品」为止', () {
    const html = '''
<div class="w700 fl"><div class="content">
<p>问：不思议迷宫机械祭坛放什么东西?</p>
<p>答：可放置的物品及奖励内容如下：</p>
<p>爆裂火箭弹：史莱姆土罐*5</p>
<p>Mark3： 黄金罐*5</p>
<p>放不同的物品可以获得不同的奖励。</p>
<p>小编推荐：百度搜索【4399不思议迷宫】。</p>
</div></div>''';
    final list = parseBsyAltarList(html);
    expect(list.map((e) => '${e.title}|${e.subtitle}').toList(), [
      '爆裂火箭弹|史莱姆土罐*5',
      'Mark3|黄金罐*5',
    ]);
    expect(list[0].uid, 'bsy:jitan:0');
    expect(list[1].blocks.single['rows'], [
      ['摆放祭品', 'Mark3'],
      ['祭坛产出', '黄金罐*5'],
    ]);
  });

  test('bsy parseBsyShrineList 拆出道具、奖励与「——」后的条件', () {
    const html = '''
<div class="w700 fl"><div class="content">
<p>不思议迷宫东方神龛在迷宫的boss层随机会出现。</p>
<p>提交五轮书，获得战斗系遗物*5</p>
<p>提交紧箍，获得钻石*25——孙悟空出战或链接</p>
<p>提交二郎神的东方的剪纸，可获得3个黄金之罐</p>
<p>注意：东方的神龛只能提交3次正确的物品。</p>
</div></div>''';
    final list = parseBsyShrineList(html);
    // 这一栏只显示列表、不进详情，所以「——」后的条件要跟着进 subtitle。
    expect(list.map((e) => '${e.title}|${e.subtitle}').toList(), [
      '五轮书|战斗系遗物*5',
      '紧箍|钻石*25 —— 孙悟空出战或链接',
      '二郎神的东方的剪纸|3个黄金之罐',
    ]);
    expect(list[1].blocks.single['rows'], [
      ['提交道具', '紧箍'],
      ['获得奖励', '钻石*25'],
      ['说明', '孙悟空出战或链接'],
    ]);
    expect(list[0].blocks.single['rows'].length, 2);
  });

  test('bsy parseBsyDpList 只取汇总表格，按分区标题分组', () {
    const html = '''
<div class="w700 fl"><div class="content">
<table><tbody>
  <tr><td colspan="3">主线DP攻略</td></tr>
  <tr><td><a href="//news.4399.com/slmbsymg/xinde/m/831358.html">冒险者之森</a></td>
      <td><a href="/slmbsymg/xinde/m/829672.html">英雄之村</a></td><td>-</td></tr>
  <tr><td colspan="3">资料片副本DP攻略</td></tr>
  <tr><td><a href="/slmbsymg/xinde/m/830501.html">骷髅岛</a></td><td></td><td></td></tr>
</tbody></table>
<table><tr><td><a href="/slmbsymg/xinde/m/999999.html">站内推荐</a></td></tr></table>
</div></div>''';
    final list = parseBsyDpList(html);
    expect(list.map((e) => '${e.title}|${e.subtitle}').toList(), [
      '冒险者之森|主线DP攻略',
      '英雄之村|主线DP攻略',
      '骷髅岛|资料片副本DP攻略',
    ]);
    expect(list[0].uid, 'bsy:dp:831358');
    expect(list[1].sourceUrl, 'https://news.4399.com/slmbsymg/xinde/m/829672.html');
    expect(list.map((e) => e.uid), isNot(contains('bsy:dp:999999')));
  });

  test('bsy parseBsySkyList 按【】分节，图片攻略只留文章链接', () {
    const html = '''
<div class="w700 fl"><div class="content">
<p>很多玩家都在问不思议迷宫天宫副本怎么过。</p>
<p>【阴森的古堡】</p>
<p>探索等级≥160</p>
<p>出战：强盗，链接：任意，神器：无需。</p>
<p>开始点尸体和书架，拿到钥匙下楼。</p>
<p>【废弃的兵工厂】</p>
<p>由于是图片攻略，请点击<a href="/slmbsymg/guanka/m/714590.html">查看</a></p>
</div></div>''';
    final list = parseBsySkyList(html);
    expect(list.map((e) => '${e.title}|${e.subtitle}').toList(), [
      '阴森的古堡|探索等级≥160',
      '废弃的兵工厂|天空副本',
    ]);
    expect(list[0].blocks.first['k'], 'kv');
    expect(list[0].blocks.first['rows'], [
      ['探索等级', '160'],
    ]);
    expect(list[0].blocks.length, 3);
    expect(list[0].sourceUrl, bsySkyUrl);
    // 指向独立文章的那条：正文交给详情页懒抓，条目自己不写 blocks。
    expect(list[1].blocks, isEmpty);
    expect(list[1].sourceUrl, 'https://news.4399.com/slmbsymg/guanka/m/714590.html');
  });

  test('bsy parseBsyQuiz 取内嵌 var list 题库，页面表格只渲染前几行', () {
    const html = '''
<div class="m-body">
<table class="m-table"><tbody id="datiList">
  <tr><td>伙计！我在操作机械时…其中n=?</td><td>N=307</td></tr>
</tbody></table>
</div>
<script>
var list = [
  {"question":"伙计！我在操作机械时，遇到了些麻烦。操作手册上有组数列，你能帮我解开它吗?256、269、286、302、n，其中n=?","answer":"N=307"},
  {"question":"圣者阿斯塔纳，发现了一个自然界最完美的公式，它将数学中最重要的几个元素，联系在一起，你知道e^πi = ?","answer":"-1"},
  {"question":"魔法学院有一面神奇的镜子，虽然没有施加过任何魔法，但透过它，可将看到的物体放大。请问，这是什么镜子?","answer":""}
];
</script>''';
    final list = parseBsyQuiz(html);
    expect(list.map((e) => e.subtitle).toList(), ['N=307', '-1']);
    expect(list[0].title.endsWith('256、269、286、302、n，其中n=?'), isTrue);
    expect(list[0].uid, 'bsy:quiz:0');
    expect(list[0].sourceUrl, bsyQuizUrl);
    expect(list[1].blocks.single['rows'], [
      ['问题', list[1].title],
      ['答案', '-1'],
    ]);
    expect(parseBsyQuiz('<html><body>没有题库脚本</body></html>'), isEmpty);
  });

  test('bsy parseBsyFeiting 类别取当前页的 on，uid 用 /gl/ 文章 id', () {
    const html = '''
<div class="bq_list">
  <a class="on"><i></i>科技类</a>
  <a href="/zt/259_gl_fttj_85_1/"><i></i>魔法类</a>
</div>
<div class="info">
  <a href="https://shouyou.3dmgame.com/gl/11699.html" target="_blank"><div class="img"><img data-original="https://syimg.3dmgame.com/a.jpg"></div><span>死星</span></a>
  <a href="https://shouyou.3dmgame.com/gl/11631.html" target="_blank"><div class="img"><img src="/b.png"></div><span>冈布奥号</span></a>
  <a href="https://shouyou.3dmgame.com/zt/259/" target="_blank"><span>专区入口</span></a>
</div>''';
    final list = parseBsyFeiting(html);
    expect(list.map((e) => '${e.title}|${e.subtitle}').toList(), ['死星|科技类', '冈布奥号|科技类']);
    expect(list[0].uid, 'bsy:feiting:11699');
    expect(list[0].sourceUrl, 'https://shouyou.3dmgame.com/gl/11699.html');
    expect(list[0].thumb, 'https://syimg.3dmgame.com/a.jpg');
    // 懒加载图在 data-original 上，相对路径要补全站名；指向专区的链接不是条目。
    expect(list[1].thumb, 'https://shouyou.3dmgame.com/b.png');
    expect(list.map((e) => e.sortOrder).toList(), [0, 1]);
    expect(
      parseBsyFeiting('<div class="info"><a href="/zt/259/"><span>x</span></a></div>'),
      isEmpty,
    );
  });

  test('bsy parseBsyRobot 共用 .info 条目解析，没有类别 tabs 就不带 subtitle', () {
    const html = '''
<div class="zqleft_warptop"><span>不思议迷宫天空机器人</span></div>
<div class="info">
  <a href="https://shouyou.3dmgame.com/gl/107260.html" target="_blank"><div class="img"><img data-original="https://syimg.3dmgame.com/w.jpg"></div><span>瓦力</span></a>
  <a href="https://shouyou.3dmgame.com/gl/107111.html" target="_blank"><div class="img"><img data-original="https://syimg.3dmgame.com/h.jpg"></div><span>毁灭玩偶</span></a>
</div>''';
    final list = parseBsyRobot(html);
    expect(list.map((e) => e.title).toList(), ['瓦力', '毁灭玩偶']);
    expect(list.map((e) => e.subtitle).toList(), ['', '']);
    expect(list[0].uid, 'bsy:robot:107260');
    expect(list[0].type, 'robot');
    expect(list[1].sourceUrl, 'https://shouyou.3dmgame.com/gl/107111.html');
  });

  test('bsy parseBsyAbyss 一格一个冈布奥，没有链接的格子 sourceUrl 留空', () {
    const html = '''
<div class="w700"><div class="content">
<table border="1"><tbody>
  <tr><td bgcolor="#ff99ff" colspan="6"><strong><font color="#000000">渊的咆哮阵营冈布奥大全</font></strong></td></tr>
  <tr>
    <td align="center"><div><img alt="吸血伯爵" src="//newsimg.5054399.com/uploads/userup/1604/10154121D24.jpg"></div>
        <div><a href="//news.4399.com/slmbsymg/shilaimu/zd/m/620796.html">吸血伯爵</a></div></td>
    <td align="center"><div><img alt="恶魔" src="//newsimg.5054399.com/uploads/userup/1604/e.jpg"></div>
        <div>恶魔</div></td>
    <td align="center"><div><img alt="地狱火 " src="//newsimg.5054399.com/uploads/userup/1604/h.jpg"></div>
        <div><a href="//news.4399.com/slmbsymg/shilaimu/mf/m/714133.html">地狱火</a> </div></td>
  </tr>
</tbody></table>
</div></div>''';
    final list = parseBsyAbyss(html);
    expect(list.map((e) => e.title).toList(), ['吸血伯爵', '恶魔', '地狱火']);
    expect(list[0].uid, 'bsy:abyss:620796');
    expect(
      list[0].thumb,
      'https://newsimg.5054399.com/uploads/userup/1604/10154121D24.jpg',
    );
    expect(list[0].sourceUrl, 'https://news.4399.com/slmbsymg/shilaimu/zd/m/620796.html');
    // 没链接的那格：名字还在，但不进详情页。
    expect(list[1].uid, 'bsy:abyss:恶魔');
    expect(list[1].sourceUrl, '');
    expect(list[2].sourceUrl, 'https://news.4399.com/slmbsymg/shilaimu/mf/m/714133.html');
  });

  test('bsy parseBsy3dmDetail 摊平 3DM 正文表格，停在站方套话前', () {
    const html = '''
<div class="news_warp_top"><div class="time">时间：<span>2017-04-25 11:47:46</span></div></div>
<div class="news_warp_center">
  <p style="text-indent:2em;">《不思议迷宫》死星是科技飞艇。</p>
  <p><table border="1"><tbody>
    <tr><td colspan="3"><strong>死星</strong></td></tr>
    <tr><td rowspan="5"><img src="https://syimg.3dmgame.com/x.png"></td><td colspan="2">圆满属性</td></tr>
    <tr><td>火力</td><td>25</td></tr>
    <tr><td>主炮效果</td><td colspan="2">
      <p>威力：造成100%的伤害</p>
      <p>特殊：摧毁整个行星</p>
    </td></tr>
  </tbody></table></p>
  <p><strong>本文内容来源于互联网，如有侵权请联系删除。</strong></p>
</div>''';
    final blocks = parseBsy3dmDetail(html);
    expect(blocks.length, 3);
    expect(blocks[0], {
      'k': 'kv',
      'rows': [
        ['发布于', '2017-04-25 11:47:46'],
      ],
    });
    expect(blocks[1], {'k': 'text', 't': '《不思议迷宫》死星是科技飞艇。'});
    // 表格里空文字的单元格（放飞艇图的那格）丢掉，剩下的按行摊平。
    expect(blocks[2]['k'], 'table');
    expect(blocks[2]['rows'], [
      ['死星'],
      ['圆满属性'],
      ['火力', '25'],
      ['主炮效果', '威力：造成100%的伤害\n特殊：摧毁整个行星'],
    ]);
  });
}
