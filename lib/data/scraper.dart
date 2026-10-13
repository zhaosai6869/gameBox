import 'dart:async';
import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:dio/dio.dart';

const userAgent =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

class Http {
  final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent': userAgent,
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Referer': 'https://gumballs.leiting.com/',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.plain,
    ),
  );

  Future<String> get(String url, {Map<String, String>? headers}) async {
    Object? lastError;
    for (var i = 0; i < 3; i++) {
      try {
        final r = await _dio.get<String>(url, options: Options(headers: headers));
        final body = r.data ?? '';
        if (body.isEmpty) throw Exception('empty body: $url');
        return body;
      } catch (e) {
        lastError = e;
        await Future.delayed(Duration(milliseconds: 600 * (i + 1)));
      }
    }
    throw Exception('抓取失败 $url: $lastError');
  }

  /// 原始字节抓取后按页面 charset 解码：4399 响应头只给 text/html（不带 charset），
  /// Dio 会按 UTF-8 硬解成乱码，所以 GBK 站点必须自己读 meta 再选编码。
  Future<String> getDecoded(String url) async {
    final bytes = await getBytes(url);
    final name = _metaCharset(bytes);
    final encoding = name == null ? utf8 : (Charset.getByName(name) ?? utf8);
    try {
      return encoding.decode(bytes);
    } on FormatException {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  Future<List<int>> getBytes(String url) async {
    Object? lastError;
    for (var i = 0; i < 3; i++) {
      try {
        final r = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final body = r.data ?? const <int>[];
        if (body.isEmpty) throw Exception('empty body: $url');
        return body;
      } catch (e) {
        lastError = e;
        await Future.delayed(Duration(milliseconds: 600 * (i + 1)));
      }
    }
    throw Exception('抓取失败 $url: $lastError');
  }

  static String? _metaCharset(List<int> head) {
    final s = String.fromCharCodes(head.take(4096));
    return RegExp(
      r'charset[\s=:/"\x27]*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(s)?.group(1)?.toLowerCase();
  }
}

/// 抓到的条目；blocks 为渲染块列表（见 ui/blocks_view.dart 约定）。
class ScrapedEntity {
  final String uid;
  final String gameId;
  final String mode;
  final String type;
  final String title;
  final String subtitle;
  final String thumb;
  final String sourceUrl;
  final int sortOrder;
  final List<Map<String, dynamic>> blocks;

  const ScrapedEntity({
    required this.uid,
    required this.gameId,
    this.mode = '',
    required this.type,
    required this.title,
    this.subtitle = '',
    this.thumb = '',
    this.sourceUrl = '',
    this.sortOrder = 0,
    this.blocks = const [],
  });

  ScrapedEntity copyWith({
    List<Map<String, dynamic>>? blocks,
    String? thumb,
    int? sortOrder,
  }) => ScrapedEntity(
    uid: uid,
    gameId: gameId,
    mode: mode,
    type: type,
    title: title,
    subtitle: subtitle,
    thumb: thumb ?? this.thumb,
    sourceUrl: sourceUrl,
    sortOrder: sortOrder ?? this.sortOrder,
    blocks: blocks ?? this.blocks,
  );
}

abstract class GameScraper {
  String get gameId;
  String get gameName;
  Map<String, String> get typeLabels;
  List<String> get typeOrder;

  /// 可切换的模式（赛季/玩法分区）；空列表表示该游戏不分模式。
  Future<List<GameMode>> loadModes() async => const [];

  Future<void> init();

  /// 全量列表抓取（刷新时调用）：type -> 条目。
  Future<Map<String, List<ScrapedEntity>>> crawlAll({String mode = ''});

  /// 「特殊机制」这类栏目的类别（官方 mechanism_tab）；空表示该游戏没有。
  Future<List<MechCategory>> loadMechCategories() async => const [];

  /// 特殊机制的全部条目：不随模式切换，按类别各自归属的模式存放。
  Future<List<ScrapedEntity>> crawlMech() async => const [];

  /// 详情页懒抓取；返回渲染块，null 表示不支持。
  Future<List<Map<String, dynamic>>>? fetchDetail(ScrapedEntity entity) => null;

  /// 「其他」里某个栏目的按需抓取（栏目页首次打开时调用，不进全量刷新）；
  /// 返回 null 表示该栏目还没有数据源。
  Future<List<ScrapedEntity>>? crawlColumn(String type) => null;

  /// 抽屉里「更新」按钮要跑的分步清单：一步 = 一个模式或一个栏目，
  /// 单独成功/失败，所以某一步挂了不会把已抓到的数据一起丢掉。
  Future<List<CrawlStep>> updateSteps() async {
    return [(label: gameName, run: crawlAll)];
  }
}

/// 「更新」的一步：`label` 直接给用户看，`run` 返回 type -> 条目。
/// 落库按条目自带的 mode 分组，见 state/providers.dart 的 writeStep。
typedef CrawlStep = ({
  String label,
  Future<Map<String, List<ScrapedEntity>>> Function() run,
});

/// 特殊机制的一个类别（官方 basicConfig.js 的 mechanism_tab 条目）。
class MechCategory {
  /// 数据文件标识：galaxy / adventure，对应 versiondataconfig 的 `<id>url`。
  final String id;

  /// 官方展示名：奇遇 / 小精灵。
  final String name;

  /// 该类别所属的模式条目 id，作为 Entity.mode 存储。
  final String modeId;
  final String mode;
  final String season;

  const MechCategory({
    required this.id,
    required this.name,
    required this.modeId,
    required this.mode,
    required this.season,
  });
}

/// 一个模式（如金铲铲的「画之灵」），mode/season 为官方数据文件的定位键。
class GameMode {
  final String id;
  final String name;
  final String mode;
  final String season;
  final String lineupUrl;

  const GameMode({
    required this.id,
    required this.name,
    required this.mode,
    required this.season,
    this.lineupUrl = '',
  });
}

String utf8Of(String raw) {
  // leiting / gtimg 均为 UTF-8；此函数留给未来 GBK 源扩展。
  return raw;
}

List<Map<String, dynamic>> decodeBlocks(String payload) {
  if (payload.isEmpty || payload == '[]') return [];
  try {
    final v = jsonDecode(payload);
    return v is List ? v.cast<Map<String, dynamic>>() : [];
  } catch (_) {
    return [];
  }
}
